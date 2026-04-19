COREX = COREX or {}
Corex = COREX
COREX.Utils = {}

math.randomseed(os.time() * 1000 + (GetGameTimer and GetGameTimer() or 0))

function COREX.Utils.DeepCopy(tbl, visited)
    if type(tbl) ~= 'table' then return tbl end
    visited = visited or {}
    if visited[tbl] then return visited[tbl] end
    local copy = {}
    visited[tbl] = copy
    for k, v in pairs(tbl) do
        copy[COREX.Utils.DeepCopy(k, visited)] = COREX.Utils.DeepCopy(v, visited)
    end
    return setmetatable(copy, getmetatable(tbl))
end

function COREX.Utils.TableContains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function COREX.Utils.MergeConfig(defaults, overrides)
    local result = COREX.Utils.DeepCopy(defaults)
    if type(overrides) ~= 'table' then return result end
    for k, v in pairs(overrides) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = COREX.Utils.MergeConfig(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

function COREX.Utils.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

function COREX.Utils.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function COREX.Utils.TableLength(tbl)
    local count = 0
    if type(tbl) == 'table' then
        for _ in pairs(tbl) do count = count + 1 end
    end
    return count
end

function COREX.Utils.SafeGet(tbl, ...)
    local keys = {...}
    local current = tbl
    for _, key in ipairs(keys) do
        if type(current) ~= 'table' then return nil end
        current = current[key]
    end
    return current
end

function COREX.Utils.FormatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function COREX.Utils.Wait(ms)
    Wait(ms)
end

function COREX.Utils.GetDistance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function COREX.Utils.GetDistanceVec(vec1, vec2)
    return #(vec1 - vec2)
end

function COREX.Utils.IsFinite(val)
    return type(val) == 'number' and val == val and val ~= math.huge and val ~= -math.huge
end
