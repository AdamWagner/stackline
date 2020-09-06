require("hs.ipc")
print(hs.settings.bundleID)

local u = require 'stackline.lib.utils'
local StackConfig = require 'stackline.stackline.config'
local wf = hs.window.filter -- just an alias

local stackline = {}

stackline.focusedScreen = nil

stackline.wf = wf.new():setOverrideFilter{ -- {{{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
} -- }}}

local click = hs.eventtap.event.types['leftMouseDown'] -- print hs.eventtap.event.types to see all event types
stackline.clickTracker = hs.eventtap.new({click}, --  {{{
function(e)
    -- Listen for left mouse click events
    -- if indicator containing the clickAt position can be found, focus that indicator's window
    local clickAt = hs.geometry.point(e:location().x, e:location().y)
    local clickedWin = stackline.manager:getClickedWindow(clickAt)
    if clickedWin then
        clickedWin._win:focus()
        return true -- stops propogation
    end
end) -- }}}

stackline.refreshClickTracker = function() -- {{{
    if stackline.clickTracker:isEnabled() then
        stackline.clickTracker:stop()
    end
    stackline.clickTracker:start()
end -- }}}

function stackline.start(userPrefs) -- {{{
    u.pheader('starting stackline')
    local defaultUserPrefs = {
        showIcons = true,
        enableTmpFixForHsBug = true,

        -- Window frames are rounded to fuzzFactor before equality comparison. 
        -- ~30 is needed to support stacks w/ iTerm
        frameFuzz = 30,
    }
    local prefs = userPrefs or defaultUserPrefs
    stackline.config = StackConfig:new():setEach(prefs):registerWatchers()
    stackline.manager = require('stackline.stackline.stackmanager'):new()
    stackline.manager:update() -- always update window state on start
    stackline.clickTracker:start()
end -- }}}

stackline.queryWindowState = hs.timer.delayed.new(0.30, function() -- {{{
    -- 0.30s delay debounces querying via Hammerspoon & yabai
    -- yabai is only queried if Hammerspoon query results are different than current state
    stackline.manager:update()
end) -- }}}

function stackline.redrawWinIndicator(hsWin, _app, _event) -- {{{
    -- Dedicated redraw method to *adjust* the existing canvas element is WAY
    -- faster than deleting the entire indicator & rebuilding it from scratch,
    -- particularly since this skips querying the app icon & building the icon image.
    local stackedWin = stackline.manager:findWindow(hsWin:id())
    if stackedWin then -- if non-existent, the focused win is not stacked
        stackedWin:redrawIndicator()
    end

end -- }}}

stackline.windowEvents = { -- {{{
    -- TODO: review how @alin32 structured window (and config!) events into
    -- 'shouldRestack' and 'shouldClean' and apply those ideas here.

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
} -- }}}

stackline.wf:subscribe(stackline.windowEvents, function() -- {{{
    -- callback args: window, app, event
    stackline.queryWindowState:start()
end) -- }}}

stackline.wf:subscribe(wf.windowFocused, stackline.redrawWinIndicator)

local unfocused = {wf.windowNotVisible, wf.windowUnfocused}
stackline.wf:subscribe(unfocused, stackline.redrawWinIndicator)

hs.spaces.watcher.new(function() -- {{{
    -- Added 2020-08-12 to fill the gap of hs._asm.undocumented.spaces
    stackline.queryWindowState:start()
    stackline.refreshClickTracker()
end):start() -- }}}

-- Delayed start (stackline module needs to be loaded globally before it can reference its own methods)
-- TODO: Add instructions to README.md to call stackline:start(userPrefs) from init.lua, and remove this.
hs.timer.doUntil(function() -- {{{
    return stackline.manager
end, function()
    stackline.start()
end, 0.1) -- }}}

return stackline
