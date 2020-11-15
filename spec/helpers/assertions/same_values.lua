local u = require 'lib.utils'
local s = require("say")
local assert = require("luassert")

local function same_values(state, arguments)
    return u.same(arguments[1], arguments[2])
end

s:set("assertion.same_values.positive", "Expected %s\n to deep equal %s")
s:set("assertion.same_values.negative", "Expected %s\n to NOT deep equal %s")

assert:register("assertion", "same_values", same_values, "assertion.same_values.positive", "assertion.same_values.negative")
