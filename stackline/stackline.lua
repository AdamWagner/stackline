require("hs.ipc")
u = require 'stackline.lib.utils'

local wf = hs.window.filter -- just an alias
local u = require 'stackline.lib.utils'
local cb = u.invoke
local log = hs.logger.new('stackline')
log.setLogLevel('debug')
log.i("Loading module")

stackline = {}
stackline.config = require 'stackline.stackline.configManager'
stackline.window = require 'stackline.stackline.window'

function stackline.init(userConfig) -- {{{
    log.i('starting stackline')

    stackline.config:init(          -- init config with default conf + user overrides
        table.merge(require 'stackline.conf', userConfig)
    )

    stackline.manager = require('stackline.stackline.stackmanager'):init()

    stackline.manager:update() -- always update window state on start

    if stackline.config:get('features.clickToFocus') then
        hs.alert.show('clickTracker has started')
        log.i('FEAT: ClickTracker starting')
        stackline.clickTracker:start()
    end
end -- }}}

stackline.wf = wf.new():setOverrideFilter{
    visible = true, -- (i.e. not hidden and not minimized)
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
}

local click = hs.eventtap.event.types['leftMouseDown'] -- print hs.eventtap.event.types to see all event types
stackline.clickTracker = hs.eventtap.new({click}, function(e) --  {{{
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
    local turnedOn = stackline.config:get('features.clickToFocus')

    if stackline.clickTracker:isEnabled() then
        stackline.clickTracker:stop()                     -- always stop if running
    end
    if turnedOn then -- only start if feature is enabled
        log.d('features.clickToFocus is enabled!')
        hs.alert.show('clickTracker has refreshed')
        stackline.clickTracker:start()
    else
        log.d('features.clickToFocus is DISABLED ❌')
        stackline.clickTracker:stop()                     -- double-stop if disabled
        stackline.clickTracker = nil                      -- erase if disabled
    end
end -- }}}

stackline.queryWindowState = hs.timer.delayed.new(0.30, function()
    -- 0.30s delay debounces querying via Hammerspoon & yabai
    -- yabai is only queried if Hammerspoon query results are different than current state
    stackline.manager:update()
end
)

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

-- On each win evt above, query window state & check if refersh needed
stackline.wf:subscribe(stackline.windowEvents, function() -- {{{
    -- callback args: window, app, event
    stackline.queryWindowState:start()
end) -- }}}

-- On each win evt listed, simply *redraw* indicators
-- No need for heavyweight query + refresh
stackline.wf:subscribe({
    wf.windowFocused,
    wf.windowNotVisible,
    wf.windowUnfocused,
}, stackline.redrawWinIndicator)

-- On space switch, query window state & refresh, plus refresh click tracker
hs.spaces.watcher.new(function() -- {{{
    stackline.queryWindowState:start()
    stackline.refreshClickTracker()
end):start() -- }}}

return stackline
