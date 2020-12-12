local observe = require 'lib.kvo'
local u = require 'stackline.lib.utils'
local Indicator = require'stackline.indicator'

-- TODO: remove tmp `onChange()` fn
local function onChange(key,old,new)
  if old ~= new then
    print('\n\nWINDOW ',key, 'changed', '\n old: ', old, '\n new:', new, '\n\n')
  end
end

local Window = {}

function Window:new(hsWin) -- {{{
    local stackIdResult = self:makeStackId(hsWin)

    local ws = {}
    ws.title      = hsWin:title()              -- window title
    ws.app        = hsWin:application():name() -- app name (string)
    ws.id         = hsWin:id()                 -- window id (string) NOTE: HS win.id == yabai win.id
    ws.frame      = hsWin:frame()              -- x,y,w,h of window (table)
    ws.stackId    = stackIdResult.stackId      -- "{{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
    ws.topLeft    = stackIdResult.topLeft      -- "{{x}|{y}" e.g., "35|63" (string)
    ws.stackIdFzy = stackIdResult.fzyFrame     -- "{{x}|{y}" e.g., "35|63" (string)
    ws._win       = hsWin                      -- hs.window object (table)
    ws.screen     = hsWin:screen():id()

    setmetatable(ws, self)
    self.__index = self
    -- ws = observe.add(ws, 'focus', onChange)
    -- ws = observe.add(ws, '_win.frame', onChange)
    return ws
end -- }}}

function Window:update() -- {{{
    local hsWin = self._win
    local stackIdResult = self:makeStackId(hsWin)

    self.title      = hsWin:title()              -- window title
    self.frame      = hsWin:frame()              -- x,y,w,h of window (table)
    self.stackId    = stackIdResult.stackId      -- "{{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
    self.topLeft    = stackIdResult.topLeft      -- "{{x}|{y}" e.g., "35|63" (string)
    self.stackIdFzy = stackIdResult.fzyFrame     -- "{{x}|{y}" e.g., "35|63" (string)
    return self
end -- }}}

function Window:isFocused() -- {{{
  local focusedWin = hs.window.focusedWindow()
  self.focus = focusedWin and (focusedWin:id() == self.id) or false
  return self.focus
end -- }}}

function Window:setupIndicator()  -- {{{
  if self.indicator then self.indicator:delete() end
  self:isFocused()
  -- self.stack:isFocused()
  self.indicator = Indicator
     :new(self)
     :init()
     :draw()
end  -- }}}

function Window:getScreenSide() -- {{{
    -- Returns the side of the screen that the window is (mostly) on
    -- Retval: "left" or "right"
    local thresh = 0.75
    local screenWidth = self._win:screen():fullFrame().w

    local leftEdge  = self.frame.x
    local rightEdge = self.frame.x + self.frame.w
    local percR     = 1 - ((screenWidth - rightEdge) / screenWidth)
    local percL     = (screenWidth - leftEdge) / screenWidth

    local side = (percR > thresh and percL < thresh) and 'right' or 'left'
    return side

    -- TODO [low-priority]: BUG: Right-side window incorrectly reports as a left-side window with {{{
    -- very large padding settings. Will need to consider coordinates from both sides of a window.
    -- Impact is minimal with smaller threshold (<= 0.75). }}}

    -- TODO [very-low-priority]: find a way to use hs.window.filter.windowsTo{Dir}  {{{
    -- to determine side instead of percLeft/Right
    --    https://www.hammerspoon.org/docs/hs.window.filter.html#windowsToWest
    --      stackline.wf:windowsToWest(self._win)
    --    https://www.hammerspoon.org/docs/hs.window.html#windowsToWest
    --      self._win:windowsToSouth() }}}
end -- }}}

function Window:makeStackId(hsWin) -- {{{
    local frame = hsWin:frame():floor()
    local x,y,w,h = frame.x, frame.y, frame.w, frame.h

    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor') or 1
    local roundToFuzzFactor = u.partial(u.roundToNearest, fuzzFactor)
    local ff = u.map({x, y, w, h}, roundToFuzzFactor)

    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
        fzyFrame = table.concat(ff, '|'),
    }
end -- }}}

function Window:deleteIndicator() -- {{{
    if self.indicator then
        self.indicator:delete()
        self.indicator.canvas = nil -- TODO: Update stack_spec so that stack:resetAllIndicators() passes *without* this kludge
    end
end -- }}}

function Window:setOtherAppWindows(byApp) -- {{{
    local function notSelfSameScreen(w)
        return (w.id ~= self.id) and (w.screen == self.screen)
    end
    self.otherAppWindows = u.filter(byApp[self.app], notSelfSameScreen)
end -- }}}

function Window:unfocusOtherAppWindows() -- {{{
    u.each(self.otherAppWindows, function(w)
        w.indicator:redraw()
    end)
end -- }}}

-- function Window:__tostring()  -- {{{
--   local w = u.copy(self)

--   local remove = {
--     _win = true,
--     config = true,
--     screen = true,
--     showIcons = true,
--   }

--   replace = {
--     -- stack = {    -- {{{
--     --   focus = self.stack.focus,
--     --   id = self.stack.windows[1].stackId,
--     --   idFzy = self.stack.windows[1].stackIdFzy,
--     --   numWin = #self.stack.windows
--     -- },    -- }}}
--     -- indicator = {    -- {{{
--     --   side = self.indicator.side,
--     --   canvas_rect = tostring(self.indicator.canvas_rect),
--     --   icon_rect = tostring(self.indicator.icon_rect),
--     --   showIcons = self.indicator.showIcons,
--     --   canvas = self.indicator.showIcons,
--     --   width = self.indicator.width,
--     -- },    -- }}}
--   }

--   local count = {
--     -- otherAppWindows = true,
--     history = true,
--   }

--   for k, v in pairs(w) do
--     if remove[k] then
--       w[k] = nil
--     elseif replace[k] then
--       w[k] = replace[k]
--     elseif count[k] then
--       w[k] = 'count = ' .. #v
--     end
--   end

--   return ''
--   -- return hs.inspect(w)
--   -- return hs.inspect(table.merge(
--   --     w,
--   --     { '…hidden keys: ' .. table.concat(u.keys(remove), ', ') }
--   --   ))
-- end  -- }}}

function Window.__eq(a,b)  -- {{{
  -- needed b/c hs.inspect checks equality
  -- with an internal variable that does *not* have key 'frame'
  if not a.frame or not b.frame then
    print('WARNING: one of args to Window.__eq() missing frame key')
    return false
  end

  -- local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor') or 1
  local fuzzFactor = 5

  for k,v in pairs(a.frame) do
    if math.abs(a.frame[k] - b.frame[k]) > fuzzFactor then
      return false
    end
  end
  return true

end  -- }}}

return Window
