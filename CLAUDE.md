# Stackline — Reconcile Branch

**Prior work:** See `claude_01.md` for the full history (bugs fixed, refactoring plan, commit log, complexity audit).

## What This Is

macOS overlay that renders visual indicators (icons/pills) on Yabai-stacked windows. Runs on Hammerspoon. Written in Lua.

## The Core Data Problem

Neither Hammerspoon nor yabai has enough info alone:
- **Hammerspoon** knows window frames → gives us *grouping* (which windows overlap)
- **Yabai** knows stack-index → gives us *ordering* and confirms truly stacked (index > 0)
- **Stackline** merges both: frame-based grouping + yabai stack-index

No `stack-id` exists in yabai. This two-source architecture is permanent.

## Module Map

```
stackline.lua        Singleton, event wiring, click tracker, space watcher
├── stackmanager.lua Manages Stack collection, per-space canvas/state caching, reconcile
│   └── queryYabai.lua  Groups windows by frame, queries yabai, merges data
├── stack.lua        Single stack (Collection of Windows)
├── window.lua       Window model: identity, reconcile, focus coordination
├── indicator.lua    Single indicator: geometry, appearance, canvas element lifecycle
├── configmanager.lua Schema-validated config with onChange events
lib/collection.lua   Keyed storage mixin (used by Stackmanager and Stack)
lib/utils.lua        Functional helpers (map, filter, groupBy, etc.)
conf.lua             Default config values
```

## Two Update Paths

**Slow path** (structural changes): HS event → throttle (0.5s) → group windows → shouldQuery? → yabai query → merge → `reconcile()` (diff-based update)

**Fast path** (focus changes): HS event → find window → `redrawIndicator()` → `indicator:updateFocus()` (tweak colors/shadow in-place)

## Naming Convention: Three Verbs by Cost

| Verb | Meaning | Cost |
|---|---|---|
| **query** | Call yabai subprocess, get fresh data | High — external I/O |
| **rebuild** | Tear down canvas elements, recreate from data | Medium — icon lookups |
| **redraw** | Tweak colors/opacity/shadow on existing elements | Low — nearly free |

## What's Been Done (This Branch)

All items from the refactoring plan in `claude_01.md` are complete.

Key architectural changes on this branch:
- **Item 9: Indicator extraction** — Rendering logic pulled from window.lua into indicator.lua
- **Item 17: Single canvas per screen** — One shared `hs.canvas` per screen per space; indicators insert elements by string ID
- **Item 16: Reconcile pipeline** — Diff-based updates replace full teardown/rebuild. `extractWindowData()` produces plain data tables; `reconcile()` matches by window ID, reuses existing Window/Indicator objects
- **Per-space caching** — `_spaceItems` cache + `switchSpace()`. Return visits are instant (stacks can't change on inactive spaces)

## Future Direction: Model/View Split

The reconcile pipeline established a clean data boundary — the next architectural step is making it explicit with directory-level separation:

```
model/                          view/
  window.lua     (data only)      indicator.lua  (already clean)
  stack.lua      (collection)     renderer.lua   (owns canvases, maps model → indicators)
  stackmanager.lua (query, diff)
  query.lua      (yabai, grouping)
```

Goal: model/ has zero `hs.canvas` references, view/ has zero yabai/grouping logic. The reconcile work makes this *possible* — Window already delegates all rendering to Indicator, and extractWindowData produces pure data tables. But the actual separation hasn't been done: Window still straddles both sides (holds model state *and* calls buildIndicator/redrawIndicator), and Stackmanager mixes concerns (Stack collection *and* screenCanvases).

## What's Left to Do

### Reconcile pipeline cleanup
- [x] **Remove `ingest()`** — Dead code; `run()` calls `reconcile()` now.
- [x] **Remove `Window:new()` and `Window:makeStackId()`** — Replaced by `extractWindowData()` + `newFromData()`.
- [x] **Remove `Stackmanager:getShowIconsState()`** — Already inlined in item 12.
- [x] **Remove `byApp` from `groupWindows()`** — `reconcile()` builds its own in step 6.
- [x] **Item 14: Pass focused window ID through redraw cycle** — `redrawIndicator()` resolves `hs.window.focusedWindow()` once, passes ID through `isStackFocused()` → `Stack:anyFocused()` → `Window:isFocused()`. Eliminates N+1 redundant HS API calls per focus event.

### Known bugs
- **I1**: Stale focus state when switching within a stack (intermittent, HS #2400 related)
- **I2**: Same-app focus bleeds into unfocused stacks (intermittent, HS #2400 related)
- **I4**: Slow indicator repositioning after warp/move (0.5s throttle + async query latency)
- **I5**: No error logging when yabai subprocess fails (silent failure)

## Key Facts to Keep in Mind

- **Globals**: `stackline` (singleton), `u` (utils). Both set in stackline.lua.
- **Comment conventions**: Top-of-file `--[[ ]]` blocks. Function comments go *above* the `function` line, not inside the body. Everything uses single-line `--`.
- **Fold markers**: `-- {{{` / `-- }}}` throughout.
- **Canvas keys**: `screenId|spaceId` — one canvas per screen per space, no `canJoinAllSpaces`.
- **Indicator element IDs**: `rect_<winId>`, `icon_<winId>` — string-keyed for O(1) access.
- **Window IDs are stable** across HS and yabai — this is what makes reconciliation by ID work.
- **`mergeWinStackIdxs` can produce empty arrays** — reconcile guards with `#windowDataArray > 0`.
- **HS #2400**: Focus events unreliable for same-app windows in stacks. Workaround: `otherAppWindows` + manual redraw.
- **Testing**: No automated tests possible (requires macOS + HS + yabai). Visual verification only. See manual test plan in `claude_01.md`.

## Developer Guidelines

- Normalize data shapes upfront (don't branch repeatedly for two shapes)
- Follow through on simplifications (inline dead variables, remove unused args)
- Small steps, each independently verifiable
- Don't mock Hammerspoon — surface area too large, doesn't prevent real bugs
