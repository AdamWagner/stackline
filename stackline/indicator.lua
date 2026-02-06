--[[
Single indicator: appearance, geometry, and canvas lifecycle for one window's
stack indicator. Owns the hs.canvas, computes position/size from config, and
handles focus-driven visual updates (colors, shadows, opacity).

Created by Window:buildIndicator() with a flat args table — no references
back to Window or Stack. At redraw time, only needs two booleans
(isWinFocused, isStackFocused) passed in by Window.
]]
local log = hs.logger.new('indicator', 'info')
log.i('Loading module: indicator')

local Indicator = {}

-- Canvas element indices (constant — rect is always first, icon second)
local RECT = 1
local ICON = 2

function Indicator:new(args) -- {{{
    local config    = args.config
    local showIcons = config.showIcons
    local width     = showIcons and config.size or (config.size / config.pillThinness)

    local ind = {
        config              = config,
        showIcons           = showIcons,
        width               = width,
        iconRadius          = width / config.radius,
        frame               = args.windowFrame,
        stackIdx            = args.stackIdx,
        screenFrame         = args.screen:fullFrame(),
        appName             = args.appName,
        canvas              = nil, -- hs.canvas, created in draw()
        showingWinFocused   = args.isFocused,
        showingStackFocused = args.isStackFocused,
    }

    setmetatable(ind, self)
    self.__index = self

    ind.side = ind:getScreenSide()

    return ind
end -- }}}

function Indicator:draw() -- {{{
    log.i('draw indicator')
    local indicatorRect, iconRect = self:buildRects()

    local radius = self.showIcons and self.iconRadius or self.config.radius
    local fadeDuration = self.config.shouldFade and self.config.fadeDuration or 0

    if self.canvas then
        self.canvas:delete()
    end

    self.canvas = hs.canvas.new(self.screenFrame)

    local colorAttrs = self:computeColorAttrs()

    self.canvas:insertElement({
        type = "rectangle",
        action = "fill",
        fillColor = colorAttrs.bg,
        frame = indicatorRect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow = true,
        shadow = self:computeShadowAttrs(),
    }, RECT)

    if self.showIcons then
        self.canvas:insertElement({
            type = "image",
            image = self:iconFromAppName(),
            frame = iconRect,
            imageAlpha = colorAttrs.img,
        }, ICON)
    end

    self.canvas:clickActivating(false)
    self.canvas:show(fadeDuration)
end -- }}}

function Indicator:delete() -- {{{
    log.d('delete indicator')
    if self.canvas then
        self.canvas:delete(self.config.fadeDuration)
        self.canvas = nil
    end
end -- }}}

function Indicator:updateFocus(isWinFocused, isStackFocused) -- {{{
    -- Compare live focus against what we're currently showing
    local winChanged = isWinFocused ~= self.showingWinFocused
    local stackChanged = isStackFocused ~= self.showingStackFocused

    if not winChanged and not stackChanged then return nil end

    -- Update what we're showing.
    -- showingStackFocused always tracks reality.
    if stackChanged then
        self.showingStackFocused = isStackFocused
    end
    -- showingWinFocused only updates within a focused stack. When the stack
    -- is unfocused, the old value is preserved — the "last-active window"
    -- renders slightly brighter, showing which window was last used.
    if winChanged and isStackFocused then
        self.showingWinFocused = isWinFocused
    end

    -- Update canvas properties in-place (fast path — no teardown/rebuild)
    if not self.canvas then return nil end

    local rect = self.canvas[RECT]

    local colorAttrs = self:computeColorAttrs()
    rect.fillColor = colorAttrs.bg
    if self.showIcons then
        self.canvas[ICON].imageAlpha = colorAttrs.img
    end
    rect.shadow = self:computeShadowAttrs()

    return {winChanged = winChanged, stackChanged = stackChanged}
end -- }}}

function Indicator:getHitFrame() -- {{{
    -- Returns the rectangle element's frame for click hit-testing,
    -- or nil if no canvas exists.
    if not self.canvas then return nil end
    return self.canvas:canvasElements()[RECT].frame
end -- }}}

