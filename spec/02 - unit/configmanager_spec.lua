describe('#module #configmanager', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    hs.logger:setLogLevel('nothing')

    state = require 'spec.fixtures.load'()
    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    stackline = require 'stackline.stackline.stackline'
    stackline.config = require 'stackline.stackline.configManager'
  end)

  it("exists", function()
    stackline.config:init(require 'conf')
    assert.is_table(stackline.config)
    assert.is_table(stackline.config.schema)
    assert.is_table(stackline.config.types)
  end)

  it("has methods", function()
    stackline.config:init(require 'conf')
    assert.is_callable(stackline.config.get)
    assert.is_callable(stackline.config.set)
    assert.is_callable(stackline.config.validate)
    assert.is_callable(stackline.config.autosuggest)
  end)

  it("returns default config", function()
    local conf = require 'stackline.conf'
    stackline.config:init(conf)
    assert.same(conf, stackline.config:get())
  end)

  it("fails with invalid conf", function()  -- {{{
    local conf = require 'conf'
    conf.appearance.dimmer = nil
    local _, ok, err = stackline.config:init(conf)
    assert.is_false(ok)
    assert.contains_key(err.appearance, 'dimmer')
  end)  -- }}}

  it('get() key works', function()
    local features = stackline.config:get('features')
    assert.are.same({enabled = true, fuzzFactor = 30}, features.fzyFrameDetect)
  end)

  it('get() dotted path works', function()
    local fzyFrameDetect = stackline.config:get('features.fzyFrameDetect')
    -- print(hs.inspect(features))
    assert.same({enabled = true, fuzzFactor = 30}, fzyFrameDetect)
  end)

  it('set() dotted path works', function()
    local expected = 55
    stackline.config:set('features.fzyFrameDetect.fuzzFactor', expected)
    local result = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
    assert.is_equal(result, expected)
  end)

  it('getorSet() dotted path works', function()
    local a = 12
    stackline.config:set('features.fzyFrameDetect.fuzzFactor', a)
    local b = stackline.config:getOrSet('features.fzyFrameDetect.fuzzFactor')
    assert.is_equal(a, b)

    local c = 12
    stackline.config:getOrSet('features.fzyFrameDetect.fuzzFactor', c)
    local d = stackline.config:getOrSet('features.fzyFrameDetect.fuzzFactor')
    assert.is_equal(d, c)
  end)

  it('autosuggest', function()
    local suggestion = stackline.config:autosuggest('fuzz')
    assert.is_equal('features.fzyFrameDetect.fuzzFactor', suggestion)
  end)

  it('toggle', function()
    stackline.config:set('appearance.showIcons', true)
    local current = stackline.config:get('appearance.showIcons')
    assert.is_true(current)

    stackline.config:toggle('appearance.showIcons')
    local toggled = stackline.config:get('appearance.showIcons')
    assert.is_false(toggled)
    assert.not_equal(current, toggled)
  end)

  pending('events', function()
    -- TODO: test that events fire when values are changed
    return false
  end)

end)

