local class = require 'lib.class'
local Event = require 'stackline.modules.EventBus'

--[[ REFERENCE / INSPO
  https://github.com/Wednesnight/lostengine/blob/master/source/resources/lost/guiro/event/EventManager.lua
]]


M = class('handleEvent')

function M:setNext(next)
  self.__next = next
  return self
end

function M:resolve(evt)
  printf('Trying to resolve in "handleEvent". Will execute if evt.id "%s" == self.id "%s"', evt.id, self.id)
  return evt.id == self.id
end

function M:handle(evt)
  print('\n\n------------------------------')
  printf('Handling event "%s" as "%s"', evt.id, self.id)

  if self:resolve(evt) then
    return self:execute(evt)

  else

    -- FIXME: "self:fail(evt)" is called once for each time that an event is propagated up the chain
    return self:propagate(evt) or self:fail(evt)

  end
end

function M:propagate(evt)
  local function propagateTo(key) -- {{{
    local next = u.is.callable(self[key]) and self[key]() or self[key]
    if next~=nil and next.handle then
      printf('\n⤴ propagating event id "%s" to "%s -> %s"', evt.id, self.id, next.id)
      return next:handle(evt)
    end
  end -- }}}

  if evt.propagate==false then self:fail(evt) end

  return 
    propagateTo('__next')
    or propagateTo('parent')
end


function M:execute(evt)
  printf('%s is executing event %s', self.id, hs.inspect(evt))

  local result = true -- TODO: write actual event handler executor

  if result then
    self:done(evt, result)
    return true
  end
end

function M:done(evt, result)
  printf('evt "%s" was successfully resolved by %s with result %s.', evt.id, self.id, hs.inspect(result))
  print('------------------------------\n')
end

function M:fail(evt)
  printf('\n\nERROR: evt "%s" can not be resolved.', evt.id)
end

return M
