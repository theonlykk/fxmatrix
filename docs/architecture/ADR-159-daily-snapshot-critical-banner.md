This message has a line count at the bottom

# ADR-159 -- DAILY SNAPSHOT, CRITICAL BANNER, ACCOUNT IDENTITY, EJECTED-FILL EXCLUSION (C24 + C19 + A5 + A2 point 4)

**Status:** IMPLEMENTED 2026-09-23 (section 11). pipshed `e475506`
(migration 002 applied); fxmatrix EA `1c4a549`, suite 1739/1739. Accepted
rev 2, 2026-09-23 (operator confirmed). Gemini ruled on G1-G8; his rulings and our verification of
each are in section 10. History: rev 0 `930cd27`; rev 1 `8703226`
folded in the previous chat's review of rev 0: F5 fixed here as D9 and
recorded as an ADR-158 rev 2 note; F6 corrected; event days from the EA's
UTC clock, not ingest time; broker offset reported, never assumed. Spans two repos (fxmatrix
EA, pipshed). Gates cycle 3 (pre-registration A2 point 8). Operator stance:
demo mode -- ship a clear rule, learn from the demo, adjust. No arbitrary
barriers.

**Gemini:** your questions are in section 9 (G1-G8). Rule on each. Please
reason from the cited source lines rather than from general architecture.
Where a claim below is INFERRED rather than read in source, it says so.

---

## 0. AUDIT TRAIL

Verified at fxmatrix `53a38d2` (code tree == tested `646b526`) and pipshed
`5153977`.

| # | finding | where | status |
|---|---|---|---|
| F1 | `EJECT_ACCEPTED / REFUSED / FILLED` are JOURNAL-ONLY. `Grind_TelemetryEmit` is a `Print`; only `Grind_ArchiveMarker` and `Grind_TelemetryCritical` reach `ea_events`. A2 points 4-5 assume pipshed sees them; it does not | `grind_telemetry.mqh:118-124`; emit sites `grind_engine.mqh:402,426,505,1855` | fix here (D6) |
| F2 | `scalp_closed` is queued BEFORE the ejected check and carries no ejected flag, so the dashboard's scalp counts and `scalp_history` include ejected fills | `grind_engine.mqh` ~1840 (queue) vs ~1850 (`Grind_EjectIsEjected`) | fix here (D7) |
| F3 | `ea_events` are deleted after 90 days. A daily table rebuilt from events would lose history | pipshed `archive_worker.py` `run_retention_if_due` | fix here (P1) |
| F4 | The pre-midnight entry halt sets a flag and emits NOTHING. A2 point 5 reports it | `grind_engine.mqh:959` | fix here (D4) |
| F5 | **Breaker latch read only at a day-key change.** `GRIND_BREAKER_TRIPPED_<day>` is read at `:934` only when the key changes. An instance that did not itself see equity under the trip keeps entering after another instance tripped, if equity recovers first. ADR-158 decision 4 says "all instances agree". Previous chat: a spec bug, not a design choice | `grind_engine.mqh:906-935,940-952` | fix here (D9) |
| F6 | ADR-156 has two events: WARN `STARTUP_EXIT_SHORTFALL` on any shortfall, and CRITICAL `STARTUP_EXIT_SHORTFALL_SIDE` (archived via `Grind_TelemetryCritical`) when a side has every required exit missing. C19's example is the CRITICAL one, so a CRITICAL-only banner shows it | `fxgrind.mq5:182-188` | G4 (WARN tier only) |
| F7 | Breaker day logic runs only in `OnTick`. That is deliberate and harmless for the breaker (entries only happen on ticks). But a snapshot roll detector there would miss Saturday and Sunday | `fxgrind.mq5:312` | D1 uses `OnTimer` |
| F8 | No canonical s4 scalp counter exists. `archive_counts.py` has no scalp mode. The cycle-3 figures (4.2x dispersion) came from `scripts/measure_geometry_depth_holdtime.py` on the UNMERGED branch `research/geometry-depth-holdtime`. It reads a CSV deals dump (`data/deals_dump_20260918_2354.csv`) and takes CloseBy as `entry == OUT_BY` with a `#` comment; it does not read the archive | pipshed `scripts/archive_counts.py`; branch `afcf214` | P5, operator to confirm |
| F10 | `ea_time_ms` is UTC epoch milliseconds: the archive clock is anchored from `TimeGMT()*1000` at configure and advanced by the tick counter. It is on every archived row EXCEPT `scalp_history` (built from the `scalp_closed` POST) | `grind_archive.mqh:112,126-132,268`; `archive_worker.py` `build_row` | P2 uses it |
| F11 | Broker time is UTC+3 in September (observed). It is NOT verified year-round; a server of this kind may run +2 in winter and may switch on US rather than EU dates (INFERRED). ADR-158 already derives the offset at runtime (`TimeTradeServer() - TimeGMT()`). ADR-158 section 1's "01:00 broker" is a summer statement | `grind_engine.mqh:924-925` | D3/D7 report it |
| F9 | Existing and usable: `CARRY_PASS_SUMMARY` / `_INCOMPLETE` are already archived with a `clamped` count (C26 source); `BREAKER_TRIPPED` is archived CRITICAL; `config_events.account_login` is set on every ONINIT/DEINIT | `grind_carry.mqh:820-836`; `grind_telemetry.mqh:162-183`; `archive_worker.py` CONFIG_EVENT_FIELDS | reuse |

