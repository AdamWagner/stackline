-- NOTES: Functionality from this file can be completely factored out into
-- stack.lua and stackline.lua. In fact, I've already done this once, but was
-- riding a bit too fast and found myself in a place where nothing worked, and I
-- didn't know why. So, this mess lives another day. Conceptually, it'll be
-- pretty easy to put this stuff where it belongs.
-- DONE: remove dependency on hs._asm.undocumented.spaces
-- Affects line at ./stackline/stackline.lua:48 using hs.window.filter.windowNotInCurrentSpace
-- local spaces = require 'hs._asm.undocumented.spaces'
local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'

-- stackline modules
local Window = require 'stackline.stackline.window'
local Query = {}

function Query:getWinStackIdxs() -- {{{
    -- call out to yabai to get stack-indexes
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, _stderr)
        self.winStackIdxs = hs.json.decode(stdout)
    end, {scriptPath}):start()
end -- }}}

function Query:makeStacksFromWindows(ws) -- {{{
    -- Given windows from hs.window.filter: 
    --    1. Create stackline window objects
    --    2. Group wins by `stackId` prop (aka top-left frame coords) 
    --    3. If at least one such group, also group wins by app (to workaround hs bug unfocus event bug)

    local byStack
    local byApp
    local windows = _.map(ws, function(w)
        return Window:new(w)
    end)

    -- See 'stackId' def @ /window.lua:233
    byStack = _.filter(_.groupBy(windows, 'stackId'), _.greaterThan(1)) -- stacks have >1 window, so ignore 'groups' of 1

    if _.length(byStack) > 0 then
        -- app names are keys in group
        local stackedWins = _.reduce(u.values(byStack), _.concat)
        byApp = _.groupBy(stackedWins, 'app')
    end

    self.appWindows = byApp
    self.stacks = byStack
end -- }}}

function Query:mergeWinStackIdxs() -- {{{
    -- merge windowID <> stack-index mapping queried from yabai into window objs

    function assignStackIndex(win)
        win.stackIdx = self.winStackIdxs[tostring(win.id)]
    end

    _.each(self.stacks, function(stack)
        _.each(stack, assignStackIndex)
    end)
end -- }}}

function shouldRestack(new) -- {{{
    -- Analyze self.stacks to determine if a stack refresh is needed
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change position
    --    • change num windows (win added / removed)

    local curr = sm:getSummary()
    new = sm:getSummary(u.values(new))

    if curr.numStacks ~= new.numStacks then
        print('num stacks changed')
        return true
    end

    if not _.equal(curr.topLeft, new.topLeft) then
        print('position changed')
        return true
    end

    if not _.equal(curr.numWindows, new.numWindows) then
        print('num windows changed')
        return true
    end
end -- }}}

function Query:windowsCurrentSpace() -- {{{
    self:makeStacksFromWindows(wfd:getWindows()) -- set self.stacks & self.appWindows

    local shouldRefresh
    local extantStacks = sm:get()
    local extantStackSummary = sm:getSummary()
    local extantStackExists = extantStackSummary.numStacks > 0

    if extantStackExists then
        shouldRefresh = shouldRestack(self.stacks, extantStacks)
        -- stacksMgr:dimOccluded() TODO: revisit in a future update. This is
        -- kind of an edge case — there are bigger fish to fry.
    else
        shouldRefresh = true
    end

    if shouldRefresh then
        self:getWinStackIdxs() -- set self.winStackIdxs (async shell call to yabai)

        function whenStackIdxDone()
            self:mergeWinStackIdxs() -- Add the stack indexes from yabai to the hs window data
            sm:ingest(self.stacks, self.appWindows, extantStackExists) -- hand over to the Stack module
        end

        local pollingInterval = 0.1
        hs.timer.waitUntil(function()
            return self.winStackIdxs ~= nil
        end, whenStackIdxDone, pollingInterval)
    end
end -- }}}

return Query
