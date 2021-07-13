--[[ {{{ ABOUT
    == ADAPTED FROM ==
        https://github.com/rxi/classic/blob/master/classic.lua

    == WHEN ==
        2021-07-06

    == REF ==
       * ~/Programming/Projects/stackline-scratchpad/June-2021/class.lua
       * https://github.com/kartoFlane/ITB-ModLoader/blob/master/scripts/mod_loader/bootstrap/classes.lua
       * Metamagic helpers: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/metamagic.lua
       * Iterators: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/iterators.lua
       * Memoize: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/memoize.lua

    == IDEAS == {{{

    == BEFORE / AFTER METHOD HOOKS ==  https://github.com/xonglennao/lua-files/blob/master/oo.lua#L45
        function Object:beforehook(method_name, hook)
            local method = self[method_name] or glue.pass
            rawset(self, method_name, function(self, ...)
                return method(self, hook(self, ...))
            end)
        end

        function Object:afterhook(method_name, hook)
            local method = self[method_name] or glue.pass
            rawset(self, method_name, function(self, ...)
                return hook(method(self, ...))
            end)
        end

    == MOVE OBJECT FIELDS WITH DUNDER TO OBJECT'S METATABLE ==
    for k,v in pairs(self) do
        if tostring(k):find("__") then
            getmetatable(self)[k] = v
            self[k] = nil
        end
    end


    == ITERATE OVER NON META KEYS == FROM: https://github.com/djerius/validate.args/blob/d2ae4857681694ee0ecc2c9047191258d2c69c08/src/validate/args.lua#L34
    local function next_notmeta( table, index )

       local k, v = next( table, index )

       while k do
          if not k:find( '^__' ) then
         return k, v
          end
          k, v = next( table, k )
       end

       return k, v

    end

    local function nmpairs( table )
       return next_notmeta, table, nil
    end


    == GET ROOT OBJ FROM CHILD == FROM https://github.com/djerius/validate.args/blob/master/src/validate/args.lua#L34
    local function getRoot(container)
        local parent = container.parent
        if parent then
            while parent.parent ~= nil do
                parent = parent.parent
            end
        end
        return parent
    end

    == SINGLE FUNCTION BASE CLASS == FROM: https://github.com/djerius/validate.args/blob/master/src/validate/args.lua#L68
    -- create child object
    ---   1. make *shallow* copy of non-function data
    ---   2. call datum:new() if datum is a table and has a new() method
    function Base:new( attr )

       local obj = {}

       -- copy data from parent.  if a datum is an object, call its constructor
       -- so far, all objects stored in children of Base are themselves children
       -- of Base, so this is safe.
       -- does a shallow copy! tables are copied by reference
       for k, v in nmpairs( self ) do
          if ( type(v) == 'table' and type(v.new) == 'function' ) then
         obj[k] = v:new()
          elseif type(v) ~= 'function' then
         obj[k] = v
          end
       end

       for k, v in nmpairs( attr or {} ) do
          obj[k] = v
       end

       setmetatable( obj, self )

       self.__index = self

       -- inherit __newindex by crawling up the index chain. kinda magical
       self.__newindex = self.__newindex

       return obj

    end



  == END "IDEAS" == }}}

 }}} ]]

