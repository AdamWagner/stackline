local u = require 'stackline.lib.utils'

-- ┌───────────────┐
-- │ Window module │
-- └───────────────┘
local Window = {}
-- TODO: Click on indicator to activate target window (like tabs) https://github.com/AdamWagner/stackline/issues/19

function Window:new(hsWin) -- {{{
    print("hsWin.stackIdx", hsWin.stackIdx)
    local ws = {
        title = hsWin:title(), -- window title
        app = hsWin:application():name(), -- app name (string)
        id = hsWin:id(), -- window id (string) NOTE: the ID is the same as yabai! So we could interopt if we need to
        frame = hsWin:frame(), -- x,y,w,h of window (table)
        -- stackIdx = hsWin.stackIdx, -- only from yabai, unfort.
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

function Window:isStackFocused() -- {{{
    return self.stack:anyFocused()
end -- }}}

function Window:setupIndicator() -- {{{
    -- Config
    self.showIcons = Sm:getShowIconsState()
    self:isStackFocused()

    -- TODO: move into stackConfig module (somehow… despite its lack of support for nested keys :/)
    self.config = {
        color = {white = 0.90},
        alpha = 1,

        dimmer = 2.5, -- larger numbers increase contrast b/n focused & unfocused states
        iconDimmer = 1.1, -- custom dimmer for icons

        size = 32,
        radius = 3,
        padding = 4,
        iconPadding = 4,
        pillThinness = 6,

        vertSpacing = 1.2,
        offset = {y = 2, x = 4},
        -- example: overlapped with window + percent top offset
        --  offset = { y = self.frame.h * 0.1, x = -(self.width / 2) }

        shouldFade = true,
        fadeDuration = 0.2,
    }

    local c = self.config -- alias config for convenience

    -- computed from config
    self.width = self.showIcons and c.size or (c.size / c.pillThinness)
    self.iconRadius = self.width / 3

    -- Set canvas to fill entire screen
    local screenFrame = self._win:screen():frame()

    -- subtract screen x,y from window x,y
    -- window frame must be relative to screen to support multi-monitor setups
    for _, coord in pairs({'x', 'y'}) do
        self.frame[coord] = self.frame[coord] - screenFrame[coord]
    end

    self.canvas_frame = screenFrame

    -- Display indicators on 
    --   left edge of windows on the left side of the screen, &
    --   right edge of windows on the right side of the screen
    self.side = self:getScreenSide()
    local xval
    -- local xval = self.frame.x

    -- DONE: Limit the stack left/right side to the screen boundary so it doesn't go off screen https://github.com/AdamWagner/stackline/issues/21
    if self.side == 'right' then
        xval = (self.frame.x + self.frame.w) + c.offset.x
        if xval + self.width > screenFrame.w then
            -- don't go beyond the right screen edge
            xval = screenFrame.w - self.width
        end
    else
        xval = self.frame.x - (self.width + c.offset.x)
        xval = math.max(xval, 0) -- don't go beyond left screen edge
    end

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
end -- }}}

function Window:drawIndicator(overrideOpts) -- {{{
    -- should there be a dedicated "Indicator" class to perform the actual drawing?

    local opts = u.extend(self.config, overrideOpts or {})
    local radius = self.showIcons and self.iconRadius or opts.radius
    local fadeDuration = opts.shouldFade and opts.fadeDuration or 0

    self.focus = self:isFocused()
    self.stackFocus = true

    if self.indicator then
        self.indicator:delete()
    end

    self.indicator = hs.canvas.new(self.canvas_frame)

    self.indicator:insertElement({
        type = "rectangle",
        action = "fill", -- options: strokeAndFill, stroke, fill
        fillColor = self:getColorAttrs(self.stackFocus, self.focus).bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        padding = 60,
        withShadow = true,
        shadow = self:getShadowAttrs(),
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

    self.indicator:show(fadeDuration)
end -- }}}

function Window:redrawIndicator() -- {{{
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

    -- LOGIC: Redraw according to what changed.
    -- Supports indicating the *last-active* window in an unfocused stack.
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

        if self.focus and stackConfig:get('enableTmpFixForHsBug') then
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
    local thresh = 0.75
    local screenWidth = self._win:screen():fullFrame().w

    local leftEdge = self.frame.x
    local rightEdge = self.frame.x + self.frame.w

    local percR = 1 - ((screenWidth - rightEdge) / screenWidth)
    local percL = (screenWidth - leftEdge) / screenWidth

    local side = (percR > thresh and percL < thresh) and 'right' or 'left'

    return side

    -- TODO [low-priority]: BUG: Right-side window incorrectly reports as a left-side window with
    -- very large padding settings. Will need to consider coordinates from both
    -- sides of a window. Impact is minimal with smaller threshold (<= 0.75).

    -- TODO [very-low-priority]: find a way to use hs.window.filter.windowsTo{Dir} 
    -- to determine side instead of percLeft/Right
    --    https://www.hammerspoon.org/docs/hs.window.filter.html#windowsToWest
    --      wfd:windowsToWest(self._win)
    --    https://www.hammerspoon.org/docs/hs.window.html#windowsToWest
    --      self._win:windowsToSouth()
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
                            alpha = Sm:getShowIconsState() and 0 or 0.2,
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
    local iconsDisabledDimmer = Sm:getShowIconsState() and 1 or 5
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
    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
    }
end -- }}}

function Window:deleteIndicator() -- {{{
    if self.indicator then
        self.indicator:delete(self.config.fadeDuration)
    end
end -- }}}

function Window:unfocusOtherAppWindows() -- {{{
    u.each(self.otherAppWindows, function(w)
        w:redrawIndicator()
    end)
end -- }}}

return Window
