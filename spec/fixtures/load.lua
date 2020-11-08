local fixtureUtils = require 'spec.fixtures.utils'

return function(fixture)
    -- get specified fixture data (or default), process, and return
  fixture = fixture or 'two_stacks_six_windows'
  local data = require('spec.fixtures.data.' .. fixture)
  local result =  fixtureUtils.process(data)
  return result
end


