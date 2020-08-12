local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

-- ┌───────────────┐
-- │ Window module │
-- └───────────────┘
local Window = {}

function Window:new(hsWin) -- {{{
    local ws = {
        title = hsWin:title(), -- window title
        app = hsWin:application():name(), -- app name (string)
        id = hsWin:id(), -- window id (string) NOTE: the ID is the same as yabai! So we could interopt if we need to
        frame = hsWin:frame(), -- x,y,w,h of window (table)
        stackIdx = hsWin.stackIdx, -- only from yabai, unfort.
        stackId = self:makeStackId(hsWin).stackId, -- "{{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
        topLeft = self:makeStackId(hsWin).topLeft, -- "{{x}|{y}" e.g., "35|63" (string)
        _win = hsWin, -- hs.window object (table)
        indicator = nil, -- the canvas element (table)
    }
    setmetatable(ws, self)
    self.__index = self
    return ws
end -- }}}

function Window:isFocused() -- {{{
    local focusedWin = hs.window.focusedWindow()
    if focusedWin == nil then
        return false
    end
    local isFocused = self.id == focusedWin:id()
    return isFocused
end -- }}}

function Window:getScreenSide() -- {{{
    local screenWidth = self._win:screen():fullFrame().w
    local frame = self.frame
    local percRight = 1 - ((screenWidth - (frame.x + frame.w)) / screenWidth)
    local percLeft = (screenWidth - frame.x) / screenWidth
    local side = (percRight > 0.95 and percLeft < 0.95) and 'right' or 'left'

    return side

    -- TODO: BUG: Right-side window incorrectly reports as a left-side window with
    -- very large padding settings. Will need to consider coordinates from both
    -- sides of a window.

    -- TODO: find a way to use hs.window.filter.windowsTo{Dir} 
    -- to determine side instead of percLeft/Right ↑
    --    https://www.hammerspoon.org/docs/hs.window.filter.html#windowsToWest
    --      wfd:windowsToWest(self._win)
    --    https://www.hammerspoon.org/docs/hs.window.html#windowsToWest
    --      self._win:windowsToSouth()
end -- }}}

function Window:setupIndicator() -- {{{
    -- Config
    local showIcons = sm:getShowIconsState()

    -- Padding
    self.padding = 4
    self.iconPadding = 4

    -- Size
    self.aspectRatio = 6 -- determines width of pills when showIcons = false
    self.size = 32
    self.width = showIcons and self.size or (self.size / self.aspectRatio)

    -- Position
    self.offsetY = 2
    self.offsetX = 4
    --    example: overlapped with window + percent top offset
    --    self.offsetY = self.frame.h * 0.1
    --    self.offsetX = -(self.width / 2)

    -- Roundness
    self.indicatorRadius = 3
    self.iconRadius = self.width / 4.0

    -- Fade-in/out duration
    self.fadeDuration = 0.2

    -- Display indicators on 
    --   left edge of windows on the left side of the screen, &
    --   right edge of windows on the right side of the screen
    local side = self:getScreenSide()
    local xval
    if side == 'right' then
        xval = (self.frame.x + self.frame.w) + self.offsetX
    else
        xval = self.frame.x - (self.width + self.offsetX)
    end

    -- Set canvas to fill entire screen
    self.canvas_frame = self._win:screen():frame()

    -- Store  canvas elements indexes to reference via :elementAttribute()
    -- https://www.hammerspoon.org/docs/hs.canvas.html#elementAttribute
    self.rectIdx = 1
    self.iconIdx = 2

    -- NOTE: self.stackIdx comes from yabai
    self.indicator_rect = {
        x = xval,
        y = self.frame.y + ((self.stackIdx - 1) * self.size * 1.1),
        w = self.width,
        h = self.size,
    }

    self.icon_rect = {
        x = xval + self.iconPadding,
        y = self.indicator_rect.y + self.iconPadding,
        w = self.indicator_rect.w - (self.iconPadding * 2),
        h = self.indicator_rect.h - (self.iconPadding * 2),
    }
end -- }}}

