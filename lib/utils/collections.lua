local fns = hs.fnutils
local bind = require 'lib.utils.functional'.bind
local rearg = require 'lib.utils.functional'.rearg
local is = require 'lib.utils.types'.is

-- INSPO: Python-like dict() and list() objects: github.com/sentrip/AutoTouchPlus/blob/master/src/objects.lua
--        Tests for ↑ https://github.com/sentrip/AutoTouchPlus/blob/master/tests/test_objects.lua

local M = {}

--[[ 
== Alias hs.fns methods ==
  These fns aren't used because they don't meet my needs as-is.
  M.each         = fns.each
  u.map          = fns.map
  u.filter       = fns.filter
  u.contains     = fns.Contains
]]
M.reduce       = fns.reduce
M.concat       = fns.concat
M.sortByKeys   = fns.sortByKeys
M.sortByValues = fns.sortByKeyValues

function M.each(t, f) -- Replaces hs.fns.each b/c: Passes key as 2nd param {{{
  assert(is.tbl(t) and is.callable(f), 'u.each expects args of type(table, func)')
  for k, v in pairs(t) do
    f(v, k)
  end
  return t
end -- }}}

local function iteratee(x) --[[ {{{
  Shortcuts for writing common map & filter funcs by simply passing a string or table.
  This turns out to be extremely useful.
  See also https://github.com/rxi/lume#iteratee-functions.
     - M.map(x, 'key')                           -> get list of values at 'key'
     - M.filter(x, {key1='special', key2=true }) -> get collection elements that match the key,val pairs specified
  ]]

  if x==nil then return u.identity end -- Use identity fn if 'x' is nil
  if u.is.callable(x) then return x end -- Return as-is if 'x' is callable

  if type(x)=='table' then
    return function(el)
      for k, v in pairs(x) do
        if el[k] ~= v then return false end
      end
      return true
    end
  end

  -- Otherwise, assume x is a 'string' and simply lookup 'x' on each element in collection
  return function(el) return el[x] end
end -- }}}

--[[ == M.map(t, fn) NOTES, TESTS, TODOS == {{{

  = TESTS =
  -- Setup by creating stackline window objects
  ws = M.map(hs.window.filter(), stackline.window:call('new'))

  -- Pluck keys of child tables with string 'fn' arg:
  appnames = M.map(ws, 'app') -- -> { "Hammerspoon", "Google Chrome", "Google Chrome", "kitty", "kitty" }

  TODO: If table is list-like & values are strings, delegate to M.pick(...)
  TODO: Doesn't work with 'map': M.map(tbl, {'id', 'app', 'frame'}) does not pluck id,app,frame keys
  TODO: Pass multiple string values to filter each child table to those keys:
        e.g., appnames_and_ids = M.map(ws, 'app', 'id') -- -> { {id=123, app="Hammerspoon"}, {id=456, app="Google Chrome", ...}
 }}} ]]

local function makeMapper(iter) --[[ {{{
  Factory fn to produce mappers {{{
  NOTE: This exists primarily because `hs.fns.map` *only* maps values, not keys. Also, the `iteratee` capabilities are nice.
  NOTE: return v, k from map fn to map *both* values & keys
  mapping fn prototyped as `f (v, k)`

  Adapted from: https://github.com/Yonaba/Moses/blob/master/moses.lua#L395
  }}} ]]
  iter = iter or u.rawpairs -- default to 'rawpairs', but can be given custom iter

  return function(t, fn, ...)
    t = t or {}
    fn = iteratee(fn)
    local res = {}

    for k,v in iter(t) do
      local r1, r2 = fn(v, k, ...)
      local newKey = r2 and r1 or k  -- If 2nd retval nil, use original key 'k'
      local newVal = r2 and r2 or r1 -- If 2nd retval not nil, *newVal* is **second** retval, otherwise the first
      res[newKey] = newVal
    end

    return res
  end
end -- }}} }}}

M.map = makeMapper(pairs) -- use as u.map(tbl, funcOrTable)

M.imap = makeMapper(ipairs) -- use as u.imap(tbl, funcOrTable)

--[[ == M.filter(t, fn) NOTES, TODOS == {{{
  param `fn` may be a function OR a table.  If it's a table, it's treated as a filter specification
  TODO: Support nested functions as values.
    E.g., to find elements with app = kitty and a title that contains 'nvim':
    M.filter(ws, { app = 'kitty', title = function(x) return x:find('nvim') end })
 }}} ]]

function M.filter(t, fn)
  return fns.filter(t, iteratee(fn))
end

function M.ifilter(t, fn)
  return fns.ifilter(t, iteratee(fn))
end

function M.filterKeys(t, fn) -- {{{
  local res = {}
  for k, v in u.rawpairs(t or {}) do
    if fn(v, k) then res[k] = v end
  end
  return res
end -- }}}

M.some = fns.some
M.any  = fns.some -- alias 'some()' as 'any()'
M.all  = fns.every -- alias 'every()' as 'all()'
M.none = function(t) return not M.some(t) end

