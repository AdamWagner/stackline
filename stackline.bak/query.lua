local log = hs.logger.new('query')
log.setLogLevel(0)
log.i("Loading query")

local async = require 'stackline.lib.async'
local u = require 'stackline.lib.utils'

local c = stackline.config:get()

function getWinStackIdxs()  -- {{{
  r = async()
  hs.task.new(c.paths.getStackIdxs, r.resolve):start()
  return r:wait()
end  -- }}}

function getStackedWinIds(byStack) -- {{{
  stackedWinIds = {}
  for _, group in pairs(byStack) do
    for _, win in pairs(group) do
      stackedWinIds[win.id] = true
    end
  end
  return stackedWinIds
end -- }}}

function groupWindows(ws) -- {{{
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
  local groupKey = c.features.fzyFrameDetect.enabled and 'stackIdFzy' or 'stackId'

  byStack = u.filter(u.groupBy(windows, groupKey), u.greaterThan(1)) -- stacks have >1 window, so ignore 'groups' of 1

  if u.length(byStack) > 0 then
    local stackedWinIds = getStackedWinIds(byStack)
    local stackedWins = u.filter(windows, function(w)
      return stackedWinIds[w.id] -- true if win id is in stackedWinIds
    end)

    byApp = u.groupBy(stackedWins, 'app') -- app names are keys in group
  end

  return byStack, byApp
end -- }}}

function removeUnstackedWindowsFromGroups(groups)  -- {{{
    -- Remove windows with stackIdx == 0. Such windows overlap exactly with
    -- other (potentially stacked) windows, and so are grouped with them,
    -- but they are NOT stacked according to yabai. 
    -- Windows that belong to a *real* stack have stackIdx > 0.
  local result = u.map(groups, function(group)
    return u.filter(group, function(w)
      return w.stackIdx ~= 0
    end)
  end)
  return result
end  -- }}}

function mergeWinStackIdxs(groups, winStackIdxs) -- {{{
  -- merge windowID <> stack-index mapping queried from yabai into window objs
  return u.map(groups, function(group)
    return u.map(group, function(w)
      w.stackIdx = winStackIdxs[tostring(w.id)]
      return w
    end)
  end)

end -- }}}

function shouldRestack(new) -- {{{
  -- Analyze new vs. current to determine if a stack refresh is needed
  --  • change num stacks (+/-)
  --  • changes to existing stack
  --    • change position
  --    • change num windows (win added / removed)

  local curr = stackline.manager:getSummary()
  new = stackline.manager:getSummary(u.values(new))

  if curr.numStacks ~= new.numStacks then
    log.d('num stacks changed')
    return true
  end

  if not u.equal(curr.topLeft, new.topLeft) then
    log.d('position changed')
    return true
  end

  if not u.equal(curr.numWindows, new.numWindows) then
    log.d('num windows changed')
    return true
  end

  log.d('Should not redraw.')
end -- }}}

function query(ws) -- {{{
  local byStack, byApp = groupWindows(ws)

  local extantStacks = stackline.manager:get()
  local extantStackSummary = stackline.manager:getSummary()
  local extantStackExists = extantStackSummary.numStacks > 0
  local shouldRefresh = (extantStackExists and shouldRestack(byStack, extantStacks)) or true

  if shouldRefresh then
    local onDone = u.partial(whenStackIdxDone, byStack, byApp)

    async(function()
      local _, stackIndexes = getWinStackIdxs() -- async shell call to yabai

      local ok, winStackIndexes = pcall(hs.json.decode, stackIndexes)
      if ok then
          byStack = mergeWinStackIdxs(byStack, winStackIndexes)
          stackline.manager:ingest(byStack, byApp, extantStackExists) -- hand over to the Stack module
      end
    end)


  end
end -- }}}

return {
    query = query,
    groupWindows = groupWindows,
    getWinStackIdxs = getWinStackIdxs,
    removeUnstackedWindowsFromGroups = removeUnstackedWindowsFromGroups,
    shouldRestack = shouldRestack,
    mergeWinStackIdxs = mergeWinStackIdxs,
}
