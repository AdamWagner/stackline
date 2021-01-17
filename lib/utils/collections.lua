-- INSPO
--  - https://github.com/lunarmodules/Penlight/blob/master/lua/pl/tablex.lua
--  - https://github.com/lunarmodules/Penlight/blob/master/lua/pl/List.lua
--  - https://github.com/lunarmodules/Penlight/blob/master/lua/pl/Map.lua
--  - https://github.com/DoooReyn/LuaHashMap/blob/master/map.lua
--  - https://github.com/kurapica/PLoop
--  - https://github.com/renatomaia/loop-collections/tree/master/lua/loop/collection
--  - https://github.com/jeblad/LuaCollections/tree/master/includes/LuaLibrary/lua/pure
--  - https://github.com/Billiam/enumerable.lua


local check = require 'lib.utils.typecheck'.scheck

-- local helper fns ------------------------------------------------------------

local function indexByEquality(self, x)   -- {{{
  for k,v in pairs(self) do
    if k == x then
      return v
    end
  end
end  -- }}}

local flip = require 'lib.utils.functions'.flip
local curry = require 'lib.utils.functions'.curry
local pipe = require 'lib.utils.functions'.pipe

-- Collections utils
-- ———————————————————————————————————————————————————————————————————————————
local M = {}


local primatives = {
  'number',
  'table',
  'string',
  'boolean',
  'function',
  'userdata',
  'thread',
}

function M.identity(x)  -- {{{
  return x
end  -- }}}

function M.getiter(x) -- {{{
  -- Dynamically determine whether to use ipairs or pairs based on the provided table
  -- USAGE NOTE: How to check which fn was returned from the outside:
  --    local fn = u.getiter(tbl)
  --    local iteratorType = fn == ipairs and 'pairs' or 'pairs'
  local u = require 'lib.utils.types'
  if u.is_array(x) then return ipairs
  elseif u.is_table(x) then return pairs end
  error("expected table", 3)
end  -- }}}

function M.iter(x) -- {{{
  return M.getiter(x)(x)
end  -- }}}

-- copy all hs.fnutils functions to this module
local fnutils = hs and hs.fnutils or require 'hs.fnutils'
fnutils.any = fnutils.some

for k,v in pairs(fnutils) do
  M[k] = v -- add the vanilla fnutils method
  M['_'..k] = curry(flip(v)) -- alt version: curry & flip args for easy piping (like Ramda.js)
end


function makeMapper(iter)-- {{{
  local iterator = (iter==pairs or iter==ipairs)
    and iter -- use given iterator if either 'pairs' or 'ipairs'
    or pairs -- otherwise, fallback to 'pairs'

  return function(t, f)
    -- From moses.lua
    -- fnutils.map only uses the 1st return value from mapper fn
    -- NOTE: end key as 2nd return value to map both values *and* keys
    local _t = {}
    for idx,val in iterator(t) do
      local i, kv, v = idx, f(val, idx)
      _t[v and kv or i] = v or kv
    end
    return _t
  end
end-- }}}

-- CAUTION! Keep an eye on this — could cause some sneaky bugs.
-- Tweak map to accept a list of fns
-- and automatically send through pipe.
function M.map(tbl, ...)
  local mapper = makeMapper(pairs)
  if #{...} > 1 then   -- if multiple fns give, use pipe
    return mapper(tbl, u.pipe(...))
  else -- otherwise run given fn on each member
    return mapper(tbl, ...)
  end
end

function M.mapi(tbl, ...)
  local mapper = makeMapper(ipairs)

  local fns = #{...} > 1
    and u.pipe(...)   -- if multiple fns give, use pipe
    or select(1, ...) -- otherwise run given fn on each member

  return mapper(tbl, fns)
end


function M.detect(t, value)  -- {{{
  local equal = require 'lib.utils.comparison'.deepEqual
  local _iter = (type(value) == 'function') and value or equal
  for key,arg in pairs(t) do
    if _iter(arg,value) then return key end
  end
end  -- }}}

