-- Inspo:
--     https://github.com/leegao/AMX2D/blob/master/core/table.lua
--     https://github.com/mikelovesrobots/lua-enumerable/blob/master/lua-enumerable.lua
--     MUST REVIEW: https://github.com/LPGhatguy/ld27-fast-food/blob/main/ussuri/core/utility.lua


-- The following allows you to safely pack varargs while retaining nil values
table.NIL = table.NIL or setmetatable({}, {
    __tostring = function() return "nil" end
})



-- uses table.insert(..) for numeric keys and t[k] = v for all other keys
table.insertraw = table.insert
table.insert = function(...)  -- {{{
  local args = {...}
  if #args==3 and type(args[2])=='string' then
    local t, k, v = table.unpack(args)
    t[k] = v
    return t
  end
  table.insertraw(...)
end -- }}}
table._insert = table.insert

table.removeraw = table.remove
table.remove = function(t, k)  -- {{{
  if k~=nil and type(k) == 'string' then
    t[k] = nil
  else
    return table.removeraw(t,k)
  end
end  -- }}}
table._remove = table.remove

function table.removeEmpty(tbl)  -- {{{
  local same = require 'lib.utils.comparison'.same
  for k,v in pairs(tbl) do
    if same(v, {}) then tbl[k] = nil end
  end
  return tbl
end  -- }}}

local function indexByEquality(self, x)  -- {{{
  for k,v in pairs(self) do
    -- if k == x then
    if u.same(k,x) then
      return v
    end
  end
end  -- }}}

function table.length(t)  -- {{{
  local n = 0
  for k, v in pairs(t) do n = n+1 end
  return n
end  -- }}}
table.len = table.length

function table.find(t, o)  -- {{{
  for k, v in pairs(t) do
    if v == o then
      return k
    end
  end
end  -- }}}

function table.flatten(tbl)  -- {{{
  local function flatten(tbl, mdepth, depth, prefix, res, circ)   -- {{{
    local k, v = next(tbl)
    while k do
      local pk = prefix .. k
      if type(v) ~= 'table' then
	res[pk] = v
      else
	local ref = tostring(v)
	if not circ[ref] then
	  if mdepth > 0 and depth >= mdepth then
	    res[pk] = v
	  else   -- set value except circular referenced value
	    circ[ref] = true
	    local nextPrefix = pk .. '.'
	    flatten(v, mdepth, depth + 1, nextPrefix, res, circ)
	    circ[ref] = nil
	  end
	end
      end
      k, v = next(tbl, k)
    end
    return res
  end   -- }}}

  local maxdepth = 0
  local circularRef = {[tostring(tbl)] = true}
  local prefix = ''
  local result = {}

  return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end  -- }}}

-- old table.merge only supports 2 args
-- function table.merge(t1, t2) -- {{{
--   if not type(t2)=='table' then return t1 end
--   if not type(t1)=='table' then return t2 end
--   for k,v in pairs(t2) do
--     if type(v) == "table" then
--       if type(t1[k] or false) == "table" then
-- 	table.merge(t1[k] or {}, t2[k] or {})
--       else
-- 	t1[k] = v
--       end
--     else
--       t1[k] = v
--     end
--   end
--   return t1
-- end -- }}}

function table._merge(...)-- {{{
  local iter = require 'lib.utils.collections'.iter
  local rtn = {}
  for i = 1, select('#', ...) do
      local t = select(i, ...)
      for k, v in iter(t) do
	  rtn[k] = v
      end
  end
  return rtn
end-- }}}

-- TODO: Remove table.extend() OR table.merge()
function table.extend(from, to)  -- {{{
  if not from or not to then error("table can't be nil") end
  local u = require 'lib.utils.types'

  local function extend(f, t)
    for k, v in pairs(f) do

      if u.is_table(f[k]) and u.is_table(t[k]) then
	t[k] = extend(f[k], t[k])

      elseif u.is_table(f[k]) then
	t[k] = extend(f[k], {})

      else
	t[k] = v
      end
    end
    return t
  end

  return extend(from, to)
end  -- }}}

