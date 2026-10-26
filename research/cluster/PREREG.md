This message has a line count at the bottom

# THE CLUSTER MEASUREMENT -- PRE-REGISTRATION v2 (26 Oct 2026 ~03:35Z; before any tick is read for it)

| | |
|---|---|
| Status | **DRAFT v2 for review** (Argon: `prompts/argon_review_cluster_v2.md`; reply on `review/argon-cluster-v2`). v1 (`b058521`) reviewed by Argon (`reviews/argon_review_cluster.md` on `review/argon-cluster`, `2875f99`): SOUND WITH CHANGES; its item 1(b) a real flaw (s1). No code, no run yet. |
| Why | The operator (25 Oct): "we are searching for a cluster of tight mean reversion"; "there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"; and (~03:23Z 26 Oct) "if this is random walk, then we are just trying to read tea leaves and any repeated pattern we do see might end as soon as we deploy capital ... there is a lot of back and forth around 'whole' numbers ... maybe we use those as clusters where we add and are more sparse between add layers ... i feel we could test this". |
| What follows | **Nothing live.** A result that holds in both regimes AND on the confirmation ticks (s7) becomes a candidate geometry for its own pre-registered simulator, then harness, check. No result: reported as such. |
| Prior evidence | Osler, "Currency Orders and Exchange-Rate Dynamics" (FRBNY Staff Report 125, 2001; J. Finance 2003): take-profit orders cluster at round numbers (trends tend to reverse there), stop-loss orders just beyond them (trends accelerate once through). A mechanism, so a reason the pattern might outlive its discovery; in 1990s bank order books, not tested here before. |

## 1. WHY v1 WAS WRONG, AND ONE WORKED EXAMPLE (EURUSD, 7-pip steps, prices)

v1 measured p_k, the share of steps at depth k that went back toward the anchor. Take the cleanest range there is:
price swings 1.1600 -> 1.1572 -> 1.1600 for ever (depth 0 to 4 and back). Each swing gives at depth 1 one step out
and one back (50%), the same at depths 2 and 3 (50%), and at depth 4 one turn (100%): **50 / 50 / 50 / 100**. Every
step out past a level is matched by a step back before the excursion ends, so inside ANY range p_k sits near 50%, as
for a random walk; p_k moves only where crossings stop. **p_k finds a wall, not a range.** Hence:

- **Part A** counts activity per depth (the operator's "drop in range trading activity"): in the example 2
  crossings per swing at each of depths 1-4 and none at 5, a cliff at K = 4.
- **Part B** asks the wall question directly, where it belongs: does price turn more often at round numbers?
  Example: EURUSD reaches 1.1600 from above; does it come back to 1.1605 before it reaches 1.1595 more often than it
  does at 1.1615 or 1.1585?

## 2. DATA (as v1 s3; the replay's ticks; hashes checked before anything is read)

| regime | files (`D:\mt5-replay\MQL5\Files\replay`) | segments | recorded sha256 (`sweep_notes.md`) |
|---|---|---|---|
| calm | `ticks_53077984_<PAIR>__h8w.csv` | the 8 weekly segments of `inputs/swcap/run_swcapw_<pair>.csv` (3 Aug - 25 Sep, server time) | starts EURUSD `10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa` |
| October | `ticks_53077984_<PAIR>_oct.csv`; EURUSD `ticks_53077984_EURUSD_w2hw.csv` | the one segment of `run_swcapo_<pair>.csv` (1 Oct 04:00 - 20 Oct 23:45 server) | GBPUSD `7c1c080f`, EURGBP `9139142b`, AUDCAD `f1be6881`, AUDCHF `df6a785d`, CADCHF `09d6aced`, EURUSD `93816e45` |

E's six pairs. Mid = (bid + ask) / 2 per tick; a tick is in a segment when `from_ms <= time_msc_server <= to_ms`
(`research/opt_budget/runs.py` `window`). Pips: 0.0001 (all six pairs quote 5 digits). Prices compared to a level
with eps = 1e-9. One broker (IC 53077984); the ticks chose t3's adds (in-sample for Part A's scales; never used for
round numbers).

