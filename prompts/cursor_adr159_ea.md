This message has a line count at the bottom

# CURSOR -- ADR-159 EA SIDE (D1-D9) + C29 FLEET MAGIC, TESTS FIRST -- REV 0

**For Gemini first** (questions at the end), then Cursor. The pipshed side
is merged and live (pipshed `e475506`, migration `002` applied); it already
accepts every field this prompt emits.

## AUDIT TRAIL

| item | where | status |
|---|---|---|
| Design | `docs/architecture/ADR-159-daily-snapshot-critical-banner.md` rev 2 (367 lines) | ACCEPTED |
| Base | fxmatrix `main` `ed1756f`; code identical to tested `646b526` | verified by Claude |
| Timer | `OnTimer` (`fxgrind.mq5:268`), `EventSetTimer(1)` at `:251`, first line `Grind_GvFlushIfDirty()` | verified |
| C25 flush | `Grind_GvMarkDirty()` / `Grind_GvFlushIfDirty()`, `grind_carry.mqh:487-500` | verified |
| Breaker | `Grind_BreakerOnTick`, `grind_engine.mqh` ~898-956; latch GV read ONLY at a day-key change (~933) | verified (F5) |
| FTMO day | `Grind_FtmoDayKey` returns `"yyyy.mm.dd"`; `Grind_FtmoDayStartGmt`; `Grind_BreakerDayAnchor`, `Grind_BreakerCollectDealHistory`, `Grind_BreakerLoadInitialDeposit` | verified |
| Eject emits | `EJECT_REFUSED` ~402 and ~505, `EJECT_ACCEPTED` ~426, `EJECT_FILLED` ~1855: all `Grind_TelemetryEmit` = `Print` only | verified (F1) |
| OUT_BY branch | `grind_engine.mqh` ~1821-1864: `Grind_QueueScalpClosedEvent` at ~1840, then `Grind_EjectIsEjected` at ~1850, then `Grind_EjectOffsetDelete` | verified (F2) |
| Scalp payload | `Grind_BuildScalpClosedPayload` (`grind_scalp_events.mqh`), 9 fields; tests `Test_S1_*`, `Test_S2_ScalpPayloadNineFields` | verified |
| Heartbeat | `Grind_TelemetryHeartbeatJson` (`grind_telemetry.mqh:187`); already carries `account_balance`, `account_equity` | verified |
| Guard | `g_grind_last_guard_total` (`grind_api_counter.mqh:21`), assigned at `grind_engine.mqh` ~1218 and ~1476 | verified |
| Fleet table | `GRIND_CAP_ALL_MAGICS[16]`, `GRIND_CAP_MAGIC_LEG_A[16]`, `GRIND_CAP_MAGIC_LEG_B[16]`, `#define GRIND_CAP_MAGIC_COUNT 16` (`grind_cap.mqh:18-56`); `22260701` absent everywhere in `ea/`; `Test_CM1_CapMagicsCoverFleet` asserts size 16 | verified (C29) |
| Archive test hooks | `Grind_ArchiveTestReset`, `Grind_ArchiveQueueCount`, `Grind_ArchiveQueuePeek` (see `AR4`) | verified |
| Test prefix | `SN` is unused | verified |
| Contract | the 21 `DAILY_SNAPSHOT` keys in pipshed `ftmo_daily.py` (section 3 below) | verified in pipshed |

## SETUP

1. `git fetch origin && git checkout main && git pull --ff-only`;
   `git log --oneline -1` -- report the SHA.
2. `git checkout -b adr159-ea`. Run `git branch --show-current` before
   EVERY commit; it must print `adr159-ea`.
3. Confirm `origin/main` holds this spec: `prompts/cursor_adr159_ea.md`
   has the line count in its footer. STOP if it differs.

## 1. WHAT TO BUILD

**New file `ea/grind_snapshot.mqh`**, included in `ea/fxgrind.mq5` AND
`ea/fxgrind_tests.mq5` directly after `#include "grind_engine.mqh"`.

