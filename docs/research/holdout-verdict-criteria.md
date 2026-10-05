This message has a line count at the bottom

# HOLDOUT VERDICT CRITERIA -- DOES THE GRID HAVE AN EDGE? (6-9 OCT)

| | |
|---|---|
| Status | **ACCEPTED 5 Oct ~18:30Z** (Claude's draft 5 Oct ~04:20Z, T4 and K8 ~14:05Z; Gemini GH-1..GH-6 and Claude's check s10; the operator: "equity matters the most", "the more days we test the better"). Fixed BEFORE the window opens (5 Oct 22:00Z). Nothing below changes except by a dated amendment (s8) written before the scoring run |
| Origin | Operator, 5 Oct ~04:13Z: "is this whole effort going to end in disappointment?"; Claude proposed fixing in advance what result counts as "it works" and what counts as "it doesn't", so the verdict comes from the data and not from a bad night; operator: "proceed" |
| Builds on | `docs/research/markout-variance-study.md` (first pass, s4-s6); `docs/runbooks/compass-round.md` s1 (realised all-in P&L); backlog C124 (FTMO pass probability), C103, C84 |
| Decides | Whether the grid makes money on unseen days: FTMO's equity, day by day (s2 V). The markout tests (T1, T2, T4) and IC's money (T3) are reported, never deciding. Not a geometry ruling; not a compass verdict |

## 0. AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| K1 | The first pass used FTMO minute bars to 3 Oct 07:30 server (= the Friday close) and fills from `archive_2026-10-02.jsonl`: **1-2 Oct are IN its sample.** The study's s6 "re-run on 1-7 Oct (C84's window)" would score on days it was fitted on. C84's 1-7 Oct holdout is for the ejection replay (frozen 30 Sep) and stays as it is | study header table (Data row), s6; backlog C84 | VERIFIED (docs) |
| K2 | The predicted groups, as written before this document: "GBPUSD, EURGBP, NZDCAD revert; AUDCHF, NZDCHF, AUDCAD trended at the hour" | HANDOFF s56; study s4.2 | VERIFIED |
| K3 | First-pass values: 1-hour markout +0.7 / +0.3 / +0.1 (reverting group), -2.4 / -1.6 / -1.0 (trending group); 4-hour L0 -5.0, depth 6-7 +2.2, depth 8+ +2.5; naive se 0.1-0.3 pips at 1 h, 0.5-0.7 at 4 h, too small by perhaps 2-3x (fills not independent) | study s4.1, s4.2, s5 | VERIFIED |
| K4 | `research/markout/markout.py <bidask folder> <archive export>` scores every ENT layer opened after the first bar + 1 h; a horizon that lands in a closed market takes the next bar within 3 days, else drops (the first pass ended at the Friday close too, so Friday-afternoon fills are treated alike) | `markout.py` 1-40 | VERIFIED |
| K5 | `compass_score.load(paths, accounts)` and `side_metrics(layers, inst, side, windows, cutoff)` give realised all-in net (profit + swap + commission, scalps + rolls + ejections) per instance and side by close time over given windows; `load` takes any account list (FTMO 1514731800 included) | `research/compass/compass_score.py` 67-74, 104-137 | VERIFIED |
| K6 | Inside the window: the Monday build on B, C, D (after 22:00Z Mon 5 Oct: re-roll ON, twins retired), then this week's compass reloads (tight widths, round 2 and 3 probes; cap stays 8: operator 5 Oct ~18:15Z); FTMO (A) changes nothing (frozen cycle), which is why A decides (GH-3) | monday-build s1; operator | VERIFIED (runbooks) |
| K7 | Before this was written, two status reads fell inside the window (00:35Z and 02:52Z Mon 5 Oct: open MTM; the EUR longs down). No markout and no realised P&L of the window was computed | HANDOFF s54, s56; this chat | VERIFIED |
| K8 | The first pass's "depth 1 = L0" row counts fills onto a side holding no other layer (`markout.py`: "Depth = the side's open layers at the fill, itself included"), not the EA's L0 label; a roll moves an exit and is never a fill. Split 5 Oct ~14:00Z on the SAME first-pass sample (a scratch copy of `markout.py` with one added count; the repo file unchanged; the 463 / -2.3 / -5.0 reproduced): 429 of the 463 had layers open on the OTHER side (the counter-side entry, re-centred to mid +/- W after 4 pips of drift, K6 of cap10-reload), 34 a flat book. Counter-side 4-hour markout -5.6 (se 0.7; other side 1-3 layers -3.4, 4-7 -5.3, 8+ -6.9); flat book +3.1 (se 3.1, n 34); IC counter-side before the 2 Oct 03:05Z S = W + 1 change -5.9 (n 349), after -6.8 (n 62) | this document s2 T4 | MEASURED (in-sample) |

