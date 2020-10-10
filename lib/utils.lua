local log = hs.logger.new('utils')
log.setLogLevel('info')
log.i("Loading module")


-- TODO: consider adding fnutils extensions here: https://github.com/mikeyp/dotfiles/blob/master/hammerspoon/fntools.lua (compose, maybe, result, etc)
-- Also https://github.com/muppetjones/hammerspoon_config/blob/master/util.lua
-- OTHERS ----------------------------------------------------------------------
-- https://github.com/luapower/glue/blob/master/glue.lua
-- https://github.com/Desvelao/f/blob/master/f/table.lua (new in 2020)
-- https://github.com/moriyalb/lamda (based on ramda, updated May 2020, 27 stars)
-- https://github.com/EvandroLG/Hash.lua (new - updated Aug 2020, 7 stars)
-- https://github.com/Mudlet/Mudlet/tree/development/src/mudlet-lua/lua ← Very unusual / interesting lua utils
--
-- Extend builtins -------------------------------------------------------------
function string:split(p) -- {{{
    -- Splits the string [s] into substrings wherever pattern [p] occurs.
    -- Returns: a table of substrings or, a table with the string as the only element
    local p = p or '%s' -- split on space by default
    local temp = {}
    local index = 0
    local last_index = self:len()

    while true do
        local i, e = self:find(p, index)

        if i and e then
            local next_index = e + 1
            local word_bound = i - 1
            table.insert(temp, self:sub(index, word_bound))
            index = next_index
        else
            if index > 0 and index <= last_index then
                table.insert(temp, self:sub(index, last_index))
            elseif index == 0 then
                temp = {self}
            end
            break
        end
    end

    return temp
end -- }}}

function table.merge(t1, t2) -- {{{
    u.pheader('t1')
    u.p(t1)
    u.pheader('t2')
    u.p(t2)
    for k,v in pairs(t2) do
      if type(v) == "table" then
        if type(t1[k] or false) == "table" then
          table.merge(t1[k] or {}, t2[k] or {})
        else
          t1[k] = v
        end
      else
        t1[k] = v
      end
    end
    return t1
end -- }}}

-- utils module ----------------------------------------------------------------
utils = {}

function utils.keyBind(hyper, keyFuncTable) -- {{{
    for key, fn in pairs(keyFuncTable) do
        hs.hotkey.bind(hyper, key, fn)
    end
end -- }}}

-- Alias hs.fnutils methods {{{
utils.map = hs.fnutils.map
utils.filter = hs.fnutils.filter
utils.reduce = hs.fnutils.reduce
utils.partial = hs.fnutils.partial
utils.each = hs.fnutils.each
utils.contains = hs.fnutils.contains
utils.some = hs.fnutils.some
utils.any = hs.fnutils.some -- also rename 'some()' to 'any()'
utils.concat = hs.fnutils.concat
utils.copy = hs.fnutils.copy
-- }}}

-- FROM: https://github.com/rxi/lume/blob/master/lume.lua
function utils.isarray(x) -- {{{
    return type(x) == "table" and x[1] ~= nil
end -- }}}
local getiter = function(x) -- {{{
    if utils.isarray(x) then
        return ipairs
    elseif type(x) == "table" then
        return pairs
    end
    error("expected table", 3)
end -- }}}
function utils.invert(t) -- {{{
    local rtn = {}
    for k, v in pairs(t) do
        rtn[v] = k
    end
    return rtn
end -- }}}
function utils.keys(t) -- {{{
    local rtn = {}
    local iter = getiter(t)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end -- }}}
function utils.find(t, value) -- {{{
    local iter = getiter(t)
    result = nil
    for k, v in iter(t) do
        if k == value then
            result = v
        end
    end
    return result
end -- }}}
-- END lume.lua

