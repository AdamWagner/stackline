local u = require 'stackline.lib.utils'
local Class = require 'stackline.lib.self'

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
        -- TODO: Incorrect when the 1st window has min-size < stack width. See ./query.lua:104
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

    getWindowByPoint = function(self, point)
        local foundWin = u.filter(self.windows, function(w)

            local windowFrame = hs.geometry.rect(
                w.indicator:canvasElements()[1].frame)

            local isInside = point:inside(windowFrame)

            -- print('winFrame', hs.inspect(windowFrame))
            -- print('point', point)
            print('is inside', isInside)
            return isInside
        end)

        u.p(foundWin)
        return foundWin
    end,
})

return Stack
