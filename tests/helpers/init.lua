-- print('Primis eleifend litora luctus a magnis neque, fames sociis ullamcorper sollicitudin ridiculus lacinia, taciti orci adipiscing ante faucibus. Habitant netus porttitor nam molestie natoque enim adipiscing parturient himenaeos, nullam luctus aenean porta tristique dis faucibus ipsum metus nunc, quis fringilla mollis volutpat conubia fermentum convallis laoreet. Vestibulum tristique mollis porta aliquam dapibus congue etiam ligula sapien volutpat vitae morbi, dictum integer nullam faucibus fames facilisis consequat praesent primis hac. Enim dapibus consequat dolor consectetur himenaeos adipiscing eros conubia, pellentesque urna ullamcorper id donec litora interdum senectus, primis praesent et cursus velit commodo magna.  Imperdiet volutpat ut habitant litora orci cubilia suscipit, taciti bibendum facilisi mauris vitae molestie facilisis ante, donec duis porttitor ultrices massa dictumst. Porta lorem facilisi ullamcorper erat ridiculus natoque, neque lacus phasellus et sollicitudin dictumst class, pulvinar quam ultricies accumsan pretium. Quisque euismod mi penatibus commodo amet nam, class consectetur eros mus mattis, dignissim erat viverra lobortis inceptos. Congue lobortis condimentum orci auctor platea facilisi, mollis curabitur nam non etiam, quis tempus at pulvinar inceptos.  Dui odio torquent malesuada nibh turpis ad aenean venenatis placerat hac, nisi amet tincidunt nec conubia scelerisque sollicitudin cubilia aliquam arcu, ligula faucibus molestie parturient at interdum morbi tristique convallis. Ullamcorper libero in molestie class morbi cras litora lacus suscipit dui, mollis vivamus luctus platea curae volutpat vitae accumsan tempus facilisis leo, posuere eros tortor etiam iaculis condimentum laoreet natoque aliquet. Enim quam sagittis nunc lacinia suscipit lacus rhoncus luctus facilisis, ad est curae ipsum aliquet et curabitur cras class, morbi odio sed laoreet hendrerit ut suspendisse tempus. Purus dictumst ipsum suspendisse dis orci cras convallis ante aenean imperdiet, fermentum lectus aliquam nisi urna phasellus nisl rutrum. Faucibus per dictum potenti dictumst venenatis viverra quam augue habitant ultrices, iaculis neque dignissim eros suscipit tellus sem litora fermentum diam quisque, vivamus curae accumsan nullam lacus eget enim habitasse consequat. Habitasse pretium mollis dapibus laoreet duis pharetra mauris augue vulputate, habitant tellus nullam ullamcorper sapien tempor rhoncus curae feugiat lorem, ipsum praesent donec vehicula litora suscipit nisl placerat.')

package.path = package.path .. '/usr/local/lib/lua/5.3/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?/init.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?/init.lua;'
package.path = package.path .. '/Applications/Hammerspoon.app/Contents/Resources/extensions/?/init.lua;'

-- ┌─────┐
-- │ RSC │
-- └─────┘
-- 
-- Super sophisticated helpers: fixture loader, default before/after funcs, stubbing, etc
-- Huge, well-organized spec folder
--    https://github.com/kevbrain/apicastsix/blob/master/spec/spec_helper.lua
--    https://github.com/myrepo5588/apicast/blob/master/spec/spec_helper.lua
--    See fixtures: https://github.com/kevbrain/apicastsix/tree/master/spec/fixtures
--    See complex tests: 
--        https://github.com/kevbrain/apicastsix/blob/master/spec/mapping_rule_spec.lua
--        https://github.com/kevbrain/apicastsix/blob/master/spec/mapping_rules_matcher_spec.lua
--        https://github.com/kevbrain/apicastsix/blob/master/spec/configuration_store_spec.lua


-------------------------------------------------------------------------------


-- local asyncTest = {}  -- {{{

-- local mt = {}
-- function asyncTest:run(fn)
--   self:reset()
--   local r = async(fn)
--   while self.resolved ~= false  do
--     return self:get('resolved')
--   end
-- end

-- mt.__index = {resolved = false}
-- setmetatable(asyncTest, mt)
-- function asyncTest:reset() self.resolved = false end
-- function asyncTest:set(key, val) self[key] = val end
-- function asyncTest:get(key) return self[key] end
--   -- }}}

-- local function setupFile()  -- {{{
--   _G.hs = helpers.reloadMock()
--   _G.async = require 'stackline.lib.async'
-- end  -- }}}

local function loadFixture()  -- {{{
  state = require 'tests.fixtures.load'(
      'screen_state.two_stacks_four_windows_84d20a6f24b84ce33e790e50543fcb23')
    -- state = require 'tests.fixtures.load'('screen_state.one_stack_three_windows')

  hs.window.filter:set(state.screen.windows)
  hs.task:set(state.stackIndexes)

  wf = hs.window.filter.new()
  ws = wf:getWindows()
end  -- }}}

-- local function initStackline()  -- {{{
--   stackline = require 'stackline.stackline.stackline'
--   stackline.config = require 'stackline.stackline.configManager'
--   stackline.config:init(require 'stackline.conf')
--   stackline.manager = require('stackline.stackline.stackmanager'):init()
--   Query = require('stackline.stackline.query')
--   hs.logger.setGlobalLogLevel(0)   -- control chattiness of app printing in tests
-- end  -- }}}


  local function ensureHsLoggerDeps()
      -- define hs.printf right away bc hs.logger (unnecessarily!) depends on it
    _G.hs = { printf = function(fmt,...) return print(string.format(fmt,...)) end }
  end 
ensureHsLoggerDeps()


function logSetup(module)  -- {{{
    -- Load hs.logger if needed
    -- Removing the conditions causes a crash?!
    --    tests/tests_functional/core/stack_tests.lua:9: attempt to index a nil value (field 'window')
  -- if not _G.hs or not _G.hs.logger then
  --   -- ensureHsLoggerDeps()
  --   _G.hs.logger = require 'hs.logger'
  -- end

  -- local log = _G.hs.logger.new(module, 0)
  local log =  { i = function(m) print(m) end, d = function(m) print(m) end, }
  log.i("Loading " .. module)
  return log
end  -- }}}


assert = require 'luassert'
require 'tests.helpers.assertions'
match = require 'luassert.match'
spy = require 'luassert.spy'

-- _G.u = require 'stackline.lib.utils'

_G.helpers = {
  reloadMock = require 'tests.helpers.reload_mock',
  methodSpy = require 'tests.helpers.methodSpy',
  -- asyncTest = asyncTest, 
  -- setupFile = setupFile, 
  loadFixture = loadFixture, 
  -- initStackline = initStackline, 
  logSetup = logSetup, 
}