function Window:drawIndicator(overrideOpts) -- {{{
    self.defaultOpts = {
        shouldFade = true,
        alphaFocused = 1,
        alphaUnfocused = 0.33,
    }

    local opts = u.extend(self.defaultOpts, overrideOpts or {})

    -- Color
    self.colorFocused = {white = 0.9, alpha = opts.alphaFocused}
    self.colorUnfocused = {white = 0.9, alpha = opts.alphaUnfocused}

    -- Unfocused icons less transparent than bg color, but no more than 1
    self.iconAlphaFocused = opts.alphaFocused
    self.iconAlphaUnfocused = math.min(opts.alphaUnfocused * 2.25, 1)

    local showIcons = sm:getShowIconsState()
    local radius = showIcons and self.iconRadius or self.indicatorRadius
    local fadeDuration = opts.shouldFade and self.fadeDuration or 0

    self.focus = self:isFocused()
    -- Speed profile: 0.0123s / 75 (0.0002s) :: isFocused 

    if self.indicator then
        self.indicator:delete()
    end

    self.indicator = hs.canvas.new(self.canvas_frame)

    self.currStyle = {
        fillColor = self.focus and self.colorFocused or self.colorUnfocused,
        imageAlpha = self.focus and self.iconAlphaFocused or
            self.iconAlphaUnfocused,
    }

    self.indicator:insertElement({
        type = "rectangle",
        action = "fill",
        fillColor = self.currStyle.fillColor,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        padding = 60,
        withShadow = true,
        shadow = self:getShadowAttrs(),
    }, self.rectIdx)

    if showIcons then
        -- TODO: Figure out how to prevent clipping when adding a subtle shadow
        -- to the icon to help distinguish icons with a near-white edge.Note
        -- that `padding` attribute, which works for rects, does not work for images.
        self.indicator:insertElement({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.icon_rect,
            imageAlpha = self.currStyle.imageAlpha,
        }, self.iconIdx)
    end

    self.indicator:show(fadeDuration)
end -- }}}

function Window:redrawIndicator(isFocused) -- {{{
    -- bail early if there's nothing to do
    if isFocused == self.focus then
        return false
    else
        self.focus = isFocused
    end

    if not self.indicator then
        self:setupIndicator()
    end

    local f = self.focus
    local rect = self.indicator[self.rectIdx]
    local icon = self.indicator[self.iconIdx]

    rect.fillColor = f and self.colorFocused or self.colorUnfocused
    rect.shadow = self:getShadowAttrs(f)
    if sm:getShowIconsState() then
        icon.imageAlpha = f and self.iconAlphaFocused or self.iconAlphaUnfocused
    end
end -- }}}

function Window:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:getShadowAttrs() -- {{{
    local shadowAlpha = self.focus and 3 or 3.75 -- denominator in 1 / N, so "2" == 50% alpha 
    local shadowBlur = self.focus and 18.0 or 5.0

    -- Shadows should cast outwards toward the screen edges as if due to the glow of onscreen windows…
    -- …or, if you prefer, from a light source originating from the center of the screen.
    local shadowXDirection = (self:getScreenSide() == 'left') and -1 or 1
    local shadowOffset = {
        h = (self.focus and 3.0 or 2.0) * -1.0,
        w = (self.focus and 7.0 or 6.0) * shadowXDirection,
    }
    -- TODO [just for fun]: Dust off an old Geometry textbook and try get the
    -- shadow's angle to rotate around a point at the center of the screen (aka, 'light source').
    -- Here's a super crude POC that uses the indicator's stack index such that
    -- higher indicators have a negative Y offset and lower indicators have a
    -- positive Y offset ;-) 
    --      h = (self.focus and 3.0 or 2.0 - (2 + (self.stackIdx * 5))) * -1.0,

    return {
        blurRadius = shadowBlur,
        color = {alpha = 1 / shadowAlpha}, -- TODO align all alpha values to be defined like this (1/X)
        offset = shadowOffset,
    }
end -- }}}

function Window:makeStackId(hsWin) -- {{{
    -- stackId is top-left window frame coordinates
    -- example: "302|35|63|1185|741"
    local frame = hsWin:frame():floor()
    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h
    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
    }
end -- }}}

function Window:deleteIndicator() -- {{{
    if self.indicator then
        self.indicator:delete(self.fadeDuration)
    end
end -- }}}

return Window
