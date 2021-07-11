--[[ {{{
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

]]

--[[ == TESTS ==

class = require 'lib.class'

-- BASIC  ----------------------------------------------
Thing = class()
function Thing:new(t) self.name = t.name self.age = t.age end 
a = Thing:new({name = 'adam', age = 33, type = 'fun'})


-- NON-TABLE INPUT TO :NEW() ----------------------
Thing = class()
function Thing:new(w) self.frame = w:frame() end
w = stackline.manager:get()[1].windows[1]._win
b = Thing:new(w)

-- CUSTOM CONSTRUCTOR --------------------------------
Thing = class()
function Thing:new(t) self.name = t.name self.age = t.age end 
t = Thing:new{name = 'adam', age = 33 }


-- DEFAULT CONSTRUCTOR WITH TABLE ARG ----------------
Thing = class()
a = Thing:new({name = 'me', age = 99})
assert(a.name == "me")
assert(a.age == 99)


-- DEFAULT CONSTRUCTOR WITH NON-TABLE ARGS ------------
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

-- INHERITANCE: COUNTER ---------------------------------
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

-- c = Counter:new()
-- c:update() -- -> 1
-- c:update() -- -> 2

CountByTwo = Counter:extend('CountByTwo')
CountByTwo.incAmt = 2

-- b = CountByTwo:new()
-- b:update():update() -- -> 4

function CountByTwo:new()
    print("Calling 'CountByTwo:new()'")
    -- CountByTwo:super()._constructor(self)
    self.isCountByTwo = true
    self.val = 0
end

b = CountByTwo:new()
b:update():update() -- -> 4

-- BEFORE/AFTER HOOKS --------------------
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

-- MIXINS ---------------------------------
class = require 'lib.class'
Utils = class(require 'lib.utils')
t = Utils:new{1,2,3,4,5}

res = t:map(function(x) return x * 2 end)
res -- -> {2,4,6,8,10}

-- MIXINS WITH :new() METHOD ---------------
class = require 'lib.class'

FlysWhenHavingFun = class() 
function FlysWhenHavingFun:new() 
    print('running `FlysWhenHavingFun` constructor')
    u.p(self)
    self.incAmt = 20 
end

Counter = class(FlysWhenHavingFun)

function Counter:new() self.val = 0 end
function Counter:update() 
  self.val = self.val + (self.incAmt or 1) 
  return self 
end

c = Counter:new()

-- INHERITANCE W/ MULTIPLE `new()` METHODS ----------------
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

-- inspect = getmetatable(hs.inspect).__call
inspect = hs.inspect
inspect._LICENSE = nil
inspect._DESCRIPTION = nil
inspect._URL = nil
inspect._VERSION = nil
inspect.METATABLE = nil
inspect.KEY = nil

local Object = {}
Object.__index = Object
Object.__tostring = inspect

-- Create new subclass
function Object:extend(...) -- {{{
    local mixins = {...}
    local name = u.isstring(mixins[1]) and table.remove(mixins,1) or 'Anonymous Class'
    local subclass = {}

    -- lift superclass's metamethods to subclass
    for k, v in u.rawpairs(self) do
        if tostring(k):find('__') == 1 then subclass[k] = v end
    end

    subclass.__index = subclass
    subclass.__super = self
    subclass.__name = name or 'Anonymous Class'
    subclass._constructors = u.dcopy(self._constructors or {})
    subclass._mixins = self._mixins or {}

    setmetatable(subclass, self)
    subclass:use(unpack(mixins))
    u.trycall(subclass.onExtend, subclass, name, ...)

    return subclass
end -- }}}

function Object:__newindex(k,v) --[[ {{{
    On attempt to assign a fn to "new", rename it to "__constructor" 
    to be called from within the builtin "new" fn. ]]
    if k=='new' then
        -- TODO: Remove this whole mechanism - just set self._constructor.
        -- THEN, update Object:new() to call parent constructor(s) automatically
        if u.iscallable(v) then 
            table.insert(self._constructors, v)
        end
    else
        rawset(self, k, v)
    end
end -- }}}

----- * Everything below ↓ are nice-to-have. The essential bits are above * -----

function Object:new(...) -- {{{
    local i = setmetatable({}, self)
    local args = {...}

    -- 1. Invoke class constuctors (oldest ancestor first, youngest last)
    -- 2. Invoke mixin constructors (in order added)
    u.each({self._constructors, self._mixins}, function(fns) 
        u.each(fns, function(ctor) 
            ctor(i, unpack(args))
        end)
    end)

    -- If constructors & mixins haven't assigned instance members, simply extend with args
    if u.len(i)==0 then u.safeExtend(i, args) end

    return i
end -- }}}

function Object:use(...) -- {{{
  for _, mixin in pairs({...}) do
    for k, v in pairs(mixin) do

      if k=='_constructors' then
          u.concat(u.dcopy(self._mixins), v)
      elseif self[k]==nil and u.iscallable(v) then
        self[k] = v
      end

    end
  end
end -- }}}

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

function Object:super() -- {{{
    local mt = getmetatable(self)
    return mt and mt.__index or nil
end -- }}}


function Object:__call(...) -- {{{
    -- TODO: update `extend()` to accept input
    local cls = self:extend(...)
    return cls
end -- }}}


-- ↓ ↓ EVERYTHING BELOW SHOULD BE MOVED TO NON-BASE OBJECT ↓ ↓ -------------------------

function Object:setAttributes(attr)
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
end




return setmetatable(Object, {__call = Object.__call })
