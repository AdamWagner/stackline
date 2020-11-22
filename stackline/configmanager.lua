-- setup configmanager logger
local log = hs.logger.new('sline.conf')
log.setLogLevel('info')
log.i("Loading module")

-- local validation helpers
local v = require 'stackline.lib.valid'
local o = v.optional

local function unknownTypeValidator(v)  -- {{{
    log.i("Not validating: ", v)
    return true
end  -- }}}

local M = {}

-- Validation ------------------------------------------------------------------
local is_color = v.is_table {  -- {{{
    white = o(v.is_number()),
    red   = o(v.is_number()),
    green = o(v.is_number()),
    blue  = o(v.is_number()),
    alpha = o(v.is_number()),
}

M.types = {
    ['string']    = { validator = v.is_string, coerce = tostring },
    ['number']    = { validator = v.is_number, coerce = tonumber },
    ['table']     = { validator = v.is_table, coerce = u.identity },
    ['boolean']   = { validator = v.is_boolean, coerce = u.toBool },
    ['color']     = { validator = u.cb(is_color), coerce = u.identity },
    ['winTitles'] = {
        validator = u.cb(v.in_list {true, false, 'when_switching', 'not_implemented'}),
        coerce = u.identity,
    },
    ['dynamicLuminosity'] = {
        validator = u.cb(v.in_list {true, false, 'not_implemented'}),
        coerce = u.identity,
    },
} -- }}}

local defaultOnChangeEvt = {    -- {{{
    __index = function() stackline.queryWindowState:start() end
}  -- }}}

M.events = setmetatable({ -- {{{
    appearance = {
        onChange = function()
            stackline.manager:resetAllIndicators()
        end,
    },
    features = {
        clickToFocus      = function() return stackline:refreshClickTracker() end,
        hsBugWorkaround   = nil,
        winTitles         = nil,
        dynamicLuminosity = nil,
        fzyFrameDetect    = function() stackline.manager:update() end,
    },
    advanced = {
        maxRefreshRate    = function() print('Needs implemented') end,
    },
}, defaultOnChangeEvt) -- }}}

M.schema = { -- {{{
    paths = {getStackIdxs = 'string', jq = 'string', yabai = 'string'},
    appearance = {
        color        = 'color',
        alpha        = 'number',
        dimmer       = 'number',
        iconDimmer   = 'number',
        showIcons    = 'boolean',
        size         = 'number',
        radius       = 'number',
        iconPadding  = 'number',
        pillThinness = 'number',

        vertSpacing  = 'number',
        offset       = { x = 'number', y = 'number' },
        shouldFade   = 'boolean',
        fadeDuration = 'number',
    },
    features = {
        clickToFocus      = 'boolean',
        hsBugWorkaround   = 'boolean',
        winTitles         = 'winTitles',
        dynamicLuminosity = 'dynamicLuminosity',
        fzyFrameDetect    = {enabled = 'boolean', fuzzFactor = 'number'},
    },
    advanced = {maxRefreshRate = 0.3},
} -- }}}

function M:getSchemaForPath(path) -- {{{
    local _type = u.getfield(path, self.schema) -- lookup type in schema
    if not _type then return false end
    local validator = self.types[_type].validator()
    return _type, validator
end -- }}}

function M.generateValidator(schemaType) -- {{{
    if type(schemaType) == 'table' then --  return table of validators built by calling self recursively
        local children = u.map(schemaType, M.generateValidator)
        return v.is_table(children)
    end
    return M.types[schemaType] -- return a single fn to be called with val to validate
            and M.types[schemaType].validator()
            or unknownTypeValidator
end -- }}}

-- Config manager --------------------------------------------------------------
function M:init(conf) -- {{{
    assert(conf, "Initial conf table is required (use the default conf)")
    log.i('Initializing configmanager…')
    ipcConfigPort = hs.ipc.localPort('stackline-config',
        function(_, msgID, msg)
            if msgID == 900 then
                return "version:2.0a" -- if this is not returned, *ipc msgs will NOT work*
            elseif msgID == 500 then
                self:handleMsg(msg)
            end
        end)

    self.__index = self
    return self, self:validate(conf)
end -- }}}

function M:validate(conf) -- {{{
    local c            = conf or self.conf
    local validate     = self.generateValidator(self.schema)
    local isValid, err = validate(c)


    if isValid then
        log.i('✓ Conf validated successfully')
        self.conf = c
        self.autosuggestions = u.keys(table.flatten(self.conf))
    else
        local invalidKeys = table.concat(u.keys(table.flatten(err)), ", ")
        hs.notify.new(nil, {
            title           = 'Invalid stackline config!',
            subTitle        = 'invalid keys:' .. invalidKeys,
            informativeText = 'Please refer to the default conf file.',
            withdrawAfter   = 10
        }):send()

        log.e('Invalid stackline config:', hs.inspect(err))
    end


    return isValid, err
end -- }}}

