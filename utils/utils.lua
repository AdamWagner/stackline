utils = {}

utils.map = hs.fnutils.map
utils.concat = hs.fnutils.concat
utils.each = hs.fnutils.each

utils.filter = function(t, f)
    local out = {}
    for k, v in pairs(t) do
        if (f(k, v)) then
            out[k] = v
        end
    end
    return out
end

function utils.keyBind(hyper, keyFuncTable)
    for key, fn in pairs(keyFuncTable) do
        hs.hotkey.bind(hyper, key, fn)
    end
end

utils.length = function(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

utils.indexOf = function(t, object)
    if type(t) ~= "table" then
        error("table expected, got " .. type(t), 2)
    end

    for i, v in pairs(t) do
        if object == v then
            return i
        end
    end
end

--[[
This function takes 2 values as input and returns true if they are equal
and false if not. a and b can numbers, strings, booleans, tables and nil.
--]]
function utils.isEqual(a, b)

    local function isEqualTable(t1, t2)

        if t1 == t2 then
            return true
        end

        -- luacheck: ignore
        for k, v in pairs(t1) do

            if type(t1[k]) ~= type(t2[k]) then
                return false
            end

            if type(t1[k]) == "table" then
                if not isEqualTable(t1[k], t2[k]) then
                    return false
                end
            else
                if t1[k] ~= t2[k] then
                    return false
                end
            end
        end

        for k, v in pairs(t2) do

            if type(t2[k]) ~= type(t1[k]) then
                return false
            end

            if type(t2[k]) == "table" then
                if not isEqualTable(t2[k], t1[k]) then
                    return false
                end
            else
                if t2[k] ~= t1[k] then
                    return false
                end
            end
        end

        return true
    end

    if type(a) ~= type(b) then
        return false
    end

    if type(a) == "table" then
        return isEqualTable(a, b)
    else
        return (a == b)
    end

end

-- Functions stolen from lume.lua
-- (I should probably just use the library itself)
-- https://github.com/rxi/lume/blob/master/lume.lua
function utils.isarray(x)
    return type(x) == "table" and x[1] ~= nil
end

local getiter = function(x)
    if utils.isarray(x) then
        return ipairs
    elseif type(x) == "table" then
        return pairs
    end
    error("expected table", 3)
end
function utils.invert(t)
    local rtn = {}
    for k, v in pairs(t) do
        rtn[v] = k
    end
    return rtn
end
function utils.keys(t)
    local rtn = {}
    local iter = getiter(t)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end

function utils.find(t, value)
    local iter = getiter(t)
    result = nil
    for k, v in iter(t) do
        print('value looking for')
        print(value)
        print('key matching against')
        print(k)
        print('are they equal?')
        print(k == value)
        if k == value then
            result = v
        end
    end
    utils.pheader('result')
    print(result)
    return result
end
-- END lume.lua pillaging

--- Check if a row matches the specified key constraints.
-- @param row The row to check
-- @param key_constraints The key constraints to apply
-- @return A boolean result
local function filter_row(row, key_constraints)
    -- Loop through all constraints
    for k, v in pairs(key_constraints) do
        if v and not row[k] then
            -- The row is missing the key entirely,
            -- definitely not a match
            return false
        end

        -- Wrap the key and constraint values in arrays,
        -- if they're not arrays already (so we can loop through them)
        local actual_values = type(row[k]) == "table" and row[k] or {row[k]}
        local required_values = type(v) == "table" and v or {v}

        -- Loop through the values we *need* to find
        for i = 1, #required_values do
            local found
            -- Loop through the values actually present
            for j = 1, #actual_values do
                if actual_values[j] == required_values[i] then
                    -- This object has the required value somewhere in the key,
                    -- no need to look any farther
                    found = true
                    break
                end
            end

            if not found then
                return false
            end
        end
    end

    return true
end

--- Filter an array, returning entries matching `key_values`.
-- @param input The array to process
-- @param key_values A table of keys mapped to their viable values
-- @return An array of matches
function utils.pick(input, key_values)
    local result = {}
    utils.each(key_values, function(k)
        result[k] = input[k]
    end)
    return result
end

local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next

function utils.print_r(root)
    local cache = {[root] = "."}
    local function _dump(t, space, name)
        local temp = {}
        tinsert(temp, "\n")
        for k, v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                tinsert(temp, "+" .. key .. " {" .. cache[v] .. "}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                tinsert(temp, "+" .. key ..
                            _dump(v, space .. (next(t, k) and "|" or " ") ..
                                      srep(" ", #key), new_key))
            else
                tinsert(temp, "+" .. key .. " [" .. tostring(v) .. "]")
            end
        end
        return tconcat(temp, "\n" .. space)
    end
    print(_dump(root, "", ""))
end

--- Recursively print out a Lua value.
-- @param value The value to print
-- @param indent Indentation level (defaults to 0)
-- @param no_newline If true, won't print a newline at the end
function utils.deep_print(value, indent, no_newline)
    indent = indent or 0

    if type(value) == "table" then
        print("{")
        for k, v in pairs(value) do
            io.write(string.rep(" ", indent + 2) .. "[")
            deep_print(k, indent + 2, true)
            io.write("] = ")
            deep_print(v, indent + 2, true)
            print(";")
        end
        io.write(string.rep(" ", indent) .. "}")
    elseif type(value) == "string" then
        io.write(("%q"):format(value))
    else
        io.write(tostring(value))
    end

    if not no_newline then
        print()
    end
end

function utils.p(...)
    -- Auto-inspect non-string values when printing for debugging:
    -- Example 1:
    --    p('# to be cleaned: ', table.length(self.tabStacks))
    --    -> "# to be cleaned:  2"
    -- Example 2:
    --    p('keys be cleaned: ', table.keys(self.tabStacks)) 
    --    -> "keys be cleaned: 	{ "6207671375", "63771631066207041183" }"

    result = {}

    -- How to handle variable arguments
    -- https://www.lua.org/pil/5.2.html
    for i = 1, select("#", ...) do
        local x = select(i, ...)
        if type(x) == 'string' then
            table.insert(result, x)
        else
            table.insert(result, hs.inspect(x))
        end
    end
    print(table.unpack(result), '\n')
end

function utils.pdivider(str)
    str = string.upper(str) or ""
    print("=========", str, "==========")
end

function utils.pheader(str)
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
end

return utils
