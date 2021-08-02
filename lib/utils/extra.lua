local M = {}

function M.inject(t, lookup, mutateMt) --[[ {{{
  Inject 'hidden' key,value pairs into a table via metatable.
  'Hidden' keys aren't set directly on table & so will never be found via iteration. 'Hidden' keys can *only* be access explicitly.
  Does not overwrite actual key,values set on table.
  Works on tables with an existing metatable (even if mt.__index is used)
  If multiple values are injected at the same key, the most recently set value takes precedence

  ADAPTED FROM: https://github.com/peete-q/assets/blob/master/lua-modules/lib/metatable.lua
  SEE ALSO: https://github.com/MyMindWorld/Starbound_mods/blob/master/unpacked/interface/games/util.lua#L2

  @param t: Table that will be able to access k,v pairs in `lookup`
  @param lookup: Index func -or- table of k,v pairs that will be accessible on `t`
  @param mutateMt: Boolean. When true, `lookup` will be injected for *all siblings* of `t`
                  mutateMt true: `t` and ALL of its siblings have access to k,v pairs in `lookup`
                  mutateMt false: `t` no longer inherits changes made to original mt, but access to `lookup` is contained
  @test basic {{{
    x = { name = 'John', age = 33 }
    setmetatable(x, {__call = function() print('called "x"') end})
    u.inject(x, {job = 'farmer'})
    u.inject(x, {color = 'red'})
    u.inject(x, {type = 'Person'})
  }}}
  @test class instance, mutateMt=false {{{
    w = stackline.manager:get()[1].windows[1]
    w2 = stackline.manager:get()[1].windows[2]
    u.inject(w, { name = 'John' })
    assert(w.name=='John')
    assert(type(w)=='table') -- be sure to try to pretty-print the whole object. This is good at catching infinite __index loops
    assert(w2.name==nil)
  }}}
  @test class instance, mutateMt=true {{{
    -- use w1 and w2 from previous test
    w3 = stackline.manager:get()[1].windows[3]
    u.inject(w2, { name = 'Jane' }, true)
    assert(w2.name=='Jane')
    assert(w3.name=='Jane') -- siblings can access injected k,v's
    assert(w.name=='John') -- ... but `w` still has its own separate metatable that maps 'name' to 'John'
  }}} ]]
  -- Short circut if not given a table and a lookup table/func
  if u.isnt.tbl(t) or lookup==nil then return t end

  local mt = getmetatable(t) or {} -- get current metatable on `t`

  local idx_to_fn = function(idx)
    return u.is.func(idx)
      and idx
      or function(_,k) return idx[k] end
  end

  lookup = idx_to_fn(lookup)
  mt.__index = idx_to_fn(mt.__index)

  local newmeta = ((mutateMt) and mt or u.dcopy(mt)) or {}
  newmeta.__index = function(self, k)
    return
      lookup(self,k)
      or (mt.__index and mt.__index(self, k))
  end

  return setmetatable(t, newmeta)
end -- }}}