-- underscore.lua
function utils.identity(value) -- {{{
    return value
end -- }}}
function utils.iter(list_or_iter) -- {{{
    if type(list_or_iter) == "function" then
        return list_or_iter
    end

    return coroutine.wrap(function()
        for i = 1, #list_or_iter do
            coroutine.yield(list_or_iter[i])
        end
    end)
end -- }}}
function utils.values(t) -- {{{
    local values = {}
    for _k, v in pairs(t) do
        values[#values + 1] = v
    end
    return values
end -- }}}
function utils.extend(destination, source) -- {{{
    for k, v in pairs(source) do
        destination[k] = v
    end
    return destination
end -- }}}
function utils.include(list, value) -- {{{
    for i in Underscore.iter(list) do
        if i == value then
            return true
        end
    end
    return false
end -- }}}
function utils.any(list, func) -- {{{
    for i in utils.iter(list) do
        if func(i) then
            return true
        end
    end
    return false
end -- }}}
function utils.all(vs, fn) -- {{{
    for _, v in pairs(vs) do
        if not fn(v) then
            return false
        end
    end
    return true
end
utils.every = utils.all
-- }}}
-- end underscore.lua

local function f_max(a, b)  -- {{{
    return a > b
end  -- }}}
local function f_min(a, b)  -- {{{
    return a < b
end  -- }}}

function utils.identity(value) -- {{{
    return value
end -- }}}

function utils.invoke(instance, name, ...) -- {{{
    -- FIXME: This doesn't work, but it seems like it should
    --        attempt to index a nil value (local 'instance')
    return function(instance, ...)
        if instance[name] then
            instance[name](instance, ...)
        end
    end
end -- }}}
utils.cb = utils.invoke -- shorter u.cb alias for u.invoke

function utils.cb(fn) -- {{{
    return function()
        return fn
    end
end -- }}}

function utils.extract(list, comp, transform, ...) -- {{{
    -- from moses.lua
    -- extracts value from a list
    transform = transform or utils.identity
    local _ans
    for k, v in pairs(list) do
        if not _ans then
            _ans = transform(v, ...)
        else
            local val = transform(v, ...)
            _ans = comp(_ans, val) and _ans or val
        end
    end
    return _ans
end -- }}}

function utils.setfield(f, v, t) -- {{{
    -- FROM: https://www.lua.org/pil/14.1.html
    log.d(string.format('field: %s, val: %s', f, v))
    local t = t or _G -- start with the table of globals
    for w, d in string.gmatch(f, "([%w_]+)(.?)") do
        if d == "." then -- not last field?
            t[w] = t[w] or {} -- create table if absent
            t = t[w] -- get the table
        else -- last field
            t[w] = v -- do the assignment
        end
    end
end -- }}}

function utils.getfield(f, t, isSafe) -- {{{
    -- FROM: https://www.lua.org/pil/14.1.html
    -- TODO: add 'tryGet()' — safe get that *doesn't* cause other errors during startup

    local v = t or _G -- start with the table of globals
    local res = nil
    for w in string.gmatch(f, "[%w_]+") do

        if type(v) ~= 'table' then
            return v -- if v isn't table, return immediately
        end

        v = v[w]     -- lookup next val

        if v ~= nil then
            res = v  -- only update safe result if v not null
        end

        log.d('utils.getfield — key "word"',w)
        log.d('utils.getfield — "v" is:', v)
        log.d('utils.getfield — "res" is:', res)
    end
    if isSafe then          -- return the last non-nil value found
        if v ~= nil then return v
        else return res end
    else return v           -- return the last value found regardless
    end
end -- }}}

function utils.max(t, transform) -- {{{
    -- from moses.lua
    return utils.extract(t, f_max, transform)
end -- }}}

utils.length = function(t) -- {{{
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end -- }}}

function utils.boolToNum(value) -- {{{
    return value == true and 1 or value == false and 0
end -- }}}

function utils.toBool(val) -- {{{
    -- Reference:
    -- function toboolean( v )
    --   local n = tonumber( v )
    --   return n ~= nil and n ~= 0
    -- end
    local t = type(val)
    if t == 'boolean' then
        return val
    elseif t == 'number' then
        return val == 1 and true or false
    elseif t == 'string' then
        val = val:gsub("%W", "") -- remove all whitespace
        local TRUE = {
            ['1'] = true,
            ['t'] = true,
            ['T'] = true,
            ['true'] = true,
            ['TRUE'] = true,
            ['True'] = true,
        };
        local FALSE = {
            ['0'] = false,
            ['f'] = false,
            ['F'] = false,
            ['false'] = false,
            ['FALSE'] = false,
            ['False'] = false,
        };
        if TRUE[val] == true then
            return true;
        elseif FALSE[val] == false then
            return false;
        else
            return false, string.format('cannot convert %q to boolean', val);
        end
    end
end -- }}}

function utils.isEqual(a, b) -- {{{
    --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
    --]]

    local function isEqualTable(t1, t2)

        if t1 == t2 then
            return true
        end

        -- luacheck: ignore
        for k, v in pairs(t1) do

            if type(t1[k]) ~= type(t2[k]) then
                return false
            end

            if type(t1[k]) == "table" then
                if not isEqualTable(t1[k], t2[k]) then
                    return false
                end
            else
                if t1[k] ~= t2[k] then
                    return false
                end
            end
        end

        for k, v in pairs(t2) do

            if type(t2[k]) ~= type(t1[k]) then
                return false
            end

            if type(t2[k]) == "table" then
                if not isEqualTable(t2[k], t1[k]) then
                    return false
                end
            else
                if t2[k] ~= t1[k] then
                    return false
                end
            end
        end

        return true
    end

    if type(a) ~= type(b) then
        return false
    end

    if type(a) == "table" then
        return isEqualTable(a, b)
    else
        return (a == b)
    end

end -- }}}

