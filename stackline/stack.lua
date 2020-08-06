-- Utils
-- TODO: consolidate these utils!
local _ = require 'stackline.utils.utils'
-- local u = require 'stackline.utils.underscore'
-- local tut = require 'stackline.utils.table-utils'
-- local under = require 'stackline.utils.underscore'

-- stackline modules
local query = require 'stackline.stackline.WIP-query'

-- TODO: add proper logging
-- local log = hs.logger.new('[stack]', 'debug')

-- Convenience aliases
local map = hs.fnutils.map

-- ┌──────────────┐
-- │ Stack module │
-- └──────────────┘
local Stack = {}

function Stack:toggleIcons() -- {{{
    self.showIcons = not self.showIcons
    self:redrawAllIndicators()
end -- }}}

function Stack:redrawIndicator(win) -- {{{
    -- USAGE: pass this func to Stack:eachWin()
    print('calling redraw indicator')
    win:setupIndicator()
    win:drawIndicator()
end -- }}}

function Stack:eachWin(fn) -- {{{
    for _stackId, stack in pairs(self.tabStacks) do
        for _idx, win in pairs(stack) do
            fn(win)
        end
    end
end -- }}}

function Stack:redrawAllIndicators()
    self:eachWin(function(win)
        self:redrawIndicator(win)
    end)
end

function Stack:findWindow(wid) -- {{{
    -- NOTE: A window must be *in* a stack to be found with this method!
    -- print('…searching for win id:', wid)
    for _stackId, stack in pairs(self.tabStacks) do
        -- print('searching', #stack, 'windows in stackID', _stackId)
        for _idx, win in pairs(stack) do
            -- print('curr win id:', win.id)
            if win.id == wid then
                -- print('found window', win.id)
                return win
            end
        end
    end
end -- }}}

function Stack:cleanup() -- {{{
    -- _.p('# to be cleaned: ', _.length(self.tabStacks))
    -- _.p('keys be cleaned: ', _.keys(self.tabStacks))

    for key, stack in pairs(self.tabStacks) do
        -- DEBUG: {{{
        -- _.p(stack)
        -- _.pheader('stack keys')
        -- _.p(_.map(stack, function(w)
        --     return _.pick(w, {'id', 'app'})
        -- end)) }}}

        -- For each window, clear canvas element
        _.each(stack, function(w)
            -- _.pheader('window indicator in cleanup')
            -- print(w.indicator)
            w.indicator:delete()
        end)

        self.tabStacks[key] = nil
    end
end -- }}}

i = 1
local heap = require 'stackline.utils.heap' -- {{{
h = heap.valueheap {
    cmp = function(a, b)
        return a.timestamp < b.timestamp
    end,
} -- }}}

function stackDiff() -- {{{
    local curr = h:pop()
    local last = h:pop()

    _.pheader('stack diff:')
    print("current: ", curr.timestamp)
    print("last: ", last.timestamp)
    print("diff: ", curr.timestamp - last.timestamp)
    -- for _winIdx, w in pairs(curr) do
    --     print(hs.inspect(w, {depth = 1}))
    -- end
end -- }}}

local clearConsoleAfterNewStack = hs.timer.delayed.new(5,
    hs.console.clearConsole)

function Stack:newStack(stack, stackId) -- {{{
    -- clearConsoleAfterNewStack:start()
    print('new stack:', stackId, 'w/', #stack, 'wins')

    -- UPDATE: tentative solution found in hs.timer.delayed
    -- FIXME: The problem with this is that there are multiple event
    -- subscribers, and so Stack.update() is being called multiple times per
    -- actual "change" event, so typically the last two stacks in diff() are the same. 
    -- ACTUALLY — is this fine? Much of the time, a stack WOULD be the same,
    -- even if events *were* debounced / consolidated. The diff will tell the
    -- story. The timestamp just ensrues that they stay in the right order.
    -- FTNOTE: Well, it's not "fine" — it's very bad from a performance POV.
    -- "Fine" above was only in reference to WRT to detecting state changes &
    -- reacting appropriately.

    self.tabStacks[stackId] = stack
    self:redrawAllIndicators()

    -- for _winIdx, w in pairs(stack) do
    -- print(hs.inspect(w, {depth = 1}))
    -- end
end -- }}}

function Stack:ingest(windowData) -- {{{

    -- TODO: track stacks in heap here instead of in Stack:newStack()
    -- IDEA: which MIGHT solve the problem of the problematic timestamp key — we
    -- could delete it before "ingestion"!
    -- NOTE: disabled until solution to timestamp key is implemented

    -- h:push(stack)
    -- print("heap length: ", h:length())
    -- if h:length() > 2 then
    --     stackDiff()
    -- end

    for stackId, stackWindows in pairs(windowData) do
        Stack:newStack(stackWindows, stackId)
    end
end -- }}}

function Stack:update(shouldClean) -- {{{
    if shouldClean then
        _.pheader('running cleanup')
        Stack:cleanup()
    end

    query:windowsCurrentSpace() -- calls Stack:ingest when ready
end -- }}}

function Stack:get(shouldPrint) -- {{{
    if shouldPrint then
        _.p(self.tabStacks, 3)
    end
    return self.tabStacks
end -- }}}

function Stack:getShowIconsState() -- {{{
    return self.showIcons
end -- }}}

function Stack:newStackManager() -- {{{
    self.tabStacks = {}
    self.showIcons = false

    -- TODO: is it really necessary to expose methods like this? Or could other
    -- modules just invoke the instance method, e.g., wsi:get() if we used
    -- setmetatable to merge Stack methods with instance ala .window.lua:52
    return {
        ingest = function(windowData)
            return self:ingest(windowData)
        end,
        get = function()
            return self:get()
        end,
        getShowIconsState = function()
            return self:getShowIconsState()
        end,
        getCache = function()
            return cache
        end,
        update = self.update,
        cleanup = function()
            return self:cleanup()
        end,
        toggleIcons = function()
            return self:toggleIcons()
        end,
        findWindow = function(wid)
            return self:findWindow(wid)
        end,
        each_win = function(wid)
            return self:each_win_id(wid)
        end,
        get_win_str = function()
            return Stack.win_str
        end,
        redrawAllIndicators = function()
            return self:redrawAllIndicators()
        end,
    }
end -- }}}

return Stack

