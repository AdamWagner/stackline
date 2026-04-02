local log   = hs.logger.new('query', 'info')
log.i('Loading module: query')

local warned = {}

local function notifyOnce(key, title, text) -- {{{
    if warned[key] then return end
    warned[key] = true
    hs.notify.new(nil, {
        title = title,
        informativeText = text,
        withdrawAfter = 10,
    }):send()
end -- }}}

local function pathMode(path) -- {{{
    return path and hs.fs.attributes(path, 'mode')
end -- }}}

local function resolveYabaiPath() -- {{{
    local configuredPath = stackline.config:get'paths.yabai'
    local candidates = {}

    if configuredPath then
        table.insert(candidates, configuredPath)
        if pathMode(configuredPath) == 'directory' then
            table.insert(candidates, configuredPath .. '/bin/yabai')
        end
    end

    u.each({
        '/opt/homebrew/bin/yabai',
        '/usr/local/bin/yabai',
        '/opt/homebrew/opt/yabai/bin/yabai',
        '/usr/local/opt/yabai/bin/yabai',
    }, function(path)
        table.insert(candidates, path)
    end)

    for _, path in ipairs(candidates) do
        if pathMode(path) == 'file' then
            if configuredPath and path ~= configuredPath then
                local msg = ('Configured path "%s" is not executable; using "%s" instead.'):format(
                    configuredPath,
                    path
                )
                log.w(msg)
                notifyOnce('resolvedYabaiPath', 'Stackline adjusted yabai path', msg)
            end
            return path
        end
    end

    local msg = configuredPath
        and ('Configured path "%s" is not an executable yabai binary.'):format(configuredPath)
        or 'No yabai path is configured and no default install location was found.'

    log.e(msg)
    notifyOnce('missingYabaiPath', 'Stackline cannot find yabai', msg)
end -- }}}

local function yabai(command, callback) -- {{{
    callback = callback or function(x) return x end
    command = '-m ' .. command

    local yabaiPath = resolveYabaiPath()
    if not yabaiPath then return end

    local task = hs.task.new(
        yabaiPath,
        u.task_cb(callback),   -- wrap callback in json decoder
        command:split(' ')
    )

    if not task or not task:start() then
        local msg = ('Unable to launch yabai using "%s".'):format(yabaiPath)
        log.e(msg)
        notifyOnce('launchYabaiFailed', 'Stackline could not run yabai', msg)
    end
end  -- }}}

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

local function groupStacklineWindows(windows) -- {{{
    local byApp
    -- See 'stackId' def @ /window.lua:233
    local groupKey = c.features.fzyFrameDetect.enabled
        and 'stackIdFzy'
        or 'stackId'

    local byStack = u.filter(
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

local function groupWindows(ws) -- {{{
    -- Given windows from hs.window.filter:
    --    1. Create stackline window objects
    --    2. Group wins by `stackId` prop (aka top-left frame coords)
    --    3. If at least one such group, also group wins by app (to workaround hs bug unfocus event bug)
    local windows = {}

    for _, hsWin in pairs(ws or {}) do
        table.insert(windows, stackline.window:new(hsWin))
    end

    return groupStacklineWindows(windows)
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
        if not stackIdx or stackIdx == 0 then
            -- Remove windows with stackIdx == 0. Such windows overlap exactly with
            -- other (potentially stacked) windows, and so are grouped with them,
            -- but they are NOT stacked according to yabai. Missing entries are
            -- also treated as unstacked, since yabai is the source of truth.
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

local function countStackWindows(byStack) -- {{{
    local count = 0
    for _, stack in pairs(byStack or {}) do
        count = count + #stack
    end
    return count
end -- }}}

local function activeSpaceLookup() -- {{{
    local lookup = {}
    local activeSpaces = hs.spaces.activeSpaces() or {}

    for _, spaceId in pairs(activeSpaces) do
        lookup[spaceId] = true
        lookup[tostring(spaceId)] = true
    end

    return lookup
end -- }}}

local function getActiveStackedYabaiWindows(yabaiWindows) -- {{{
    local activeSpaces = activeSpaceLookup()
    local restrictToActiveSpaces = next(activeSpaces) ~= nil

    return u.filter(yabaiWindows or {}, function(win)
        return type(win) == 'table'
            and (win['stack-index'] or 0) > 0
            and win['is-minimized'] == false
            and win['is-hidden'] == false
            and win['is-native-fullscreen'] == false
            and win['subrole'] == 'AXStandardWindow'
            and (
                not restrictToActiveSpaces
                or activeSpaces[win.space]
                or activeSpaces[tostring(win.space)]
            )
    end)
end -- }}}

local function groupWindowsFromYabai(yabaiWindows) -- {{{
    local windows = {}

    for _, yabaiWin in pairs(getActiveStackedYabaiWindows(yabaiWindows)) do
        local hsWin = hs.window.get(yabaiWin.id)
        if hsWin then
            local win = stackline.window:new(hsWin)
            win.stackIdx = yabaiWin['stack-index']
            table.insert(windows, win)
        else
            log.w(('Unable to resolve hs.window for yabai window %s'):format(yabaiWin.id))
        end
    end

    return groupStacklineWindows(windows)
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
            local activeStackedWins = getActiveStackedYabaiWindows(yabaiRes)
            local mergedStacks = mergeWinStackIdxs(byStack, winStackIdxs)
            local mergedAppWins = byApp

            if countStackWindows(mergedStacks) < #activeStackedWins then
                log.w('yabai reports stacked windows on an active space, but hs.window.filter did not expose all of them; falling back to yabai window IDs')
                notifyOnce(
                    'yabaiWindowFallback',
                    'Stackline is using a yabai fallback',
                    'Hammerspoon did not expose all stacked windows, so Stackline rebuilt the stack from yabai window IDs.'
                )
                mergedStacks, mergedAppWins = groupWindowsFromYabai(yabaiRes)
            end

            stackline.manager:ingest( -- hand over to stackmanager
                mergedStacks,   -- Add the stack indexes from yabai to byStack
                mergedAppWins,
                spaceHasStacks
            )
        end)
    end
end -- }}}

return {
    run = run,
    setLogLevel = log.setLogLevel
}
