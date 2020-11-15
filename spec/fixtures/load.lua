local fixtureUtils = require 'spec.fixtures.utils'

local DEFAULT_FIXTURE = 'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574'

return function(fixture)
    -- get specified fixture data (or default), process, and return
  fixture = fixture or DEFAULT_FIXTURE
  local data = require('spec.fixtures.data.' .. fixture)
  local result =  fixtureUtils.process(data)
  return result
end


