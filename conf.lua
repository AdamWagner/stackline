--[[
Default configuration values for stackline. Users override these by passing
a config table to stackline:init(). See configmanager.lua for the schema that
validates these values, and CLAUDE.md for architecture documentation.
]]

local c = {}
c.paths = {}
c.appearance = {}
c.features = {}
c.advanced = {}

-- Paths
-- Apple Silicon: /opt/homebrew/bin/yabai  (default)
-- Intel Mac:     /usr/local/bin/yabai
c.paths.yabai                         = '/opt/homebrew/bin/yabai'

-- Appearance
c.appearance.color                    = { white = 0.90 }    -- Indicator background color, e.g., {red = 0.5, blue = 0 }
c.appearance.alpha                    = 1                   -- Opacity of active indicators
c.appearance.dimmer                   = 2.5                 -- Higher numbers increase contrast b/n focused & unfocused state
c.appearance.iconDimmer               = 1.1                 -- Divisor for inactive icon opacity (low value like 1.1 keeps icons readable)
c.appearance.showIcons                = true                -- Window indicator style ('lozenge'-shaped when false)
c.appearance.size                     = 32                  -- Size of window indicators (height when icons off)
c.appearance.radius                   = 3.5                 -- Corner radius. Higher → more square; 0 is also square
c.appearance.iconPadding              = 4                   -- Space between icon & indicator edge. Higher numbers → smaller, more inset icons
c.appearance.pillThinness             = 6                   -- Aspect ratio of pill-style icons (width = size / pillThinness)

c.appearance.vertSpacing              = 1.2                 -- Vertical spacing multiplier (gap = size * vertSpacing)

c.appearance.offset                   = {}                  -- Offset controls position of stack indicators relative to the window
c.appearance.offset.y                 = 2                   -- Distance from top of the window to render indicators
c.appearance.offset.x                 = 4                   -- Distance away from the edge of the window to render indicators

c.appearance.shadowIntensity          = 1                   -- Shadow opacity multiplier (higher = more visible shadows)
c.appearance.shadowSpread             = 1                   -- Shadow blur multiplier (higher = softer, more diffuse shadows)

c.appearance.shouldFade               = true                -- Enable/disable fade animations
c.appearance.fadeDuration             = 0.2                 -- Duration of fade animations (seconds) 

-- Features
c.features.clickToFocus               = true                -- Click indicator to focus window. Mouse clicks are tracked when enabled
c.features.hsBugWorkaround            = true                -- Workaround for https://github.com/Hammerspoon/hammerspoon/issues/2400

c.features.fzyFrameDetect             = {}                  -- Round window frame dimensions by fuzzFactor before identifying stacked windows
c.features.fzyFrameDetect.enabled     = true                -- Enable/disable fuzzy frame detection
c.features.fzyFrameDetect.fuzzFactor  = 30                  -- Window frame dimensions will be rounded to nearest fuzzFactor

c.features.winTitles                 = 'not_implemented'    -- Valid options: false, true, 'when_switching', 'not_implemented'
c.features.dynamicLuminosity         = 'not_implemented'    -- Valid options: false, true, 'not_implemented'

c.advanced.maxRefreshRate             = 0.5                 -- Min interval (seconds) between yabai queries. Higher = less responsive + less battery drain

return c
