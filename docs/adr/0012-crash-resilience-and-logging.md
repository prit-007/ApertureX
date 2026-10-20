# ADR 0012 — Crash resilience & system-wide observability (pure error boundary)

Status: Accepted · Date: 2026-10-15

## Context

The app must never die from its own faults on Android, and every activity must
be observable after the fact:

- **Zero crashes from app code** — every error is caught by a boundary; the app
  keeps living (or recovers on next launch with evidence intact).
- **On error** → popup with a **"View logs"** action that navigates to the log
  page showing exactly what happened.
- **On crash** → the user gets the option, on recovery, to open that same page.
- **Everything meaningful is logged**, and logging itself must never throw.

Today (`core/log/`, `features/logs/`): an in-memory `ActivityLog` ring (500),
an append-only JSONL `LogFileStore`, the global `axLog(domain, message, level)`
helper (19 call sites), and a full `LogsScreen` (filter/copy/share/guide)
reachable from Settings. What is missing is the *resilience* half: there are **no
global error boundaries** (no `FlutterError.onError`, `PlatformDispatcher.onError`,
`runZonedGuarded`, `ErrorWidget.builder`), `LogEntry` carries **no error/stack**,
errors surface as one-off SnackBars with no path to the log page, a Kotlin
uncaught exception kills the process with no trace, and the log file grows
without bound.

## Decision

One system, four concerns: **boundaries → reporter → log → recovery UI**.

### 1. Boundary stack (the "pure error boundary")

| Layer | Hook | Catches | Outcome |
|---|---|---|---|
| Zone | `runZonedGuarded(main, …)` | uncaught async errors in the root zone (futures, timers, event handlers) | `ErrorReporter.report(fatal: true)` → log + dialog + crash marker |
| Framework | `FlutterError.onError` | build/layout/paint/gesture exceptions the framework routes out of widgets | log + dialog (non-fatal); remembers `lastError` for the fallback below |
| Dispatcher | `PlatformDispatcher.instance.onError` (return `true`) | Dart errors that escaped everything else | log + dialog + crash marker; **engine keeps running** |
| Subtree render | `ErrorWidget.builder` → `BoundaryFallback` | any element that fails to build paints elsewhere in the tree | in-place fallback card (tap → dialog → logs) instead of a dead/blank region |
| Riverpod / call sites | existing `try/catch` + SnackBar, now routed through `ErrorReporter` | handled feature errors | popup + log, app continues |
| Rust | `std::panic::set_hook` (once, at engine init) + FRB's unwind capture | panics become `AnyhowException` on the Dart side | hook appends a **LogEntry-JSONL** `rust_panic.log` line (hydrated into the in-app log page) before unwinding; the Dart exception hits the dispatcher boundary (popup + marker) |
| Kotlin | channel handlers fully `try/catch` → `result.error`; `Application` installs `Thread.setDefaultUncaughtExceptionHandler`; `ApplicationExitInfo` on next launch | platform-channel faults; process-level uncaught exceptions; native SIGSEGV/SIGABRT, ANR, LMK | channel faults become popup+log (app **lives**); JVM uncaught ones write `native.log` + `crash_marker.json` before the process dies; **native deaths bypass the JVM**, so `getHistoricalProcessExitReasons` reconstructs the marker on the next launch |

Honest limits: an uncaught **main-thread Kotlin** exception still ends the
process (Android owns that), and **native signals cannot be caught from Dart,
Kotlin, or Rust**. Survival there means *not letting exceptions escape
handlers* (channel/executor guards), *eliminating known native crash sources*,
and *recovering with evidence* (`ApplicationExitInfo` → marker →
next-launch report). Everything Dart-side is survivable in-process.

### 2. `ErrorReporter` — classify, throttle, present

Singleton (`core/error/error_reporter.dart`), deps injected for tests (log,
clock, dialog presenter):

1. `report(error, stack, {fatal})` → `axLog('error'|'crash', …, LogLevel.error)`
   with `error:` + `stack:` fields on the entry.
2. **Dedupe/throttle**: key = error type + top stack frame; repeats within
   10 s are counted in the log but show no second dialog (no dialog storms).
3. `fatal: true` (zone/dispatcher/native) also writes `crash_marker.json`
   (`{t, where: dart|native|rust, error, stack}`, best-effort, deleted after
   the report is shown once).
4. **Popup** via the root `navigatorKey` (no context plumbing):
   `ErrorDialog` — message + domain chip, actions **View logs** (pushes
   `LogsScreen(initialDomain: …)` so the feed is pre-filtered to the failure),
   **Copy**, **Dismiss**. App stays alive behind the barrier.
5. `BoundaryFallback.onTap` shows the dialog for the failure it was built
   with (`ErrorWidget.builder` *does* receive the `FlutterErrorDetails`;
   `reporter.lastError` is kept as belt-and-braces since the framework calls
   `FlutterError.onError` first).

### 3. Next-launch crash report (the "on crash → navigate" promise)

`main()` after `TesseraEngine.init()`: if `crash_marker.json` exists → hydrate
the log, then after the first frame show `CrashReportDialog` — "ApertureX hit a
serious error last session" + **View logs** / **Copy details** / **Dismiss** —
then delete the marker. This covers both Dart fatals that the app survived and
Kotlin crashes that killed it; the log already holds the stack.

### 4. Log schema v2 + retention

