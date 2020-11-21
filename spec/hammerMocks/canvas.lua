-- STACKLINE REFERENCES
--    hs.canvas
--    hs.canvas.new
-- -----------------------------------------------------------------------------
--[[ hs.canvas method reference {{{
  .elements = list
    fillColor
    shadow

  METHODS -----
  :insertElement()
   Args = {
         -- type = "image",
         -- image = hs.image
         -- frame = hs.geometry.rect
         -- imageAlpha = {}
     -- },
     -- iconIdx
  :elementAttribute(idx, key)
  :frame() -> hs.geometry.rect
  :alpha()
  :clickActivating(false)
  :show(fadeDuration)
  :hide(fadeDuration)
  :delete(fadeDuration)

  imageAlpha
    0.123123 (float)

  fillColor
    { alpha = 1.0, blue = 1.0, green = 0.0, red = 0.0 }

  shadow
  { blurRadius = 5.0,
    color = COLORTYPE,
    offset = { h = -5.0, w = 5.0 }
  }
 }}} ]] -- mock utils

-- mock utils
local prop = require 'hammerMocks.utils.prop'
local MockBase = require 'hammerMocks.utils.mockbase'

-- Default new canvas values
-- ———————————————————————————————————————————————————————————————
local default = {name = 'test'}

-- ———————————————————————————————————————————————————————————————————————————
-- hs.canvas mock
-- TODD: Lots of work needed before writing window indicator tests
-- ———————————————————————————————————————————————————————————————————————————
local canvas = MockBase:new(default)

function canvas.new(o)
  o = o or {}
  setmetatable(o, canvas)
  canvas.__index = canvas
  return o
end

function canvas:insertElement(o, idx)
  -- log.d(hs.inspect(o), idx)
  return self
end

function canvas:clickActivating(bool)
  return self
end

function canvas:show()
  return self
end

function canvas:hide()
  return self
end
function canvas:delete()
  self = nil
  return self
end

function canvas:appendElements()
  return {
    show = function()
      return nil
    end,
  }
end

return canvas
