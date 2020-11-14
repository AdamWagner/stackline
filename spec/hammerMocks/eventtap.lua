-- STACKLINE REFERENCES:
--    hs.eventtap.event.types
--    hs.eventtap.new
-- -----------------------------------------------------------------------------

-- ———————————————————————————————————————————————————————————————————————————
-- hs.eventtap mock
-- ———————————————————————————————————————————————————————————————————————————
local e = require 'lib.event'()

eventtap = {
  event = {
      types = {
        leftMouseDown = 1
      },
  },
}

function eventtap.new(evts, fn)
  local o = { fn = fn, enabled = false }
  setmetatable(o, eventtap)
  eventtap.__index = eventtap

  evts = type(evts)=='table' and evts or {evts}
  for i,evt in pairs(evts) do
    e:on(tostring(evt), function(...)
      if eventtap.enabled then
        fn(...)
      end
    end)
  end

  return o
end

function eventtap:isEnabled()
  return self.enabled
end

function eventtap:start()
  self.enabled = true
  return self
end

function eventtap:stop()
  self.enabled = false
    return self
end

return eventtap

