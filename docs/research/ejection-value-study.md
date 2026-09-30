This message has a line count at the bottom

# STUDY -- WERE THE EJECTIONS WORTH IT? (C16 REVIVED, 28 SEP)

Written by Claude, 28 Sep ~14:00Z, for Gemini's review before any code;
rulings in s7. Tools: pipshed `archive_counts.py --export-study` (EX1-EX5)
and `scripts/grind_bar_dump.mq5`; analysis in `research/ejection_value/`.
No EA change, no pipshed web change: read-only data, analysis offline.

## 0. WHY NOW

28 Sep, the first live ADR-157 ejections: 18 by 13:22Z (A 5, B 9, C 4),
all `source: auto`, each filled in 0-2 min, $3.00-5.49 each. Cycle 3 keeps
ejecting (frozen); from C63 (Tue/Thu) B and C ROLL instead (lattice), so
the same yardstick will later score rolls against ejections.

**The operator's thesis (27-28 Sep, his words):** "we can only control our
pnl by trading - layer 8 means we cant trade - ergo it is bad." The study
must PROVE OR DISPROVE this with numbers, not assume it.

## 1. QUESTIONS

- Q1 (the thesis): how much trading does a side lose while it sits at
  cap? Hours at cap per side, and the side's scalp rate below cap against
  its rate at cap.
- Q2 (per ejection): did ejecting beat holding? Counterfactual below.
- Q3 (risk): how much adverse excursion did each ejection avoid (FTMO's
  $500 day is measured on equity, not closes)?

## 2. DEFINITIONS (Gemini: GQ1-GQ3 are about these)

**Depth timeline per side** from `fill_logs`: an `ENT` fill (entry_type
IN, role ENT) adds a layer at its `layer_index`; the layer leaves when its
position closes (the close-by OUT_BY pair). "At cap" = depth ==
`max_layers` of that instance at the time (`config_events`).

**Per ejection e** (from `ea_events` `EJECT_ACCEPTED`/`EJECT_FILLED`:
instance, side, layer_index, entry, offset; realised from the ledger):
- `E` = realised net of the ejected layer (<= 0; commission and swap in).
- `X_orig` = the layer's exit before the ejection = entry +/- exit pips of
  that side (+ accrued carry shift, if any; the eject offset excluded).
- Price path after the fill, horizons `h` = 24 h and 48 h: `hit` = price
  reached `X_orig` (long exit: bid >= X_orig; short exit: ask <= X_orig);
  `t_hit`; `MAE` = the worst price against the layer before `t_hit` or `h`;
  `MTM_h` = the layer's mark at `h` if no hit.
- `H` = what holding would have made on that layer: the normal scalp net
  if `hit`, else `MTM_h` (plus the swap it would have paid).
- `F` = FREED-SLOT SCALPS: the net of scalps by layers that exist only
  because the ejection freed a slot. Proposed: layers ENT-filled on that
  side AFTER the ejection's fill at `layer_index` >= the ejected layer's
  index, closed before `min(t_hit, h)` (after `t_hit` the held world is
  below cap too, so the worlds re-converge).
- `V = (E - H) + F`. `V > 0`: the ejection beat holding.

**Chains.** Consecutive ejections on one side (EURGBP A: 3 in 75 min) are
ONE episode: in the held world the side never left cap, so the later
ejections would not have happened. Score the episode from the first
ejection until the held world's first layer returns to its exit.

## 3. DATA

- Archive (Postgres, worker only): `fill_logs` (side, layer_index, role,
  entry_type, deal_price, order_price_open, deal_time_broker_msc,
  position_id, profit, swap, commission), `ea_events` (EJECT_*, ROLL_*),
  `config_events` (max_layers, add, exit per instance and time).
  **Retention (CORRECTED 30 Sep):** no job deletes `fill_logs`; `ea_events`
  (EJECT_*, ROLL_*) are deleted at 90 days (`grid-thesis.md` T8).
  Export: a new `archive_counts.py --export-study --days N` flag printing
  JSON lines to stdout (read-only SELECTs; no web change).
