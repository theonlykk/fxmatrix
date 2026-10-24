This message has a line count at the bottom

# CAN ANY OPT / ALT (/ DUP) GEOMETRY STABILISE OCTOBER? THE PROJECT'S GO / NO-GO QUESTION (21 OCT)

| | |
|---|---|
| Status | **OPEN (operator CONFIRMED 24 Oct ~03:50Z, HANDOFF s90): E's live weeks against D's t1 set on the same six pairs are the out-of-sample test (s8.7); a reload of E after its first week NOT ruled.** Before: **ANSWERED IN PART (22 Oct ~03:25Z, s8): the daily rule passes nothing; over the period every wide geometry covers OPT; the next step is E with narrower ALT adds (s8.4).** Written 21 Oct ~20:05Z (HANDOFF s87 continued 2); s5 rewritten ~20:10Z with the operator's definition of "stabilise" (a meaningful offset of OPT's losses by the wider arm's gains; the 0.25 mark Claude's placeholder). The surface (sweep9, s6) to be built and pre-registered next |
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

## 5. "STABILISE": THE OPERATOR'S DEFINITION (21 OCT ~20:09Z), AND HOW IT IS MEASURED

**The operator:** "Stabilise means that there is some meaningful offset to the losses on OPT with the gains on the
wider add pip arms." Not that the book ends flat: that the wider arm GAINS when OPT LOSES.

