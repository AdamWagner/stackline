--  Lamda v0.2.0
--  https://github.com/moriyalb/lamda
--  (c) 2017 MoriyaLB
--  Lamda may be freely distributed under the MIT license.

-- @Basic Instructions
-- @String is treated as Array(lua table)
-- @All method is auto curried
-- @`nil` is the very annoy params in lua because it not only a `none` value but also a `absent` method args. 
-- 	we can not tell the difference, so if we curry the method, the nil args is rejected to send or the method 
-- 	will return a `curried` function as a invalid result.
-- @All method is immutable function without side effect
-- @All sort method is none-stable (based on lua table.sort), a stable version may released later.
-- @Lamda transducer / lens / transformer / fantasy-land is not implements in the current version.
-- @All method doesn't handle the self param, you may take care of it (unlike javascript, `self` is as normal as any other method args)
-- @Try think functional by using this library

-- Enjoy it.
-- local R = Cupid.Libs.Lamda
-- local sayHello = R.compose(R.join(" "), R.map(R.pipe(R.toUpper, R.trim, R.take(3))), R.split(","))
-- R.call(print, sayHello("Hello, Lamda!"))

local R = {}

math.randomseed(os.time())

-- ===========================================
-- ================ Constants ================
-- ===========================================
R.ARRAY = "@@array"
R.OBJECT = "@@object"
R.TABLE = "@@table"
R.STRING = "@@string"
R.NAN = "@@nan"
R.INF = "@@inf"
R.INTEGER = "@@int"
R.NUMBER = "@@number"
R.NIL = "@@nil"
R.FUNCTION = "@@func"
R.USERDATA = "@@user"
R.THREAD = "@@thread"

-- ===================================================
-- ================ Private Functions ================
-- =================================================== 
R.__ = { ['@@functional/placeholder'] = true }
local __INF = 1/0
local __LUAJIT = jit ~= nil
local __LUAVER = _VERSION

local unpack = unpack
if unpack == nil then 
	unpack = table.unpack
end
R.unpack = unpack

local _isPlaceholder = function(a)
    return a ~= nil and type(a) == 'table' and a['@@functional/placeholder']
end


--[[
	unlike the lua `table.pack` function. 
	_pack will return a simple array with the given arguments.
	
	@private
	@category Functional
	@param {*...} * any arguments
	@return {Array} all arguments array
]]
local _pack = function(...)
	return {...}
end

--[[
	Optimized internal one-arity curry function.
	
	@private
	@category Function
	@param {Function} fn The function to curry.
	@return {Function} The curried function.
]]
local _curry1 = function(fn)
	local f1
	f1 = function(...)
		local args = {...}
		if #args == 0 or _isPlaceholder(args[1]) then
			return f1
		else
			return fn(unpack(args))
		end
	end
	return f1
end

--[[
	Optimized internal two-arity curry function.
	
	@private
	@category Function
	@param {Function} fn The function to curry.
	@return {Function} The curried function.
]]
local _curry2 = function(fn)
	local f2
	f2 = function(...)
		local args = {...}
		if #args == 0 then
			return f2
		elseif #args == 1 then
			return _isPlaceholder(args[1]) and f2 or _curry1(function(...)
				return fn(args[1], ...)
			end)
		else
			return (_isPlaceholder(args[1]) and _isPlaceholder(args[2])) and f2 or (_isPlaceholder(args[1]) and _curry1(function (_a, ...)
			 	return fn(_a, args[2], ...)
			end) or (_isPlaceholder(args[2]) and _curry1(function (...)
				return fn(args[1], ...)
			end) or fn(...)))
		end
	end
	return f2
end

--[[
	Optimized internal three-arity curry function.
	
	@private
	@category Function
	@param {Function} fn The function to curry.
	@return {Function} The curried function.
]]
local _curry3 = function(fn)
	local f3
	f3 = function(...)
		local args = {...}
		local a, b, c = unpack(args)
		if #args == 0 then
			return f3
		elseif #args == 1 then
			return _isPlaceholder(a) and f3 or _curry2(function (...)
				return fn(a, ...)
			end)
		elseif #args == 2 then
			return (_isPlaceholder(a) and _isPlaceholder(b)) and f3 or (_isPlaceholder(a) and _curry2(function (_a, ...)
				return fn(_a, b, ...)
			end) or (_isPlaceholder(b) and _curry2(function (...)
				return fn(a, ...)
			end) or _curry1(function (...)
				return fn(a, b, ...)
			end)))
		else
			if _isPlaceholder(a) and _isPlaceholder(b) and _isPlaceholder(c) then
				return f3
			elseif _isPlaceholder(a) and _isPlaceholder(b) then
				return _curry2(function (_a, _b, ...)
					return fn(_a, _b, c, ...)
				end)
			elseif _isPlaceholder(a) and _isPlaceholder(c) then
				return  _curry2(function (_a, ...)
					return fn(_a, b, ...)
				end)
			elseif _isPlaceholder(b) and _isPlaceholder(c) then
				return  _curry2(function (...)
					return fn(a, ...)
				end)
			elseif _isPlaceholder(a)  then
				return _curry1(function (_a, ...)
					return fn(_a, b, c, ...)
				end)
			elseif _isPlaceholder(b) then
				return _curry1(function (_b, ...)
					return fn(a, _b, c, ...)
				end)
			elseif _isPlaceholder(c) then
				return _curry1(function (...)				
					return fn(a, b, ...)
				end)
			else
				return fn(...)
			end
		end
	end
	return f3
end

