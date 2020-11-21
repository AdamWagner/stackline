local async = require 'stackline.lib.async'

describe('#module query', function()
  before_each(function()
    require 'lib.updatePackagePath'
    _G.hs = helpers.reloadMock()
    fixture = require 'spec.fixtures.load'()
    hs.window.filter:set(fixture.screen.windows)
    hs.task:set(fixture.stackIndexes)

  end)
    it(':getWinStackIdx()', function()
      async(function()
        local stackIndexResponse = require 'stackline.query'.getWinStackIdxs()
        local winStackIndexes = hs.json.decode(stackIndexResponse)
        assert.same(winStackIndexes, fixture.stackIndexes)
      end)
    end)
end)
