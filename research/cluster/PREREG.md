This message has a line count at the bottom

# THE CLUSTER MEASUREMENT -- PRE-REGISTRATION (25 Oct 2026 ~19:50Z; before any tick is read for it)

| | |
|---|---|
| Status | **DRAFT for review** (Argon: `prompts/argon_review_cluster.md`; reply on `review/argon-cluster`). No code, no run yet. |
| Why | The operator (25 Oct): "we are searching for a cluster of tight mean reversion"; "there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"; "we might end up with more layers but less fx pairs". The OPT cap sweep (`research/opt_budget/PREREG_CAP.md`) found cap 9 better than 7 but not 11 or 13; this asks the price question underneath: **from a stack's anchor, how far does price stay more likely to come back than to go on?** |
| What follows | **Nothing live.** A pair with a cluster in both regimes becomes a candidate (a cap or a pair choice) for its own pre-registered simulator, then harness, check (as swcap). No cluster: the idea is not supported at these scales, and that is reported. |

## 1. ONE WORKED EXAMPLE (EURUSD, a = 7 pips, prices)

A stack's anchor at 1.1600. Price falls to 1.1593 (depth k = 1), then 1.1586 (k = 2). From 1.1586 the next 7-pip move is
either back to 1.1593 (**RETRACE**) or on to 1.1579 (**EXTEND**). A driftless random walk retraces 50% of the time at
every depth. **A cluster of tight mean reversion** is a run of depths k = 1 ... K where it retraces clearly more than
that, say 60%, and beyond K about 50%: a stack's layers down to depth K sit inside it, deeper ones do not. If K = 4 for
EURUSD at 7 pips, the layers below 1.1572 (the anchor less 4 x 7) add exposure outside the cluster.

## 2. THE MEASURE (one series = one pair x one scale a x one regime)

- **Price:** mid = (bid + ask) / 2 of every tick, in order, within each segment (s3). Pips as the pair's point x 10.
- **Lattice:** levels at L0 + j x a, L0 = the segment's first mid; the state n (an integer) = the current level
  minus the anchor's, in steps of a; the anchor starts at the first level.
- **A move:** a tick whose mid reaches the next level up or down from the current level (first passage). A tick
  that crosses m > 1 levels at once (a gap) moves n by m and counts as ONE decision, at the level it left.
- **A decision:** at |n| = k >= 1, the next move is RETRACE (|n| falls) or EXTEND (|n| rises). Long and short
  excursions pooled (|n|). At n = 0 the excursion ends and the next move starts a new one (no decision at k = 0).
- **p_k** = RETRACE / (RETRACE + EXTEND) at depth k, for k = 1 ... 14 and a pooled "15 or more". Reported with N_k.
- **Segment ends:** the state is carried across a weekend inside one segment (October); the open decision at a
  segment's end is dropped (neither outcome).

## 3. DATA (the replay's tick files; nothing new dumped; hashes checked before the measure is read)

| regime | files (`D:\mt5-replay\MQL5\Files\replay`) | segments | recorded sha256 (sweep_notes) |
|---|---|---|---|
| calm | `ticks_53077984_<PAIR>__h8w.csv` | the 8 weekly segments of `inputs/swcap/run_swcapw_<pair>.csv` (Mon 3 Aug - Fri 25 Sep, server time) | starts EURUSD `10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa` |
| October | `ticks_53077984_<PAIR>_oct.csv`; EURUSD `ticks_53077984_EURUSD_w2hw.csv` | the one segment of `run_swcapo_<pair>.csv` (1 Oct 04:00 - 20 Oct 23:45 server) | GBPUSD `7c1c080f`, EURGBP `9139142b`, AUDCAD `f1be6881`, AUDCHF `df6a785d`, CADCHF `09d6aced`, EURUSD `93816e45` |

Pairs: E's six (GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF). **Scales a:** each pair's t3 OPT add and t3 ALT add
(GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP 5 / 23, AUDCAD 18 / 26, AUDCHF 14 / 20, CADCHF 10 / 17). 6 x 2 x 2 = 24 series.
One broker's ticks (IC 53077984); the same ticks chose t3's adds (in-sample: disclosed, s8).

