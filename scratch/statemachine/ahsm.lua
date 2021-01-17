--
-- AW NOTE: I don't understand this one :/
-- https://github.com/xopxe/ahsm


--- ahsm Hierarchical State Machine.
-- ahsm is a very small implementation of Hierararchical State Machines,
-- also known as Statecharts. It's written in Lua, with no external 
-- dependencies, and in a single file. Can be run on platforms as small as 
-- a microcontroler.
-- @module ahsm
-- @usage local ahsm = require 'ahsm'
-- @alias M

--[[
ahsm = require 'lib.ahsm'

-- HELLO WORLD STATES
hello_s = ahsm.state { exit=function () print "HW STATE hello" end } --state with exit func
world_s = ahsm.state { entry=function () print "HW STATE world" end } --state with entry func
t11 = ahsm.transition { src=hello_s, tgt=world_s, events={hello_s.EV_DONE} } --transition on state completion
t12 = ahsm.transition { src=world_s, tgt=hello_s, events={'e_restart'}, timeout=2.0} --transition with timeout, event is a string

a = 0
helloworld_s = ahsm.state {
  states = { hello=hello_s, world=world_s }, --composite state
  transitions = { to_world=t11, to_hello=t12 },
  initial = hello_s, --initial state for machine
  doo = coroutine.wrap( function () -- a long running doo with yields
    while true do
      a = a + 1
      coroutine.yield(true)
    end
  end ),
  entry = function() print 'HW doo running' end,
  exit = function () print('HW doo iteration count', a) end,  -- will show efect of doo on exit
}


-- COMPOSITE
ahsm = require 'lib.ahsm'
s1 = ahsm.state {}                    -- an empty state

s2 = ahsm.state {                     -- another state, with behavior
  entry = function() print 'IN' end,  -- to be called on state activation
  exit = function() print 'OUT' end,  -- to be called on state deactivation
  doo = function()                    -- to be called while the state is active
    print 'DURING'
    return true                       -- doo() will be polled as long as it returns true
  end
}

t1 = ahsm.transition {
  src=s1,
  tgt=s2,
  events={'an_event', 'another_event'},
  effect = print,
}

ev1 = {}
t2 = ahsm.transition {
  src=s2,
  tgt=s1,
  events = {ev1},
  timeout = 5.0
}

s3 = ahsm.state {
  states = {s1, s2},
  transitions = {t1, t2},
  initial = s1  -- the inital state of the embedded machine
}

fsm = ahsm.init(s3)

]]


local pairs, ipairs, type, rawset, rawget, tonumber = pairs, ipairs, type, rawset, rawget, tonumber
local math_huge = math.huge

local M = {}

local EV_ANY = {}
local EV_TIMEOUT = {_name='EV_TIMEOUT'}


local function init ( composite )
  --initialize debug name for states and events
  if M.debug then 
    for ne, e in pairs(composite.events or {}) do
      M.debug('event', e, ne)
    end
    for ns, s in pairs(composite.states) do
      s.container = composite
      M.debug('state', s, ns)
    end
    for nt, t in pairs(composite.transitions) do
      M.debug('trans', t, nt)
    end
  end

  for _, s in pairs(composite.states) do
    s.container = composite
    for nt, t in pairs(composite.transitions or {}) do
      if t.src == s then 
        for _, e in pairs(t.events or {}) do
          if M.debug then
            M.debug('trsel', s, t, e)
          end
          s.out_trans[e] = s.out_trans[e] or {}
          s.out_trans[e][t] = true
        end
      end
    end
    if s.states then init( s ) end --recursion
  end
end

--- Function used to get current time.
-- Replace with whatever your app uses. Must return a number. This is used when
-- computing timeouts for transitions.
-- Defaults to os.time.
-- @function get_time
M.get_time = os.time

--- Initialize a state.
-- Converts a state specfification into a state. 
-- The state has a EV\_DONE field which is an event triggered on state
-- completion.
-- @param state_s state specificatios (see @{state_s}).
-- @return the initilized state
M.state = function (state_s)
  state_s = state_s or {}
  state_s.EV_DONE = {} --singleton, trigered on state completion
  state_s.out_trans = {}
  return state_s
end

--- Debug print function.
-- If provided, this function will be called to print debug information.
-- It must be set before calling @{init}. The debug will try to get friendly
-- names for events, transitions and states from the exported names (see `states`,
-- `transitions` and `events` fields from @{state_s}), or a `_name` field. 
-- @usage ahsm.debug = print
M.debug = nil

-- metatable to maintain state.out_trans structure for transition timeouts
local to_key = {}
local mt_transition = {
  __index = function (t, k)
    if k=='timeout' then
      return rawget(t, to_key)
    else
      return rawget(t, k)
    end
  end,
  __newindex = function(t, k, v)
    if k=='timeout' then
      local src_out_trans = t.src.out_trans
      local number_v = tonumber(v)
      if number_v then  -- add a timeout
        if M.debug then M.debug('sched', t, v) end
        src_out_trans[EV_TIMEOUT] = src_out_trans[EV_TIMEOUT] or {}
        src_out_trans[EV_TIMEOUT][t] = true
      elseif src_out_trans[EV_TIMEOUT] then -- remove a timeout
        if M.debug then M.debug('sched', t, 'unset') end
        src_out_trans[EV_TIMEOUT][t] = nil
      end
      rawset(t, to_key, number_v)
    else
      rawset(t, k, v)
    end
  end
}

