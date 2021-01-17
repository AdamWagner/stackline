-- FROM: https://github.com/rifleh700/check

-- Alternatives. Note that many of these did NOT work for me in a vanilla lua
-- environment — they tend to require unavailable libs such as `ffi`

--   - https://github.com/tarantool/checks/blob/master/checks.lua (doesn't work in vanilla lua)
--   - https://github.com/CrackedP0t/charge
--   - https://github.com/rifleh700/check/blob/master/check.lua
--   - https://github.com/tarantool/checks/blob/master/checks.lua (doesn't work in vanilla lua)
--   - https://github.com/djerius/validate.args
--   - SUPER huge, more about schema validation: https://github.com/djerius/validate.args

-- Linter that runs locally: https://github.com/geoffleyland/argcheck


--[[
Examples:

local charge = require("charge")

local function appendSum(number1, number2, text)
  -- Will throw an error if any argument is not valid
  charge(number1, "number", number2, "number", text, "string")
  return text .. tostring(number1 + number2)
end

print(appendSum(2, 3, "Five -> ")) -- Prints "Five -> 5"

print(appendSum(2, {}, "Five -> ")) -- Throws an error:
bad argument #2 to 'appendSum' (number expected; got table)

Variables can also have multiple correct types:

local charge = require("charge")

local function basicTypeToString(thing)
  -- Will also accept tables of types
  charge(thing, {"number", "boolean"})
  return tostring(thing)
end

print(basicTypeToString(true)) -- Prints "true"
print(basicTypeToString(12)) -- Prints "12"

print(basicTypeToString(function() end)) -- Throws an error:
-- Bad argument #1 to 'basicTypeToString' (any of number, boolean expected; got function)

--]]

