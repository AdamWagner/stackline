local u = require 'stackline.lib.utils'
local Class = require 'stackline.lib.class'
local Queue = require 'stackline.lib.data-structures.Queue'

local Indicator = Class()

function Indicator:new(win)  -- {{{
    self.config    = stackline.config:get('appearance')
    self.c         = self.config

    self.win       = win
    self.stack     = win.stack
    self.screen    = win._win:screen()
    self.canvas    = nil
    self.history   = Queue:new()

    self.rectIdx   = 1   -- Store  canvas elements indexes to reference via :elementAttribute()
    self.iconIdx   = 2   -- hammerspoon.org/docs/hs.canvas.html#elementAttribute

    return self
end  -- }}}

function Indicator:init() -- {{{
    local c = self.config

    self.width = self.c.showIcons and c.size or (c.size / c.pillThinness)
    self.iconRadius = self.width / c.radius

    self.frame = self.screen:absoluteToLocal(hs.geometry(self.win._win:frame()))  -- Set canvas to fill entire screen

    local xval = self:getIndicatorPosition()

    -- NOTE: self.stackIdx comes from yabai. Window is stacked if stackIdx > 0
    self.canvas_rect = {
        x = xval,
        y = self.frame.y + c.offset.y + (self.win.stackIdx - 1) * c.size * c.vertSpacing,
        w = self.width,
        h = c.size,
    }

    self.icon_rect = {
        x = xval + c.iconPadding,
        y = self.canvas_rect.y + c.iconPadding,
        w = self.canvas_rect.w - (c.iconPadding * 2),
        h = self.canvas_rect.h - (c.iconPadding * 2),
    }
    return self
end -- }}}

-- TODO: Consider moving :updateState() & :changes() into the Window module
function Indicator:updateState()  -- {{{
    self.history:push({
        focus = self.win:isFocused(),
        stackFocus = self.stack:isFocused()
    })
end  -- }}}

function Indicator:changes()  -- {{{
    if self.history:size() < 2 then return true end -- "noChange true"
    local curr, last = self.history:peek2()
    local windowFocusChange = curr.focus ~= last.focus
    local stackFocusChange = curr.stackFocus ~= last.stackFocus

      -- permutations of stack, window change combos
    local noChange = not stackFocusChange and not windowFocusChange
    local bothChange = stackFocusChange and windowFocusChange
    local onlyStackChange = stackFocusChange and not windowFocusChange
    local onlyWinChange = not stackFocusChange and windowFocusChange

    return noChange, bothChange, onlyStackChange, onlyWinChange
end  -- }}}

function Indicator:addElement(stackFocus, focus, radius) -- {{{
    local fillColor = self:getColorAttrs(stackFocus, focus).bg

    self.canvas:insertElement({
        type             = "rectangle",
        action           = "fill", -- options: strokeAndFill, stroke, fill
        fillColor        = fillColor,
        frame            = self.canvas_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        withShadow       = true,
        shadow           = self:getShadowAttrs(),
    }, self.rectIdx)
end -- }}}

function Indicator:addIcon(stackFocus, focus) -- {{{
    self.canvas:insertElement({
        type = "image",
        image = self:iconFromAppName(),
        frame = self.icon_rect,
        imageAlpha = self:getColorAttrs(stackFocus, focus).img,
    }, self.iconIdx)
end -- }}}

function Indicator:draw(overrideOpts) -- {{{
    if self.canvas then self.canvas:delete() end

    self.config = table.merge(self.config, overrideOpts or {})
    local c = self.config

    local radius = c.showIcons and self.iconRadius or self.radius
    local fadeDuration = c.shouldFade and c.fadeDuration or 0

    self:updateState()
    local curr = self.history:peek()
    local stackFocus, focus = curr.stackFocus, curr.focus

    -- TODO: Should we create a new canvas for each window, not each indicator?
    self.canvas = hs.canvas.new(self.screenFrame)

    self:addElement(stackFocus, focus, radius)

    if c.showIcons then
        self:addIcon(stackFocus, focus)
    end

    self.canvas:clickActivating(false) -- clicking on a canvas elment should NOT bring Hammerspoon wins to front
    self.canvas:show(fadeDuration)     -- only fade in if shouldFade is set

    return self
end -- }}}

function Indicator:redraw(evt) -- {{{
    -- LOGIC: Cascade redrawing
    -- Supports indicating the *last-active* window in an unfocused stack.
    -- TODO: Fix bug causing stack to continue appearing focused when switching to a non-stacked window from the same app as the focused stack window. Another casualtiy of HS #2400 :<
    self:updateState()
    local curr = self.history:peek()
    local noChange, bothChange, onlyStackChange, onlyWinChange = self:changes()

    if noChange then -- bail early if there's nothing to do
        return false

    elseif onlyWinChange then -- changing window focus within a stack
        if curr.focus and stackline.config:get('features.hsBugWorkaround') then
            self.win:unfocusOtherAppWindows()
        end

    elseif bothChange then -- If both change, it means a *focused* window's stack is now unfocused.
        self.stack:redrawAllIndicators({except = self.id})

    elseif onlyStackChange then -- aka, already unfocused window's stack is now unfocused, too
        if curr.focus then
            self.stack:redrawAllIndicators({except = self.id})
        end
    end

    if not self.canvas then
        self:init()
    end

    -- ACTION: Update canvas values --------------------------------------------
    local rect = self.canvas[self.rectIdx]
    local icon = self.canvas[self.iconIdx]

    local colorAttrs = self:getColorAttrs(curr.stackFocus, curr.focus)
    rect.fillColor = colorAttrs.bg
    if self.c.showIcons then
        icon.imageAlpha = colorAttrs.img
    end
    rect.shadow = self:getShadowAttrs()
end -- }}}

