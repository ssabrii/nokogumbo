local Buffer = require "gumbo.buffer"
local Indent = require "gumbo.indent"

-- This has had much less attention than the other two serializers and is
-- inherently much harder to do properly. Consider it experimental for now.

-- TODO:
-- * Collapse newlines around inline elements and short block elements.
-- * Handle <style>, <script> and <pre> elements properly.
-- * Implement escaping for special characters in tag names (e.g. '=')?

-- Set of void elements
-- whatwg.org/specs/web-apps/current-work/multipage/syntax.html#void-elements
local void = {
    area = true,
    base = true,
    br = true,
    col = true,
    embed = true,
    hr = true,
    img = true,
    input = true,
    keygen = true,
    link = true,
    menuitem = true,
    meta = true,
    param = true,
    source = true,
    track = true,
    wbr = true
}

local escmap = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;"
}

local function escape(text)
    return text:gsub("[&<>]", escmap)
end

local function wrap(text, indent)
    local limit = 78
    local indent_width = #indent
    local pos = 1 - indent_width
    local function reflow(start, word, stop)
        if stop - pos > limit then
            pos = start - indent_width
            return "\n" .. indent .. word
        else
            return " " .. word
        end
    end
    return indent, text:gsub("%s+()(%S+)()", reflow), "\n"
end

local function to_html(node, buffer, indent_width)
    local buf = buffer or Buffer()
    local indent = Indent(indent_width)
    local function serialize(node, level)
        if node.type == "element" then
            local tag = node.tag
            buf:write(indent[level], "<", tag)
            for index, name, value in node:attr_iter() do
                if value == "" then
                    buf:write(" ", name)
                else
                    buf:write(" ", name, '="', value:gsub('"', "&quot;"), '"')
                end
            end
            buf:write(">")
            local length = #node
            if length == 0 then
                if not void[tag] then
                    buf:write("</", tag, ">")
                end
            elseif tag == "script" or tag == "style" then -- Raw text node
                assert(length == 1 and node[1].type == "text")
                buf:write("\n")
                buf:write(wrap(node[1].text, indent[level+1]))
                buf:write(indent[level], "</", tag, ">")
            elseif length == 1 and node[1].type == "text"
                   and #node.attr == 0 and #node[1].text <= 40
            then
                buf:write(node[1].text)
                buf:write("</", tag, ">")
            else
                buf:write("\n")
                for i = 1, length do
                    serialize(node[i], level + 1)
                end
                buf:write(indent[level], "</", tag, ">")
            end
            buf:write("\n")
        elseif node.type == "text" then
            buf:write(wrap(escape(node.text), indent[level]))
        elseif node.type == "comment" then
            buf:write(indent[level], "<!--", node.text, "-->\n")
        elseif node.type == "document" then
            if node.has_doctype == true then
                buf:write("<!doctype ", node.name, ">\n")
            end
            for i = 1, #node do
                serialize(node[i], level)
            end
        end
    end
    serialize(node, 0)
    return io.type(buf) and true or tostring(buf)
end

return to_html
