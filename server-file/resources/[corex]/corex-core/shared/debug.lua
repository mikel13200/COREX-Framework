COREX = COREX or {}
COREX.Debug = {}

local LOG_LEVELS = {
    [1] = {name = 'ERROR',   color = '^1'},
    [2] = {name = 'WARNING', color = '^3'},
    [3] = {name = 'INFO',    color = '^5'},
    [4] = {name = 'VERBOSE', color = '^7'}
}

function COREX.Debug.Print(...)
    if not Config.Debug then return end
    print(...)
end

function COREX.Debug.Log(level, msg)
    if not Config.Debug then return end
    local levelInfo = LOG_LEVELS[level] or LOG_LEVELS[3]
    local timestamp = IsDuplicityVersion() and os.date('%H:%M:%S') or ''
    if timestamp ~= '' then
        print(string.format('%s[%s] [%s]^7 %s', levelInfo.color, timestamp, levelInfo.name, msg))
    else
        print(string.format('%s[%s]^7 %s', levelInfo.color, levelInfo.name, msg))
    end
end

function COREX.Debug.Error(msg)
    COREX.Debug.Log(1, msg)
end

function COREX.Debug.Warning(msg)
    COREX.Debug.Log(2, msg)
end

function COREX.Debug.Warn(msg)
    COREX.Debug.Warning(msg)
end

function COREX.Debug.Info(msg)
    COREX.Debug.Log(3, msg)
end

function COREX.Debug.Verbose(msg)
    COREX.Debug.Log(4, msg)
end



function COREX.Debug.Dump(tbl, indent, visited)
    if not Config.Debug then return '' end
    indent = indent or 0
    visited = visited or {}

    local indentStr = string.rep('  ', indent)

    if type(tbl) ~= 'table' then
        local output = indentStr .. tostring(tbl)
        if indent == 0 then print(output) end
        return output
    end

    if visited[tbl] then
        local output = indentStr .. '<circular reference>'
        if indent == 0 then print(output) end
        return output
    end
    visited[tbl] = true

    local result = {}
    for k, v in pairs(tbl) do
        local key = type(k) == 'string' and ('["' .. k .. '"]') or ('[' .. k .. ']')
        if type(v) == 'table' then
            table.insert(result, indentStr .. key .. ' = {')
            table.insert(result, COREX.Debug.Dump(v, indent + 1, visited))
            table.insert(result, indentStr .. '}')
        elseif type(v) == 'string' then
            table.insert(result, indentStr .. key .. ' = "' .. v .. '"')
        else
            table.insert(result, indentStr .. key .. ' = ' .. tostring(v))
        end
    end

    visited[tbl] = nil

    local output = table.concat(result, '\n')
    if indent == 0 then print(output) end
    return output
end

