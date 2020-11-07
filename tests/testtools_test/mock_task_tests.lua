
describe('#mock hs.task', function()
  before_each(function()
    hs = helpers.reloadMock()
    -- local log = hs.logger.new('hsmock.task')
    -- log.setLogLevel('info')
    -- log.i("Loading'hsmock.task")
  end)

  it('task:set()', function()
    local testResult = {red = 42, blue = 29}
    hs.task:set(testResult)
    assert.is_table(hs.task.__stdout)
  end)

  it('task.new', function()
    local testResult = {red = 42, blue = 29}
    hs.task:set(testResult)

    local result = hs.task.new('ls', function(exitCode, stdout, stderr)
      return stdout
    end)

    assert.is_table(result)
    assert.is_callable(result.start)
  end)

  it('task.new():start', function()
    local testResult = {red = 42, blue = 29}
    hs.task:set(testResult)

    local result = hs.task.new('ls', function(exitCode, stdout, stderr)
      return stdout
    end):start()

    local expected = hs.json.encode(testResult)
    assert.is_same(expected, result)
  end)

end)
