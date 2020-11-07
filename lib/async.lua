--[[
adapted from: https://github.com/ImagicTheCat/Luaseq/blob/master/src/Luaseq.lua

┌───────┐
│ USAGE │
└───────┘
-- function makeCall()
--     local r = async()
--     hs.task.new(c.paths.getStackIdxs, function(a,b,c) 
--        r(a,b,c)    --  <- "r" can be called directly to resolve
--                    -- except not when passed as a callback to hammerspoon fns:
--                    -- https://github.com/Hammerspoon/hammerspoon/issues/932
--     end):start()
--     return r:wait()
-- end

function makeAnother()
    r = async()
    -- r.resolve is an alias for calling "r()" directly, and can be passed as callback
    hs.task.new(c.paths.getStackIdxs, r.resolve):start()
    return r:wait()
end

async(function()
    local a,b,c = makeCall()
    print(a,b,c)

    local a,b,c = makeAnother()
    print(a,b,c)
end)
]]

local async = {}

-- TASK 
-- wait for task to return
-- return task return values
local function task_wait(self)
  if self.val then return table.unpack(self.val) end -- already done, return values

  local co = coroutine.running()
  if not co then error("async wait outside a coroutine") end
  table.insert(self, co)
  return coroutine.yield(co) -- wait for the task to return
end

-- complete task ---------------------------------------------------------------
-- (multiple calls will do nothing)
-- ...: return values
local function task_return(self, ...)
  if not self.val then
    self.val = {...}
    for _, co in ipairs(self) do
      local ok, err = coroutine.resume(co, ...)
      if not ok then io.stderr:write(debug.traceback(co, "async: "..err).."\n") end
    end
  end
end

local meta_task = {
  __index = {
    wait = task_wait,
    resolve = task_return,

    -- Adapted from: https://github.com/iagrib/AsyncLua
    -- DOES NOT WORK as of 2020-10-17
    -- get = function(self, cb)
    --   assert(type(cb) == "function", "Awaitable:get(fn) - argument must be a function")
    --   if self.val then
    --     cb(unpack(self.val))
    --   end
    -- end

  },
  __call = task_return,
}

-- async ----------------------------------------------------------------------
-- no parameters: create a task
--- return task
-- parameters: execute function as coroutine (shortcut)
--- f: function
function async.async(f)
  if f then
    local co = coroutine.create(f)
    local ok, err = coroutine.resume(co)
    -- This ↓ breaks luassert!
    err = type(err)=='table' and table.concat(err, '\n') or err
    if not ok then io.stderr:write(debug.traceback(co, "async: "..err).."\n") end
    -- if not ok then return err end
  else
    local new = {}
    -- wrap in fn & pass new (self) as 1st param,
    -- so that r.resolve can be passed as a callback to third-party async fns
    -- E.g.,
    --    function makeAnother()
    --        r = async()
    --        hs.task.new(c.paths.getStackIdxs, r.resolve):start()
    --        return r:wait()
    --    end
    new.resolve = function(...) task_return(new, ...) end
    return setmetatable(new, meta_task)
  end
end

return async.async