---

## 1. CONTEXT

Realised P&L counts only winners (no stops), so it cannot show whether
the system makes money (backlog C24). The daily equation is spread
capture (realised) minus adverse selection (the change in inventory P&L).
FTMO judges the account per FTMO day (00:00 CE(S)T, ADR-158). A2 point 5
fixes the secondary measures per FTMO day, reported in USD beside pips,
with no USD target. CRITICAL events are stored in `ea_events` but never
shown on the dashboard (C19). Cycle 2 and cycle 3 must not mix (A5).
Ejected fills are not scalps (A2 point 4).

---

## 2. EA -- DAILY_SNAPSHOT (C24 + A5)

**D1. Roll detection in `OnTimer` (1 s),** from
`Grind_FtmoDayKey(TimeGMT())`. This is independent of breaker state and
of ticks, so weekend rolls are seen. Every instance detects the roll, and
exactly one emits (D2). Runs whether or not the instance is halted: a
halted instance still reports the account.

**D2. One emitter per account: a single persistent CAS variable.**
`GRIND_SNAPSHOT_CLAIM` holds the last claimed day as a number `yyyymmdd`.
To claim the new day N: read `v`; if `v >= N` someone already claimed it;
otherwise `GlobalVariableSetOnCondition(CLAIM, N, v)`, and success means
this instance claimed. Marked dirty so the C25 flush writes it.
This refines the earlier per-day name (`GRIND_SNAPSHOT_<day>`): one
variable, no growth, and a true compare-and-swap. The only race is the
very first creation (two instances both `Set(0)`); pipshed's unique key
(P1) absorbs a duplicate. (G2)

**D3. The row is for the day that ENDED (key D), emitted at the first
second of day D+1.** The claimer reads the account once and writes the
new day's start values (persistent, dirty-flushed):
`GRIND_SNAPSHOT_START_DAY`, `_START_BAL`, `_START_EQ`, `_START_PSWAP`
(the sum of `POSITION_SWAP` over all open positions).

| field | definition |
|---|---|
| `account_login` | `AccountInfoInteger(ACCOUNT_LOGIN)` (A5) |
| `ftmo_day` | D (`yyyy.mm.dd`, as `Grind_FtmoDayKey`) |
| `balance_start`, `equity_start` | stored at the previous roll, if its stored day == D |
| `balance_end`, `equity_end` | read now |
| `realised` | `balance_end - balance_start` |
| `nontrade` | sum over D's non-trade deals (`DEAL_TYPE` other than BUY/SELL: deposits, credits, adjustments). Reported, not subtracted |
| `inventory_pnl` | `(equity_end - balance_end) - (equity_start - balance_start)` |
| `total` | `equity_end - equity_start` |
| `swap_day` | sum of `DEAL_SWAP` over D's deals + (`PSWAP_now - PSWAP_start`). (G1) |
| `positions_long`, `positions_short`, `orders` | account-wide counts, all magics, read now |
| `guard_total` | the emitter's `g_grind_last_guard_total`, plus `guard_age_s` (the value is tick-driven and may be stale at a weekend roll) |
| `breaker_tripped` | `GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + D)` |
| `premidnight_seen` | `GlobalVariableCheck("GRIND_BREAKER_PREMID_" + D)` (D4) |
| `broker_utc_offset_s` | `TimeTradeServer() - TimeGMT()` at emission (F11) |
| `start_known` | true if the stored start day == D |
| `balance_start_source` | `stored` or `history` |

