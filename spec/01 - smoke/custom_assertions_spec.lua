local u = require 'lib.utils'

describe('#custom_assertions', function()

    it('contains - array', function()
      assert.contains({1,2,3}, 2)
    end)

    it('contains - key', function()
      assert.contains_key({name='adam', age=33}, 'name')
    end)

    it('substring', function()
      assert.substring('hello', 'ell')
    end)


    describe('deepEqual', function()
      it('array', function()
        -- arrays are sorted
        assert.deepEqual({1,2,3,4,5}, {4,5,1,2,3})
        assert.is_not.deepEqual({1,2,3,4,5}, {4,5,1,2,9})
      end)

      it('dict', function()
        local a = {name = 'adam', age = 33}
        local b = {age = 33, name = 'adam'}
        assert.deepEqual(a,b)
      end)

      it('list of lists', function()
        local a = { { name = 'adam' }, { name = 'amy'} }
        local b = { { name = 'amy'}, { name = 'adam' } }
        assert.deepEqual(a,b)
      end)

      it('nested dict', function()
        local a = {name = 'adam', friends = { { name = 'amy' }, { name = 'bill'} }}
        local b = {friends = { { name = 'bill' }, { name = 'amy'} }, name = 'adam' }
        assert.deepEqual(a,b)
      end)
    end)
  end)


