-- luacheck: ignore 142 112
local log = hs.logger.new('utils', 'info')
log.i('Loading module: utils')

-- === Extend builtins ===
function string:split(p) -- {{{
    -- Splits the string [s] into substrings wherever pattern [p] occurs.
    -- Returns: a table of substrings or, a table with the string as the only element
    p = p or '%s' -- split on space by default
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
            elseif index==0 then
                temp = {self}
            end
            break
        end
    end

    return temp
end -- }}}

function string:trim() -- {{{
    return self
        :gsub('^%s+', '') -- trim leading whitespace
        :gsub('%s+$', '') -- trim trailing whitespace
end -- }}}

function string:capitalize() -- {{{
	return self:sub(1,1):upper()..self:sub(2)
end -- }}}

function table.slice(array, from, to) -- {{{
    local t = {}
    for k = from or 1, to or #array do
        t[#t+1] = array[k]
    end
    return t
end -- }}}

function printf(s, ...) -- {{{
    print(string.format(s,...))
end -- }}}

unpack = unpack or table.unpack

-- === utils module ===
local u = {}
u.identity = function(val) return val end

function u.unwrap(tbl) --[=[ {{{
  Recurseively flatten 'redundant' tables
  Distinct from `u.flatten()` as it preserves non-redundant tables
  == EXAMPLES == {{{
  u.unwrap( {1,2} )   -> { 1, 2 } · Does nothing when there's more than 1 element
  u.unwrap( {1} )     -> 1        · Returns plain-old '1'
  u.unwrap( {{1}} )   -> 1        · Same; The wrapping table is 'redundant'
  u.unwrap( {{1,2}} ) -> 1        · {1,2}; The 1st wrapping table is redundant, but the inner table is the desired value, and so not unpacked into multiple retvals.

  u.unwrap( {{name='me'}} )   -> {name='me'}
  u.unwrap( {{name='me'},2} ) -> {{name='me'},2}
  }}} ]=]
   -- Use u.len (vs #tbl) to count non-sequential keys
   -- type(...) only checks the 1st arg. E.g., type(1, {}) == 'number'
   while u.len(tbl)==1 and type(tbl)=='table' do
      tbl = tbl[1]
   end
   return tbl -- otherwise return the original tbl
end -- }}}

function u.wrap(...) --[[ {{{
   Ensure that all arguments are wrapped in a table
   If the 1st and only arg is a table itself, it will be returned as-is
   == EXAMPLES == {{{
   a = u.wrap(1,2,3,4)                                -> { 1, 2, 3, 4 }
   b = u.wrap({1,2,3,4})                              -> { 1, 2, 3, 4 }
   c = u.wrap({name = 'johnDoe'}, {name = 'janeDoe'}) -> { { name = "johnDoe" }, { name = "janeDoe" } }
   d = u.wrap({ name = 'johnDoe' }, 1,2,3)            -> { { name = "johnDoe" }, 1, 2, 3 }
   }}} ]]
   return u.unwrap({...})
end -- }}}

-- == Alias hs.fnutils methods ==
--[[ These fns aren't used because they don't meet my needs as-is.
    u.each         = hs.fnutils.each
    u.map          = hs.fnutils.map
    u.filter       = hs.fnutils.filter
    u.contains     = hs.fnutils.Contains
]]
u.reduce       = hs.fnutils.reduce
u.concat       = hs.fnutils.concat
u.copy         = hs.fnutils.copy
u.sortByKeys   = hs.fnutils.sortByKeys
u.sortByValues = hs.fnutils.sortByKeyValues

u.partial      = hs.fnutils.partial
u.bind         = hs.fnutils.partial -- alias'partial()' to 'bind()'

u.some         = hs.fnutils.some
u.any          = hs.fnutils.some -- alias 'some()' as 'any()'
u.all          = hs.fnutils.every -- alias 'every()' as 'all()'

-- Replaces hs.fnutils.contains b/c: compares by u.equal & searches deeply into nested tables
function u.contains(t, needle) --[[ {{{
    == TESTS == {{{
    u.contains({1,2,3}, 2) -- -> true
    u.contains({1,2,3}, 4) -- -> false

    haystack = {{name = 'cindy'}, {name = 'john'}, {{id=1}, {id=2}, {id=3}}, 1, 2, 3}
    t1 = {name  = 'john'}
    t2 = {name  = 'johnDo'}
    t3 = 'john'
    t4 = 2
    t5 = {id=2}
    t6 = {id=9}

    u.contains(haystack, t1) -- -> true
    u.contains(haystack, t2) -- -> false
    u.contains(haystack, t3) -- -> true
    u.contains(haystack, t4) -- -> true
    u.contains(haystack, t5) -- -> true
    u.contains(haystack, t6) -- -> false
    }}} ]]
    for k, v in pairs(t) do
        if u.equal(v, needle) then return true end
        if type(v)=='table' then
            if u.contains(v, needle) then return true end
        end
    end
    return false
end 
u.include = u.contains
u.includes = u.contains
-- }}}

-- Replaces hs.fnutils.each b/c: Passes key as 2nd param
function u.each (t, f) -- {{{
    if type(t)~='table' or type(f)~='function' then return t end
    for k, v in pairs(t) do
        f(v, k)
    end
end -- }}}

function u.rawpairs(tbl)  -- {{{
   return next, tbl, nil
end  -- }}}

function u.length(t) -- {{{
   local _t = type(t)
   local countable = (_t=='table' or _t=='string')
   local useBuiltin = (u.isarray(t) or _t=='string')
   if not countable then return 0 end
   if useBuiltin then return #t end -- u.isarray short-circuits quickly, so this should be faster overall? Should benchmark
   local len = 0
   for _ in next, t do
      len = len + 1
   end
   return len
end
u.len = u.length -- alias as u.len
-- }}}

function u.reverse(tbl) -- {{{
    -- Reverses values in a given array. The passed-in array should not be sparse.
    local res = {}
    for i = #tbl,1,-1 do
        res[#res+1] = tbl[i]
    end
    return res
end -- }}}

function u.isnum(x) -- {{{
    return type(x) == 'number'
end -- }}}

function u.istable(x) -- {{{
    return type(x) == 'table'
end -- }}}

function u.isstring(x) -- {{{
  return type(x) == 'string'
end -- }}}

function u.isbool(x) -- {{{
    return type(x) == 'boolean'
end -- }}}

function u.isfunc(x) -- {{{
    return type(x) == 'function'
end -- }}}

function u.isarray(x) -- {{{
   if x==nil or type(x)~='table' then return false end
   local i = 0
   for k in pairs(x) do
      i = i + 1
      if x[i] == nil then return false end
   end
   return true
end -- }}}

function u.isjson(x) -- {{{
    return u.isstring(x) and x:find('{') and x:find('}')
end -- }}}

function u.iscallable(x)  -- {{{
    if type(x)=='function' then return true end
    local mt = getmetatable(x)
    return mt and mt.__call~=nil
end -- }}}

local function iteratee(x) --[[ {{{
  Shortcuts for writing common map & filter funcs by simply passing a string or table.
  This turns out to be extremely useful.
  See also https://github.com/rxi/lume#iteratee-functions.
     - u.map(x, 'key')                           -> get list of values at 'key'
     - u.filter(x, {key1='special', key2=true }) -> get collection elements that match the key,val pairs specified
  ]]

  if x==nil then return u.identity end -- Use identity fn if 'x' is nil
  if u.iscallable(x) then return x end   -- Return as-is if 'x' is callable

  --[[ If it's a table, treat as filter specification.
      == EXAMPLE ==
      items = {
        {height = 10, weight = 8, price = 500},
        {height = 10, weight = 15, price = 700},
        {height = 15, weight = 15, price = 3000},
        {height = 10, weight = 8, price = 3000},
      }
      u.filter(items, {height = 10}) -- => {items[1], items[2], items[4]}
      u.filter(items, {weight = 15}) -- => {items[2], items[3]}
      u.filter(items, {prince = 3000}) -- => {items[3], items[4]}
      u.filter(items, {height = 10, weight = 15, prince = 700}) -- => {items[2]}
  ]]
  -- TODO: If table is list-like & values are strings, delegate to u.pick(...)
  -- TODO: Doesn't work with 'map': u.map(tbl, {'id', 'app', 'frame'}) does not pluck id,app,frame keys
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

local function makeMapper(iter) --[[ {{{
   Factory fn to produce mappers
   NOTE: This exists primarily because `hs.fnutils.map` *only* maps values, not keys. Also, the `iteratee` capabilities are nice.
   NOTE: return v, k from map fn to map *both* values & keys
   mapping fn prototyped as `f (v, k)`

   Adapted from: https://github.com/Yonaba/Moses/blob/master/moses.lua#L395
  ]]

  iter = iter or u.rawpairs -- default to 'rawpairs', but can be given custom iter

  return function(t, fn, deep)
    t = t or {}
    deep = deep or false
    fn = iteratee(fn)

    local res = {}

    for k,v in iter(t) do
      local r1, r2 = fn(v, k)
      local newKey = r2 and r1 or k  -- If 2nd retval nil, use original key 'k'
      local newVal = r2 and r2 or r1 -- If 2nd retval not nil, *newVal* is **second** retval, otherwise the first

      -- If 'deep' is true, recursively map tables assign result to res tbl
      --[[ FIXME: I don't think `deep` is working as expected; it requires `fn` to do a lot of type checking since we might pass it a table, or a k,v pair
           DEEP MAP EXAMPLES:
           https://github.com/ami-megarac/MORF-REST-Server/blob/43c41f98018ff64ed371cbc84d1d625124336f38/app/utils.lua#L257
           https://github.com/dyne/Zenroom/blob/e781a261b626494043b43f7ba9ed018e7bb7d59a/src/lua/zenroom_common.lua#L308
        ]]
      res[newKey] = (deep and type(newVal)=='table')
        and fn(newVal, fn, deep)
        or newVal
    end

    return res
  end
end -- }}}

--[[ u.map(t, fn, [deep]) NOTES {{{
== Setup by creating stackline window objects ==
ws = u.map(hs.window.filter(), stackline.window:call('new'))

== Pluck keys of child tables with string 'fn' arg: ==
appnames = u.map(ws, 'app')
-> { "Hammerspoon", "Google Chrome", "Google Chrome", "kitty", "kitty" }

TODO: Pass multiple string values to filter each child table to those keys:
appnames_and_ids = u.map(ws, 'app', 'id')
-> { {id=123, app="Hammerspoon"}, {id=456, app="Google Chrome", ...}

 }}} ]]
u.map = makeMapper(pairs) -- use as u.map(tbl, func, [deep])
u.imap = makeMapper(ipairs)

function u.filter(t, fn) -- {{{
   --[[ {{{ NOTES
   == Setup by creating stackline window objects ==
   function new_win(w) return stackline.window:new(w) end
   ws = u.map(stackline.wf:getWindows(), new_win)

   == Filter by specifying key,val pairs in table ==
   only_kitty = u.filter(ws, { app = 'kitty'})

   == Filter by specifying key,val pairs in table ==
   only_kitty = u.filter(ws, { app = 'kitty'})              -- single key,val
   only_kitty = u.filter(ws, { app = 'kitty', id = 532)     -- multiple key,val

   TODO: Support nested functions as values.
   E.g., to find elements with app = kitty and a title that contains 'nvim':
       u.filter(ws, {
           app = 'kitty',
           title = function(x) return x:find('nvim') end,
       })

   }}} ]]
   fn = iteratee(fn)
   return hs.fnutils.filter(t, fn)
end -- }}} }}}

function u.ifilter(t, fn) -- {{{
   -- NOTES: See u.filter
   fn = iteratee(fn)
   return hs.fnutils.ifilter(t, fn)
end -- }}} }}}

function u.filterKeys(t, fn) -- {{{
    local matches = {}
    for k, v in u.rawpairs(t or {}) do
        if fn(v, k) then matches[k] = v end
    end
    return matches
end -- }}}

function u.keys(t) -- {{{
    local rtn = {}
    for k in pairs(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end -- }}}

function u.values(t) -- {{{
    local values = {}
    for _k, v in pairs(t) do
        values[#values + 1] = v
    end
    return values
end -- }}}

-- TODO: Either improve or deprecate. Not very useful as-is
function u.find(t, val) -- {{{
    result = nil
    for k, v in pairs(t) do
        if k==val then
            result = v
        end
    end
    return result
end -- }}}

function u.uniq(tbl) -- {{{
    local res = {}
    for _, v in ipairs(tbl) do
        res[v] = true
    end
    return u.keys(res)
end -- }}}

function u.extend(t1, t2) -- {{{
    if not type(t2)=='table' then return t1 end
    t1 = type(t1)=='table' and t1 or {}
    for k, v in pairs(t2 or {}) do
        t1[k] = v
    end
    return t1
end -- }}}

function u.safeExtend(t1, t2) -- {{{
    if not type(t2)=='table' then return t1 end
    t1 = type(t1)=='table' and t1 or {}
    for k, v in pairs(t2 or {}) do
        if t1[k]==nil and v~=nil then
            t1[k] = v
        end
    end
    return t1
end -- }}}

function u.mergeOnKey(arr1, arr2, key) --[[
    t1 = { {id = 1, name = 'person1'}, {id = 2, name = 'person2'} }
    t2 = { {id = 1, age = 33 }, {id = 2, age = 28} }
    r = u.mergeOnKey(t1, t2, 'id') -- => {{ age=33, id=1, name="person1" },{age=28, id=2, name="person2" }}

    NOTE: Written to replace `query.mergeStackIdx()` in a more generic way. 
    This doesn't quite do it, tho: need to traverse `arr2` if it has a more deeply nested structure
    ]]
    for _, obj in ipairs(arr1) do
        for k,v in pairs(obj) do
            local other = u.find(arr2, obj[key])
            u.extend(obj, other)
        end
    end
    return arr1
end

function u.mergeOnto(extra, grouped, byKey, asKey) --[[ {{{
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

function u.cb(fn) -- {{{
    return function()
        return fn
    end
end -- }}}

function u.json_cb(fn) -- {{{
    -- wrap fn to decode json arg
    return function(...)
        return u.pipe(hs.json.decode, fn, ...)
    end
end -- }}}

function u.task_cb(fn) -- {{{
    -- wrap callback given to hs.task
    return function(...)
      local out = {...}

      local is_hstask = function(x) -- {{{
         return #x==3
            and tonumber(x[1])
            and u.isstring(x[2])
      end -- }}}

      if is_hstask(out) then
         local stdout = out[2]

         if u.isjson(stdout) then
            -- NOTE: hs.json.decode cannot parse "inf" values
            -- yabai response may have "inf" values: e.g., frame":{"x":inf,"y":inf,"w":0.0000,"h":0.0000}
            -- So, we must replace ":inf," with ":0,"
            local clean = stdout:gsub(':inf,',':0,')
            stdout = hs.json.decode(clean)
         end

         return fn(stdout)
      end

      -- fallback if 'out' is not from hs.task
      return fn(out)
   end
end -- }}}

function u.setfield(path, val, tbl) -- {{{
    log.d(('u.setfield: %s, val: %s'):format(path, val))

    tbl = tbl or _G -- start with the table of globals
    for w, d in path:gmatch('([%w_]+)(.?)') do
        if d=='.' then -- not last field?
            tbl[w] = tbl[w] or {} -- create table if absent
            tbl = tbl[w] -- get the table
        else -- last field
            tbl[w] = val -- do the assignment
        end
    end
end -- }}}

function u.getfield(path, tbl, isSafe) -- {{{
    -- NOTE: isSafe defaults to false
    log.d(('u.getfield: %s (isSafe = %s)'):format(path, isSafe))

    local val = tbl or _G -- start with the table of globals
    local res = nil

    for path_seg in path:gmatch('[%w_]+') do
        if not u.istable(val) then return val end -- if v isn't table, return immediately
        val = val[path_seg]                   -- lookup next val
        if (val~=nil) then res = val  end         -- only update safe result if v not null
    end

    return isSafe and val==nil
            and res -- return last non-nil value found
            or val  -- else return last value found, even if nil
end -- }}}

function u.toBool(val) -- {{{
    local t = type(val)

    if t=='boolean' then
        return val
    elseif t=='number' or tonumber(val) then
        return tonumber(val)>=1 and true or false
    elseif t=='string' then
        val = val:trim():lower()
        local lookup = {
            ['t'] = true,
            ['true'] = true,
            ['f'] = false,
            ['false'] = false,
        }
        return lookup[val]
    end

    print(string.format('toBool(val): Cannot convert %q to boolean. Returning "false"', val))
    return false
end -- }}}

function u.greaterThan(n) -- {{{
    return function(t)
        return #t > n
    end
end -- }}}

function u.roundToNearest(roundTo, numToRound) -- {{{
    return numToRound - numToRound % roundTo
end -- }}}

function u.p(data, howDeep) -- {{{
    -- local logger = hs.logger.new('inspect', 'debug')
    local depth = howDeep or 3
    if type(data)=='table' then
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    else
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    end
end -- }}}

function u.pheader(str) -- {{{
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
end -- }}}

function u.groupBy(t, f) --[[ {{{
    -- FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
    x = { 'string1', 1, {1,2,3}, 'string2', 4, {'string3'} }
    u.groupBy(x, type)
    ->  {
          number = { 1, 4 },
          string = { "string1", "string2" },
          table = { { 1, 2, 3 }, { "string3" } }
        }
    ]]
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

function u.copy(t, iter) -- {{{
    -- FROM: https://github.com/XavierCHN/go/blob/master/game/go/scripts/vscripts/utils/table.lua
    if not u.istable(t) then
        local copy = t
        return copy
   end
    iter = iter or pairs
    local copy = {}
    u.p(iter)
    for k, v in iter(t) do
       copy[k] = v
    end
    return copy
end -- }}}

function u.dcopy(obj, iter, seen) --[[ {{{
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
    ]]

    -- Handle non-tables and previously-seen tables
    if not u.istable(obj) then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively
    iter = iter or pairs
    seen = seen or {}
    local res = {}
    seen[obj] = res

    for k, v in iter(obj) do
        local key = u.dcopy(k, iter, seen)
        local val = u.dcopy(v, iter, seen)
        res[key] = val
    end

    local mt = u.copy(getmetatable(obj) or {})      -- Must copy the metatable to avoid mutating the actual mt on `obj`
    if iter == u.rawpairs then mt.__pairs = nil end -- Clear __pairs metamethod if u.rawpairs `iter` is given

    return setmetatable(res, mt)
end -- }}}

function u.sort(tbl, fn) -- {{{
    -- WANRING: Sorting mutates table
    fn = fn or function(x,y) return x < y end
    if u.isarray(tbl) then
        table.sort(tbl,fn)
    end
    return tbl
end -- }}}

function u.equal(a, b) --[[ {{{
    Adapted from: https://github.com/Yonaba/Moses/blob/master/moses.lua#L2786
    REVIEW: explore Interesting alternative from RBXunderscore: https://github.com/dennis96411/RBXunderscore/blob/master/RBXunderscore.lua#L1489
    == TESTS == {{{
    a = {name = 'john'}
    b = {name = 'john'}

    a1 = { {name = 'john'}, {name = 'cindy'} }
    b1 = { {name = 'john'}, {name = 'cindy'} }

    a3 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }
    b3 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }

    a4 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }
    b4 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 7 }

    u.equal(a, b) -- -> true
    u.equal(a1, b1) -- -> true
    u.equal(a2, b2) -- -> true
    u.equal(a3, b3) -- -> true
    u.equal(a4, b4) -- -> false

    }}} ]]

    local typeA, typeB = type(a), type(b)

    -- Equal if direct compare is `true`. Note this will use mt.__eq if present and equal on both args.
    if a==b then return true end

    -- Not equal if either arg is nil
    if a==nil or b==nil then return false end

    -- Not equal if not of same type
    if typeA~=typeB then return false end

    -- If either arg is not a table, return direct comparison
    if not u.all({a,b}, u.istable) then return (a==b) end

    -- == NOTE: At this point, we know *both args ARE tables*

    -- Not equal if args do not have same length
    if u.len(a)~=u.len(b) then return false end

    -- == NOTE: Now we have no choice but to compare each k,v in the table

    -- Before doing so, do a safe sort (sorts if array only) first
    -- FIXME: causes error: bad argument #2 to 'sort' (function expected, got number)
    -- u.each({a,b}, u.sort)

    -- Deep compare elements of `a` and `b`
    for k in pairs(a) do if not u.equal(b[k], a[k]) then return false end end

    -- Finally, make sure that `b` doesn't have keys that are missing in `a`
    for k in pairs(b) do if a[k]==nil then return false end end

    return true
end -- }}}

function u.allEqual(t, comp) -- {{{
    -- Compare the 1st element in `t` to the other elements
    -- Return true if all equal
    comp = comp or u.equal
    local _, first = next(t)
    for k, v in pairs(t) do
        if not comp(first, v) then return false end
    end
    return true
end -- }}}

function u.levenshteinDistance(str1, str2) -- {{{
    str1, str2 = str1:lower(), str2:lower()
    local len1, len2 = #str1, #str2
    local c1, c2, dist = {}, {}, {}

    str1:gsub('.', function(c) table.insert(c1, c) end)
    str2:gsub('.', function(c) table.insert(c2, c) end)
    for i = 0, len1 do dist[i] = {} end
    for i = 0, len1 do dist[i][0] = i end
    for i = 0, len2 do dist[0][i] = i end

    for i = 1, len1 do
        for j = 1, len2 do
            dist[i][j] =
                math.min(dist[i - 1][j] + 1,
                dist[i][j - 1] + 1, dist[i - 1][j - 1] + (c1[i]==c2[j] and 0 or 1))
        end
    end
    return dist[len1][len2] / #str2
end -- }}}

function u.flatten(arr) -- {{{
   -- If input is not an array, coerce it to one with u.values()
   -- WARNING: This discards top-level keys in the dict! If this causes problems, make a copy of `arr` first.
   arr = u.isarray(arr) and arr or u.values(arr)

   local res = { }

   local function flatten(arr)
      for _, v in ipairs(arr) do
         if u.isarray(v) then
            flatten(v)
         else
            table.insert(res, v)
         end
      end
   end

   flatten(arr)
   return res
end -- }}}

function u.flattenPath(tbl) -- {{{
    local function flatten(input, mdepth, depth, prefix, res, circ) -- {{{
        local k, v = next(input)
        while k do
            local pk = prefix .. k
            if not u.istable(v) then
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
            k, v = next(input, k)
        end
        return res
    end -- }}}

    local maxdepth = 0
    local prefix = ''
    local result = {}
    local circularRef = {[tostring(tbl)] = true}

    return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end -- }}}

-- Functional utils --
-- ~/Programming/Projects/stackline-scratchpad/June-2021/functional-test.lua
-- ~/Programming/Projects/stackline-july-2021-classes-&-proxy/lib/utils/init.lua
-- /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/fnutils/init.lua
-- TODO: CHECK OUT 'liter' - a really interesting looking iteration library with mucho control over how & what is iterated:
-- https://github.com/ok-nick/liter

function u.trycall(fn, ...) -- {{{
    if u.iscallable(fn) then
        return fn(...)
    else
        return ...
    end
end -- }}}

function u.bindTail(f, ...) --[[ {{{
    Bind all *except* the 1st argument.
    Useful for applying args to class methods in advance without needing to know the caller.
    Example:
        processWithOptions = u.bindTail(SomeClass.processData, opts)
    Then, in any instance that inherits from SomeClass:
        self.processWithOptions = processWithOptions
        self:processWithOptions()
    Or simply:
        processWithOptions(self)
    ]]
    local args = {...}
    return function(x)
        return f(x, unpack(args))
    end
end -- }}}

function u.curry(f, n) --[[ {{{
    @param f: the function to curry
    @param n: # of expected args for `f`. If omittied, will attempt to compute via `debug.getinfo()`.
    @returns: curried function or result of calling satisifed function
    == TESTS == {{{
    -- TEST: Args applied one-by-one
    x = function(a,b,c) return a + b + c end
    c = u.curry(x)
    a = c(1)(2)(3)
    assert(a == 6)
    -----------------------------
    -- TEST: Args applied in bulk
    x = function(a,b,c) return a + b + c end
    c = u.curry(x)
    b = c(1,2)(3)
    assert(b == 6)
    -----------------------------
    -- TEST: Args applied all at once
    x = function(a,b,c) return a + b + c end
    c = u.curry(x)
    c = c(1,2,3)
    assert(c == 6)
    -----------------------------
    }}} ]]
    n = n or debug.getinfo(f, 'u').nparams
    assert(n, "Must specify # of args as `u.curry(f, n)` if debug.getinfo isn't avaialble")
	if n == 0 then return f() end -- if no args remain, return result of calling fn
	if n == 1 then return f end -- if only 1 arg remains, return fn to call
	return function(...)
		return u.curry(
            u.bind(f, ...), -- new fn with given args partially applied
            n - select('#', ...) -- # of args still expected before `f` will execute
        )
	end
end -- }}}

function u.wrapFn(f, wrapper) --[[ {{{
    Wraps a function inside a wrapper. Allows the wrapper to execute code before and after function run.
    == EXAMPLE == {{{
    local greet = function(name) return "hi: " .. name end
    local greet_backwards = M.wrap(greet, function(f,arg)
      return f(arg) ..'\nhi: ' .. arg:reverse()
    end)
    greet_backwards('John')

    -- => hi: John
    -- => hi: nhoJ
    }}} ]]
    return function (...) return  wrapper(f,...) end
end -- }}}

function u.negate(f) -- {{{
   if type(f)=='function' then
       return function(...) return not f(...) end
   else
       return not f
   end
end -- }}}

function u.flip(func) -- {{{
    -- Flips the order of parameters passed to a function
    return function(...)
        return func(unpack(u.reverse({...})))
    end
end -- }}}

function u.pipe(f, g, ...) -- {{{

  local function simpleCompose(f1, g1)
    return function(...)
      return f1(g1(...))
    end
  end

  if (g==nil) then return f or u.identity end
  local nextFn = simpleCompose(g, f)

  return u.pipe(nextFn, ...)
end -- }}}

function u.applySpec(specs) --[[ {{{
    Returns a function which applies `specs` on args. This function produces an object having
    the same structure than `specs` by mapping each property to the result of calling its
    associated function with the supplied arguments.

    local stats = M.applySpec({
        min = function(...) return math.min(...) end,
        max = function(...) return math.max(...) end,
    })
    stats(5,4,10,1,8) -- => {min = 1, max = 10}
  ]]
  return function (...)
    local spec = {}
    for i, f in pairs(specs) do spec[i] = f(...) end
    return spec
  end
end -- }}}

function u.bind(func, ...) --[[ {{{
  Create a function with bound arguments.
  The bound function returned will call func with the arguments passed on to its creation.
  If more arguments are given during its call, they are appended to the original ones.

  SEE relatively simple verison that allows '_' placeholder values
  https://github.com/Yonaba/Moses/blob/master/moses.lua#L2423
  ]]

  local saved_args = { ... }
  return function(...)
    local args = { unpack(saved_args) }
    for _, arg in ipairs({...}) do
      table.insert(args, arg)
    end
    return func(unpack(args))
  end
end -- }}}

function u.bindMethods(obj, ...) --[[ {{{
    Binds methods to object. Mutates object.
    Whenever any of these methods is invoked, it always receives the object as its first argument.
    == EXAMPLE == {{{
    w = stackline.manager:get()[1].windows[1]
    methods = u(getmetatable(w)):filter(function(v) return type(v)=='function' end):keys():value()
    -- w.isFocused() -- => Error: attempt to index a nil value (local 'self')
    u.bindall(w, methods)
    }}} ]]
	local methodNames = u.wrap(...) -- supports both varargs or table
	for i, methodName in ipairs(methodNames) do
		local method = obj[methodName]
		if method then obj[methodName] = u.bind(method, obj) end
	end
	return obj
end -- }}}

function u.rearg(f, indexes) --[[ {{{
  Returns a function which runs with arguments rearranged. Arguments are passed to the returned function in the order of supplied `indexes` at call-time.
      f = M.rearg(function (...) return ... end, {5,4,3,2,1})
      f('a','b','c','d','e') -- => 'e','d','c','b','a'
  }}} ]]
  return function(...)
    local args = {...}
    local reargs = {}
    for i, arg in ipairs(indexes) do reargs[i] = args[arg] end
    return f(unpack(reargs))
  end
end

function u.invoke(t, meth) --[[
  Invokes method k at `k` on each `el` in a table
  OR returns property at `k` if `el[k]` is not callable.
  Adapted from moses: https://github.com/Yonaba/Moses/blob/master/moses.lua#L641
  == EXAMPLE == {{{
    ws = u.map(hs.window.filter(), stackline.window:call('new'))

    -- Call `frame` method on each window in `ws`
    frames = u.invoke(ws, 'frame')
    frames[1] -- -> hs.geometry.rect(1456.0,28.0,1501.0,1664.0)

    -- Get `id` prop on each window in `ws`
    ids = u.invoke(ws, 'id')
    ids[1] -- -> 35646

  }}} ]]

  return u.map(t, function(v, k)
    if u.iscallable(meth) then return meth(v,k) end
    if (type(v)=='table') then
      if v[meth] and u.iscallable(v[meth]) then
        return v[meth](v,k)
      else
        return v[meth]
      end
    end
  end)
end

function u.groupByInnerKeys(tbl) 
    -- From: https://github.com/CVandML/torchnet-master/blob/master/transform.lua#L242
    local res = {}
    for i, x in pairs(tbl) do
        for k, v in pairs(x) do
            if not res[k] then res[k] = {} end
            res[k][i] = v
            u.p(res)
        end
    end
    return res
end 

function u.methods(obj, ignoreMt) --[[ {{{
    = TEST =
        w = stackline.manager:get()[1].windows[1]
        methods = u.methods(w)
    ]]
    obj = obj or M
    local res = u.filter(obj,u.isfunc)

    if ignoreMt then return res end

    local mt = getmetatable(obj)
    if mt and mt.__index then
        u.extend(res, u.methods(mt.__index))
    end
    return res
end -- }}}


function u.weakKeys(input) -- {{{
    local t = input or {}
    local mt = getmetatable(t)
    mt.__mode = 'k'
    return setmetatable(t, mt)
end -- }}}


local Chain = {
    new = function(self, t, o)
        o = o or {}
        o.chained = t
        setmetatable(o, {__index = self})
        return o
    end,
    tap = function(self, f)
        if u.isarray(self.chained) then
            u.each(self.chained, f)
        else
            f(self.chained)
        end
        return self
    end,
    inspect = function(self) return self:tap(u.p) end,
    value = function(self) return self.chained end
}

u.each(u, function(fn, k)
    Chain[k] = function(self, ...)
        self.chained = fn(self.chained, ...)
        return self
    end
end)

function u.chain(t) return Chain:new(t) end

return setmetatable(u, {__call = function(u, t) return u.chain(t) end})
