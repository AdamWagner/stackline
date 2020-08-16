# Refactor notes

## Overview

The goal of this file is to eliminate the need to 'shell out' to yabai to query
window data needed to render stackline, which would have addressed 
https://github.com/AdamWagner/stackline/issues/8 if @alin32 hadn't implemented
an even better fix faster than I could ;_) 

Originally, I thought the main problem with relying on `yabai` was the 0.03s sleep required to ensure that the new window state is, in fact, represented in the query response from `yabai`. I've since noticed secondary downsides, such as overall performance. Specifically, `yabai` is frequently sluggish during something simple like focusing a window. This is, I presume, a side effect of `stackline` pummelling yabai with dozens of (mostly superfluous) `query` invocations. :confusion:

So, instead, I want to try  try using hammerspoon's mature (if complicated) hs.window.filter and hs.window modules to achieve the same goal natively within hammerspon.

I also hope for tertiary benefits:

- easier to implement enhancements that we haven't even considered yet
- easier to maintain
- drop the jq dependency


┌────────┐
│ Status │
└────────┘

## 2020-08-16

### Changes

- Support stack focus "events"! Now, a stack takes on a new look when all windows become unfocused, with the last-active window distinct from the rest. This required a fair bit more complexity than expected, but is unavoidable (I think). There's a minor, barely noticable performance hit, too (not yet a problem, tho).
- Centralized indicator config settings & consistent "current style" retrieval. Reduced reliance on magic numbers (indicator style is more purely from user config settings now).
- Store a reference to the stack on each window, so any window can easily call stack methods. This allowed `redrawOtherAppWindows()` to move into the window class, where it's less awkward.
- Resolved bug in which unfocused same-app windows would 'flash focus' briefly

### Multi-monitor support is still a `?`

Stacks refresh on every space/monitor change, wasting resources shelling out to yabai & redrawing all indicators from scratch. 

Instead, it might better to update our data model to store: `screens[] → spaces[] → stacks[] → windows[]` … and then only update on *window* change events.

## 2020-08-02

We're not yet using any of the code in this file to actually render the indiators or query ata — all of that is still achieved via the "old" methods.

However, `query.lua` IS being required by ./core.lua and runs one every window focus event, and the resulting "stack" data is printed to the hammerspoon console.

The stack data structure differs from that used in ./stack.lua enough that it won't work as a drop-in replacement. I think that's fine (and it wouldn't be worth attempting to make this a non-breaking change, esp. since (hopefully?) no one is rellying on `stackline` for daily computing.

┌──────┐
│ Next │
└──────┘
- [x] Integrate appropriate functionality in Query module the Core module
- [x] Integrate appropriate functionality in Query module into the Stack module
- [x] Update key Stack module functions to have basic compatiblity with the new
  data structure
- [x] Simplify / refine Stack functions to leverage the benefits of having access to the hs.window module for each tracked window
- [x] Fix egregious indicator lag when switching the focused window in a stack


## Challenges & resolutions

┌──────────────────────────────────────┐
│ coalescing a torrent of async events │
└──────────────────────────────────────┘

`hs.timer.delayed` has done a great job taming the flood of window-change events that can occur when, say, resizing windows in a tiled layout.

NOTE: alternative: https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/deferred/init.lua This extension makes it simple to defer multiple actions after a delay from the initial execution.

Unlike `hs.timer.delayed`, the delay will not be extended with subsequent `run()` calls, but the delay will trigger again if `run()` is called again later.


┌──────────────────────────────────────┐
│ Methods to group windows into stacks │
└──────────────────────────────────────┘
TOP-LEFT ONLY
Rationale: Identifying frames by topLeft (frame.x, frame.y) of each window
addresses macos MIN WIN SIZE EDGE CASE that can result in a stacked
window NOT sharing the same dimensions.
PRO:
   ensures such windows will be members of the stack
CON:
   zoom-parent & zoom-fullscreen windows will ALSO be counted as stack members
PROPER FIX
   Filter out windows with a 0 stack-index using yabai data

NOTE: 'stackID' groups by full frame, so windows with min-size > stack
width will not be stacked properly. See above ↑ }}}


┌────────────────┐
│ Draw vs Redraw │
└────────────────┘
I originally apporached this with a "reactjs" mindset — _destroy everythig on every render — that'll keep things simple!

Unfortunately, it also made things _SLOW_.

The costliest aspect of drawing the indicators from scratch each time is
fetching the icon & generating the icons's image.

When it exists, it's MUCH faster/snappier to modify the attributes of existing canvas instances to achieve the desired "focused window has changed" effect.  Obviously, 100ms isn't going to ruin anyone's day… But it _is_ the difference between: 

- "Hey, I wonder if _stackline_ is what's been driing the fans at full blast recently? It _does_ seem to struggle…"

And:

- "Damnit, Chrome. When will the Chrome team get their shit together? This is ridiculous… _—force quit—_"


┌───────────────────────────────────┐
│ windows of the same app (hs bug)  │
└───────────────────────────────────┘
There's a very annoying Hammerspoon bug that needed to be worked around: windowUnfocused event not fired for same-app windows. 

See https://github.com/Hammerspoon/hammerspoon/issues/2400 for more detail.

NOTE: v1 *substantially* slowed down indicator redraw when focus changes. So much so as to justify storing an "otherAppWindows" field on each window. See history below:

v1: Search for stack by window:
    E.g., local stack = stacksMgr:findStackByWindow(stackedWin)

v2: Lookup stack from window instead of searching by window ID:
    local stack = stackedWin.stack

v3: Store `otherAppWindows` directly on window:

Related:

- `./stack.lua:22`
- `./stack.lua:30`
