-- luacheck: ignore (augments hs.window module)
local spaces = require("hs._asm.undocumented.spaces")
local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

-- stackline modules
local Window = require 'stackline.stackline.window'

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
- [ ] Integrate appropriate functionality in this file into the Core module
- [ ] Integrate appropriate functionality in this file into the Stack module
- [x] Update key Stack module functions to have basic compatiblity with the new data structure
- [x] Simplify / refine Stack functions to leverage the benefits of having access to the hs.window module for each tracked window
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

function lenGreaterThanOne(t) -- {{{
    return #t > 1
end -- }}}

function winToHs(win) -- {{{
    return win._win
end -- }}}

local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'
local Query = {}
Query.focusedWindow = nil

function Query:getWinStackIdxs() -- {{{
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, _stderr)
        self.winStackIdxs = hs.json.decode(stdout)
    end, {scriptPath}):start()
end -- }}}

-- function Query.getSpaces() -- {{{
--     return fnutils.mapCat(screen.allScreens(), function(s)
--         return spaces.layout()[s:spacesUUID()]
--     end)
-- end -- }}}

-- function Query.getActiveSpaceIndex() -- {{{
--     local s = Query.getSpaces()
--     local activeSpace = spaces.activeSpace()
--     return _.indexOf(s, activeSpace)
-- end -- }}}

function Query:makeStacksFromWindows(ws) -- {{{
    local windows = map(ws, function(w)
        return Window:new(w)
    end)
    local groupedWindows = _.groupBy(windows, 'stackId')

    -- stacks contain more than one window, 
    -- so ignore groups with only 1 window
    stacks = hs.fnutils.filter(groupedWindows, lenGreaterThanOne)
    self.stacks = stacks
end -- }}}

function isStackOccluded(stack) -- {{{
    -- FIXES: When a stack that has "zoom-parent": 1 occludes another stack, the
    -- occluded stack's indicators shouldn't be displaed
    -- https://github.com/AdamWagner/stackline/issues/11

    -- Returns true if any non-stack window occludes the stack's frame.
    -- This can occur when an unstacked window is zoomed to cover a stack.
    -- In this situation, we  want to *hide* the occluded stack's indicators
    -- TODO: Convert to Stack instance method (wouldn't need to pass in the 'stack' arg)

    function notInStack(hsWindow)
        local stackWindowsHs = u.map(stack, winToHs)
        local isInStack = u.include(stackWindowsHs, hsWindow)
        return not isInStack
    end

    -- NOTE: under.filter works with tables
    -- _.filter only works with "list-like" tables
    local nonStackWindows = u.filter(wfd:getWindows(), notInStack)
    _.pheader('nonstackwindows')
    _.p(nonStackWindows)

    function isStackInside(nonStackWindow)
        -- _.pheader('stack in is stack inside')
        -- _.p(stack.windows[1])
        local stackFrame = stack.windows[1]._win:frame()
        return stackFrame:inside(nonStackWindow:frame())
    end

    local stackIsOccluded = u.any(map(nonStackWindows, isStackInside))
    print("\nstack is occluded", stackIsOccluded)
    return stackIsOccluded
end -- }}}

-- luacheck: ignore
function Query:dimOccludedStacks(stacks) -- {{{
    each(filter(stacks, isStackOccluded), function(stack)
        _.pheader('dimming occluded indicators')
        print('\n\noccluded stack id', #stack.windows)
        stack:dimAllIndicators()
    end)
end -- }}}

function Query:mergeWinStackIdxs() -- {{{
    hs.fnutils.each(self.stacks, function(stack)
        hs.fnutils.each(stack, function(win)
            -- print(win.id)
            win.stackIdx = self.winStackIdxs[tostring(win.id)]
        end)
    end)
end -- }}}

function shouldRestack(new) -- {{{
    local curr = stacksMgr:getSummary()
    local new = stacksMgr:getSummary(u.values(new))

    -- _.p(curr)
    -- _.p(new)

    if curr.numStacks ~= new.numStacks then
        _.pheader('number of stacks changed')
        return true
    end

    if not _.equal(curr.topLeft, new.topLeft) then
        _.pheader('position changed')
        _.p(curr.topLeft)
        _.p(new.topLeft)
        return true
    end

    if not _.equal(curr.numWindows, new.numWindows) then
        _.pheader('num windows changed')
        return true
    end
end -- }}}

local count = 0
function Query:windowsCurrentSpace() -- {{{
    self:makeStacksFromWindows(wfd:getWindows()) -- set self.stacks

    -- Analyze self.stacks to determine if a stack refresh is needed
    --  • change space
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change num windows (covers win added / removed)
    --    • change position

    local shouldRefresh = false -- tmp var mocking ↑

    local extantStacks = stacksMgr:get()
    local extantStackSummary = stacksMgr:getSummary()
    local extantStackExists = extantStackSummary.numStacks > 0

    if extantStackExists then
        shouldRefresh = shouldRestack(self.stacks, extantStacks)
        -- self:dimOccludedStacks(extantStacks) -- set self.occludedStacks
    else
        shouldRefresh = true
    end

    if shouldRefresh then
        self:getWinStackIdxs() -- set self.winStackIdxs (async shell call to yabai)

        -- DEBUG {{{
        -- _.pheader('wfd:getWindows() in query')
        -- for _idx, win in pairs(wfd:getWindows()) do
        --     print(win:application():title(), ":", win:title())
        -- end
        -- }}}

        function whenStackIdxDone()
            self:mergeWinStackIdxs() -- Add the stack indexes from yabai to the hs window data
            stacksMgr:ingest(self.stacks, extantStackExists) -- hand over to the Stack module
        end

        local pollingInterval = 0.1
        hs.timer.waitUntil(function()
            return self.winStackIdxs ~= nil
        end, whenStackIdxDone, pollingInterval)
    end
end -- }}}
return Query