function M.flattenPath(tbl) -- {{{
  local function flatten(input, mdepth, depth, prefix, res, circ) -- {{{
    local k, v = next(input)
    while k do
      local pk = prefix .. k
      if not u.is.tbl(v) then
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

function M.aliasTableKeys(aliasLookup, keyFn, selfFn, tbl) -- {{{
  keyFn = keyFn or M.identity   -- unconditionally transform the key (e.g., remove 's' from string)
  selfFn = selfFn or M.identity -- transform self before doing lookup (e.g., try looking in a child table)

  local __args = {aliasLookup, keyFn, selfFn, tbl}

  if type(tbl)~='table' then return tbl end

  setmetatable(tbl, {
    __index = function(self, key)
      xform_key = keyFn(key)
      local k = aliasLookup[key] or aliasLookup[xform_key] or xform_key
      return rawget(selfFn(self), k)
    end
  })

  return tbl -- Not necessary to return anything, since setmetatable(t) mutates 't', but we do anyway
end -- }}}

function M.makeTypeMetatable(builtin)  --[[ {{{
  Invert the key,val pairs of builtin to get a reverse-lookup
  If a table modded with this fn can't find a key on its own, it will use
  this lookup table to map the given key to an alternative key ]]
  local aliasLookup = u.invert(builtin)

  -- Transform lookup string before indexing `u.is` and even the root `u` module
  -- Strip trailing "s" (to ignore pluralization) & leading "is"
  local key_fn = function(key)
    key = key:gsub('s$',''):gsub('^is','')
    return key
  end

  -- Transform self to try to find key within child 'is' table
  local self_fn = function(self)
    return rawget(self, 'is') or self
  end

  -- Partially apply the key lookup table + key/self xformation fns
  -- The last remaining arg to u.aliasTableKeys() will be the *tbl*
  local addTypecheckAliases = u.curry(u.aliasTableKeys)(aliasLookup, key_fn, self_fn)

  return addTypecheckAliases
end  -- }}}

function M.groupByInnerKeys(tbl) -- {{{
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
end -- }}}

function M.task_cb(fn) -- wrap callback given to hs.task {{{
  return function(...)
    local out = {...}

    local is_hstask = function(x) -- {{{
      return #x==3
        and tonumber(x[1])
        and u.is.str(x[2])
    end -- }}}

    if is_hstask(out) then
      local stdout = out[2]

      if u.is.json(stdout) then
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

-- WIP
function M.switch()
  -- https://github.com/kitsunies/switch.lua
  local switch = {}
  switch.__index = switch
  switch.__call = function(self, v)
    local c = self._callbacks[v] or self._default
    assert(c, "No case statement defined for variable, and :default is not defined")
    c()
  end
  function switch:case(v, f)
    self._callbacks[v] = f
    return self
  end
  function switch:default(f)
    self._default = f
    return self
  end

  return setmetatable({_callbacks = {}}, switch) 
end

-- Class utils
function M.newindexer(class)-- {{{
  -- FROM: https://github.com/Mehgugs/tourmaline-framework/blob/master/framework/libs/oop/oo.lua
  return function(self,k,v)
    local setKey = 'set'..tostring(k):gsub("^.",string.upper)
    if class[setKey] then
      return class[setKey](self,v)
    else
      return rawset(self,k,v)
    end
  end
end-- }}}

function M.functions(obj, recurseMt)-- {{{
  --- Returns a sorted list of all methods names found in an object. If the given object
  -- has a metatable implementing an `__index` field pointing to another table, will also recurse on this
  -- table if `recurseMt` is provided. If `obj` is omitted, it defaults to the library functions.
  -- <br/><em>Aliased as `methods`</em>.
  -- @name functions
  -- @param[opt] obj an object. Defaults to Moses library functions.
  -- @return an array-list of methods names
  recurseMt = recurseMt or true
  obj = obj or M
  local _methods = {}
  for key, value in pairs(obj) do
    if type(value) == 'function' then
      _methods[#_methods+1] = key
    end
  end
  if recurseMt then
    local mt = getmetatable(obj)
    if mt and mt.__index then
      local mt_methods = M.functions(mt.__index, recurseMt)
      for k, fn in ipairs(mt_methods) do
        _methods[#_methods+1] = fn
      end
    end
  end
  return _methods
end-- }}}

function M.containsAny(t1, t2)-- {{{
  t2 = u.wrap(t2)
  for _,v1 in ipairs(t1) do
    if M.contains(t2, v1) then
      return true
    end
  end
  return false
end-- }}}

function M.containsAll(t1, t2)-- {{{
  t2 = u.wrap(t2)
  for _,v in ipairs(t2) do
    if not M.contains(t1, v) then
      return false
    end
  end
  return true
end-- }}}

function M.fpairs(fn, t) -- {{{
  return u.rawpairs(u.filter(t, fn))
end -- }}}

function M.track(t, k)
  local mt = { -- create metatable
    __index = function (tt, kk)
      if k==nil or k==kk then
        print("*access to element " .. tostring(kk))
      end
      return t[kk] -- access the original table
    end,
    __newindex = function (tt, kk, v)
      if k==nil or k==kk then
        print("*update of element " .. tostring(kk) .. " to " .. tostring(v))
      end
      t[kk] = v -- update original table
    end,
  }

  local proxy = {}
  setmetatable(proxy, mt)
  return proxy
end

function M.keyBy(t, fn)
  -- FROM: https://github.com/CodeKingdomsTeam/rodash/blob/master/src/Tables.lua#L174
  local result = {}
  for i, v in pairs(t) do
    local key = fn(v, i)
    if key~=nil then result[key] = v end
  end
  return result
end

function countOccurences(t, counts)
  counts = counts or {}
  for _, v in pairs(t) do
    if type(v)=='table' then
      if counts[v] then
        counts[v] = counts[v] + 1
      else
        counts[v] = 1
        countOccurences(v, counts)
      end
    end
  end
  return counts
end



function M.dive(t, fn)
  -- ADAPTED FROM: https://github.com/mnemnion/orb/blob/master/lib/util.lua
  -- FIXME: does not work (stack overflow)
  cache = cache or {}
  local res = {}

  local function recursor(t)
    for k,v in pairs(t) do
      if type(v)=='table' then
        if cache[v] then break end
         recursor(v)
      end
      cache[v] = fn(v,k)
      table.insert(res, cache[v])
    end
  end

  recursor(t)

  return res
end



function M.gather(iterator, ...)
  -- @exmaple
  --  r = u.gather(u.rawpairs, ws)
  --  r = u.gather(pairs, ws)
  local res = {}
  for k,v in iterator(...) do
    res[k] = v
  end
  return res
end

-- INSPO FB ARCHIVE UTILS
-- https://github.com/facebookarchive/fblualib/blob/master/fblualib/util/fb/util/multi_level.lua
-- https://github.com/facebookarchive/fblualib/blob/master/fblualib/util/fb/util/reactor.lua


-- https://github.com/facebookarchive/fblualib/blob/master/fblualib/util/fb/util/init.lua#L281
-- Determine the longest prefix among a list of strings
-- TODO: Can I replace the levenstein distinct algo used for auto-suggest in configmanager.lua?
local function longest_common_prefix(strings)
  if #strings == 0 then
    return ''
  end
  local prefix = strings[1]
  for i = 2, #strings do
    local s = strings[i]
    local len = 0
    for j = 1, math.min(#s, #prefix) do
      if s:sub(j, j) == prefix:sub(j, j) then
        len = len + 1
      else
        break
      end
    end
    prefix = prefix:sub(1, len)
    if len == 0 then
      break
    end
  end
  return prefix
end

function M.privatize(source) --[[ {{{
  Returns a copy of _source_, ensuring each key starts with an underscore `_`.
  Keys which are already prefixed with an underscore are left unchanged.
  @example {{{
    privates = u.privatize({ [1] = 1, public = 2, _private = 3 })
    privates --> {_1 = 1, _public = 2, _private = 3}
  }}} ]]
  return M.keyBy(source, function(_, key)
    local stringKey = tostring(key)
    return string.startsWith(stringKey, "_") and stringKey or "_" .. stringKey
  end
  )
end -- }}}

function M.iterator(f, value, n) --[[ {{{
  Produces an iterator which repeatedly apply a function `f` onto an input.
  Yields `value`, then `f(value)`, then `f(f(value))`, continuously.
  @name iterator
  @param f a function
  @param value an initial input to `f`
  @param[opt] n the number of times the iterator should run
  @return an iterator function
  ]]
  local cnt = 0
  return function()
    cnt = cnt + 1
    if n and cnt > n then return end
    value = f(value)
    return value
  end
end-- }}}

function M.array_of(type_)
  -- Returns predicate checking that value is an array with
  -- elements of type.
  -- FROM: https://github.com/MilanVasko/luacheck/blob/master/src/luacheck/utils.lua
   return function(x)
      if type(x) ~= "table" then
         return false
      end

      for _, item in ipairs(x) do
         if type(item) ~= type_ then
            return false
         end
      end

      return true
   end
end

function M.flyweight() --[[ {{{
  Originally to save memory, the flyweight pattern is useful in lua to ensure 2 tables with same data are always equal by reference.
  See more: https://luazdf.aiq.dk/fn/flyweightstore.html

  This function interns the list of arguments, i.e. it generates a reference table `refTab` for each possible list. When
  it is called multiple times with the same list, it will return the same reference.  All the reference are automatically
  garbage collected when no more used.

  == Example ==
  local intern = require 'intern'
  local int = intern()
  local a = int( 1, nil, 0/0, 3 )
  local b = int( 1, nil, 0/0, 2 )
  local c = int( 1, nil, 0/0, 2 )
  assert( a ~= b )
  assert( b == c )
  ]]
  local NIL, NAN = {}, {}
  local internmeta = {
    -- __index = function() error('Can not access interned content directly.', 2) end,
    __newindex = function() error('Can not cahnge or add contents to a intern.', 2) end,
  }

  local internstore = setmetatable( {}, { __mode = "kv" } )

  -- A map from child to parent is used to protect the internstore table's contents.
  -- In this way, they will he collected only when all the children are collected in turn.
  local parent = setmetatable( {}, { __mode = 'k' })

  return function( ... )
    local currentintern = internstore

    for a = 1, select( '#', ... ) do
      local tonext = select( a, ... ) -- Get next intern field. Replace un-storable contents.
      if tonext ~= tonext then tonext = NAN end
      if tonext == nil then tonext = NIL end

      -- Get or create the correspondent sub-intern
      local subintern = rawget( currentintern, tonext )

      if subintern == nil then
        subintern = setmetatable( {}, internmeta )
        parent[subintern] = currentintern
        rawset( currentintern, tonext, subintern )
      end

      currentintern = subintern
    end
    return currentintern
  end
end -- }}}

local tuplefactory = M.flyweight()

function M.tuple( ... ) -- {{{
  -- Adapted from: https://github.com/aiq/luazdf/blob/master/tab/tuple/tuple.lua#L50
  -- Improvements: Add iterator metamethods & remove `n` field
  -- == TEST ==
  -- t1 = u.tuple('John', 'one')
  -- t2 = u.tuple('John', 'one')
  -- t3 = u.tuple('Jane', 'three')

  -- t1 == t2 -- -> true (both t1 and t2 refer to exactly the same table underneath - no need to "deep compare")
  -- t1 == t3 -- -> false
  local tupleTable = tuplefactory(...)
  if not getmetatable(tupleTable).__type then -- First time initialization
    local fields = {...}
    setmetatable(tupleTable, {
      __type = 'tuple',
      __index = function(t, k) return fields[k] end,
      __newindex = function(t, k) return error('can not change tuple field', 2) end,
      __pairs = function(t) return pairs(fields) end,
      __ipairs = function(t) return ipairs(fields) end,
    })

  end
  return tupleTable
end -- }}}

local distinctTableFactory = M.flyweight()

function M.distinct(tbl) -- {{{
  -- Adapted from: https://github.com/aiq/luazdf/blob/master/tab/tuple/tuple.lua#L50
  -- Improvements: Add iterator metamethods & remove `n` field
  -- == TEST ==
  -- t1 = u.tuple('John', 'one')
  -- t2 = u.tuple('John', 'one')
  -- t3 = u.tuple('Jane', 'three')

  -- t1 == t2 -- -> true (both t1 and t2 refer to exactly the same table underneath - no need to "deep compare")
  -- t1 == t3 -- -> false
  local distinctTable = distinctTableFactory(unpack(tbl))
  if not getmetatable(distinctTable).__type then -- First time initialization
    local fields = {unpack(tbl)}
    setmetatable(distinctTable, {
      __type = 'distinct_table',
      __index = function(t, k) return fields[k] end,
      __newindex = function(t, k) return error('can not change tuple field', 2) end,
      __pairs = function(t) return pairs(fields) end,
      __ipairs = function(t) return ipairs(fields) end,
    })

  end
  return distinctTable
end -- }}}

function M.rect_grow(dx, dy, rect) -- {{{
  -- FROM: https://github.com/tboox/ltui/blob/master/src/ltui/rect.lua
  -- if 2nd arg has an `area` prop, then it's the rect,
  -- so `dy` is the same as `dx` (uniform growth).
  if u.is.num(dy.area) then
    rect = dy
    dy = dx
  end
  local res = u.dcopy(rect)
  res.x = res.x - dx / 2
  res.y = res.y - dy / 2
  res.w = res.w + dx
  res.h = res.h + dy
  return res
end -- }}}

function M.destructure(fieldMapping, tbl) --[[  {{{
  Adapted from https://github.com/tboox/ltui/blob/master/src/ltui/object.lua
  = EXAMPLE =
  local point = object { _init = {"x", "y"} }
  local p1 = point {1, 2}
  > p1 {x = 1, y = 2}
  ]]
  local res = {}
  for i, v in pairs(tbl) do
    if fieldMapping[i] ~= nil then
      res[fieldMapping[i]] = v
    else
      res[i] = v
    end
  end
  return res
end -- }}}

function M.autotable_alt1(depth) --[[ {{{
  FROM: https://github.com/Ruin0x11/OpenNefia/blob/develop/src/thirdparty/automagic.lua
  `depth` is how deep to auto-generate tables. If `depth == 0` (default 50) then there is no limit.
  The last table in the chain generated will itself not be an auto-table.

  == TEST ==
  x = u.autotable()
  val = { a=1, b=2, c=3, d=4 }
  u.assign(x.collection, val)
  assert.equal(val, x.collection)
  -- automatically create table `x.collection` when not found
  -- => { collection = { a=1, b=2, c=3, d=4 } }
  ]]
  return setmetatable({}, {
    depth = depth or 50,
    __index = function(self, key)
      local mt,t  = getmetatable(self)
      local t = {}
      if mt.depth~=1 then
        setmetatable(t, { __index = mt.__index, depth = mt.depth - 1})
      end
      self[key] = t
      return t
    end,
  })
end -- }}}

function M.autotable_alt2(tab) -- {{{
  -- FROM: https://github.com/liuxuezhan/lxz_server/blob/master/lualib/base.lua
  -- == TEST ==
  --   x.one.two = {}
  --   x.one.two.three.four = {} -- -> attempt to index a nil value (field 'three')
  local mt_auto = {}
  mt_auto.__index = function(t, k)
    local new = setmetatable({}, mt_auto)
    rawset(t, k, new)
    return new
  end
  mt_auto.__newindex = function(t, k, v)
    v = type(v)=='table' and setmetatable(v, mt_auto) or v
    rawset(t, k, v)
  end
  return setmetatable(tab or {}, mt_auto)
end -- }}}

function M.autotable() -- {{{
  -- The approach here is pretty neat. 
  -- It's overkill for making an autotable that doesn't need its child tables to also be autoables.
  -- Still, could be useful for other things were we want to auto-set a parent that can be referenced via the metatable.

  -- ADAPTED FROM: https://github.com/jakelogemann/dotfiles.nvim/blob/main/lua/vimrc/fn/table.lua
  -- returns auto-vivicated table (can accept deeply-nested assignments without itermediate tables existing beforehand)

  -- == TEST ==
  --   x.one.two = {}
  --   x.one.two.three.four = {} -- -> attempt to index a nil value (field 'three')

  function assign(tab, key, val)
    local oldmt = getmetatable(tab)
    oldmt.parent[oldmt.key] = tab
    setmetatable(tab, meta)
    tab[key] = type(val)=='table'
      and setmetatable(val, meta)
      or val
  end

  function auto(tab, key)
    return setmetatable({}, {
      __index = auto,
      __newindex = assign,
      parent = tab,
      key = key
    })
  end

  meta = { __index = auto }

  return setmetatable({}, meta)
end -- }}}

return M

