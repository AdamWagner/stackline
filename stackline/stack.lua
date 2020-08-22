local u = require 'stackline.lib.utils'
local Class = require 'stackline.lib.self'
-- NOTE: using simple 'self' library fixed the issue of only 1 of N stacks
-- responding to focus events.  Experimented with even smaller libs, but only
-- 'self' worked so far.

-- args: Class(className, parentClass, table [define methods], isGlobal)
local Stack = Class("Stack", nil, {
    windows = {},

    new = function(self, stackedWindows) -- {{{
        self.windows = stackedWindows
    end, -- }}}

    get = function(self) -- {{{
        return self.windows
    end, -- }}}

    getHs = function(self) -- {{{
        return u.map(self.windows, function(w)
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
        return u.filter(self:get(), function(w)
            u.pheader('window in getOtherAppWindows')
            u.p(w)
            return w.app == win.app
        end)
    end, -- }}}

    anyFocused = function(self) -- {{{
        return u.any(self.windows, function(w)
            return w:isFocused()
        end)
    end, -- }}}

    resetAllIndicators = function(self) -- {{{
        self:eachWin(function(win)
            win:setupIndicator()
            win:drawIndicator()
        end)
    end, -- }}}

    redrawAllIndicators = function(self, opts) -- {{{
        self:eachWin(function(win)
            if win.id ~= opts.except then
                win:redrawIndicator()
            end
        end)
    end, -- }}}

    deleteAllIndicators = function(self) -- {{{
        self:eachWin(function(win)
            win:deleteIndicator()
        end)
    end, -- }}}

    -- all occlusion-related methods currently disabled, but should be revisted soon
    -- dimAllIndicators = function(self) -- {{{
    --     self:eachWin(function(win)
    --         win:drawIndicator({unfocusedAlpha = 1})
    --     end)
    -- end, -- }}}

    -- restoreAlpha = function(self) -- {{{
    --     self:eachWin(function(win)
    --         win:drawIndicator({unfocusedAlpha = nil})
    --     end)
    -- end, -- }}}

    -- isWindowOccludedBy = function(self, otherWin, win) -- {{{
    --     -- Test uses optional 'win' arg if provided,
    --     -- otherwise test uses 1st window of stack
    --     local stackedFrame = win and win:frame() or self:frame()
    --     return stackedFrame:inside(otherWin:frame())
    -- end, -- }}}

    -- isOccluded = function(self) -- {{{
    --     -- FIXES: https://github.com/AdamWagner/stackline/issues/11
    --     -- When a stack that has "zoom-parent": 1 occludes another stack, the
    --     -- occluded stack's indicators shouldn't be displaed

    --     -- Returns true if any non-stack window occludes the stack's frame.
    --     -- This can occur when an unstacked window is zoomed to cover a stack.
    --     -- In this situation, we  want to hide or dim the occluded stack's indicators

    --     local stackedHsWins = self:getHs()

    --     function notInStack(hsWin)
    --         return not u.include(stackedHsWins, hsWin)
    --     end

    --     local windowsCurrSpace = wfd:getWindows()
    --     local nonStackWindows = u.filter(windowsCurrSpace, notInStack)

    --     -- true if *any* non-stacked windows occlude the stack's frame
    --     -- NOTE: u.any() works, hs.fnutils.some does NOT work :~
    --     local stackIsOccluded = u.any(u.map(nonStackWindows, function(w)
    --         return self:isWindowOccludedBy(w)
    --     end))
    --     return stackIsOccluded
    -- end, -- }}}
})

return Stack
