local log = hs.logger.new('utils')
local unpack = table.unpack or unpack
local format = string.format
log.setLogLevel('info')
log.i("Loading module")

--[[
https://luazdf.aiq.dk/fn/like.html
https://github.com/Akwatujou/Windower/tree/master/addons/libs
https://github.com/moriyalb/lamda/blob/master/dist/lamda.lua
https://github.com/Yonaba/Moses/blob/master/moses.lua
]]

-- utils module ----------------------------------------------------------------
u = {}

function u.keys_are_consecutive(val)  -- {{{
  local i = 0
  for k in pairs(val) do
    i = i + 1
    if val[i] == nil then
      return false
    end
  end
  return true
end  -- }}}
function u.wrapargs(...) -- {{{
  --[[ TEST
     a = u.wrapargs(1,2,3,4)
       -> { 1, 2, 3, 4 }
     b = u.wrapargs({1,2,3,4})
       -> { 1, 2, 3, 4 }
     c = u.wrapargs({name = 'johnDoe'}, {name = 'johnDoe'})
     d = u.wrapargs({ name = 'johnDoe' }, 1,2,3)
  ]]
  local args = {...}
  if u.all(args, u.types.null) then print(args) end
  local first_tbl_is_args = u.types.tbl(args[1]) and #args[1]>0 and #args==1
  return first_tbl_is_args and args[1] or args
end -- }}}

