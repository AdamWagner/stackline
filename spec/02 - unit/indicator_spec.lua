describe('#module indicator', function()

  -- setup(function()
  --   local  = mock(t, true)
  -- end)

  before_each(function()
    require 'lib.updatePackagePath'
    u = require 'lib.utils'
    _G.hs = helpers.reloadMock()

    local fixturePath = 'screen_state.three_S__seven_W_45315fe12c8ef6a1a7fbf3a3a2b013f6'
    fixture = require 'spec.fixtures.load'()
    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)
    stackline = mock(require 'stackline.stackline')
    -- stackline.window = require 'stackline.window'
    stackline:init()
  end)

  it('new()', function()

    -- stackline.manager:eachStack(function(s)
    --   s:resetAllIndicators()
    --   s:eachWin(function(w)
    --     table.insert(indicators_reset, w.indicator.canvas)
    --   end)
    -- endn)

    stackline.manager = mock(stackline.manager)
    stackline.window = mock(stackline.window)

    stackline.manager:update()
    stackline.manager:update()

    -- u.p(stackline.manager)
    assert.spy(stackline.manager.update).was_called(2)


    -- hs.logger.new('fuck')
    -- hs.logger.new('fucking')
    -- hs.logger.new('fucked')
    -- assert.spy(hs.logger.new).was_called_with('fuck')
    -- assert.spy(hs.logger.new).was_called(3)
  end)

end)
