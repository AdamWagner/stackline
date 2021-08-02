--[[ === TESTS === {{{

-- == Generic setup == --
ww = u.map(hs.window.filter(), function(w) return stackline.window:new(w) end)
w = stackline.manager:get()[1].windows[1]

-- == window:destroy() == --
s = stackline.manager:get()[1]
w = s.windows[2]
w:destroy()

 }}} ]]

-- TODO: Move this to... ??? Somwehere. Or get rid of it.
-- REVIEW: Might be able to get rid of this entirely now that I have frame-comparing fuzzy matching implemented.
-- Alternatively, could set a *region* on the stack's window filter to automatically pick up new windows added to stack!
local function makeStackId(hsWin) -- {{{
    -- See also: framesEqual() and groupForScreen() in https://github.com/zef/dotfiles/blob/master/hammerspoon/init.lua
    local frame = hsWin:frame():floor()

    local x, y, w, h = frame.x, frame.y, frame.w, frame.h
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    local roundToFuzzFactor = u.bind(u.roundToNearest, fuzzFactor)

    local ff = u.map({x, y, w, h}, roundToFuzzFactor)

    local topLeft = table.concat({x, y}, '|')
    local stackId = table.concat({x, y, w, h}, '|')
    local fzyFrame = table.concat(ff, '|')

    return topLeft, stackId, fzyFrame
end -- }}}

local uiElement = require'classes.UiElement'
local Window = uiElement:subclass('Window')

function Window:new(hswin) -- {{{
    self.log.i( ('Window:new(%s)'):format(hswin:id()) )

    local topLeft, stackId, fzyFrame = makeStackId(hswin)
    local function callHs(k, ...) return u.bind(hswin[k], hswin, ...) end

    self.created     = os.date()                    -- window creation date/time
    self.title       = hswin:title()                -- window title
    self.app         = hswin:application():name()   -- app name (string)
    self.id          = hswin:id()                   -- window id (string) NOTE: HS win.id == yabai win.id
    self.stackId     = stackId                      -- "{{x}|{y}|{w}|{h}" e.g."35|63|1185|741" (string)
    self.topLeft     = topLeft                      -- "{{x}|{y}" e.g."35|63" (string)
    self.stackIdFzy  = fzyFrame                     -- "{{x}|{y}" e.g."35|63" (string)
    self.screen      = hswin:screen():id()          -- ID of the screen containing the window
    self.frame       = callHs('frame')              -- not equivilent to `hswin.frame`, which will use a `Window` instance as self rather than `hswin`

    self.stackIdx = nil or 1    --> Integer: Set using yabai data in query.lua
    self.indicator = nil        --> Userdata: hs.canvas instance
    self.side = nil             --> String: 'left', 'right'

    self._win        = hswin   -- hs.window object (userdata)
    self._screen     = hswin:screen()
    self._config     = stackline.config:get('appearance')
    self._wf         = hs.window.filter.new(function(w) return w:id()==hswin:id() end)
    self._stack      = nil    -- back-reference to parent is set in self:setup()
end -- }}}

function Window:setup(stack)  -- {{{
    self._stack = stack

    self.indicator = require 'stackline.indicator':new(self)
    self.indicator:setup():draw()

    self:listen({'windowFocused', 'windowUnfocused', 'windowDestroyed'})
    return self
end  -- }}}

function Window:isFocused() -- {{{
    self.log.df('isFocused() called for %s', self.id)
    local hswin = hs.window.focusedWindow()
    return hswin ~= nil and (self.id == hswin:id())
end -- }}}

function Window:handleEvent(hswin, _app, evt)  -- {{{
    if hswin:id() == self.id then
        print('matching event')
        self['on'..evt:capitalize()](self)
    end
end  -- }}}

function Window:unfocusOtherAppWindows() -- {{{
    -- NOTE: may not need when HS issue #2400 is closed
    u(self._stack.windows)
        :filter(function(w) return w.app==self.app and w.id~=self.id end)
        :each(function(w) w.indicator:redraw() end)
    return self
end -- }}}

-- TODO: Deprecate (has been copied to tentative "Position" module (currently stackline.utils)
function Window:getScreenSide() --[[ {{{
    Returns the side of the screen that the window is (mostly) on
    Retval: "left" or "right" ]]
    local thresh = 0.75
    local screenWidth = self._win:screen():fullFrame().w
    local f = self:frame()

    local leftEdge  = f.x
    local rightEdge = f.x + f.w
    local percR     = 1 - ((screenWidth - rightEdge) / screenWidth)
    local percL     = (screenWidth - leftEdge) / screenWidth

    local side = (percR > thresh and percL < thresh) and 'right' or 'left'
    return side
end -- }}}

-- TODO: Deprecate (has been copied to tentative "Position" module (currently stackline.utils)
function Window:getIndicatorAnchor() -- {{{
    self.side = self:getScreenSide()
    local f = self:frame()

    local xval = self.side == 'left'
        and f.x -- left edge
        or (f.x + f.w) -- right edge

    return hs.geometry { x = xval, y = f.y }
end -- }}}

function Window:onWindowFocused() -- {{{
    self.indicator:redraw()
    self:unfocusOtherAppWindows()
end -- }}}

function Window:onWindowUnfocused() -- {{{
    self.indicator:redraw()
end -- }}}

function Window:onWindowDestroyed()  -- {{{
    self._stack:remove(self)
    -- TODO: Move windows *below* the destroyed window *up*

    self.indicator:deleteIndicator()
    self:unlisten()
    self = nil
end  -- }}}

function Window:resetIndicator()  -- {{{
    self.indicator:reset()
    return self
end  -- }}}

return Window