function table.merge(...) -- {{{
  -- See also: https://github.com/btatarov/gamedevkit-lua/blob/main/gamedevkit.lua#L545
  -- ↑ it's simpler, but doesn't work the way I need it to; it preserves keys,
  -- so that the merged result will not have more keys than the largest input table.
  local u = require 'lib.utils.types'
  u.iter = require 'lib.utils.collections'.iter
  --[[
  table.merge(...)
  x = {1,2,3}
  y = {'a', 'b', 'c', name = 'JohnDoe', blocks = { 'test',2,3 }}
  z = {blocks = { 1,2,'3', 99, 3 }, 7,8,9}
  a = table.merge(x,z,y)
  hs.inspect(a)
  --]]
  local out = {}
  for _, tbl in ipairs({...}) do
    if not u.is_table(tbl) then return tbl end

    -- For eeach key, value pair:
    for k, v in u.iter(tbl) do -- if *value* is a table…
      if u.is_table(v) then

     -- … *and* there's an existing value set at that key that is *also* a table
     if u.is_table(out[k]) then -- recursively call merge with
       table.merge(out[k] or {}, tbl[k] or {})

     -- otherwise just assign k,v
     -- else out[k] = (ut (ut v end
     else table.insert(out,k,v) end

      -- v is *not* a table, so just insert it
      else table.insert(out,k,v)
      end
    end
  end

  return out
end-- }}}

local function iteratee(tbl)-- {{{
  local identity = require 'lib.utils.math'.identity
  local u = require 'lib.utils.types'
  if tbl == nil then return identity end
  if u.iscallable(tbl) then return tbl end
  if u.is_table(tbl) then
    return function(z)
      for k, v in pairs(tbl) do -- Q: should this use u.iter(x)?
	if z[k] ~= v then return false end
      end
      return true
    end
  end
  return function(z) return z[tbl] end
end-- }}}

function table.match(src, fn)-- {{{
  -- Returns the value and key of the value in the table which returns true when
  -- a function is called on it. Returns nil if no such value exists.
  local iter = require 'lib.utils.collections'.iter
  fn = iteratee(fn)
  for k, v in iter(src) do
    if fn(v) then return v, k end
  end
  return nil
end-- }}}

function table.concat_all(...)-- {{{
  local iter = require 'lib.utils.collections'.iter
  -- Returns a new array consisting of all given arrays concatenated into one.
  -- NOTE: the returned table will NOT have any string keys — this is for lists of tables *only*
  -- FROM: https://github.com/btatarov/gamedevkit-lua/blob/main/gamedevkit.lua#L560
  local rtn = {}
  for i = 1, select('#', ...) do
    local t = select(i, ...)
    if t ~= nil then
      for _, v in iter(t) do
	rtn[#rtn + 1] = v
      end
    end
  end
  return rtn
end-- }}}

function table._concat(set1, set2)  -- {{{
    --[[
  Private `concat` function to merge two array-like objects.

  @private
  @param {Array} {set1={}} An array-like object.
  @param {Array} {set2={}} An array-like object.
  @return {Array} A new, merged array.
  @example
  _concat({4, 5, 6}, {1, 2, 3})   --> {4, 5, 6, 1, 2, 3}
  ]]
  set1 = set1 or {}
  set2 = set2 or {}
  local len1 = #set1
  local len2 = #set2
  local result = {}

  local idx = 1
  while idx <= len1 do
    result[#result + 1] = set1[idx]
    idx = idx + 1
  end

  idx = 1
  while idx <= len2 do
    result[#result + 1] = set2[idx]
    idx = idx + 1
  end
  return result
end  -- }}}

function table.join(t1, t2, o)  -- {{{
  local iter = require 'lib.utils.collections'.iter
  local tab = t1
  for k, v in iter(t2) do
    if (t1[k] and o) or not (t1[k]) then
      tab[k] = v
    end
  end
  return tab
end  -- }}}

function table.slice(obj, start, finish)  -- {{{
  if (#obj == 0) or (start == finish) then return {} end
  local _finish = finish or (#obj + 1)

  local output = {}
  for i = (start or 1), (_finish - 1) do
    table.insert(output, obj[i])
  end

  return output
end  -- }}}

function table.reduce(obj, fn, accum)  -- {{{
  local initial = 1
  local _accum = accum
  if _accum == nil then
    initial = 2
    _accum = obj[1]
  end

  for i=initial, #obj do
    _accum = fn(_accum, obj[i], i)
  end

  return _accum
end  -- }}}

function table.foreach(tbl, fn)  -- {{{
  for k,v in pairs(tbl) do
    fn(k,v)
  end
end  -- }}}

function table.groupBy(tbl, by)  -- {{{ assert(tbl ~= nil, 'table to groupBy must not be nil')
  --[[
      a = {
      {color = 'red', num = 99 },
      {color = 'red', num = 9 },
      {color = 'red', num = 102 },
      {color = 'red', num = 101 },
      {color = 'red', num = 103 },
      {color = 'red', num = 102 },
      {color = 'red', num = 114 },
      {color = 'orange', num = 9 },
      {color = 'orange', num = 1 },
      {color = 'orange', num = 02 },
      {color = 'orange', num = 01 },
      {color = 'orange', num = 03 },
      {color = 'orange', num = 02 },
      {color = 'orange', num = 14 },
      {color = 'orange', num = 24 },
      {color = 'orange', num = 76 },
      {color = 'blue', num = 2 },
      {color = 'blue', num = 1 },
      {color = 'blue', num = 3 },
      {color = 'blue', num = 2 },
      {color = 'blue', num = 4 },
    }
    d.inspectByDefault(false)
    Con = require 'lib.Container'
    g = Con(table.groupBy(a, 'color'))
    g:print(1)


      a = {
      {color = 'red', num = 99 },
      {color = 'red', num = 99 },
      {color = 'blue', num = 102 },
      {color = 'green', num = 3 },
      {color = 'green', num = 3 },
      {color = 'green', num = 4 },
    }
    d.inspectByDefault(false)
    Con = require 'lib.Container'
    g = Con(table.groupBy(a))
    t1 = g[5][1]
    t2 = g[4][1]
    u.same(t2,t1)

  --]]


  local u = require 'lib.utils.types'
  local keys = require 'lib.utils.collections'.keys
  local values = require 'lib.utils.collections'.values

  -- assume identity if no 'by' is passed
  if by==nil then by = function(x) return x end end

  local function reducer(accum, curr)
    assert(type(accum) == 'table', 'reducer accumulator must be a table')
    local res
    if u.is_function(by) then
      res = by(curr)
    elseif u.is_string(by) then
      res = curr[by]
    end
    if not accum[res] then
      accum[res] = {}
    end
    table.insert(accum[res], curr)
    return accum
  end

  -- indexByEquality is VERY important for grouping equal elements together
  local accumulator = setmetatable({}, { __index = indexByEquality })

  -- Do the reduction!
  local res = table.reduce(tbl, reducer, accumulator)

  return u.is_table(keys(res)[1])
    and values(res)  -- if keys are table, return values instead
    or res           -- otherwise, just send back the normal result
end  -- }}}

function table.seperate(t)  -- {{{
  local itab = {}
  local tab = {}
  for k, v in pairs(t) do
    if type(k) == "number" then
      itab[k] = v
    else
      tab[k] = v
    end
  end
  return itab, tab
end  -- }}}

function table.invert(t, _i)  -- {{{
  local tab = {}
  for k, v in pairs(t) do
    if type(v) == "table" and not _i then
      for _k, _v in pairs(v) do
	tab[_v] = k
      end
    else
      if not tab[v] then
	tab[v] = k
      else
	if not (type(tab[v]) == "table") then
	  tab[v] = {tab[v], k}
	else
	  table.insert(tab[v], k)
	end
      end
    end
  end
  return tab
end  -- }}}

function table.ascend(x, y)  -- {{{
  return x<y
end  -- }}}

function table.descend(x, y)  -- {{{
  return x>y
end  -- }}}

function table.ssort(t,f)  -- {{{
  if not f then f = table.ascend end
  local i=1
  local x, _x = table.seperate(t)
  local n = table.length(x)
  while i<=n do
    local m,j=i,i+1
    while j<=n do
      if f(x[j],x[m]) then m=j end
      j=j+1
    end
    x[i],x[m]=x[m],x[i]			  -- swap x[i] and x[m]
    i=i+1
  end
  return table.join(x, _x, false)
end  -- }}}

-- function table.sort(t, f)  -- {{{
  -- 	return table.seperate(table.ssort(t, f))
  -- end  -- }}}

function table.diff(t1, t2, opts, currDepth)  -- {{{
  -- (potential) opts keys:
  --    - depth
  --    - keys (in t1, t2) to ignore when computing diff
  -- See also /Users/adamwagner/Programming/Projects/stackline/lib/utils/comparison.lua:146

  opts = opts or {}
  opts.ignore = opts.ignore or {}
  opts.maxDepth = opts.maxDepth or 10

  local diff = {
    changed = {},
    removed = {},
    new = {},
    same = {},
    skipped = {},
    child = {},
  }

  local function shouldSkip(k,v)
    if v==nil
      or u.is_userdata(v)
      or u.is_function(v)
      or (currDepth or 1) >= opts.maxDepth
    then return true end

    if u.is_string(k)
      and (k:startsWith('_kvo') or u.includes(opts.ignore, k)) then
      return true
    end
  end

  --[[
  IMPORTANT! When using multiple key/value observers,
  (e.g., stackline/lib/kvo.lua)
  using `v` in this loop will reference an *outdated* value.
  *Always* use `t1[k]` instead of `v`
  ]]

  for k, v in pairs(t1) do
    local skip = shouldSkip(k, t1[k])
	      or shouldSkip(k, t2[k])

    if skip then
      diff.skipped[k] = true
      break

    elseif u.all({t1, t2}, u.is_table) then
      diff.child[k] = table.diff(t1[k], t2[k], opts, (currDepth or 1) + 1)

    elseif t2[k]==nil then
      diff.removed[k] = t1[k]

    elseif not u.same(t2[k], t1[k]) then
      diff.changed[k] = {old = t1[k], new = t2[k]}

    else
      diff.same[k] = v
    end

  end

  for k, v in pairs(t2) do
    if not (diff.changed[k] or diff.removed[k] or diff.same[k] or diff.skipped[k] or diff.child[k]) then
      diff.new[k] = v
    end
  end

  return table.removeEmpty(diff)
  end  -- }}}
  -- ALT Table diff {{{

  -- https://github.com/RobSis/treesome/blob/c34210c4ae90eceb136ca3d25104169e7b1b5937/init.lua#L53
    -- function table_diff(table1, table2)
    --     local diffList = {}
    --     for i,v in ipairs(table1) do
    --         if table2[i] ~= v then
    --             table.insert(diffList, v)
    --         end
    --     end
    --     if #diffList == 0 then
    --         diffList = nil
    --     end
    --     return diffList
    -- end

  -- OTHERS
  -- https://github.com/geheur/wowluascratch/blob/master/cleanWAscript.lua
  --  }}}

function table.changed(t1, t2, opts)  -- {{{
  local simple_diff = {}
  local tdiff = table.diff(t1, t2, opts) -- important to pass opts along (ignore keys!)

  local function simplify(d, childKey)

    for k,_ in pairs(d.changed) do
      if d.child and d.child[k] then
	simplify(d.child[k], k)
      else
	local str
	if childKey then
	  str = string.format("%s -- %s -> %s", childKey, d.changed[k].old, d.changed[k].new)
	else
	  str = string.format("%s -> %s", d.changed[k].old, d.changed[k].new)
	end
	simple_diff[k] = str
      end
    end

  end
  u.pheader('tdiff at start')
  u.p(tdiff)
  print('-------------------\n\n')

  simplify(tdiff)
  return simple_diff
end  -- }}}

-- BACKUP of table.changed
-- function table.changed(t1, t2, opts)  -- {{{
--   local diff = table.diff(t1, t2, opts)
--   local simple_diff = {}
--   for k,v in pairs(diff.changed) do
--     if diff.child[k] then
--       simple_diff[k] = diff.child[k].changed or true
--     end
--   end
--   return simple_diff
-- end  -- }}}

function table.keyAsValue(...)  -- {{{
    local arr = {...}
    local ret = {}
    for _,v in ipairs(arr) do
        ret[v] = v
    end
    return ret
end  -- }}}

function table.len(tbl)  -- {{{
  if type(tbl)~='table' then return 0 end
  local iter = require 'lib.utils.collections'.iter
  local c = 0
  for _ in iter(tbl) do c = c + 1 end
  return c
end  -- }}}

function table.print(tbl)  -- {{{
    local format = string.format
    for k,v in pairs(tbl) do
        print(format('[%s] => ', k), v)
    end
end  -- }}}

function table.Equals(source, target)  -- {{{
    local sourceType, targetType = type(source), type(target)

    if sourceType ~= targetType then
        return false
    end

      -- non-table types can be directly compared
    if not u.istable(source) or not u.istable(target) then
        return source == target
    end

    for k1, v1 in pairs(source) do
        local v2 = target[k1]
        if v2 == nil or not table.Equals(v1, v2) then
            return false
        end
    end

    for k2, v2 in pairs(target) do
        local v1 = source[k2]
        if v1 == nil or not table.Equals(v1, v2) then
            return false
        end
    end

    return true
end  -- }}}

function table.ShallowDiff(source, target)  -- {{{
  local diff = {}

  for k,v in pairs(source) do
    if type(v)=='table' and type(target[k])=='table' then
      diff[k] = table.ShallowDiff(v, target[k])
    elseif target[k]==nil or not table.Equals(v, target[k]) then
      diff[k] = v
    end
  end

  return table.removeEmpty(diff)
end  -- }}}


--[[ {{{ TEST DATA

data = {
  {
  name='JohnDoe',
  age = 33,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  {
  name='JaneDoe',
  age = 36,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  {
  name='bob',
  age = 55,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  type = 'example',
  version = 1.05
}

data = {
  {
  name='JohnDoe',
  age = 33,
  friends = {
    {name='bob'},
    }
  },
  {
  name='JaneDoe',
  age = 36,
  friends = {
    {name='bob'},
    }
  },
  {
  name='bob',
  age = 55,
  friends = {
    {name='bob'},
    }
  },
  type = 'example',
  version = 1.05
}
a = u.dcopy(data)
b = u.dcopy(data)

b.version = 6
b[1].friends[1].name = 'Suzie Q'
Con = require 'lib.Container'

r = table.diff(a,b)

r = Con(r)
r:print(99)

-- }}} ]]


--[[
  ┌──────┐
  │ Test │
  └──────┘

  d.inspectByDefault(true)
  x = { name = 'JohnDoe', age = 33, friends = {{ name = 'bill'}, {name = 'Jenna'}, {name = 'bob'}} }
  y = u.dcopy(x)
  y.friends[1].name = 'josh'
  y.age = 34
  r = table.changed(x,y)

--]]