function M.select(t, f)  -- {{{
  --- Selects and returns values passing an iterator test.
  -- <br/><em>Aliased as `filter`</em>.
  -- @name select
  -- @param t a table
  -- @param f an iterator function, prototyped as `f (v, k)`
  -- @return the selected values
  -- @see reject
  local _t = {}
  for index,value in pairs(t) do
    if f(value,index) then _t[#_t+1] = value end
  end
  return _t
end  -- }}}

function M.where(t, props)  -- {{{
  --[[
    Filter list of tables by providing key=val pairs that must match.
    E.g.,
    x = {
      { name = 'billy',   age = 33, sex = 'male' },
      { name = 'bob',     age = 33, sex = 'male' },
      { name = 'thorton', age = 22, sex = 'female' }
    }
    r = M.findWhere(x, {sex = 'male'})
    → {
      { name = 'billy',   age = 33, sex = 'male' },
      { name = 'bob',     age = 33, sex = 'male' },
    }
  --]]
  local r = M.select(t, function(v)
    for key in pairs(props) do
      if v[key] ~= props[key] then return false end
    end
    return true
  end)
  return #r > 0 and r or nil
end  -- }}}

function M.findWhere(t, props)  -- {{{
  -- FROM: https://github.com/Yonaba/Moses/blob/master/moses.lua#L582
  --[[
    Get just the FIRST element matching key=val pairs
    in a list of tables.
    E.g.,
    x = {
      { name = 'billy',   age = 33, sex = 'male' },
      { name = 'bob',     age = 33, sex = 'male' },
      { name = 'thorton', age = 22, sex = 'female' }
    }
    r = M.findWhere(x, {sex = 'male'})
    → {
      { name = 'billy',   age = 33, sex = 'male' },
    }
  --]]
  local index = M.detect(t, function(v)
    print('V:', hs.inspect(v))
    for key in pairs(props) do
      if props[key] ~= v[key] then return false end
    end
    return true
  end)
  return index and t[index]
end  -- }}}

function M.reject(xs, y)  -- {{{
  return M.filter(xs, function(x) return y ~= x end)
end  -- }}}

-- building blocks -------------------------------------------------------------
function M.len(t)  -- {{{
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end  -- }}}

function M.setfield(path, val, tbl)  -- {{{
  tbl = tbl or _G
  for part, sep in path:gmatch("([%w_]+)(.?)") do
    if sep == "." then   -- not last field?
      tbl[part] = tbl[part] or {}   -- create table if absent
      tbl = tbl[part]               -- get the table
    else   -- last field
      tbl[part] = val   -- do the assignment
    end
  end
end  -- }}}

function M.getfield(path, tbl, opts)  -- {{{
  tbl = tbl or _G
  opts = opts or {}
  local res = nil

  for part in path:gmatch("[%w_]+") do
    if type(tbl) ~= 'table' then return tbl end  -- if v isn't table, return immediately
    tbl = tbl[part]                              -- lookup next val
    if tbl ~= nil then res = tbl end             -- only update safe result if v not null
  end

  if opts.lastNonNil then   -- return the last non-nil value found
    return tbl ~=nil and tbl or res
  else
    return tbl   -- return the last value found regardless
  end
end  -- }}}

-- find ------------------------------------------------------------------------
function M.keys(t)  -- {{{
  local rtn = {}
  for k in M.iter(t) do
    rtn[#rtn + 1] = k
  end
  return rtn
end  -- }}}

function M.values(t)  -- {{{
  if type(t)~='table' then return {} end
  local values = {}
  for _, v in pairs(t) do
    values[#values + 1] = v
  end
  return values
end  -- }}}

function M.find(t, value)  -- {{{
  result = nil
  for k, v in M.iter(t) do
    if k == value then
      result = v
    end
  end
  return result
end  -- }}}

function M.filterType(tbl, _type, _depth)  -- {{{
  check('table,string,?number,?table')

  assert(tbl, "you must provide tbl to filterType")
  assert(_type, "you must provide an expected type to filterType")

  -- TODO: local opts = _opts or {} -- opts for metatable, and keep/reject/action
  local depth = _depth or 20
  local currDepth = 0
  local res = {}

  -- TODO: local action = opts.action or table._insert

  local function getType(val)
    currDepth = currDepth + 1
    for _,v in pairs(val) do
      local typ = type(v)
      if typ==_type then
	res[#res+1] = v
      end
       if typ=='table' and (currDepth <= depth) then
	getType(v)
      end
    end
  end
  getType(tbl) -- get the recursion party started
  return res
end  -- }}}

function M.include(t, search)  -- {{{ supports nested tables
  local testFn = u.is_function(search)
    and search     -- if search is a fn, use it as our testFn
    or u.deepEqual -- otherwise fallback to deepEqual

  -- return true the first time it's found
  for _,v in M.iter(t) do
    if testFn(v, search) then return true end
  end

  return false
end

M.includes = M.include
M.contains = M.include
-- }}}

-- filter ----------------------------------------------------------------------
function M.any(t, fn) -- {{{
  -- NOTE: changed from M.iter(t) to _,v in pairs(t) on 2020-11-21
  -- NOTE: changed back to M.iter on 2020-12-22
  for _, v in M.iter(t) do
    if fn(v) then return true end
  end
  return false
end -- }}}

function M.all(t, fn)  -- {{{
  if not u.is_table(t) then return false end
  for k, v in M.iter(t) do
    if not fn(v, k) then return false end
  end
  return true
end
M.every = M.all
-- }}}

M.none = function(vs, fn)  -- {{{
  return not M.all(vs, fn)
end  -- }}}

function M.intersection(...)  -- {{{
  local arg = {...}
  local array = arg[1]
  table.remove(arg, 1)
  local res = {}
  for i,value in ipairs(array) do
    if M.all(arg,function(v) return M.include(v,value) end) then
    res[#res+1] = value
  end
end
return res
end  -- }}}

function M.uniq(tbl)  -- {{{
  local mt = { __index = indexByEquality } -- Ensure that __eq metamethods are used when looking up 'seen' keys
  local seen = setmetatable({}, mt)        -- set mt

  local res = {}
  for _, v in ipairs(tbl) do
    if not seen[v] then
      seen[v] = true
      res[#res + 1] = v
    end
  end
  return result
end  -- }}}

-- transform -------------------------------------------------------------------
function M.pluck(t, key)  -- {{{
  local _t = {}
  for k, v in pairs(t) do
    if v[key] then _t[#_t+1] = v[key] end
  end
  return _t
end  -- }}}

function M.pick(obj, ...)  -- {{{
  local whitelist = table.flatten {...}
  local _picked = {}
  for key, property in M.iter(whitelist) do
    if (obj[property])~=nil then
      _picked[property] = obj[property]
    end
  end
  return _picked
end  -- }}}

function M.omit(obj, ...)  -- {{{
  local blocklist = M.flatten {...}
  local _picked = {}
  for key, value in M.iter(obj) do
    if not M.include(blocklist,key) then
      _picked[key] = value
    end
  end
  return _picked
end  -- }}}

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

function M.extend(dst, src)  -- {{{
  for k, v in M.iter(src) do
    dst[k] = v
  end
  return dst
end  -- }}}

function M.invert(t)  -- {{{
  local rtn = {}
  for k, v in pairs(t) do
    rtn[v] = k
  end
  return rtn
end  -- }}}

M.unnest = pipe(
  M.values, -- doesn't work if key,value pairs, and usually we care about counting the values
  table.unpack,
  table.merge
)

function M.flatten(tbl, depth, currDepth)  -- {{{
  local u = require 'lib.utils.types'
  local insert = table.insert
  local istab = u.is_table
  depth = depth or 100
  currDepth = currDepth or 0

  local function flatten(res, vs)
    for k,v in M.iter(vs) do
      if istab(v) then flatten(res, v)
      else insert(res, k, v) end
    end
    return res
  end

  local result = flatten({}, tbl)   -- generate draft result

  return table.len(result) > 1
    and result                      -- if result has length, return result
    or M.unnest(tbl)                -- otherwise, fall back to unnest() instead
end  -- }}}

return M