-- return function(...)
  --   local args = {...}
  --   local retArgs = {}
  --
  --   if #args % 2 ~= 0 then
  --     error(("bad argument #%i to '%s' (any of string, table expected; got nil)")
  --     :format(#args + 1, debug.getinfo(1, "n").name or "unknown"), 2)
  --   end
  --
  --   for i = 1, math.max(1, #args), 2 do
  --     local val, cType = args[i], args[i + 1]
  --     local valType, cTypeType = type(val), type(cType)
  --
  --     if cTypeType == "table" then
  --       local shouldError = true
  --       local typeList = ""
  --
  --       for j, v in ipairs(cType) do
  -- 	shouldError = shouldError and valType ~= v
  -- 	typeList = typeList .. ", " .. v
  --       end
  --
  --       if shouldError then
  -- 	error(("bad argument #%i to '%s' (any of %s expected; got %s)")
  -- 	:format(math.ceil(i / 2)
  -- 	, debug.getinfo(2, "n").name or "unknown"
  -- 	, typeList:sub(3, -1)
  -- 	, valType)
  -- 	, 3)
  --       end
  --     elseif cTypeType ~= "string" then
  --       error(("bad argument #%i to '%s' (any of string, table expected; got %s)")
  --       :format(i + 1, debug.getinfo(1, "n").name or "unknown", cTypeType), 2)
  --     elseif valType ~= cType then
  --       error(("bad argument #%i to '%s' (%s expected; got %s)")
  --       :format(math.ceil(i / 2), debug.getinfo(2, "n").name or "unknown", cType, valType), 3)
  --     end
  --
  --     retArgs[#retArgs + 1] = val
  --   end
  --
  --   return (unpack and unpack or table.unpack)(retArgs)
  -- end




  checkers = {}

  local string_match = string.match
  local string_format = string.format
  local string_gsub = string.gsub
  local string_find = string.find
  local table_concat = table.concat
  local debug_getinfo = debug.getinfo
  local debug_getlocal = debug.getlocal

  local _string_rep = string.rep
  local function string_rep(s, n, sep)
    if n == 1 then return s end
    if n < 1 then return "" end

    return _string_rep(s..(sep or ""), n - 1)..s
  end

  local function mta_type(value)

    local t = type(value)
    if t ~= "userdata" then return t end

    local udt = getUserdataType(value)
    if udt == t then return t end
    if udt ~= "element" then return t..":"..udt end

    return t..":"..udt..":"..getElementType(value)
  end

  local function is_subtype(sub, parent)

    return
    sub == parent or
    string_find(sub, parent..":", 1, true) == 1
  end

  local default_checkers = {
    ["userdata:element:gui"] = function(v) return string_match(mta_type(v), "^userdata:element:gui%-") end
  }

  local type_cuts = {
    ["b"] = "boolean",
    ["n"] = "number",
    ["s"] = "string",
    ["t"] = "table",
    ["u"] = "userdata",
    ["f"] = "function",
    ["th"] = "thread"
  }

  local cache = {}

  local function parse(pattern)

    if cache[pattern] then return cache[pattern] end

    local result = pattern
    result = string_gsub(result, "(%a+)", type_cuts)
    result = string_gsub(result, "(%?)(%a+)", "nil|%2")
    result = string_gsub(result, "%?", "any")
    result = string_gsub(result, "!", "notnil")
    result = string_gsub(result, "([^,]+)%[(%d)%]", function(t, n) return string_rep(t, tonumber(n), ",") end)

    result = u.split(result, ",")
    for i = 1, #result do
      result[i] = u.split(result[i], "|")
    end

    cache[pattern] = result

    return result
  end

  local function arg_invalid_msg(funcName, argNum, argName, msg)

    msg = msg and string_format(" (%s)", msg) or ""

    return string_format(
    "bad argument #%d '%s' to '%s'%s",
    argNum, argName or "?", funcName or "?", msg
    )
  end

  local function expected_msg(variants, found)

    for i = 1, #variants do
      variants[i] = string_gsub(variants[i], ".+:", "")
    end
    variants = table_concat(variants, "\\")
    found = string_gsub(found, ".+:", "")

    return string_format(
    "%s expected, got %s",
    variants, found
    )
  end

  function warn(msg, lvl)
    check("s,?n")

    lvl = (lvl or 1) + 1
    local dbInfo = debug_getinfo(lvl, "lS")

    if dbInfo and lvl > 1 then
      local src = dbInfo.short_src
      local line = dbInfo.currentline

      msg = string_format(
      "%s:%s: %s",
      src, line, msg
      )
    end

    local formatted = msg:split(':')
    :map(function(s) return s:trim() end)
    :filter(function(s) return tonumber(s)==nil end)
    :join('\n\t--> ')

    u.printWarning(formatted)
    return msg
  end

  local function check_one(variants, value)

    local valueType = mta_type(value)
    local mt = getmetatable(value)
    local valueClass = mt and mt.__type

    for i = 1, #variants do

      local variant = variants[i]

      if variant == "any" then return true end
      if variant == "notnil" and value ~= nil then return true end
      if valueClass and valueClass == variant then return true end

      if is_subtype(valueType, variant) then return true end

      local checker = default_checkers[variant]
      if checker and checker(value) then return true end

      checker = checkers[variant]
      if type(checker) == "function" and checker(value) then return true end
    end

    local msg = expected_msg(variants, valueClass or valueType)
    return false, msg
  end

  local function check_main(pattern)

    local parsed = parse(pattern)
    for argNum = 1, #parsed do

      local argName, value = debug_getlocal(3, argNum)
      local success, descMsg = check_one(parsed[argNum], value)
      if not success then

	local funcName = debug_getinfo(3, "n").name
	local msg = arg_invalid_msg(funcName, argNum, argName, descMsg)
	return false, msg
      end
    end

    return true
  end

  function check(pattern)
    if type(pattern) ~= "string" then check("string") end

    local success, msg = check_main(pattern)
    if not success then error(msg, 3) end

    return true
  end

  function scheck(pattern)
    if type(pattern) ~= "string" then check("string") end

    local success, msg = check_main(pattern)
    if not success then return warn(msg, 3) and false end

    return true
  end

  return {
    check = check,
    scheck = scheck,
    warn = warn
  }

