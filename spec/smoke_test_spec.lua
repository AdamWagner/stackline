
describe('#main', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    helpers.reloadMock()

    state = require 'spec.fixtures.load'('screen_state.one_stack_three_windows')

    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    stackline = require 'stackline.stackline'
    stackline.config = require 'stackline.configManager'
  end)

  it('stackline:init()', function()
    stackline:init()
    assert.is_table(stackline)
    assert.is_table(stackline.manager)
  end)

  it('config:get()', function()
    stackline:init()
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    assert.is_equal(fuzzFactor, 30)
  end)

  it('config: override defaults', function()
    -- config can be passed in at start
    local customFuzzFactor = 90
    stackline:init({features = { fzyFrameDetect = { fuzzFactor = customFuzzFactor } }})
    local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    assert.is_equal(fuzzFactor, customFuzzFactor)
  end)

end)