**Measured on the daily equity curves (s6), EURUSD at 0.01 lots, 1 Oct 04:00 to 20 Oct 23:45 server, one flat start,
the book carried; a day's P&L = the change in (realised - commission + swap + the open book marked at the server
day's last tick):**
- **Offset ratio** = (ALT's summed P&L on the days OPT's P&L < 0) / -(OPT's summed P&L on those days). Worked example:
  OPT loses -100 pips over its losing days and ALT makes +40 on the same days: offset 0.40; ALT -10 on them: -0.10.
- **The same per burst:** 1-7 Oct and 14-16 Oct, each on its own days.
- **MEANINGFUL (the pass mark, Claude's placeholder; the operator may move it before any run):** the offset ratio is
  at least **0.25** over the period AND positive in BOTH bursts.
- Computed for OPT (the live 7 / 7, cap 7, and each OPT candidate on the surface) against every ALT geometry on the
  surface, and against 2 x ALT (DUP, C160: the same curve doubled). Reported for every pair as a table, so where any
  offset lives on the surface is visible, not only whether one passes.
- **Also reported, not deciding:** OPT + ALT's end net and worst equity against OPT alone's (whether the offset also
  leaves the book better off), and scalps per roll step for OPT alone and OPT + ALT on the burst days.
- sweep8's eight calm weeks would score NEGATIVE on this measure (ALT lost on OPT's losing weeks): the failure it is
  built to catch.

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

- **Some combination offsets meaningfully (s5):** the two-arm idea has a basis; its geometry is the candidate for D's next reload
  (after ALT's first live week), and the replay knows where it is fragile (the surface around it).
- **Some offset, none meaningfully (a positive ratio below the mark, or in one burst only):** the mechanism exists
  but is too weak at these geometries; read where on the surface it is strongest before the next idea.
- **No offset anywhere (every ratio <= 0):** no geometry of this grid survives a ranging, rolling fortnight on EURUSD. By the operator's
  own test (s1), the work as built has no future without a different premise.


## 8. THE RESULT (SWEEP9, 22 OCT ~03:25Z) AND WHAT FOLLOWS

**8.1 By s5's rule: no geometry is MEANINGFUL** (`research/replay/results/sweep_notes.md`, sweep9 RESULT;
`sweep9/sw9_report.md`). Against OPT live (`a7e7n7`, net -361, worst -608) every daily offset ratio is <= 0 but one
(+0.00). On the days OPT loses, the wide arm mostly loses too (12 and 14 Oct both negative). By s7's letter: "no
offset anywhere" - at the scale of days.

**8.2 At the scale of the period, the offset is there.** Net rises with the add (cap 7, add = exit: 4 -1,861; 7 -361;
10 +128; 14 +378; 18 +532; 20 +597; 23 +454; 27 +465), and every cap 8 cell with add >= 14 is positive at every exit
(+126 to +862). OPT + ALT: with `a23e23n7` +93, `a27e27n7` +103, `a18e18n7` +170, `a20e20n7` +236; with DUP (2 x ALT)
+548 to +832. sweep8's calm weeks: OPT + ALT q95 +299, q90 +306. **The live two-arm set was positive on EURUSD in both
regimes: OPT carries the calm weeks, the wide arm the rolling fortnight.** This reading is post hoc (s5 was daily) and
in-sample for the t1 adds; the whole 14-27 band being positive, not one cell, is what makes it more than a fit.

**8.3 The operator's reading (22 Oct ~03:34-03:43Z; first written ~23:34-23:43Z: local EDT, corrected HANDOFF s88):** ALT is cheap insurance; a second ALT (DUP) at about the same
adds makes it work harder when it works; ALT rolls mean "we are screwed anyway", and should be rare. **Claude's
caveat:** the cost of the insurance in calm weeks is small (ALT about -20 over sweep8's eight weeks), but the tail is a
slow one-way drift larger than ALT's stack: sweep8 carried 3 Aug - 25 Sep, ALT realised +747 and held **-1,444 pips
open** at the end (EURUSD 1.1545 to 1.1711, then down to 1.1312, ended 1.1393); with DUP the carried loss is -1,475 /
-1,549. A weekly flat start hides it; a live book does not. ALT's roll steps and its open book are the live signal.

**8.4 What follows (operator: "proceed as you recommend", 22 Oct ~03:43Z):**
- **(A)** E runs OPT + ALT on its six pairs with **narrower ALT adds**: q80 / q85 of the excursion method
  (`research/alt_adds/`, on D's archives of 1-16 Oct) in place of q90; the operator picks; E attached from Thu 22:05Z.
  DUP is read afterwards by doubling ALT's contribution; a real DUP arm only on C's ring (C160), three pairs, so the
  slots allow it.
- **(B)** The same surface per pair (tick dumps of 1-21 Oct from wine-d), pre-registered, to check that EURUSD's band
  is not EURUSD's alone.
- **Watch, live:** ALT's roll steps and open book per pair (8.3). If ALT rolls through a drift, that is the tail, not
  noise.

**8.5 (A) done (22 Oct ~04:15Z, HANDOFF s88; `research/alt_adds/results_2026-10-22.md`).** q80 has no single answer
(several fixed points of the exit = add solve on EURUSD, GBPUSD and AUDCAD: the seed decides); q85 puts EURUSD at 15,
where sweep9's OPT + ALT is +17 (14) to +129 (16), no better than t1's 23 (+93); sweep9's 18 - 20 band sits at q87 -
q88. **The operator: q88 on all six** (ALT add = exit 21, 18, 16, 26, 20, 9; `ea/presets_e/*_alt_e_t2.set`), chosen to
land EURUSD in the band (in-sample; (B) checks the other five).

**8.6 (B), sweep10 (22 Oct ~15:15Z; `sweep_notes` sweep10): EURUSD's answer does not carry to E's other five.** By the
rule ruled before the runs: the offset at q88 on 2 of 5 (GBPUSD barely, CADCHF), no retune anywhere. OPT lost on every
pair (-168 to -727 pips); ALT at q88 made +11 to +181 on four and -432 on EURGBP (a one-way fall); OPT + ALT negative
on all five. E's six as one fleet over 1-20 Oct: OPT -$310, OPT + ALT -$264 (worst -$358), with DUP -$217. **By s7: "some
offset, none meaningfully" on the five; the loss sits in OPT's tight adds, and only on EURUSD did the wide arm out-earn
it.** What follows is the operator's call (E's set for tonight; whether OPT's geometry, not ALT's, is the next question).

**8.7 sweep11 and E's t3 (22 Oct ~18:50Z to 23 Oct ~03:25Z; `sweep_notes` sweep11; HANDOFF s88 continued 3-5).** After 8.6
the operator dropped the premise that OPT's live adds are fixed ("we should not need to be married to the OPT presets"):
each pair's OPT add from the calm Aug - Sep weeks (OPT's revenue), its ALT add from October (the insurance), by a rule
ruled before the runs. **Over both periods, at 0.01 lots, the six as one fleet: t3 +$231 against the staged t1 + t2's
-$300.** Per pair, both periods, pips: EURUSD +399, GBPUSD +1,004, EURGBP -461, AUDCAD +1,271, AUDCHF -29, CADCHF +532.
Three picks are the operator's, made after the nets were read (AUDCHF OPT 14, GBPUSD OPT 9, EURGBP ALT 23): disclosed
as post hoc. E attached on t3 23 Oct 03:04-03:25Z; its first fill 03:29:01Z.

- **Where s1's question stands:** in-sample, the two-set geometry ends positive over both regimes on four of the six
  pairs and as a fleet; EURGBP (a one-way fall in October) and AUDCHF (a one-way drift up in four of the calm weeks)
  are the trend cases where nothing here earns. Out of sample is live: E's weeks, beside D's t1 set on the same six
  pairs. **Status: OPEN, E's live weeks against D are the test** (the previous chat's reading, 23 Oct; CONFIRMED by the
  operator 24 Oct ~03:50Z, HANDOFF s90).
- **Not yet measured:** the calm-period drift at the t3 adds (weekly flat starts hide it, 8.3); ALT's live roll steps
  and open book per pair; whether a first-week read may reload E (not ruled; E's runbook s10 still says no change
  except for a defect).

Line count: 201
