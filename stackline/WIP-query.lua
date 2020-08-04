local _ = require 'stackline.utils.utils'
local spaces = require("hs._asm.undocumented.spaces")
local screen = require 'hs.screen'
local u = require 'stackline.utils.underscore'
local fnutils = require("hs.fnutils")

-- stackline modules
local Window = require 'stackline.stackline.window'

-- shortcuts
local map = hs.fnutils.map

function clone(table)
    _clone = {}
    i, v = next(table, nil)
    while i do
        _clone[i] = v
        i, v = next(table, i)
    end
    return _clone
end

--[[ {{{ NOTES
The goal of this file is to eliminate the need to 'shell out' to yabai to query
window data needed to render stackline, which would address
https://github.com/AdamWagner/stackline/issues/8. The main problem with relying
on yabai is that a 0.03s sleep is required in the yabai script to ensure that
the changes that triggered hammerspoon's window event subscriber are, in fact,
represented in the query response from yabai. There are probably secondary
downsides, such as overall performance, and specifically *yabai* performance
(I've noticed that changing focus is slower when lots of yabai queries are
happening simultaneously).

┌────────┐
│ Status │
└────────┘
We're not yet using any of the code in this file to actually render the
indiators or query ata — all of that is still achieved via the "old" methods.

However, this file IS being required by ./core.lua and runs one every window focus
event, and the resulting "stack" data is printed to the hammerspoon console.

The stack data structure differs from that used in ./stack.lua enough that it
won't work as a drop-in replacement. I think that's fine (and it wouldn't be
worth attempting to make this a non-breaking change, esp. since zero people rely
on it as of 2020-08-02.

┌──────┐
│ Next │
└──────┘
- [ ] Integrate appropriate functionality in this file into the Stack module
- [ ] Update key Stack module functions to have basic compatiblity with the new data structure
- [ ] Simplify / refine Stack functions to leverage the benefits of having access to the hs.window module for each tracked window
- [ ] Integrate appropriate functionality in this file into the Core module
- [ ] … see if there's anything left and decide where it should live

┌───────────┐
│ WIP NOTES │
└───────────┘
Much of the functionality in this file should either be integrated into
stack.lua or core.lua — I don't think a new file is needed.

Rather than calling out to the script ../bin/yabai-get-stacks, we're using
hammerspoon's mature (if complicated) hs.window.filter and hs.window modules to
achieve the same goal natively within hammerspon.

There might be other benefits in addition to fixing the problems that inspired
#8: We get "free" access to the *hammerspoon* window module in the window data
tracked by stackline, which will probably make it easier to implement
enhancements that we haven't even considered yet. This approach should also be
easier to maintain, *and* we get to drop the jq dependency!

-- }}} --]]

-- Private functions
local wfd = hs.window.filter.new():setOverrideFilter{ -- {{{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
}:setSortOrder(hs.window.filter.sortByCreated) -- }}}

function makeStackId(win, winSpaceId) -- {{{
    -- generate stackId from spaceId & frame values
    -- example: "302|35|63|1185|741"
    local frame = win:frame():floor()
    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h
    return table.concat({winSpaceId, x, y, w, h}, '|')
end -- }}}

function lenGreaterThanOne(t) -- {{{
    return #t > 1
end -- }}}

function winToHs(win) -- {{{
    return win._win
end -- }}}

local Query = {}
Query.focusedWindow = nil

function Query:getWinStackIdxs() -- {{{
    local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, _stderr)
        local winStackIdxs = hs.json.decode(stdout)
        self.winStackIdxs = winStackIdxs
        -- print('stack idxs are ', hs.inspect(winStackIdxs))
    end, {scriptPath}):start()
end -- }}}

function mapWin(hsWindow) -- {{{
    local winData = {
        stackId = makeStackId(hsWindow, hsWindow:spaces()[1]),
        id = hsWindow:id(),
        app = hsWindow:application():name(),
        -- title = hsWindow:title(),
        frame = hsWindow:frame(),
        _win = hsWindow,
        focused = (Query.focusedWindow == hsWindow),
    }
    return Window:new(winData)
end -- }}}

function Query.getSpaces() -- {{{
    return fnutils.mapCat(screen.allScreens(), function(s)
        return spaces.layout()[s:spacesUUID()]
    end)
end -- }}}

function Query.getActiveSpaceIndex() -- {{{
    local s = Query.getSpaces()
    local activeSpace = spaces.activeSpace()
    return _.indexOf(s, activeSpace)
end -- }}}

