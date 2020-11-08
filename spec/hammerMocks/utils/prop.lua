--[[
Hammerspoon often makes object fields callable.
E.g.,
  hs.window:screen():frame()
↑ :frame() rather than .frame because frame *itself* has methods

┌─────────┐
│ prop()  │
└─────────┘
returns value when called as a function

This avoids need for writing tons of "module.field()" getter functions
that simply return the field value hidden internally.

Real example from mock-hs.lua:
function screen:new(o)
    …
    o.id        = prop(o.id or self.__defaults.id)
    o.frame     = prop(o.frame or self.__defaults.frame)
    o.fullFrame = prop(o.fullFrame or self.__defaults.frame)
    …
end
]]

local function printTable(value)
  if type(value)=='table' then
    local mt = getmetatable(value)
    if mt and type(mt.__tostring)=='function' then
      return tostring(value)
    else
      local keys = u.keys(value)
      return tostring(value) .. ': ' .. table.concat(keys, ', ')
    end
  else
    return tostring(value)
  end
end

local function prop(v)
    local o = { value = v }
    mt = {
        __call = function()
            return o.value
        end,
        __tostring = function()
          return printTable(o.value)
        end,
    }
    setmetatable(o, mt)
    o.__index = self
    return o
end

local function wrap(o)
  local obj = {}
  for k,v in pairs(o or {}) do

    if type(v)=='string' or type(v)=='number' then
      obj[k] = prop(v)

    elseif type(v)=='table'  then

      if getmetatable(v)==nil then
        -- recursively wrap
        obj[k] = prop(wrap(v))
      else
        -- `v` has metamethods, so don't recursively wrap
        -- it's probably a hammerspoon instance (geometry)
        obj[k] = prop(v)
      end

    else
      obj[k] = v
    end
  end
  return obj
end

return {
  new = prop,
  wrap = wrap,
}





