local prop = require 'hammerMocks.utils.prop'
local MockBase = require 'hammerMocks.utils.mockbase'

-- local log = hs.logger.new('hsmock.canvas')
-- log.setLogLevel('info')
-- log.i("Loading'hsmock.canvas")

-- STACKLINE REFERENCES
-- hs.canvas
-- hs.canvas.new


  --[[ DATA {{{
    .elements = list
      fillColor
      shadow

    METHODS
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
]]  -- }}}


local default = {
  name = 'test'
}

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
    return nil
end

function canvas:appendElements()
    return {
        show = function()
            return nil
        end,
    }
end

return canvas
