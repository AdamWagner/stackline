--[[ 
Slow-path pipeline: groups Hammerspoon windows by frame, queries yabai for
stack indices, and merges the two data sources. This is where the core data
problem is solved — HS provides grouping (which windows overlap), yabai provides
ordering (stack-index) and confirmation (stack-index > 0 means truly stacked).
Called by stackmanager:update(). Hands merged results to stackmanager:ingest().
shouldQuery() avoids unnecessary yabai subprocess calls via change detection.
]]
local log   = hs.logger.new('query', 'info')
log.i('Loading module: queryYabai')

local function yabai(command, callback) -- {{{
    -- Run a yabai CLI command asynchronously. Callback receives parsed JSON response.
    callback = callback or function(x) return x end
    command = '-m ' .. command -- prepend yabai message flag

    hs.task.new(
        stackline.config:get'paths.yabai',
        u.task_cb(callback),   -- wrap callback in json decoder
        command:split(' ')
    ):start()
end  -- }}}

local function stackIdMapper(yabaiWindow) -- {{{
    -- Build a {[winId_string] = stack_index} map from yabai's JSON response.
    -- Windows with stack-index == 0 are not stacked and are excluded.
    local res = {}
    if type(yabaiWindow)~='table' then u.p(yabaiWindow) end -- debug guard: log unexpected non-table response
    for _,win in pairs(yabaiWindow or {}) do
        if win['stack-index']~=0 then
            res[tostring(win.id)] = win['stack-index']
        end
    end
    return res
end  -- }}}

local function groupWindows(ws) -- {{{
    -- Given windows from hs.window.filter:
    --    1. Create stackline window objects
    --    2. Group wins by `stackId` prop (aka top-left frame coords)
    --    3. If at least one such group, also group wins by app (to workaround hs bug unfocus event bug)
    local windows = u.map(ws, function(w)
        return stackline.window:new(w)
    end)

    -- See Window:makeStackId() in window.lua
    local groupKey = stackline.config:get('features.fzyFrameDetect').enabled
        and 'stackIdFzy'
        or 'stackId'

    local byStack = u.filter(
        u.groupBy(windows, groupKey),
        u.greaterThan(1)  -- stacks have >1 window, so ignore 'groups' of 1
    )

    local byApp
    if u.length(byStack) > 0 then
        byApp = u.groupBy(u.flatValues(byStack), 'app')
    end

    return byStack, byApp
end -- }}}

local function mergeWinStackIdxs(byStack, winStackIdxs) -- {{{
    -- Assign yabai stack indices to frame-grouped windows, then prune any
    -- that yabai says aren't truly stacked (absent from map → stack-index was 0).
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

local function shouldQuery(new) -- {{{
    -- Analyze byStack to determine if a stack refresh is needed
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change position
    --    • change num windows (win added / removed)

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

local function run(opts) -- {{{
    -- Main slow-path entry point, called by stackmanager:update().
    -- Groups HS windows by frame, checks if anything changed, and if so
    -- queries yabai for stack indices and hands off to stackmanager:ingest().
    opts = opts or {}
    local byStack, byApp = groupWindows(stackline.wf:getWindows()) -- returns byStack, byApp

    if shouldQuery(byStack) or opts.forceQuery then
        log.i('Refreshing stackline')
        -- TODO: if there's only 1 space, use 'query --windows --space' to reduce chance that parsing fails
        local yabai_cmd = 'query --windows'

        yabai(yabai_cmd, function(yabaiRes)
            local winStackIdxs = stackIdMapper(yabaiRes)
            stackline.manager:ingest( -- hand over to stackmanager
                mergeWinStackIdxs(byStack, winStackIdxs), -- Add the stack indexes from yabai to byStack
                byApp
            )
        end)
    end
end -- }}}

return {
    run = run,
    setLogLevel = log.setLogLevel
}
