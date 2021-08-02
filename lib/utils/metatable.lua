local M = {}

function M.methods(obj, ignoreMt) --[[ {{{
  = TEST =
    w = stackline.manager:get()[1].windows[1]
    methods = u.methods(w)
  ]]
  obj = obj or M
  local res = filter(obj, u.is.func)

  if ignoreMt then return res end

  local mt = getmetatable(obj)
  if mt and mt.__index then
    extend(res, M.methods(mt.__index))
  end
  return res
end -- }}}

function M.weakKeys(input) -- {{{
  local t = input or {}
  local mt = getmetatable(t)
  mt.__mode = 'k'
  return setmetatable(t, mt)
end -- }}}

function M.copyMetaMethods(from, to) --[[ {{{
  Copy metamethods from super to cls
  `from` is typically the super, and `to` is the subclass.
  This ensures metamethods defined on the class will be inherited by instances
  (normal methods can be looked up via instance's mt.__index, but
  metamethods cannot be inherited this way) ]]
  for _, k in ipairs(allowed_metamethods) do
    to[k] = from[k]
  end
end -- }}}

function M.getmetamethod(t, f) -- {{{
  local mt = getmetatable(t)
  return mt and rawget(mt,f)
end -- }}}

function M.setmetatablekey(t,k,v) -- {{{
  local mt = getmetatable(t) or {}
  rawset(mt, k, v)
  return setmetatable(t, mt)
end -- }}}

function M.filterMt(tbl) -- {{{
  if not M.istable(tbl) then return tbl end

  local mt = {}
  local not_mt = {}
  for k,v in pairs(tbl) do
    if ismetamethod(k) then
      mt[k] = v
    else
      not_mt[k] = v
    end
  end
  local original_mt = getmetatable(tbl)
  return setmetatable(mt, original_mt),  setmetatable(not_mt, original_mt)
end -- }}}

function M.rejectMt(tbl) -- {{{
  local is_mt, not_mt = M.filterMt(tbl)
  return not_mt
end -- }}}

function M.indexBy(tbl, matcher, groupVals) --[[ {{{
  When looking up a table key, return value for which matcher(key) is `true`.
  When setting a table value at key, overwrite or "group" value for which matcher(key) is true
  __eq() metamethod will drive equality comparison if set on keys that are tables.

  = NOTES = {{{
  The "simple" version from before this major update:
    function indexByEquality(self, x)
      for k, v in pairs(self) do -- CAUTION 2021-02-07: u.iter(self) results in stackoverflow. [Q]: Why?
        if u.deepEqual(k, x) then return v end
      end
    end
  }}}

  = TESTS =  {{{

  -- no groupVals
  g = u.indexBy({}, u.equal)
  g[{'a'}] = 'adam'
  g[{'a'}] = 'bob' ------- > { [{ "a" }] = "bob" }

  -- groupVals 
  g = u.indexBy({}, u.equal, true)
  g[{'a'}] = 'adam'
  g[{'a'}] = 'bob' ------- > { [{ "a" }] = { "bob", "adam" } }

  -- groupVals does not add duplicates
  g = u.indexBy({}, u.equal, true)
  g[{'a'}] = 'adam'------- > { [{ "a" }] = { "adam" } }
  g[{'a'}] = 'bob' ------- > { [{ "a" }] = { "bob", "adam" } }
  g[{'a'}] = 'bob' ------- > { [{ "a" }] = { "bob", "adam" } } ('bob' is not added again)
  g[{'a'}] = 'bobby' ------> { [{ "a" }] = { "bob", "adam", "bobby" } }
  }}}

  ]]
  tbl = tbl or {}
  matcher = matcher or u.equal

  local raw = tbl
  local mt = getmetatable(raw) or {}

  local function findMatchingKey(key) 
    return u.find(
      u.keys(tbl), 
      u.bind(matcher, key)
      )
  end

  local function indexByEquality(_, key)
    for extantKey, v in pairs(raw) do
      if matcher(extantKey, key) then 
        return v 
      end
    end
  end

  local function newindexByEquality(_, newkey, newval)
    local original = raw[newkey]
    local new

    if groupVals then
      if original then 
        table.insert(original, newval)
        return rawset(tbl, findMatchingKey(newkey), u.uniq(original))
      else
        return rawset(tbl, newkey, {newval})
      end
    end

    if original then
      rawset(tbl, findMatchingKey(newkey), new)
    else
      return rawset(raw, newkey, new)
    end
  end

  mt.__index = indexByEquality
  mt.__newindex = newindexByEquality

  return setmetatable(tbl, mt)
end -- }}}

