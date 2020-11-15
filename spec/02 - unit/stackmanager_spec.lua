local async = require 'stackline.lib.async'

describe('#module stackmanager', function()

  before_each(function()
    require 'lib.updatePackagePath'
    _G.hs = helpers.reloadMock()
    fixture = require 'spec.fixtures.load'()
    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)

  end)

  it('main module is initially nil', function()
    assert.is_nil(stackline)
  end)

  describe(':init()', function() -- {{{

    before_each(function()
      stackline = require 'stackline.stackline'
      stackline.config = require 'stackline.configManager'
    end)

    it('works', function()
      stackline:init()
      assert.is_table(stackline.manager)
      assert.is_boolean(stackline.manager.showIcons)
    end)

    it('key methods are callable', function()
      stackline:init()
      assert.is_function(stackline.manager.get)
      assert.is_function(stackline.manager.ingest)
    end)

    it('expected num stacks', function()
      assert.equals(fixture.summary.numStacks, #stackline.manager.tabStacks)
    end)


    it('expected summary', function()
      stackline:init()
      stackline.manager:update()

      -- stackline.manager:update()
      local summary = stackline.manager:getSummary()
      summary.topLeft = nil
      assert.deepEqual(summary, fixture.summary)
    end)

  end) -- }}}

  -- it(':ingest()', function() -- {{{
  --   before_each(function()
  --     hs.window.filter:set(fixture.screen.windows)
  --     stackline = require 'stackline.stackline'
  --     stackline:init()
  --     stackline.manager:update()
  --   end)

  --   it('trigger by passing ws → Query.query()', function()
  --     local ws = stackline.wf:getWindows()
  --     stackline.manager:update()

  --     local test = stackline.manager.tabStacks
  --     -- u.p(test)
  --     -- u.p(hs.window.filter:getWindows())
  --     -- wf = hs.window.filter.new()
  --     -- u.p(wf:getWindows())
  --     -- assert.greater_than(0, #stackline.manager.tabStacks)
  --   end)

  -- it('creates stack instances given grpd wins', function()
  --   u.p(stackline.manager.tabStacks)
  --     -- assert.is_table(actual)
  -- end)

  -- it('are retrieved', function()
  --   async(function()
  --     local winStackIndexes = hs.json.decode(Query.getWinStackIdxs())
  --     local ok, parsed = pcall(hs.json.decode, winStackIndexes)
  --     assert.same(parsed, fixture.stackIndexes)
  --   end)
  -- end)

  -- end) -- }}}

end)