function M:autosuggest(path) -- {{{
    local scores = u.zip(
            u.map(self.autosuggestions, function(str) return path:distance(str) end), -- list of scores {0.2024, 0.182, 0.991, …}
            self.autosuggestions -- list of strings
        )
    local function asc(a, b)
        return a[1] < b[1]
    end
    table.sort(scores, asc)
    log.d(hs.inspect(scores))

    local result1, result2 = scores[1][2], scores[2][2] -- return the best 2 matches

    hs.notify.new(nil, {
        title = 'Did you mean?',
        subTitle =  string.format('"%s"', result1),
        informativeText = string.format('"%s" is not a default stackline config path', path),
        withdrawAfter = 10
    }):send()

    return result1, result2
end -- }}}

function M:getOrSet(path, val) -- {{{
    if path == nil or val == nil then
        return self:get(path)
    else
        return self:set(path, val)
    end
end -- }}}

function M:get(path) -- {{{
    -- @path is a dot-separated string (e.g., 'appearance.color')
    -- return full config if no path provided
    if path == nil then return self.conf end

    local ok, val = pcall(u.getfield, path, self.conf)

    if ok then
        return val
    else
        self:autosuggest(path)
    end
end -- }}}

function M:set(path, val) -- {{{
    --[[ @path is a dot-separated string (e.g., 'appearance.color')
       @val is the value to set at path
       non-existent path segments will be set to an empty table ]]

    local _type, validator = self:getSchemaForPath(path) -- lookup type in schema

    if _type == nil then
        self:autosuggest(path)
    else
        local typedVal = self.types[_type].coerce(val)
        local isValid, err = validator(typedVal)           -- validate val is appropriate type
        -- log.d('\nval:', typedVal)
        -- log.d('val type:', type(typedVal))
        if isValid then
            -- log.d('Setting', path, 'to', typedVal)
            u.setfield(path, typedVal, self.conf)
            local onChange = u.getfield(path, self.events, true)
            if type(onChange) == 'function' then onChange() end
        else
            -- log.e(hs.inspect(err))
        end
        return self, val
    end

end -- }}}

function M:toggle(key) -- {{{
    local toggledVal = not self:get(key)
    -- log.d('Toggling', key, 'from ', self:get(key), 'to ', toggledVal)
    self:set(key, toggledVal)
    return self
end -- }}}

function M:parseMsg(msg) -- {{{
    local _, path, val = table.unpack(msg:split(':'))
    path = path:gsub("_(.)", string.upper) -- convert snake_case to camelCase
    log.d('path parsed from ipc port', path)

    if type(val) == 'string' then
        val = val:gsub("%W", "") -- remove all whitespace
    end

    -- TODO: resolve 'chicken & egg' problem: need type to fully parse, need to fully parse to get type w/o error
    local _type, validator = self:getSchemaForPath(path)
    local parsedMsg = {
        path      = path,
        val       = val,
        _type     = _type,
        validator = validator,
        isGet     = (path ~= nil) and (val == nil),
        isSet     = (path ~= nil) and (val ~= nil),
        isToggle  = path:match("toggle") ~= nil, -- TODO: add and _type == 'boolean' when todo above is complete
    }

    log.d('Parsed msg:\n', hs.inspect(parsedMsg))
    return parsedMsg
end -- }}}

function M:handleMsg(msg) -- {{{
    log.d('msg', msg)
    local m = self:parseMsg(msg)
    log.d(m)

    if m.isToggle then
        log.d('isToggle')
        local key = m.path
            :gsub('toggle', '')        -- strip leading 'toggle'
            :gsub("^%L", string.lower) -- lowercase 1st character
        self:toggle(key)
        return self:get(key)

    elseif m.isSet then
        log.d('isSet')
        local _, setVal = self:set(m.path, m.val)
        return setVal

    elseif m.isGet then
        log.d('isGet')
        local val = self:get(m.path)
        return val

    else
        log.e('Unparsable IPC message. Try:')
        log.i( '    `echo ":toggle_appearance.show_icons:" | hs -m stackline-config"`')
        log.i( '    `echo ":get_appearance.show_icons:" | hs -m stackline-config"`')
    end

    return "ok"
end -- }}}

return M
