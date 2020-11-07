local u = require 'stackline.lib.utils'


local function isarray(x) 
    return type(x) == "table" and x[1] ~= nil
end 

local getiter = function(x) 
    if isarray(x) then
        return ipairs
    elseif type(x) == "table" then
        return pairs
    end
    error("expected table", 3)
end 

local function asc(a, b)
  return a[1] < b[1]
end

local function matchBest(needle, haystack)
  -- lev.d fn that can be mapped over list of candidates
  local dist = u.partial(u.levenshteinDistance, needle) 
  local scores =
      u.zip(
	  u.map(haystack, dist), -- list of scores {0.2024, 0.182, 0.991, …}
          haystack               -- keys for the scores
      )
  table.sort(scores, asc)
  local keyMatch1, keyMatch2 = scores[1][2], scores[2][2] -- return the best 2 matches
  return keyMatch1, keyMatch2
end



local M = {}

function M:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end


function M:keys()
    local rtn = {}
    local iter = getiter(self)
    for k in iter(t) do
        rtn[#rtn + 1] = k
    end
    return rtn
end

function M:get(key)
  -- base case
  local value = self[key]
  if value then return value end

  -- fuzzy case
  return self[matchBest(key, self:keys())]
end

return M
