local each = require 'lib.utils.collections'.each

local M = {}

function M.identity(value)
  return value
end

function M.roundToNearest(roundTo, numToRound)
  assert(type(numToRound)=='number', "\nroundToNearest(): numToRound must be a number\n")
  assert(type(roundTo)=='number', "\nroundToNearest(): roundTo must be a number\n")
  if roundTo == 0 then roundTo=1 end
  return numToRound - numToRound % roundTo
end

function M.uniqueHash(data)
  -- Sort data keys for consistent hashes
  each(data, function(v)
    if type(v) == 'table' then
      table.sort(v, function(a,b)
        if type(v)=='table' then return true end
        return a < b
      end)
    end
  end)

  -- …and build unique hash based on stack summary
  local result = hs.hash.MD5(hs.inspect(data))
  return result
end

-- USAGE: numberWordMap[4] → 'four'
M.numberWordMap = setmetatable({
  "one", "two", "three", "four", "five",
  "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen",
  "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
}, {
  __index = function(_, k) -- special case for zero & anything more than 20
    return k == 0 and 'zero' or 'more than twenty'
  end,
})

return M