**Missed start.** If the stored start day is not D (first day on the
account, a restart across FTMO midnight, an outage), the row is still
emitted. `balance_start` is rebuilt from deal history exactly as the
breaker anchor is (`Grind_BreakerCollectDealHistory` over D's
boundaries); `equity_start`, `inventory_pnl`, `total` and `swap_day` are
`null`; and `start_known=false`. A multi-day outage emits only the day
just ended; earlier days are gaps. (G7)

**Emission:** `Grind_ArchiveMarker("INFO", "DAILY_SNAPSHOT", D, 0, detail)`
plus a journal `TELEM|` line, then `Grind_ArchiveFlush(true)`.

**D4. Pre-midnight halt becomes visible.** On the first false-to-true
transition in a day, if `GRIND_BREAKER_PREMID_<day>` does not exist, set
it (dirty) and archive `INFO BREAKER_PREMIDNIGHT` once. The prefix is
already covered by the clean-up script's `GRIND_BREAKER_`.

**D5. A5 in the heartbeat:** add `account_login` to the heartbeat JSON,
so the live dashboard shows which account it is reading. Cheap and
optional (previous chat); included.

---

## 3. EA -- EJECTION VISIBLE TO THE ARCHIVE (F1, F2)

**D6.** At the three emit sites, keep the journal line and also call
`Grind_ArchiveMarker`: `EJECT_ACCEPTED` INFO, `EJECT_REFUSED` INFO,
`EJECT_FILLED` INFO. `ticket` = the ENT position ticket; `detail` is
unchanged, so it still carries `source` (auto/command) where it does
today. `EJECT_FILLED` has no `source`; pipshed joins it to the latest
`EJECT_ACCEPTED` for the same ticket. No new GV.

**D7. `ejected` flag at source.** In the OUT_BY branch
(`grind_engine.mqh` ~1822-1864), compute
`const bool was_ejected = Grind_EjectIsEjected(position_ticket)` BEFORE
`Grind_QueueScalpClosedEvent`, and pass it through, so the payload
carries `"ejected":true|false`. This ordering matters: the offset is
deleted a few lines later (`Grind_EjectOffsetDelete`). The same payload
also gains `broker_utc_offset_s` (F11), because `close_time` is broker
time and `scalp_history` has no `ea_time_ms` (F10).

Refusals (previous chat): auto-eject refusals are silent by ADR-157
design, so only command refusals and failed modifies reach the archive,
and failed modifies are limited to one per side per W minutes by the
backoff.

**D8. Clean-up script:** add `GRIND_SNAPSHOT_` to
`scripts/grind_gv_clean.mq5`'s prefix list. The script is
documentation-adjacent but runs on the VPS: compile 0/0 is required.

**D9. Breaker latch read every tick (F5; ADR-158 rev 2 note).** In
`Grind_BreakerOnTick`, while not tripped, check
`GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + key)` on every tick. If it
is set, adopt the trip: set `g_grind_breaker_tripped = true`, and cancel
resting entries once through the existing `g_grind_breaker_cancel_done`
path. Do NOT emit a second `BREAKER_TRIPPED`; the instance that set the
GV already did. ADR-158 gets a one-paragraph rev 2 note recording the
fix, and a correction to section 1: "01:00 broker" holds in summer only
(F11).

---

## 4. PIPSHED

**P1. Migration `002`.**
- New table `daily_snapshots`: one column per D3 field, plus `detail
  jsonb` (raw), `received_at`, and the derived columns in P2.
  `UNIQUE (account_login, ftmo_day)`, insert `ON CONFLICT DO NOTHING`.
  **No retention.**
- `scalp_history`: add `ejected boolean NULL` (NULL = before ADR-159) and
  `broker_utc_offset_s integer NULL`. Add both to `SCALP_FIELDS`.

**P2. Worker.**
- When an `ea_event` with `code='DAILY_SNAPSHOT'` is inserted, also
  insert its row into `daily_snapshots`, in the same transaction.