## 1. THE WINDOW

- **FTMO days Tue 6 - Fri 9 Oct:** 5 Oct 22:00Z to 9 Oct 21:00Z (Friday
  ends at the close, ~20:57Z). Four days (GH-2: Monday's open MTM had
  been seen, K7; it also held the GBPUSD halt of 13:41-13:52Z).
- **Extension, once (s3):** FTMO days Mon 12 - Fri 16 Oct, 11 Oct 22:00Z
  to 16 Oct 21:00Z; then all nine days pooled.
- **Why not 1-7 Oct:** K1.

## 2. THE TESTS

**V -- the verdict: FTMO's equity, day by day (decides).** For each FTMO
day of the window (22:00Z-22:00Z): dE = realised (profit + swap +
commission by deal time) + change in open MTM (longs at the minute bid,
shorts at the ask, USD at the minute mid), from FTMO's deal history and
minute bars (`research/ftmo_pass/ftmo_days.build_days`, unchanged; C124
checked it against the account to $3-8). The DAY is the unit (GH-1:
fills are not independent); the mean daily dE is resampled by day
(20,000 resamples, seed 1, `research/holdout/holdout_verdict.py`).
Equity counts open losses (GH-4); FTMO is the fleet whose structure does
not change this week (GH-3). Measured on 24 Sep - 2 Oct for scale (C124,
in-sample): A's seven ring pairs +$9 a day, A with eleven instances
+$15, the ring7 pool of all four fleets +$5 (se $10).

The tests below are REPORTED beside V, never deciding (operator 5 Oct
~18:05Z: the hour is a proxy; entry questions stay where C103 ruled).
Each markout figure is given with its own day-bootstrap interval (GH-1).

All four fleets' fills; FTMO's mid for markouts (as the first pass);
`markout.py` and `vr.py` UNCHANGED (the commit they are at when this is
accepted). "Group" = the three pairs of K2, pooled over fills.

**T1 -- the pair ranking (markout, 1 hour; reported).** D1 = mean 1-hour
markout of the reverting group's fills minus the trending group's.
First pass: about +2.0 (unweighted over the pairs; pooled by fill +1.97,
day-bootstrap 2.5% bound -0.28: suggestive, not proven). Reported with the
nine
pairs' 1-hour markouts, and the rank correlation of first-pass VR(60)
with holdout 1-hour markout over the nine.

**T2 -- depth (markout, 4 hours; reported).**
D2 = mean 4-hour markout at depth 6+ minus at depth 1 (an empty-side
fill, K8; not the EA's L0 label). First pass:
about +7.

**T4 -- the counter-side entry (markout, 1 and 4 hours; reported).**
The operator's reading (5 Oct ~04:35Z): once one side is a few layers
deep, bringing the other side's entry close to the market acts like a
momentum strategy on our own trades, when it matters most. Measured on
depth-1 fills whose OTHER side holds >= 1 layer (K8). First pass: 1 h
-2.4, 4 h -5.6 (n 429): the bounce that fills it kept going, the same
reversion that pays the deep side (depth 8+ +2.5 at 4 h); the first
pass predicts a negative 4-hour markout again (GH-6: the fill's markout
is the test of the entry). Reported beside it: the same by the
other side's depth (1-3, 4-7, 8+), by fleet, and the realised net of
the counter side's layers opened inside the window (a markout is one
fill; the counter side then grids on, and its own deeper layers may
pay). This week's tighter widths bring that entry closer: compare.

