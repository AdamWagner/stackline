local M = {}

local fnutils = hs and hs.fnutils or require 'hs.fnutils'
fnutils.any = fnutils.some

for k,v in pairs(fnutils) do
    M[k] = v
end

-- collection building blocks
function M.iter(list_or_iter)
    if type(list_or_iter) == "function" then
        return list_or_iter
    end

    return coroutine.wrap(function()
        for i = 1, #list_or_iter do
            coroutine.yield(list_or_iter[i])
        end
    end)
end

function M.extract(list, comp, transform, ...)
    -- from moses.lua
    -- extracts value from a list
    transform = transform or M.identity
    local _ans
    for _, v in pairs(list) do
        if not _ans then
            _ans = transform(v, ...)
        else
            local val = transform(v, ...)
            _ans = comp(_ans, val) and _ans or val
        end
    end
    return _ans
end

local getiter = function(x)

    if u.isarray(x) then
        return ipairs
    elseif type(x) == "table" then
        return pairs
    end
    error("expected table", 3)
end

-- Compute
function M.len(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- get / set
function M.setfield(f, v, t)
    t = t or _G -- start with the table of globals
    for w, d in string.gmatch(f, "([%w_]+)(.?)") do
        if d == "." then -- not last field?
            t[w] = t[w] or {} -- create table if absent
            t = t[w]          -- get the table
        else -- last field
            t[w] = v -- do the assignment
        end
    end
end

function M.getfield(f, t, isSafe)
    local v = t or _G -- start with the table of globals
    local res = nil

    for w in string.gmatch(f, "[%w_]+") do
        if type(v) ~= 'table' then return v end -- if v isn't table, return immediately
        v = v[w]                                -- lookup next val
        if v ~= nil then res = v end            -- only update safe result if v not null
    end

    if isSafe then -- return the last non-nil value found
        if v ~= nil then return v else return res end
    else
        return v -- return the last value found regardless
    end

end

-- Find
function M.keys(t)

    -- print('printing M')
    -- u.p(_G.utils)

    local rtn = {}
    local iter = getiter(t)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end

function M.values(t)
    local values = {}
    for _, v in pairs(t) do
        values[#values + 1] = v
    end
    return values
end

function M.find(t, value)
    local iter = getiter(t)
    result = nil
    for k, v in iter(t) do
        if k == value then
            result = v
        end
    end
    return result
end

function M.include(list, value)
    for i in M.iter(list) do
        if i == value then
            return true
        end
    end
    return false
end

-- Filtering
function M.any(list, func)
    for i in M.iter(list) do
        if func(i) then
            return true
        end
    end
    return false
end

function M.all(vs, fn)
    for _, v in pairs(vs) do
        if not fn(v) then
            return false
        end
    end
    return true
end
M.every = M.all


-- Transform
function M.zip(a, b)
    local rv = {}
    local idx = 1
    local len = math.min(#a, #b)
    while idx <= len do
        rv[idx] = {a[idx], b[idx]}
        idx = idx + 1
    end
    return rv
end

function M.extend(destination, source)
    for k, v in pairs(source) do
        destination[k] = v
    end
    return destination
end

function M.invert(t)
    local rtn = {}
    for k, v in pairs(t) do
        rtn[v] = k
    end
    return rtn
end

return M