--[[
	Internal curryN function.
	
	@private
	@category Function
	@param {Number} length The arity of the curried function.
	@param {Array} received An array of arguments received thus far.
	@param {Function} fn The function to curry.
	@return {Function} The curried function.
]]
local _curryN
_curryN = function(length, received, fn)
	return function(...)
		local args = {...}
		local argsIdx = 1
		local combined = {}	
		local left = length
		local combinedIdx = 1
		
		while combinedIdx <= #received or argsIdx <= #args do
			local result
			if (combinedIdx <= #received and (not _isPlaceholder(received[combinedIdx]) or argsIdx >= #args)) then
				result = received[combinedIdx]
			else
				result = args[argsIdx]
				argsIdx = argsIdx + 1
			end
			combined[combinedIdx] = result
			if not _isPlaceholder(result) then
				left = left - 1
			end
			combinedIdx = combinedIdx + 1
		end
		return left <= 0 and fn(unpack(combined)) or _curryN(length, combined, fn)
	end
end

local _pipe = function (f, g)
	return function (...)
		return g(f(...))
	end
end

--[[
	Get a table size 
	@private
	@param {*} val The object or array.
	@return {int} the extactly count that the given value contains
	@example	
		_safe_size(nil) --> 0
		_safe_size({}) --> 0
		_safe_size({1,2,3}) --> 3
		_safe_size({1,2,3,nil,5}) --> 4
]]
local _safe_size = function(val)
	if type(val) ~= "table" then
		error("<lamda_error> _safe_size::can not get a non-table size " .. val)
		return 0
	end
	local s = 0
	for k, v in pairs(val) do
		s = s + 1
	end
	return s
end

local _array_size = function(val)
	if type(val) ~= "table" then
		error("<lamda_error> _safe_size::can not get a non-table size " .. val)
		return 0
	end
	local s = 0
	for k, v in ipairs(val) do
		s = s + 1
	end
	return s
end

local _isTable = function(val)
	return type(val) == "table"
end

local _isArray = function(val)
	return type(val) == "table" and _safe_size(val) == _array_size(val)
end

local _isString = function(val)
	return type(val) == "string"
end

local _isObject = function(val)
	return type(val) == "table" and _safe_size(val) ~= _array_size(val)
end

local _isBoolean = function(val)
	return type(val) == "boolean"
end

local _isNan = function(val)
	return val ~= val
end

local _isInf = function(val)
	return val == __INF
end

local _isInteger = function(val)
	return val ~= nil and type(val) == "number" and not _isInf(val) and math.floor(val) == val
end

local _isNumber = function(val)
	return val ~= nil and type(val) == "number" and not _isInf(val) and not _isNan(val)
end

local _isFunction = function (val)
    return type(val) == "function"
end

local _isUserData = function (val)
	return type(val) == "userdata"
end

local _isThread = function (val)
	return type(val) == "thread"
end

local _get = function(idx, list)
	if _isString(list) then
		if idx <= 0 then return "" end
		return string.sub(list, idx, idx)
	elseif _isArray(list) then
		if idx <= 0 then return nil end
		return list[idx]
	end
end

local _assign = function(obj, ...)
	local args = {...}
	for _,v in pairs(args) do
		for key,value in pairs(v) do
			obj[key] = value
		end
	end
	return obj
end

local _ifelse = function(cond, _t, _f)
	if cond then
		return _t
	else
		return _f
	end
end

--[[
     `_makeFlat` is a helper function that returns a one-level or fully recursive
     function based on the flag passed in.
     
     @private
]]
local _makeFlat = function(recursive)
	local flatt
	flatt = function(list)
		local value, jlen, j
		local result = {}
		local idx = 1
		local ilen = #list
		while idx <= ilen do
			if _isArray(list[idx]) then
				value = recursive and flatt(list[idx]) or list[idx]
				j = 1
				jlen = #value
				while j <= jlen do
					result[#result + 1] = value[j]
					j = j + 1
				end
			else
				result[#result + 1] = list[idx]
			end
			idx = idx + 1
		end
		return result
	end

	return flatt
end

local _clone
_clone = function(value, deep)
	if deep == nil then deep = true end

	if _isTable(value) then
		local c = {}
		for k,v in ipairs(value) do
			if deep then
				c[k] = _clone(v)
			else
				c[k] = v
			end
		end
		for k,v in pairs(value) do
			if deep then
				c[k] = _clone(v)
			else
				c[k] = v
			end
		end
		return c
	elseif _isString(value) or _isNumber(value) or _isBoolean(value) then
		return value
	else
		error("<lamda_error> _clone:: can not clone this value -> " .. value)
	end
end

local _complement = function(f)
	return function(...)
		return not f(...)
	end
end

--[[
	Private `concat` function to merge two array-like objects.
	
	@private
	@param {Array} {set1={}} An array-like object.
	@param {Array} {set2={}} An array-like object.
	@return {Array} A new, merged array.
	@example
		_concat({4, 5, 6}, {1, 2, 3}) --> {4, 5, 6, 1, 2, 3}
]]
local _concat = function(set1, set2)
	set1 = set1 or {}
	set2 = set2 or {}
	local len1 = #set1
	local len2 = #set2
	local result = {}
	local idx = 1
	while idx <= len1 do
		result[#result + 1] = set1[idx]
		idx = idx + 1
	end
	idx = 1
	while idx <= len2 do
		result[#result + 1] = set2[idx]
		idx = idx + 1
	end
	return result
end

local _containsWith = function(pred, x, list)
	local idx = 1
	local len = #list
	while idx <= len do
		if pred(x, list[idx]) then
			return true
		end
		idx = idx + 1
	end
	return false
end

local function _ref_equal(a, b)
	return a == b
end

local _equals
_equals = function(a, b)	
	if (type(a) ~= type(b)) then
		return false
	end

	if not _isTable(a) and not _isTable(b) then
		return a == b
	end

	if _isArray(a) then
		if not _isArray(b) then return false end
		if #a ~= #b then return false end
		for i,v in ipairs(a) do
			if not _equals(v, b[i]) then
				return false
			end
		end
		return true
	elseif _isArray(b) then
		return false
	else
		for k,v in pairs(a) do
			if not _equals(v, b[k]) then
				return false
			end
		end
		for k,v in pairs(b) do
			if not _equals(v, a[k]) then
				return false
			end
		end
		return true
	end
end

local _filter = function(fn, list)
	local idx = 1
	local len = #list
	local result = {}
	while idx <= len do
		if fn(list[idx]) then
			result[#result + 1] = list[idx]
		end
		idx = idx + 1
	end
	return result
end

local _has = function(prop, obj)
	return _isTable(obj) and not R.isNull(obj[prop])
end

local _identity = function(x)
	return x
end

local _indexOf = function(xs, target, idx)
	if _isString(xs) then
		for i = idx, string.len(xs) do
			if string.sub(xs, i, i) == target then
				return i
			end
		end
	else
		while idx <= #xs do
			if R.equals(target, xs[idx]) then
				return idx
			end
			idx = idx + 1
		end
	end
	return -1
end

local _contains = function(a, list)
    return _indexOf(list, a, 1) >= 1
end

local _of = function(x)
   return {x}
end

local _reduce = function(fn, acc, list)
	local idx = 1
	while idx <= #list do		
		acc = fn(acc, list[idx])
		idx = idx + 1
	end
	return acc
end

local _reduceBy = _curryN(4, {}, function(valueFn, valueAcc, keyFn, list)
	return _reduce(function (acc, elt)
		local key = keyFn(elt)
		local v = _ifelse(_has(key, acc), acc[key], valueAcc)
		acc[key] = valueFn(v, elt)
		return acc
	end, {}, list)
end)

local _mapObject = function(fn, list)
	if _isObject(list) then
		local result = {}
		for k,v in pairs(list) do
			result[k] = fn(v, k, list)
		end	
		return result
	else
		return R.map(fn, list)
	end
end

--not pure
local _shuffle = function(list)
	if not list or #list == 0 then return list end
	for i = 1, #list do
		local rnd = math.random(i, #list)
		list[i], list[rnd] = list[rnd], list[i]
	end
end

-- ================================================
-- ================ Util Functions ================
-- ================================================ 
--[[
	Counts the elements of a list according to how many match each value of a
	key generated by the supplied function. Returns an object mapping the keys
	produced by `fn` to the number of occurrences in the list. Note that all
	keys are coerced to strings because of how JavaScript objects work.
		
	@func
	@category Util
	@sig (a -> String) -> [a] -> {*}
	@param {Function} fn The function used to map values to keys.
	@param {Array} list The list to count elements from.
	@return {Object} An object mapping keys to number of occurrences in the list.
	@example	
		local numbers = {1.0, 1.1, 1.2, 2.0, 3.0, 2.2}
		R.countBy(Math.floor)(numbers) --> {'1': 3, '2': 2, '3': 1}	
		local letters = {'a', 'b', 'A', 'a', 'B', 'c'}
		R.countBy(R.toLower)(letters) --> {'a': 3, 'b': 2, 'c': 1}
]]
R.countBy = _reduceBy(function (acc, elem)
	return acc + 1
end, 0)

--[[
	Counts the given element of a list
	
	@func
	@category Util
	@sig a -> [a] -> Number
	@param {*} c The given element to count.
	@param {Array} list The list to count elements from.
	@return {Number} The element occurrences in the list
	@example	
		R.count(5, {1,2,5,5,3,2}) --> 2
		R.count('a', "hello world") --> 0
]]
R.count = _curry2(function(c, list)
	local index = 1
	local result = 0
	if _isString(list) then		
		while index <= string.len(list) do
			if R.equals(c, string.sub(list, index, index)) then
				result = result + 1
			end
			index = index + 1
		end
	else
		while index <= #list do
			if R.equals(c, list[index]) then
				result = result + 1
			end
			index = index + 1
		end
	end
	return result
end)

--[[
	Returns the second argument if it is not `nil` or `nan` or `inf`
	otherwise the first argument is returned.
	
	@func
	@category Util
	@sig a -> b -> a | b
	@param {a} default The default value.
	@param {b} val `val` will be returned instead of `default` unless `val` is `null`, `nil` or `NaN`.
	@return {*} The second value if it is not `null`, `nil` or `NaN`, otherwise the default value
	@example	
		R.defaultTo(42, nil) --> 42
		R.defaultTo(42, 0/0) --> 42
		R.defaultTo(42, 1/0) --> 42
		R.defaultTo(42, 100) --> 100

	@not curried
		nil value will be tested.
]]
R.defaultTo = function(d, v)
	return R.isNull(v) and d or v
end

--[[
    Returns the first argument.
	
	@func
	@category Util
	@sig a, *... -> a
	@param {*} ... Any arguments
	@return {*} The first arugment 
	@example     
		local t = R.first('a', 'b', 'c') --> 'a'
		local t = R.first()	--> nil
	@not curried
		curry for this method is no sense
]]
R.first = function(...)
	local args = {...}
	if #args > 0 then
		return args[1]
	else
		return nil
	end
end

--[[
	Returns the empty value of its argument's type. Lamda defines the empty
	value of Table(`{}`), String (`''`), and Arguments.	
	
	@func
	@category Util
	@sig a -> a
	@param {*} x The value to check.
	@return {*} The empty value by the given value's type.
	@example	
		R.empty(3) --> 0
		R.empty(function() end)	--> nil
		R.empty({1, 2, 3}) --> {}
		R.empty('unicorns') --> ''
		R.empty({x = 1, y = 2}) --> {}
		R.empty(true) --> false
]]
R.empty = _curry1(function(x)
	if _isTable(x) then
		return {}
	elseif _isString(x) then
		return ""
	elseif _isNumber(x) then
		return 0
	elseif _isBoolean(x) then
		return false
	else
		return nil
	end
end)

--[[
	Returns `true` if its arguments are equivalent, `false` otherwise. 
	
	@func
	@category Util
	@sig a -> b -> Boolean
	@param {*} a
	@param {*} b
	@return {Boolean}
	@see R.same
	@example	
		R.equals(1, 1) --> true
		R.equals(1, '1') --> false
		R.equals({1, 2, 3}, {1, 2, 3}) --> true

		local a = {} 
		a.v = a
		local b = {} 
		b.v = b
		R.equals(a, b) --> stack error , don't do this!
]]
R.equals = _curry2(_equals)
--[[
	@alias R.equals
	@not curried
]]
R.safeEquals = _equals

--[[
	Takes a function and two values in its domain and returns `true` if the
	values map to the same value in the codomain `false` otherwise.
	
	@func
	@category Util
	@sig (a -> b) -> a -> a -> Boolean
	@param {Function} f
	@param {*} x
	@param {*} y
	@return {Boolean}
	@example
		R.eqBy(math.abs, 5, -5) --> true
]]
R.eqBy = _curry3(function(f, x, y)
	return R.equals(f(x), f(y))
end)

--[[
	Reports whether two objects have the same value, in [`R.equals`](#equals)
	terms, for the specified property. Useful as a curried predicate.
	
	@func
	@category Util
	@category Object
	@sig k -> {k: v} -> {k: v} -> Boolean
	@param {String} prop The name of the property to compare
	@param {Object} obj1
	@param {Object} obj2
	@return {Boolean}
	
	@example
		local o1 = { a = 1, b = 2, c = 3, d = 4 }
		local o2 = { a = 10, b = 20, c = 3, d = 40 }
		R.eqProps('a', o1, o2) --> false
		R.eqProps('c', o1, o2) --> true
]]
R.eqProps = _curry3(function(prop, obj1, obj2)
	return R.equals(obj1[prop], obj2[prop])
end)

--[[
	Returns `true` if the first argument is greater than the second `false`
	otherwise.
	
	@func
	@category Util
	@sig Ord a => a -> a -> Boolean
	@param {*} a
	@param {*} b
	@return {Boolean}
	@see R.lt
	@example	
		R.gt(2, 1) --> true
		R.gt(2, 2) --> false
		R.gt(2, 3) --> false
		R.gt('a', 'z') --> false
		R.gt('z', 'a') --> true
]]
R.gt = _curry2(function (a, b)
	return a > b
end)

--[[
	Returns `true` if the first argument is greater than or equal to the second
	`false` otherwise.
	
	@func
	@category Util
	@sig Ord a => a -> a -> Boolean
	@param {Number} a
	@param {Number} b
	@return {Boolean}
	@see R.lte
	@example	
		R.gte(2, 1) --> true
		R.gte(2, 2) --> true
		R.gte(2, 3) --> false
		R.gte('a', 'z') --> false
		R.gte('z', 'a') --> true
]]
R.gte = _curry2(function(a, b)
	return a >= b
end)

--[[
	See if `val` is an instance of the supplied constructor. 
	
	@func
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@example
		R.is(R.TABLE, {}) --> true
		R.is(R.NUMBER, 1) --> true
		R.is(R.OBJECT, 1) --> false
		R.is(R.STRING, 's') --> true     
		R.is(R.ARRAY, 's') --> false
		R.is(R.NUMBER, {}) --> false
	@not curried
]]
R.is = function(Type, val)
	if Type == R.TABLE then
		return _isTable(val)
	elseif Type == R.ARRAY then
		return _isArray(val)
	elseif Type == R.OBJECT then
		return _isObject(val)
	elseif Type == R.STRING then
		return _isString(val)
	elseif Type == R.INTEGER then
		return _isInteger(val)
	elseif Type == R.NUMBER then
		return _isNumber(val)
	elseif Type == R.FUNCTION then 
		return _isFunction(val)
	elseif Type == R.USERDATA then
		return _isUserData(val)
	elseif Type == R.NAN then
		return _isNan(val)
	elseif Type == R.INF then
		return _isInf(val)
	elseif Type == R.NIL then
		return val == nil
	else
		error("<lamda_error> is:: Invalid Type To Check ===> " .. Type)
	end
end

--[[
	See if `val` is an integer
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isInteger = _curry1(_isInteger)

--[[
	See if `val` is an integer. 

	If val is nil, return false.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isInteger
	@not curried
]]
R.isSafeInteger = _isInteger

--[[
	See if `val` is a number.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isNumber = _curry1(_isNumber)

--[[
	See if `val` is a number.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isNumber		
	@not curried
]]
R.isSafeNumber = _isNumber

--[[
	See if `val` is a string.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isString = _curry1(_isString)

--[[
	See if `val` is a string.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isString
	@not curried	
]]
R.isSafeString = _isString

--[[
	See if `val` is a function.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isFunction = _curry1(_isFunction)

--[[
	See if `val` is a function.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isFunction
	@not curried
]]
R.isSafeFunction = _isFunction

--[[
	See if `val` is a user data.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isUserData = _curry1(_isUserData)

--[[
	See if `val` is a user data.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isUserData
	@not curried	
]]
R.isSafeUserData = _isUserData

--[[
	See if `val` is a thread.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is
]]
R.isThread = _curry1(_isThread)

--[[
	See if `val` is a user data.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isThread
	@not curried	
]]
R.isSafeThread = _isThread

--[[
	See if `val` is a table.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isTable = _curry1(_isTable)

--[[
	See if `val` is a table.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isTable
	@not curried
]]
R.isSafeTable = _isTable

--[[
	See if `val` is an array.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isArray = _curry1(_isArray)

--[[
	See if `val` is an array.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isArray
	@not curried	
]]
R.isSafeArray = _isArray

--[[
	See if `val` is an object.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isObject = _curry1(_isObject)

--[[
	See if `val` is an object.

	If val is nil, return false.

	@func	
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isObject
	@not curried	
]]
R.isSafeObject = _isObject

--[[
	See if `val` is nan.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isNan = _curry1(_isNan)

--[[
	See if `val` is nan.

	if val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isNan
	@not curried
]]
R.isSafeNan = _isNan

--[[
	See if `val` is inf.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isInf = _curry1(_isInf)

--[[
	See if `val` is inf.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isInf
	@not curried
]]
R.isSafeInf = _isInf

--[[
	See if `val` is boolean.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
]]
R.isBoolean = _curry1(_isBoolean)

--[[
	See if `val` is boolean.

	If val is nil, return false.

	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is, R.isBoolean
	@not curried
]]
R.isSafeBoolean = _isBoolean

--[[
	See if `val` is empty value like `nil` `inf` `nan`.
	
	@func
	@since 0.2.0
	@category Util
	@sig (* -> {*}) -> a -> Boolean
	@param {Object} ctor A constructor
	@param {*} val The value to test
	@return {Boolean}
	@see R.is		
	@not curried
]]
R.isNull = function(val)
	return R.isNil(val) or _isNan(val) or _isInf(val)
end

--[[
	Returns `true` if the given value is its type's empty value `false`
	otherwise.
	
	@func
	@category Util
	@sig a -> Boolean
	@param {*} x
	@return {Boolean}
	@example
		R.isEmpty({1, 2, 3})   --> false
		R.isEmpty({})          --> true
		R.isEmpty('')          --> true
		R.isEmpty(nil)        --> true
		R.isEmpty({})          --> true
		R.isEmpty({length = 0}) --> false
	@not curried
]]
R.isEmpty = function(x)
	if R.isNull(x) then 
		return true
	elseif _isString(x) then 
		return x == ""
	elseif _isTable(x) then
		return next(x) == nil
	else
		return false
	end
end

--[[
	Checks if the input value is `nil`.
	
	@func
	@category Util
	@sig * -> Boolean
	@param {*} x The value to test.
	@return {Boolean} `true` if `x` is `nil` or `null`, otherwise `false`.
	@example
		R.isNil(nil) --> true
		R.isNil(0) --> false
		R.isNil(1/0) --> false
		R.isNil(0/0) --> false
		R.isNil([]) --> false
	@not curried
]]
R.isNil = function(x)
	return x == nil
end

--[[
	Returns `true` if the first argument is less than the second `false`
	otherwise.
	
	@func
	@category Util
	@sig Ord a => a -> a -> Boolean
	@param {*} a
	@param {*} b
	@return {Boolean}
	@see R.gt
	@example	
		R.lt(2, 1) --> false
		R.lt(2, 2) --> false
		R.lt(2, 3) --> true
		R.lt('a', 'z') --> true
		R.lt('z', 'a') --> false
]]
R.lt = _curry2(function(a, b)
	return a < b
end)

--[[
	Returns `true` if the first argument is less than or equal to the second
	`false` otherwise.
	
	@func
	@category Util
	@sig Ord a => a -> a -> Boolean
	@param {Number} a
	@param {Number} b
	@return {Boolean}
	@see R.gte
	@example	
		R.lte(2, 1) --> false
		R.lte(2, 2) --> true
		R.lte(2, 3) --> true
		R.lte('a', 'z') --> true
		R.lte('z', 'a') --> false
]]
R.lte = _curry2(function(a, b)
	return a <= b
end)

--[[
	Returns the larger of its two arguments.
	
	@func
	@category Util
	@sig Ord a => a -> a -> a
	@param {*} a
	@param {*} b
	@return {*}
	@see R.maxBy, R.min
	@example	
		R.max(789, 123) --> 789
		R.max('a', 'b') --> 'b'
]]
R.max = _curry2(function(a, b)
	return b > a and b or a
end)


--[[
	Takes a function and two values, and returns whichever value produces the
	larger result when passed to the provided function.
	
	@func
	@category Util
	@sig Ord b => (a -> b) -> a -> a -> a
	@param {Function} f
	@param {*} a
	@param {*} b
	@return {*}
	@see R.max, R.minBy
	@example
		local square = function(x) return x*x end     
		R.maxBy(square, -3, 2) --> -3     
		R.reduce(R.maxBy(square), 0, {3, -5, 4, 1, -2}) --> -5
		R.reduce(R.maxBy(square), 0, {}) --> 0
]]
R.maxBy = _curry3(function(f, a, b)
	return f(b) > f(a) and b or a
end)

--[[
	Returns the smaller of its two arguments.
	
	@func
	@category Util
	@sig Ord a => a -> a -> a
	@param {*} a
	@param {*} b
	@return {*}
	@see R.minBy, R.max
	@example
		R.min(789, 123) --> 123
		R.min('a', 'b') --> 'a'
]]
R.min = _curry2(function(a, b)
	return b < a and b or a
end)

--[[
	Takes a function and two values, and returns whichever value produces the
	smaller result when passed to the provided function.
	
	@func
	@category Util
	@sig Ord b => (a -> b) -> a -> a -> a
	@param {Function} f
	@param {*} a
	@param {*} b
	@return {*}
	@see R.min, R.maxBy
	@example
		local square = n => n * n
		R.minBy(square, -3, 2) --> 2     
		R.reduce(R.minBy(square), 100, {3, -5, 4, 1, -2}) --> 1
		R.reduce(R.minBy(square), 100, {}) --> 100
]]
R.minBy = _curry3(function(f, a, b)
	return f(b) < f(a) and b or a
end)

--[[
	Unlike the lua `table.pack` function that `R.pack` will return a simple array with the given arguments.
	
	@func
	@category Util
	@sig *... -> [*...]		
	@param {*...} * any arguments
	@return {Array} all arguments array
	@example
		R.pack(1,2,3,4) --> {1,2,3,4}
	@not curried
]]
R.pack = _pack

--[[
	Returns `true` if its arguments are equivalent by reference, `false` otherwise. 
	
	@func
	@category Util
	@sig a -> b -> Boolean
	@param {*} a
	@param {*} b
	@return {Boolean}
	@see R.equals
	@example	
		R.same(1, 1) --> true
		R.same(1, '1') --> false
		R.same({1, 2, 3}, {1, 2, 3}) --> false
		local a = {}
		local b = a
		R.same(a, b) --> true
]]
R.same = _curry2(function(a, b)
	return a == b
end)

--[[
    Returns the second argument.
	
	@func	
	@category Util
	@sig a, b, *... -> b
	@param {*} ... Any arguments.
	@return {*} The second argument.
	@example     
		local t = R.second('a', 'b', 'c') --> 'b'
		local t = R.second('a') --> nil
	@not curried
		curry for this method is no sense
]]
R.second = function(...)
	local args = {...}
	if #args > 1 then
		return args[2]
	else
		return nil
	end
end

--[[
	Print all the arguments to stdout
	
	@func
	@since 0.2.0
	@category Util
	@sig * -> nil
	@param {*} ...
	@example     
		R.show(1,2,"hell", {a=b={c="hello"}})
	@not curried		
]]
R.show = function(...)
	local _t = ""
	for k, v in ipairs({...}) do
		_t = _t .. R.toString(v)
	end
	print(_t)
end

--[[
	Finds the set (i.e. no duplicates) of all elements contained in the first or
	second list, but not both.
	
	@func
	@category Util
	@sig [*] -> [*] -> [*]
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The elements in `list1` or `list2`, but not both.
	@see R.symmetricDifferenceWith, R.difference, R.differenceWith
	@example	
		R.symmetricDifference({1,2,3,4}, {7,6,5,4,3}) --> {1,2,7,6,5}
		R.symmetricDifference({7,6,5,4,3}, {1,2,3,4}) --> {7,6,5,1,2}
]]
R.symmetricDifference = _curry2(function(list1, list2)
	return R.concat(R.difference(list1, list2), R.difference(list2, list1))
end)

--[[
	Finds the set (i.e. no duplicates) of all elements contained in the first or
	second list, but not both. Duplication is determined according to the value
	returned by applying the supplied predicate to two list elements.
	
	@func
	@category Util
	@sig ((a, a) -> Boolean) -> [a] -> [a] -> [a]
	@param {Function} pred A predicate used to test whether two items are equal.
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The elements in `list1` or `list2`, but not both.
	@see R.symmetricDifference, R.difference, R.differenceWith
	@example	
		local eqA = R.eqBy(R.prop('a'))
		local l1 = {{a=1}, {a=2}, {a=3}, {a=4}}
		local l2 = {{a=3}, {a=4}, {a=5}, {a=6}}
		R.symmetricDifferenceWith(eqA, l1, l2) --> {{a=1}, {a=2}, {a=5}, {a=6}}
]]
R.symmetricDifferenceWith = _curry3(function(pred, list1, list2)
	return R.concat(R.differenceWith(pred, list1, list2), R.differenceWith(pred, list2, list1))
end)

local _check = function(test, loop)
	return _isTable(test) and R.any(R.same(test), loop)
end

local _toString
_toString = function(value, loop, isJson, forceObj)
	if _isTable(value) then
		loop[#loop + 1] = value
	end

	if not forceObj and _isArray(value) then
		local arr = {}
		for _,v in ipairs(value) do			
			if _check(v, loop) then 
				arr[#arr + 1] = "\"<#loop ...>\""
			else
				arr[#arr + 1] = _toString(v, loop, isJson, forceObj)
			end
		end
		if isJson then
			return "["..table.concat(arr, ",").."]"				
		else
			return "{"..table.concat(arr, ",").."}"	
		end
	elseif _isTable(value) then
		local arr = {}
		for k,v in pairs(value) do	
			if _check(v, loop) then 
				if isJson then
					arr[#arr + 1] = "\""..k.."\""..":".."\"<#loop ...>\""
				else
					arr[#arr + 1] = "[".._toString(k, loop, isJson, forceObj).."]=".."\"<#loop ...>\""
				end
			else
				if isJson then
					arr[#arr + 1] = "\""..k.."\""..":".._toString(v, loop, isJson, forceObj)
				else
					arr[#arr + 1] = "[".._toString(k, loop, isJson, forceObj).."]=".._toString(v, loop, isJson, forceObj)
				end
			end					
		end		
		return "{"..table.concat(arr, ",").."}"		
	elseif _isString(value) then
		return "\""..value.."\""
	elseif _isFunction(value) then
		return "\"<#f "..tostring(value)..">\""
	elseif _isUserData(value) then
		return "\"<#u "..tostring(value)..">\""
	elseif _isThread(value) then
		return "\"<#t "..tostring(value)..">\""
	elseif value == nil then
		if isJson then
			return "null"
		else
			return "nil"
		end
	elseif _isNan(value) then
		if isJson then
			return "NaN"
		else
			return "nan"
		end
	elseif _isInf(value) then
		if isJson then
			return "Infinity"
		else
			return "inf"
		end
	else
		return tostring(value)
	end
end

--[[
	Convert the value to string recursively.
	
	@func	
	@category Util
	@sig * -> String
	@param {*} value
	@param {bool} forceObj make sure the out table is table-like, not array-like
	@return {String}
	@example     
		local t = R.toString() --> "nil"
		local t = R.toString("") --> ""
		local t = R.toString({a=1}) --> "{["a"]=1}"
	@not curried
		can not curry this function because nil will not be print
]]
R.toString = function(value, forceObj)
	local loop = {}
	return _toString(value, loop, false, forceObj)
end

--[[
	Convert the value to string(json format) recursively
	
	@func	
	@since 0.3.0
	@category Util
	@sig * -> String
	@param (*) value
	@param {bool} forceObj make sure the out table is table-like, not array-like
	@return {String}
	@example     
		local t = R.toJson() --> "[null]"
		local t = R.toJson("") --> 
		local t = R.toJson({a=1}) --> "{"a":1}"
	@not curried
		can not curry this function because nil will not be print
]]
R.toJson = function(value, forceObj)
	local loop = {}
	if not _isTable(value) then
		return "[" .. _toString(value, loop, true, forceObj) .."]"
	else
		return _toString(value, loop, true, forceObj)
	end
end

-- ======================================================
-- ================ Functional Functions ================
-- ======================================================
--[[
	Returns a function that always returns the given value. Note that for
	non-primitives the value returned is a reference to the original value.
	
	This function is known as `const`, `constant`, or `K` (for K combinator) in
	other languages and libraries.
	
	@func	
	@category Functional
	@sig a -> (* -> a)
	@param {*} val The value to wrap in a function
	@return {Function} A Function :: * -> val.
	@example
		local t = R.always('Tee')
		t() --> 'Tee'
]]
R.always = _curry1(function(val)
	return function()
		return val
	end
end)

--[[
	A function that always returns `false`. Any passed in parameters are ignored.
	
	@func	
	@category Functional
	@sig * -> Boolean
	@param {*}
	@return {Boolean}
	@see R.always, R.T
	@example	
		R.F()  --> false
]]
R.F = R.always(false)

--[[
	A function that always returns `true`. Any passed in parameters are ignored.
	
	@func
	
	@category Functional
	@sig * -> Boolean
	@param {*}
	@return {Boolean}
	@see R.always, R.F
	@example
		R.T()  --> true
]]
R.T = R.always(true)

--[[
	Takes a list of predicates and returns a predicate that returns true for a
	given list of arguments if every one of the provided predicates is satisfied
	by those arguments.
	
	
	@func
	@category Functional
	@sig (*... -> Boolean) -> ... -> (*... -> Boolean)
	@param {Function}* predicates to check
	@return {Function} The combined predicate
	@see R.anyPass
	@example
		local isQueen = R.propEq('rank', 'Q')
		local isSpade = R.propEq('suit', '♠︎')
		local isQueenOfSpades = R.allPass(isQueen, isSpade)
	
		isQueenOfSpades({rank = 'Q', suit = '♣︎'}) --> false
		isQueenOfSpades({rank = 'Q', suit = '♠︎'}) --> true
	@not curried
]]
R.allPass = function(...)
	local preds = {...}
	return function(...)
		for k,pred in ipairs(preds) do
			if not pred(...) then
				return false
			end
		end
		return true
	end
end

--[[
	Returns `true` if both arguments are `true` `false` otherwise.
	
	@func
	@category Functional
	@sig a -> b -> a | b
	@param {Any} a
	@param {Any} b
	@return {Any} the first argument if it is falsy, otherwise the second argument.
	@see R.both
	@example
		R.and(true, true) --> true
		R.and(true, false) --> false
		R.and(false, true) --> false
		R.and(false, false) --> false
]]
R.and_ = _curry2(function(a, b)
    return a and b
end)

--[[
	Takes a list of predicates and returns a predicate that returns true for a
	given list of arguments if at least one of the provided predicates is
	satisfied by those arguments.
		
	@func
	@category Functional
	@sig (*... -> Boolean) -> ... -> (*... -> Boolean)
	@param {Function}* predicates to check
	@return {Function} The combined predicate
	@see R.allPass
	@example	
		local isClub = R.propEq('suit', '♣')
		local isSpade = R.propEq('suit', '♠')
		local isBlackCard = R.anyPass(isClub, isSpade)
	
		isBlackCard({rank = '10', suit ='♣'}) --> true
		isBlackCard({rank = 'Q', suit = '♠'}) --> true
		isBlackCard({rank = 'Q', suit = '♦'}) --> false
]]
R.anyPass = function(...)
	local preds = {...}
	return function(...)
		for k,pred in ipairs(preds) do
			if pred(...) then
				return true
			end
		end
		return false
	end
end

--[[
	Applies function `fn` to the argument list `args`. This is useful for
	creating a fixed-arity function from a variadic function. `fn` should be a
	bound function if context is significant.
	
	@func
	@category Functional
	@sig (*... -> a) -> [*] -> a
	@param {Function} fn The function which will be called with `args`
	@param {Array} args The arguments to call `fn` with
	@return {*} result The result, equivalent to `fn(...args)`
	@see R.unapply
	@example	
		local nums = {1, 2, 3, -99, 42, 6, 7}
		R.apply(math.max, nums) --> 42

	@symb R.apply(f, {a, b, c}) = f(a, b, c)
]]
R.apply = _curry2(function(fn, args)
    return fn(unpack(args))
end)

--[[
	Makes an ascending comparator function out of a function that returns a value
	that can be compared with `<` and `>`.
	
	@func
	@category Functional
	@sig Ord b => (a -> b) -> a -> a -> Number
	@param {Function} fn A function of arity one that returns a value that can be compared
	@param {*} a The first item to be compared.
	@param {*} b The second item to be compared.
	@return {Number} `-1` if fn(a) < fn(b), `1` if fn(b) < fn(a), otherwise `0`
	@see R.descend
	@example	
		local byAge = R.ascend(R.prop('age'))
		local people = {
			{ name = 'Emma', age = 70 },
			{ name = 'Peter', age = 78 },
			{ name = 'Mikhail', age = 62 },
		}
		local peopleByYoungestFirst = R.sort(byAge, people) --> {{ name = 'Mikhail', age: 62 },{ name = 'Emma', age: 70 }, { name = 'Peter', age: 78 }}
]]
R.ascend = _curry3(function(fn, a, b)
	local aa = fn(a)
	local bb = fn(b)
    return R.same(aa, bb) and 0 or aa < bb and -1 or 1
end)

--[[
	Wraps a function of any arity (including nullary) in a function that accepts
	exactly 2 parameters. Any extraneous parameters will not be passed to the
	supplied function.
	
	@func
	@category Functional
	@sig (* -> c) -> (a, b -> c)
	@param {Function} fn The function to wrap.
	@return {Function} A new function wrapping `fn`. The new function is guaranteed to be of arity 2.
	@see R.nAry, R.unary
	@example
		local takesThreeArgs = function(a, b, c)
			return {a, b, c}
		end
		takesThreeArgs(1, 2, 3) --> {1, 2, 3}
	
		local takesTwoArgs = R.binary(takesThreeArgs)
		-- Only 2 arguments are passed to the wrapped function
		takesTwoArgs(1, 2, 3) --> {1, 2}

	@symb R.binary(f)(a, b, c) = f(a, b)
]]
R.binary = _curry1(function(fn)
	return R.nAry(2, fn)
end)

--[[
	Creates a function that is bound to a context.
	
	@func
	@category Functional
	@sig (* -> *) -> {*} -> (* -> *)
	@param {Function} fn The function to bind to context
	@param {Object} thisObj The context to bind `fn` to
	@return {Function} A function that will execute in the context of `thisObj`.
	@see R.partial
	@example
		local str = "test hello world" --> length 16
		local strlen = R.bind(string.len, str)
		R.map(strlen, R.split(",", "123,4,56789")) --> {16, 16, 16}

	@symb R.bind(f, o)(a, b) = f(o, a, b)
]]
R.bind = _curry2(function(fn, thisObj)
	return function (...)
		return fn(thisObj, ...)
	end
end)

--[[
	A function which calls the two provided functions and returns the `&&`
	of the results.

	It returns the result of the first function if it is false-y and the result
	of the second function otherwise. Note that this is short-circuited,
	meaning that the second function will not be invoked if the first returns a
	false-y value.
	
	@func
	@category Functional
	@sig (*... -> Boolean) -> (*... -> Boolean) -> (*... -> Boolean)
	@param {Function} f A predicate
	@param {Function} g Another predicate
	@return {Function} a function that applies its arguments to `f` and `g` and `&&`s their outputs together.
	@see R.and
	@example
		local gt10 = R.gt(R.__, 10)
		local lt20 = R.lt(R.__, 20)
		local f = R.both(gt10, lt20)
		f(15) --> true
		f(30) --> false
]]
R.both = _curry2(function(f, g)
	return function(...)
		return f(...) and g(...)
	end
end)

--[[
	Returns the result of calling its first argument with the remaining
	arguments. This is occasionally useful as a converging function for
	[`R.converge`](#converge): the first branch can produce a function while the
	remaining branches produce values to be passed to that function as its
	arguments.
	
	@func
	@category Functional
	@sig (*... -> a),*... -> a
	@param {Function} fn The function to apply to the remaining arguments.
	@param {...*} args Any number of positional arguments.
	@return {*}
	@see R.apply
	@example	
		R.call(R.add, 1, 2) --> 3

	@symb R.call(f, a, b) = f(a, b)
]]
R.call = function(fn, ...)
	return fn(...)
end

--[[
	Returns a function, `fn`, which encapsulates `if/else, if/else, ...` logic.
	`R.cond` takes a list of predicate pairs. All of the arguments
	to `fn` are applied to each of the predicates in turn until one returns a
	"truthy" value, at which point `fn` returns the result of applying its
	arguments to the corresponding transformer. If none of the predicates
	matches, `fn` returns nil.
	
	@func
	@category Functional
	@sig [ [(*... -> Boolean),(*... -> *)] ] -> (*... -> *)
	@param {Array} pairs A list of [predicate, transformer]
	@return {Function}
	@example	
		local fn = R.cond({
			{R.equals(0),   R.always('water freezes at 0°C')},
			{R.equals(100), R.always('water boils at 100°C')},
			{R.T,           function(temp) return 'nothing special happens at ' .. temp .. '°C' end}
		})
		fn(0) --> 'water freezes at 0°C'
		fn(50) --> 'nothing special happens at 50°C'
		fn(100) --> 'water boils at 100°C'
]]
R.cond = _curry1(function(p)
	return function (...)
		for k,v in pairs(p) do
			if v[1](...) then
				return v[2](...)
			end
		end
	end
end)

--[[
	Makes a comparator function out of a function that reports whether the first
	element is less than the second.
	
	@func
	@category Functional
	@sig (a, b -> Boolean) -> (a, b -> Number)
	@param {Function} pred A predicate function of arity two which will return `true` if the first argument
	is less than the second, `false` otherwise
	@return {Function} A Function :: a -> b -> Int that returns `-1` if a < b, `1` if b < a, otherwise `0`
	@example	
		local byAge = R.comparator(function(a, b) return a.age < b.age end)
		local people = {
			-- ...
		}
		local peopleByIncreasingAge = R.sort(byAge, people)
	@see R.ascend, R.desend
]]
R.comparator = _curry1(function(pred)
	return function (a, b)
		return pred(a, b)
	end
end)

--[[
	Takes a function `f` and returns a function `g` such that if called with the same arguments
	when `f` returns a "truthy" value, `g` returns `false` and when `f` returns a "falsy" value `g` returns `true`.
		
	@func
	@category Functional
	@sig (*... -> *) -> (*... -> Boolean)
	@param {Function} f
	@return {Function}
	@see R.not
	@example	
		local isNotNil = R.complement(R.isNil)
		R.isNil(nil) --> true
		isNotNil(nil) --> false
		R.isNil(7) --> false
		isNotNil(7) --> true
]]
R.complement = _curry1(_complement)

--[[
	Performs right-to-left function composition. The rightmost function may have
	any arity the remaining functions must be unary.
	
	*Note:** The result of compose is not automatically curried.
	
	@func
	@category Functional
	@sig ((y -> z), (x -> y), ..., (o -> p), ((a, b, ..., n) -> o)) -> ((a, b, ..., n) -> z)
	@param {...Function} ...functions The functions to compose
	@return {Function}
	@see R.pipe
	@example	
		local classyGreeting = function(firstName, lastName) 
			return "The name's " + lastName + ", " + firstName + " " + lastName
		end
		local yellGreeting = R.compose(R.toUpper, classyGreeting)
		yellGreeting('James', 'Bond') --> "THE NAME'S BOND, JAMES BOND"
	
		R.compose(math.abs, R.add(1), R.multiply(2))(-4) --> 7
	
	@symb R.compose(f, g, h)(a, b) = f(g(h(a, b)))
	@not curried
]]
R.compose = function(...)
	local args = {...}
	if #args == 0 then
		error('<lamda_error> compose:: requires at least one argument')
	end
	return R.pipe(unpack(R.reverse(args)))
end

--[[
	Accepts a converging function and a list of branching functions and returns
	a new function. When invoked, this new function is applied to some
	arguments, each branching function is applied to those same arguments. The
	results of each branching function are passed as arguments to the converging
	function to produce the return value.
	
	@func
	@category Functional
	@sig (x1 -> x2 -> ... -> z) -> [(a -> b -> ... -> x1), (a -> b -> ... -> x2), ...] -> (a -> b -> ... -> z)
	@param {Function} after A function. `after` will be invoked with the return values of `fn1` and `fn2` as its arguments.
	@param {Array} functions A list of functions.
	@return {Function} A new function.
	@see R.useWith
	@example	
		local average = R.converge(R.divide, {R.sum, R.length})
		average({1, 2, 3, 4, 5, 6, 7}) --> 4
	
		local strangeConcat = R.converge(R.concat, {R.toUpper, R.toLower})
		strangeConcat("Yodel") --> "YODELyodel"
	
	@symb R.converge(f, {g, h})(a, b) = f(g(a, b), h(a, b))
]]
R.converge = _curry2(function(after, fns)
	return function (...)
		local args = {...}
		return after(unpack(R.map(function (fn)
			return fn(unpack(args))
		end, fns)))
	end
end)

--[[
	Returns a curried equivalent of the provided function, with the specified
	arity. The curried function has two unusual capabilities. First, its
	arguments needn't be provided one at a time. If `g` is `R.curryN(3, f)`, the
	following are equivalent:
	
	- `g(1)(2)(3)`
	- `g(1)(2, 3)`
	- `g(1, 2)(3)`
	- `g(1, 2, 3)`
	
	Secondly, the special placeholder value [`R.__`](#__) may be used to specify
	"gaps", allowing partial application of any combination of arguments,
	regardless of their positions. If `g` is as above and `_` is [`R.__`](#__),
	the following are equivalent:
	
	- `g(1, 2, 3)`
	- `g(_, 2, 3)(1)`
	- `g(_, _, 3)(1)(2)`
	- `g(_, _, 3)(1, 2)`
	- `g(_, 2)(1)(3)`
	- `g(_, 2)(1, 3)`
	- `g(_, 2)(_, 3)(1)`
	
	@func
	@category Functional
	@sig Number -> (* -> a) -> (* -> a)
	@param {Number} length The arity for the returned function.
	@param {Function} fn The function to curry.
	@return {Function} A new, curried function.
	@see R.curry
	@example	
		local sumArgs = function(...) return R.sum({...}) end
	
		local curriedAddFourNumbers = R.curryN(4, sumArgs)
		local f = curriedAddFourNumbers(1, 2)
		local g = f(3)
		g(4) --> 10
]]
R.curryN = _curry2(function(length, fn)
	if length == 1 then
		return _curry1(fn)
	end
	return _curryN(length, {}, fn)
end)
--[[
	@alias R.curryN
	Special for curryN
]]
R.curry1 = _curry1
--[[
	@alias R.curryN
	Special for curryN
]]
R.curry2 = _curry2
--[[
	@alias R.curryN
	Special for curryN
]]
R.curry3 = _curry3

--[[
	Makes a descending comparator function out of a function that returns a value
	that can be compared with `<` and `>`.
	
	@func
	@category Functional
	@sig Ord b => (a -> b) -> a -> a -> Number
	@param {Function} fn A function of arity one that returns a value that can be compared
	@param {*} a The first item to be compared.
	@param {*} b The second item to be compared.
	@return {Number} `-1` if fn(a) > fn(b), `1` if fn(b) > fn(a), otherwise `0`
	@see R.ascend
	@example
		local byAge = R.descend(R.prop('age'))
		local people = {
			{ name = 'Emma', age = 70 },
			{ name = 'Peter', age = 78 },
			{ name = 'Mikhail', age = 62 },
		}
		local peopleByYoungestFirst = R.sort(byAge, people) --> {{ name = 'Peter', age: 78 }, { name = 'Emma', age: 70 }, { name = 'Mikhail', age: 62 }}
]]
R.descend = _curry3(function(fn, a, b)
	local aa = fn(a)
	local bb = fn(b)
	return R.same(aa, bb) and 0 or aa > bb and -1 or 1
end)

--[[
	A function wrapping calls to the two functions in an `or` operation,
	returning the result of the first function if it is truth-y and the result
	of the second function otherwise. Note that this is short-circuited,
	meaning that the second function will not be invoked if the first returns a
	truth-y value.    
	
	@func
	@category Functional
	@sig (*... -> Boolean) -> (*... -> Boolean) -> (*... -> Boolean)
	@param {Function} f a predicate
	@param {Function} g another predicate
	@return {Function} a function that applies its arguments to `f` and `g` and `or`s their outputs together.
	@see R.or_
	@example	
		local gt10 = function(x) return x > 10 end
		local even = function(x) return x % 2 == 0 end
		local f = R.either(gt10, even)
		f(101) --> true
		f(8) --> true
]]
R.either = _curry2(function(f, g)
	return  function (...)
		return f(...) or g(...)
	end
end)

--[[
	Returns a new function much like the supplied one, except that the first two
	arguments' order is reversed.
	
	@func
	@category Functional
	@sig (a -> b -> c -> ... -> z) -> (b -> a -> c -> ... -> z)
	@param {Function} fn The function to invoke with its first two parameters reversed.
	@return {*} The result of invoking `fn` with its first two parameters' order reversed.
	@example
		local mergeThree = function(a, b, c) return a .. b .. c end	
		mergeThree('1','2','3') --> "123"	
		R.flip(mergeThree)('1','2','3') --> "213"
	@symb R.flip(f)(a, b, ...) = f(b, a, ...)
]]
R.flip = _curry1(function(fn)
	return _curry2(function (a, b, ...)		
		return fn(b, a, ...)
	end)
end)

--[[
	A function that does nothing but return the parameter supplied to it. Good
	as a default or placeholder function.
	
	@func
	@category Functional
	@sig a -> a
	@param {*} x The value to return.
	@return {*} The input value, `x`.
	@example
		R.identity(1) --> 1	
		local obj = {}
		R.identity(obj) == obj --> true
	@symb R.identity(a) = a
]]
R.identity = _curry1(_identity)

--[[
	Creates a function that will process either the `onTrue` or the `onFalse`
	function depending upon the result of the `condition` predicate.
	
	@func
	@category Functional
	@sig (*... -> Boolean) -> (*... -> *) -> (*... -> *) -> (*... -> *)
	@param {Function} condition A predicate function
	@param {Function} onTrue A function to invoke when the `condition` evaluates to a truthy value.
	@param {Function} onFalse A function to invoke when the `condition` evaluates to a falsy value.
	@return {Function} A new unary function that will process either the `onTrue` or the `onFalse` function depending upon the result of the `condition` predicate.
	@see R.unless, R.when
	@example	
		local incCount = R.ifElse(
			R.has('count'),
			R.assoc('count', 'null'),
			R.assoc('count', 1)
		)
		print(R.toString(incCount({})))            --> { count: 1 }
		print(R.toString(incCount({ count = 1 }))) --> { count = 'null' }
]]
R.ifElse = _curry3(function(condition, onTrue, onFalse)
	return function (...)
		local args = {...}
		local toCall = R.clone(args)
		return condition(unpack(args)) and onTrue(unpack(toCall)) or onFalse(unpack(toCall))
	end
end)

--[[
	juxt applies a list of functions to a list of values.
	
	@func
	@category Functional
	@sig [(a, b, ..., m) -> n] -> ((a, b, ..., m) -> [n])
	@param {Array} fns An array of functions
	@return {Function} A function that returns a list of values after applying each of the original `fns` to its parameters.
	@see R.applySpec
	@example     
		local getRange = R.juxt({math.min, math.max})
		getRange(3, 4, 9, -3) --> {-3, 9}

	@symb R.juxt([f, g, h])(a, b) = [f(a, b), g(a, b), h(a, b)]
]]
R.juxt = _curry1(function(fns)
	return R.converge(function (...)
		return {...}
	end, fns)
end)

--[[
	Takes a function and
	a [functor](https:--github.com/fantasyland/fantasy-land#functor),
	applies the function to each of the functor's values, and returns
	a functor of the same shape.
	
	Lamda provides suitable `map` implementations for `Array` and `Object`,
	so this function may be applied to `[1, 2, 3]` or `{x: 1, y: 2, z: 3}`.
	
	Also treats functions as functors and will compose them together.
	
	@func
	@category Functional
	@sig Functor f => (a -> b) -> f a -> f b
	@param {Function} fn The function to be called on every element of the input `list`.
	@param {Array} list The list to be iterated over.
	@return {Array} The new list.
	@example	
		local double = x => x * 2	
		R.map(double, [1, 2, 3]) --> [2, 4, 6]	
		R.map(double, {x: 1, y: 2, z: 3}) --> [2, 4, 6]

	@symb R.map(f, [a, b]) = [f(a), f(b)]
	@symb R.map(f, { x: a, y: b }) = { f(a, x), f(b, x) }
]]
R.map = _curry2(function(fn, list)
	local result = {}
	if _isArray(list) then		
		for k,v in ipairs(list) do
			result[k] = fn(v, k)			
		end		
	elseif _isObject(list) then
		for k,v in pairs(list) do
			result[#result + 1] = fn(v, k)
		end	
	end
	return result
end)

--[[
	The `mapAccum` function behaves like a combination of map and reduce it
	applies a function to each element of a list, passing an accumulating
	parameter from left to right, and returning a final value of this
	accumulator together with the new list.
	
	The iterator function receives two arguments, *acc* and *value*, and should
	return a tuple *[acc, value]*.
	
	@func
	@category Functional
	@sig (acc -> x -> (acc, y)) -> acc -> [x] -> (acc, [y])
	@param {Function} fn The function to be called on every element of the input `list`.
	@param {*} acc The accumulator value.
	@param {Array} list The list to iterate over.
	@return {*} The final, accumulated value.
	@see R.mapAccumRight
	@example	
		local digits = {'1', '2', '3', '4'}
		local appender = R.juxt({R.concat, R.concat})
		R.mapAccum(appender, 0, digits) --> {'01234', {'01', '012', '0123', '01234'} }

	@symb R.mapAccum(f, a, [b, c, d]) = [
		f(f(f(a, b)[1], c)[1], d)[1],
		[
			f(a, b)[1],
			f(f(a, b)[1], c)[1],
			f(f(f(a, b)[1], c)[1], d)[1]
		]
	]
]]
R.mapAccum = _curry3(function(fn, acc, list)
	local idx = 1
	local len = #list
	local result = {}
	local tuple = {acc}
	while idx <= len do
		tuple = fn(tuple[1], list[idx])
		result[idx] = tuple[2]
		idx = idx + 1
	end
	return {
		tuple[1],
		result
	}
end)

--[[
	The `mapAccumRight` function behaves like a combination of map and reduce it
	applies a function to each element of a list, passing an accumulating
	parameter from right to left, and returning a final value of this
	accumulator together with the new list.
	
	Similar to [`mapAccum`](#mapAccum), except moves through the input list from
	the right to the left.
	
	The iterator function receives two arguments, *value* and *acc*, and should
	return a tuple *[value, acc]*.
	
	@func
	@category Functional
	@sig (x-> acc -> (y, acc)) -> acc -> [x] -> ([y], acc)
	@param {Function} fn The function to be called on every element of the input `list`.
	@param {*} acc The accumulator value.
	@param {Array} list The list to iterate over.
	@return {*} The final, accumulated value.
	@see R.mapAccum
	@example
		local digits = {'1', '2', '3', '4'}
		local appender = R.juxt({R.concat, R.concat})
		R.mapAccumRight(append, 5, digits) --> {{'12345', '2345', '345', '45'}, '12345'}
		
	@symb R.mapAccumRight(f, a, [b, c, d]) = [
		[
			f(b, f(c, f(d, a)[0])[0])[1],
			f(c, f(d, a)[0])[1],
			f(d, a)[1],
		]
		f(b, f(c, f(d, a)[0])[0])[0],
	]
]]
R.mapAccumRight = _curry3(function(fn, acc, list)
	local idx = #list
	local result = {}
	local tuple = {acc}
	while idx > 0 do
		tuple = fn(list[idx], tuple[1])
		result[idx] = tuple[2]
		idx = idx -1
	end
	return {
		result,
		tuple[1]
	}
end)

--[[
	A customisable version of [`R.memoize`](#memoize). `memoizeWith` takes an
	additional function that will be applied to a given argument set and used to
	create the cache key under which the results of the function to be memoized
	will be stored. Care must be taken when implementing key generation to avoid
	clashes that may overwrite previous entries erroneously.
	
	@func
	@category Functional
	@sig (*... -> String) -> (*... -> a) -> (*... -> a)
	@param {Function} fn The function to generate the cache key.
	@param {Function} fn The function to memoize.
	@return {Function} Memoized version of `fn`.
	@see R.memoize
	@example	
		local count = 0
		local factorial = R.memoizeWith(R.identity, function(n)
			count = count + 1
			return R.product(R.range(1, n + 1))
		end)
		factorial(5) --> 120
		factorial(5) --> 120
		factorial(5) --> 120
		count --> 1
]]
R.memoizeWith = _curry2(function(mFn, fn)
	local cache = {}
	return function (...)
		local key = mFn(...)
		if not _has(key, cache) then
			cache[key] = fn(...)
		end
		return cache[key]
	end
end)

--[[
	Creates a new function that, when invoked, caches the result of calling `fn`
	for a given argument set and returns the result. Subsequent calls to the
	memoized `fn` with the same argument set will not result in an additional
	call to `fn` instead, the cached result for that set of arguments will be
	returned.
	
	@func
	@category Functional
	@sig (*... -> a) -> (*... -> a)
	@param {Function} fn The function to memoize.
	@return {Function} Memoized version of `fn`.
	@see R.memoizeWith
	@example	
		local count = 0
		local factorial = R.memoize(function(n)
			count = count + 1
			return R.product(R.range(1, n + 1))
		end)
		factorial(5) --> 120
		factorial(5) --> 120
		factorial(5) --> 120
		count --> 1
]]
R.memoize = R.memoizeWith(function (...)
	return R.toString(...)
end)

--[[
	Takes a value, returns an array of this value and the result of this 
	value being passed into the given function call.
	
	@func
	@since 0.2.0
	@category Functional
	@sig (a -> * ) -> a -> [a, *]
	@param {*} v any value.
	@return {Array} the result array with v and it's clone.
	@example	
		R.mirrorBy(R.id, 1) --> {1,1}
		R.mirrorBy(R.size, {1,2,3}) --> {{1,2,3}, 3}
]]
R.mirrorBy = _curry2(function(fn, v)
	return {v, fn(v)}
end)

--[[
	Takes a value, return an array with the value and it's clone value
	
	@func
	@since 0.2.0
	@category Functional
	@sig a -> [a]
	@param {*} v any value.
	@return {Array} the result array with v and it's clone.
	@example	
		R.mirror(1) --> {1,1}
		R.mirror({}) --> {{},{}}
]]
R.mirror = R.mirrorBy(_clone)

--[[
	Wraps a function of any arity (including nullary) in a function that accepts
	exactly `n` parameters. Any extraneous parameters will not be passed to the
	supplied function.
	Max n is ten (error if greater than 10)
	
	@func
	@category Functional
	@sig Number -> (* -> a) -> (* -> a)
	@param {Number} n The desired arity of the new function.
	@param {Function} fn The function to wrap.
	@return {Function} A new function wrapping `fn`. The new function is guaranteed to be of arity `n`.
	@see R.binary, R.unary
	@example
		local takesTwoArgs = function (a, b, c, d)
			return {a, b, c, d}
		end	
		takesTwoArgs(1, 2, 3, 4) --> {1, 2, 3, 4}
	
		local takesOneArg = R.nAry(3, takesTwoArgs)	
		-- Only `n` arguments are passed to the wrapped function
		takesOneArg(1, 2, 3, 4) --> {1, 2, 3}

	@symb R.nAry(0, f)(a, b) = f()
	@symb R.nAry(1, f)(a, b) = f(a)
	@symb R.nAry(2, f)(a, b) = f(a, b)
]]
R.nAry = _curry2(function(n, fn)
	if n == 0 then
		return function ()
			return fn()
		end
	elseif n == 1 then
		return function (a0)
			return fn(a0)
		end
	elseif n == 2 then
		return function (a0, a1)
			return fn(a0, a1)
		end
	elseif n == 3 then
		return function (a0, a1, a2)
			return fn(a0, a1, a2)
		end
	elseif n == 4 then
		return function (a0, a1, a2, a3)
			return fn(a0, a1, a2, a3)
		end
	elseif n == 5 then
		return function (a0, a1, a2, a3, a4)
			return fn(a0, a1, a2, a3, a4)
		end
	elseif n == 6 then
		return function (a0, a1, a2, a3, a4, a5)
			return fn(a0, a1, a2, a3, a4, a5)
		end
	elseif n == 7 then
		return function (a0, a1, a2, a3, a4, a5, a6)
			return fn(a0, a1, a2, a3, a4, a5, a6)
		end
	elseif n == 8 then
		return function (a0, a1, a2, a3, a4, a5, a6, a7)
			return fn(a0, a1, a2, a3, a4, a5, a6, a7)
		end
	elseif n == 9 then
		return function (a0, a1, a2, a3, a4, a5, a6, a7, a8)
			return fn(a0, a1, a2, a3, a4, a5, a6, a7, a8)
		end
	elseif n == 10 then
		return function (a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			return fn(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
		end
	else
		error('<lamda_error> nAry:: First argument to nAry must be a non-negative integer no greater than ten')
	end
end)

--[[
	A function that returns the `not` of its argument. It will return `true` when
	passed false-y value, and `false` when passed a truth-y one.
	
	@func
	@category Functional
	@sig * -> Boolean
	@param {*} a any value
	@return {Boolean} the logical inverse of passed argument.
	@see R.complement
	@example	
		R.not(true) --> false
		R.not(false) --> true
		R.not(0) --> false
		R.not(1) --> false
]]
R.not_ = _curry1(function(a)
	return not a
end)

--[[
	`o` is a curried composition function that returns a unary function.
	Like [`compose`](#compose), `o` performs right-to-left function composition.
	Unlike [`compose`](#compose), the rightmost function passed to `o` will be
	invoked with only one argument.
	
	@func
	@category Functional
	@sig (b -> c) -> (a -> b) -> a -> c
	@param {Function} f
	@param {Function} g
	@return {Function}
	@see R.compose, R.pipe
	@example
		local classyGreeting = function(name)
			return "The name's " + name.last + ", " + name.first + " " + lastName
		end
		local yellGreeting = R.o(R.toUpper, classyGreeting)
		yellGreeting({first = 'James', last = 'Bond'}) --> "THE NAME'S BOND, JAMES BOND"
	
		R.o(R.multiply(10), R.add(10))(-4) --> 60
	
	@symb R.o(f, g, x) = f(g(x))
]]
R.o = _curry3(function (f, g, x)
	return f(g(x))
end)

--[[
	Returns `true` if one or both of its arguments are `true`. Returns `false`
	if both arguments are `false`.
	
	@func
	@category Functional
	@sig a -> b -> a | b
	@param {Any} a
	@param {Any} b
	@return {Any} the first argument if truthy, otherwise the second argument.
	@see R.either
	@example     
		R.or(true, true) --> true
		R.or(true, false) --> true
		R.or(false, true) --> true
		R.or(false, false) --> false
]]
R.or_ = _curry2(function(a, b)
	return a or b
end)

--[[
	Returns a singleton array containing the value provided.
	
	@func
	@category Functional
	@sig a -> [a]
	@param {*} x any value
	@return {Array} An array wrapping `x`.
	@example	
		R.of(42) --> {42}
		R.of({42}) --> {{42}}
]]
R.of = _curry1(_of)

--[[
	Accepts a function `fn` and returns a function that guards invocation of
	`fn` such that `fn` can only ever be called once, no matter how many times
	the returned function is invoked. The first value calculated is returned in
	subsequent invocations.
	
	@func
	@category Functional
	@sig (a... -> b) -> (a... -> b)
	@param {Function} fn The function to wrap in a call-only-once wrapper.
	@return {Function} The wrapped function.
	@example	
		local addOneOnce = R.once(R.add(1))
		addOneOnce(10) --> 11
		addOneOnce(addOneOnce(50)) --> 11
]]
R.once = _curry1(function(fn)
	local called = false
	local result
	return function (...)
		if called then
			return result
		end
		called = true
		result = fn(...)
		return result
	end
end)

--[[
	Takes a function `f` and the left arguments and returns a function `g`.
	When applied, `g` returns the result of applying `f` to the arguments
	provided initially followed by the arguments provided to `g`.
	
	@func
	@category Functional
	@sig ((a, b, c, ..., n) -> x) -> a, b, c -> ((d, e, f, ..., n) -> x)
	@param {Function} f
	@param {*} args
	@return {Function}
	@see R.partialRight
	@example	
		local double = R.partial(R.multiply, 2)
		double(2) --> 4
	
		local greet = function (salutation, title, firstName, lastName) 
			return salutation .. ', ' .. title .. ' ' .. firstName .. ' ' .. lastName .. '!'
		end
	
		local sayHello = R.partial(greet, 'Hello')
		local sayHelloToMs = R.partial(sayHello, 'Ms.')
		sayHelloToMs('Jane', 'Jones') --> 'Hello, Ms. Jane Jones!'

	@symb R.partial(f, [a, b])(c, d) = f(a, b, c, d)
]]
R.partial = function(func, ...)
	local args = {...}
  	return function(...)
    	return func(unpack(_concat(args, {...})))
  	end
end

--[[
	Takes a function `f` and the left arguments, and returns a function `g`.
	When applied, `g` returns the result of applying `f` to the arguments
	provided to `g` followed by the arguments provided initially.
	
	@func
	@category Functional
	@sig ((a, b, c, ..., n) -> x) -> d, e, f, ..., n -> ((a, b, c, ...) -> x)
	@param {Function} f
	@param {Array} args
	@return {Function}
	@see R.partial
	@example	
		local greet = function (salutation, title, firstName, lastName) 
			return salutation .. ', ' .. title .. ' ' .. firstName .. ' ' .. lastName .. '!'
		end
		local greetMsJaneJones = R.partialRight(greet, 'Ms.', 'Jane', 'Jones')	
		greetMsJaneJones('Hello') --> 'Hello, Ms. Jane Jones!'

	@symb R.partialRight(f, [a, b])(c, d) = f(c, d, a, b)
]]
R.partialRight = function(func, ...)
	local args = {...}
  	return function(...)
    	return func(unpack(_concat({...}, args)))
  	end
end

--[[
	Performs left-to-right function composition. The leftmost function may have
	any arity the remaining functions must be unary.
	
	In some libraries this function is named `sequence`.	
	*Note:** The result of pipe is not automatically curried.
	
	@func
	@category Functional
	@sig (((a, b, ..., n) -> o), (o -> p), ..., (x -> y), (y -> z)) -> ((a, b, ..., n) -> z)
	@param {...Function} functions
	@return {Function}
	@see R.compose
	@example	
		local f = R.pipe(Math.pow, R.negate, R.inc)	
		f(3, 4) --> -(3^4) + 1

	@symb R.pipe(f, g, h)(a, b) = h(g(f(a, b)))
	@not curried
]]
R.pipe = function(...)
	local args = {...}
	if #args == 0 then
		error('<lamda_error> pipe:: requires at least one argument')
	end
	return R.reduce(_pipe, args[1], R.tail(args))
end

--[[
	Runs the given function with the supplied object, then returns the object.
	
	@func
	@category Functional
	@sig (a -> *) -> a -> a
	@param {Function} fn The function to call with `x`. The return value of `fn` will be thrown away.
	@param {*} x
	@return {*} `x`.
	@example	
		R.tap(R.partial(R.show, "x is "), 100) --> 100
		-->> "x is "100

	@symb R.tap(f, a) = a
]]
R.tap = _curry2(function(fn, x)
	fn(x)
	return x
end)

--[[
/**
	`tryCatch` takes three functions, a `tryer`, a `catcher` and a finaller . The returned
	function evaluates the `tryer`; if it does not throw, it simply returns the
	result. If the `tryer` *does* throw, the returned function evaluates the
	`catcher` function and returns its result. 
	If the finaller is not nil, then the function always return the finaller's results.
	
	@func
	@category Functional
	@sig (...x -> a) [-> ((e, ...x) -> a) -> (...x -> a)] -> (...x -> a)
	@param {Function} tryer The function that may throw.
	@param {Function} catcher The function that will be evaluated if `tryer` throws.
	@return {Function} A new function that will catch exceptions and send then to the catcher.
	@example
		R.tryCatch(R.prop('x'), R.F)({x = true}) 	--> true
		R.tryCatch(R.prop('x'), R.F)(1)      		--> false
	@not curried
]]
R.tryCatch = function(tryer, catcher, finaller)
	return function(...)
		local error
		local args = {...}
		local success, result = xpcall(function()
			return tryer(unpack(args))
		end, function(err)
			error = err
		end)		
		if not success then
			if catcher then
				result = catcher(error, unpack(args))
			else 
				print("Exception Got -> ", error)
			end
		end
		if finaller then
			result = finaller(unpack(args))
		end
		return result
	end
end

--[[
	Takes a function `fn`, which takes a single array argument, and returns a
	function which:	
		- takes any number of positional arguments
		- passes these arguments to `fn` as an array and
		- returns the result.
	
	In other words, `R.unapply` derives a variadic function from a function which
	takes an array. `R.unapply` is the inverse of [`R.apply`](#apply).
	
	@func
	@category Functional
	@sig ([*...] -> a) -> (*... -> a)
	@param {Function} fn
	@return {Function}
	@see R.apply
	@example
		R.unapply(R.sum)(1, 2, 3) --> 6

	@symb R.unapply(f)(a, b) = f([a, b])
]]
R.unapply = _curry1(function(fn)
	return function (...)
		return fn({...})
	end
end)

--[[
	Wraps a function of any arity (including nullary) in a function that accepts
	exactly 1 parameter. Any extraneous parameters will not be passed to the
	supplied function.
	
	@func
	@category Functional
	@sig (* -> b) -> (a -> b)
	@param {Function} fn The function to wrap.
	@return {Function} A new function wrapping `fn`. The new function is guaranteed to be of arity 1.
	@see R.binary, R.nAry
	@example	
		local takesTwoArgs = function(a, b) {
			return {a, b}
		}
		takesTwoArgs(1, 2) --> {1, 2}
	
		local takesOneArg = R.unary(takesTwoArgs)
		-- Only 1 argument is passed to the wrapped function
		takesOneArg(1, 2) --> {1}
	@symb R.unary(f)(a, b, c) = f(a)
]]
R.unary = _curry1(function(fn)
	return R.nAry(1, fn)
end)

--[[
	Tests the final argument by passing it to the given predicate function. If
	the predicate is not satisfied, the function will return the result of
	calling the `whenFalseFn` function with the same argument. If the predicate
	is satisfied, the argument is returned as is.
	
	@func
	@category Functional
	@sig (a -> Boolean) -> (a -> a) -> a -> a
	@param {Function} pred        A predicate function
	@param {Function} whenFalseFn A function to invoke when the `pred` evaluates to a falsy value.
	@param {*} x An object to test with the `pred` function and pass to `whenFalseFn` if necessary.
	@return {*} Either `x` or the result of applying `x` to `whenFalseFn`.
	@see R.ifElse, R.when
	@example	
		local safeInc = R.unless(R.isString, R.inc)
		safeInc('a') -->'a'
		safeInc(1) --> 2
end
]]
R.unless = _curry3(function(pred, whenFalseFn, x)
	return pred(x) and x or whenFalseFn(x)
end)

--[[
	Takes a predicate, a transformation function, and an initial value,
	and returns a value of the same type as the initial value.
	It does so by applying the transformation until the predicate is satisfied,
	at which point it returns the satisfactory value.
	
	@func
	@category Functional
	@sig (a -> Boolean) -> (a -> a) -> a -> a
	@param {Function} pred A predicate function
	@param {Function} fn The iterator function
	@param {*} init Initial value
	@return {*} Final value that satisfies predicate
	@example	
		R.until_(R.gt(R.__, 100), R.multiply(2))(1) --> 128
]]
R.until_ = _curry3(function(pred, fn, init)
	local val = init
	while not pred(val) do
		val = fn(val)
	end
	return val
end)

--[[
	Accepts a function `fn` and a list of transformer functions and returns a
	new curried function. When the new function is invoked, it calls the
	function `fn` with parameters consisting of the result of calling each
	supplied handler on successive arguments to the new function.
	
	If more arguments are passed to the returned function than transformer
	functions, those arguments are passed directly to `fn` as additional
	parameters. If you expect additional arguments that don't need to be
	transformed, although you can ignore them, it's best to pass an identity
	function so that the new function reports the correct arity.
	
	@func
	@category Functional
	@sig (x1 -> x2 -> ... -> z) -> [(a -> x1), (b -> x2), ...] -> (a -> b -> ... -> z)
	@param {Function} fn The function to wrap.
	@param {Array} transformers A list of transformer functions
	@return {Function} The wrapped function.
	@see R.converge
	@example	
		R.useWith(math.pow, {R.identity, R.identity})(3, 4) --> 81
		R.useWith(math.pow, {R.identity, R.identity})(3)(4) --> 81
		R.useWith(math.pow, {R.dec, R.inc})(3, 4) --> 32
		R.useWith(math.pow, {R.dec, R.inc})(3)(4) --> 32

	@symb R.useWith(f, [g, h])(a, b, c) = f(g(a), h(b), c)
]]
R.useWith = _curry2(function(fn, transformers)
	return R.curryN(#transformers, function (...)
		local params = {...}
		local args = {}
		local idx = 1
		while idx <= #transformers do
			args[#args + 1] = transformers[idx](params[idx])
			idx = idx + 1
		end
		while idx <= #params do
			args[#args + 1] = params[idx]
			idx = idx + 1
		end
		return fn(unpack(args))
	end)
end)

--[[
	Tests the final argument by passing it to the given predicate function. If
	the predicate is satisfied, the function will return the result of calling
	the `whenTrueFn` function with the same argument. If the predicate is not
	satisfied, the argument is returned as is.
	
	@func
	@category Functional
	@sig (a -> Boolean) -> (a -> a) -> a -> a
	@param {Function} pred       A predicate function
	@param {Function} whenTrueFn A function to invoke when the `condition` evaluates to a truthy value.
	@param {*}  x An object to test with the `pred` function and pass to `whenTrueFn` if necessary.
	@return {*} Either `x` or the result of applying `x` to `whenTrueFn`.
	@see R.ifElse, R.unless
	@example	
		-- truncate :: String -> String
		local truncate = R.when(
		R.compose(R.gt(R.__, 10), R.size),
		R.pipe(R.take(10), R.append('...'))
	)
	this.lu.assertEquals(truncate('12345'), '12345') --> '12345'
	this.lu.assertEquals(truncate('0123456789ABC'), '0123456789...') --> '0123456789…'
]]
R.when = _curry3(function(pred, whenTrueFn, x)
	return pred(x) and whenTrueFn(x) or x
end)

-- ================================================
-- ================ Math Functions ================
-- ================================================
--[[
	Get the absolute value.
	
	@func
	@since v0.2.0
	@category Math
	@sig number -> number
	@param {number} a
	@return {number}
	@example
		R.abs(-5)       --> 5
]]
R.abs = _curry1(function (a)
	if _isNumber(a) then return math.abs(a) end
	error("<lamda_error> abs:: can not invoke abs method on non-number value.")
end)

--[[
	Adds two values.
	
	@func
	@category Math
	@sig number -> number -> number
	@param {number} a
	@param {number} b
	@return {number}
	@see R.subtract
	@example
		R.add(2, 3)       --> 5
		R.add(7)(10)      --> 17
]]
R.add = _curry2(function (a, b)
	return a + b
end)
--[[
	@alias R.add
]]
R.plus = R.add

--[[
	Subtracts its second argument from its first argument.
	
	@func
	@category Math
	@sig Number -> Number -> Number
	@param {Number} a The first value.
	@param {Number} b The second value.
	@return {Number} The result of `a - b`.
	@see R.add
	@example
		R.subtract(10, 8) --> 2
	
		local minus5 = R.subtract(R.__, 5)
		minus5(17) --> 12
	
		local complementaryAngle = R.subtract(90)
		complementaryAngle(30) --> 60
		complementaryAngle(72) --> 18
]]
R.subtract = _curry2(function(a, b)
	return a - b
end)
--[[
	@alias R.subtract
]]
R.minus = R.subtract

--[[
	Restricts a number to be within a range.	
	Also works for other ordered types such as strings
	
	@func
	@category Math
	@sig Ord a => a -> a -> a -> a
	@param {Number} minimum The lower limit of the clamp (inclusive)
	@param {Number} maximum The upper limit of the clamp (inclusive)
	@param {Number} value Value to be clamped
	@return {Number} Returns `minimum` when `val < minimum`, `maximum` when `val > maximum`, returns `val` otherwise
	@example	
		R.clamp(1, 10, -5) --> 1
		R.clamp(1, 10, 15) --> 10
		R.clamp(1, 10, 4)  --> 4
]]
R.clamp = _curry3(function(min, max, value)
	if min > max then
		min, max = max, min
	end
	return value < min and min or (value > max and max or value)
end)

--[[
	Decrements its argument.
	
	@func
	@category Math
	@sig Number -> Number
	@param {Number} n
	@return {Number} n - 1
	@see R.inc
	@example	
		R.dec(42) --> 41
]]
R.dec = R.add(-1)

--[[
	Divides two numbers. Equivalent to `a / b`.
	
	@func
	@category Math
	@sig Number -> Number -> Number
	@param {Number} a The first value.
	@param {Number} b The second value.
	@return {Number} The result of `a / b`.
	@see R.multiply
	@example
		R.divide(71, 100) --> 0.71
	
		local half = R.divide(R.__, 2)
		half(42) --> 21
	
		local reciprocal = R.divide(1)
		reciprocal(4)   --> 0.25
]]
R.divide = _curry2(function(a, b)
	if b == 0 then
		error('<lamda_error> divide:: divide by zero')
	end
	return a / b
end)

--[[
	Increments its argument.
	
	@func
	@category Math
	@sig Number -> Number
	@param {Number} n
	@return {Number} n + 1
	@see R.dec
	@example
		R.inc(42) --> 43
]]
R.inc = R.add(1)

--[[
	Returns the mean of the given list of numbers.
	
	@func
	@category Math
	@sig [Number] -> Number
	@param {Array} list
	@return {Number}
	@see R.median
	@example	
		R.mean({2, 7, 9}) --> 6
		R.mean({}) --> nan
]]
R.mean = _curry1(function(list)
	return R.sum(list) / #list
end)

--[[
	Returns the median of the given list of numbers.
	
	@func
	@category Math
	@sig [Number] -> Number
	@param {Array} list
	@return {Number}
	@see R.mean
	@example	
		R.median({2, 9, 7}) --> 7
		R.median({7, 2, 10, 9}) --> 8
		R.median({}) --> nan
]]
R.median = _curry1(function(list)
	local len = #list
	if len == 0 then
		return 0/0
	end
	local width = 2 - len % 2
	local idx = (len - width) / 2 + 1
	return R.mean(R.slice(idx, idx + width, R.sort(R.lt, list)))
end)

--[[
	Divides the first parameter by the second and returns the remainder. 
	
	@func
	@category Math
	@sig Number -> Number -> Number
	@param {Number} a The value to the divide.
	@param {Number} b The pseudo-modulus
	@return {Number} The result of `b % a`.
	@example	
		R.mod(17, 3) --> 2

		local isOdd = R.mod(R.__, 2)
		isOdd(42) --> 0
		isOdd(21) --> 1
]]
R.mod = _curry2(function(a, b)
	return a % b
end)

--[[
	Multiplies two numbers. Equivalent to `a * b` but curried.
	
	@func
	@category Math
	@sig Number -> Number -> Number
	@param {Number} a The first value.
	@param {Number} b The second value.
	@return {Number} The result of `a * b`.
	@see R.divide
	@example
		local double = R.multiply(2)
		local triple = R.multiply(3)
		double(3)       -->  6
		triple(4)       --> 12
		R.multiply(2, 5)  --> 10
]]
R.multiply = _curry2(function(a, b)
	return a * b
end)

--[[
	Negates its argument.
	
	@func
	@category Math
	@sig Number -> Number
	@param {Number} n
	@return {Number}
	@example     
		R.negate(42) --> -42
]]
R.negate = _curry1(function(n)
	return -n
end)

--[[
	Multiplies together all the elements of a list.
	
	@func
	@category Math
	@sig [Number] -> Number
	@param {Array} list An array of numbers
	@return {Number} The product of all the numbers in the list.
	@see R.reduce
	@example     
		R.product({2,4,6,8,100,1}) --> 38400
		R.product({}) --> 1
]]
R.product = _curry3(_reduce)(R.multiply, 1)



-- ================================================
-- ================ Array Functions ===============
-- ================================================
--[[
	Applies a function to the value at the given index of an array, returning a
	new copy of the array with the element at the given index replaced with the
	result of the function application.
	
	@func
	@category Array
	@sig (a -> a) -> Number -> [a] -> [a]
	@param {Function} fn The function to apply.
	@param {Number} idx The index.
	@param {Array} list The array table to be modified.
	@return {Array} A copy of the array with
			the element at index `idx` replaced with the value
			returned by applying `fn` to the existing element.
	@see R.update
	@example
		R.adjust(R.add(10), 2, {1, 2, 3})     --> {1, 12, 3}
		R.adjust(R.add(10))(2)({1, 2, 3})     --> {1, 12, 3}
	
	@symb R.adjust(f, -1, {a, b}) = {a, f(b)}
	@symb R.adjust(f, 0, {a, b}) = {a, b}
	@symb R.adjust(f, 1, {a, b}) = {f(a), b}
]]
R.adjust = _curry3(function (fn, idx, list)
	if (idx == 0 or idx > #list or idx < -#list) then
		return list
	end
	local start = idx < 0 and #list + 1 or 0
	local _idx = start + idx
	local _list = _concat(list)
	_list[_idx] = fn(list[_idx])
	return _list
end)

--[[
	Returns `true` if all elements of the list match the predicate, `false` if
	there are any that don't.
	
	Dispatches to the `all` method of the second argument, if present.
		
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> Boolean
	@param {Function} fn The predicate function.
	@param {Array} list The array to consider.
	@return {Boolean} `true` if the predicate is satisfied by every element, `false` otherwise.
	@see R.any, R.none
	@example
		local equals3 = R.equals(3)
		R.all(equals3, {3, 3, 3, 3}) --> true
		R.all(equals3)({3, 3, 1, 3}) --> false
]]
R.all = _curry2(function(fn, list)
	local idx = 1
	while idx <= #list do
		if not fn(list[idx]) then
			return false
		end
		idx = idx + 1
	end
	return true
end)

--[[
	Returns `true` if at least one of elements of the list match the predicate,
	`false` otherwise.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> Boolean
	@param {Function} fn The predicate function.
	@param {Array} list The array to consider.
	@return {Boolean} `true` if the predicate is satisfied by at least one element, `false` otherwise.
	@see R.all, R.none
	@example
		local lessThan0 = R.lt(R.__, 0)
		local lessThan2 = R.lt(R.__, 2)
		R.any(lessThan0, {1, 2}) --> false
		R.any(lessThan2)({1, 2}) --> true
]]
R.any = _curry2(function(fn, list)
	local idx = 1
	while idx <= #list do
		if fn(list[idx]) then
			return true
		end
		idx = idx + 1
	end
	return false
end)

--[[
	Returns a new list, composed of n-tuples of consecutive elements. If `n` is
	greater than the length of the list, an empty list is returned.	
	
	@func
	@category Array
	@sig Number -> [a] -> [ [a] ]
	@param {Number} n The size of the tuples to create
	@param {Array} list The list to split into `n`-length tuples
	@return {Array} The resulting list of `n`-length tuples	
	@example
		R.aperture(2, {1, 2, 3, 4, 5}) --> {{1, 2}, {2, 3}, {3, 4}, {4, 5}}
		R.aperture(3, {1, 2, 3, 4, 5}) --> {{1, 2, 3}, {2, 3, 4}, {3, 4, 5}}
		R.aperture(7, {1, 2, 3, 4, 5}) --> {}
		R.aperture(0, {1, 2, 3, 4, 5}) --> {{}, {}, {}, {}, {}, {}}
]]
R.aperture = _curry2(function(n, list)
	local idx = 1
	local limit = #list - n + 1
	local acc = {}
	if n < 0 then return {} end
	while idx <= limit do
		acc[idx] = R.slice(idx, idx + n, list)
		idx = idx + 1
	end
	return acc
end)

--[[
	Returns a new list containing the contents of the given list, followed by
	the given element.
	
	@func
	@category Array
	@sig a -> [a] -> [a]
	@param {*} el The element to add to the end of the new list.
	@param {Array} list The list of elements to add a new item to list.
	@return {Array} A new list containing the elements of the old list followed by `el`.
	@see R.prepend
	@example
		R.append('tests', {'write', 'more'}) --> {'write', 'more', 'tests'}
		R.append('tests', {}) --> {'tests'}
		R.append({'tests'}, {'write', 'more'}) --> {'write', 'more', {'tests'}}
]]
R.append = _curry2(function(el, list)
	if _isString(list) then return list .. el end
	return _concat(list, {el})
end)
--[[
	@alias R.append
]]
R.push = R.append

--[[
	`chain` maps a function over a list and concatenates the results. `chain`
	is also known as `flatMap` in some libraries.
	If second param is function, chain(f, g)(x) equals f(g(x), x).
		
	@func
	@category Array
	@sig Chain m => (a -> m b) -> m a -> m b
	@param {Function} fn The function to map with
	@param {Array} list The list to map over
	@return {Array} The result of flat-mapping `list` with `fn`
	@example	
		local duplicate = function(n) return {n, n} end
		R.chain(duplicate, {1, 2, 3}) --> {1, 1, 2, 2, 3, 3}     
		R.chain(R.append, R.head)({1, 2, 3}) --> {1, 2, 3, 1}
	@symb Func g => R.chain(f, g)(x) = f(g(x), x)
]]
R.chain = _curry2(function(fn, monad)
	if _isFunction(monad) then
		return function (x)
			return fn(monad(x))(x)
		end
	end
	return _makeFlat(false)(R.map(fn, monad))
end)

--[[
	Returns the result of concatenating the given lists or strings.     
	Note: `R.concat` expects both arguments to be of the same type as array or string
	
	@func
	@category Array
	@sig [a] -> [a] -> [a]
	@sig String -> String -> String
	@param {Array|String} firstList The first list
	@param {Array|String} secondList The second list
	@return {Array|String} A list consisting of the elements of `firstList` followed by the elements of `secondList`.
	@example	
		R.concat('ABC', 'DEF') --> 'ABCDEF'
		R.concat([4, 5, 6], [1, 2, 3]) --> [4, 5, 6, 1, 2, 3]
		R.concat([], []) --> []
]]
R.concat = _curry2(function(a, b)
	if _isArray(a) then
		if _isArray(b) then
			return _concat(a, b)
		else
			error("<lamda_error> concat:: ".. R.toString(b) .. ' is not an array')
		end
	else
		return a..b
	end
end)

--[[
	Returns `true` if the specified value is equal, in [`R.equals`](#equals)
	terms, to at least one element of the given list `false` otherwise.
	
	@func
	@category Array
	@sig a -> [a] -> Boolean
	@param {Object} a The item to compare against.
	@param {Array} list The array to consider.
	@return {Boolean} `true` if an equivalent item is in the list, `false` otherwise.
	@see R.any
	@example	
		R.contains(3, {1, 2, 3}) --> true
		R.contains(4, {1, 2, 3}) --> false
		R.contains({ name = 'Fred' }, {{ name = 'Fred' }}) --> true
		R.contains({42}, {{42}}) --> true
]]
R.contains = _curry2(_contains)
--[[
	@alias R.contains
]]
R.includes = R.contains

--[[
	Finds the set (i.e. no duplicates) of all elements in the first list not
	contained in the second list. Objects and Arrays are compared in terms of
	value equality, not reference equality.
	
	@func
	@category Array
	@sig [*] -> [*] -> [*]
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The elements in `list1` that are not in `list2`.
	@see R.differenceWith, R.symmetricDifference, R.symmetricDifferenceWith, R.without
	@example
		R.difference({1,2,3,4}, {7,6,5,4,3}) --> {1,2}
		R.difference({7,6,5,4,3}, {1,2,3,4}) --> {7,6,5}
		R.difference({{a = 1}, {b = 2}}, {{a = 1}, {c = 3}}) --> {{b = 2}}
]]
R.difference = _curry2(function(first, second)
	local out = {}
	local idx = 1
	local firstLen = #first
	while idx <= firstLen do
		if (not _contains(first[idx], second)) and (not _contains(first[idx], out)) then
			out[#out + 1] = first[idx]
		end
		idx = idx + 1
	end
	return out
end)

--[[
	Finds the set (i.e. no duplicates) of all elements in the first list not
	contained in the second list. Duplication is determined according to the
	value returned by applying the supplied predicate to two list elements.
	
	@func
	@category Array
	@sig ((a, a) -> Boolean) -> [a] -> [a] -> [a]
	@param {Function} pred A predicate used to test whether two items are equal.
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The elements in `list1` that are not in `list2`.
	@see R.difference, R.symmetricDifference, R.symmetricDifferenceWith
	@example
		local cmp = function(x, y) return x.a == y.a end
		local l1 = {{a = 1}, {a = 2}, {a = 3}}
		local l2 = {{a = 3}, {a = 4}}
		R.differenceWith(cmp, l1, l2) --> {{a = 1}, {a = 2}}
]]
R.differenceWith = _curry3(function(pred, first, second)
	local out = {}
	local idx = 1
	local firstLen = #first
	while idx <= firstLen do
		if (not _containsWith(pred, first[idx], second)) and (not _containsWith(pred, first[idx], out)) then
			out[#out + 1] = first[idx]
		end
		idx = idx + 1
	end
	return out
end)

--[[
	Returns all but the first `n` elements of the given list, string, or
	transducer/transformer (or object with a `drop` method).
		
	@func
	@category Array
	@sig Number -> [a] -> [a]
	@sig Number -> String -> String
	@param {Number} n
	@param {*} list
	@return {*} A copy of list without the first `n` elements
	@see R.take, R.transduce, R.dropLast, R.dropWhile
	@example
		R.drop(1, {'foo', 'bar', 'baz'}) --> {'bar', 'baz'}
		R.drop(2, {'foo', 'bar', 'baz'}) --> {'baz'}
		R.drop(3, {'foo', 'bar', 'baz'}) --> {}
		R.drop(4, {'foo', 'bar', 'baz'}) --> {}
		R.drop(3, 'ramda')               --> 'da'
]]
R.drop = _curry2(function(n, xs)
	return R.slice(math.max(0, n) + 1, 0, xs)
end)

--[[
	Returns a list containing all but the last `n` elements of the given `list`.
	
	@func
	@category Array
	@sig Number -> [a] -> [a]
	@sig Number -> String -> String
	@param {Number} n The number of elements of `list` to skip.
	@param {Array} list The list of elements to consider.
	@return {Array} A copy of the list with only the first `#list - n` elements
	@see R.takeLast, R.drop, R.dropWhile, R.dropLastWhile
	@example	
		R.dropLast(1, {'foo', 'bar', 'baz'}) --> {'foo', 'bar'}
		R.dropLast(2, {'foo', 'bar', 'baz'}) --> {'foo'}
		R.dropLast(3, {'foo', 'bar', 'baz'}) --> {}
		R.dropLast(4, {'foo', 'bar', 'baz'}) --> {}
		R.dropLast(3, 'lamda')               --> 'la'
]]
R.dropLast = _curry2(function(n, xs)
    return R.take(n < R.size(xs) and R.size(xs) - n or 0, xs)
end)

--[[
	Returns a new list excluding all the tailing elements of a given list which
	satisfy the supplied predicate function. It passes each value from the right
	to the supplied predicate function, skipping elements until the predicate
	function returns a `falsy` value. The predicate function is applied to one argument:
	(value)*.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> [a]
	@param {Function} predicate The function to be called on each element
	@param {Array} list The collection to iterate over.
	@return {Array} A new array without any trailing elements that return `falsy` values from the `predicate`.
	@see R.takeLastWhile, R.drop, R.dropWhile
	@example	
		R.dropLastWhile(R.gte(3), {1, 2, 3, 4, 3, 2, 1}) --> {1, 2, 3, 4}
]]
R.dropLastWhile = _curry2(function(pred, list)
	local idx = R.size(list)
	while idx > 0 and pred(_get(idx, list)) do
		idx = idx - 1
	end
	if (idx == 0) then return R.empty(list) end
	return R.slice(1, idx + 1, list)
end)

--[[
	Returns a new list excluding the leading elements of a given list which
	satisfy the supplied predicate function. It passes each value to the supplied
	predicate function, skipping elements while the predicate function returns
	`true`. The predicate function is applied to one argument: *(value)*.    
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> [a]
	@param {Function} fn The function called per iteration.
	@param {Array} list The collection to iterate over.
	@return {Array} A new array.
	@see R.takeWhile
	@example	
		R.dropWhile(R.gte(2), {1, 2, 3, 4, 3, 2, 1}) --> {3, 4, 3, 2, 1}
]]
R.dropWhile = _curry2(function(pred, list)
	local idx = 1
	local len = R.size(list)
	while idx <= len and pred(_get(idx, list)) do
		idx = idx + 1
	end
	return R.slice(idx, len + 1, list)
end)

--[[
	Takes a predicate and an array, and returns a new array of the
	same type containing the members of the given array which satisfy the
	given predicate. 
		
	@func
	@category Array
	@category Object
	@sig Filterable f => (a -> Boolean) -> f a -> f a
	@param {Function} pred
	@param {Array} filterable
	@return {Array} Filterable
	@see R.reject
	@example	
		local isEven = function(n) return n % 2 == 0 end	
		R.filter(isEven, {1, 2, 3, 4}) --> {2, 4}	
		R.filter(isEven, {a = 1, b = 2, c = 3, d = 4}) --> {b = 2, d = 4}
]]
R.filter = _curry2(function(pred, filterable)
	if _isObject(filterable) then
		local result = {}
		for k,v in pairs(filterable) do
			if pred(v) then
				result[k] = v
			end
		end
		return result
	else
		return _filter(pred, filterable)
	end
end)

--[[
	Returns the first element of the list which matches the predicate, or
	`nil` if no element matches.
	
	If `predicate` is not a function, use R.equals to check it's value
		
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> a | nil
	@param {Function} fn The predicate function used to determine if the element is the desired one.
	@param {Array} list The array to consider.
	@return {Object} The element found, or `nil`.	
	@example
		local xs = {{a = 1}, {a = 2}, {a = 3}}
		R.find(R.propEq('a', 2))(xs) --> {a = 2}
		R.find(R.propEq('a', 4))(xs) --> nil
]]
R.find = _curry2(function(fn, list)
	local idx = 1
	local len = #list
	while idx <= len do
		if _isFunction(fn) then
			if fn(list[idx]) then
				return list[idx]
			end
		elseif R.equals(fn, list[idx]) then
			return list[idx]
		end
		idx = idx + 1
	end
end)

--[[
	Returns the index of the first element of the list which matches the
	predicate, or `-1` if no element matches.
		
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> Number
	@param {Function} fn The predicate function used to determine if the element is the desired one.
	@param {Array} list The array to consider.
	@return {Number} The index of the element found, or `-1`.
	@example
		local xs = {{a = 1}, {a = 2}, {a = 3}}
		R.findIndex(R.propEq('a', 2))(xs) --> 2
		R.findIndex(R.propEq('a', 4))(xs) --> -1
]]
R.findIndex = _curry2(function(fn, list)
	local idx = 1
	local len = #list
	while idx <= len do
		if _isFunction(fn) then
			if fn(list[idx]) then
				return idx
			end
		elseif R.equals(fn, list[idx]) then
			return idx
		end
		idx = idx + 1
	end
	return -1
end)

--[[
	Returns the last element of the list which matches the predicate, or
	`nil` if no element matches.
		
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> a | nil
	@param {Function} fn The predicate function used to determine if the element is the
	desired one.
	@param {Array} list The array to consider.
	@return {Object} The element found, or `nil`.	
	@example
		local xs = {{a = 1, b = 0}, {a = 1, b = 1}}
		R.findLast(R.propEq('a', 1))(xs) --> {a = 1, b = 1}
		R.findLast(R.propEq('a', 4))(xs) --> nil
]]
R.findLast = _curry2(function(fn, list)
	local idx = #list
	while idx > 0 do
		if _isFunction(fn) then
			if fn(list[idx]) then
				return list[idx]
			end
		elseif R.equals(fn, list[idx]) then
			return list[idx]
		end
		idx = idx - 1
	end
end)


--[[
	Returns the index of the last element of the list which matches the
	predicate, or `-1` if no element matches.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> Number
	@param {Function} fn The predicate function used to determine if the element is the desired one.
	@param {Array} list The array to consider.
	@return {Number} The index of the element found, or `-1`.
	@example
		local xs = {{a = 1, b = 0}, {a = 1, b = 1}}
		R.findLastIndex(R.propEq('a', 1))(xs) --> 1
		R.findLastIndex(R.propEq('a', 4))(xs) --> -1
]]
R.findLastIndex = _curry2(function(fn, list)
	local idx = #list
	while idx > 0 do
		if _isFunction(fn) then
			if fn(list[idx]) then
				return idx
			end
		elseif R.equals(fn, list[idx]) then
			return idx
		end
		idx = idx - 1
	end
	return -1
end)

--[[
	Returns a new list by pulling every item out of it (and all its sub-arrays)
	and putting them in a new array, depth-first.
	
	@func
	@category Array
	@sig [a] -> [b]
	@param {Array} list The array to consider.
	@return {Array} The flattened list.
	@see R.unnest
	@example	
		R.flatten({1, 2, {3, 4}, 5, {6, {7, 8, {9, {10, 11}, 12}}}})
		--> {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
]]
R.flatten = _curry1(_makeFlat(true))

--[[
	Iterate over an input `list`, calling a provided function `fn` for each
	element in the list.
	
	`fn` receives one argument: *(value)*.    
	
	@func
	@category Array
	@category Object
	@sig (a -> *) -> [a] -> [a]
	@param {Function} fn The function to invoke. Receives argument, `value` and `key`.
	@param {Array} list The list to iterate over.
	@return {Array} The original list.
	@example
		local printXPlusFive = function(x) print(x + 5) end
		R.forEach(printXPlusFive, {1, 2, 3})
		--> 6
		--> 7
		--> 8
	@symb R.forEach(f, {a, b, c}) = {a, b, c}
]]
R.forEach = _curry2(function(fn, list)
	if _isObject(list) then
		for k, v in pairs(list) do
			fn(v, k)
		end
	elseif _isArray(list) then
		for k, v in ipairs(list) do
			fn(v, k)
		end
	end
	return list
end)

--[[
	Takes a list and returns a list of lists where each sublist's elements are
	all satisfied pairwise comparison according to the provided function.
	Only adjacent elements are passed to the comparison function.
	
	@func
	@category Array
	@sig ((a, a) → Boolean) → [a] → [ [a] ]
	@param {Function} fn Function for determining whether two given (adjacent)
		elements should be in the same group
	@param {Array} list The array to group. Also accepts a string, which will be
		treated as a list of characters.
	@return {List} A list that contains sublists of elements,
			whose concatenations are equal to the original list.
	@example	
		print(R.toString(R.groupWith(R.equals, {0, 1, 1, 2, 3, 5, 8, 13, 21})))
		--> {{0}, {1, 1}, {2}, {3}, {5}, {8}, {13}, {21}}
		print(R.toString(R.groupWith(function(a, b) return a + 1 == b end, {0, 1, 1, 2, 3, 5, 8, 13, 21})))
		--> {{0, 1}, {1, 2, 3}, {5}, {8}, {13}, {21}}
		print(R.toString(R.groupWith(function(a, b) return a % 2 == b % 2 end, {0, 1, 1, 2, 3, 5, 8, 13, 21})))
		--> {{0}, {1, 1}, {2}, {3, 5}, {8}, {13, 21}}
		print(R.toString(R.groupWith(R.eqBy(R.contains(R.__, "aeiou")), 'aestiou')))
		--> {'ae', 'st', 'iou'}
]]
R.groupWith = _curry2(function (fn, list)
	local res = {}
	if _isString(list) then
		local idx = 1
		local len = string.len(list)
		while idx <= len do
			local nextidx = idx + 1
			while nextidx <= len and fn(string.sub(list,nextidx - 1,nextidx-1), string.sub(list, nextidx, nextidx)) do
				nextidx = nextidx + 1
			end
			res[#res + 1] = string.sub(list, idx, nextidx - 1)
			idx = nextidx
		end
	else
		local idx = 1
		local len = #list
		while idx <= len do
			local nextidx = idx + 1
			while nextidx <= len and fn(list[nextidx - 1], list[nextidx]) do
				nextidx = nextidx + 1
			end
			res[#res + 1] = R.slice(idx, nextidx, list)
			idx = nextidx
		end
	end
	return res
end)

--[[
	Returns the position of the first occurrence of an item in an array, or -1
	if the item is not included in the array. [`R.equals`](#equals) is used to
	determine equality.
	
	@func
	@category Array
	@category String
	@sig a -> [a] -> Number
	@param {*} target The item to find.
	@param {Array} xs The array to search in.
	@return {Number} the index of the target, or -1 if the target is not found.
	@see R.findIndex, R.lastIndexOf
	@example	
		R.indexOf(3, {1,2,3,4}) --> 3
		R.indexOf('e', "abcd")  --> -1
]]
R.indexOf = _curry2(function(target, xs)
	return _indexOf(xs, target, 1)
end)

--[[
	Takes a predicate `pred`, a list `xs`, and a list `ys`, and returns a list
	`xs'` comprising each of the elements of `xs` which is equal to one or more
	elements of `ys` according to `pred`.
	
	`pred` must be a binary function expecting an element from each list.
	
	`xs`, `ys`, and `xs'` are treated as sets, semantically, so ordering should
	not be significant, but since `xs'` is ordered the implementation guarantees
	that its values are in the same order as they appear in `xs`. Duplicates are
	not removed, so `xs'` may contain duplicates if `xs` contains duplicates.
	
	@func
	@category Array
	@sig (a -> b -> Boolean) -> [a] -> [b] -> [a]
	@param {Function} pred
	@param {Array} xs
	@param {Array} ys
	@return {Array}
	@see R.intersection
	@example	
		R.innerJoin(
			function(data, id) return data.id == id end,
			{{id = 824, name = 'Richie Furay'},
				{id = 956, name = 'Dewey Martin'},
				{id = 313, name = 'Bruce Palmer'},
				{id = 456, name = 'Stephen Stills'},
				{id = 177, name = 'Neil Young'}},
			{177, 456, 999}
		) --> {{name = "Stephen Stills",id = 456},{name = "Neil Young",id = 177}}
]]
R.innerJoin = _curry3(function(pred, xs, ys)
	return _filter(function (x)
		return _containsWith(pred, x, ys)
	end, xs)
end)

--[[
	Inserts the supplied element into the list, at the specified `index`. _Note that
	this is not destructive_: it returns a copy of the list with the changes.
	<small>No lists have been harmed in the application of this function.</small>
	
	@func
	@category Array
	@sig Number -> a -> [a] -> [a]
	@param {Number} index The position to insert the element
	@param {*} elt The element to insert into the Array
	@param {Array} list The list to insert into
	@return {Array} A new Array with `elt` inserted at `index`.
	@example     
		R.insert(2, 'x', {1,2,3,4}) --> {1,2,'x',3,4}
]]
R.insert = _curry3(function(idx, elt, list)
	idx = idx <= #list and idx > 0 and idx or #list + 1
	local result = R.slice(1, idx + 1, list)
	result[#result + 1] = elt
	for i = idx + 1, #list do
		result[#result + 1] = list[i]
	end
	return result
end)


--[[
	Inserts the sub-list into the list, at the specified `index`. _Note that this is not
	destructive_: it returns a copy of the list with the changes.
	<small>No lists have been harmed in the application of this function.</small>
	
	@func
	@category Array
	@sig Number -> [a] -> [a] -> [a]
	@param {Number} index The position to insert the sub-list
	@param {Array} elts The sub-list to insert into the Array
	@param {Array} list The list to insert the sub-list into
	@return {Array} A new Array with `elts` inserted starting at `index`.
	@example	
		R.insertAll(2, {'x','y','z'}, {1,2,3,4}) --> {1,2,'x','y','z',3,4}
]]
R.insertAll = _curry3(function(idx, elts, list)
	idx = idx <= #list and idx > 0 and idx or #list + 1
	local result = R.slice(1, idx + 1, list)
	for _,v in ipairs(elts) do
		result[#result + 1] = v
	end
	for i = idx + 1, #list do
		result[#result + 1] = list[i]
	end
	return result
end)

--[[
	Creates a new list with the separator interposed between elements.
	
	@func
	@category Array
	@sig a -> [a] -> [a]
	@param {*} separator The element to add to the list.
	@param {Array} list The list to be interposed.
	@return {Array} The new list.
	@example     
		R.intersperse('n', {'ba', 'a', 'a'}) --> {'ba', 'n', 'a', 'n', 'a'}
]]
R.intersperse = _curry2(function(separator, list)
	local out = {}
	local idx = 1
	local length = #list
	while idx <= length do
		if idx == length then
			out[#out + 1] = list[idx]
		else
			out[#out + 1] = list[idx]
			out[#out + 1] = separator
		end
		idx = idx + 1
	end
	return out
end)

--[[
	Returns the number of elements in the table.
	
	@func
	@category Array
	@sig [a] -> Number
	@param {Array} list The array to inspect.
	@return {Number} The length of the array.
	@example	
		R.length({}) --> 0
		R.length({1, 2, 3}) --> 3
]]
R.length = _curry1(function(v)
	if _isTable(v) then
		return _safe_size(v)
	elseif _isString(v) then
		return string.len(v)
	else
		return 0
	end
end)
--[[
	@alias R.length
]]
R.size = R.length

--[[
	Returns the position of the last occurrence of an item in an array, or -1 if
	the item is not included in the array. [`R.equals`](#equals) is used to
	determine equality.
	
	@func
	@category Array
	@sig a -> [a] -> Number
	@param {*} target The item to find.
	@param {Array} xs The array to search in.
	@return {Number} the index of the target, or -1 if the target is not found.
	@see R.indexOf
	@example	
		R.lastIndexOf(3, {-1,3,3,0,1,2,3,4}) --> 7
		R.lastIndexOf(10, {1,2,3,4}) --> -1
]]
R.lastIndexOf = _curry2(function(target, xs)
	if _isString(xs) then
		for i = string.len(xs), idx, -1 do
			if string.sub(xs, i, i) == target then
				return i
			end
		end
	else
		idx = #xs
		while idx >= 1 do
			if R.equals(target, xs[idx]) then
				return idx
			end
			idx = idx -1
		end
	end
	return -1
end)

--[[
	Returns the nth element of the given list or string. If n is negative the
	element at index length + n is returned.
	
	@func
	@category Array
	@sig Number -> [a] -> a | nil
	@sig Number -> String -> String
	@param {Number} offset
	@param {*} list
	@return {*}
	@example
		local list = {'foo', 'bar', 'baz', 'quux'}
		R.nth(1, list) --> 'bar'
		R.nth(-1, list) --> 'quux'
		R.nth(-99, list) --> nil	
		R.nth(2, 'abc') --> 'c'
		R.nth(3, 'abc') --> ''

	@symb R.nth(-1, [a, b, c]) = c
	@symb R.nth(0, [a, b, c]) = a
	@symb R.nth(1, [a, b, c]) = a
]]
R.nth = _curry2(function(offset, list)
	if offset == 0 then offset = 1 end
	local idx = offset < 0 and R.size(list) + offset + 1 or offset	
	return _get(idx, list)
end)

--[[
	Returns the first element of the given list or string. In some libraries
	this function is named `first`.
	
	@func
	@category Array
	@sig [a] -> a | nil
	@sig String -> String
	@param {Array|String} list
	@return {*}
	@see R.tail, R.init, R.last
	@example
		R.head({'fi', 'fo', 'fum'}) --> 'fi'
		R.head({}) --> nil
		R.head('abc') --> 'a'
		R.head('') --> ''
]]
R.head = R.nth(1)

--[[
	Returns the last element of the given list or string.
	
	@func
	@category Array
	@sig [a] -> a | nil
	@sig String -> String
	@param {*} list
	@return {*}
	@see R.init, R.head, R.tail
	@example	
		R.last({'fi', 'fo', 'fum'}) --> 'fum'
		R.last({}) --> nil	
		R.last('abc') --> 'c'
		R.last('') --> ''
]]
R.last = R.nth(-1)

--[[
	Takes two arguments, `fst` and `snd`, and returns `{fst, snd}`.
	
	@func
	@category Array
	@sig a -> b -> (a,b)
	@param {*} fst
	@param {*} snd
	@return {Array}
	@see R.objOf, R.of
	@example	
		R.pair('foo', 'bar') --> {'foo', 'bar'}
]]
R.pair = _curry2(function(fst, snd)
	return {fst, snd}	
end)

--[[
	Returns a new list with the given element at the front, followed by the
	contents of the list.
	
	@func
	@category Array
	@sig a -> [a] -> [a]
	@param {*} el The item to add to the head of the output list.
	@param {Array} list The array to add to the tail of the output list.
	@return {Array} A new array.
	@see R.append
	@example	
		R.prepend('fee', {'fi', 'fo', 'fum'}) --> {'fee', 'fi', 'fo', 'fum'}
]]
R.prepend = _curry2(function(el, list)
	return _concat({el}, list)
end)
--[[
	@alias R.prepend
]]
R.unshift = R.prepend

--[[
	Returns a list of numbers from `from` (inclusive) to `to` (exclusive).
	
	@func
	@category Array
	@sig Number -> Number -> [Number]
	@param {Number} from The first number in the list.
	@param {Number} to One more than the last number in the list.
	@return {Array} The list of numbers in tthe set `[a, b)`.
	@example	
		R.range(1, 5)    --> {1, 2, 3, 4}
		R.range(50, 53)  --> {50, 51, 52}
]]
R.range = _curry2(function(from, to)
	if not _isInteger(from) or not _isInteger(to) then
		error('<lamda_error> range:: Both arguments to range must be numbers')
	end
	local result = {}
	local n = from
	while n < to do
		result[#result + 1] = n
		n = n + 1
	end
	return result
end)

--[[
	Returns a single item by iterating through the list, successively calling
	the iterator function and passing it an accumulator value and the current
	value from the array, and then passing the result to the next call.
	
	The iterator function receives two values: *(acc, value)*. 
	
	The arguments' order of [`reduceRight`](#reduceRight)'s iterator function
	is *(value, acc)*.
	
	@func
	@category Array
	@sig ((a, b) -> a) -> a -> [b] -> a
	@param {Function} fn The iterator function. Receives two values, the accumulator and the
		current element from the array.
	@param {*} acc The accumulator value.
	@param {Array} list The list to iterate over.
	@return {*} The final, accumulated value.
	@see R.reduceRight
	@example	
		R.reduce(R.subtract, 0, {1, 2, 3, 4}) --> ((((0 - 1) - 2) - 3) - 4) = -10	
		--          -               -10
		--         / \              / \
		--        -   4           -6   4
		--       / \              / \
		--      -   3   ==>     -3   3
		--     / \              / \
		--    -   2           -1   2
		--   / \              / \
		--  0   1            0   1

	@symb R.reduce(f, a, [b, c, d]) = f(f(f(a, b), c), d)
]]
R.reduce = _curry3(_reduce)

--[[
	Groups the elements of the list according to the result of calling
	the String-returning function `keyFn` on each element and reduces the elements
	of each group to a single value via the reducer function `valueFn`.
	
	This function is basically a more general [`groupBy`](#groupBy) function.
	
	@func
	@category Array
	@sig ((a, b) -> a) -> a -> (b -> String) -> [b] -> {String: a}
	@param {Function} valueFn The function that reduces the elements of each group to a single
		value. Receives two values, accumulator for a particular group and the current element.
	@param {*} acc The (initial) accumulator value for each group.
	@param {Function} keyFn The function that maps the list's element into a key.
	@param {Array} list The array to group.
	@return {Object} An object with the output of `keyFn` for keys, mapped to the output of
			`valueFn` for elements which produced that key when passed to `keyFn`.
	@see R.groupBy, R.reduce
	@example	
		local reduceToNamesBy = R.reduceBy(function(acc, student)
			return R.append(student.name, acc) 
		end, {})
		local namesByGrade = reduceToNamesBy(function(student)
			local score = student.score
			return score < 65 and 'F' or
					score < 70 and 'D' or
					score < 80 and 'C' or
					score < 90 and 'B' or 'A'
		end)
		local students = {{name = 'Lucy', score = 92},
						{name = 'Drew', score = 85},
						{name = 'Leo', score = 90},
						{name = 'Bart', score = 62}}
		namesByGrade(students) --> {A={"Lucy", "Leo"}, B={"Drew"}, F={"Bart"}}
]]
R.reduceBy = _reduceBy

--[[
	Returns a single item by iterating through the list, successively calling
	the iterator function and passing it an accumulator value and the current
	value from the array, and then passing the result to the next call.
	
	Similar to [`reduce`](#reduce), except moves through the input list from the
	right to the left.
	
	The iterator function receives two values: *(value, acc)*, while the arguments'
	order of `reduce`'s iterator function is *(acc, value)*.
	
	@func	@category Array
	@sig (a, b -> b) -> b -> [a] -> b
	@param {Function} fn The iterator function. Receives two values, the current element from the array
		and the accumulator.
	@param {*} acc The accumulator value.
	@param {Array} list The list to iterate over.
	@return {*} The final, accumulated value.
	@see R.reduce
	@example     
		R.reduceRight(R.subtract, 0, {1, 2, 3, 4}) --> (1 - (2 - (3 - (4 - 0)))) = -2
		--   -               -2
		--  / \              / \
		-- 1   -            1   3
		--    / \              / \
		--   2   -     ==>    2  -1
		--      / \              / \
		--     3   -            3   4
		--        / \              / \
		--       4   0            4   0
	
    @symb R.reduceRight(f, a, [b, c, d]) = f(b, f(c, f(d, a)))
]]
R.reduceRight = _curry3(function(fn, acc, list)
	local idx = #list
	while idx > 0 do
		acc = fn(list[idx], acc)
		idx = idx - 1
	end
	return acc
end)


--[[
	Like [`reduce`](#reduce), `reduceWhile` returns a single item by iterating
	through the list, successively calling the iterator function. `reduceWhile`
	also takes a predicate that is evaluated before each step. If the predicate
	returns `false`, it "short-circuits" the iteration and returns the current
	value of the accumulator.
	
	@func
	@category Array
	@sig ((a, b) -> Boolean) -> ((a, b) -> a) -> a -> [b] -> a
	@param {Function} pred The predicate. It is passed the accumulator and the
		current element.
	@param {Function} fn The iterator function. Receives two values, the
		accumulator and the current element.
	@param {*} a The accumulator value.
	@param {Array} list The list to iterate over.
	@return {*} The final, accumulated value.
	@see R.reduce
	@example	
		local isOdd = R.o(R.equals(1), R.mod)
		local xs = {1, 3, 5, 60, 777, 800}
		R.reduceWhile(isOdd, R.add, 0, xs) --> 9
	
		local ys = {2, 4, 6}
		R.reduceWhile(isOdd, R.add, 111, ys) --> 111
]]
R.reduceWhile = _curryN(4, {}, function(pred, fn, a, list)
	local terminate = false
	return _reduce(function (acc, x)
		if terminate or not pred(acc, x) then
			terminate = true
			return acc 
		end
		return fn(acc, x)
	end, a, list)
end)

--[[
	Splits a list into sub-lists stored in an object, based on the result of
	calling a String-returning function on each element, and grouping the
	results according to values returned.
		
	@func
	@category Array
	@sig (a -> String) -> [a] -> {String: [a]}
	@param {Function} fn Function :: a -> String
	@param {Array} list The array to group
	@return {Object} An object with the output of `fn` for keys, mapped to arrays of elements
			that produced that key when passed to `fn`.
	
	@example	
		local byGrade = R.groupBy(function(student) 
			local score = student.score
			return score < 65 and 'F' or
					score < 70 and 'D' or
					score < 80 and 'C' or
					score < 90 and 'B' or 'A'
		end)
		local students = {{name = 'Lucy', score = 92},
					{name = 'Drew', score = 85},
					{name = 'Leo', score = 90},
					{name = 'Bart', score = 62}}
		byGrade(students)
		--> {
		-- 	A={{name="Lucy", score=92}, {name="Leo", score=90}},
		-- 	B={{name="Drew", score=85}},
		-- 	F={{name="Bart", score=62}}
		-- }
]]
R.groupBy = _curry2(R.reduceBy(function (acc, item)	
	if acc == R.NIL then
		acc = {}
	end
	acc[#acc + 1] = item
	return acc
end, R.NIL))

--[[
	Given a function that generates a key, turns a list of objects into an
	object indexing the objects by the given key. Note that if multiple
	objects generate the same value for the indexing key only the last value
	will be included in the generated object.
		
	@func
	@category Array
	@sig (a -> String) -> [{k: v}] -> {k: {k: v}}
	@param {Function} fn Function :: a -> String
	@param {Array} array The array of objects to index
	@return {Object} An object indexing each array element by the given property.
	@example	
		local list = {{id = 'xyz', title = 'A'}, {id = 'abc', title = 'B'}}
		R.indexBy(R.prop('id'), list)
		--> {abc: {id = 'abc', title = 'B'}, xyz: {id = 'xyz', title = 'A'}}
]]
R.indexBy = R.reduceBy(function (acc, elem)
	return elem
end, "nil")

--[[
	The complement of [`filter`](#filter).
	
	@func
	@category Array
	@sig Filterable f => (a -> Boolean) -> f a -> f a
	@param {Function} pred
	@param {Array} filterable
	@return {Array}
	@see R.filter
	@example	
		local isOdd = R.o(R.equals(1), R.mod(R.__, 2))	
		R.reject(isOdd, {1, 2, 3, 4}) --> {2, 4}
		R.reject(isOdd, {a = 1, b = 2, c = 3, d = 4}) --> {b = 2, d = 4}
]]
R.reject = _curry2(function(pred, filterable)
	return R.filter(_complement(pred), filterable)
end)

--[[
	Takes a predicate and a list or other `Filterable` object and returns the
	pair of filterable objects of the same type of elements which do and do not
	satisfy, the predicate, respectively. Filterable objects include plain objects or any object
	that has a filter method such as `Array`.
	
	@func
	@category Array
	@sig Filterable f => (a -> Boolean) -> f a -> [f a, f a]
	@param {Function} pred A predicate to determine which side the element belongs to.
	@param {Array} filterable the list (or other filterable) to partition.
	@return {Array} An array, containing first the subset of elements that satisfy the
			predicate, and second the subset of elements that do not satisfy.
	@see R.filter, R.reject
	@example	
		R.partition(R.contains('s'), {'sss', 'ttt', 'foo', 'bars'}) --> {{'sss', 'bars'}, {'ttt', 'foo' }}	
		R.partition(R.contains('s'), {a = 'sss', b = 'ttt', foo = 'bars'}) --> {{ a = 'sss', foo = 'bars' }, { b = 'ttt' }}
]]
R.partition = R.juxt({
	R.filter,
	R.reject
})

--[[
	Removes the sub-list of `list` starting at index `start` and containing
	`count` elements. _Note that this is not destructive_: it returns a copy of
	the list with the changes.
	<small>No lists have been harmed in the application of this function.</small>
	
	@func
	@category Array
	@sig Number -> Number -> [a] -> [a]
	@param {Number} start The position to start removing elements
	@param {Number} count The number of elements to remove
	@param {Array} list The list to remove from
	@return {Array} A new Array with `count` elements from `start` removed.
	@example	
		R.remove(2, 3, {1,2,3,4,5,6,7,8}) --> {1,2,6,7,8}
]]
R.remove = _curry3(function(start, count, list)
	if count <= 0 then return list end
	if start == 0 then start = 1 end
	local result = R.slice(1, start, list)
	return R.concat(result, R.slice(start + count, #list + 1, list))
end)

--[[
	Returns a fixed list of size `n` containing a specified identical value.
	
	@func
	@category Array
	@sig a -> n -> [a]
	@param {*} value The value to repeat.
	@param {Number} n The desired size of the output list.
	@return {Array} A new array containing `n` `value`s.
	@see R.times
	@example	
		R.repeat_('hi', 5) --> {'hi', 'hi', 'hi', 'hi', 'hi'}
		local obj = {}
		local repeatedObjs = R.repeat_(obj, 5) --> {{}, {}, {}, {}, {}}
		R.same(repeatedObjs[1], repeatedObjs[2]) --> true

	@symb R.repeat(a, 0) = []
	@symb R.repeat(a, 1) = [a]
	@symb R.repeat(a, 2) = [a, a]
]]
R.repeat_ = _curry2(function(value, n)
	return R.times(R.always(value), n)
end)

--[[
	Returns a new list or string with the elements or characters in reverse
	order.
	
	@func
	@category Array
	@sig [a] -> [a]
	@sig String -> String
	@param {Array|String} list
	@return {Array|String}
	@example	
		R.reverse({1, 2, 3})  --> {3, 2, 1}
		R.reverse({1, 2})     --> {2, 1}
		R.reverse({1})        --> {1}
		R.reverse({})         --> {}
	
		R.reverse('abc')      --> 'cba'
		R.reverse('ab')       --> 'ba'
		R.reverse('a')        --> 'a'
		R.reverse('')         --> ''
]]
R.reverse = _curry1(function(list)
	if _isString(list) then
		return string.reverse(list)
	else
		local result = {}
		for i = #list,1,-1 do
			result[#result + 1] = list[i]
		end
		return result
	end
end)

--[[
	Scan is similar to [`reduce`](#reduce), but returns a list of successively
	reduced values from the left
	
	@func
	@category Array
	@sig (a,b -> a) -> a -> [b] -> [a]
	@param {Function} fn The iterator function. Receives two values, the accumulator and the
		current element from the array
	@param {*} acc The accumulator value.
	@param {Array} list The list to iterate over.
	@return {Array} A list of all intermediately reduced values.
	@see R.reduce
	@example	
		local numbers = {1, 2, 3, 4}
		local factorials = R.scan(R.multiply, 1, numbers) --> {1, 1, 2, 6, 24}

	@symb R.scan(f, a, [b, c]) = [a, f(a, b), f(f(a, b), c)]
]]
R.scan = _curry3(function(fn, acc, list)
	local idx = 1
	local len = #list
	local result = {acc}
	while idx <= len do
		acc = fn(acc, list[idx])
		result[idx + 1] = acc
		idx = idx + 1
	end
	return result
end)

--[[
	Returns the elements of the given list or string from `fromIndex` (inclusive) to `toIndex` (exclusive).	
	if `fromIndex` is zero then it will set to 1(from the first element)
	if `toIndex` is zero then it will set to length + 1(include the last element)
	negative number is the index from right side
	-1 means the last element, etc..
	
	@func
	@category Array
	@sig Number -> Number -> [a] -> [a]
	@sig Number -> Number -> String -> String
	@param {Number} fromIndex The start index (inclusive).
	@param {Number} toIndex The end index (exclusive).
	@param {*} list
	@return {*}
	@example
		R.slice(2, 3, {'a', 'b', 'c', 'd'})        --> {'b'}
		R.slice(1, -2, {'a', 'b', 'c', 'd'})       --> {'a', 'b'}
		R.slice(-3, -1, {'a', 'b', 'c', 'd'})      --> {'b', 'c'}
		R.slice(1, 3, 'lamda')                     --> 'la'
]]
R.slice = _curry3(function(start, stop, list)
	start = start == 0 and 1 or start	
	if _isString(list) then		
		if start < 0 then
			start = string.len(list) + start + 1
		end
		if stop <= 0 then
			stop = string.len(list) + stop + 1
		end
		return string.sub(list, start, stop - 1)
	else
		local array = {}
		if start < 0 then
			start = #list + start + 1
		end
		if stop <= 0 then
			stop = #list + stop + 1
		end
		for index = start, stop - 1, 1 do
			array[#array + 1] = list[index]
		end
		return array
	end
end)

--[[
	Returns all but the last element of the given list or string.
	
	@func
	@category Array
	@sig [a] -> [a]
	@sig String -> String
	@param {*} list
	@return {*}
	@see R.last, R.head, R.tail
	@example	
		R.init({1, 2, 3})  --> {1,2}
		R.init({1, 2})     --> {1}
		R.init({1})        --> {}
		R.init({})         --> {}
	
		R.init('abc')  --> 'ab'
		R.init('ab')   --> 'a'
		R.init('a')    --> ''
		R.init('')     --> ''
]]
R.init = R.slice(1, -1)

--[[
	Returns a copy of the list, sorted according to the comparator function,
	which should accept two values at a time and return a negative number if the
	first value is smaller, a positive number if it's larger, and zero if they
	are equal. Please note that this is a **copy** of the list. It does not
	modify the original.
	
	@func
	@category Array
	@sig (a,a -> Number) -> [a] -> [a]
	@param {Function} comparator A sorting function :: a -> b -> Int
	@param {Array} list The list to sort
	@return {Array} a new array with its elements sorted by the comparator function.
	@example	
		local diff = R.lt
		R.sort(diff, {4,2,7,5}) --> {2, 4, 5, 7}
]]
R.sort = _curry2(function(comparator, list)
	local _l = R.clone(list)
	table.sort(_l, function(a, b)
		local result = comparator(a, b)
		if _isBoolean(result) then return result
		else return result < 0 end
	end)
	return _l
end)

--[[
	Sorts a list according to a list of comparators.
	
	@func
	@category Array
	@sig [a -> a -> Number] -> [a] -> [a]
	@param {Array} functions A list of comparator functions.
	@param {Array} list The list to sort.
	@return {Array} A new list sorted according to the comarator functions.
	@example	
		local alice = {
			name = 'alice',
			age = 40
		}
		local bob = {
			name = 'bob',
			age = 30
		}
		local clara = {
			name = 'clara',
			age = 40
		}
		local people = {clara, bob, alice}
		local ageNameSort = R.sortWith({
			R.descend(R.prop('age')),
			R.ascend(R.prop('name'))
		})
		ageNameSort(people) --> {alice, clara, bob}
]]
R.sortWith = _curry2(function(comparator, list)
	local _l = R.clone(list)
	table.sort(_l, function (a, b)
		local result = 0
		local i = 1
		while result == 0 and i <= #comparator do
			result = comparator[i](a, b)
			i = i + 1
		end
		return result < 0
	end)
	return _l
end)

--[[
	Splits a string into an array of strings based on the given
	separator.
	
	@func
	@category String
	@sig (String | String) -> String -> [String]
	@param {String|String} sep The pattern.
	@param {String} str The string to separate into an array.
	@return {Array} The array of strings from `str` separated by `str`.
	@see R.join
	@example	
		local pathComponents = R.split('/')
		R.tail(pathComponents('/usr/local/bin')) --> {'usr', 'local', 'bin'}
		R.split('.', 'a.b.c.xyz.d') --> {'a', 'b', 'c', 'xyz', 'd'}
]]
R.split = _curry2(function(sep, str)
	local fields = {}
	local size = R.size(sep)
	if size <= 0 then return {str} end 
	local pin = 1
	local seq = ""
	while pin <= R.size(str) do
		local toMatch = string.sub(str, pin, pin + size - 1)
		if R.same(toMatch, sep) then
			fields[#fields + 1] = seq
			pin = pin + size
			seq = ""
		else
			pin = pin + 1
			seq = seq .. R.head(toMatch)
		end       
	end
	fields[#fields + 1] = seq
    return fields
end)

--[[
	Splits a given list or string at a given index.
	
	@func
	@category Array
	@sig Number -> [a] -> [ [a], [a] ]
	@sig Number -> String -> [String, String]
	@param {Number} index The index where the array/string is split.
	@param {Array|String} array The array/string to be split.
	@return {Array}
	@example	
		R.splitAt(2, {1, 2, 3})          --> {{1}, {2, 3}}
		R.splitAt(6, 'hello world')      --> {'hello', ' world'}
		R.splitAt(-1, 'foobar')          --> {'fooba', 'r'}
]]
R.splitAt = _curry2(function(index, array)
	return {
		R.slice(1, index, array),
		R.slice(index, #array + 1, array)
	}
end)

--[[
	Splits a collection into slices of the specified length.
	
	@func
	@category Array
	@sig Number -> [a] -> [ [a] ]
	@sig Number -> String -> [String]
	@param {Number} n
	@param {Array} list
	@return {Array}
	@example	
		R.splitEvery(3, {1, 2, 3, 4, 5, 6, 7}) --> {{1, 2, 3}, {4, 5, 6}, {7}}
		R.splitEvery(3, 'foobarbaz') --> {'foo', 'bar', 'baz'}
]]
R.splitEvery = _curry2(function(n, list)
	if n <= 0 then
		error('<lamda_error> splitEvery:: First argument to splitEvery must be a positive integer')
	end
	local result = {}
	local idx = 1
	while idx <= #list do
		result[#result + 1] = R.slice(idx, idx + n, list)
		idx = idx + n
	end
	return result
end)

--[[
	Takes a list and a predicate and returns a pair of lists with the following properties:
	
	The result of concatenating the two output lists is equivalent to the input list
	none of the elements of the first output list satisfies the predicate and
	if the second output list is non-empty, its first element satisfies the predicate.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> [ [a], [a] ]
	@param {Function} pred The predicate that determines where the array is split.
	@param {Array} list The array to be split.
	@return {Array}
	@example	
		R.splitWhen(R.equals(2), {1, 2, 3, 1, 2, 3})   --> {{1}, {2, 3, 1, 2, 3}}
]]
R.splitWhen = _curry2(function(pred, list)
	local idx = 1
	local len = R.size(list)
	local prefix
	if _isString(list) then
		prefix = ""
		while idx <= len and not pred(_get(idx, list)) do
			prefix = prefix .. _get(idx, list)
			idx = idx + 1
		end
	else
		prefix = {}
		while idx <= len and not pred(list[idx]) do
			prefix[#prefix + 1] = list[idx]
			idx = idx + 1
		end
	end
	return {
		prefix,
		R.slice(idx, #list + 1, list)
	}
end)

--[[
	Adds together all the elements of a list.
	
	@func
	@category Math
	@sig [Number] -> Number
	@param {Array} list An array of numbers
	@return {Number} The sum of all the numbers in the list.
	@see R.reduce
	@example	
		R.sum({2,4,6,8,100,1}) --> 121
]]
R.sum = R.reduce(R.add, 0)

--[[
	Returns all but the first element of the given list or string (or object
	with a `tail` method).

	Dispatches to the `slice` method of the first argument, if present.

	@func
	@category Array
	@sig [a] -> [a]
	@sig String -> String
	@param {*} list
	@return {*}
	@see R.head, R.init, R.last
	@example
		R.tail({1, 2, 3})  --> {2, 3}
		R.tail({1, 2})     --> {2}
		R.tail({1})        --> {}
		R.tail({})         --> {}

		R.tail('abc')  --> 'bc'
		R.tail('ab')   --> 'b'
		R.tail('a')    --> ''
		R.tail('')     --> ''
]]
R.tail = R.slice(2, 0)

--[[
	Returns the first `n` elements of the given list, string
	
	@func
	@category Array
	@sig Number -> [a] -> [a]
	@sig Number -> String -> String
	@param {Number} n
	@param {*} list
	@return {*}
	@see R.drop
	@example
		R.take(1, {'foo', 'bar', 'baz'}) --> {'foo'}
		R.take(2, {'foo', 'bar', 'baz'}) --> {'foo', 'bar'}
		R.take(3, {'foo', 'bar', 'baz'}) --> {'foo', 'bar', 'baz'}
		R.take(4, {'foo', 'bar', 'baz'}) --> {'foo', 'bar', 'baz'}
		R.take(3, 'ramda')               --> 'ram'
	
		local personnel = {
			'Dave Brubeck',
			'Paul Desmond',
			'Eugene Wright',
			'Joe Morello',
			'Gerry Mulligan',
			'Bob Bates',
			'Joe Dodge',
			'Ron Crotty'
		}	
		local takeFive = R.take(5)
		takeFive(personnel) --> {'Dave Brubeck', 'Paul Desmond', 'Eugene Wright', 'Joe Morello', 'Gerry Mulligan'}
	@symb R.take(-1, [a, b]) = [a, b]
	@symb R.take(0, [a, b]) = []
	@symb R.take(1, [a, b]) = [a]
	@symb R.take(2, [a, b]) = [a, b]
]]
R.take = _curry2(function (n, xs)
	if n <= 0 then return R.empty(xs) end
	return R.slice(1, n + 1, xs)
end)

--[[
	Returns a new list containing the last `n` elements of the given list.
	If `n > #list`, returns a list of `#list` elements.
	
	@func
	@category Array
	@sig Number -> [a] -> [a]
	@sig Number -> String -> String
	@param {Number} n The number of elements to return.
	@param {Array} xs The collection to consider.
	@return {Array}
	@see R.dropLast
	@example	
		R.takeLast(1, {'foo', 'bar', 'baz'}) --> {'baz'}
		R.takeLast(2, {'foo', 'bar', 'baz'}) --> {'bar', 'baz'}
		R.takeLast(3, {'foo', 'bar', 'baz'}) --> {'foo', 'bar', 'baz'}
		R.takeLast(4, {'foo', 'bar', 'baz'}) --> {'foo', 'bar', 'baz'}
		R.takeLast(3, 'lamda')               --> 'mda'
]]
R.takeLast = _curry2(function(n, xs)
	if n <= 0 then return R.empty(xs) end
	return R.drop(R.size(xs) - n, xs)
end)

--[[
	Returns a new list containing the last `n` elements of a given list, passing
	each value to the supplied predicate function, and terminating when the
	predicate function returns `false`. Excludes the element that caused the
	predicate function to fail. The predicate function is passed one argument:
	(value)*.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> [a]
	@param {Function} fn The function called per iteration.
	@param {Array} list The collection to iterate over.
	@return {Array} A new array.
	@see R.dropLastWhile
	@example	
		local isNotOne = R.complement(R.equals(1))	
		R.takeLastWhile(isNotOne, {1, 2, 3, 4}) --> {2, 3, 4}
]]
R.takeLastWhile = _curry2(function(fn, list)
	local idx = R.size(list)
	while idx > 0 and fn(_get(idx, list)) do
		idx = idx - 1
	end
	return R.slice(idx + 1, R.size(list) + 1, list)
end)

--[[
	Returns a new list containing the first `n` elements of a given list,
	passing each value to the supplied predicate function, and terminating when
	the predicate function returns `false`. Excludes the element that caused the
	predicate function to fail. The predicate function is passed one argument:
	(value)*.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> [a]
	@param {Function} fn The function called per iteration.
	@param {Array} list The collection to iterate over.
	@return {Array} A new array.
	@see R.dropWhile
	@example	
		local isNotFour = R.complement(R.equals(4))	
		R.takeWhile(isNotFour, {1, 2, 3, 4, 3, 2, 1}) --> {1, 2, 3}
]]
R.takeWhile = _curry2(function(fn, list)
	local idx = 1
	while idx <= R.size(list) and fn(_get(idx, list)) do
		idx = idx + 1
	end
	return R.slice(1, idx, list)
end)

--[[
	Calls an input function `n` times, returning an array containing the results
	of those function calls.
	
	`fn` is passed one argument: The current value of `n`, which begins at `1`
	and is gradually incremented to `n`.
	
	@func
	@category Array	
	@sig (Number -> a) -> Number -> [a]
	@param {Function} fn The function to invoke. Passed one argument, the current value of `n`.
	@param {Number} n A value between `0` and `n - 1`. Increments after each function call.
	@return {Array} An array containing the return values of all calls to `fn`.
	@see R.repeat
	@example     
		R.times(R.identity, 5) --> {1, 2, 3, 4, 5}
		
	@symb R.times(f, 0) = []
	@symb R.times(f, 1) = [f(1)]
	@symb R.times(f, 2) = [f(1), f(2)]
]]
R.times = _curry2(function (fn, n)
	local len = n
	local idx = 1
	local list = {}
	if len < 0 then
		error('<lamda_error> times:: n must be a non-negative number')
	end
	while idx <= len do
		list[idx] = fn(idx)
		idx = idx + 1
	end
	return list
end)

--[[
	Transposes the rows and columns of a 2D list.
	When passed a list of `n` lists of length `x`,
	returns a list of `x` lists of length `n`.
		
	@func
	@category Array
	@sig [ [a] ] -> [ [a] ]
	@param {Array} list A 2D list
	@return {Array} A 2D list
	@example	
		R.transpose({{1, 'a'}, {2, 'b'}, {3, 'c'}}) --> {{1, 2, 3}, {"a", "b", "c"}}
		R.transpose({{1, 2, 3}, {'a', 'b', 'c'}}) --> {{1, "a"}, {2, "b"}, {3, "c"}}
	
		-- If some of the rows are shorter than the following rows, their elements are skipped:
		R.transpose({{10, 11}, {20}, {}, {30, 31, 32}}) --> {{10, 20, 30}, {11, 31}, {32}}

	@symb R.transpose({{a], [b], [c] ]) = [a, b, c]
	@symb R.transpose({{a, b], [c, d] ]) = {{a, c], [b, d] ]
	@symb R.transpose({{a, b], [c] ]) = {{a, c], [b] ]
]]
R.transpose = _curry1(function(outerlist)
	local i = 1
	local result = {}
	while i <= #outerlist do
		local innerlist = outerlist[i]
		local j = 1
		while j <= #innerlist do
			if result[j] == nil then
				result[j] = {}
			end
			result[j][#result[j] + 1] = innerlist[j]
			j = j + 1
		end
		i = i + 1
	end
	return result
end)

--[[
	Builds a list from a seed value. Accepts an iterator function, which returns
	either false to stop iteration or an array of length 2 containing the value
	to add to the resulting list and the seed to be used in the next call to the
	iterator function.
	
	The iterator function receives one argument: *(seed)*.
	
	@func
	@category Array
	@sig (a -> [b]) -> * -> [b]
	@param {Function} fn The iterator function. receives one argument, `seed`, and returns
		either false to quit iteration or an array of length two to proceed. The element
		at index 0 of this array will be added to the resulting array, and the element
		at index 1 will be passed to the next call to `fn`.
	@param {*} seed The seed value.
	@return {Array} The final list.
	@example	
		local f = function(n)
			if n > 50 then return false end
			return {-n, n + 10}
		end
		R.unfold(f, 10) --> {-10, -20, -30, -40, -50}
		
	@symb R.unfold(f, x) = [f(x)[0], f(f(x)[1])[0], f(f(f(x)[1])[1])[0], ...]
]]
R.unfold = _curry2(function(fn, seed)
	local pair = fn(seed)
	local result = {}
	if not pair or not _isArray(pair) then return result end
	while pair and #pair > 0 do
		result[#result + 1] = pair[1]
		pair = fn(pair[2])
		if not pair or not _isArray(pair) then break end
	end
	return result
end)

--[[
	Returns a new list containing only one copy of each element in the original
	list, based upon the value returned by applying the supplied function to
	each list element. Prefers the first item if the supplied function produces
	the same value on two items. [`R.equals`](#equals) is used for comparison.
	
	@func
	@category Array
	@sig (a -> b) -> [a] -> [a]
	@param {Function} fn A function used to produce a value to use during comparisons.
	@param {Array} list The array to consider.
	@return {Array} The list of unique items.
	@example	
		R.uniqBy(math.abs, {-1, -5, 2, 10, 1, 2}) --> {-1, -5, 2, 10}
]]
R.uniqBy = _curry2(function(fn, list)
	local resultSet = {}
	local result = {}
	for k,v in ipairs(list) do
		local appliedItem = fn(v)
		if not _contains(appliedItem, resultSet) then
			result[#result + 1] = v
			resultSet[#resultSet + 1] = appliedItem
		end
	end
	return result
end)

--[[
	Returns a new list containing only one copy of each element in the original
	list. [`R.equals`](#equals) is used to determine equality.
	
	@funn
	@category Array
	@sig [a] -> [a]
	@param {Array} list The array to consider.
	@return {Array} The list of unique items.
	@example	
		R.uniq({1, 1, 2, 1}) --> {1, 2}
		R.uniq({1, '1'})     --> {1, '1'}
		R.uniq({{42}, {42}}) --> {{42}}
]]
R.uniq = R.uniqBy(R.identity)

--[[
	Returns a new list containing only one copy of each element in the original
	list, based upon the value returned by applying the supplied predicate to
	two list elements. Prefers the first item if two items compare equal based
	on the predicate.
	
	@func
	@category Array
	@sig (a, a -> Boolean) -> [a] -> [a]
	@param {Function} pred A predicate used to test whether two items are equal.
	@param {Array} list The array to consider.
	@return {Array} The list of unique items.
	@example
	
		local strEq = R.eqBy(String)
		R.uniqWith(strEq)([1, '1', 2, 1]) --> [1, 2]
		R.uniqWith(strEq)([{}, {}])       --> [{}]
		R.uniqWith(strEq)([1, '1', 1])    --> [1]
		R.uniqWith(strEq)(['1', 1, 1])    --> ['1']
]]
R.uniqWith = _curry2(function(pred, list)
	local idx = 1
	local len = #list
	local result = {}
	local item
	while idx <= len do
		item = list[idx]
		if not _containsWith(pred, item, result) then
			result[#result + 1] = item
		end
		idx = idx + 1
	end
	return result
end)

--[[
	Combines two lists into a set (i.e. no duplicates) composed of the elements
	of each list.
	
	@func
	@category Array
	@sig [*] -> [*] -> [*]
	@param {Array} as The first list.
	@param {Array} bs The second list.
	@return {Array} The first and second lists concatenated, with
			duplicates removed.
	@example	
		R.union({1, 2, 3}, {2, 3, 4}) --> {1, 2, 3, 4}
]]
R.union = _curry2(R.pipe(_concat, R.uniq))

--[[
	Combines two lists into a set (i.e. no duplicates) composed of the elements
	of each list. Duplication is determined according to the value returned by
	applying the supplied predicate to two list elements.
	
	@func
	@category Array
	@sig (a -> a -> Boolean) -> [*] -> [*] -> [*]
	@param {Function} pred A predicate used to test whether two items are equal.
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The first and second lists concatenated, with
			duplicates removed.
	@see R.union
	@example	
		local l1 = {{a = 1}, {a = 2}}
		local l2 = {{a = 1}, {a = 4}}
		R.unionWith(R.eqBy(R.prop('a')), l1, l2) --> {{a = 1}, {a = 2}, {a = 4}}
]]
R.unionWith = _curry3(function(pred, list1, list2)
	return R.uniqWith(pred, _concat(list1, list2))
end)

--[[
	Combines two lists into a set (i.e. no duplicates) composed of those
	elements common to both lists.
	
	@func
	@category Array
	@sig [*] -> [*] -> [*]
	@param {Array} list1 The first list.
	@param {Array} list2 The second list.
	@return {Array} The list of elements found in both `list1` and `list2`.
	@see R.innerJoin
	@example	
		R.intersection({1,2,3,4}, {7,6,5,4,3}) --> {3, 4}
]]
R.intersection = _curry2(function(list1, list2)
	local lookupList, filteredList
	if #list1 > #list2 then
		lookupList = list1
		filteredList = list2
	else
		lookupList = list2
		filteredList = list1
	end
	return R.uniq(_filter(R.contains(R.__, lookupList), filteredList))
end)

--[[
	Returns a new copy of the array with the element at the provided index
	replaced with the given value.
	
	@func
	@category Array
	@sig Number -> a -> [a] -> [a]
	@param {Number} idx The index to update.
	@param {*} x The value to exist at the given index of the returned array.
	@param {Array|Arguments} list The source array-like object to be updated.
	@return {Array} A copy of `list` with the value at index `idx` replaced with `x`.
	@see R.adjust
	@example	
		R.update(2, 11, {0, 1, 2})     --> {0, 11, 2}
		R.update(2)(11)({0, 1, 2})     --> {0, 11, 2}
		 
	@symb R.update(-1, a, [b, c]) = [b, a]
	@symb R.update(0, a, [b, c]) = [a, c]
	@symb R.update(1, a, [b, c]) = [b, a]
]]
R.update = _curry3(function (idx, x, list)
	return R.adjust(R.always(x), idx, list)
end)

--[[
	Shorthand for `R.chain(R.identity)`, which removes one level of nesting from
	any [Chain](https:--github.com/fantasyland/fantasy-land#chain).
	
	@func
	@category Array
	@sig Chain c => c (c a) -> c a
	@param {*} list
	@return {*}
	@see R.flatten, R.chain
	@example	
		R.unnest({1, {2}, {{3}}}) --> {1, 2, {3}}
		R.unnest({{1, 2}, {3, 4}, {5, 6}}) --> {1, 2, 3, 4, 5, 6}
]]
R.unnest = R.chain(_identity)

--[[
	Returns a new list without values in the first argument.
	[`R.equals`](#equals) is used to determine equality.
		
	@func
	@category Array
	@sig [a] -> [a] -> [a]
	@param {Array} list1 The values to be removed from `list2`.
	@param {Array} list2 The array to remove values from.
	@return {Array} The new array without values in `list1`.
	@see R.difference
	@example	
		R.without({1, 2}, {1, 2, 1, 3, 4}) --> {3, 4}
]]
R.without = _curry2(function (xs, list)
	return R.reject(R.contains(R.__, xs), list)
end)

--[[
	Creates a new list out of the two supplied by creating each possible pair
	from the lists.
	
	@func
	@category Array
	@sig [a] -> [b] -> [ [a,b] ] 
	@param {Array} as The first list.
	@param {Array} bs The second list.
	@return {Array} The list made by combining each possible pair from
			`as` and `bs` into pairs (`[a, b]`).
	@example	
		R.xprod({1, 2}, {'a', 'b'}) --> {{1, 'a'}, {1, 'b'}, {2, 'a'}, {2, 'b'}}

	@symb R.xprod([a, b], [c, d]) = {{a, c], [a, d], [b, c], [b, d] ]
]]
R.xprod = _curry2(function(a, b)
	local idx = 1
	local ilen = #a
	local j
	local jlen = #b
	local result = {}
	while idx <= ilen do
		j = 1
		while j <= jlen do
			result[#result + 1] = {
				a[idx],
				b[j]
			}
			j = j + 1
		end
		idx = idx + 1
	end
	return result
end)

--[[
	Creates a new list out of the two supplied by pairing up equally-positioned
	items from both lists. The returned list is truncated to the length of the
	shorter of the two input lists.
	Note: `zip` is equivalent to `zipWith(function(a, b) return {a, b} end)`.
	
	@func
	@category Array
	@sig [a] -> [b] -> [ [a,b] ]
	@param {Array} list1 The first array to consider.
	@param {Array} list2 The second array to consider.
	@return {Array} The list made by pairing up same-indexed elements of `list1` and `list2`.
	@example	
		R.zip({1, 2, 3}, {'a', 'b', 'c'}) --> {{1, 'a'}, {2, 'b'}, {3, 'c'}}

	@symb R.zip([a, b, c], [d, e, f]) = [ [a, d], [b, e], [c, f] ]
]]
R.zip = _curry2(function(a, b)
	local rv = {}
	local idx = 1
	local len = math.min(#a, #b)
	while idx <= len do
		rv[idx] = {
			a[idx],
			b[idx]
		}
		idx = idx + 1
	end
	return rv
end)

--[[
	Creates a new object out of a list of keys and a list of values.
	Key/value pairing is truncated to the length of the shorter of the two lists.
	Note: `zipObj` is equivalent to `pipe(zipWith(pair), fromPairs)`.
	
	@func
	@category Array
	@sig [String] -> [*] -> {String: *}
	@param {Array} keys The array that will be properties on the output object.
	@param {Array} values The list of values on the output object.
	@return {Object} The object made by pairing up same-indexed elements of `keys` and `values`.
	@example	
		R.zipObj({'a', 'b', 'c'}, {1, 2, 3}) --> {a = 1, b = 2, c = 3}
]]
R.zipObj = _curry2(function(keys, values)
	local idx = 1
	local len = math.min(#keys, #values)
	local out = {}
	while idx <= len do
		out[keys[idx]] = values[idx]
		idx = idx + 1
	end
	return out
end)

--[[
	Creates a new list out of the two supplied by applying the function to each
	equally-positioned pair in the lists. The returned list is truncated to the
	length of the shorter of the two input lists.
	
	@func
	@category Array
	@sig (a,b -> c) -> [a] -> [b] -> [c]
	@param {Function} fn The function used to combine the two elements into one value.
	@param {Array} list1 The first array to consider.
	@param {Array} list2 The second array to consider.
	@return {Array} The list made by combining same-indexed elements of `list1` and `list2`
			using `fn`.
	@example	
		local f = function(x, y) 
			-- ...
		end	
		R.zipWith(f, {1, 2, 3}, {'a', 'b', 'c'})
		--> {f(1, 'a'), f(2, 'b'), f(3, 'c')}
		
	@symb R.zipWith(fn, [a, b, c], [d, e, f]) = [fn(a, d), fn(b, e), fn(c, f)]
]]
R.zipWith = _curry3(function(fn, a, b)
	local rv = {}
	local idx = 1
	local len = math.min(#a, #b)
	while idx <= len do
		rv[idx] = fn(a[idx], b[idx])
		idx = idx + 1
	end
	return rv
end)

-- ==================================================
-- ================ Object Functions ================
-- ==================================================
--[[
	Makes a shallow clone of an object, setting or overriding the specified
	property with the given value. Note that this copies and flattens prototype
	properties onto the new object as well. All non-primitive properties are
	copied by reference.
	
	@func
	@category Object
	@category Array
	@sig String -> a -> {k: v} -> {k: v}
	@param {String} prop The property name to set
	@param {*} val The new value
	@param {Object} obj The object to clone
	@return {Object} A new object equivalent to the original except for the changed property.
	@see R.dissoc
	@example
		R.assoc('c', 3, {a = 1, b = 2}) --> {a = 1, b = 2, c = 3}
]]
R.assoc = _curry3(function(prop, val, obj)
	local result = {}
	for p, k in pairs(obj) do
		result[p] = k
	end
	result[prop] = val
	return result
end)

--[[
	Makes a shallow clone of an object, setting or overriding the nodes required
	to create the given path, and placing the specific value at the tail end of
	that path. Note that this copies and flattens prototype properties onto the
	new object as well. All non-primitive properties are copied by reference.
	
	@func
	@category Object
	@category Array
	@typedefn Idx = String | Int
	@sig [Idx] -> a -> {a} -> {a}
	@param {Array} path the path to set
	@param {*} val The new value
	@param {Object} obj The object to clone
	@return {Object} A new object equivalent to the original except along the specified path.
	@see R.dissocPath
	@example	
		R.assocPath({'a', 'b', 'c'}, 42, {a = {b = {c = 0}}}) --> {a = {b = {c = 42}}}
		-- Any missing or non-object keys in path will be overridden
		R.assocPath({'a', 'b', 'c'}, 42, {a = 5}) --> {a = {b = {c = 42}}}
]]
R.assocPath = _curry3(function(path, val, obj)
	if #path == 0 then
		return val
	end
	local idx = path[1]
	if #path > 1 then
		local nextObj = not R.isNil(obj) and _has(idx, obj) and _isTable(obj[idx]) and obj[idx] or {}
		val = R.assocPath(R.slice(2, #path + 1, path), val, nextObj)
	end
	if _isInteger(idx) and _isArray(obj) then
		local arr = R.concat({}, obj)
		arr[idx] = val
		return arr
	else
		return R.assoc(idx, val, obj)
	end
end)

--[[
	Creates a deep copy of the value which may contain (nested) `Array`s and
	`Object`s, `Number`s, `String`s, `Boolean`s and `Date`s. `Function`s are
	assigned by reference rather than copied
	
	Dispatches to a `clone` method if present.
	
	@func
	@category Object
	@sig {*} -> {*}
	@param {*} value The object or array to clone
	@return {*} A deeply cloned copy of `val`
	@example	
		local objects = {{}, {}, {}}
		local objectsClone = R.clone(objects)
		objects == objectsClone --> false
		objects[1] == objectsClone[1] --> false
]]
R.clone = _curry1(function(value)
	return _clone(value)
end)

--[[
	Returns a new object that does not contain a `prop` property.
	All non-primitive properties are copied by reference.
	
	@func
	@category Object
	@category Array
	@sig String -> {k: v} -> {k: v}
	@param {String} prop The name of the property to dissociate
	@param {Object} obj The object to clone
	@return {Object} A new object equivalent to the original but without the specified property
	@see R.assoc
	@example	
		R.dissoc('b', {a = 1, b = 2, c = 3}) --> {a = 1, c = 3}
]]
R.dissoc = _curry2(function(prop, obj)
	local result = {}
	if _isArray(obj) then
		for p,v in ipairs(obj) do
			result[p] = v
		end
	else		
		for p,v in pairs(obj) do
			result[p] = v
		end		
	end
	result[prop] = nil		
	return result
end)

--[[
	Makes a shallow clone of an object, omitting the property at the given path.
	Note that this copies and flattens prototype properties onto the new object
	as well. All non-primitive properties are copied by reference.
	
	@func
	@category Object
	@category Array
	@typedefn Idx = String | Int
	@sig [Idx] -> {k: v} -> {k: v}
	@param {Array} path The path to the value to omit
	@param {Object} obj The object to clone
	@return {Object} A new object without the property at path
	@see R.assocPath
	@example	
		R.dissocPath({'a', 'b', 'c'}, {a = {b = {c = 42}}}) --> {a = {b = {}}}
]]
R.dissocPath = _curry2(function(path, obj)
	if #path == 0 then
		return obj
	elseif #path == 1 then
		return R.dissoc(path[1], obj)
	else
		local head = path[1]
		local tail = R.slice(2, #path + 1, path)
		if obj[head] == nil then
			return obj
		else
			return R.assoc(head, R.dissocPath(tail, obj[head]), obj)
		end
	end
end)

--[[
	Creates a new object from a list key-value pairs. If a key appears in
	multiple pairs, the rightmost pair is included in the object.
	
	@func
	@category Object
	@sig {{k,v}} -> {k: v}
	@param {Array} pairs An array of two-element arrays that will be the keys and values of the output object.
	@return {Object} The object made by pairing up `keys` and `values`.
	@see R.toPairs, R.pair
	@example	
		R.fromPairs({{'a', 1}, {'b', 2}, {'c', 3}}) --> {a = 1, b = 2, c = 3}
]]
R.fromPairs = _curry1(function(pairs)
	local result = {}
	local idx = 1
	while idx <= #pairs do
		result[pairs[idx][1]] = pairs[idx][2]
		idx = idx + 1
	end
	return result
end)

--[[
	Returns whether or not an object has an key with the specified name
	
	@func
	@category Object
	@sig s -> {s: x} -> Boolean
	@param {String} prop The name of the property to check for.
	@param {Object} obj The object to query.
	@return {Boolean} Whether the property exists.
	@example
		local hasName = R.has('name')
		hasName({name = 'alice'})   --> true
		hasName({name = 'bob'})     --> true
		hasName({})                --> false
	
		local point = {x = 0, y = 0}
		local pointHas = R.has(R.__, point)
		pointHas('x')  --> true
		pointHas('y')  --> true
		pointHas('z')  --> false
]]
R.has = _curry2(_has)

--[[
	Same as [`R.invertObj`](#invertObj), however this accounts for objects with
	duplicate values by putting the values into an array.
	
	@func
	@category Object
	@sig {s: x} -> {x: [ s, ... ]}
	@param {Object} obj The object or array to invert
	@return {Object} out A new object with keys in an array.
	@see R.invertObj
	@example	
		local raceResultsByFirstName = {
			first = 'alice',
			second = 'jake',
			third = 'alice',
		}
		R.invert(raceResultsByFirstName) --> { 'alice': {'first', 'third'}, 'jake':{'second'} }
]]
R.invert = _curry1(function(obj)	
	local out = {}
	for k,v in pairs(obj) do
		v = tostring(v)		
		if _has(v, out) then
			local len = R.length(out[v])
			out[v][len + 1] = k
		else
			out[v] = {k}
		end
	end
	return out
end)

--[[
	Returns a new object with the keys of the given object as values, and the
	values of the given object, which are coerced to strings, as keys. Note
	that the last key found is preferred when handling the same value.
	
	@func
	@category Object
	@sig {s: x} -> {x: s}
	@param {Object} obj The object or array to invert
	@return {Object} out A new object
	@see R.invert
	@example
		local raceResults = {
			first = 'alice',
			second = 'jake'
		}
		R.invertObj(raceResults) --> { 'alice' = 'first', 'jake' = 'second' }
	
		-- Alternatively:
		local raceResults = {'alice', 'jake'}
		R.invertObj(raceResults) --> { alice = 1, jake = 2 }
]]
R.invertObj = _curry1(function(obj)
	local out = {}
	if _isArray(obj) then		
		for k,v in ipairs(obj) do			
			v = tostring(v)
			out[v] = k
		end
	else
		for k,v in pairs(obj) do	
			v = tostring(v)
			out[v] = k
		end
	end
	return out
end)

--[[
	Returns a list containing the names of all the key of the supplied object.	
	
	@func
	@category Object
	@sig {k: v} -> [k]
	@param {Object} obj The object to extract properties from
	@return {Array} An array of the object's keys.
	@see R.values, R.sortedKeys
	@example
		R.keys({a = 1, b = 2, c = 3}) --> {'a', 'b', 'c'}
]]
R.keys = _curry1(function(obj)
	if not R.isTable(obj) then return {} end
	local keys = {}
	for k, v in pairs(obj)	do
		table.insert(keys, k)
	end
	return keys
end)

--[[
	Create a new object with the keys of the first object merged with
	the keys of the second object. If a key exists in both objects,
	the value from the second object will be used.
	
	@func
	@category Object
	@sig {k: v} -> {k: v} -> {k: v}
	@param {Object} l
	@param {Object} r
	@return {Object}
	@see R.mergeDeepRight, R.mergeWith, R.mergeWithKey
	@example	
		R.merge({ 'name' = 'fred', 'age': 10 }, { 'age': 40 }) --> { 'name' = 'fred', 'age': 40 }	
		local resetToDefault = R.merge(R.__, {x: 0})
		resetToDefault({x: 5, y: 2}) --> {x: 0, y: 2}
	@symb R.merge({ x: 1, y: 2 }, { y: 5, z: 3 }) = { x: 1, y: 5, z: 3 }
]]
R.merge = _curry2(function(...)
	return _assign({}, ...)
end)

--[[
	Merges a list of objects together into one object.
	
	@func
	@category Object
	@sig [{k: v}] -> {k: v}
	@param {Array} list An array of objects
	@return {Object} A merged object.
	@see R.reduce
	@example	
		R.mergeAll({{foo = 1},{bar = 2},{baz = 3}}) --> {foo:1,bar:2,baz:3}
		R.mergeAll({{foo = 1},{foo = 2},{baz = 3}}) --> {foo:2,bar:2}
	@symb R.mergeAll([{ x: 1 }, { y: 2 }, { z: 3 }]) = { x: 1, y: 2, z: 3 }
]]
R.mergeAll = _curry1(function(list)
	return _assign({}, unpack(list))
end)

--[[
	Creates a new object with the keys of the two provided objects.
	If a key exists in both objects:
	- and both associated values are also objects then the values will be
	recursively merged.
	- otherwise the provided function is applied to the key and associated values
	using the resulting value as the new value associated with the key.
	If a key only exists in one object, the value will be associated with the key
	of the resulting object.
	
	@func
	@category Object
	@sig (String -> a -> a -> a) -> {a} -> {a} -> {a}
	@param {Function} fn
	@param {Object} lObj
	@param {Object} rObj
	@return {Object}
	@see R.mergeWithKey, R.mergeDeep, R.mergeDeepWith
	@example	
		local concatValues = function(k, l, r)
			return k == 'values' and R.concat(l, r) or r
		end
		R.mergeDeepWithKey(concatValues,
							{ a = true, c = { thing = 'foo', values = {10, 20} }},
							{ b = true, c = { thing = 'bar', values = {15, 35} }})
		--> {a=true, b=true, c={thing="bar", values={10, 20, 15, 35}}}
]]
R.mergeDeepWithKey = _curry3(function(fn, lObj, rObj)
	return R.mergeWithKey(function (k, lVal, rVal)
		if _isObject(lVal) and _isObject(rVal) then
			return R.mergeDeepWithKey(fn, lVal, rVal)
		else
			return fn(k, lVal, rVal)
		end
	end, lObj, rObj)
end)

--[[
	Creates a new object with the keys of the first object merged with
	the keys of the second object. If a key exists in both objects:
	- and both values are objects, the two values will be recursively merged
	- otherwise the value from the first object will be used.
	
	@func
	@category Object
	@sig {a} -> {a} -> {a}
	@param {Object} lObj
	@param {Object} rObj
	@return {Object}
	@see R.merge, R.mergeDeepRight, R.mergeDeepWith, R.mergeDeepWithKey
	@example
		R.mergeDeepLeft({ name = 'fred', age = 10, contact = { email = 'moo@example.com' }},
						{ age = 40, contact = { email = 'baa@example.com' }})
		--> {age=10, contact={email="moo@example.com"}, name="fred"}
]]
R.mergeDeepLeft = _curry2(function(lObj, rObj)
	return R.mergeDeepWithKey(function (k, lVal, rVal)
		return lVal
	end, lObj, rObj)
end)

--[[
	Creates a new object with the keys of the first object merged with
	the keys of the second object. If a key exists in both objects:
	- and both values are objects, the two values will be recursively merged
	- otherwise the value from the second object will be used.
	
	@func
	@category Object
	@sig {a} -> {a} -> {a}
	@param {Object} lObj
	@param {Object} rObj
	@return {Object}
	@see R.merge, R.mergeDeepLeft, R.mergeDeepWith, R.mergeDeepWithKey
	@example
		R.mergeDeepRight({ name = 'fred', age = 10, contact = { email = 'moo@example.com' }},
						{ age = 40, contact = { email = 'baa@example.com' }})
		--> {age=40, contact={email="baa@example.com"}, name="fred"}
]]
R.mergeDeepRight = _curry2(function (lObj, rObj)
	return R.mergeDeepWithKey(function (k, lVal, rVal) 
		return rVal
	end, lObj, rObj)
end)

--[[
	Creates a new object with the keys of the two provided objects.
	If a key exists in both objects:
	- and both associated values are also objects then the values will be
	recursively merged.
	- otherwise the provided function is applied to associated values using the
	resulting value as the new value associated with the key.
	If a key only exists in one object, the value will be associated with the key
	of the resulting object.
	
	@func
	@category Object
	@sig (a -> a -> a) -> {a} -> {a} -> {a}
	@param {Function} fn
	@param {Object} lObj
	@param {Object} rObj
	@return {Object}
	@see R.mergeWith, R.mergeDeep, R.mergeDeepWithKey
	@example	
		v = R.mergeDeepWith(R.concat,
				{ a = true, c = { values = {10, 20} }},
				{ b = true, c = { values = {15, 35} }})
		--> {a=true, b=true, c={values={10, 20, 15, 35}}}
]]
R.mergeDeepWith = _curry3(function(fn, lObj, rObj)
	return R.mergeDeepWithKey(function (k, lVal, rVal)
		return fn(lVal, rVal)
	end, lObj, rObj)
end)


--[[
	Creates a new object with the keys of the two provided objects. If
	a key exists in both objects, the provided function is applied to the values
	associated with the key in each object, with the result being used as the
	value associated with the key in the returned object.
	
	@func
	@category Object
	@sig (a -> a -> a) -> {a} -> {a} -> {a}
	@param {Function} fn
	@param {Object} l
	@param {Object} r
	@return {Object}
	@see R.mergeDeepWith, R.merge, R.mergeWithKey
	@example	
		R.mergeWith(R.concat,
			{ a = true, values = {10, 20} },
			{ b = true, values = {15, 35} })
		--> {a=true, b=true, values = {10, 20, 15, 35}}
]]
R.mergeWith = _curry3(function(fn, l, r)
	return R.mergeWithKey(function (_, _l, _r)
		return fn(_l, _r)
	end, l, r)
end)

--[[
	Creates a new object with the keys of the two provided objects. If
	a key exists in both objects, the provided function is applied to the key
	and the values associated with the key in each object, with the result being
	used as the value associated with the key in the returned object.
	
	@func
	@category Object
	@sig (String -> a -> a -> a) -> {a} -> {a} -> {a}
	@param {Function} fn
	@param {Object} l
	@param {Object} r
	@return {Object}
	@see R.mergeDeepWithKey, R.merge, R.mergeWith
	@example	
		local concatValues = function(k, l, r)
			return k == 'values' and R.concat(l, r) or r
		end
		v = R.mergeWithKey(concatValues,
			{ a = true, thing = 'foo', values = {10, 20} },
			{ b = true, thing = 'bar', values = {15, 35} })
		--> {a=true, b=true, thing="bar", values={10, 20, 15, 35}}
		
	@symb R.mergeWithKey(f, { x: 1, y: 2 }, { y: 5, z: 3 }) = { x: 1, y: f('y', 2, 5), z: 3 }
]]
R.mergeWithKey = _curry3(function(fn, l, r)
	local result = {}
	local k
	for k,v in pairs(l) do
		result[k] = _has(k, r) and fn(k, v, r[k]) or v
	end
	for k,v in pairs(r) do
		if not _has(k, result) then
			result[k] = v
		end
	end
	return result
end)

--[[
	Returns `true` if no elements of the list match the predicate, `false`
	otherwise.
	
	Dispatches to the `any` method of the second argument, if present.
	
	@func
	@category Array
	@sig (a -> Boolean) -> [a] -> Boolean
	@param {Function} fn The predicate function.
	@param {Array} list The array to consider.
	@return {Boolean} `true` if the predicate is not satisfied by every element, `false` otherwise.
	@see R.all, R.any
	@example	
		local isEven = n => n % 2 === 0
	
		R.none(isEven, {1, 3, 5, 7, 9, 11}) --> true
		R.none(isEven, {1, 3, 5, 7, 8, 11}) --> false
]]
R.none = _curry2(_complement(R.any))

--[[
	Creates an object containing a single key:value pair.
	
	@func
	@category Object
	@sig String -> a -> {String:a}
	@param {String} key
	@param {*} val
	@return {Object}
	@see R.pair
	@example	
		local matchPhrases = R.compose(
			R.objOf('must'),
			R.map(R.objOf('match_phrase'))
		)
		matchPhrases({'foo', 'bar', 'baz'}) --> {must={{match_phrase="foo"}, {match_phrase="bar"}, {match_phrase="baz"}}}
]]
R.objOf = _curry2(function(key, val)
	local obj = {}
	obj[key] = val
	return obj
end)

--[[
	Returns a partial copy of an object omitting the keys specified.
	
	@func
	@category Object
	@sig [String] -> {String: *} -> {String: *}
	@param {Array} names an array of String property names to omit from the new object
	@param {Object} obj The object to copy from
	@return {Object} A new object with properties from `names` not on it.
	@see R.pick
	@example	
		R.omit({'a', 'd'}, {a = 1, b = 2, c = 3, d = 4}) --> {b = 2, c = 3}
]]
R.omit = _curry2(function(names, obj)
	local result = {}
	if not _isObject(obj) then return result end
	for k,v in pairs(obj) do
		if not _contains(k, names) then
			result[k] = obj[k]
		end
	end
	return result
end)

--[[
	Retrieve the value at a given path.
	
	@func
	@category Object
	@typedefn Idx = String | Int
	@sig [Idx] -> {a} -> a | nil
	@param {Array} path The path to use.
	@param {Object} obj The object to retrieve the nested property from.
	@return {*} The data at `path`.
	@see R.prop
	@example
		R.path({'a', 'b'}, {a = {b = 2}}) --> 2
		R.path({'a', 'b'}, {c = {b = 2}}) --> nil
]]
R.path = _curry2(function(paths, obj)
	local val = obj
	local idx = 1
	
	if R.isEmpty(obj) then return nil end

	while idx <= #paths do
		if val == nil then
			return nil
		end

		local cur_path = paths[idx]		
		if _isObject(val) then
			val = val[cur_path]
		elseif _isArray(val) or _isString(val) then
			if not _isInteger(cur_path) then
				return nil
			end
			val = _get(cur_path, val)
		else
			return nil
		end			
		idx = idx + 1
	end
	return val
end)

--[[
	Determines whether a nested path on an object has a specific value, in
	[`R.equals`](#equals) terms. Most likely used to filter a list.
	
	@func
	@category Object
	@typedefn Idx = String | Int
	@sig [Idx] -> a -> {a} -> Boolean
	@param {Array} path The path of the nested property to use
	@param {*} val The value to compare the nested property with
	@param {Object} obj The object to check the nested property in
	@return {Boolean} `true` if the value equals the nested object property,
			`false` otherwise.
	@example	
		local user1 = { address = { zipCode = 90210 } }
		local user2 = { address = { zipCode = 55555 } }
		local user3 = { name = 'Bob' }
		local users = { user1, user2, user3 }
		local isFamous = R.pathEq({'address', 'zipCode'}, 90210)
		R.filter(isFamous, users) --> {{address={zipCode=90210}}}
]]
R.pathEq = _curry3(function(_path, val, obj)
	return R.equals(R.path(_path, obj), val)
end)

--[[
	If the given, non-null object has a value at the given path, returns the
	value at that path. Otherwise returns the provided default value.
	
	@func
	@category Object
	@typedefn Idx = String | Int
	@sig a -> [Idx] -> {a} -> a
	@param {*} d The default value.
	@param {Array} p The path to use.
	@param {Object} obj The object to retrieve the nested property from.
	@return {*} The data at `path` of the supplied object or the default value.
	@example	
		R.pathOr('N/A', {'a', 'b'}, {a = {b = 2}}) --> 2
		R.pathOr('N/A', {'a', 'b'}, {c = {b = 2}}) --> "N/A"
]]
R.pathOr = _curry3(function(d, p, obj)
	return R.defaultTo(d, R.path(p, obj))
end)

--[[
	Returns `true` if the specified object property at given path satisfies the
	given predicate `false` otherwise.
	
	@func
	@category Object
	@typedefn Idx = String | Int
	@sig (a -> Boolean) -> [Idx] -> {a} -> Boolean
	@param {Function} pred
	@param {Array} propPath
	@param {*} obj
	@return {Boolean}
	@see R.propSatisfies, R.path
	@example	
		R.pathSatisfies(y => y > 0, {'x', 'y'}, {x = {y = 2}}) --> true
]]
R.pathSatisfies = _curry3(function(pred, propPath, obj)
	return #propPath > 0 and pred(R.path(propPath, obj))
end)

--[[
	Returns a partial copy of an object containing only the keys specified. If
	the key does not exist, the property is ignored.
	
	@func
	@category Object
	@sig [k] -> {k: v} -> {k: v}
	@param {Array} names an array of String property names to copy onto a new object
	@param {Object} obj The object to copy from
	@return {Object} A new object with only properties from `names` on it.
	@see R.omit, R.props
	@example	
		R.pick({'a', 'd'}, {a = 1, b = 2, c = 3, d = 4}) --> {a = 1, d = 4}
		R.pick({'a', 'e', 'f'}, {a = 1, b = 2, c = 3, d = 4}) --> {a = 1}
]]
R.pick = _curry2(function(names, obj)
	local result = {}
	local idx = 1
	while idx <= #names do
		if _has(names[idx], obj) then
			result[names[idx]] = obj[names[idx]]
		end
		idx = idx + 1
	end
	return result
end)

--[[
	Similar to `pick` except that this one includes a `key: undefined` pair for
	properties that don't exist.
	
	@func
	@since v0.2.0
	@category Object
	@sig [k] -> {k: v} -> {k: v}
	@param {Array} names an array of String property names to copy onto a new object
	@param {Object} obj The object to copy from
	@return {Object} A new object with only properties from `names` on it.
	@see R.pick
	@example	
		R.pickAll({'a', 'd'}, {a = 1, b = 2, c = 3, d = 4}) --> {a = 1, d = 4}
		R.pickAll({'a', 'e', 'f'}, {a = 1, b = 2, c = 3, d = 4}) --> {a = 1}
]]
R.pickAll = _curry2(function(names, obj)
	local result = {}
	local idx = 1
	local len = #names
	while idx <= len do
		local name = names[idx]
		result[name] = obj[name]
		idx = idx + 1
	end
	return result
end)

--[[
	Returns a partial copy of an object containing only the keys that satisfy
	the supplied predicate.
	
	@func
	@category Object
	@sig (v, k -> Boolean) -> {k: v} -> {k: v}
	@param {Function} pred A predicate to determine whether or not a key
		should be included on the output object.
	@param {Object} obj The object to copy from
	@return {Object} A new object with only properties that satisfy `pred`
			on it.
	@see R.pick, R.filter
	@example	
		local isUpperCase = R.compose(R.safeEquals, R.unpack, R.mirrorBy(R.toUpper), R.second)		
		R.pickBy(isUpperCase, {a = 1, b = 2, A = 3, B = 4}) --> {A = 3, B = 4}
]]
R.pickBy = _curry2(function(test, obj)
	local result = {}	
	for prop,v in pairs(obj) do
		if test(v, prop, obj) then
			result[prop] = obj[prop]
		end
	end
	return result
end)

--[[
	Returns a new list by plucking the same named property off all objects in
	the list supplied.	
	
	@func
	@category Object
	@category Array	
	@sig Functor f => k -> f {k: v} -> f v
	@param {Number|String} key The key name to pluck off of each object.
	@param {Array} f The array or functor to consider.
	@return {Array} The list of values for the given key.
	@see R.props
	@example
		R.pluck('a')({{a = 1}, {a = 2}}) --> {1, 2}
		R.pluck(0)({{1, 2}, {3, 4}}) --> {1, 3}
		R.pluck('val', {a = {val = 3}, b = {val = 5}}) --> {a = 3, b = 5}

	@symb R.pluck('x', [{x: 1, y: 2}, {x: 3, y: 4}, {x: 5, y: 6}]) = [1, 3, 5]
	@symb R.pluck(0, [ [1, 2], [3, 4], [5, 6] ]) = [1, 3, 5]
]]
R.pluck = _curry2(function(p, list)
	return _mapObject(R.prop(p), list)
end)

--[[
	Reasonable analog to SQL `select` statement.
	
	@func
	@category Object
	@category Util
	@sig [k] -> [{k: v}] -> [{k: v}]
	@param {Array} props The property names to project
	@param {Array} objs The objects to query
	@return {Array} An array of objects with just the `props` properties.
	@example	
		local abby = {name = 'Abby', age = 7, hair = 'blond', grade = 2}
		local fred = {name = 'Fred', age = 12, hair = 'brown', grade = 7}
		local kids = {abby, fred}
		R.project({'name', 'grade'}, kids) --> {{name = 'Abby', grade = 2}, {name = 'Fred', grade = 7}}
]]
-- passing `identity` gives correct arity
R.project = R.useWith(R.map, {
	R.pickAll,
	R.identity
})

--[[
	Returns a function that when supplied an object returns the indicated
	property of that object, if it exists.
	
	@func
	@category Object
	@sig s -> {s: a} -> a | nil
	@param {String} p The property name
	@param {Object} obj The object to query
	@return {*} The value at `obj.p`.
	@see R.path
	@example	
		R.prop('x', {x = 100}) --> 100
		R.prop('x', {}) --> nil
		R.prop(1, {'a', 'b'}) --> 'a'
		R.prop(-9, {'a', 'b'}) --> nil
]]
R.prop = _curry2(function(p, obj)
	return obj[p]
end)

--[[
	Returns `true` if the specified object property is of the given type
	`false` otherwise.

	@func
	@category Object
	@sig Type -> String -> Object -> Boolean
	@param {Function} type
	@param {String} name
	@param {*} obj
	@return {Boolean}
	@see R.is, R.propSatisfies
	@example	
		R.propIs(R.NUMBER, 'x', {x = 1, y = 2})  --> true
		R.propIs(R.NUMBER, 'x', {x = 'foo'})    --> false
		R.propIs(R.NUMBER, 'x', {})            --> false
]]
R.propIs = _curry3(function(t, name, obj)
	return R.is(t, obj[name])
end)

--[[
	If the given, non-null object has a key with the specified name,
	returns the value of that property. Otherwise returns the provided default
	value.
	
	@func
	@category Object
	@sig a -> String -> Object -> a
	@param {*} val The default value.
	@param {String} p The name of the property to return.
	@param {Object} obj The object to query.
	@return {*} The value of given property of the supplied object or the default value.
	@example	
		local alice = {
			name = 'ALICE',
			age = 101
		}
		local favorite = R.prop('favoriteLibrary')
		local favoriteWithDefault = R.propOr('Lamda', 'favoriteLibrary')
	
		favorite(alice)  --> nil
		favoriteWithDefault(alice)  --> 'Lamda'
]]
R.propOr = _curry3(function(val, p, obj)
    return _has(p, obj) and obj[p] or val
end)

--[[
	Returns `true` if the specified object property satisfies the given
	predicate `false` otherwise.
	
	@func
	@category Object
	@sig (a -> Boolean) -> String -> {String: a} -> Boolean
	@param {Function} pred
	@param {String} name
	@param {*} obj
	@return {Boolean}
	@see R.propEq, R.propIs
	@example	
		R.propSatisfies(R.lt(0), 'x', {x = 1, y = 2}) --> true
]]
R.propSatisfies = _curry3(function(pred, name, obj)
	local r = pred(obj[name])
	return not _isFunction(r) and r or false
end)

--[[
	Acts as multiple `prop`: array of keys in, array of values out. Preserves
	order.
	
	@func
	@category Object
	@sig [k] -> {k: v} -> [v]
	@param {Array} ps The property names to fetch
	@param {Object} obj The object to query
	@return {Array} The corresponding values or partially applied function.
	@example	
		R.props({'x', 'y'}, {x = 1, y = 2}) --> {1, 2}
		R.props({'c', 'a', 'b'}, {b = 2, a = 1}) --> {nil, 1, 2}
	
		local fullName = R.compose(R.join(' '), R.props({'first', 'last'}))
		fullName({last = 'Bullet-Tooth', age = 33, first = 'Tony'}) --> 'Tony Bullet-Tooth'
]]
R.props = _curry2(function(ps, obj)
	local len = #ps
	local out = {}
	local idx = 1
	while idx <= len do
		out[idx] = obj[ps[idx]]
		idx = idx + 1
	end
	return out
end)

--[[
	Returns `true` if the specified object property is equal, in
	[`R.equals`](#equals) terms, to the given value `false` otherwise.
	
	@func
	@category Object
	@sig String -> a -> Object -> Boolean
	@param {String} name
	@param {*} val
	@param {*} obj
	@return {Boolean}
	@see R.equals, R.propSatisfies
	@example	
		local abby = {name = 'Abby', age = 7, hair = 'blond'}
		local fred = {name = 'Fred', age = 12, hair = 'brown'}
		local rusty = {name = 'Rusty', age = 10, hair = 'brown'}
		local alois = {name = 'Alois', age = 15, disposition = 'surly'}
		local kids = {abby, fred, rusty, alois}
		local hasBrownHair = R.propEq('hair', 'brown')
		R.filter(hasBrownHair, kids) --> {fred, rusty}
]]
R.propEq = _curry3(function(name, val, obj)
	return R.safeEquals(val, obj[name])
end)

--[[
	Returns a sorted list containing the names of all the enumerable keys of
	the supplied object.
	
	@func
	@category Object
	@sig {k: v} -> [k]
	@param {Object} obj The object to extract properties from
	@return {Array} An array of the object's keys.
	@see R.keys
	@example
		R.sortedKeys({a = 1, x = 2, c = 3}) --> {'a', 'b', 'x'}
]]
R.sortedKeys = _curry1(function(obj)
	if not R.isTable(obj) then return {} end
	local keys = {}
	for k, v in pairs(obj)	do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end)
--[[
	@alias R.sortedKeys
]]
R.skeys = R.sortedKeys

--[[
	Converts an object into an array of key, value arrays. 
	Note that the order of the output array is not guaranteed.
	
	@func
	@category Object
	@typedefn Key = String | Int
	@sig {Key: *} -> [ [Key,*] ]
	@param {Object} obj The object to extract from
	@return {Array} An array of key, value arrays from the object's keys.
	@see R.fromPairs
	@example	
		R.toPairs({a = 1, b = 2, c = 3}) --> {{"a", 1}, {"c", 3}, {"b", 2}}
]]
R.toPairs = _curry1(function(obj)
	local _p = {}
	for prop, v in pairs(obj) do
		_p[#_p + 1] = {prop, v}
	end
	return _p
end)

--[[
	Returns a list of all the enumerable keys of the supplied object.
	Note that the order of the output array is not guaranteed across different
	JS platforms.
	
	@func
	@category Object
	@sig {k: v} -> [v]
	@param {Object} obj The object to extract values from
	@return {Array} An array of the values of the object's keys.
	@see R.valuesIn, R.keys
	@example     
		R.values({a: 1, b: 2, c: 3}) --> {1, 2, 3}
]]
R.values = _curry1(function(obj)
	if not R.isTable(obj) then return {} end
	local values = {}
	for _, p in pairs(obj) do
		table.insert(values, p)
	end
	return values
end)

--[[
	Takes a spec object and a test object returns true if the test satisfies
	the spec. Each of the spec's keys must be a predicate function.
	Each predicate is applied to the value of the corresponding property of the
	test object. `where` returns true if all the predicates return true, false
	otherwise.
	
	`where` is well suited to declaratively expressing constraints for other
	functions such as [`filter`](#filter) and [`find`](#find).
	
	@func
	@category Object
	@sig {String: (* -> Boolean)} -> {String: *} -> Boolean
	@param {Object} spec
	@param {Object} testObj
	@return {Boolean}
	@example	
		-- pred :: Object -> Boolean
		local pred = R.where({
			a = R.equals('foo'),
			b = R.complement(R.equals('bar')),
			x = R.gt(R.__, 10),
			y = R.lt(R.__, 20)
		})
	
		pred({a = 'foo', b = 'xxx', x = 11, y = 19}) --> true
		pred({a = 'xxx', b = 'xxx', x = 11, y = 19}) --> false
		pred({a = 'foo', b = 'bar', x = 11, y = 19}) --> false
		pred({a = 'foo', b = 'xxx', x = 10, y = 19}) --> false
		pred({a = 'foo', b = 'xxx', x = 11, y = 20}) --> false
]]
R.where = _curry2(function(spec, testObj)
	for prop,v in pairs(spec) do
		if R.isNil(testObj[prop]) or not v(testObj[prop]) then
			return false
		end
	end
	return true
end)

--[[
	Takes a spec object and a test object returns true if the test satisfies
	the spec, false otherwise. An object satisfies the spec if, for each of the
	spec's keys, accessing that property of the object gives the same
	value (in [`R.equals`](#equals) terms) as accessing that property of the
	spec.
	
	`whereEq` is a specialization of [`where`](#where).
	
	@func
	@category Object
	@sig {String: *} -> {String: *} -> Boolean
	@param {Object} spec
	@param {Object} testObj
	@return {Boolean}
	@see R.where
	@example
		-- pred :: Object -> Boolean
		local pred = R.whereEq({a = 1, b = 2})

		pred({a = 1})              --> false
		pred({a = 1, b = 2})        --> true
		pred({a = 1, b = 2, c = 3})  --> true
		pred({a = 1, b = 1})        --> false
]]
R.whereEq = _curry2(function(spec, testObj)
	return R.where(_mapObject(R.unary(R.equals), spec), testObj)
end)

-- ==================================================
-- ================ String Functions ================
-- ==================================================
--[[
	Checks if a list ends with the provided values
	
	@func
	@category String
	@sig [a] -> Boolean
	@sig String -> Boolean
	@param {*} suffix
	@param {*} list
	@return {Boolean}
	@example	
		R.endsWith('c', 'abc')                --> true
		R.endsWith('b', 'abc')                --> false
		R.endsWith({'c'}, {'a', 'b', 'c'})    --> true
		R.endsWith({'b'}, {'a', 'b', 'c'})    --> false
]]
R.endsWith = _curry2(function (suffix, list)
	return R.equals(R.takeLast(#suffix, list), suffix)
end)

--[[
	Returns a string made by inserting the `separator` between each element and
	concatenating all the elements into a single string.
	
	@func
	@category String
	@sig String -> [a] -> String
	@param {Number|String} separator The string used to separate the elements.
	@param {Array} xs The elements to join into a string.
	@return {String} str The string made by concatenating `xs` with `separator`.
	@see R.split
	@example	
		local spacer = R.join(' ')
		spacer({'a', 2, 3.4})   --> 'a 2 3.4'
		R.join('|', {1, 2, 3})  --> '1|2|3'
]]
R.join = _curry2(function(sep, xs)
	return table.concat(R.map(tostring, xs), sep)
end)

--[[
	Tests a regular expression against a String. Note that this function will
	return an empty array when there are no matches. 
	
	@func
	@category String
	@sig String -> String -> [String | nil]
	@param {String} rx A regular expression.
	@param {String} str The string to match against
	@return {Array} The list of matches or empty array.
	@see R.test
	@example	
		R.match("[a-z]a", 'bananas') --> {"ba", "na", "na"}
		R.match("a", 'b') --> {}
]]
R.match = _curry2(function(rx, str)
	local r = {}
	for w in string.gmatch(str, rx) do
		r[#r + 1] = w
	end
	return r
end)

--[[
	Replace a substring or regex match in a string with a replacement.
	
	@func
	@category String
	@sig String|String -> String -> String -> String
	@param {String|String} pattern A regular expression or a substring to match.
	@param {String} replacement The string to replace the matches with.
	@param {String} str The String to do the search and replacement in.
	@return {String} The result.
	@example	
		R.replace('foo', 'bar', 1, 'foo foo foo') --> 'bar foo foo'
		R.replace('foo', 'bar', 0, 'foo foo foo') --> 'bar bar bar'
]]
R.replace = _curryN(4, {}, function(regex, replacement, count, str)
	if count < 1 then count = nil end
	if count == R.NIL then count = nil end
	return string.gsub(str, regex, replacement, count)
end)

--[[
	Checks if a list starts with the provided values
	
	@func
	@category String
	@sig [a] -> Boolean
	@sig String -> Boolean
	@param {*} prefix
	@param {*} list
	@return {Boolean}
	@example	
		R.startsWith('a', 'abc')                --> true
		R.startsWith('b', 'abc')                --> false
		R.startsWith({'a'}, {'a', 'b', 'c'})    --> true
		R.startsWith({'b'}, {'a', 'b', 'c'})    --> false
]]
R.startsWith = _curry2(function (prefix, list)
	return R.equals(R.take(R.size(prefix), list), prefix)
end)

--[[
	Determines whether a given string matches a given regular expression.
	
	@func
	@category String
	@sig String -> String -> Boolean
	@param {String} pattern
	@param {String} str
	@return {Boolean}
	@see R.match
	@example	
		R.test("^x", 'xyz') --> true
		R.test("^y", 'xyz') --> false
]]
R.test = _curry2(function(pattern, str)
	return string.match(str, pattern, 1) ~= nil
end)

--[[
	The lower case version of a string.
	
	@func
	@category String
	@sig String -> String
	@param {String} str The string to lower case.
	@return {String} The lower case version of `str`.
	@see R.toUpper
	@example	
		R.toLower('XYZ') --> 'xyz'
]]
R.toLower = _curry1(function(str)
	return string.lower(str)
end)

--[[
	The upper case version of a string.
	
	@func
	@category String
	@sig String -> String
	@param {String} str The string to upper case.
	@return {String} The upper case version of `str`.
	@see R.toLower
	@example	
		R.toUpper('abc') --> 'ABC'
]]
R.toUpper = _curry1(function(str)
	return string.upper(str)
end)

--[[
	Removes (strips) whitespace from both ends of the string.
	
	@func
	@category String
	@sig String -> String
	@param {String} str The string to trim.
	@return {String} Trimmed version of `str`.
	@example	
		R.trim('   xyz  ') --> 'xyz'
		R.map(R.trim, R.split(',', 'x, y, z')) --> {'x', 'y', 'z'}
]]
R.trim = _curry1(function(s)
	if not _isString(s) then
		return ""
	end
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end)
--[[
	@alias R.trim
]]
R.strip = R.trim

-- ===========================================
-- ============ Random Functions =============
-- ===========================================
--[[
	Normal stochastic algorithm | box muller algorithm
	The algorithm generates a normal distributed random number with `mu` as the average and `sigma` as the standard deviation.
	
	@func
	@category Random
	@sig Number a => a -> a -> a
	@param {Number} the average
	@param {Number} the standard deviation
	@return {Number} a normal distributed random number
	@example	
		R.boxMullerSampling(1, 1)
]]
R.boxMullerSampling = _curry2(function(mu, sigma)
	local u = math.random()
	local v = math.random()
	local z0 = math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v)
	--local z1 = math.sqrt(-2 * math.log(u)) * math.sin(2 * math.pi * v)
	return mu + z0 * sigma
end)

--[[
	Normal stochastic algorithm 
	The algorithm generates a normal distributed random number with `min` `max` as the range and `sigma` as the standard deviation.
	This algorithm based on box muller algorithm
	
	@func
	@category Random
	@sig Number a => a -> a -> a -> a
	@param {Number} the min value
	@param {Number} the max value
	@param {Number} the standard deviation
	@return {Number} a normal distributed random number
	@example	
		R.normalDistributed(0, 1, 0.7)
]]
R.normalDistributed = _curry3(function(min, max, sigma)
	error("<lamda_error> normalDistributed:: not implement")
end)


--[[
	Return some random values from the given list.
	
	@func
	@category Random
	@sig [a] -> [a]
	@param {Number} sample count
	@param {Array} the given list with non-zero length	
	@return {Array} random values from the list
	@example	
		R.sample(3, {1, 2, 3, 4, 5}) --> 1, 3, 5
		R.sample(1, {1, 2, 3, 4, 5}) --> 2
]]
R.sample = _curry2(function(count, list)
	if #list == 0 or count <= 0 then
		return nil
	end

	local out = {}
	if count == 1 or #list > count * 5 then
        local indexs = {}
        for i = 1, count do
            local index = math.random(1, #list)
            while indexs[index] do
                index = math.random(1, #list)
			end
            indexs[index] = true
            table.insert(out, list[index])
        end
    else
        for i = 1, #list do
			local p = (count - #out) / (#list - i + 1)
            if p > math.random() then
                table.insert(out, list[i])
			end
        end
	end
	
	return out
end)

--[[
	Return a random value from the given list.
	
	@func
	@category Random
	@sig [a] -> a
	@param {Array} the given list with non-zero length
	@return {*} a random value from the list
	@example	
		R.choice({1, 2, 3, 4, 5}) --> 2
		R.choice({1, 2, 3, 4, 5}) --> 4
]]
R.choice = R.o(R.head, R.sample(1))

--[[
	Return a random value between `from`(inclusive) and `to`(inclusive) value
	
	@func
	@category Random
	@sig Integer a -> a -> a
	@param {Integer} the min value
	@param {Integer} the max value
	@return {*} a random value
	@example	
		R.randrange(1, 100) --> 31
]]
R.randrange = _curry2(function(from, to)
	if from > to then from, to = to, from end
	local delta = math.floor(to - from)
	if delta < 1 then return math.floor(from) end
	return math.floor(delta * math.random() + from)
end)

--[[
	Return a shuffled list
	
	@func
	@category Random
	@sig [a] -> [a]
	@param {Array} the given list
	@return {Array} the shuffled list
	@example	
		R.shuffle({1,2,3,4}) --> {4,1,3,2}
]]
R.shuffle = function(list)
	local nl = R.clone(list)
	_shuffle(nl)
	return nl
end

-- =========================================
-- ============ Not Implements =============
-- =========================================
--Transformers
--R.identical
--R.hasIn
--R.keysIn
--R.addIndex
--R.nthArg
--R.reduced
--R.toPairsIn
--R.type
--R.uncarryN
--R.valuesIn
--R.transduce
--R.into
--R.mapObjIndexed
--R.ap
--R.applySpec
--R.constructN
--R.lens series
--R.liftN
--R.pipeP
--R.sequence
--R.traverse
--R.composeK
--R.composeN
--R.lift
--R.pipeK
--R.envolve

-- ==================================
-- ============ Renamed =============
-- ==================================
-- R.and_
-- R.or_
-- R.repeat_
-- R.not_
-- R.until_

return R
