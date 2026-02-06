# Stackline — Architecture & Design Notes

## What Stackline Does

Stackline renders visual indicators (app icons or minimal pills) on windows that Yabai has stacked. Yabai's window stacking has no built-in UI — you can't see what's in a stack or which window is focused. Stackline fills that gap.

## The Three-System Relationship

```
Yabai (C binary)          Stackline (Lua)           Hammerspoon (ObjC + Lua)
─────────────────         ───────────────           ────────────────────────
Manages window tiling     Bridges the two           Provides Lua runtime,
& stacking. Queried       systems. Contains         window event subscriptions,
via CLI for stack-index   all application logic.    canvas drawing API, mouse
per window.                                         event taps, app icon lookup.
```

- Hammerspoon is both the **event source** (when did something change?) and the **rendering target** (draw indicators via `hs.canvas`).
- Yabai is a **read-only data source** consulted via async subprocess (`yabai -m query --windows`) for authoritative stack ordering.
- Stackline orchestrates everything: listens for events, decides what changed, queries yabai when needed, and renders.

Note: Yabai does have a signal system (`yabai -m signal`) that can trigger shell commands on window events. Stackline doesn't currently use it — it relies on Hammerspoon's `hs.window.filter` instead — but yabai signals could potentially replace or supplement the HS event system.

## The Core Data Problem

**Neither Hammerspoon nor yabai alone provides enough information to render stack indicators.** Understanding why is essential to working on this code.

### What Hammerspoon knows
- All visible windows and their frame rectangles (x, y, w, h)
- Which window is focused
- Real-time window events (created, moved, focused, destroyed, etc.)

### What Hammerspoon does NOT know
- Whether windows sharing the same frame are actually stacked (vs. just overlapping)
- The order of windows within a stack

### What yabai knows
- Each window's `stack-index`: its position within its stack (1, 2, 3...), or 0 if not stacked

### What yabai does NOT know (or rather, does not expose)
- **Which stack a window belongs to.** There is no `stack-id` or grouping key. Two separate stacks both have windows with `stack-index: 1`, `stack-index: 2`, etc. You cannot distinguish "two stacks of two" from "one stack of four" using `stack-index` alone.

### How stackline solves this
1. **Frame-based grouping** (from Hammerspoon, fast, synchronous): windows with the same frame coordinates are grouped together. This gives us the *grouping* — which windows are in the same stack. The grouping key is `stackId = "x|y|w|h"` (see `window.lua:makeStackId()`).
2. **stack-index** (from yabai, slower, async subprocess): gives us the *ordering* within each group, and confirms which windows are truly stacked (stack-index > 0) vs. just overlapping (stack-index == 0).
3. **Merge**: `queryYabai.lua:mergeWinStackIdxs()` assigns yabai's `stackIdx` to each grouped window. Windows with `stackIdx == 0` are removed from their group (they were false positives from frame-matching).

### Fuzzy frame detection
Stacked windows *should* share identical frames, but in practice they often don't, for two reasons:

1. **App minimum sizes.** Some macOS apps enforce a minimum window size. When a stack's frame is smaller than an app's minimum, that app's window will be larger than its siblings. These differences can be significant — not just a few pixels.
2. **Small frame drift.** Even without min-size constraints, stacked windows' frames can be off by a few pixels despite being in the same stack.

`fzyFrameDetect` addresses both by rounding frame dimensions to the nearest `fuzzFactor` (default 30px) before generating the grouping key (`stackIdFzy`).

This is safe to be aggressive with because **yabai corrects false positives**. Even if a large fuzzFactor incorrectly groups non-stacked windows together, `mergeWinStackIdxs()` checks each window's `stack-index` from yabai and removes any with `stack-index == 0` (queryYabai.lua:84-89). The frame grouping is just a rough first pass; yabai is the authority. False positives get pruned. The only real risk is a fuzzFactor that's *too small* — causing false negatives where truly stacked windows with different min-sizes fail to group and are never sent to yabai for confirmation.

## Two Update Paths

### Slow path: structural changes (query + rebuild)
Triggered by: window created, destroyed, moved, hidden, minimized, fullscreened, space change.

