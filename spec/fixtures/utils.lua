-- ┌────────────────┐
-- │ Fixture utils  │
-- └────────────────┘
local geometry = require 'hs.geometry' -- real hs.geometry

local M = {}

function M.prepareFrame(f)
  local frame = {}
  for k, v in pairs(f) do
    local key = k:gsub('_', '')
    frame[key] = v
  end
  return frame
end

function isGeometryObject(v)
  local mt = getmetatable(v)
  if mt and mt.getarea then
    return true
  end
end

function M.process(data)
  -- If key is 'frame' or 'fullFrame' wrap value in geometry(...). Recursive.
  -- 'opts' arg specifies which checks should be made, which is needed to avoid infinite loop.
  local obj = {}

  for k, v in pairs(data) do

    if (k == 'frame' or k == 'fullFrame') and (not isGeometryObject(v)) then
      obj[k] = geometry(M.prepareFrame(v))

    elseif type(v) == 'table' then
      obj[k] = M.process(v)

    else
      obj[k] = v

    end

  end
  return obj
end

return M