**D1/D2 -- roll detection and claim.**
- Global `string g_grind_snapshot_day_key = "";`
- Pure: `bool Grind_SnapshotRollDue(const string last_key, const string key)`
  returns `last_key != "" && last_key != key`.
- Pure: `int Grind_FtmoDayNum(const string key)`: `"2026.09.23"` ->
  `20260923`; anything not exactly 10 chars in that shape -> `0`.
- `bool Grind_SnapshotClaim(const string gv_name, const int day_num)`:
  if the GV does not exist, `GlobalVariableSet(gv_name, 0.0)`; read `v`;
  if `v >= day_num` return false; if
  `!GlobalVariableSetOnCondition(gv_name, day_num, v)` return false;
  `Grind_GvMarkDirty()`; return true. Production name:
  `GRIND_SNAPSHOT_CLAIM`. The name is a parameter so tests use their own.
- `void Grind_SnapshotOnTimer()`: `key = Grind_FtmoDayKey(TimeGMT())`. If
  `g_grind_snapshot_day_key == ""`: set it to `key` and return (a startup
  never emits). If `Grind_SnapshotRollDue(last, key)`: set the global to
  `key` FIRST, then, if `Grind_SnapshotClaim("GRIND_SNAPSHOT_CLAIM",
  Grind_FtmoDayNum(key))`, call `Grind_SnapshotEmit(last)`.
- In `OnTimer`, call `Grind_SnapshotOnTimer()` as the SECOND line, directly
  after `Grind_GvFlushIfDirty()`: every second, outside the telemetry
  interval block, whether or not the instance is halted.

**D3 -- the row.**
- `struct GrindSnapshot` with one member per contract key (section 3),
  plus `bool guard_known`.
- Pure: `void Grind_SnapshotCompute(const bool start_known, const double
  stored_bal_start, const double stored_eq_start, const double
  stored_pswap_start, const double hist_bal_start, const double bal_end,
  const double eq_end, const double pswap_now, const double
  deal_swap_day, GrindSnapshot &s)`:
  - `balance_start` = stored if `start_known`, else `hist_bal_start`;
    `balance_start_source` = `"stored"` / `"history"`.
  - `balance_end`, `equity_end` as given; `realised = bal_end - balance_start`.
  - Only if `start_known`: `equity_start = stored_eq_start`;
    `inventory_pnl = (eq_end - bal_end) - (stored_eq_start - balance_start)`;
    `total = eq_end - stored_eq_start`;
    `swap_day = deal_swap_day + (pswap_now - stored_pswap_start)`.
- Pure: `string Grind_SnapshotJson(const GrindSnapshot &s)`: exactly the 21
  contract keys; money with 2 decimals; `account_login` as a bare integer;
  `ftmo_day` and `balance_start_source` quoted; booleans bare. When
  `!start_known`, `equity_start`, `inventory_pnl`, `total` and `swap_day`
  are `null`. When `!guard_known`, `guard_age_s` is `null`.
