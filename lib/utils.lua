local log = hs.logger.new('utils')
local unpack = table.unpack or unpack
log.setLogLevel('info')
log.i("Loading module")

-- utils module ----------------------------------------------------------------
u = {}

-- Extend builtins -------------------------------------------------------------
function string:split(p) -- {{{
  -- Splits the string [s] into substrings wherever pattern [p] occurs.
  -- Returns: a table of substrings or, a table with the string as the only element
  local p = p or '%s' -- split on space by default
  local temp = {}
  local index = 0
  local last_index = self:len()

  while true do
    local i, e = self:find(p, index)

    if i and e then
      local next_index = e + 1
      local word_bound = i - 1
      table.insert(temp, self:sub(index, word_bound))
      index = next_index
    else
      if index > 0 and index <= last_index then
        table.insert(temp, self:sub(index, last_index))
      elseif index == 0 then
        temp = {self}
      end
      break
    end
  end

  return temp
end -- }}}

-- table.insert {{{
-- uses table.insert(..) for numeric keys
-- and  t[k] = v         for all other keys
table.insertraw = table.insert
table.insert = function(...)
  local args = {...}
  if (#args == 3) and (type(args[2]) == 'string') then
    local t, k, v = table.unpack(args)
    t[k] = v
    return t
  end
  table.insertraw(...)
end
table._insert = table.insert
-- }}}
function table.merge(...) -- {{{
  -- Recursively merge tables
  --[[ {{{  TEST DATA
  table.merge(...)
  x = {1,2,3}
  y = {'a', 'b', 'c', name = 'JohnDoe', blocks = { 'test',2,3 }}
  z = {blocks = { 1,2,'3', 99, 3 }, 7,8,9}
  a = table.merge(x,z,y)
  hs.inspect(a)
    -> { "a", "b", "c", 7, 8, 9, 1, 2, 3,
          blocks = { 1, 2, "3", 99, 3, "test", 2, 3 },
          name = "JohnDoe"
       }
  }}} ]]

  local istbl = u.istable
  local function both_are_tables(tbl_list)
    return u.all(tbl_list, istbl)
  end
  local out = {}

  for _, tbl in u.iter({...}) do
    if not istbl(tbl) then
      return tbl
    end

    for k, currVal in u.iter(tbl) do
      local targetVal = out[k]
      if both_are_tables({currVal, targetVal}) then
        -- set currVal to recursively merged results
        currVal = table.merge(currVal, targetVal)
      end
      -- set (or replace) key in table
      table.insert(out, k, currVal)
    end
  end
  return out
end -- }}}
function table.flatten(tbl) -- {{{
  --[[ TEST
      -- Children keys == parent keys
      x = {name='adam',age=33,friends={{name='amy',age=28},{name='bob',age=66}}}
      y = table.flatten(x)

      -- Children keys != parent keeys
      a = {name='adam',age=33,things={{type='physical', order=28},{another='blah',more=66}}}
      b = table.flatten(a)
   ]]
  local function flatten(_tbl, mdepth, depth, prefix, res, circ) -- {{{
    local k, v = next(_tbl)
    while k do
      local pk = prefix .. k
      if type(v) ~= 'table' then
        res[pk] = v
      else
        local ref = tostring(v)
        if not circ[ref] then
          if mdepth > 0 and depth >= mdepth then
            res[pk] = v
          else -- set value except circular referenced value
            circ[ref] = true
            local nextPrefix = pk .. '.'
            flatten(v, mdepth, depth + 1, nextPrefix, res, circ)
            circ[ref] = nil
          end
        end
      end
      k, v = next(_tbl, k)
    end
    return res
  end -- }}}

  local maxdepth = 0
  local circularRef = {[tostring(tbl)] = true}
  local prefix = ''
  local result = {}

  return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end -- }}}
function table.setPath(f, v, t) -- {{{
  -- FROM: https://www.lua.org/pil/14.1.html
  t = t or _G -- start with the table of globals
  for w, d in string.gmatch(f, "([%w_]+)(.?)") do
    if d == "." then -- not last field?
      t[w] = t[w] or {} -- create table if absent
      t = t[w] -- get the table
    else -- last field
      t[w] = v -- do the assignment
    end
  end
end -- }}}
function table.getPath(path, tbl, isSafe) -- {{{
  --[[ TEST {{{
  x = { name = 'adam', path = { other = { more = 33 } } }

  table.getPath('x.path.other')
  -> { more =  33 }

  table.getPath('x.path.other.more')
  -> 33

  table.getPath('x.path.other.more.does.not.exist')
  -> 33

  table.setPath('x.path.other.more', 55)
  x.path.other.more == 55
  -> true
  }}} ]]

  -- FROM: https://www.lua.org/pil/14.1.html
  isSafe = isSafe or true
  local v = tbl or _G -- default to global tabl if tbl not provided
  local res = nil

  for w in path:gmatch('[%w_]+') do
    if not u.istable(v) then
      return v
    end -- if v isn't table, return immediately
    v = v[w] -- lookup next val
    if v ~= nil then
      res = v
    end -- only update safe result if v not null
  end

  if isSafe then -- return the last non-nil value found
    return v ~= nil and v or res
  else -- return the last value found regardless
    return v
  end
end -- }}}
function table.len(t) -- {{{
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end -- }}}
u.len = table.len

-- Type utils
function u.isnil(val) -- {{{
  return type(val) == 'nil'
end -- }}}
function u.isnum(val) -- {{{
  return type(val) == 'number'
end -- }}}
function u.istable(val) -- {{{
  return type(val) == 'table'
end -- }}}
function u.iskey(val) -- {{{
  return type(val) == 'string' or type(val) == 'number'
end -- }}}
function u.isarray(val) -- {{{
  if not u.istable(val) then
    return false
  end

  local function keys_are_consecutive(x)
    local i = 0
    for k in pairs(x) do
      i = i + 1
      if x[i] == nil then
        return false
      end
    end
    return true
  end

  return keys_are_consecutive(val)
end -- }}}
function u.toBool(val) -- {{{
  -- Reference:
  -- function toboolean( v )
  --   local n = tonumber( v )
  --   return n ~= nil and n ~= 0
  -- end
  local t = type(val)
  if t == 'boolean' then
    return val
  elseif t == 'number' then
    return val == 1 and true or false
  elseif t == 'string' then
    val = val:gsub("%W", "") -- remove all whitespace
    local TRUE = {
      ['1'] = true,
      ['t'] = true,
      ['T'] = true,
      ['true'] = true,
      ['TRUE'] = true,
      ['True'] = true,
    };
    local FALSE = {
      ['0'] = false,
      ['f'] = false,
      ['F'] = false,
      ['false'] = false,
      ['FALSE'] = false,
      ['False'] = false,
    };
    if TRUE[val] == true then
      return true;
    elseif FALSE[val] == false then
      return false;
    else
      return false, string.format('cannot convert %q to boolean', val);
    end
  end
end -- }}}
function u.boolToNum(value) -- {{{
  return value == true and 1 or value == false and 0
end -- }}}

function u.wrapargs(...) -- {{{
  local args = {...}
  local not_all_nil = not u.all({...}, u.isnil)

  assert(not_all_nil, 'Error: all wrapped varargs are nil.')

  return u.istable(args[1]) and table.len(args[1]) and args[1] or args
end -- }}}
function u.all_tables(...) -- {{{
  return u.all(u.wrapargs(...), u.istable)
end -- }}}
function u.all_nums(...) -- {{{
  -- u.all_nums(1,2,3)              -- -> true
  -- u.all_nums({1,2,3})            -- -> true
  -- u.all_nums(1,2,3, nil, 'hi')   -- -> false
  -- u.all_nums({1,2,3, nil, 'hi'}) -- -> false
  -- u.all_nums(nil, nil, nil)      -- -> false
  return u.all(u.wrapargs(...), u.isnum)
end -- }}}

-- Iteration utils
function u.getiter(x) -- {{{
  -- Dynamically determine whether to use ipairs or pairs based on the provided table
  -- USAGE NOTE: How to check which fn was returned from the outside:
  --    local fn = u.getiter(tbl)
  --    local iteratorType = fn == ipairs and 'pairs' or 'pairs'
  assert(u.istable(x), 'getiter() expects a table')
  if u.isarray(x) then
    return ipairs
  elseif u.istable(x) then
    return pairs
  end
end -- }}}
function u.iter(x) -- {{{
  -- selects appropriate iterator AND kicks off the process:
  --    for k,v in u.iter(tbl) do ...
  -- instead of:
  --    for k,v in u.getiter(tbl)(tbl) do ...

  --[[ TEST
  array = {1,2,3,34,4}
  dict = {name = 'adam', age = 33}
  for k,v in u.iter(array) do print(k,v) end
  for k,v in u.iter(dict) do print(k,v) end
  ]]
  return u.getiter(x)(x)
end -- }}}

-- String utils
function u.levenshteinDistance(str1, str2) -- {{{
  str1, str2 = str1:lower(), str2:lower()
  local len1, len2 = #str1, #str2
  local char1, char2, distance = {}, {}, {}
  str1:gsub('.', function(c)
    table.insert(char1, c)
  end)
  str2:gsub('.', function(c)
    table.insert(char2, c)
  end)
  for i = 0, len1 do
    distance[i] = {}
  end
  for i = 0, len1 do
    distance[i][0] = i
  end
  for i = 0, len2 do
    distance[0][i] = i
  end
  for i = 1, len1 do
    for j = 1, len2 do
      distance[i][j] = math.min(distance[i - 1][j] + 1, distance[i][j - 1] + 1,
          distance[i - 1][j - 1] + (char1[i] == char2[j] and 0 or 1))
    end
  end
  return distance[len1][len2] / #str2 -- note
end -- }}}

function u.extract(list, comp, transform, ...) -- {{{
  -- from moses.lua
  -- extracts value from a list
  transform = transform or u.identity
  local _ans
  for k, v in pairs(list) do
    if not _ans then
      _ans = transform(v, ...)
    else
      local val = transform(v, ...)
      _ans = comp(_ans, val) and _ans or val
    end
  end
  return _ans
end -- }}}
function u.max(t, transform) -- {{{
  return u.extract(t, u.gt, transform)
end -- }}}

function u.roundToNearest(roundTo, numToRound) -- {{{
  u.pheader('roundTo', roundTo)
  u.pheader('numToRound', numToRound)
  local allnums = u.all_nums(roundTo, numToRound)
  print('allnums', allnums)
  if not allnums then
    print('NOT NUMS')
    log.w('roundToNearest() expects number args - returning "0" by default')
    return 0
  end
  return numToRound - numToRound % roundTo
end -- }}}

-- Print / debug utils
function u.p(data, howDeep) -- {{{
  -- local logger = hs.logger.new('inspect', 'debug')
  local depth = howDeep or 3
  if type(data) == 'table' then
    print(hs.inspect(data, {depth = depth}))
    -- logger.df(hs.inspect(data, {depth = depth}))
  else
    print(hs.inspect(data, {depth = depth}))
    -- logger.df(hs.inspect(data, {depth = depth}))
  end
end -- }}}
function u.look(obj) -- {{{
  print(hs.inspect(obj, {depth = 2, metatables = true}))
end -- }}}
function u.pdivider(str) -- {{{
  str = string.upper(str) or ""
  print("=========", str, "==========")
end -- }}}
function u.pheader(...) -- {{{
  print('\n\n\n')
  print("========================================")
  for _, str in pairs(u.wrapargs(...)) do
    print(hs.inspect(str))
  end
  print("========================================")
end -- }}}

-- Copy utils
function u.scopy(orig) -- {{{
  -- FROM: https://github.com/XavierCHN/go/blob/master/game/go/scripts/vscripts/utils/table.lua
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end -- }}}
function u.dcopy(obj, seen) -- {{{
  --[[ NOTES {{{
    from https://gist.githubusercontent.com/tylerneylon/81333721109155b2d244/raw/5d610d32f493939e56efa6bebbcd2018873fb38c/copy.lua
    The issue here is that the following code will call itself
    indefinitely and ultimately cause a stack overflow:

    local my_t = {}
    my_t.a = my_t
    local t_copy = copy2(my_t)

    This happens to both copy1 and copy2, which each try to make
    a copy of my_t.a, which involves making a copy of my_t.a.a,
    which involves making a copy of my_t.a.a.a, etc. The
    recursive table my_t is perfectly legal, and it's possible to
    make a deep_copy function that can handle this by tracking
    which tables it has already started to copy.

    Thanks to @mnemnion for pointing out that we should not call
    setmetatable() until we're doing copying values; otherwise we
    may accidentally trigger a custom __index() or __newindex()!

    Handle non-tables and previously-seen tables.
  }}} ]]

  -- return primative values
  if not u.istable(obj) then
    return obj
  end

  -- don't recompute cached values
  if seen and seen[obj] then
    return seen[obj]
  end

  -- New table; mark it as seen and copy recursively.
  local s = seen or {}
  local res = {}
  s[obj] = res
  for k, v in pairs(obj) do
    -- handles table keys
    res[u.dcopy(k, s)] = u.dcopy(v, s)
  end
  return setmetatable(res, getmetatable(obj))
end -- }}}

-- Comparison utils
function u.gt(a, b) -- {{{
  return a > b
end -- }}}
function u.lt(a, b) -- {{{
  return a < b
end -- }}}
function u.equal(a, b) -- {{{
  if #a ~= #b then
    return false
  end

  for i, _ in ipairs(a) do
    if b[i] ~= a[i] then
      return false
    end
  end

  return true
end -- }}}
function u.isEqual(a, b) -- {{{
  --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
    --]]

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

end -- }}}
function u.greaterThan(n) -- {{{
  return function(t)
    return #t > n
  end
end -- }}}

