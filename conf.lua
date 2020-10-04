-- default stackline config
-- TODO: Experiment with setting __index() metatable to leverage autosuggest when keys not found

c = {}
c.paths = {}
c.appearance = {}
c.features = {}
c.advanced = {}

-- Paths
c.paths.getStackIdxs                  = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'
c.paths.jq                            = '/usr/local/bin/jq'
c.paths.yabai                         = '/usr/local/bin/yabai'

-- Appearance
c.appearance.color                    = { white = 0.90 }
c.appearance.alpha                    = 1
c.appearance.dimmer                   = 2.5                 -- larger numbers increase contrast b/n focused & unfocused state
c.appearance.iconDimmer               = 1.1                 -- custom dimmer for icon
c.appearance.showIcons                = true
c.appearance.size                     = 32
c.appearance.radius                   = 3
c.appearance.padding                  = 4
c.appearance.iconPadding              = 4
c.appearance.pillThinness             = 6

c.appearance.vertSpacing              = 1.2

c.appearance.offset                   = {}
c.appearance.offset.y                 = 2
c.appearance.offset.x                 = 4

c.appearance.shouldFade               = true
c.appearance.fadeDuration             = 0.2

-- Features
c.features.clickToFocus               = true
c.features.hsBugWorkaround            = true

c.features.fzyFrameDetect             = {}
c.features.fzyFrameDetect.enabled     = true
c.features.fzyFrameDetect.fuzzFactor  = 15                  -- window frame dimensions will be rounded to nearest fuzzFactor

c.features.winTitles                 = 'not_implemented'    -- false, true, 'when_switching', 'not_implemented'
c.features.dynamicLuminosity         = 'not_implemented'    -- false, true, 'not_implemented'

c.advanced.maxRefreshRate             = 0.3                 -- how aggressively to refresh stackline (higher = slower response time + less battery drain)

return c
