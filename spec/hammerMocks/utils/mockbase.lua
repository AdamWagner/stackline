local prop = require 'hammerMocks.utils.prop'

-- ————————————————————————————————————————————————————————————————————————————
-- Mockbase is a simple base class that simplifies writing stateful mock modules.
-- See alternative approach that uses tiered __index() lookup to manage defaults/overrides:
--    https://github.com/inmation/library/blob/master/mock/inmation.lua
-- ————————————————————————————————————————————————————————————————————————————

local MockBase = {}

function MockBase:new(o)
  o = o or {}
  self.__defaults = prop.wrap(o) or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- TODO: Remove if still unused after 2020-11-14
-- function MockBase:__configDefaults(o)
--   self.__defaults = {}
--   for k,v in pairs(o) do
--     self.__setDefaults[k] = v
--   end
-- end

function MockBase:__setDefaults(o)
  self.__defaults = table.merge(self.__defaults, prop.wrap(o))
end

function MockBase:__getDefaults(o)
  return self.__defaults
end

return MockBase

