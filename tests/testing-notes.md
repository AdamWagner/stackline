To disable output of SUT:

```lua
local old_print
setup(function()
  old_print = print
  print = function() end
end)
teardown(function()
  print = old_print
end
```


# Test inspo 
   - [/13k/invokation/spec][1]
   - [/kuailedeluojie-sudo/lua_study/base/spec/unit/util_spec.lua][2]
   - [/victorpopkov/spec/helper.lua][3]
   - [/exosite/squel/spec/delete_spec.lua][4]
   - [/LuaDist-testing/scene/tree/master/spec][5]

More complex use-cases
   - [/Tieske/ncache.lua/blob/master/spec/ncache_spec.lua][6]
   - [/xiecanjie/roem/tree/master/spec][7]

Integration test files search:
  - [lua integration test search results][8]
  - [lua integration tests with busted][9]


# EVENT implementations 
  [/djs-it/LinkUp/DataTable.lua][10]
  DataTable class with Eventable
  Again: [/djs-it/LinkSrc/blob/LinkUtil.lua][11]

  /Bytebit-Org/fitumi
  Fake It 'Till You Make It - A unit testing utility for faking dependencies in Lua


```lua
-- Simple class initiation:
-- All below from: /Tieske/timerwheel.lua/blob/master/spec/timerwheel_spec.lua
describe("new()", function()
  it("succeeds without options", function()
    local wheel = tw.new()
    assert.is_table(wheel)
    assert.is_function(wheel.step)
  end)
  it("fails with bad options", function()
    local function factory(opts)
      return function()
        tw.new(opts)
      end
    end
    assert.has_error(function()
      tw:new()
    end, "new should not be called with colon ':' notation")
    assert.has_error(factory {precision = -0.3},
        "expected 'precision' to be number > 0")
    assert.has_error(factory {precision = 0},
        "expected 'precision' to be number > 0")
    assert.has_error(factory {ringsize = -1},
        "expected 'ringsize' to be an integer number > 0")
    assert.has_error(factory {ringsize = 0},
        "expected 'ringsize' to be an integer number > 0")
    assert.has_error(factory {ringsize = 1.5},
        "expected 'ringsize' to be an integer number > 0")
    assert.has_error(factory {now = "hello"},
        "expected 'now' to be a function, got: string")
    assert.has_error(factory {err_handler = "hello"},
        "expected 'err_handler' to be a function, got: string")
  end)
  it("succeeds with proper options", function()
    local wheel = tw.new {
      precision = 0.5,
      ringsize = 10,
      now = function() end,
      err_handler = function() end,
    }
    assert.is_table(wheel)
    assert.is_function(wheel.step)

  end)
end)
```


[1]: /13k/invokation/tree/master/spec
[2]: /kuailedeluojie-sudo/lua_study/blob/master/koreader/base/spec/unit/util_spec.lua
[3]: /victorpopkov/dst-mod-dev-tools/blob/master/spec/helper.lua
[4]: /exosite/squel/blob/master/spec/delete_spec.lua
[5]: /LuaDist-testing/scene/tree/master/spec
[6]: /Tieske/ncache.lua/blob/master/spec/ncache_spec.lua
[7]: /xiecanjie/roem/tree/master/spec
[8]: /search?p=4&q=language%3Alua+integration+spec+in%3Apath&type=Code
[9]: /search?q=language%3Alua+integration+in%3Apath+describe+in%3Afile&type=Code
[10]: /djs-it/LinkUp/blob/a9df86c07ea7f28a1822cd660d995c593ac3b9df/src/fmw/data/DataTable.lua
[11]: /djs-it/LinkSrc/blob/62ffa7bd8fbb1232784aa9130026fa32bf87444c/app/LinkUtil.lua
