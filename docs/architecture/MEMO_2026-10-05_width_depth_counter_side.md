This message has a line count at the bottom

# MEMO -- WIDTH, DEADBAND, DEPTH AND THE COUNTER SIDE (5 OCT)

| | |
|---|---|
| Status | **Record of a discussion** (operator and Claude, 5 Oct ~18:10Z-19:00Z). Decisions marked as such; everything else is a proposal for Gemini or a later round |
| Backlog | C103 (counter-side width), C127 (counter side at 0.02: designs), C128 (cap as a compass lever), C48 / C39 (plane fit) |
| Sources | `ea/grind_engine.mqh` ~3130-3145 (L0 at mid +/- W each tick a side is empty), 2946-2990 (re-centre); `ea/grind_pure.mqh` 9-10, 41-52 (the add / width guard); ADR-153 s1 ("They exist to catch typos and nonsense, not to encode a quoting design"); `docs/research/ejection-value-study.md` s12; `docs/research/markout-variance-study.md` s4.1; `docs/research/holdout-verdict-criteria.md` K8; FTMO cycle-3 presets `ea/presets/*_opt.set` |

## 1. THE OPERATOR'S POINTS

1. **This week is compass iteration.** "We dont have that many levers":
   add and exit per side, and layers. Control realised P&L through add /
   exit first; whether equity follows is the next problem; no complete
   solution at once. Realised decides each round (scalps + rolls +
   ejections); scalp P&L is reported beside it.
2. **The flat side must enter as fast as possible, passively.** "Without
   it we are literally just fading moves." With longs adding every 10
   pips in a fall and the short side's entry 2 pips away, a short is
   about five times more likely to fill than the next long add (on a
   random walk: P(+2 before -10) = 10 / 12); a 10-pip short exit then
   offsets about one long layer. It does not stop a trend; it turns part
   of it into scalps.
3. **The deadband stays** (requests), as low as evidence allows.
4. **One counter entry battling eight** is what made 0.02 lots
   attractive; partly retracted: maybe fewer layers (4 or 5) instead.
5. **Span against granularity:** the layers must span a cluster of
   trades (cap x add); a wider add spans more but loses granularity. A
   trade-off to learn from the compass, and perhaps a plane fit over
   (add, exit, cap) (C48, C39).

## 2. WHAT THE CODE AND THE DATA SAY

