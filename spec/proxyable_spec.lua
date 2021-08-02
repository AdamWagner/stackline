require 'spec.helpers'

describe('proxyable', function()

  before_each(function() -- {{{
    class = require 'lib.class'
    Thing = class('Thing'):use('proxyable')
    proxyable = require 'mixins.proxyable'

    changeEvents = {}
    defaultHandler = function(k,v,o) table.insert(changeEvents, {key=k, new=v, old=o}) end

    function Thing:getAge()
      if self.age and self.age < 21 then
        print ('too young')
      end
      return self.age
    end

  end) -- }}}

  after_each(function() -- {{{
    class, Thing, proxyable = nil, nil, nil
    changeEvents, defaultHandler = nil, nil
  end) -- }}}

  it('can be used as a class mixin', function() -- {{{
    t = Thing:new()

    t.bind.name(defaultHandler)

    t.name = 'John'
    t.name = 'Jane'

    assert.equal(2, #changeEvents)
  end) -- }}}

  it('supports setters', function() -- {{{
    t = Thing:new()

    function t:setName(v, proxy) 
      self.name = v
      local names = self.name:split(' ') 
      -- If other keys are set in a setter, *and* you want these to trigger
      -- change events, then they must be set on the *proxy*, not the raw table
      proxy.first_name = names[1] 
      proxy.last_name = names[2] 
    end

    t.name = 'Jane Doe'
    t.name = 'John Doe'

    assert.equal('John', t.first_name)
    assert.equal('Doe', t.last_name)
  end) -- }}}

  it('supports getters', function() -- {{{
    t = Thing:new()
    local suffix = ' (this is the name)'
    function t:getName() if self.name~=nil then return self.name .. suffix  end end

    t.name = 'John'

    assert.equal('John'..suffix, t.name)
  end) -- }}}

  it('supports binding change handlers to specific keys', function() -- {{{
    t = Thing:new()

    t.bind.name(defaultHandler)

    t.name = 'Jane Doe'
    t.name = 'John Doe'

    assert.equal(2, #changeEvents) -- there are 6 change events because "name" setter *also* sets first & last name
  end) -- }}}

  it('supports binding change handlers to any key via "__all"', function() -- {{{
    t = Thing:new()
    t.bind.__all(defaultHandler)

    t.name = 'Jane Doe'
    t.age = 33
    t.color = 'red'

    assert.equal(3, #changeEvents) -- there are 6 change events because "name" setter *also* sets first & last name
  end) -- }}}

  it('supports "computed" props', function() -- {{{
    x = require 'mixins.proxyable'.new()

    function CelciusToFarenheit(T) return (T * (9/5)) + 32 end
    function FarenheitToCelcius(T) return ((T - 32) * 5) / 9 end

    function x:setFarenheit(v, proxy)
      self.farenheit = v
      proxy.celcius = FarenheitToCelcius(v)
    end

    function x:setCelcius(v)
      rawset(self, 'celcius', v)
      rawset(self, 'farenheit', CelciusToFarenheit(v))
    end

    x.celcius = 100
    assert.equal(212, x.farenheit)

    x.farenheit = 32
    assert.equal(0, x.celcius)
  end) -- }}}

  it('supports "validators"', function() -- {{{
    x = proxyable.new()
    x._validator = proxyable.validators.sameType

    x.name = 'John'
    assert.equal('John', x.name)

    x.name = function() end -- > 'Must set key "name" to type "string", not "nil"'
    assert.equal('John', x.name)

    x.name = 'Sue'
    assert.equal('Sue', x.name)
  end) -- }}}

  it('can wrap a hammerspoon instance that is type "userdata"', function() --[[ {{{
    WARNING: We don't have access to actual hammerspoon instances in the test environment,
    so this test is imperfect:
     - Var `w` is not a real hammerspoon instance, but a mock. It's type is not "userdata", 
       but the structure of its limited keys (id, application, frame) do match that of a real `hs.window`
     - The `hsInstanceToTable` function will return `w` as-is, since it's not type "userdata"
     - Will not catch failures caused by trying to index user data, e.g., `rawget(ud_tbl, 'key')`
    ]]
    w = hs.window.filter()[1]
    wt = hsInstanceToTable(w)
    x = proxyable.new(wt)

    assert(type(x.frame)=='table', 'Window frame via proxy by accessing key should be type "table"')
    assert(type(x.frame.x)=='number', 'Frame.x should be a number')
  end) -- }}}

  it('can wrap hammerspoon instance with nested instances', function() -- {{{
    -- WARNING: Test is imperfect (see above)
    w = hs.window.filter()[1]
    wt = hsInstanceToTable(w)
    x = proxyable.new(wt)

    assert(type(x.application.name)=='string', '`wt.application.name` should be type "string"')
  end) -- }}}

end)
