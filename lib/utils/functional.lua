local M = {}

M.partial      = hs.fnutils.partial
M.bind         = hs.fnutils.partial -- alias'partial()' to 'bind()'

-- Functional utils --
-- ~/Programming/Projects/stackline-scratchpad/June-2021/functional-test.lua
-- ~/Programming/Projects/stackline-july-2021-classes-&-proxy/lib/utils/init.lua
-- /Applications/Hammerspoon.app/Contents/Resources/extensions/hs/fnutils/init.lua
-- TODO: CHECK OUT 'liter' - a really interesting looking iteration library with mucho control over how & what is iterated:
-- https://github.com/ok-nick/liter

function M.trycall(fn, ...) -- {{{
    if M.iscallable(fn) then
        return fn(...)
    else
        return ...
    end
end -- }}}

function M.bindTail(f, ...) --[[ {{{
    Bind all *except* the 1st argument.
    Useful for applying args to class methods in advance without needing to know the caller.
    Example:
        processWithOptions = M.bindTail(SomeClass.processData, opts)
    Then, in any instance that inherits from SomeClass:
        self.processWithOptions = processWithOptions
        self:processWithOptions()
    Or simply:
        processWithOptions(self)
    ]]
    local args = {...}
    return function(x)
        return f(x, unpack(args))
    end
end -- }}}

function M.curry(f, n) --[[ {{{
    @param f: the function to curry
    @param n: # of expected args for `f`. If omittied, will attempt to compute via `debug.getinfo()`.
    @returns: curried function or result of calling satisifed function
    == TESTS == {{{
    -- TEST: Args applied one-by-one
    x = function(a,b,c) return a + b + c end
    c = M.curry(x)
    a = c(1)(2)(3)
    assert(a == 6)
    -----------------------------
    -- TEST: Args applied in bulk
    x = function(a,b,c) return a + b + c end
    c = M.curry(x)
    b = c(1,2)(3)
    assert(b == 6)
    -----------------------------
    -- TEST: Args applied all at once
    x = function(a,b,c) return a + b + c end
    c = M.curry(x)
    c = c(1,2,3)
    assert(c == 6)
    -----------------------------
    }}} ]]
    n = n or debug.getinfo(f, 'u').nparams
    assert(n, "Must specify # of args as `M.curry(f, n)` if debug.getinfo isn't avaialble")
	if n == 0 then return f() end -- if no args remain, return result of calling fn
	if n == 1 then return f end -- if only 1 arg remains, return fn to call
	return function(...)
		return M.curry(
            M.bind(f, ...), -- new fn with given args partially applied
            n - select('#', ...) -- # of args still expected before `f` will execute
        )
	end
end -- }}}

function M.wrapFn(f, wrapper) --[[ {{{
    Wraps a function inside a wrapper. Allows the wrapper to execute code before and after function run.
    == EXAMPLE == {{{
    local greet = function(name) return "hi: " .. name end
    local greet_backwards = M.wrap(greet, function(f,arg)
      return f(arg) ..'\nhi: ' .. arg:reverse()
    end)
    greet_backwards('John')

    -- => hi: John
    -- => hi: nhoJ
    }}} ]]
    return function (...) return  wrapper(f,...) end
end -- }}}

function M.negate(f) -- {{{
   if type(f)=='function' then
       return function(...) return not f(...) end
   else
       return not f
   end
end -- }}}

function M.flip(func) -- {{{
    -- Flips the order of parameters passed to a function
    return function(...)
        return func(unpack(M.reverse({...})))
    end
end -- }}}

function M.pipe(f, g, ...) -- {{{

  local function simpleCompose(f1, g1)
    return function(...)
      return f1(g1(...))
    end
  end

  if (g==nil) then return f or M.identity end
  local nextFn = simpleCompose(g, f)

  return M.pipe(nextFn, ...)
end -- }}}

function M.applySpec(specs) --[[ {{{
    Returns a function which applies `specs` on args. This function produces an object having
    the same structure than `specs` by mapping each property to the result of calling its
    associated function with the supplied arguments.

    local stats = M.applySpec({
        min = function(...) return math.min(...) end,
        max = function(...) return math.max(...) end,
    })
    stats(5,4,10,1,8) -- => {min = 1, max = 10}
  ]]
  return function (...)
    local spec = {}
    for i, f in pairs(specs) do spec[i] = f(...) end
    return spec
  end
end -- }}}

function M.bind(func, ...) --[[ {{{
  Create a function with bound arguments.
  The bound function returned will call func with the arguments passed on to its creation.
  If more arguments are given during its call, they are appended to the original ones.

  SEE relatively simple verison that allows '_' placeholder values
  https://github.com/Yonaba/Moses/blob/master/moses.lua#L2423
  ]]

  local saved_args = { ... }
  return function(...)
    local args = { unpack(saved_args) }
    for _, arg in ipairs({...}) do
      table.insert(args, arg)
    end
    return func(unpack(args))
  end
end -- }}}

function M.bindMethods(obj, ...) --[[ {{{
    Binds methods to object. Mutates object.
    Whenever any of these methods is invoked, it always receives the object as its first argument.
    == EXAMPLE == {{{
    w = stackline.manager:get()[1].windows[1]
    methods = u(getmetatable(w)):filter(function(v) return type(v)=='function' end):keys():value()
    -- w.isFocused() -- => Error: attempt to index a nil value (local 'self')
    M.bindall(w, methods)
    }}} ]]
	local methodNames = M.wrap(...) -- supports both varargs or table
	for i, methodName in ipairs(methodNames) do
		local method = obj[methodName]
		if method then obj[methodName] = M.bind(method, obj) end
	end
	return obj
end -- }}}

function M.rearg(f, indexes) --[[ {{{
  Returns a function which runs with arguments rearranged. Arguments are passed to the returned function in the order of supplied `indexes` at call-time.
      f = M.rearg(function (...) return ... end, {5,4,3,2,1})
      f('a','b','c','d','e') -- => 'e','d','c','b','a'
  }}} ]]
  return function(...)
    local args = {...}
    local reargs = {}
    for i, arg in ipairs(indexes) do reargs[i] = args[arg] end
    return f(unpack(reargs))
  end
end

function M.invoke(t, meth, ...) --[[
  Invokes method k at `k` on each `el` in a table
  OR returns property at `k` if `el[k]` is not callable.
  Adapted from moses: https://github.com/Yonaba/Moses/blob/master/moses.lua#L641
  == EXAMPLE == {{{
    ws = M.map(hs.window.filter(), stackline.window:call('new'))

    -- Call `frame` method on each window in `ws`
    frames = M.invoke(ws, 'frame')
    frames[1] -- -> hs.geometry.rect(1456.0,28.0,1501.0,1664.0)

    -- Get `id` prop on each window in `ws`
    ids = M.invoke(ws, 'id')
    ids[1] -- -> 35646

  }}} ]]

  local args = {...}

  return M.map(t, function(v, k)
    if M.iscallable(meth) then 
      return meth(v, k, unpack(args)) 
    end

    if M.istable(v) then

      if M.iscallable(v[meth]) then
        return v[meth](v, unpack(args))
      else
        return v[meth]
      end

    end
  end)
end

return M
