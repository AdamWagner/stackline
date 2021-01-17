local unpack = table.unpack
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
  -- FROM: https://github.com/EvandroLG/pipe.lua/blob/master/pipe.lua
  local funcs = {...}
  print(hs.inspect(funcs))
  return function(...)
    local ret = {...}
    for i, f in ipairs(funcs) do
      ret = {f(table.unpack(ret))}
    end
    return table.unpack(ret)
  end
end  -- }}}

function M.sleep(s)  -- {{{
  local ntime = os.clock() + s/10
  repeat until os.clock() > ntime
end  -- }}}

function M.extend_mt(tbl, mt)
  local orig_mt = getmetatable(tbl)
  return setmetatable(tbl, table.merge(orig_mt, mt))
end



--[[
	Takes a function _fn_ and binds _arguments_ to the head of the _fn_ argument list.
	Returns a function which executes _fn_, passing the bound arguments supplied, followed by any
	dynamic arguments.
	@example
		local function damagePlayer( player, amount )
			player:Damage(amount)
		end
		local damageLocalPlayer = dash.bind(damagePlayer, game.Players.LocalPlayer)
		damageLocalPlayer(5)
]]
--: <A, A2, R>(((...A, ...A2 -> R), ...A) -> ...A2 -> R)
function M.bind(fn, ...)
  -- FROM: https://github.com/CodeKingdomsTeam/rodash/blob/master/src/Functions.lua	
	local args = {...}
	return function(...)
		return fn(unpack(args), ...)
	end
end


--[[
	Takes a chainable function _fn_ and binds _arguments_ to the tail of the _fn_ argument list.
	Returns a function which executes _fn_, passing a subject ahead of the bound arguments supplied.
	@example
		local function setHealthTo(player, health)
			player.Health = health
		end
		local restoreHealth = dash.bindTail(setHealthTo, 100)
		local Jimbo = {
			Health = 5
		}
		restoreHealth(Jimbo)
		Jimbo.Health --> 100
	@example
		local filterHurtPlayers = dash.bindTail(dash.filter, function(player)
			return player.Health < player.MaxHealth
		end)
		local getName = dash.bindTail(dash.map, function(player)
			return player.Name
		end)
		local filterHurtNames = dash.compose(filterHurtPlayers, getName)
		filterHurtNames(game.Players) --> {"Frodo", "Boromir"}	
	@see `dash.filter`
	@see `dash.compose`
	@usage Chainable rodash function feeds are mapped to `dash.fn`, such as `dash.fn.map(handler)`.
]]
--: <S>(Chainable<S>, ...) -> S -> S
function M.bindTail(fn, ...)
  -- FROM: https://github.com/CodeKingdomsTeam/rodash/blob/master/src/Functions.lua	
  local args = {...}
	return function(subject)
		return fn(subject, unpack(args))
	end
end

--[[
	Returns a function that when called, only calls _fn_ the first time the function is called.
	For subsequent calls, the initial return of _fn_ is returned, even if it is `nil`.
	@returns the function with method `:clear()` that resets the cached value.
	@trait Chainable
	@example
		local fry = dash.once(function(item)
			return "fried " .. item
		end)
		fry("sardine") --> "fried sardine"
		fry("squid") --> "fried sardine"
		fry:clear()
		fry("squid") --> "fried squid"
		fry("owl") --> "fried squid"
	@throws _passthrough_ - any error thrown when called will cause `nil` to cache and pass through the error.
	@usage Useful for when you want to lazily compute something expensive that doesn't change.
]]
--: <A, R>((...A -> R), R?) -> Clearable & (...A -> R)
function M.once(fn)
  -- FROM: https://github.com/CodeKingdomsTeam/rodash
	local called = false
	local result = nil
	local once = {
		clear = function()
			called = false
			result = nil
		end
	}
	setmetatable(
		once,
		{
			__call = function(_, ...)
				if called then
					return result
				else
					called = true
					result = fn(...)
					return result
				end
			end
		}
	)
	return once
end


return M


