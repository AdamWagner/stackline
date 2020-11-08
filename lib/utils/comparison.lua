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

return M
