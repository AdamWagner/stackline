--[[
Manages the collection of Stack objects for the current space.
Slow path: receives grouped+indexed windows from queryYabai.lua via ingest(),
creates Stack objects, wires up HS #2400 workaround data, and triggers canvas rebuild.
Fast path: findWindow() locates a window by ID for in-place redraws.
Inherits from Collection for keyed storage and standard iteration.
]]
local log        = hs.logger.new('stackmanager', 'info')
local Collection = require 'lib.collection'

local Stackmanager = setmetatable({}, Collection)
Stackmanager.__index = Stackmanager

function Stackmanager.__tostring(self)
    return ('<Stackmanager: %d stacks>'):format(self:count())
end

Stackmanager.query = require 'stackline.queryYabai'

function Stackmanager:init() -- {{{
    self._items = {}
    self.screenCanvases = {} -- {screenId → hs.canvas} — one shared canvas per screen
    self.showIcons = stackline.config:get('appearance.showIcons')
    return self
end -- }}}

function Stackmanager:stacks() -- {{{
    -- Convenience accessor: returns array of Stack objects (same shape as old self.stacks)
    return self:get()
end -- }}}

function Stackmanager:update(opts) -- {{{
    log.i('Running update()')
    self.query.run(opts) -- async: calls stackmanager:ingest when yabai responds
    return self
end -- }}}

function Stackmanager:getScreenCanvas(screen) -- {{{
    -- Returns the shared canvas for a screen, creating it on first use.
    -- Canvas persists across rebuild cycles — only elements are swapped.
    local screenId = screen:id()
    if not self.screenCanvases[screenId] then
        local canvas = hs.canvas.new(screen:fullFrame())
        canvas:clickActivating(false)
        canvas:show()
        self.screenCanvases[screenId] = canvas
    end
    return self.screenCanvases[screenId]
end -- }}}

function Stackmanager:ingest(stacks, appWins) -- {{{
    self:cleanup()

    for stackId, groupedWindows in pairs(stacks) do
        local stack = require 'stackline.stack':new(groupedWindows)
        stack.id = stackId
        stack:each(function(win)
            -- win.otherAppWindows needed to workaround Hammerspoon issue #2400
            win.otherAppWindows = u.filter(appWins[win.app], function(w)
                -- exclude self and windows on other screens
                return (w.id ~= win.id) and (w.screen == win.screen)
            end)
            -- TODO: fix error with nil stack field (??): window.lua:32: attempt to index a nil value (field 'stack')
            win.stack = stack -- enables calling stack methods from window
            -- Pass shared screen canvas so Indicator inserts elements into it
            win.screenCanvas = self:getScreenCanvas(win._win:screen())
        end)
        self:add(stack)
    end
    self:rebuildAllIndicators()
end -- }}}

function Stackmanager:cleanup() -- {{{
    -- Clear all elements from shared canvases (canvases themselves persist)
    for _screenId, canvas in pairs(self.screenCanvases) do
        canvas:replaceElements()
    end
    self:clear()
end -- }}}

function Stackmanager:getSummary(external) -- {{{
    -- Summarizes all stacks on the current space, making it easy to determine
    -- what needs to be updated (if anything).

    -- Normalize: external is already an array of window arrays; self:stacks()
    -- contains Stack objects, so unwrap :windows() to get the same shape.
    local stacks = external or u.map(self:stacks(), function(s) return s:windows() end)
    return {
        numStacks = #stacks,
        topLeft = u.map(stacks, function(ws) return ws[1].topLeft end),
        dimensions = u.map(stacks, function(ws) return ws[1].stackId end),
        numWindows = u.map(stacks, function(ws) return #ws end),
    }
end -- }}}

function Stackmanager:rebuildAllIndicators() -- {{{
    -- Clear all canvas elements first, then rebuild (avoids stale elements)
    for _screenId, canvas in pairs(self.screenCanvases) do
        canvas:replaceElements()
    end
    self:each(function(stack)
        stack:rebuildAllIndicators()
    end)
end -- }}}

function Stackmanager:findWindow(wid) -- {{{
    -- NOTE: A window must be *in* a stack to be found with this method!
    for _, stack in pairs(self._items) do
        local win = stack:get(wid) -- O(1) keyed lookup
        if win then return win end
    end
end -- }}}

function Stackmanager:findStackByWindow(win) -- {{{
    -- NOTE: may not need when Hammerspoon #2400 is closed
    -- O(1) keyed lookup by stackId
    return self:get(win.stackId)
end -- }}}

function Stackmanager:getShowIconsState() -- {{{
    return self.showIcons
end -- }}}

function Stackmanager:getClickedWindow(point) -- {{{
    -- given the coordinates of a mouse click, return the first window whose
    -- indicator element encompasses the point, or nil if none.
    for _, stack in pairs(self._items) do
        local clickedWindow = stack:getWindowByPoint(point)
        if clickedWindow then
            return clickedWindow
        end
    end
end -- }}}

function Stackmanager:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

return Stackmanager