- **Derived columns, built INTO the table** (because `ea_events` expire),
  hourly like the carry table. The build recomputes only the last 7 FTMO
  days; older rows are frozen. (G5) The FTMO day of an event comes from
  the EA's own UTC clock (F10), not from `received_at`, because ingest
  can lag across 22:00Z:
  `(to_timestamp(ea_time_ms / 1000.0) AT TIME ZONE 'Europe/Prague')::date`.
  For `scalp_history`, which has no `ea_time_ms`, use `close_time_broker
  - broker_utc_offset_s` for rows that carry the offset; skip older rows.
  Derived:
  - `ejections_auto`, `ejections_command` (`EJECT_ACCEPTED` by `source`);
  - `ejected_fills` and `ejected_realised` (`scalp_history` rows with
    `ejected=true`; day as above; no hard-coded broker offset anywhere);
  - `eject_filled_events` (count of `EJECT_FILLED`) as the cross-check,
    with `eject_mismatch` = `ejected_fills - eject_filled_events`;
  - `carry_clamps` (sum of `clamped` over `CARRY_PASS_*` events);
  - `critical_events` (count of level CRITICAL).
- Publish `fxmatrix:daily:table` (JSON, newest first) to Redis for the
  dashboard, as `fxmatrix:carry:table` is published.

**P3. CRITICAL banner (C19), with an amber tier (G4 ruling).** Every
60 s the worker publishes `fxmatrix:critical:last24h`: `ea_events` with
`level='CRITICAL'` (red), or `level='WARN'` AND `code IN
('STARTUP_EXIT_SHORTFALL', 'QUARANTINE_ENTER', 'WARN_API_ENTRY_STOP')`
(amber), and `received_at > now() - 24h`, grouped by (`instance_id`, `code`) with a
count, first/last times and level. Duplicates are expected (several
instances can emit the same code), so the grouping matters. The dashboard
shows a red banner while any CRITICAL row exists, otherwise an amber one
while any WARN row exists. `STRAY_L0_*` is never shown. It ages out after 24 h with no
acknowledge action (previous chat and operator stance). (G4)

**P4. Dashboard.** Add a "Daily (FTMO day)" card beside the carry table,
showing: day, account, realised, inventory, total, swap, positions L/S,
guard, breaker/pre-midnight flags, and the ejection columns. A row with
`start_known=false` shows its nulls as a dash, never as zero.

**P5. s4 counter (A2 point 4, F8).** New read-only
`scripts/s4_scalps.py` (same connection pattern as `archive_counts.py`).
Per instance per FTMO day (day from `fill_logs.ea_time_ms`, F10), it
counts CloseBy pairs from `fill_logs` as DISTINCT `order_ticket` over
`entry_type='OUT_BY'` rows (both deals of one close-by share its order;
see section 10, G6), EXCLUDING any pair in which either row's
`position_id` matches an `EJECT_FILLED.ticket`, and prints each pair's ratio to the
fleet median (s4). It also prints the `scalp_history` count with
`ejected IS NOT TRUE`, and flags any day where the two disagree.
**Proposed as canonical; operator to confirm.** It replaces the
unmerged research script (F8), which read a deals dump rather than the
archive. (G6)

---

## 5. DEPLOY ORDER

Pipshed first. Unknown codes already land in `ea_events` untouched, so
pipshed must tolerate the table being empty and old scalp payloads
without `ejected`. The EA ships at the cycle-3 attach
(`cycle3-start.md`); nothing lands mid-cycle.

---

## 6. TESTS (tests first, against stubs, with predicted failures)

EA: new assertions under a prefix that no existing test uses (`DS`),
named in full. Money logic goes in pure functions in `grind_pure.mqh`
(`Grind_SnapshotCompute`, `Grind_SnapshotClaimDecide`), with expected
values derived by hand. Cases, at minimum:
- known start -> every field;
- unknown start -> nulls + `start_known=false` + balance from history;
- CAS: already-claimed, won, lost;
- day key across the CET/CEST change (last Sunday of October);
- `broker_utc_offset_s` present in `DAILY_SNAPSHOT` and `scalp_closed`;
- `nontrade` does not change `realised`;
- `was_ejected` true and false in the `scalp_closed` payload;
- `EJECT_*` markers enqueued to the archive;
- pre-midnight GV set once, and marker emitted once;
- D9: an instance that did not see the dip adopts a GV trip mid-day,
  blocks entries, cancels once, and emits nothing.

