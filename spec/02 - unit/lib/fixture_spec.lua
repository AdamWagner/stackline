
describe('#lib fixtures', function()
  before_each(function()
    _G.hs = helpers.reloadMock()
  end)

  it('can load default', function()
    fixture = require 'spec.fixtures.load'()
    assert.is_table(fixture)
  end)

  it('can load specific', function()
    local fname = 'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574'
    fixture = require 'spec.fixtures.load'(fname)
    assert.is_table(fixture)
  end)
end)
