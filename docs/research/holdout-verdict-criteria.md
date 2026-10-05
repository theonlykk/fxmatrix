This message has a line count at the bottom

# HOLDOUT VERDICT CRITERIA -- DOES THE GRID HAVE AN EDGE? (5-9 OCT)

| | |
|---|---|
| Status | **DRAFT for Gemini** (Claude, 5 Oct ~04:20Z). Written BEFORE any holdout markout or P&L is computed. T4 and K8 added 5 Oct ~14:05Z (operator's counter-side reading; first-pass split), before Gemini's review. Once accepted, nothing below changes except by a dated amendment (s8) written before the scoring run |
| Origin | Operator, 5 Oct ~04:13Z: "is this whole effort going to end in disappointment?"; Claude proposed fixing in advance what result counts as "it works" and what counts as "it doesn't", so the verdict comes from the data and not from a bad night; operator: "proceed" |
| Builds on | `docs/research/markout-variance-study.md` (first pass, s4-s6); `docs/runbooks/compass-round.md` s1 (realised all-in P&L); backlog C124 (FTMO pass probability), C103, C84 |
| Decides | Whether the first pass's two findings hold on unseen days, and whether the grid made money where they say it should. Not a geometry ruling; not a compass verdict |

## 0. AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| K1 | The first pass used FTMO minute bars to 3 Oct 07:30 server (= the Friday close) and fills from `archive_2026-10-02.jsonl`: **1-2 Oct are IN its sample.** The study's s6 "re-run on 1-7 Oct (C84's window)" would score on days it was fitted on. C84's 1-7 Oct holdout is for the ejection replay (frozen 30 Sep) and stays as it is | study header table (Data row), s6; backlog C84 | VERIFIED (docs) |
| K2 | The predicted groups, as written before this document: "GBPUSD, EURGBP, NZDCAD revert; AUDCHF, NZDCHF, AUDCAD trended at the hour" | HANDOFF s56; study s4.2 | VERIFIED |
| K3 | First-pass values: 1-hour markout +0.7 / +0.3 / +0.1 (reverting group), -2.4 / -1.6 / -1.0 (trending group); 4-hour L0 -5.0, depth 6-7 +2.2, depth 8+ +2.5; naive se 0.1-0.3 pips at 1 h, 0.5-0.7 at 4 h, too small by perhaps 2-3x (fills not independent) | study s4.1, s4.2, s5 | VERIFIED |
| K4 | `research/markout/markout.py <bidask folder> <archive export>` scores every ENT layer opened after the first bar + 1 h; a horizon that lands in a closed market takes the next bar within 3 days, else drops (the first pass ended at the Friday close too, so Friday-afternoon fills are treated alike) | `markout.py` 1-40 | VERIFIED |
| K5 | `compass_score.load(paths, accounts)` and `side_metrics(layers, inst, side, windows, cutoff)` give realised all-in net (profit + swap + commission, scalps + rolls + ejections) per instance and side by close time over given windows; `load` takes any account list (FTMO 1514731800 included) | `research/compass/compass_score.py` 67-74, 104-137 | VERIFIED |
| K6 | Inside the window: tonight's Monday build on B, C, D (after 22:00Z Mon 5 Oct: re-roll ON, twins retired) and probably the cap-10 reload (cap 10, new widths, AUDUSD); FTMO (A) changes nothing (frozen cycle) | monday-build s1; cap10-reload s1 | VERIFIED (runbooks) |
| K7 | Before this was written, two status reads fell inside the window (00:35Z and 02:52Z Mon 5 Oct: open MTM; the EUR longs down). No markout and no realised P&L of the window was computed | HANDOFF s54, s56; this chat | VERIFIED |
| K8 | The first pass's "depth 1 = L0" row counts fills onto a side holding no other layer (`markout.py`: "Depth = the side's open layers at the fill, itself included"), not the EA's L0 label; a roll moves an exit and is never a fill. Split 5 Oct ~14:00Z on the SAME first-pass sample (a scratch copy of `markout.py` with one added count; the repo file unchanged; the 463 / -2.3 / -5.0 reproduced): 429 of the 463 had layers open on the OTHER side (the counter-side entry, re-centred to mid +/- W after 4 pips of drift, K6 of cap10-reload), 34 a flat book. Counter-side 4-hour markout -5.6 (se 0.7; other side 1-3 layers -3.4, 4-7 -5.3, 8+ -6.9); flat book +3.1 (se 3.1, n 34); IC counter-side before the 2 Oct 03:05Z S = W + 1 change -5.9 (n 349), after -6.8 (n 62) | this document s2 T4 | MEASURED (in-sample) |

## 1. THE WINDOW

- **FTMO days Mon 5 - Fri 9 Oct:** 4 Oct 22:00Z to 9 Oct 21:00Z (Friday
  ends at the close, ~20:57Z). Five days.
- **Why not 1-7 Oct:** K1. **Why not later:** the sooner the answer, the
  sooner a decision; one extension is allowed (s5).
- K7 is declared, not hidden: about five hours of the window's open MTM
  were seen before the rules were fixed. The groups and thresholds below
  come from the first pass only.

## 2. THE TESTS

All four fleets' fills; FTMO's mid for markouts (as the first pass);
`markout.py` and `vr.py` UNCHANGED (the commit they are at when this is
accepted). "Group" = the three pairs of K2, pooled over fills.

**T1 -- the pair ranking holds (markout, 1 hour).** D1 = mean 1-hour
markout of the reverting group's fills minus the trending group's.
First pass: about +2.0 (unweighted over the pairs). **PASS: D1 >= +1.0 pip. FAIL: D1 <= 0.**
Between: inconclusive. Reported beside it, never deciding: the nine
pairs' 1-hour markouts, and the rank correlation of first-pass VR(60)
with holdout 1-hour markout over the nine.

**T2 -- depth (markout, 4 hours; diagnostic, not part of the verdict).**
D2 = mean 4-hour markout at depth 6+ minus at depth 1 (an empty-side
fill, K8; not the EA's L0 label). First pass:
about +7. **PASS: D2 >= +2.0. FAIL: D2 <= 0.** It feeds C103 (the
counter-side L0) whatever the verdict.

**T4 -- the counter-side entry (markout, 1 and 4 hours; diagnostic).**
The operator's reading (5 Oct ~04:35Z): once one side is a few layers
deep, bringing the other side's entry close to the market acts like a
momentum strategy on our own trades, when it matters most. Measured on
depth-1 fills whose OTHER side holds >= 1 layer (K8). First pass: 1 h
-2.4, 4 h -5.6 (n 429): the bounce that fills it kept going, the same
reversion that pays the deep side (depth 8+ +2.5 at 4 h). **The first
pass predicts FAIL. PASS (the hedge works): 4-hour markout > 0. FAIL:
<= -2.0.** Between: inconclusive. Reported beside it: the same by the
other side's depth (1-3, 4-7, 8+), by fleet, and the realised net of
the counter side's layers opened inside the window (a markout is one
fill; the counter side then grids on, and its own deeper layers may
pay). Feeds C103 (how close the counter-side entry should sit), not the
verdict.

**T3 -- the money where T1 says it should be (realised; decides).**
Realised all-in net (K5) of the reverting group's instances, both
sides, closed inside the window, per fleet (A runs all three; B, C, D
run all three).
- **T3a: the reverting group's realised net > 0 on at least 3 of the
  4 fleets.**
- **T3b (reported, not deciding):** per instance per day, reverting
  group minus trending group, on B, C and D (A runs only AUDCHF of the
  trending group).
- **T3c: total = realised + change in open MTM**, the reverting group
  summed over A, B, C, D, open MTM marked at the MID at 22:30Z Sun 4 Oct
  and 20:45Z Fri 9 Oct (outside the rollover spreads), realised over the
  same span. **T3c > 0** is required for "supported".
  Claude's proposal, for the operator: compass-round s1 decides on
  realised only, which is right for comparing geometries on the same
  book; whether an edge EXISTS cannot ignore losses left open, and that
  is what the desk and FTMO's daily limit see.

## 3. THE VERDICT

| Verdict | Rule |
|---|---|
| **SUPPORTED** | T1 PASS **and** T3a PASS **and** T3c > 0 |
| **NOT SUPPORTED** | T1 FAIL, **or** (T3a fails **and** T3c <= 0) |
| **INCONCLUSIVE** | anything else |

## 4. WHAT EACH VERDICT LEADS TO (proposals; the operator decides)

- **SUPPORTED:** the pair screen (VR(60), Z(10), spread / range) goes to
  Gemini as the rule for rings and scouts; C124 (pass probability) is
  run on the reverting group's days as well as the seven; any answer to
  BMO is built on that pair set and the T3c numbers.
- **NOT SUPPORTED:** no new challenge fee, no real money, no BMO trial of
  the method as it stands. The lab may keep running only for a NEW
  pre-registered hypothesis (e.g. from T2: a different first layer),
  written like this one before its data.
- **INCONCLUSIVE:** extend ONCE, to FTMO days 12-16 Oct, the same rules
  on the ten days pooled. Inconclusive after the extension counts as
  NOT SUPPORTED: no third week.

## 5. SCORING (after the Friday 9 Oct close; Saturday 10 Oct)

1. FTMO minute bars: `grind_bidask_dump` on the desktop FTMO terminal
   (read-only), `InpFrom` = `2026.10.05 00:00` (server; = 4 Oct 21:00Z),
   `InpTo` empty, into Downloads as `bidask_ftmo_2026-10-09\`.
2. IC minute bars for T3c's marks: the same on wine-c, `InpFrom` the
   same, scp to Downloads (`bidask_ic_1009\`).
3. The archive export (`archive_counts.py --export-archive`) for T1 and
   T2, and the study export (`--export-study --days 14`) for T3.
4. Claude runs `markout.py` (T1, T2) and a small read-only driver over
   `compass_score.load` / `side_metrics` (T3); the driver is written THIS
   week, before the window ends, tests first with hand-derived values on
   the 2 Oct export, and changes no existing file. The marks for T3c
   use the minute bar's mid at the stated times.
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

(none)

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

Line count: 169
