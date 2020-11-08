package.path = '/Users/adamwagner/.luarocks/share/lua/5.4/?.lua;' .. package.path

mm = require 'mm'
local c = hs.console
local u = require 'stackline.lib.utils'
local json = require 'stackline.lib.json'

-- TIPS
-- ———————————————————————————————————————————————————————————————————————————
-- Interactive stackline state search:
-- TODO: fast way to restart (or auto-restart with hammerspoon)
-- hs -c 'stackline' | jid
-- hs -c 'stackline' | jq
-- hs -c 'stackline' | gron | rg

-- Console
-- See for more inspo:
-- https://github.com/hendri54/hammerspoon/blob/master/hsLH.lua
-- https://github.com/irliao/dotfiles/blob/master/hammerspoon/console.lua
-- ———————————————————————————————————————————————————————————————————————————
hs.console.consoleFont({name = 'Operator Mono', size = 12})

local function size(n)  -- {{{
    hs.console.consoleFont({size = n, name = 'Operator Mono'})
end  -- }}}

local function colorize(bg, fg)  -- {{{
    c.windowBackgroundColor({hex = bg})
    c.outputBackgroundColor({hex = bg})
    c.inputBackgroundColor({hex = bg})

    c.consoleCommandColor({hex = fg})
    c.consolePrintColor({hex = fg})
    c.consoleResultColor({hex = fg})
    c.alpha(1)
end  -- }}}

local dark = '#1b232d'
local light = '#A7BACC'

local function darkTheme() -- {{{
    colorize(dark, light)
end -- }}}
local function lightTheme() -- {{{
    colorize(light, dark)
end -- }}}

local function toggleDark() -- {{{
    c.darkMode(not c.darkMode())

    if c.darkMode() then
        darkTheme()
    else
        lightTheme()
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

-- Repl
-- ———————————————————————————————————————————————————————————————————————————
local function removeUserdata(obj, d) -- {{{
    local depth = d or 0

    if type(obj) == 'function' then
        return tostring(obj)
    elseif type(obj) ~= 'table' then
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
            v = pruneWindow(v)
            v = u.copyShallow(v)
            v.__index = nil

            if depth > 5 then return tostring(v) end

            if not (type(i) == 'string' or type(i) == 'number') then
                _obj[tostring(i)] = removeUserdata(v, depth + 1)
            else
                _obj[i] = removeUserdata(v, depth + 1)
            end

        -- if the KEY is a table tho… just stringify it
        elseif type(i) == 'table' then
            i = u.copyShallow(i)
            i.__index = nil

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

function shouldInspect(input)  -- {{{
    local skipIfContains = {'%s', 'help', 'test()'}
    for _, v in pairs(skipIfContains) do
        if input:find(v) then return false end
    end
    return true
end  -- }}}

local function inspectByDefault(activate) -- {{{
    if activate then
        hs._consoleInputPreparser = function(s)
            -- TODO: don't count equals signs in parens

            if shouldInspect(s) then
                return 'hs.inspect(' .. s .. ')'
            else
                return s
            end
        end
    else
        hs._consoleInputPreparser = nil
    end
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
    light = lightTheme,
    dark = darkTheme,
    size = size,

    -- introspect
    getGlobals = getGlobals,
    pruneWindow = pruneWindow,

    -- repl
    toJson = toJson,
    repl = repl,
    inspectByDefault = inspectByDefault,
    getFnDesc = getFnDesc,
}