local mt_state_gc = {
  __gc = function (s)
    if s.exit then s.exit(s) end
  end
}

--- Initialize a transition.
-- Converts a transition specification into a transition table.
-- @param transition_s transition specificatios (see @{transition_s}).
-- @return the initilized transition
M.transition = function (transition_s)
  transition_s = transition_s or {}
  assert(transition_s.src, 'missing source state in transition')
  assert(transition_s.tgt, 'missing target state in transition')

  local timeout = transition_s.timeout
  transition_s.timeout = nil
  setmetatable(transition_s, mt_transition)
  transition_s.timeout = timeout
  return transition_s
end

--- When used in the @{transition_s}`.events` field will match any event.
M.EV_ANY = EV_ANY --singleton, event matches any event

--- Event reported to @{transition_s}`.effect` when a transition is made due 
-- to a timeout. 
M.EV_TIMEOUT = EV_TIMEOUT

--- Create a hsm.
-- Constructs and initializes an hsm from a root state.
-- @param root the root state, must be a composite.
-- @return initialized hsm
M.init = function ( root )
  local hsm = { 
    --- Callback for pulling events.
    -- If provided, this function will be called from inside the `step` call
    -- so new events can be added. 
    -- @param evqueue an array where new events can be added.
    -- @function hsm.get_events
    get_events = nil, --function (evqueue) end,
    root = root,
  }
  root.container = {_name='.'} -- fake container for root state
  if M.debug then M.debug('state', root, '') end

  init( root )

  if root.exit then -- use gc to trigger exit() function on root state
    setmetatable(root, mt_state_gc)
  end

  local evqueue = { n=0 } -- array, will hold events for step() to process
  local current_states = {}  -- states being active
  local active_trans = {} --must be balanced (enter and leave step() empty)

  local function enter_state (hsm, s, now)
    if s.entry then s.entry(s) end
    s.container.current_substate = s
    s.done = nil
    current_states[s] = true

    local out_trans_timeout = s.out_trans[EV_TIMEOUT]
    if out_trans_timeout then 
      local timeout, t = math_huge, nil
      for tt in pairs(out_trans_timeout) do
        local t_timeout = tt.timeout
        if t_timeout<timeout then timeout, t = t_timeout, tt end
      end
      --if M.debug then M.debug('sched', now, now + timeout, s, t) end
      s.expiration = now + timeout
    end

    if s.initial then
      if M.debug then M.debug('init', s.initial) end
      enter_state(hsm, s.initial, now) -- recurse into embedded hsm
    end
  end

  local function exit_state (hsm, s)
    if s.exit then s.exit(s) end
    current_states[s] = nil
    if s.current_substate then 
      exit_state (hsm, s.current_substate) --FIXME call or not call?
    end
  end

  enter_state (hsm, root, M.get_time()) -- activate root state

  local stepping = false  -- do not allow recursion whil stepping

  local function step ()
    if stepping then return true end
    stepping = true

    local next_expiration = math_huge
    local now = M.get_time()

    --queue new events
    if hsm.get_events then 
      hsm.get_events( evqueue )
    end

    --find active transitions
    for s, _ in pairs( current_states ) do
      local transited = false
      -- check for matching transitions for events
      --for _, e in ipairs(evqueue) do
      for i = 1, evqueue.n do
        local e=evqueue[i]
        local out_trans_e = s.out_trans[e]
        if out_trans_e then 
          for t in pairs(out_trans_e) do -- search through transitions on event 
            if t.guard==nil or t.guard(e) then  --TODO pcall?
              transited = true
              active_trans[t] = e
              break
            end
          end
          if transited then break end
        end
      end
      --check if event is * and there is anything queued
      if not transited then -- priority down if already found listed event
        local out_trans_any = s.out_trans[EV_ANY]
        local e = evqueue[1]
        if e~=nil and out_trans_any then 
          for t in pairs(out_trans_any) do
            if t.guard==nil or t.guard(e) then
              transited = true
              active_trans[t] = e
              break
            end
          end
        end
      end
      --check timeouts
      if not transited then
        local out_trans_timeout = s.out_trans[EV_TIMEOUT]
        if out_trans_timeout then 
          for t in pairs(out_trans_timeout) do -- search through transitions on tmout 
            local expiration = s.expiration
            if now>=expiration then
              if (t.guard==nil or t.guard(EV_TIMEOUT)) then 
                transited = true
                --active_trans[s.out_trans[EV_TIMEOUT]] = EV_TIMEOUT
                active_trans[t] = EV_TIMEOUT
              end
            else
              if expiration<next_expiration then
                next_expiration = expiration
              end
            end
          end
        end
      end
    end

    -- purge current events
    for i=1, evqueue.n do
      rawset(evqueue, i, nil)
    end
    evqueue.n = 0

    local idle = true

    --call leave_state, traverse transition, and enter_state
    for t, e in pairs(active_trans) do
      if current_states[t.src] then --src state could've been left
        if M.debug then 
          M.debug('step', t, e) 
        end
        idle = false
        exit_state(hsm, t.src)
        if t.effect then t.effect(e) end --FIXME pcall
        enter_state(hsm, t.tgt, now)
      end
      active_trans[t] = nil
    end

    --call doo on active_states
    for s, _ in pairs(current_states) do
      if not s.done then
        if type(s.doo)=='nil' then 
          evqueue.n = evqueue.n + 1
          evqueue[evqueue.n] = s.EV_DONE
          s.done = true
          idle = false -- let step again for new event
        elseif type(s.doo)=='function' then 
          local poll_flag = s.doo(s) --TODO pcall
          if not poll_flag then 
            evqueue.n = evqueue.n + 1
            evqueue[evqueue.n] = s.EV_DONE
            s.done = true
            idle = false -- let step again for new EV_DONE event
          end
        end
      end
    end

    if next_expiration==math_huge then
      next_expiration = nil
    end

    stepping = false
    return idle, next_expiration
  end

  --- Push new event to the hsm.
  -- The event will be queued, and then the machine will be looped using 
  -- @{loop}.  
  -- BEWARE: if this is called from a callback from C side, will cause a core 
  -- panic. In this scenario you must use @{queue_event}.
  -- @param ev an event. Can be of any type except nil.
  hsm.send_event = function (ev)
    evqueue.n = evqueue.n + 1
    evqueue[evqueue.n] = ev
    hsm.loop()
  end

  --- Queue new event to the hsm.
  -- The queued messages will be processed when machine is stepped using 
  -- @{step} or @{loop}. Also, see @{send_event}
  -- @param ev an event. Can be of any type except nil.
  hsm.queue_event = function (ev)
    evqueue.n = evqueue.n + 1
    evqueue[evqueue.n] = ev
  end

  --- Step trough the hsm.
  -- A single step will consume all pending events, and do a round evaluating
  -- available doo() functions on all active states. This call finishes as soon 
  -- as the cycle count is reached or the hsm becomes idle.
  -- @param count maximum number of cycles to perform. Defaults to 1
  -- @return the idle status, and the next impending expiration time if 
  -- available. Being idle means that all events have been consumed and no 
  -- doo() function is pending to be run. The expiration time indicates there 
  -- is a transition with timeout waiting.
  hsm.step = function ( count )
    count = count or 1
    for i=1, count do
      local idle, expiration = step()
      if idle then return true, expiration end
    end
    return false
  end

  --- Loop trough the hsm.
  -- Will step the machine until it becomes idle. When this call returns means
  -- there's no actions to be taken immediatelly.
  -- @return If available, the time of the closests pending timeout
  -- on a transition
  hsm.loop = function ()
    local idle, expiration 
    repeat
      idle, expiration = step()
    until idle
    return expiration
  end

  return hsm
