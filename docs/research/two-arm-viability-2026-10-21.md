This message has a line count at the bottom

# CAN ANY OPT / ALT (/ DUP) GEOMETRY STABILISE OCTOBER? THE PROJECT'S GO / NO-GO QUESTION (21 OCT)

| | |
|---|---|
| Status | **OPEN.** Written 21 Oct ~20:05Z (HANDOFF s87 continued 2). The surface (sweep9, s6) to be built and pre-registered next; the definition of "stabilise" (s5) is PROPOSED, for the operator to confirm |
| Owner | The operator (Lead Quant); Claude (Lead Engineer) builds and reads the replay |
| Evidence so far | sweep8 on EURUSD (`research/replay/results/sweep_notes.md`, sweep8 and its result); the live EURUSD rolls of B, C, D 1-20 Oct (s3); the two-arm fleets built today (D, C; E tonight) |
| Related | `docs/research/fleet-d-two-arm-ring-2026-10-16.md` (why ALT); `research/alt_adds/results_2026-10-17.md` (ALT's adds, fitted on 1-16 Oct); backlog C157, C160 (DUP), C162 (this question) |

## 1. THE OPERATOR'S CONCERN, IN HIS WORDS (21 OCT ~19:54-20:05Z)

> "the issue last week was that even though we did a lot of scalps and overall the market returned broadly to its
> starting position - we did not make money. the problem was that we were rolling too often vs the scalps. hence the
> solution was to have another arm with wider adds and hence wider tolerance before rolling. if the market was trading
> very tightly, then this arm would hardly trade - and hence few scalps/less rolls - it was nothing to do with
> commission. we could make money from opt. if the market was like last week - it would trigger the alt arm and even
> though opt would lose money, alt would make money - like an offset. Hence we probably set the add pips too wide for
> alt. this is an important thing to get right. if we brush it off - then this whole project ends."

> "you need to be less fixated on these one week periods. you should have a very clear idea of when fleet started
> losing money and we had a flurry of rolls. use that as your starting period. your strictness for statistical rigour
> will throw the baby out with the bath water."

> "we spent ages building this replay harness ... we seem to be hardly using it. we should be able to replicate this
> october period using a range of pips ... We should have a full surface of scalps and rolls given say 8 layers and a
> variety of add/exit pips."

> "if we cannot find a single geometry that uses an OPT/ALT and maybe even DUP arm that can at least stabilise in these
> last few weeks - then there is no future in this work."

**The question, stated once:** over the October regime (s3), is there ANY combination of arms (OPT, ALT, and DUP = a
second ALT, C160) and geometry (add, exit, cap) that at least stabilises the book (s5)? If yes: that geometry is the
next live step and the replay says where. If no: the grid as built has no regime it survives, and the project stops
or changes its premise.

## 2. THE HYPOTHESIS: ALT AS AN OFFSET

One worked example (EURUSD, OPT add = exit 7, cap 7; ALT add = exit 16, cap 7). Price ranges 1.1600 - 1.1540 -
1.1600 twice in a week. OPT (width 2) rests L0 at 1.1598 and fills its seventh layer at 1.1556 (6 x 7 pips lower),
then rolls a step at each further 7 pips (1.1549, 1.1542): two roll steps by 1.1540, then scalps on the way back:
many scalps, and the roll closes cost more than they earn. ALT (width 4) rests L0 at 1.1596 and adds at 1.1580,
1.1564 and 1.1548: four layers by 1.1540, far from its first roll (six adds, 96 pips, below L0); on the way back to
1.1600 it scalps three of them at +16 each (+48 pips; L0's exit at 1.1612 is not reached), with no roll. The hypothesis: in a range wider than OPT's stack and narrower than ALT's, ALT's scalps
pay for OPT's rolls; in a narrow range ALT hardly trades and OPT earns; in a one-way trend both lose (accepted: "if the
market trends in one direction for a week and ends up 200 pips away we will likely lose money - but that was not the
case").

## 3. THE OCTOBER REGIME (LIVE, EURUSD, B + C + D)

From the replay inputs' live event files (`research/replay/inputs/eurusd_20261008_p4/real_eurusd_*.csv` and
`eurusd_window_p4/`, de-duplicated; server days):

| Day | Roll closes | Entries |
|---|---|---|
| Thu 1 Oct | **33** | 86 |
| Fri 2 Oct | 3 | 113 |
| Mon 5 Oct | **38** | 96 |
| Tue 6 Oct | **23** | 64 |
| Wed 7 Oct | **27** | 75 |
| Thu 8 Oct | 0 | 92 |
| Fri 9 Oct | 12 | 30 |
| Mon 12 Oct | 14 | 27 |
| Tue 13 Oct | 0 | 38 |
| Wed 14 Oct | **19** | 75 |
| Thu 15 Oct | **23** | 124 |
| Fri 16 Oct | 14 | 61 |
| Sun 18 - Tue 20 Oct | 0 | 117 |

**The regime is 1-16 Oct: two roll bursts (1 and 5-7 Oct; 14-16 Oct), quiet after.** EURUSD only; the CHF crosses (1
Oct) and GBPUSD (16 Oct) had their own. The replay holds EURUSD's ticks for the whole stretch in one continuous file
(`ticks_53077984_EURUSD_w2hw.csv`, 1 Oct 04:00 to 21 Oct 01:30 server, `93816e45...6c81`, in `D:\mt5-replay`), the
data plan 4 validated the harness on (T1 98-99% at timing 1).

## 4. WHAT SWEEP8 SHOWED, AND WHAT IT DID NOT

sweep8 (pre-registered, EURUSD, eight weekly flat starts 3 Aug - 25 Sep, the live t1 geometries): OPT +318 pips, ALT
q95 -19, ALT q90 -12; ALT gross about zero; **in OPT's four losing weeks ALT lost too** (same sign every week): ALT
behaved as a smaller OPT, not a hedge; ALT never rolled within a week, its losses waited as open inventory (carried 8
weeks: -1,444 pips open). **What it did not test:** the October regime (s3), any ALT add other than 23 / 27, or a
carried book through a roll burst. Aug - Sep was a regime OPT earned in; there was little to offset. So sweep8 does not
answer s1's question; it says the t1 ALT (23-30 pips) is too wide to offset in a calm regime, consistent with the
operator's "we probably set the add pips too wide for alt".

## 5. "STABILISE": PROPOSED DEFINITION (for the operator to confirm before any run)

Over 1 Oct 04:00 to 20 Oct 23:45 server (the "last few weeks"), one flat start, the book carried, EURUSD at 0.01 lots:
a combination STABILISES if (a) its net at the end (realised - commission + swap + the open book marked) is >= 0, and
(b) its worst equity (the same, marked each day) is no lower than OPT alone's. It PASSES the regime if (a) and (b)
hold and it is at least as good as OPT alone over the two bursts (1-7 Oct and 14-16 Oct) marked at each burst's
end. Combinations: OPT alone; OPT + ALT(add, exit) for every ALT on the surface; OPT + 2 x ALT (DUP: the same orders
twice, so its curve is ALT's doubled, C160: no extra run).

## 6. THE SURFACE (SWEEP9, TO BE PRE-REGISTERED)

- **Harness** `8044284` (validated), timing 1, sessions on, **carry ON** (October's swaps exist: `swaps.csv` of the
  window set), FREE; the desktop's `D:\mt5-replay` (the Surface has no replay install, and a new IC login there is
  C150's risk).
- **Data:** the w2hw EURUSD ticks; one segment per geometry, flat at Thu 1 Oct 04:00 server, carried to Tue 20 Oct
  23:45 server.
- **Grid, cap 8:** add {4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 23, 27} x exit {4, 5, 7, 9, 11, 14, 18, 23, 27} (117);
  and the add = exit diagonal at cap 7 (the t1 shape, 13). Width = add / 4 rounded up to 0.5, at least 2 (ADR-153:
  add / width <= 4); stranded = width + 1; deadband 2; lattice, re-roll on; roll gate 0.
- **Per geometry:** S, R, A (roll steps), scalps per roll step, realised, commission, swap, open book at the end, net,
  worst floating, and **a daily equity curve** (the deal log replayed into a book, marked at each server day's last
  tick), so that any pair of geometries can be summed afterwards (OPT + ALT, OPT + 2 x ALT).
- **Reported:** the surface of net and of scalps per roll step; every combination's end net, worst equity and burst
  marks; which pass s5. **Then** the passing geometries on the eight calm weeks (sweep8's h8w data) as a check that
  they do not lose heavily with nothing to offset; then live.
- **Run time:** about 45 s per geometry at timing 1 (sweep8: 982 s for 240 day-geometries): 130 geometries about 1.5-2
  h, unattended, split into run files of about 30 geometries (the runner's timeout is 30 minutes unless raised).
- **Limits written first:** one pair and one feed; one path (the regime happened once); the geometry is chosen on the
  same data it is judged on (deliberately: s1 asks whether ANY geometry survives it; the calm check and live weeks are
  the out-of-sample part); P&L is outside plan 4's validated counts (a guide); E's other pairs need their own October
  tick dumps (wine-d serves them) before the same surface can be run on them.

## 7. WHAT EACH ANSWER MEANS

- **Some combination passes s5:** the two-arm idea has a basis; its geometry is the candidate for D's next reload
  (after ALT's first live week), and the replay knows where it is fragile (the surface around it).
- **None passes, but some stabilise (a and b only):** the arms can hold the book through the regime without earning;
  read the cost per roll step against the scalps for the next idea.
- **None stabilises:** no geometry of this grid survives a ranging, rolling fortnight on EURUSD. By the operator's
  own test (s1), the work as built has no future without a different premise.

Line count: 127
