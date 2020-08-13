-- NOTES: Functionality from this file can be completely factored out into
-- stack.lua and stackline.lua. In fact, I've already done this once, but was
-- riding a bit too fast and found myself in a place where nothing worked, and I
-- didn't know why. So, this mess lives another day. Conceptually, it'll be
-- pretty easy to put this stuff where it belongs.
--
-- DONE: remove dependency on hs._asm.undocumented.spaces
-- Affects line at ./stackline/stackline.lua:48 using hs.window.filter.windowNotInCurrentSpace
-- local spaces = require 'hs._asm.undocumented.spaces'
local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

-- stackline modules
local Window = require 'stackline.stackline.window'

local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'

local Query = {}

function Query:getWinStackIdxs() -- {{{
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, _stderr)
        self.winStackIdxs = hs.json.decode(stdout)
    end, {scriptPath}):start()
end -- }}}

function Query:makeStacksFromWindows(ws) -- {{{
    -- _.p(ws)
    local windows = _.map(ws, function(w)
        return Window:new(w)
    end)

    -- NOTE: 'stackID' groups by full frame, so windows with min-size > stack
    -- width will not be stacked properly. See above ↑
    local groupedWins = _.groupBy(windows, 'stackId')

    local byStack = _.filter(groupedWins, _.greaterThan(1)) -- stacks have >1 window, so ignore 'groups' of 1
    local byApp

    if _.length(byStack) > 0 then -- if byStack == {}, there are no more stacks on space, so just cleanup
        byApp = _.groupBy(_.reduce(u.values(byStack), _.concat), 'app') -- group stacked windows by app (app name is key)
    end

    -- stacks contain more than one window,
    -- so ignore groups with only 1 window
    self.appWindows = byApp
    self.stacks = byStack
end -- }}}

function Query:mergeWinStackIdxs() -- {{{
    hs.fnutils.each(self.stacks, function(stack)
        hs.fnutils.each(stack, function(win)
            win.stackIdx = self.winStackIdxs[tostring(win.id)]
        end)
    end)
end -- }}}

function shouldRestack(new) -- {{{
    -- Analyze self.stacks to determine if a stack refresh is needed
    --  • change space
    --  • change num stacks (+/-)
    --  • changes to existing stack
    --    • change num windows (covers win added / removed)
    --    • change position

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
        -- stacksMgr:dimOccluded() TODO: revisit in a future update. This is kind of an edge case — there are bigger fish to fry.
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
