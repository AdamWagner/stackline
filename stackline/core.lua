require("hs.ipc")

local _ = require 'stackline.utils.utils'
local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'
local wf = hs.window.filter

wsi = Stack:newStackManager(showIcons)

local win_added = { -- {{{
    wf.windowCreated,
    wf.windowUnhidden,
    wf.windowUnminimized,
} -- }}}

local win_changed = { -- {{{
    wf.windowFullscreened,
    wf.windowUnfullscreened,
    wf.windowMoved, -- NOTE: windowMoved captures movement OR resize events
} -- }}}

-- combine added & changed events
local added_changed = tut.mergeArrays(win_added, win_changed)

local win_removed = { -- {{{
    wf.windowDestroyed,
    wf.windowHidden,
    wf.windowMinimized,
    wf.windowNotInCurrentSpace,
} -- }}}

local wfd = wf.new():setOverrideFilter{ -- {{{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
} -- }}}

-- TO CONFIRM: Compared to calling wsi.update() directly in wf:subscribe
-- callback, even a delay of "0" appears to coalesce events as desired.
-- NOTE: alternative: https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/deferred/init.lua
-- This extension makes it simple to defer multiple actions after a delay from the initial execution.
--  Unlike `hs.timer.delayed`, the delay will not be extended
-- with subsequent `run()` calls, but the delay will trigger again if `run()` is called again later.
local queryWindowState = hs.timer.delayed.new(0.10, function()
    wsi.update()
end)

-- ┌──────────────────────────────────┐
-- │ Query window state subscriptions │
-- └──────────────────────────────────┘
-- callback args: window, app, event
wfd:subscribe(added_changed, function()
    -- wsi.update()
    queryWindowState:start()
end)

wfd:subscribe(win_removed, function()
    -- TODO: implement cleanup in a better way
    -- wsi:update(true)
    queryWindowState:start()
end)

-- call once on load
wsi.update()

-- ┌─────────────────────────────────┐
-- │ Update indicators subscriptions │
-- └─────────────────────────────────┘

-- DONE: rather than subscribing to windowFocused here, do it only for
-- windows within a stack. This will shorten the update process for focus
-- changes, since we *only* need to update the indicators, not query for new
-- window state entirely.
-- wf.windowFocused,
-- wf.windowUnfocused,

-- DONE: Parameterize Activate / Deactivate by reading event

function redrawWinIndicator(hsWin, appName, event)
    local id = hsWin:id()
    print(event:gsub('window', ''), appName, id)

    -- Lookup *stacked* window by ID
    -- If not found, then the focused/unfocused window is not stacked, 
    -- and this is a no-op.
    local stackedWin = wsi.findWindow(id)
    if stackedWin then -- if not found, then focused win is not stacked
        -- -- DEBUG {{{
        -- print('found window:', win.id)
        -- print('indicator:', win.indicator, '\n\n')
        -- print('Focused curr focus', win:isFocused())
        -- -- }}}
        stackedWin:drawIndicator()
    end
end

wfd:subscribe(wf.windowFocused, redrawWinIndicator)
wfd:subscribe({wf.windowNotVisible, wf.windowUnfocused}, redrawWinIndicator)

-- HS BUG! windowUnfocused is not called when switching between windows of the
-- same app - it's ONLY called when switching between windows of different apps
-- https://github.com/Hammerspoon/hammerspoon/issues/2400

-- I tried an experiment to redraw all indicators inside `redrawWinIndicator()`
-- every time, but it slowed down changing win focus A LOT:
-- wsi.redrawAllIndicators()