```
HS window event → throttle (0.5s) → groupWindows() → shouldRestack()?
  → YES → yabai query (async) → merge stack indices → ingest → rebuild all canvases
  → NO  → do nothing
```

This path tears down and recreates all `hs.canvas` elements. It's expensive because of the subprocess call, JSON parsing, and canvas rebuilding (including app icon lookups).

### Fast path: focus changes (redraw in-place)
Triggered by: window focused, unfocused, not visible.

```
HS focus event → find window in manager → update canvas element properties in-place
```

No yabai query needed. No canvas destruction/creation. Just tweaks `fillColor`, `imageAlpha`, and `shadow` on existing canvas elements. This matters because focus changes happen constantly (every alt-tab, every click).

### `forceRedraw` flag
`forceRedraw` bypasses the `shouldRestack()` optimization, forcing a yabai query + rebuild regardless of whether the summary diff detected a change. It's set on events where something significant likely happened (windowCreated, windowMoved, windowsChanged, space switch, init) and serves as a safety net when the summary check might miss a real change. Also useful for debugging: `stackline.manager:update({forceRedraw=true})` in the HS console forces a fresh yabai query at any time.

### Throttling
The slow path uses `hs.timer.delayed` with `maxRefreshRate` (default 0.5s). Multiple rapid events (e.g., several windows moving during a layout change) collapse into a single update cycle. Some events (`windowCreated`, `windowsChanged`, `windowMoved`) set `forceRedraw=true` to bypass the `shouldRestack()` optimization.

## Module Map

```
init.lua                          Entry point. Adds stackline to package.path.
├── stackline/stackline.lua       App lifecycle. Event wiring. Click tracker. Space watcher.
│   ├── stackline/configmanager.lua   Schema-validated config. get/set/toggle with onChange events.
│   ├── stackline/stackmanager.lua    Manages collection of Stack objects. Coordinates updates.
│   │   └── stackline/queryYabai.lua       Groups HS windows by frame. Queries yabai. Detects changes.
│   ├── stackline/stack.lua           Single stack: contains windows, iterators, hit-testing.
│   └── stackline/window.lua          Window model + all indicator rendering. Largest module (365 lines).
├── conf.lua                      Default config values.
├── lib/utils.lua                 Functional helpers (map, filter, groupBy, etc.) + table utilities.
└── lib/valid.lua                 Schema validation library for config.
```

### Key module details

**stackline.lua** — Sets up `hs.window.filter` subscriptions that route events to either the slow path (`queryWindowState` timer) or fast path (`redrawWinIndicator`). Also sets up `hs.eventtap` for click-to-focus and `hs.spaces.watcher` for space changes. Uses the global `stackline` table as a singleton.

**queryYabai.lua** — The `run()` function is the slow-path entry point. `groupWindows()` maps `hs.window` objects into `Window` objects and groups by `stackId`/`stackIdFzy`. `shouldRestack()` compares summary stats (num stacks, positions, window counts) against the previous state to avoid unnecessary yabai queries. When a query is needed, `stackIdMapper()` extracts the `window.id → stack-index` mapping from yabai's JSON, and `mergeWinStackIdxs()` assigns those indices onto the grouped windows.

