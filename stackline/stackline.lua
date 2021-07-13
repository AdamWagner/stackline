-- luacheck: globals u
-- luacheck: ignore 112
hs.logger.historySize(500) -- save 500 log lines to history

local timer = hs.timer.delayed
local log   = hs.logger.new('stackline', 'info')
local click = hs.eventtap.event.types['leftMouseDown'] -- fyi, print `hs.eventtap.event.types` to see all event types

log.i 'Loading module: stackline'

_G.u = require 'stackline.lib.utils'

stackline = {} -- access stackline under global 'stackline'
stackline.config = require 'stackline.configmanager'
stackline.window = require 'stackline.window'

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
    self.manager.query.run({forceRedraw=true})

    -- Reuseable update fn that runs at most once every maxRefreshRate (default 0.3s)
    -- NOTE: yabai is only called if query.shouldRestack() returns true (see ./stackline/query.lua:104)
    self.queryWindowState = timer.new(
      self.config:get'advanced.maxRefreshRate',
      function()
         self.manager.query.run({forceRedraw=self.forceRedraw})
         if(self.forceRedraw) then self.forceRedraw = false end
      end,
      true -- continue on error
   )

    self:setupClickTracker()
    return self
end -- }}}

function stackline:setupClickTracker() --[[ {{{
    Listen for left mouse click events
    If indicator containing the clickAt position can be found, focus that indicator's window
    SEE: https://github.com/Hammerspoon/hammerspoon/issues/2425
    --------
    To debug live mouse location:
        hs.eventtap.new(
            { hs.eventtap.event.types.mouseMoved }, 
            function(event)
                u.p(event)
                u.p(event:location())
            end
        ):start()
    ]]

    -- local function initialize()
    --     internalData.watcher = hs.eventtap.new({
    --         hs.eventtap.event.types.leftMouseDown,
    --         hs.eventtap.event.types.leftMouseUp,
    --         hs.eventtap.event.types.leftMouseDragged
    --     },dragDropEvent)
    -- end
    -- local moved = hs.eventtap.event.types.mouseMoved

    -- -- self.clickTracker = hs.eventtap.new({click, moved}, function(e)
    -- self.clickTracker = hs.eventtap.new({click, moved}, function(e)
    --     local evt = e:getType()
    --     local clickAt = hs.geometry.point(e:location().x, e:location().y)

    --     if evt ~= click then 
    --         u.p(clickAt)
    --         return false
    --     end

    --     local clickedWin = self.manager:getClickedWindow(clickAt)

    --     if clickedWin then
    --         log.i('Clicked window at', clickAt)
    --         clickedWin._win:focus()
    --         return true   -- stop propogation
    --     end
    -- end)

    -- -- Activate clickToFocus if feature turned on
    -- if self.config:get'features.clickToFocus' then
    --     log.i'ClickTracker starting'
    --     self.clickTracker:start()
    -- end
end -- }}}

function stackline:refreshClickTracker() -- {{{
    self.clickTracker:stop() -- always stop if running
    if self.config:get'features.clickToFocus' then -- only start if feature is enabled
        log.i'features.clickToFocus is enabled — starting clickTracker for current space'
        self.clickTracker:start()
    end
end -- }}}

function stackline:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    self.window:setLogLevel(lvl)
    self.manager:setLogLevel(lvl)
    log.i( ('stackline log level set to %s'):format(lvl) )
end -- }}}

stackline.spaceWatcher = hs.spaces.watcher.new( -- {{{
    function(spaceIdx)
        -- QUESTION: do I need to clean up (i.e., manuallygarbage collect) this watcher? If so, how?
        -- Update stackline when switching spaces
        -- NOTE: hs.spaces.watcher uses deprecated macos APIs, so this may break in an upcoming macos release
        log.i(('hs.spaces.watcher -> changed to space %d'):format(spaceIdx))
        stackline.forceRedraw = true -- force the next update cycle to redraw
        stackline.queryWindowState:start()
        stackline:refreshClickTracker()
    end
):start() -- }}}

return stackline
