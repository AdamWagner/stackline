
-- TODO: Refactor this into a "Position" module
-- TODO: Refactor this using polymorphism (e.g., LeftSide = Position:extend('LeftSide'))

local Position = {}

function Position.padRect(padding, rect)   -- WORK IN PROGRESS!! Delete if returning much after 2021-07-05 {{{
   padding = padding or 4
end-- }}}

local function ensureOnScreen(xval, screen, config) --[[ {{{
   Limit xval to screen boundary to prevent drawing offscreen (#21)
   If beyond right screen edge, position indicator at right screen edge.
   NOTE: Will likely cause indicators to overlap window content ]]

   local indicatorWidth = config.size
   local screenWidth = screen:fullFrame().w

   if (xval + indicatorWidth) > screenWidth then
      xval = screenWidth - indicatorWidth
   end
   -- Don't go beyond left screen edge, which starts at '0'
   -- So simply ensure that xval isn't < 0
   return math.max(xval, 0)
end -- }}}

function Position.getScreenSide(f, screen) --[[ {{{
    Returns the side of the screen that the window is (mostly) on
    Retval: "left" or "right" ]]
    local thresh = 0.75
    local screenWidth = screen:fullFrame().w

    local leftEdge  = f.x
    local rightEdge = f.x + f.w
    local percR     = 1 - ((screenWidth - rightEdge) / screenWidth)
    local percL     = (screenWidth - leftEdge) / screenWidth

    local side = (percR > thresh and percL < thresh) and 'right' or 'left'
    return side
    -- TODO [low-priority]: BUG: Right-side window incorrectly reports as a left-side window with {{{
    -- very large padding settings. Will need to consider coordinates from both
    -- sides of a window. Impact is minimal with smaller threshold (<= 0.75). }}}
    -- IDEA: Use win:windowsToWest() methods to determine if the window is on the left or right side
end -- }}}

function Position.getIndicatorAnchor(f, side) -- {{{
    local leftEdge, rightEdge = f.x, (f.x + f.w)
    return hs.geometry { 
      x = side == 'left' and leftEdge or rightEdge,
      y = f.y 
   }
end -- }}}

function Position.getPosition(f, idx, screen, config) --[[ {{{
   Display indicators on the:
       * left edge of windows when stack is on the left side of the screen
       * right edge of windows when stack is on the right side of the screen ]]

   idx = idx or 1   -- default ot 1st element if not given
   local function getX() 
      local side            = Position.getScreenSide(f, screen)
      local xoffset         = config.offset.x
      local xSign           = (side=='left') and -1 or 1   -- Add or subtract offset depending on window's 'side'
      local indicatorWidth  = config.size
      local wSign           = (side=='left') and -1 or 0   -- Subtract indicator width when shown on left edge. Do nothing if shown on right edge.

      local xval = Position.getIndicatorAnchor(f, side).x
            + (xSign * xoffset)
            + (wSign * indicatorWidth)

      return ensureOnScreen(xval, screen, config)
   end 

   local function getY() --[[
      NOTE: self.PositionstackIdx comes from yabai. Indicator is stacked if stackIdx > 0
      vertCascade example: `stackIdx=1` at top & `stackIdx=len(stack)` at bottom
      Increase `config.vertSpacing` to add more vertical space between indicators ]]
      local vertCascade = config.vertSpacing 
         * config.size 
         * (idx - 1)

      return config.offset.y + f.y + vertCascade
   end 

   return getX(), getY()

end -- }}}

return Position
