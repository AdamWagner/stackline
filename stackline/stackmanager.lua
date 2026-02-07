--[[ 
Manages the collection of Stack objects for the current space.
Slow path: receives grouped+indexed windows from queryYabai.lua via ingest(),
creates Stack objects, wires up HS #2400 workaround data, and triggers canvas rebuild.
Fast path: findWindow() does a linear scan to locate a window by ID for in-place redraws.
]]
local log   = hs.logger.new('stackmanager', 'info')

local Stackmanager = {}

Stackmanager.query = require 'stackline.queryYabai'

function Stackmanager:init() -- {{{
    self.stacks = {}
    self.screenCanvases = {} -- {screenId → hs.canvas} — one shared canvas per screen
    self.showIcons = stackline.config:get('appearance.showIcons')
    self.__index = self
    return self
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
        u.each(stack.windows, function(win)
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
        table.insert(self.stacks, stack)
    end
    self:rebuildAllIndicators()
end -- }}}

function Stackmanager:get() -- {{{
    return self.stacks
end -- }}}

function Stackmanager:eachStack(fn) -- {{{
    for _stackId, stack in pairs(self.stacks) do
        fn(stack)
    end
end -- }}}

function Stackmanager:cleanup() -- {{{
    -- Clear all elements from shared canvases (canvases themselves persist)
    for _screenId, canvas in pairs(self.screenCanvases) do
        canvas:replaceElements()
    end
    self.stacks = {}
end -- }}}

function Stackmanager:getSummary(external) -- {{{
    -- Summarizes all stacks on the current space, making it easy to determine
    -- what needs to be updated (if anything).
    
    -- Normalize: external is already an array of window arrays; self.stacks
    -- contains Stack objects, so unwrap .windows to get the same shape.
    local stacks = external or u.map(self.stacks, function(s) return s.windows end)
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
    self:eachStack(function(stack)
        stack:rebuildAllIndicators()
    end)
end -- }}}

function Stackmanager:findWindow(wid) -- {{{
    -- NOTE: A window must be *in* a stack to be found with this method!
    for _stackId, stack in pairs(self.stacks) do
        for _idx, win in pairs(stack.windows) do
            if win.id == wid then
                return win
            end
        end
    end
end -- }}}

function Stackmanager:findStackByWindow(win) -- {{{
    -- NOTE: may not need when Hammerspoon #2400 is closed
    -- NOTE 2: Currently unused, since reference to "otherAppWindows" is sstored
    -- directly on each window. Likely to be useful, tho, so keeping it around.
    for _stackId, stack in pairs(self.stacks) do
        if stack.id == win.stackId then
            return stack
        end
    end
end -- }}}

function Stackmanager:getShowIconsState() -- {{{
    return self.showIcons
end -- }}}

function Stackmanager:getClickedWindow(point) -- {{{
    -- given the coordinates of a mouse click, return the first window whose
    -- indicator element encompasses the point, or nil if none.    
    for _stackId, stack in pairs(self.stacks) do
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
