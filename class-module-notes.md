# Class module development notes

Was it necessary to write my own class module when there are already too many OOP/class libraries for lua.

Of course not.  

That said, it helped to me understand how classes actually work in lua, and gave me the flexibility to make classes in stackline work exactly the way I want them to.


## REFERENCE

* ~/Programming/Projects/stackline-scratchpad/June-2021/class.lua
* https://github.com/kartoFlane/ITB-ModLoader/blob/master/scripts/mod_loader/bootstrap/classes.lua
* Metamagic helpers: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/metamagic.lua
* Iterators: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/iterators.lua
* Memoize: https://github.com/edubart/nelua-lang/blob/master/nelua/utils/memoize.lua
* https://github.com/Mehgugs/tourmaline-framework/blob/master/framework/libs/oop/oo.lua

### Reference loxy.lua when writing Proxy mixin

https://github.com/ebernerd/Flare/blob/master/lib/class.lua

loxy.lua supports bi-directional getters/setters.

This ends up looking like computed properties to me.

It also supports "signals" & "marshallers" to connect events to instances & process the return values of event handlers.

https://github.com/klokane/loxy/blob/master/loxy/object.lua

```lua
Circle = object({
  radius = 0,
  getArea = function(self)
    return self.radius^2 * PI
  end,
  setArea = function(self, area)
  self.radius = math.sqrt(area / PI)
  end,
})

  -- usage
c = Circle({ area = 20^2*PI })
assert(c.radius == 20)
```

## IDEAS 

### ITERATE OVER NON META KEYS
  https://github.com/djerius/validate.args/blob/d2ae4857681694ee0ecc2c9047191258d2c69c08/src/validate/args.lua#L34

```lua
local function next_notmeta(t, idx)
  local k, v = next(t, idx)
  while k do
    if not k:find( '^__' ) then return k, v end
    k, v = next(t, k) 
  end
  return k, v
end

local function nmpairs( t )
  return next_notmeta, t, nil
end
```


### GET ROOT OBJ FROM CHILD
  FROM https://github.com/djerius/validate.args/blob/master/src/validate/args.lua#L34

```lua
local function getRoot(container)
  local parent = container.parent
  if parent then
    while parent.parent ~= nil do
      parent = parent.parent
    end
  end
  return parent
end
```

### SINGLE FUNCTION BASE CLASS
  FROM: https://github.com/djerius/validate.args/blob/master/src/validate/args.lua#L68

  Create child object
    1. make *shallow* copy of non-function data
    2. call datum:new() if datum is a table and has a new() method

```lua
function Base:new( attr )
  local obj = {}
  -- copy data from parent.  if a datum is an object, call its constructor
  -- so far, all objects stored in children of Base are themselves children
  -- of Base, so this is safe.
  -- does a shallow copy! tables are copied by reference
  for k, v in nmpairs( self ) do
    if (type(v)=='table' and type(v.new)=='function') then
      obj[k] = v:new()
    elseif type(v)~='function' then
      obj[k] = v
    end
  end

  for k, v in nmpairs(attr or {}) do
    obj[k] = v
  end

  setmetatable(obj, self)
  self.__index = self
  self.__newindex = self.__newindex -- inherit __newindex by crawling up the index chain. kinda magical

  return obj
end
```
