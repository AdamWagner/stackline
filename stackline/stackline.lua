-- luacheck: globals table.merge
-- luacheck: globals u
-- luacheck: ignore 112
local wf    = hs.window.filter
local timer = hs.timer.delayed
local log   = hs.logger.new('stackline', 'info')
local click = hs.eventtap.event.types['leftMouseDown'] -- fyi, print hs.eventtap.event.types to see all event types

log.i'Loading module: stackline'
_G.u = require 'lib.utils'
_G.stackline = {} -- access stackline under global 'stackline'
stackline.config = require'stackline.configmanager'
stackline.window = require'stackline.window'

function stackline:init(userConfig) -- {{{
    log.i'Initializing stackline'
    if stackline.manager then -- re-initializtion guard https://github.com/AdamWagner/stackline/issues/46
        return log.i'stackline already initialized'
    end

    -- init config with default settings + user overrides
    self.config:init(u.extend(require 'stackline.conf', userConfig or {}))

    -- init stackmanager, & run update right away
    -- NOTE: Requires self.config to be initialized first
    self.manager = require'stackline.stackmanager':init()
    self.manager:update({forceRedraw=true})

    -- Reuseable update fn that runs at most once every maxRefreshRate (default 0.3s)
    -- NOTE: yabai is only called if query.shouldRestack() returns true (see ./stackline/query.lua:104)
    self.queryWindowState = timer.new(
      self.config:get'advanced.maxRefreshRate',
      function()
         self.manager:update({forceRedraw=self.forceRedraw})
         if(self.forceRedraw) then self.forceRedraw = false end
      end,
      true -- continue on error
   )

    self:setupListeners()

    self:setupClickTracker()
    return self
end -- }}}

stackline.wf = wf.new():setOverrideFilter{ -- {{{
    -- Default window filter controls what hs.window 'sees'
    visible = true, -- i.e., neither hidden nor minimized
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
} -- }}}

stackline.events = { -- {{{
    checkOn = {
        wf.windowCreated,
        wf.windowUnhidden,

        wf.windowMoved,   -- NOTE: winMoved includes move AND resize evts
        wf.windowUnminimized,

        wf.windowFullscreened,
        wf.windowUnfullscreened,

        wf.windowDestroyed,
        wf.windowHidden,
        wf.windowMinimized,
        wf.windowsChanged,   -- NOTE: pseudo-event for any change in list of windows. Addresses missing windowCreated events :/
    },
    forceCheckOn = {
        wf.windowCreated,
        wf.windowsChanged,
        wf.windowMoved,
    },
    redrawOn = {
        wf.windowFocused,
        wf.windowNotVisible,
        wf.windowUnfocused,
    }
} -- }}}

function stackline:setupListeners() -- {{{
    -- On each win evt above, run update at most once every maxRefreshRate (defaults to 0.3s))
    -- update = query window state & check if redraw needed
    self.wf:subscribe(self.events.checkOn, function(_win, _app, evt)
        self.forceRedraw = u.contains( -- forceRedraw depending on the type of event
            self.events.forceCheckOn,
            evt
        )

        log.i('Window event:', evt, 'force:', self.forceRedraw)
        self.queryWindowState:start()
    end)

    -- On each win evt listed, simply *redraw* indicators
    -- No need for heavyweight query + refresh
    self.wf:subscribe(
        self.events.redrawOn,
        self.redrawWinIndicator
    )
end -- }}}

function stackline:setupClickTracker() -- {{{
      -- Listen for left mouse click events
      -- If indicator containing the clickAt position can be found, focus that indicator's window
    self.clickTracker = hs.eventtap.new({click}, function(e)
        local clickAt = hs.geometry.point(e:location().x, e:location().y)
        local clickedWin = self.manager:getClickedWindow(clickAt)
        if clickedWin then
            log.i('Clicked window at', clickAt)
            clickedWin._win:focus()
            return true   -- stop propogation
        end
    end)

    -- Activate clickToFocus if feature turned on
    if self.config:get'features.clickToFocus' then
        log.i'ClickTracker starting'
        self.clickTracker:start()
    end
end -- }}}

function stackline:refreshClickTracker() -- {{{
    self.clickTracker:stop()                         -- always stop if running
    if self.config:get'features.clickToFocus' then -- only start if feature is enabled
        log.i'features.clickToFocus is enabled — starting clickTracker for current space'
        self.clickTracker:start()
    end
end -- }}}

function stackline.redrawWinIndicator(hsWin, _app, _evt) -- {{{
    --[[ Dedicated redraw method to *adjust* the existing canvas element is WAY
       faster than deleting the entire indicator & rebuilding it from scratch,
       particularly since this skips querying the app icon & building the icon image.
    ]]
    local stackedWin = stackline.manager:findWindow(hsWin:id())
    if not stackedWin then return end -- if non-existent, the focused win is not stacked
    stackedWin:redrawIndicator()
end -- }}}

function stackline:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

stackline.spaceWatcher = hs.spaces.watcher.new( -- {{{
    function(spaceIdx)
        -- QUESTION: do I need to clean this up? If so, how?
        -- Update stackline when switching spaces
        -- NOTE: hs.spaces.watcher uses deprecated macos APIs, so this may break in an upcoming macos release
        log.i(('hs.spaces.watcher -> changed to space %d'):format(spaceIdx))
        stackline.forceRedraw = true -- force the next update cycle to redraw
        stackline.queryWindowState:start()
        stackline:refreshClickTracker()
    end
):start() -- }}}

return stackline
