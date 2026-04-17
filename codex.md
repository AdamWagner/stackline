# Stackline Audit (2026-02-19)

This audit focuses on your goals: readability, clear module boundaries, simple extension points, and a fluid internal API from raw windows -> stacks -> indicators.

## Executive Assessment

The current tree direction (Node -> Stackmanager/Stack/Window + ViewManager/Indicator split) is strong. The main issues are now around system boundaries and data contracts, not raw rendering logic:

1. async correctness/race handling is underspecified
2. module coupling is still high via globals and hidden dependencies
3. the data pipeline uses implicit table-shape transitions that are hard to reason about
4. config behavior is less ergonomic than it looks from the API surface

The recommendations below are ordered by impact.

## 1) Opportunities To Improve Code Quality

### P0: Guard async query responses against stale space/generation
- **Why this matters:** A late `yabai` callback can reconcile into the wrong current space after a space switch, causing stale or cross-space state.
- **Evidence:** `stackline/model/queryYabai.lua:124`, `stackline/model/queryYabai.lua:133`, `stackline/model/stackmanager.lua:71`, `stackline/model/stackmanager.lua:221`.
- **Recommendation:** Add `epoch` + `spaceId` to each query request and drop callbacks that do not match manager current state.

### P0: Fail closed on yabai errors instead of tearing down good state
- **Why this matters:** Non-table/failed query responses currently degrade toward empty merges and can remove valid indicators.
- **Evidence:** `lib/utils.lua:205`, `lib/utils.lua:217`, `stackline/model/queryYabai.lua:30`, `stackline/model/queryYabai.lua:80`.
- **Recommendation:** Preserve exit code/stderr from `hs.task`; if query fails, log and return without reconcile.

### P1: Avoid lifecycle bypasses (`_items` mutation/clear without destroy semantics)
- **Why this matters:** `Stackmanager` currently bypasses Node lifecycle contracts; this blocks safe future extensions at stack-level hooks.
- **Evidence:** `stackline/model/stackmanager.lua:92`, `stackline/model/stackmanager.lua:132`, `stackline/model/stackmanager.lua:167`.
- **Recommendation:** Add explicit Node APIs (`detachChildren`, `destroyMissingChildren`, `clearWithDestroy`) and use those instead of direct `_items` writes.

### P1: Fix config merge ergonomics (shallow merge is hostile to partial overrides)
- **Why this matters:** `stackline:init({appearance={alpha=...}})` replaces the whole `appearance` subtree before validation.
- **Evidence:** `stackline/stackline.lua:37`, `lib/utils.lua:181`.
- **Recommendation:** Replace shallow `u.extend` with deep merge from defaults; support partial nested overrides by design.

### P1: Make config onChange behavior explicit and complete for nested keys
- **Why this matters:** Nested paths under `features` can silently do nothing unless explicitly listed; behavior is not intuitive.
- **Evidence:** `stackline/configmanager.lua:71`, `stackline/configmanager.lua:73`, `stackline/configmanager.lua:205`, `lib/utils.lua:250`.
- **Recommendation:** Replace current metatable fallback + `isSafe` lookup with explicit path matcher (`appearance.*`, `features.clickToFocus`, etc.) and guaranteed default handler.

### P1: `maxRefreshRate` changes do not reconfigure timer behavior
- **Why this matters:** Runtime config implies behavior change, but timer interval is fixed at init.
- **Evidence:** `stackline/model/stackmanager.lua:38`, `stackline/configmanager.lua:109`.
- **Recommendation:** Add handler for `advanced.maxRefreshRate` that replaces/reconfigures `_timer`.

### P2: Remove or quarantine dead/low-signal primitives
- **Why this matters:** Contributor cognitive load increases when dead abstractions remain.
- **Evidence:** `lib/collection.lua` appears unused by runtime modules; `lib/node.lua:16` (`Chain`) has no in-repo usage.
- **Recommendation:** Delete dead files or move to clearly labeled "experimental/internal" area; keep runtime surface minimal.

### P2: Avoid mutating inputs in shared utility equality helper
- **Why this matters:** `u.equal` sorts inputs in place, creating hidden side effects that are hard to debug.
- **Evidence:** `lib/utils.lua:397`.
- **Recommendation:** Compare copied arrays or implement non-mutating canonicalization.

## 2) Opportunities To Simplify Division Of Labor Across Modules

### P1: Move focus-state resolution to one place (manager-level context)
- **Current split:** `Window:redrawIndicator` computes focus, `ViewManager:buildIndicator` recomputes stack focus, and sibling redraw repeats work.
- **Evidence:** `stackline/model/window.lua:105`, `stackline/model/window.lua:109`, `stackline/view/manager.lua:54`, `stackline/view/manager.lua:55`.
- **Recommendation:** Resolve `focusedWinId` once per event/update and pass a compact `focusContext` through redraw/build calls.

### P1: Clarify ownership of screen/frame transformations
- **Current split:** Query stores frame/screen on Window data, but view layer pulls live geometry from `win._win` repeatedly.
- **Evidence:** `stackline/model/queryYabai.lua:53`, `stackline/model/window.lua:43`, `stackline/view/manager.lua:51`, `stackline/view/manager.lua:71`.
- **Recommendation:** Treat Window model as canonical geometry source; derive and store screen-local frame at absorb time.

