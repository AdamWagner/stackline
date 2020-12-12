-- FROM: https://github.com/faimin/LuaKVO
--
-- AlTNERATIVES:
--   https://github.com/Phrogz/notifitable/blob/master/notifitable.lua
--   https://github.com/ZichaoNickFox/ReactiveTable
--   https://github.com/klokane/loxy (big - also offers OOP stuff)
--   https://github.com/hgiesel/lua-observer
--   https://github.com/zhaolihang/lua-observer-watcher (complex)

--   Very simple:
--   https://github.com/w775198287/projects/blob/master/blackjackgame/src/utils/TableUtils.lua#L83
--
--   Unclear, but new (2019) and simple
--   https://github.com/niksok13/ReactiveDict/blob/master/rdict.lua
--
--   INSPIRATION
--   Port of bacon.js (reactive programming.
--   https://github.com/mrunderhill89/bacon.lua

local u = require 'lib.utils'

-- Helpers
-- ———————————————————————————————————————————————————————————————————————————
local function proxy_kvo_key(trackKey)  -- {{{
    return ("_kvo_" .. trackKey)
end  -- }}}

local function add_callback(proxy, key, callback)  -- {{{
    if not key then return end

    local kvokey = proxy_kvo_key(key)
    local callbackFuncs = proxy[kvokey]

    if not callbackFuncs then
        callbackFuncs = {}
        proxy[kvokey] = callbackFuncs
    end

    table.insert(callbackFuncs, callback)
end  -- }}}

local function splitKeyPathWithDot(keypath)  -- {{{
    assert(type(keypath) == "string")
    local words = {}
    for s in string.gmatch(keypath, "[^.]+") do
        table.insert(words, s)
    end
    u.p(words)
    return words
end  -- }}}

local function getFromTrackKey(tbl, trackKey)  -- {{{
    -- TODO: Determine if this can be replaced with u.getfield()
    if type(trackKey) == "number" then
        trackKey = tostring(trackKey)
    end

    local keys = splitKeyPathWithDot(trackKey)
    trackKey = table.remove(keys)

    local penultimateTbl = tbl
    local lastKey = nil
    for i, v in ipairs(keys) do
        local index = i

        if i > 1 then
            index = i - 1
        end

        assert(type(tbl) == "table", string.format("Table expected - got %s", type(tbl)))

        tbl = tbl[v]

        if i == #keys - 1 then
            penultimateTbl = tbl
        elseif i == #keys then
            lastKey = v
        end
    end

    return lastKey, penultimateTbl
end  -- }}}

-- Module
-- ———————————————————————————————————————————————————————————————————————————
local M = {}

function M.add(tbl, trackKey, changeFunc)
    if not tbl or type(tbl) ~= "table" then
        assert(false, "'tbl' must exist and be type table in observe.add(tbl, trackKey, changeFunc)")
        return tbl
    end

    if tbl.is_kvo_proxy then  -- {{{
        add_callback(tbl, trackKey, changeFunc)
        return tbl
    end  -- }}}

    local proxy = { is_kvo_proxy = true }

    local lastKey, penultimateTbl = getFromTrackKey(tbl, trackKey)
    if penultimateTbl and lastKey then
        penultimateTbl[lastKey] = proxy
    end

    add_callback(proxy, trackKey, changeFunc)

    local proxy_mt = {}
    function proxy_mt:__index(k)  -- {{{
        return tbl[k] or proxy_mt[k]
    end  -- }}}
    function proxy_mt:__newindex(k, v)  -- {{{
        assert(k, "key must not be nil (kvo proxy_tbl.__newindex())")
        local oldValue = tbl[k]

        tbl[k] = v

        local kvokey = proxy_kvo_key(k)
        if proxy[kvokey] then
            for i, callback in ipairs(proxy[kvokey]) do
                callback(k, oldValue, v)
            end
        end
    end  -- }}}
    function proxy_mt:__pairs()  -- {{{
        return function(self, k)
            local nextkey, nextvalue = next(tbl, k)
            return nextkey, nextvalue
        end
    end  -- }}}
    function proxy_mt:__ipairs() -- {{{
        local function iter(t, i)
            i = i + 1
            local v = t[i]
            if v then
                return i, v
            end
        end

        return iter, tbl, 0
    end  -- }}}
    function proxy_mt:__len()  -- {{{
        return #tbl
    end  -- }}}
    function proxy_mt:__tostring()  -- {{{
        if tbl.__tostring then
            return tbl:__tostring()
        else
            return tostring(tbl)
        end
    end  -- }}}

    -- YAY! We can now get the onChange fns registered to keys,
    -- so theoretically, we can clone tables *with* kv observers / watchers!
    -- I think that u.copyDeep() should be modified to handle tables with
    -- watched values (rather than implementing a custom proxy_mt:clone() method)… but I'm not 100% confident about this.

    -- I'm also a little worried about the performance, tho.
    function proxy_mt:getOnChangeCallbacks()  -- {{{
        local callbacks = {}
        for k in pairs(tbl) do
            callbacks[k] = self[proxy_kvo_key(k)]
        end
        return callbacks
    end  -- }}}

    setmetatable(proxy, proxy_mt)

    return proxy
end

function M.remove(proxy, key)  -- {{{
    if not key or not proxy then
        return
    end

    if type(key) == "number" then
        key = tostring(key)
    end

    local keys = splitKeyPathWithDot(key)

    key = table.remove(keys)

    for i, v in ipairs(keys) do
        local index = i
        if i > 1 then
            index = i - 1
        end
        assert(type(proxy) == "table", string.format("keypath 中的 %s 不是table", keys[index]))
        proxy = proxy[v]
    end

    local kvokey = proxy_kvo_key(key)
    local callbackFuncs = proxy[kvokey]

    if callbackFuncs then
        local count = #callbackFuncs
        for i = 1, count do
            table.remove(callbackFuncs)
        end
    end

    proxy[kvokey] = nil;
end  -- }}}

return M
