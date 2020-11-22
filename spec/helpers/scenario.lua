local u = require 'lib.utils'
local lfs = require 'lfs'

local M = {}

function M.getFixturePaths()  -- {{{
  local fixtures_dir = lfs.currentdir() .. "/spec/fixtures/data/screen_state"
  local fixturePaths = {}
  for fixturePath in lfs.dir(fixtures_dir) do
    if fixturePath ~= '.' and fixturePath ~= '..' then
      fixturePath = string.gsub('screen_state.' .. fixturePath, '.lua', '')
        -- print('fixturePath:', fixturePath)
        -- helpers.scenario.run(fixturePath)
      table.insert(fixturePaths, fixturePath)
    end
  end
  return fixturePaths
end  -- }}}

function M.run(fixture)  -- {{{
  local scenarioName = fixture:split('%d')[1]:trim()

    -- Separate scenarios with blank line
  describe('', function() it('', function() end) end)

  describe('#integration Scenario: ' .. scenarioName, function()

    before_each(function()   -- {{{
      hs = helpers.reloadMock()

      state = require 'spec.fixtures.load'(fixture)
      hs.window.filter:set(state.screen.windows)
      hs.task:set(state.stackIndexes)

      stackline = require 'stackline.stackline.stackline'
      stackline.config = require 'stackline.stackline.configManager'
    end)   -- }}}

    it("exists", function()
      stackline.config:init(require 'conf')
      assert.is_table(stackline.config)
      assert.is_table(stackline.config.schema)
      assert.is_table(stackline.config.types)
    end)

    it("has expected methods", function()
      stackline.config:init(require 'conf')
      assert.is_callable(stackline.config.get)
      assert.is_callable(stackline.config.set)
      assert.is_callable(stackline.config.validate)
      assert.is_callable(stackline.config.autosuggest)
    end)

    it("returns default config", function()
      local conf = require 'stackline.conf'
      stackline.config:init(conf)
      local c = stackline.config:get()
      assert.is_table(c)
      assert.are_same(conf, c)
    end)
  end)

end  -- }}}

return M
