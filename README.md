<!-- vim: set tw=0 :-->
![stackline-logo](https://user-images.githubusercontent.com/1683979/90966915-1f9b1400-e48d-11ea-8cbb-0ceea6fcfc39.png)
<p>
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.61-blue.svg?cacheSeconds=2592000" />
  <a href="#" target="_blank">
    <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg" />
  </a>
</p>

> Visualize yabai window stacks on macOS. Works with yabai & hammerspoon.

**Current status**

Unfortunately, I've haven't been able to work on this project since Q3 2021. Initially, this was due to a scary bout of RSI-esque finger pain that entirely prevented from me from typing (really – I had to use [Talon](https://talonvoice.com/) for basic computer use); The lesson I took away is that my hobbies shouldn't invovlve continuous typing (given I'm already typing all day for work). 

I apologize that I won't be working on this anymore – but that doesn't mean _you_ can't fork & carry the torch ;) 

**June 2021 update**

2021-06-06: Fixes & cleanup (`v0.1.61`)

- Fixed: offset indicators when menubar is not hidden (#80)
- Fixed: Icons don't change when toggling showIcons (#68)
- Fixed: Failure to parse json output from `yabai` that contains `inf` values (might fix #46)
- Removed external dependency on `jq`
- Removed shell script used to call out to `yabai`
- Replaced third-party json library with `hs.json`
- Refactored unnecessary object-orientation out of `stackline.query`
- Cleaned up `stackline.lib.utils`

See [changelog](https://github.com/AdamWagner/stackline/wiki/Changelog).

Everything below & more is in the [wiki](https://github.com/AdamWagner/stackline/wiki/Install-dependencies).

## What is stackline & why would I want to use it?

`stackline` adds unobtrusive visual indicators to complement `yabai`'s window stacking functionality.

A 'stack' enables multiple macOS windows to occupy the same screen space and behave as a single unit. 

Stacks are a recent addition (June 2020) to the (_excellent!_) macOS tiling window manager [koekeishiya/yabai](https://github.com/koekeishiya/yabai). See [yabai #203](https://github.com/koekeishiya/yabai/issues/203) for more info about `yabai`'s stacking feature. Currently, there's no built-in UI for stacks, which makes it easy to forget about stacked windows that aren't visible or get disoriented.

Enter `stackline`: unobtrusive visual indicators that complement `yabai` window stacks.

![stackline-demo](https://user-images.githubusercontent.com/1683979/90967233-08f6bc00-e491-11ea-9b0a-d75f248ce4b1.gif)

### Features

- 🚦 **Window indicators** show the position and window count of stacks
- 🔦 Use **app icons** to show apps inside stacks or slim indicators to save space
- 🧘 **Smart positioning**. Indicators stay on the outside edge of the window nearest the screen edge
- 🕹️ **Flexible control**. Control stackline via shell commands, or access the instance directly via hammerspoon.
- 🖥️ **Multi-monitor support** introduced in `stackline v0.1.55`

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


## Quickstart

### Prerequisites

- https://github.com/koekeishiya/yabai ([install guide](https://github.com/koekeishiya/yabai/wiki/Installing-yabai-(latest-release)))
- https://github.com/Hammerspoon/hammerspoon ([getting started guide](https://www.hammerspoon.org/go/))

See [wiki](https://github.com/AdamWagner/stackline/wiki/Install-&-configure-dependencies#user-content-configure-yabai-stacks) for example keybindings to create and navigate between stacks.

### Installation

1. [Clone the repo into ~/.hammerspoon/stackline](https://github.com/AdamWagner/stackline/wiki/Install-stackline#1-clone-the-repo-into-hammerspoonstackline)
2. [Install the hammerspoon cli tool](https://github.com/AdamWagner/stackline/wiki/Install-stackline#2-install-the-hammerspoon-cli-tool)

#### 1. Clone the repo into ~/.hammerspoon/stackline

```sh
# Get the repo
git clone https://github.com/AdamWagner/stackline.git ~/.hammerspoon/stackline

# Make stackline run when hammerspoon launches
cd ~/.hammerspoon
echo 'stackline = require "stackline"' >> init.lua
echo 'stackline:init()' >> init.lua
```

Now your `~/.hammerspoon` directory should look like this:

```
├── init.lua
└── stackline
  ├── conf.lua
  ├── stackline
  │   ├── configmanager.lua
  │   ├── query.lua
  │   ├── stack.lua
  │   ├── stackline.lua
  │   ├── stackmanager.lua
  │   └── window.lua
  └── lib
      └── …
```


#### 2. Install the hammerspoon cli tool

This is an optional step. It's required to send configuration commands to `stackline` from scripts, for example:

```sh
# Toggle boolean values with the hs cli
hs -c "stackline.config:toggle('appearance.showIcons')"
```
1. Ensure Hammerspoon is running
2. Open the hammerspoon console via the menu bar
3. Type `hs.ipc.cliInstall()` and hit return
                          
    If Hammerspoon is installed via Brew on Apple Silicon, `hs.ipc.cliInstall("/opt/homebrew")` [#2930](https://github.com/Hammerspoon/hammerspoon/issues/2930)
4. Confirm that `hs` is available by entering the following in your terminal (shell):

```sh
❯ which hs
/usr/local/bin/hs
```

<table>
<tbody>
<thead>
 <th>Open the Hammperspoon console via the menu bar</th>
 <th>Type `hs.ipc.cliInstall()` and hit return</th>
</thead>
  <tr>
    <td>
       <img src="https://user-images.githubusercontent.com/1683979/90970190-66513400-e4b6-11ea-9385-6e31571fd013.png"/>
    </td>
    <td>
       <img src="https://user-images.githubusercontent.com/1683979/100528318-769d3d00-3190-11eb-8444-1a70ad5f7baa.png"/>
    </td>
  </tr>
</tbody>
</table>

### Usage

- Launch `yabai` (or make sure it's running) (`brew services start yabai`)
- Launch `hammerspoon` (or make sure it's running) (`open -a "Hammerspoon"`)

**Create a window stack**

Now, assuming you've been issuing these commands from a terminal and _also_ have a browser window open on the same space, make sure your terminal is positioned immediately to the _left_ of your browser and issue the following command (or use [keybindings](https://github.com/AdamWagner/stackline/wiki/Install-dependencies)) to create a stack:

```sh
yabai -m window --stack next
```

Did the terminal window expand to cover the area previously occupied by Safari? Great! At this point, you should notice **two app icons at the top-left corner of your terminal window**, like this:

<img width="50%" src="https://user-images.githubusercontent.com/1683979/90969027-53376780-e4a8-11ea-88c9-354f43b0a4ef.png" />

You can toggle minimalist mode by turning the icons off:

```sh
hs -c 'stackline.config:toggle("appearance.showIcons")'
```

<img width="50%" src="https://user-images.githubusercontent.com/1683979/90969026-52063a80-e4a8-11ea-885d-9dd5b1409f20.png" />

See the wiki to [for details about how to do this with a key binding](https://github.com/AdamWagner/stackline/wiki/Keybindings).


## Thanks to contributors!

All are welcome. Feel free to dive in by opening an [issue](https://github.com/AdamWagner/stackline/issues/new) or submitting a PR.

[@alin23](https://github.com/alin23) initially proposed the [concept for stackline here](https://github.com/koekeishiya/yabai/issues/203#issuecomment-652948362) and encouraged [@AdamWagner](https://github.com/AdamWagner) to share the mostly-broken proof-of-concept publicly. Since then, [@alin23](https://github.com/alin23) dramatically improved upon the initial proof-of-concept with [#13](https://github.com/AdamWagner/stackline/pull/13), has some pretty whiz-bang functionality on deck with [#17](https://github.com/AdamWagner/stackline/pull/17), and has been a great thought partner/reviewer.  

[@zweck](https://github.com/zweck), who, [in the same thread](https://github.com/koekeishiya/yabai/issues/203#issuecomment-656780281), got the gears turning about how [@alin23](https://github.com/alin23)'s idea could be implemented and _also_ urged Adam to share his POC.

[@johnallen3d](https://github.com/johnallen3d) for being of one the first folks to install stackline, and for identifying several mistakes & gaps in the setup instructions. 

[@pete-may](https://github.com/pete-may) for saving folks from frustration by fixing an out-of-date command in the readme ([#48](https://github.com/AdamWagner/stackline/pull/48))

[@AdamWagner](https://github.com/AdamWagner) wrote the initial proof-of-concept (POC) for stackline.

Give a ⭐️ if you think (a more fully-featured version of) stackline would be useful!

### …on the shoulders of giants

Thanks to [@koekeishiya](https://github.com/koekeishiya) without whom the _wonderful_ [yabai](https://github.com/koekeishiya/yabai) would not exist, and projects like this would have no reason to exist.

Similarly, thanks to [@dominiklohmann](https://github.com/dominiklohmann), who has helped _so many people_ make chunkwm/yabai "do the thing" they want and provides great feedback on new and proposed yabai features.

Thanks to [@cmsj](https://github.com/cmsj), [@asmagill](https://github.com/asmagill), and all of the contributors to [hammerspoon](https://github.com/Hammerspoon/hammerspoon) for making macos APIs accessible to the rest of us!

Thanks to the creators & maintainers of the lua utility libraries [underscore.lua](https://github.com/mirven/underscore.lua), [lume.lua](https://github.com/rxi/lume), and [self.lua](https://github.com/M1que4s/self).

## License & attribution

stackline is licensed under the [&nearr;&nbsp;MIT&nbsp;License](stackline-license), the same license used by [yabai](https://github.com/koekeishiya/yabai/blob/master/LICENSE.txt) and [hammerspoon](https://github.com/Hammerspoon/hammerspoon/blob/master/LICENSE).

MIT is a simple permissive license with conditions only requiring the preservation of copyright and license notices. Licensed works, modifications, and larger works may be distributed under different terms and without source code.

[MIT](LICENSE) © Adam Wagner
