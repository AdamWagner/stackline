local u = require 'lib.utils'

describe('#module #window', function()

  setup(function()
    require 'lib.updatePackagePath'
    hs = helpers.reloadMock()

    testSchema = helpers.schemas.testGen.testSchema

    -- TODO: use scenario helper to run suite on all fixtures
    local fixturePath = 'screen_state.three_S__seven_W_45315fe12c8ef6a1a7fbf3a3a2b013f6'
    fixture = require 'spec.fixtures.load'()

    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)

    stackline = mock(require 'stackline.stackline')
    stackline:init()
  end)

  it('new()', function()  -- {{{

      -- build 2 spies (called / called with) for an object with self:method() methods
    local makeStackId_called, makeStackId_called_with =
          helpers.methodSpy(
              stackline.window,   -- object
              'makeStackId'       -- method
            )

    local configGet_called, configGet_called_with =
            helpers.methodSpy(
              stackline.config,   -- object
              'get'               -- method
            )

    -- for each of the windows in the fixture, create stackline window & spy on calls made within
    for k,v in pairs(fixture.screen.windows) do
      local hsWin = hs.window:new(v)
      local win = stackline.window:new(hsWin)

        -- confirm window.makeStackId was called {i} times with hsWin
      makeStackId_called(k)
      makeStackId_called_with(hsWin)

        -- in window.makeStackId, stackline.config:get(…fuzzFactor…) is called
      configGet_called(k)
      configGet_called_with('features.fzyFrameDetect.fuzzFactor')
    end
  end)  -- }}}

  describe('has', function()  -- {{{
      local hsWin = hs.window:new(fixture.screen.windows[1])
      local win = stackline.window:new(hsWin)
      testSchema(helpers.schemas.testGen.sl_win.schema, win)
  end)  -- }}}

  describe('._win has', function()  -- {{{
      local hsWin = hs.window:new(fixture.screen.windows[1])
      local win = stackline.window:new(hsWin)._win
      testSchema(helpers.schemas.testGen.hs_win.schema, win)
  end)  -- }}}

  it('getScreenSide()', function()  -- {{{
      -- for each of the windows in the fixture, create stackline window & spy on calls made within
    for k,v in pairs(fixture.screen.windows) do
        -- print('Making window number', k)
      local hsWin = hs.window:new(v)
      local win = stackline.window:new(hsWin)

      -- TODO: save screen-side when capturing fixture so it can be checked here (?)
      assert.contains({'left', 'right'}, win:getScreenSide())
    end
  end)  -- }}}

  it('isFocused()', function()  -- {{{
    for k,v in pairs(fixture.screen.windows) do
      local hsWin = hs.window:new(v)
      local win = stackline.window:new(hsWin)

      local isFocused = win:isFocused()
      assert.is_boolean(isFocused)
    end
  end)  -- }}}

  it('only 1 isFocused() == true', function()  -- {{{
    local focus = {}
    for k,v in pairs(fixture.screen.windows) do
      local hsWin = hs.window:new(v)
      local win = stackline.window:new(hsWin)

      local isFocused = win:isFocused()
      table.insert(focus, isFocused)
    end
    local numFocused = #u.filter(focus, function(x) return x end)
    assert.equal(1, numFocused)
  end)  -- }}}

end)
