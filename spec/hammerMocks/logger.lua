-- STACKLINE REFERENCES:
-- hs.logger.new(level)
--    log.setLogLevel('info')
--    log.i(msg), etc
-- -----------------------------------------------------------------------------

-- NOTE:
-- 90 Line log module with color output & file-writing
-- https://github.com/rxi/log.lua/blob/master/log.lua

-- ———————————————————————————————————————————————————————————————————————————
-- hs.logger mock
-- ———————————————————————————————————————————————————————————————————————————
local logger = {}

logger.levels = {
  ['nothing'] = 0,
  ['error']   = 1,
  ['warning'] = 2,
  ['info']    = 3,
  ['debug']   = 4,
  ['verbose'] = 5,
}

logger.level = 1

local function parseLevel(lvl)
  if type(lvl)=='number' then
    return lvl
  elseif type(lvl)=='string' then
    return tonumber(logger.levels[lvl])
  else
    error("Can't parse logger level")
  end
end

function logger.new(name, level)
  local l = {
    level = level,
    e = function(...) if logger.level >= 1 then print(name, ...) end end,
    w = function(...) if logger.level >= 2 then print(name, ...) end end,
    i = function(...) if logger.level >= 3 then print(name, ...) end end,
    d = function(...) if logger.level >= 4 then print(name, ...) end end,
    v = function(...) if logger.level >= 5 then print(name, ...) end end,
    setLogLevel = function() end,
    getLogLevel = function() end,
  }
  l.level = logger.level
  setmetatable(l, logger)
  logger.__index = logger
  return l
end

-- TODO: cleanup these nasty conditionals in logger.setLogLevel
function logger.setLogLevel(self, nl)
  if type(self)=='number' and nl==nil then
    nl = self
  elseif type(self)=='table' and nl ~= nil then
    self.level = parseLevel(nl)
  elseif nl ~= nil then
    logger.level = parseLevel(nl)
  else
    error(string.format("Can't set logger level with %s or %s", self, nl))
  end
end

function logger:getLogLevel()
  return self.level
end

return logger
