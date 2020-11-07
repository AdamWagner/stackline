--[[-----------------------------------------------------------------------------
Adapted from: https://github.com/iagrib/AsyncLua

Alternates that I expolored:
  https://github.com/ImagicTheCat/Luaseq/blob/master/src/Luaseq.lua

-- NOTE: tables with a __call metamethod will NOT work as callbacks in Hammerspoon
-- https://github.com/Hammerspoon/hammerspoon/issues/932

Example use --------------------------------------------------------------------

  local a = require 'stackline.lib.async'

   Make the call site async
  ===========================

  -- Wrapper method #1: directly wrap async func in a:new(…)
  function fetchJson()
    return a:new(function(resolve)
      hs.task.new(c.paths.getStackIdxs, resolve):start()
    end)
  end

  -- Wrapper method #2a: create promise with no-args to a:new(), then
  -- promise:resolve or promise.resolve
  function fetchAlt()
    local p = a:new()
    hs.task.new(c.paths.getStackIdxs, p.resolve):start()
    return p
  end

  -- Wrapper method #2b: create promise with no-args to a:new(), then
  -- Then call p.resolve in a custom callback function
  function fetchAlt()
    local p = a:new()
    hs.task.new(c.paths.getStackIdxs, function(_,b,c) 
	p.resolve(_, b,c)
    end):start()
    return p
  end

   Extract the async value
  ===========================

  -- Option #1: Call the function normally, then :get(cb)
  fetchAlt():get(function(_, b, c)
    print(b)
  end)

  -- Option #2: from within an a.sync(…) wrapper, call async fun in an a.wait() wrapper
  a.sync(function()
    print('REG-------------------')
    local _, b, c = a.wait(fetchJson())
    print(_,b,c)
  end)()



-----------------------------------------------------------------------------
]]
local unpack = table.unpack

local awaitable = {}
awaitable.__index = awaitable

function awaitable:get(cb)
  assert(type(cb) == "function", "Awaitable:get(fn) - argument must be a function")
  if self.val then
    cb(unpack(self.val))
  else
    self.callbacks[#self.callbacks + 1] = cb
  end
end

function awaitable:resolve(...)
  assert(not self.resolved, "Awaitable objects can only be resolved once")
  self.resolved = true
  self.val = {...}
  for i = 1, #self.callbacks do
    self.callbacks[i](...)
  end
end

function awaitable:new(fn)
  local t = type(fn) -- must be separate, can't be inlined inside assert
  assert(t == "nil" or t == "function", "Awaitable(fn) - argument must be a function or nil")

  local new = {}
  new.callbacks = {}

  -- Used when creating a promise with p = a:new().
  -- Can pasee p.resolve as the callback to third-party funcs.
  new.resolve = function(...)
    awaitable.resolve(new, ...)
  end

  -- just an alias
  new.res = new.resolve

  -- Used when wrapping asyncFn directly with a:new(function(res) asyncFn(x, res))
  -- Can pasee p.resolve as the callback to third-party funcs.
  if fn then
    fn(function(...)
      new.resolve(...)
    end)
  end

  return setmetatable(new, awaitable)
end

function awaitable.wait(av)
  if getmetatable(av) == awaitable then
    return coroutine.yield(av)
  else
    return av
  end
end

function awaitable.sync(fn)
  return function(...)
    local arg = {...}

    local thread = coroutine.create(function()
      return fn(table.unpack(arg))
    end)

    local aw = awaitable:new()

    local function handleThread(...)
      local returned = {coroutine.resume(thread, ...)}
      assert(table.remove(returned, 1), "Error in async function: " .. tostring(returned[1]))

      if coroutine.status(thread) == "dead" then
        aw:resolve(table.unpack(returned))
      else
        returned[1]:get(handleThread)
      end
    end

    handleThread()
    return aw
  end
end

return awaitable
