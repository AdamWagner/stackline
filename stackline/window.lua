local _ = require 'stackline.utils.utils'

local Window = {}

-- FROM: How to chain metatables: https://stackoverflow.com/questions/8109790/chain-lua-metatables
local metatbl = {}
-- luacheck: ignore
function metatbl.__index(intbl, key) -- {{{
    -- luacheck: ignore
    for i, mtbl in ipairs(metatbl.tbls) do
        local mmethod = mtbl.__index
        if (type(mmethod) == "function") then
            local ret = mmethod(table, key)
            if ret then
                return ret
            end
        else
            if mmethod[key] then
                return mmethod[key]
            end
        end
        return nil
    end
end -- }}}

function Window:setStackIdx() -- {{{
    -- FIXME: Too slow. Probably want to query all windows on space, pluck out
    -- their stack indexes with jq, & send to hammerspoon to merge with windows.

    -- _.pheader('running setStackIdx for: ' .. self.id)
    local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, stderr)
        local stackIdx = tonumber(stdout)
        self.stackIdx = stackIdx
        -- print('stack idx for ', self.id, ' is ', stackIdx)
    end, {scriptPath, tostring(self.id)}):start():waitUntilExit()
end -- }}}

-- luacheck: ignore
function Window:new(w) -- {{{
    local ws = {
        app = w.app, -- app name (string)
        id = w.id, -- window id (string) NOTE: the ID is the same as yabai! So we could interopt if we need to
        title = w.title, -- window title (string)
        _win = w._win, -- hs.window object (table)
        frame = w.frame, -- x,y,w,h of window (table)
        -- stackIdx = w.stackIdx, -- from yabai :(
        stackId = w.stackId, -- "{spaceId}|{x}|{y}|{w}|{h}" e.g., "302|35|63|1185|741" (string)
        indicator = nil, -- the canvas element (table)
    }

    setmetatable(ws, self)
    self.__index = self
    return ws
end -- }}}

function Window:isFocused() -- {{{
    local focusedWin = hs.window.focusedWindow()
    if focusedWin == nil then
        return false
    end
    local isFocused = self.id == focusedWin:id()
    return isFocused
end -- }}}

-- function Window.__eq(a, b) -- {{{
--     -- FIXME: unused as of 2020-07-31
--     local t1 = a.id
--     local t2 = b.id
--     print('Window.__eq metamethod called:', a.id, a.focused, ' < VS: > ', t2,
--           b.focused)
--     local existComp = {id = a.id, frame = a.frameFlat, focused = a.focused}
--     local currComp = {id = b.id, frame = b.frameFlat, focused = b.focused}
--     -- _.p('A Compare:', existComp)
--     -- _.p('B Compare:', currComp)
--     local isEqual = _.isEqual(existComp, currComp)
--     return isEqual
-- end -- }}}

-- TODO: ↑ Convert to .__eq metatable
function Window:setNeedsUpdated(extant) -- {{{
    local isEqual = _.isEqual(existComp, currComp)
    self.needsUpdated = not isEqual
end -- }}}

function Window:process(Icons) -- {{{
    -- Config
    local showIcons = wsi.getShowIconsState()
    local unfocused_color = {white = 0.9, alpha = 0.30}
    local focused_color = {white = 0.9, alpha = 0.99}
    local padding = 4
    local aspectRatio = 5
    local size = 25

    local width = showIcons and size or (size / aspectRatio)

    local currTabIdx = self.stackIdx
    local xval = self.frame.x - (width + padding)

    self.canvas_frame = {
        x = xval,
        y = self.frame.y + 2,
        w = self.frame.w,
        h = self.frame.h,
    }

    self.indicator_rect = {
        x = 0,
        y = ((currTabIdx - 1) * size * 1.1),
        w = width,
        h = size,
    }

    local focused = self:isFocused()

    self.color_opts = {
        bg = focused and focused_color or unfocused_color,
        canvasAlpha = focused and 1 or 0.2,
        imageAlpha = focused and 1 or 0.4,
    }

    self:draw_indicator()

end -- }}}

function Window:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:draw_indicator() -- {{{
    if self.indicator then
        self.indicator:delete()
    end

    self.indicator = hs.canvas.new(self.canvas_frame)

    local width = self.indicator_rect.w
    self.indicator:appendElements{
        type = "rectangle",
        action = "fill",
        fillColor = self.color_opts.bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = 2.0, yRadius = 2.0},
    }

    if wsi.getShowIconsState() then
        self.indicator:appendElements{
            type = "image",
            image = self:iconFromAppName(),
            frame = self.indicator_rect,
            imageAlpha = self.color_opts.imageAlpha,
        }
    end
    self.indicator:show()
end -- }}}

return Window