function Query.stackOccluded(stack) -- {{{
    -- FIXES: When a stack that has "zoom-parent": 1 occludes another stack, the
    -- occluded stack's indicators shouldn't be displaed
    -- https://github.com/AdamWagner/stackline/issues/11

    -- Returns true if any non-stack window occludes the stack's frame.
    -- This can occur when an unstacked window is zoomed to cover a stack.
    -- In this situation, we  want to *hide* the occluded stack's indicators
    -- TODO: Convert to Stack instance method (wouldn't need to pass in the 'stack' arg)

    function notInStack(hsWindow)
        local stackWindowsHs = u.map(u.values(stack), winToHs)
        local isInStack = u.include(stackWindowsHs, hsWindow)
        return not isInStack
    end

    -- NOTE: under.filter works with tables
    -- _.filter only works with "list-like" tables
    local nonStackWindows = u.filter(wfd:getWindows(), notInStack)

    function isStackInside(nonStackWindow)
        local stackFrame = stack[1]._win:frame()
        return stackFrame:inside(nonStackWindow:frame())
    end

    return u.any(_.map(nonStackWindows, isStackInside))
end -- }}}

function Query:makeStacksFromWindows(ws) -- {{{
    Query.focusedWindow = hs.window.focusedWindow()
    local windows = u.map(ws, mapWin)

    --     DEBUG {{{
    --     print('\n\n\n\n\n\n')
    --     _.pheader('Query.makestacksfromwindows')
    --     _.p(windows, 2) }}}

    local groupedWindows = _.groupBy(windows, 'stackId')

    -- TODO: since we already need to shell out to yabai, we *could* do this by
    -- intersecting windows with those that have a stack index

    -- stacks contain more than one window, 
    -- so ignore groups with only 1 window
    stacks = hs.fnutils.filter(groupedWindows, lenGreaterThanOne)
    self.stacks = stacks
end -- }}}

-- luacheck: ignore
function Query:setOccludedStacks(stacks) -- {{{
    -- NOTE: This *could* be a simple one-liner
    local occludedStacks = _.map(stacks, Query.stackOccluded)
    self.occludedStacks = occludedStacks
    -- print('occluded stacks: ', hs.inspect(self.occludedStacks))
end -- }}}

function Query:winStackIdxsAreSet()
    _.pheader('polling called')
    local areSet = self.winStackIdxs ~= nil
    -- print('ARE SET: ', areSet)
    return areSet
end

function Query:mergeWinStackIdxs()
    hs.fnutils.each(self.stacks, function(stack)
        hs.fnutils.each(stack, function(win)
            -- print(win.id)
            win.stackIdx = self.winStackIdxs[tostring(win.id)]
        end)
    end)
end

local count = 0

function Query:windowsCurrentSpace() -- {{{
    self:getWinStackIdxs() -- set self.winStackIdxs (async shell call to yabai)
    self:makeStacksFromWindows(wfd:getWindows()) -- set self.stacks
    self:setOccludedStacks(self.stacks) -- set self.occludedStacks

    _.pheader('wfd:getWindows() in query')
    for _idx, win in pairs(wfd:getWindows()) do
        print(win:application():title(), ":", win:title())
    end

    -- Don't return until the yabai query is returned
    function checkWinStackIdxsDone() -- {{{
        -- _.pheader('check stack idxs done')
        -- Careful! These timers accumulate, tho it's less noticable with a fast polling interval
        -- TODO: Find a way to cancel this if it's called again before completing?
        return self:winStackIdxsAreSet()
    end -- }}}

    function whenStackIdxDone()

        -- Add the stack indexes from yabai to the hs window data
        self:mergeWinStackIdxs()

        -- _.p(self.stacks)

        local cloneStack = map(clone(self.stacks), function(stack)
            local _stack = clone(stack)

            -- TODO: Decide whether the timestamp field is necessary, and if so,
            -- store in temp var & delete key before looping over windows, then
            -- restore at end.
            -- NOTE: Removed to defer solving the problem of ignoring the
            -- timestamp field for now.
            -- → → _stack.timestamp = hs.timer.absoluteTime()

            return _stack
        end)

        -- FIXME: self.stacks is being past to ingest as a *reference)out*, so
        -- changes in the Stack module affect self.stacks

        -- After trying many different deepcopy methods, that path seemed unworkable.
        -- Next, I thoughtabout using metatables? But this also seems not quite right.
        -- https://stackoverflow.com/questions/18177101/hiding-a-lua-metatable-and-only-exposing-an-objects-attributes
        -- It does make me think of a todo, tho:
        -- NOTE: Found that hs.fnutils has a copy function! hs.fnutils.copy.  Found in https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/watcher/init.lua
        -- TODO: Create an actual "Stack" class that represents a single stack.
        -- The current "Stack" class is *actually* a stack manager.

        -- NOTE: This is only being called ONCE per change (as desired), but
        -- wsi:
        count = count + 1
        print('Query module calling stack:ingest (' .. count .. ' times total)')

        -- NOTE: must require here to avoid circular dependency 
        -- & "Too many C levels" error
        require('stackline.stackline.stack'):ingest(cloneStack) -- hand over to the Stack module
        -- local stacks = wsi.ingest(self.stacks)
    end

    local pollingInterval = 0.1
    hs.timer.waitUntil(checkWinStackIdxsDone, whenStackIdxDone, pollingInterval)
end -- }}}
return Query

