Modern = require 'lib.Modern'

Org = Modern:extend()
function Org:new(type)
  self.type = type
  return self
end

function Org:id()
  print('I am an organism of type', self.type)
end

function Org:setType(type)
  self.type = type
  return self
end

Animal = Modern:extend()

function Animal:new(species)
  self.species = species
  return self
end

function Animal:talk()
  print('I am an animal of species', self.speices)
end


Human = Animal:extend(Org)
function Human:new(name, species, type)
  self.name = name
  self.__super.new(self, species)
  self:setType(type)
  return self
end

JohnDoe = Human('JohnDoe', 'species-example', 'type-example')



-- Entity = Container:extend()



-- Container with Modern
-- ———————————————————————————————————————————————————————————————————————————
Container = Modern:extend()

function Container:new(o)
  for k,v in pairs(o or {}) do
    self[k] = v
  end
  return self
end



-- Making my custom 'Class' more like Modern
-- ———————————————————————————————————————————————————————————————————————————

Klass = require 'lib.Class2'
Bus = require 'lib.EventBus'

mixin = {}
function mixin:talk() print("I'm talking. My name is:", self.name) end

Human = Class:extend(mixin, Bus)
function Human:new(name)
  self.name = name
  return self
end

function Human:talk()
  print('hi there, I am self.name =', self.name)
  return self
end

JohnDoe = Human:new('JohnDoe')



-- Close
-- ———————————————————————————————————————————————————————————————————————————
Klass = require 'lib.Class2'
Human = Klass()
function Human:new(name, age)
  self.name = name
  self.age = age
  return self
end
function Human:talk()
  print(self.name, 'is talking')
end
JohnDoe = Human:new('JohnDoe', 33)
JaneDoe = Human:new('JaneDoe', 28)


Class = require 'lib.Class'

Human = Class()

function Human:new(name, age)
  self.name = name
  self.age = age
  return self
end

JohnDoe = Human:_new('JohnDoe')



