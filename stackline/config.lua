local StackConfig = {}

function StackConfig:new() -- {{{
    local config = {id = 'stackline', store = hs.settings}

    setmetatable(config, self)
    self.__index = self
    return config
end -- }}}

function StackConfig:get(key) -- {{{
    local settingPath = self:makePath(key)
    return self.store.get(settingPath)
end -- }}}

function StackConfig:set(key, val) -- {{{
    local settingPath = self:makePath(key)
    self.store.set(settingPath, val)
    return self.store.get(settingPath)
end -- }}}

function StackConfig:setEach(settingsTable) -- {{{
    for key, value in pairs(settingsTable) do
        local settingPath = self:makePath(key)
        self.store.set(settingPath, value)
    end
    return self
end -- }}}

function StackConfig:getOrSet(key, val) -- {{{
    local settingPath = self:makePath(key)
    local existingVal = self.store.get(settingPath)
    if val ~= nil then -- set if val provided
        self.store.set(settingPath, val)
        return val
    else
        return existingVal
    end
end -- }}}

function StackConfig:toggle(key) -- {{{
    local toggledVal = not self:get(key) -- if key is not yet set, initial toggle is "on"
    self:set(key, toggledVal)
    return toggledVal
end -- }}}

function StackConfig:makePath(key) -- {{{
    return self.id .. '-' .. key
end -- }}}

function StackConfig:registerWatchers() -- {{{
    local key = 'showIcons'
    local identifier = self:makePath(key .. '-handler')
    local settingPath = self:makePath(key)
    self.store.watchKey(identifier, settingPath, function(_val)
        stackline.manager:toggleIcons()
    end)
    return self
end -- }}}

-- TODO: integrate with StackConfig() module

local handlers = {  -- {{{
    ['900'] = function() return "version:2.0a" end,

    ['500'] = function()
        local key, _value = msg:match(".+:([%a_-]+):([%a%d_-]+)")
        if key == "toggle_icons" then
            stackline.config:toggle('showIcons')   -- global var
        end
    end
}  -- }}}

local function handleSignal(_, msgID, msg) -- {{{
    print('msgID', msgID)
    print('msg', msg)
    return handlers[tostring(msgID)]
end -- }}}

-- luacheck: ignore
ipcConfigPort = hs.ipc.localPort('stackline-config', handleSignal)

return StackConfig
