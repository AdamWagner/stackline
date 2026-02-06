--[[ 
A single stack: a group of overlapping windows sharing the same frame.
Contains Window objects, iterators, indicator lifecycle, and click hit-testing.
]]
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
   -- so the 1st HS window's frame is ≈ the stack's frame.
   -- TODO: Incorrect when the 1st window has min-size < stack width (see fuzzy frame detection)
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
   -- SLOW PATH: tears down and recreates canvas elements from scratch.
   -- Called during rebuild after a yabai query.
   self:eachWin(function(w)
       w:setupIndicator():drawIndicator()
   end)
end -- }}}

function Stack:redrawAllIndicators(opts) -- {{{
   -- FAST PATH: updates existing canvas properties in-place (colors, shadow, opacity).
   -- Called on focus changes — no canvas teardown, no icon lookups.
   self:eachWin(function(win)
       if win.id ~= opts.except then -- skip the triggering window (it redraws itself)
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
   if p.x < 0 or p.y < 0 then -- negative coords mean click is on a non-primary screen
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
      p = clickedScren                          -- convert to screen-relative coords
         and clickedScren:absoluteToLocal(p)   -- to match indicator frames
         or p
   end

   return table.unpack(
         u.filter(self.windows, function(w)
          local indicatorFrame = w.indicator and w.indicator:canvasElements()[1].frame -- get the rectangle element's frame
          if not indicatorFrame then return false end
          return p:inside(indicatorFrame) -- NOTE: frame *must* be a hs.geometry.rect instance
      end)
   )
end

return Stack
