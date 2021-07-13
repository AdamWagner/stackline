require 'stackline.lib.utils.globals'

local modulePath = "stackline.lib.utils.%s"

local function get(module)
  printf('Loading utils module: %s', module)
  return require(modulePath:format(module))
end

local u = get('core')

for _, mod in ipairs{'types', 'compare', 'iterators', 'collections', 'functional', 'path', 'debug', 'extra' } do
  for k,v in pairs(get(mod)) do
    u[k] = v
  end
end

local Chain = {
  new = function(self, t, o)
    o = o or {}
    o.chained = t
    setmetatable(o, {__index = self})
    return o
  end,
  tap = function(self, f)
    if u.is.array(self.chained) then
      u.each(self.chained, f)
    else
      f(self.chained)
    end
    return self
  end,
  inspect = function(self) return self:tap(u.p) end,
  value = function(self) return self.chained end
}

u.each = require 'stackline.lib.utils.iterators'.each

u.each(u, function(fn, k)
  Chain[k] = function(self, ...)
    self.chained = fn(self.chained, ...)
    return self
  end
end)

function u.chain(t) return Chain:new(t) end

return setmetatable(u, {__call = function(u, t) return u.chain(t) end})
