-- INSPO
--    - https://github.com/sorcerykid/collections/blob/master/init.lua
--    - https://github.com/renatomaia/loop-collections/tree/master/lua/loop/collection
--    - https://github.com/kurapica/PLoop

---------------------------------
-- Author: Reyn
-- Date: 2016-07-01
-- Comment: HashMap
-- FROM: https://github.com/DoooReyn/LuaHashMap/blob/master/map.lua
---------------------------------

local format = string.format

-- TODO: remove duplication from lib.utils.typecheck ?? {{{
DATA_TYPE = table.keyAsValue('boolean', 'number', 'string', 'function', 'table', 'thread', 'nil')
function checkType(v, type)
  return v == DATA_TYPE[type]
end
local function checkHashType(tp)
  if not (tp == 'Mixed' or DATA_TYPE[tp]) then
    tp = 'Mixed'
  end
  return tp
end
-- END checktype ---------------------------------------------------------- }}}


function Map(ktype, vtype)
  local new_map = {}
  local __map__ = {}

  local __methods__ = {}
  local __key_type__, __value_type__ = checkHashType(ktype), checkHashType(vtype)
  function __methods__:typeOf()
    return string.format('HashMap<%s, %s>',__key_type__,__value_type__)
  end
  function __methods__:len()
    return table.len(__map__)
  end
  function __methods__:set(k, v)
    if (__key_type__ == 'Mixed' or type(k) == __key_type__)
      and (__value_type__ == 'Mixed' or type(v) == __value_type__) then
      __map__[k] = v
    end
  end
  function __methods__:unset(k)
    __map__[k] = nil
  end
  function __methods__:print()
    table.print(__map__)
  end
  function __methods__:filterKey(tp)
    print('filter key type:',tp)
    for k,v in pairs(__map__) do
      if not checkType(type(k), tp) then
        __map__[k] = nil
      end
    end
  end
  function __methods__:filterValue(tp)
    print('filter value type:',tp)
    for k,v in pairs(__map__) do
      if not checkType(type(v), tp) then
        __map__[k] = nil
      end
    end
  end
  function __methods__:setKeyType(type)
    if not checkType(type, nil) then
      if __key_type__ == type then
        return
      end
      __key_type__ = type
      self:filterKey(type)
    end
  end
  function __methods__:setValueType(type)
    if not checkType(type, nil) then
      if __value_type__ == type then
        return
      end
      __value_type__ = type
      self:filterValue(type)
    end
  end
  function __methods__:filter(val)
    for k,v in pairs(__map__) do
      if v == val then
        __map[k] = nil
      end
    end
  end

  local mt = {
    __index = function(t, k)
      if __map__[k] then
        return __map__[k]
      end
      if __methods__[k] then
        return __methods__[k]
      end
    end,
    __newindex = function(t, k, v)
      if __methods__[k] then
        print('[warning] can not override native method.')
        return
      end
      __methods__:set(k, v)
    end
  }
  setmetatable(new_map, mt)

  return new_map
end

return Map