function M.sort(tbl, fn) -- {{{
  -- WANRING: Sorting mutates table
  fn = fn or function(x,y) return x < y end
  if u.is.array(tbl) then
    table.sort(tbl,fn)
  end
  return tbl
end -- }}}

function M.reverse(t) -- {{{
  -- Reverses values in a given array. The passed-in array should not be sparse.
  local res = {}
  for i = #t, 1, -1 do
    res[#res+1] = t[i]
  end
  return res
end -- }}}

function M.find(t, val, compareFn) -- {{{
  compareFn = compareFn or u.equal

  local pred = u.is.callable(val)
    and val
    or u.bindTail(compareFn, val)

  for k, v in pairs(t) do
    if pred(v,k) then return v, k end
  end
end -- }}}

function M.getFirst(t, ...) -- {{{
  for _,key in pairs({...}) do
    if t[key]~=nil then
      return t[key]
    end
  end
end -- }}}

function M.contains(t, needle) --[[ {{{
  == TESTS == {{{
  M.contains({1,2,3}, 2) -- -> true
  M.contains({1,2,3}, 4) -- -> false

  haystack = {{name = 'cindy'}, {name = 'john'}, {{id=1}, {id=2}, {id=3}}, 1, 2, 3}
  t1 = {name  = 'john'}
  t2 = {name  = 'johnDo'}
  t3 = 'john'
  t4 = 2
  t5 = {id=2}
  t6 = {id=9}

  M.contains(haystack, t1) -- -> true
  M.contains(haystack, t2) -- -> false
  M.contains(haystack, t3) -- -> true
  M.contains(haystack, t4) -- -> true
  M.contains(haystack, t5) -- -> true
  M.contains(haystack, t6) -- -> false
  }}} ]]
  for k, v in pairs(t) do
    if u.equal(v, needle) then return true end
    if type(v)=='table' then
      if M.contains(v, needle) then return true end
    end
  end
  return false
end

M.include = M.contains
M.includes = M.contains
-- }}}

function M.invert(t, iter)  -- {{{
  iter = iter or pairs
  local res = {}
  for k,v in iter(t) do res[v] = k end
  return res
end  -- }}}

function M.uniq(tbl) -- {{{
  return u.keys(M.invert(tbl))
end -- }}}

function M.append(t, val, ...) -- {{{
  if (val==nil) then return t end
  table.insert(t, val)
  return M.append(t, ...)
end -- }}}

function M.clear(t, keys) -- {{{
  -- `keys` is optional list of keys to clear. If absent, all keys are cleared.
  for _, k in pairs(keys or u.keys(t)) do
    t[k] = nil
  end
end -- }}}

function M.move(t1, t2, key) -- {{{
  local tmp = u.dcopy(t1) -- Cache the instance's data so it can be moved to a private key later
  u.clear(t1) -- set all source keys to `nil`
  t2[key] = tmp -- and set copied source data to destination key
end -- }}}

function M.assignIf(_pred, t1, t2, ...) --[[ {{{
  If pred is callable then only assign ... to t1[k] to v if `pred(v,k,t)` return true
  ADAPTED FROM: https://github.com/CodeKingdomsTeam/rodash/blob/master/src/Tables.lua#L648
  @param pred may be a boolean OR predicate function
    * when predicate fn, called as _pred(v,k,t1)
    * when boolean, `true` overwrites non-nil keys in t1 & `false` does not
  @usage {{{
    x = { name = 'john', age = 99 }
    y = { job = 'farmer', color = 'red'}
    z = { job = 'banker', color = 'orange', poop = 'smelly', things = {1,2,3,4} }

    r = u.assign(false, u.copy(x),y,z)
    assert(r.job == 'farmer')

    r = u.assign(true, u.copy(x),y,z)
    assert(r.job == 'banker')

    r = u.assign(u.is.tbl, u.copy(x),y,z)
    assert(r.job == nil)
    assert(u.equal(r.things, {1,2,3,4}))
  }}} ]]
  if (t2==nil) then return t1 end

  pred = u.isnt.func(_pred)
    and function() return _pred end
    or _pred

  -- Assignment does not typically ignore fields that might be ignored by a modified __pairs metamethod
  -- This is especially true in u.assignMeta 
  for k, v in u.rawpairs(t2) do
    if pred(v, k, t1) then
      t1[k] = v
    end
  end

  return M.assignIf(_pred, t1, ...)
end -- }}}

M.assign     = bind(M.assignIf, true) -- overwrite 1st table always
M.assignSafe = bind(M.assignIf, function(_,k,t) return t[k] == nil end) -- only set if key is nil
M.assignMeta = bind(M.assignIf, rearg(is.metamethod, {2})) -- only extend
M.copy = bind(M.assign, {}) -- extend args to a new empty table
-- IDEA: Kind of a neat way to copy *array-like* takes: `function copytable(t) return {unpack(t)} end`

function M.dcopy(t, iter, seen) --[[ {{{
  from https://gist.github.com/tylerneylon/81333721109155b2d244/
  The issue here is that the following code will call itself indefinitely and ultimately cause a stack overflow:
  @test cyclic references {{{
    x = {}
    x.a = x
    x1 = u.dcopy(x)
    assert(x1.a.a.a == x1.a)
  }}}
  @test table keys {{{
    x = {}
    a,b,c = {'a'},{'b'},{'c'}
    x[b] = true
    x[a] = true
    x[c] = {1,2,3}

    -- Test accessing table with key = table `c`
    x[c] -- -> {1,2,3}

    x1 = u.dcopy(x)

    -- copy ~= original & copy at idx `c` is *nil* b/c *keys* were also copied
    assert(x1~=x)
    assert(x1[c]==nil)
  }}}
  @example {{{
    Harry     = { patronus = "stag", age  = 12 }
    Hedwig    = { animal   = "owl", owner = Harry }
    Harry.pet = Hedwig

    HarryClone = u.dcopy(Harry)
    Harry.age = 13

    -- The object HarryClone is completely independent of any changes to Harry:
    u.p(HarryClone) --> '<1>{age = 12, patronus = "stag", pet = {animal = "owl", owner = &1}}'
  }}} ]]

  -- Handle non-tables and previously-seen tables
  if is.null(t) then return {} end
  if is.nt.tbl(t) then return t end
  if is.tbl(seen) and seen[t] then return seen[t] end

  -- New table; mark it as seen and copy recursively
  iter = iter or u.rawpairs
  seen = seen or {}
  local result = {}
  seen[t] = result

  for k, v in iter(t) do
    result[M.dcopy(k, iter, seen)] = M.dcopy(v, iter, seen)
  end

  return setmetatable(result, getmetatable(t) or {})
end -- }}}

function M.groupBy(t, f) --[[ {{{
  FROM: https://github.com/pyrodogg/AdventOfCode/blob/master/2019/lua/util.lua#L149
  == TESTS == {{{
  x = { 'string1', 1, {1,2,3}, 'string2', 4, {'string3'} }
  M.groupBy(x, type)
  ->  {
    number = { 1, 4 },
    string = { "string1", "string2" },
    table = { { 1, 2, 3 }, { "string3" } }
    }
  }}} ]]
  local res = {}
  for _, v in ipairs(t) do

    assert(u.is.str(f) or u.is.func(f), 'Invalid group parameter [' .. f .. ']')
    -- if not u.is.str(f) or u.is.func(f) then
    --   error('Invalid group parameter [' .. f .. ']')
    -- end

    local groupKey = type(f)=='function'
      and f(v)
      or v[f]

    -- ensure groupKey is a table
    if res[groupKey]==nil then
      res[groupKey] = {}
    end

    table.insert(res[groupKey], v)
  end

  return res
end -- }}}

function M.zip(a, b) --[[ {{{
  Given 2 array-like tables, pair 1st, 2nd, 3rd .. els of both tables
  @example
    x,y = {1,2,3}, {4,5,6}
    u.zip(x,y) --> { { 1, 4 }, { 2, 5 }, { 3, 6 } }
  ]]
  local rv = {}
  local idx = 1
  local len = math.min(#a, #b)

  while i <= len do
    rv[i] = { a[i], b[i] }
    i = i + 1
  end

  return rv
end -- }}}

function M.mergeOnKey(arr1, arr2, key) --[[ {{{
  Written to replace `query.mergeStackIdx()` in a more generic way.
  This doesn't quite do it, tho: need to traverse `arr2` if it has a more deeply nested structure
  = TEST = {{{
  t1 = { {id = 1, name = 'person1'}, {id = 2, name = 'person2'} }
  t2 = { {id = 1, age = 33 }, {id = 2, age = 28} }
  r = M.mergeOnKey(t1, t2, 'id') -- => {{ age=33, id=1, name="person1" },{age=28, id=2, name="person2" }}
    }}} ]]
  for _, obj in ipairs(arr1) do
    for k,v in pairs(obj) do
      local other = u.find(arr2, obj[key])
      M.assign(obj, other)
    end
  end
  return arr1
end -- }}}

function M.mergeOnto(extra, grouped, byKey, asKey) --[[ {{{
  Mutate <grouped> by assigning <extra>[byKey] to groupedItem[asKey]
  <grouped> = list of lists with window objs: { group1 = { t1, t2, t3 }, group2 = { t4, t5, t6 }  }
  <extra> = map of { key = val } pairs where each key is a value at `<key>` on an inner object of <grouped>

  NOTE: This has dubious general utility. It was ported from stackline.query.lua on 2021-07-08.
  ]]
  return u(grouped)
    :each(function(grp)
      u(grp):each(function(el)
        el[asKey] = extra[ el[byKey] ]
      end)
    end)
    :value()
end -- }}}

return M
