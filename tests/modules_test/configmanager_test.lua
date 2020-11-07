describe('#module configmanager', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    log = helpers.logSetup('test_configmanager',0)
    hs.logger.setGlobalLogLevel(0)
    hs.logger.setModulesLogLevel(0)

    state = require 'tests.fixtures.load'('screen_state.one_stack_three_windows')
    hs.window.filter:set(state.screen.windows)
    hs.task:set(state.stackIndexes)

    stackline = require 'stackline.stackline.stackline'
    stackline.config = require 'stackline.stackline.configManager'
  end)

  it("exists", function()
    stackline.config:init()
    assert.is_table(stackline.config)
    assert.is_table(stackline.config.schema)
    assert.is_table(stackline.config.types)
  end)

  it("has expected methods", function()
    stackline.config:init()
    assert.is_callable(stackline.config.get)
    assert.is_callable(stackline.config.set)
    assert.is_callable(stackline.config.validate)
    assert.is_callable(stackline.config.autosuggest)
  end)


  it("returns default config", function()
    local conf = require 'stackline.conf'
    stackline.config:init(conf)
    local c = stackline.config:get()
    assert.is_table(c)
    assert.are_same(conf, c)
  end)

  pending("thing another thing", function() 
    return false
  end)

  pending("returns invalid when init w incomplete conf", function()  -- {{{
      -- TODO: validate method currently has no return value, just a side effect (hs.notify)
    local conf = require 'stackline.conf'
    conf.appearance.dimmer = nil
    stackline.config:init(conf)

      -- TODO: to spy on hs fns, hs *must* be passed in to stackline modules
      -- Alternatively, use a lib that auto-spies all methods

      -- local s = spy.on(hs.notify, 'new')
      -- stackline.config:init(conf)
      -- assert.spy(s).was.called_with(match._)

    local c = stackline.config:get()
      -- assert.is_table(c)
      -- print(hs.inspect(c))
    assert.are_same(conf, c)
  end)  -- }}}

  it('get() key works', function()
    local features = stackline.config:get('features')
    -- print(hs.inspect(features))
    assert.are.same({enabled = true, fuzzFactor = 30}, features.fzyFrameDetect)
  end)

  it('get() dotted path works', function()
    local fzyFrameDetect = stackline.config:get('features.fzyFrameDetect')
    -- print(hs.inspect(features))
    assert.are.same({enabled = true, fuzzFactor = 30}, fzyFrameDetect)
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

  describe('validator', function()  -- {{{
    num = stackline.config.generateValidator('number')
    str = stackline.config.generateValidator('string')
    bool = stackline.config.generateValidator('boolean')

    it('number (success)', function()
      local r = num(5)
      assert.is_true(r)
    end)

    it('number (fail)', function()
      local r = table.pack(num('adam'))
      local expected = {false,	'adam is not a number.', n = 2}
      assert.are.same(r, expected) 
    end)

    it('string (success)', function()
      local s = 'test string'
      local r = str(s)
      assert.is_true(r)
    end)

    it('string (fail)', function()
      local s = 5
      local r = table.pack(str(s))
      local expected = { false, '5 is not a string.', n = 2}
      assert.are.same(r, expected)
    end)

    it('bool (success)', function()
      local b = false
      local r = bool(b)
      assert.is_true(r)
    end)

    it('bool (fail)', function()
      local b = 'false'
      local isValid, msg = bool(b)
      assert.is_false(isValid)
      local msgExpected = 'false is not a boolean.'
      assert.are.same(msg, msgExpected)
    end)

    it('tbl (success)', function()
      local t = {one = 'is the loneliest', num = 'ber'}

        -- dynamically build nested schema based on supplied table 't'
      local tbl = stackline.config.generateValidator(t)
      local r = tbl(t)
      assert.is_true(r)
    end)

    it('tbl (fail)', function()
      local t = {one = 'is the loneliest', num = 'ber'}

        -- Child *values* are not validated (keys are tho)
        -- So 'two' will fail (wrong key), but '5' won't (values aren't validated)
        -- To validate the values, you need to call the matching key in the
        -- validator table on the value-to-validate.
      local t1 = {two = 5, num = 5} 

        -- Dynamically build nested schema (tbl) based on supplied table 't'
        -- Key values will be functions that need to be called on the values of
        -- the table to test. Calling on table as a whole will only test that keys
        -- are the same.
      local tbl = stackline.config.generateValidator(t)

      local isValid, msg = tbl(t1)
      local isValidExpected, msgExpected = false, { two = "is not allowed." }

      assert.is_false(isValid)
      assert.are_same(msg, msgExpected)
    end)

  end)  -- }}}


end)

