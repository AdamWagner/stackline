
function utils.identity(value)
    return value
end

function utils.roundToNearest(roundTo, numToRound)
    return numToRound - numToRound % roundTo
end
