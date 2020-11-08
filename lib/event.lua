--
-- Create by ray studio
-- 2019-11-22
--

local Event = {}
Event.__index = Event


function Event:new()
    self._handlers = {}
end

function Event:dispatch(type, ...)
    local handlers = self:_getEventHandlers(type, false)
    if handlers then
        for _, k in ipairs(handlers) do
            if not k.instance then
                k.handler(...)
            else
                k.handler(k.instance, ...)
            end
        end
    end
end

function Event:on(type, handler, instance)
    local handlers = self:_getEventHandlers(type, true)
    table.insert(handlers, {
        instance = instance,
        handler = handler
    })
    return self
end

function Event:remove(type, handler)
    local handlers = self:_getEventHandlers(type, false)
    if handlers then
        for i = #handlers, 1, -1 do
            if handlers[i].handler == handler then
                table.remove(handlers, i)
            end
        end
    end
end

function Event:clear(type)
    if type then
        if self._handlers[type] then
            self._handlers[type] = nil
        end
    else
        self._handlers = {}
    end
end

function Event:_getEventHandlers(type, create)
    local ret = self._handlers[type]
    create = create or false
    if not ret and create then
        ret = {}
        self._handlers[type] = ret
    end

    return ret
end

function Event:__tostring()
    return 'Event'
end

function Event:__call(...)
    local obj = setmetatable({}, Event)
    obj:new(...)
    return obj
end

return setmetatable({}, Event)
