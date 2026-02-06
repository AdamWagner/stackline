--[[ 
Window model AND all indicator rendering logic (the largest module).
Each Window wraps an hs.window, computes stack grouping IDs, and owns a
single hs.canvas for its indicator. Contains both the slow path (setupIndicator
+ drawIndicator: full canvas creation) and the fast path (redrawIndicator:
in-place color/shadow/opacity updates based on focus state changes).
]]
local log   = hs.logger.new('window', 'info')
log.i('Loading module: window')

local Window = {}

function Window:new(hsWin) -- {{{
    local stackIdResult = self:makeStackId(hsWin)
    local ws = {
        title      = hsWin:title(),              -- window title
        app        = hsWin:application():name(), -- app name (string)
        id         = hsWin:id(),                 -- window id (string) NOTE: HS win.id == yabai win.id
        frame      = hsWin:frame(),              -- x,y,w,h of window (table)
        stackId    = stackIdResult.stackId,      -- "{{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
        topLeft    = stackIdResult.topLeft,      -- "{{x}|{y}" e.g., "35|63" (string)
        stackIdFzy = stackIdResult.fzyFrame,     -- fuzzy "{x}|{y}|{w}|{h}" rounded by fuzzFactor (string)
        _win       = hsWin,                      -- hs.window object (table)
        screen     = hsWin:screen():id(),
        indicator  = nil,                        -- the canvas element (table)
    }
    setmetatable(ws, self)
    self.__index = self

    log.i( ('Window:new(%s)'):format(ws.id) )

    return ws
end -- }}}

function Window:isFocused() -- {{{
    local focusedWin = hs.window.focusedWindow()
    return focusedWin ~= nil and self.id == focusedWin:id()
end -- }}}

function Window:isStackFocused() -- {{{
    return self.stack:anyFocused()
end -- }}}

function Window:setupIndicator() -- {{{
    log.d('setupIndicator for', self.id)
    self.config = stackline.config:get('appearance')
    local c = self.config
    self.showIcons = c.showIcons

    -- computed from config
    self.width = self.showIcons and c.size or (c.size / c.pillThinness) -- icons are square; pills are narrow
    self.iconRadius = self.width / c.radius

    -- Set canvas to fill entire screen
    self.screen = self._win:screen()
    self.frame = self.screen:absoluteToLocal(hs.geometry(self._win:frame())) -- canvas uses screen-relative positioning

    local xval = self:getIndicatorPosition()

    -- Store  canvas elements indexes to reference via :elementAttribute()
    -- https://www.hammerspoon.org/docs/hs.canvas.html#elementAttribute
    self.rectIdx = 1
    self.iconIdx = 2

    -- NOTE: self.stackIdx comes from yabai. Window is stacked if stackIdx > 0
    self.indicator_rect = {
        x = xval,
        y = self.frame.y + c.offset.y +                        -- stack indicators vertically by stackIdx
            ((self.stackIdx - 1) * c.size * c.vertSpacing),
        w = self.width,
        h = c.size,
    }

    self.icon_rect = {
        x = xval + c.iconPadding,
        y = self.indicator_rect.y + c.iconPadding,
        w = self.indicator_rect.w - (c.iconPadding * 2),
        h = self.indicator_rect.h - (c.iconPadding * 2),
    }
    return self
end -- }}}

function Window:drawIndicator(overrideOpts) -- {{{
    log.i('drawIndicator for', self.id)
    -- should there be a dedicated "Indicator" class to perform the actual drawing?
    local opts = u.extend(u.copy(self.config), overrideOpts or {})
    local radius = self.showIcons and self.iconRadius or opts.radius
    local fadeDuration = opts.shouldFade and opts.fadeDuration or 0

    self.winFocused = self:isFocused()
    self.stackFocused = self:isStackFocused()

    if self.indicator then              -- clean up previous canvas if rebuilding
        self.indicator:delete()
    end

    -- TODO: Should we really create a new canvas for each window? Or should
    -- there be one canvas per screen/space into which each window's indicator element is appended?
    self.indicator = hs.canvas.new(self.screenFrame)

    local colorAttrs = self:getColorAttrs(self.stackFocused, self.winFocused)

    self.indicator:insertElement({
        type = "rectangle",
        action = "fill", -- options: strokeAndFill, stroke, fill
        fillColor = colorAttrs.bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow = true,
        shadow = self:getShadowAttrs(self.winFocused),
        -- trackMouseEnterExit = true,
        -- trackMouseByBounds = true,
        -- trackMouseDown = true,
    }, self.rectIdx)

    if self.showIcons then
        -- TODO [low priority]: Figure out how to prevent clipping when adding a subtle shadow
        -- to the icon to help distinguish icons with a near-white edge.Note
        -- that `padding` attribute, which works for rects, does not work for images.
        self.indicator:insertElement({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.icon_rect,
            imageAlpha = colorAttrs.img,
        }, self.iconIdx)
    end

    self.indicator:clickActivating(false) -- clicking on a canvas element should NOT bring Hammerspoon wins to front
    self.indicator:show(fadeDuration)
    return self
end -- }}}

