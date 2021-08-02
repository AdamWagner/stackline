--[[ 
  == class.lua ==

  == Features ==
  Mixins:
  A mixin is just a normal table with functions that expect to be called with some class's instance (with one exception noted below)
  mixin.init(cls):       If the mixin has an `init` function, it will be called when the mixin is added to a class via `use`. You can add class-level attributes in `mixin.init()`
  mixin.new(instance):   If the mixin has a `new` function, it will be called at the end of instance initialization.

  == ADAPTED FROM 2021-07-06 ==
  https://github.com/rxi/classic/blob/master/classic.lua

  == TESTS ==
  ./spec/class_spec.lua
]]

local u = require 'stackline.lib.utils'
local is, len, assign, trycall, dcopy, bind = u.is, u.len, u.assign, u.trycall, u.dcopy, u.bind
local concat, reverse, clear, assignMeta = u.concat, u.reverse, u.clear, u.assignMeta

-- Remove unnecessary keys from `hs.inspect` so it can be assigned to Object.__tostring w/o polluting the console when printing the class
local inspect = clear(hs.inspect, {'_LICENSE', '_DESCRIPTION', '_URL', '_VERSION', 'METATABLE', 'KEY'})
local MIXIN_PATH = 'stackline.modules.mixins'
local instance_base = {__isClass=false}

local registry = {}
local function register(subclass, super, mixins) -- {{{
registry[subclass] = {}
registry[subclass].super = super
registry[subclass].class = subclass
registry[subclass].mixins = mixins
return subclass
end -- }}}
local function super(self) return registry[self:class()].super end 
local function mixins(self) return registry[self:class()].mixins end 
local function setMixins(self, newmixins) concat(registry[self].mixins, newmixins) return self end 

local function cast(i, parent)-- {{{
local mt = u.assignMeta({}, parent)
mt.__index = parent
if parent:isRoot() then mt.__newindex = nil end
return setmetatable(i, mt) -- Cast instance as one of the parent class
end-- }}}
local function maybeAutoconstruct(args, class) --[[ {{{
Implicit constructor sets instance to a copy of the table arg if and only if:
   1. `args` contains a *single* *table*
   2. the immediate parent class does not have a constructor
While convenient, implicit construction has bitten me a couple of times:
Setting instance to the 1st table arg given to `new` can cause lots of problems if there is also an explicit constructor on the immediate parent class.
It might even cause problems if there are *any* explicit constructors on any of the hierarchy - I'm not sure about this.
Copying the table arg (via assign) minimizes the problems caused, but doesn't eliminate them
]]
local noExplicitCtor = class._constructor==nil
local oneTblArg = len(args)==1 and is.tbl(args[1])

if noExplicitCtor and oneTblArg then
  return assign({}, args[1])
end
return {}
end -- }}}
local function invokeConstructors(i, arr, args) --[[ {{{
Invoke `_constructor` with instance & args
1. for every parent (from oldest to immediate parent class)
2. for every mixin (in order added)
]]
local instance = i
u(arr)
  :map('_constructor')
  :each(function(ctor)
    local res = ctor(i, unpack(args))
    if (res==nil) then return end
    instance = res
  end)
return instance
end -- }}}

local mixin = { -- {{{
load = function(mixin) 
  if is.str(mixin) then mixin = require(MIXIN_PATH..'.'..mixin) end
  return dcopy(mixin) -- NOTE: it's important to copy the mixin so that `Proxy` mixin will not share state across instances
end ,
start = function(class, mixin) 
  trycall(mixin.init, class) -- `mixin.init()` can initialize class-level fields & methods.
  return mixin
end, 
apply = function(class, mixin) 
  for k, v in pairs(mixin) do -- Assign all mixin keys to class
    if rawget(class, k)==nil and k~='used' and k~='new' then
      class[k] = v
    end
  end
  return mixin
end, 
renameConstructor = function(mixin)
  -- Important: must occur *after* mixin.apply() or it will overwrite the class's own constructor
  mixin._constructor = rawget(mixin, 'new')
  mixin.new = nil
  return mixin
end,
} -- }}}

local Object = register({}, nil, {})
Object.__name = 'Object'
Object.__index = Object
Object.__tostring = inspect
Object.class = function() return Object end
Object.isRoot = function(self) return self == Object end

function Object:subclass(name) 
local subclass = register({}, self, {})
assignMeta(subclass, self) -- lift metamethods from super → subclass b/c they aren't inherited via `__index`
subclass.__index = subclass
subclass.__name = name or 'Anonymous Class'
subclass.class = function() return subclass end
trycall(self.init, subclass) -- `init()` runs when class is *created*, not when instances are instantiated

return setmetatable(subclass, self)
end 

function Object:new(...) 
local args = {...}
local i = maybeAutoconstruct(args, self)
i = cast(i, self) -- Cast instance as one of the parent class
i = invokeConstructors(i, self:supers(), args) -- 1. Invoke all constructors set on super classes (oldest first)
i = invokeConstructors(i, self:mixins(), args) -- 2. Then all constructors from mixins (in order added)

return i
end 

Object.super = super
Object.mixins = mixins
Object.setMixins = setMixins

function Object:__newindex(k,v) -- {{{
-- Rename 'new' assignments to "__constructor" to be called from within the builtin "new" fn
if k=='new' and is.callable(v) then
  self._constructor = v -- print('Trapping "new" assignment to ', self.__name)
else
  rawset(self, k, v)
end
end -- }}}

function Object:supers() -- {{{
-- All parents & self (oldest to newest)
local lineage = u({}):append(self:class())
local super = self:super()
while super do
  lineage:append(super)
  super = super:super()
end
return lineage:reverse():value()
end -- }}}

function Object:use(...) -- takes (mixin1, mixin2, ...) {{{
return self:setMixins(
  u {...}
    :map(mixin.load)
    :map(bind(mixin.start, self))
    :map(bind(mixin.apply, self))
    :map(mixin.renameConstructor)
    :value()
)
end -- }}}

function Object:is(class) -- {{{
if (class == nil) then return false end
if (class == self) then return true end

classname = is.str(class) and class or class.__name
if classname == self.__name then return true end -- Short circuit on the common case

return u(self:supers())
  :map('__name')
  :contains(classname)
  :value()
end -- }}}

return setmetatable(Object, {__call = Object.subclass })
