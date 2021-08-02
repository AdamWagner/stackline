
--[[ === BIG TODO 2021-07-05 === {{{
    This is very much a messy work-in-progress.
    There are still lots of wires remaining to connect properly,
    and of course there is a great deal of cleanup to do once everything *is* working properly.
 }}} ]]

--[[ == TEST:Bootstrap == {{{
stack = stackline.manager:get()[1]
w = u.map(hs.window.filter(), function(w) w = stackline.window:new(w) w:setup(stack) return w end)[1]
indicator = require 'stackline.indicator'
i = indicator:new(w)
i:setup()
i:draw()


== TEST:Destroy ==
s = stackline.manager:get()[1]
ws = s.windows
w = ws[3]
w:destroy()
-- * Manual action -> Click on another stack * --
 }}} ]]

local pos = require 'modules.position'

local uiElement = require'classes.UiElement'
local Indicator = uiElement:subclass('Indicator')

function Indicator:new(win)-- {{{
   local hswin = win._win
   self.log.i( ('Indicator:new(%s)'):format(hswin:id()) )

   -- u.header('indicator self')
   -- u.p(self)

   self._config = stackline.config:get('appearance')
   self._screen = win._screen
   self._winbackref    = win
   self._stack  = win._stack
   self.rectIdx = 1 -- Store  canvas elements indexes to reference via :elementAttribute()
   self.iconIdx = 2 -- hammerspoon.org/docs/hs.canvas.html#elementAttribute
   self.canvas  = nil -- Will become an hs.canvas instance of type <userdata>
   return self
end-- }}}

function Indicator:setup()-- {{{
   self.log.d('setupIndicator for', self.id)
   local c = self._config

   self.radius = c.showIcons and c.iconRadius or c.radius
   self.width  = self._config.showIcons and c.size or (c.size / c.pillThinness)
   local xval, yval = self:getPosition()

   self._canvas_rect = {
      x = 0,
      y = c.size * (self._winbackref.stackIdx - 1) * c.vertSpacing,
      w = self.width,
      h = c.size,
   }

   self._icon_rect = {
      x = c.iconPadding,
      y = self._canvas_rect.y + c.iconPadding,
      w = self._canvas_rect.w - (c.iconPadding * 2),
      h = self._canvas_rect.h - (c.iconPadding * 2),
   }
   return self
end-- }}}

function Indicator:getCanvas()-- {{{
   -- TODO: Check that self._winbackref:frame() does the abs-to-local conversion here ↓
   -- self.frame = self._screen:absoluteToLocal(hs.geometry(self._winbackref._winbackref:frame())) -- Set canvas to fill entire screen
   local function check()
      if self.canvas:canvasElements()[1] then
         return self.canvas
      end
   end
   local ok, cframe = pcall(check)
   if not ok then return false end
   return ok, cframe
end-- }}}

function Indicator:redraw() --[[ {{{
   Redraw with fresh styles based on current focus state of win & stack.
   ]]
   if not self:getCanvas() then
      self.log.d('Indicator:redraw(): No self.canvas, so rebuilding')
      self:setup():draw()
   end

   local styles = self:getStyle()
   local rect = self.canvas[self.rectIdx]
   rect.fillColor = styles.bg
   rect.shadow = self:getShadowAttrs()

   if self._config.showIcons then
      local icon = self.canvas[self.iconIdx]
      icon.imageAlpha = styles.img
   end
end-- }}}

function Indicator:draw()-- {{{
   self.log.i('win.indicator.draw() for', self._winbackref.id)
   local c = self._config

   if self:getCanvas() then -- if canvas exists, abort :draw()
      self.log.w('Window:drawIndicator() -- Indicator already exists on win #', self._winbackref.id)
      return self
   end

   -- TODO: Append the indicator elements to a pre-existing canvas on `stack`
   -- that is *the minimum size needed to contain indicators*
   self._stack:buildCanvas()
   self.canvas = self._stack.container

   self.canvas[self.rectIdx] = self:buildRect()
   self.canvas[self.iconIdx] = self:buildIcon()

   -- clicking on a canvas elment should NOT bring Hammerspoon wins to front
   -- SEE: https://github.com/Hammerspoon/hammerspoon/issues/2425
   self.canvas:clickActivating(false)
   self.canvas:show(c.shouldFade and c.fadeDuration or 0)
   return self
end-- }}}

