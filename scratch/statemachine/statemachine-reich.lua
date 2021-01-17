--FROM: https://github.com/recih/lua-fsm/blob/master/luafsm.lua

--[[ EXAMPLE {{{

  machine = require 'lib.statemachine-reich'
  d.inspectByDefault(true)
  c = machine.create({
    initial = "menu",

    events = {
      { name = 'play',      from = 'menu', to = 'game' },
      { name = 'quit',      from = 'game', to = 'menu' },
    },

    callbacks = {

      onplay = function() print('fired play event') end,

      onentermenu = function()
        print('entering menu')
        print('async state', c.asyncState)
      end,

      onentergame = function()
        print('entering game')
        print('async state', c.asyncState)
      end,

      onleavemenu = function(self, name, from, to)
        print('start leave menu')
        print('async state',c.asyncState)
        hs.timer.doAfter(1, function()
          c.transition()
        end)

        -- tell machine to defer next state until we call transition (in fadeOut callback above)
        -- NOTE: return `false` to cancel transition
        return machine.ASYNC
      end,

      onleavegame = function(self,name, from, to)
        print('start leave game')
        print('async state',c.asyncState)
        hs.timer.doAfter(3, function()
          c.transition()
        end)

        -- tell machine to defer next state until we call transition (in slideDown callback above)
        -- NOTE: return `false` to cancel transition
        return machine.ASYNC
      end,
    }
  })

  -- }}}
]]



  --[[=================================================
  Lua State Machine Library
  ----=================================================]]
  VERSION = "2.3.2"

  SUCCEEDED = 1 -- the event transitioned successfully from one state to another
  NOTRANSITION = 2 -- the event was successfull but no state transition was necessary
  CANCELLED = 3 -- the event was cancelled by the caller in a beforeEvent callback
  PENDING = 4 -- the event is asynchronous and the caller is in control of when the transition occurs

  INVALID_TRANSITION_ERROR = 'INVALID_TRANSITION_ERROR' -- caller tried to fire an event that was innapropriate in the current state
  PENDING_TRANSITION_ERROR = 'PENDING_TRANSITION_ERROR' -- caller tried to fire an event while an async transition was still pending
  INVALID_CALLBACK_ERROR = 'INVALID_CALLBACK_ERROR' -- caller provided callback function threw an exception

  WILDCARD = '*'
  ASYNC = 'async'

  local function do_callback(fsm, func, event, params)
    if type(func) == 'function' then
      local success, ret = pcall(func, table.unpack(params))
      if not success then
        local err = ret
        fsm:error(event, INVALID_CALLBACK_ERROR, err)
      end
      return ret
    end
  end

  local function before_any_event(fsm, event, params)
    return do_callback(fsm, fsm.onbeforeevent, event, params)
  end

  local function after_any_event(fsm, event, params)
    return do_callback(fsm, fsm.onafterevent or fsm.onevent, event, params)
  end

  local function leave_any_state(fsm, event, params)
    return do_callback(fsm, fsm.onleavestate, event, params)
  end

  local function enter_any_state(fsm, event, params)
    return do_callback(fsm, fsm.onenterstate or fsm.onstate, event, params)
  end

  local function change_state(fsm, event, params)
    return do_callback(fsm, fsm.onchangestate, event, params)
  end

  local function before_this_event(fsm, event, params)
    return do_callback(fsm, fsm['onbefore' .. event.name], event, params)
  end

  local function after_this_event(fsm, event, params)
    return do_callback(fsm, fsm['onafter' .. event.name] or fsm['on' .. event.name], event, params)
  end

  local function leave_this_state(fsm, event, params)
    return do_callback(fsm, fsm['onleave' .. event.from], event, params)
  end

  local function enter_this_state(fsm, event, params)
    return do_callback(fsm, fsm['onenter' .. event.to] or fsm['on' .. event.to], event, params)
  end

  local function before_event(fsm, event, params)
    if before_this_event(fsm, event, params) == false or before_any_event(fsm, event, params) == false then
      return false
    end
  end

  local function after_event(fsm, event, params)
    after_this_event(fsm, event, params)
    after_any_event(fsm, event, params)
  end

  local function leave_state(fsm, event, params)
    local specific = leave_this_state(fsm, event, params)
    local general = leave_any_state(fsm, event, params)
    if specific == false or general == false then
      return false
    elseif specific == ASYNC or general == ASYNC then
      return ASYNC
    end
  end

  local function enter_state(fsm, event, params)
    enter_this_state(fsm, event, params)
    enter_any_state(fsm, event, params)
  end

  local function build_event(name, entry)
    return function(self, ...)
      local from = self.current
      local to = entry[from] or entry[WILDCARD] or from
      local event = {
        name = name,
        from = from,
        to = to,
      }
      local params = {self, event, ...}

      if self.transition then
        return self:error(event, PENDING_TRANSITION_ERROR, ('event %s inappropriate because previous transition did not complete'):format(name))
      end

      if self:cannot(name) then
        return self:error(event, INVALID_TRANSITION_ERROR, ('event %s inappropriate in current state %s'):format(name, self.current))
      end

      if before_event(self, event, params) == false then
        return CANCELLED
      end

      if from == to then
        after_event(self, event, params)
        return NOTRANSITION
      end

      -- prepare a transition method for use EITHER lower down,
      -- or by caller if they want an async transition (indicated by an ASYNC return value from leaveState)
      local fsm = self
      self.transition = {
        -- provide a way for caller to cancel async transition if desired
        cancel = function()
          fsm.transition = nil
          after_event(fsm, event, params)
        end
      }
      setmetatable(self.transition, {
        __call = function()
          fsm.transition = nil -- this method should only ever be called once
          fsm.current = to
          enter_state(fsm, event, params)
          change_state(fsm, event, params)
          after_event(fsm, event, params)
          return SUCCEEDED
        end
      })

      local leave = leave_state(fsm, event, params)
      if leave == false then
        self.transition = nil
        return CANCELLED
      elseif leave == ASYNC then
        return PENDING
      else
        if self.transition then -- need to check in case user manually called transition() but forgot to return ASYNC
          return self.transition()
        end
      end
    end
  end

  function create(cfg, target)
    assert(type(cfg) == 'table', 'cfg must be a table')

    -- allow for a simple string, or an object with { state: = 'foo', event = 'setup', defer = true|false }
    local initial = type(cfg.initial) == 'string' and { state = cfg.initial } or cfg.initial
    local terminal = cfg.terminal or cfg.final
    local fsm = target or cfg.target or {}
    local events = cfg.events or {}
    local callbacks = cfg.callbacks or {}
    local map = {}

    local function add(e)
      -- allow 'wildcard' transition if 'from' is not specified
      local from = type(e.from) == 'table' and e.from or (e.from and {e.from} or {WILDCARD})
      local entry = map[e.name] or {}
      map[e.name] = entry
      for _, v in ipairs(from) do
        entry[v] = e.to or v -- allow no-op transition if 'to' is not specified
      end
    end

    if initial then
      initial.event = initial.event or 'startup'
      add { name = initial.event, from = 'none', to = initial.state }
    end

    for _, e in ipairs(events) do
      add(e)
    end

    for k, v in pairs(map) do
      fsm[k] = build_event(k, v)
    end

    for k, v in pairs(callbacks) do
      fsm[k] = v
    end

    fsm.current = 'none'
    fsm.is = function(self, state)
      if type(state) == 'table' then
        for _, s in ipairs(state) do
          if s == self.current then
            return true
          end
        end
        return false
      else
        return self.current == state
      end
    end
    fsm.can = function(self, event)
      if (not self.transition) and map[event] and
        (map[event][self.current] or map[event][WILDCARD]) then
        return true
      else
        return false
      end
    end
    fsm.cannot = function(self, event) return not self:can(event) end
    -- default behavior when something unexpected happens is to throw an exception, but caller can override this behavior if desired
    fsm.error = cfg.error or function(self, event, error_code, err) error(error_code .. " " .. err) end
    fsm.is_finished = function(self) return self:is(terminal) end

    if initial and not initial.defer then
      fsm[initial.event](fsm)
    end

    return fsm
  end

  return { create = create }
