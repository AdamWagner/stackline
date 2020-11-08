local u = require 'stackline.lib.utils'
local async = require 'stackline.lib.async'
local c = stackline.config:get()

local Query = {}

function Query.groupByStack(windows)  -- {{{
  local groupKey = c.features.fzyFrameDetect.enabled and 'stackIdFzy' or 'stackId' -- Group by raw stackId (frame dims) or *fzy* frame dims?
  return u.filter(u.groupBy(windows, groupKey), u.greaterThan(1))                  -- stacks have > 1 window, so ignore 'groups' of 1
end  -- }}}

function Query.groupByApp(byStack, windows)  -- {{{
    -- TODO: Remove when https://github.com/Hammerspoon/hammerspoon/issues/2400 closed
  if u.len(byStack) > 0 then
    local stackedWinIds = Query.getStackedWinIds(byStack)
    local stackedWins = u.filter(windows, function(w)
      return stackedWinIds[w.id]   -- true if win id is in stackedWinIds
    end)

    return u.groupBy(stackedWins, 'app')   -- app names are keys in group
  end
end -- }}}

function Query.getWinStackIdxs() -- {{{
  local r = async()
  hs.task.new(c.paths.getStackIdxs, r.resolve):start()
  return r:wait()
end -- }}}

function Query.getStackedWinIds(byStack) -- {{{
  local stackedWinIds = {}
  for _, group in pairs(byStack) do
    for _, win in pairs(group) do
      stackedWinIds[win.id] = true
    end
  end
  return stackedWinIds
end -- }}}

function Query.groupWindows(ws) -- {{{
--[[ Given windows from hs.window.filter:
       1. Create stackline window objects
       2. Group wins by `stackId` prop (aka top-left frame coords)
       3. If at least one such group, also group windows by app (to workaround hs bug unfocus event bug)
  ]]
  local windows = u.map(ws, function(w)
    return stackline.window:new(w)
  end)

  local byStack = Query.groupByStack(windows)
  local byApp = Query.groupByApp(byStack, windows)

  return byStack, byApp
end -- }}}

function Query.mergeWinStackIdxs(groups, winStackIdxs) -- {{{
  -- merge windowID <> stack-index mapping queried from yabai into window objs
  return u.map(groups, function(group)
    return u.map(group, function(w)
      w.stackIdx = winStackIdxs[tostring(w.id)]
      return w
    end)
  end)
end -- }}}

function Query.shouldRestack(groupedWindows) -- {{{
  -- Analyze new vs. current to determine if a stack refresh is needed
  --  • change num stacks (+/-)
  --  • changes to existing stack
  --    • change position
  --    • change num windows (win added / removed)
  local curr = stackline.manager:getSummary()
  local new = stackline.manager:getSummary(u.values(groupedWindows))

  if curr.numStacks ~= new.numStacks then
    return true
  elseif not u.equal(curr.topLeft, new.topLeft) then
    return true
  elseif not u.equal(curr.numWindows, new.numWindows) then
    return true
  end
end -- }}}

function Query.run(ws) -- {{{
  local byStack, byApp = Query.groupWindows(ws)

  local extantStackExists = stackline.manager:getSummary().numStacks > 0
  local shouldRefresh = (extantStackExists and Query.shouldRestack(byStack)) or true

  if shouldRefresh then
    async(function()
      local _, stackIndexes = Query.getWinStackIdxs() -- async shell call to yabai
      local ok, winStackIndexes = pcall(hs.json.decode, stackIndexes)
      if ok then
        byStack = Query.mergeWinStackIdxs(byStack, winStackIndexes)
        stackline.manager:ingest(byStack, byApp, extantStackExists) -- hand over to the Stack module
      end
    end)
  end
end -- }}}

return Query
