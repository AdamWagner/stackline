--[[
  == Proxyable mxin ==
  TESTS: ./spec/proxy2_spec.lua
  Many thanks to @darmyn for https://github.com/darmyn/MetaProxy for the inspiration
  SEE ALSO: https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_meta.lua#L38
]]

local Observable = require 'classes.Observable'

-- TODO: Move this to a more appropriate location?
hsInstanceToTable = function(hsInstance) --[[ {{{
  `rawget` expects a table.
  This getter enables Proxy to wrap hammerspoon instances, which are userdata.
  This is done by looking up keys on the userdata's *metatable* instad of trying to index the userdata itself.
  Then, if the value at `k` is a function, it is called with the userdata as the 1st arg.
  ]]
  if u.isnt.hsInstance(hsInstance) then return hsInstance end
  local mt = getmetatable(hsInstance) or {}

  local indexer = function(_, k)
    local val = mt[k]
    local result = u.is.callable(val)
      and val(hsInstance)
      or val
    if u.is.hsInstance(result) then
      return hsInstanceToTable(result)
    end

    return result
  end

  return setmetatable({}, {__index = indexer })
end -- }}}

local function accessorLookup(kind, key, tbl) -- {{{
  if u.isnt.str(key) then return end
  local accessor = tbl[kind..key:capitalize()] or tbl[kind .. '_' .. key]
  return u.is.callable(accessor) and accessor
end -- }}}

local Proxyable = {__name = 'Proxyableable'}

function Proxyable.new(raw, opts)
  raw, opts = raw or {}, opts or {}

  local proxy = {
    _isProxyable = true,
    _validator = Proxyable.validators[tostring(opts._validator)] or opts._validator or function() return true end,
    _filter = Proxyable.validators[tostring(opts._filter)] or opts._filter or function() return true end,
    _get = opts._get,
    _set = opts._set,
    _raw = function() return raw end
  }

  --[[ When accessing a nil val in `proxy.bind` table, a new observable will be created.
       This provides syntatic sugar for binding handlers to specific keys in the proxy:
       -> proxy.bind.name(function(k,v,o) ... end)
  ]]
  proxy.bind = u.inject({}, function(t,k)
    t[k] = Observable:new()
    return t[k]
  end)

  setmetatable(proxy, {
    __index = function(_,k)
      if not proxy._validator(k, nil, raw[k]) then return end
      local getter = accessorLookup('get', k, raw)

      if getter then
        return getter(raw, v)
      elseif opts._get then
        return opts._get(raw, k, v)
      else
        return raw[k]
      end

    end,

    __newindex = function(_,k,v)
      local o = proxy[k]
      -- print('proxy validator for ', k, ' to ', v, ' : ', proxy._validator(k,v,o))
      if not proxy._validator(k,v,o) then return end

      local setter = accessorLookup('set', k, raw)

      --[[ This is why `proxy` is passed to the setter as the 3rd arg because
           if other keys are set in a setter, *and* should trigger change events, 
           then they must be set on the *proxy*, not the raw table.  ]]
      if setter then 
        setter(raw, v, proxy)
      elseif opts._set then
        opts._set(raw, k, v)
      else
        raw[k] = v
      end

      proxy.bind[k]:publish(k,v,o,raw) -- emit `set` event. If any handlers have been bound to `k` via `proxy.bind[k]`, they'll be called with args given to `publish.
      proxy.bind['__all']:publish(k,v,o,raw) -- call any handlers that are listening to the special '__all' key

      return proxy
    end,

    __pairs = function()
      return pairs(u.filterKeys(raw, proxy._filter))
    end
  })

  return proxy
end


Proxyable.validators = { -- {{{
 sameType = function(k,v,o)
    if o==nil then return true end
    if type(v)~=type(o) and v~=nil then
      printf('Must set key "%s" to type "%s", not "%s"', k, type(o), type(v))
      return false
    end
    return true
  end,

  noFunctions = function(k,v,o) return u.isnt.func(o) and u.isnt.func(v) end,
} -- }}}

Proxyable.filters = { -- {{{
  noPrivate = function(v,k)
    if v==nil then return false end
    if u.is.str(k) then
      return not (k:sub(1,1)=='_' or k=='log')
    end
    return true
  end
} -- }}}

return Proxyable
