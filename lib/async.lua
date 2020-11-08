-- adapted from: https://github.com/ImagicTheCat/Luaseq/blob/master/src/Luaseq.lua

--[[ USAGE {{{
function makeCall()
    local r = async()
    hs.task.new(c.paths.getStackIdxs, function(a,b,c) 
       r(a,b,c)    --  <- "r" can be called directly to resolve
                   -- except not when passed as a callback to hammerspoon fns:
                   -- https://github.com/Hammerspoon/hammerspoon/issues/932
    end):start()
    return r:wait()
end

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
-- }}} ]]

local async = {}

local function task_wait(self)
  -- wait for task to return
  -- return task return values
  if self.val then return table.unpack(self.val) end -- already done, return values

  local co = coroutine.running()
  if not co then error("async wait outside a coroutine") end
  table.insert(self, co)
  return coroutine.yield(co) -- wait for the task to return
end

local function task_return(self, ...)
  -- complete task (multiple calls will do nothing)
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
  },
  __call = task_return,
}

function async.async(f)
  -- no parameters: create a task → return task
  -- parameter: function
  if f then
    local co = coroutine.create(f)
    local ok, err = coroutine.resume(co)
    if not ok then return err end
  else
    local new = {}
    new.resolve = function(...) task_return(new, ...) end
    return setmetatable(new, meta_task)
  end
end

return async.async

