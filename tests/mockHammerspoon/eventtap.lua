local log = helpers.logSetup('mock_eventtap')
local e = require 'stackline.lib.event'()

-- LIB REFERENCE {{{
  -- https://github.com/flameleo11/lua-events
  -- https://github.com/friesencr/lua_emitter/tree/master/src
  -- https://github.com/gillern/Signal (relatively unique approach)
  --
  -- Super interesting, probably what I want
  -- https://github.com/develephant/Eventable
  --
  -- Newer, and really tiny
  --    https://github.com/u-train/events/blob/master/event.lua INTERESTING (no metatable)
  --    https://github.com/Warlik50/event
  --    https://github.com/ThetaCC/eventMan/blob/master/eventMan.lua
  --    https://github.com/EmeraldFramework/Events/blob/master/events.lua
  --    TINY! https://github.com/ScriptingSausage/Lua-events
  --    22d old, 66 lines: https://github.com/prabirshrestha/lua-eventbus/blob/master/eventbus.lua
  --        Factored out of vis (editor) https://github.com/martanne/vis/tree/master/lua
  --
  -- related: using coroutines to synchronize events
  --    https://github.com/renatomaia/coutil
  --    https://github.com/thislight/away/blob/master/away.lua
  --
  -- RANDOM
  --    - cool game dev helpers (unique)

  -- Made for warcraft, but actually looks pretty neat!
  -- Can attach to table fields
  --    https://github.com/Indaxia/lua-eventDispatcher

  -- INspo from game: Better mouse events for roblox:
  -- https://github.com/brianush1/rbx-bettermouse/blob/master/init.lua
-- }}}

-- Stackline uses:
-- hs.eventtap.event.types
-- hs.eventtap.new
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
    log.d('registering', evt)
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

