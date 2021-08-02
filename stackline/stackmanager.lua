local wf    = hs.window.filter
local delay = hs.fnutils.partial(hs.timer.doAfter, 0.1)
local Stack = require 'stackline.stack'
local uiElement = require'classes.UiElement'

local Stackmanager = uiElement:subclass('Stackmanager')

Stackmanager.__len = function(s) return #s.stacks end
Stackmanager.showIcons = stackline.config:get('appearance.showIcons')
Stackmanager.query = require 'stackline.stackline.query'
Stackmanager._wf = wf.new():setOverrideFilter{ -- Window filter ('wf') controls what hs.window 'sees'
    visible = true, -- i.e., neither hidden nor minimized
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
}

Stackmanager.events = {}
Stackmanager.events.create       = { wf.windowCreated, wf.windowInCurrentSpace, wf.windowUnhidden, wf.windowUnminimized }
Stackmanager.events.moveOrResize = { wf.windowMoved --[[NOTE: includes move AND resize evts]] }
Stackmanager.events.destroy      = { wf.windowDestroyed, wf.windowHidden, wf.windowMinimized }
-- wf.windowFullscreened, wf.windowUnfullscreened,

function Stackmanager:init()  -- {{{
  self.stacks = {}
  self:setupListeners()
  return self
end  -- }}}

function Stackmanager:ingest(winGroups, shouldRefresh)  -- {{{
  if shouldRefresh then self:cleanup() end
  for _, wins in pairs(winGroups) do
    table.insert(
      self.stacks,
      Stack:new(wins):setupWindows()
    )
  end

  _G.w = u.dcopy(stackline.manager:get()[1].windows[1])
end  -- }}}

function Stackmanager:setupListeners() -- {{{
    for group, events in pairs(Stackmanager.events) do
        self:listen(events, group)
    end
end -- }}}

function Stackmanager:onCreate(hswin, _app, evt) -- {{{
    -- If new window belongs to an existing stack, *insert* window into stack instead of reloading everything
    -- Delay allows window's size & position to stabilize
    self.log.f('onCreate()')
    delay(function()
        local w = stackline.window:new(hswin)
        self:eachStack(function(s)
            if s == w then s:push(w) end
        end)
    end)
end -- }}}

function Stackmanager:onMoveOrResize(hswin, _app, evt) -- {{{
    -- Only redraw if the indicatorAnchor has changed
end -- }}}

function Stackmanager:get() -- {{{
    return self.stacks
end -- }}}

function Stackmanager:eachStack(fn) -- {{{
    for _, stack in pairs(self.stacks) do
        return fn(stack)
    end
end -- }}}

function Stackmanager:eachWin(fn) -- {{{
    for _, stack in pairs(self.stacks) do
        stack:eachWin(fn)
    end
end -- }}}

function Stackmanager:findWindow(wid) -- {{{ A window must be *in* a stack to be found with this method!
    for _, stack in ipairs(self.stacks) do
        return stack:findWindow(wid)
    end
end -- }}}

function Stackmanager:cleanup() -- {{{
    self:eachWin(function(w)
        w.indicator:delete()
    end)

    self:eachWin('unlisten')
    self.stacks = {}
end -- }}}

function Stackmanager:getSummary(external) -- {{{
    -- Summarizes all stacks on the current space, making it easy to determine
    -- what needs to be updated (if anything)
    local stacks = external or self.stacks
    return {
        numStacks = #stacks,
        topLeft = u.map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].topLeft
        end),
        dimensions = u.map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].stackId -- stackId is stringified window frame dims ("1150|93|531|962")
        end),
        numWindows = u.map(stacks, function(s)
            local windows = external and s or s.windows
            return #windows
        end),
    }
end -- }}}

function Stackmanager:resetAllIndicators() -- {{{
    self:eachWin('resetIndicator')
end -- }}}

function Stackmanager:getClickedWindow(point) --[[ {{{
    Given the coordinates of a mouse click, return the first window whose
    indicator element encompasses the point, or nil if none. ]]
    for _, stack in pairs(self.stacks) do
        return stack:getWindowByPoint(point)
    end
end -- }}}

return Stackmanager
