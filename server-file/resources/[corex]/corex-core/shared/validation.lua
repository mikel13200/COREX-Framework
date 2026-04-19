--[[
    COREX Framework - Validation Helpers
    Safety and validation utility functions
]]

COREX = COREX or {}
COREX.Validate = {}

---Check if value is a number
---@param val any
---@return boolean
function COREX.Validate.IsNumber(val)
    return type(val) == 'number'
end

---Check if value is a string
---@param val any
---@return boolean
function COREX.Validate.IsString(val)
    return type(val) == 'string'
end

---Check if value is a table
---@param val any
---@return boolean
function COREX.Validate.IsTable(val)
    return type(val) == 'table'
end

---Check if value is a function
---@param val any
---@return boolean
function COREX.Validate.IsFunction(val)
    return type(val) == 'function'
end

---Check if value is a boolean
---@param val any
---@return boolean
function COREX.Validate.IsBoolean(val)
    return type(val) == 'boolean'
end

---Check if value is nil
---@param val any
---@return boolean
function COREX.Validate.IsNil(val)
    return val == nil
end

---Check if value exists (not nil)
---@param val any
---@return boolean
function COREX.Validate.Exists(val)
    return val ~= nil
end

---Check if number is within range (inclusive)
---@param val number
---@param min number
---@param max number
---@return boolean
function COREX.Validate.InRange(val, min, max)
    if type(val) ~= 'number' then return false end
    return val >= min and val <= max
end

---Check if string is not empty
---@param val any
---@return boolean
function COREX.Validate.NotEmpty(val)
    if type(val) == 'string' then
        return val ~= '' and val:match('%S') ~= nil
    elseif type(val) == 'table' then
        return next(val) ~= nil
    end
    return val ~= nil
end

---Check if value is a positive number
---@param val any
---@return boolean
function COREX.Validate.IsPositive(val)
    return type(val) == 'number' and val > 0
end

---Check if value is a valid player source
---@param source any
---@return boolean
function COREX.Validate.IsValidSource(source)
    if type(source) ~= 'number' then return false end
    return source > 0
end

---Check if string matches pattern
---@param val string
---@param pattern string
---@return boolean
function COREX.Validate.Matches(val, pattern)
    if type(val) ~= 'string' then return false end
    return string.match(val, pattern) ~= nil
end

---Ensure value is within range, clamp if necessary
---@param val number
---@param min number
---@param max number
---@return number
function COREX.Validate.Clamp(val, min, max)
    if type(val) ~= 'number' then return min end
    return math.max(min, math.min(max, val))
end

---Validate and sanitize string (remove dangerous characters)
---@param val string
---@return string
function COREX.Validate.SanitizeString(val)
    if type(val) ~= 'string' then return '' end
    -- Remove potential script injection characters
    return val:gsub('[<>\"\'\\]', '')
end

---Assert condition and return error message if failed
---@param condition boolean
---@param errorMsg string
---@return boolean, string|nil
function COREX.Validate.Assert(condition, errorMsg)
    if not condition then
        return false, errorMsg or 'Validation failed'
    end
    return true, nil
end
