local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

local Class = require 'stackline.utils.self'
-- NOTE: using simple 'self' library fixed 
-- the issue of only 1 of N stacks responding to focus events.
-- Experimented with even smaller libs, but only 'self' worked so far.

-- Class example in vanilla lua
-- https://github.com/lharck/inheritance-example

-- ARGS: Class(className,
--             parentClass,
--             table [define methods],
--             isGlobal)
local Stack = Class("Stack", nil, {
    windows = {},

    new = function(self, stackedWindows) -- {{{
        self.windows = stackedWindows
        self.id = stackedWindows[1].stackId
    end, -- }}}

    get = function(self) -- {{{
        return self.windows
    end, -- }}}

    getHs = function(self) -- {{{
        return _.map(self.windows, function(w)
            return w._win
        end)
    end, -- }}}

    frame = function(self) -- {{{
        -- All stacked windows have the same dimensions, 
        -- so the 1st Hs window's frame is ~= to the stack's frame
        -- FIXME: Incorrect when the 1st window has min-size < stack width 
        --        See ./query.lua:104
        return self.windows[1]._win:frame()
    end, -- }}}

    eachWin = function(self, fn) -- {{{
        for _idx, win in pairs(self.windows) do
            fn(win)
        end
    end, -- }}}

    getOtherAppWindows = function(self, win) -- {{{
        -- NOTE: may not need when HS issue #2400 is closed
        return _.filter(self:get(), function(w)
            _.pheader('window in getOtherAppWindows')
            _.p(w)
            return w.app == win.app
        end)
    end, -- }}}

    redrawAllIndicators = function(self) -- {{{
        self:eachWin(function(win)
            win:setupIndicator()
            win:drawIndicator()
        end)
    end, -- }}}

    deleteAllIndicators = function(self) -- {{{
        self:eachWin(function(win)
            win:deleteIndicator()
        end)
    end, -- }}}

    dimAllIndicators = function(self) -- {{{
        self:eachWin(function(win)
            win:drawIndicator({unfocusedAlpha = 1})
        end)
    end, -- }}}

    restoreAlpha = function(self) -- {{{
        self:eachWin(function(win)
            win:drawIndicator({unfocusedAlpha = nil})
        end)
    end, -- }}}

    isWindowOccludedBy = function(self, otherWin, win) -- {{{
        -- Test uses optional 'win' arg if provided,
        -- otherwise test uses 1st window of stack
        local stackedFrame = win and win:frame() or self:frame()
        return stackedFrame:inside(otherWin:frame())
    end, -- }}}

    isOccluded = function(self) -- {{{
        -- FIXES: https://github.com/AdamWagner/stackline/issues/11
        -- When a stack that has "zoom-parent": 1 occludes another stack, the
        -- occluded stack's indicators shouldn't be displaed

        -- Returns true if any non-stack window occludes the stack's frame.
        -- This can occur when an unstacked window is zoomed to cover a stack.
        -- In this situation, we  want to *hide* the occluded stack's indicators

        -- DONE: Convert to Stack instance method (wouldn't need to pass in the 'stack' arg)
        local stackedHsWins = self:getHs()

        function notInStack(hsWin)
            return not u.include(stackedHsWins, hsWin)
        end

        local windowsCurrSpace = wfd:getWindows()
        local nonStackWindows = _.filter(windowsCurrSpace, notInStack)

        -- true if *any* non-stacked windows occlude the stack's frame
        -- NOTE: u.any() works, hs.fnutils.some does NOT work :~
        local stackIsOccluded = u.any(_.map(nonStackWindows, function(w)
            return self:isWindowOccludedBy(w)
        end))
        return stackIsOccluded
    end -- }}}
})

return Stack