function utils.greaterThan(n) -- {{{
    return function(t)
        return #t > n
    end
end -- }}}

function utils.roundToNearest(roundTo, numToRound) -- {{{
    return numToRound - numToRound % roundTo
end -- }}}

function utils.p(data, howDeep) -- {{{
    -- local logger = hs.logger.new('inspect', 'debug')
    local depth = howDeep or 3
    if type(data) == 'table' then
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    else
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    end
end -- }}}

function utils.look(obj) -- {{{
    print(hs.inspect(obj, {depth = 2, metatables = true}))
end -- }}}

function utils.pdivider(str) -- {{{
    str = string.upper(str) or ""
    print("=========", str, "==========")
end -- }}}

function utils.pheader(str) -- {{{
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
end -- }}}

function utils.groupBy(t, f) -- {{{
    -- FROM: https://github.com/pyrodogg/AdventOfCode/blob/1ff5baa57c0a6a86c40f685ba6ab590bd50c2148/2019/lua/util.lua#L149
    local res = {}
    for _k, v in pairs(t) do
        local g
        if type(f) == 'function' then
            g = f(v)
        elseif type(f) == 'string' and v[f] ~= nil then
            g = v[f]
        else
            error('Invalid group parameter [' .. f .. ']')
        end

        if res[g] == nil then
            res[g] = {}
        end
        table.insert(res[g], v)
    end
    return res
end -- }}}

