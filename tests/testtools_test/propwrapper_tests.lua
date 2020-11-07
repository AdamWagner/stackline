

describe('#mock prop()', function()
  before_each(function()
    _G.hs = helpers.reloadMock()
    -- local log = hs.logger.new('propwrapper_tests')
    -- log.setLogLevel('info')
    -- log.i("Loading'tests_prop")
    prop = require 'tests.mockHammerspoon.utils.prop'
  end)

  it('loads', function()
    assert.is_table(prop)
  end)

  it('new', function()
    local wrappedVal = prop.new('example string')
    assert.is_table(wrappedVal)
    assert.is_string(wrappedVal.value)
    assert.is_callable(wrappedVal)
  end)

  it('wrapped val can be called', function()
    local str = 'example string'
    local wrappedVal = prop.new(str)
    local unwrapped = wrappedVal()
    assert.equal(unwrapped, str)
  end)

  it('vals can be called', function()
    local w = hs.window:new()
    local id = w:id()
    assert.equal(id, 11111)
  end)

  it('recursively wraps tables', function()
    local wrappedVal = prop.wrap({key = {nested = 'example string'}})

    assert.is_table(wrappedVal.key)
    assert.is_callable(wrappedVal.key)
    assert.is_callable(wrappedVal.key().nested)
  end)

  it('can access recursively wrapped tables', function()
    local wrappedVal = prop.wrap({key = {nested = 'example string'}})
    assert.is_table(wrappedVal)
    assert.is_table(wrappedVal.key().nested)
    assert.is_callable(wrappedVal.key().nested)
    assert.is_string(wrappedVal.key():nested())
  end)

  describe('integrates with hs mock', function()
    before_each(function()
      _G.hs = helpers.reloadMock()
    end)

    it('hs.window:new():id()', function()
      local w = hs.window:new()
      assert.is_callable(w.id)
    end)

    it('w:id() works', function()
      local w = hs.window:new()
      local id = w:id()
      assert.is_number(id)
    end)

    it('w:application():name() works', function()
      local w = hs.window:new()
      assert.is_callable(w.application)
      assert.is_callable(w.application().name)
      local name = w:application():name()
      assert.is_string(name)
    end)
  end)

end)