- `void Grind_SnapshotEmit(const string ended_key)`:
  - `now_gmt = TimeGMT()`; `off = TimeTradeServer() - TimeGMT()`;
    `start_next = Grind_FtmoDayStartGmt(now_gmt)`; `start_ended =
    Grind_FtmoDayStartGmt(start_next - 1)`. Server-time window for the
    ended day: `[start_ended + off, start_next + off - 1]`.
  - Collect over that window, ALL deals: `deal_swap_day` = sum of
    `DEAL_SWAP`; `nontrade` = sum of profit + swap + commission + fee over
    deals whose `DEAL_TYPE` is neither `DEAL_TYPE_BUY` nor `DEAL_TYPE_SELL`.
  - `pswap_now` = sum of `POSITION_SWAP` over ALL open positions (all magics).
  - Stored start: `GRIND_SNAPSHOT_START_DAY`, `_START_BAL`, `_START_EQ`,
    `_START_PSWAP`. `start_known` iff `START_DAY` exists and equals
    `Grind_FtmoDayNum(ended_key)`. Read these BEFORE step 7 overwrites them.
  - `hist_bal_start`: `Grind_BreakerLoadInitialDeposit()`, then
    `Grind_BreakerCollectDealHistory(start_ended + off, TimeTradeServer()
    + 60, ...)` and `Grind_BreakerDayAnchor(balance_now, ..., start_ended
    + off, g_grind_breaker_initial_deposit, g_grind_breaker_initial_time)`,
    exactly as the breaker does.
  - Account-wide: `positions_long` / `positions_short` (by
    `POSITION_TYPE`), `orders = OrdersTotal()`, `account_login =
    AccountInfoInteger(ACCOUNT_LOGIN)`, `broker_utc_offset_s = off`.
  - `guard_total = g_grind_last_guard_total`; `guard_known =
    g_grind_last_guard_time > 0`; `guard_age_s = now_gmt -
    g_grind_last_guard_time`.
  - `breaker_tripped = GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" +
    ended_key)`; `premidnight_seen = GlobalVariableCheck("GRIND_BREAKER_PREMID_"
    + ended_key)`.
  - Step 7: write the NEW day's start: `START_DAY = Grind_FtmoDayNum(current
    key)`, `START_BAL = balance`, `START_EQ = equity`, `START_PSWAP =
    pswap_now`; `Grind_GvMarkDirty()`.
  - Emit: `json = Grind_SnapshotJson(s)`;
    `Grind_TelemetryEmit(g_grind_telemetry_instance, "DAILY_SNAPSHOT", json)`;
    `Grind_ArchiveMarker("INFO", "DAILY_SNAPSHOT", ended_key, 0, json)`;
    `Grind_ArchiveFlush(true)`.
- **Guard age:** add `datetime g_grind_last_guard_time = 0;` beside
  `g_grind_last_guard_total`, and set it to `TimeGMT()` on the line after
  EACH of the two assignments of `g_grind_last_guard_total`.

**D4 -- pre-midnight marker.** New `bool Grind_BreakerMarkPremidnight(const
string key)` in `grind_engine.mqh` beside the breaker: if
`GlobalVariableCheck("GRIND_BREAKER_PREMID_" + key)` return false; set it to
1.0; `Grind_GvMarkDirty()`; `Grind_ArchiveMarker("INFO",
"BREAKER_PREMIDNIGHT", key, 0, "{\"day\":\"" + key + "\"}")`; return true.
Call it at the END of `Grind_BreakerOnTick`, after
`g_grind_breaker_premidnight` is computed, only when that flag is true.

**D5 -- heartbeat.** In `Grind_TelemetryHeartbeatJson`, add
`"account_login":<AccountInfoInteger(ACCOUNT_LOGIN)>` (bare integer)
directly after `account_equity`. No signature change.

**D6 -- ejection reaches the archive.** New `void Grind_EjectReport(const
string code, const ulong ticket, const string detail)` in
`grind_engine.mqh`: `Grind_TelemetryEmit(g_grind_telemetry_instance, code,
detail)` then `Grind_ArchiveMarker("INFO", code, "", ticket, detail)`.
Replace the `Grind_TelemetryEmit` call at each of the FOUR eject emit sites
(two `EJECT_REFUSED`, one `EJECT_ACCEPTED`, one `EJECT_FILLED`) with
`Grind_EjectReport`, passing the POSITION ticket already in each detail.
Details and `Print` lines unchanged.

**D7 -- flag at source.** `Grind_BuildScalpClosedPayload` and
`Grind_QueueScalpClosedEvent` gain three LAST parameters: `const bool
ejected, const long broker_utc_offset_s, const long account_login`. The
payload adds `"ejected":true|false`, `"broker_utc_offset_s":<n>`,
`"account_login":<n>` after `instance_id`. In the OUT_BY branch, compute
`const bool was_ejected = Grind_EjectIsEjected(side.layers[i].position_ticket);`
BEFORE the queue call; pass `was_ejected`, `(long)(TimeTradeServer() -
TimeGMT())`, `AccountInfoInteger(ACCOUNT_LOGIN)`; and change the later
`if(Grind_EjectIsEjected(closed_position))` to `if(was_ejected)`.
In `Test_S2_ScalpPayloadNineFields`, APPEND `false, 10800, 1514582088` to the
builder call. Change nothing else in S1 or S2.

**D8 -- clean-up.** Add `"GRIND_SNAPSHOT_",` to the prefix list in
`scripts/grind_gv_clean.mq5`, directly before `"GRIND2226_",`.

**D9 -- breaker latch every tick.** New `void Grind_BreakerAdoptPeerTrip(const
string key)`: `if(!g_grind_breaker_tripped &&
GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + key)) g_grind_breaker_tripped
= true;` -- nothing else, no event. In `Grind_BreakerOnTick`, call it
directly after the `equity` and `balance` reads and BEFORE the
`Grind_BreakerShouldTrip` block. The existing cancel block then cancels
this instance's entry orders once.

**C29 -- fleet table.** Append `22260701UL, 22260702UL` to
`GRIND_CAP_ALL_MAGICS`, `"NZD", "NZD"` to `GRIND_CAP_MAGIC_LEG_A`, `"CHF",
"CHF"` to `GRIND_CAP_MAGIC_LEG_B`; all three sizes and
`GRIND_CAP_MAGIC_COUNT` become 18. Update the comment to "All eighteen known
fxgrind magics". In `Test_CM1_CapMagicsCoverFleet`, the expected list gains
the two magics and the size assert reads 18. **This is the ONLY permitted
change to an existing expected value.**

## 2. TESTS (commit 1) -- `ea/fxgrind_tests.mq5`, registered in the run list

Every SN test starts AND ends with: `Grind_ArchiveTestReset()`,
`Grind_TestResetSideState()`, deleting every GV it created, and resetting
`g_grind_breaker_tripped`, `g_grind_breaker_cancel_done`,
`g_grind_snapshot_day_key`. Test GV day keys use `2099.01.0x`, and the claim
GV is named `GRIND_TEST_SNAPSHOT_CLAIM`. Configure the archive the way AR4
does before any archive assertion. Write the hand derivation above every
numeric assert.

| test | assert |
|---|---|
| `Test_SN1_ComputeKnownStart` | the 23 Sep numbers: stored bal 10190.96, eq 9860.50, pswap -15.67; end bal 9685.62, eq 9685.62; pswap_now 0; deal_swap_day -15.67 -> realised -505.34, inventory +330.46, total -174.88, swap_day 0.00, source "stored" (all within 1e-6) |
| `Test_SN2_ComputeUnknownStart` | start_known false, hist 10190.96 -> balance_start 10190.96, realised -505.34, source "history" |
| `Test_SN3_JsonContract` | SN1's struct: all 21 keys present; `"ftmo_day":"2026.09.23"`; `"account_login":1514582088`; `"start_known":true` |
| `Test_SN4_JsonNulls` | SN2's struct, guard_known false: `"equity_start":null`, `"inventory_pnl":null`, `"total":null`, `"swap_day":null`, `"guard_age_s":null`, `"start_known":false`, `"balance_start_source":"history"` |
| `Test_SN5_DayNum` | `"2026.09.23"` -> 20260923; `""` -> 0; `"2026-09-23"` -> 0 |
| `Test_SN6_Claim` | on `GRIND_TEST_SNAPSHOT_CLAIM`: day 20990102 true; again false; 20990101 false; 20990103 true; GV deleted at end |
| `Test_SN7_RollDue` | ("", k) false; (k, k) false; ("2099.01.01", "2099.01.02") true |
| `Test_SN8_PremidnightOnce` | key `2099.01.04`: first call true, GV exists, queue count +1 and peek contains `BREAKER_PREMIDNIGHT`; second call false, count unchanged |
| `Test_SN9_AdoptPeerTrip` | GV `GRIND_BREAKER_TRIPPED_2099.01.05` set, tripped false -> after call tripped true, `cancel_done` still false, queue count unchanged; with no GV, tripped stays false |
| `Test_SN10_EjectReport` | `Grind_EjectReport("EJECT_FILLED", 5001, "{\"ticket\":5001}")`: count 1; peek contains `EJECT_FILLED` and `5001` |
| `Test_SN11_ScalpPayloadNewFields` | builder with `true, 10800, 1514582088`: contains `"ejected":true`, `"broker_utc_offset_s":10800`, `"account_login":1514582088`; with `false` contains `"ejected":false` |
| `Test_SN12_OutByCarriesEjectedFlag` | model on `Test_S1_CloseByPairEmitsOneScalpEvent`; before the OUT_BY deal, `Grind_EjectOffsetSet(<ENT position>, 0.00010)`: the queued payload contains `"ejected":true`, and afterwards `Grind_EjectIsEjected(<ENT>)` is false (offset deleted). Clean the offset GV at the end |
| `Test_SN13_HeartbeatLogin` | a heartbeat from `Grind_TelemetryHeartbeatJson` contains `"account_login":` |
| `Test_SN14_FleetMagicNzdchf` | `Grind_IsFleetMagic(22260701)` and `(22260702)` true; `Grind_CapMagicCarriesLeg` for each: NZD true, CHF true, USD false |

**Commit 1 message:** `ADR-159 EA tests and stubs (SN1-SN14, CM1 at 18)`.
Stubs: every new function exists with a do-nothing body (`return false`,
`return 0`, `return ""`, compute leaves the struct untouched); the new
D7 parameters exist but are not emitted, and the OUT_BY call passes the
placeholders `false, 0, 0` (commit 2 replaces them); the four eject sites
are NOT yet changed; the fleet table is NOT yet changed. Do not
predict the suite totals; list every SN assertion by its full name in the
report.

**Commit 2 message:** `ADR-159 EA: daily snapshot, eject archive, scalp flag, latch per tick, NZDCHF fleet magic`.

## 3. THE CONTRACT (pipshed parses exactly these)

`account_login, ftmo_day, balance_start, equity_start, balance_end,
equity_end, realised, nontrade, inventory_pnl, total, swap_day,
positions_long, positions_short, orders, guard_total, guard_age_s,
breaker_tripped, premidnight_seen, broker_utc_offset_s, start_known,
balance_start_source`.

## NEGATIVE SPACE

- No new inputs; no preset, pipshed, runbook or handoff change.
- No change to entry, exit, carry or ejection DECISIONS other than D9.
  Nothing in reconstruction or the invariants reads a `GRIND_SNAPSHOT_*`
  or `GRIND_BREAKER_PREMID_*` GV.
- Do NOT deploy, CLI compile, launch MetaTrader or run the suite. The
  operator compiles in MetaEditor and runs the suite; stub-check first.
- No `git stash`, `git add .`, `git add -u`, merge, PR or amend. Add by path.
- ASCII only.

## FAILURE MODES -- STOP AND REPORT

- Any audit-trail site is not where stated (source drifted).
- MQL5 rejects a struct member of type `string` in `GrindSnapshot`, or
  default arguments where D7 needs none.
- Any existing test other than CM1 would need an expected value changed.

## FOR GEMINI

- **Q1.** D9 adopts a peer's trip on the next tick, cancels this
  instance's entries once through the existing path, and emits nothing.
  DeepSeek audits D9 after the build (it cancels orders). Anything to add
  before we build?
- **Q2.** The snapshot's day window is in server time, `[start_ended +
  off, start_next + off - 1]`, with `off = TimeTradeServer() - TimeGMT()`
  read at emission. The breaker builds its anchor the same way. Any
  objection?
- **Q3.** C29 adds both NZDCHF magics now: OPT (`22260701`, cycle 3) and
  ALT (`22260702`, reserved for the C30 duplicate). The currency cap stays
  disabled (thresholds 0.0). Accept adding ALT now?

## FINAL REPORT (fixed format)

```
BRANCH: <git branch --show-current>
BASE:   <sha>
COMMIT1: <sha from git log>  files: <list>
COMMIT2: <sha from git log>  files: <list>
PUSHED: <git ls-remote origin adr159-ea>
LINES:  <wc -l of every changed file>
DIFF:   <git diff --stat origin/main..adr159-ea>
SN ASSERTIONS: <every SN assertion name, one per line>
DEVIATIONS: <none, or each one with reason>
```

Line count: 265
