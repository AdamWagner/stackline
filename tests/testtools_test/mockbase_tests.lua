
describe('#mock MockBase', function()
  before_each(function()
    _G.hs = helpers.reloadMock()
    -- local log = hs.logger.new('tests_mockbase')
    -- log.setLogLevel('info')
    -- log.i("Loading'tests_mockbase")
  end)

  it('has defaults', function()
    local w = hs.window:new()
    local id = w:id()
    assert.equal(id, 11111)
  end)

  -- TODO: fix scope issues that permanently overwrite defaults
  it('__setDefaults() works', function()
    local winDefault = {id = 22222}
    hs.window:__setDefaults(winDefault)
    local w = hs.window:new()
    local id = w:id()
    assert.equal(id, 22222)
  end)

  it('instance vals override defaults', function()
    local winProps = {id = 33333}
    local w = hs.window:new(winProps)
    local id = w:id()
    assert.equal(id, 33333)
  end)

  pending('defaults still work when vals passed to instance', function()
    -- Merging passed-props with defaults deprecated 2020-10-15
    -- due to unexpected behavior from table.merge (and a strong need for this)
    local winProps = {id = 33333}
    local w = hs.window:new(winProps)

    local id = w:id()
    assert.equal(id, 33333)

    local title = w:title()
    local titleMatch = string.match(title, "NVIM")
    assert.is_string(titleMatch)
  end)

end)

