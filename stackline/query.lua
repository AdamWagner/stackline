local log   = hs.logger.new('query', 'info')
log.i('Loading module: query')

local function yabai(command, callback) -- {{{
    callback = callback or u.identity
    command = '-m ' .. command
    hs.task.new(
        stackline.config:get'paths.yabai',
        u.task_cb(callback), -- wrap callback in json decoder
        command:split(' ')
    ):start()
end  -- }}}

local function groupWindows(ws) -- {{{
    local groupKey = stackline.config:get('features.fzyFrameDetect.enabled') -- See 'stackId' def @ /window.lua:233
        and 'stackIdFzy'
        or 'stackId'
    return u(ws)
        :map(stackline.window:call('new'))
        :groupBy(groupKey)
        :filter(u.greaterThan(1)) -- stacks have >1 window, so ignore 'groups' of 1
        :value() 
end -- }}}

local function mergeYabaiOntoGroups(yabaiRes, listOfWinGroups) --[[ {{{
    Merge ['stack-index'] from yabai into window in `listOfWinGroups`
    @param yabaiRes: flat output from `yabai -m query --windows`. List of tables representing window data.
    @param listOfWinGroups: list of lists of <stackline.window> objects occupying the same position on screen
    ]]
    return u(yabaiRes)
        :filter(function(v) return v['stack-index']~=0 end) -- Keep only stacked windows ['stack-index']~=0
        :map(function(v,k) return v.id, v['stack-index'] end) -- Map of winID:stackIdxs -> { [14671] = 1, [217] = 1, ...  }
        :mergeOnto(listOfWinGroups, 'id', 'stackIdx') -- Merge map of winID:stackIdxs onto `listOfWinGroups`
        :value()
end -- }}}

local function shouldRestack(new) --[[ {{{
    Analyze listOfWinGroups to determine if a stack refresh is needed {{{
     • change num stacks (+/-)
     • changes to existing stack
       • change position
       • change num windows (win added / removed)
    }}} ]]

    -- Get a summary report of current (old) state and build a second 
    -- summary using the brand new query results. Compare these to determine 
    -- if we need to do a 'full restack' (call out to `yabai`, destroy & redraw everything)
    local curr = stackline.manager:getSummary()
    new = stackline.manager:getSummary(u.values(new))

    if curr.numStacks ~= new.numStacks then
        log.i('Should refresh -> Num stacks changed')
        return true
    end

    if not u.equal(curr.topLeft, new.topLeft) then
        log.i('Should refresh -> Stack position changed', curr.topLeft, new.topLeft)
        return true
    end

    if curr.numWindows ~= new.numWindows then
        log.i('Should refresh -> Windows changed')
        return true
    end

    log.i('Should not redraw.')
end -- }}}

local function run(opts) --[[ {{{ 
    == TEST == {{{
    query = require 'stackline.query'
    ws = hs.window.filter()
    grouped = query.groupWindows(ws)
    }}} ]]
    log.i('calling run()')

    opts = opts or {}
    local sm = stackline.manager
    local listOfWinGroups = groupWindows(sm.wf:getWindows()) -- set listOfWinGroups & self.appWindows
    local spaceHasStacks  = sm:getSummary().numStacks > 0 -- Check if space has stacks...
    local shouldRefresh = spaceHasStacks and shouldRestack(listOfWinGroups) -- Don't even check on a space that doesn't have any stacks

    if shouldRefresh or opts.forceRedraw then
        log.i('Querying yabai for window stack indexes')

        yabai('query --windows', function(yabaiRes)
            local winGroups = mergeYabaiOntoGroups(yabaiRes, listOfWinGroups)
            sm:ingest(winGroups, spaceHasStacks) -- hand over to stackmanager
        end)

    end
end -- }}}

return {
    run = run,
    setLogLevel = log.setLogLevel,
    groupWindows = groupWindows,
}
