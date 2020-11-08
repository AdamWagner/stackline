local assert = require("luassert")
local say = require("say")

function greater_than(_, arguments)
  local expected = arguments[1]
  local tested = arguments[2]
  assert(type(expected) == "number" and type(tested) == "number", "assert.greater_than expects numeric values")
  return tested > expected
end

function less_than(_, arguments)
  local expected = arguments[1]
  local tested = arguments[2]
  assert(type(expected) == "number" and type(tested) == "number", "assert.less_than expects numeric values")
  return tested < expected
end

function in_range(_, arguments)
  local low_range = arguments[1]
  local high_range = arguments[2]
  local tested = arguments[3]
  assert(type(low_range) == "number" and type(high_range) == "number" and type(tested) == "number", "assert.in_range expects numeric values")
  return low_range <= tested and tested <= high_range
end


say:set("assertion.greater_than.positive", "Expected %s to be less than: %s")
say:set("assertion.greater_than.negative", "Expected %s to not be less than: %s")
assert:register("assertion", "greater_than", greater_than, "assertion.greater_than.positive", "assertion.greater_than.negative")

say:set("assertion.less_than.positive", "Expected %s to be greater than: %s")
say:set("assertion.less_than.negative", "Expected %s to not be greater than: %s")
assert:register("assertion", "less_than", less_than, "assertion.less_than.positive", "assertion.less_than.negative")

say:set("assertion.in_range.positive", "Expected range %s to %s to include: %s")
say:set("assertion.in_range.negative", "Expected range %s to %s to not include: %s")
assert:register("assertion", "in_range", in_range, "assertion.in_range.positive", "assertion.in_range.negative")
