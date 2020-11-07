

describe('#mock hs.screen', function()

  before_each(function()
    hs = helpers.reloadMock()
    -- local log = hs.logger.new('hsmock.screen')
    -- log.setLogLevel('info')
    -- log.i("Loading'hsmock.screen")
    s = hs.screen:new()
  end)

  it('s:frame()', function()
    local frame = s.frame()
    assert.is_table(frame)
    assert.is_callable(frame)
  end)

  it('s:frame():getarea', function()
    local frame = s.frame()
    local area = frame:getarea()
    assert.is_number(area)
  end)

  it('s:mainScreen()', function()
    local methods = u.keys(getmetatable(s))
    assert.is_table(s)
    assert.is_function(s.mainScreen)
    assert.is_callable(s.mainScreen)
  end)

  it('s:screen():absoluteToLocal(…)', function()
    local rect = hs.geometry({x = 1, y = 1, w = 50, h = 50})
    local result = s:absoluteToLocal(rect)
    assert.is_number(result:getarea())
  end)

  it('s:screen():absoluteToLocal(…)', function()
    local rect = hs.geometry({x = 1, y = 1, w = 50, h = 50})
    local result = s:absoluteToLocal(rect)
    assert.is_number(result:getarea())
  end)

end)
