local u = require 'lib.utils'
local test_utils = helpers.test_utils
local is_stackline_indicator = helpers.schemas.entities.is_stackline_indicator

describe('#module #indicator', function()

  setup(function()
    hs = helpers.reloadMock()
    local fixturePath = 'screen_state.three_S__seven_W_45315fe12c8ef6a1a7fbf3a3a2b013f6'
    fixture = test_utils.applyFixture(fixturePath)
    test_utils.startStackline(fixture)
  end)

  it('exists for each stacked win', function()
    local indicators = {}
    stackline.manager:eachWin(function(w)
        table.insert(indicators, w.indicator)
    end)
    u.p(indicators[1])

    local indicator_keys = {"side", "rectIdx", "iconIdx", "canvas_rect", "canvas", "radius", "screen", "c", "showIcons", "frame", "width", "iconRadius", "stackFocus", "screenFrame", "fadeDuration", "icon_rect" }

    -- u.p(u.keys(u.omit(indicators[1], 'win', 'config')))
    u.p(u.omit(indicators[1], 'win', 'config'))


    assert.equals(fixture.meta.num_total_wins, #indicators)



  end)

  it('match schema', function()
    stackline.manager:eachWin(function(w)
      local indicator = u.omit(w.indicator, 'config', 'win')
      local ok, err = is_stackline_indicator(indicator)
      if not ok then assert.is_true(err) end
    end)
  end)




  it('Experiment with spies & mocks', function()
    stackline.manager = mock(stackline.manager)
    stackline.window = mock(stackline.window)

    stackline.manager:update()
    stackline.manager:update()

    -- u.p(stackline.manager)
    -- assert.spy(stackline.manager.update).was_called(2)


    -- hs.logger.new('test')
    -- hs.logger.new('testing')
    -- hs.logger.new('tested')
    -- assert.spy(hs.logger.new).was_called_with('test')
    -- assert.spy(hs.logger.new).was_called(3)
  end)


end)
