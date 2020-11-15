local assert = require("luassert")
local say = require("say")

local function hasKey(state, args)
    if type(args[1]) ~= 'table' then
        return false
    end
    return args[1][args[2]]
end

say:set('assertion.hasKey.positive', 'Expected %s to have property: %s')
say:set('assertion.hasKey.negative', 'Expected %s to not have property: %s')
assert:register('assertion', 'has_key', hasKey, 'assertion.hasKey.positive', 'assertion.hasKey.negative')