- Prices: M1 bars (time, OHLC bid, spread) per symbol from a read-only
  MQL5 script `scripts/grind_bar_dump.mq5` (the tick probe's pattern),
  written to `MQL5/Files`: run on the desktop terminal for FTMO prices
  (fleet A) and on box 2 for IC prices (fleets B, C: same server). Ask
  side approximated as bid + bar spread (GQ4); cases within 1 pip of a
  hit are flagged "borderline" and reported separately.
  Why not `scripts/export_m1_bidask.mq5` (true ask, from ticks): it does
  a linear minute search per tick and a bubble sort (about 1e6 ticks x
  7e3 bars per pair per week), minutes of CPU per pair beside eleven live
  EAs on a 2-vCPU box, and it has no NZDCHF. It stays the tie-breaker
  for a single pair and day (GQ4 ruling).
  Known bias: an M1 bar's `spread` is the broker's stored bar spread
  (typically the bar's lowest), so bid + spread can understate the ask in
  a spike; a short-side hit is flattered by at most that spike. The
  1-pip borderline flag catches it on a 10-pip exit.
- Timestamps: bars are TRADE SERVER time (the header gives
  server_minus_gmt_s); `fill_logs.deal_time_broker_msc` is broker time
  too; `received_at` is UTC. Join on broker time per account.

## 4. OUTPUT (a report per run)

- Per side and fleet: hours at cap, scalps/hour below cap vs at cap,
  scalps forgone estimate = hours at cap x below-cap rate x mean scalp net.
- Per episode: E, H, F, V, MAE avoided ($), hit yes/no at 24/48 h.
- Totals: sum V, count V>0, by pair and fleet; B vs its `_ALTB` twins (add
  10: fewer caps) as a same-account control; A vs B vs C on the same days.
- Verdict on the thesis: is sum(V) > 0 AND is the forgone-scalps cost of
  sitting at cap larger than the ejection costs?

Sample: interim report Thu 1 Oct (B/C ejections stop at C63; A continues);
final ~9 Oct with >= 30 episodes. Rolls get the same treatment after C63.

## 5. WHO

Claude: the bar-dump script (operator compiles and runs it), the export
flag (small-fix route, with a test), the analysis in Claude's sandbox on
the exported files; code committed to fxmatrix `research/ejection_value/`.
Operator: two exports and two bar dumps per run (copy files to the chat).

## 6. FOR GEMINI

- **GQ1.** Is `F` right? Should freed-slot scalps count only layers at
  index >= the ejected index, or every scalp on that side after the
  ejection (the held side at cap can still scalp its shallower layers on a
  retrace, so those exist in both worlds)?
- **GQ2.** Horizons 24/48 h, and the chain rule (one episode until the held
  world's deepest layer would have exited). Any bias from ejections only
  happening in trends (the sample is conditioned on a move)?
- **GQ3.** `H` includes the held layer's swap to the horizon (from the
  carry table's rates). Enough, or must the carry shift move `X_orig`
  over the horizon too?
- **GQ4.** M1 bid bars + bar spread for the ask side, with a 1-pip
  borderline flag, rather than tick data (millions of rows). Acceptable
  for a 10-pip exit question?
- **GQ5.** Q1's "scalps forgone" uses the side's own below-cap scalp rate.
  Is that rate biased (a side reaches cap in trends, when scalp rates
  differ from the average)? Better: the same pair's OTHER side's rate in
  the same hours?

## 7. GEMINI'S RULINGS (28 Sep ~14:00Z) AND CLAUDE'S CHECK

- GQ1 ACCEPTED: `F` counts layers at `layer_index` >= the ejected index.
- GQ2 ACCEPTED: horizons 24/48 h; one episode per chain.
- GQ3 ACCEPTED with a correction: `X_orig` moves each night by that
  night's carry shift WITH ITS SIGN (away from the market when the side
  pays swap, closer when it earns it; ADR-135b), not always away.
- GQ4 ACCEPTED: M1 bid bars + bar spread, 1-pip borderline flag; ticks
  only to break a tie that flips an episode's sign.
- GQ5 DIAGNOSIS ACCEPTED (own average and other side both overstate);
  his fix (the `_ALTB` twins) covers only AUDNZD and NZDCAD, none of the
  28 Sep ejections (EURGBP, AUDCHF, NZDCHF), and the twins run add 10.
  **GQ5-F (for Gemini to confirm):** two controls that exist for every
  pair: (1) Fleet C vs Fleet B, same broker, settings and hours, different
  books: while B's side is at cap and C's same side is not, C's scalp
  rate in those hours is the uncapped rate (usable until C63); (2) `F`
  per hour at cap, measured directly (the trading the ejection bought).
  The twins stay as a third check where they exist. STATUS: sent to
  Gemini 28 Sep; the analysis codes all three, so his answer changes
  only which is headline.

## 8. 28 SEP AFTERNOON: CODE, PILOT, CORRECTIONS (CLAUDE)

**Code:** `research/ejection_value/` (standard library only; README
there): `ev_data` (export and bar loaders; server time -> UTC; the
forming last bar dropped), `ev_book` (layers from the ledger: close-by
pairs, all-in net; depth timelines; cap anchors; Q1), `ev_episodes`
(ejections, carry-shifted exit, hit/MAE/mark, chains, F, V), `ev_controls`
(GQ5-F: cross-fleet, twins, F per hour), `ev_report`. 19 synthetic tests,
expected values by hand; every rule broken once and caught.

**Pilot (28 Sep, export `--days 2` 16:24Z; IC bars from box 2, FTMO bars
from the desktop):** Fleet C's six ejections E sum to -17.72 = the strip;
A and B differ from the strip by exactly the ENT commissions of layers
opened before the window; the rebuilt depth equals the EA's `stack_depth`
on 45/45 scalps; every cap anchor consistent (spread 0). 26 ejections, all
filled; 1-8 `EJECT_ACCEPTED` rows per ticket (trailing). No episode scored
yet: 24/48 h of bars after each ejection are needed.

**Data changes:** export `--days 14` (the depth rebuild needs every ENT
since each fleet started; 14 days was chosen on a wrong retention premise,
see s3); IC bars from box 2
(VNC works; box 1's repo stays on the live build); FTMO bars from the
desktop terminal's flat `MQL5\Scripts\`. A close-by whose EXT IN deal is
missing (a fill in a broker resync, C76) pairs on the layer's ENT leg;
neither leg known -> skipped and counted.

**Correction to GQ1 (for Gemini after ADR-164; one document at a time):**
auto-eject takes the layer whose exit ranks depth-1 (`grind_engine.mqh`
559-585): the exit furthest from the market, the MOST UNDERWATER layer,
usually L0 (first live ejection: `layer_index` 0). So "F counts layers at
`layer_index` >= the ejected index" counts every later layer, including
those that exist in both worlds. The code decides by DEPTH: a layer is
freed-slot when it was added while the held world was still at cap
(visible depth + chain layers still held >= cap). **GQ6:** accept the
depth rule? And `V_strict` = `V_doc` + the mark of freed-slot layers still
open at the chain end (omitting them flatters ejection): headline which?

**Inferred, not verified:** the night multiplier (Wed 3, Sat/Sun 0, else
1; C61 is open).
## 9. AMENDMENT 30 SEP -- CAP SENSITIVITY AND NAMED CASES (FOR GEMINI)

Written by Claude 30 Sep ~15:00Z. Why: `docs/research/grid-thesis.md`
s5-s6 (caps 5-10 as a frontier, GT-5 agreed; trade history is the gold
standard, so a counterfactual counts only once it reproduces our fills).
For Thursday's interim. No EA or pipshed change.

**9.1 Method: a per-side ladder REPLAY on M1 bars** (new
`ev_replay.py`), run first at the ACTUAL cap against the actual fills
(9.2), then at caps 5-10 with add, exit and width unchanged. The EA's
rules, simplified; every simplification is listed:
- Start: the side's actual book at the window start (layers and entries
  from the ledger); add, exit, width and cap from `config_events` at each
  time (B's dial of 27 Sep 23:05Z included).
- Adds rest at the deepest entry -/+ add and fill when the bar's ask low
  (long: bid low + bar spread) or bid high (short) touches. After the
  deepest layer scalps, the add returns to that layer's level (ADR-162
  s3). A flat side's L0 rests at bar mid -/+ width and moves only when it
  would move by more than the deadband (4 pips). SIMPLIFIED: the EA's
  stranded-threshold test before a re-centre.
- Exits: every layer at entry +/- exit, filled when the bid (long) or ask
  (short) touches. SIMPLIFIED: the carry shift (small over days) and the
  exit queue (it orders what rests, not what fills).
- At cap: ADR-157 on bars -- S1 (the side's extreme at least W = 5 bars
  old over the last 2W) and S3 (bar spread <= 1.5 x the mean of the last
  60) -- closes the most underwater layer at that bar's close.
  SIMPLIFIED: live ejections filled 0-2 min later at a passive price.
  (S1 flips on an M1 boundary, which is why live ejections cluster at
  :57-:00 s, on every fleet at once, 30 Sep.)
- Intra-bar order: O-L-H-C when C >= O, else O-H-L-C; an add and its
  exit in the same bar count as a scalp only if that path allows it.
- Money: pip value and commission per lot from the ledger. SIMPLIFIED:
  swap.

**9.2 Reconciliation gate (per pair and fleet, same window, actual
cap).** The replay must match the ledger: scalps within 10%, ejections
within 20% or 2, closed net within 15% or $3. A pair that misses is
reported with its mismatch and gets NO frontier. Every replay number is
labelled "first-order, reconciled" or "not reconciled".

**9.3 Frontier (reconciled pairs only; caps 5, 6, 7, 8, 9, 10), a table,
not a score:** per pair and fleet -- closed net, scalps, ejections (count
and $); carried MTM at each FTMO day roll (22:00Z), worst and mean; the
fleet's worst intraday equity (minute by minute: closed since the day's
start + MTM, all its instances) against -$500; peak positions + orders
against the slot guard (194), which caps 9-10 must pass.

**9.4 Named cases:**
- (a) 30 Sep 01:47Z, AUD (`09_EVENT_LOG.md`): the depth of every AUD
  side on A, B and C at 01:40Z; did A's sides escape by depth or by
  price? `AUDNZD_ALTB` runs A's exact AUDNZD settings and ejected.
- (b) 30 Sep 06:08-13:59Z, a GBP and AUD trend day: A 11 ejections
  (-$57), B 28 (-$115), C ~26 (-$110); scalps A 116, B 139, C 143; closed
  net A +$35.96, B -$3.15, C +$3.92 (cards 14:29Z, broker day). The
  same depth read, and the cap 5-10 replay over that window.

**9.5 Data:** export `--days 14` (`fill_logs` are kept, s3 corrected;
14 days covers every fleet's start); bar dumps with `InpFrom =
2026.09.24 00:00` (the script's default of 27 Sep misses A's and B's
first days), desktop FTMO terminal and box 2.

**9.6 FOR GEMINI** (GQ6, s8, is still open and goes with these):
- **GQ7.** A replay gated by reconciliation at the actual cap, rather
  than an analytic count of moves beyond the room (`grid-thesis.md` s2).
  Accept?
- **GQ8.** The O-L-H-C / O-H-L-C path rule on M1 bars. Anything better
  with M1 only?
- **GQ9.** The tolerances in 9.2, and withholding the frontier for a
  pair that misses. Too loose, too tight?
- **GQ10.** Seeding with the actual book at the window start. After a
  counterfactual ejection or an extra layer the replay's book diverges
  from the actual one by design; the reconciliation only proves the
  actual-cap path. Is that enough to trust caps 5-10 first-order?

## 10. GEMINI'S RULINGS ON s9 (30 SEP ~14:45Z) AND WHAT THE DATA CHANGED

**Rulings, with Claude's check:** GQ6 depth rule ACCEPTED, `V_strict`
is the headline (the report now prints it first). GQ7, GQ9, GQ10
ACCEPTED (GQ10: first-order guidance only). GQ8 ACCEPTED, his reason is
wrong: a biased path rule does not "cancel out" over many bars, it
accumulates; what protects the result is the reconciliation gate.
GQ9 misread: the net tolerance is the looser of 15% and $3.

**Calibration log (every change mirrors the EA or the broker, never a
tuned constant; fleet A was used to diagnose, B and C are the holdout):**
- C1. Cycle 2 (FTMO 1514582088) used fleet A's instance ids: a 14-day
  export mixed 2,865 of its fills into A. Rows are now kept by session
  -> account (`filter_by_account`, both runners).
- C2. No exit fills in the bar its layer filled (the EA places the exit
  after the fill is processed; ledger: 2 of 575 A scalps closed within
  a minute of their fill).
- C3. A flat side's L0 is placed once and re-centres only while the
  OTHER side holds layers (`Grind_TryPlaceL0`, ADR-123;
  `Grind_TryRecenterOppositeL0`, ADR-124).
- C4. **GQ4 superseded: the true ask.** M1 bars store the minute's
  MINIMUM spread; at news and rollover the bid spikes while the real
  ask stays far away (AUDNZD 24 Sep 12:30Z: bid low 25 pips down with a
  1-pip bar spread; the replay filled two buy limits, the EA none).
  New read-only script `scripts/grind_bidask_dump.mq5` (tick history,
  one linear pass: bid OHLC, ask OHLC, min/max spread per minute); run
  30 Sep on the desktop FTMO terminal and on box 2 (9 symbols each, no
  failed chunk; box 2 in ~4 s). The replay uses the true ask when the
  file exists (buy limits fill on the ask low, sell limits on the bid
  high; S3 compares the close spread with the mean bar spread).

**Reconciliation at the actual cap (export 30 Sep 14:48Z, 24 Sep ->
30 Sep ~15:00Z):**

| | M1 bars | true bid/ask |
|---|---|---|
| A (diagnosed) | 2 / 11 | 4 / 11 |
| B (holdout) | 6 / 11 | 8 / 11 |
| C (holdout) | 3 / 11 | 6 / 11 |
| total | 11 / 33 | 18 / 33 |

Passing everywhere or nearly: EURGBP (3/3), NZDCAD ALT (3/3), CADCHF,
AUDCHF, AUDNZD ALT (B, C). **Open:** A's AUDNZD (the replay's add rests
where A's real add filled 27 pips below its level at 30 Sep 01:30:33,
as if placed after the fall; not the entry horizon, which is 0 in every
preset, nor the floating-loss gate); GBPUSD C (halted and reattached
28 Sep); small-count misses (NZDCHF C 14 vs 12 scalps).

## 11. INTERIM RESULTS (30 SEP NOON RUN; rerun tonight for Thursday)

First-order, reconciled instances only (A 4, B 8, C 6), 24-30 Sep: one
week, trend-heavy (the 30 Sep GBP and AUD days included).

**Caps 5-10, per fleet** (closed P&L; closed + open book at the end;
worst day = lowest of closed since the 22:00Z roll + open MTM; worst
open MTM carried into a roll):

| fleet | cap | closed | + open | worst day | worst carried |
|---|---|---|---|---|---|
| A | 5 | 51.33 | 41.18 | -50.92 | -19.38 |
| A | 6 | 66.66 | 49.32 | -59.45 | -22.47 |
| A | 8 | 108.27 | 67.56 | -80.91 | -44.10 |
| A | 10 | 124.78 | 66.40 | -98.48 | -53.99 |
| B | 5 | 81.33 | 71.73 | -51.71 | -51.11 |
| B | 6 | 95.92 | 75.34 | -59.91 | -56.00 |
| B | 8 | 125.52 | 74.30 | -81.97 | -74.67 |
| B | 10 | 152.48 | 64.53 | -120.52 | -101.41 |
| C | 5 | 15.91 | 8.58 | -21.42 | -21.42 |
| C | 6 | 30.87 | 13.25 | -30.84 | -30.84 |
| C | 8 | 51.81 | 11.91 | -58.43 | -47.61 |
| C | 10 | 80.73 | 15.98 | -81.87 | -64.43 |

Peak slots (reconciled subsets only) <= 126 at cap 10: no guard issue.

**Reading:**
- CLOSED P&L rises with cap on every fleet (Gemini's "toxic winner":
  the compass on closed P&L would push cap up).
- CLOSED + OPEN is flat from cap 6-7 upward (B peaks at 6-7 and falls
  at 10): the extra closed P&L of a higher cap is mostly loss deferred
  into open inventory.
- Risk grows steadily with cap: worst day and carried MTM at least
  double from cap 5 to cap 10 on every fleet.
- Per pair the best cap differs (closed + open): EURGBP best at 5 on all
  three fleets (it trended); GBPUSD and EURUSD best at 10 (they
  retraced); CADCHF best at 5; AUDCAD and AUDNZD around 6; AUDCHF at
  9-10; NZDCAD barely reaches 7-8. No single cap is right for every
  pair (`grid-thesis.md` s1).
- On B and C, cap 6 gives the same total as 8 (B 75.34 vs 74.30, C
  13.25 vs 11.91) with 25-45% less worst-day loss; on A, cap 8 keeps a
  lead (67.56 vs 49.32 at 6). One week; the rolls from C63 change what
  "at cap" costs on B and C.

**Ejection value (s2, V_strict):** at 24 h, 17 chains scored: A
-11.90 (7), B -8.10 (6), C -8.92 (4); 6 of 17 positive -- the three
EURGBP chains (the trend never came back) and three small ones. At 48 h, 7
scored, all negative (-40.16). 29 chains unscored (their horizon runs
past the data). **Q1:** sides spent at most 2.6 h of 157 h at cap; the
scalps forgone at cap are at most $0.29 per side. In this window the
"at cap we cannot trade" cost is small, and ejecting mostly lost value
against holding.

Line count: 364