## 4. THE NULLS

1. **50%** (a driftless random walk), with a Wilson 95% interval on p_k.
2. **The shuffle** (keeps each segment's drift, removes everything else): the segment's sequence of move directions
   (up / down, gaps kept as their own runs of m) permuted 200 times (seed 20261025); p_k recomputed on each; the 2.5%
   and 97.5% of the 200 values per k.

## 5. DEFINITIONS (fixed now)

- **REVERTING at k:** p_k above BOTH 50% and the shuffle's 97.5% value, with N_k >= 30.
- **TRENDING at k:** p_k below both 50% and the shuffle's 2.5% value, with N_k >= 30.
- **K\* (the cluster's depth)** for a series: the largest K with REVERTING at every k = 1 ... K (0 if not at k = 1).
- **The fall-off:** the first k > K\* that is not REVERTING (reported with its p_k).
- **A CLUSTER (pair, scale):** K\* >= 2 in BOTH calm and October. Its depth: the smaller of the two K\*.
- **Reference only (not deciding): the break-even** p\* = (a + c + s) / (2a), c = the commission per close in pips at
  0.01 lots ($0.06 / the pair's USD per pip at 0.01 lots, `research/replay/sweep.py` 56-59), s = the series' median spread in pips: a one-step bet
  of a pips each way needs p\* to pay its costs.

## 6. WHAT IS REPORTED

Per series: N_k, p_k (Wilson), the shuffle band, REVERTING / TRENDING per k, K\*, the fall-off, p\*. Per pair: CLUSTER
or not at each scale; for a CLUSTER its depth against the current caps (OPT 7 on D and E, 9 on C's EURUSD and AUDCAD;
ALT 7). A figure per pair: p_k against k, both regimes, with 50% and the shuffle band.

**Reading rule (fixed now):** a CLUSTER deeper than the cap says the arm rolls inside it (more layers is the
direction); shallower says layers past it sit outside (fewer layers, or the roll at the fall-off). Either is a
candidate for its own pre-registered simulator check, not a change.

## 7. SELF-CHECKS FIRST (any failure: STOP, record, amend before any p_k is read)

1. Each tick file's sha256 equals the recorded one (s3); the tick counts equal the replay's `TICKS_LOADED` where
   recorded (October: sweep10's counts; EURUSD w2hw 1,021,095).
2. The tests (s9) pass; a synthetic random walk (seeded, 1,000,000 steps) gives every p_k within its Wilson interval
   of 50% for k = 1 ... 10 (at most one miss).
3. Per series the decisions add up: the sum of N_k equals the number of moves less the moves from n = 0 less the
   dropped end decisions.

## 8. CLAUDE's PREDICTIONS (before any tick is read)

1. Most p_k sit inside the shuffle band: price at these scales is close to a random walk.
2. At OPT's scales in calm, p_1 to p_3 lean above 50% (OPT earns in calm); in October they do not.
3. **A CLUSTER (both regimes) on at most one pair at OPT's scale and on none at ALT's.**
4. No clear fall-off inside 7 at OPT's scale (as `depth.py`: layers 5-7 scalp as well as 1-4).

## 9. THE CODE AND THE RUN (after this is reviewed and committed)

`research/cluster/cluster.py` with `test_cluster.py` first, in their own commit, against a stub (hand values: a
zig-zag of one level gives p_1 = 100%; a straight run of 10 levels gives p_1 ... p_9 = 0% with N = 1 each; a gap of 3
levels counts one decision; a segment end drops its open decision; the shuffle keeps the up / down count). Then the
code; then the operator runs it on the desktop (`python research\cluster\cluster.py --data
D:\mt5-replay\MQL5\Files\replay`, outputs to `research/cluster/out/`, about a minute a file). The outputs and a hash
manifest committed; then `results.md`.

## 10. LIMITS

In-sample ticks (they chose t3's adds); one broker; mid prices (the spread is in p\* only); decisions within one
excursion are not independent, so the Wilson interval is too narrow and the shuffle band is the guard; a 1-pip lattice
offset (L0) could move a level: a sensitivity run at L0 + a/2 is reported beside the main one, not deciding.

Line count: 102
