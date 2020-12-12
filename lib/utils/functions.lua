local M = {}

function M.invoke(instance, name, ...)  -- {{{
      -- FIXME: This doesn't work, but it seems like it should
      --        attempt to index a nil value (local 'instance')
    return function(instance, ...)
        if instance[name] then
            instance[name](instance, ...)
        end
    end
end  -- }}}

function M.cb(fn)  -- {{{
    return function()
        return fn
    end
end  -- }}}

function M.flip(fn)  -- {{{
	return function (a, b, ...)		
		return fn(b, a, ...)
	end
end -- }}}

function M.partial(f, ...)  -- {{{
    local unpack = unpack or table.unpack
    local a = {...}
    local a_len = select("#", ...)
    return function(...)
        local tmp = {...}
        local tmp_len = select("#", ...)
          -- Merge arg lists
        for i = 1, tmp_len do
            a[a_len + i] = tmp[i]
        end
        return f(unpack(a, 1, a_len + tmp_len))
    end
end  -- }}}

function M.curry(func, params) -- {{{
  -- FROM: https://github.com/KelsonBall/LuaCurry/blob/master/curry.lua
  return (function (...)
    local args = params or {}
    if #args + #{...} == debug.getinfo(func).nparams then
      args = {table.unpack(args)}
      for _,v in ipairs({...}) do
        table.insert(args, v)
      end
      return func(table.unpack(args))
    else
      args = {table.unpack(args)}
      for _,v in ipairs({...}) do
        table.insert(args, v)
      end
      return M.curry(func, args)
    end
  end)
end  -- }}}

function M.pipe(...)  -- {{{
  local arg = {...}

  return function(...)
    local result = nil

    for _, fn in ipairs(arg) do
      result = fn(result == nil and ... or result)
    end

    return result
  end
end  -- }}}

function M.sleep(s)  -- {{{
  local ntime = os.clock() + s/10
  repeat until os.clock() > ntime
end  -- }}}

return M
