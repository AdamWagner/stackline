local fixtureUtils = require 'spec.fixtures.utils'

-- local DEFAULT_FIXTURE = 'screen_state.one_S__three_W_ad24dbe2c27924edb669be1459ffaa11'
-- local DEFAULT_FIXTURE = 'screen_state.one_S__two_W_802717a1287ed5d75a5fcd2bc672974c'
local DEFAULT_FIXTURE = 'screen_state.three_S__seven_W_45315fe12c8ef6a1a7fbf3a3a2b013f6'
-- local DEFAULT_FIXTURE = 'screen_state.two_S__five_W_7c100e413a1d0a4b53923d40c66eb5f1'
-- local DEFAULT_FIXTURE = 'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574'

return function(fixture)
    -- get specified fixture data (or default), process, and return
  fixture = fixture or DEFAULT_FIXTURE
  local data = require('spec.fixtures.data.' .. fixture)
  local result =  fixtureUtils.process(data)
  return result
end


