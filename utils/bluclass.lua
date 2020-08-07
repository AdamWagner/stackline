local bluclass = {
    _VERSION        = 'bluclass 1.1.0',
    _DESCRIPTION    = 'Lua OOP module with simple inheritance',
    _URL            = 'https://github.com/superzazu/bluclass.lua',
    _LICENSE        = [[
Copyright (c) 2015-2019 Nicolas Allemand

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
}

bluclass.class = function(super)
    local class = {}
    class.super = super

    class.new = function(self, ...)
        local instance = {}
        instance.class = self

        setmetatable(instance, {__index = function(t, key)
            if self[key] then
                return self[key]
            elseif self.super and self.super[key] then
                return self.super[key]
            end
        end})

        if instance.init then
            instance:init(...)
        end

        return instance
    end

    return class
end

return bluclass