Pipshed: `scripts/verify_daily_snapshots.py` in the existing `verify_*`
style, covering: insert + conflict; derived columns; the 7-day freeze;
the Prague DST date; the banner grouping; and `s4_scalps.py` against
fixture rows, including one ejected pair.

---

## 7. NEGATIVE SPACE

- No change to entry, exit, carry or ejection DECISIONS, except D9
  (which makes ADR-158's stated intent true). Otherwise this ADR only
  reports.
- No hard-coded broker UTC offset, in either repo.
- No USD target anywhere (A2).
- No per-instance P&L split in the snapshot. Instances share one account
  balance, so a split is attribution, not measurement.
- No acknowledge/dismiss action on the banner.
- No new retention job; `daily_snapshots` is never deleted.
- No market orders, no position closes.

---

## 8. RISKS

- **Clock:** the FTMO day comes from `TimeGMT()`. The attach checks it
  against real UTC (A2 point 8).
- **A lost claimer:** if the claiming instance's archive queue drops the
  event, that day is a gap. Accepted; the existing `ARCHIVE_DROPPED`
  marker makes the drop visible.
- **Weekend `guard_total`** is stale by construction; `guard_age_s` says
  how stale.

---

## 9. QUESTIONS FOR GEMINI

- **G1 swap_day.** In MT5, swap on an open position accrues into
  `POSITION_SWAP` and reaches the balance only as `DEAL_SWAP` at close.
  So a day's swap = the closed-deal swap booked in D + the change in the
  open-position swap sum. Is that correct, and worth the extra stored
  value, or is closed-deal swap alone enough? (The previous chat agrees
  it is worth it: cycle 3 turns carry on, and swap is an A2 measure.)
- **G2 claim.** Is a single CAS variable acceptable, given the
  first-creation race absorbed by the DB unique key? Or do you want a
  lock around creation (the MAE claim-lock pattern)?
- **G3 breaker latch (D9).** The previous chat confirms F5 is a spec
  bug. Confirm D9: adopt the GV trip on the next tick, cancel resting
  entries once, and no second event. Is a per-tick `GlobalVariableCheck`
  cheap enough, or do you want it throttled?
- **G4 banner scope.** CRITICAL already covers `STARTUP_EXIT_SHORTFALL_SIDE`
  (F6). Is that enough? Or add an amber tier from an allow-list of WARN
  codes: `STARTUP_EXIT_SHORTFALL`, `QUARANTINE_ENTER`,
  `WARN_API_ENTRY_STOP` (not the noisy `STRAY_L0_*`)?
- **G5 freeze.** Recompute derived columns for the last 7 FTMO days, then
  freeze. Is that right, given 90-day event retention and late archive
  delivery?
- **G6 s4 join.** A CloseBy produces an OUT_BY deal on each of the two
  positions. Is matching `fill_logs.position_id` to the ENT position
  ticket (= `EJECT_FILLED.ticket`) sufficient to exclude the pair, and is
  counting one OUT_BY per pair by `role` the right dedupe? Cursor must
  verify the `role` values in `fill_logs`.
- **G7 multi-day outage.** Emit only the day just ended (proposed), or
  back-fill earlier days' realised from deal history with null
  equity-side fields?
- **G8 anything this ADR changes that an invariant reads.** None
  intended: new GVs are reporting-only and not read by reconstruction.
  Please confirm from the reconstruction code rather than from this
  statement.

---

## 10. RULINGS (Gemini, 2026-09-23) AND OUR VERIFICATION

Gemini's reply carried no line-count footer. His verdicts are adopted.
Where his stated REASON does not match this codebase, that is recorded
here, so the ruling is not later defended on the wrong grounds.

- **G1 swap: ACCEPTED as designed.** Closed-deal swap plus the change in
  open `POSITION_SWAP`. Reason sound.
- **G2 claim: ACCEPTED.** Single CAS variable; the first-creation race is
  absorbed by the DB unique key. Reason sound.
- **G3 / D9 latch: ACCEPTED, per tick, not throttled.** Verified: in
  `OnTick`, `Grind_BreakerOnTick` runs before `Grind_OnTickEngine` and
  before the halted return (`fxgrind.mq5` ~307-333). So a latch adopted
  on a tick blocks that same tick's entries.
- **G4 banner: ACCEPTED, amber tier added (P3).** His reason is wrong in
  its detail: neither code means "halted". `QUARANTINE_ENTER` precedes a
  possible halt, and `STARTUP_EXIT_SHORTFALL` means the EA placed the
  missing exits and carried on (ADR-156). The verdict stands on a
  different ground: both are states the operator should know about
  within 24 h. He named two codes; `WARN_API_ENTRY_STOP` stays on the
  list as proposed (it stops entries account-wide) unless he objects.
- **G5 7-day window: ACCEPTED.**
- **G6 s4 dedupe: verdict ACCEPTED, mechanism specified here.** He said
  to group "by the CloseBy match" without saying how. `fill_logs` has no
  comment column, and its `role` is parsed from `DEAL_COMMENT`
  (`grind_archive.mqh` ~415-422). The research script identifies CloseBy
  deals by a `#` comment, which `GrindCommentParse` very likely rejects,
  leaving `role` null on both OUT_BY rows (INFERRED). So P5 dedupes by
  DISTINCT `order_ticket`, because both deals of one close-by share its
  order (MT5 semantics, INFERRED). **Cursor verifies both on real
  archive rows before building:** OUT_BY rows exist in `fill_logs` (they
  pass the magic filter in `Grind_ArchiveRecordFill`), they come in
  pairs per `order_ticket`, and their `role` values.
- **G7 outage: ACCEPTED -- the day just ended only, no back-fill.** Note:
  his reasoning ("rows with null primary metrics break aggregations")
  would, if applied, also drop D3's missed-START rows (e.g. a restart
  across FTMO midnight). Those rows STAY, as agreed with the previous
  chat: a row with honest unknowns beats a silent gap. The dashboard
  shows a dash, and any aggregation skips `start_known=false`.
