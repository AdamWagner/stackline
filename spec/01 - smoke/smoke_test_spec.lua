describe('#smoke', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
  end)


  describe('libs:', function()

    it('json', function()  -- {{{
        -- mocked hs.json uses https://github.com/rxi/json.lua
      local decoded = hs.json.decode('[1,2,3,{"x":10}]')
      assert.is_table(decoded)
      local encoded = hs.json.encode({1, 2, 3, {x = 10}})
      assert.is_string(encoded)
    end)  -- }}}

    it('fixture: can load specific', function()  -- {{{
      local fname = 'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574'
      fixture = require 'spec.fixtures.load'(fname)
      assert.is_table(fixture)
    end)  -- }}}

    it('fixture: can load default', function()  -- {{{
      fixture = require 'spec.fixtures.load'()
      assert.is_table(fixture)
    end)

  end)  -- }}}

  describe('stackline', function()

    before_each(function()  -- {{{
      _G.hs = helpers.reloadMock()
      helpers.reloadMock()
      fixture = require 'spec.fixtures.load'()

      hs.window.filter:set(fixture.screen.windows)
      hs.task:set(fixture.stackIndexes)

      stackline = require 'stackline.stackline'
      stackline.config = require 'stackline.configManager'
    end)  -- }}}

    describe('config', function()  -- {{{
      it("exists", function()
        stackline.config:init(require 'conf')
        assert.is_table(stackline.config)
        assert.is_table(stackline.config.schema)
        assert.is_table(stackline.config.types)
      end)

      it("with default conf", function()
        local conf = require 'stackline.conf'
        stackline.config:init(conf)
        local c = stackline.config:get()
        assert.is_table(c)
        assert.are_same(conf, c)
      end)

      it("has expected methods", function()
        stackline.config:init(require 'conf')
        assert.is_callable(stackline.config.get)
        assert.is_callable(stackline.config.set)
        assert.is_callable(stackline.config.validate)
        assert.is_callable(stackline.config.autosuggest)
      end)

    end)  -- }}}

    describe(':init()', function()  -- {{{

      it('runs', function()
        stackline:init()
        assert.is_table(stackline)
        assert.is_table(stackline.manager)
      end)

      it('with custom conf', function()
        local customFuzzFactor = 90
        stackline:init({features = { fzyFrameDetect = { fuzzFactor = customFuzzFactor } }})
        local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
        assert.is_equal(fuzzFactor, customFuzzFactor)
      end)

    end)  -- }}}

  end)

end)

