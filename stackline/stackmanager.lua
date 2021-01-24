local Query = require 'stackline.stackline.query'
local Stack = require 'stackline.stackline.stack'

local Stackmanager = {}

function Stackmanager:init() -- {{{
    self.stacks = {}
    self.showIcons = stackline.config:get('appearance.showIcons')
    return self
end -- }}}

function Stackmanager:update() -- {{{
    local hsWins = stackline.wf:getWindows()
    local stacklineWins = u.map(hsWins, function(w)
        return stackline.window:new(w)
    end)
    Query.run(stacklineWins)
    return self
end -- }}}

function Stackmanager:ingest(byStack, byApp, shouldClean) -- {{{
    local stacksCount = u.len(byStack)
    if shouldClean or (stacksCount == 0) then
        self:cleanup()
    end

    for _, winGroup in pairs(byStack) do
        -- instantiate new instance of Stack()
        local stack = Stack:new(winGroup)
        stack:eachWin(function(win)
            win:setOtherAppWindows(byApp)
            -- easily call stack methods from window
            -- 'stack' attr is hidden from iteration
            win.stack = stack
        end)
        table.insert(self.stacks, stack)
        self:resetAllIndicators()
    end
    return self
end -- }}}

function Stackmanager:get() -- {{{
    return self.stacks
end -- }}}

function Stackmanager:eachStack(fn) -- {{{
    for _stackId, stack in pairs(self.stacks) do
        fn(stack)
    end
end -- }}}

function Stackmanager:cleanup() -- {{{
    -- u.pheader('cleanup')
    self:eachStack(function(stack)
        stack:deleteAllIndicators()
    end)
    self.stacks = {}
end -- }}}

function Stackmanager:getSummary(external) -- {{{
    -- Summarizes all stacks on the current space,
    -- making it easy to determine what needs to be updated (if anything)
    local stacks = external or u.pluck(self.stacks, 'windows')

    -- WIP: Sort stacks & windows before compare:
    u.ieach(stacks, function(stack) table.sort(stack, function(a,b) return a.id < b.id end) end)
    table.sort(stacks, function(a,b) return #a < #b end)
    -- end WIP sorting

    return {
        numStacks = #stacks,
        ids = u.imap(stacks, function(s)
            return u.pluck(s, 'id')
        end),
        topLeft = u.imap(stacks, function(s)
            return s[1].topLeft
        end),
        dimensions = u.imap(stacks, function(s)
            return s[1].stackId -- stackId is stringified window frame dims ("1150|93|531|962")
        end),
        numWindows = u.imap(stacks, function(s)
            return #s
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
    for _stackId, stack in pairs(self.stacks) do
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
    for _stackId, stack in pairs(self.stacks) do
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
    for _stackId, stack in pairs(self.stacks) do
        local clickedWindow = stack:getWindowByPoint(point)
        if clickedWindow then
            return clickedWindow
        end
    end
end -- }}}

return Stackmanager