- **G8 invariants: verdict CONFIRMED by us, not by his reasoning.** He
  cites `Grind_GridReconstruct`, which does not exist in the repo. Our
  check: the only EA code that enumerates GVs by prefix is the carry
  prune (`grind_carry.mqh` ~936-941: `GRIND_CARRY_SHIFT_`,
  `GRIND_CARRY_RELEASE_`), and `grind_recon.mqh` reads no GV directly.
  `GRIND_SNAPSHOT_*` and `GRIND_BREAKER_PREMID_*` match neither prefix,
  and no invariant reads them.

---

## 11. IMPLEMENTATION RECORD (2026-09-23)

**Pipshed** (P1-P5): spec `prompts/adr159_pipshed.md` (`b81a339`) and fix 1
(`93b1611`), merged `e475506`; migration `002` applied from inside
Railway (`railway ssh --service archive-worker python db_migrate.py`,
because Postgres has no public network). Verify script 17/17. Fix 1: DS11
did not guard the broker offset (proved by mutation); swallowed build
errors now roll the connection back (including the pre-existing
`try_carry_build`). `s4_scalps.py --probe` confirmed G6 on the archive
itself: every CloseBy `order_ticket` has exactly two OUT_BY rows, `role`
null. Archive vs broker dump: exact every FTMO day from 18 Sep; 16-17 Sep
short by 3 and 4 scalps (backlog C34).

**EA** (D1-D9, C29): spec `prompts/cursor_adr159_ea.md` (`40e8517`),
fixes 1 (`26ac32c`) and 2 (`8a07157`), merged `1c4a549`. Stub checks
matched their predictions by name each time. Found on the way:
- SN1's `swap_day` expected 0.00, so a stub could pass it: SN15 added.
- C29 grew the fleet table to 18, which broke four fixtures that encoded
  the 16-magic fleet (CM2, CL1-CL2 helper, CL4, RX3): updated with
  hand-derived sums (fix 1). No production effect: the cap is disabled.
- DeepSeek R1 audit (`prompts/deepseek_adr159_audit_response.md`),
  verified in source: T-4 (start values keyed by day only) and T-5
  (silent zeros when history fails) ACCEPTED and fixed in fix 2
  (`GRIND_SNAPSHOT_START_LOGIN`; `history_ok` with nulls). T-1 no-basis
  REJECTED (the day key is set before the return; adoption is one tick
  late); T-1 enable switch BY DESIGN (preset check, backlog C35); T-3
  REJECTED (archive `WebRequest` timeout is 200 ms, not 5000); T-6
  REJECTED (queue 5000, eject events are few).

**Contract note:** the `DAILY_SNAPSHOT` JSON carries a 22nd key,
`history_ok`, after `balance_start_source`. Pipshed keeps it in `detail`;
it is not a column.

Line count: 403
