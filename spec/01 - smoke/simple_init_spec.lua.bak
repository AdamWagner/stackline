-- local log = hs.logger.new('tests_initialization')
-- log.setLogLevel('info')
-- log.i("Loading'tests_initialization")

describe('#main', function()

  before_each(function()
    _G['hs'] = helpers.reloadMock()
    _G['u'] = require 'stackline.lib.utils'
    package.loaded['hs.ipc'] = true

    state = require 'tests.fixtures.load'('screen_state.one_stack_three_windows')

    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    -- log = helpers.logSetup('test_configmanager')

    -- stackline = nil
    -- _G.stackline = nil
    -- package.loaded['stackline'] = false
    -- u.p(stackline)

    stackline = require 'stackline.stackline.stackline'{_hs=_G.hs}
  end)

  it('stackline:init()', function()

    -- config can be passed in at start
    local fuzzFactor
    stackline:init()

    local actualFuzzFactor = stackline.config:get('features.fzyFrameDetect')
    -- assert.is_equal(fuzzFactor, actualFuzzfactor)


    -- u.p(stackline.manager:getSummary())
    -- u.p(stackline.manager:get()[1].windows[1]._win:title())
    -- u.p(stackline.manager:get()[1].windows[1].indicator)
    -- u.p(stackline)
  end)

  pending('stackline.config', function()
    -- config can be passed in at start
    stackline:init({features = { fzyFrameDetect = { fuzzFactor = 90 } }})
    u.p(stackline.config:get('features.fzyFrameDetect'))
  end)

end)
