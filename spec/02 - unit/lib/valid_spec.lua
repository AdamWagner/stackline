describe('#lib validator', function()
  before_each(function()
    _G.hs = helpers.reloadMock()
    stackline = require 'stackline.stackline'
    num = stackline.config.generateValidator('number')
    str = stackline.config.generateValidator('string')
    bool = stackline.config.generateValidator('boolean')
  end)


  it('number (success)', function()
    local r = num(5)
    assert.is_true(r)
  end)

  it('number (fail)', function()
    local r = table.pack(num('JohnDoe'))
    local expected = {false,	'JohnDoe is not a number.', n = 2}
    assert.are.same(r, expected)
  end)

  it('string (success)', function()
    local s = 'test string'
    local r = str(s)
    assert.is_true(r)
  end)

  it('string (fail)', function()
    local s = 5
    local r = table.pack(str(s))
    local expected = { false, '5 is not a string.', n = 2}
    assert.are.same(r, expected)
  end)

  it('bool (success)', function()
    local b = false
    local r = bool(b)
    assert.is_true(r)
  end)

  it('bool (fail)', function()
    local b = 'false'
    local isValid, msg = bool(b)
    assert.is_false(isValid)
    local msgExpected = 'false is not a boolean.'
    assert.are.same(msg, msgExpected)
  end)

  it('tbl (success)', function()
    local t = {one = 'is the loneliest', num = 'ber'}

      -- dynamically build nested schema based on supplied table 't'
    local tbl = stackline.config.generateValidator(t)
    local r = tbl(t)
    assert.is_true(r)
  end)

  it('tbl (fail)', function()
    local t = {one = 'is the loneliest', num = 'ber'}

      -- Child *values* are not validated (keys are tho)
      -- So 'two' will fail (wrong key), but '5' won't (values aren't validated)
      -- To validate the values, you need to call the matching key in the
      -- validator table on the value-to-validate.
    local t1 = {two = 5, num = 5}

      -- Dynamically build nested schema (tbl) based on supplied table 't'
      -- Key values will be functions that need to be called on the values of
      -- the table to test. Calling on table as a whole will only test that keys
      -- are the same.
    local tbl = stackline.config.generateValidator(t)

    local isValid, msg = tbl(t1)
    local isValidExpected, msgExpected = false, { two = "is not allowed." }

    assert.is_false(isValid)
    assert.are_same(msg, msgExpected)
  end)

end)
