require("hs.ipc")

local _ = require 'stackline.utils.utils'
local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'

function getOrSet(key, val)
    local existingVal = hs.settings.get(key)
    if existingVal == nil then
        hs.settings.set(key, val)
        return val
    end
    return existingVal
end

local wf = hs.window.filter

local showIcons = getOrSet("showIcons", false)

wsi = Stack:newStackManager(showIcons)

local win_added = { -- {{{
    wf.windowCreated,
    wf.windowUnhidden,
    wf.windowUnminimized,
} -- }}}

local win_changed = { -- {{{

    -- TODO: rather than subscribing to windowFocused here, do it only for
    -- windows within a stack. This will shorten the update process for focus
    -- changes, since we *only* need to update the indicators, not query for new
    -- window state entirely.
    -- wf.windowFocused,
    -- wf.windowUnfocused,

    wf.windowFullscreened,
    wf.windowUnfullscreened,

    -- NOTE: windowMoved captures movement OR resize events
    wf.windowMoved,
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

function indicatorActivate(hsWin) -- {{{
    local id = hsWin:id()
    print('Focused', hsWin:application():name(), id)

    local win = wsi.findWindow(id)

    -- DEBUG {{{
    -- print('found window:', win.id)
    -- print('indicator:', win.indicator, '\n\n')
    -- print('Focused curr focus', win:isFocused())
    -- }}}

    -- NOTE: redraws indicator
    -- TODO: rename win:process() to improve clarity!
    win:process()

    -- NOTE: experiment to keep indicators in sync despite HS bug in which
    -- windowUnfocused is not called when switching between two windows of the
    -- same app :<
    -- https://github.com/Hammerspoon/hammerspoon/issues/2400
    -- wsi.redrawAllIndicators()
end -- }}}

function indicatorDeactivate(hsWin) -- {{{
    local id = hsWin:id()
    print('Unfocused', hsWin:application():name(), id)

    local win = wsi.findWindow(id)

    -- DEBUG {{{
    -- print('found window:', win.id)
    -- print('Unfocused curr focus', win:isFocused())
    -- print('indicator:', win.indicator, '\n\n')
    -- }}}

    -- NOTE: redraws indicator
    -- TODO: rename win:process() to improve clarity!
    win:process()
end -- }}}

wfd:subscribe(wf.windowFocused, indicatorActivate)

-- HS BUG! windowUnfocused is not called when switching between windows of the
-- same app - it's ONLY called when switching between windows of different apps
-- https://github.com/Hammerspoon/hammerspoon/issues/2400
wfd:subscribe({wf.windowNotVisible, wf.windowUnfocused}, indicatorDeactivate)

