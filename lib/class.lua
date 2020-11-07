u = require 'stackline.lib.utils'


--[[
Difference betweeen Obj.__index = Obj and setmetatable(o, self)
https://stackoverflow.com/questions/46749367/difference-between-table-in-index-field-and-metatable

┌─────────────────────────────────────────────┐
│ THE "CLASSES IN LUA" INSIGHT THAT I NEEDED: │
└─────────────────────────────────────────────┘
https://www.oreilly.com/library/view/creating-solid-apis/9781491986301/ch04.html



-- MyClass.lua -----------------------------------------------------------------

      MyClass = {}

      function MyClass:new(obj)
	obj = obj or {}                 -- Line 1.
	self.__index = self             -- Line 2.
	return setmetatable(obj, self)  -- Line 3.
      end

      function MyClass:method()
	log.d('Hi from ' .. self.name)
      end

      return MyClass
 -------------------------------------------------------------------------------

Subclasses in Lua
Before diving into the Baddy class, let’s take a look at a more generic subclass
of the earlier MyClass example. In the simplest case, your subclass won’t
require any special per-instance initialization, and will only either add or
replace existing methods. Here’s a simple subclass that overrides method():

-- Subclass.lua ----------------------------------------------------------------
      --
      -- An example subclass of the earlier MyClass example.
      --

      local MyClass = require 'MyClass'

      local Subclass = MyClass:new()

      function Subclass:method()
	log.d('Hi from subclass instance ' .. self.name)
      end

      return Subclass
 -------------------------------------------------------------------------------

-- ┌────────────────────────────────────────────────────────────────────────────────────┐
-- │ !!! KEY INSIGHT !!!                                                                │ 
-- │ The interesting thing here is that Subclass begins life as an instance of MyClass. │
-- └────────────────────────────────────────────────────────────────────────────────────┘

The interesting thing here is that Subclass begins life as an instance of
MyClass. (In other languages, it’s common for classes to simply define new types
in the language, rather than to be values [such as class instances] themselves.)
I’ll explain how this works in a moment. Here’s an example usage of Subclass:

-- subclass_usage.lua ----------------------------------------------------------
      local Subclass = require 'Subclass'

      local s = Subclass:new({name = 'Gwendolyn'})

      s:method()  --> Prints 'Hi from subclass instance Gwendolyn'.
 -------------------------------------------------------------------------------

In using the subclass, we give it similar treatment to the superclass, calling
its new() method first, followed by a method() call on the resulting instance.

The preceding example works because of the following two connections:
  1. Because Subclass is an instance of MyClass, any method of MyClass—including
  new()—is also a method of Subclass. So, calling Subclass:new() is the same as
  calling MyClass.new(Subclass).

  2. The new() method on MyClass was written specifically to support this usage
  pattern. In particular, a call to MyClass.new(Subclass) will ensure that
  Subclass.__index = Subclass, and that the new instance obj has Subclass as its
  metatable. So, methods defined on Subclass will be callable on all instances
  of Subclass, and methods defined on MyClass that are not overridden by
  Subclass will also be callable on Subclass instances.

This simple example didn’t cover two common workflows:

First, if you’d like to call a superclass’s method that you’ve overridden from a
subclass’s method, you can do so by using this syntax:

    Superclass.method(self, <other parameters>)

The other common workflow is the case in which your subclass needs its own new()
method. The Baddy class will provide an example of this. You also can wrap calls
to the superclass’s new() method, but you must do so explicitly because
overridden methods in Lua, even constructors, don’t automatically call the
versions they override. Such a new() method might look like this:

-- Overriding the new() method in a subclass: ----------------------------------
      function Subclass:new(obj)
	obj = Superclass.new(obj)
	-- Subclass-specific setup.
	self.__index = self
	return setmetatable(obj, self)
      end
 -------------------------------------------------------------------------------




]]



-- FROM: https://github.com/grynmoor/class
--[[ Documentation {{{

local newclass = require('class')

-- Creating a class ----------------------------------------------------------
local Fruit = newclass()

-- Creating a constructor
function Fruit:new(name, mass)
  self.name = name or 'Fruit'
  self.mass = mass or 1
  self.peeled = false
end

--Creating a class instance ----------------------------------------------------
local newFruit = Fruit('New Fruit', 3)
log.d(newFruit.name)     -- 'New Fruit'
log.d(newFruit.mass)     -- 3
log.d(newFruit.peeled)   -- false

-- Creating methods ------------------------------------------------------------
function Fruit:bite(numTimes)
  if numTimes == nil then numTimes = 1 end
  local massLost = 0
  for i = 1, numTimes do
    if self.mass <= 0 then return massLost end
    massLost = math.floor(self.mass * 0.5)
    self.mass = self.mass - massLost
  end
  return massLost
end

function Fruit:peel()
  if self.peeled then return end
  self.peeled = true
end

-- Example usage ---------------------------------------------------------------
local newFruit = Fruit(nil, 5)
log.d(newFruit.peeled)   -- false
newFruit:peel()
log.d(newFruit.peeled)   -- true
log.d(newFruit.mass)     -- 5
newFruit:bite(2)
log.d(newFruit.mass)     -- 1

-- Creating metamethods --------------------------------------------------------
function Fruit:__tostring()
  if self.mass > 0 then
    return ('A %s%s with a mass of %d'):format(self.peeled and 'peeled ' or '', self.name, self.mass)
  else 
    return "There's nothing left!"
  end
end

function Fruit:__call(...)
  return self:bite(...)
end

-- Example usage
local newFruit = Fruit('Banana')
log.d(newFruit)   -- 'A Banana with a mass of 1'
newFruit()
log.d(newFruit)   -- "There's nothing left!"

-- Creating a subclass ---------------------------------------------------------
local Pineapple = class(Fruit)

function Pineapple:new(mass, tanginess)
  Pineapple.super.new(self, 'Pineapple', mass)
  self.tanginess = tanginess or 50
end

-- Calling a method from a superclass
function Pineapple:bite(numTimes)
  if self.peeled then Pineapple.super.bite(self, numTimes) end   -- You wouldn't eat a pineapple that isn't peeled, would you?
end

-- Creating static variables ---------------------------------------------------
local Apple = newclass(Fruit)

Apple.keepsDoctorAway = true

function Apple:new(mass)
	Apple.super.new(self, 'Apple', mass)
end

-- Example usage
local newApple = Apple()
log.d(newApple.keepsDoctorAway)   -- true

-- Checking object types -------------------------------------------------------
local newPineapple = Pineapple()
log.d(newPineapple:is(Apple))   -- false
log.d(newPineapple:is(Fruit))   -- true
log.d(newPineapple:is(Pineapple))   -- true

-- }}} ]]

