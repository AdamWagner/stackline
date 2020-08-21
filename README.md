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

**2020-08-09 Status update**

This update makes adds performance, reliability, and even some new functionality: 

- Hammerspoon is now responsible for querying and processing macOS window data. Hammerspoon's ability to coalesce the swarm of asynchronous change events that were causing your fans to spin up is a major improvement over calling `yabai -m query --windows --space …` dozens of times a minute. The move also made it possible to take a more traditional OOP approach, which has made tracking and mutating all of this desktop state a bit simpler.  Unfortunately, it's still necessary to call out `yabai`, as it's the the keeper of each window's `stack-index` — a key bit of info that, afaict, is neither available elsewhere nor inferrable. That said, `yabai` is invoked _much less frequently_ in this update.
- In addition to only updating data when it's actually necessary, special attention has been given to _changing focus within a stack_: the POC blew away all of the UI state and _regenerated it from scratch … every … time … a window gained/lost focus. That approach is easier to think about, but it's far too slow to be useful. In this version, indicators should be _snappy_ when changing focus :)

There's also some fun new functionality:

- Stack indicators are always positioned on the side of the window that's closest to the edge of the screen. This allows for tight `window_gaps`, — even with `showIcons` enabled. 
- Magic numbers are less entangled in the implementation details (though it's still pretty bad) — and a few of them have even been abstracted into easy-to-mess with configuration settings. The new `config.lua` file isn't that exciting yet (it's mostly boilerplate), but I think the _next_ update will bring the much-needed configuration mojo.

**NOTE:** even though this update focused on performance and reliability, there are _still plenty of bugs_. One particularly annoying bug appears to be [Hammerspoon's fault](https://github.com/Hammerspoon/hammerspoon/issues/2400), and required ugly workarounds to get a so-so result. 

Also I'm still very new to lua and find its behavior (particularly its silence about errors) pretty baffling … it's quite hard to diagnose — or — even _notice_ small problems, which of course means they eventually become large, messy problems. ( ͡° ʖ̯ ͡°) If you're a lua pro and you're reading this, it'd be great to get your critique.  ---

**2020-08-01 | Status update**

https://github.com/AdamWagner/stackline is a proof-of-concept for visualizing the # of windows in a stack & the currently active window. 

There is much crucial fuctionality that is either missing or broken. For example, stack indicators do not refresh when:

1. the tree is rotated or mirrored
2. updating padding or gap values
3. a stacked window is warped out of the stack
4. app icons are toggled on/off


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
echo 'require "stackline.stackline.stackline"' >> init.lua
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

You can also configure a keybinding in your `init.lua` to toggle icons:

```lua
stackline = require "stackline.stackline.stackline"
hs.hotkey.bind({'alt', 'ctrl'}, 't', function()
    stackline.manager:toggleIcons()
end)
```

![stackline setup 02](assets/stackline-icon-indicators.png)

Image (and feature!) courtesy of [@alin23](https://github.com/alin23).

## Help us get to v1.0.0!

Give a ⭐️ if you think (a fully functional version of) stackline would be useful!


## Thanks to contributors!

All are welcome (actually, _please_ help us, 🤣️)! Feel free to dive in by opening an [issue](https://github.com/AdamWagner/stackline/issues/new) or submitting a PR.

[@AdamWagner](https://github.com/AdamWagner) wrote the initial proof-of-concept (POC) for stackline.

[@alin23](https://github.com/alin23), initially proposed the [concept for stackline here](https://github.com/koekeishiya/yabai/issues/203#issuecomment-652948362) and encouraged [@AdamWagner](https://github.com/AdamWagner) to share this mostly-broken POC publicly.

- After [@alin23](https://github.com/alin23)'s https://github.com/AdamWagner/stackline/pull/13, stackline sucks a lot less.

Thanks to [@johnallen3d](https://github.com/johnallen3d) for being one the first folks to install stackline, and for identifying several mistakes & gaps in the setup instructions. 

[@zweck](https://github.com/zweck), who, [in the same thread](https://github.com/koekeishiya/yabai/issues/203#issuecomment-656780281), got the gears turning about how [@alin23](gh-alin23)'s idea could be implemented and _also_ urged Adam to share his POC.

### …on the shoulders of giants

Thanks to [@koekeishiya](gh-koekeishiya) without whom the _wonderful_ [yabai](https://github.com/koekeishiya/yabai) would not exist, and projects like this would have no reason to exist.

Similarly, thanks to [@dominiklohmann](https://github.com/dominiklohmann), who has helped _so many people_ make chunkwm/yabai "do the thing" they want, that I seriously doubt either project would enjoy the vibrant user bases they do today.

And of course, thanks to [@cmsj](https://github.com/cmsj), [@asmagill](https://github.com/asmagill), and all of the contributors to [hammerspoon](https://github.com/Hammerspoon/hammerspoon) for opening up macOS APIs to all of us!

Thanks to the creators & maintainers of [underscore.lua](https://github.com/mirven/underscore.lua), [lume.lua](https://github.com/rxi/lume), [self.lua](https://github.com/M1que4s/self), and several other lua utility belts that have been helpful.

## License & attribution
stackline is licensed under the [&nearr;&nbsp;MIT&nbsp;License](stackline-license), the same license used by [yabai](https://github.com/koekeishiya/yabai/blob/master/LICENSE.txt) and [hammerspoon](https://github.com/Hammerspoon/hammerspoon/blob/master/LICENSE).

MIT is a simple permissive license with conditions only requiring preservation of copyright and license notices. Licensed works, modifications, and larger works may be distributed under different terms and without source code.

[MIT](LICENSE) © Adam Wagner

