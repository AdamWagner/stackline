require 'busted.runner'()
local it = require'busted'.it
local describe = require'busted'.describe
local before_each = require'busted'.before_each
local after_each = require'busted'.after_each

local M = {}

function M.run(fixture)
  local scenarioName = fixture:split('%d')[1]:trim()

  describe('Scenario: ' .. scenarioName, function()

    before_each(function() -- {{{
      _G.hs = helpers.reloadMock()

      state = require 'spec.fixtures.load'(fixture)
      hs.window.filter:set(state.screen.windows)
      hs.task:set(state.stackIndexes)

      stackline = require 'stackline.stackline.stackline'
      stackline.config = require 'stackline.stackline.configManager'
    end) -- }}}

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

end

return M
