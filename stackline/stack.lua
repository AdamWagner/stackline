--[[ === TESTS === {{{

-- == Stack.frameFzyEqual(other) == --

-- = TEST No. 1 = (Compare stack to window by fuzzy frame)
w = stackline.manager:get()[1].windows[2]
res1 = w._stack:frameFzyEqual(w)
--> * Manual action -> resize windows
res2 = w._stack:frameFzyEqual(w)
assert(res1, 'res1 should be "true"')
assert(res2, 'res2 should be "true"')

-- == TEST No. 2 = (stack.push)
s = stackline.manager:get()[1]
s:push({1,2,3,33,3,3})

 }}} ]]

local uiElement = require'classes.UiElement'
local Stack = uiElement:subclass('Stack')

function Stack:new(winGroup)
   self.windows   = winGroup or {}
   self.id        = self.windows.stackId
   self.frame     = function() return self.windows[1]:frame() end
   self.screen    = function() return self.windows[1]._screen end
   self.focusHist = {}

   -- TODO: try setting a *region* on the stack's window filter to automatically pick up new windows added to stack!
   self._wf = hs.window.filter.new(function(w)
        return u.contains(u.map(self.windows, 'id'), w:id())
    end)
end

function Stack:__len()
  -- NOTE that this will create empty `nil` entries in the a stack such that
  -- the # of entires (including nil) == #stack.windows.
  -- This is harmless, but strange.
  return u.len(self.windows)
end

function Stack:push(...) -- {{{
   table.insert(self.windows, ...)
   return self
end -- }}}

function Stack:addWin(win) -- {{{
    win.stackIdx = win.stackIdx or #self.windows+1
    self:push(win)
    return self
end -- }}}

function Stack:removeWin(win) -- {{{
    local w = self:findWindow(win.id)
    if w==nil then return end
    -- TODO: actually remove window from `self.windows`. Note that __eq method breaks hs.fnutils.indexOf (always returns 1st el since they're all "equal" according to frame)
    w:destroy()
end -- }}}

function Stack:sort()
    local byStackIdx = function(a,b) return a.stackIdx < b.stackIdx end
    self.windows = u.sort(self.windows, byStackIdx)
end

function Stack:setupWindows() -- {{{
    -- NOTE: Not part of constructor b/c it requires an initialized instance
    self:sort()
    local stackBackreference = self
    self:eachWin('setup', stackBackreference)
    return self
end -- }}}

function Stack:findWindow(wid) -- {{{
    for _, win in ipairs(self.windows) do
        if win.id == wid then return win end
    end
end -- }}}

function Stack:buildCanvas() -- {{{
   local pos = require 'modules.position'
   local c = stackline.config:get('appearance')
   local x, y = pos.getPosition(self:frame(), nil, self:screen(), c)

   self.container = hs.canvas.new{
      x = x,
      y = y,
      w = c.size,
      h = (#self * c.size * c.vertSpacing),
   }:appendElements({
      action = "fill",
      type = "rectangle",
      fillColor = { alpha = 0.5, blue = 0.2 },
   }):show()

    -- NOTE: Big win here by scoping mouse event detection to just the canvas tht encloses a stack's indicators
    -- TODO: Finish the job.. This is a mere proof of concept at the moment.
    -- TODO: How could click tracking be extracted into a plugin?
	self.container:clickActivating(false)
       :canvasMouseEvents(true, true, true, true)   -- Booleans to fire events for down, up, enter/exit, move
       :level("status")
       :mouseCallback(function(evt, id, x, y)
          self.log.i('Canvas mouse event test callback', evt, id, x, y)
       end)

   return self
end -- }}}

function Stack:eachWin(fn, ...) --[[ {{{
   Given a Window method name as string and optional varargs
   E.g., stack.eachWin('resetIndicator'), stack.eachWin('setup', aStack) ]]
   for _, win in ipairs(self.windows) do
      if type(fn)=='function' then
         fn(win)
      else
         win:call(fn)(...)
      end
   end
   return self
end -- }}}

function Stack:isFocused() -- {{{
   -- A stack is focusedIf when any of the stack's windows are focused
   local isFocused = u.any(self.windows, function(w)
      return w:isFocused()
   end)

   -- Append `current` if history has <= 1 item
   if #self.focusHist <= 1 then
      table.insert(self.focusHist, isFocused)
      return false
   end

   -- Inner fn: `true` if current `isFocused` is different than last recorded val
   local function focusChanged(current) -- {{{
      return current ~= self.focusHist[#self.focusHist]
   end -- }}}

   if focusChanged(isFocused) then
      table.insert(self.focusHist, isFocused) -- Push to focusHIstory if `isFocused` has changed
      self:eachWin(function(w) w.indicator:redraw() end) -- ...and apply "unfocused stack" styling by redrawing all indicators
   end

   return isFocused
end -- }}}

function Stack:getWindowByPoint(p) -- {{{
   -- FIX: https://github.com/AdamWagner/stackline/issues/62
   -- NOTE: Window indicator frame coordinates are relative to the window's screen.
   -- So, if click point has negative X or Y vals, then convert its coordinates
   -- to relative to the clicked screen before comparing to window indicator frames.

   local function ensureRelative(clickPoint) -- {{{
      -- Convert a given `clickPoint` to relative coordinates if needed
      local function isNotRelative(_clickPoint)
         return _clickPoint.x < 0 or _clickPoint.y < 0
      end

      if not isNotRelative(clickPoint) then
         return clickPoint -- as is
      end

      -- Get the screen with frame that contains point 'p'
      local function findClickedScreen(_p)
         return table.unpack(
            u.filter(hs.screen.allScreens(), function(s)
               return _p:inside(s:frame())
            end)
         )
      end

      return findClickedScreen(clickPoint):absoluteToLocal(clickPoint)
        or findClickedScreen(clickPoint)
   end -- }}}

   -- `windowsContainingClickPoint()` could technically return multiple windows, but there *should* only be one window.
   -- Regardless, additional retvals will be discarded by caller.
   local windowsEnclosingPoint = u.filter(self.windows, function(w)
      return w.indicator:contains( ensureRelative(p) )
   end)

   -- Unwrap the filtered list of windows containing click point before returning (we want the *result*, not a list of windows)
   return table.unpack(windowsEnclosingPoint)
end -- }}}

return Stack