function Window:redrawIndicator() -- {{{
    log.i('redrawIndicator for', self.id)

    -- Compare live focus against render state to detect changes.
    -- Render state (self.winFocused, self.stackFocused) persists between calls
    -- so that each call can detect what changed since the last redraw.
    local isWinFocused = self:isFocused()
    local isStackFocused = self:isStackFocused()

    local winChanged = isWinFocused ~= self.winFocused
    local stackChanged = isStackFocused ~= self.stackFocused

    -- HS #2400 workaround: manually redraw same-app windows on focus gain.
    -- Runs BEFORE the early return because "last-active" preservation keeps
    -- winFocused=true after leaving a stack, so winChanged may be false even
    -- though focus genuinely moved here from a same-app window in another stack.
    -- Safe: unfocusOtherAppWindows calls redrawIndicator on unfocused windows,
    -- which won't re-trigger (isWinFocused=false), so no recursion.
    if isWinFocused and stackline.config:get('features.hsBugWorkaround') then
        self:unfocusOtherAppWindows()
    end

    if not winChanged and not stackChanged then return false end

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

    -- Trigger sibling redraws on stack focus transitions.
    if stackChanged and (winChanged or isWinFocused) then
        self.stack:redrawAllIndicators({except = self.id})
    end

    -- Update canvas
    if not self.indicator then           -- safety net: create indicator if it doesn't exist yet
        self:setupIndicator()
    end

    local rect = self.indicator[self.rectIdx]
    local icon = self.indicator[self.iconIdx]

    local colorAttrs = self:getColorAttrs(self.stackFocused, self.winFocused)
    rect.fillColor = colorAttrs.bg
    if self.showIcons then
        icon.imageAlpha = colorAttrs.img
    end
    rect.shadow = self:getShadowAttrs(self.winFocused)
end -- }}}

function Window:getScreenSide() -- {{{
    -- Returns the side of the screen that the window is (mostly) on
    -- Retval: "left" or "right"
    local thresh = 0.75
    local screenWidth = self._win:screen():fullFrame().w

    local leftEdge  = self.frame.x
    local rightEdge = self.frame.x + self.frame.w
    local percR     = rightEdge / screenWidth                       -- how far right edge extends across screen (0→1)
    local percL     = (screenWidth - leftEdge) / screenWidth      -- how far left edge is from right side (0→1)

    local side = (percR > thresh and percL < thresh) and 'right' or 'left'
    return side

    -- TODO [low-priority]: BUG: Right-side window incorrectly reports as a left-side window with {{{
    -- very large padding settings. Will need to consider coordinates from both
    -- sides of a window. Impact is minimal with smaller threshold (<= 0.75). }}}

    -- TODO [very-low-priority]: find a way to use hs.window.filter.windowsTo{Dir}  {{{
    -- to determine side instead of percLeft/Right
    --    https://www.hammerspoon.org/docs/hs.window.filter.html#windowsToWest
    --      stackline.wf:windowsToWest(self._win)
    --    https://www.hammerspoon.org/docs/hs.window.html#windowsToWest
    --      self._win:windowsToSouth() }}}

end -- }}}

function Window:getIndicatorPosition() -- {{{
    -- Display indicators on left edge of windows on the left side of the screen,
    -- & right edge of windows on the right side of the screen
    local xval
    local c = self.config
    self.screenFrame = self.screen:fullFrame()
    self.side = self:getScreenSide()

    -- Clamp indicators to screen boundary to prevent drawing offscreen
    -- https://github.com/AdamWagner/stackline/issues/21
    if self.side == 'right' then xval = (self.frame.x + self.frame.w) + c.offset.x   -- position indicators on right edge
        if xval + self.width > self.screenFrame.w then      -- don't go beyond the right screen edge
            xval = self.screenFrame.w - self.width
        end
    else   -- side is 'left'
        xval = self.frame.x - (self.width + c.offset.x)     -- position indicators on left edge
        xval = math.max(xval, 0)                            -- don't go beyond left screen edge
    end
    return xval
end -- }}}

function Window:getColorAttrs(isStackFocused, isWinFocused) -- {{{
    -- Returns {bg = fillColor, img = imageAlpha} based on focus state.
    -- Called by drawIndicator (slow path) and redrawIndicator (fast path).
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
        local showIcons = self.showIcons
        return {
            bg = withAlpha(showIcons and 0 or 0.2),
            img = opts.alpha / (opts.iconDimmer + (opts.iconDimmer * 0.70)),
        }
    end
end -- }}}

function Window:getShadowAttrs(isWinFocused) -- {{{
    -- Returns {blurRadius, color, offset} based on focus state.
    -- Called by drawIndicator (slow path) and redrawIndicator (fast path).
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

    -- TODO [just for fun]: Dust off an old Geometry textbook and try get the shadow's angle to rotate around a point at the center of the screen (aka, 'light source')
    -- Here's a super crude POC that uses the indicator's stack index such that
    -- higher indicators have a negative Y offset and lower indicators have a positive Y offset
    --   h = (self.winFocused and 3.0 or 2.0 - (2 + (self.stackIdx * 5))) * -1.0,

    return {
        blurRadius = blurDimmer,
        color = {alpha = 1 / alphaDimmer}, -- TODO align all alpha values to be defined like this (1/X)
        offset = offset,
    }
end -- }}}

function Window:iconFromAppName() -- {{{
    local appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:makeStackId(hsWin) -- {{{
    local frame = hsWin:frame():floor() -- floor to avoid sub-pixel differences

    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h

    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    local roundToFuzzFactor = u.partial(u.roundToNearest, fuzzFactor)
    local ff = u.map({x, y, w, h}, roundToFuzzFactor) -- round all dimensions by fuzzFactor

    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
        fzyFrame = table.concat(ff, '|'),
    }
end -- }}}

function Window:deleteIndicator() -- {{{
    log.d('deleteIndicator for', self.id)
    if self.indicator then
        self.indicator:delete(self.config.fadeDuration)
    end
end -- }}}

function Window:unfocusOtherAppWindows() -- {{{
    -- Part of the HS #2400 workaround: when focusing a window, manually redraw
    -- other windows from the same app since HS may not fire unfocus events for them.
    log.i('unfocusOtherAppWindows for', self.id)
    u.each(self.otherAppWindows, function(w)
        w:redrawIndicator()
    end)
end -- }}}

function Window:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

return Window
