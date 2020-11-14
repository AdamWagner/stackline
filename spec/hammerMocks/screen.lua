-- STACKLINE REFERENCES:
--    screen
-- -----------------------------------------------------------------------------

-- mock utils
local prop = require 'hammerMocks.utils.prop'

-- real hs modules
local geometry = require 'hs.geometry'

-- ———————————————————————————————————————————————————————————————————————————
-- hs.screen mock
-- ———————————————————————————————————————————————————————————————————————————
local screen = {}

-- NOTE: if the dock & menubar are hidden, frame & fullFrame will be equal
screen.__defaults = {}
screen.__defaults.frame = geometry({h = 1120.0, w = 1792.0, x = 0.0, y = 0.0})
screen.__defaults.fullFrame = geometry({h = 1120.0, w = 1792.0, x = 0.0, y = 0.0})
screen.__defaults.id = 2077748985

function screen:__setDefaults(o)
  self.__defaults = table.merge(self.defaults, o)
end

function screen:__getDefaults(o)
  self.__defaults = table.merge(self.defaults, o)
end

function screen:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  o.id = prop.new(o.id or self.__defaults.id)
  o.frame = prop.new(o.frame or self.__defaults.frame)
  o.fullFrame = prop.new(o.fullFrame or self.__defaults.fullFrame)
  return o
end

function screen.mainScreen(o)
  return screen.new(screen, o)
end

-- Directly from source: /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/screen/init.lua
function screen:localToAbsolute(rect, ...)
  return rect + self:fullFrame().topleft
end

function screen:absoluteToLocal(rect, ...)
  return rect - self:fullFrame().topleft
end

return screen
