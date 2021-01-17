-- FROM: https://github.com/kyleconroy/lua-state-machine
-- OOP version: https://github.com/katichar/FTGEditor/blob/master/src/framework/cc/components/behavior/StateMachine.lua

--[[ EXAMPLE {{{

    async = require 'stackline.lib.async'
    machine = require 'lib.statemachine-old-refactor'

    function delayedAction(str) -- {{{
        local r = async()
        hs.timer.doAfter(1, function()
            r(str .. ' after delay')
        end)
        return r:wait()
    end -- }}}

    d.inspectByDefault(true)
    c = machine:new({
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

            onPlay = function() print('fired play event') end,

            onEnterMenu = function() print('entering menu') end,
            onEnterGame = function() print('entering game') end,

            onLeaveMenu = function(self, name, from, to)

                -- async(function()
                --   result = delayedAction('onMenuLeave')
                --   u.p(result)
                --
                --     print('start leave menu')
                --     hs.timer.doAfter(1, function()
                --         self:transition(name)
                --     end)
                --
                --     -- tell machine to defer next state until we call transition (in fadeOut callback above)
                --     -- NOTE: return `false` to cancel transition
                -- end)
                return machine.ASYNC

            end,

            onLeaveGame = function(self,name, from, to)
                print('start leave game')
                hs.timer.doAfter(3, function()
                    self:transition(name)
                end)

                -- tell machine to defer next state until we call transition (in slideDown callback above)
                -- NOTE: return `false` to cancel transition
                return machine.ASYNC
            end,
        }
    })


    ]]   -- }}}

local Class = require 'lib.Class'
local machine = Class()

local NONE = "none"
local ASYNC = "async"

local function call_handler(handler, params)
    if handler then
        return handler(table.unpack(params))
    end
end

local function create_transition(name)  -- {{{
  local can, to, from, params

  local function transition(self, ...)
    if self.asyncState == NONE then
      can, to = self:can(name)
      from = self.current
      params = { self, name, from, to, ...}

      if not can then return false end
      self.currentTransitioningEvent = name

      local beforeReturn = call_handler(self["onBefore" .. name:capitalize()], params)
      local leaveReturn = call_handler(self["onLeave" .. from:capitalize()], params)

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

      local enterReturn = call_handler(self["onEnter" .. to:capitalize()] or self["on" .. to:capitalize()], params)

      self.asyncState = name .. "WaitingOnEnter"

      if enterReturn ~= ASYNC then
        transition(self, ...)
      end

      return true
    elseif self.asyncState == name .. "WaitingOnEnter" then
      call_handler(self["onAfter" .. name] or self["on" .. name:capitalize()], params)
      call_handler(self["onStateChange"], params)
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
end  -- }}}

-- local function create_transition(name)  -- {{{
--     local can, to, from, params
--
--     local function transition(self, ...)   -- {{{
--           -- print('  --  --  --  --  --  --  ---\ncreate transition self \n\n')
--           -- u.p(self)
--
--
--         if self.asyncState == NONE then
--             can, to = self:can(name)
--             from = self.current
--             params = { self, name, from, to, ...}
--
--             if not can then return false end
--             self.currentTransitioningEvent = name
--
--             local beforeReturn = self:onBeforeEvent(name, params)
--             local leaveReturn = self:onLeaveState(from, params)
--
--             if beforeReturn == false
--                 or leaveReturn == false then
--                 return false
--             end
--
--             self.asyncState = name .. "WaitingOnLeave"
--             if leaveReturn ~= ASYNC then
--                 transition(self, ...)
--             end
--
--             local waitingOnLeave = self.asyncState == name .. "WaitingOnLeave"
--             local waitingOnEnter = self.asyncState == name .. "WaitingOnEnter"
--
--             return true
--
--
--         elseif waitingOnLeave then
--             self.current = to
--             local enterReturn = self:onEnterState(to, params)
--             self.asyncState = name .. "WaitingOnEnter"
--             if enterReturn ~= ASYNC then
--                 transition(self, ...)
--             end
--             return true
--
--         elseif waitingOnEnter then
--             self:onAfterEvent(name, params)
--             call_handler(self["onStateChange"], params)
--             self.asyncState = NONE
--             self.currentTransitioningEvent = nil
--             return true
--
--         else
--             local waitLeave = self.asyncState:find("WaitingOnLeave")
--             local waitEnter = self.asyncState:find("WaitingOnEnter")
--             print(waitLeave)
--             print(waitEnter)
--             if waitLeave or waitEnter then
--                 self.asyncState = NONE
--                 transition(self, ...)
--                 return true
--             end
--         end
--
--         self.currentTransitioningEvent = nil
--         return false
--     end   -- }}}
--
--     return transition
-- end  -- }}}

local function add(map, event) -- {{{
if type(event.from) == 'string' then
    map[event.from] = event.to
else
    for _, from in ipairs(event.from) do
        map[from] = event.to
    end
end
end -- }}}


function machine:new(cfg) -- {{{
assert(type(cfg)=='table', 'State machine must be initialized with config')

self.current = cfg.initial or 'none'
self.asyncState = NONE
self.events = {}

self:addEvents(cfg.events or {})

for name, callback in pairs(cfg.callbacks or {}) do
    self[name] = callback
end

return self
end -- }}}

function machine:addEvents(events)
    for _, event in ipairs(events or {}) do
        local name = event.name
        self[name] = self[name] or create_transition(name)
        self.events[name] = self.events[name] or { map = {} }
        add(self.events[name].map, event)
    end
end

function machine:onBeforeEvent(eventName, params)
    local key = "onBefore" .. eventName:capitalize()
    return call_handler(self[key], params)
end

function machine:onAfterEvent(eventName, params)
    local specific = "onAfter" .. eventName:capitalize()
    local generic = "on" .. eventName:capitalize()
    return call_handler(self[specific] or self[generic], params)
end

function machine:onEnterState(stateName, params)
    local specific = "onEnter" .. stateName:capitalize()
    local generic = "on" .. stateName:capitalize()
    return call_handler(self[specific] or self[generic], params)
end

function machine:onLeaveState(stateName, params)
    local key = "onLeave" .. stateName:capitalize()
    return call_handler(self[key], params)
end


function machine:is(state) -- {{{
    return self.current == state
end -- }}}

function machine:can(e) -- {{{
    local event = self.events[e]
    local to = event and event.map[self.current] or event.map['*']
    return to ~= nil, to
end -- }}}

function machine:cannot(e) -- {{{
    return not self:can(e)
end -- }}}

function machine:todot(filename) -- {{{
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
end -- }}}

function machine:transition(event) -- {{{
if self.currentTransitioningEvent == event then
    return self[self.currentTransitioningEvent](self)
end
end -- }}}

function machine:cancelTransition(event) -- {{{
if self.currentTransitioningEvent == event then
    self.asyncState = NONE
    self.currentTransitioningEvent = nil
end
end -- }}}

machine.NONE = NONE
machine.ASYNC = ASYNC

return machine
