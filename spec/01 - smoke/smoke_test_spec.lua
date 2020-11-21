describe('#smoke', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    helpers.reloadMock()
    fixture = require 'spec.fixtures.load'()

    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)

    stackline = require 'stackline.stackline'
    stackline.config = require 'stackline.configManager'
  end)


    describe(':init()', function()

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

    end)

  end)

