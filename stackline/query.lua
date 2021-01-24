local u = require 'stackline.lib.utils'
local async = require 'stackline.lib.async'
local log = hs.logger.new('query', 'info')
log.setLogLevel('debug')

local function getWinStackIdxs() -- {{{
  local p = stackline.config:get('paths')
  local r = async()

  hs.task.new(p.getStackIdxs, function(_code, out, _err)
    log.d('getWinStackIdxs() completed', out)
    return r.resolve(out)
  end, {p.yabai, p.jq}):start()

  return r:wait()
end -- }}}

-- groupWindows( ... ) -- {{{
  --[[ TEST {{{
    hs.console.clearConsole()
    ws = stackline.wf:getWindows()
    windows = u.map(ws, function(w)
      return stackline.window:new(w)
    end)
    = require 'stackline.stackline.query'
    byStack = groupByStack(windows)
    byApp = groupByApp(byStack)
    groupByStackRaw = u.pipe(
      table.groupBy,
      u._filter(u._gt(1))
    )
   }}} ]]
local groupByStack = u.pipe(
  table.groupBy,          -- groups by identity if grouping fn is nil
  u._filter(u._gt(1))     -- stacks have > 1 window, so ignore 'groups' of 1
)
-- TODO: can remove groupByApp when github.com/Hammerspoon/hammerspoon/issues/2400 is closed
local groupByApp = u.pipe(
  table.join,             -- ungroup stacked wins
  table._groupBy('app')   -- app names are keys in group
)
local function groupWindows(ws) --[[
  Given stackline window objects:
     1. Group wins into stacks by equality; Windows are equal if the diff
        between each coord of frame is <= fuzzFactor
     2. Then, group stacked wins by app (workaround for hs bug unfocus event bug)
  ]]
  local byStack = groupByStack(ws)
  local byApp = groupByApp(byStack)

  return byStack, byApp
end -- }}}

local function mergeWinStackIdxs(groups, winStackIdxs) -- {{{
  -- Merge windowID <> stack-index mapping queried from yabai into window objs
  return u.map(groups, function(group)
    return u.map(group, function(w)
      w.stackIdx = winStackIdxs[tostring(w.id)]
      return w
    end)
  end)
end -- }}}

local function shouldRestack(new) --[[ {{{
  Analyze self.stacks to determine if a stack refresh is needed
    • change num stacks (+/-)
    • changes to existing stack
       • change position
       • change num windows (win added / removed)
  ]]
  local curr = stackline.manager:getSummary()
  new = stackline.manager:getSummary(new)

  if curr.numStacks ~= new.numStacks then
    log.d('num stacks changed')
    return true

  elseif not u.equal(curr.topLeft, new.topLeft) then
    log.d('position changed')
    return true

  elseif not u.equal(curr.numWindows, new.numWindows) then
    log.d('num windows changed')
    return true
  end

  log.d('Should not restack.')
end -- }}}

local function handoff(byStack, byApp, _shouldRestack) -- {{{
  async(function()
    -- Safely attempt to get and decode json stack index data from yabai
    -- Each stacked window's 'index' determines the vertical placement of its indictor
    local ok, winStackIndexes = pcall(hs.json.decode, getWinStackIdxs())

    -- Exit early if there's a problem decoding stack indexes
    if not ok then
      log.e('Failed to get stack index data from yabai')
      return false
    end

    -- Update each draft stack with an 'index' from yabai
    -- NOTE: stackIndexes are retrieved & merged into byStack here due to the
    -- high cost of the operation.
    byStack = mergeWinStackIdxs(byStack, winStackIndexes)

    -- Hand draft stack data over to the stackmanager
    stackline.manager:ingest(byStack, byApp, _shouldRestack)
  end)
end -- }}}

local function run(ws) --[[
  Given a new set of stackline window objects, group into draft stacks to
  compare with the current state. If a restack is needed, merge in each window's
  stack index from yabai and push the draft into stackmanager to trigger a restack.
  ]]
  local byStack, byApp = groupWindows(ws)
  local _shouldRestack = shouldRestack(byStack)

  if _shouldRestack then
    handoff(byStack, byApp, _shouldRestack)
  end
end

return {
  run = run,
  log = log,
  -- fns below temporarily exported for easier debugging
  _groupByStack = groupByStack,
  _groupByApp = groupByApp,
  _groupWindows = groupWindows,
  _getWinStackIdxs = getWinStackIdxs,
  _handoff = handoff,
  _shouldRestack = shouldRestack,
}
