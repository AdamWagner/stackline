local M = {}

function M.identity(value)
    return value
end

function M.roundToNearest(roundTo, numToRound)
    return numToRound - numToRound % roundTo
end

return M
