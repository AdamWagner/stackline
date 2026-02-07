--[[
Window model: wraps an hs.window, computes stack grouping IDs, tracks focus
state, and coordinates indicator updates. Delegates all rendering to the
Indicator module (stackline/indicator.lua).
]]
local log       = hs.logger.new('window', 'info')
local Indicator = require 'stackline.indicator'
log.i('Loading module: window')

local Window = {}

function Window:new(hsWin) -- {{{
    local stackIdResult = self:makeStackId(hsWin)
    local ws = {
        title      = hsWin:title(),              -- window title
        app        = hsWin:application():name(), -- app name (string)
        id         = hsWin:id(),                 -- window id (string) NOTE: HS win.id == yabai win.id
        frame      = hsWin:frame(),              -- x,y,w,h of window (table)
        stackId    = stackIdResult.stackId,      -- "{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
        topLeft    = stackIdResult.topLeft,       -- "{x}|{y}" e.g., "35|63" (string)
        stackIdFzy = stackIdResult.fzyFrame,     -- fuzzy "{x}|{y}|{w}|{h}" rounded by fuzzFactor (string)
        _win       = hsWin,                      -- hs.window object (table)
        screen     = hsWin:screen():id(),
        indicator  = nil,                        -- Indicator instance (created in buildIndicator)
    }
    setmetatable(ws, self)
    self.__index = self

    log.i( ('Window:new(%s)'):format(ws.id) )

    return ws
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
