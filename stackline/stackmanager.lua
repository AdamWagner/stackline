local log   = hs.logger.new('stackmanager', 'info')

local Stackmanager = {}

Stackmanager.query = require 'stackline.stackline.query'

function Stackmanager:init() -- {{{
    self.tabStacks = {}
    self.showIcons = stackline.config:get('appearance.showIcons')
    self.__index = self
    return self
end -- }}}

function Stackmanager:update(opts) -- {{{
    log.i('Running update()')
    self.query.run(opts) -- calls Stack:ingest when ready
    return self
end -- }}}

function Stackmanager:ingest(stacks, appWins, shouldClean) -- {{{
    if shouldClean then self:cleanup() end

    for stackId, groupedWindows in pairs(stacks) do
        local stack = require 'stackline.stackline.stack':new(groupedWindows)
        stack.id = stackId
        u.each(stack.windows, function(win)
            -- win.otherAppWindows needed to workaround Hammerspoon issue #2400
            win.otherAppWindows = u.filter(appWins[win.app], function(w)
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
    return self.tabStacks
end -- }}}

function Stackmanager:eachStack(fn) -- {{{
    for _stackId, stack in pairs(self.tabStacks) do
        fn(stack)
    end
end -- }}}

function Stackmanager:cleanup() -- {{{
    self:eachStack(function(stack)
        stack:deleteAllIndicators()
    end)
    self.tabStacks = {}
end -- }}}

function Stackmanager:getSummary(external) -- {{{
    -- Summarizes all stacks on the current space, making it easy to determine
    -- what needs to be updated (if anything)
    local stacks = external or self.tabStacks
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
    self:eachStack(function(stack)
        stack:resetAllIndicators()
    end)
end -- }}}

function Stackmanager:findWindow(wid) -- {{{
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
    return self.showIcons
end -- }}}

function Stackmanager:getClickedWindow(point) -- {{{
    -- given the coordinates of a mouse click, return the first window whose
    -- indicator element encompasses the point, or nil if none.    
    for _stackId, stack in pairs(self.tabStacks) do
        local clickedWindow = stack:getWindowByPoint(point)
        if clickedWindow then
            return clickedWindow
        end
    end
end -- }}}

function Stackmanager:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

return Stackmanager
