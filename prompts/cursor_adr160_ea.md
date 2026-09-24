This message has a line count at the bottom

# CURSOR -- ADR-160 EA: ALL-DAY FLOATING-LOSS GATE (R4, 50/40), TESTS FIRST -- REV 0

**For Gemini first** (one question at the end), then Cursor.

## AUDIT TRAIL

| item | where | status |
|---|---|---|
| Design | `docs/architecture/ADR-160-carried-mtm-daily-limit.md` rev 1 (231 lines), sections 8-9 (D1-D5) | ACCEPTED |
| Base | fxmatrix `main` `07efa38`; code = ADR-159 merge `1c4a549`, suite 1739/1739 | verified by Claude |
| Breaker | `grind_engine.mqh`: globals ~821-845 (`g_grind_breaker_premidnight`, `g_grind_breaker_allowance` at ~839); `Grind_BreakerBlocksEntries` ~825; pre-midnight line ~989 at the end of `Grind_BreakerOnTick` | verified |
| Entry sites | the five `if(Grind_EntriesBlocked()) return` sites (~1014, ~1240, ~1449, ~1553, ~1664) only return; nothing cancels | verified |
| Pure | `Grind_BreakerPreMidnightHalt` in `grind_pure.mqh` ~499 | verified |
| Reporter lease | `g_grind_mae_is_reporter` (`grind_mae.mqh:22`), visible to the engine via `grind_telemetry.mqh` | verified |
| Timer | `OnTimer` (`fxgrind.mq5`): the telemetry-interval block calls `Grind_MaeOnTimer()` first | verified |
| Snapshot | `grind_snapshot.mqh` (ADR-159): struct `GrindSnapshot`, `Grind_SnapshotCompute` sets `history_ok = true` first, JSON ends with `history_ok` | verified |
| Test prefix | `GT` unused; `Test_B9_EntriesBlocked` is unaffected (its clear case sets `enabled` false) | verified |

## SETUP

1. `git fetch origin && git checkout main && git pull --ff-only`; report
   `git log --oneline -1`.
2. `git checkout -b adr160-gate`; `git branch --show-current` before EVERY
   commit.

## 1. BUILD (commit 2)

**`grind_pure.mqh`:**
- `bool Grind_BreakerFloatGate(const bool was_gated, const double floating,
  const double allowance)`: `if(allowance <= 0.0) return false;` if
  `!was_gated` return `floating >= 0.5 * allowance`; else return
  `floating > 0.4 * allowance`.
- `int Grind_GateAddSeconds(const datetime last, const datetime now, const
  int cap)`: `0` if `last <= 0` or `now <= last`; else
  `MathMin((int)(now - last), cap)`.

**`grind_engine.mqh`:**
- `bool g_grind_breaker_gated = false;` beside `g_grind_breaker_premidnight`.
- `Grind_BreakerBlocksEntries()` returns `g_grind_breaker_enabled &&
  (g_grind_breaker_tripped || g_grind_breaker_premidnight ||
  g_grind_breaker_gated)`.
- `void Grind_BreakerGateTransition(const bool was_gated, const bool
  now_gated, const bool is_reporter, const double floating, const double
  allowance, const string key)`: return if `was_gated == now_gated` or
  `!is_reporter`; else `Grind_ArchiveMarker("INFO", now_gated ?
  "BREAKER_GATE_ON" : "BREAKER_GATE_OFF", key, 0, detail)`, with detail
  `{"floating":<2dp>,"allowance":<2dp>,"day":"<key>"}` built with
  `Grind_ArchiveJsonDouble`.
- At the END of `Grind_BreakerOnTick`, after the pre-midnight lines:
  `const bool was_gated = g_grind_breaker_gated;`
  `g_grind_breaker_gated = Grind_BreakerFloatGate(was_gated, balance -
  equity, g_grind_breaker_allowance);`
  `Grind_BreakerGateTransition(was_gated, g_grind_breaker_gated,
  g_grind_mae_is_reporter, balance - equity, g_grind_breaker_allowance,
  key);`

**`grind_snapshot.mqh`:**
- `datetime g_grind_gate_last_add = 0;`
- `void Grind_GateAccumulate(const string gv_name, const bool is_reporter,
  const bool gated, const datetime now, const int cap)`: if
  `!is_reporter`, set `g_grind_gate_last_add = 0` and return;
  `const int add = Grind_GateAddSeconds(g_grind_gate_last_add, now, cap);`
  `g_grind_gate_last_add = now;` if `gated && add > 0`:
  `GlobalVariableSet(gv_name, GlobalVariableGet(gv_name) + add)` (an absent
  GV reads 0) and `Grind_GvMarkDirty()`.
- `GrindSnapshot` gains `int gated_seconds`; `Grind_SnapshotCompute` sets
  `s.gated_seconds = 0;` right after `s.history_ok = true;`.
  `Grind_SnapshotEmit` sets it from GV `"GRIND_SNAPSHOT_GATED_S_" +
  ended_key` (0 if absent). `Grind_SnapshotJson` appends
  `,"gated_seconds":<n>` as the LAST key, after `history_ok`.

