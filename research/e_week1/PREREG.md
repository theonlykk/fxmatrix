This message has a line count at the bottom

# FLEET E's FIRST WEEK -- PRE-REGISTRATION (25 Oct 2026 ~18:30Z; before the week is read)

| | |
|---|---|
| Status | **PRE-REGISTERED 25 Oct ~19:10Z, AMENDED by Argon's review** (`reviews/argon_review_e_week1.md` on `review/argon-e-week1`, `ba6a36a`: SOUND WITH CHANGES; 515 quotes exact; the changes applied below, `rho` not taken: S / A is reported). Before the week's read. |
| Why | C162 (OPEN): E's live weeks on `_t3` against D's `_t1`, the out-of-sample test of sweep11. C164: E's worst FTMO-day loss against $300 (Instant) and $500 (the trial). The operator (24 Oct): "we are yet to have a trial run that hasnt had a terrible drawdown"; "anchor on the actual episode". |
| What follows | **Nothing automatically.** E is not changed except for a defect (E's runbook s10; the operator 25 Oct: "E stays as it is"); a reload of E, and stepping in near $500, are the operator's rulings, not this read's. The read informs them. |
| Already seen | E's first FTMO day (Fri 23 Oct): realised +$50.84, equity 9,997.17 at the close, book 18 long / 27 short, deepest 4 (HANDOFF s89 continued 2, s90). Disclosed; nothing else of the week read. |

## 1. ONE WORKED EXAMPLE (FTMO's daily loss, in prices and dollars)

A day starts with balance $10,050 and equity $9,997 (the stacks open at -$53). AUDCAD falls 40 pips through the
morning: OPT's long stack fills and rolls, the open book reaches -$300; meanwhile the other pairs bank +$20 of scalps.
At the low, balance $10,070, equity $9,770. **FTMO's daily loss = day-start balance - the day's lowest equity =
$10,050 - $9,770 = $280**, though the day's closed P&L was +$20: $53 of it was carried in from earlier days
(02_TRAPS 24 Oct day). Under Instant's $300 by $20; under the trial's $500.

## 2. THE WINDOW AND THE DAYS

- **Window W:** from E's first fill, **Fri 23 Oct 03:29:01Z**, to the end of **Fri 30 Oct's session** (the last
  state snapshot before 21:05Z). If FTMO ends the trial earlier, W ends at the breach.
- **FTMO days** (Prague midnight): 23 Oct = Thu 22:00Z - Fri 22:00Z; 24 Oct = Fri 22:00Z - Sat 22:00Z; **25 Oct =
  Sat 22:00Z - Sun 23:00Z (25 hours: Prague leaves summer time at 01:00Z; this day holds Sunday's open, ~21:00Z)**;
  26-30 Oct = 23:00Z - 23:00Z (30 Oct's day ends after W). Weekend days count (a carried loss counts on them too). The
  brokers' midnight (21:00Z) is unchanged until 1 Nov.
- **Trading days** (for rates): 0.73 on 23 Oct (03:29Z - 21:00Z) + 5 (Mon 26 - Fri 30) = **5.73**.

## 3. INPUTS (read-only; nothing re-run)

- **pipshed's archive** (Railway Postgres; desktop `D:\pipshed`, `railway ssh --service archive-worker`), exported to
  `D:\fxmatrix-exports\e_week1\` after Fri 30 Oct ~21:10Z, hashed (sha256) before any number is computed:
  - `scripts/archive_counts.py --export-snapshots --from 2026-10-23T03:00Z --to 2026-10-30T21:30Z --csv`: one row
    per instance per minute (net_mtm, layers per side, api_count, halted, quarantined). **Balance and equity are the
    account's and are filled on ONE reporter instance per account only** (`grind_mae.mqh` 314-326; the others null):
    the account rows are the non-null ones per `account_login` (E 1515045375, D 53077984); other fleets' rows dropped.
  - `scripts/archive_counts.py --export-archive --instance <id>` for E's twelve (`GRIND_<PAIR>_{OPT,ALT}E`) and D's
    twelve (`GRIND_<PAIR>_{OPT,ALT}D`): fill_logs (profit, swap, commission per deal), scalp_history, ea_events
    (`ROLL_ACCEPTED`, `ROLL_*`), config_events.
  - **Clocks:** `state_snapshots.snapped_at` (UTC); `fill_logs.deal_time_broker` is server time, UTC = it - 3 h this
    week (GMT+3 until 1 Nov); `scalp_history.close_time_broker` - `broker_utc_offset_s`; `ea_events` by `received_at`.
- **FTMO's own objectives page** for 1515045375 (the operator reads it once after the close): its "max daily loss"
  and "max loss" figures are the authority; ours explains them.
- **The replay's committed counts** (s8): `research/t3_drawdown/t3dd_output.txt` (October 1-20, 14 trading days),
  `research/t3_drawdown/calm_comm_output.txt` (calm, 8 weeks = 40 trading days).

## 4. SELF-CHECKS FIRST (any failure: STOP, record it, amend before any measure is read)

1. **Balance reconciles:** $10,000.00 + the sum over E's deals in W of (profit + swap + commission) equals E's last
   reporter balance in W within $0.05. D: its first reporter balance in W + D's deals between that snapshot and its
   last one in W = its last reporter balance, within $0.05. Any non-trade balance entry is listed, not netted.
2. **Minute coverage:** E's account has a snapshot in at least 95% of W's session minutes; every gap over 5 minutes
   listed (a gap can hide the day's low).
3. **Instances:** E's twelve and D's twelve present; config_events show no attach after 23 Oct 03:25Z on E (none
   expected) and none on D after 21 Oct 15:54Z.
4. **Counts agree:** per E instance, scalp_history rows equal the exit fills in fill_logs (`entry_type` IN and role
   EXT: the close-by deal itself carries the broker's comment, so its role is null) within 2.

## 5. MEASURES (E; D the same where marked D)

- **M1 FTMO daily loss per FTMO day** (s1's formula on minute marks; the minute marks under-read the true low, so M1
  is a lower bound; FTMO's page decides): the worst, its day and minute, and the days over $300 and over $500.
- **Day-start balance:** 23 Oct $10,000.00; each later FTMO day, the reporter's last balance before that day's Prague
  midnight (the market is shut then; `daily_snapshots.balance_start` where `start_known`, as a cross-check).
- **M2 Max loss:** E's lowest equity in W against FTMO's $9,000 floor (trial, static 10%); and against Instant's
  trailing floor at each minute (the highest balance so far - $1,000), reported, not deciding.
- **M3 Money (E and D):** the change in equity over W (primary: realised + the change in the open book, swaps and
  commission in); realised; commission (as a cost, > 0); gross = realised + commission; commission / gross (n/a if
  gross <= 0). **Per pair and cell:** realised from fill_logs + the change in that instance's net_mtm over W (equity is
  account-wide). D also at FTMO's $0.06 a close instead of IC's $0.08 (`sr_table.py` 27-34), and D's realised split
  between positions opened before W and inside W.
- **M4 Per cell (pair x arm; E and D):** closes not rolled S and rolled closes R (`scalp_history.rolled`), roll steps A
  (the `ROLL_ACCEPTED` events, `grind_engine.mqh` 1093), realised net; **closes per trading day = (S + R) / 5.73**;
  scalps per roll step S / A (n/a if A = 0).
- **M5 Requests:** E's highest `api_count` per server day against FTMO's 2,000 (C106).
- **M6 For Instant and the guard (reported):** the best FTMO day's share of W's closed profit (Instant's consistency
  rule, 30% or 50%: C164); E's peak open positions (the layers summed per minute) against the guard's 194.

## 6. THE EPISODE (the operator: anchor on the actual episode, not on a fixed window)

Let O(t) = equity - balance (E's open book) at each minute. **The episode** runs around the earliest minute of W's
lowest O: from the last minute before it with O >= -$50 (or W's start) to the first minute after it with O >= -$50 (or
W's end). If W's lowest O is above -$100 there is no episode; say so. (Anchored on O, not equity: banked scalps lift
the balance, so the lowest equity can sit early in W while the deepest open book comes later.) M1's worst minute is
reported beside it. For the episode: its span; M1 for each FTMO day it touches; per cell the open P&L
(net_mtm) and layers at the low; S, R and A inside it; which pairs and arms carried the loss. **This is read first.**

## 7. THE THREE QUESTIONS AND HOW EACH IS READ

**Q1 (FTMO; C164).** **TRIAL-SAFE** if M1 < $500 on every day, M2 above $9,000 and M5 below 2,000 every day;
**INSTANT-FIT** if also M1 <= $300 on every day. Where FTMO's page gives a day's loss, it replaces M1 for that day.
Otherwise the day and the episode that broke it.

**Q2 (does live trade like the replay?).** Per cell, the live closes per trading day against the band **[0.5 x the
lower, 1.5 x the higher]** of the replay's calm and October rates (s8; inclusive, both rounded to 2 decimals).
**CONSISTENT** if at least 9 of the 12 cells fall inside; else **NOT CONSISTENT**: the replay misreads live activity, and changes built on it (C's cap 9 among them)
are flagged before the next one.

**Q3 (t3 against t1; C162).** E's M3 equity change against D's over W, in total and per pair. **Reported, not
decided:** one week is one draw; C162 stays OPEN. Read beside it: the brokers differ (FTMO against IC: spreads,
commission per close, fills), and D entered W holding its 21 Oct book while E started flat.

## 8. THE REPLAY's RATES (closes S + R per trading day at 0.01 lots, cap 7; from s3's files; the bands of Q2; computed by script)

| cell | calm | October | band | | cell | calm | October | band |
|---|---|---|---|---|---|---|---|---|
| GBPUSD OPT 9 | 16.62 | 23.14 | 8.31-34.71 | | GBPUSD ALT 15 | 5.75 | 8.29 | 2.88-12.43 |
| EURUSD OPT 7 | 16.27 | 35.00 | 8.14-52.50 | | EURUSD ALT 23 | 1.52 | 4.07 | 0.76-6.11 |
| EURGBP OPT 5 | 5.95 | n/a | 2.98-8.93 | | EURGBP ALT 23 | 0.12 | 0.71 | 0.06-1.07 |
| AUDCAD OPT 18 | 2.58 | 3.36 | 1.29-5.04 | | AUDCAD ALT 26 | 1.10 | 1.57 | 0.55-2.36 |
| AUDCHF OPT 14 | 1.55 | 3.21 | 0.78-4.82 | | AUDCHF ALT 20 | 0.80 | 1.64 | 0.40-2.46 |
| CADCHF OPT 10 | 2.70 | 4.64 | 1.35-6.96 | | CADCHF ALT 17 | 0.78 | 1.86 | 0.39-2.79 |

Calm = (S + R) / 40 (`calm_comm_output.txt`); October = closes / 14 (`t3dd_output.txt`, closes = commission / $0.06).
EURGBP OPT 5's October count at cap 7 is not committed (its run sits outside git): its band uses calm only (disclosed).

## 9. CLAUDE's PREDICTIONS (before the week is read)

1. Q1: TRIAL-SAFE, not INSTANT-FIT (at least one FTMO day over $300; none over $500).
2. Q2: CONSISTENT (at least 9 of 12 cells in band).
3. M3: commission / gross for E between 38% and 84% (the replay's calm and October).
4. Q3: E's equity change over W above D's.

## 10. LIMITS

Minute marks under-read intraday lows (FTMO's page is the authority). One week; one draw per pair. The replay's rates
come from 0.01 lots on one instance per pair and arm (the live fleets are the same). E's first day is already seen
(header). Reported per cell, not only as a fleet. Amendments, if any, are committed before any measure is read.

## 11. AFTER THE READ

`research/e_week1/results.md` (the episode first, then Q1-Q3, the predictions scored); the script `read.py` with its
tests committed first (against a stub, hand values), before the exports are opened.

Line count: 136
