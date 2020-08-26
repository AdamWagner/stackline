require("hs.ipc")
print(hs.settings.bundleID)

local StackConfig = require 'stackline.stackline.config'
local Stackmanager = require 'stackline.stackline.stackmanager'
local wf = hs.window.filter

-- ┌────────┐
-- │ config │
-- └────────┘
local config = {showIcons = true, enableTmpFixForHsBug = true}

-- ┌─────────┐
-- │ globals │
-- └─────────┘
-- instantiate instances of key classes and assign to global table (_G)
_G.stackConfig = StackConfig:new():setEach(config):registerWatchers()
_G.Sm = Stackmanager:new()
_G.wfd = wf.new():setOverrideFilter{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
}

-- TODO: review how @alin32 structured window (and config!) events into
-- 'shouldRestack' and 'shouldClean' and apply those ideas here.
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
}

-- TO CONFIRM: Compared to calling wsi.update() directly in wf:subscribe 
-- callback, even a delay of "0" appears to coalesce events as desired.
local queryWindowState = hs.timer.delayed.new(0.30, function()
    Sm:update()
end)

-- ┌───────────────────────────────┐
-- │ window events → update stacks │
-- └───────────────────────────────┘
wfd:subscribe(windowEvents, function()
    -- callback args: window, app, event
    queryWindowState:start()
end)

hs.spaces.watcher.new(function()
    -- Added 2020-08-12 to fill the gap of hs._asm.undocumented.spaces
    queryWindowState:start()
end):start()

function redrawWinIndicator(hsWin, _app, _event) -- {{{
    -- Dedicated redraw method to *adjust* the existing canvas element is WAY
    -- faster than deleting the entire indicator & rebuilding it from scratch,
    -- particularly since this skips querying the app icon & building the icon image.
    local stackedWin = Sm:findWindow(hsWin:id())
    if stackedWin then -- when falsey, the focused win is not stacked
        stackedWin:redrawIndicator()
    end
end -- }}}

wfd:subscribe(wf.windowFocused, redrawWinIndicator)

wfd:subscribe({wf.windowNotVisible, wf.windowUnfocused}, redrawWinIndicator)

-- always update on load
Sm:update()

return {config = _G.stackConfig, manager = _G.Sm}