**`fxgrind.mq5`:** in the telemetry-interval block of `OnTimer`, directly
after `Grind_MaeOnTimer();`:
`Grind_GateAccumulate("GRIND_SNAPSHOT_GATED_S_" + Grind_FtmoDayKey(TimeGMT()),
g_grind_mae_is_reporter, g_grind_breaker_gated, TimeGMT(), 2 *
TelemetryIntervalSec);`

## 2. TESTS (commit 1) -- `ea/fxgrind_tests.mq5`, registered after SN19

Each GT test saves and restores every breaker global it touches, resets
`g_grind_breaker_gated = false` and `g_grind_gate_last_add = 0` at start
and end, calls `Grind_ArchiveTestReset()` (archive configured as AR4 does)
where it checks the queue, and deletes `GRIND_TEST_GATED_S` at start and
end. Use EXACTLY these assertion names.

| test | assertions |
|---|---|
| `Test_GT1_FloatGate` (allowance 500) | `GT1 engage at 250` (false, 250.00) true; `GT1 below 250` (false, 249.99) false; `GT1 hold at 200.01` (true, 200.01) true; `GT1 clear at 200` (true, 200.00) false; `GT1 no allowance off` (false, 300, allowance 0) false; `GT1 no allowance gated off` (true, 300, allowance 0) false |
| `Test_GT2_BlocksWhenGated` | enabled true, tripped false, premidnight false, gated true: `GT2 gated blocks` true; enabled false: `GT2 gated off switch` false |
| `Test_GT3_AddSeconds` (cap 120) | `GT3 first call` (0, 1000) 0; `GT3 normal` (1000, 1060) 60; `GT3 capped` (1000, 1500) 120; `GT3 zero` (1060, 1060) 0; `GT3 backwards` (1100, 1000) 0 |
| `Test_GT4_Accumulate` (GV `GRIND_TEST_GATED_S`, cap 120; after each call read the GV, absent = 0) | reporter+gated at t=1000: `GT4 first zero` 0; reporter+gated t=1060: `GT4 plus 60` 60; reporter, NOT gated, t=1120: `GT4 not gated` 60; NOT reporter, gated, t=1180: `GT4 not reporter` 60; reporter+gated t=1240: `GT4 lease regained` 60; reporter+gated t=1300: `GT4 total 120` 120 |
| `Test_GT5_Transition` (floating 260, allowance 500, key `2099.01.07`) | (false, true, reporter): `GT5 on count` queue +1, `GT5 on code` peek contains `BREAKER_GATE_ON`; (true, false, reporter): `GT5 off count` +1 more, `GT5 off code` contains `BREAKER_GATE_OFF`; (false, true, NOT reporter): `GT5 not reporter` count unchanged; (true, true, reporter): `GT5 unchanged` count unchanged |
| `Test_GT6_SnapshotGatedSeconds` | SN3's compute inputs: `GT6 default zero` JSON contains `"gated_seconds":0`; after `s.gated_seconds = 3600;`: `GT6 3600` contains `"gated_seconds":3600` |

**Commit 1** `ADR-160 EA tests and stubs (GT1-GT6)`. Stubs: every NEW
function exists with a do-nothing body (`return false`, `return 0`, empty),
the new globals and struct field exist, and NOTHING existing changes:
`Grind_BreakerBlocksEntries`, `Grind_BreakerOnTick`, `Grind_SnapshotCompute`,
`Grind_SnapshotJson`, `Grind_SnapshotEmit` and `OnTimer` are untouched.

**Commit 2** `ADR-160 EA: all-day floating-loss gate (50/40), transitions, gated seconds`.

**Expected (the operator runs):** stub `SUMMARY: 1750/1766`, failing exactly
`GT1 engage at 250`, `GT1 hold at 200.01`, `GT2 gated blocks`, `GT3 normal`,
`GT3 capped`, `GT4 plus 60`, `GT4 not gated`, `GT4 not reporter`, `GT4
lease regained`, `GT4 total 120`, `GT5 on count`, `GT5 on code`, `GT5 off
count`, `GT5 off code`, `GT6 default zero`, `GT6 3600`. Real: `SUMMARY:
1766/1766`.

## NEGATIVE SPACE

- No change to the 80% trip, its latch, D9 adoption, the pre-midnight
  halt, or any entry site. No order is cancelled by the gate.
- No new inputs. No preset, pipshed, runbook or handoff change.
- Do NOT deploy, CLI compile, launch MetaTrader or run the suite. No
  `git stash`, `git add .`, `git add -u`, merge, PR or amend. ASCII only.
- Never change an existing assertion or expected value.

## FAILURE MODES -- STOP AND REPORT

- Any audit-trail site is not where stated.
- `g_grind_mae_is_reporter` is not visible where `Grind_BreakerOnTick` is
  compiled.

## FOR GEMINI

- **Q1.** D4 counts gated time per telemetry interval by the reporter-lease
  holder, capping one addition at twice the interval so a stalled timer
  cannot add a huge block. Accept?

## FINAL REPORT (fixed format)

```
BRANCH: <git branch --show-current>
BASE:   <sha>
COMMIT1: <sha from git log>  files: <list>
COMMIT2: <sha from git log>  files: <list>
PUSHED: <git ls-remote origin adr160-gate>
DIFF:   <git diff --stat origin/main..adr160-gate>
DEVIATIONS: <none, or each one with reason>
```

Line count: 145
