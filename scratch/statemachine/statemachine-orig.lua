-- FROM: https://github.com/kyleconroy/lua-state-machine

--[[ EXAMPLE {{{

    machine = require 'lib.statemachine-orig'
    d.inspectByDefault(true)
    c = machine.create({
        initial = "menu",
        error = function(eventName, from, to, args, errorCode, errorMessage)
            return 'event ' .. eventName .. ' was naughty :- ' .. errorMessage
        end,
        events = {
            { name = 'play',      from = 'menu', to = 'game' },
            { name = 'quit',      from = 'game', to = 'menu' },
            { name = 'forceQuit', from = '*',    to = 'menu' }
        },

        callbacks = {

            onplay = function() print('fired play event') end,

            onbeforeplay = function()
              print('async state', c.asyncState)
              if c.asyncState:find('WaitingOnLeave') then return false end
            end,
            onbeforequit = function()
              print('async state', c.asyncState)
              if c.asyncState:find('WaitingOnLeave') then return false end
            end,

            onentermenu = function()
              -- if c.asyncState:find('WaitingOnLeave') then return  end
              print('entering menu')
              -- print('async state', c.asyncState)
            end,

            onentergame = function()
              -- if c.asyncState:find('WaitingOnLeave') then return  end
              print('entering game')
              -- print('async state', c.asyncState)
            end,

            onleavemenu = function(self, name, from, to)
                print('start leave menu')
                -- print('async state',c.asyncState)
                hs.timer.doAfter(1, function()
                    self:transition(name)
                end)

                -- tell machine to defer next state until we call transition (in fadeOut callback above)
                -- NOTE: return `false` to cancel transition
                return c.ASYNC
            end,

            onleavegame = function(self,name, from, to)
                print('start leave game')
                -- print('async state',c.asyncState)
                hs.timer.doAfter(3, function()
                    self:transition(name)
                end)

                -- tell machine to defer next state until we call transition (in slideDown callback above)
                -- NOTE: return `false` to cancel transition
                return c.ASYNC
            end,
        }
    })


    ]]   -- }}}
local machine = {}
machine.__index = machine

local NONE = "none"
local ASYNC = "async"

local function call_handler(handler, params)
  if handler then
    return handler(table.unpack(params))
  end
end

local function create_transition(name)
  local can, to, from, params

  local function transition(self, ...)
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
  end

  return transition
end

local function add_to_map(map, event)
  if type(event.from) == 'string' then
    map[event.from] = event.to
  else
    for _, from in ipairs(event.from) do
      map[from] = event.to
    end
  end
end

function machine.create(options)
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
end

function machine:is(state)
  return self.current == state
end

function machine:can(e)
  local event = self.events[e]
  local to = event and event.map[self.current] or event.map['*']
  return to ~= nil, to
end

function machine:cannot(e)
  return not self:can(e)
end

function machine:todot(filename)
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
end

function machine:transition(event)
  if self.currentTransitioningEvent == event then
    return self[self.currentTransitioningEvent](self)
  end
end

function machine:cancelTransition(event)
  if self.currentTransitioningEvent == event then
    self.asyncState = NONE
    self.currentTransitioningEvent = nil
  end
end

machine.NONE = NONE
machine.ASYNC = ASYNC

return machine
