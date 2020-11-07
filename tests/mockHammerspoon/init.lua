-- Notes on OOP lib {{{
-- Might want to review Classy OOP lib:
--    https://github.com/nightness/Classy/blob/master/Init.lua
--    https://github.com/ImagicTheCat/Luaoop
--    https://github.com/misterquestions/lua-class
--    https://github.com/mwilsnd/lava
--    https://github.com/M1que4s/Self
--    https://github.com/aschuhardt/lua-oop (REALLY small, and new)
--    https://github.com/RMuskovets/luaclass/blob/master/main.lua
--    https://github.com/ActivexDiamond/cruxclass/tree/master/src/libs WIP
--    https://github.com/nightness/Classy <- HAS Collection, DataSet, and even Queue!
--    https://github.com/benglard/luaclass (old, but nice)

-- THIS also shows how to attach functions to run when table values change (like eventable and tablemonitor):
--    https://github.com/MattSchrubb/OOPService/blob/master/ObjectVariable
--    … so does this ↓ ! in a very clean way
--    https://github.com/nightness/Classy/blob/master/Observable.lua

-- Interesting design choices w/ this Data handler (same author as ↑):
--    https://github.com/MattSchrubb/DataHandler



--  THE WINNER OF THE SHORT CLASS MODULE CONTEST!
--  https://github.com/niksok13/LuaClass/blob/master/class.lua
--     → 15 (FIFTEEN!!) lines
--     … and he built a finite state machine on top of it !?! 
--        https://github.com/niksok13/LuaFsm/blob/master/Fsm.lua
--     also something he calls "reactive dict", which I don't understand (yet): 
--        https://github.com/niksok13/ReactiveDict/blob/master/rdict.lua

--   TIE with 15 lines:
--   https://github.com/4v0v/class
--      Les functionality than niksok13 tho
--


--  11:30am
--  I read two lua user wiki articles that helped me grok lua's oop a bit more:
--      - http://lua-users.org/wiki/YetAnotherClassImplementation
--      - http://lua-users.org/wiki/SimpleLuaClasses
--      I really liked the 1st article, but unfort the code isn't that nice and
--      it hasn't been maintained: https://github.com/jpatte/yaci.lua
--      And the complexity that arises 1/2 through the article is … insane.

-- 11:40am udpate: I actually think this very old library is the simplest:
--
--
--      MAYBE
--      https://github.com/deepmind/classic is also nice 
--        - "strict" mode throws error when accessing nil fields
--      https://github.com/rxi/classic
--      https://github.com/grynmoor/class
--        - great balance b/n simplicty and power.  <- WINNER WINNER WINNER!!
--      https://github.com/4v0v/class
--        - 15 LINES! And does inheritance
--      https://github.com/binaryfs/lua-class
--        - multiple inheritance, but relatively simple
--
--
--      Interesting but unsure
--        - https://github.com/misterquestions/lua-class
--          Really nice create class syntax, but looks too sugar-y? And unclear
--          utility for the advanced features.
--

--
--      NO: 
--        - too complicated: https://github.com/siffiejoe/lua-classy
--        - too simple (no inherit):      https://github.com/GabeMillikan/ClassFactory
--        - too simple (no inherit): https://github.com/Dan23123/Lua-Simple-Class-Creator
--          


-- Robust mock of Roblox datastore service. Good reference.
--    https://github.com/buildthomas/MockDataStoreService

-- Similarly, this appears to be a playground framework. Things to learn from here:
--    https://github.com/wofead/FairyStudy/tree/master/Lua/Src
--    E.g., see their main app file: https://github.com/wofead/FairyStudy/blob/master/Lua/Src/App.lua
--        .. kinda like stackline.stackline.stackline, eh?
-- }}}

-- Mockaagne {{{
-- ———————————————————————————————————————————————————————————————————————————
-- mockagne = require "mockagne"

-- when = mockagne.when
-- any = mockagne.any
-- verify = mockagne.verify

-- t = mockagne.getMock()
-- }}}

-- Base class + utilties w/o depedencies
-- https://github.com/wherewindblow/lbase

return {
    -- constants
    configdir = os.getenv('HOME') .. '/.hammerspoon',

    -- geometry, inspect, and logger *can* be required directly!
    -- they neither directly nor indirectly depend on 'internal.so' files
    geometry = require 'hs.geometry',
    inspect = require 'hs.inspect',
    -- logger = require 'hs.logger',

    -- The rest are custom mocks
    appfinder = require 'tests.mockHammerspoon.appfinder',
    application = require 'tests.mockHammerspoon.application',
    canvas = require 'tests.mockHammerspoon.canvas',
    event = require 'tests.mockHammerspoon.event',
    eventtap = require 'tests.mockHammerspoon.eventtap',
    image = require 'tests.mockHammerspoon.image',
    ipc = { localPort = function() end },
    json = require 'tests.mockHammerspoon.json', -- luarocks module. NOT == stackline.lib.json (which is dkjson… such a mess)
    notify = require 'tests.mockHammerspoon.notify',
    screen = require 'tests.mockHammerspoon.screen',
    spaces = require 'tests.mockHammerspoon.spaces',
    task = require 'tests.mockHammerspoon.task',
    timer = require 'tests.mockHammerspoon.timer',
    window = require 'tests.mockHammerspoon.window',
}
