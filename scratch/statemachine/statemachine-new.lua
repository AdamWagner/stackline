-- FROM: https://github.com/unindented/lua-fsm
--
-- VARIANT of: https://github.com/kyleconroy/lua-state-machine
-- A slightly newer / shorter version: https://github.com/ieu/lua-state-machine

--[[ EXAMPLE {{{

machine = require 'lib.statemachine-new'
d.inspectByDefault(true)
c = machine.create({
  initial = "menu",
  error = function(eventName, from, to, args, errorCode, errorMessage)
    return 'event ' .. eventName .. ' was naughty :- ' .. errorMessage
  end,
  events = {
    { name = 'play', from = 'menu', to = 'game' },
    { name = 'quit', from = 'game', to = 'menu' },
    { name = 'force_quit', from = '*', to = 'menu' }
  },

  callbacks = {

    on_play = function() print('fired play event') end,

    on_enter_menu = function() print('entering menu') end,
    on_enter_game = function() print('entering game') end,

    on_leave_menu = function(self, name, from, to)
      print('start leave menu')
      hs.timer.doAfter(1, function()
        self:confirm(name)
      end)

      -- tell machine to defer next state until we call transition (in fadeOut callback above)
      -- NOTE: return `false` to cancel transition
      return machine.ASYNC
    end,

    on_leave_game = function(self,name, from, to)
      print('start leave game')
      hs.timer.doAfter(3, function()
        self:confirm(name)
      end)

      -- tell machine to defer next state until we call transition (in slideDown callback above)
      -- NOTE: return `false` to cancel transition
      return machine.ASYNC
    end,
  }
})


]]  -- }}}

-- luacheck: globals unpack
local unpack = unpack or table.unpack

local M = {}

M.WILDCARD      = "*"
M.ASYNC         = 0
M.SUCCEEDED     = 1
M.NO_TRANSITION = 2
M.PENDING       = 3
M.CANCELLED     = 4

local function do_callback(handler, args) -- {{{
  if handler then
    return handler(unpack(args))
  end
end -- }}}

local function before_event(self, event, _, _, args) -- {{{
  local specific = do_callback(self["on_before_" .. event], args)
  local general = do_callback(self["on_before_event"], args)

  if specific == false or general == false then
    return false
  end
end -- }}}

local function leave_state(self, _, from, _, args) -- {{{
  local specific = do_callback(self["on_leave_" .. from], args)
  local general = do_callback(self["on_leave_state"], args)

  if specific == false or general == false then
    return false
  end
  if specific == M.ASYNC or general == M.ASYNC then
    return M.ASYNC
  end
end -- }}}

local function enter_state(self, _, _, to, args) -- {{{
  do_callback(self["on_enter_" .. to] or self["on_" .. to], args)
  do_callback(self["on_enter_state"] or self["on_state"], args)
end -- }}}

local function after_event(self, event, _, _, args) -- {{{
  do_callback(self["on_after_" .. event] or self["on_" .. event], args)
  do_callback(self["on_after_event"] or self["on_event"], args)
end -- }}}

local function build_transition(self, event, states) -- {{{
  return function (...)
    local from = self.current
    local to = states[from] or states[M.WILDCARD] or from
    local args = {self, event, from, to, ...}

    assert(not self:is_pending(), "previous transition still pending")
    assert(self:can(event), "invalid transition from state '" .. from .. "' with event '" .. event .. "'")

    local before = before_event(self, event, from, to, args)
    if before == false then return M.CANCELLED end

    if from == to then
      after_event(self, event, from, to, args)
      return M.NO_TRANSITION
    end

    self.confirm = function ()
      self.confirm = nil
      self.cancel = nil
      self.current = to
      enter_state(self, event, from, to, args)
      after_event(self, event, from, to, args)
      return M.SUCCEEDED
    end

    self.cancel = function ()
      self.confirm = nil
      self.cancel = nil
      after_event(self, event, from, to, args)
      return M.CANCELLED
    end

    local leave = leave_state(self, event, from, to, args)
    if leave == false then return M.CANCELLED end
    if leave == M.ASYNC then return M.PENDING end

    if self.confirm then
      return self.confirm()
    end
  end
end -- }}}


local Class = require 'lib.Class'
local o = Class()

function o:new() -- {{{
  return self
end  -- }}}

function o.is(state) -- {{{
  -- if table, check all provided states
  if type(state) == "table" then
    for _, s in ipairs(state) do
      if self.current == s then return true end
    end
    return false
  end

  -- otherwise, just compare current to given string state
  return self.current == state
end -- }}}

function o:can(event) -- {{{
  local states = self.states_for_event[event]
  local to = states[self.current] or states[M.WILDCARD]
  return to ~= nil
end -- }}}

function o:cannot(event) -- {{{
  return not self:can(event)
end -- }}}

function o.transitions() -- {{{
  return events_for_state[self.current]
end -- }}}

function o:is_pending() -- {{{
  return self.confirm ~= nil
end -- }}}

function o.ks_finished() -- {{{
  return self.is(terminal)
end -- }}}


function M.create(cfg, target)-- {{{
  local self = target or o:new()

  cfg.initial = type(cfg.initial) == "string"
    and {state = cfg.initial}
    or cfg.initial -- Allow for a string, or a map like `{state = "foo", event = "setup"}`.

  local initial_event = cfg.initial and cfg.initial.event or "startup" -- cfg.initial event.

  local terminal = cfg.terminal         -- Terminal state.
  local events = cfg.events or {}       -- Events.
  local callbacks = cfg.callbacks or {} -- Callbacks.
  self.states_for_event = {}            -- Track state transitions allowed for an event.
  self.events_for_state = {}            -- Track events allowed from a state.

  local function add(e)-- {{{

    local from = type(e.from) == "table" -- Allow wildcard transition if `from` is not specified.
      and e.from 
      or (e.from and {e.from} or {M.WILDCARD})

    local to = e.to
    local event = e.name

    self.states_for_event[event] = self.states_for_event[event] or {}

    for _, fr in ipairs(from) do
      self.events_for_state[fr] = self.events_for_state[fr] or {}
      table.insert(self.events_for_state[fr], event)
      self.states_for_event[event][fr] = to or fr -- Allow no-op transition if `to` is not specified.
    end
  end-- }}}

  if cfg.initial then
    add({name = initial_event, from = "none", to = cfg.initial.state})
  end

  -- add events
  for _, event in ipairs(events) do
    add(event)
  end

  -- build transitions
  for event, states in pairs(self.states_for_event) do
    self[event] = build_transition(self, event, states)
  end

  -- register callbacks
  for name, callback in pairs(callbacks) do
    self[name] = callback
  end

  self.current = "none"

  if cfg.initial and not cfg.initial.defer then
    self[initial_event]()
  end


  return self
end-- }}}

return M