**stackmanager.lua** — `ingest()` receives grouped+merged windows from query, creates `Stack` objects, wires up `otherAppWindows` (for the HS #2400 workaround), and triggers indicator rendering. `findWindow()` does a linear scan across all stacks to locate a window by ID (used by the fast path). `cleanup()` tears down all canvas elements before a full refresh.

**window.lua** — The most complex module. `Window:new()` wraps an `hs.window` and computes `stackId`/`stackIdFzy`. `setupIndicator()` calculates rect positions from config + stackIdx. `drawIndicator()` creates a new `hs.canvas` with a rounded rect and optional app icon. `redrawIndicator()` is the fast-path logic — it determines which of 4 focus states changed (stack focused/unfocused x window focused/unfocused) and updates canvas properties accordingly. `getColorAttrs()` and `getShadowAttrs()` compute visual properties from focus state.

**configmanager.lua** — Stores config as a flat-ish table accessed via dot-notation paths (`"appearance.color"`). Schema defined in `Config.schema`, validated on init and on `set()`. `Config.events` maps config key paths to side-effect functions (e.g., changing any `appearance.*` key triggers `resetAllIndicators`).

## Known Workarounds

### Hammerspoon #2400
When switching focus between windows of the *same app* within a stack, Hammerspoon sometimes fails to fire the unfocus event for the previously-focused window. The workaround (`features.hsBugWorkaround`) tracks `otherAppWindows` per window and manually calls `redrawIndicator()` on them during focus changes. See `Window:unfocusOtherAppWindows()` and the wiring in `stackmanager.lua:ingest()`.

### `windowsChanged` pseudo-event
Hammerspoon sometimes misses `windowCreated` events. Subscribing to `windowsChanged` (fires on any change to the window list) acts as a catch-all.

## Globals & Conventions

- `stackline` is a global singleton table. Modules access it freely (e.g., `stackline.config`, `stackline.manager`, `stackline.wf`).
- `u` is a global alias for `lib/utils.lua`, set in `stackline.lua:10`.
- `c` is used as a local alias for config values in `window.lua` and `conf.lua`.
- Objects use Lua's metatable pattern: `setmetatable(instance, Class); Class.__index = Class`.
- Fold markers (`-- {{{` / `-- }}}`) are used throughout for editor code folding.
- **Comment conventions:** Top-of-file module comments use `--[[ ]]` blocks (first line is just `--[[`). Everything else (inline, TODOs, section headers) uses single-line `--`.

## Avoiding Bug Introduction

Running stackline requires macOS + Hammerspoon + Yabai + real windows — this can't be automated. Mocking Hammerspoon objects has been tried and is impractical (huge surface area, didn't prevent bugs). The strategy below avoids both extremes (no verification vs. full mocking).

### Strategy: extract, test, discipline

**1. Extract pure functions, then test those.**
Most complexity lives in functions that *could* be pure but currently reach into globals (`stackline.config`, `stackline.manager`, `hs.window.focusedWindow()`). Refactoring should pull the logic out into pure functions that take explicit arguments and return values. These are trivially testable with standalone Lua — no HS, no mocking. Examples:
- Color/shadow calculation: `(config, showIcons, stackFocused, winFocused) → {bg, img}` and `→ {blur, color, offset}`
- Stack ID from frame: `(frame, fuzzFactor) → stackId`
- Focus state transitions: `(oldFocus, newFocus, oldStackFocus, newStackFocus) → {actions to take}`
- Grouping + merge pipeline: `(windowFrames, yabaiJson) → grouped stacks with indices`

A simple test file (`test.lua`) runnable with `lua test.lua` or `luajit test.lua` using plain `assert()` is sufficient — no test framework needed.

**2. Provably-correct structural changes need no tests.**
Moving `resetAllIndicators()` outside a loop, adding `local` to a variable, replacing `u.extend(x, ...)` with `u.extend(u.copy(x), ...)`, removing dead code — these are their own proof. The discipline is: one small change at a time, each obviously correct in isolation.

**3. Snapshot tests for the data pipeline.**
Feed known inputs (real yabai JSON + window frame data) through the grouping/merge pipeline, assert expected outputs. Covers the core logic without HS. User provides sample data; tests run in standalone Lua.

**4. Visual verification is batched, not per-change.**
Don't try to automate canvas rendering verification. Batch up visual changes, then the user does one manual check. Keep structural/logic changes separate from visual changes so each batch is coherent.

### What NOT to do
- Don't mock Hammerspoon objects — the surface area is too large and it doesn't prevent the bugs that matter.
- Don't add runtime assertions at module boundaries — Lua already crashes with a line number on nil access, and the data from yabai/HS is consistent. Assertions add code clutter that hurts the readability goal without catching bugs that wouldn't surface immediately anyway.
- Don't introduce a heavy test framework — plain `assert()` in a Lua file is enough.
- Don't try to test canvas rendering programmatically — visual output is verified by eyes.
- Don't make large sweeping changes — small steps, each independently verifiable.

## Developer Guidelines

