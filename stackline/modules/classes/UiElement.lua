local class = require 'lib.class'

local UiElement = class('UiElement')
  :use('loggable')
  :use('framed')
  :use('hidePrivate')

function UiElement:call(m) --[[
  Call a method in a callback like this:
  u.map(hs.window.filter(), stackline.window:call('new')) ]]
  return u.bind(self[m], self)
end

function UiElement:listen(events, handlerName)
  -- Convert an event name to a handler method name
  -- E.g., 'windowCreated' -> 'onWindowCreated'
  handlerName = type(handlerName)=='string' and 'on'..handlerName:capitalize() or 'None'

  self.log.f('Listening for events:  %s · Custom handler fn: <%s>', hs.inspect(events), handlerName)

  local handler = handlerName~='None'
    and self:call(handlerName) -- Call the specific handler name if present.
    or self:call('handleEvent') -- Otherwise call `handleEvent` to dispatch the desired handler

  -- TODO: The var names of hs.window.filter (`wf`) varies among the consumers of this base class :/
  -- This is very messy and needs to be cleaned up.
  local wf = self._wf or self.wf or self._stack._wf

  wf:subscribe(events, handler)
end

function UiElement:unlisten()
  self._wf:unsubscribeAll()
end

function UiElement:handleEvent(...)
  local handlerName = 'on'..group:capitalize()
  self[handlerName](self, ...)

  if hswin:id() == self.id then
    self['on'..evt:capitalize()](self)
  end
end

return UiElement
