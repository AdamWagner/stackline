local u = require 'lib.utils'
local s = require("say")
local assert = require("luassert")


local function luassert_contains(state, arguments)
    return u.includes(arguments[1], arguments[2])
end

s:set("assertion.containsValue.positive", "Expected %s\n to contain %s")
s:set("assertion.containsValue.negative", "Expected %s\n to NOT contain %s")

assert:register("assertion", "contains", luassert_contains, "assertion.containsValue.positive", "assertion.containsValue.negative")


local function luassert_contains_key(state, arguments)
    return u.includes(u.keys(arguments[1]), arguments[2])
end

s:set("assertion.contains_key.positive", "Expected %s\n to contain %s")
s:set("assertion.contains_key.negative", "Expected %s\n to NOT contain %s")

assert:register("assertion", "contains_key", luassert_contains_key, "assertion.contains_key.positive", "assertion.contains_key.negative")
