
-- local helper fns
local getiter = function(x)  -- {{{
  local function isarray(x)
        -- NOTE: this duplicates functionality in utils > types, but needs to be
        -- defined here to avoid circular reference / stack overflow
        -- TODO: find a better way to handle this (?)
    return type(x) == 'table' and x[1] ~= nil
  end
  if isarray(x) then
    return ipairs
  elseif type(x) == "table" then
    return pairs
  end
  error("expected table", 3)
end  -- }}}

-- Collections utils
-- ———————————————————————————————————————————————————————————————————————————
local M = {}

-- copy all hs.fnutils functions to this module
local fnutils = hs and hs.fnutils or require 'hs.fnutils'  -- {{{
fnutils.any = fnutils.some
for k,v in pairs(fnutils) do
    M[k] = v
end
  -- }}}

-- measure
function M.len(t)  -- {{{
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end  -- }}}

-- get / set
function M.setfield(f, v, t)  -- {{{
    t = t or _G   -- start with the table of globals
    for w, d in string.gmatch(f, "([%w_]+)(.?)") do
        if d == "." then   -- not last field?
            t[w] = t[w] or {}   -- create table if absent
            t = t[w]            -- get the table
        else   -- last field
            t[w] = v   -- do the assignment
        end
    end
end  -- }}}

function M.getfield(f, t, isSafe)  -- {{{
    local v = t or _G   -- start with the table of globals
    local res = nil

    for w in string.gmatch(f, "[%w_]+") do
        if type(v) ~= 'table' then return v end   -- if v isn't table, return immediately
        v = v[w]                                  -- lookup next val
        if v ~= nil then res = v end              -- only update safe result if v not null
    end

    if isSafe then   -- return the last non-nil value found
        if v ~= nil then return v else return res end
    else
        return v   -- return the last value found regardless
    end
end  -- }}}

-- find
function M.keys(t)  -- {{{
    local rtn = {}
    local iter = getiter(t)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end  -- }}}

function M.values(t)  -- {{{
    local values = {}
    for _, v in pairs(t) do
        values[#values + 1] = v
    end
    return values
end  -- }}}

function M.find(t, value)  -- {{{
    local iter = getiter(t)
    result = nil
    for k, v in iter(t) do
        if k == value then
            result = v
        end
    end
    return result
end  -- }}}

function M.include(t, value)  -- {{{
    -- supports nested tables
  local u = require 'lib.utils'
  local _iter = (type(value) == 'function') and value or u.deepEqual
  for k,v in pairs(t) do
    if _iter(v,value) then return true end
  end
  return false
end
M.includes = M.include
M.contains = M.include
-- }}}

-- filter
function M.any(list, func)  -- {{{
    for i in M.iter(list) do
        if func(i) then
            return true
        end
    end
    return false
end  -- }}}

function M.all(vs, fn)  -- {{{
    for _, v in pairs(vs) do
        if not fn(v) then
            return false
        end
    end
    return true
end
M.every = M.all
-- }}}

M.none = function(vs, fn)  -- {{{
    return not M.all(vs, fn)
end  -- }}}

-- transform
function M.zip(a, b)  -- {{{
    local rv = {}
    local idx = 1
    local len = math.min(#a, #b)
    while idx <= len do
        rv[idx] = {a[idx], b[idx]}
        idx = idx + 1
    end
    return rv
end  -- }}}

function M.extend(destination, source)  -- {{{
    for k, v in pairs(source) do
        destination[k] = v
    end
    return destination
end  -- }}}

function M.invert(t)  -- {{{
    local rtn = {}
    for k, v in pairs(t) do
        rtn[v] = k
    end
    return rtn
end  -- }}}

return M
