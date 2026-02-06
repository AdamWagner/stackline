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

function Indicator:new(args) -- {{{
    local config = args.config
    local showIcons = config.showIcons

    -- Indicator width: icons are square; pills are narrow
    local width = showIcons and config.size or (config.size / config.pillThinness)
    local iconRadius = width / config.radius

    local screen = args.screen
    local screenFrame = screen:fullFrame()
    local frame = args.windowFrame

    -- Determine which screen edge to place indicator on
    local side = self:getScreenSide(frame, screenFrame.w)

    -- Compute x position, clamped to screen bounds
    local xval
    if side == 'right' then
        xval = (frame.x + frame.w) + config.offset.x
        if xval + width > screenFrame.w then
            xval = screenFrame.w - width
        end
    else
        xval = frame.x - (width + config.offset.x)
        xval = math.max(xval, 0)
    end

    -- stackIdx comes from yabai: position within the stack (1, 2, 3...)
    local indicator_rect = {
        x = xval,
        y = frame.y + config.offset.y +
            ((args.stackIdx - 1) * config.size * config.vertSpacing),
        w = width,
        h = config.size,
    }

    local icon_rect = {
        x = xval + config.iconPadding,
        y = indicator_rect.y + config.iconPadding,
        w = indicator_rect.w - (config.iconPadding * 2),
        h = indicator_rect.h - (config.iconPadding * 2),
    }

    local ind = {
        config         = config,
        showIcons      = showIcons,
        width          = width,
        iconRadius     = iconRadius,
        screenFrame    = screenFrame,
        side           = side,
        indicator_rect = indicator_rect,
        icon_rect      = icon_rect,
        rectIdx        = 1,
        iconIdx        = 2,
        appName        = args.appName,
        canvas         = nil,           -- hs.canvas, created in draw()
        winFocused     = args.isFocused,
        stackFocused   = args.isStackFocused,
    }

    setmetatable(ind, self)
    self.__index = self
    return ind
end -- }}}

function Indicator:draw() -- {{{
    log.i('draw indicator')
    local radius = self.showIcons and self.iconRadius or self.config.radius
    local fadeDuration = self.config.shouldFade and self.config.fadeDuration or 0

    if self.canvas then
        self.canvas:delete()
    end

    self.canvas = hs.canvas.new(self.screenFrame)

    local colorAttrs = self:getColorAttrs(self.stackFocused, self.winFocused)

    self.canvas:insertElement({
        type = "rectangle",
        action = "fill",
        fillColor = colorAttrs.bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow = true,
        shadow = self:getShadowAttrs(self.winFocused),
    }, self.rectIdx)

    if self.showIcons then
        self.canvas:insertElement({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.icon_rect,
            imageAlpha = colorAttrs.img,
        }, self.iconIdx)
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
    -- Compare live focus against render state to detect changes.
    -- Render state (self.winFocused, self.stackFocused) persists between calls
    -- so that each call can detect what changed since the last redraw.
    local winChanged = isWinFocused ~= self.winFocused
    local stackChanged = isStackFocused ~= self.stackFocused

    if not winChanged and not stackChanged then return nil end

    -- Update render state for this redraw (and as baseline for the next call).
    -- stackFocused always tracks reality.
    if stackChanged then
        self.stackFocused = isStackFocused
    end
    -- winFocused tracks reality when focus changes *within* a focused stack.
    -- When the stack is unfocused (whether we just left it or a cross-stack
    -- HS #2400 redraw triggered this), winFocused is preserved — the
    -- "last-active window" renders slightly brighter, showing which window
    -- was last used in the now-unfocused stack.
    if winChanged and isStackFocused then
        self.winFocused = isWinFocused
    end

    -- Update canvas properties in-place (fast path — no teardown/rebuild)
    if not self.canvas then return nil end

    local rect = self.canvas[self.rectIdx]
    local icon = self.canvas[self.iconIdx]

    local colorAttrs = self:getColorAttrs(self.stackFocused, self.winFocused)
    rect.fillColor = colorAttrs.bg
    if self.showIcons then
        icon.imageAlpha = colorAttrs.img
    end
    rect.shadow = self:getShadowAttrs(self.winFocused)

    return {winChanged = winChanged, stackChanged = stackChanged}
end -- }}}

function Indicator:getHitFrame() -- {{{
    -- Returns the rectangle element's frame for click hit-testing,
    -- or nil if no canvas exists.
    if not self.canvas then return nil end
    return self.canvas:canvasElements()[self.rectIdx].frame
end -- }}}

function Indicator:getColorAttrs(isStackFocused, isWinFocused) -- {{{
    -- Returns {bg = fillColor, img = imageAlpha} based on focus state.
    local opts = self.config
    local function withAlpha(a)
        return u.extend(u.copy(opts.color), {alpha = a})
    end

    if isStackFocused and isWinFocused then
        -- focused window in focused stack: full brightness
        return {
            bg = withAlpha(opts.alpha),
            img = opts.alpha
        }

    elseif isStackFocused then
        -- unfocused window in focused stack: dimmed
        return {
            bg = withAlpha(opts.alpha / opts.dimmer),
            img = opts.alpha / opts.iconDimmer
        }

    elseif isWinFocused then
        -- last-active window in unfocused stack: slightly less dimmed
        return {
            bg = withAlpha(opts.alpha / (opts.dimmer / 1.2)),
            img = opts.alpha
        }

    else
        -- unfocused window in unfocused stack: most dimmed
        -- icon mode hides bg entirely (alpha=0); pill mode keeps a faint bg (0.2)
        return {
            bg = withAlpha(self.showIcons and 0 or 0.2),
            img = opts.alpha / (opts.iconDimmer + (opts.iconDimmer * 0.70)),
        }
    end
end -- }}}

function Indicator:getShadowAttrs(isWinFocused) -- {{{
    -- Returns {blurRadius, color, offset} based on focus state.
    local iconsDisabledDimmer = self.showIcons and 1 or 5 -- pills get much subtler shadows than icons
    local alphaDimmer = (isWinFocused and 6 or 7) * iconsDisabledDimmer
    local blurDimmer = (isWinFocused and 15.0 or 7.0) / iconsDisabledDimmer

    -- Shadows cast outward toward screen edges, as if from a
    -- light source at the screen's center
    local xDirection = (self.side == 'left') and -1 or 1
    local offset = {
        h = (isWinFocused and 3.0 or 2.0) * -1.0,                              -- drop shadow (negative = downward)
        w = ((isWinFocused and 7.0 or 6.0) * xDirection) / iconsDisabledDimmer, -- cast outward toward screen edge
    }

    return {
        blurRadius = blurDimmer,
        color = {alpha = 1 / alphaDimmer},
        offset = offset,
    }
end -- }}}

function Indicator:getScreenSide(frame, screenWidth) -- {{{
    -- Returns the side of the screen that the window is (mostly) on: "left" or "right"
    local thresh = 0.75
    local percR = (frame.x + frame.w) / screenWidth
    local percL = (screenWidth - frame.x) / screenWidth
    return (percR > thresh and percL < thresh) and 'right' or 'left'
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
