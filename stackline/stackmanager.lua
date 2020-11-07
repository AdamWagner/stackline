  -- Reference: hs.tabs does something pretty similar
  -- /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/tabs/init.lua

local defaultDeps = {
    __index = {
        hs = _G.hs,
        u = require 'stackline.lib.utils',
    },
}

return function(deps)
  deps = setmetatable(deps or {}, defaultDeps)

  local capture = require 'stackline.tests.fixtures.capture'
  local Stack = require 'stackline.stackline.stack'

  local Stackmanager = {
    -- log = hs.logger.new('smanager'),
    log = { i = function(m) print(m) end, d = function(m) print(m) end, },
    stackline = deps.stackline,
  }

  function Stackmanager:init() -- {{{
    self.log.i('init()')
    self.tabStacks = {}
    self.showIcons = self.stackline.config:get('appearance.showIcons')
    return self
  end -- }}}

  function Stackmanager:update() -- {{{
    self.log.i('update()')

    -- construct module w/ dependencies
    self.query = require 'stackline.stackline.query' {stackline = self.stackline}

    self.query.query(self.stackline.wf:getWindows()) -- query calls Stackmanager:ingest() if should refresh
    return self
  end -- }}}

  function Stackmanager:ingest(windowGroups, appWindows, shouldClean) -- {{{
    self.log.i('ingest()')

    -- u.p(windowGroups)
    -- capture.managerIngest(windowGroups, appWindows, shouldClean)

    local stacksCount = u.length(windowGroups)
    if shouldClean or (stacksCount == 0) then
      self:cleanup()
    end

    for stackId, groupedWindows in pairs(windowGroups) do
      local stack = Stack:new(groupedWindows) -- instantiate new instance of Stack()
      stack.id = stackId
      u.each(stack.windows, function(win)
        -- win.otherAppWindows needed to workaround Hammerspoon issue #2400
        win.otherAppWindows = u.filter(appWindows[win.app], function(w)
          -- exclude self and other app windows from other others
          return (w.id ~= win.id) and (w.screen == win.screen)
        end)
        -- TODO: fix error with nil stack field (??): window.lua:32: attempt to index a nil value (field 'stack')
        win.stack = stack -- enables calling stack methods from window
      end)
      table.insert(self.tabStacks, stack)
      self:resetAllIndicators()
    end
  end -- }}}

  function Stackmanager:get() -- {{{
    self.log.i('get()')
    return self.tabStacks
  end -- }}}

  function Stackmanager:eachStack(fn) -- {{{
    self.log.i('eachStack()')
    for _stackId, stack in pairs(self.tabStacks) do
      fn(stack)
    end
  end -- }}}

  function Stackmanager:cleanup() -- {{{
    self.log.i('cleanup()')
    self:eachStack(function(stack)
      stack:deleteAllIndicators()
    end)
    self.tabStacks = {}
  end -- }}}

  function Stackmanager:getSummary(external) -- {{{
    self.log.i('getSummary()')
    -- Summarizes all stacks on the current space, making it easy to determine
    -- what needs to be updated (if anything)
    local stacks = external or self.tabStacks
    return {
      numStacks = #stacks,
      stacksSummary = u.map(stacks, function(s)
        local windows = external and s or s.windows
        return {
          id = s.id,
          numWindows = #windows,
          winDims = u.map(windows, function(w)
            return {id = w.id, frame = w.frame}
          end),
        }
      end),
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
    self.log.i('resetAllIndicators()')
    self:eachStack(function(stack)
      stack:resetAllIndicators()
    end)
  end -- }}}

  function Stackmanager:findWindow(wid) -- {{{
    self.log.i('findWindow()')
    -- NOTE: A window must be *in* a stack to be found with this method!
    for _stackId, stack in pairs(self.tabStacks) do
      for _idx, win in pairs(stack.windows) do
        if win.id == wid then
          return win
        end
      end
    end
  end -- }}}

  function Stackmanager:findStackByWindow(win) -- {{{
    self.log.i('findStackByWindow()')
    -- NOTE: may not need when Hammerspoon #2400 is closed
    -- NOTE 2: Currently unused, since reference to "otherAppWindows" is sstored
    -- directly on each window. Likely to be useful, tho, so keeping it around.
    for _stackId, stack in pairs(self.tabStacks) do
      if stack.id == win.stackId then
        return stack
      end
    end
  end -- }}}

  function Stackmanager:getShowIconsState() -- {{{
    self.log.d('getShowIconsState()')
    return self.showIcons
  end -- }}}

  function Stackmanager:getClickedWindow(point) -- {{{
    self.log.i('getClickedWindow()')
    -- given the coordinates of a mouse click, return the first window whose
    -- indicator element encompasses the point, or nil if none.    
    for _stackId, stack in pairs(self.tabStacks) do
      local clickedWindow = stack:getWindowByPoint(point)
      if clickedWindow then
        return clickedWindow
      end
    end
  end -- }}}

  return Stackmanager
end
