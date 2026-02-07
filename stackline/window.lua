--[[
Window model: wraps an hs.window, computes stack grouping IDs, tracks focus
state, and coordinates indicator updates. Delegates all rendering to the
Indicator module (stackline/indicator.lua).
]]
local log       = hs.logger.new('window', 'info')
local Indicator = require 'stackline.indicator'
log.i('Loading module: window')

local Window = {}
Window.__index = Window

function Window.__tostring(self)
    return ('<Window %s: %s — %s>'):format(self.id or '?', self.app or '?', self.title or '')
end

function Window:new(hsWin) -- {{{
    local stackIdResult = self:makeStackId(hsWin)
    local ws = setmetatable({
        title      = hsWin:title(),              -- window title
        app        = hsWin:application():name(), -- app name (string)
        id         = hsWin:id(),                 -- window id (string) NOTE: HS win.id == yabai win.id
        frame      = hsWin:frame(),              -- x,y,w,h of window (table)
        stackId    = stackIdResult.stackId,      -- "{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
        topLeft    = stackIdResult.topLeft,      -- "{x}|{y}" e.g., "35|63" (string)
        stackIdFzy = stackIdResult.fzyFrame,     -- fuzzy "{x}|{y}|{w}|{h}" rounded by fuzzFactor (string)
        _win       = hsWin,                      -- hs.window object (table)
        screen     = hsWin:screen():id(),
        indicator  = nil,                        -- Indicator instance (created in buildIndicator)
    }, self)

    log.i( ('Window:new(%s)'):format(ws.id) )

    return ws
end -- }}}

function Window:newFromData(data) -- {{{
    -- Create a Window from a plain data table (from extractWindowData).
    -- Used by reconcile path for windows that don't yet exist.
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

function Window:reconcile(data) -- {{{
    -- Update an existing Window in-place from new data.
    -- Only rebuilds the indicator when screen or app changed (different canvas/icon).
    -- Repositions in-place when only geometry changed. Does nothing if unchanged.
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

function Window:isFocused() -- {{{
    local focusedWin = hs.window.focusedWindow()
    return focusedWin ~= nil and self.id == focusedWin:id()
end -- }}}

function Window:isStackFocused() -- {{{
    return self.stack:anyFocused()
end -- }}}

function Window:buildIndicator() -- {{{
    -- Slow path: create a new Indicator (computes geometry) and draw it.
    -- Replaces the old setupIndicator():drawIndicator() chain.
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

function Window:redrawIndicator() -- {{{
    -- Fast path: update existing indicator appearance based on focus changes.
    -- Handles Window/Stack side effects (workaround, sibling redraws), then
    -- delegates canvas updates to self.indicator:updateFocus().
    log.i('redrawIndicator for', self.id)

    local isWinFocused = self:isFocused()
    local isStackFocused = self:isStackFocused()

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

function Window:makeStackId(hsWin) -- {{{
    local frame = hsWin:frame():floor() -- floor to avoid sub-pixel differences

    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h

    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    local roundToFuzzFactor = u.partial(u.roundToNearest, fuzzFactor)
    local ff = u.map({x, y, w, h}, roundToFuzzFactor) -- round all dimensions by fuzzFactor

    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
        fzyFrame = table.concat(ff, '|'),
    }
end -- }}}

function Window:unfocusOtherAppWindows() -- {{{
    -- Part of the HS #2400 workaround: when focusing a window, manually redraw
    -- other windows from the same app since HS may not fire unfocus events for them.
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
