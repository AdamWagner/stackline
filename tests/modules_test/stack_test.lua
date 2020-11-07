local prop = require 'tests.mockHammerspoon.utils.prop'

describe('#module stack', function()

  before_each(function()  -- {{{
    _G.hs = helpers.reloadMock()
    log = helpers.logSetup('test_stack')


    local fixture = '2_groups_3_appwindows_375a7ad1f9b6eaa76001ccc7d73d8581'
    ingestArgs = require 'tests.fixtures.load'('manager_ingest.' .. fixture)
    -- u.p(u.keys(ingestArgs))
    -- u.p(ingestArgs.shouldClean)
    -- u.p(ingestArgs.appWindows)

    windowGroups = ingestArgs.windowGroups
    appWindows = ingestArgs.appWindows
    shouldClean = ingestArgs.shouldClean

    stackline = require 'stackline.stackline.stackline'
    stackline.config = require 'stackline.stackline.configManager'

    stackline.config:init(require 'stackline.conf')
  end)  -- }}}


  describe('test', function()
    it('description', function()
      
    end)
    
  end)


  describe('basics:', function()  -- {{{
    it("args exist", function()
      assert.is_table(ingestArgs)
    end)

    it("shouldClean is bool", function()
      assert.is_boolean(ingestArgs.shouldClean)
    end)

    it("at least one windowGroup", function()
      assert.greater_than(0, u.length(windowGroups))
    end)

    it('has expected keys', function()
      local groupKey = u.keys(windowGroups)[1]
      local appKey = u.keys(appWindows)[1]
      assert.is.string(groupKey)
      assert.is.string(appKey)
    end)

    it('windowGroup structure', function()
          -- check window group structure
        local group_first = u.values(windowGroups)[1]
        assert.is_true(u.isarray(group_first))
    end)

    it('frame is an hs.geometry object', function()
        local group_first = u.values(windowGroups)[1]
        local win_first = group_first[1]
        -- u.p(win_first)

        -- FIXME: win_first has not been properly wrapped in prop.wrap :(  
        local frameArea = win_first.frame:getarea()
        assert.is_number(frameArea)
    end)

    pending('stackId format', function()
      -- NOTE: at this point, the windows have already become HS windows, so no StackID yet. 
      -- TODO: find a way to use the stackId in the fixture to verify test results
        local group_first = u.values(windowGroups)[1]
        local win_first = group_first[1]
        local stackId = win_first.stackId
        assert.is_truthy(stackId:match('|'))
    end)
  end)  -- }}}


  describe('core functionality', function()  -- {{{
    before_each(function() 

      -- state = require 'tests.fixtures.load'('screen_state.one_stack_three_windows')
      -- hs.window.filter:set(state.screen.windows)
      -- hs.task:set(state.stackIndexes)

      -- local wf = hs.window.filter.new()
      -- local ws = wf:getWindows()
      -- u.pheader('windows from filter for query')
      -- u.p(ws)

      -- stackline.manager = require('stackline.stackline.stackmanager'):init()
      -- local Query = require 'stackline.stackline.query'

    end)

    it('stackmanager:ingest()', function()

      -- u.pheader('windowGroups')
      -- u.p(windowGroups)
      -- u.pheader('appWindows')
      -- u.p(appWindows)
      -- stackline.manager:ingest(windowGroups, appWindows, shouldClean)
      
    end)

      -- it('stackmanager:ingest()', function()
      
      -- end)
    
  end)  -- }}}


end)

