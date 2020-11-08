-- ┌────────────────┐
-- │ Fixture utils  │
-- └────────────────┘

local geometry = require 'hs.geometry' -- real hs.geometry

local M = {}

function M.prepareFrame(f)
  local frame = {}
  for k,v in pairs(f) do
    local key = k:gsub('_','')
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

    if (k=='frame' or k=='fullFrame') and not isGeometryObject(v) then
        obj[k] = geometry(M.prepareFrame(v))

    -- elseif k=='app' and not data[k].name then
    --   obj.application = { name = v }

    -- elseif k=='screen' and not data[k].frame then
    --   print('k IS SCREEN!')
    --   if data[k] then
    --     obj.screen = hs.screen:new(data[k])
    --   else
    --     obj.screen = hs.screen:new()
    --   end


    -- elseif type(v)=='table' and #u.values(v)>0 then
    elseif type(v)=='table' then
      obj[k] = M.process(v)

    else
      obj[k] = v
    end
  end

  -- if data._win and #u.values(data._win)==0 then
  --   obj._win = hs.window:new({
  --     id = obj.id,
  --     application = obj.application,
  --     title = obj.title,
  --     frame = geometry(obj.frame),
  --     screen = hs.screen:new(),
  --   }, true)
  -- end

  return obj

end

return M
