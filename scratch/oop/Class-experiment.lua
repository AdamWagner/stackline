-- https://github.com/okahyphen/base
-- Fantaistically written readme is worth checking out.
local Base = { fn = {} }

local function new (self, ...)
    local instance = { __index = self.fn }

    setmetatable(instance, instance)
    self.__initializer(self.__source, instance, ...)

    return instance
end

function Base:derive (initializer)
    local Derivative = {
	__call = new,
	__index = self,
	__initializer = initializer,
	fn = { __index = self.fn }
    }

    function Derivative.__source (instance, ...)
	self.__initializer(self.__source, instance, ...)
    end

    setmetatable(Derivative.fn, Derivative.fn)

    return setmetatable(Derivative, Derivative)
end

return Base
