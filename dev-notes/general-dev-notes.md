# stackline development notes 

## Inspiration
[hhtwm/init.lua](https//github.com/szymonkaliski/hhtwm/blob/master/hhtwm/init.lua)

Probably the best source of inspo, esp. the module.cache = {…} implementation.

[megalithic/window.lua](https://github.com/megalithic/dotfiles/blob/master/hammerspoon/hammerspoon.symlink/ext/window.lua)

 - [/utils/wm/window-handlers.lua](https://github.com/megalithic/dotfiles/blob/master/hammerspoon/hammerspoon.symlink/utils/wm/window-handlers.lua)
 - [/utils/wm/init.lua](https://github.com/megalithic/dotfiles/blob/master/hammerspoon/hammerspoon.symlink/utils/wm/init.lua)

[window_set.lua](https://github.com/macrael/panes/blob/master/Panes.spoon/window_set.lua)

Seems similar to what I'm doing, but it didn't run w/ SpoonInstall so I haven't used it yet

See how they manage window indicators:

- single (full-frame) canvas
- window methods set indicator = nil to kill
- [window.lua#L249](https://github.com/xcv58/Hammerspoon-xcv58/blob/master/hammerspoon/window.lua#L249)

**Others**

- [draw_border.lua](https://github.com/lanlan47879/dotfiles/blob/master/hammerspoon/config/draw_border.lua): Simple script to draw border on active window
- [status-display.lua](https://github.com/andweeb/ki/blob/master/src/status-display.lua): Ki status-display. He clears canvas elements *in the draw method*! This might work well, esp.  for updating.
- [Indicator_KE.lua](https://github.com/spring-haru/.hammerspoon/blob/master/Indicator_KE.lua): Another project, Indicator_KE.lua, does the same thing.
- [msteams.lua](https://github.com/thenoseman/zsh_config/blob/master/home/.hammerspoon/msteams.lua)
- [window.lua](https://github.com/NTT123/hswm/blob/master/window.lua): See how they manage tracking borders on windows as they're moved / resized
- [preocas.lua](https://github.com/asmagill/hammerspoon-config-take2/blob/master/preocas.lua): Complicated canvas stuff (asmagill)
- [quickPreview.lua](https://github.com/asmagill/hammerspoon-config-take2/blob/master/utils/_actions/_off/quickPreview.lua): Uses metatables to do canvas stuff. I don't really get it.
- [.hammerspoon/bar](https://github.com/goweiwen/dotfiles/tree/master/hammerspoon/.hammerspoon/bar):Status bar. Not *that* useful, for my purposes.
- [dashboard.lua](https://github.com/hollandan/hammerspoon/blob/master/dashboard.lua): This looks a little too simple, which might mean it's worth a second look later
- [colorboard.lua](https://github.com/CommandPost/CommandPost/blob/develop/src/plugins/finalcutpro/touchbar/widgets/colorboard.lua): CommandPost Colorboard The opposite of above, this is *complicated*!  Lots of state management, but not sure how applicable it is for me.
- [statuslets.lua](https://github.com/cmsj/hammerspoon-config/blob/master/statuslets.lua): statuslets


## Debugging

Debugging utils for lua

- https://github.com/renatomaia/loop-debugging

## Caching & queing

[pyericz/LuaWorkQueue](https://github.com/pyericz/LuaWorkQueue/tree/master/src)
A work queue implementation written in Lua.

[darkwark/queue-lua](https://github.com/darkwark/queue-lua)
Queue implementation for Lua and PICO-8
Newer (2020)

[hewenning/Lua-Container](https://github.com/hewenning/Lua-Container/blob/master/Container.lua)
🌏 Implement various containers, stack, queue, priority queue, heap, A* algorithms, etc. through Lua.

[KurtLoeffler/Lua_CachePool](https://github.com/KurtLoeffler/Lua_CachePool)
A lua library for creating pools of cached objects.


## Working with async in Hammerspoon

`hs.task` is async. There are 2 ways to deal with this:

1. `hs.timer.waitUntil(pollingCallback, func)`
2. `hs.task.new(…):start():waitUntilUNex()`

The 1st polls a callback to check if the expected result of the async task has
materialized.
The 2nd makes `hs.task` synchronous.

The docs strongly discourage use of the 2nd approach, but as long as there isn't
background work that could be done while waiting (there isn't in the use case
I'm thinking of), then it should be slightly _faster_ than polling since the
callback will fire immediately when the task completes. It also saves the cycles
needed to poll in the first place.

```lua
-- Wait until the win.stackIdx is set from async shell script
 hs.task.new("/usr/local/bin/dash", function(_code, stdout, stderr)
   callback(stdout)
 end, {cmd, args}):start():waitUntilExit()

 -- NOTE: timer.waitUntil is like 'await' in javascript
 hs.timer.waitUntil(winIdxIsSet, function() return data end)

-- Checker func to confirm that win.stackIdx is set 
-- For hs.timer.waitUntil
-- NOTE: Temporarily using hs.task:waitUntilExit() to accomplish the
-- same thing
function winIdxIsSet()
    if win.stackIdx ~= nil then
        return true
    end
end 
```



## Using hs.canvas

Yet another project has a similar take:

```lua
if canvas then
   canvas:delete()
end
```

Clear any pre-existing status display canvases

```lua
     for state, display in pairs(self.displays) do
        if display ~= nil then
            display:delete()
            self.displays[state] = nil
        end
     end
```