- **Follow through on simplifications.** When you remove the primary use of a variable, check all remaining uses and question whether they're still needed. When a change reduces an expression to a trivial case (e.g., a variable that's just an alias for a single function call), inline it. Don't leave orphaned variables or unnecessary indirection behind.

- **Normalize data shapes upfront.** When a function handles two data shapes (e.g., raw arrays vs. wrapper objects), don't branch repeatedly in the body. Normalize at the top so the body only deals with one shape. Example: `getSummary` replaced per-callback `external and s or s.windows` branching with a single `u.map` at the top that unwraps Stack objects into the same shape as the raw input.

- **Eliminate dead variables and redundant calls.** When auditing for readability:
  - Variables assigned and immediately returned → inline the expression.
  - Function arguments that the callee ignores → remove them (and the variable).
  - Identical if/else branches → collapse to one path.
  - Duplicate function calls with same args in a single flow → compute once, reuse.
  - Algebraic simplifications → apply when the result is clearer (e.g., `1 - (a-b)/a` → `b/a`).

- **Always update CLAUDE.md.** After every commit: add to the Commits list in Work Log, and update the Refactoring Plan checkboxes. Don't let them drift.

### Naming Conventions

The codebase currently uses several different words for the same operations. The target naming scheme assigns one verb per cost level, so the name itself signals the performance implication.

**Three verbs, by cost:**

| Verb | Meaning | Cost |
|---|---|---|
| **query** | Call yabai (subprocess), get fresh data, rebuild everything | High — external I/O |
| **rebuild** | Tear down canvases, create new ones from existing data | Medium — canvas + icon lookups |
| **redraw** | Tweak colors/opacity/shadow on existing canvases in-place | Low — nearly free |

The slow path = **query** (which triggers a rebuild). The fast path = **redraw**.

**Current → Target renames:**

| Current | Target | Why |
|---|---|---|
| `shouldRestack()` | `shouldQuery()` | "Should we call yabai?" — signals external I/O |
| `forceRedraw` | `forceQuery` | Forces the yabai call, not just a redraw |
| `queryWindowState` | *(keep)* | Already correct |
| `checkOn` | *(keep)* | Accurate: these events trigger a *check* (shouldRestack), not always a query |
| ~~`forceCheckOn`~~ | `forceQueryOn` | **Done.** What's forced is the query, not the check |
| `resetAllIndicators()` | `rebuildAllIndicators()` | "Reset" is vague; "rebuild" says canvases are torn down and recreated |
| `tabStacks` | `stacks` | The `tab` prefix adds nothing; everything else says "stacks" |
| `self.focus` | `self.winFocused` | Distinguishes from `self.stackFocused`; matches param style |
| `self.stackFocus` | `self.stackFocused` | Consistent adjective form matching local vars and params |
| `maxRefreshRate` | *(keep)* | Already understood |
| `redrawOn` | *(keep)* | Already correct |
| `redrawIndicator()` | *(keep)* | Already correct |
| `redrawAllIndicators()` | *(keep)* | Already correct |
| `_win` (unused callback param) | *(keep)* | Intentional underscore convention for unused args |

## Complexity Hotspots (Refactoring Targets)

### Bugs / Latent Issues

**B1. `u.extend` mutates the config color table** (window.lua:255)
Line 255: `u.extend(opts.color, {alpha = opts.alpha})` mutates the shared config color object. The other 3 branches (lines 259, 268, 275) correctly do `u.extend(u.copy(opts.color), ...)`. This one forgot to copy first. Every call to `getColorAttrs(true, true)` permanently adds/overwrites `alpha` on the config's color table.

**B2. `Config:autosuggest()` is called but never defined** (configmanager.lua:187)
`Config:set()` calls `self:autosuggest(path)` when a path isn't in the schema, but this method doesn't exist. Would throw a runtime error on any `set()` with an invalid path. The `self.autosuggestions` table is built in `validate()` (line 146) but never read anywhere.

**B3. `forceRedraw` flag can be clobbered** (stackline.lua:86)
The event handler unconditionally sets `self.forceRedraw = u.contains(...)` on every event. If a `windowCreated` sets it `true`, then a `windowHidden` fires before the timer executes, it gets overwritten to `false`. Should be `self.forceRedraw = self.forceRedraw or u.contains(...)`.

