--[[
prop:new(val) returns value when key called as a function.
prop:wrap(tbl) wraps all table values

Hammerspoon often makes object fields callable.
E.g.,
  hs.window:screen():frame()
↑ :frame() rather than .frame because frame *itself* has methods

The prop util avoids need for writing tons of "module.field()"
getter functions that simply return the field value hidden internally.

Example use: -------------------------------------------------------------------
function screen:new(o)
    …
    o.id        = prop(o.id or self.__defaults.id)
    o.frame     = prop(o.frame or self.__defaults.frame)
    o.fullFrame = prop(o.fullFrame or self.__defaults.frame)
    …
end
-- ]]

local function printTable(value)  -- {{{
  if type(value) == 'table' then
    local mt = getmetatable(value)
    if mt and type(mt.__tostring) == 'function' then
      return tostring(value)
    else
      local keys = u.keys(value)
      return tostring(value) .. ': ' .. table.concat(keys, ', ')
    end
  else
    return tostring(value)
  end
end  -- }}}

local function prop(v)  -- {{{
  local o = {value = u.dcopy(v)}
  local mt = {
    __call = function()
      return o.value
    end,
    __tostring = function()
      return printTable(o.value)
    end,
  }
  setmetatable(o, mt)
  return o
end  -- }}}

local function wrap(o)
  local obj = {}
  for k, v in pairs(o or {}) do

    if type(v) == 'string' or type(v) == 'number' then   -- wrap
      obj[k] = prop(v)

        -- TODO: why is this nested within the "is string / number" condition above?
        -- TODO: may need to get more sophisticated about identifying real hs modules if start utilizing metatables in stackline modules

    elseif type(v) == 'table' then   -- recursively wrap if no metatable (real hs modules will have non-nil metatable)

      -- TODO: consider using u.isGeometryObject()
      if getmetatable(v) ~= nil or k == 'frame' then
        obj[k] = prop(v)
      else
        obj[k] = prop(wrap(v))
      end

    else   -- so do nothing (value is not string, number, or table)
      obj[k] = v
    end

  end
  return obj
end

return {new = prop, wrap = wrap}