function Indicator:delete() -- {{{
    local fadeDuration = stackline.config:get('appearance.fadeDuration')

    if self.canvas then
        self.canvas:delete(fadeDuration)
    end
end -- }}}

function Indicator:getIndicatorPosition() -- {{{
    -- Inspo: https://github.com/dreemsoul/awesome-laptop/blob/master/treesome/init.lua
    -- Display indicators on left edge of windows on the left side of the screen,
    -- & right edge of windows on the right side of the screen
    local xval
    local c = self.config
    self.screenFrame = self.screen:frame()
    self.side = self.win:getScreenSide()

    -- DONE: Limit stack left/right side to screen boundary to prevent drawing offscreen https://github.com/AdamWagner/stackline/issues/21
    if self.side == 'right' then
        xval = (self.frame.x + self.frame.w) + c.offset.x -- position indicators on right edge
        if xval + self.width > self.screenFrame.w then -- don't go beyond the right screen edge
            xval = self.screenFrame.w - self.width
        end
    else -- side is 'left'
        xval = self.frame.x - (self.width + c.offset.x) -- position indicators on left edge
        xval = math.max(xval, 0) -- don't go beyond left screen edge
    end
    return xval
end -- }}}

function Indicator:getColorAttrs(isStackFocused, isWinFocused) -- {{{
    local color, alpha, dimmer, iconDimmer = self.c.color, self.c.alpha, self.c.dimmer, self.c.iconDimmer
    -- Lookup bg color and image alpha based on stack + window focus
    -- e.g., fillColor = self:getColorAttrs(self.stackFocus, self.win.focus).bg
    --       iconAlpha = self:getColorAttrs(self.stackFocus, self.win.focus).img
    local colorLookup = {
        stack = {
            ['true'] = {
                window = {
                    ['true'] = {bg = table.merge(color, {alpha = alpha}), img = alpha},
                    ['false'] = {
                        bg = table.merge(u.copy(color), {alpha = alpha / dimmer}),
                        img = alpha / iconDimmer,
                    },
                },
            },
            ['false'] = {
                window = {
                    ['true'] = {
                        bg = table.merge(u.copy(color), {alpha = alpha / (dimmer / 1.2)}), -- last-focused icon stays full alpha when stack unfocused
                        img = alpha,
                    },
                    ['false'] = {
                        bg = table.merge(u.copy(color), {alpha = stackline.manager:getShowIconsState() and 0 or 0.2}), -- unfocused icon has slightly lower alpha when stack also unfocused
                        img = alpha / (iconDimmer + (iconDimmer * 0.70)),
                    },
                },
            },
        },
    }

    return colorLookup
            .stack[tostring(isStackFocused)]
            .window[tostring(isWinFocused)]
end -- }}}

function Indicator:getShadowAttrs() -- {{{
    -- less opaque & blurry when iconsDisabled
    -- even less opaque & blurry when unfocused
    local iconsDisabledDimmer = stackline.manager:getShowIconsState() and 1 or 5
    local alphaDimmer = (self.win.focus and 6 or 7) * iconsDisabledDimmer
    local blurDimmer = (self.win.focus and 15.0 or 7.0) / iconsDisabledDimmer

    -- Shadows should cast outwards toward the screen edges as if due to the glow of onscreen windows…
    -- …or, if you prefer, from a light source originating from the center of the screen.
    local xDirection = (self.side == 'left') and -1 or 1
    local offset = {
        h = (self.win.focus and 3.0 or 2.0) * -1.0,
        w = ((self.win.focus and 7.0 or 6.0) * xDirection) / iconsDisabledDimmer,
    }

    -- TODO [just for fun]: Dust off an old Geometry textbook and try get the shadow's angle to rotate around a point at the center of the screen (aka, 'light source')
    -- Here's a super crude POC that uses the indicator's stack index such that
    -- higher indicators have a negative Y offset and lower indicators have a positive Y offset
    --   h = (self.win.focus and 3.0 or 2.0 - (2 + (self.stackIdx * 5))) * -1.0,
    return {
        blurRadius = blurDimmer,
        color = {alpha = 1 / alphaDimmer}, -- TODO align all alpha values to be defined like this (1/X)
        offset = offset,
    }
end -- }}}

function Indicator:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.win.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

return Indicator
