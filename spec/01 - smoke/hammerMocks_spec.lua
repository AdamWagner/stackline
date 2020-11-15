local async = require 'stackline.lib.async'

describe('#mocks', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
    fixture = require 'spec.fixtures.load'()
    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)
    stackline = require 'stackline.stackline'
    stackline:init()
  end)


  describe('hs.window', function()

    it('works', function()  -- {{{
      stackline.manager:eachStack(function(s)
        s:eachWin(function(w)
          assert.is_number(w.id)
          assert.is_string(w.app)
        end)
      end)
    end)  -- }}}

    it(':frame()', function() -- {{{
      stackline.manager:eachStack(function(s)
        s:eachWin(function(w)
          local hsWin = w._win
          local frame = hsWin:frame()
          assert.is_table(frame)
          assert.same_values({'h', 'y', 'x', 'w'}, u.keys(frame.table))
          assert.contains(u.keys(getmetatable(frame)), 'floor')

          assert.is_table(hsWin:frame().table)
          assert.is_number(hsWin:frame().table.w)
        end)
      end)
    end) -- }}}

    it(':screen():frame()', function()  -- {{{
      stackline.manager:eachStack(function(s)
        s:eachWin(function(w)
          local hsWin = w._win
          assert.is_table(hsWin:screen():frame())
          assert.is_table(hsWin:screen():frame())
          assert.is_table(hsWin:screen():frame().table)
          assert.is_number(hsWin:screen():frame().table.w)
        end)
      end)
    end)  -- }}}

    it('key methods are callable', function()  -- {{{
      stackline:init()
      assert.is_function(stackline.manager.get)
      assert.is_function(stackline.manager.ingest)
    end)  -- }}}

  end)

end)