**T3 -- the money by pair group and fleet (reported).**
Realised all-in net (K5) of the reverting group's instances, both
sides, closed inside the window, per fleet (A runs all three; B, C, D
run all three).
- **T3a:** the reverting group's realised net per fleet.
- **T3b (reported, not deciding):** per instance per day, reverting
  group minus trending group, on B, C and D (A runs only AUDCHF of the
  trending group).
- **T3c: total = realised + change in open MTM**, the reverting group
  summed over A, B, C, D, open MTM marked at the MID at 22:30Z Mon 5 Oct
  and 20:45Z Fri 9 Oct (outside the rollover spreads), realised over the
  same span (`research/holdout/holdout_t3.py`).

## 3. THE VERDICT

| Verdict | Rule (V: FTMO's daily equity change over the window's days) |
|---|---|
| **SUPPORTED** | the 2.5% day-bootstrap bound of the mean daily change > 0 |
| **NOT SUPPORTED** | the total change over the window <= 0 |
| **INCONCLUSIVE** | anything else: extend once (s1), decide on all days pooled by the same rule; INCONCLUSIVE again = NOT SUPPORTED (GH-5) |

How strict this is, measured before the window (C124's FTMO days, 24 Sep
- 2 Oct: mean +$15 a day, sd $59, one -$119 day): if those days repeated,
400 simulated runs of four days plus the extension give SUPPORTED 57%,
NOT SUPPORTED 43%. A real but modest edge can fail this test: NOT
SUPPORTED means "not shown in nine days", not "disproved".

## 4. WHAT EACH VERDICT LEADS TO (proposals; the operator decides)

- **SUPPORTED:** C124 (pass probability) re-run with the window's days;
  the T1 pair ranking to Gemini as a candidate screen for rings and
  scouts; any answer to BMO is built on V's numbers.
- **NOT SUPPORTED:** no new challenge fee, no real money, no BMO trial of
  the method as it stands. The lab may keep running only for a NEW
  pre-registered hypothesis (e.g. from T2: a different first layer),
  written like this one before its data.
- **INCONCLUSIVE:** extend ONCE, to FTMO days 12-16 Oct (s1), the same
  rule on the nine days pooled. Inconclusive after the extension counts
  as NOT SUPPORTED: no third week.

## 5. SCORING (after the Friday 9 Oct close; Saturday 10 Oct)

