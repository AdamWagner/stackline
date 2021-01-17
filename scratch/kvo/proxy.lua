-- FROM: https://github.com/matthewdean/proxy.lua
--[[
benefits of using local variables:
	- faster access
	- ensures that changes to the global environment will not affect this module
	- e.g. loadstring = nil
]]
local unpack = unpack
local type = type
local pairs = pairs
local setmetatable = setmetatable
local getmetatable = getmetatable
local pcall = pcall
local error = error
local select = select
local tostring = tostring
local rawset = rawset

local null = {}
--[[
echo used to strip stack information from error messages
local t = 5
t()
--> attempt to call local 't' (a number value)
echo(t)()
--> attempt to call a number value
credit to mniip for this hack
--]]
local function echo(...)
	return ...
end

-- equivalent to Lua 5.2's table.pack
-- but we are in 5.1
local function pack(...)
	return {n = select('#',...), ...}
end

local convertValue do

	-- takes a variadic list of arguments
	-- and it to the other "side"
	local convertValues = function(mt, from, to, ...)
		local results = pack(...)
		for i = 1, results.n do
			results[i] = convertValue(mt,from,to,results[i])
		end
		return unpack(results,1,results.n)
	end

	convertValue = function(mt, from, to, value)
		-- if there is already a wrapper, return it
		-- no point in making a new wrapper and it ensures consistency:
		-- assert(loadstring == loadstring)
		local result = to.lookup[value]
		if result then
			-- hack to get around lua's lack of meaningful nil
			if result == null then
				return nil
			else
				if to.trusted and type(value) == 'table' then
					-- __newindex doesn't fire for t[existingKey] = nil or t[existingKey] = otherValue
					local trustedTable = result
					local untrustedTable = value
					for trustedKey in pairs(trustedTable) do
						local untrustedKey = convertValue(mt, to, from, trustedKey)
						assert(untrustedKey, "untrusted key is nil")
						local untrustedValue = rawget(untrustedTable, untrustedKey)
						local trustedValue = convertValue(mt, from, to, untrustedValue)
						rawset(trustedTable, trustedKey, trustedValue)
					end
				end
				return result
			end
		end

		local type = type(value)
		if type == 'table' then
			result = {}
			-- must be indexed before keys and values are converted
			-- otherwise stack overflow
			--if to.trusted then
			to.lookup[value] = result
			--end
			from.lookup[result] = value
			for key, value in pairs(value) do
				result[convertValue(mt,from,to,key)] = convertValue(mt,from,to,value)
			end
			if to.trusted then
				-- any future changes by the user to the table
				-- will be picked up by the metatable and transferred to its partner
				setmetatable(value,mt)
			else
				setmetatable(result,mt)
			end
			return result
		elseif type == 'userdata' then
			-- create a userdata to serve as proxy for this one
			result = newproxy(true)
			local metatable = getmetatable(result)
			for event, metamethod in pairs(mt) do
				metatable[event] = metamethod
			end
			to.lookup[value] = result
			from.lookup[result] = value
			return result
		elseif type == 'function' then
			result = function(...)
				-- would do pcall(value) but there's a roblox bug w/ pcall(getfenv) atm
				local results = pack(pcall(function(...) return value(...) end,convertValues(mt,to,from,...)))
				if results[1] then
					return convertValues(mt,from,to,unpack(results,2,results.n))
				else
					error(results[2],2)
				end
			end
			-- unwrap arguments, call function, wrap arguments
			to.lookup[value] = result
			from.lookup[result] = value
			return result
		else
			-- numbers, strings, booleans, nil, and threads are returned as-is
			-- because they are harmless
			return value
		end
	end
end