**B4. `iconFromAppName` leaks a global** (window.lua:322)
`appBundle = hs.appfinder...` is missing `local`, creating an implicit global on every call.

**B5. `conf.lua` leaks global `c`** (conf.lua:4)
`c = {}` without `local`. Harmless in practice but pollutes the global namespace.

### Architectural

**A1. Full teardown/rebuild on every slow-path update** (queryYabai.lua:45-47, stackmanager.lua:20-38)
`groupWindows()` creates brand-new Window objects for *every* visible window on every update cycle. Old Window objects (with their canvas references, cached icons, focus state) are thrown away and rebuilt from scratch. This forces full canvas teardown/rebuild — the most expensive operation.

Window IDs are stable (same in HS and yabai), so a **keyed reconciliation** could avoid this: keep a `windowsById` map, diff new state against existing state, and only create/destroy/reposition what actually changed. This would eliminate most canvas churn and icon re-lookups. Previous attempts to solve this via a deep OOP hierarchy (auto-building data tree from global → screen → space → stack → window → indicator) became too complex and buggy. A flat hash-map diff is simpler: just three cases per window ID — unchanged (keep), changed (update), gone (delete) — plus new IDs (create).

**A2. `resetAllIndicators` called inside the ingest loop** (stackmanager.lua:36)
Inside `for stackId, groupedWindows in pairs(stacks)`, each iteration calls `self:resetAllIndicators()`, which iterates *all* stacks accumulated so far. With N stacks, indicators are set up 1+2+...+N = N(N+1)/2 times total. Should be called once after the loop.

**A3. One `hs.canvas` per window, sized to full screen** (window.lua:98)
Each stacked window creates its own canvas spanning the entire screen frame, then draws one small rect+icon in it. A single canvas per screen with multiple elements would be lighter and could also simplify click hit-testing.

**A4. `Window:isFocused()` queries HS on every call** (window.lua:28-35)
Calls `hs.window.focusedWindow()` every time. During a single `redrawIndicator()`, this is called once directly, then again for every window in the stack via `isStackFocused()` → `stack:anyFocused()`. A 5-window stack = 6 calls to `hs.window.focusedWindow()` per event. The focused window ID could be resolved once and passed through.

### Unnecessary Complexity

**C1. `redrawIndicator` focus state machine** (window.lua:130-196)
4-way branch (`noChange`, `bothChange`, `onlyWinChange`, `onlyStackChange`) with side effects scattered across branches. Some update `self.focus`, some update `self.stackFocus`, some trigger sibling redraws. The "last-active window" behavior — `bothChange` updates `stackFocus` but intentionally does *not* update `self.focus` — is a non-obvious design decision buried in a branch. Sibling redraw trigger is duplicated in two branches. The inline TODO says "Refactor to reduce complexity."

**C2. `getColorAttrs` rebuilds a nested lookup on every call** (window.lua:245-292) — **FIXED**
Replaced 50-line deeply nested string-keyed lookup with flat if/else + `withAlpha` helper. 4 branches with early returns, each self-documenting. Only the needed branch computes (was building all 4 `u.copy`/`u.extend` every call).

**C3. `getShadowAttrs` magic numbers** (window.lua:294-319)
Hardcoded dimming ratios (`6`, `7`, `15.0`, `7.0`, `3.0`, `2.0`, etc.) with no names or config backing. Difficult to tune or understand.

**C4. `getSummary` dual data shape** (stackmanager.lua:57-76) — **FIXED**
The `external` parameter switched between reading from Stack objects (`.windows` property) and raw grouped arrays, branching in every callback. Fixed by normalizing at the top of the function: unwrap `Stack.windows` via `u.map` so the body always works with plain window arrays.

**C5. `drawIndicator` mutates `self.config`** (window.lua:85)
`u.extend(self.config, overrideOpts or {})` mutates `self.config` in place. Since `overrideOpts` is currently never passed, this is a no-op today, but would corrupt shared config state if ever used. Intent is to support overrides — fix is to extend a *copy* of `self.config` instead.