--[[ == TESTS == {{{

class = require 'lib.class'

-- BASIC  -------------------------------------------------------------------------------
Thing = class()
function Thing:new(t) self.name = t.name self.age = t.age end
a = Thing:new({name = 'adam', age = 33, type = 'fun'})


-- NON-TABLE INPUT TO :NEW() ------------------------------------------------------------
Thing = class()
function Thing:new(w) self.frame = w:frame() end
w = stackline.manager:get()[1].windows[1]._win
b = Thing:new(w)

-- CUSTOM CONSTRUCTOR -------------------------------------------------------------------
Thing = class()
function Thing:new(t) self.name = t.name self.age = t.age end
t = Thing:new{name = 'adam', age = 33 }


-- DEFAULT CONSTRUCTOR WITH TABLE ARG ---------------------------------------------------
Thing = class()
a = Thing:new({name = 'me', age = 99})
assert(a.name == "me")
assert(a.age == 99)


-- DEFAULT CONSTRUCTOR WITH NON-TABLE ARGS ----------------------------------------------
Thing = class()
a = Thing:new('me', 99)
assert(a[1] == "me")
assert(a[2] == 99)

-- INHERITANCE ---------------------------
Thing = class()
function Thing:new(t) self.name = t.name self.age = t.age end
Thing.static = {'static', 'field'}
Child = Thing:extend()
c = Child:new({})
c.test = 'test'
for k,v in c:allpairs() do print (k) end

-- INHERITANCE: COUNTER -----------------------------------------------------------------
class = require 'lib.class'
Counter = class('Counter')
function Counter:new()
    print("Calling 'Counter:new()'")
    self.val = 0
    self.isCounter = true
    self.max = 100
end
function Counter:update()
  self.val = self.val + (self.incAmt or 1)
  return self
end

c = Counter:new()

CountByTwo = Counter:extend('CountByTwo')
CountByTwo.incAmt = 2

function CountByTwo:new()
    print("Calling 'CountByTwo:new()'")
    -- self:super()._constructor(self)
    self.isCountByTwo = true
    self.val = 0
end

b = CountByTwo:new()
b:update():update() -- -> 4

-- BEFORE/AFTER HOOKS -------------------------------------------------------------------
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

-- MIXINS -------------------------------------------------------------------------------
class = require 'lib.class'
Utils = class(require 'lib.utils')
t = Utils:new{1,2,3,4,5}

res = t:map(function(x) return x * 2 end)
res -- -> {2,4,6,8,10}


-- MIXINS WITH :new() METHOD ------------------------------------------------------------
class = require 'lib.class'

FlysWhenHavingFun = class()
function FlysWhenHavingFun:new()
    print('running `FlysWhenHavingFun` constructor')
    self.FlysWhenHavingFunMixin = true
    self.incAmt = 20
end

Counter = class('Counter', FlysWhenHavingFun)

function Counter:new() self.val = 0 end
function Counter:update()
  self.val = self.val + (self.incAmt or 1)
  return self
end

c = Counter:new()

-- INHERITANCE W/ MULTIPLE `new()` METHODS ----------------------------------------------
-- Test that ctors are called in expected order

class = require 'lib.class'

FlysWhenHavingFun = class()
function FlysWhenHavingFun:new()
    print('running `FlysWhenHavingFun` constructor')
    self.incAmt = 20
end

Weakling = class()
function Weakling:new()
    self.max = self.max / 11
end

Counter = FlysWhenHavingFun:extend('Counter')
Counter:use(Weakling)

function Counter:new()
    self.max = 100
    self.val = 0
    self.incAmt = self.incAmt / 3
end

function Counter:update()
  if self.val >= self.max then
    printf("We've hit the maximum of %s. I'm tired.", self.max)
    return self.val
  end
  self.val = self.val + (self.incAmt or 1)
  return self
end


c = Counter:new()

 }}} ]]

local u = require 'stackline.lib.utils'

inspect = hs.inspect
for _, key in ipairs({'_LICENSE', '_DESCRIPTION', '_URL', '_VERSION', 'METATABLE', 'KEY'}) do
  inspect[key] = nil
end

local Object = {}
Object.__name = 'Object'
Object.__index = Object
Object.__tostring = inspect

-- Create new subclass
function Object:extend(...)
    local super, subclass, mixins = self, {}, {...}

    -- lift super's metamethods to subclass
    for k, v in u.rawpairs(super) do
        if tostring(k):find('__') == 1 then subclass[k] = v end
    end

    subclass.__index = subclass
    subclass.__name = u.is.str(mixins[1]) and table.remove(mixins,1) or 'Anonymous Class'

    if self.init then self.init(subclass) end

    function subclass:super() return super end
    function subclass:class() return subclass end
    function subclass:mixins() return mixins end
    function subclass:setMixins(newMixins) u.concat(mixins, newMixins) return self end

    setmetatable(subclass, self)
    subclass:use(unpack(mixins))

    return subclass