-- functional utils
function u.identity(value) -- {{{
  return value
end -- }}}
function u.partial(f, ...) -- {{{
  -- FROM: https://www.reddit.com/r/lua/comments/fh2go5/a_partialcurry_implementation_of_mine_hope_you/
  -- WHEN: 2020-08-08
  local unpack = unpack or table.unpack -- Lua 5.3 moved unpack
  local a = {...}
  local a_len = select("#", ...)
  return function(...)
    local tmp = {...}
    local tmp_len = select("#", ...)
    -- Merge arg lists
    for i = 1, tmp_len do
      a[a_len + i] = tmp[i]
    end
    return f(unpack(a, 1, a_len + tmp_len))
  end
end -- }}}
function u.pipe(...) -- {{{
  local funcs = {...}
  return function(...)
    local ret = {...}
    for i, f in ipairs(funcs) do
      ret = {f(unpack(ret))}
    end
    return unpack(ret)
  end
end -- }}}
function u.cb(fn) -- {{{
  return function()
    return fn
  end
end -- }}}
function u.values(t) -- {{{
  local values = {}
  for _k, v in pairs(t) do
    values[#values + 1] = v
  end
  return values
end -- }}}
function u.include(list, value) -- {{{
  for i in u.iter(list) do
    if i == value then
      return true
    end
  end
  return false
end -- }}}
function u.any(list, func) -- {{{
  for i in u.iter(list) do
    if func(i) then
      return true
    end
  end
  return false
end -- }}}
function u.all(vs, fn) -- {{{
  fn = fn or u.identity
  for _, v in pairs(vs) do
    if not fn(v) then
      return false
    end
  end
  return true
end
u.every = u.all
-- }}}
-- Alias hs.fnutils methods {{{
u.map = hs.fnutils.map
u.filter = hs.fnutils.filter
u.reduce = hs.fnutils.reduce
u.partial = hs.fnutils.partial
u.each = hs.fnutils.each
u.contains = hs.fnutils.contains
u.some = hs.fnutils.some
u.any = hs.fnutils.some -- also rename 'some()' to 'any()'
u.concat = hs.fnutils.concat
u.copy = hs.fnutils.copy
-- }}}

-- Collections / transformation utils
function u.extend(destination, source) -- {{{
  for k, v in pairs(source) do
    destination[k] = v
  end
  return destination
end -- }}}
function u.zip(a, b) -- {{{
  local rv = {}
  local idx = 1
  local len = math.min(#a, #b)
  while idx <= len do
    rv[idx] = {a[idx], b[idx]}
    idx = idx + 1
  end
  return rv
end -- }}}
function u.groupBy(t, f) -- {{{
  -- FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
  local res = {}
  for _k, v in pairs(t) do
    local g
    if type(f) == 'function' then
      g = f(v)
    elseif type(f) == 'string' and v[f] ~= nil then
      g = v[f]
    else
      error('Invalid group parameter [' .. f .. ']')
    end

    if res[g] == nil then
      res[g] = {}
    end
    table.insert(res[g], v)
  end
  return res
end -- }}}
function u.flatten(tbl, depth) -- {{{
  --[[ TEST
      -- Children keys == parent keys
      x = {name='adam',age=33,friends={{name='amy',age=28},{name='bob',age=66}}}
      y = u.flatten(x)

      -- Children keys != parent keeys
      a = {name='adam',age=33,things={{type='physical', order=28},{another='blah',more=66}}}
      b = u.flatten(a)
   ]]
  depth = depth or 100
  local currDepth = 0

  local function flatten(res, vs, currdepth)
    local tinsert = table.insert

    for k, v in pairs(vs) do
      currDepth = currDepth + 1

      if u.istable(v) and (currDepth <= depth) then
        flatten(res, v, currdepth)
      end

      local key = u.iskey(k) and k or tostring(k)
      tinsert(res, key, v)

    end
    return res
  end

  local result = flatten({}, tbl) -- generate draft result
  return result
  --[[
    TODO: Update `return …` when dependencies are available
        -> return table.len(result) > 1
            and result       -- if result has length, return result
            or M.unnest(tbl) -- otherwise, fall back to unnest() instead
    ]]
end -- }}}
function u.invert(t) -- {{{
  local rtn = {}
  for k, v in pairs(t) do
    rtn[v] = k
  end
  return rtn
end -- }}}
function u.keys(t) -- {{{
  local rtn = {}
  for k in u.iter(t) do
    rtn[#rtn + 1] = k
  end
  return rtn
end -- }}}
function u.find(t, value) -- {{{
  local iter = getiter(t)
  result = nil
  for k, v in iter(t) do
    if k == value then
      result = v
    end
  end
  return result
end -- }}}

return u

