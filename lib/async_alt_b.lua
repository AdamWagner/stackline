local PENDING = 'pending'
local FULFILLED = 'fulfilled'
local REJECTED = 'rejected'

local passthrough = function(x) return x end
local errorthrough = function(x) error(x) end

local function callable_table(callback)
    local mt = getmetatable(callback)
    return type(mt) == 'table' and type(mt.__call) == 'function'
end

local function is_callable(value)
    local t = type(value)
    return t == 'function' or (t == 'table' and callable_table(value))
end

local Promise = {is_promise = true, state = PENDING}
Promise.mt = {__index = Promise}

local run

local function transition(promise, state, value)
    if promise.state == state or promise.state ~= PENDING or
        (state ~= FULFILLED and state ~= REJECTED) then return end

    promise.state = state
    promise.value = value
    run(promise)
end

local function reject(promise, reason) transition(promise, REJECTED, reason) end

local function fulfill(promise, value) transition(promise, FULFILLED, value) end

local function resolve(promise, x)
    if promise == x then
        reject(promise, 'TypeError: cannot resolve a promise with itself')
        return
    end

    local x_type = type(x)

    if x_type ~= 'table' then
        fulfill(promise, x)
        return
    end

    -- x is a promise in the current implementation
    if x.is_promise then
        -- 2.3.2.1 if x is pending, resolve or reject this promise after completion
        if x.state == PENDING then
            x:next(function(value) resolve(promise, value) end,
                   function(reason) reject(promise, reason) end)
            return
        end
        -- if x is not pending, transition promise to x's state and value
        transition(promise, x.state, x.value)
        return
    end

    local called = false
    -- 2.3.3.1. Catches errors thrown by __index metatable
    local success, reason = pcall(function()
        local next = x.next
        if is_callable(next) then
            next(x, function(y)
                if not called then
                    resolve(promise, y)
                    called = true
                end
            end, function(r)
                if not called then
                    reject(promise, r)
                    called = true
                end
            end)
        else
            fulfill(promise, x)
        end
    end)

    if not success then if not called then reject(promise, reason) end end
end
function run(promise)
    if promise.state == PENDING then return end
    Promise.register(function()
        while true do
            local obj = table.remove(promise.queue, 1)
            if not obj then break end

            local success, result = pcall(
                                        function()
                    return (promise.state == FULFILLED and
                               (obj.fulfill or passthrough) or
                               (obj.reject or errorthrough))(promise.value)
                end)

            if not success then
                reject(obj.promise, result)
            else
                resolve(obj.promise, result)
            end
        end
    end)
end
function Promise:next(on_fulfilled, on_rejected)
    local promise = Promise.new()

    table.insert(self.queue, {
        fulfill = is_callable(on_fulfilled) and on_fulfilled or nil,
        reject = is_callable(on_rejected) and on_rejected or nil,
        promise = promise
    })

    run(self)

    return promise
end

function Promise.new(callback)
    local instance = {queue = {}}
    setmetatable(instance, Promise.mt)

    if callback then
        callback(function(value) resolve(instance, value) end,
                 function(reason) reject(instance, reason) end)
    end

    return instance
end

function Promise:catch(callback) return self:next(nil, callback) end

function Promise:resolve(value) fulfill(self, value) end

function Promise:reject(reason) reject(self, reason) end

-- resolve when all promises complete
function Promise.all(...)
    local promises = {...}
    local results = {}
    local remaining = #promises
    results.n = remaining

    local promise = Promise.new()

    if remaining == 0 then
        transition(promise, FULFILLED, results)
    else
        for i, p in ipairs(promises) do
            p:next(function(value)
                results[i] = value
                remaining = remaining - 1
                if remaining > 0 then return end
                transition(promise, FULFILLED, results)
            end, function(value) transition(promise, REJECTED, value) end)
        end
    end

    return promise
end

-- resolve with first promise to complete
function Promise.race(...)
    local promises = {...}
    local promise = Promise.new()

    Promise.all(...):next(nil, function(value) reject(promise, value) end)

    local success = function(value) fulfill(promise, value) end

    for _, p in ipairs(promises) do p:next(success) end

    return promise
end

function Promise.register(callback) callback() end
return Promise