1. FTMO minute bars: `grind_bidask_dump` on the desktop FTMO terminal
   (read-only), `InpFrom` = `2026.10.05 00:00` (server; = 4 Oct 21:00Z),
   `InpTo` empty, into Downloads as `bidask_ftmo_2026-10-09\`; and FTMO's
   deal history (`grind_history_dump.mq5`, the same terminal, read-only)
   into Downloads as `history_1514731800.csv` (V).
2. IC minute bars for T3c's marks: the same on wine-c, `InpFrom` the
   same, scp to Downloads (`bidask_ic_1009\`).
3. The archive export (`archive_counts.py --export-archive`) for T1 and
   T2, and the study export (`--export-study --days 14`) for T3.
4. Claude runs `holdout_verdict.py` (V; tests first V1-V6),
   `markout.py` (T1, T2, T4) and `holdout_t3.py` (T3; tests first H1-H5),
   each unchanged from the commit at which this document was accepted.
5. One results section appended here (s7): every number, the verdict,
   the commit hashes and files used. Gemini sees the result after it is
   computed, not before.

## 6. NEGATIVE SPACE

- No markout, VR or realised P&L of the window is computed before the
  Friday close (status reads for safety continue as normal).
- No change to the groups, thresholds, window or verdict table after
  acceptance, except a dated amendment in s8 written before the scoring
  run, with its reason.
- No change to `markout.py`, `vr.py` or `compass_score.py` for this.
- The verdict is not reinterpreted afterwards ("it would have passed
  without EUR"): a reading of that kind is a new hypothesis for a new
  window.

## 7. RESULTS

(empty until Saturday 10 Oct)

## 8. AMENDMENTS

- **5 Oct ~17:55Z (method, before any window data):** T3 reads the
  ARCHIVE export (`--export-archive`), not the 14-day study export (s5.3):
  a layer opened more than 14 days before the window has no open price
  in a 14-day export and could not be marked for T3c. The driver is
  `research/holdout/holdout_t3.py` (tests first, H1-H5).
- **5 Oct ~18:30Z (after Gemini, before the window):** the verdict moved
  from T1 + T3 to V (FTMO's daily equity, day-bootstrap); the window to
  Tue 6 - Fri 9 Oct; T1, T2, T3, T4 reported only (s10).
- **5 Oct ~21:05Z (a slip from GH-2, before the window opened):** T3
  follows the window: T3c's first mark is 22:30Z Mon 5 Oct (was Sun 4
  Oct) and `holdout_t3.py` `WINDOW` / `MARKS` start 5 Oct 22:00Z / 22:30Z,
  four days (were 4 Oct, five). The 18:30Z amendment moved V's window but
  not T3's. Tests pass windows explicitly (H1-H5 unchanged, 5/5).

## 9. FOR GEMINI (attack the premises; say which fact is missing)

- **GH-1. Thresholds.** T1 at +1.0 pip and T2 at +2.0 with fills that
  are not independent (K3). Too loose, too tight, or should a
  block-bootstrap interval by day replace a fixed number?
- **GH-2. The window had started** (K7: two status reads of open MTM).
  Start at Tue 6 Oct instead (four days), or keep five days with K7
  declared?
- **GH-3. Structural changes on B, C, D inside the window** (K6). T1 and
  T3 compare pairs inside one fleet on the same days, so the changes are
  alike across pairs; re-roll mostly touches sides already stuck (EUR,
  NZDCHF). Should IC fills after the cap-10 reload be scored apart, or
  should FTMO (unchanged) carry T2 alone?
- **GH-4. T3c counts open MTM**, against compass-round s1's realised-only
  rule (s2). Right for this question?
- **GH-5. "Inconclusive twice = not supported".** Fair as a guard
  against drift, or does it bias the answer toward stopping?
- **GH-6. T4's reading.** A counter-side fill that loses 5-6 pips at 4
  hours while the deep side gains is a hedge paying for the reversion
  the deep side harvests. Is the fill's markout the right test of the
  hedge, or should only the counter side's realised net count?

## 10. GEMINI'S RULINGS (5 OCT ~18:00Z) AND CLAUDE'S CHECK

Gemini read this file as an attachment. The operator decided after the
check (5 Oct ~18:05Z-18:15Z).
- **GH-1 ACCEPTED (a day-bootstrap interval), his reason corrected.**
  Clustered fills do not bias the mean one way ("40 fills each +3.0
  pips" is not how a trend scores: fills INTO a trend mark against us);
  they make it less certain, which the day-bootstrap measures. Checked
  on the first pass: the pooled +1.97 has a 2.5% bound of -0.28, and a
  four-day stretch clears it about 38% of the time. Adopted as the
  merged rule of s3 (bound > 0 supports; a total <= 0 fails; between,
  extend), applied to V.
- **GH-2 ACCEPTED:** the window starts Tue 6 Oct (s1).
- **GH-3 ACCEPTED in part:** FTMO decides (V). His premise that FTMO is
  "the only control group" matching the first pass is wrong (65% of the
  first pass's fills were IC's: B 1,262, C 1,085, D 610 of 4,518, all on
  the lattice), and IC never ejects, so cap 10 cannot "prevent
  ejections"; but this week's IC reloads (K6) do change depth and money
  there, so IC is reported only.
- **GH-4 ACCEPTED:** open MTM counts (V is equity).
- **GH-5 ACCEPTED:** inconclusive twice = not supported.
- **GH-6 ACCEPTED:** the fill's markout tests the entry (T4, reported);
  his "consuming margin" is not the binding constraint at 0.01 lots
  (slots are), the reason that stands is that the markout measures the
  entry itself.
- **Operator (5 Oct ~18:05Z-18:10Z):** the one-hour markout is a proxy and the
  entry tests lean toward entry optimisation (C103: "boring is best"):
  T1, T2, T4 reported only; "equity matters the most": V decides.

Line count: 225
