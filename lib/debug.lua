local c = hs.console
local u = require 'stackline.lib.utils'
local json = require 'stackline.lib.json'
-- local json = hs.json



-- ———————————————————————————————————————————————————————————————————————————
-- TIPS
-- ———————————————————————————————————————————————————————————————————————————
-- Interactive stackline state search:
-- TODO: fast way to restart (or auto-restart with hammerspoon)
-- hs -c 'stackline' | jid
-- hs -c 'stackline' | jq
-- hs -c 'stackline' | gron | rg 


-- Console
-- ———————————————————————————————————————————————————————————————————————————
local function dark() -- {{{
    local bg = '#242E38'
    local fg = '#A7BACC'
    c.windowBackgroundColor {hex = bg}
    c.outputBackgroundColor {hex = bg}
    c.inputBackgroundColor {hex = bg}

    c.consoleCommandColor {hex = fg}
    c.consolePrintColor {hex = fg}
    c.consoleResultColor {hex = fg}
    c.alpha(1)
end -- }}}
local function light() -- {{{
    c.windowBackgroundColor {white = 1}
    c.outputBackgroundColor {white = 1}
    c.inputBackgroundColor {white = 1}

    c.consoleCommandColor {white = 0}
    c.consolePrintColor {white = 0}
    c.consoleResultColor {white = 0}
    c.alpha(1)
end -- }}}

local function toggleDark() -- {{{
    local current = c.darkMode()
    c.darkMode(not current)

    if c.darkMode() then
        dark()
    else
        light()
    end
end -- }}}

-- Introspect
-- ———————————————————————————————————————————————————————————————————————————

function getGlobals(onlyType) -- {{{
    for k, v in pairs(_G) do
        if onlyType == nil then
            print(k, v)
        elseif type(v) == onlyType then
            print(k, v)
        end
    end
end -- }}}

local function pruneWindow(table) -- {{{
    if table._win == nil then
        return table
    else
        local input = u.copyShallow(table)
        local remove = {
            _win = true,
            canvas_frame = true,
            config = true,
            iconRadius = true,
            icon_rect = true,
            indicator = true,
            indicator_rect = true,
            screen = true,
            showIcons = true,
            side = true,
            -- stack = true,
            width = true,
        }

        local count = {otherAppWindows = true}

        for k, v in pairs(input) do
            if count[k] then
                input[k] = 'count = ' .. #v
            end
        end

        for k, v in pairs(input) do
            if remove[k] then
                input[k] = nil
            end
        end
        return input
    end
end -- }}}

-- CLI repl
-- ———————————————————————————————————————————————————————————————————————————

local function getFuncParams(func) -- {{{
    local info, params = debug.getinfo(func, 'u'), {}
    for i = 1, info.nparams do
        params[i] = debug.getlocal(func, i)
    end
    if info.isvararg then
        params[#params + 1] = '...'
    end
    return params
end -- }}}

local function getFnDesc(func) -- {{{
    local params = getFuncParams(func)
    local addr = tostring(func):match '%X(%x+)%X*$'
    return 'function@' .. addr .. '(' .. table.concat(params, ', ') .. ')'
end -- }}}

-- Processing
-- ———————————————————————————————————————————————————————————————————————————

--  -- test recurseTables {{{
-- test = {
--     name = 'adam',
--     moments = {1, 2, 3, 4},
--     friends = {
--         {name = 'amy', age = 22},
--         {name = 'carlos', age = 32},
--         {name = 'mom', age = 62},
--     },
--     age = 33,
-- }
-- test.self = test
-- }}}

local function recurseTables(tbl, fn, _d) -- {{{
    -- provide nested "tbl" and "fn" to apply 
    -- to parent tbl & child tables, recursively
    local depth = _d or 0
    if type(tbl) ~= 'table' then
        return tbl
    else
        local copy = u.copyShallow(tbl)
        local processed = fn(copy)
        for k, v in pairs(processed) do
            if type(k) == 'table' then
                if depth > 3 then
                    return tostring(k)
                end
                processed[tostring(k)] = recurseTables(fn(k), fn, depth + 1)
            elseif type(v) == 'table' then
                if depth > 3 then
                    return tostring(k)
                end
                processed[tostring(k)] = recurseTables(fn(v), fn, depth + 1)
            end
        end
        return processed
    end
end -- }}}

procFunc = function(x) -- {{{
    print('calling proc func')
    local input = u.copyShallow(x)
    local remove = {age = true, self = true, friends = true}
    if type(input) ~= 'table' then
        print('input is not table')
        return x
    else
        for k, v in pairs(input) do
            print('for k,v in input')
            print(k)
            if remove[k] then
                input[k] = nil
            end
        end
        return input
    end
end -- }}}

-- print(recurseTables(test, procFunc))

-- Repl
-- ———————————————————————————————————————————————————————————————————————————

local function removeUserdata(obj, d) -- {{{
    local depth = d or 0

    if type(obj) == 'function' then
        return tostring(obj)
    end

    if type(obj) ~= 'table' then
        return obj
    end

    -- otherwise, it's a table…
    local _obj = {}
    obj.__index = nil

    for i, v in pairs(obj) do

        if type(v) == 'userdata' then
            _obj[tostring(i)] = tostring(v)

        elseif type(v) == 'function' then
            _obj[tostring(i)] = getFnDesc(v)

        elseif type(v) == 'table' then
            v = u.copyShallow(v)
            v = pruneWindow(v)
            v.__index = nil
            if depth > 5 then
                return tostring(v)
            end
            if not (type(i) == 'string' or type(i) == 'number') then
                _obj[tostring(i)] = removeUserdata(v, depth + 1)
            else
                _obj[i] = removeUserdata(v, depth + 1)
            end

        elseif type(i) == 'table' then
            i = u.copyShallow(i)
            i.__index = nil
            if depth > 2 then
                return tostring(i)
            end
            -- _obj[tostring(i)] = removeUserdata(i, depth + 1)
            _obj[tostring(i)] = tostring(i)

        elseif type(i) == 'function' then
            _obj[tostring(i)] = getFnDesc(i)

        else
            _obj[tostring(i)] = v
        end

    end -- loop
    return _obj
end -- }}}

local function toJson(i) -- {{{
    local input = removeUserdata(i)
    input = u.deepCopy(input)
    return json:encode(input)
end -- }}}

local function repl(activate) -- {{{
    if activate then
        hs._consoleInputPreparser = function(s)
            return 'd.toJson(' .. s .. ')'
        end
    else
        hs._consoleInputPreparser = nil
    end
end -- }}}

return {
    -- console
    toggleDark = toggleDark,
    light = light,
    dark = dark,

    -- introspect
    getGlobals = getGlobals,
    pruneWindow = pruneWindow,

    -- process
    recurseTables = recurseTables,

    -- repl
    toJson = toJson,
    repl = repl,
    getFnDesc = getFnDesc,
}