end


--- Data structures.
-- Main structures used to describe a hsm.
-- @section structures

------
-- State specification.
-- A state can be either leaf or composite. A composite state has a hsm 
-- embedded, defined by the `states`, `transitions` and `initial` fields. When a
-- compodite state is activated the embedded hsm is started from the `initial`
-- state. The activity of a state must be provided in the `entry`, `exit` and `doo` 
-- fields.
-- @field entry an optional function to be called on entering the state.
-- @field exit an optional function to be called on leaving the state.
-- @field doo an optional function that will be called when the state is 
-- active. If this function returns true, it will be polled again. If
-- returns false, it is considered as completed.
-- @field EV_DONE This field is created when calling @{state}, and is an
-- event emitted when the `doo()` function is completed, or immediatelly if 
-- no `doo()` function is provided.
-- @field states When the state is a composite this table's values are the 
-- states of the embedded hsm. Keys can be used to provide a name.
-- @field transitions When the state is a composite this table's values are
-- the transitions of the embedded hsm. Keys can be used to provide a name.
-- @field initial This is the initial state of the embedded.
-- @table state_s

------
-- Transition specification.
-- @field src source state.
-- @field dst destination state.
-- @field events table where the values are the events that trigger the 
-- transition. Can be supressed by the guard function
-- @field guard if provided, when the transition is triggered this function 
-- will be evaluated with the event as parameter. If returns a true value
-- the transition is made.
-- @field effect this funcion of transition traversal, with the triggering 
-- event as parameter.
-- @field timeout If provided, this number is used as timeout for time 
-- traversal. After timeout time units spent in the souce state the transition 
-- will be triggered with the @{EV_TIMEOUT} event as parameter. Uses the 
-- @{get_time} to read the system's time.
-- @table transition_s



return M
