local log   = hs.logger.new('query', 'info')
log.i('Loading module: query')

local function yabai(command, callback) -- {{{
    callback = callback or function(x) return x end
    command = '-m ' .. command

    local task = hs.task.new(
      stackline.config:get 'paths.yabai',
      u.task_cb(callback),     -- wrap callback in json decoder
      command:split(' ')
    ):start()
    if not task then
      log.e(
        "Error calling '" ..
        stackline.config:get('paths.yabai') ..
        " " .. command .. "'. " .. "Please check logs above this message to find out what went wrong."
      )
    end
  end                                       -- }}}

local function stackIdMapper(yabaiWindow) -- {{{
    -- u.p(yabaiWindow)
    local res = {}
    if type(yabaiWindow)~='table' then u.p(yabaiWindow) end
    for _,win in pairs(yabaiWindow or {}) do
        if win['stack-index']~=0 then
            res[tostring(win.id)] = win['stack-index']
        end
    end
    return res
end  -- }}}

local function getStackedWinIds(byStack) -- {{{
    local stackedWinIds = {}
    for _, group in pairs(byStack) do
        for _, win in pairs(group) do
            stackedWinIds[win.id] = true
        end
    end
    return stackedWinIds
end  -- }}}

local function groupWindows(ws) -- {{{
    -- Given windows from hs.window.filter:
    --    1. Create stackline window objects
    --    2. Group wins by `stackId` prop (aka top-left frame coords)
    --    3. If at least one such group, also group wins by app (to workaround hs bug unfocus event bug)
    local byStack
    local byApp

    local windows = u.map(ws, function(w)
        return stackline.window:new(w)
    end)

    -- See 'stackId' def @ /window.lua:233
    local groupKey = c.features.fzyFrameDetect.enabled
        and 'stackIdFzy'
        or 'stackId'

    byStack = u.filter(
        u.groupBy(windows, groupKey),
        u.greaterThan(1))  -- stacks have >1 window, so ignore 'groups' of 1

    if u.length(byStack) > 0 then
        local stackedWinIds = getStackedWinIds(byStack)
        local stackedWins = u.filter(windows, function(w)
            return stackedWinIds[w.id] --true if win id is in stackedWinIds
        end)

        byApp = u.groupBy(stackedWins, 'app') -- app names are keys in group
    end

    return byStack, byApp
end -- }}}

local function removeGroupedWin(win, byStack) -- {{{
    -- remove given window if it's present in byStack windows
    return u.map(byStack, function(stack)
        return u.filter(stack, function(w)
            return w.id ~= win.id
        end)
    end)
end -- }}}

local function mergeWinStackIdxs(byStack, winStackIdxs) -- {{{
    -- merge windowID <> stack-index mapping queried from yabai into window objs

    local function assignStackIndex(win)
        local stackIdx = winStackIdxs[tostring(win.id)]
        if stackIdx == 0 then
            -- Remove windows with stackIdx == 0. Such windows overlap exactly with
            -- other (potentially stacked) windows, and so are grouped with them,
            -- but they are NOT stacked according to yabai.
            -- Windows that belong to a *real* stack have stackIdx > 0.
            byStack = removeGroupedWin(win, byStack)
        end

        -- set the stack idx
        win.stackIdx = stackIdx
    end

    u.each(byStack, function(stack)
        u.each(stack, assignStackIndex)
    end)

    return byStack

end -- }}}

local function shouldRestack(new) -- {{{
    -- Analyze byStack to determine if a stack refresh is needed
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change position
    --    • change num windows (win added / removed)

    local curr = stackline.manager:getSummary()
    new = stackline.manager:getSummary(u.values(new))

    if curr.numStacks ~= new.numStacks then
        log.i('Should refresh -> Num stacks changed')
        return true
    end

    if not u.equal(curr.topLeft, new.topLeft) then
        u.p(curr.topLeft)
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
    opts = opts or {}
    local byStack, byApp = groupWindows(stackline.wf:getWindows()) -- set byStack & self.appWindows

    -- Check if space has stacks...
    local spaceHasStacks  = stackline.manager:getSummary().numStacks > 0

    local shouldRefresh = spaceHasStacks and shouldRestack(byStack) -- Don't even check on a space that doesn't have any stacks

    if shouldRefresh or opts.forceRedraw then
        log.i('Refreshing stackline')
        -- TODO: if there's only 1 space, use 'query --windows --space' to reduce chance that parsing fails
        local yabai_cmd = 'query --windows'

        yabai(yabai_cmd, function(yabaiRes)
            local winStackIdxs = stackIdMapper(yabaiRes)
            stackline.manager:ingest( -- hand over to stackmanager
                mergeWinStackIdxs(byStack, winStackIdxs), -- Add the stack indexes from yabai to byStack
                byApp,
                spaceHasStacks
            )
        end)
    end
end -- }}}

return {
    run = run,
    setLogLevel = log.setLogLevel
}