- **The add / width bound is a typo check, not a design.** `OnInit`
  refuses add / width outside [0.5, 4.0] (ADR-153: "a typo of 40 instead
  of 4"). Nothing in the trading ties width to add. It is the only thing
  keeping widths above add / 4 (GBPUSD add 9: width >= 2.25).
- **Re-entry after a scalp is already "width from the last exit".** Each
  tick a side is empty, its L0 goes to mid +/- W (passive, clamped).
  When a long side's last layer scalps at X, mid is about X, so the new
  buy rests near X - W: never at or above the sale while W exceeds half
  the spread (IC medians 0.1-0.5 pips). No new rule is needed; W small
  but not zero.
- **The deadband dilutes the 5-to-1.** The empty side re-centres only
  after drifting max(D, S - W). On IC (S = W + 1 since 2 Oct, D 4) the
  counter entry sits 2-6 pips from the market with W 2, nearer 2.5-to-1
  than 5-to-1.
- **On FTMO the deadband is not what binds:** cycle-3 presets have S =
  2W (or W + 5 / W + 7), so the drift that re-quotes is 5-7 pips. Lowering
  D alone changes nothing there; S = W + 1 is needed too.
- **Request cost (replay of the re-centre rule on FTMO minute mids, 20
  Sep - 2 Oct, the seven ring pairs; the other side assumed always held,
  so counts are an upper bound; measured 2 Oct: 0-8 L0 re-quotes per
  instance-day):** relative to today, S = W + 1 with D 4: re-quotes 1.5x,
  counter fills +12%; D 3: 2.1x, +26%; D 2: 3.1x, +38%. L0 re-quotes were
  about 1.4% of FTMO's requests (~20 a day), so D 3 costs some 20-40 a
  day against 2,000.
- **Counter-side fills, first pass (old widths 3-7):** 429 of the 463
  empty-side fills were counter-side; their 4-hour markout -5.6 pips
  (the bounce that fills them kept going). Tighter widths fill on smaller
  bounces: a different set of fills. Holdout T4 reports it this week.
- **Depth, first pass:** the deepest layers were the best entries
  (depth 6-7 +2.2 pips at 4 h, +5.4 at a day; 8+ +2.5 at 4 h).
- **Cap, ejection study s12 (interim, 30 Sep):** closed P&L rises with
  cap on every fleet; closed + open flattens around cap 8-9 (extra
  closed P&L of a higher cap is mostly loss deferred into open); risk
  grows steadily: from cap 5 to 10 the worst day 1.9x (A), 2.4x (B),
  3.4x (C). Per instance the best cap differed (week-specific paths).
- **Lowering the cap on a live book halts it:** I7 fails when a side
  holds more layers than the cap (not quarantinable; BOOT s1). With
  re-roll on, capped sides stay at 8: a reload to cap 5 halts every side
  above 5 unless it thins out or is ejected by hand first. Raising is
  safe (cap10-reload K1).
- **0.02 lots on one order needs C14** (partial fills: exits are placed
  for `InpLots`). Two 0.01 orders avoid it.

## 3. DECISIONS (5 OCT)

1. **Cap 8 this week** on B, C, D; cap 10, the fixed-width table and the
   AUDUSD scout wait. Round 2's reload Tue 6 Oct in session carries the
   new widths, the deadband and the probes together: one reload, not
   cap10-reload GW-1's two (its reason, the slot load at cap 10, does not
   arise at cap 8). Rounds of two FTMO days; round 2 Wed 7 + Thu 8,
   round 3 from Fri 9.
2. **Widths: the tightest the guard allows, the same on B, C, D**
   (ceil to the half pip of the round's largest add / 4): about 1.0 on
   AUDCHF, CADCHF, NZDCHF and EURGBP; 1.5 AUDCAD; 2.0 EURUSD, NZDCAD,
   AUDNZD; 2.5 GBPUSD (from round 1's verdict tonight). A pair whose add
   later steps wider re-derives its width (structural for that pair).
3. **Deadband 2 on B, C, D** (S = W + 1 kept), in Tuesday's reload.
4. **FTMO: S = W + 1 and D 3 after the holdout** (not before: V needs A
   unchanged to Fri 9 Oct, or 16 Oct if extended; the frozen cycle
   allows stranded and deadband changes, geometry-cycle3 A1).
5. **Re-roll ON tonight** (the Monday build): a capped side whose layers
   are all rolled keeps re-rolling; twins retired; nine instances per IC
   fleet.

## 4. PROPOSALS (for Gemini; one document, after tonight's build)

- **Width guard (C103 step 2):** replace the ratio with absolute bounds
  that still catch typos (e.g. width >= 0.5 pip and <= 2 x add), so
  widths can reach about 1 pip on every pair. EA change: tests first,
  Gemini, Cursor, the suite; not in tonight's build (runbook s3.3);
  a later IC build with or after v2.2a.
- **C127, the counter side at 0.02 (two designs):** (a) a tight FIRST
  add on the counter side (1-2 pips) used only while the other side is N
  or more layers deeper: the second 0.01 follows at once, a pip or two
  better, one instance, one input; (b) a counter-only twin per pair (ALT
  magic, cap 1, trades only the side opposite the primary's deep side
  while the imbalance is N or more, reading the primary's depth from the
  cap-exposure Global Variables): exactly 0.02 at one price, more moving
  parts (peer read, magic, presets, pipshed lists), few slots if rare.
  Claude's lean: (a).
- **C128, the cap as a compass lever:** one IC fleet at cap 5 against B
  at 8, everything else equal, as its own structural round after this
  week's add / exit rounds; that fleet's sides must hold 5 layers or
  fewer at its reload (watched, or ejected by hand). Answers depth vs
  span with our own P&L. Later: a plane fit over (add, exit, cap) from
  the compass rounds (C48, C39).

Line count: 122
