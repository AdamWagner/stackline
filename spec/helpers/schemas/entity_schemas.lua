local v = require 'stackline.lib.valid'
local o = v.optional

local unwrap = function(x)
  return  v.is_table {
    value = x
  }
end

local is_frame  = function()
    return v.is_table {
      _h = v.is_number(),
      _w = v.is_number(),
      _x = v.is_number(),
      _y = v.is_number(),
  }
end

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


M.is_stackline_win = v.is_table {
    app        = v.is_string(),
    -- app        = v.is_boolean(), -- just for testing
    frame      = is_frame(),
    id         = v.is_number(),
    screen     = v.is_number(),
    stackId    = v.is_string(),
    stackIdFzy = v.is_string(),
    title      = v.is_string(),
    topLeft    = v.is_string(),
    _win       = M.is_hs_win,
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
