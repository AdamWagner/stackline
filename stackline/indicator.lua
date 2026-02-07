--[[
Single indicator: appearance, geometry, and focus-driven visual updates for one
window's stack indicator. Inserts elements into a shared per-screen hs.canvas
(owned by Stackmanager) rather than creating its own canvas.

Created by Window:buildIndicator() with a flat args table — no references
back to Window or Stack. At redraw time, only needs two booleans
(isWinFocused, isStackFocused) passed in by Window.
]]
local log = hs.logger.new('indicator', 'info')
log.i('Loading module: indicator')

-- ---------------------------------------------------------------------------
-- Local helpers (pure computations, not part of the class interface)
-- ---------------------------------------------------------------------------

-- Returns "left" or "right" based on which side of the screen the window is on.
-- Biased toward "left": window must have its right edge past 75% of screen width.
local function screenSide(frame, screenWidth)
    return (frame.x + frame.w) / screenWidth > 0.75 and 'right' or 'left'
end

local function appIcon(appName)
    return hs.image.imageFromAppBundle(hs.appfinder.appFromName(appName):bundleID())
end

-- ---------------------------------------------------------------------------
-- Indicator class
-- ---------------------------------------------------------------------------

local Indicator = {}
Indicator.__index = Indicator

function Indicator:new(args) -- {{{
    local config      = args.config
    local showIcons   = config.showIcons
    local width       = showIcons and config.size or (config.size / config.pillThinness)
    local screenFrame = args.screen:fullFrame()

    -- Element IDs for string-keyed access into the shared canvas
    local winId = tostring(args.winId)
    local rectId = "rect_" .. winId
    local iconId = "icon_" .. winId

    return setmetatable({
        config              = config,
        showIcons           = showIcons,
        width               = width,
        iconRadius          = width / config.radius,
        frame               = args.windowFrame,
        stackIdx            = args.stackIdx,
        screenFrame         = screenFrame,
        appName             = args.appName,
        canvas              = args.canvas,  -- shared per-screen canvas (from Stackmanager)
        rectId              = rectId,
        iconId              = iconId,
        showingWinFocused   = args.isFocused,
        showingStackFocused = args.isStackFocused,
        side                = screenSide(args.windowFrame, screenFrame.w),
    }, self)
end -- }}}

function Indicator:draw() -- {{{
    log.i('draw indicator')

    local indicatorRect, iconRect = self:buildRects()
    local radius = self.showIcons and self.iconRadius or self.config.radius

    -- Insert elements into the shared canvas (no canvas creation)
    self.canvas:appendElements({
        id = self.rectId,
        type = "rectangle",
        action = "fill",
        frame = indicatorRect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow = true,
    })

    if self.showIcons then
        self.canvas:appendElements({
            id = self.iconId,
            type = "image",
            image = appIcon(self.appName),
            frame = iconRect,
        })
    end

    self:applyAppearance()
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

    if not self.canvas then return nil end
    self:applyAppearance()

    return {winChanged = winChanged, stackChanged = stackChanged}
end -- }}}

function Indicator:delete() -- {{{
    -- Remove this indicator's elements from the shared canvas.
    -- Iterates to find numeric indices since hs.canvas methods require them.
    log.d('delete indicator')
    if not self.canvas then return end

    -- Collect indices to remove, then remove in reverse order (highest first)
    -- so that earlier indices aren't shifted by later removals.
    local toRemove = {}
    for i = 1, self.canvas:elementCount() do
        local id = self.canvas:elementAttribute(i, 'id')
        if id == self.rectId or id == self.iconId then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        self.canvas:removeElement(toRemove[i])
    end
end -- }}}

function Indicator:getHitFrame() -- {{{
    -- Returns the rectangle element's frame for click hit-testing,
    -- or nil if no canvas/element exists.
    if not self.canvas then return nil end
    local elem = self.canvas[self.rectId]
    if not elem then return nil end
    return elem.frame
end -- }}}

-- ---------------------------------------------------------------------------
-- Internal methods
-- ---------------------------------------------------------------------------

function Indicator:applyAppearance() -- {{{
    -- Apply colors and shadow to canvas elements based on current render state.
    local bg, imgAlpha = self:computeColors()
    self.canvas[self.rectId].fillColor = bg
    self.canvas[self.rectId].shadow = self:computeShadow()
    if self.showIcons then
        self.canvas[self.iconId].imageAlpha = imgAlpha
    end
end -- }}}

function Indicator:computeColors() -- {{{
    -- Returns bg color table, icon opacity for the current focus state.
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

    return bg, imgAlpha
end -- }}}

function Indicator:computeShadow() -- {{{
    -- Focused indicators get larger, bolder shadows.
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

function Indicator:buildRects() -- {{{
    -- Compute indicator and icon rectangles from frame, config, and screen side.
    -- X position is clamped to screen bounds to prevent drawing offscreen.
    local c = self.config

    -- Position indicator just outside the window edge
    local xval = self.side == 'right'
        and self.frame.x + self.frame.w + c.offset.x
        or  self.frame.x - self.width - c.offset.x

    -- Clamp to screen bounds
    xval = u.clamp(xval, 0, self.screenFrame.w - self.width)

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

function Indicator:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i(('Indicator.log level set to %s'):format(lvl))
end -- }}}

return Indicator
