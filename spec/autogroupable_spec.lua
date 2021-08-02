-- luacheck: globals assert
require 'spec.helpers'

describe('Autogroupable', function()

  before_each(function()
    class = require 'lib.class'
    AutoGroupable = require 'mixins.AutoGroupable'
  end)

  after_each(function() end)

  describe('used as a regular func', function()
    it('returns an empty table', function() -- {{{
      autogroup = AutoGroupable.autogroup()
      assert.is_table(autogroup)
      assert.equal(0, #autogroup)
    end) -- }}}

    it('can autogroup list-like table values at index 3+', function() -- {{{
      -- NOTE: here, matcher is not being passed as `opts.matcher`, but `self.matcher`!
      local x = AutoGroupable.autogroup { matcher = function(x) return x > 2 end }
      table.insert(x, 'one')
      table.insert(x, 'two')
      table.insert(x, 'three')
      table.insert(x, 'four')
      table.insert(x, 'five')

      local expected = { { "one" }, { "two" }, { "three", "four", "five" } }
      assert.same(expected, x)
    end) -- }}}
  end)

  describe('used as mixin', function()
    it('returns an empty table', function() -- {{{
      autogroup = AutoGroupable:autogroup()
      assert.is_table(autogroup)
      assert.equal(0, #autogroup)
    end) -- }}}

    it('can autogroup list-like table values at index 3+', function() -- {{{
      local Thing = class('Thing'):use('AutoGroupable')
      Thing.matcher = function(x) return x > 2 end -- `matcher` can be set as a class attr
      x = Thing:new():autogroup()

      table.insert(x, 'one')
      table.insert(x, 'two')
      table.insert(x, 'three')
      table.insert(x, 'four')
      table.insert(x, 'five')
      table.insert(x, 'six')

      local expected = { { "one" }, { "two" }, { "three", "four", "five", "six" } }
      assert.same(expected, x)
    end) -- }}}

    it('can be configured with opts', function() -- {{{
      local Thing = class('Thing'):use('AutoGroupable')

      local opts = { matcher = function(x) return x > 2 end }
      x = Thing:new():autogroup(opts)

      table.insert(x, 'one')
      table.insert(x, 'two')
      table.insert(x, 'three')
      table.insert(x, 'four')
      table.insert(x, 'five')
      table.insert(x, 'six')

      local expected = { { "one" }, { "two" }, { "three", "four", "five", "six" } }
      assert.same(expected, x)
    end) -- }}}

    it('autogroups a dict-like table by equality by default', function() -- {{{
      local Thing = class('Thing'):use('AutoGroupable')
      x = Thing:new():autogroup()

      x[{'a'}] = 'a1'
      x[{'a'}] = 'a2'
      x[{'a'}] = 'a3'
      x[{'b'}] = 'b1'
      x[{'b'}] = 'b2'
      x[{'c'}] = 'c2'

      -- Need to set assign "expected" keys to a variable, because they're *not* magical 
      -- autogroup instances, so I can't index by table & expect to get the correct value.
      local keyA, keyB, keyC = {'a'}, {'b'}, {'c'}
      local expected = {
        [keyA] = { 'a1', 'a2', 'a3' },
        [keyB] = { 'b1', 'b2' },
        [keyC] = { 'c2' }
      }

      assert.same(expected[keyA], x[{'a'}])
      assert.same(expected[keyB], x[{'b'}])
      assert.same(expected[keyC], x[{'c'}])
    end) -- }}}
  end)
end)
