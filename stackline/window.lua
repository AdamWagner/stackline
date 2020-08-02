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
    print(a.id, a.focused)
    print(t2, b.focused)
    local existComp = {id = a.id, frame = a.frameFlat, focused = a.focused}
    local currComp = {id = b.id, frame = b.frameFlat, focused = b.focused}
    -- _.p('A Compare:', existComp)
    -- _.p('B Compare:', currComp)
    local isEqual = _.isEqual(existComp, currComp)
    return isEqual
end -- }}}

-- TODO: ↑ Convert to .__eq metatable
function Window:setNeedsUpdated(extant) -- {{{
    local isEqual = _.isEqual(existComp, currComp)
    self.needsUpdated = not isEqual
end -- }}}

function Window:process(showIcons, currTabIdx) -- {{{
    -- Config
    self.showIcons = showIcons
    local unfocused_color = {white = 0.9, alpha = 0.30}
    local focused_color = {white = 0.9, alpha = 0.99}
    local padding = 4
    local aspectRatio = 5
    local size = 25

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
        y = ((currTabIdx - 1) * size * 1.1),
        w = width,
        h = size,
    }

    self.color_opts = {
        bg = self.focused and focused_color or unfocused_color,
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
    self.indicator:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = self.color_opts.bg,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = 2.0, yRadius = 2.0},
    })

    if self.showIcons then
        self.indicator:appendElements({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.indicator_rect,
            imageAlpha = self.color_opts.imageAlpha,
        })
    end
end -- }}}

return Window
