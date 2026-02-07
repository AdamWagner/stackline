--[[
Stackline entry point and singleton. Wires up hs.window.filter event subscriptions
that route to either the slow path (yabai query + canvas rebuild via queryWindowState
timer) or the fast path (in-place canvas property updates via redrawWinIndicator).
Also sets up click-to-focus (hs.eventtap) and space-change watcher (hs.spaces.watcher).
Initializes the two globals: _G.u (utils) and _G.stackline (this singleton).
]]
-- luacheck: globals u
-- luacheck: globals hs
-- luacheck: ignore 112
local wf    = hs.window.filter
local timer = hs.timer.delayed
local log   = hs.logger.new('stackline', 'info')
local click = hs.eventtap.event.types['leftMouseDown'] -- fyi, print hs.eventtap.event.types to see all event types

log.i'Loading module: stackline'
-- Globals: u and stackline are global so every module can access them
-- without circular require chains. Set once here, used everywhere.
_G.u = require 'lib.utils'
_G.stackline = {}
stackline.config = require'stackline.configmanager'
stackline.window = require'stackline.window'

function stackline:init(userConfig) -- {{{
    log.i'Initializing stackline'
    if stackline.manager then -- re-initializtion guard https://github.com/AdamWagner/stackline/issues/46
        return log.i'stackline already initialized'
    end

    -- init config with default settings + user overrides
    self.config:init(u.extend(require 'conf', userConfig or {}))

    -- init stackmanager, & run update right away
    -- NOTE: Requires self.config to be initialized first
    self.manager = require'stackline.stackmanager':init()
    self.manager:update({forceQuery=true})

    -- Reuseable update fn that runs at most once every maxRefreshRate (default 0.5s)
    -- NOTE: yabai is only called if shouldQuery() returns true (see queryYabai.lua:shouldQuery)
    self.queryWindowState = timer.new(
      self.config:get'advanced.maxRefreshRate',
      function()
         self.manager:update({forceQuery=self.forceQuery})
         if(self.forceQuery) then self.forceQuery = false end -- reset after consuming
      end,
      true -- continue on error
   )

    self:setupListeners()

    self:setupClickTracker()
    return self
end -- }}}

-- Default window filter controls what hs.window 'sees'
stackline.wf = wf.new():setOverrideFilter{ -- {{{
    visible = true, -- i.e., neither hidden nor minimized
    fullscreen = false,
    currentSpace = true,
    allowRoles = 'AXStandardWindow',
} -- }}}

stackline.events = { -- {{{
    -- Slow path: check if stacks changed, query yabai if so
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
    -- Subset of checkOn that bypasses the change-detection check and always queries yabai
    forceQueryOn = {
        wf.windowCreated,
        wf.windowsChanged,
        wf.windowMoved,
    },
    -- Fast path: update existing indicator canvas elements in-place (no yabai query)
    redrawOn = {
        wf.windowFocused,
        wf.windowNotVisible,
        wf.windowUnfocused,
    }
} -- }}}

-- Subscribe to window events:
-- checkOn events → throttled slow path (query yabai if stacks changed)
-- redrawOn events → fast path (update indicator appearance in-place)
function stackline:setupListeners() -- {{{
    self.wf:subscribe(self.events.checkOn, function(_win, _app, evt)
        self.forceQuery = self.forceQuery or u.contains( -- set forceQuery depending on the type of event
            self.events.forceQueryOn,
            evt
        )

        log.i('Window event:', evt, 'force:', self.forceQuery)
        self.queryWindowState:start() -- (re)start the throttled timer
    end)

    self.wf:subscribe(
        self.events.redrawOn,
        self.redrawWinIndicator
    )
end -- }}}

-- Listen for left mouse click events.
-- If indicator containing the clickAt position can be found, focus that indicator's window.
function stackline:setupClickTracker() -- {{{
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

-- Fast path entry point: find the stacked window and update its indicator in-place.
-- WAY faster than rebuilding from scratch since it skips icon lookup and canvas creation.
function stackline.redrawWinIndicator(hsWin, _app, _evt) -- {{{
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
        -- Update stackline when switching spaces
        -- NOTE: hs.spaces.watcher uses deprecated macos APIs, so this may break in an upcoming macos release
        log.i(('hs.spaces.watcher -> changed to space %d'):format(spaceIdx))
        if not stackline.manager then return end

        -- Switch to per-space canvas + cached stacks
        stackline.manager:switchSpace(hs.spaces.focusedSpace())

        if stackline.manager:count() == 0 then
            -- First visit to this space: discover stacks via yabai
            stackline.forceQuery = true
            stackline.queryWindowState:start()
        end
        -- Return visit: cached stacks are valid (can't change on inactive space).
        -- Per-space canvas already has the right indicators — macOS shows it automatically.
        -- Focus events will update focus state via the fast path.

        stackline:refreshClickTracker()
    end
):start() -- }}}

return stackline