--[[
local base = { -- Base data that all classes will have.
  class = nil,
  super = nil,
  new = function(self, ...)
  end, -- Used as a constructor when instantiating new instances
  is = function(self, other) -- Type-check method for classes
    local class = self.class
    while class do
      if class == other then
        return true
      end
      class = class.super
    end
    return false
  end,
}
local meta = { -- Used to filter metamethods
  __index = true,
  __newindex = true,
  __call = true,
  __concat = true,
  __unm = true,
  __add = true,
  __sub = true,
  __mul = true,
  __div = true,
  __mod = true,
  __pow = true,
  __tostring = true,
  __metatable = true,
  __eq = true,
  __lt = true,
  __le = true,
  __mode = true,
}

local function newclass(super) -- Used to create new classes, is returned by module
  local class, classMt, instanceMt = {}, {}, {}

  class.class = class
  class.instanceMt = instanceMt

  classMt.__newindex =
      function(t, i, v) -- Any metamethods set to 'class' will be moved over to 'instanceMt'
        if meta[i] then
          instanceMt[i] = v
        else
          rawset(t, i, v)
        end
      end
  classMt.__call = function(t, ...) -- Used to instantiate new instances
    local instance = setmetatable({}, instanceMt)
    instance:new(...)
    return instance
  end

  if super then -- If inheriting, carry over instance metamethods from super to new class
    class.super = super
    classMt.__index = super
    for i, v in pairs(super.instanceMt) do
      instanceMt[i] = v
    end
  else -- If not inheriting, implement base data
    for i, v in pairs(base) do
      class[i] = v
    end
  end
  instanceMt.__index = class

  return setmetatable(class, classMt)
end

return newclass

--]]

-- ————————————————————————————————————————————————————————————————————
-- Alternate
-- TODO: find source!
-- ————————————————————————————————————————————————————————————————————

--[[ {{{
Parent = class(){value = "default"}

Mixin = {}

function Mixin:method(value) 
  self.value = value 
end

Child = class(Parent, Mixin){
  value = "another", 
  init = function(self, value) 
    self:method(value) 
  end
}
}}} --]]

--[[
return function(...)
  local parents = {...}

  return function(add)
    u.pheader('add in inner func')
    u.p(add)
    local child = {}

    -- assign parent fields to child
    for _, parent in pairs(parents or {}) do
      for k, v in pairs(parent) do
        child[k] = v
      end
    end

    -- assign fields given in 
    for k, v in pairs(add or {}) do
      child[k] = v
    end

    return setmetatable(child, {
      -- when Class() is called, pass args to init
      __call = function(self, ...)
        local result = {}
        for k, v in pairs(child or {}) do
          result[k] = v
        end
        result:init(...)
        return result
      end,
    })

  end

end
--]]

-- ———————————————————————————————————————————————————————————————————————————
-- Alternate #3
-- https://github.com/4v0v/class
-- ———————————————————————————————————————————————————————————————————————————

--[[
local Class = {}

function Class:extend(name)
  local obj = {}
  obj.super = self

  obj.class = function()
    return name or "Default"
  end

  obj.new = function() end
  obj.__index = obj
  obj.__call = self.__call
  return setmetatable(obj, self)
end

function Class:__index(v)
  return Class[v]
end

function Class:__call(...)
  local obj = setmetatable({}, self)
  obj:new(...)
  return obj
end

return Class

]]

-- ———————————————————————————————————————————————————————————————————————————
-- Alternate #2
-- WARNING: MODIFIED FROM ORIGINAL FORM
-- https://github.com/niksok13/LuaClass/blob/master/class.lua
-- ———————————————————————————————————————————————————————————————————————————
return function(...)
  local parents = {...}

  local child = {}

  for _, parent in pairs(parents or {}) do
    for k, v in pairs(parent) do
      child[k] = v
    end
  end

  return setmetatable(child, {
    __call = function(self, ...)
      local result = {}
      for k, v in pairs(child or {}) do
        result[k] = v
      end
      return result
    end,
  })

end

