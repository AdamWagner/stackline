local M = {}

function M.equal(a, b)
    if #a ~= #b then return false end
    for i, _ in ipairs(a) do
        if b[i] ~= a[i] then
            return false
        end
    end

    return true
end

function M.greaterThan(n)
    return function(t)
        return #t > n
    end
end

function M.isEqual(a, b)
    --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
    --]]

    local function isEqualTable(t1, t2)
        if t1 == t2 then return true end

        for k, _ in pairs(t1) do
            if type(t1[k]) ~= type(t2[k]) then return false end
            if type(t1[k]) == "table" then
                if not isEqualTable(t1[k], t2[k]) then return false end
            else
                if t1[k] ~= t2[k] then return false end
            end
        end

        for k, _ in pairs(t2) do
            if type(t2[k]) ~= type(t1[k]) then return false end
            if type(t2[k]) == "table" then
                if not isEqualTable(t2[k], t1[k]) then return false end
            else
                if t2[k] ~= t1[k] then return false end
            end
        end
        return true
    end

    if type(a) ~= type(b) then return false end
    if type(a) == "table" then return isEqualTable(a, b) else return (a == b) end

end


function M.same(a, b)
    --- Checks if two tables are the same. It compares if both tables features the
    --same values, but not necessarily at the same keys.
  local u = require 'lib.utils'
  return u.all(a, function(v) return u.include(b,v) end)
                and u.all(b, function(v) return u.include(a,v) end)
end


function M.deepEqual(a, b)
    local u = require 'lib.utils'
    if u.isSortable(a) then table.sort(a) end
    if u.isSortable(b) then table.sort(b) end

    if type(a) ~= type(b) then
        local message = ("{1} is of type %s, but {2} is of type %s"):format(type(a), type(b))
        return false, message
    end


    if u.istable(a) and u.istable(b) and #a == #b then
        if M.same(a,b) then return true end
    end

    if type(a) == "table" then
        local visitedKeys = {}

        for key, value in pairs(a) do
            visitedKeys[key] = true

            local success, innerMessage = M.deepEqual(value, b[key])
            if not success then
                local message = innerMessage:gsub("{1}", ("{1}[%s]"):format(tostring(key))):gsub(
                    "{2}", ("{2}[%s]"):format(tostring(key)))

                return false, message
            end
        end

        for key, value in pairs(b) do
            if not visitedKeys[key] then
                local success, innerMessage = M.deepEqual(value, a[key])

                if not success then
                    local message = innerMessage:gsub("{1}", ("{1}[%s]"):format(tostring(key)))
                        :gsub("{2}", ("{2}[%s]"):format(tostring(key)))

                    return false, message
                end
            end
        end

        return true
    end

    if a == b then
        return true
    end

    local message = "{1} ~= {2}"
    return false, message
end

return M
