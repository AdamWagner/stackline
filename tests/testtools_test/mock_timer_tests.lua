
describe('#mock hs.timer', function()
  before_each(function()
    hs = helpers.reloadMock()
    -- local log = hs.logger.new('tests.mockHammerspoon.timer')
    -- log.setLogLevel('info')
    -- log.i("Loading'tests.mockHammerspoon.timer")
  end)

  it('timer.delayed', function()
    local x = hs.timer.delayed.new(1, function() end)
    local instanceSelf = match.is_ref(x)
    local timerSpy = spy.on(x, "start")
    x:start()
    assert.spy(timerSpy).was_called_with(instanceSelf)
  end)

  it('timer.doAfter', function()
    local expected = 'expected timer.doAfter result'

    -- TODO: I need to update timer to use coroutines, at which point this test
    -- will probably stop working. Currently the sleep in doAfter blocks the
    -- test progress
    local x = hs.timer.doAfter(1, function()
      local actual = 'expected timer.doAfter result'
      assert.are.same(expected, actual)
    end)
  end)

end)
