-- FROM: https://github.com/LinaTsukusu-CCOC/table-util/blob/master/table-util.lua
-- ALT: https://github.com/yaflow-droid/lua-table
local function checkType(a, t)
    return type(a) == t
end
local function isNum(a)
    return checkType(a, "number")
end
local function isStr(a)
    return checkType(a, "string")
end
local function isTable(a)
    return checkType(a, "table")
end


local index = {}

function index:inspect(indent)
    indent = indent or 1
    local space = "  "
    for i = 2, indent do
        space = space .. space
    end

    local ret = "{\n"
    for k, v in pairs(self) do
        ret = ret .. space .. tostring(k) .. " = "
        local value = tostring(v)
        if isTable(v) then
            value = tableUtil(v):inspect(indent + 1)
        elseif isStr(v) then
            value = "\"" .. tostring(v) .. "\""
        end
        ret = ret .. value .. ",\n"
    end
    ret = ret .. space:sub(1, -3) .. "}"
    return ret
end

function index:concat(tbl)
    local new = self:clone()
    local last = #new
    for k, v in pairs(tbl) do
        if isNum(k) then
            new[last + k] = v
        else
            new[k] = v
        end
    end
    return new
end

function index:difference(tbl)
    local this = self:clone()
    local other = tableUtil(tbl):uniq()
    for k, v in pairs(other) do
        keys = this:find(v)
        for i = #keys, 1, -1 do
            this:remove(keys[i])
        end
    end
    return this
end

function index:insert(key, value)
    if value == nil then
        value = key
        key = #self + 1
    end

    local ret = false
    if isNum(key) then
        table.insert(self, key, value)
        ret = true
    elseif isStr(key) then
        self[key] = value
        ret = true
    end
    return ret
end

function index:push(value)
    return self:insert(value)
end

function index:remove(key)
    local ret = false
    if isNum(key) then
        table.remove(self, key)
        ret = true
    elseif isStr(key) then
        self[key] = nil
        ret = true
    end
    return ret
end

function index:pop()
    local ret = self[#self]
    table.remove(self, #self)
    return ret
end

function index:shift()
    local ret = self[1]
    table.remove(self, 1)
    return ret
end

function index:find(value)
    local list = {}
    for k, v in pairs(self) do
        if v == value then
            table.insert(list, k)
        end
    end
    return tableUtil(list)
end

function index:isexist(value)
    for k, v in pairs(self) do
        if v == value then
            return true
        end
    end
    return false
end

function index:clone()
    local meta = getmetatable(self)
    local copy = {}
    for k, v in pairs(self) do
        if isTable(v) then
            copy[k] = tableUtil(v):clone()
        else
            copy[k] = v
        end
    end
    setmetatable(copy, meta)
    return copy
end

function index:clear()
    self = tableUtil({})
end

function index:join(sep, i, j)
    return table.concat(self, sep, i, j)
end

function index:uniq()
    local t = tableUtil({})
    for k, v in pairs(self) do
        if not t:isexist(v) then
            t:push(v)
        end
    end
    return t
end

function index:isempty()
    return #self == 0
end

-- stream
-- 中間操作
function index:map(callback)
    local new = {}
    for k, v in pairs(self) do
        table.insert(new, callback(v, k))
    end
    return tableUtil(new)
end

function index:dmap(callback)
    for k, v in pairs(self) do
        self[v] = callback(v, k)
    end
    return self
end

function index:sort(comparator)
    local new = self:clone()
    table.sort(new, comparator)
    return tableUtil(new)
end

function index:dsort(comparator)
    table.sort(self, comparator)
    return self
end

function index:filter(condition)
    local new = {}
    for i, v in pairs(self) do
        if condition(v, i) then
            table.insert(new, v)
        end
    end
    return tableUtil(new)
end

function index:slice(a, b)
    local start, finish
    if b == nil then
        start = 1
        finish = a
    else
        start = a
        finish = b
    end

    local new = {}
    for i = start, finish do
        table.insert(new, self[i])
    end
    return tableUtil(new)
end


-- 終端操作
function index:each(callback)
    for k, v in pairs(self) do
        callback(v, k)
    end
end

function index:foreach(callback)
    return self:each(callback)
end

function index:matchAll(condition)
    for k, v in pairs(self) do
        if not condition(v, k) then
            return false
        end
    end
    return true
end

function index:matchAny(condition)
    for k, v in pairs(self) do
        if condition(v, k) then
            return true
        end
    end
    return false
end

function index:sum()
    local sum = 0
    for i, v in pairs(self) do
        sum = sum + v
    end
    return sum
end


function index:mul(other)
    if isNum(other) then
        local this = self:clone()
        for i = 1, other do
            this = this + this
        end
        return this
    elseif isStr(other) then
        return self:join(other)
    end
end

tableUtil = setmetatable({
    __index = index,
    __tostring = index.inspect,
    __add = index.concat,
    __sub = index.difference,
    __mul = index.mul,
}, {
    __index = table,
    __call = function(self, tbl)
        return setmetatable(tbl, self)
    end
})

return tableUtil
