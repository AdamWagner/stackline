local _ = require 'stackline.utils.utils'
local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'

-- This file is trash: lowercase globals, copy/paste duplication in
-- update_stack_data_redraw() just to pass 'shouldClean':true :(

wsi = Stack:newStackManager()
wf = hs.window.filter.default

local win_added = {
    hs.window.filter.windowCreated,
    hs.window.filter.windowUnhidden,
    hs.window.filter.windowUnminimized,
}

local win_removed = {
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowHidden,
    hs.window.filter.windowMinimized,
    hs.window.filter.windowMoved,
}

-- NOTE: windowMoved captures movement OR resize events
local win_changed = {
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnfocused,
    hs.window.filter.windowFullscreened,
    hs.window.filter.windowUnfullscreened,
}

-- TODO: convert to use wsi.update method
-- ./stack.lua:15
local added_changed = tut.mergeArrays(win_added, win_changed)

wf:subscribe(added_changed, (function(_win, _app, event)
    _.pheader(event)
    wsi:update()
end))

wf:subscribe(win_removed, (function(_win, _app, event)
    _.pheader(event)
    -- look(win)
    -- print(app)
    wsi:update(true)
end))

