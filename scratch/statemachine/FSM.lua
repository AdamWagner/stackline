---
-- fsm.lua
-- FROM: https://github.com/NickFlexer/finita/blob/master/fsm.lua

--[[
FSM = require "lib.FSM"

state_1 = {
  name = 'state 1',
  enter = function() print('entering state 1') end,
  execute = function() print('executing state 1') end,
  exit = function() print('exiting state 1') end,
}

state_2 = {
  name = 'state 2',
  enter = function() print('entering state 2') end,
  execute = function(...) 
    for k,v in pairs({...}) do
      print('\n--------------------------------')
      print(k)
      print(hs.inspect(v))
    end
  end,
  exit = function() print('exiting state 2') end,
}

Game = {}

function Game:new()
  -- create instance of FSM class and pass Game as FSM owner
  self.fsm = FSM(self)

  -- owner stores links to all states
  self.states = {
    menu = state_1,
    gameplay = state_2,
  }

  -- set current state
  self.fsm:set_current_state(self.states.menu)

  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Game:update(dt)
  -- update fsm and pass extra paremeter 'dt' to current_state execute method
  print('updating to:', dt)
  self.fsm:update(dt)
  return self
end

function Game:handle_input(key)
  if key == "Enter" then
    -- change current state
    self.fsm:change_state(self.states.gameplay)
  end
end

]]


local FSM = {
  _DESCRIPTION = "Finite State Machine implementation for Lua"
}
local FSM_mt = {__index = FSM}

local function check_state(state)
  if type(state) == "table" then
    if state.enter and type(state.enter) == "function"
      and state.execute and type(state.execute) == "function"
      and state.exit and type(state.exit) == "function" then

      return true
    end
  end

  return false
end

function FSM:new(owner)
  self:set_owner(owner)
  self.name = nil
  self.current_state = nil
  self.previous_state = nil
  self.global_state = nil

  return setmetatable({}, FSM_mt)
end

function FSM:set_owner(owner)
  assert(owner, "FSM:set_owner() try to set nil owner")
  self.owner = owner
  return self
end

function FSM:set_current_state(state)
  if check_state(state) then
    self.current_state = state
    self.current_state:enter(self.owner)
  else
    error("FSM:set_current_state() incorrect state declaration for state " .. tostring(state))
  end
  return self
end

function FSM:set_previous_state(state)
  if check_state(state) then
    self.previous_state = state
  else
    error("FSM:set_previous_state() incorrect state declaration for state " .. tostring(state))
  end
  return self
end

function FSM:set_global_state(state)
  if check_state(state) then
    self.global_state = state
    self.global_state:enter(self.owner)
  else
    error("FSM:set_global_state() incorrect state declaration for state " .. tostring(state))
  end
  return self
end

function FSM:update(...)
  print('running FSM:update')
  print(...)
  if self.global_state then
    self.global_state:execute(self.owner, ...)
  end

  if self.current_state then
    self.current_state:execute(self.owner, ...)
  end
  return self
end

function FSM:change_state(new_state)
  assert(self.current_state, "FSM:change_state() current_state was nil")
  assert(check_state(new_state), "FSM:change_state() trying to change to invalid state")

  -- Don't do anything if new state is same as current
  if self:is_in_state(new_state) then return self end

  -- Current state becomes previous & runs onExit()
  self.previous_state = self.current_state
  self.current_state:exit(self.owner)

  -- New state becomes current & runs onEnter
  self.current_state = new_state
  self.current_state:enter(self.owner)
  return self
end

function FSM:revent_to_previous_state()
  self:change_state(self.previous_state)
  return self
end

function FSM:is_in_state(state)
  return self.current_state == state
end

return setmetatable(FSM, {__call = FSM.new})