### P1: Isolate HS #2400 workaround into a dedicated policy component
- **Current split:** Workaround wiring is in `Stackmanager:reconcile`, execution in `Window:redrawIndicator`.
- **Evidence:** `stackline/model/stackmanager.lua:146`, `stackline/model/window.lua:111`, `stackline/model/window.lua:134`.
- **Recommendation:** Create `focus_workaround.lua` (or similar) with explicit inputs/outputs; keep model/view methods focused on core behavior.

### P2: Reduce stackline-global coupling by introducing a runtime context object
- **Current split:** Many modules reach into `stackline.*` and global `u`.
- **Evidence:** `stackline/stackline.lua:18`, `stackline/stackline.lua:19`, `stackline/model/window.lua:73`, `stackline/model/queryYabai.lua:99`, `stackline/view/manager.lua:80`.
- **Recommendation:** Pass a `ctx` table into module initializers (`ctx.config`, `ctx.manager`, `ctx.view`, `ctx.hs`, `ctx.u`) to make dependencies explicit.

## 3) Opportunities To Improve API Fluidity (Data -> Windows -> Stacks -> Management)

### P1: Introduce explicit stage contracts for the slow-path pipeline
- **Current shape:** `groupWindows`/`mergeWinStackIdxs` rely on implicit table semantics (dict vs array) and mixed data fields (`_win` + derived keys).
- **Evidence:** `stackline/model/queryYabai.lua:65`, `stackline/model/queryYabai.lua:80`, `stackline/model/queryYabai.lua:87`.
- **Recommendation:** Define explicit records:
  - `WindowRecord` (raw + normalized)
  - `GroupedStacks` (`{ [stackKey] = WindowRecord[] }`)
  - `StackSnapshot` (post-yabai-confirmed)
  Then make each stage pure and named by contract.

### P1: Unify stack identity naming and lifecycle semantics
- **Current shape:** `stackId`, `stackIdFzy`, `topLeft`, `dimensions` are mixed across detection and summary.
- **Evidence:** `stackline/model/queryYabai.lua:56`, `stackline/model/queryYabai.lua:57`, `stackline/model/queryYabai.lua:58`, `stackline/model/stackmanager.lua:179`, `stackline/model/stackmanager.lua:180`.
- **Recommendation:** Establish one explicit identity model:
  - `groupKey` (detection key, exact/fuzzy strategy)
  - `stackGeometryKey` (canonical geometry fingerprint)
  - `stackPositionKey` (top-left only, if needed)
  Document each key's purpose.

### P2: Replace "summary diff" with versioned model diff inputs
- **Current shape:** `shouldQuery` depends on condensed summaries and side-effectful utility equality.
- **Evidence:** `stackline/model/queryYabai.lua:98`, `stackline/model/queryYabai.lua:107`, `stackline/model/queryYabai.lua:112`, `lib/utils.lua:383`.
- **Recommendation:** Compute a stable lightweight signature from grouped windows (`count + ordered frame hashes + window ids`) and compare signatures directly.

### P2: Add an internal "pipeline facade" for readability
- **Current shape:** flow intent is correct but spread over free functions and manager globals.
- **Recommendation:** Encapsulate as:
  - `snapshot = pipeline:collect():group():confirm():normalize()`
  - `manager:reconcile(snapshot)`
  This gives contributors one obvious path to follow/extend.

## 4) Other Improvements

### P1: Harden icon loading
- **Why this matters:** `appFromName()` can be nil and crash icon creation.
- **Evidence:** `stackline/view/indicator.lua:23`.
- **Recommendation:** Add nil-safe fallback icon and short-circuit logic.

### P1: Introduce a tiny, no-HS unit test harness for pure logic
- **Why this matters:** You can protect refactors without mocking full Hammerspoon.
- **Targets:** color/shadow math, rect building, stack grouping/merge, summary/signature logic.
- **Evidence:** good pure-function candidates in `stackline/view/indicator.lua:182`, `stackline/view/indicator.lua:216`, `stackline/model/queryYabai.lua:65`, `stackline/model/queryYabai.lua:80`.

### P2: Clean documentation drift to lower onboarding friction
- **Why this matters:** Some docs still describe old interfaces (`ingest`, Collection-based flow), increasing contributor confusion.
- **Evidence:** `docs/codebase-study-guide.md` includes stale API descriptions versus current `stackline/model/stackmanager.lua`.
- **Recommendation:** Keep one authoritative architecture doc and mark others as historical.

## Suggested Rollout (Pragmatic Sequence)

1. **Correctness first:** add query epoch/space guards + yabai error handling.
2. **Contract clarity:** define pipeline record shapes and convert `queryYabai` stages to explicit contracts.
3. **Responsibility cleanup:** centralize focus context + geometry source ownership.
4. **Config ergonomics:** deep merge and explicit onChange routing.
5. **Debt cleanup:** remove dead abstractions (`collection`, maybe `Chain`), then align docs.

## Net Outcome If You Apply This

- fewer race-condition regressions in real-world space switching
- clearer extension seams for future Screen/Space nodes
- simpler contributor mental model (explicit contracts, less hidden global coupling)
- smoother API feel when changing config and adding new data-flow stages
