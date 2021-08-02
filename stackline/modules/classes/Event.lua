class = require 'lib.class'

local Event = class('Event')

function Event:new(key, data)
   self.key = key
   self.data = data
   self.propagate = true
   self.enabled = true
end

function Event:stopPropagation()
  self.propagate = false
end

function Event:propagate()
  return self.propagate
end

return Event
