# stackline development notes 

## Inspiration

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
