require("hs.ipc")
u = require 'stackline.lib.utils'

-- Aliases / shortcuts
local wf    = hs.window.filter
local timer = hs.timer.delayed
local log   = hs.logger.new('stackline', 'info')
local click = hs.eventtap.event.types['leftMouseDown'] -- fyi, print hs.eventtap.event.types to see all event types

log.i("Loading module")

stackline = {}
stackline.config = require 'stackline.stackline.configManager'
stackline.window = require 'stackline.stackline.window'

function stackline:init(userConfig) -- {{{
    log.i('starting stackline')

    -- Default window filter controls what windows hs "sees"
    -- Required before initialization
    self.wf = wf.new():setOverrideFilter{  -- {{{
        visible = true,   -- (i.e. not hidden and not minimized)
        fullscreen = false,
        currentSpace = true,
        allowRoles = 'AXStandardWindow',
    }  -- }}}

    self.config:init( -- init config with default conf + user overrides
        table.merge(require 'stackline.conf', userConfig)
    )

    -- init stackmanager, and run update right away
    self.manager = require('stackline.stackline.stackmanager'):init()
    self.manager:update()


    -- Reuseable fn that runs at most once every 0.3s
    -- yabai is only queried if Hammerspoon query results are different than current state
    local maxRefreshRate = self.config:get('advanced.maxRefreshRate')
    self.queryWindowState = timer.new(maxRefreshRate, function()  -- {{{
        self.manager:update()
    end)  -- }}}

    -- Listen for left mouse click events
    -- if indicator containing the clickAt position can be found, focus that indicator's window
    self.clickTracker = hs.eventtap.new({click}, function(e)  -- {{{
        local clickAt    = hs.geometry.point(e:location().x, e:location().y)
        local clickedWin = self.manager:getClickedWindow(clickAt)
        if clickedWin then
            clickedWin._win:focus()
            return true   -- stops propogation
        end
    end)  -- }}}

    self.windowEvents = { -- {{{
        wf.windowCreated,      -- window added
        wf.windowUnhidden,
        wf.windowUnminimized,

        wf.windowFullscreened, -- window changed
        wf.windowUnfullscreened,
        wf.windowMoved,        -- NOTE: winMoved includes move AND resize evts

        wf.windowDestroyed,    -- window removed
        wf.windowHidden,
        wf.windowMinimized,
    } -- }}}

    -- On each win evt above (or at most once every 0.3s)
    -- query window state and check if refersh needed
    self.wf:subscribe(
        self.windowEvents, function(_win, _app, _evt) -- {{{
            self.queryWindowState:start()
        end 
    ) -- }}}

    -- On each win evt listed, simply *redraw* indicators
    -- No need for heavyweight query + refresh
    self.wf:subscribe({  -- {{{
        wf.windowFocused,
        wf.windowNotVisible,
        wf.windowUnfocused,
    }, self.redrawWinIndicator)  -- }}}

    -- Activate clickToFocus if feature turned on
    if self.config:get('features.clickToFocus') then  -- {{{
        log.i('FEAT: ClickTracker starting')
        self.clickTracker:start()
    end  -- }}}
end -- }}}

function stackline:refreshClickTracker() -- {{{
    local turnedOn = self.config:get('features.clickToFocus')

    if self.clickTracker:isEnabled() then
        self.clickTracker:stop() -- always stop if running
    end
    if turnedOn then -- only start if feature is enabled
        log.d('features.clickToFocus is enabled!')
        self.clickTracker:start()
    else
        log.d('features.clickToFocus is disabled')
        self.clickTracker:stop() -- double-stop if disabled
    end
end -- }}}

function stackline.redrawWinIndicator(hsWin, _app, _event) -- {{{
    -- Dedicated redraw method to *adjust* the existing canvas element is WAY
    -- faster than deleting the entire indicator & rebuilding it from scratch,
    -- particularly since this skips querying the app icon & building the icon image.
    local stackedWin = stackline.manager:findWindow(hsWin:id())
    if stackedWin then -- if non-existent, the focused win is not stacked
        stackedWin:redrawIndicator()
    end

end -- }}}

hs.spaces.watcher.new(function() -- {{{
    -- On space switch, query window state & refresh,
    -- plus refresh click tracker
    stackline.queryWindowState:start()
    stackline:refreshClickTracker()
end):start() -- }}}

return stackline
