-- FROM: https://github.com/kyleconroy/lua-state-machine/blob/master/statemachine.lua
-- ALTERNATE FLAVOR: https://github.com/ieu/lua-state-machine
-- NEWER FLAVOR: https://github.com/unindented/lua-fsm
-- MUCH NEWER rewrite by 'novice programmer': https://github.com/Devyze/lua-state-machine/blob/master/src/init.lua

-- Totally different, but new-ish libs. Most support sub-states.
  -- https://github.com/F-RDY/lua-state-machine
  -- https://github.com/allsey87/luafsm
  -- https://github.com/freedomcondor/luaStateMachine

  --[[ NOTES / USAGE {{{

┌───────────────────────────────────────────┐
│ Events and States are defined like this ↓ │
└───────────────────────────────────────────┘
  'Events' are synonymous with 'Transitions'

  event_one = {
    name = 'warn',    -- EVENT name: 'warn'
    from = 'green',   -- from STATE 'green'
    to   = 'yellow'   -- to STATE 'yellow'
  }
  event_two = {
    name = 'panic',    -- EVENT name: 'panic'
    from = 'yellow',   -- from STATE 'yellow'
    to   = 'red'       -- to STATE 'red'
  }

  The two events above define 3 total states
    - green, yellow, red

  … and two events (transitions)
    - warn, panic


┌──────────────────────────────────────┐
│ Transition methods (aka 'callbacks') │
└──────────────────────────────────────┘
FOUR CALLBACK NAMING CONVENTIONS:
    onbeforeevent - fired before the event
    onafterevent - fired after the event

    onleavestate - fired when leaving the old state
    onenterstate - fired when entering the new state

  YOU CAN AFFECT THE EVENT BY:
    1. return `false` from an onbefore(event or state) handler to cancel the event
    2. return ASYNC from an onleavestate or onenterstate handler to perform an
       asynchronous state transition (see next section)

  FOR CONVENIENCE, THE 2 MOST USEFUL CALLBACKS CAN BE SHORTENED:
    onevent - convenience shorthand for onafterevent
      e.g., "on panic" → fsm:onpanic(name, from, to) … end
    onstate - convenience shorthand for onenterstate

  IN ADDITION, A GENERIC ONSTATECHANGE() CALLBACK
   can be used to call a single function for all state changes:
    onstatechange()

┌─────────┐
│ Example │
└─────────┘

    d.inspectByDefault(true)
    machine = require('lib.statemachine')

    a = machine.create({
      initial = 'green',
      events = {
        { name = 'warn',  from = 'green',  to = 'yellow' },
        { name = 'panic', from = 'yellow', to = 'red'    },
        { name = 'calm',  from = 'red',    to = 'yellow' },
        { name = 'clear', from = 'yellow', to = 'green'  }
      },
      callbacks = {


          -- using shorthand for 'onenterstate'
        onpanic =  function(self, event, from, to, msg) print('panic!      \n Current state: ' .. self.current) end,
        onclear =  function(self, event, from, to, msg) print('to clear    \n Current state: ' .. self.current) end,
        ongreen =  function(self, event, from, to)      print('green light \n Current state: ' .. self.current) end,
        onyellow = function(self, event, from, to)      print('yellow light\n Current state: ' .. self.current) end,
        onred =    function(self, event, from, to)      print('red light   \n Current state: ' .. self.current) end,

        onstatechange = function() print('\n\n SOMETHING CHANGED') end,
      }
    })

    function fsm:onstatechange(name, from, to, foo)
      print('\n name: ', hs.inspect(name), '\nfrom: ', from, '\nto: ', to)
    end


┌────────────────────────────────────────────────────┐
│ Multiple 'from' and 'to' states for a single event │
└────────────────────────────────────────────────────┘
  If an event is allowed from multiple states, and always transitions to the same
    state, then simply provide an array of states in the from attribute of an
    event. However, if an event is allowed from multiple states, but should
    transition to a different state depending on the current state, then provide
    multiple event entries with the same name:

  ┌─────────┐
  │ Example │
  └─────────┘
    b = machine.create({
      initial = 'hungry',
      events = {
        { name = 'eat',  from = 'hungry',                                to = 'satisfied' },
        { name = 'eat',  from = 'satisfied',                             to = 'full'      },
        { name = 'eat',  from = 'full',                                  to = 'sick'      },
        { name = 'rest', from = {'hungry', 'satisfied', 'full', 'sick'}, to = 'hungry'    },
            -- OR   --
        { name = 'rest', from = '*', to = 'hungry'    },
    }})

  This example will create an object with 2 event methods:
    fsm:eat()
    fsm:rest()

  The rest event will always transition to the hungry state, while the eat event
    will transition to a state that is dependent on the current state.

  NOTE: The rest event could use a wildcard '*' for the 'from' state if it should
    be allowed from any current state.
  NOTE: The rest event in the above example can also be specified as multiple
    events with the same name if you prefer the verbose approach.


c = machine.create({

  initial = 'menu',

  events = {
    { name = 'play', from = 'menu', to = 'game' },
    { name = 'quit', from = 'game', to = 'menu' }
  },

  callbacks = {
    function onentermenu() print('entering menu') end,
    function onentergame() print('entering game') end,

    function self:onleavemenu(name, from, to)
      print('start leave menu')
      hs.timer.doAfter(1, function()
        fsm:transition(name)
      end)

        -- tell machine to defer next state until we call transition (in fadeOut callback above)
        -- NOTE: return `false` to cancel transition
      return fsm.ASYNC
    end,

    function self:onleavegame(name, from, to)
      print('start leave game')
      hs.timer.doAfter(3, function()
        fsm:transition(name)
      end)

        -- tell machine to defer next state until we call transition (in slideDown callback above)
        -- NOTE: return `false` to cancel transition
      return fsm.ASYNC
    end,
  }
})

]]  -- }}}