### Dead Code

**D1. Some utils.lua functions are dead code**
Truly unused and not useful for the functional coding style or debugging: `u.json_cb` (redundant with `u.task_cb`), `u.from_iter`, `u.copyShallow` (buggy — missing `local copy = {}`; `u.copy` from hs.fnutils already exists), `u.levenshteinDistance` (for unfinished autosuggest feature), `u.pheader`, `table.slice`, `table.merge` (never called). Functional-style utilities like `u.pipe`, `u.flip`, `u.flatten`, `u.zip`, `u.uniq`, `u.include`, `u.deepCopy` should be kept — they support a terse, readable coding style and may be used in future refactoring.

**D2. `Stackmanager:findStackByWindow` — keep** (stackmanager.lua:95-103)
Currently unused in code, but useful for live debugging via the Hammerspoon console. Methods like this let you inspect the live system state interactively.

**D3. `Stackmanager:getShowIconsState` is stale indirection** (stackmanager.lua:106-108)
Returns `self.showIcons` set once at `init()` from config. Called from `getColorAttrs` and `getShadowAttrs`. Doesn't reflect runtime config changes via `set()`. Could read config directly.

## Refactoring Plan (least-risky → most-risky)

Each item gets its own commit. Provably-correct changes first, then logic restructuring, then architectural changes.

### Tier 1: Provably correct (no behavior change possible)

- [x] **1. Remove dead code from utils.lua** (D1) — Remove functions that aren't useful for stackline's functional style or debugging: `u.json_cb` (redundant with `u.task_cb`), `u.from_iter`, `u.copyShallow` (buggy, `u.copy` exists), `u.levenshteinDistance` (for unfinished autosuggest), `u.pheader`, `table.slice`, `table.merge` (never called). Keep functional-style utilities (`u.pipe`, `u.flip`, `u.flatten`, etc.) — they support a terse, readable coding style even if not currently called.
- [x] **2. Fix `conf.lua` global leak** (B5) — `c = {}` → `local c = {}`. No behavior change; `c` is returned and assigned by the caller.
- [x] **3. Fix `iconFromAppName` global leak** (B4) — Add missing `local` to `appBundle`. No behavior change.
- [x] **4. Fix `getColorAttrs` config mutation** (B1) — Line 255: `u.extend(opts.color, ...)` → `u.extend(u.copy(opts.color), ...)`. Matches the pattern already used on lines 259, 268, 275.
- [x] **5. Fix `drawIndicator` config mutation** (C5) — `u.extend(self.config, ...)` → `u.extend(u.copy(self.config), ...)`. Preserves override intent without mutating shared state.
- [x] **6. Fix `forceRedraw` clobbering** (B3) — `self.forceRedraw = u.contains(...)` → `self.forceRedraw = self.forceRedraw or u.contains(...)`. One-line change, fixes a real race condition.
- [x] **6b. Remove `spaceHasStacks` guard in queryYabai.lua** — The `spaceHasStacks and` prefix on `shouldRestack()` creates a blind spot (0→N stacks) that forces `forceRedraw` to cover init/space-switch. Removing it lets `shouldRestack()` handle all transitions naturally via `numStacks` diff.
- [x] **7. Move `resetAllIndicators` outside ingest loop** (A2) — Move one line from inside to after the `for` loop. Same final state, eliminates N(N+1)/2 redundant calls.
- [x] **8. Remove or stub `autosuggest`** (B2) — Either delete the call in `set()` or add a no-op method. Currently crashes on invalid config paths.
- [x] **8c. Fix `u.find()` global leak** — Add missing `local` to `result` variable. Same class of bug as items 3-5.
- [x] **8d. Fix comment typos and inaccuracies** — Fix typos (forgiven, WANRING, elment), wrong defaults (0.3s→0.5s), stale line-number references, stale `-- end`, incorrect stackIdFzy description, `~=` → `≈`.
- [x] **8e. Add high-value comments** — Module-level comments, explain non-obvious patterns (stackFocus=true, string-key lookup, __index metatable fallback, globals), label slow/fast paths, document queryYabai.lua functions, clarify conf.lua values. Remove dead `self:isStackFocused()` call in setupIndicator.
- [ ] **8f. Normalize naming conventions** — Rename per the naming scheme in Developer Guidelines. `shouldRestack`→`shouldQuery`, `forceRedraw`→`forceQuery`, `checkOn`→`queryOn`, `forceCheckOn`→`forceQueryOn`, `resetAllIndicators`→`rebuildAllIndicators`, `tabStacks`→`stacks`, `self.focus`→`self.winFocused`, `self.stackFocus`→`self.stackFocused`. Pure renames, no logic change.

