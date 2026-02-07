--[[
Slow-path pipeline: groups Hammerspoon windows by frame, queries yabai for
stack indices, and merges the two data sources. This is where the core data
problem is solved — HS provides grouping (which windows overlap), yabai provides
ordering (stack-index) and confirmation (stack-index > 0 means truly stacked).
Called by stackmanager:update(). Hands merged results to stackmanager:reconcile()
(diff-based update). forceRebuild calls cleanup() first so reconcile sees no existing state.
extractWindowData() produces plain data tables; Window objects persist across cycles.
shouldQuery() avoids unnecessary yabai subprocess calls via change detection.
]]
local log   = hs.logger.new('query', 'info')
log.i('Loading module: queryYabai')

-- Run a yabai CLI command asynchronously. Callback receives parsed JSON response.
local function yabai(command, callback) -- {{{
    callback = callback or function(x) return x end
    command = '-m ' .. command -- prepend yabai message flag

    hs.task.new(
        stackline.config:get'paths.yabai',
        u.task_cb(callback),   -- wrap callback in json decoder
        command:split(' ')
    ):start()
end  -- }}}

-- Build a {[winId_string] = stack_index} map from yabai's JSON response.
-- Windows with stack-index == 0 are not stacked and are excluded.
local function stackIdMapper(yabaiWindow) -- {{{
    local res = {}
    if type(yabaiWindow)~='table' then u.p(yabaiWindow) end -- debug guard: log unexpected non-table response
    for _,win in pairs(yabaiWindow or {}) do
        if win['stack-index']~=0 then
            res[tostring(win.id)] = win['stack-index']
        end
    end
    return res
end  -- }}}

-- Extract data from an hs.window into a plain table for grouping and comparison.
-- Computes stackId/stackIdFzy for frame-based grouping.
-- Lightweight, disposable records (no metatable, no indicator).
local function extractWindowData(hsWin) -- {{{
    local frame = hsWin:frame():floor()
    local x, y, w, h = frame.x, frame.y, frame.w, frame.h
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    local roundToFuzzFactor = u.partial(u.roundToNearest, fuzzFactor)
    local ff = u.map({x, y, w, h}, roundToFuzzFactor)

    return {
        id         = hsWin:id(),
        title      = hsWin:title(),
        app        = hsWin:application():name(),
        frame      = hsWin:frame(),
        screen     = hsWin:screen():id(),
        _win       = hsWin,
        topLeft    = table.concat({x, y}, '|'),
        stackId    = table.concat({x, y, w, h}, '|'),
        stackIdFzy = table.concat(ff, '|'),
    }
end -- }}}

-- Given windows from hs.window.filter:
--    1. Extract plain data tables from hs.window objects
--    2. Group by stackId (frame coords), keeping only groups with >1 window
local function groupWindows(ws) -- {{{
    local windows = u.map(ws, function(w)
        return extractWindowData(w)
    end)

    local groupKey = stackline.config:get('features.fzyFrameDetect').enabled
        and 'stackIdFzy'
        or 'stackId'

    return u.filter(
        u.groupBy(windows, groupKey),
        u.greaterThan(1)  -- stacks have >1 window, so ignore 'groups' of 1
    )
end -- }}}

-- Assign yabai stack indices to frame-grouped windows, then prune any
-- that yabai says aren't truly stacked (absent from map → stack-index was 0).
local function mergeWinStackIdxs(byStack, winStackIdxs) -- {{{
    u.each(byStack, function(stack)
        u.each(stack, function(win)
            win.stackIdx = winStackIdxs[tostring(win.id)]
        end)
    end)

    return u.map(byStack, function(stack)
        return u.filter(stack, function(win)
            return win.stackIdx ~= nil
        end)
    end)
end -- }}}

-- Analyze byStack to determine if a stack refresh is needed:
--   • change num stacks (+/-)
--   • change position
--   • change num windows (win added / removed)
local function shouldQuery(new) -- {{{
    local curr = stackline.manager:getSummary()            -- snapshot current state
    new = stackline.manager:getSummary(u.values(new))      -- snapshot incoming state in same format

    if curr.numStacks ~= new.numStacks then
        log.i('Should refresh -> Num stacks changed')
        return true
    end

    if not u.equal(curr.topLeft, new.topLeft) then
        log.i('Should refresh -> Stack position changed', curr.topLeft, new.topLeft)
        return true
    end

    if not u.equal(curr.numWindows, new.numWindows) then
        log.i('Should refresh -> Windows changed')
        return true
    end

    log.i('Should not redraw.')
end -- }}}

-- Main slow-path entry point, called by stackmanager:update().
-- Groups HS windows by frame, checks if anything changed, and if so
-- queries yabai for stack indices and hands off to stackmanager:reconcile().
-- When forceRebuild is set, cleanup() runs first so reconcile sees no existing state.
local function run(opts) -- {{{
    opts = opts or {}
    local byStack = groupWindows(stackline.wf:getWindows())

    if shouldQuery(byStack) or opts.forceQuery then
        log.i('Refreshing stackline')
        -- TODO: if there's only 1 space, use 'query --windows --space' to reduce chance that parsing fails
        local yabai_cmd = 'query --windows'

        yabai(yabai_cmd, function(yabaiRes)
            local winStackIdxs = stackIdMapper(yabaiRes)
            local merged = mergeWinStackIdxs(byStack, winStackIdxs)
            if opts.forceRebuild then
                stackline.manager:cleanup()              -- delete everything first
            end
            stackline.manager:reconcile(merged)          -- diff-based update (after cleanup = full rebuild)
        end)
    end
end -- }}}

return {
    run = run,
    setLogLevel = log.setLogLevel
}
