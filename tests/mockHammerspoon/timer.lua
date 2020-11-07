local sleep = require 'stackline.lib.utils'.sleep

-- See
-- https://github.com/vocksel/Timer

local timer = {}

function timer.new(interval, fn)
end

function timer.doAfter(delay, fn)
  -- USAGE:
  -- hs.timer.doAfter(1, function() self:getWinStackIdxs() end)
  sleep(delay)
  fn()
end

timer.delayed = {
  -- source: /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/timer/init.lua
  new = function(delay, fn)
    local tmr = { delay = delay, fn = fn, }
    return {
      start = function(self)
        sleep(tmr.delay)
        tmr.fn()
        return self
      end,
      stop = function(self) end,
      nextTrigger = function() end,
      running = function(self) end,
      setDelay = function(self, dl) end,
    }
  end,
}

return timer



-- ———————————————————————————————————————————————————————————————————————————
-- Example full timer implementation
-- https://github.com/sniper00/lua_timer/blob/master/timer.lua
-- ———————————————————————————————————————————————————————————————————————————

--[[

local timers = {}

local tbinsert = table.insert
local tbremove = table.remove
local ipairs = ipairs
local xpcall = xpcall
local traceback = debug.traceback

local co_create = coroutine.create
local co_running = coroutine.running
local co_resume = coroutine.resume
local co_yield = coroutine.yield

---you can replace this with your clock function
local clock = os.clock

local function insert_timer(sec, fn)
    local expiretime = clock() + sec
    local pos = 1
    for i, v in ipairs(timers) do
        if v.expiretime > expiretime then
            break
        end
        pos = i+1
    end
    local context = { expiretime =expiretime, fn = fn}
    tbinsert(timers, pos, context)
    return context
end

local co_pool = setmetatable({}, {__mode = "kv"})

local function coresume(co, ...)
    local ok, err = co_resume(co, ...)
    if not ok then
        error(traceback(co, err))
    end
    return ok, err
end

local function routine(fn)
    local co = co_running()
    while true do
        fn()
        co_pool[#co_pool + 1] = co
        fn = co_yield()
    end
end

local M = {}

function M.async(fn)
    local co = tbremove(co_pool)
    if not co then
        co = co_create(routine)
    end
    local _, res = coresume(co, fn)
    if res then
        return res
    end
    return co
end

---@param seconds integer @duration in seconds，decimal part means millseconds
---@param fn function @ timeout callback
function M.timeout(seconds, fn)
    return insert_timer(seconds, fn)
end

---coroutine style
---@param seconds integer @duration in seconds，decimal part means millseconds
function M.sleep(seconds)
    local co = co_running()
    insert_timer(seconds, function()
        co_resume(co)
    end)
    return co_yield()
end

function M.remove(ctx)
    ctx.remove = true
end

function M.update()
    while #timers >0 do
        local timer = timers[1]
        if timer.expiretime <= clock() then
            tbremove(timers,1)
            if not timer.remove then
                local ok, err = xpcall(timer.fn, traceback)
                if not ok then
                    print("timer error:", err)
                end
            end
        else
            break
        end
    end
end

return M
]]
