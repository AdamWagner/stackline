
describe('#main', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    helpers.reloadMock()
    state = require 'spec.fixtures.load'('screen_state.one_stack_three_windows')

    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    stackline = require 'stackline.stackline.stackline'
    stackline.config = require 'stackline.stackline.configManager'
  end)

  it('stackline:init()', function()
    stackline:init()
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect')
    assert.is_equal(fuzzFactor, 30)
  end)

  pending('stackline.config', function()
    -- config can be passed in at start
    local customFuzzFactor = 90
    stackline:init({features = { fzyFrameDetect = { fuzzFactor = customFuzzFactor } }})
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect')
    assert.is_equal(fuzzFactor, customFuzzFactor)
  end)

end)

