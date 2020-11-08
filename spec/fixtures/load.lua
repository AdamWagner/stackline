package.path = package.path .. '/usr/local/lib/lua/5.3/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?/init.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?/init.lua;'
package.path = package.path .. '/Applications/Hammerspoon.app/Contents/Resources/extensions/?/init.lua;'

local fixtureUtils = require 'stackline.tests.fixtures.utils'

return function(fixture)  -- {{{
    -- get specified fixture data (or default), process, and return
  fixture = fixture or 'two_stacks_six_windows'
  local data = require('tests.fixtures.data.' .. fixture)
  local result =  fixtureUtils.process(data)
  return result
end  -- }}}


