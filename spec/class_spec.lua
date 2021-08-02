-- luacheck: globals assert
require 'spec.helpers'

describe('Class', function()
  before_each(function()
    class = require 'lib.class'
    Thing = class('Thing')
  end)

  after_each(function() -- {{{
    class, Thing, a = nil, nil, nil
  end) -- }}}

  it('supports implicit constructor with table arg', function() -- {{{
    a = Thing:new({name = 'adam', age = 33, type = 'fun'})
    assert.equal('adam',a.name)
    assert.equal('fun',a.type)
    assert.equal(33,a.age)
  end) -- }}}

  it('does not support implicit constructors with non-table args', function() -- {{{
    a = Thing:new('me', 99)
    assert.equal(nil, a[1])
    assert.equal(nil, a[2])
  end) -- }}}

  it('does not do implicit construction if class ctor is set', function() -- {{{
    function Thing:new() end
    a = Thing:new{name = 'me', age = 99}
    assert.equal(nil, a.name)
    assert.equal(nil, a.age)
  end) -- }}}

  it('supports explicit constructors', function() -- {{{
    function Thing:new(t, type) self.name = t.name self.age = t.age self.type = type end

    a = Thing:new({name = 'adam', age = 33}, 'type:person')

    assert.equal('adam', a.name)
    assert.equal(33, a.age)
    assert.equal('type:person',  a.type)
  end) -- }}}

  it('renames `new` assignment to `_constructor` so it can be auto-called withinin default ctor', function() -- {{{
    local builtin_ctor_before = Thing.new -- cache ref to builtin ctor

    assert.is_nil(Thing._constructor)
    assert.is_function(builtin_ctor_before)

    -- assign custom constructor
    function Thing:new(t) self.name = t.name self.age = t.age end

    assert.equal(builtin_ctor_before, Thing.new) -- assigning `new` did *not* overwrite the builtin `new` method
    assert.is_function(Thing._constructor)
  end) -- }}}

  it('runs `init` when a class is created', function() -- {{{
    -- Primarily useful for doing things when a subclass is created
    -- NOTE: only the nearest non-nil `init` method will run — this does not cascade from the eldest heir like constructors.
    local counter = 0
    local Parent = class('Parent')
    function Parent:init()
      counter = counter + 1
      self.depth = counter
    end

    Child = Parent:subclass('Child')
    Grandchild = Child:subclass('Grandchild')

    -- self.depth is incremented twice
    assert.equal(2, Grandchild.depth)

    -- When overwritten on a subclass, *only* the youngest `init` method will run.
    function Grandchild:init() self.depth = 99 end
    ManyGreatsLater = Grandchild:subclass('Grandchild')

    assert.equal(99, ManyGreatsLater.depth)
  end) -- }}}

  it('can check if instance is a specific class', function() -- {{{
    a = Thing:new()

    assert.equal(true, a:is(Thing))
  end) -- }}}

  it('can check if instance is a descendant of a class ', function() -- {{{
    ThingChild = Thing:subclass('ThingChild')

    a = ThingChild:new()

    assert.equal(true, a:is(ThingChild))
    assert.equal(true, a:is(Thing))
    assert.equal(true, a:is('Object'))
  end) -- }}}

  it('supports checking instance class by name/string', function() -- {{{
    a = Thing:new()

    assert.equal(true, a:is('Thing'))
    assert.equal(true, a:is('Object'))
  end) -- }}}

  it('applies metamethods to instances', function() -- {{{
    local changes = {}

    function Thing:__newindex(k, v)
      local val = v..'_custom'
      rawset(self, k, val)
      table.insert(changes, string.format('Set self.%s to %s', k, val))
    end

    a = Thing:new()
    a.name = 'john'

    assert.same({ "Set self.name to john_custom" }, changes)
    assert.equal('john_custom', a.name)
  end) -- }}}

  it('lifts metamethods onto subclasses', function() -- {{{
    local changes = {}

    function Thing:__newindex(k, v)
      local val = v..'_custom'
      rawset(self, k, val)
      table.insert(changes, string.format('Set self.%s to %s', k, val))
    end
    OtherThing = Thing:subclass()

    a = OtherThing:new()
    a.name = 'john'

    assert.same({ "Set self.name to john_custom" }, changes)
    assert.equal('john_custom', a.name)
  end) -- }}}

  pending('guards against instances using class methods', function() -- {{{
    t = Thing:new()

    assert.error(t:subclass())
    assert.equal(t:use())
    assert.equal(t:new())
  end) -- }}}

  describe('mixins', function()
    it('can use mixins', function() -- {{{
      local utils_mixin = require 'lib.utils'
      Utils = class('Utils'):use(utils_mixin)

      t = Utils:new{1,2,3,4,5}
      res = t:map(function(x) return x * 2 end)

      assert.same({2,4,6,8,10}, res)
    end) -- }}}

    it('can use multiple mixins', function() -- {{{
      MixinOne = {map = u.map, imap = u.imap}
      MixinTwo = {filter = u.filter, ifilter = u.ifilter}

      Utils = class('Utils'):use(MixinOne, MixinTwo)

      t = Utils:new{1,2,3,4,5}

      res1 = t:map(function(x) return x * 2 end)
      assert.same({2,4,6,8,10}, res1)

      res2 = t:filter(function(x) return x > 2 end)
      assert.same({3,4,5}, res2)
    end) -- }}}

    it('cannot use a table of mixins', function() -- {{{
      MixinOne = {map = u.map, imap = u.imap}
      MixinTwo = {filter = u.filter, ifilter = u.ifilter}

      -- Must be called :use(M1, M2), *NOT* :use{M1, M2}
      Utils = class('Utils'):use{MixinOne, MixinTwo}

      t = Utils:new{1,2,3}

      assert.equal(nil, t.map)
    end) -- }}}

    it('can use a mixin given as string name of a module in MIXIN_PATH', function() -- {{{
      Thing = class('Thing'):use('Hookable')
      assert.is_function(Thing.beforeHook)
    end) -- }}}

    it('runs `mixin.init` when used', function() -- {{{
      Thing = class('Thing')
      M = {}
      function M:init() self.__name = 'Thing:Mixin' end

      i = Thing:new()
      assert.equal('Thing', i.__name)

      -- Class is renamed when `M` mixin is used.
      -- Note that `self` in mixin:init(...) is the class, not the instance
      i = Thing:use(M)
      assert.equal('Thing:Mixin', i.__name)

    end) -- }}}

    describe('mixin constructors', function() -- describe: multiple mixin constructors
      it('do not interfere with implicit class constructor', function() -- {{{
        Thing = class('Thing')
        M = {}
        function M:init() self.__name = 'Thing:Mixin' end

        i = Thing:new()
        assert.equal('Thing', i.__name)

        -- Class is renamed when `M` mixin is used.
        -- Note that `self` in mixin:init(...) is the class, not the instance
        i = Thing:use(M)
        assert.equal('Thing:Mixin', i.__name)

      end) -- }}}

      it('do not interfere with explicit class constructor', function() -- {{{
        Thing, Mixin = class('Thing'), {}
        function Thing:new(x) self.val = x end
        function Mixin:init() end
        Thing:use(Mixin)

        assert.equal(3, Thing:new(3).val)
      end) -- }}}

      it('are renamed to _constructor when "used"', function() -- {{{
        M1 = {__name='M1'}
        function M1:new() self.M1 = true end

        assert.is_function(M1.new)
        assert.is_nil(M1._constructor)

        Thing:use(M1)

        assert.same('M1', Thing:mixins()[1].__name)

        -- The "used" mixin has `_constructor` set to `new`, and `new` set to `nil`
        assert.is_function(Thing:mixins()[1]._constructor)
        assert.is_nil(Thing:mixins()[1].new)

        -- The original mixin is not mutated
        assert.is_function(M1.new)
        assert.is_nil(M1._constructor)
      end) -- }}}

      it('do not interfere with class constructors', function() -- {{{
        Thing = class('Thing')
        M1 = {__name='M1'}
        function M1:new() self.M1 = true end
        Thing:use(M1)

        assert.same(nil, Thing._constructor)

        -- Implicit construction should still work when there is a *mixin* constructor present
        -- NOTE: Setting a class constructor will prevent implicit construction
        local t = Thing:new{name = 'john', job = 'farmer'}
        assert.equal('farmer', t.job)
        assert.equal(true, t.M1)
      end) -- }}}

      it('are called after class constructors', function() -- {{{
        Thing.max = 100
        Weakling = {__name='Weakling'}
        function Weakling:new()
          self.usesWeakling = true
          self.isCounter = 'overwritten' -- can overwrite attrs set during init
          self.max = self.max / 10 -- and has access to `self` attrs for the same reason
        end
        Thing:use(Weakling)

        w = Thing:new()

        assert.equal(true, w.usesWeakling)
        assert.equal('overwritten', w.isCounter)
        assert.equal(10, w.max)
      end) -- }}}

      it('are called in order that the mixins were added', function() -- {{{
        FirstMixin = {__name='FirstMixin'}
        function FirstMixin:new()
          self.mixinNum = self.mixinNum + 3 -- mixinNum is defined here, so is nil on rhs of assignment
        end

        SecondMixin = {__name='SecondMixin'}
        function SecondMixin:new()
          self.mixinNum = self.mixinNum * (self.mixinNum + 9) -- runs after FirstMixin:new(), so `mixinNum` can be used in rhs of assignment
        end

        Thing = class('Thing')
        Thing:use(FirstMixin):use(SecondMixin)
        Thing.mixinNum = 1
        a = Thing:new()
        assert.equal(52, a.mixinNum) -- mixinNum assignment in SecondMixin references mixinNum set in FirstMixin

        Thing = class('Thing')
        Thing:use(SecondMixin):use(FirstMixin)
        Thing.mixinNum = 1
        a = Thing:new()
        assert.equal(13, a.mixinNum) -- mixinNum assignment in SecondMixin references mixinNum set in FirstMixin
      end) -- }}}
    end)
  end)

  describe('reflection', function() 
    it('can view ancestral tree via :supers()', function() -- {{{
      SubThing = Thing:subclass('SubThing')
      local ancestralTree = u.map(SubThing:supers(),'__name')
      assert.same({'Object', 'Thing', 'SubThing'}, ancestralTree)
    end)-- }}}

    it('can view mixins', function() -- {{{
      Thing = class('Thing'):use('Hookable')
      assert.same({'Hookable'}, u.map(Thing:mixins(), '__name'))
    end)-- }}}

    it('can view :class() on both instance & class', function() -- {{{
      a = Thing:new({name = 'adam', age = 33, type = 'fun'})
      assert.same('Thing', Thing:class().__name)
    end)-- }}}

    it('can view :super() on both instance & class', function() -- {{{
      a = Thing:new({name = 'adam', age = 33, type = 'fun'})
      assert.same('Object', a:super().__name)
      assert.same('Object', Thing:super().__name)
    end)-- }}}

    it('unnamed classes have __name == "Anonymous Class"', function() -- {{{
      Anon = class()
      assert.same('Anonymous Class', Anon:class().__name)
    end)-- }}}
  end) 

  describe('inherits', function() -- describe: inherits
    it('properties from parent class', function() -- {{{
      Thing.static = {'static', 'field'}
      Child = Thing:subclass()

      c = Child:new({})

      assert.equal(Thing.static, c.static)
    end) -- }}}

    it('methods from parent class', function() -- {{{
      function Thing:doubleAge() return self.age * 2 end
      Child = Thing:subclass()

      c = Child:new({age = 25})

      assert.equal(50, c:doubleAge())
    end) -- }}}

    describe('Example: Counter()', function() -- describe: Example: Counter()
      before_each(function()
        Counter = class('Counter')
        function Counter:new()
          self.val = 0
          self.isCounter = true
          self.max = 100
        end
        function Counter:inc()
          self.val = self.val + (self.incAmt or 1)
          return self
        end
        c = Counter:new()
      end)

      after_each(function() -- {{{
        Counter = nil
        a,b,c,d,e,f,g = nil, nil, nil, nil, nil, nil, nil
      end) -- }}}

      it('subclass can change behavior via class attrs', function() -- {{{
        CountByTwo = Counter:subclass('CountByTwo')
        CountByTwo.incAmt = 2

        b = CountByTwo:new()
        b:inc():inc() -- inc() is defined on parent & not ovewritten — only the `incAmt` has changed.

        assert.equal(4, b.val) -- i.e., 0 + 2 + 2 rather than 0 + 1 + 1
      end) -- }}}

      it('subclasses automatically call super.new() in constructor', function() -- {{{
        CountByTwo = Counter:subclass('CountByTwo')
        function CountByTwo:new()
          self.isCountByTwo = true
          self.val = 0
        end

        b = CountByTwo:new()

        assert.equal(true, b.isCountByTwo)
      end) -- }}}

      describe('multiple levels of subclassing', function()
        before_each(function()
          function Counter:new()
            self.max = 100
            self.enabled = true
            self.val = 0
            self.incAmt = 1
          end
          function Counter:update()
            if not self.enabled then return self end
            self.val = self.val + (self.incAmt or 1)
            if (self.val >= self.max) then
              self.enabled = false
            end
            return self
          end
          FlysWhenHavingFun = Counter:subclass('FlysWhenHavingFun')
          function FlysWhenHavingFun:new()
            self.isFlysWhenHavingFun = true
            self.max = self.max + 50
            self.incAmt = 20
            self.val = self.val + 1
          end
          ShortDay = FlysWhenHavingFun:subclass('ShortDay')
          function ShortDay:new()
            self.isShortDay = true
            self.max = self.max / 5
            self.incAmt = self.incAmt / 2
            self.val = self.val + 2
          end
        end)

        after_each(function() -- {{{
          Counter, FlysWhenHavingFun, ShortDay, s = nil, nil, nil, nil
        end) -- }}}

        it('works', function() -- {{{
          s = ShortDay:new()
          assert.same({'Object', 'Counter', 'FlysWhenHavingFun', 'ShortDay'}, u.map(s:supers(), '__name'))
        end) -- }}}

        it('auto-calls all super constructors', function() -- {{{
          s = ShortDay:new()
          assert.equal(true, s.isShortDay)
          assert.equal(true, s.isShortDay)
          assert.equal(true, s.enabled)
        end) -- }}}

        it('calls all super constructors *oldest* to *newest* with access to `self`', function() -- {{{
          s = ShortDay:new()
          assert.equal(30, s.max) -- (100 + 50) / 5
          assert.equal(10, s.incAmt) -- 20 / 2
          assert.equal(3, s.val) -- 0 + 1 + 2
        end) -- }}}

        it('uses methods defined on a grandparent with own attributes', function() -- {{{
          s = ShortDay:new()

          s:update():update():update() -- update 3 times to increment `val` & (hopefully) disable the counter by exceeding `max`
          assert.equal(33, s.val)
          assert.equal(false, s.enabled) -- disabled when self.val (33) exceeds self.max (30)

          s:update():update():update() -- update() has no effect when disabled
          assert.equal(33, s.val)
        end) -- }}}

      end)
    end)
  end)
end)