function Indicator:computeColorAttrs() -- {{{
    -- Returns {bg = color table with alpha, img = icon opacity} for current focus state.
    local opts = self.config
    local bgAlpha, imgAlpha

    if self.showingStackFocused and self.showingWinFocused then
        -- focused window in focused stack: full brightness
        bgAlpha  = opts.alpha
        imgAlpha = opts.alpha

    elseif self.showingStackFocused then
        -- unfocused window in focused stack: dimmed
        bgAlpha  = opts.alpha / opts.dimmer
        imgAlpha = opts.alpha / opts.iconDimmer

    elseif self.showingWinFocused then
        -- last-active window in unfocused stack: 20% brighter than dimmed
        bgAlpha  = (opts.alpha / opts.dimmer) * 1.2
        imgAlpha = opts.alpha

    else
        -- unfocused window in unfocused stack: most dimmed
        -- icon mode hides bg entirely; pill mode keeps a faint bg
        bgAlpha  = self.showIcons and 0 or 0.2
        imgAlpha = opts.alpha / (opts.iconDimmer * 1.5)
    end

    local bg = u.copy(opts.color)
    bg.alpha = bgAlpha

    return {
        bg = bg,
        img = imgAlpha
    }
end -- }}}

function Indicator:computeShadowAttrs() -- {{{
    -- Focused window indicators get larger, bolder shadows.
    -- pillDimmer scales down blur, opacity, and horizontal spread for pills.
    local focused      = self.showingWinFocused
    local pillDimmer   = self.showIcons and 1 or 5
    local intensity    = self.config.shadowIntensity
    local spread       = self.config.shadowSpread
    local offsetSpread = math.sqrt(spread) -- offsets scale subtly with spread

    -- Compute shadow opacity & blur
    local alpha = (focused and 0.33 or 0.25) / pillDimmer * intensity
    local blur  = (focused and 8 or 5) / pillDimmer * spread

    -- Cast shadow outward toward nearest screen edge
    local drop  = -(focused and 3 or 2) * offsetSpread
    local castDir = self.side == 'left' and -1 or 1
    local cast    = (focused and 3 or 2) / pillDimmer * castDir * offsetSpread

    return {
        blurRadius = blur,
        color = {alpha = alpha},
        offset = {h = drop, w = cast},
    }
end -- }}}

function Indicator:getScreenSide() -- {{{
    -- Returns "left" or "right" based on which side of the screen the window is on.
    -- Biased toward "left": window must have its right edge past 75% of screen width.
    local rightEdge = (self.frame.x + self.frame.w) / self.screenFrame.w
    return rightEdge > 0.75 and 'right' or 'left'
end -- }}}

function Indicator:buildRects() -- {{{
    -- Compute indicator and icon rectangles from frame, config, and screen side.
    -- X position is clamped to screen bounds to prevent drawing offscreen.
    local c = self.config

    -- Position indicator just outside the window edge
    local xval
    if self.side == 'right' then
        xval = self.frame.x + self.frame.w + c.offset.x
    else
        xval = self.frame.x - self.width - c.offset.x
    end

    -- Clamp to screen bounds
    xval = math.max(0, math.min(xval, self.screenFrame.w - self.width))

    -- stackIdx comes from yabai: position within the stack (1, 2, 3...)
    local indicatorRect = {
        x = xval,
        y = self.frame.y + c.offset.y +
            ((self.stackIdx - 1) * c.size * c.vertSpacing),
        w = self.width,
        h = c.size,
    }

    local iconRect = {
        x = xval + c.iconPadding,
        y = indicatorRect.y + c.iconPadding,
        w = indicatorRect.w - (c.iconPadding * 2),
        h = indicatorRect.h - (c.iconPadding * 2),
    }

    return indicatorRect, iconRect
end -- }}}

function Indicator:iconFromAppName() -- {{{
    local appBundle = hs.appfinder.appFromName(self.appName):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Indicator:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i(('Indicator.log level set to %s'):format(lvl))
end -- }}}

return Indicator
