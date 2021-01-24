local u = require 'stackline.lib.utils'
local async = require 'stackline.lib.async'
local c = stackline.config:get()
local log = hs.logger.new('query', 'info')

local Query = {}
Query.log = log

function Query.getWinStackIdxs() -- {{{
  local r = async()
  log.d('getWinStackIdxs() started')
  hs.task.new(c.paths.getStackIdxs, function(_code, out, _err)
    log.d('getWinStackIdxs() completed', out)
    return r.resolve(out)
  end, {c.paths.yabai, c.paths.jq}):start()

  return r:wait()
end -- }}}

-- Query.groupByStack( ... ) -- {{{
  --[[ TEST {{{
    hs.console.clearConsole()

    ws = stackline.wf:getWindows()

    windows = u.map(ws, function(w)
      return stackline.window:new(w)
    end)

    Query = require 'stackline.stackline.query'

    byStack = Query.groupByStack(windows)

    byApp = Query.groupByApp(byStack)

    groupByStackRaw = u.pipe(
      table.groupBy,
      u._filter(u._gt(1))
    )
   }}} ]]

Query.groupByStack = u.pipe(
  table.groupBy,       -- groups by identity if grouping fn is nil
  u._filter(u._gt(1))  -- stacks have > 1 window, so ignore 'groups' of 1
)

Query.groupByApp = u.pipe(
  -- TODO: Remove when https://github.com/Hammerspoon/hammerspoon/issues/2400 closed
  table.join,             -- ungroup stacked wins
  table._groupBy('app')   -- app names are keys in group
)

function Query.groupWindows(ws)
  --[[ Given stackline window objects:
       1. Group wins by `stackId` prop (aka top-left frame coords)
       2. If at least one such group, also group windows by app (to workaround hs bug unfocus event bug)
  ]]
  local byStack = Query.groupByStack(ws)
  local byApp = Query.groupByApp(byStack)

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

function Query.shouldRestack(new) -- {{{
  -- Analyze self.stacks to determine if a stack refresh is needed
  --  • change num stacks (+/-)
  --  • changes to existing stack
  --    • change position
  --    • change num windows (win added / removed)

  local curr = stackline.manager:getSummary()
  new = stackline.manager:getSummary(new)

  -- u.pheader('curr summary')
  -- u.p(curr)
  -- u.pheader('new summary')
  -- u.p(new)

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

  print('Should not redraw.')
end -- }}}

function Query.handoff(byStack, byApp, shouldRestack) -- {{{
  async(function()
    -- Safely attempt to decode json stack index data from yabai
    local ok, winStackIndexes = pcall(hs.json.decode, Query.getWinStackIdxs())

    -- Exit early if there's a problem decoding stack indexes
    if not ok then
      log.e('Failed to parse stack index json data retrieved from yabai')
      return false
    end

    -- Update each draft stack with an 'index' from yabai
    byStack = Query.mergeWinStackIdxs(byStack, winStackIndexes)

    -- Hand draft stack data over to the stackmanager
    stackline.manager:ingest(byStack, byApp, shouldRestack)
  end)
end -- }}}

function Query.run(ws, force)
  local byStack, byApp = Query.groupWindows(ws)
  local shouldRestack = Query.shouldRestack(byStack)
  log.d('shouldRestack?  -> ' .. tostring(shouldRestack))

  if shouldRestack or force then
    Query.handoff(byStack, byApp, shouldRestack)
  end
end

return Query
