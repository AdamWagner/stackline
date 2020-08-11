require("hs.ipc")

local StackConfig = require 'stackline.stackline.config'
local Stackmanager = require 'stackline.stackline.stackmanager'
local _ = require 'stackline.utils.utils'

print(hs.settings.bundleID)

-- ┌────────┐
-- │ config │
-- └────────┘
stackConfig = StackConfig:new():setEach({
    showIcons = false,
    enableTmpFixForHsBug = true,
}):registerWatchers()

-- instantiate an instance of the stack manager globally
sm = Stackmanager:new(showIcons)

-- ┌─────────┐
-- │ globals │
-- └─────────┘
wf = hs.window.filter
wfd = wf.new():setOverrideFilter{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
}

-- TODO: review how @alin32 structured window (and config!) events into
-- 'shouldRestack' and 'shouldClean' and integrate the good parts here.
local windowEvents = {
    -- window added
    wf.windowCreated,
    wf.windowUnhidden,
    wf.windowUnminimized,

    -- window changed
    wf.windowFullscreened,
    wf.windowUnfullscreened,
    wf.windowMoved, -- NOTE: includes move AND resize events

    -- window removed
    wf.windowDestroyed,
    wf.windowHidden,
    wf.windowMinimized,
    wf.windowNotInCurrentSpace,
}

-- TO CONFIRM: Compared to calling wsi.update() directly in wf:subscribe 
-- callback, even a delay of "0" appears to coalesce events as desired.
local queryWindowState = hs.timer.delayed.new(0.30, function()
    sm:update()
end)

-- ┌───────────────────────────────┐
-- │ window events → update stacks │
-- └───────────────────────────────┘
wfd:subscribe(windowEvents, function()
    -- callback args: window, app, event
    queryWindowState:start()
end)

-- ┌───────────────────────────────────────────────┐
-- │ special case: focus events → optimized redraw │
-- └───────────────────────────────────────────────┘
function unfocusOtherAppWindows(win) -- {{{
    -- To workaround HS BUG "windowUnfocused event not fired for same-app windows "
    -- https://github.com/Hammerspoon/hammerspoon/issues/2400
    -- ../notes-query.md:103
    _.each(win.otherAppWindows, function(w)
        w:redrawIndicator(false)
    end)
end -- }}}

function redrawWinIndicator(hsWin, _app, event) -- {{{
    -- Dedicated redraw method to *adjust* the existing canvas element is WAY
    -- faster than deleting the entire indicator & rebuilding it from scratch,
    -- particularly since this skips querying the app icon & building the icon image.
    local id = hsWin:id()
    local stackedWin = sm:findWindow(id)
    if stackedWin then -- when falsey, the focused win is not stacked
        -- BUG: Unfocused window(s) flicker when an app has 2+ win in a stack {{{
        -- TODO: If there are 2+ windows of the same app in a stack, then the
        -- *unfocused* window(s) indicator(s) flash 'focused' styles for a split second *before* the 
        -- the actually focused window's indicator :< 
        -- REPRO TIP #1: A non-common app window must be between the same-app windows.
        -- REPRO TIP #2: You must be switching FROM a non-common app window TO a a shared app-window. 
        --               Switching between same-app windows is fine, even when a
        --               non-common window is in the same stack. You must. }}}
        if stackConfig:get('enableTmpFixForHsBug') then
            unfocusOtherAppWindows(stackedWin)
        end
        local focused = (event == wf.windowFocused)
        stackedWin:redrawIndicator(focused) -- draw instantly on focus change
    end
end -- }}}

wfd:subscribe(wf.windowFocused, redrawWinIndicator)

wfd:subscribe({wf.windowNotVisible, wf.windowUnfocused}, redrawWinIndicator)

-- always update on load
sm:update()

