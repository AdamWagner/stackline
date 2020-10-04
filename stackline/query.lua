local u = require 'stackline.lib.utils'
local c = stackline.config:get()

local Query = {}

function Query:getWinStackIdxs(onSuccess) -- {{{
    -- TODO: Consider coroutine (allows HS to do other work while waiting for yabai)
    --       https://github.com/koekeishiya/yabai/issues/502#issuecomment-633378939
    hs.task.new("/bin/sh", function(_code, stdout, _stderr)
        -- call out to yabai to get stack-indexes
        local ok, json = pcall(hs.json.decode, stdout)
        if ok then
            onSuccess(json)
        else -- try again
            hs.timer.doAfter(1, function() self:getWinStackIdxs() end)
        end
    end, {c.paths.getStackIdxs}):start()
end -- }}}

function getStackedWinIds(byStack)  -- {{{
    stackedWinIds = {}
    for _, group in pairs(byStack) do
        for _, win in pairs(group) do
            stackedWinIds[win.id] = true
        end
    end
    return stackedWinIds
end  -- }}}

function Query:groupWindows(ws) -- {{{
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

    self.stacks = byStack
    self.appWindows = byApp
end -- }}}

function Query:removeGroupedWin(win) -- {{{
    -- remove given window if it's present in self.stacks windows
    self.stacks = u.map(self.stacks, function(stack)
        return u.filter(stack, function(w)
            return w.id ~= win.id
        end)
    end)
end -- }}}

function Query:mergeWinStackIdxs() -- {{{
    -- merge windowID <> stack-index mapping queried from yabai into window objs

    function assignStackIndex(win)
        local stackIdx = self.winStackIdxs[tostring(win.id)]

        if stackIdx == 0 then
            -- Remove windows with stackIdx == 0. Such windows overlap exactly with
            -- other (potentially stacked) windows, and so are grouped with them,
            -- but they are NOT stacked according to yabai. 
            -- Windows that belong to a *real* stack have stackIdx > 0.
            self:removeGroupedWin(win)
        end

        -- set the stack idx 
        win.stackIdx = stackIdx
    end

    u.each(self.stacks, function(stack)
        u.each(stack, assignStackIndex)
    end)

end -- }}}

function shouldRestack(new) -- {{{
    -- Analyze self.stacks to determine if a stack refresh is needed
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change position
    --    • change num windows (win added / removed)

    local curr = stackline.manager:getSummary()
    new = stackline.manager:getSummary(u.values(new))

    if curr.numStacks ~= new.numStacks then
        print('num stacks changed')
        return true
    end

    if not u.equal(curr.topLeft, new.topLeft) then
        print('position changed')
        return true
    end

    if not u.equal(curr.numWindows, new.numWindows) then
        print('num windows changed')
        return true
    end

    print('Should not redraw.')
end -- }}}

function Query:windowsCurrentSpace() -- {{{
    self:groupWindows(stackline.wf:getWindows()) -- set self.stacks & self.appWindows

    local extantStacks       = stackline.manager:get()
    local extantStackSummary = stackline.manager:getSummary()
    local extantStackExists  = extantStackSummary.numStacks > 0
    local shouldRefresh      = (extantStackExists and shouldRestack(self.stacks, extantStacks)) or true

    if shouldRefresh then
        function whenStackIdxDone(yabaiRes)
            self.winStackIdxs = yabaiRes
            self:mergeWinStackIdxs() -- Add the stack indexes from yabai to the hs window data
            stackline.manager:ingest(self.stacks, self.appWindows, extantStackExists) -- hand over to the Stack module
        end
        self:getWinStackIdxs(whenStackIdxDone) -- set self.winStackIdxs (async shell call to yabai)
    end
end -- }}}

return Query
