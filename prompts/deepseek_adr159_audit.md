This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-159 EA SIDE (DAILY SNAPSHOT, LATCH PER TICK, EJECT ARCHIVE)

You are auditing an IMPLEMENTATION before it merges. It is tested (suite
1724/1724; the stub commit failed exactly as predicted). Find what tests
cannot see.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders), one instance per symbol and slot, many instances on one
FTMO account sharing terminal global variables (GVs). An FTMO day runs
00:00-24:00 Prague time (22:00Z in summer); the daily loss limit is
measured from the day-start balance, and equity includes open MTM.

**ADR-159 (EA side)**, attached at branch `adr159-ea` `05f5ae7`:
- D1/D2: `OnTimer` (every 1 s) detects the FTMO day roll; one instance
  claims it through a compare-and-swap on GV `GRIND_SNAPSHOT_CLAIM`.
- D3: the claimer emits a `DAILY_SNAPSHOT` row for the day that ENDED,
  from stored day-start GVs (`GRIND_SNAPSHOT_START_*`) or, if missing,
  from deal history; it then writes the new day's start values.
- D4: a once-per-day pre-midnight marker. D5: login in the heartbeat.
- D6: `EJECT_*` events now reach the archive. D7: `scalp_closed` carries
  `ejected`, computed BEFORE the ejection offset is deleted.
- **D9: an instance adopts a peer's breaker trip (GV
  `GRIND_BREAKER_TRIPPED_<day>`) on its next tick and cancels its own
  entry orders once. This moves orders; it is why you are here.**
- C29: the fleet magic table grows from 16 to 18 (NZDCHF OPT and ALT).
**Do not re-open ADR-159's design.** Attack the implementation.

## GIVENS -- verify each, cite the line

- G1. `Grind_BreakerOnTick` (`grind_engine.mqh:928`) is called from
  `OnTick` (`fxgrind.mq5:314`) before the halted return. After reading
  equity and balance it calls `Grind_BreakerAdoptPeerTrip(key)` (`:968`),
  then the own-trip block, then the existing cancel-once block
  (`Grind_CancelOwnEntryOrders`, `:985`), then the pre-midnight marker
  (`:993`).
- G2. `Grind_BreakerAdoptPeerTrip` (`:898`) sets only
  `g_grind_breaker_tripped`, emits nothing, and does nothing when the
  instance has already tripped.
- G3. In the OUT_BY branch, `was_ejected` (`:1875`) is computed before the
  scalp event is queued and before `Grind_EjectOffsetDelete` (`:1897`).
- G4. `Grind_SnapshotOnTimer` (`grind_snapshot.mqh:299`) never emits on
  its first call after a start; it emits only when the day key changes
  and the claim succeeds (`Grind_SnapshotClaim`, `:68`).
- G5. Every `HistorySelect` in the EA (`grind_engine.mqh:851`, `:910`,
  `:2221`; `grind_snapshot.mqh:225`) selects and then iterates within the
  same call, so the snapshot's selection cannot disturb another routine.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 D9 adoption paths.** Does an adopted trip block entries on the
  SAME tick (via `Grind_EntriesBlocked`) and cancel exactly once? What
  happens when this instance's key-change branch returned early (no
  allowance, `BREAKER_NO_BASIS`), when `InpBreakerEnable` differs between
  instances, when the instance is halted or quarantined, and on a restart
  mid-day with the GV already set?
- **T-2 Cancel path under D9.** `Grind_CancelOwnEntryOrders(magic, slot)`
  predates ADR-159. With adoption, can it now run at a moment it never ran
  before (for example on an instance whose own equity check never
  tripped, while its exit queue is mid-reprice)? Any interaction with
  resting EXIT orders or with purgatory-held entries?
- **T-3 Blocking flush at the roll (Claude, suspected NEEDS-FIX).**
  `Grind_SnapshotEmit` ends with `Grind_ArchiveFlush(true)` inside
  `OnTimer`. If that forces a synchronous `WebRequest`, the claimer's
  `OnTimer` blocks at 22:00Z for up to the request timeout, delaying its
  ticks and fills. Quantify from `grind_archive_flush.mqh`. Smallest fix?
  (Candidate: `Grind_ArchiveFlush(false)`, leaving the next timer flush to
  send it.)
- **T-4 Account switch (Claude, suspected NEEDS-FIX).** The start GVs are
  keyed by DAY only. If a new account is attached with stale
  `GRIND_SNAPSHOT_START_*` from the old account (the close-out clean-up
  skipped), its first row could use the old account's balance and equity
  with `start_known=true`. Smallest fix? (Candidate: also store
  `GRIND_SNAPSHOT_START_LOGIN` and require it to match.)
- **T-5 Degraded terminal at the roll.** Disconnected, or history not yet
  loaded: `HistorySelect` fails and `deal_swap_day`/`nontrade` silently
  stay 0; `TimeTradeServer()` is an estimate. Should the row say so, and
  what is the smallest honest flag?
- **T-6 Archive pressure.** D6 adds archive events in the fill path
  (`EJECT_FILLED`) and on every refused or accepted eject. Can these
  crowd out `fill_log` rows under queue limits (see `grind_archive.mqh`)?
- **T-7 Claim and GV lifecycle.** Races between instances at the roll;
  a claimer that dies between claiming and emitting (that day's row is
  lost -- acceptable?); GV flush timing (`Grind_GvMarkDirty`) for the
  start values across a terminal crash.
- **T-8 C29 side effects.** Everything that iterates the fleet table
  (`Grind_IsFleetMagic` in the slot guard, `grind_magic_lock.mqh`, the
  cap). Any behaviour change on a live account with the cap disabled
  (thresholds 0.0)?

## RULES

- Cite `file:line` for every claim; otherwise mark it INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside ADR-159's implementation and the code it touches.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G5: CONFIRMED / WRONG (with line)
T-1 .. T-8       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- safe to merge? one paragraph
TEST GAPS        -- tests missing, with expected values
```

Line count: 107
