
-- NOTE: "insulate" is the only way I could load a new fixture in & make sure
-- the old one was forgotten. That doesn't seem right, but…
insulate('#module #stack', function()

  before_each(function()
    require 'lib.updatePackagePath'
    hs = helpers.reloadMock()

    local fixturePath = 'screen_state.three_S__seven_W_45315fe12c8ef6a1a7fbf3a3a2b013f6'
    fixture = require 'spec.fixtures.load'()
    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)
    stackline = require 'stackline.stackline'
    stackline:init()
    stack = stackline.manager:get()[1]
  end)

  it('get()', function()
    assert.is_table(stack:get())
  end)

  it('frame() is an hs.geom rect', function()
    assert.is_rect(stack:frame())
  end)

  it('eachWin()', function()
    local win_ids = {}

    stackline.manager:eachStack(function(s)
      s:eachWin(function(w)
        table.insert(win_ids, w.id)
      end)
    end)

    local numStackedWindows = #win_ids
    assert.equal(numStackedWindows, fixture.meta.num_stacked_wins)
  end)

  -- TODO: Refactor deleteAllIndicators & resetAllIndicators tests to reduce reptition
  it('deleteAllIndicators', function()
    local indicators = {}

    stackline.manager:eachStack(function(s)
      s:eachWin(function(w)
        table.insert(indicators, w.indicator.canvas)
      end)
    end)

    assert.greater_than(0, #indicators)

    local indicators_deleted = {}

    stackline.manager:eachStack(function(s)
      s:deleteAllIndicators()
      s:eachWin(function(w)
        table.insert(indicators_deleted, w.indicator.canvas)
      end)
    end)

    assert.equal(0, #indicators_deleted)
  end)

  it('resetAllIndicators', function()
    local indicators = {}
    stackline.manager:eachStack(function(s)
      s:eachWin(function(w)
        table.insert(indicators, w.indicator.canvas)
      end)
    end)

    assert.greater_than(0, #indicators)

    local indicators_deleted = {}
    stackline.manager:eachStack(function(s)
      s:deleteAllIndicators()
      s:eachWin(function(w)
        table.insert(indicators_deleted, w.indicator.canvas)
      end)
    end)

    assert.equal(0, #indicators_deleted)

    local indicators_reset = {}
    stackline.manager:eachStack(function(s)
      s:resetAllIndicators()
      s:eachWin(function(w)
        table.insert(indicators_reset, w.indicator.canvas)
      end)
    end)

    assert.equal(fixture.meta.num_stacked_wins, #indicators_reset)
  end)

end)