## 3. PART A -- ACTIVITY PER DEPTH FROM A STACK's ANCHOR

- **Series:** pair x scale a x regime; a = the pair's t3 OPT add and t3 ALT add (GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP
  5 / 23, AUDCAD 18 / 26, AUDCHF 14 / 20, CADCHF 10 / 17): 24 series.
- **Lattice:** levels at L0 + j x a, L0 = the segment's first mid; state n = the level index of the last level
  reached, relative to the anchor; the anchor = the level at the start of each excursion (the first, L0).
- **Moves:** a tick whose mid reaches the next level up or down. A tick that passes m > 1 levels counts every
  level passed (m moves, in order). **An excursion** runs from leaving n = 0 to the next arrival at n = 0; a gap
  that passes through n = 0 ends the excursion at 0 and starts the next on the other side.
- **The measure:** V_k = arrivals at depth k = |n| (from either side), summed over the series; **A_k = V_k / V_1**,
  k = 1 ... 14. A driftless random walk's profile is flat (equal expected arrivals at every depth per excursion);
  the cliff example gives A_1 ... A_4 = 1, A_5 = 0.
- **Null (the shuffle):** the series' moves (a gap's m moves kept together as one block, in its direction) permuted
  1,000 times, generator `random.Random(20261025 + i)`, i = the series' index in s3's order (pairs as listed, OPT
  then ALT, calm then October); A_k recomputed each time; the band = the 26th and 975th of the 1,000 sorted values.
  A permutation with V_1 = 0 or V_k undefined is skipped and counted.
- **DROP at k:** A_k below the band's lower edge, counted only where the shuffle's median V_k is at least 20 (with
  fewer, depth k is too thin to read: reported as THIN).
- **The fall-off K:** the smallest k >= 2 with DROP at k and at k + 1 (two in a row). None: K = none.
- **A CLUSTER (pair, scale):** K exists in BOTH regimes; its depth = the smaller K.
- **Against the caps (Argon 1(c)):** a stack with cap c holds layers at depths 0 ... c - 1 (L0 at the anchor) and
  rolls at depth c. **A CLUSTER of depth K reads: the layers at depths < K sit inside it; cap K would roll at the
  fall-off.** Against today's caps (OPT 7; C's three OPT 9; ALT 7): K > cap says more layers; K < cap fewer.

## 4. PART B -- ROUND NUMBERS

- **Levels:** every 5 pips (multiples of 0.0005). **Classes:** R100 (multiples of 100 pips: 1.1600, 0.9800), R50
  (multiples of 50 pips, not of 100: 1.1650), OTHER (the rest).
- **Scale:** s = 5 pips (primary) and s = 10 pips (reported, not deciding).
- **An arrival at level L:** the first tick whose mid reaches L (at or beyond it, eps) from one side, after the mid
  has been at least s away from L on that side since L's last arrival (re-armed). The arrival side = the side it came
  from.
- **The outcome:** after the arrival, which comes first: the mid back at L + s on the arrival side (**TURN**) or at L
  - s on the far side (**THROUGH**); a gap past L - s is THROUGH. An arrival still open at the segment's end is
  dropped and counted.
- **Rates:** t_class = TURN / (TURN + THROUGH), per pair, per regime, and pooled over the six pairs.
- **The effect:** d100 = t_R100 - t_OTHER and d50 = t_R50 - t_OTHER (pooled). Interval: a day-block bootstrap (the
  arrivals grouped by server date; 2,000 resamples of days with replacement, `random.Random(20261026)`; the 51st and
  1,950th of the sorted differences). A random walk gives the same t in every class (a class has no meaning to it),
  so the classes are each other's control; no shuffle.