- `LogEntry` gains optional `error` (short), `stack` (truncated ~8 KB), `meta`
  (small map) — `decode` stays backward/forward-compatible (missing → null,
  unknown keys ignored). `activityLogReport` prints the new fields.
- New domains (colour-coded in `LogsScreen`): `error`, `crash`, `nav`,
  `native`, `engine`; lifecycle events go to the existing `app` domain.
- **Rotation**: `LogFileStore` caps `activity.log` at 2 MiB — after append, if
  over, rewrite keeping the newest 1 000 lines. Kotlin maintains
  `filesDir/aperturex/native.log` (same JSONL shape, trimmed at init); Rust
  appends `rust_panic.log` (also LogEntry-compatible JSONL, RFC3339 `t`).
  Three files, one writer each — no torn interleaved lines.
- Startup merge: `hydrateActivityLog(dir)` hydrates `activity.log` **plus**
  the tails of `native.log` (over the channel) **and** `rust_panic.log`
  (time-merged, capped at the 500-entry ring) — so **every layer's** errors
  are visible on the log page, not just Dart's.
- Logging code paths are structurally non-throwing (`LogFileStore` already
  swallows; reporters/observers must too).

### 5. What "every activity" means (granularity policy)

Logged: app lifecycle (start/resume/pause/detach/hot-restart), navigation
(push/pop via a `NavigatorObserver`, route names only), gallery pick/load/export
outcomes, editor open/close, tool/tab switches, preset/LUT/XMP applies,
undo/redo, export start/progress/finish/cancel, permission requests/results,
settings changes, engine/viewport events that matter (texture bind, ROI decode
native-vs-fallback outcome, bake/decode failures), and every boundary hit.

Not logged (noise): per-frame bakes, slider scrub deltas (commit granularity
only), scroll/pointer streams, per-tile work.

### 6. Android native hardening

- `AxApplication : Application` (manifest `android:name`): init native logger,
  install the uncaught handler (marker + `native.log`, then chain to default),
  then call `NativeLog.capturePreviousExit(this)`. On API 30+ it reads
  `ActivityManager.getHistoricalProcessExitReasons`, records the newest unread
  fatal exit (`CRASH_NATIVE`, `CRASH`, `SIGNALED`, `ANR`, init failure,
  resource exhaustion) to `native.log`, and reconstructs
  `crash_marker.json` with the exit description and trace. The last-seen
  timestamp lives in `last_exit_ms` so old exits are not re-reported; an
  existing JVM/Dart marker always wins.
- Audit every `setMethodCallHandler` and executor task: `try/catch` →
  `result.error(...)` / posted error — never an exception reaching the looper.
  Dart converts `PlatformException` → `ErrorReporter` (popup + log, app lives).

### 7. Rust

- `api::logging::init_panic_hook(dir)` called once from the `TesseraEngine`
  init chain: appends a **LogEntry-compatible JSONL** line to
  `rust_panic.log` (`t` RFC3339, `d: crash`, payload + panic location, fields
  capped ~4 KB) before unwinding; FRB's unwind capture then delivers the
  panic as an exception to the Dart boundary (popup + crash marker), and the
  startup merge puts the file's lines on the log page even when the panic was
  caught mid-session — a Rust failure is never invisible in the UI.

### 8. TDD slices (W13)

1. Schema: `LogEntry` error/stack/meta round-trip + legacy-line decode +
   `LogFileStore` rotation (pure/temp-dir tests).
2. `ErrorReporter`: classify/dedupe/throttle/log-write tests (fake clock +
   fake presenter).
3. Boundary wiring: invoke captured `FlutterError.onError` /
   `PlatformDispatcher.onError` / zone body in tests → assert log + popup.
4. UI: `ErrorDialog` deep-links to `LogsScreen(initialDomain:)`;
   `ErrorWidget.builder` fallback replaces a throwing subtree and opens the
   dialog on tap (widget tests).
5. `NavObserver` + lifecycle observer → entries (widget/binding tests).
6. `LogsScreen`: expandable stack detail + new domain colours (widget tests).
7. Kotlin (`AxApplication`, handlers): APK-compile gate — no JVM harness
   (same documented stance as the ROI channel); Dart-side `native.log`
   parsing/merge covered by fixture tests.
8. Rust panic-hook marker (cargo test, temp dir).
9. Docs + commit/push.

## Consequences

- The trio (`runZonedGuarded` + `FlutterError.onError` +
  `PlatformDispatcher.onError`) plus `ErrorWidget.builder` is the canonical
  Flutter equivalent of React error boundaries; there is **no per-widget
  boundary class** — subtree isolation comes from the global builder, which the
  framework feeds *after* calling `FlutterError.onError` (hence
  `reporter.lastError`).
- Dialogs are throttled by design: during a failure loop the user sees at most
  one popup per 10 s; the log still records every hit.
- Native main-thread death cannot be suppressed without hacky looper surgery —
  we choose **evidence + one-tap recovery** (marker → report → logs) over
  fake survival, and eliminate the realistic crash source (channel handlers)
  instead.
- Three small log files with a single writer each; no new third-party deps
  (`THIRD_PARTY.md` untouched).

## Follow-ups (workstream W13)

See `docs/IMPLEMENTATION_PLAN.md` §5 "W13 — Crash resilience & observability"
for the slice list, files, and status.
