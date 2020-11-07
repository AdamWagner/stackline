-- Adapted from: https://github.com/iagrib/AsyncLua
local unpack = table.unpack

local awaitable = {
	__index = {
		get = function(self, cb)
				assert(type(cb) == "function", "Awaitable:get(fn) - argument must be a function")

				if self.val then cb(unpack(self.val))
				else self.callbacks[#self.callbacks + 1] = cb end
		end,

		resolve = function(self, ...)
			assert(not self.resolved, "Awaitable objects can only be resolved once")

			self.resolved = true
			self.val = {...}
			for i = 1, #self.callbacks do
				self.callbacks[i](...)
			end
		end,
	}
}

-- function awaitable:resolve(...)
-- 	assert(not self.resolved, "Awaitable objects can only be resolved once")

-- 	self.resolved = true
-- 	p
-- 	self.val = {...}
-- 	for i = 1, #self.callbacks do
-- 		self.callbacks[i](...)
-- 	end
-- end

function awaitable:new(fn)
  local t = type(fn)
  assert(t == "nil" or t == "function", "Awaitable(fn) - argument must be a function or nil")

  local new = setmetatable({}, { callbacks = {}, }, awaitable)

  if fn then fn(function(...) new:resolve(new, ...) end) end
  return new
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
      assert(table.remove(returned, 1),
          "Error in async function: " .. tostring(returned[1]))
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
