--- The keywords can optionally be used with another library by directly requiring this file
--- @usage
--- async, await = require "orderly/keywords" (MyPromiseLib, function(promise, handler) promise:Then(handler) end, function(promise, handler) promise:Catch(handler) end)
local coroMap = {}
local function resume(co, ...)
    local response = table.pack(coroutine.resume(co, ...))
    if table.remove(response, 1) then
        if coroutine.status(co) == 'dead' then
            coroMap[co]:resolve(table.unpack(response))
        end
    else
        coroMap[co]:reject(table.unpack(response))
    end
end
return function(create, onsuccess, onfailure)
    return function(func)
        return function(...)
            local co = coroutine.create(func)
            local promise = create()
            coroMap[co] = promise
            resume(co, ...)
            return promise
        end
    end, function(promise)
        local co, TTS_main = coroutine.running()
        if TTS_main or not co then
            error("await is only valid in async function")
        end
        onsuccess(promise, function(...) resume(co, ...) end)
        onfailure(promise, function(...) coroMap[co]:reject(...) end)
        return coroutine.yield()
    end
end
