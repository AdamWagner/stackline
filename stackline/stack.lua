--[[
A single stack: a group of overlapping windows sharing the same frame.
Contains Window objects, iterators, indicator lifecycle, and click hit-testing.
Inherits from Collection for keyed storage and standard iteration.
]]
local Collection = require 'lib.collection'

local Stack = setmetatable({}, Collection)
Stack.__index = Stack

function Stack.__tostring(self)
    return ('<Stack %s: %d windows>'):format(self.id or '?', self:count())
end

function Stack:new(stackedWindows) -- {{{
    local stack = setmetatable({}, self)
    stack._items = {}
    for _, win in ipairs(stackedWindows) do
        stack:add(win)
    end
    return stack
end -- }}}

-- Convenience accessor: returns array of Window objects.
function Stack:windows() -- {{{
    return self:get()
end -- }}}

function Stack:getHs() -- {{{
   return self:map(function(w)
       return w._win
   end)
end -- }}}

-- All stacked windows have the same dimensions,
-- so the 1st HS window's frame is ≈ the stack's frame.
-- TODO: Incorrect when the 1st window has min-size < stack width (see fuzzy frame detection)
function Stack:frame() -- {{{
   return self:first()._win:frame()
end -- }}}

-- NOTE: may not need when HS issue #2400 is closed
function Stack:getOtherAppWindows(win) -- {{{
   return self:filter(function(w)
       return w.app == win.app
   end)
end -- }}}

function Stack:anyFocused(focusedWinId) -- {{{
   return self:any(function(w)
       return w:isFocused(focusedWinId)
   end)
end -- }}}

-- SLOW PATH: tears down and recreates canvas elements from scratch.
-- Called during rebuild after a yabai query.
function Stack:rebuildAllIndicators() -- {{{
   self:each(function(w)
       w:buildIndicator()
   end)
end -- }}}

-- FAST PATH: updates existing canvas properties in-place (colors, shadow, opacity).
-- Called on focus changes — no canvas teardown, no icon lookups.
function Stack:redrawAllIndicators(opts) -- {{{
   self:each(function(win)
       if win.id ~= opts.except then -- skip the triggering window (it redraws itself)
           win:redrawIndicator()
       end
   end)
end -- }}}

function Stack:deleteAllIndicators() -- {{{
   self:each(function(win)
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

      local clickedScreen = findClickedScreen(p)
      p = clickedScreen                         -- convert to screen-relative coords
         and clickedScreen:absoluteToLocal(p)   -- to match indicator frames
         or p
   end

   return table.unpack(
         self:filter(function(w)
          local indicatorFrame = w.indicator and w.indicator:getHitFrame()
          if not indicatorFrame then return false end
          return p:inside(indicatorFrame) -- NOTE: frame *must* be a hs.geometry.rect instance
      end)
   )
end

return Stack
