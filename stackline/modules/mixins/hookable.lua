--[[
    == Hookable ==
    Call a method before or after an existing method on an object.

    This overwries the `method_name` on `self` with a new function
    that calls `hook` before or after the `method_name`.
]]

--[[ ==TESTS == {{{
  class = require 'lib.class'
  Counter = class()
  function Counter:new() self.val = 0 end
  function Counter:update()
    self.val = self.val + (self.incAmt or 1)
    return self
  end
  Counter:afterhook('update', function(self)
      self.val = self.val - 2
      print('running after calling "update"', self.val)
  end)

  c = Counter:new()
 }}} ]]


local Hookable = {__name='Hookable'}

function Hookable:beforeHook(method_name, hook)
    local method = self[method_name] or u.identity
    rawset(self, method_name, function(this, ...)
        return method(this, hook(this, ...))
    end)
end

function Hookable:afterHook(method_name, hook)
    local method = self[method_name] or u.identity
    rawset(self, method_name, function(this, ...)
        return hook(method(this, ...))
    end)
end

return Hookable
