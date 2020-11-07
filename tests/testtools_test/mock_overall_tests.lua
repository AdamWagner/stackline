-- local log = hs.logger.new('mock_overall_tests')
-- log.setLogLevel('info')
-- log.i("Loading'mock_overall_tests")

-- TODO: dynamically read files out of tests.mockHammerspoon
local hsMocks = {
  'appfinder',
  'application',
  'canvas',
  'event',
  'eventtap',
  'image',
  'logger',
  'screen',
  'task',
  'timer',
  'window',
}

local modules = {'stackline', 'hs', 'u'}

describe('#mock ensure modules not loaded yet', function()
  for _, module in pairs(modules) do
    it(module, function()
      assert.is_nil(package.loaded[k]) -- mymodule is not loaded
      assert.is_nil(_G[k]) -- _G.myglobal is not set
    end)
  end
end)

describe('#mock hs', function()

  before_each(function()
    _G.hs = helpers.reloadMock()
  end)

  it("#mock hs module exists", function()
    assert.is_table(hs)
  end)

  for _, module in pairs(hsMocks) do
    it('hs.' .. module .. ' exists', function()
      assert.is_table(hs[module])
    end)
  end

end)
