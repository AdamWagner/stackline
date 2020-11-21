local u = require 'lib.utils'
local s = require("say")
local assert = require("luassert")

local function luassert_is_rect(state, arguments)
    return u.isGeometryObject(arguments[1])
end

s:set("assertion.is_rect.positive", "Expected %s\n to deep equal %s")
s:set("assertion.is_rect.negative", "Expected %s\n to NOT deep equal %s")

assert:register("assertion", "is_rect", luassert_is_rect, "assertion.is_rect.positive", "assertion.is_rect.negative")
