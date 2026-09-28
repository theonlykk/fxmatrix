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
  **Retention: `fill_logs` 14 days** -> export at least weekly.
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
Line count: 148
