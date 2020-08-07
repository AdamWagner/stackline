local _ = require 'stackline.utils.utils'

local Stack = {}

function Stack:new(stackData) -- {{{
    self.windows = stackData
    return self
end -- }}}
function Stack:get() -- {{{
    return self
end -- }}}
function Stack:eachWin(fn) -- {{{
    for _idx, win in pairs(self.windows) do
        fn(win)
    end
end -- }}}
function Stack:redrawAllIndicators() -- {{{
    self:eachWin(function(win)
        print('calling redraw indicator')
        -- TODO see if it works *without* win:setupIndicator
        win:setupIndicator()
        win:drawIndicator()
    end)
end -- }}}
function Stack:deleteAllIndicators() -- {{{
    self:eachWin(function(win)
        print('calling delete indicator')
        win:deleteIndicator()
    end)
end -- }}}
function Stack:dimAllIndicators() -- {{{
    self:eachWin(function(win)
        print('calling delete indicator')
        win:drawIndicator({unfocusedAlpha = 1})
    end)
end -- }}}

return Stack
