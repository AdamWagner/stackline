local M = {}

-- hs win
-- ————————————————————————————————————————————————————————————————————————————————
M.hs_win = {}
M.hs_win.getters = {
  app = function(w) return w:application():name() end,
  title = function(w) return w:title() end,
  id = function(w) return w:id() end,
  frame = function(w) return w:frame() end,
  frame_area = function(w) return w:frame():getarea() end,
  screen = function(w) return w:screen() end,
  screen_frame = function(w) return w:screen():frame() end,
  screen_fullFrame = function(w) return w:screen():fullFrame() end,
}



M.hs_win.schema = {
  {key = 'app name', fn = M.hs_win.getters.app, is_type = assert.is_string},
  {key = 'title', fn = M.hs_win.getters.title, is_type = assert.is_string},
  {key = 'id', fn = M.hs_win.getters.id, is_type = assert.is_number},
  {key = 'frame', fn = M.hs_win.getters.frame, is_type = assert.is_rect},
  {key = 'frame area', fn = M.hs_win.getters.frame_area, is_type = assert.is_number},
  {key = 'screen', fn = M.hs_win.getters.screen, is_type = assert.is_table},
  {key = 'screen frame', fn = M.hs_win.getters.screen_frame, is_type = assert.is_rect},
  {key = 'screen fullFrame', fn = M.hs_win.getters.screen_fullFrame, is_type = assert.is_rect},
}


-- Stackline win
-- ———————————————————————————————————————————————————————————————————————————
M.sl_win = {}
M.sl_win.schema = {
  { key = 'app', is_type = assert.is_string },
  { key = 'title', is_type = assert.is_string },
  { key = 'id', is_type = assert.is_number },
  { key = 'screen', is_type = assert.is_number },
  { key = 'frame', is_type = assert.is_rect },
  { key = 'stackId', is_type = assert.is_string },
  { key = 'stackIdFzy', is_type = assert.is_string },
}

function M.testSchema(schema, obj)  -- {{{
    -- given a schema and an obj, test obj for each entry in schema

  for _, val in pairs(schema) do
    -- ensure required schema keys exist:
    assert(val.key, 'Schema entries must have a "key" property')
    assert(val.is_type, 'Schema entries must have a "is_type" property')
    assert.is_callable(val.is_type)

    local getter = (val.fn ~= nil)
                      and val.fn                             -- use val.fn if it exists
                      or function(x) return x[val.key] end   -- otherwise use val.key to lookup directly

      -- run the test!
    it(val.key, function()
      val.is_type(getter(obj))
    end)
  end
end  -- }}}

return M