- **A ROUND EFFECT (class R100 or R50):** its d above 0 with the bootstrap interval above 0, pooled, in BOTH
  regimes at s = 5. Per pair reported, not deciding. **Reported beside it (Osler's second effect):** after a THROUGH
  at a round level, the share that reach a further s beyond before returning to L, against OTHER.

## 5. SELF-CHECKS FIRST (any failure: STOP, record, amend before any real number is read)

1. The tick files' sha256 equal the recorded ones; counts equal the replay's `TICKS_LOADED` where recorded
   (October: sweep10's; EURUSD w2hw 1,021,095; calm: sweep8's logs, `sweep_notes.md` 833-834).
2. The tests pass (s8).
3. **Synthetic random walks** (seed 20261027; per series the same number of moves and the same overall up / down
   count as the real series, i.e. one shuffle each): Part A gives a CLUSTER on at most 1 of the 12 pair-scales.
   Part B, 10 runs per regime: a Gaussian walk of the mid per pair (the real series' tick count, first mid and
   standard deviation of tick-to-tick mid changes), the same rules; the d100 and d50 intervals include 0 on at least
   9 of the 10 runs. More false findings than that: the rules are too loose; amend before reading real data.
4. Identities: per series, the sum over k of arrivals = the moves less the moves into n = 0; per class, TURN +
   THROUGH + dropped = arrivals.

## 6. CLAUDE's PREDICTIONS (before any tick is read)

1. Part A: a CLUSTER on at most 1 of the 12 pair-scales; none at ALT's scale.
2. Part B, calm, s = 5: pooled d100 between +1 and +8 points; d50 smaller than d100.
3. Part B: a ROUND EFFECT at R100 in both regimes (lean, from Osler); none at R50.
4. Osler's second effect (reported): after a THROUGH at R100 the continuation share above OTHER's.

## 7. THE CONFIRMATION (the operator's "tea leaves": what counts is what holds on ticks nobody has seen)

A finding from s3 or s4 counts as **CONFIRMED** only if it also holds, by the same rule, on **new ticks: E's six
pairs from Mon 26 Oct 00:00 to Fri 6 Nov 23:57 server**, dumped on wine-d (IC 53077984, as every h8w and `_oct`
file) after 6 Nov's close with `grind_tick_dump`, hashed, and read once. Until then a finding is IN-SAMPLE only and
nothing is built on it beyond a simulator pre-registration.

## 8. THE CODE AND THE RUN

`research/cluster/cluster.py` with `test_cluster.py` first, in their own commit, against a stub, hand values: A: the
v1 cliff (1.1600 <-> 1.1572 at 7 pips) gives A_1 ... A_4 = 1 and A_5 = 0; a 10-level straight run gives V_1 ... V_10 =
1; a gap of 3 levels counts 3 arrivals; a gap across n = 0 ends one excursion and starts the next; the shuffle keeps
the up / down count and the gap blocks. B: a bounce off 1.1600 from above is TURN; a gap from 1.1607 to 1.1592 is
THROUGH; a re-arm needs s away first; an open arrival at the end is dropped. Then the code; then the operator runs
it on the desktop (`python research\cluster\cluster.py --data D:\mt5-replay\MQL5\Files\replay`, outputs to
`research/cluster/out/`); outputs and a hash manifest committed; then `results.md`.

## 9. IF PART B HOLDS (the operator's grid idea; NOT pre-registered here)

A round-aware lattice: adds denser within a few pips of R100 / R50 levels, sparser between them. Its own
pre-registration and simulator check (as the OPT budget and the cap sweep), after s7's confirmation.

## 10. LIMITS

In-sample ticks (s7 is the answer); one broker; mid prices; one level grid (5 pips) and two scales for B; A's
lattice starts at the segment's first mid (a sensitivity run at L0 + a / 2 reported, not deciding); arrivals within
a day are dependent (the day-block bootstrap is the guard for B; the shuffle and s5.3 for A).

Line count: 130