local unpack = unpack or table.unpack

local machine = {}
machine.__index = machine

local NONE = "none"
local ASYNC = "async"

local function call_handler(handler, params)-- {{{
  if handler then
    return handler(unpack(params))
  end
end-- }}}

local function create_transition(name)-- {{{
  local can, to, from, params

  local function transition(self, ...)-- {{{
    if self.asyncState == NONE then
      can, to = self:can(name)
      from = self.current
      params = { self, name, from, to, ...}

      if not can then return false end
      self.currentTransitioningEvent = name

      local beforeReturn = call_handler(self["onbefore" .. name], params)
      local leaveReturn = call_handler(self["onleave" .. from], params)

      if beforeReturn == false or leaveReturn == false then
        return false
      end

      self.asyncState = name .. "WaitingOnLeave"

      if leaveReturn ~= ASYNC then
        transition(self, ...)
      end

      return true
    elseif self.asyncState == name .. "WaitingOnLeave" then
      self.current = to

      local enterReturn = call_handler(self["onenter" .. to] or self["on" .. to], params)

      self.asyncState = name .. "WaitingOnEnter"

      if enterReturn ~= ASYNC then
        transition(self, ...)
      end

      return true
    elseif self.asyncState == name .. "WaitingOnEnter" then
      call_handler(self["onafter" .. name] or self["on" .. name], params)
      call_handler(self["onstatechange"], params)
      self.asyncState = NONE
      self.currentTransitioningEvent = nil
      return true
    else
    	if string.find(self.asyncState, "WaitingOnLeave") or string.find(self.asyncState, "WaitingOnEnter") then
    		self.asyncState = NONE
    		transition(self, ...)
    		return true
    	end
    end

    self.currentTransitioningEvent = nil
    return false
  end-- }}}

  return transition
end-- }}}

local function add_to_map(map, event)-- {{{
  if type(event.from) == 'string' then
    map[event.from] = event.to
  else
    for _, from in ipairs(event.from) do
      map[from] = event.to
    end
  end
end-- }}}

function machine.create(options)-- {{{
  assert(options.events)

  local fsm = {}
  setmetatable(fsm, machine)

  fsm.options = options
  fsm.current = options.initial or 'none'
  fsm.asyncState = NONE
  fsm.events = {}

  for _, event in ipairs(options.events or {}) do
    local name = event.name
    fsm[name] = fsm[name] or create_transition(name)
    fsm.events[name] = fsm.events[name] or { map = {} }
    add_to_map(fsm.events[name].map, event)
  end

  for name, callback in pairs(options.callbacks or {}) do
    fsm[name] = callback
  end

  return fsm
end-- }}}

function machine:is(state)-- {{{
  return self.current == state
end-- }}}

function machine:can(e)-- {{{
  local event = self.events[e]
  local to = event and event.map[self.current] or event.map['*']
  return to ~= nil, to
end-- }}}

function machine:cannot(e)-- {{{
  return not self:can(e)
end-- }}}

function machine:todot(filename)-- {{{
  local dotfile = io.open(filename,'w')
  dotfile:write('digraph {\n')
  local transition = function(event,from,to)
    dotfile:write(string.format('%s -> %s [label=%s];\n',from,to,event))
  end
  for _, event in pairs(self.options.events) do
    if type(event.from) == 'table' then
      for _, from in ipairs(event.from) do
        transition(event.name,from,event.to)
      end
    else
      transition(event.name,event.from,event.to)
    end
  end
  dotfile:write('}\n')
  dotfile:close()
end-- }}}

function machine:transition(event)-- {{{
  if self.currentTransitioningEvent == event then
    return self[self.currentTransitioningEvent](self)
  end
end-- }}}

function machine:cancelTransition(event)-- {{{
  if self.currentTransitioningEvent == event then
    self.asyncState = NONE
    self.currentTransitioningEvent = nil
  end
end-- }}}

machine.NONE = NONE
machine.ASYNC = ASYNC

return machine
