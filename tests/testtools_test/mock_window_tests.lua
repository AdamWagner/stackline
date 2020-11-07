

describe('#mock hs.window', function()

  before_each(function()
    hs = helpers.reloadMock()
    -- local log = hs.logger.new('tests.mockHammerspoon.window')
    -- log.setLogLevel('info')
    -- log.i("Loading'tests.mockHammerspoon.window")
    w = hs.window:new()
  end)

  it('w:new()', function()
    local spy = spy.on(hs.window, 'new')
    local fixture = {frame = hs.geometry({x = 1, y = 2, w = 4, h = 1})}

    local result = helpers.methodSpy(hs.window, 'new', {fixture})
    assert.is_table(result)

  end)

  it('w:frame()', function()
    local frame = w.frame()
    assert.is_table(frame)
  end)

  it('w:frame():getarea', function()
    local frame = w.frame()
    local area = frame:getarea()
    assert.is_number(area)
  end)

  it('w:screen()', function()
    local screen = w:screen()
    local methods = u.keys(getmetatable(screen))
    assert.is_table(screen)
    assert.is_function(screen.mainScreen)
    assert.is_function(screen.mainScreen)
  end)

  it('w:screen():absoluteToLocal(…)', function()
    local screen = w:screen()
    local rect = hs.geometry({x = 1, y = 1, w = 50, h = 50})
    local result = screen:absoluteToLocal(rect)
    assert.is_number(result:getarea())
  end)
end)

