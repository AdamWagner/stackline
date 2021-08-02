local class = require 'lib.class'

--[[
e = Observable:new()
e:subscribe(function(...) print('event!!', ...) x = {...} return x[1] end)
e:subscribe(function(...) print('event!!', ...) x = {...} return x[2] end)
r = e:publish(1,2,3)
]]

collectors = {
  last = function()
    return {
      val = nil,
      add = function(self,val) self.val = val end,
      res = function(self) return self.val end,
    }
  end,
  all = function()
    return {
      val = {},
      add = function(self,val) table.insert(self.val,val) end,
      res = function(self) return self.val end,
    }
  end,
}


Observable = class('Observable')

function Observable:new(c)
  self._collector = c or collectors.last
  self._subscribers = {}
end

function Observable:publish(...)
  local c = self._collector()
  for func, _ in pairs(self._subscribers) do
    c:add(func(...))
  end
  return c:res()
end

function Observable:subscribe(other)
  self._subscribers[other] = true -- using subscriber as the key rather than the value makes it quick to look up when unsubscribing
end

function Observable:unsubscribe(other)
  self._subscribers[other] = nil
end

Observable.__call = Observable.subscribe

return Observable