function utils.zip(a, b) -- {{{
    local rv = {}
    local idx = 1
    local len = math.min(#a, #b)
    while idx <= len do
        rv[idx] = {a[idx], b[idx]}
        idx = idx + 1
    end
    return rv
end -- }}}

function utils.copyShallow(orig) -- {{{
    -- FROM: https://github.com/XavierCHN/go/blob/master/game/go/scripts/vscripts/utils/table.lua
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end -- }}}

function utils.deepCopy(obj, seen) -- {{{
    -- from https://gist.githubusercontent.com/tylerneylon/81333721109155b2d244/raw/5d610d32f493939e56efa6bebbcd2018873fb38c/copy.lua
    -- The issue here is that the following code will call itself
    -- indefinitely and ultimately cause a stack overflow:
    --
    -- local my_t = {}
    -- my_t.a = my_t
    -- local t_copy = copy2(my_t)
    --
    -- This happens to both copy1 and copy2, which each try to make
    -- a copy of my_t.a, which involves making a copy of my_t.a.a,
    -- which involves making a copy of my_t.a.a.a, etc. The
    -- recursive table my_t is perfectly legal, and it's possible to
    -- make a deep_copy function that can handle this by tracking
    -- which tables it has already started to copy.
    --
    -- Thanks to @mnemnion for pointing out that we should not call
    -- setmetatable() until we're doing copying values; otherwise we
    -- may accidentally trigger a custom __index() or __newindex()!

    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do
        res[utils.deepCopy(k, s)] = utils.deepCopy(v, s)
    end
    return setmetatable(res, getmetatable(obj))
end -- }}}

function utils.equal(a, b) -- {{{
    if #a ~= #b then
        return false
    end

    for i, _ in ipairs(a) do
        if b[i] ~= a[i] then
            return false
        end
    end

    return true
end -- }}}

function utils.partial(f, ...) -- {{{
    -- FROM: https://www.reddit.com/r/lua/comments/fh2go5/a_partialcurry_implementation_of_mine_hope_you/
    -- WHEN: 2020-08-08
    local unpack = unpack or table.unpack -- Lua 5.3 moved unpack
    local a = {...}
    local a_len = select("#", ...)
    return function(...)
        local tmp = {...}
        local tmp_len = select("#", ...)
        -- Merge arg lists
        for i = 1, tmp_len do
            a[a_len + i] = tmp[i]
        end
        return f(unpack(a, 1, a_len + tmp_len))
    end
end -- }}}

function utils.levenshteinDistance(str1, str2) -- {{{
    local str1, str2 = str1:lower(), str2:lower()
    local len1, len2 = #str1, #str2
    local char1, char2, distance = {}, {}, {}
    str1:gsub('.', function(c)
        table.insert(char1, c)
    end)
    str2:gsub('.', function(c)
        table.insert(char2, c)
    end)
    for i = 0, len1 do
        distance[i] = {}
    end
    for i = 0, len1 do
        distance[i][0] = i
    end
    for i = 0, len2 do
        distance[0][i] = i
    end
    for i = 1, len1 do
        for j = 1, len2 do
            distance[i][j] = math.min(distance[i - 1][j] + 1,
                distance[i][j - 1] + 1, distance[i - 1][j - 1] +
                    (char1[i] == char2[j] and 0 or 1))
        end
    end
    return distance[len1][len2] / #str2 -- note
end -- }}}

function flattenDict(tbl) -- {{{
    --[[ Flattens key,val table,
     preserving *only the final keys*
     FROM: https://github.com/AlexWesterman/GravitationalRacing/blob/master/src/lua/scenario/gravitationalRacing/utils/tableComprehension.lua
 ]]
    if type(tbl) ~= "table" then
        return {tbl}
    end

    local flattenedtbl = {}
    for k1, element in pairs(tbl) do
        for k2, value in pairs(flattenDict(element)) do
            -- If flattenDict is called on a value, k2 will be 1 ie. a number
            if type(k2) ~= "number" then
                -- Value is now a value and not a table (if it was previously)
                flattenedtbl[k2] = value
            else
                flattenedtbl[k1] = value
            end
        end
    end
    return flattenedtbl
end -- }}}

local function isFinite(n) -- {{{
    local INF_POS = math.huge
    local INF_NEG = -INF_POS
    return type(n) == 'number' and (n < INF_POS and n > INF_NEG)
end -- }}}
local function encode(key, val) -- {{{
    -- default do-nothing
    return key, val
end -- }}}
local function setAsTable(tbl, key, val) -- {{{
    tbl[key] = val
end -- }}}

local function _flatten(tbl, maxdepth, encoder, depth, prefix, res, circular, -- {{{
    setter)
    local k, v = next(tbl)
    while k do
        if type(v) ~= 'table' then
            setter(res, encoder(prefix .. k, v))
        else
            local ref = tostring(v)
            -- set value except circular referenced value
            if not circular[ref] then
                if maxdepth > 0 and depth >= maxdepth then
                    setter(res, prefix .. k, v)
                else
                    circular[ref] = true
                    _flatten(v, maxdepth, encoder, depth + 1,
                        prefix .. k .. '.', res, circular, setter)
                    circular[ref] = nil
                end
            end
        end
        k, v = next(tbl, k)
    end
    return res
end -- }}}

function utils.flatten(tbl, maxdepth, encoder, setter) -- {{{
    -- FROM: https://github.com/mah0x211/lua-table-flatten/blob/master/flatten.lua
    local encoder = encode
    local maxdepth = 0
    local setter = setAsTable
    return _flatten(tbl, maxdepth, encoder, 1, '', {}, {[tostring(tbl)] = true},
        setter)
end -- }}}

return utils

