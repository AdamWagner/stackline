local prop = require 'stackline.tests.mockHammerspoon.utils.prop'


local MockBase = {}

function MockBase:new(o)
  o = o or {}
  self.__defaults = prop.wrap(o) or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function MockBase:__configDefaults(o)
  self.__defaults = {}
  for k,v in pairs(o) do
    self.__setDefaults[k] = v
  end
end

function MockBase:__setDefaults(o)
    self.__defaults = table.merge(self.__defaults, prop.wrap(o))
end

function MockBase:__getDefaults(o)
    return self.__defaults
end


return MockBase

