describe('#module #configmanager', function()

  before_each(function()
    hs = helpers.reloadMock()
    stackline = nil
    hs.logger:setLogLevel('nothing')

    state = require 'spec.fixtures.load'()
    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    stackline = require 'stackline.stackline.stackline'
    stackline:init()
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

  it("fails with invalid conf", function()
    local conf = require 'conf'
    conf.appearance.dimmer = nil
    local _, ok, err = stackline.config:init(conf)
    assert.is_false(ok)
    assert.contains_key(err.appearance, 'dimmer')
  end)

  it("returns default config", function()
    local conf = require 'stackline.conf'
    stackline.config:init(conf)
    assert.same(conf, stackline.config:get())
  end)

  describe('get()', function()
    it('key', function()
      local features = stackline.config:get('features')
      local default = require 'conf'
      assert.are.same(default.features.fzyFrameDetect, features.fzyFrameDetect)
    end)

    it('dotted path', function()
      local fzyFrameDetect = stackline.config:get('features.fzyFrameDetect')
      local default = require 'conf'
      assert.same(default.features.fzyFrameDetect, fzyFrameDetect)
    end)

    it('last non-nil val', function()
      local onChangeEvtsTbl = stackline.config.events
      local lastNonNil = u.getfield('appearance.radius', stackline.config.events, {lastNonNil = true})
      assert.is_callable(lastNonNil)
      assert.is_function(lastNonNil)
    end)
  end)

  describe('set()', function()
    it('dotted path', function()
      local expected = 55
      stackline.config:set('features.fzyFrameDetect.fuzzFactor', expected)
      local result = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
      assert.is_equal(result, expected)
    end)
  end)

  it('getorSet() dotted path', function()
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

  describe('onChange:', function()
    it('run when val set', function()
      local resetSpy = spy.on(stackline.manager, 'resetAllIndicators')

      assert.spy(resetSpy).was_not_called()

      stackline.config:set('appearance.radius', 2)
      assert.spy(resetSpy).was_called(1)
    end)

    it('run when val set repeatedly', function()
      local resetSpy = spy.on(stackline.manager, 'resetAllIndicators')

      assert.spy(resetSpy).was_not_called()

      stackline.config:set('appearance.radius', 4)
      stackline.config:set('appearance.radius', 3)
      stackline.config:set('appearance.radius', 2)
      stackline.config:set('appearance.radius', 1)
      assert.spy(resetSpy).was_called(4)
    end)

    it('not run when new val == oldVal', function()
      local resetSpy = spy.on(stackline.manager, 'resetAllIndicators')

      assert.spy(resetSpy).was_not_called()

      local curr = stackline.config:get('appearance.radius')
      local new = curr + 1

      stackline.config:set('appearance.radius', new)
      assert.spy(resetSpy).was_called(1)

      stackline.config:set('appearance.radius', new)
      stackline.config:set('appearance.radius', new)
      assert.spy(resetSpy).was_called(1) -- still just called once
    end)
  end)


end)

