
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

  it('fixtures can be loaded', function()
    local fname = 'manager_ingest.2_groups_3_appwindows_375a7ad1f9b6eaa76001ccc7d73d8581'
    state = require 'spec.fixtures.load'(fname)
    assert.is_table(state)
  end)

  it('json lib', function()
    -- mocked hs.json uses https://github.com/rxi/json.lua
    local decoded = hs.json.decode('[1,2,3,{"x":10}]')
    assert.is_table(decoded)
    local encoded = hs.json.encode({ 1, 2, 3, { x = 10 } })
    assert.is_string(encoded)
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

