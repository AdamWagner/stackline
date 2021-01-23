-- https://github.com/erento/lua-schema-validation
local log = hs.logger.new('sline.conf')
log.setLogLevel('info')
log.i('Loading module')

local M = {}

-- Validators & type lookup
local v = require 'stackline.lib.valid'
local o = v.optional
local is_color = v.is_table { -- {{{
    white = o(v.is_number()),
    red   = o(v.is_number()),
    green = o(v.is_number()),
    blue  = o(v.is_number()),
    alpha = o(v.is_number()),
} -- }}}
local function unknownTypeValidator(val) -- {{{
    log.i('Not validating: ', val)
    return true
end -- }}}

M.types = { -- {{{
    ['string'] = {
        validator = v.is_string,
        coerce = tostring,
    },
    ['number'] = {
        validator = v.is_number,
        coerce = tonumber,
    },
    ['table'] = {
        validator = v.is_table,
        coerce = u.identity,
    },
    ['boolean'] = {
        validator = v.is_boolean,
        coerce = u.toBool,
    },
    ['color'] = {
        validator = u.cb(is_color),
        coerce = u.identity,
    },
    ['winTitles'] = {
        validator = u.cb(v.in_list { true, false, 'when_switching', 'not_implemented', }),
        coerce = u.identity,
    },
    ['dynamicLuminosity'] = {
        validator = u.cb(v.in_list {true, false, 'not_implemented'}),
        coerce = u.identity,
    },
} -- }}}

local defaultOnChangeEvt = {   -- {{{
    __index = function() stackline.queryWindowState:start() end
}  -- }}}

M.events = setmetatable({ -- {{{
    appearance = {
        onChange = function() stackline.manager:resetAllIndicators() end,
    },
    features = {
        clickToFocus      = function() return stackline:refreshClickTracker() end,
        maxRefreshRate    = nil,
        hsBugWorkaround   = nil,
        winTitles         = nil,
        dynamicLuminosity = nil,
    },
    advanced = {
        maxRefreshRate = function() print('Needs implemented') end,
    },
}, defaultOnChangeEvt) -- }}}

M.schema = { -- {{{
    paths = {
      getStackIdxs        = 'string',
      jq                  = 'string',
      yabai               = 'string'
    },
    appearance = {
        color             = 'color',
        alpha             = 'number',
        dimmer            = 'number',
        iconDimmer        = 'number',
        showIcons         = 'boolean',
        size              = 'number',
        radius            = 'number',
        iconPadding       = 'number',
        pillThinness      = 'number',

        vertSpacing       = 'number',
        offset            = {x='number', y='number'},
        shouldFade        = 'boolean',
        fadeDuration      = 'number',
    },
    features = {
        clickToFocus      = 'boolean',
        hsBugWorkaround   = 'boolean',
        winTitles         = 'winTitles',
        dynamicLuminosity = 'dynamicLuminosity',
        fzyFrameDetect    = { enabled = 'boolean', fuzzFactor = 'number' },
    },
    advanced = {
        maxRefreshRate = 0.3,

    }
} -- }}}

function M:getPathSchema(path) -- {{{
    local _type = table.getPath(path, self.schema) -- lookup type in schema
    if not _type then return false end
    local validator = self.types[_type].validator()

    return _type, validator
end -- }}}

function M.generateValidator(schemaType) -- {{{
    if type(schemaType)=='table' then -- recursively build validator
        local children = u.map(schemaType, M.generateValidator)
        log.d('validator children:\n', hs.inspect(children))
        return v.is_table(children)
    end

    -- otherwise, return validation fn forgiven type
    log.i('schemaType:', schemaType)
    return M.types[schemaType]                  -- if schemaType is a known config type..
            and M.types[schemaType].validator() -- then return validation fn
            or unknownTypeValidator             -- otherwise, unknown types are assumed valid
end -- }}}

-- Config manager
function M:init(conf) -- {{{
    log.i('Initializing configmanager…')
    self:validate(conf)
    self.__index = self
    return self
end -- }}}

function M:validate(conf) -- {{{
    local c            = conf or self.conf
    local validate     = self.generateValidator(self.schema)
    local isValid, err = validate(c)

    if isValid then
        log.i('✓ Conf validated successfully')
        self.conf = conf
        self.autosuggestions = u.keys(u.flatten(self.conf))
    else
        local invalidKeys = table.concat(u.keys(u.flatten(err)), ', ')
        log.e('Invalid stackline config:\n', hs.inspect(err))
        hs.notify.new(nil, {
            title           = 'Invalid stackline config!',
            subTitle        = 'invalid keys:' .. invalidKeys,
            informativeText = 'Please refer to the default conf file.',
            withdrawAfter   = 10
        }):send()
    end

    return isValid, err
end -- }}}

function M:autosuggest(path) -- {{{
    local dist = u.partial(u.distance, path) -- lev.d fn that can be mapped over list of candidates
    local scores = u.zip(
            u.map(self.autosuggestions, dist),          -- list of scores {0.2024, 0.182, 0.991, …}
            self.autosuggestions                        -- list of strings
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
end -- }}}

function M:getOrSet(path, val) -- {{{
    if path and val then
        return self:set(path, val)
    end

    return self:get(path)
end -- }}}

function M:get(path) -- {{{
    -- @path is a dot-separated string (e.g., 'appearance.color')
    -- return full config if no path provided
    if path == nil then return self.conf end

    local ok, val = pcall(table.getPath, path, self.conf)

    if ok then return val
    else self:autosuggest(path)
    end
end -- }}}

function M:set(path, val) -- {{{
    --[[ @path is a dot-separated string (e.g., 'appearance.color')
       @val is the value to set at path
       non-existent path segments will be set to an empty table ]]

    local _type, validator = self:getPathSchema(path) -- lookup type in schema

    if _type == nil then
        self:autosuggest(path)
        return self
    end

    local typedVal = self.types[_type].coerce(val)
    local isValid, err = validator(typedVal)           -- validate val is appropriate type

    log.d('\nval:', typedVal, '\nval type:', type(typedVal))

    if not isValid then
        log.e(hs.inspect(err))
        return self
    end

    log.d('Setting', path, 'to', typedVal)

    table.setPath(path, typedVal, self.conf)

    local onChange = table.getPath(path, self.events, true)
    if type(onChange) == 'function' then onChange() end
    return self, val

end -- }}}

function M:toggle(key) -- {{{
    local val = self:get(key)
    if type(val)~='boolean' then log.w(key, 'cannot be toggled because it is not boolean') end
    local toggledVal = not val
    log.d('Toggling', key, 'from ', val, 'to ', toggledVal)
    self:set(key, toggledVal)
    return self
end -- }}}

return M
