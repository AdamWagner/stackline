
local function checkTables(t1, t2) -- Return "t1,t2" or "{}, {}"
  t1 = type(t1)=='table' and t1 or {}
  t2 = type(t2)=='table' and t2 or {}
  return t1, t2
end 

local function extender(t1, t2, pred) -- If pred is callable then only assign t1[k] to v if `pred(t,k,v)` return true
  t1, t2 = checkTables(t1, t2)
  local skipCheck = not u.is.callable(pred)

  for k, v in pairs(t2) do
    if skipCheck or pred(t,k,v) then
      t1[k] = v
    end
  end

  return t1
end


local M = {}

M.some = hs.fnutils.some
M.any  = hs.fnutils.some -- alias 'some()' as 'any()'
M.all  = hs.fnutils.every -- alias 'every()' as 'all()'

function M.sort(tbl, fn) -- {{{
  -- WANRING: Sorting mutates table
  fn = fn or function(x,y) return x < y end
  if u.is.array(tbl) then
    table.sort(tbl,fn)
  end
  return tbl
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
    if M.equal(v, needle) then return true end
    if type(v)=='table' then
      if M.contains(v, needle) then return true end
    end
  end
  return false
end

M.include = M.contains
M.includes = M.contains
-- }}}

function M.extend(t1, t2, t3, ...)-- {{{
  t1 = extender(t1,t2)

  return type(t3)=='table'
    and M.extend(t1, t3, ...) -- if there are more tables, keep going
    or t1 -- otherwise just return the extended t1
end -- }}}

function M.safeExtend(t1, t2, t3, ...)-- {{{
  t1 = extender(t1,t2, function(t,k,v)
    return t[k]==nil
  end)

  return type(t3)=='table'
    and M.safeExtend(t1, t3, ...) -- if there are more tables, keep going
    or t1 -- otherwise just return the extended t1
end -- }}}

function M.reverse(t) -- {{{
  -- Reverses values in a given array. The passed-in array should not be sparse.
  local res = {}
  for i = #t, 1, -1 do
    res[#res+1] = t[i]
  end
  return res
end -- }}}

function M.copy(t, iter) -- {{{
    -- FROM: https://github.com/XavierCHN/go/blob/master/game/go/scripts/vscripts/utils/table.lua
    if not M.is.tbl(t) then
        local copy = t
        return copy
   end
    iter = iter or pairs
    local copy = {}
    for k, v in iter(t) do
       copy[k] = v
    end
    return copy
end -- }}}

function M.dcopy(obj, iter, seen) --[[ {{{
    from https://gist.github.com/tylerneylon/81333721109155b2d244/
    The issue here is that the following code will call itself indefinitely and ultimately cause a stack overflow:

    = TEST =
    local my_t = {}
    my_t.a = my_t
    local t_copy = copy2(my_t)

    This happens to both copy1 and copy2, which each try to make a copy of
    my_t.a, which involves making a copy of my_t.a.a, which involves making a copy
    of my_t.a.a.a, etc. The recursive table my_t is perfectly legal, and it's
    possible to make a deep_copy function that can handle this by tracking which
    tables it has already started to copy.

    We do not call setmetatable() until doing copying values;
    otherwise may accidentally trigger a custom __index() or __newindex()!
    ]]

    -- Handle non-tables and previously-seen tables
    if not M.is.tbl(obj) then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively
    iter = iter or pairs
    seen = seen or {}
    local res = {}
    seen[obj] = res

    for k, v in iter(obj) do
        local key = M.dcopy(k, iter, seen)
        local val = M.dcopy(v, iter, seen)
        res[key] = val
    end

    local mt = M.copy(getmetatable(obj) or {})      -- Must copy the metatable to avoid mutating the actual mt on `obj`
    if iter == u.rawpairs then mt.__pairs = nil end -- Clear __pairs metamethod if M.rawpairs `iter` is given

    return setmetatable(res, mt)
end -- }}}

function M.groupBy(t, f) --[[ {{{
  FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
  = TESTS = {{{
  x = { 'string1', 1, {1,2,3}, 'string2', 4, {'string3'} }
  M.groupBy(x, type)
    ->  {
      number = { 1, 4 },
      string = { "string1", "string2" },
      table = { { 1, 2, 3 }, { "string3" } }
    }
  }}} ]]
  local res = {}
  for _k, v in pairs(t) do
    local g
    if type(f)=='function' then
      g = f(v)
    elseif type(f)=='string' and v[f]~=nil then
      g = v[f]
    else
      error('Invalid group parameter [' .. f .. ']')
    end

    if res[g]==nil then
      res[g] = {}
    end
    table.insert(res[g], v)
  end
  return res
end -- }}}

function M.zip(a, b) -- {{{
  local rv = {}
  local idx = 1
  local len = math.min(#a, #b)
  while idx <= len do
    rv[idx] = {a[idx], b[idx]}
    idx = idx + 1
  end
  return rv
end -- }}}

function M.uniq(tbl) -- {{{
  local res = {}
  for _, v in ipairs(tbl) do
    res[v] = true
  end
  return M.keys(res)
end -- }}}

function M.find(t, val) -- {{{
  for k, v in pairs(t) do
    if u.equal(k, val) then
      return v
    end
  end
end -- }}}

function M.flatten(t, deep) -- {{{
  local ret = {}
  for _, v in ipairs(t) do
    if type(v) == 'table' and deep then
      for _, fv in ipairs(u.flatten(v)) do
        ret[#ret + 1] = fv
      end
    else
      ret[#ret + 1] = v
    end
  end
  return ret
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
      M.extend(obj, other)
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
  u.each(grouped, function(tbl)
    u.each(tbl, function(el)
      el[asKey] = extra[el[byKey]]
    end)
  end)
  return grouped
end -- }}}

return M
