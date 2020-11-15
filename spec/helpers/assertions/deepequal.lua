local u = require 'lib.utils'
local s = require("say")
local assert = require("luassert")


local function luassert_deep_equal(state, arguments)
    return u.deepEqual(arguments[1], arguments[2])
end

s:set("assertion.deepEqual.positive", "Expected %s\n to deep equal %s")
s:set("assertion.deepEqual.negative", "Expected %s\n to NOT deep equal %s")

assert:register("assertion", "deepEqual", luassert_deep_equal, "assertion.deepEqual.positive", "assertion.deepEqual.negative")
