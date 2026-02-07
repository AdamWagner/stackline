--[[
Manages the collection of Stack objects for the current space.
Maintains per-space state: _items holds current space's stacks, _spaceItems caches
other spaces' stacks. switchSpace() swaps between them on space change.
One canvas per screen per space (no canJoinAllSpaces): macOS auto-hides/shows on switch.
Return visits are instant — cached stacks and canvas elements persist.
Slow path: reconcile() diffs incoming data against existing Window objects.
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
    self._spaceItems = {}  -- {spaceId → {stackId → Stack}} — cached stacks per space
    self._currentSpace = hs.spaces.focusedSpace()
    self.screenCanvases = {} -- {screenId|spaceId → hs.canvas} — one canvas per screen per space
    self.showIcons = stackline.config:get('appearance.showIcons')
    return self
end -- }}}

function Stackmanager:stacks() -- {{{
    -- Convenience accessor: returns array of Stack objects (same shape as old self.stacks)
    return self:get()
end -- }}}

function Stackmanager:update(opts) -- {{{
    log.i('Running update()')
    self.query.run(opts) -- async: calls reconcile() (cleanup first if forceRebuild)
    return self
end -- }}}

function Stackmanager:switchSpace(newSpaceId) -- {{{
    -- Save current space's stacks, restore new space's cached stacks.
    -- Canvases are per-space: macOS auto-hides old, auto-shows new.
    -- Stacks can't change on inactive spaces, so cached state is always valid.
    if self._currentSpace == newSpaceId then return end
    if self._currentSpace then
        self._spaceItems[self._currentSpace] = self._items
    end
    self._currentSpace = newSpaceId
    self._items = self._spaceItems[newSpaceId] or {}
    log.i(('switchSpace: now on space %s (%d cached stacks)'):format(
        tostring(newSpaceId), self:count()))
end -- }}}

function Stackmanager:getScreenCanvas(screen) -- {{{
    -- Returns the shared canvas for a screen+space, creating it on first use.
    -- Canvas stays on its creation space (no canJoinAllSpaces): macOS auto-hides/shows
    -- on space switch. Elements persist across rebuild cycles within a space.
    local key = tostring(screen:id()) .. '|' .. tostring(self._currentSpace)
    if not self.screenCanvases[key] then
        local canvas = hs.canvas.new(screen:fullFrame())
        canvas:clickActivating(false) -- prevents Hammerspoon from stealing focus when canvas is clicked
        canvas:show()
        self.screenCanvases[key] = canvas
    end
    return self.screenCanvases[key]
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

function Stackmanager:reconcile(newStacks) -- {{{
    -- Reconcile-based update: reuses existing Window/Indicator objects where possible.
    -- Only creates/destroys/repositions what actually changed.

    -- 1. Collect all existing windows into a flat lookup
    local existingWindows = {}
    for _, stack in pairs(self._items) do
        stack:each(function(win)
            existingWindows[win.id] = win
        end)
    end

    -- 2. Clear stacks but NOT canvases or indicators (those persist on windows)
    self._items = {}

    -- 3. Build new stacks, reusing existing windows where possible
    -- Skip empty groups: mergeWinStackIdxs can filter out all windows from a group
    -- when none had a valid stack-index (they were overlapping, not truly stacked).
    for stackId, windowDataArray in pairs(newStacks) do
        if #windowDataArray > 0 then
            local stack = require 'stackline.stack':new({})
            stack.id = stackId

            for _, data in ipairs(windowDataArray) do
                local existing = existingWindows[data.id]
                if existing then
                    existing:reconcile(data)
                    existing.stack = stack
                    existing.screenCanvas = self:getScreenCanvas(data._win:screen())
                    stack:add(existing)
                    existingWindows[data.id] = nil  -- claimed
                else
                    local win = stackline.window:newFromData(data)
                    win.stack = stack
                    win.screenCanvas = self:getScreenCanvas(data._win:screen())
                    stack:add(win)
                end
            end
            self:add(stack)
        end
    end

    -- 4. Delete indicators for windows no longer in any stack
    local orphanCount = 0
    for _, orphan in pairs(existingWindows) do
        orphan:deleteIndicator()
        orphanCount = orphanCount + 1
    end

    -- 5. Build indicators for new windows (those without one)
    local newCount = 0
    self:each(function(stack)
        stack:each(function(win)
            if not win.indicator then
                win:buildIndicator()
                newCount = newCount + 1
            end
        end)
    end)

    log.i(('reconcile: %d stacks, %d new, %d orphaned'):format(
        self:count(), newCount, orphanCount))

    -- 6. Wire up otherAppWindows (HS #2400 workaround)
    local byApp = {}
    self:each(function(stack)
        stack:each(function(win)
            if not byApp[win.app] then byApp[win.app] = {} end
            table.insert(byApp[win.app], win)
        end)
    end)
    self:each(function(stack)
        stack:each(function(win)
            win.otherAppWindows = u.filter(byApp[win.app] or {}, function(w)
                return (w.id ~= win.id) and (w.screen == win.screen)
            end)
        end)
    end)
end -- }}}

function Stackmanager:cleanup() -- {{{
    -- Clear all elements from all canvases (all spaces) and invalidate cache.
    -- Canvases themselves persist (empty).
    for _, canvas in pairs(self.screenCanvases) do
        canvas:replaceElements()
    end
    self:clear()
    self._spaceItems = {}
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
    -- Clear all canvas elements (all spaces), invalidate cache, then rebuild current space.
    -- Other spaces rebuild on next visit (treated as first visit).
    for _, canvas in pairs(self.screenCanvases) do
        canvas:replaceElements()
    end
    self._spaceItems = {}
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