function Indicator:getPosition() --[[ {{{ 
    Display indicators on the: 
       * left edge of windows when stack is on the left side of the screen
       * right edge of windows when stack is on the right side of the screen ]]
   local w = self._winbackref

   -- REVIEW: `getPosition()` may actually make more sense as a member of Indicator? 
   -- We're passing a lot of state to the non-method helper fn...
   return pos.getPosition(w:frame(), w.stackIdx, w._screen, w._config)

   --[=[
   local function getX() 
      local function ensureOnScreen(xval) --[[
         Limit xval to screen boundary to prevent drawing offscreen (#21)
         If beyond right screen edge, position indicator at right screen edge.
         NOTE: Will likely cause indicators to overlap window content ]]
         if (xval + self.width) > self._screen:fullFrame().w then
            xval = self._screen:fullFrame().w - self.width
         end
         return math.max(xval, 0)
      end

      local side = self._winbackref:getScreenSide()
      local xoffset = self._config.offset.x
      local xoffsetSign = side == 'left' and -1 or 1 -- Add or subtract offset depending on window's 'side'
      local widthSign = side == 'left' and -1 or 0 -- Subtract indicator width when shown on left edge. Do nothing if shown on right edge.

      local xval = self._winbackref:getIndicatorAnchor().x
         + (xoffsetSign * xoffset)
         + (widthSign * self.width)

      return ensureOnScreen(xval)
   end 

   local function getY() --[[
      NOTE: self._stackIdx comes from yabai. Indicator is stacked if stackIdx > 0
      vertCascade example: `stackIdx=1` at top & `stackIdx=len(stack)` at bottom
      Increase `config.vertSpacing` to add more vertical space between indicators ]]
      local vertCascade = self._config.vertSpacing * self._config.size * (self._winbackref.stackIdx - 1)
      return self._winbackref:frame().y + self._config.offset.y + vertCascade
   end 

   return getX(), getY()
   ]=]

end -- }}}

function Indicator:buildRect() -- {{{
  return {
    type = "rectangle",
    action = "fill", -- options: strokeAndFill, stroke, fill
    fillColor = self:getStyle().bg,
    frame = self._canvas_rect,
    roundedRectRadii = {xRadius = self.radius, yRadius = self.radius},
    withShadow = true,
    shadow = self:getShadowAttrs(),
  }
end -- }}}

function Indicator:buildIcon() -- {{{
  if not self._config.showIcons then return end
  return {
    type = "image",
    image = self:iconFromAppName(),
    frame = self._icon_rect,
    imageAlpha = self:getStyle().img,
  }
end -- }}}

function Indicator:getStyle() -- {{{
   local c, w = self._config, self._winbackref
   local bg, img = c.alpha, c.alpha
   local iconDimmer = c.dimmer / 2 -- dim inactive icons less than indicator BGs are dimmed

   -- Decrease opacity for each level (stack, window) that is unfocused
   u.each({w._stack:isFocused(), w:isFocused()}, function(focused)
      if not focused then
         bg = bg/c.dimmer
         img = img/iconDimmer
      end
   end)

   return {
      bg = u.assign(c.color, {alpha = bg}), -- color obj, e.g., {alpha=0.4, white=0.9, red=0, blue=0, green=0}
      img = img,                            -- alpha float, e.g., 0.45
   }
end -- }}}

function Indicator:getShadowAttrs() -- {{{
  local iconsDisabledDimmer = self._config.showIcons and 1 or 5 -- less opaque & blurry when iconsDisabled
  local focus = self._winbackref:isFocused()                           -- ...and even less opaque & blurry when unfocused
  local alphaDimmer = (focus and 6 or 7) * iconsDisabledDimmer
  local blurDimmer = (focus and 15.0 or 7.0) / iconsDisabledDimmer

  -- Shadows should cast outwards toward the screen edges as if due to the glow of onscreen windows…
  -- …or, if you prefer, from a light source originating from the center of the screen.
  local direction = (self.side == 'left') and -1 or 1
  local offset = {
    h = (focus and 3.0 or 2.0) * -1.0,
    w = ((focus and 7.0 or 6.0) * direction) / iconsDisabledDimmer,
  }

  -- TODO [just for fun]: Dust off an old Geometry textbook and try get the shadow's angle to rotate around a point at the center of the screen (aka, 'light source')
  -- Here's a super crude POC that uses the indicator's stack index such that
  -- higher indicators have a negative Y offset and lower indicators have a positive Y offset
  --   h = (self._winbackref.focus and 3.0 or 2.0 - (2 + (self._stackIdx * 5))) * -1.0,
  return {
    blurRadius = blurDimmer,
    color = {alpha = 1 / alphaDimmer}, -- TODO align all alpha values to be defined like this (1/X)
    offset = offset,
  }
end -- }}}

function Indicator:iconFromAppName() -- {{{
    return hs.image.imageFromAppBundle(
      hs.appfinder.appFromName(self._winbackref.app):bundleID()
   )
end -- }}}

function Indicator:deleteIndicator()-- {{{
  local fadeDuration = stackline.config:get('appearance.fadeDuration')
  if self.canvas then
    self.canvas:delete(fadeDuration)
  end
  return self
end-- }}}

function Indicator:reset()-- {{{
   return self
      :deleteIndicator()
      :setup()
      :draw()
end-- }}}

function Indicator:destroy()-- {{{
    self:deleteIndicator()
    -- self = nil
end-- }}}

function Indicator:contains(point) -- {{{ NOTE: `frame` & `point` *must* be a hs.geometry.rect instance
   local ok, canvasFrame = self:getCanvas()
   if not ok then return false end
   return point:inside(canvasFrame:canvasElements()[1].frame) -- NOTE: frame *must* be a hs.geometry.rect instance
end -- }}}

return Indicator
