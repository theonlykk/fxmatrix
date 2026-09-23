This message has a line count at the bottom

# ADR-159 -- DAILY SNAPSHOT, CRITICAL BANNER, ACCOUNT IDENTITY, EJECTED-FILL EXCLUSION (C24 + C19 + A5 + A2 point 4)

**Status:** DRAFT rev 0, 2026-09-23, for Gemini. Spans two repos (fxmatrix
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
| F5 | **Breaker latch read only at a day-key change.** `GRIND_BREAKER_TRIPPED_<day>` is read at `:934` only when the key changes. An instance that did not itself see equity under the trip keeps entering after another instance tripped, if equity recovers first. ADR-158 decision 4 says "all instances agree" | `grind_engine.mqh:906-935,940-952` | G3 |
| F6 | C19's own example (`STARTUP_EXIT_SHORTFALL`) is archived at level WARN, so a CRITICAL-only banner will not show it | `fxgrind.mq5:183` | G4 |
| F7 | Breaker day logic runs only in `OnTick`. There are no ticks at weekends, so a roll detector there misses Saturday and Sunday | `fxgrind.mq5:312` | D1 uses `OnTimer` |
| F8 | No canonical s4 scalp counter exists. `archive_counts.py` has no scalp mode; A2 says only "the deals, via the archive" | pipshed `scripts/archive_counts.py` | P4, operator to confirm |
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
deleted a few lines later (`Grind_EjectOffsetDelete`).

**D8. Clean-up script:** add `GRIND_SNAPSHOT_` to
`scripts/grind_gv_clean.mq5`'s prefix list. The script is
documentation-adjacent but runs on the VPS: compile 0/0 is required.

---

## 4. PIPSHED

**P1. Migration `002`.**
- New table `daily_snapshots`: one column per D3 field, plus `detail
  jsonb` (raw), `received_at`, and the derived columns in P2.
  `UNIQUE (account_login, ftmo_day)`, insert `ON CONFLICT DO NOTHING`.
  **No retention.**
- `scalp_history`: add `ejected boolean NULL` (NULL = before ADR-159).
  Add `ejected` to `SCALP_FIELDS`.

**P2. Worker.**
- When an `ea_event` with `code='DAILY_SNAPSHOT'` is inserted, also
  insert its row into `daily_snapshots`, in the same transaction.
- **Derived columns, built INTO the table** (because `ea_events` expire),
  hourly like the carry table. The build recomputes only the last 7 FTMO
  days; older rows are frozen. (G5) The FTMO day of an event is
  `(received_at AT TIME ZONE 'Europe/Prague')::date`. Derived:
  - `ejections_auto`, `ejections_command` (`EJECT_ACCEPTED` by `source`);
  - `ejected_fills` and `ejected_realised` (`scalp_history` rows with
    `ejected=true`, by FTMO day of `close_time_broker`, where broker time
    = UTC+3 -- INFERRED from ADR-158 section 1, so Cursor verifies it);
  - `eject_filled_events` (count of `EJECT_FILLED`) as the cross-check,
    with `eject_mismatch` = `ejected_fills - eject_filled_events`;
  - `carry_clamps` (sum of `clamped` over `CARRY_PASS_*` events);
  - `critical_events` (count of level CRITICAL).
- Publish `fxmatrix:daily:table` (JSON, newest first) to Redis for the
  dashboard, as `fxmatrix:carry:table` is published.

**P3. CRITICAL banner (C19).** Every 60 s the worker publishes
`fxmatrix:critical:last24h`: `ea_events` with `level='CRITICAL'` and
`received_at > now() - 24h`, grouped by (`instance_id`, `code`) with a
count and first/last times. Duplicates are expected (each instance trips
the breaker itself), so the grouping matters. The dashboard shows a red
banner while the list is non-empty. It ages out after 24 h with no
acknowledge action (previous chat and operator stance). (G4)

**P4. Dashboard.** Add a "Daily (FTMO day)" card beside the carry table,
showing: day, account, realised, inventory, total, swap, positions L/S,
guard, breaker/pre-midnight flags, and the ejection columns. A row with
`start_known=false` shows its nulls as a dash, never as zero.

**P5. s4 counter (A2 point 4, F8).** New read-only
`scripts/s4_scalps.py` (same connection pattern as `archive_counts.py`).
Per instance per FTMO day, it counts CloseBy pairs from `fill_logs`
(`entry_type='OUT_BY'`, one per pair), EXCLUDING any `position_id` that
matches an `EJECT_FILLED.ticket`, and prints each pair's ratio to the
fleet median (s4). It also prints the `scalp_history` count with
`ejected IS NOT TRUE`, and flags any day where the two disagree.
**Proposed as canonical; operator to confirm.** (G6)

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
- `nontrade` does not change `realised`;
- `was_ejected` true and false in the `scalp_closed` payload;
- `EJECT_*` markers enqueued to the archive;
- pre-midnight GV set once, and marker emitted once;
- (if G3 is accepted) the latch is read mid-day.

Pipshed: `scripts/verify_daily_snapshots.py` in the existing `verify_*`
style, covering: insert + conflict; derived columns; the 7-day freeze;
the Prague DST date; the banner grouping; and `s4_scalps.py` against
fixture rows, including one ejected pair.

---

## 7. NEGATIVE SPACE

- No change to entry, exit, carry or ejection DECISIONS (G3 excepted, if
  accepted). This ADR only reports.
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
  value, or is closed-deal swap alone enough?
- **G2 claim.** Is a single CAS variable acceptable, given the
  first-creation race absorbed by the DB unique key? Or do you want a
  lock around creation (the MAE claim-lock pattern)?
- **G3 breaker latch (F5).** Read `GRIND_BREAKER_TRIPPED_<key>` on every
  tick while not tripped: one `GlobalVariableCheck`, with no emit on a
  latch inherited from another instance. Fold it into ADR-159 (it gates
  the same cycle and is about ten lines plus a test), or make it its own
  ADR-158 rev 2?
- **G4 banner scope.** CRITICAL only, as C19 says? Or CRITICAL (red) plus
  an allow-list of WARN codes (amber): `STARTUP_EXIT_SHORTFALL`,
  `QUARANTINE_ENTER`, `WARN_API_ENTRY_STOP`? Not the noisy
  `STRAY_L0_*`.
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

Line count: 278
