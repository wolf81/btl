local M = {}

function M.split(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch('(.-)'..delimiter) do
        table.insert(result, match)
    end
    return result
end

function M.getNormalizedPath(...)
    local parts = {...}

    local components = {}
    for _, part in ipairs(parts) do
        local segments = M.split(part, '/')
        for _, segment in ipairs(segments) do
            if segment == '..' then
                table.remove(components)
            elseif segment ~= '.' and segment ~= '' then
                table.insert(components, segment)
            end
        end
    end

    return table.concat(components, '/')
end

function M.hexToColor(hex)
    local _, _, a, r, g, b = hex:find('#(%x%x)(%x%x)(%x%x)(%x%x)')
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16) }
end

function M.getDirectory(file_path)
    return file_path:match('(.*[/\\])')
end

return M
