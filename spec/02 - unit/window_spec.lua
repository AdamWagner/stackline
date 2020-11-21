

-- test helpers
-- ———————————————————————————————————————————————————————————————————————————
local  get_win = {  -- {{{
    -- getters for hs.window values
  app = function(w) return w:application():name() end,
  title = function(w) return w:title() end,
  id = function(w) return w:id() end,
  frame = function(w) return w:frame() end,
  frame_area = function(w) return w:frame():getarea() end,
  screen = function(w) return w:screen() end,
  screen_frame = function(w) return w:screen():frame() end,
  screen_fullFrame = function(w) return w:screen():fullFrame() end,
}  -- }}}

local function testSchema(schema, obj)  -- {{{
    -- given a schema and an obj, test obj for each entry in schema
  for _,val in pairs(schema) do
    assert(val.key, 'Schema entries must have a "key" property')
    assert(val.is_type, 'Schema entries must have a "is_type" property')
    assert.is_callable(val.is_type)

    local getter = (val.fn ~= nil)
      and val.fn                             -- use val.fn if it exists
      or function(x) return x[val.key] end   -- otherwise use val.key to lookup directly

      -- run the test!
    it(val.key, function()
      val.is_type(getter(obj))
    end)
  end
end  -- }}}

describe('#module #only window', function()

  setup(function()
    require 'lib.updatePackagePath'
    u = require 'lib.utils'
    _G.hs = helpers.reloadMock()

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
              'get'       -- method
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

      local schema = {
        { key = 'app', is_type = assert.is_string },
        { key = 'title', is_type = assert.is_string },
        { key = 'id', is_type = assert.is_number },
        { key = 'screen', is_type = assert.is_number },
        { key = 'frame', is_type = assert.is_rect },
        { key = 'stackId', is_type = assert.is_string },
        { key = 'stackIdFzy', is_type = assert.is_string },
      }

      testSchema(schema, win)
  end)  -- }}}

  describe('._win has', function()  -- {{{
      local hsWin = hs.window:new(fixture.screen.windows[1])
      local win = stackline.window:new(hsWin)._win
      local schema = {
        { key = 'app name',         fn = get_win.app,              is_type = assert.is_string },
        { key = 'title',            fn = get_win.title,            is_type = assert.is_string },
        { key = 'id',               fn = get_win.id,               is_type = assert.is_number },
        { key = 'frame',            fn = get_win.frame,            is_type = assert.is_rect },
        { key = 'frame area',       fn = get_win.frame_area,       is_type = assert.is_number },
        { key = 'screen',           fn = get_win.screen,           is_type = assert.is_table },
        { key = 'screen frame',     fn = get_win.screen_frame,     is_type = assert.is_rect },
        { key = 'screen fullFrame', fn = get_win.screen_fullFrame, is_type = assert.is_rect },
      }

      testSchema(schema, win)
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
