local prop = require 'stackline.tests.mockHammerspoon.utils.prop'
local MockBase = require 'stackline.tests.mockHammerspoon.utils.mockbase'

-- local log = hs.logger.new('hsmock.canvas')
-- log.setLogLevel('info')
-- log.i("Loading'hsmock.canvas")

-- Stackline uses:
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


-- function Win:new(o) 
--   local o = o or self.__defaults
-- 	-- win = MockBase:new(o)
--   local win = prop.wrap(o)
--   setmetatable(win, self)
--   self.__index = self
--   return win
-- end    


function canvas.new(o)
    local o = o or {}
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