function M.extend_mt(tbl, newmeta) -- {{{
  -- ALT: https://github.com/panhuan/tgyh/blob/master/client/lib/metatable.lua#L24
  local mt = getmetatable(tbl) or {}
  for k,v in pairs(newmeta) do
    if k ~= '__index' then -- only want to copy class metamethods OTHER than index
      rawset(mt, k, v)
    end
  end

  return setmetatable(tbl, mt)
end -- }}}

function M.mt_extend(t, new_mt) -- {{{
  -- This does several things that u.extend_mt() does not:
  --   1. It extends __index tables
  --   2. It recurses using getmetable(...) on the passed-in metatable itself
  if new_mt == nil then return t end

  local mt = getmetatable(t) or {}

  for k, v in pairs(new_mt) do
    if k~='__index' and k~='__newindex' and type(v)=='function' then
      mt[k] = v
    end
  end

  -- Extend __index if both are tables and the given mt is not == to its index
  -- Don't overwrite keys
  if type(new_mt.__index)=="table" and type(mt.__index)=="table" and new_mt.__index~=new_mt then
    u.assignSafe(mt.__index, new_mt.__index)
  end

  -- Recurse with the metatable's metatable (and so on until nil)
  M.mt_extend(t, getmetatable(new_mt))
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

function M.deep_clear_metatables(tbl) --[[ {{{
Recursively removes metatables from all subtables but not from other object types.
  @tparam table tbl
  @treturn table The input table. *Doesn't* have a Table module metatable.
  @usage {{{
  local test = setmetatable({},{
  __index = function() print'first meta' return 1 end,
  })
  -- recursive
  test.test = test
  -- different
  test.foo  = setmetatable({},{
  __index = function() print'second meta' return 2 end,
  })

  -- metamethods will trigger additional printing
  local x = test[1]
  > first meta
  local x = test.test[1]
  > first meta
  local x = test.foo[1]
  > second meta

  Table.deep_clear_metatables(test)
  -- without metatables there is no printing (and also no values in this case).
  local x = test[1]
  local x = test.test[1]
  local x = test.foo[1]
  }}} ]]
  local seen = {}
  local function _clear(obj)
    -- if  type(obj) == 'table'
    if  isPlainTable(obj)
      and seen[obj] ~= true then
      seen[obj] = true
      debug_setmetatable(obj,nil)
      for k,v in pairs(obj) do
        _clear(k)
        _clear(v)
      end
    end
    return obj
  end
  return _clear(tbl)
end -- }}}

sub = string.sub
upper = string.upper

-- cache the names of the property getter/setter functions
setters = setmetatable( {}, {
  __index = function(self, k)
  if type(k)~="string" then return end
  end
})

getters = setmetatable( {}, { 
  __index = function(self, k)
    if type(k) ~= "string" then return end; 
  end
})


--[[

== TEST ==

x = {}

function CelciusToFarenheit(T)
  return (T * (9/5)) + 32
end
function FarenheitToCelcius(T)
  return ((T - 32) * 5) / 9
end


function x:setFarenheit(v) 
  print('setting temperature in F') 
  rawset(self, 'farenheit', v) 
  rawset(self, 'celcius', FarenheitToCelcius(v))
end

function x:setCelcius(v) 
  print('setting temperature in C') 
  rawset(self, 'celcius', v) 
  rawset(self, 'farenheit', CelciusToFarenheit(v))
end


r = u.makeAccessor(x)

]]


local function accessorLookup(kind, key, tbl)
  local accessor = tbl[kind..key:capitalize()]
  return u.is.callable(accessor) and accessor
end


M.metamethods = {
  __index = {

    -- TODO: update to use M.indexBy(...) builder
    withEquality = function(tbl, requestedKey) -- {{{
      for key, val in pairs(tbl) do -- CAUTION 2021-02-07: u.iter(self) results in stackoverflow. [Q]: Why?
        if u.equal(key, requestedKey) then return val end
      end
    end, -- }}}

    withGetters = function(self, k) -- {{{
      -- FROM: https://github.com/Mehgugs/tourmaline-framework/blob/master/framework/libs/oop/oo.lua
      local getKey = 'get'..tostring(k):gsub("^.",string.upper)
      if self[getKey] then
        return self[getKey](self)
      elseif self[k] then
        return self[k]
      end
    end -- }}}
  },

  __eq = {},

  __pairs = {},

}

return M