### Tier 2: Extract & simplify (same behavior, clearer code)

- [ ] **9. Extract geometry & aesthetic calculations into a utility file** — Pull pure calculation functions out of window.lua into a new `stackline/indicator_utils.lua` (or similar). These don't need `self` — they take explicit arguments and return values, making them trivially testable with standalone Lua. Candidates:
  - **Geometry:** `getScreenSide(frame, screenWidth)`, `getIndicatorPosition(frame, screenFrame, side, width, config)`, `makeStackId(frame, fuzzFactor)`, y-position formula from `setupIndicator`
  - **Aesthetics:** `getColorAttrs(config, showIcons, isStackFocused, isWinFocused)`, `getShadowAttrs(config, showIcons, isFocused, side)`
  - Window.lua becomes focused on lifecycle & state management (the hard part). Items 10, 11, and 14 are naturally addressed during extraction (flatten getColorAttrs, name shadow magic numbers, pass focused ID as arg instead of querying HS).
- [x] **10. Flatten `getColorAttrs`** (C2) — Replaced nested string-keyed lookup with flat if/else + `withAlpha` helper. 50 lines → 20. Each branch is self-documenting with early returns. Only the needed branch computes.
- [ ] **11. Name `getShadowAttrs` magic numbers** (C3) — Extract hardcoded values into local constants with descriptive names. Same outputs, more readable. (Can be done as part of item 9 or standalone.)
- [ ] **12. Inline `getShowIconsState`** (D3) — Replace `stackline.manager:getShowIconsState()` calls with `stackline.config:get('appearance.showIcons')`. Fixes stale-cache bug and removes indirection.
- [x] **13. Simplify `getSummary` dual data shape** (C4) — Normalize data shape at the top of the function instead of branching in every callback. Unwrap `Stack.windows` via `u.map` so the body is branch-free. Simpler than splitting into two functions.
- [ ] **14. Pass focused window ID through update cycle** (A4) — Resolve `hs.window.focusedWindow()` once at the top of `redrawIndicator`, pass the ID down. Eliminates N+1 redundant HS API calls per focus event. (Can be done as part of item 9 or standalone.)
- [ ] **15. Simplify `redrawIndicator` state machine** (C1) — Restructure the 4-way branch to make the "last-active window" behavior explicit and deduplicate the sibling-redraw trigger. Same logic, clearer intent.

### Tier 3: Architectural (higher risk, higher reward)

- [ ] **16. Keyed reconciliation in ingest** (A1) — Maintain `windowsById` map. Diff new state against existing windows. Only create/destroy/reposition what changed. Eliminates full teardown/rebuild on every slow-path update.
- [ ] **17. Single canvas per screen** (A3) — Replace per-window full-screen canvases with one canvas per screen containing multiple elements. Lighter, simpler hit-testing.

## Work Log