-- Metatable helpers (see for more: https://github.com/nsimplex/wicker/blob/master/init/init_modules/metatablelib.lua)
function u.extend_mt(tbl, additional_mt)  -- {{{
  local orig_mt = getmetatable(tbl)

  for k,v in pairs(additional_mt) do
    if k ~= '__index' then -- only want to copy class metamethods OTHER than index
      getmetatable(tbl)[k] = v
    end
  end


  return tbl
end  -- }}}
function u.isMetamethodName(key)  -- {{{
  return u.types.string(key) and key:startsWith('__')
end  -- }}}
function u.filterMt(tbl)  -- {{{
  local res = {}
  for k,v in pairs(tbl) do
    if u.isMetamethodName(k) then
      res[k] = v
    end
  end
  return res
end  -- }}}
function u.rejectMt(tbl)  -- {{{
  local res = {}
  for k,v in pairs(tbl) do
    if not u.isMetamethodName(k) then
      res[k] = v
    end
  end
  return res
end  -- }}}
function u.extend_mt(tbl, additional_mt)  -- {{{
  local orig_mt = getmetatable(tbl)
  for k,v in pairs(additional_mt) do
    if k ~= '__index' then -- only want to copy class metamethods OTHER than index
      getmetatable(tbl)[k] = v
    end
  end

  return tbl
end  -- }}}

-- string
function string:startsWith(str) -- {{{
  local firstChar = self:sub(1, #str)
  return firstChar == str
end -- }}}
function string:endsWith(str) -- {{{
  local lastChar = self:sub(#self - (#str - 1))
  return lastChar == str
end -- }}}
function string:removeExcessWhitespace(str) -- {{{
  return self:gsub("%s+", " ")
end -- }}}
function string:ensureEndsWith(char) -- {{{
  local lastChar = self:sub(#self)
  if lastChar ~= char then
    self = self .. char
  end
  return self
end -- }}}
function string:removeWhitespace(str) -- {{{
  return self:gsub("%s+", "")
end -- }}}
function string:capitalize() -- {{{
  -- FROM: https://github.com/EvandroLG/str/blob/master/src/str/init.lua#L128
  if #self== 0 then return self end

  local function upperFirst()
    return self:sub(1, 1):upper()
  end

  local function lowerRest()
    return self:sub(2):lower()
  end

  return upperFirst() .. lowerRest()
end -- }}}
function string:split(pat) -- {{{
  -- splits the string into substring using the specified separator and return them as a table

  pat = pat or '%s' -- split on space by default
  local output = {}
  local fpat = '(.-)' .. pat
  local last_end = 1
  local _s, e, cap = self:find(fpat, 1)

  while _s do
    if _s ~= 1 or cap ~= '' then
      table.insert(output, cap)
    end

    last_end = e+1
    _s, e, cap = self:find(fpat, last_end)
  end

  if last_end <= #self then
    cap = self:sub(last_end)
    table.insert(output, cap)
  end

  return output
end -- }}}
function string.join(tbl, sep) -- {{{
  sep = sep or '\n'
  return table.concat(tbl, sep)
end -- }}}
function string:trim_right() -- {{{
  -- returns a new string with trailing whitespace removed
  return self:match('(.-)%s*$')
end -- }}}
function string:trim_left() -- {{{
  -- returns a new string with leading whitespace removed
  return self:match('[^%s+].*')
end -- }}}
function string:trim() -- {{{
  -- returns a copy of string leading and trailing whitespace removed
  return self.trim_right(
    self.trim_left(self)
  )
end -- }}}
function string:center(n) -- {{{
  -- returns a copy of the string passed as parameter centralized with spaces passed in size parameter
  local aux = ''

  for i=1, n do
    aux = aux .. ' '
  end

  return aux .. self .. aux
end -- }}}
function u.distance(str1, str2) -- {{{
  str1, str2 = str1:lower(), str2:lower()
  local len1, len2 = #str1, #str2
  local char1, char2, dist = {}, {}, {}
  str1:gsub('.', function(c) table.insert(char1, c) end)
  str2:gsub('.', function(c) table.insert(char2, c) end)
  for i = 0, len1 do dist[i] = {} end
  for i = 0, len1 do dist[i][0] = i end
  for i = 0, len2 do dist[0][i] = i end
  for i = 1, len1 do
    for j = 1, len2 do
      dist[i][j] = math.min(
        dist[i-1][j] + 1, dist[i][j-1] + 1,
        dist[i-1][j-1] + (char1[i] == char2[j] and 0 or 1)
      )
    end
  end
  return dist[len1][len2] / #str2
end -- }}}

-- Iteration utils
function u.getiter(x) -- {{{
  -- Dynamically determine whether to use ipairs or pairs based on the provided table
  -- USAGE NOTE: How to check which fn was returned from the outside:
  --    local fn = u.getiter(tbl)
  --    local iteratorType = fn == ipairs and 'pairs' or 'pairs'
  assert(u.types.tbl(x), 'getiter() expects a table')
  if u.types.array(x) then
    return ipairs
  elseif u.types.tbl(x) then
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
  dict = {name = 'johnDoe', age = 33}
  for k,v in u.iter(array) do print(k,v) end
  for k,v in u.iter(dict) do print(k,v) end
  ]]
  return u.getiter(x)(x)
end -- }}}
function u.rawpairs(tbl)  -- {{{
 return next, tbl, nil
end  -- }}}
function u.spairs(t, order)  -- {{{
  if type(t) ~= "table" then return end

  local keys = {}
  if type(order) == 'string' then order = string.lower(order) end

  for k, _ in pairs(t) do
    if type(k) == 'number' then keys[#keys + 1] = k end
  end
  if order == "ascending" then
    table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
  elseif order == "descending" then
    table.sort(keys, function(a, b) return tonumber(a) > tonumber(b) end)
  elseif type(order) == 'function' then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  local i = 0
  return function()
    i = i + 1
    if keys[i] then return keys[i], t[keys[i]] end
  end
end -- }}}
function u.iter_if(fn)  -- {{{
  return function(tbl, k)
    repeat
      k, v = next(tbl, k)
      if fn(k,v) then return k,v end
    until k == nil
  end
end  -- }}}

-- Type utils
-- Generate type check functions {{{
local primative_types = {
  ['table'] = true,
  ['string'] = true,
  ['boolean'] = true,
  ['function'] = true,
  ['userdata'] = true,
  ['thread'] = true,
  ['nil'] = true,
  ['nan'] = function(val) return val ~= val end,
}

local type_aliases = {
  ['number'] = 'num',
  ['function'] = 'fn',
  ['table'] = 'tbl',
  ['nil'] = 'null',
}

local compound_types = {    -- {{{
      -- Note that `number` will overwrite the primative type checker with the same name.
      -- TODO: is there a better name for this one?
  number = function(val)
    return type(val)=='number'
          and not u.types.null(val)
          and not u.types.nan(val)
  end,

  integer = function(val)
    return val~=nil
          and u.types.num(val)
          and math.floor(val)==val
  end,

  object = function(val)     -- `val` is an object if keys aren't consecutive from 1.
    if not u.types.tbl(val) then return false end
    return not u.keys_are_consecutive(val)
  end,

  array = function(val)     -- `val` is an array if keys are consecutive from 1.
    if not u.types.tbl(val) then return false end
    return u.keys_are_consecutive(val)
  end,

  obj_key = function(val)
    return u.types.string(val) or u.types.num(val)
  end,

  array_key = function(k)
    return u.types.integer(k) and k >= 1
  end,

  sortable = function(val)
    if not u.types.tbl(val) then return false end
    if u.any(u.values(val), u.types.tbl) then return false end
    return u.keys_are_consecutive(val)
  end,

  callable = function(val)
    if u.types.fn(val) then return true end
    local mt = getmetatable(val)
    return mt and mt.__call~=nil
  end,

  empty = function(val)
    if u.types.null(val) then
      return true
    elseif u.types.string(val) then
      return val == ""
    elseif u.types.tbl(val) then
      return next(val)==nil
    else
      return false
    end
  end,
}   -- }}}

local function make_typecheck_fn(typ, fn)    -- {{{
    -- generate fns for all primative types
  return type(fn)=='function'
    and fn
    or function(val) return type(val)==typ end
end    -- }}}

u.types = {}
u.types.all = {}
u.types.any = {}

local function make_checker(typ, fn)
  local key = type_aliases[typ] or typ
  u.types[key] = make_typecheck_fn(typ, fn)
  u.types.all[key ..'s'] = function(...) -- {{{
    --[[ TEST
      u.types.all.nums(1,2,3)              -- -> true
      u.types.all.nums({1,2,3})            -- -> true
      u.types.all.nums(1,2,3, nil, 'hi')   -- -> false
      u.types.all.nums({1,2,3, nil, 'hi'}) -- -> false
      u.types.all.nums(nil, nil, nil)      -- -> false

      u.types.all.tbls({1,2,3}, {1,2,3})
      u.types.all.tbls({ {1,2,3}, {1,2,3} })
    --]]
    return u.all(u.wrapargs(...), u.types[key])
  end -- }}}
  u.types.any[key ..'s'] = function(...) -- {{{
    --[[ TEST
      u.types.any.nums(1,'test')                -- -> true
      u.types.any.nums({1,2,2}, {'one', 'two'}) -- -> false
    --]]
    return u.any(u.wrapargs(...), u.types[key])
  end -- }}}
end
for typ, fn in pairs(primative_types) do
  make_checker(typ, fn)
end

for typ, fn in pairs(compound_types) do
  make_checker(typ, fn)
end
  -- }}}
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

-- Math utils
function u.roundToNearest(roundTo, numToRound) -- {{{
  local allnums = u.types.all.nums(roundTo, numToRound)
  if not allnums then
    log.w('roundToNearest() expects number args - returning "0" by default')
    return 0
  end
  return numToRound - numToRound % roundTo
end -- }}}

-- Print / debug utils
function u.p(...) -- {{{
  local args = u.wrapargs(...)
  local last_arg = args[u.len(args)-1]
  local depth = u.types.num(last_arg) and last_arg or 3
  print(hs.inspect(unpack(args), {depth = depth}))
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
  if not u.types.tbl(obj) then
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

-- functional utils
function u.identity(value) -- {{{
  return value
end -- }}}
function u.curry(fn, params) -- {{{
  -- FROM: https://github.com/KelsonBall/LuaCurry/blob/master/curry.lua
  -- ALT (a little simpler?) https://github.com/ericnething/lua-lambda/blob/master/lambda.lua#L30
  return (function(...)
    local args = params or {}
    local num_expected = debug.getinfo(fn).nparams
    local total_args = #args + #{...}

    if total_args == num_expected then
      args = {unpack(args)}
      for _, v in ipairs({...}) do
        table.insert(args, v)
      end
      return fn(unpack(args))
    else
      for _, v in ipairs({...}) do
        table.insert(args, v)
      end
      return u.curry(fn, args)
    end
  end)
end -- }}}
function u.flip(fn) -- {{{
  return function(a, b, ...)
    return fn(b, a, ...)
  end
end -- }}}
function u.partial(f, ...) -- {{{
  -- FROM: https://www.reddit.com/r/lua/comments/fh2go5/a_partialcurry_implementation_of_mine_hope_you/
  -- WHEN: 2020-08-08
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
  --[[ TEST
    mangle = u.pipe(string.upper, string.reverse )
    mangle('hi there')
  ]]
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
-- -> Alias all hs.fnutils methods {{{
hs.fnutils.any = hs.fnutils.some -- alias 'some' as 'any'
hs.fnutils.all = hs.fnutils.every -- alias 'every' as 'all'

-- Assign hs.fnutils methods to utils ...*plus* curried/flipped alt methods via u._<method_name>
for k,v in pairs(hs.fnutils) do
  u[k] = v -- add the vanilla fnutils method
  u['_'..k] = u.curry(u.flip(v)) -- alt version: curry & flip args for easy piping (like Ramda.js)
end

--[[ TEST curried & flipped fnutils {{{

-- Filter -------------------------
x = {1,2,3,4,4,4,4,6,6,6}
gt5  = u._filter(function(x) return x > 5 end)
gt5(x) -- -> {6,6,6}

-- Reduce ------------------------
x = {1,2,3,4,4,4,4,6,6,6,9}
sum_reducer = function(acc, curr) return acc + curr end
sum  = u._reduce(sum_reducer, 0)
sum(x) -- -> 49

-- Pipe combo ------------------------
sumif = u.pipe(gt5,sum)
sumif(x) -- -> 18

 }}} ]]


-- }}}
u._reduce = u.curry(function(fn, acc, tbl) -- {{{
  -- overwrite u._reduce() generated from hs.fnutils with custom version
  local idx = 1
  while idx <= #tbl do
    acc = fn(acc, tbl[idx])
    idx = idx + 1
  end
  return acc
end) -- }}}
function u.rawfilter(tbl,fn) -- {{{
  -- Bypass __pairs()
  local res = {}
  for k,v in u.iter_if(fn), tbl do
    res[u.types.list_idx(k) and (#res+1) or k] = v
  end
  return res
end -- }}}

-- Comparison utils
function u.gt(a,b) -- {{{
  if u.types.any.nulls(a,b) then
    return false
  elseif u.types.tbl(a) then
    return u.len(a) > b
  else
    return a > b
  end
end
u._gt = u.curry(u.flip(u.gt))
-- }}}
function u.lt(a, b) -- {{{
  return a < b
end -- }}}
function u.eq(a,b)-- {{{
  return a==b
end-- }}}
function u.eqLen(a,b)-- {{{
  return u.len(a)==u.len(b)
end-- }}}
function u.eqType(a,b)-- {{{
  return type(a)==type(b)
end-- }}}
function u.like(a, b) -- {{{
  local tmp = {}
  for i, v in ipairs(a) do
    local base = tmp[v] or 0
    tmp[v] = base + 1
  end
  for i, v in ipairs(b) do
    local base = tmp[v] or 0
    tmp[v] = base + 1
  end
  for k, v in pairs(tmp) do
    if v % 2 ~= 0 then
      return false
    end
  end
  return true
end -- }}}
function u.same(a,b)  -- {{{
  -- Checks if both array tables are the same. Array tables are the same if they
  -- have at each position the same values.
  if u.types.any.tbl({a,b}) then
    return a == b
  end
  for k, v in pairs(a) do
    local bVal = b[k]
    if bVal == nil or not u.same(v, bVal) then
      return false
    end
  end
  for k, v in pairs(b) do
    local aVal = a[k]
    if aVal == nil or not u.same(v, aVal) then
      return false
    end
  end
  return true
end  -- }}}
function u.equal(a, b) -- {{{
  --[[ TEST {{{

    -- Will compare table keys/vals
    u.equal({name = 'johnDoe'}, {name = 'johnDoe '})
    -- -> true

    -- ..but *not* nested tables
    u.equal(
      {{name = 'johnDoe'}, {name = 'johnDoe'}},
      {{name = 'johnDoe'}, {name = 'johnDoe'}}
    )
    -- -> false
  }}} ]]
  if a==b then return true end
  if u.types.all.tbls(a,b) then
    for i, _ in u.iter(a) do
      if b[i]~=a[i] then return false end
    end
  end
  return true
end -- }}}
function u.isSubset(left, right)-- {{{
  --[[ M.isSubset(left, right) --] {{{

    Returns `true` if all the values in *left* match corresponding values in *right* recursively.
      - Non-table elements match if they are equal
      - Table elements match if right is a subset of left

    @example ---------
      local car = {
        speed = 10,
        wheels = 4,
        lightsOn = { indicators = true, headlights = false }
      }

      M.isSubset(car, {})                                           --> true
      M.isSubset(car, car)                                          --> true
      M.isSubset(car, {speed = 10, lightsOn = {indicators = true}}) --> true
      M.isSubset(car, {speed = 12})                                 --> false
      M.isSubset({}, car)                                           --> false
   }}} ]]

 if not u.types.all.tbls { left, right } then return false end

 for key, a in pairs(left) do
   local b = right[key]

   if not u.eqType(a, b) then
     return false
   elseif a ~= b then
     if u.types.tbl(a) then
       if not u.isSubset(a, b) then
         return false
       end
     else
       return false
     end
   end -- end `not eqType(a, b)`
 end -- end `for key, a in

  -- if we've gotten this far, right IS a subset of left
 return true
end-- }}}
function u.deepEqual(a, b) -- {{{
  --[[ M.deepEqual(a, b) {{{

    Returns `true` if every element in *a* recursively matches every element *b*.
      * For elements which are not tables, they match if they are equal.
      * If they are tables they match if the left is recursively deeply-equal to the right.

    @example
      local car = {
        speed = 10,
        wheels = 4,
        lightsOn = { indicators = true, headlights = false }
      }
      local car2 = {
        speed = 10,
        wheels = 4,
        lightsOn = { indicators = false, headlights = false }
      }

      M.deepEqual(car, {})                  --> false
      M.deepEqual(car, car)                 --> true
      M.deepEqual(car, M.clone(car))        --> true
      M.deepEqual(car, M.cloneDeep(car))    --> true
      M.deepEqual(car, car2)                --> false
    }}} ]]
  if a==b then return true end
  return u.isSubset(a, b) and u.isSubset(b, a)
end
u.dequal = u.deepEqual
u.deepEquals = u.deepEqual
-- }}}
function u.greaterThan(n) -- {{{
  return function(t)
    return #t > n
  end
end -- }}}

-- Collections / transformation utils
function u.keys(tbl) -- {{{
  local res = {}
  for k in u.iter(tbl) do
    res[#res + 1] = k
  end
  return table.new(res)
end -- }}}
function u.values(tbl) -- {{{
  local res = {}
  for _k, v in u.iter(tbl) do
    res[#res + 1] = v
  end
  return table.new(res)
end -- }}}
function u.find(tbl, val) -- {{{
  res = nil
  for k, v in u.iter(tbl) do
    if k == val then
      res = v
    end
  end
  return res
end -- }}}
u.pick = function(tbl, ...) -- {{{
  -- Extracts values in a table having a given key.
  local keys = {...}
  local res = {}
  for k, v in pairs(tbl) do
    for _, key in ipairs(keys) do
      if k == key then res[key] = v end
    end
  end
  return table.new(res)
end
u._pick = u.curry(u.flip(u.pick))
-- }}}
function u.mapPick(tbl, ...)  -- {{{
  local keys = {...}
  local res = {}
  for _, _tbl in pairs(tbl) do
    local o = {}
    for k,v in pairs(_tbl) do
      if u.include(keys, k) then
        o[k] = v
        res[#res+1] = o
      end
    end
  end
  return res
end  -- }}}
u.pluck = function(tbl, ...) -- {{{
  -- Extracts values in a table having a given key.
  local keys = {...}
  local res = {}
  for k, v in pairs(tbl) do
    for _, key in ipairs(keys) do
      if v[key] then res[#res+1] = v[key] end
    end
  end
  return table.new(res)
end
u._pluck = u.curry(u.flip(u.pluck))
-- }}}
function u.include(tbl, target) -- {{{
  for _, v in u.iter(tbl) do
    if v == target then
      return true
    end
  end
  return false
end
u.includes = u.include
-- }}}
function u.groupBy(tbl, fn) -- {{{
  -- FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
  local res = {}
  for _k, v in pairs(tbl) do
    local g
    if u.types.fn(fn) then
      g = fn(v)
    elseif u.types.string(fn) and v[fn]~=nil then
      g = v[fn]
    else
      error('Invalid group parameter [' .. fn .. ']')
    end

    if res[g] == nil then
      res[g] = {}
    end
    table.insert(res[g], v)
  end
  return res
end -- }}}
u.unnest = u.pipe( -- {{{
  u.values,   -- doesn't work if key,value pairs, and usually we care about counting the values
  u._reduce(u.concat, {})
) -- }}}
function u.flatten(tbl, depth) -- {{{
  --[[ TEST
      -- Children keys == parent keys
      x = {name='johnDoe',age=99,friends={{name='janeDoe',age=28},{name='bob',age=66}}}
      y = u.flatten(x)
         -> {
              age = 33,
              ["friends.1.age"] = 28,
              ["friends.1.name"] = "janeDoe",
              ["friends.2.age"] = 66,
              ["friends.2.name"] = "bob",
              name = "johnDoe"
            }

      -- Children keys != parent keeys
      a = {name='johnDoe',age=99,things={{type='physical', order=28},{another='blah',more=66}}}
      b = u.flatten(a)
   ]]
  depth = depth or 100
  local currDepth = 0

  local function flatten(res, vs, currdepth)
    local tinsert = table.insert

    for k, v in pairs(vs) do
      currDepth = currDepth + 1

      if u.types.tbl(v) and (currDepth <= depth) then
        flatten(res, v, currdepth)
      end

      local key = u.types.obj_key(k) and k or tostring(k)
      tinsert(res, key, v)

    end
    return res
  end

  local result = flatten({}, tbl) -- generate draft result
  return table.len(result) > 1
    and result       -- if result has length, return result
    or u.unnest(tbl) -- otherwise, fall back to unnest() instead
end -- }}}
function u.concat(a, b)  -- {{{
  --[[
  Merge two array-like objects.
  @example
  u.concat({4, 5, 6}, {1, 2, 3})   --> {4, 5, 6, 1, 2, 3}
  ]]
  assert(u.types.all.arrays(a, b), 'concat(a,b) expects two array-like tables.')
  a = a or {}
  b = b or {}
  local len1 = #a
  local len2 = #b
  local result = {}
  local idx = 1
  while idx <= len1 do
    result[#result + 1] = a[idx]
    idx = idx + 1
  end
  idx = 1
  while idx <= len2 do
    result[#result + 1] = b[idx]
    idx = idx + 1
  end
  return result
end  -- }}}
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
function u.toSet(tbl)  -- {{{
  local res = {}
  for k,v in ipairs(tbl) do
    res[v] = true
  end
  return res
end  -- }}}
function u.unkey(tar, ...)  -- {{{
    -- Destructure a table
    -- @param tar table Target table
    -- @param t table Keys[] to destructure
    -- FROM: https://github.com/HunterGhost27/AuxiliaryFunctions/blob/master/Story/RawFiles/Lua/AuxFunctions/Shared/Tables.lua#L100
  local t = {...}
  if type(t) ~= 'table' then return end
  local temp = {}
  for idx, key in u.spairs(t) do
    if type(tar[key])=='table' then temp[idx] = u.unkey(tar[key], t) end
    if tar[key] then temp[idx] = tar[key] end
  end
  return table.unpack(temp)
end  -- }}}

-- table
_meta = {}
function table.merge(...) -- {{{
  -- Recursively merge tables
  --[[ {{{  TEST DATA
    -- case 1 ---
  x = {1,2,3}
  y = {'a', 'b', 'c', name = 'JohnDoe', blocks = { 'test',2,3 }}
  z = {blocks = { 1,2,'3', 99, 3 }, 7,8,9}
  a = table.merge(x,z,y)
      -> { "a", "b", "c", 7, 8, 9, 1, 2, 3,
            blocks = { 1, 2, "3", 99, 3, "test", 2, 3 },
            name = "JohnDoe"
         }

  }}} ]]

  local args = {...}
  local out = {}

  for _, tbl in u.iter(args) do
    if not u.types.tbl(tbl) then
      return tbl
    end

    for k, currVal in u.iter(tbl) do
      local targetVal = out[k]
      if u.types.all.tbls({currVal, targetVal}) then
        -- set currVal to recursively merged results
        currVal = table.merge(currVal, targetVal)
      end
      -- set (or replace) key in table
      table.insert(out, k, currVal)
    end
  end
  return out
end -- }}}
-- table.insert {{{
-- uses table.insert(..) for numeric keys
-- and  t[k] = v         for all other keys
table.insertraw = table.insert
table.insert = function(...)
  local args = {...}
  if (#args == 3) and (type(args[2]) == 'string') then
    local t, k, v = unpack(args)
    t[k] = v
    return t
  end
  table.insertraw(...)
end
table._insert = table.insert
-- }}}
_meta.T = {  -- {{{
  __index = table.merge(table, hs.fnutils, { pluck = u.pluck, pick = u.pick, mapPick = u.mapPick, keys = u.keys, values = u.values })
}  -- }}}
function table.new(t)  -- {{{
  local function n(_t)
    local newmt = table.merge(getmetatable(_t), _meta.T)
    return setmetatable(_t, newmt)
  end
  local ok, newTable = pcall(n, t)
  return ok and newTable or t
end  -- }}}
table.it = (function()  -- {{{
  local it = function(t)
    local key

    return function()
      key = next(t, key)
      return t[key], key
    end
  end

  return function(t)
    local meta = getmetatable(t)
    if not meta then
      return it(t)
    end

    local index = meta.__index
    if index == table then
      return it(t)
    end

    local fn = type(index) == 'table' and index.it or index(t, 'it') or it
    return (fn == table.it and it or fn)(t)
  end
end)()  -- }}}
function table.len(t) -- {{{
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end
u.len = table.len
-- }}}
function table.rekey(t, key)  -- {{{
    -- Returns a table keyed by a specified index of a subtable.
    -- Requires a table of tables, and key must be a valid key in every table.
    -- Only produces the correct result, if the key is unique.
    local res = {}

    for value in table.it(t) do
        res[value[key]] = value
    end

    return setmetatable(res, getmetatable(t))
end  -- }}}
function table.clear(t)  -- {{{
  -- Removes all elements from a table.
    for key in pairs(t) do
        rawset(t, key, nil)
    end

    return t
end  -- }}}
function table.unpackDict(t)  -- {{{
    -- Returns the values of the table, extracted into an argument list.
    -- Like unpack, but works on dictionaries as well.

    -- Convert a (possible) dictionary into an array.
    local res = {}
    local i = 1
    for value in table.it(t) do
        res[i] = value
        i = i + 1
    end

    return table.unpack(res)
end  -- }}}
function table.empty(t, rec)  -- {{{
  -- Check if table is empty.
  -- If rec is true, it counts empty nested empty tables as empty as well.
  if not rec then return next(t) == nil end

  for _, val in pairs(t) do
    if type(val) ~= 'table' then
      return false;
    else
      if not table.empty(val, true) then
        return false;
      end
    end
  end
  return true
end  -- }}}
function table.removeEmpty(tbl) -- {{{
  for k, v in pairs(tbl) do
    if table.empty(v) then
      tbl[k] = nil
    end
  end
  return tbl
end -- }}}
function table.reassign(t, tn)  -- {{{
    -- Returns the first table, reassigned to the second one.
    return table.update(table.clear(t), tn)
end  -- }}}

--[[ TEST DIFF {{{
  af = {{name = 'amy'}, {name = 'bob'}}
  a = { name = 'adam', age = 33, friends = af}

  bf = {{name = 'amy'}}
  b = { name = 'adam', age = 34, friends = bf}
 }}} ]]
function table.diff(a, b)  -- {{{
  --[[ {{{ NOTES
     FROM: https://github.com/martinfelis/luatablediff/blob/master/ltdiff.lua
  See alternate:
     /Users/adamwagner/Programming/Projects/stackline/lib/utils/table.lua:215
     https://github.com/Alloyed/patch.lua/blob/master/patch.lua
     https://github.com/lijinlong/tbdiff
     https://github.com/LuaDist-testing/ltdiff/blob/master/ltdiff.lua
     https://github.com/leegao/AMX2D/blob/9ccb32e5320e37f091d7814147b862ba14a82e47/core/table.lua#L288
     https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/PhotoStation_upload.lrplugin/PSUtilities.lua#L299
           Supports filtering by keys first, and supplying equality func



  NOTE: copying the tables before comparison BREAKS the comparison!!
  No differences are found!
  A = u.dcopy(A)
  B = u.dcopy(B)

  for k,v in pairs(A) do
    if type(A[k])=="function" or type(A[k])=="userdata" then
      A[k] = nil
    end
  end
  for k,v in pairs(B) do
    if type(B[k])=="function" or type(B[k])=="userdata" then
      B[k] = nil
    end
  end
  }}} ]]

  local is = u.types
  local diff = {del = {}, mod = {}, sub = {}}

  local function compare(x, y)
    for k, v in pairs(x) do
      local xk, yk = x[k], y[k]

      if is.fn(xk) or is.userdata(xk) then
        -- do nothing (skip)

      elseif yk~=nil and is.all.tbls(xk, yk) then
        diff[k] = table.diff(xk, yk)

        if next(diff[k])==nil then
          diff[k] = nil
        end

      elseif yk==nil then
        diff.del[#(diff.del) + 1] = k

      elseif yk~=v then
        diff.mod[k] = {old = xk, new = yk}
      end
    end
  end

  compare(a,b)
  compare(b,a)
  return table.removeEmpty(diff)
end  -- }}}
function table.diff2(t1, t2, opts, currDepth) -- {{{
  -- See also /Users/adamwagner/Programming/Projects/stackline/lib/utils/comparison.lua:146
  -- Another alt: https://github.com/Akwatujou/Windower/blob/master/addons/libs/config.lua#L363

  --[[ TEST {{{
    af = {{name = 'amy'}, {name = 'bob'}}
    a = { name = 'adam', age = 33, friends = af}

    bf = {{name = 'amy'}}
    b = { name = 'adam', age = 34, friends = bf}

    d = table.diff(a,b)
       -> {
            changed = { age = { new = 34, old = 33 } },
            child = {
              friends = {
                child = {...},
                skipped = {...}
              }
            },
            same = { name = "adam" }
          }
  }}} ]]

  opts = opts or {}
  opts.ignore = opts.ignore or {}
  opts.maxDepth = opts.maxDepth or 10

  local diff = {changed = {}, removed = {}, new = {}, same = {}, skipped = {}, child = {}}

  local function shouldSkip(k, v)
    if v == nil or u.types.userdata(v) or u.types.fn(v) or (currDepth or 1) >= opts.maxDepth then
      return true
    end

    if u.types.string(k) and (k:startsWith('_') or u.includes(opts.ignore, k)) then
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
    local skip = shouldSkip(k, t1[k]) or shouldSkip(k, t2[k])

    if skip then
      diff.skipped[k] = true
      break

    elseif t2[k] == nil then
      diff.removed[k] = t1[k]

    elseif u.types.all.tbls(t1[k], t2[k]) then
      diff.child[k] = table.diff2(t1[k], t2[k], opts, (currDepth or 1) + 1)

    elseif not u.deepEqual(t2[k], t1[k]) then
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

  return table.new(table.removeEmpty(diff))
end -- }}}
function table.diff3(t, t_new)  -- {{{
  -- Returns the table containing only elements from t_new that are different from t and not nil.
  -- FROM: https://github.com/Akwatujou/Windower/blob/master/addons/libs/config.lua
  local res = table.new({})
  local cmp

  for key, val in u.iter(t_new) do
    cmp = t[key]
    if cmp ~= nil then
      if type(cmp) ~= type(val) then
        print('Mismatched setting types for key \''..key..'\':', type(cmp), type(val))
      else
        if type(val) == 'table' then
          if u.types.array(val) and u.types.array(cmp) then
            if not u.equal(cmp, val) then
              res[key] = val
            end
          else
            res[key] = table.diff3(cmp, val)
          end
        elseif cmp ~= val then
          res[key] = val
        end
      end
    end
  end

  return not table.empty(res) and res or nil
end  -- }}}

function table.join(tbls)  -- {{{
  return u.reduce(tbls, u.concat, {})
end  -- }}}
function table.flatten(tbl) -- {{{
  -- Completely flatten long paths into top-level dot-separated string keys
  --[[ TEST {{{
    x = {name='johnDoe',age=99,friends={{name='janeDoe',age=28},{name='bob',age=66}}}
    y = table.flatten(x)
        -> {
            age = 99,
            ["friends.1.age"] = 28,
            ["friends.1.name"] = "janeDoe",
            ["friends.2.age"] = 66,
            ["friends.2.name"] = "bob",
            name = "johnDoe"
        }
  }}} ]]
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
function table.append(t, val)-- {{{
  -- Appends an element to the end of an array table.
  t[#t+1] = val
  return t;
end-- }}}
function table.extend(t1, t2)  -- {{{
    -- Appends an array table to the end of another array table.
  if type(t2) ~= 'table' then
    return t1:append(t2)
  end
  for _, val in ipairs(t2) do
    t1:append(val)
  end

  return t1
end  -- }}}
function table.flatten2(t, recursive) -- {{{
  recursive = true and (recursive ~= false)

  local res = {}
  local key = 1
  local flat = {}
  for k, v in ipairs(t) do
    if type(v) == 'table' then
      if recursive then
        flat = table.flatten(v, recursive)
        table.extend(res, flat)
        k = k + #flat
      else
        table.extend(res, v)
        k = k + #v
      end
    else
      res[k] = v
      k = k + 1
    end
  end

  return table.new(res)
end -- }}}

-- TODO: review util method args & arg order for consistent
-- TODO: programatically create curried/flipped versions together with hs.fnutils fns
function table.groupBy(tbl, by) -- {{{
  --[[ {{{ TEST DATA
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
    g = table.groupBy(a, 'color')

    d.inspectByDefault(false)
    g = table.groupBy(a, 'color')
    g.red

   a = {
      {color = 'red', num = 99 },
      {color = 'red', num = 99 },
      {color = 'blue', num = 102 },
      {color = 'blue', num = 102 },
      {color = 'green', num = 3 },
      {color = 'green', num = 3 },
      {color = 'green', num = 4 },
    }
    g = table.groupBy(a)

    -- NOTE: order is NOT guaranteed - so g[2] could be the group with only 1 item (green/4)
    t1 = g[2][1]
    t2 = g[2][2]
    u.isEqual(t2,t1)
  }}} ]]

  -- NOTE: indexByEquality is VERY important for grouping equal elements together
  local function indexByEquality(self, x) -- {{{
    for k, v in pairs(self) do
      if u.deepEqual(k, x) then return v end
    end
  end -- }}}

  assert(tbl ~= nil, 'table to groupBy must not be nil')
  by = by or u.identity -- assume identity if no 'by' is passed

  local function reducer(acc, curr)
    local res

    if u.types.fn(by) then
      res = by(curr)

    elseif u.types.string(by) then
      res = curr[by]
    end

    if not acc[res] then
      acc[res] = {}
    end

    if curr then
      table.insert(acc[res], curr)
    end
    return acc
  end

  -- IMPORTANT: grouping equal elements together *requires* indexByEquality to be set to __index fn
  local accumulator = setmetatable({}, {__index = indexByEquality})

  -- Do the reduction!
  local res = u._reduce(reducer, accumulator)(tbl)

  return u.types.tbl(u.keys(res)[1]) -- if keys are table
            and u.values(res)        -- return values instead
            or res                   -- otherwise, just send back the normal result
end -- }}}
table._groupBy = u.curry(u.flip(table.groupBy))

function table.setPath(path, val, tbl) -- {{{
  -- FROM: https://www.lua.org/pil/14.1.html
  tbl = tbl or _G -- start with the table of globals
  for w, d in string.gmatch(path, "([%w_]+)(.?)") do
    if d == "." then -- not last field?
      tbl[w] = tbl[w] or {} -- create table if absent
      tbl = tbl[w] -- get the table
    else -- last field
      tbl[w] = val -- do the assignment
    end
  end
end -- }}}
function table.getPath(path, tbl, isSafe) -- {{{
  -- FROM: https://www.lua.org/pil/14.1.html
  --[[ TEST {{{
  x = { name = 'johnDoe', path = { other = { more = 33 } } }

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

  isSafe = isSafe or true
  local v = tbl or _G -- default to global tabl if tbl not provided
  local res = nil

  for w in path:gmatch('[%w_]+') do
    if not u.types.tbl(v) then
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

return u

