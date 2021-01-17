-- https://github.com/F-RDY/lua-state-machine/blob/master/src/init.lua

-- NOTE 2020-12-20 —— I *DO NOT* understand this one :/
-- I think mine is significantly simpler (?)
--    fsm-aw.lua


--[[ EXAMPLE

d.inspectByDefault(true)

stateChanges = 0
cleanups = 0

function accumulate()
  stateChanges = stateChanges + 1

  return function()
    cleanups = cleanups + 1
  end
end

StateMachine = require 'lib.fsm-frdy'

fsm = StateMachine.new({
			states = {
				foo = {
					events = {
						goToBar = "bar",
					},
					activate = accumulate,
					initial = "baz",
					states = {
						baz = {
							events = {
								goToFoobar = "foobar",
							},
							activate = accumulate,
						},
						foobar = {
							events = {
								goToBaz = "baz",
							},
							activate = accumulate,
						},
					},

				},
				bar = {
					events = {
						goToFoo = "foo",
					},
					activate = accumulate,
				}
			},
			initial = "foo",
		})

]]

local function typecheck(object, name, ...)
	local len = select('#', ...)
	local objectType = type(object)
	local correct = false
	local types = ""

	for i = 1, len do
		local t = select(i, ...)
		
		types = types .. t .. (len == 1 and "" or i < len and ", " or ", or ")
		
		if objectType == t then
			correct = true
		end
	end

	if not correct then
		error("expected " .. name .. " to be a " .. types .. ", got " .. objectType)
	end
end

local function createSignal()
	local listeners = {}

	local function subscribe(self, callback)
		typecheck(callback, "callback", "function")

		local listener = {
			callback = callback,
			listening = true,
		}

		table.insert(listeners, listener)

		local function removeCallback()
			if listener.listening then
				listener.listening = false
				table.remove(listeners, table.find(listeners, listener))
			end
		end

		return removeCallback
	end

	local function fire(self, ...)
		for _, listener in pairs(listeners) do
			if listener.listening then
				listener.callback(...)
			end
		end
	end

	return {
		subscribe = subscribe, 
		fire = fire,
	}
end

local function call(func, ...)
	return type(func) == "function" and func(...)
end

local NONE = "NONE"
local DEFER = "DEFER"

local StateMachine = {
	None = NONE,
	Defer = DEFER,
}
StateMachine.__index = StateMachine

function StateMachine.new(options)
	local initial = options.initial or NONE
	local states = options.states

	typecheck(states, "states", "table")

	local self = setmetatable({
		_stack = {
			{
				substates = states
			},
		},
		_states = states,
	}, StateMachine)

	self:loadState(initial)

	return self
end

function StateMachine:loadState(name, ...)
	local stack = self._stack

	local parent = stack[#stack]
	local nextState

	repeat
		nextState = parent.substates[name]
    u.p(nextState)

		assert(nextState ~= nil, "Undefined state: " .. name)

		local state = {
			events = nextState.events or {},
			substates = nextState.states or {},
			cleanup = call(nextState.activate, self, ...),
		}

    u.p(state)

		stack[#stack + 1] = state

		parent = state
		name = nextState.initial or NONE
	until nextState.states == nil
end

function StateMachine:fireEvent(event, ...)
	local stack = self._stack

  u.pheader('stack')
  u.p(stack)

	for i = #stack, 2, -1 do
		local name = stack[i]
    u.pheader('stack[i]')
    u.p(name)
		local nextState = name.events[event]

		if type(nextState) == "function" then
			nextState = nextState(...)
		end

		if nextState then
			for j = #stack, i, -1 do
				call(stack[j].cleanup, ...)
				stack[j] = nil
			end

			self:loadState(nextState, ...)

			return true
		end
	end

	return false
end

return StateMachine
