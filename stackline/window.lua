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

-- luacheck: ignore
function Window:new(w) -- {{{
    local ws = {
        id = w.id, -- window id
        app = w.app, -- 0 if unfocused, 1 if focused
        focused = w.focused == 1, -- convert 0,1 into boolean 0 if unfocused, 1 if focused
        frame = w.frame, -- x,y,w,h of window
        frameFlat = w.frameFlat, -- x|y of window
        indicator = nil, -- the canvas element
    }

    setmetatable(ws, self)
    self.__index = self
    return ws
end -- }}}

function Window.__eq(a, b) -- {{{
    -- FIXME: unused as of 2020-07-31
    local t1 = a.id
    local t2 = b.id
    local existComp = {id = a.id, frame = a.frameFlat, focused = a.focused}
    local currComp = {id = b.id, frame = b.frameFlat, focused = b.focused}
    local isEqual = _.isEqual(existComp, currComp)
    return isEqual
end -- }}}

-- metatable testing {{{
local Test = {}
function Test:new(name, age)
    local test = {name = name, age = age}

    local mmt = {
        __add = function(a, b)
            return a.age + b.age
        end,
        __eq = function(a, b)
            return a.age == b.age
        end,
    }
    setmetatable(test, mmt)
    return test
end

-- local amy = Test:new('amy', 18)
-- local adam = Test:new('adam', 33)
-- local carl = Test:new('carl', 18)

-- print('amy equals adam?', amy == adam)
-- print('amy equals carl?', amy == carl)
-- print('amy plus adam?', (amy + adam))
-- print('amy plus carl?', (amy + carl))
-- print('amy plus amy?', (amy + amy))
-- }}}

-- TODO: ↑ Convert to .__eq metatable
function Window:setNeedsUpdated(extant) -- {{{
    local isEqual = _.isEqual(existComp, currComp)
    self.needsUpdated = not isEqual
end -- }}}

function Window:process(showIcons, currTabIdx) -- {{{
    -- Config
    local indicatorColors = _.settingsGetOrSet("indicator_colors", false)

    self.showIcons = showIcons
    local unfocused_color_light = {white = 0.9, alpha = 0.40}
    local focused_color_light = indicatorColors and
        {hue = 0.1, saturation = 1.0, brightness = 0.9, alpha = 0.95} or
        {white = 0.9, alpha = 0.99}
    local unfocused_color_dark = {white = 0.1, alpha = 0.40}
    local focused_color_dark = indicatorColors and
        {hue = 0.99, saturation = 0.8, brightness = 0.8, alpha = 0.95} or
        {white = 0.1, alpha = 0.99}
    local padding = 4
    local iconPadding = 4
    local aspectRatio = 5
    local size = 32

    local width = self.showIcons and size or (size / aspectRatio)

    local shit = self.frame.x - (width + padding)

    self.canvas_frame = {
        x = shit,
        y = self.frame.y + 2,
        w = self.frame.w,
        h = self.frame.h,
    }

    self.indicator_rect = {
        x = 0,
        y = _.round((currTabIdx - 1) * size * 1.1),
        w = width,
        h = size,
    }

    self.icon_rect = {
        x = iconPadding,
        y = self.indicator_rect.y + iconPadding,
        w = self.indicator_rect.w - (iconPadding * 2),
        h = self.indicator_rect.h - (iconPadding * 2),
    }

    light_bg = _.hasLightBG(self.canvas_frame, self.indicator_rect)
    self.color_opts = {
        bg = self.focused and
            (light_bg and focused_color_dark or focused_color_light) or
            (light_bg and unfocused_color_dark or unfocused_color_light),
        canvasAlpha = self.focused and 1 or 0.2,
        imageAlpha = self.focused and 1 or 0.4,
    }

    self:draw_indicator()

end -- }}}

function Window:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:draw_indicator() -- {{{
    self.indicator = hs.canvas.new(self.canvas_frame)

    local width = self.indicator_rect.w
    local radius = self.showIcons and (self.indicator_rect.w / 4.0) or 4.0
    self.indicator:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = self.color_opts.bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
    })

    if self.showIcons then
        self.indicator:appendElements({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.icon_rect,
            imageAlpha = self.color_opts.imageAlpha,
        })
    end
end -- }}}

return Window
