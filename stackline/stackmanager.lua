-- TODO: consolidate these utils!
local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

-- stackline modules
local Query = require 'stackline.stackline.query'
local Stack = require 'stackline.stackline.stack'

-- ┌──────────────┐
-- │ Stack module │
-- └──────────────┘

local Stackmanager = {}
function Stackmanager:update() -- {{{
    Query:windowsCurrentSpace() -- calls Stack:ingest when ready
end -- }}}

function Stackmanager:new() -- {{{
    self.tabStacks = {}
    self.showIcons = stackConfig:get('showIcons')
    return self
end -- }}}

function Stackmanager:ingest(stacks, appWindows, shouldClean) -- {{{
    if shouldClean then
        self:cleanup()
    end

    for _stackId, stack in pairs(stacks) do
        _.each(stack, function(win)
            win.otherAppWindows = u.filter(appWindows[win.app], function(w)
                return w.id ~= win.id
            end)
        end)
        table.insert(self.tabStacks, Stack(stack))
        self:redrawAllIndicators()
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

function Stackmanager:dimOccluded() -- {{{
    self:eachStack(function(stack)
        if stack:isOccluded() then
            stack:dimAllIndicators()
        else
            stack:restoreAlpha()
        end
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
        topLeft = _.map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].topLeft
        end),
        dimensions = _.map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].stackId
        end),
        numWindows = _.map(stacks, function(s)
            local windows = external and s or s.windows
            return #windows
        end),
    }
end -- }}}

function Stackmanager:redrawAllIndicators() -- {{{
    self:eachStack(function(stack)
        stack:redrawAllIndicators()
    end)
end -- }}}

function Stackmanager:toggleIcons() -- {{{
    self.showIcons = not self.showIcons
    self:redrawAllIndicators()
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

return Stackmanager
