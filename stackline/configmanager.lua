-- https://github.com/erento/lua-schema-validation
local log = hs.logger.new('configmgr', 'info')
local v = require 'lib.valid' -- Validators & type lookup
local o = v.optional

local is_color = v.is_table {
    white = o(v.is_number()),
    red   = o(v.is_number()),
    green = o(v.is_number()),
    blue  = o(v.is_number()),
    alpha = o(v.is_number()),
}

local function unknownTypeValidator(val)
    log.i('Not validating: ', val)
    return true
end

-- === Config module ===
log.i('Loading module: stackline.configmanager')

local Config = {}

Config.types = { -- {{{
    -- validator & coerce mthods for each type found in stackline config
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

local defaultOnChangeEvt = { -- {{{
    __index = function() stackline.queryWindowState:start() end
}  -- }}}

Config.events = setmetatable({ -- {{{
    -- Map stackline actions to config keys
    -- If config key changes, perform action
    appearance = function() stackline.manager:resetAllIndicators() end,
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

Config.schema = { -- {{{
    -- Set type for each stackline config key
    paths = {
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
        maxRefreshRate = 'number',
    }
} -- }}}

function Config:init(conf) -- {{{
    log.i('Initializing configmanager…')
    self:validate(conf)
    self.__index = self
    return self
end -- }}}

function Config:getPathSchema(path) -- {{{
    local _type = u.getfield(path, self.schema) -- lookup type in schema
    if not _type then return false end
    local validator = self.types[_type].validator()

    return _type, validator
end -- }}}

function Config.generateValidator(schemaType) -- {{{
    if u.istable(schemaType) then -- recursively build validator
        local children = u.map(schemaType, Config.generateValidator)
        log.d('validator children:\n', hs.inspect(children))
        return v.is_table(children)
    end

    -- otherwise, return validation fn forgiven type
    log.d('schemaType:', schemaType)
    return Config.types[schemaType]                  -- if schemaType is a known config type..
            and Config.types[schemaType].validator() -- then return validation fn
            or unknownTypeValidator             -- otherwise, unknown types are assumed valid
end -- }}}

function Config:validate(conf) -- {{{
    local c            = conf or self.conf
    local validate     = self.generateValidator(self.schema)
    local isValid, err = validate(c)

    if isValid then
        log.i('✓ Conf validated successfully')
        self.conf = conf
        self.autosuggestions = u.keys(u.flattenPath(self.conf))
    else
        local invalidKeys = table.concat(u.keys(u.flattenPath(err)), ', ')
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

function Config:getOrSet(path, val) -- {{{
   return (path and val)
      and self:set(path, val)
      or self:get(path)
end -- }}}

function Config:get(path) -- {{{
    -- path is a dot-separated string, e.g., 'appearance.color'
    -- returns value at path or full config if path not provided
    if path==nil then return self.conf end
    local val = u.getfield(path, self.conf)

    if val==nil then
        return log.w( ('config.get("%s") not found'):format(path) )
    end

    log.d(('get(%s) found: %s'):format(path, val))
    return val
end -- }}}

function Config:set(path, val) -- {{{
    -- path is a dot-separated string, e.g., 'appearance.color'
    -- val is the value to set at path
    -- non-existent path segments will be set to an empty table
    local _type, validator = self:getPathSchema(path) -- lookup type in schema
    if not _type then
        self:autosuggest(path)
        return self
    end

    local typedVal = self.types[_type].coerce(val)
    local isValid, err = validator(typedVal)           -- validate val is appropriate type

    if not isValid then
        log.e('Set', path, 'to invalid value.', hs.inspect(err))
        return self
    end

    u.setfield(path, typedVal, self.conf)

    local onChange = u.getfield(path, self.events, true)
    if u.isfunc(onChange) then onChange() end

    return self, val
end -- }}}

function Config:toggle(key) -- {{{
    local val = self:get(key)
    if not u.isbool(val) then
        log.w(key, 'cannot be toggled because it is not boolean')
        return self
    end
    local toggledVal = not val
    log.i('Toggling', key, 'from ', val, 'to ', toggledVal)
    self:set(key, toggledVal)
end -- }}}

function Config:setLogLevel(lvl) -- {{{
    log.setLogLevel(lvl)
    log.i( ('Window.log level set to %s'):format(lvl) )
end -- }}}

return Config
