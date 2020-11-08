local assert = require("luassert")
local say    = require("say")

say:set_namespace("en")


local is_callable = require('luassert.util').callable

local function is_callable_matcher(_, _)
    return function(value)
        return is_callable(value)
    end
end

say:set("assertion.is_calleable.positive", '%s is callable')
say:set("assertion.is_calleable.negative", '%s is not callable')
assert:register("assertion", "is_callable", is_callable,
                "assertion.is_callable.positive",
                "assertion.is_callable.negative")

assert:register('matcher', 'is_callable', is_callable_matcher)



-- This assertion requires two arguments: a pattern (as a string) and
-- another string to test against that pattern.  In this context
-- "pattern" means the kind acceptable to string.match() and similar
-- standard Lua functions.  This assertion is true if the given string
-- matches the pattern.
local function like_pattern(state, arguments)
    local pattern = arguments[1]
    local datum = arguments[2]
    return string.match(datum, pattern) ~= nil
end

say:set("assertion.like_pattern.positive", "Expected pattern %s to match the string:\n%s")
say:set("assertion.like_pattern.negative", "Expected pattern %s to not match the string:\n%s")
assert:register("assertion", "like_pattern", like_pattern,
                "assertion.like_pattern.positive",
                "assertion.like_pattern.negative")
