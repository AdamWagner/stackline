![stackline-logo](assets/stackline-github-banner@2x.png)
<p>
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.01-blue.svg?cacheSeconds=2592000" />
  <a href="#" target="_blank">
    <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg" />
  </a>
</p>

> Visualize yabai window stacks on macOS. Works with yabai & hammerspoon.

## ⚠️  ~~WARNING: THIS IS A PROOF-OF-CONCEPT~~ (it's more like an 'alpha' now!)

My humble thanks to all who have been suffering through error-ridden setup instructions, spinning fans, flickering UI, and crashes. I'm happy  to say that I _think_ this branch fixes enough of these issues that it _should_ be reasonable for actual use ;-) 

As before, if you notice something that's off, or could be better, please open an issue (or a  PR!).

---


## What is stackline & why would I want to use it?

Consider a browser window with many tabs.

A tabbed user interface consists of a collection of windows that occupy the same screen space. Only _one_ tabbed window may be visible at any given time, and it's the user's job to specify the 'active' window.

Tabbed interfaces provide visual indicators for each tab. The indicators are relatively small, so they can be visible at all times. Each indicator _identifies the contents of a window_ & _communicates its position relative to the active window_.

A 'stack' provides a generalized subset of a tabbed UI: it enables multiple to windows to occupy the same screen space, and provides mechanisms to navigate its member windows. It also provides mechanisms to add & remove windows from the stack.

