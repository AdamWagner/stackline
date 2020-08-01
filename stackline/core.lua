local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'

-- This file is trash: lowercase globals, copy/paste duplication in
-- update_stack_data_redraw() just to pass 'shouldClean':true :(

wsi = Stack:newStackManager()
wf = hs.window.filter.default

yabai_get_stacks = 'stackline/bin/yabai-get-stacks'

function update_stack_data()
    hs.task.new("/usr/local/bin/dash", wsi.ingest, {yabai_get_stacks}):start()
end

function update_stack_data_redraw()
    -- _.pheader('stack update redraw called')
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, _stderr)
        wsi.ingest(code, stdout, stderr, true)
    end, {yabai_get_stacks}):start()
end

local win_added = {
    hs.window.filter.windowCreated,
    hs.window.filter.windowUnhidden,
    hs.window.filter.windowUnminimized,
}

local win_removed = {
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowHidden,
    hs.window.filter.windowMinimized,
}

-- NOTE: windowMoved captures movement OR resize events
local win_changed = {
    hs.window.filter.windowMoved,
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnfocused,
    hs.window.filter.windowFullscreened,
    hs.window.filter.windowUnfullscreened,
}

-- TODO: convert to use wsi.update method
-- ./stack.lua:15
wf:subscribe(tut.mergeArrays(win_added, win_changed), update_stack_data)
wf:subscribe(win_removed, update_stack_data_redraw)