### 2025-02-05: Investigated yabai stack-id possibility
Checked whether yabai has added a `stack-id` or any stack-grouping field since the original feature request (https://github.com/koekeishiya/yabai/issues/672, filed by @AdamWagner in Sept 2020).

**Result: No.** Yabai still only exposes `stack-index` (position within a stack). The `window_node` struct in yabai's BSP tree has no ID field — stacks are implicit, not first-class entities. The maintainer acknowledged the usefulness in 2020 but never implemented it. Changelog through v7.1.16 (Oct 2025) has no stack-grouping changes.

**Implication:** The two-data-source architecture (Hammerspoon for grouping via frame-matching, yabai for ordering via stack-index) remains necessary. The fuzzy frame detection and the entire `groupWindows()` pipeline in `queryYabai.lua` cannot be eliminated. Any simplification work should focus on cleaning up the *implementation* of this pipeline, not replacing it.

### 2025-02-05: Deep complexity review
Audited all modules for bugs, unnecessary complexity, and dead code. Full findings written up in "Complexity Hotspots" section above (items B1-B5, A1-A4, C1-C5, D1-D3).

Key insight on **A1 (full teardown/rebuild)**: previous attempts to fix this went down a deep OOP path — building a sophisticated class library with an auto-building data tree (global → screen → space → stack → window → indicator) where each level knows how to construct its children. These attempts consistently became too complex, introduced many bugs, and failed. The simpler approach is a **flat keyed reconciliation** by window ID: diff new state against a `windowsById` map, and only create/destroy/reposition what actually changed. No new class hierarchy needed.

### Commits
- `ef91aa9` — Item 1: Remove dead code from utils.lua. Removed 7 unused functions (table.slice, table.merge, u.from_iter, u.json_cb, u.copyShallow, u.levenshteinDistance, u.pheader). 110 lines deleted. Also removed stale `luacheck: globals table.merge` directive from stackline.lua.
- `72ce9ec` — Add CLAUDE.md with architecture docs and refactoring plan.
- `4629d5a` — Item 2: Fix conf.lua global leak. Made `c` local, fixed queryYabai.lua:50 to use `stackline.config:get()`.
- `1f85833` — Item 3: Fix iconFromAppName global leak. Added missing `local`.
- `bd256d6` — Item 4: Fix getColorAttrs mutating shared config color table. Added missing `u.copy()`.
- `b2cc3ed` — Item 5: Fix drawIndicator mutating self.config via u.extend. Copy before extending.
- `3dff1c5` — Item 6: Fix forceRedraw flag being clobbered by subsequent events. Use `or` to preserve earlier force.
- `1a42537` — Item 6b: Remove `spaceHasStacks` entirely. Inlined `shouldRestack()` call, removed `shouldRefresh` variable, made `ingest()` always clean up (no-op when empty). `shouldRestack()` now handles 0→N transitions naturally.
- `24f4f9b` — Item 7: Move `resetAllIndicators()` outside ingest loop. Eliminates N(N+1)/2 redundant calls.
- `640504c` — Item 8: Remove unimplemented autosuggest. Replaced crashing `self:autosuggest()` call with `log.w()`, removed dead `self.autosuggestions` build, removed related TODO in conf.lua.
- `649f00d` — Item 8c: Fix `u.find()` global leak. Added missing `local` to `result`.
- `bad9963` — Item 8d: Fix comment typos, wrong defaults, and stale references across 6 files.
- `736a211` — Item 8e: Add high-value comments across all modules. Module-level comments, explain non-obvious patterns, label slow/fast paths, document functions, clarify config values. Remove dead `self:isStackFocused()` call.
- `82f999d` — Rename query.lua → queryYabai.lua. Updated require path and all references.
- `c7532c4` — Add/improve top-of-file comments across all modules (stackline.lua, queryYabai.lua, configmanager.lua, conf.lua, utils.lua, window.lua, stackmanager.lua).
- `33e3f91` — Item 8f: Add 31 targeted inline comments across all modules. Geometry calculations, shadow math, focus state, coordinate transforms, data flow, subtle gotchas.
- `0ab1f89` — Convert top-of-file module comments from `--` to `--[[ ]]` blocks across all 8 modules. First line is always just `--[[`.
- `fd98f27` — Item 13: Simplify `getSummary` by normalizing data shape upfront. Unwrap `Stack.windows` via `u.map` at the top instead of branching in every callback.
- `6c91a90` — Readability cleanup: collapse identical `u.p()` branches, inline `isFocused` variable, deduplicate `getColorAttrs()` call in `drawIndicator`, remove dead `local f` in `redrawIndicator`, simplify `percR` algebra, remove leftover debug print in `shouldRestack`.
- `c42c608` — Rename `forceCheckOn` → `forceQueryOn` (what's forced is the query, not the check). Add slow/fast path comments to the events table. Keep `checkOn` as-is.