end

function Object:__newindex(k,v) --[[ {{{
    On attempt to assign a fn to "new", rename it to "__constructor"
    to be called from within the builtin "new" fn. ]]
    if k=='new' and u.is.callable(v) then
        self._constructor = v
    else
        rawset(self, k, v)
    end
end -- }}}

function Object:supers() -- {{{
    -- Get all parents & self in order from newest to oldest.
    local lineage, super = {}, self:super()

    while super do
        table.insert(lineage, super)
        super = super.super and super:super() or nil -- Q: why is `...or nil` required to prevent infinite loop? Shouldn't super be set to `nil` if not super.super?
    end

    lineage = u.reverse(lineage)
    table.insert(lineage, self)
    return lineage
end -- }}}

function Object:new(...)
    local i = setmetatable({}, self)
    local args = {...}

    -- Invoke `_constructor` with instance & args for every:
    --   1. parent (from oldest to immediate parent class)
    --   2. mixin with a `new` method
    u(self:supers()):concat(self:mixins())
        :map('_constructor')
        :values()
        :reverse()
        :each(function(ctor) 
          ctor(i, unpack(args))
        end)

    -- If constructors and/or mixins haven't assigned instance members, simply extend with args
    if u.len(i)==0 then u.safeExtend(i, args) end

    return i
end

function Object:use(...) --[[
  = TEST = {{{
  class = require 'lib.class'
  Counter = class('Counter')
  function Counter:new()
      print("Calling 'Counter:new()'")
      self.val = 0
      self.isCounter = true
      self.max = 100
  end
  function Counter:update()
    self.val = self.val + (self.incAmt or 1)
    return self
  end
  mixin = {}
  function mixin:used() self.hasMixin = true end
  function mixin:talk() print('hi from mixin and', self.__name) end
  function mixin:new() self.HasMixin = true end
  Counter:use(mixin)
  }}} ]]
  local newMixins = {...}

  for _, mix in ipairs(newMixins) do
    -- If present, call `used` method on mixin w/ subclass as `self`
    -- Good for initializing class-level (not instance-level) fields & methods 
    u.trycall(mix.used, self)

    -- Assign functions on mixin to subclass
    for k, v in pairs(mix) do
      if rawget(self, k)==nil and k~='used' then
        self[k] = v
      end
    end

  end

  self:setMixins(newMixins)
  return self
end

function Object:is(class) -- {{{
  if class == nil then return false end
  classname = type(class)=='string' and class or class.__name

  -- Short circuit on the common case for efficiency.
  if classname == self.__name then return true end

  return u(self:supers())
    :map('__name')
    :contains(classname)
    :value()
end -- }}}

function Object:__call(...) -- {{{
    -- TODO: update `extend()` to accept input
    local cls = self:extend(...)
    return cls
end -- }}}

return setmetatable(Object, {__call = Object.__call })


--[[ Nice-to-haves {{{

function Object:beforehook(method_name, hook) -- {{{
    local method = self[method_name] or u.identity
    rawset(self, method_name, function(self, ...)
        return method(self, hook(self, ...))
    end)
end -- }}}

function Object:afterhook(method_name, hook) -- {{{
    local method = self[method_name] or u.identity
    rawset(self, method_name, function(self, ...)
        return hook(method(self, ...))
    end)
end -- }}}

function Object:allpairs() -- {{{
	local t,k,v = self, nil, nil
	return function() -- {{{
		k,v = next(t,k)
		if k == nil then
			t = t.__super
			if t == nil then return nil end
			k,v = next(t)
		end
		return k,v,t
	end -- }}}
end -- }}}

function Object:setAttributes(attr) -- {{{
    if attr ~= nil then
        assert(type(attr) == "table", "table expected")
        for k, v in pairs(attr) do
            assert(type(k) == "string", "attribute names  must be string")
            local setterName = "set"..upper(sub(k, 1, 1))..sub(k, 2)
            local setter = self[setterName]
            assert(type(setter) == "function", "unknown attribute '"..k.."'")
            setter(self, v)
        end
    end
end -- }}}

 }}} ]]
