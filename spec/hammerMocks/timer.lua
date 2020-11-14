local sleep = require 'lib.utils'.sleep

-- Original src: /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/timer/init.lua
-- See https://github.com/vocksel/Timer for reference implementation

local timer = {}

function timer.new(interval, fn)
end

function timer.doAfter(delay, fn)
  -- USAGE:
  -- hs.timer.doAfter(1, function() self:getWinStackIdxs() end)
  sleep(delay)
  fn()
end

timer.delayed = {
  new = function(delay, fn)
    local tmr = { delay = delay, fn = fn, }
    return {
      start = function(self)
        sleep(tmr.delay)
        tmr.fn()
        return self
      end,
      stop = function(self) end,
      nextTrigger = function() end,
      running = function(self) end,
      setDelay = function(self, dl) end,
    }
  end,
}

return timer
