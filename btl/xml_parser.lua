--[[
-- Based on LUA-based XmlParser from Alexander Makeev
-- source: http://lua-users.org/wiki/LuaXml
--]]

local M = {}

local function toXmlString(value)
    value = string.gsub(value, '&', '&amp;')      -- '&'  → "&amp;"
    value = string.gsub(value, '<', '&lt;')       -- '<'  → "&lt;"
    value = string.gsub(value, '>', '&gt;')       -- '>'  → "&gt;"
    value = string.gsub(value, '"', '&quot;')     -- '"'  → "&quot;"
    --value = string.gsub (value, '\'', "&apos;") -- '\'' → "&apos;"
    -- replace non printable char                 --      → "&#xD;"
    value = string.gsub(value, '([^%w%&%;%p%\t% ])',
        function (c) 
            return string.format('&#x%X;', string.byte(c)) 
            --return string.format("&#x%02X;", string.byte(c)) 
            --return string.format("&#%02d;", string.byte(c)) 
        end)
    return value
end

local function fromXmlString(value)
    value = string.gsub(value, '&#x([%x]+)%;',
        function(h) 
            return string.char(tonumber(h, 16)) 
        end)
    value = string.gsub(value, '&#([0-9]+)%;',
        function(h) 
            return string.char(tonumber(h, 10)) 
        end)
    value = string.gsub(value, '&quot;', '"')
    value = string.gsub(value, '&apos;', '\'')
    value = string.gsub(value, '&gt;',   '>')
    value = string.gsub(value, '&lt;',   '<')
    value = string.gsub(value, '&amp;',  '&')
    return value
end
   
local function parseArgs(s)
    local arg = {}
    string.gsub(s, '(%w+)=(["\'])(.-)%2', function (w, _, a)
        arg[w] = fromXmlString(a)
    end)
    return arg
end

M.parseXmlString = function(xml_string)
    local stack = {}
    local top = {
        name = nil,
        value = nil,
        attributes = {},
        children = {},
    }
    table.insert(stack, top)
    local ni,c,label,xarg, empty
    local i, j = 1, 1
    while true do
        ni,j,c,label,xarg, empty = string.find(xml_string, '<(%/?)([%w:]+)(.-)(%/?)>', i)
        if not ni then break end
        local text = string.sub(xml_string, i, ni - 1)
        
        if not string.find(text, '^%s*$') then
            top.value = (top.value or '') .. fromXmlString(text)
        end
        
        if empty == '/' then  -- empty element tag
            table.insert(top.children, {
                name = label,
                value = nil,
                attributes = parseArgs(xarg),
                children = {},
            })
        elseif c == '' then   -- start tag
            top = {
                name = label, 
                value = nil, 
                attributes = parseArgs(xarg), 
                children = {},
            }
            table.insert(stack, top)   -- new level
        else  -- end tag
            local to_close = table.remove(stack)  -- remove top
            top = stack[#stack]
            if #stack < 1 then
                error('XmlParser: nothing to close with ' .. label)
            end

            if to_close.name ~= label then
                error('XmlParser: trying to close ' .. to_close.name .. ' with ' .. label)
            end

            table.insert(top.children, to_close)
        end

        i = j + 1
    end

    local text = string.sub(xml_string, i)    
    if not string.find(text, '^%s*$') then
        stack[#stack].value = (stack[#stack].value or '') .. fromXmlString(text)
    end

    if #stack > 1 then
        error('XmlParser: unclosed ' .. stack[stack.n].name)
    end

    return stack[1].children[1]
end

function M.parseXmlFile(xml_path)
    local file, err = io.open(xml_path, 'r');
    if (not err) then
        local xml_string = file:read('*a') -- read file content
        io.close(file)
        return M.parseXmlString(xml_string), nil
    else
        return nil, err
    end
end

return M
