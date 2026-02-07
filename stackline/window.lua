--[[
Window model: wraps an hs.window, tracks focus state, and coordinates
indicator updates. Delegates all rendering to the Indicator module
(stackline/indicator.lua). Created via newFromData() from plain data tables
produced by extractWindowData() in queryYabai.lua.
]]
local log       = hs.logger.new('window', 'info')
local Indicator = require 'stackline.indicator'
log.i('Loading module: window')

local Window = {}
Window.__index = Window

function Window.__tostring(self)
    return ('<Window %s: %s — %s>'):format(self.id or '?', self.app or '?', self.title or '')
end

-- Create a Window from a plain data table (from extractWindowData).
-- Used by reconcile path for windows that don't yet exist.
function Window:newFromData(data) -- {{{
    return setmetatable({
        title      = data.title,
        app        = data.app,
        id         = data.id,
        frame      = data.frame,
        stackId    = data.stackId,
        topLeft    = data.topLeft,
        stackIdFzy = data.stackIdFzy,
        _win       = data._win,
        screen     = data.screen,
        stackIdx   = data.stackIdx,
        indicator  = nil,
    }, self)
end -- }}}

-- Update an existing Window in-place from new data.
-- Only rebuilds the indicator when screen or app changed (different canvas/icon).
-- Repositions in-place when only geometry changed. Does nothing if unchanged.
function Window:reconcile(data) -- {{{
    self._win  = data._win     -- refresh hs.window reference
    self.title = data.title

    local screenChanged   = self.screen ~= data.screen
    local frameChanged    = self.stackId ~= data.stackId  -- stackId encodes floored x|y|w|h
    local stackIdxChanged = self.stackIdx ~= data.stackIdx
    local appChanged      = self.app ~= data.app

    self.frame      = data.frame
    self.app        = data.app
    self.stackId    = data.stackId
    self.topLeft    = data.topLeft
    self.stackIdFzy = data.stackIdFzy
    self.stackIdx   = data.stackIdx
    self.screen     = data.screen

    if screenChanged or appChanged then
        -- Different canvas or different icon: must fully rebuild indicator
        log.d('reconcile: rebuild indicator for', self.id, '(screen/app changed)')
        self:deleteIndicator()
        self.indicator = nil  -- rebuilt later in Stackmanager:reconcile step 5
    elseif frameChanged or stackIdxChanged then
        -- Geometry changed: reposition in-place
        log.d('reconcile: reposition', self.id, '(frame/stackIdx changed)')
        if self.indicator then
            self.indicator:reposition(
                self._win:screen():absoluteToLocal(hs.geometry(self.frame)),
                self.stackIdx,
                self._win:screen():fullFrame()
            )
        end
    else
        log.d('reconcile: no change for', self.id)
    end
end -- }}}

-- Returns true if this window is the focused window.
-- Accepts an optional pre-resolved focusedWinId to avoid redundant HS API calls.
function Window:isFocused(focusedWinId) -- {{{
    if focusedWinId then return self.id == focusedWinId end
    local focusedWin = hs.window.focusedWindow()
    return focusedWin ~= nil and self.id == focusedWin:id()
end -- }}}

function Window:isStackFocused(focusedWinId) -- {{{
    return self.stack:anyFocused(focusedWinId)
end -- }}}

-- Slow path: create a new Indicator (computes geometry) and draw it.
function Window:buildIndicator() -- {{{
    log.d('buildIndicator for', self.id)
    if self.indicator then self.indicator:delete() end
    self.indicator = Indicator:new({
        appName        = self.app,
        winId          = self.id,
        stackIdx       = self.stackIdx,
        windowFrame    = self._win:screen():absoluteToLocal(hs.geometry(self._win:frame())),
        screen         = self._win:screen(),
        canvas         = self.screenCanvas, -- shared per-screen canvas from Stackmanager
        isFocused      = self:isFocused(),
        isStackFocused = self:isStackFocused(),
        config         = stackline.config:get('appearance'),
    })
    self.indicator:draw()
    return self
end -- }}}

-- Fast path: update existing indicator appearance based on focus changes.
-- Handles Window/Stack side effects (workaround, sibling redraws), then
-- delegates canvas updates to self.indicator:updateFocus().
function Window:redrawIndicator() -- {{{
    log.i('redrawIndicator for', self.id)

    -- Resolve focused window ID once; pass through to avoid N+1 hs.window.focusedWindow() calls
    local focusedWin = hs.window.focusedWindow()
    local focusedWinId = focusedWin and focusedWin:id()
    local isWinFocused = focusedWinId ~= nil and self.id == focusedWinId
    local isStackFocused = self:isStackFocused(focusedWinId)

    -- HS #2400 workaround: manually redraw same-app windows on focus gain.
    -- Runs BEFORE the early return because "last-active" preservation keeps
    -- winFocused=true after leaving a stack, so winChanged may be false even
    -- though focus genuinely moved here from a same-app window in another stack.
    -- Safe: unfocusOtherAppWindows calls redrawIndicator on unfocused windows,
    -- which won't re-trigger (isWinFocused=false), so no recursion.
    if isWinFocused and stackline.config:get('features.hsBugWorkaround') then
        self:unfocusOtherAppWindows()
    end

    if not self.indicator then self:buildIndicator() end -- safety net

    local changes = self.indicator:updateFocus(isWinFocused, isStackFocused)
    if not changes then return false end

    -- Trigger sibling redraws on stack focus transitions.
    if changes.stackChanged and (changes.winChanged or isWinFocused) then
        self.stack:redrawAllIndicators({except = self.id})
    end
end -- }}}

function Window:deleteIndicator() -- {{{
    log.d('deleteIndicator for', self.id)
    if self.indicator then self.indicator:delete() end
end -- }}}

-- Part of the HS #2400 workaround: when focusing a window, manually redraw
-- other windows from the same app since HS may not fire unfocus events for them.
function Window:unfocusOtherAppWindows() -- {{{
    log.i('unfocusOtherAppWindows for', self.id)
    u.each(self.otherAppWindows, function(w)
        w:redrawIndicator()
    end)
end -- }}}

function Window:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

return Window
