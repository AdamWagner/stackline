local u = require 'stackline.lib.utils'

local Stack = {}

function Stack:new(stackedWindows) -- {{{
    local stack = {
        windows = stackedWindows
    }
    setmetatable(stack, self)
    self.__index = self
    return stack
end -- }}}

function  Stack:get() -- {{{
    return self.windows
end -- }}}

function Stack:getHs() -- {{{
   return u.map(self.windows, function(w)
       return w._win
   end)
end -- }}}

function Stack:frame() -- {{{
   -- All stacked windows have the same dimensions, 
   -- so the 1st Hs window's frame is ~= to the stack's frame
   -- TODO: Incorrect when the 1st window has min-size < stack width. See ./query.lua:104
   return self.windows[1]._win:frame()
end -- }}}

function Stack:eachWin(fn) -- {{{
   for _idx, win in pairs(self.windows) do
       fn(win)
   end
end -- }}}

function Stack:getOtherAppWindows(win) -- {{{
   -- NOTE: may not need when HS issue #2400 is closed
   return u.filter(self:get(), function(w)
       return w.app == win.app
   end)
end -- }}}

function Stack:anyFocused() -- {{{
   return u.any(self.windows, function(w)
       return w:isFocused()
   end)
end -- }}}

function Stack:resetAllIndicators() -- {{{
   self:eachWin(function(win)
       win:setupIndicator()
       win:drawIndicator()
   end)
end -- }}}

function Stack:redrawAllIndicators(opts) -- {{{
   self:eachWin(function(win)
       if win.id ~= opts.except then
           win:redrawIndicator()
       end
   end)
end -- }}}

function Stack:deleteAllIndicators() -- {{{
   self:eachWin(function(win)
       win:deleteIndicator()
   end)
end -- }}}

function Stack:getWindowByPoint(point) -- {{{
   local foundWin = u.filter(self.windows, function(w)
       local indicatorEls = w.indicator:canvasElements()
       local wFrame = hs.geometry.rect(indicatorEls[1].frame)
       return point:inside(wFrame)
   end)

   if #foundWin > 0 then
       return foundWin[1]
   end
end

return Stack
