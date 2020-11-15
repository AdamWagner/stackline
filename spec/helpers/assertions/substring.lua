local assert = require("luassert")
local say = require("say")

function substring(state, arguments)
  local container = arguments[1]
  local expected = arguments[2]
  return container:find(expected) ~= nil
end

say:set("assertion.substring.positive", "Expected %s to contain: %s. Check for magic characters ().%%+-*?[^$")
say:set("assertion.substring.negative", "Expected %s to not contain: %s . Check for magic characters ().%%+-*?[^$")
assert:register("assertion", "substring", substring, "assertion.substring.positive", "assertion.substring.negative")
