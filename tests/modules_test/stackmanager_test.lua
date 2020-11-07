

describe('#module stackmanager', function()
  
  before_each(function()  -- {{{
    helpers.setupFile()
    helpers.loadFixture()
    asyncTest = helpers.asyncTest
  end)  -- }}}

  it('main module is initially nil', function()
    assert.is_nil(stackline)
  end)
  describe(':init()', function()
    it('works', function() -- {{{
      helpers.initStackline()
      assert.is_table(stackline.manager)
      assert.is_boolean(stackline.manager.showIcons)
    end) -- }}}

    it('key methods are callable', function()
      assert.is_function(stackline.manager.get)
      assert.is_function(stackline.manager.ingest)
    end)

    it('stacks initially empty', function()
      assert.equals(0, #stackline.manager.tabStacks)
    end)
  end)

  describe(':ingest()', function()

    it('trigger by passing ws → Query.query()', function()
      helpers.initStackline()
      local wf = hs.window.filter.new()
      Query.query(wf:getWindows())
      assert.greater_than(0, #stackline.manager.tabStacks)
    end)

    it('creates stack instances given grpd wins', function()
      u.p(stackline.manager.tabStacks)
      -- assert.is_table(actual)
    end)



      it('are retrieved', function() -- {{{
        local actual = asyncTest:run(function()
            local _, stackIndexes = getWinStackIdxs() -- async shell call to yabai
            local ok, parsed = pcall(hs.json.decode, stackIndexes)
              asyncTest:set('resolved', parsed)
            end)

        assert.is_table(actual, expected)
      end) -- }}}
  end)
end)
