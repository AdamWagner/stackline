<!-- vim: set tw=0 :-->
![stackline-logo](https://user-images.githubusercontent.com/1683979/90966915-1f9b1400-e48d-11ea-8cbb-0ceea6fcfc39.png)
<p>
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.50-blue.svg?cacheSeconds=2592000" />
  <a href="#" target="_blank">
    <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg" />
  </a>
</p>

> Visualize yabai window stacks on macOS. Works with yabai & hammerspoon.

You can find all the info below and more in the [wiki](https://github.com/AdamWagner/stackline/wiki/Install-dependencies).
See what's new in the [changelog](https://github.com/AdamWagner/stackline/wiki/Changelog).

## What is stackline & why would I want to use it?

`stackline` adds simple, unobtrusive visual indicators to compliment `yabai`'s window stacking functionality.

A 'stack' is a generalized subset of a tabbed UI that enables multiple macOS windows to occupy the same screen space and behave as a single unit. A stack let's a user…

- add & remove windows from a stack
- navigate between stacked windows
- _understand the contents of a stack at a glance_

Stacks are a recent addition (June 2020) to the (_excellent!_) macOS tiling window manager [koekeishiya/yabai](https://github.com/koekeishiya/yabai). Currently, there is no visual indication of the active window, surrounding inactive windows, or even that a stack exists in the first place.

Enter `stackline`, which adds simple, unobtrusive visual indicators to compliment `yabai`'s window stacking functionality.

![stackline-demo](https://user-images.githubusercontent.com/1683979/90967233-08f6bc00-e491-11ea-9b0a-d75f248ce4b1.gif)

### Features

- 🚦 **See your stacks**. Window indicators show you which BSP leaves are stacks & how many windows each stack contains
- 🔦 **App icons**. Toggle icons on to know exactly which apps are stacked where. Toggle icons off and get a slim minimalistic indicator that doesn't get in the way.
- 🧘‍♂️️ **Smart positioning**. Whichever mode you prefer, indicators always stay out of the way on the outside edge of the window (nearest the screen edge)
- 🧮 **Always in sync**. stackline keeps track of stacks as you move between spaces, resize windows, and add or remove stacks.
- 🕹️ **Flexible control**. Control stackline via shell commands, or access the instance directly via Hammerspoon.

<table>
<tbody>
<thead>
 <th>Icon indicators…</th>
 <th>…or minimal indicators</th>
</thead>
  <tr>
    <td>
       <img src="https://user-images.githubusercontent.com/1683979/90966909-1ad66000-e48d-11ea-9f64-7708a9e1d149.png"/>
    </td>
    <td>
       <img src="https://user-images.githubusercontent.com/1683979/90966912-1dd15080-e48d-11ea-9890-3e10ea7ce397.png"/>
    </td>
  </tr>
</tbody>
</table>


## Getting started with stackline

### Prerequisites

- https://github.com/koekeishiya/yabai ([install guide](http://https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)))
- https://github.com/Hammerspoon/hammerspoon ([getting started guide](https://www.hammerspoon.org/go/))
- https://github.com/stedolan/jq (`brew install jq`)

See [wiki](https://github.com/AdamWagner/stackline/wiki/Install-dependencies) for example keybindings to create and navigate between stacks.

### Installing stackline

1. [Clone the repo into ~/.hammerspoon/stackline](https://github.com/AdamWagner/stackline/wiki/Install-stackline#1-clone-the-repo-into-hammerspoonstackline)
2. [Install the hammerspoon cli tool](https://github.com/AdamWagner/stackline/wiki/Install-stackline#2-install-the-hammerspoon-cli-tool)

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

Now, assuming you've been issuing these commands from a terminal and _also_ have a browser window open  on the same space, make sure your terminal is positioned immediately to the _left_ of Safari and issue the following command (or use [keybindings](https://github.com/AdamWagner/stackline/wiki/Install-dependencies)) to create a stack:

```sh
yabai -m window --stack next
```

Did the terminal window expand to cover the area previously occupied by Safari? Great! At this point, you should notice **two app icons at the top-left corner of your terminal window**, like this:

<img width="50%" src="https://user-images.githubusercontent.com/1683979/90969027-53376780-e4a8-11ea-88c9-354f43b0a4ef.png" />

If the icons are a bit too heavy for you, you can toggle minimalist mode by turning the icons off:

```sh
 echo ":toggle_icons:0" | hs -m stackline-config
 # …use ":toggle_icons:1" to toggle icons back on
```


<img width="50%" src="https://user-images.githubusercontent.com/1683979/90969026-52063a80-e4a8-11ea-885d-9dd5b1409f20.png" />

The minimalist stack indicator style is shown here ↑

See the wiki to [for details about how to do this with a key binding!](https://github.com/AdamWagner/stackline/wiki/Keybindings).


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
