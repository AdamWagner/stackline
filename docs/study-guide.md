# Hammerspoon & Yabai Study Guide for Stackline Architecture

Reference document for designing Stackline's next architecture. Every claim is labeled:
- **V** = Verified (with citation)
- **P** = Plausible inference (based on verified facts)
- **U** = Unknown (needs research/testing)

---

## A. Yabai Deep Understanding

### Mental Model & Terminology

**V** Yabai is a tiling window manager that extends macOS's built-in window manager using a binary space partitioning (BSP) algorithm. It manages windows across displays and spaces. ([yabai wiki](https://github.com/koekeishiya/yabai/wiki))

**V** Key entities: **displays** (physical screens), **spaces** (virtual desktops on a display), **windows** (individual app windows). Yabai organizes windows in a BSP tree per space. ([yabai wiki](https://github.com/koekeishiya/yabai/wiki))

**V** Stacks are NOT first-class objects. A stack is a BSP tree node that contains multiple windows instead of one. There is no `stack-id` field. Windows in a stack share `stack-index` values (1, 2, 3...) but there's no grouping key to distinguish "two stacks of two" from "one stack of four." ([yabai issue #672](https://github.com/koekeishiya/yabai/issues/672))

**V** Two kinds of stacking exist:
1. **BSP stacking** — Individual nodes in a BSP tree hold multiple windows. Created via `yabai -m window --stack <dir>`. Other nodes remain single windows. Mixed layouts.
2. **Stack layout** — `yabai -m space --layout stack`. ALL windows go into `view->root` as one giant stack. Like an iPhone — all fullscreen, no splitting.

([yabai source: view.c](https://github.com/koekeishiya/yabai/blob/master/src/view.c) — `view_add_window_node_with_insertion_point`: LAYOUT_STACK calls `view_stack_window_node(view->root, window)`, BSP stacking calls `view_stack_window_node(leaf, window)`)

**V** Stack-index behavior: In BSP mode, non-stacked windows have `stack-index: 0`. Stacked windows have `stack-index: 1, 2, 3...` within their node. In stack layout mode, all windows have `stack-index > 0`. ([yabai wiki discussions](https://github.com/koekeishiya/yabai/discussions/1795))

**V** When a new window is added to a stack, it is placed after the currently focused window (since v7.1.3, 2024-09-17). Previously it was added at the end. ([yabai CHANGELOG](https://github.com/koekeishiya/yabai/blob/master/CHANGELOG.md))

**V** Stack navigation selectors: `stack.prev`, `stack.next`, `stack.first`, `stack.last`, `stack.recent`, `stack.N` (numeric index, since v7.1.2). ([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands))

### Query Commands

#### `yabai -m query --windows`

**V** Returns JSON array of all windows (all spaces, all displays). Each window object:

```json
{
    "id": 1234,                    // int — unique window ID (matches hs.window:id())
    "pid": 5678,                   // int — process ID
    "app": "Safari",               // string — application name
    "title": "Google",             // string — window title
    "scratchpad": "",              // string — scratchpad label (empty if not in scratchpad)
    "frame": {
        "x": 35.0,                // float — absolute x position
        "y": 63.0,                // float — absolute y position
        "w": 1185.0,              // float — width
        "h": 741.0                // float — height
    },
    "role": "AXWindow",            // string — accessibility role
    "subrole": "AXStandardWindow", // string — accessibility subrole
    "root-window": true,           // bool — is root window of app
    "display": 1,                  // int — display index
    "space": 1,                    // int — space index
    "level": 0,                    // int — window level
    "sub-level": 0,                // int — window sub-level
    "layer": "normal",             // string — window layer
    "sub-layer": "normal",         // string — sub-layer
    "opacity": 1.0,                // float — window opacity
    "split-type": "none",          // string — "none", "vertical", "horizontal"
    "stack-index": 0,              // int — 0 = not stacked, 1+ = position in stack
    "can-move": true,              // bool
    "can-resize": true,            // bool
    "has-focus": false,            // bool — currently focused
    "has-shadow": true,            // bool
    "has-parent-zoom": false,      // bool
    "has-fullscreen-zoom": false,  // bool
    "has-ax-reference": true,      // bool — REMOVED in v7.1.7
    "is-native-fullscreen": false, // bool
    "is-visible": true,            // bool
    "is-minimized": false,         // bool
    "is-hidden": false,            // bool
    "is-floating": false,          // bool
    "is-sticky": false,            // bool
    "is-grabbed": false            // bool
}
```

([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands); [yabai source](https://github.com/koekeishiya/yabai/blob/master/src/window.c))

**Stackline uses:** `id`, `stack-index`. Everything else is available but unused.

**V** Filtering options:
- `--window [<sel>]` — single window (focused if no selector)
- `--space [<sel>]` — all windows on a space (current if no selector)
- `--display [<sel>]` — all windows on a display (current if no selector)

Selectors can be: `first`, `last`, `recent`, compass direction, numeric index, or label.

([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands))

**Important for Stackline:** `yabai -m query --windows --space` returns only current-space windows, reducing JSON payload and (in theory) the number of Accessibility API calls yabai makes. The TODO at `queryYabai.lua:116` already notes this. However, yabai is quite fast — the actual savings need measurement before calling this "high-value."

#### `yabai -m query --spaces`

**V** Returns JSON array of spaces:

```json
{
    "id": 1,                     // int — unique space ID
    "uuid": "...",               // string
    "index": 1,                  // int — space index on display
    "label": "",                 // string — user label
    "type": "bsp",               // string — "bsp", "stack", "float"
    "display": 1,                // int — display index
    "windows": [1234, 5678],     // int array — window IDs on this space
    "first-window": 1234,        // int
    "last-window": 5678,         // int
    "has-focus": true,            // bool
    "is-visible": true,           // bool
    "is-native-fullscreen": false // bool
}
```

([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands))

#### `yabai -m query --displays`

**V** Returns JSON array of displays:

```json
{
    "id": 1,
    "uuid": "...",
    "index": 1,
    "label": "",
    "frame": {"x": 0, "y": 0, "w": 2560, "h": 1440},
    "spaces": [1, 2, 3],
    "has-focus": true
}
```

([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands))

### Signals

**V** Yabai has a signal system that executes shell commands in response to events. Signals are added via:

```
yabai -m signal --add event=<EVENT> action=<COMMAND> [label=<LABEL>] [app[!]=<REGEX>] [title[!]=<REGEX>] [active=yes|no]
```

**V** Available signal events (relevant to Stackline):

| Event | Description | Env vars provided |
|---|---|---|
| `window_created` | Window created | `$YABAI_WINDOW_ID` |
| `window_destroyed` | Window destroyed | `$YABAI_WINDOW_ID` |
| `window_focused` | Window focused | `$YABAI_WINDOW_ID` |
| `window_moved` | Window moved | `$YABAI_WINDOW_ID` |
| `window_resized` | Window resized | `$YABAI_WINDOW_ID` |
| `window_minimized` | Window minimized | `$YABAI_WINDOW_ID` |
| `window_deminimized` | Window restored | `$YABAI_WINDOW_ID` |
| `window_title_changed` | Title changed | `$YABAI_WINDOW_ID` |
| `space_changed` | Space switch | `$YABAI_SPACE_ID`, `$YABAI_RECENT_SPACE_ID` |
| `display_changed` | Display switch | `$YABAI_DISPLAY_ID`, `$YABAI_RECENT_DISPLAY_ID` |
| `application_launched` | App started | `$YABAI_PROCESS_ID` |
| `application_terminated` | App quit | `$YABAI_PROCESS_ID` |
| `application_front_switched` | App activated | `$YABAI_PROCESS_ID`, `$YABAI_RECENT_PROCESS_ID` |
| `application_visible` | App unhidden | `$YABAI_PROCESS_ID` |
| `application_hidden` | App hidden | `$YABAI_PROCESS_ID` |
| `mission_control_enter` | MC entered | (none) |
| `mission_control_exit` | MC exited | (none) |

([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Commands))

**V** Signals execute as shell commands via the `action` parameter. They run as subprocesses. The environment variables are set before execution.

**P** Signal latency is essentially the latency of the yabai event detection + subprocess spawn. Since yabai has deep hooks into macOS window events (via accessibility API and/or SIP-disabled injection), its event detection should be near-instant. The subprocess spawn adds ~2-5ms.

#### Can signals replace polling?

**P** Partially. Yabai signals fire on the yabai side (after yabai has already processed the event), which means:
- Stack-index values are already updated when the signal fires
- Signals could tell Stackline "something changed, re-query now" without waiting for `hs.window.filter` + throttle
- But signals execute as shell commands — they'd need to communicate with Hammerspoon (e.g., via `hs` CLI or touching a file that a watcher monitors)

**P** Signals are most interesting as a way to catch events that HS `window.filter` misses or gets wrong (e.g., HS #2400), not as a performance optimization. The 500ms throttle in `hs.window.filter` is a Stackline config option (`maxRefreshRate`) — it can simply be lowered if responsiveness matters. And signal actions spawn a subprocess (`sh -c ...`), adding overhead rather than removing it.

**P** The `hs` CLI (from `hs.ipc`) could receive yabai signal notifications, but `hs.ipc` has known reliability issues — it may need reinstallation after each Hammerspoon restart. This makes it an unreliable foundation for an event pipeline. Signals remain a possible supplement for catching missed HS events, not a primary event source.

### IPC Mechanism

**V** Yabai uses a Unix domain socket at `/tmp/yabai_$USER.socket`. The `yabai` CLI connects to this socket, sends a message, reads the response, and exits. ([yabai source: yabai.c](https://github.com/koekeishiya/yabai/blob/master/src/yabai.c))

**V** Message protocol:
1. **Send:** `[4-byte int32 length][arg1\0arg2\0...\0\0]` — length prefix (little-endian int), followed by null-delimited arguments, double-null terminated
2. Client calls `shutdown(SHUT_WR)` to signal end of message
3. **Receive:** Server sends plain text/JSON response. First byte `0x07` indicates error. Server closes connection when done.

([yabai source: yabai.c](https://github.com/koekeishiya/yabai/blob/master/src/yabai.c); [python-yabai-client](https://github.com/xiamaz/python-yabai-client))

**V** One message per connection. Persistent connections are not supported. Each query needs a fresh socket connection. ([yabai issue #1308](https://github.com/koekeishiya/yabai/issues/1308))

**V** Per-call overhead: subprocess spawn (~2-5ms) + socket connect + message send + yabai processes query (10-50ms, dominated by Accessibility API calls) + response send + socket close. ([yabai issue #626](https://github.com/koekeishiya/yabai/issues/626))

**V** No batching support. Each query is a separate connection.

### Failure Modes

**V** If yabai daemon is not running, `socket_connect` fails. The CLI prints an error to stderr and continues (likely returning non-zero exit code). No retry logic exists. ([yabai source: yabai.c](https://github.com/koekeishiya/yabai/blob/master/src/yabai.c))

**V** SIP constraints: Without SIP disabled, yabai cannot use its scripting addition (`sa`), which means it cannot move windows between spaces, make windows sticky, or perform other "enhanced" operations. However, **querying** works fully regardless of SIP state — all query commands use the standard Accessibility API. ([yabai wiki](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection))

**P** If a window's app is unresponsive, the Accessibility API call for that window may hang, causing the entire `query --windows` response to be delayed. This is the main reliability risk. `query --windows --space` mitigates by querying fewer windows.

**V** Yabai can return `"inf"` values in frame coordinates (e.g., `"x":inf`) for windows with undefined geometry. Stackline already handles this: `stdout:gsub(':inf,',':0,')` in `u.task_cb`. ([lib/utils.lua:224](stackline/lib/utils.lua))

---

## B. Hammerspoon Deep Understanding

### Canvas System

**V** `hs.canvas` is **retained mode**. You add elements to an internal array; they persist and are re-rendered on each `drawRect:` cycle. ([hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html); [libcanvas.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/libcanvas.m))

**V** Each canvas is an `NSWindow` containing an `NSView`. Creating a canvas = registering with the macOS window server. This is heavyweight. Reuse canvases whenever possible. ([libcanvas.m](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/libcanvas.m))

**V** **Any element property change triggers a full canvas redraw — but this is still cheap at Stackline's scale.** Setting a property (e.g., `fillColor`) is a fast dictionary update that sets `needsDisplay = YES`. On the next frame, `drawRect:` iterates ALL elements. No per-element dirty tracking. With 2-20 elements (Stackline's range), this full iteration is negligible — it would only matter with hundreds of elements. ([libcanvas.m](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/libcanvas.m))

**V** **Changes coalesce within a run loop iteration.** Multiple property changes in one Lua callback result in one `drawRect:`. So `applyAppearance()` setting `fillColor` + `shadow` + `imageAlpha` = one redraw, not three. ([P — standard macOS NSView behavior](https://developer.apple.com/documentation/appkit/nsview))

**V** String ID access (`canvas["myId"]`) is a **linear scan** through all elements. O(n). Implemented in `canvas.lua`'s `__index` metamethod. ([canvas.lua source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/canvas.lua))

**P** At Stackline's scale (2-20 elements per canvas), the O(n) scan is negligible. Would only matter with hundreds of elements.

**V** `replaceElements()` with no args removes all elements. Implemented by looping `removeElement()`. Not atomic at the native level, but visually atomic due to `needsDisplay` coalescing. ([canvas.lua source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/canvas.lua))

**V** Canvases are **not bound to screens**. Positioned by absolute coordinates via `hs.canvas.new(rect)`. For multi-monitor, use `screen:fullFrame()` for the rect. Element positions are canvas-relative (0,0 = canvas top-left). ([hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html))

**V** Canvases only appear on the space where created. To show on all spaces: `canvas:behavior("canJoinAllSpaces")`. Stackline does NOT set this — it rebuilds on space change instead. ([hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html); [Spoons issue #2](https://github.com/Hammerspoon/Spoons/issues/2))

**P** Optimization opportunity: since canvases persist on their creation space (invisible but alive on other spaces), Stackline could maintain per-space canvases. Switching back to a space would show its old indicators instantly — no rebuild needed. This would require tracking canvases by space+screen rather than just screen, and updating elements on structural changes only.

**V** `canvas:delete()` is deprecated. Canvases are now garbage collected when Lua references are lost. ([GitHub issue #3168](https://github.com/Hammerspoon/hammerspoon/issues/3168))

**V** `canvas:clickActivating(false)` prevents Hammerspoon from stealing focus when canvas is clicked. Can affect `hs.window.filter` recognition. Stackline sets this correctly. ([hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html))

**V** `canvas:wantsLayer(true)` enables Core Animation / GPU compositing. Could improve rendering performance. ([hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html))

**U** Whether `wantsLayer(true)` makes a measurable difference for Stackline's simple shapes.

### Element Types (Complete List)

| Type | Key attributes |
|---|---|
| `rectangle` | `frame`, `roundedRectRadii`, `fillColor`, `strokeColor` |
| `oval` | `frame` |
| `circle` | `center`, `radius` |
| `arc` | `center`, `radius`, `startAngle`, `endAngle` |
| `ellipticalArc` | `frame`, `startAngle`, `endAngle` |
| `segments` | `coordinates` array (Bezier support) |
| `points` | `coordinates` |
| `text` | `text`, `textFont`, `textSize`, `textColor` |
| `image` | `image` (hs.image), `imageAlpha` |
| `canvas` | Nested canvas reference |
| `resetClip` | Resets clipping (no visual output) |

**Stackline uses:** `rectangle` (indicator bg) and `image` (app icon).

### Async & External Processes

#### hs.task

**V** Single-use: each `hs.task` object can only be used once. Must create new for each execution. ([hs.task docs](https://www.hammerspoon.org/docs/hs.task.html))

**V** Lifecycle: `hs.task.new(path, callback, [streamCallback], args)` → `:start()` → subprocess runs → callback fires with `(exitCode, stdout, stderr)`. ([hs.task docs](https://www.hammerspoon.org/docs/hs.task.html))

**V** Arguments bypass shell — passed directly to `exec()`. No quoting/escaping needed. ([hs.task docs](https://www.hammerspoon.org/docs/hs.task.html))

**V** Multiple tasks can run concurrently (separate NSTask subprocesses). All callbacks dispatch to main thread via `dispatch_sync(dispatch_get_main_queue(), ...)`. ([libtask.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/task/libtask.m))

**V** No built-in timeout. Would need `hs.timer` wrapper. ([hs.task docs](https://www.hammerspoon.org/docs/hs.task.html))

**V** `hs.execute()` is synchronous — **blocks entire Hammerspoon UI**. Never appropriate for yabai queries. ([hs docs](https://www.hammerspoon.org/docs/hs.html))

#### hs.socket (Unix Domain Socket Support)

**V** `hs.socket` supports Unix domain sockets. Confirmed by docs, source code (CocoaAsyncSocket/GCDAsyncSocket), and test suite. ([hs.socket docs](https://www.hammerspoon.org/docs/hs.socket.html); [test_socket.lua](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/socket/test_socket.lua))

**V** Constructor: `hs.socket.new(callback):connect(path)` where path is the Unix socket path. ([hs.socket docs](https://www.hammerspoon.org/docs/hs.socket.html))

**V** I/O runs on a GCD dispatch queue (background thread). Lua callbacks dispatch to main thread. Non-blocking. ([libsocket.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/socket/libsocket.m))

**V** Methods: `:write(data, [tag], [callback])`, `:read(delimiter_or_length, [tag])`, `:disconnect()`. Callback receives `(data, tag)`. ([hs.socket docs](https://www.hammerspoon.org/docs/hs.socket.html))

**P** Direct socket to yabai would eliminate fork/exec overhead (~5-10ms savings). Implementation sketch:

```lua
local function yabaiSocket(args, callback)
    local path = '/tmp/yabai_' .. os.getenv('USER') .. '.socket'
    -- Build message: 4-byte length + null-delimited args + double null
    local body = table.concat(args, '\0') .. '\0\0'
    local len = string.pack('<I4', #body)
    local msg = len .. body

    local response = ''
    local client = hs.socket.new(function(data)
        if data then
            response = response .. data
        else
            -- Connection closed by server = response complete
            if response:byte(1) == 0x07 then
                log.e('yabai error: ' .. response:sub(2))
            else
                callback(hs.json.decode(response:gsub(':inf,', ':0,')))
            end
        end
    end)
    client:connect(path, function()
        client:write(msg, -1, function()
            client:read(65536) -- read response
        end)
    end)
end
```

**U** Whether `hs.socket` fires the callback with `nil` data on server disconnect (needed for the "read until close" pattern). Needs testing.

**U** Whether Lua's `string.pack` is available in Hammerspoon's Lua 5.4. If not, manual byte encoding needed.

#### hs.ipc

**V** Uses Mach message ports (CFMessagePort). For controlling Hammerspoon from the `hs` CLI. Not relevant for yabai communication. ([hs.ipc docs](https://www.hammerspoon.org/docs/hs.ipc.html))

**V** But `hs` CLI can execute arbitrary Lua in Hammerspoon. This means yabai signals could trigger Lua code: `action="hs -c 'stackline:onSignal(...)'"`. Requires `hs.ipc` module loaded.

**P** `hs.ipc` has reliability issues in practice: the `hs` CLI may need reinstallation after each Hammerspoon restart. This makes it an unreliable foundation for any architecture that depends on it. Worth investigating but not a safe assumption.

#### JSON Parsing Performance

**V** `hs.json.decode` uses NSJSONSerialization (fast) + pushNSObject (slow for large data). For 5.3MB: 37ms + 3.9s. ([GitHub issue #2145](https://github.com/Hammerspoon/hammerspoon/issues/2145))

**P** For yabai output (5-50KB): well under 1ms. Not a bottleneck.

### Event Model

#### hs.window.filter

**V** Works via Accessibility API polling, not native OS event hooks. Uses internal timers and `NSWorkspace` notifications. ([hs.window.filter source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/window/window_filter.lua))

**V** `WINDOWMOVED_DELAY` is hardcoded at 0.5s. Can be reduced to 0.01s without observed issues, but requires modifying the source. Not configurable via API. ([GitHub issue #3709](https://github.com/Hammerspoon/hammerspoon/issues/3709))

**V** `windowsChanged` is a pseudo-event that fires on any change to the window list. Stackline uses it as a catch-all for missed `windowCreated` events. ([hs.window.filter docs](https://www.hammerspoon.org/docs/hs.window.filter.html))

**V** `allowRoles = 'AXStandardWindow'` filters to standard application windows, excluding dialogs, floating panels, etc. Drawing/canvas objects use custom subrole `"hammerspoonDrawing"` to avoid being seen by the filter. ([GitHub issue #576](https://github.com/Hammerspoon/hammerspoon/issues/576))

**V** `:getWindows()` returns currently tracked windows. The filter maintains an internal cache updated by polling. ([hs.window.filter docs](https://www.hammerspoon.org/docs/hs.window.filter.html))

**V** Known issue #2400: Focus events unreliable for same-app windows in stacks. This is why Stackline has the `hsBugWorkaround` / `unfocusOtherAppWindows` mechanism. ([Hammerspoon issue #2400](https://github.com/Hammerspoon/hammerspoon/issues/2400))

#### hs.window

**V** `:id()` returns a number (integer). Stable across the window's lifetime. Matches yabai's window `id`. ([hs.window docs](https://www.hammerspoon.org/docs/hs.window.html))

**V** `:frame()` always returns absolute screen coordinates (hs.geometry rect). No option to get screen-relative directly. Multi-monitor: coordinates can be negative (left-of-primary) or very large (right/below primary). ([hs.window docs](https://www.hammerspoon.org/docs/hs.window.html))

**V** Coordinate conversion methods on `hs.screen`:
- `screen:absoluteToLocal(geom)` — absolute → screen-relative (0,0 = screen top-left)
- `screen:localToAbsolute(geom)` — screen-relative → absolute
- `screen:toUnitRect(rect)` — absolute → unit rect (0.0–1.0 relative to screen)
- `screen:fromUnitRect(unitrect)` — unit rect → absolute

Stackline already uses `absoluteToLocal` in two places: `window.lua:55` (indicator positioning) and `stack.lua:97-98` (click hit-testing). Both conversions are needed because canvas element coordinates are relative to the canvas origin (screen top-left). ([hs.screen docs](https://www.hammerspoon.org/docs/hs.screen.html))

#### hs.spaces.watcher

**V** Fires callback with space index when active space changes. Uses deprecated `NSWorkspace` APIs (`activeSpaceDidChangeNotification`). ([hs.spaces docs](https://www.hammerspoon.org/docs/hs.spaces.html))

**P** Risk of breaking in future macOS versions, but has worked through many releases. No alternative exists in Hammerspoon.

#### Run Loop

**V** Hammerspoon runs a standard NSApplication run loop on the main thread. All Lua execution is single-threaded. Timer callbacks, task callbacks, socket callbacks — all dispatch as events on this run loop, executing sequentially, never concurrently. ([GitHub issue #911](https://github.com/Hammerspoon/hammerspoon/issues/911))

**V** A long-running callback blocks everything: UI, hotkeys, timers, other callbacks. Keep callbacks fast. ([GitHub issue #2395](https://github.com/Hammerspoon/hammerspoon/issues/2395))

---

## C. Integration Design Space

### Answering the Specific Questions

#### 1. Should each window instance manage its own yabai connection?

**No.** Tradeoffs:

| Approach | Pros | Cons |
|---|---|---|
| Per-window queries | Fine-grained: only query what changed | N subprocess spawns (or socket connections) per update. Yabai's AX API calls are per-window anyway, so N individual queries = N round-trips vs 1 batch. Way more total overhead. |
| Centralized query (current) | One subprocess, one JSON parse, one callback | Returns all windows (more data than needed). Must match windows to stacks. |
| Centralized + scoped | One subprocess querying current space only | Best of both worlds. Less data, one round-trip. |

**Recommendation:** Keep centralized query, switch to `--space` scoping. The cost of N socket connections (even direct) far exceeds one scoped query. Yabai doesn't support batching, and it only allows one message per connection.

#### 2. What is the exact shape of yabai query data?

See Section A, "Query Commands" above. The key fields for Stackline are:
- `id` (int) — matches `hs.window:id()`
- `stack-index` (int) — 0 = not stacked, 1+ = position in stack
- `frame` (object) — `{x, y, w, h}` floats
- `space` (int) — space index (useful for filtering)
- `has-focus` (bool) — whether window is focused

#### 3. What other capabilities exist? What are Signals?

See Section A, "Signals" above. Yabai signals fire on window events with `$YABAI_WINDOW_ID`, but their action mechanism (subprocess shell command) adds overhead rather than removing it. The 0.5s throttle is a configurable Stackline option, not a fundamental HS limitation. Signals are most interesting as a supplement to catch events that HS `window.filter` misses (e.g., HS #2400 workaround), not as a performance optimization.

#### 4. How does the Hammerspoon canvas system work, deeply?

See Section B, "Canvas System" above. Key insights:
- Retained mode, elements array, any change = full redraw (coalesced)
- String ID access is O(n) linear scan (fine at Stackline's scale)
- One canvas per screen is the right architecture (NSWindow is expensive)
- `wantsLayer(true)` might improve rendering (untested)

#### 5. How does hs.task work? Is there something better?

See Section B, "Async & External Processes" above. Key findings:
- `hs.task` works but has ~5-10ms fork/exec overhead per call
- `hs.socket` can connect directly to yabai's Unix domain socket, eliminating subprocess overhead
- The real bottleneck is yabai's Accessibility API calls, not the IPC mechanism
- Scoped queries (`--space`) are low-risk but unproven — need measurement to confirm actual savings

### Architecture Candidates

#### Architecture 1: Current + Scoped Query (Minimal Change)

```
HS event → throttle → shouldQuery() → hs.task: yabai -m query --windows --space
         → merge → ingest → rebuild
```

**Changes:** One line in queryYabai.lua: `query --windows` → `query --windows --space`

| Aspect | Assessment |
|---|---|
| Latency savings | Theoretical: fewer AX calls = faster. Needs measurement. |
| Risk | Low |
| Complexity | One-line change |
| Migration | Trivial |

**Failure modes:** None new. If `--space` returns extra windows (known yabai bug), frame grouping filters them out. Yabai is already fast on Apple Silicon — savings may be negligible.

#### Architecture 2: Direct Socket + Scoped Query

```
HS event → throttle → shouldQuery() → hs.socket: direct to yabai daemon
         → merge → ingest → rebuild
```

**Changes:** Replace `hs.task.new(yabai_path, ...)` with `hs.socket.new(...):connect(socket_path)`

| Aspect | Assessment |
|---|---|
| Latency savings | 5-10ms (no fork/exec) on top of scoped query gains |
| Risk | Medium (socket protocol needs testing) |
| Complexity | ~30 lines replacing `yabai()` function |
| Migration | Replace one function in queryYabai.lua |

**Failure modes:** Socket read-until-close behavior needs verification. Protocol mismatch (int32 header) needs testing. Fallback to hs.task if socket fails.

#### Architecture 3: Yabai Signals (Supplementary Event Source)

```
Yabai signal → hs CLI → stackline:onSignal(event, winId)
             → trigger query or targeted update
```

**Changes:** Add yabai signal registration, add signal handler in stackline.lua.

| Aspect | Assessment |
|---|---|
| Value | Catches events HS misses (e.g., HS #2400 same-app focus bugs) |
| Risk | Medium-high (`hs.ipc` unreliable, subprocess overhead per signal) |
| Complexity | Moderate — new event source alongside existing hs.window.filter |
| Migration | Additive — supplement to hs.window.filter, not replacement |

**Failure modes:** `hs.ipc` needs reinstallation after HS restart. Signal action spawns `sh` subprocess. Race conditions between signal-triggered and timer-triggered updates. No batching — rapid events spawn many subprocesses.

**Note:** The 500ms HS throttle is a configurable Stackline option (`maxRefreshRate`), not a fundamental limitation. Signals don't bypass a hard constraint — they add a second event source. Most valuable for reliability (catching missed events), not for latency.

#### Architecture 4: State-then-Render (Approach 2 from earlier discussion)

```
Data side (pure):  HS windows + yabai JSON → group → merge → state description
Render side (diff): new state + old state → diff by winId → minimal canvas updates
```

**This is orthogonal to the connection architecture.** It can be combined with any of 1-3. The key insight is separating "what should be on screen" from "how to show it."

| Aspect | Assessment |
|---|---|
| Wins | Testability (pure functions), debuggability (dump state), keyed reconciliation |
| Risk | Medium (data side is low-risk, render diff is harder) |
| Complexity | Moderate refactor of ingest/rebuild pipeline |
| Migration | Can be done incrementally — extract data side first, add diff later |

### Recommended Sequence

1. **Performance instrumentation**. Add timing at pipeline stages. Measure before optimizing.
2. **Scoped query** (`--space`). One-line change, zero risk. Do early, measure impact.
3. **State-then-Render separation**. Makes everything else easier. Enables keyed reconciliation.
4. **Per-space canvas caching**. Avoid rebuild on space switch. Leverages canvas space behavior.
5. **Direct socket** (hs.socket). Eliminates subprocess overhead (~5-10ms). Do if measurement shows it matters.
6. **Yabai signals**. Supplementary event source for reliability. Do if HS #2400 or missed events remain a problem.

### Performance Instrumentation Points (Do This First)

Add timing at these points before making any optimization changes:

```
[T0] Event received (HS or signal)
[T1] shouldQuery() decision
[T2] Query sent (task start or socket connect)
[T3] Response received (callback fired)
[T4] JSON parsed + merged
[T5] Ingest complete
[T6] Canvas updated (rebuild or redraw)
```

Current estimated budget:
- T0→T1: 0-500ms (throttle)
- T1→T2: <1ms
- T2→T3: 10-50ms (yabai query)
- T3→T4: <1ms (JSON parse)
- T4→T5: <1ms (merge + ingest)
- T5→T6: 1-10ms (canvas operations)

Measuring these will tell us where time is actually spent, so optimizations target real bottlenecks instead of theoretical ones. Note: focus changes (fast path) don't involve T0–T5 at all — they go directly to T6 via `redrawIndicator()`. The budget above is for the slow path only.

---

## Sources

### Yabai
- [yabai wiki](https://github.com/koekeishiya/yabai/wiki)
- [yabai CHANGELOG](https://github.com/koekeishiya/yabai/blob/master/CHANGELOG.md)
- [yabai source: yabai.c](https://github.com/koekeishiya/yabai/blob/master/src/yabai.c) — IPC client
- [yabai source: message.c](https://github.com/koekeishiya/yabai/blob/master/src/message.c) — message parsing
- [yabai source: view.c](https://github.com/koekeishiya/yabai/blob/master/src/view.c) — BSP tree + stacking
- [yabai issue #672](https://github.com/koekeishiya/yabai/issues/672) — stack-id feature request (unimplemented)
- [yabai issue #626](https://github.com/koekeishiya/yabai/issues/626) — query performance
- [yabai issue #1308](https://github.com/koekeishiya/yabai/issues/1308) — one message per connection
- [python-yabai-client](https://github.com/xiamaz/python-yabai-client) — reference socket implementation

### Hammerspoon
- [hs.canvas docs](https://www.hammerspoon.org/docs/hs.canvas.html)
- [canvas.lua source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/canvas.lua)
- [libcanvas.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/canvas/libcanvas.m)
- [hs.task docs](https://www.hammerspoon.org/docs/hs.task.html)
- [libtask.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/task/libtask.m)
- [hs.socket docs](https://www.hammerspoon.org/docs/hs.socket.html)
- [libsocket.m source](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/socket/libsocket.m)
- [hs.socket test_socket.lua](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/socket/test_socket.lua)
- [hs.window.filter docs](https://www.hammerspoon.org/docs/hs.window.filter.html)
- [hs.ipc docs](https://www.hammerspoon.org/docs/hs.ipc.html)
- [GitHub issue #911](https://github.com/Hammerspoon/hammerspoon/issues/911) — threading model
- [GitHub issue #2145](https://github.com/Hammerspoon/hammerspoon/issues/2145) — JSON performance
- [GitHub issue #2400](https://github.com/Hammerspoon/hammerspoon/issues/2400) — focus event bug
- [GitHub issue #3168](https://github.com/Hammerspoon/hammerspoon/issues/3168) — canvas GC
- [GitHub issue #3709](https://github.com/Hammerspoon/hammerspoon/issues/3709) — window.filter delay
