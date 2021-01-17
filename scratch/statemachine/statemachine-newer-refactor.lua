
--[[ EXAMPLE {{{

  c = machine:new({
    initial = 'quit',
    events = {
      { name = 'play', from = 'quit', to = 'game' },
      { name = 'quit', from = 'play', to = 'quit' }
    },

    callbacks = {
      on_enter_menu = function() print('entering menu') end,
      on_enter_game = function() print('entering game') end,

      on_leave_quit = function(self, name, from, to)
        print('start leave menu')
        hs.timer.doAfter(1, function()
          u.p(self)
          self:transit()
        end)

        -- tell machine to defer next state until we call transition (in fadeOut callback above)
        -- NOTE: return `false` to cancel transition
        return 1000
      end,

      on_leave_play = function(self,name, from, to)
        print('start leave game')
        hs.timer.doAfter(3, function()
          u.p(self)
          self:transit()
        end)

        -- tell machine to defer next state until we call transition (in slideDown callback above)
        -- NOTE: return `false` to cancel transition
        return 1000
      end,
    }
  })


  ]]  -- }}}
  local string_format = string.format
  local unpack        = table.unpack
  local ipairs        = ipairs
  local pairs         = pairs
  local type          = type
  local setmetatable  = setmetatable

  local STATEMACHINE = {
    RESULT = {
      SUCCEEDED    = 1, -- State transited successfully
      NOTRANSITION = 2, -- Event successful but no state transition needed
      CANCELLED    = 3, -- asynchronous event cancelled
      PENDING      = 4  -- There is asynchronous event in progress
    },

    ERROR = {
      INVALID_TRANSITION = 100, -- Innapropriate transition detected
      PENDING_TRANSITION = 200, -- New transition requested while another transition is pending
    },

    ASYNC = 1000, -- A asynchronous event is requested

    WILDCARD = "*"
  }

  local do_callback = function(fsm, callback, name, from, to, args)-- {{{
    if not callback then
      return
    end
    return callback(name, from, to, unpack(args))
  end-- }}}

  local before_event = function(fsm, name, from, to, args) -- {{{
    do_callback(fsm, fsm["on_before_event"], name, from, to, args)
    do_callback(fsm, fsm["on_before_" .. name], name, from, to, args)
  end-- }}}

  local after_event = function(fsm, name, from, to, args)-- {{{
    do_callback(fsm, fsm["on_after_event"], name, from, to, args)
    do_callback(fsm, fsm["on_after_" .. name], name, from, to, args)
  end-- }}}

  local leave_state = function(fsm, name, from, to, args)-- {{{
    local generic = do_callback(fsm, fsm["on_leave_state"], name, from, to, args)
    local specific = do_callback(fsm, fsm["on_leave_" .. from], name, from, to, args)

    if STATEMACHINE.ASYNC == generic or STATEMACHINE.ASYNC == specific then
      return STATEMACHINE.ASYNC
    end
  end-- }}}

  local enter_state = function(fsm, name, from, to, args)-- {{{
    do_callback(fsm, fsm["on_enter_state"], name, from, to, args)
    do_callback(fsm, fsm["on_enter_" .. to], name, from, to, args)
  end-- }}}

  local register_callback = function(target, callbacks)-- {{{
    for name, callback in pairs(callbacks) do
      assert(type(target) == "table", string_format("table type expected but %s received", name))
      assert(type(callback) == "function", string_format("function type expected but %s received", callback))
      target[name] = callback
    end
  end-- }}}

  local StateMachine = {
    is = function(self, state)-- {{{
      return self.current == state
    end,-- }}}

    can = function(self, event)-- {{{
      assert(type(event) == "string", string_format("Invalid event type: %s, string expected", type(event)))
      local to = self.events[event][self.current] or self.events[event][STATEMACHINE.WILDCARD]
      return to
    end,-- }}}

    cannot = function(self, event)-- {{{
      return not self:can(event)
    end,-- }}}

    register = register_callback
  }

  local empty_transit = function() end

  local build_event = function(name, map)
    return function(self, ...) -- {{{
      local args = { ... } or {}
      local from = self.current
      local to = self.events[name][from] or self.events[name][STATEMACHINE.WILDCARD] or from

      assert(self.transit == empty_transit, "Previous transition not complete")
      assert(self:can(name), string_format('Event %s inappropriate in current state %s', name, from))

      if from == to then
        after_event(self, name, from, to, args)
        return STATEMACHINE.RESULT.NOTRANSITION
      end

      self.transit = function(self)
        self.transit = empty_transit
        self.current = to
        enter_state(self, name, from, to, args)
        after_event(self, name, from, to, args)
        return STATEMACHINE.RESULT.SUCCEEDED
      end

      self.cancel = function(self)
        if self.transit == empty_transit then
          return
        end
        self.transit = empty_transit
        after_event(self, name, from, to, args)
        return STATEMACHINE.RESULT.CANCELLED
      end,

      before_event(self, name, from, to, args)

      if STATEMACHINE.ASYNC == leave_state(self, name, from, to, args) then
        return STATEMACHINE.RESULT.PENDING
      elseif self.transit then
        return self:transit()
      end
    end-- }}}
  end


  local Class = require 'lib.Class'
  local fsm = Class()

  function fsm:new(config)
    self.current = config.initial
    self.events = {}

    for _, event in ipairs(config.events) do
      self.events[event.name] = self.events[event.name] or {}
      self.events[event.name][event.from] = event.to
      self[event.name] = build_event(event.name, self.events[event.name])
    end

    self:register(config.callbacks)

    self.transit = empty_transit

    setmetatable(self, { __index = StateMachine })
    return self
  end


  function fsm:register(callbacks)
    for name, callback in pairs(callbacks) do
      assert(type(self) == "table", string_format("table type expected but %s received", name))
      assert(type(callback) == "function", string_format("function type expected but %s received", callback))
      self[name] = callback
    end
  end


  return fsm
