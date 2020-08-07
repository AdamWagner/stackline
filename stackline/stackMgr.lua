-- TODO: consolidate these utils!
local _ = require 'stackline.utils.utils'

-- stackline modules
local Query = require 'stackline.stackline.query'
local Stack = require 'stackline.stackline.stack'

-- ┌──────────────┐
-- │ Stack module │
-- └──────────────┘

-- HEAP (unused for now) {{{
i = 1
local heap = require 'stackline.utils.heap' -- {{{
h = heap.valueheap {
    cmp = function(a, b)
        _.pheader('compare in heap')
        print('A:')
        _.p(a)
        print('B:')
        _.p(b)
        return a.timestamp < b.timestamp
    end,
} -- }}}
function Stack:heapPush(stacks) -- {{{
    -- TODO: track stacks in heap here instead of in Stack:newStack()
    local cloneStack = hs.fnutils.copy(stacks)
    cloneStack.timestamp = hs.timer.absoluteTime() -- add timestamp for heap / diff
    h:push(cloneStack)
    if h:length() > 2 then
        stackDiff()
    end
end -- }}}
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
-- }}}

local StacksMgr = {}
function StacksMgr:update() -- {{{
    Query:windowsCurrentSpace() -- calls Stack:ingest when ready
end -- }}}

-- FIXME: Doesn't wor with multiple tab stacks on same screen (?!)
function StacksMgr:new() -- {{{
    self.tabStacks = {}
    self.showIcons = true
    return self
end -- }}}

function StacksMgr:ingest(stacks, shouldClean) -- {{{
    -- self:heapPush(stacks)
    if shouldClean then
        _.pheader('running cleanup')
        self:cleanup()
    end
    for _stackId, stack in pairs(stacks) do
        _.pheader('new stack')
        _.p(stack)
        table.insert(self.tabStacks, Stack:new(stack))
        _.pheader('stacksMngr.tabStacks afterward')
        _.p(self.tabStacks)
        self:redrawAllIndicators()
    end
end -- }}}

function StacksMgr:get() -- {{{
    return self.tabStacks
end -- }}}

function StacksMgr:eachStack(fn) -- {{{
    for _stackId, stack in pairs(self.tabStacks) do
        fn(stack)
    end
end -- }}}

function StacksMgr:cleanup() -- {{{
    _.pheader('calling cleanup')
    self:eachStack(function(stack)
        print('calling stackMgr:deleteAllIndicators()')
        stack:deleteAllIndicators()
    end)
    self.tabStacks = {}
end -- }}}

function StacksMgr:getSummary(external) -- {{{
    local stacks = external or self.tabStacks
    return {
        numStacks = #stacks,
        topLeft = map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].topLeft
        end),
        dimensions = map(stacks, function(s)
            local windows = external and s or s.windows
            return windows[1].stackId
        end),
        numWindows = map(stacks, function(s)
            local windows = external and s or s.windows
            return #windows
        end),
    }
end -- }}}

function StacksMgr:redrawAllIndicators() -- {{{
    self:eachStack(function(stack)
        stack:redrawAllIndicators()
    end)
end -- }}}

function StacksMgr:toggleIcons() -- {{{
    self.showIcons = not self.showIcons
    self:redrawAllIndicators()
end -- }}}

function StacksMgr:findWindow(wid) -- {{{
    -- NOTE: A window must be *in* a stack to be found with this method!
    -- print('…searchi win id:', wid)
    for _stackId, stack in pairs(self.tabStacks) do
        -- print('searching', #stack, 'windows in stackID', _stackId)
        for _idx, win in pairs(stack.windows) do
            print('searching', win.id, 'for', wid)
            if win.id == wid then
                -- print('found window', win.id)
                return win
            end
        end
    end
end -- }}}

function StacksMgr:getShowIconsState() -- {{{
    return self.showIcons
end -- }}}

return StacksMgr

