
local log = hs.logger.new('query')
log.setLogLevel(0)
log.i("Loading query")

local u = require 'stackline.lib.utils'
local c = stackline.config:get()


-- ———————————————————————————————————————————————————————————————————————————
-- Promise.lua
-- ———————————————————————————————————————————————————————————————————————————
-- Promise = require "stackline.lib.async"
-- async, await = require "stackline.lib.keywords" (
--     Promise.new,
--     function(promise, handler) promise:next(handler) end,
--     function(promise, handler) promise:catch(handler) end)


-- local fetchJson = function()
--   if not memoizedPromise then
--     memoizedPromise = Promise.new()

--     hs.timer.doAfter(3, function(json)
--       memoizedPromise:resolve('my special value')
--     end)
--   end

--   return memoizedPromise
-- end

-- fetchJson():next(function(res)
--   print(res)
-- end)


-- ———————————————————————————————————————————————————————————————————————————
-- Asynclua
-- ———————————————————————————————————————————————————————————————————————————

u.pheader('above require')
require 'stackline.lib.async_b'

u.pheader('starting the fucking module yo!')
u.p(Awaitable)
u.p(async)
u.p(await)
u.p(getmetatable(Awaitable))

function Awaitable(fetchJson()
  return 'testing fetchjson'
    -- hs.timer.doAfter(3, function(json)
    --   return 'my special value'
    -- end)
end)

async(function() 
  local result = await(fetchJson())
  print('after result but before resolved')
  print(result)
end)()


--   return memoizedPromise
-- end








-- ———————————————————————————————————————————————————————————————————————————
-- Query
-- ———————————————————————————————————————————————————————————————————————————

local Query = {}

-- function executeAsync(cmd)
--     local taskIsDone = false
--     local output

--     hs.task.new(c.paths.getStackIdxs, function(_code, stdout, _stderr)
--         output = stdout
--         taskIsDone = true
--     end):start()

--     while not taskIsDone do
--         coroutine.applicationYield()
--     end
--     return output
-- end

-- local o

-- do_thing = a.sync(function (val)
--   u.p(o)
--   o = a.wait(executeAsync)
--   u.p(o)
--   return o + val
-- end)

function Query:getWinStackIdxs(onSuccess) -- {{{
  -- TODO: Consider coroutine (allows HS to do other work while waiting for yabai)
  --       Complete code example:
  --       https://github.com/koekeishiya/yabai/issues/502#issuecomment-633378939

  -- local res = hs.execute(c.paths.getStackIdxs)
  -- u.p(res)

  return hs.task.new(c.paths.getStackIdxs, function(_code, stdout, _stderr)
    -- call out to yabai to get stack-indexes
    local ok, json = pcall(hs.json.decode, stdout)
    if ok then
      return onSuccess(json)
      -- else -- try again
      -- hs.timer.doAfter(1, function() self:getWinStackIdxs(onSuccess) end)
    end
  end):waitUntilExit():start()
end -- }}}

function getStackedWinIds(byStack) -- {{{
  stackedWinIds = {}
  for _, group in pairs(byStack) do
    for _, win in pairs(group) do
      stackedWinIds[win.id] = true
    end
  end
  return stackedWinIds
end -- }}}

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
  local groupKey = c.features.fzyFrameDetect.enabled and 'stackIdFzy' or
                       'stackId'

  byStack = u.filter(u.groupBy(windows, groupKey), u.greaterThan(1)) -- stacks have >1 window, so ignore 'groups' of 1

  if u.length(byStack) > 0 then
    local stackedWinIds = getStackedWinIds(byStack)
    local stackedWins = u.filter(windows, function(w)
      return stackedWinIds[w.id] -- true if win id is in stackedWinIds
    end)

    byApp = u.groupBy(stackedWins, 'app') -- app names are keys in group
  end

  self.stacks = byStack
  self.appWindows = byApp
  return byStack, byApp
end -- }}}

function removeUnstackedWindowsFromGroups(groups)
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
end

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
  -- Analyze self.stacks to determine if a stack refresh is needed
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

function whenStackIdxDone(byStack, yabaiRes)
  log.d(yabaiRes)
  local merged = mergeWinStackIdxs(byStack, yabaiRes)
  u.pheader('merged in "on done" func')
  u.p(merged)
  return removeUnstackedWindowsFromGroups(merged)
end

function Query:windowsCurrentSpace() -- {{{
  local byStack, byApp = self:groupWindows(stackline.wf:getWindows()) -- set self.stacks & self.appWindows

  local extantStacks = stackline.manager:get()
  local extantStackSummary = stackline.manager:getSummary()
  local extantStackExists = extantStackSummary.numStacks > 0
  local shouldRefresh = (extantStackExists and
                            shouldRestack(self.stacks, extantStacks)) or true

  if shouldRefresh then
    local onDone = u.partial(whenStackIdxDone, byStack)
    local merged = self:getWinStackIdxs(onDone) -- set self.winStackIdxs (async shell call to yabai)
    u.pheader('merged')
    u.p(merged)
    stackline.manager:ingest(merged, byApp, extantStackExists) -- hand over to the Stack module
  end
end -- }}}

return Query
