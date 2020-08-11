local unp = unpack or table.unpack
local getmt = getmetatable
local setmt = setmetatable
local Class = {}
Class.__index = Class
Class.__name = "Object"
Class.__parent = {Class}

local function dump(t, name, indent)
    local cart
    local autoref

    local function isemptytable(t)
        return next(t) == nil
    end

    local function basicSerialize(o)
        local so = tostring(o)
        if type(o) == "function" then
            local info = debug.getinfo(o, "S")
            if info.what == "C" then
                return string.format("%q", so .. ", C function")
            else
                return ("%s, in %d-%d %s"):format(so, info.linedefined,
                    info.lastlinedefined, info.source)
            end
        elseif type(o) == "number" or type(o) == "boolean" then
            return so
        else
            return string.format("%q", so)
        end
    end

    local function addtocart(value, name, indent, saved, field)
        indent = indent or ""
        saved = saved or {}
        field = field or name
        cart = cart .. indent .. field
        if type(value) ~= "table" then
            cart = cart .. " = " .. basicSerialize(value) .. "\n"
        else
            if saved[value] then
                cart = cart .. " = {} -- " .. saved[value] ..
                           " (self reference)\n"
                autoref = autoref .. name .. " = " .. saved[value] .. "\n"
            else
                saved[value] = name
                if isemptytable(value) then
                    cart = cart .. " = {}\n"
                else
                    cart = cart .. " = {\n"
                    for k, v in pairs(value) do
                        k = basicSerialize(k)
                        local fname = string.format("%s[%s]", name, k)
                        field = string.format("[%s]", k)
                        addtocart(v, fname, indent .. "  ", saved, field)
                    end
                    cart = cart .. indent .. "}\n"
                end
            end
        end
    end

    name = name or "__unnamed__"
    if type(t) ~= "table" then
        return name .. " = " .. basicSerialize(t)
    end
    cart, autoref = "", ""
    addtocart(t, name, indent)
    return cart .. autoref
end

local function err(exp, msg, ...)
    local msg = msg:format(...)
    if not (exp) then
        error(msg, 0)
    else
        return exp
    end
end

function Class:create(name, parent, def, G)
    err(type(name) == "string" or type(name) == "nil",
        "Object.new: bad argument #1, string expected, got %s", type(name))
    err(type(parent) == "table" or type(parent) == "nil",
        "Object.new: bad argument #2, class expected, got %s", type(parent))
    err(type(def) == "table" or type(def) == "nil",
        "Object.new: bad argument #3, table expected, got %s", type(def))
    err(type(G) == "boolean" or type(G) == "nil",
        "Object.new: bad argument #4, boolean expected, got %s", type(G))

    local cls = def or {}
    cls.__parent = {self}

    if parent then
        table.insert(cls.__parent, parent)
        for k, v in pairs(parent) do
            if not cls[k] then
                cls[k] = v
            end
        end
        for i, v in ipairs(parent.__parent) do
            if not (parent.__parent[i] == (self or cls or parent)) then
                table.insert(cls.__parent, v)
            end
        end
    end

    cls.__index = cls
    cls.__name = name or "__AnonymousClass__"

    setmt(cls, self)
    if G then
        err(name, "Object.new: no name for global class")
        err(not _G[name], "Object.new: class '%s' already exists", name)
        rawset(_G, name, cls)
    else
        return cls
    end
end

function Class:uses(...)
    err(self.__name ~= "Object",
        "Object.uses: attempt to modify parent class 'Object'")
    local va = {...}
    err(#va >= 1, "Object.uses: one or more classes expected, got %d", #va)
    for idx, cls in pairs(va) do
        err(type(va[idx]) == "table",
            "Object.uses: bad argument #%d, class expected, got %s", idx,
            type(va[idx]))
        for k, v in pairs(cls) do
            if type(v) == "function" and not rawget(self, k) then
                rawset(self, k, v)
            end
        end
    end
end

function Class:is(cls)
    err(type(cls) == "table", "Object.is: bad argument, class expected, got %s",
        type(cls))
    for i, v in ipairs(self.__parent) do
        if self.__parent[i] == cls or self.__name == cls.__name then
            return true
        end
    end
    return false
end

function Class:isClass(obj)
    if not obj or type(obj) ~= "table" then
        return nil
    elseif getmt(obj) == self then
        return true
    elseif getmt(getmt(obj)) == self then
        return true
    else
        return false
    end
end

function Class:dump(details, indent)
    err(type(details) == "boolean" or "nil",
        "Object.dump: bad argument #1, boolean expected, got %s", type(details))
    err(type(indent) == "string" or "nil",
        "Object.dump: bad argument #2, string expected, got %s", type(indent))
    if details then
        return dump(getmt(self), self.__name, indent)
    else
        return dump(self, self.__name, indent)
    end
end

function Class:__call(...)
    if self.__name == "Object" then
        return self:create(...)
    end
    local o = setmt({}, self)
    if rawget(self, "new") then
        o:new(...)
    elseif rawget(self, "init") then
        o:init(...)
    else
        err(nil, "%s: no constructor defined", o.__name)
    end
    return o
end

function Class:__tostring()
    return ("Class '%s'"):format(self.__name)
end
setmt(Class, Class)

return Class
