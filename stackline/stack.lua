local Stack = {}

function Stack:new(stackedWindows) -- {{{
    local stack = {
        windows = stackedWindows
    }
    setmetatable(stack, self)
    self.__index = self
    return stack
end -- }}}

function Stack:get() -- {{{
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
   -- TODO: Incorrect when the 1st window has min-size < stack width. See ./query.lua:105
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
   self:eachWin(function(w)
       w:setupIndicator():drawIndicator()
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

function Stack:getWindowByPoint(p)
   if p.x < 0 or p.y < 0 then
      -- FIX: https://github.com/AdamWagner/stackline/issues/62
      -- NOTE: Window indicator frame coordinates are relative to the window's screen.
      -- So, if click point has negative X or Y vals, then convert its coordinates
      -- to relative to the clicked screen before comparing to window indicator frames.
      -- TODO: Clean this up after fix is confirmed

      -- Get the screen with frame that contains point 'p'
      local function findClickedScreen(_p) -- {{{
         return table.unpack(
            u.filter(hs.screen.allScreens(), function(s)
               return _p:inside(s:frame())
            end)
         )
      end -- }}}

      local clickedScren = findClickedScreen(p)
      p = clickedScren
         and clickedScren:absoluteToLocal(p)
         or p
   end

   return table.unpack(
         u.filter(self.windows, function(w)
          local indicatorFrame = w.indicator and w.indicator:canvasElements()[1].frame
          if not indicatorFrame then return false end
          return p:inside(indicatorFrame) -- NOTE: frame *must* be a hs.geometry.rect instance
      end)
   )
end

return Stack
