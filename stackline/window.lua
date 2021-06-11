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
        stackIdFzy = stackIdResult.fzyFrame,     -- "{{x}|{y}" e.g., "35|63" (string)
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
    if focusedWin == nil then
        return false
    end
    local isFocused = self.id == focusedWin:id()
    return isFocused
end -- }}}

function Window:isStackFocused() -- {{{
    return self.stack:anyFocused()
end -- }}}

function Window:setupIndicator() -- {{{
    log.d('setupIndicator for', self.id)
    self.config = stackline.config:get('appearance')
    local c = self.config
    self.showIcons = c.showIcons

    self:isStackFocused()

    -- computed from config
    self.width = self.showIcons and c.size or (c.size / c.pillThinness)
    self.iconRadius = self.width / self.config.radius

    -- Set canvas to fill entire screen
    self.screen = self._win:screen()
    self.frame = self.screen:absoluteToLocal(hs.geometry(self._win:frame()))

    local xval = self:getIndicatorPosition()

    -- Store  canvas elements indexes to reference via :elementAttribute()
    -- https://www.hammerspoon.org/docs/hs.canvas.html#elementAttribute
    self.rectIdx = 1
    self.iconIdx = 2

    -- NOTE: self.stackIdx comes from yabai. Window is stacked if stackIdx > 0
    self.indicator_rect = {
        x = xval,
        y = self.frame.y + c.offset.y +
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
    local opts = u.extend(self.config, overrideOpts or {})
    local radius = self.showIcons and self.iconRadius or opts.radius
    local fadeDuration = opts.shouldFade and opts.fadeDuration or 0

    self.focus = self:isFocused()
    self.stackFocus = true

    if self.indicator then
        self.indicator:delete()
    end

    -- TODO: Should we really create a new canvas for each window? Or should
    -- there be one canvas per screen/space into which each window's indicator element is appended?
    self.indicator = hs.canvas.new(self.screenFrame)

    self.indicator:insertElement({
        type = "rectangle",
        action = "fill", -- options: strokeAndFill, stroke, fill
        fillColor = self:getColorAttrs(self.stackFocus, self.focus).bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow = true,
        shadow = self:getShadowAttrs(),
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
            imageAlpha = self:getColorAttrs(self.stackFocus, self.focus).img,
        }, self.iconIdx)
    end

    self.indicator:clickActivating(false) -- clicking on a canvas elment should NOT bring Hammerspoon wins to front
    self.indicator:show(fadeDuration)
    return self
end -- }}}

function Window:redrawIndicator() -- {{{
    log.i('redrawIndicator for', self.id)
    local isWindowFocused = self:isFocused()
    local isStackFocused = self:isStackFocused()

    -- has stack, window focus changed?
    local stackFocusChange = isStackFocused ~= self.stackFocus
    local windowFocusChange = isWindowFocused ~= self.focus

    -- permutations of stack, window change combos
    local noChange = not stackFocusChange and not windowFocusChange
    local bothChange = stackFocusChange and windowFocusChange
    local onlyStackChange = stackFocusChange and not windowFocusChange
    local onlyWinChange = not stackFocusChange and windowFocusChange

    -- TODO: Refactor to reduce complexity
    -- LOGIC: Redraw according to what changed.
    -- Supports indicating the *last-active* window in an unfocused stack.
    -- TODO: Fix bug causing stack to continue appearing focused when switching to a non-stacked window from the same app as the focused stack window. Another casualtiy of HS #2400 :<
    if noChange then
        -- bail early if there's nothing to do
        return false

    elseif bothChange then
        -- If both change, it means a *focused* window's stack is now unfocused.
        self.stackFocus = isStackFocused
        self.stack:redrawAllIndicators({except = self.id})
        -- Despite the window being unfocused, do *not* update self.focus
        -- (unfocused stack + focused window = last-active window)

    elseif onlyWinChange then
        -- changing window focus within a stack
        self.focus = isWindowFocused

        local enableTmpFix = stackline.config:get('features.hsBugWorkaround')
        if self.focus and enableTmpFix then
            self:unfocusOtherAppWindows()
        end

    elseif onlyStackChange then
        -- aka, already unfocused window's stack is now unfocused, too
        -- so update stackFocus
        self.stackFocus = isStackFocused

        -- if only stack changed *and* win is focused, it means a previously
        -- unfocused stack is now focused, so redraw other window indicators
        if isWindowFocused then
            self.stack:redrawAllIndicators({except = self.id})
        end
    end

    if not self.indicator then
        self:setupIndicator()
    end

    -- ACTION: Update canvas values
    local f = self.focus
    local rect = self.indicator[self.rectIdx]
    local icon = self.indicator[self.iconIdx]

    local colorAttrs = self:getColorAttrs(self.stackFocus, self.focus)
    rect.fillColor = colorAttrs.bg
    if self.showIcons then
        icon.imageAlpha = colorAttrs.img
    end
    rect.shadow = self:getShadowAttrs(f)
end -- }}}

function Window:getScreenSide() -- {{{
    -- Returns the side of the screen that the window is (mostly) on
    -- Retval: "left" or "right"
    local thresh = 0.75
    local screenWidth = self._win:screen():fullFrame().w

    local leftEdge  = self.frame.x
    local rightEdge = self.frame.x + self.frame.w
    local percR     = 1 - ((screenWidth - rightEdge) / screenWidth)
    local percL     = (screenWidth - leftEdge) / screenWidth

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

    -- DONE: Limit stack left/right side to screen boundary to prevent drawing offscreen https://github.com/AdamWagner/stackline/issues/21
    if self.side == 'right' then xval = (self.frame.x + self.frame.w) + c.offset.x   -- position indicators on right edge
        if xval + self.width > self.screenFrame.w then           -- don't go beyond the right screen edge
            xval = self.screenFrame.w - self.width
        end
    else   -- side is 'left'
        xval = self.frame.x - (self.width + c.offset.x)     -- position indicators on left edge
        xval = math.max(xval, 0)                            -- don't go beyond left screen edge
    end
    return xval
end -- }}}

function Window:getColorAttrs(isStackFocused, isWinFocused) -- {{{
    local opts = self.config
    -- Lookup bg color and image alpha based on stack + window focus
    -- e.g., fillColor = self:getColorAttrs(self.stackFocus, self.focus).bg
    --       iconAlpha = self:getColorAttrs(self.stackFocus, self.focus).img
    local colorLookup = {
        stack = {
            ['true'] = {
                window = {
                    ['true'] = {
                        bg = u.extend(opts.color, {alpha = opts.alpha}),
                        img = opts.alpha,
                    },
                    ['false'] = {
                        bg = u.extend(u.copy(opts.color),
                            {alpha = opts.alpha / opts.dimmer}),
                        img = opts.alpha / opts.iconDimmer,
                    },
                },
            },
            ['false'] = {
                window = {
                    ['true'] = {
                        bg = u.extend(u.copy(opts.color), {
                            alpha = opts.alpha / (opts.dimmer / 1.2),
                        }),
                        -- last-focused icon stays full alpha when stack unfocused
                        img = opts.alpha,
                    },
                    ['false'] = {
                        bg = u.extend(u.copy(opts.color), {
                            alpha = stackline.manager:getShowIconsState() and 0 or
                                0.2,
                        }),
                        -- unfocused icon has slightly lower alpha when stack also unfocused
                        img = opts.alpha /
                            (opts.iconDimmer + (opts.iconDimmer * 0.70)),
                    },
                },
            },
        },
    }
    -- end

    local isStackFocusedKey = tostring(isStackFocused)
    local isWinFocusedKey = tostring(isWinFocused)
    return colorLookup.stack[isStackFocusedKey].window[isWinFocusedKey]
end -- }}}

function Window:getShadowAttrs() -- {{{
    -- less opaque & blurry when iconsDisabled
    -- even less opaque & blurry when unfocused
    local iconsDisabledDimmer = stackline.manager:getShowIconsState() and 1 or 5
    local alphaDimmer = (self.focus and 6 or 7) * iconsDisabledDimmer
    local blurDimmer = (self.focus and 15.0 or 7.0) / iconsDisabledDimmer

    -- Shadows should cast outwards toward the screen edges as if due to the glow of onscreen windows…
    -- …or, if you prefer, from a light source originating from the center of the screen.
    local xDirection = (self.side == 'left') and -1 or 1
    local offset = {
        h = (self.focus and 3.0 or 2.0) * -1.0,
        w = ((self.focus and 7.0 or 6.0) * xDirection) / iconsDisabledDimmer,
    }

    -- TODO [just for fun]: Dust off an old Geometry textbook and try get the shadow's angle to rotate around a point at the center of the screen (aka, 'light source')
    -- Here's a super crude POC that uses the indicator's stack index such that
    -- higher indicators have a negative Y offset and lower indicators have a positive Y offset
    --   h = (self.focus and 3.0 or 2.0 - (2 + (self.stackIdx * 5))) * -1.0,

    return {
        blurRadius = blurDimmer,
        color = {alpha = 1 / alphaDimmer}, -- TODO align all alpha values to be defined like this (1/X)
        offset = offset,
    }
end -- }}}

function Window:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:makeStackId(hsWin) -- {{{
    local frame = hsWin:frame():floor()

    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h

    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    local roundToFuzzFactor = u.partial(u.roundToNearest, fuzzFactor)
    local ff = u.map({x, y, w, h}, roundToFuzzFactor)

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