Stacks are a recent addition (June 2020) to the (_excellent!_) macOS tiling window manager [koekeishiya/yabai,](https://github.com/koekeishiya/yabai,) and visualization UI is not yet in-the-box.

Enter stackline, which adds non-obtrusive visual indicators to yabai'e 's stacking functionality.

![stackline-demo](assets/stackline-demo.gif)

## Getting started with stackline

**Prerequisites**

1. https://github.com/koekeishiya/yabai ([install guide](http://https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)))
2. https://github.com/Hammerspoon/hammerspoon ([getting started guide](https://www.hammerspoon.org/go/))
3. https://github.com/stedolan/jq (`brew install jq`)


You're free to bind yabai commands using your favorite key remapper tool (skhd, karabiner elements, and even hammerspoon are all viable options).

That said, you're _probably_ using https://github.com/koekeishiya/skhd. If so, now is a good time to map keys for navigating and manipulating yabai stacks.

```sh
# Focus window up/down in stack
ctrl - n : yabai -m window --focus stack.next
ctrl - p : yabai -m window --focus stack.prev

# Add the active window  to the window or stack to the {direction}
# Note that this only works when the active window does *not* already belong to a stack
cmd + ctrl - left  : yabai -m window west --stack $(yabai -m query --windows --window | jq -r '.id')
cmd + ctrl - down  : yabai -m window south --stack $(yabai -m query --windows --window | jq -r '.id')
cmd + ctrl - up    : yabai -m window north --stack $(yabai -m query --windows --window | jq -r '.id')
cmd + ctrl - right : yabai -m window east --stack $(yabai -m query --windows --window | jq -r '.id')
```

### Installing stackline

1. Clone the repo into ~/.hammerspoon/stackline
2. Install the hammerspoon cli tool

#### 1. Clone the repo into ~/.hammerspoon/stackline

```sh
# Get the repo
git clone https://github.com/AdamWagner/stackline.git ~/.hammerspoon/stackline

# Make stackline run when hammerspoon launches
cd ~/.hammerspoon
echo 'local stackline = require "stackline.stackline.stackline"' >> init.lua
```

Now your `~/.hammerspoon` directory should look like this:

```
├── init.lua
├── stackline
│  ├── bin
│  │  └── yabai-get-stacks
│  ├── stackline
│  │  ├── core.lua
│  │  ├── stack.lua
│  │  └── window.lua
│  └── utils
│     ├── flatten.lua
│     ├── table-utils.lua
│     ├── underscore.lua
│     └── utils.lua
├── …
```


#### 2. Install the hammerspoon cli tool

Open the hammerspoon console via the menu bar, type `hs.ipc.cliInstall()`, and hit return.

Confirm that `hs` is now available:

```sh
❯ which hs
/usr/local/bin/hs
```

### RETRO? GO! FIDO? GO! GUIDANCE…

We're almost there!

```sh
# Launch yabai (or make sure it's running)
brew services start yabai

# Launch hammerspoon (or make sure it's running)
open -a "Hammerspoon"
```

Now, assuming you've been issuing these commands from a terminal and _also_ have a browser window open  on the same space, make sure your terminal is positioned immediately to the _left_ of Safari and issue the following command:

```sh
yabai -m window --stack next
```

Did the terminal window expand to cover the area previously occupied by Safari? Great! At this point, you should notice **two pill-shaped vertical blobs just left of the top-left corner of your terminal window**, like this:

![stackline setup 01](assets/stackline-setup-01@2x.png)

The default stack indicator style is a "pill" as seen ↑

To toggle icons:

```sh
 echo ":toggle_icons:1" | hs -m stackline-config
```

![stackline setup 02](assets/stackline-icon-indicators.png)

Image (and feature!) courtesy of [@alin23](https://github.com/alin23).


#### Keybindings

If you use `shkd`, you can bind a key combo to toggle icons `~/.skhdrc` file using the hammerspoon cli we installed earlier.

```sh
# if this doesn't work, try using the absolute path to the hammerspoon cli: /usr/local/bin/hs
shift + alt - b :  echo ":toggle_icons:1" | hs -m stackline-config
```

Alternatively, you can control stackline by accessing the instance directly via Hammerspoon.

For example, to bind a key combo to toggle icons, you could add the following to your `~/.hammerspoon/init.lua` file, _after_ requiring the stackline module & assigning a local variable `stackline`:

```lua
local stackline = require "stackline.stackline.stackline" -- you should already have this line ;-)

-- bind alt+ctrl+t to toggle stackline icons
hs.hotkey.bind({'alt', 'ctrl'}, 't', function()
    stackline.manager:toggleIcons()
end)
```

## Help us get to v1.0.0!

Give a ⭐️ if you think (a more fully-featured version of) stackline would be useful!


## Thanks to contributors!

All are welcome (actually, _please_ help us, 🤣️)! Feel free to dive in by opening an [issue](https://github.com/AdamWagner/stackline/issues/new) or submitting a PR.


[@alin23(https://github.com/alin23), initially proposed the [concept for stackline here](https://github.com/koekeishiya/yabai/issues/203#issuecomment-652948362) and encouraged [@AdamWagner](https://github.com/AdamWagner) to share the mostly-broken proof-of-concept publicly. Since then, [@alin23](https://github.com/alin23) dramatically improved upon the initial proof-of-concept with https://github.com/AdamWagner/stackline/pull/13, has some pretty whiz-bang functionality on deck with https://github.com/AdamWagner/stackline/pull/17, and has been a great thought partner/reviewer.  

[@zweck](https://github.com/zweck), who, [in the same thread](https://github.com/koekeishiya/yabai/issues/203#issuecomment-656780281), got the gears turning about how [@alin23](gh-alin23)'s idea could be implemented and _also_ urged Adam to share his POC.

[@johnallen3d](https://github.com/johnallen3d) for being one the first folks to install stackline, and for identifying several mistakes & gaps in the setup instructions. 

[@AdamWagner](https://github.com/AdamWagner) wrote the initial proof-of-concept (POC) for stackline.

### …on the shoulders of giants

Thanks to [@koekeishiya](gh-koekeishiya) without whom the _wonderful_ [yabai](https://github.com/koekeishiya/yabai) would not exist, and projects like this would have no reason to exist.

Similarly, thanks to [@dominiklohmann](https://github.com/dominiklohmann), who has helped _so many people_ make chunkwm/yabai "do the thing" they want and provides great feedback on new and proposed yabai features.

Thanks to [@cmsj](https://github.com/cmsj), [@asmagill](https://github.com/asmagill), and all of the contributors to [hammerspoon](https://github.com/Hammerspoon/hammerspoon) for making macOS APIs accessible to the rest of us!

Thanks to the creators & maintainers of the lua utility libaries [underscore.lua](https://github.com/mirven/underscore.lua), [lume.lua](https://github.com/rxi/lume), and [self.lua](https://github.com/M1que4s/self).

## License & attribution

stackline is licensed under the [&nearr;&nbsp;MIT&nbsp;License](stackline-license), the same license used by [yabai](https://github.com/koekeishiya/yabai/blob/master/LICENSE.txt) and [hammerspoon](https://github.com/Hammerspoon/hammerspoon/blob/master/LICENSE).

MIT is a simple permissive license with conditions only requiring preservation of copyright and license notices. Licensed works, modifications, and larger works may be distributed under different terms and without source code.

[MIT](LICENSE) © Adam Wagner

