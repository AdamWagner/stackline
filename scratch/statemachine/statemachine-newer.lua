-- FROM: https://github.com/ieu/lua-state-machine/blob/master/state-machine.lua

--[[

machine = require 'lib.statemachine-newer'
d.inspectByDefault(true)
c = machine.create({
    initial = 'quit',
    events = {
        { name = 'play', from = 'quit', to = 'game' },
        { name = 'quit', from = 'play', to = 'quit' }
    },

    callbacks = {
        onentermenu = function() print('entering menu') end,
        onentergame = function() print('entering game') end,

        onleavequit = function(self, name, from, to)
            print('start leave menu')
            hs.timer.doAfter(1, function()
                u.p(self)
                -- self:transit()
            end)

            -- tell machine to defer next state until we call transition (in fadeOut callback above)
            -- NOTE: return `false` to cancel transition
            return 1000
        end,

        onleaveplay = function(self,name, from, to)
            print('start leave game')
            hs.timer.doAfter(3, function()
                u.p(self)
                -- self:transit()
            end)

            -- tell machine to defer next state until we call transition (in slideDown callback above)
            -- NOTE: return `false` to cancel transition
            return 1000
        end,
    }
})

--]]


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

local do_callback = function(fsm, callback, name, from, to, args)
    if not callback then
        return
    end
    return callback(name, from, to, unpack(args))
end

local before_event = function(fsm, name, from, to, args)
    do_callback(fsm, fsm["onbeforeevent"], name, from, to, args)
    do_callback(fsm, fsm["onbefore" .. name], name, from, to, args)
end

local after_event = function(fsm, name, from, to, args)
    do_callback(fsm, fsm["onafterevent"], name, from, to, args)
    do_callback(fsm, fsm["onafter" .. name], name, from, to, args)
end

local leave_state = function(fsm, name, from, to, args)
    local generic = do_callback(fsm, fsm["onleavestate"], name, from, to, args)
    local specific = do_callback(fsm, fsm["onleave" .. from], name, from, to, args)

    if STATEMACHINE.ASYNC == generic or STATEMACHINE.ASYNC == specific then
        return STATEMACHINE.ASYNC
    end
end

local enter_state = function(fsm, name, from, to, args)
    do_callback(fsm, fsm["onenterstate"], name, from, to, args)
    do_callback(fsm, fsm["onenter" .. to], name, from, to, args)
end

local register_callback = function(target, callbacks)
    for name, callback in pairs(callbacks) do
        assert(type(target) == "table", string_format("table type expected but %s received", name))
        assert(type(callback) == "function", string_format("function type expected but %s received", callback))
        target[name] = callback
    end
end

local StateMachine = {
    is = function(self, state)
        return self.current == state
    end,

    can = function(self, event)
        assert(type(event) == "string", string_format("Invalid event type: %s, string expected", type(event)))
        local to = self.events[event][self.current] or self.events[event][STATEMACHINE.WILDCARD]
        return to
    end,

    cannot = function(self, event)
        return not self:can(event)
    end,

    register = register_callback
}

local empty_transit = function() end

local build_event = function(name, map)
    return function(self, ...)
        local args = { ... } or {}
        local from = self.current
        local to = self.events[name][from] or self.events[name][STATEMACHINE.WILDCARD] or from

        assert(self.transit == empty_transit, "Previous transition not complete")
        assert(self:can(name), string_format('Event %s inappropriate in current state %s', name, from))
        if from == to then
            after_event(self, name, from, to, args)
            return STATEMACHINE.RESULT.NOTRANSITION
        end

        function self:transit()
            self.transit = empty_transit
            self.current = to
            enter_state(self, name, from, to, args)
            after_event(self, name, from, to, args)
            return STATEMACHINE.RESULT.SUCCEEDED
        end

        function self:cancel()
            if self.transit == empty_transit then
                return
            end
            self.transit = empty_transit
            after_event(self, name, from, to, args)
            return STATEMACHINE.RESULT.CANCELLED
        end

        before_event(self, name, from, to, args)
        if STATEMACHINE.ASYNC == leave_state(self, name, from, to, args) then
            return STATEMACHINE.RESULT.PENDING
        elseif self.transit then
            return self:transit()
        end
    end
end

local create = function(configs, target)
    assert(type(configs) == "table", string_format("Invalid configs type: %s, table expected", type(configs)))

    local initial = configs.initial
    local events = configs.events
    local callbacks = configs.callbacks or {}

    assert(type(initial) == "string", string_format("Invalid initial type: %s, string expected", type(initial)))
    assert(type(events) == "table", string_format("Invalid events type: %s, table expected", type(events)))
    assert(type(callbacks) == "table", string_format("Invalid callbacks type: %s, table expected", type(callbacks)))
    assert(not target or type(target) == "table", string_format("Invalid target type: %s, table expected", type(target)))
    local fsm = target or {}
    fsm.current = initial
    fsm.events = {}
    for _, event in ipairs(events) do
        assert(type(event) == "table", string_format("Invalid event type: %s, string expected", type(event)))
        fsm.events[event.name] = fsm.events[event.name] or {}
        fsm.events[event.name][event.from] = event.to
        fsm[event.name] = build_event(event.name, fsm.events[event.name])
    end
    register_callback(fsm, callbacks)
    fsm.transit = empty_transit
    setmetatable(fsm, { __index = StateMachine })

    return fsm
end

return {
    create = create
}
