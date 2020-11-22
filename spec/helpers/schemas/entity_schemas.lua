local v = require 'stackline.lib.valid'
local o = v.optional

local unwrap = function(x)  -- {{{
  return  v.is_table {
    value = x
  }
end  -- }}}

local is_color = function()  -- {{{
  return v.is_table {
    white = o(v.is_number()),
    red   = o(v.is_number()),
    green = o(v.is_number()),
    blue  = o(v.is_number()),
    alpha = o(v.is_number()),
  }
end  -- }}}

local is_frame  = function()  -- {{{
  return v.or_op(
    v.is_table {
      _h = v.is_number(),
      _w = v.is_number(),
      _x = v.is_number(),
      _y = v.is_number(),
    },
    v.is_table {
      h = v.is_number(),
      w = v.is_number(),
      x = v.is_number(),
      y = v.is_number(),
    }
  )
end  -- }}}

local is_coordinates  = function()  -- {{{
  return v.is_table {
    x = v.is_number(),
    y = v.is_number(),
  }
end  -- }}}

local M = {}

-- Hammerspoon schemas
-- ———————————————————————————————————————————————————————————————————————————

-- hs.window schema
M.is_hs_win = v.is_table {
  application = unwrap(v.is_table {
    name = unwrap( v.is_string() )
  }),
  frame = unwrap( is_frame() ),
  id = unwrap( v.is_number() ),
  title = unwrap( v.is_string() ),

  isApplication = o(v.is_boolean()),
  isFocused = o(v.is_boolean()),
  isFullScreen = o(v.is_boolean()),
  isStandard = o(v.is_boolean()),
  isVisible = o(v.is_boolean()),
  isMinimized = o(v.is_boolean()),
  isMaximizable = o(v.is_boolean()),
}


-- Stackline schemas
-- ———————————————————————————————————————————————————————————————————————————

-- TODO: stackline Indicator schema
M.is_stackline_indicator = v.is_table {
  showIcons  = v.is_boolean(),
  stackFocus = v.is_boolean(),
  side       = v.in_list{'right', 'left'},
  width      = v.is_number(),

  c = v.is_table {
    alpha        = v.is_number(),
    color        = is_color(),
    dimmer       = v.is_number(),
    fadeDuration = v.is_number(),
    iconDimmer   = v.is_number(),
    iconPadding  = v.is_number(),
    offset       = is_coordinates(),
    pillThinness = v.is_number(),
    radius       = v.is_number(),
    shouldFade   = v.is_boolean(),
    showIcons    = v.is_boolean(),
    size         = v.is_number(),
    vertSpacing  = v.is_number(),
  },

  canvas      = is_frame(),
  canvas_rect = is_frame(),
  frame       = is_frame(),
  screenFrame = is_frame(),
  icon_rect   = is_frame(),

  fadeDuration = v.is_number(),
  iconIdx      = v.is_number(),
  iconRadius   = v.is_number(),
  radius       = v.is_number(),
  rectIdx      = v.is_number(),

  screen = v.is_table {
    id        = unwrap(v.is_number()),
    frame     = unwrap(is_frame()),
    fullFrame = unwrap(is_frame()),
  }
}

-- stackline window
M.is_stackline_win = v.is_table {
  app        = v.is_string(),
  -- app        = v.is_boolean(), -- use to confirm that failing validations fail tests
  frame      = is_frame(),
  id         = v.is_number(),
  screen     = v.is_number(),
  stackId    = v.is_string(),
  stackIdFzy = v.is_string(),
  title      = v.is_string(),
  topLeft    = v.is_string(),
  _win       = M.is_hs_win,
  indicator  = o(M.is_stackline_indicator),
}

M.are_stackline_wins = v.is_array(M.is_stackline_win)


-- stackline stack
M.is_groupedwins_keys = v.is_array(v.is_string())
M.is_groupedwins_values = v.is_array(M.are_stackline_wins)

M.is_groupedwins = function(stack)
    local stackKeys = u.keys(stack)
    local stackVals = u.values(stack)

    ok, err = M.is_groupedwins_keys(stackKeys)
    assert(ok, err)

    ok, err = M.is_groupedwins_values(stackVals)
    assert(ok, err)

    return ok, err
end

return M