-- TODO possibly echo more variables, not sure which ones need it
local default_metamethods = {
	__len       = function(a) return #echo(a) end;
	__unm       = function(a) return -echo(a) end;
	__add       = function(a, b) return echo(a) + echo(b) end;
	__sub       = function(a, b) return echo(a) - echo(b) end;
	__mul       = function(a, b) return echo(a) * echo(b) end;
	__div       = function(a, b) return echo(a) / echo(b) end;
	__mod       = function(a, b) return echo(a) % echo(b) end; -- can't use math.mod because it behaves differently
	__pow       = function(a, b) return echo(a) ^ echo(b) end;
	__lt        = function(a, b) return echo(a) < echo(b) end;
	__eq        = function(a, b) return echo(a) == echo(b) end;
	__le        = function(a, b) return echo(a) <= echo(b) end;
	__concat    = function(a, b) return echo(a) .. echo(b) end;
	__call      = function(f, ...) return echo(f)(...) end;
	__tostring  = tostring;
	__index     = function(t, k) return echo(t)[k] end;
	__newindex  = function(t, k, v) echo(t)[k] = v end;
}

local proxy = {}

-- provide a custom implementation of a metamethod to override the default
function proxy:override(event, metamethod)
	self.metatable[event] = convertValue(self.metatable, self.trusted, self.untrusted, metamethod)
end

function proxy:get(obj)
	return convertValue(self.metatable, self.trusted, self.untrusted, obj)
end

-- whenever the untrusted sees the old value
-- it will be replaced with the new value
-- so replace(loadstring, nil) will prevent all access to loadstring
-- even pcall(loadstring, ...) will fail because loadstring will be nil
function proxy:replace(old, new)
	local wrapper
	if new == nil then
		wrapper = null
	else
		wrapper = convertValue(self.metatable, self.trusted, self.untrusted, new)
		self.trusted.lookup[wrapper] = new
	end
	self.untrusted.lookup[old] = wrapper
end

function proxy.new()
	local self = {}

	-- __mode metamethod allow wrappers to be garbage-collected
	self.trusted = {trusted = true,lookup = setmetatable({},{__mode='k'})}
	self.untrusted = {trusted = false,lookup = setmetatable({},{__mode='v'})}

	-- all objects need to share a common metatable
	-- so the metamethods will fire
	-- e.g. print(game == workspace), two different objects

	self.metatable = {}
	for event, metamethod in pairs(default_metamethods) do
		-- the metamethod will be fired on the wrapper class
		-- so we need to unwrap the arguments and wrap the return values
		self.metatable[event] = convertValue(self.metatable, self.trusted, self.untrusted, metamethod)
	end

	local mt = convertValue(self.metatable, self.trusted, self.untrusted, default_metamethods.__newindex)
	self.metatable.__newindex = function(...)
		if type(select(1,...)) == 'table' then
			rawset(...)
		end
		mt(...)
	end

	setmetatable(self, {__index = proxy, __call = proxy.get})

	self:replace(getfenv, function(f)
		f = f or 1
		if type(f) == "number" and f > 0  then
			f = f + 1
		end
		local success, result = xpcall(function() return getfenv(f)	end, echo)
		if not success then
			error(result, 2)
		else
			return result
		end
	end)

	for _, f in pairs({ table.insert, table.remove, table.sort, rawset }) do
		self:replace(f, function(...)
			local results = pack(pcall(f,...))
			if results[1] then
				-- copy the changes to the untrusted table, since these functions don't trigger any metamethods
				local trustedTable = select(1, ...)
				local untrustedTable = convertValue(self.metatable, self.trusted, self.untrusted, trustedTable)
				for k in pairs(untrustedTable) do
					rawset(untrustedTable, k, nil)
				end
				for k, v in pairs(trustedTable) do
					local untrustedKey = convertValue(self.metatable, self.trusted, self.untrusted, k)
					local untrustedValue = convertValue(self.metatable, self.trusted, self.untrusted, v)
					rawset(untrustedTable, untrustedKey, untrustedValue)
				end
				return unpack(results,2,results.n)
			else
				error(results[2],2)
			end
		end)
	end

	return self
end

return proxy
