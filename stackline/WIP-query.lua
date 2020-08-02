local _ = require 'stackline.utils.utils'
local spaces = require("hs._asm.undocumented.spaces")
local screen = require 'hs.screen'
local u = require 'stackline.utils.underscore'
local fnutils = require("hs.fnutils")

--[[
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

--]]

local wfd = hs.window.filter.new():setOverrideFilter{ -- {{{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
} -- }}}

function getSpaces() -- {{{
    return fnutils.mapCat(screen.allScreens(), function(s)
        return spaces.layout()[s:spacesUUID()]
    end)
end -- }}}

function getActiveSpaceIndex() -- {{{
    local s = getSpaces()
    local activeSpace = spaces.activeSpace()
    return _.indexOf(s, activeSpace)
end -- }}}

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

function mapWin(hsWindow) -- {{{
    return {
        stackId = makeStackId(hsWindow, hsWindow:spaces()[1]),
        id = hsWindow:id(),
        x = hsWindow:frame().x,
        y = hsWindow:frame().y,
        app = hsWindow:application():name(),
        title = hsWindow:title(),
        frame = hsWindow:frame(),
        _win = hsWindow,
    }
end -- }}}

function lenGreaterThanOne(t)
    return #t > 1
end

function makeStacksFromWindows(ws) -- {{{
    local windows = u.map(ws, mapWin)
    local groupedWindows = _.groupBy(windows, 'stackId')
    -- stacks contain more than one window, 
    -- so ignore groups with only 1 window
    local stacks = hs.fnutils.filter(groupedWindows, lenGreaterThanOne)
    return stacks
end -- }}}

function winToHs(win)
    return win._win
end

function stackOccluded(stack) -- {{{
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

-- luacheck: ignore
function stacksOccluded(stacks) -- {{{
    -- NOTE: This *could* be a simple one-liner
    local occludedStacks = _.map(stacks, stackOccluded)
    _.pheader('occluded stacks:')
    _.p(occludedStacks)
    return occludedStacks
end -- }}}

function windowsCurrentSpace() -- {{{
    local ws = wfd:getWindows()
    local stacks = makeStacksFromWindows(ws)
    _.pheader('STACKS!')
    _.p(stacks, 3)
    stacksOccluded(stacks)
end -- }}}

wfd:subscribe(hs.window.filter.windowFocused, windowsCurrentSpace)

windowsCurrentSpace()

