local u = require 'stackline.lib.utils'

--[[ NOTE: Auto-wraps subclass:new( … ) to create a properly independent
    instance that inherits from the parent class.

    EXAMPLE:
       Class = require 'lib.Class'
       Human = Class()                -- or Klass:extend()

       function Human:new(name, age)
         self.name = name
         self.age = age
         return self
       end

       JohnDoe = Human('JohnDoe', 33)
       JaneDoe = Human:new('JaneDoe', 55)

    MIXINs:
      local Person = Class()
      local Person = Class(kung_foo) -- use mixins to share behavior with the class

    EXTENDS:
      local Elder = Person:extend()  -- use :extend() to make subclasses that inherit from parent

    See notes here: https://github.com/AdamWagner/stackline/wiki/Dev-diary:-Researching-lua-OOP---class-libraries
--]]

local BaseClass = {}

-- Make it easy to create instances
--  e.g., local Human = Class()
function BaseClass:__call(...)
  return self:new(...)
end

-- Auto-wraps subclass:new( … ) to create a properly independent instance
function BaseClass:create(newFn)
  return function(_, ...)
    local obj = setmetatable({}, { __index = self })
    newFn(obj, ...)
    return obj
  end
end

-- If ":new()" is being set, wrap in :create(…) above
function BaseClass:__newindex(k,v)
  if k=='new' and type(v)=='function' then
   rawset(self, k, self:create(v))
  else
   rawset(self, k, v)
  end
end

-- Extend the base class with optional mixins
function BaseClass:extend(...)
  local mt = {}
  mt.__index = table.merge(self, ...)  -- merge the props from all mixins provided
  mt.__newindex = BaseClass.__newindex -- intercept the :new() method for wrapping
  mt.__call = BaseClass.__call         -- make callable so instances can be created easily with :new()
  return setmetatable({}, mt)
end

-- Return a function to get a new BaseClass
return function(o)
  local obj = u.dcopy(o or {}) -- must clone `o` to prevent from inheriting methods defined on subclass
  return BaseClass:extend(obj)
end
