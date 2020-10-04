-- https://github.com/erento/lua-schema-validation
local v = require 'stackline.lib.valid'
local o = v.optional


local is_color = v.is_table{  -- {{{
  white = o(v.is_number()),
  red   = o(v.is_number()),
  green = o(v.is_number()),
  blue  = o(v.is_number()),
  alpha = o(v.is_number()),
}  -- }}}

local function dialog(title, msg)  -- {{{
  local screen = hs.screen.mainScreen():currentMode()
  local width = screen["w"]
  hs.dialog.alert((width / 2) - 80, 25, function() end, title, msg)
end  -- }}}

local M = {}

M.schema = v.is_table{  -- {{{
  paths = o(v.is_table{
    getStackIdxs      = o(v.is_string()),
    jq                = o(v.is_string()),
    yabai             = o(v.is_string()),
  }),
  appearance = o(v.is_table{
    color               = o(is_color),
    alpha               = o(v.is_number()),
    dimmer              = o(v.is_number()),
    iconDimmer          = o(v.is_number()),
    showIcons           = o(v.is_boolean()),
    size                = o(v.is_number()),
    radius              = o(v.is_number()),
    padding             = o(v.is_number()),
    iconPadding         = o(v.is_number()),
    pillThinness        = o(v.is_number()),

    vertSpacing         = o(v.is_number()),
    offset              = o(v.is_table{ y = o(v.is_number), x = o(v.is_number) }),
    shouldFade          = o(v.is_boolean()),
    fadeDuration        = o(v.is_number()),
  }),
  features = o(v.is_table{
    clickToFocus        = o(v.is_boolean()),
    hsBugWorkaround     = o(v.is_boolean()),

    fzyFrameDetect = o(v.is_table{
      enabled           = o(v.is_boolean()),
      fuzzFactor        = o(v.is_number()),
    }),

    showTitles          = o(v.in_list{true, false, 'when_switching', 'not_implemented'}),
    dynamicLuminosity   = o(v.in_list{true, false, 'not_implemented'}),
  })
}  -- }}}

function M:init(conf)  -- {{{
    self.conf = conf

    hs.ipc.localPort('stackline-config', function(_, msgID, msg)  -- {{{
      if msgID == 900 then
          return "version:2.0a"   -- Important! This is required.
      elseif msgID == 500 then
        self:handleSignal(msg)
      end
    end)  -- }}}

    self.__index = self
    return self
end  -- }}}

function M:validate(conf)  -- {{{
  local c = conf or self.conf
  valid, err = self.schema(c)
  if err then
    dialog('Invalid stackline config:', hs.inspect(err))
  end
  return valid, err
end  -- }}}

function M:getOrSet(path, val)  -- {{{
    if path == nil or val == nil then
        return self:get(path)
    else
      return self:set(path, val)
    end
end  -- }}}

function M:get(path)  -- {{{
  -- @path is a dot-separated string (e.g., 'appearance.color')
  -- return full config if no path provided
    if path == nil then return self.conf end
    local value
    local keys = path:split("%.")
    for _, key in pairs(keys) do
        value = (value and value[key]) or self.conf[key]
    end
    return value;
end  -- }}}

function M:set(path, val)  -- {{{
  -- @path is a dot-separated string (e.g., 'appearance.color')
  -- @val is the value to set at path
  -- non-existent path segments will be set to an empty table
  local current = self.conf
  local keys = path:split("%.")

  for i, key in pairs(keys) do
    if i == #keys then
      current[key] = val         -- on the last key, set val
    else
      if current[key] == nil then
        current[key] = {}        -- set non-existent key to empty table
        current = current[key]   -- update current path to tip
      else
        current = current[key]
      end
    end
  end
  return self, val
end  -- }}}

function M:toggle(key)  -- {{{
    local toggledVal = not self:get(key)
    self:set(key, toggledVal)
    return toggledVal
end  -- }}}

function M:parseMsg(msg)  -- {{{
    local _, key, val = table.unpack(msg:split(':'))

    print('key:',key, 'val:', val)

    key = key:gsub("_(.)",string.upper)   -- convert snake_case to camelCase

    return {
        key      = key,
        val      = val,
        isGet    = (key ~= nil) and (val == nil),
        isSet    = (key ~= nil) and (val ~= nil),
        isToggle = key:match("toggle") and (val ~= nil),
    }
end  -- }}}

function M:handleSignal(msg)  -- {{{
    print('msg', msg)
    local m = self:parseMsg(msg)

    if m.isSet then
        self:set(m.key, m.val)
    elseif m.isToggle then
        self:toggle(m.key)
    elseif m.isGet then
        self:get(m.key, m.val)
    else
        print('Unparseable message. Try:')
        print('    `echo :show_icons:1 | hs -m "stackline.config"`')
        print('    `echo :toggle_show_icons: | hs -m "stackline.config"`')
    end

    return "ok"

end  -- }}}

function M:registerWatchers()  -- {{{
  -- TODO: implement
  -- watch for changes to config & take specified action(s) on change
end  -- }}}

return M
