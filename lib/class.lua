
--[[ INFO {{{
    == ABOUT ==
    class.lua — a base class and newClass() function to create new classes or subclasses
    ADAPTED FROM: https://github.com/Elektrum-77/ClassLibLua/blob/main/ObjectLib.lua

    == DOCUMENTATION ==
    A basic example will be used:
        Box = newClass()
        Box.fields = { 'w', 'h' }
        b = Box:new { w = 5, h = 2 }

    'Box' inherits from 'Base'.
    Indexing 'Box' falls back to Base if not found:

        type(Box.new)=='function'
        --> true

    Indexing instances falls back to Class, and then up the inheritance chain.
    So Class fields from any level can be accessed via an instance:

        b.fields[1] == 'w'

    This has consequences with the 'fields' property:
    A field may be set at the class level that *isn't defined on the instance*
    For example:

        Box.fields = { 'w', 'h', 'color' }
        Box.color = 'red'
        b = Box:new { w = 1, h = 2 }
        b:get()
        --> { w = 1, h = 2, color = 'red' }

    Fields may always be overwritten on the instance without affecting the class:

        b.color = 'green'
        b:get()
        --> { w = 1, h = 2, color = 'green' }
        Box.color
        --> 'red'

    Instances pick up changes to classes after instantiation:

        Box = newClass()
        Box.fields = { 'w', 'h' }
        b = Box:new { w = 1, h = 2 }
        b:area()
        --> Error: Method 'area' is not callable
        function Box:area() return self.w * self.h end
        b:area()
        --> 2

    == REFERENCE ==
    "Properties" module from Microlight library. Similar to cp.prop from CommandPost project.
    https://github.com/stevedonovan/Microlight/blob/master/ml_properties.lua

    cp.prop module from CommandPost project:
    https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/prop/init.lua

 }}} ]]

--[[ TEST {{{

Base = require 'lib.class-2'

Utils = newClass()
Utils.fields = { name = 'utils', test = 123 }
function Utils:info()
    print('info about', self.type, 'from utils class')
    print(self.type, 'area is', self:area())
    return self
end

Box = newClass()
Box.type = 'Box'
Box.fields = { 'w', 'h', 'name' }

function Box:area()
    return self.w * self.h
end


b = Box:new{ w = 5, h = 3, color = 'red' }
b.size = 'large'
b:get()

b1 = Box:new { w = 5, h = 55, color = 'blue' }

Rect = newClass(Box)
r = Rect:new { w = 55, h = 11 }
r:get()

Rect:mixin(Utils)
r:info()

Poly = newClass(Rect)

Poly.super.super.super == Base
Poly.super.super == Box
Poly.super == Rect


-- Extra testing


function Box:__eq(x)
    return x.w == self.w
end

for k,v in b:pairs() do print(k,v) end

 }}} ]]

-- Check dependencies
assert(u, "class.lua requires global utils available at 'u'")
assert(u.pick, "class.lua requires 'u.pick()' util fn")
assert(u.dcopy, "class.lua requires 'u.dcopy()' util fn")
assert(u.isfunc, "class.lua requires 'u.isfunc()' util fn")

-- === Base class ===
local Base = {}
Base.isClass = function() return true end
Base.fields = {}
Base.__index = Base

function Base:is(cls) -- {{{
    -- Could try to traverse tree of "supers" to see if any of the classes
    -- *parents* are equal to the given cls, but that's not something I need now.
    return getmetatable(self) == cls
end -- }}}

function Base:initFields(tbl) -- {{{
    for _, k in ipairs(self.fields) do
        self[k] = tbl[k]
    end
end -- }}}

function Base:__newindex(k,v) -- {{{
    -- Auto-wrap "new" method: If user tries to assign a fn to "new", rename it
    -- to "_new" to be called from within the builtin "new" fn
    if k=='new' and u.isfunc(v) then
        rawset(self, '_'..k, v)
    else
        rawset(self, k, v)
    end
end -- }}}

function Base:new(tbl) -- {{{
    local o = setmetatable({}, self)

    if u.isfunc(self._new) then
        -- Call custom "new" fn and capture output
        -- May return transformed tbl to be given to o:initFields(_tbl)
        local _tbl = o:_new(tbl)
    end

    -- If needed, automatically assign all k,v in given tbl to "o"
    if #u.keys(o)==0 then
        o:initFields(_tbl or tbl or {})
    end

    return o
end -- }}}

function Base:mixin(...) -- {{{
    for _, cls in pairs({...}) do
        for k, v in pairs(cls) do
            if self[k]==nil and u.isfunc(v) then
                self[k] = v
            end
        end
    end
end -- }}}

function Base:get() -- {{{
    -- Return keys specified in self.fiels only
    return u.pick(self.fields, self)
end -- }}}

function Base:pairs() -- {{{
    -- Return the pairs of the object without internal object attributes
    -- See also: https://stackoverflow.com/questions/18177101/only-exposing-an-objects-attributes
    -- See also: Base:__allpairs() traverses up inheritance chain to get ALL props. https://github.com/AlexKordic/lua-files/blob/master/winapi/object.lua#L42
    return pairs(self:get())
end -- }}}

-- === newClass() - global function ===
function _G.newClass(parent)
    cls = u.dcopy(parent or {}) -- deep copy table to avoid mutating the inherited class
    cls.super = parent or Base -- but set super to original (not copied) parent or Base
    cls.__index = cls
    return setmetatable(cls, cls.super) -- Set metatable on *class* to cls.super (parent or base)
end

return Base
