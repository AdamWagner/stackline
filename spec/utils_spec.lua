-- luacheck: globals assert
require 'stackline.spec.helpers'

describe('utils.core', function()

  describe('u.unwrap', function() -- {{{
    it("unwraps a single value '1' wrapped in a table", function()
      local res = u.unwrap( {1} )
      assert.same(1, res)
    end)
    it("unwraps a single value '1' wrapped in redunant tables", function()
      local res = u.unwrap( {{1}} )
      assert.same(1, res)
    end)
    it("Unwraps the 1st (redundant) table, but does not unpack the inner table when it has multiple values", function()
      local res = u.unwrap( {{1,2}} )
      assert.same({1,2}, res)
    end)
    it("does nothing when there's more than 1 element in a non-redundant table", function()
      local res = u.unwrap( {1,2} )
      assert.same({1,2}, res)
    end)
    it("works with map-style tables", function()
      local res = u.unwrap( {{name='me'}} )
      assert.same({name='me'}, res)
    end)
    it("works with tables that are a mix of hash-like and array-like", function()
      local res = u.unwrap( {{name='me'},2} )
      assert.same({{name='me'},2}, res)
    end)
  end) -- }}}

  describe('u.wrap', function() -- {{{
    it("wraps varargs in a table", function()
      local res = u.wrap(1,2,3,4)
      assert.same({ 1, 2, 3, 4 }, res)
    end)

    it("does nothing when given a table", function()
      local res = u.wrap({1,2,3,4})
      assert.same({ 1, 2, 3, 4 }, res)
    end)

    it("wraps 2 table args in a table", function()
      local res = u.wrap({name = 'johnDoe'}, {name = 'janeDoe'})
      assert.same({ { name = "johnDoe" }, { name = "janeDoe" } }, res)
    end)

    it("wraps combination of table & varargs in a table", function()
      local res = u.wrap({ name = 'johnDoe' }, 1, 2, 3)
      assert.same({ { name = "johnDoe" }, 1, 2, 3 }, res)
    end)
  end) -- }}}

  describe('u.keys', function() -- {{{
    it("returns list of string keys in hash-like table with 1 key", function()
      local res = u.keys({name='john'})
      assert.same({'name'}, res)
    end)

    it("returns list of string keys in hash-like table with 2 keys", function()
      local res = u.keys({name='john', age=33})
      assert.equals(2, #res)
      assert.is.string(res[1])
    end)

    it("resturns list of integer keys in array-like table", function()
      local res = u.keys({1,2,3,4})
      assert.same({ 1, 2, 3, 4 }, res)
    end)
  end) -- }}}

  describe('u.values', function() -- {{{
    it("returns list of values in hash-like table with 1 key", function()
      local res = u.values({name='john'})
      assert.same({'john'}, res)
    end)

    it("returns list of values in hash-like table with 2 keys", function()
      local res = u.values({first_name='john', last_name='smith'})
      assert.equals(2, #res)
      assert.is.string(res[1])
    end)

    it("resturns list of integer values in array-like table", function()
      local res = u.values({1,2,3,4})
      assert.same({ 1, 2, 3, 4 }, res)
    end)
  end) -- }}}

  describe('u.cb', function() -- {{{
    it("returns a function that returns the given function when called", function()
      local fn = function() return 'it worked' end
      local res = u.cb(fn)
      assert.is.same('it worked', res()())
    end)
  end) -- }}}

  describe('u.prepareJsonEncode', function() -- {{{
    it('removes functions', function()
      local t = { name = 'john', talk = function() end }
      local res = u.prepareJsonEncode(t)
      assert.same({name='john'}, res)
    end)

    -- NOTE: this also tests the helper `hsExec` here: ./spec/helpers/init.lua
    -- While unfortunate, the nominal function being tested exists primarily to enable `hsExec`
    it('enables send/receive data from live hammerspoon via `hs` cli', function()
      local groupedWindows = hsExec [[
        require "stackline.query".groupWindows(hs.window.filter())
      ]]

      -- Get what should be a window from the groupedWindows response
      -- Note that this will fail if hammerspoon is not running and there are no stacks on the active space
      local window = u.values(groupedWindows)[1][1]

      assert.is.table(groupedWindows)
      assert.is.number(window.id)
    end)

  end) -- }}}

end)

describe('utils.functional', function()

  before_each(function() -- {{{
    makeTable = function(a,b,c,d) return {a,b,c,d} end
    sum = function(a,b,c) return a + b + c end
  end) -- }}}

  describe('u.bind', function() -- {{{
    it("binds 1 arg to a func that takes 4 args", function()
      local bound = u.bind(makeTable, 1)
      assert.same({1,2,3,4}, bound(2,3,4))
    end)

    it("binds 3 args to a func that takes 4 args", function()
      local bound = u.bind(makeTable, 1,2,3)
      assert.same({1,2,3,4}, bound(4))
    end)

    it("binds all 4 args to a func that takes 4 args", function()
      local bound = u.bind(makeTable, 1,2,3,4)
      assert.same({1,2,3,4}, bound())
    end)

    it("ignores bound args that exceed fn arity", function()
      local bound = u.bind(makeTable, 1,2,3,4,5,6)
      assert.same({1,2,3,4}, bound())
    end)
  end) -- }}}

  describe('u.curry', function() -- {{{
    before_each(function()
      curriedMakeTable = u.curry(makeTable)
      curriedSum = u.curry(sum)
    end)
    it("Args applied one-by-one", function()
      local res = curriedSum(1)(2)(3)
      assert.equal(6, res)
    end)
    it("Args applied in bulk", function()
      local res = curriedSum(1,2)(3)
      assert.equal(6, res)
    end)
    it("Args applied all at once", function()
      local res = curriedSum(1,2,3)
      assert.equal(6, res)
    end)
  end) -- }}}

  describe('u.rearg', function() -- {{{
    it("Reorders function args", function()
      -- Returns a function which runs with arguments rearranged.
      -- Arguments are passed to the returned function in the order of supplied `indexes` at call-time.
      f = u.rearg(function (...) return ... end, {5,4,3,2,1})
      local r1, r2, r3, r4, r5 = f('a','b','c','d','e') -- =>
      assert.same({'e', 'd', 'c', 'b', 'a'}, {r1,r2,r3,r4,r5})
    end)
  end) -- }}}

  describe('u.bindTail', function() -- {{{
    -- Returns a function which runs with arguments rearranged.
    -- Arguments are passed to the returned function in the order of supplied `indexes` at call-time.
    before_each(function()
      fn = function(a,b,opts)
        if opts.op == 'add' then return a + b
        elseif opts.op == 'sub' then return a - b
        elseif opts.op == 'div' then return a / b
        elseif opts.op == 'mult' then return a * b
        end
      end

      add2 = u.bindTail(fn, 2, {op = 'add'})
      sub2 = u.bindTail(fn, 2, {op = 'sub'})
    end)

    it("binds all but the *first* arg", function()
      local res = add2(2)
      assert.same(4, add2(2))
      assert.same(0, sub2(2))
    end)
  end) -- }}}

  describe('u.bindTail2', function() -- {{{
    -- Returns a function which runs with arguments rearranged.
    -- Arguments are passed to the returned function in the order of supplied `indexes` at call-time.
    before_each(function()
      fn = function(a,b,opts)
        if opts.op == 'add' then return a + b
        elseif opts.op == 'sub' then return a - b
        elseif opts.op == 'div' then return a / b
        elseif opts.op == 'mult' then return a * b
        end
      end

      add = u.bindTail2(fn, {op = 'add'})
      sub = u.bindTail2(fn, {op = 'sub'})
    end)

    it("binds all but the *first TWO* args", function()
      assert.same(4, add(2,2))
      assert.same(0, sub(2,2))
    end)
  end) -- }}}

end)

describe('utils.collections', function()

  before_each(function() -- {{{
    list = {1,2,3,4,5}
    dict = { name = 'John', age = 33, color = 'red', likes = list }
    collection = {dict, dict, dict}
    double = function(x) return x * 2 end
  end) -- }}}

  describe('u.map', function() -- {{{

    it('applies a func to a list', function()
      local doubled = u.map(list, double)
      assert.same({2,4,6,8,10}, doubled)
    end)

    it('plucks a prop from a collection', function()
      local names = u.map(collection, 'name')
      assert.same({'John', 'John', 'John'}, names)
    end)

  end) -- }}}

  describe('u.filter', function() -- {{{

    before_each(function() -- {{{
      xs = {
        {height = 10, weight = 8, price = 500},
        {height = 10, weight = 15, price = 700},
        {height = 15, weight = 15, price = 3000},
        {height = 10, weight = 8, price = 3000},
      }
    end) -- }}}

    it('by specifying k,v pairs in table', function() -- {{{
      assert.same(
        {xs[1], xs[2], xs[4]},
        u.filter(xs, {height = 10})
      )

      assert.same(
        {xs[2], xs[3]},
        u.filter(xs, {weight = 15})   
      )

      assert.same(
        {xs[3], xs[4]},
        u.filter(xs, {price = 3000})
      )
    end) -- }}}

    it('by specifying multiple k,v pairs in table', function() -- {{{
      assert.same(
        {xs[2]},
        u.filter(xs, {height = 10, weight = 15, price = 700}) 
      )
    end) -- }}}

    it('with a predicate func', function() -- {{{
      assert.same(
        {xs[3], xs[4]},
        u.filter(xs, function(x) return x.price > 1000 end)
      )
    end) -- }}}

    it('with a predicate func with only 1 result', function() -- {{{
      assert.same(
        {xs[4]}, -- note the single result is wrapped in a table
        u.filter(xs, function(x) return x.price > 1000 and x.weight == 8 end)
      )
    end) -- }}}

    it('returns full collection if predicate func is nil', function() -- {{{
      assert.same(
        xs,
        u.filter(xs, nil) -- falls back to u.identity if predicate nil
      )
    end) -- }}}

  end) -- }}}

end)
