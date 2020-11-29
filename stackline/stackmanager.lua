local Query = require 'stackline.stackline.query'
local Stack = require 'stackline.stackline.stack'

local Stackmanager = {}

function Stackmanager:init() -- {{{
    self.tabStacks = {}
    self.showIcons = stackline.config:get('appearance.showIcons') or true
    -- self.__index = self
    return self
end -- }}}

function Stackmanager:update() -- {{{
    local ws = stackline.wf:getWindows()
    Query.run(ws)
    return self
end -- }}}

function Stackmanager:ingest(windowGroups, appWindows, shouldClean) -- {{{
    local stacksCount = u.len(windowGroups)

    if shouldClean or (stacksCount == 0) then
        self:cleanup()
    end

    for stackId, groupedWindows in pairs(windowGroups) do
        local stack = Stack:new(groupedWindows) -- instantiate new instance of Stack()
        stack.id = stackId
        stack:eachWin(function(win)
            win:setOtherAppWindows(appWindows)
            win.stack = stack -- makes it easy to call stack methods from window
        end)
        table.insert(self.tabStacks, stack)
        self:resetAllIndicators()
    end
end -- }}}

function Stackmanager:get() -- {{{
    return self.tabStacks
end -- }}}

function Stackmanager:eachStack(fn) -- {{{
    for _, stack in pairs(self.tabStacks) do
        fn(stack)
    end
end -- }}}

function Stackmanager:eachWin(fn) -- {{{
    self:eachStack(function(s)
        s:eachWin(fn)
    end)
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
            return s.windows[1].topLeft
        end),
        dimensions = u.map(stacks, function(s)
            return s.windows[1].stackId -- stackId is stringified window frame dims ("1150|93|531|962")
        end),
        dimensionsFzy = u.map(stacks, function(s)
            return s.windows[1].stackIdFzy -- stackId is stringified window frame dims ("1150|93|531|962")
        end),
        numWindows = u.map(stacks, function(s)
            return #s.windows
        end),
        appCount = (function()
            -- local win = u.flatten(u.values(u.map(stacks, function(s) return s.windows end)))
            local stackedWin = u.flatten(
                u.values(u.map(stacks, function(s) return s.windows end))
            )

            local prunedWins = u.map(stackedWin, function(w) return u.pick(w, 'id', 'app') end)

            local byApp = table.groupBy(prunedWins, 'app')

            local appCount = u.map(byApp, function(x) return #x end)

            return appCount
        end)(),
    }
end -- }}}

function Stackmanager:resetAllIndicators() -- {{{
    self:eachStack(function(stack)
        stack:resetAllIndicators()
    end)
end -- }}}

function Stackmanager:findWindow(wid) -- {{{
    -- NOTE: A window must be *in* a stack to be found with this method!
    -- TODO: Figure out how to get self:eachWin() to return found window and replace ↓
    for _, stack in pairs(self.tabStacks) do
        for _, win in pairs(stack.windows) do
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
        if (stack.id == win.stackId) or (stack.id == win.stackIdFzy) then
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

return Stackmanager
