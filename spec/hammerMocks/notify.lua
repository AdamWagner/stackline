-- STACKLINE REFERENCES:
-- hs.notify.new(nil, {
--     title           = 'Invalid stackline config!',
--     subTitle        =  'invalid keys:' .. invalidKeys,
--     informativeText = 'Please refer to the default conf file.',
--     withdrawAfter   = 10
-- }):send()
-- -----------------------------------------------------------------------------


-- ———————————————————————————————————————————————————————————————————————————
-- hs.notify mock
-- ———————————————————————————————————————————————————————————————————————————
local notify = {}

function notify.new(fn, attributes)
  local o = {fn = fn, attributes = attributes}
  setmetatable(o, notify)
  notify.__index = notify
  return o
end

function notify.show(title, subtitle, information)
  local o = {title = title, subtitle = subtitle, information = information}
  o = notify.new(nil, o)
  o:send()
  return o
end

function notify:send()
  return self
end

return notify
