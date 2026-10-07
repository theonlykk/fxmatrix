This message has a line count at the bottom

# COMPASS AMENDMENT -- A ROUND IS DECIDED ON EQUITY, NOT REALISED (FROM ROUND 2)

| | |
|---|---|
| Status | **RULED by the operator 7 Oct ~14:53Z** ("this example is a compelling reason why the original approach was flawed. proceed"); **REVIEWED ~15:05Z (Gemini GQ7-1..4, Claude's check, s7): the COHORT decides (operator ~15:07Z "proceed")**. Written BEFORE round 2's window opens (7 Oct 22:00Z): a pre-registered amendment. s2 states the rule as first drafted; s7 the rule that stands |
| Changes | compass-round s1 (what decides) and s4.2-s4.4 (scoring); `research/compass/equity_score.py` decides, `compass_score.py` (realised) is reported beside it, unchanged |
| Sources | HANDOFF s64 (7 Oct); compass-round s1, s4; `docs/research/compass-round2-review.md` s6 (GR2-2); ADR-165 s5 |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | The rule until now: realised all-in P&L per pair and side per day decides; open MTM is reported (operator 2-3 Oct; 6 Oct after GR2-2) | compass-round s1; round2-review s6 | VERIFIED |
| K2 | Re-roll (ADR-165, ON on B, C, D since 5 Oct): a fully rolled side moves the rolled layer with the highest VL; when that exit fills, the layer's whole loss from its ORIGINAL entry is realised at once | ADR-165 s4.2, s5; `grind_engine.mqh` `Grind_LatticeRerollIndex` 964 | VERIFIED |
| K3 | 7 Oct EURUSD long, B (anchor, add 7) vs C (add probe, add 6), broker day to 13:36Z: scalps 13 / +$12.04 vs 15 / +$13.76; roll closes B 4 / -$35.24 (two OLD re-rolled layers: -$16.48 at 09:02Z, -$9.40 at 13:19Z from entry 1.12746) vs C 5 / -$12.41 (first rolls of recent layers). C realised its old EURUSD losses on 5 Oct night (9 re-rolls, "-618 pips, -$65") | study export `study_2026-10-07_1336.jsonl` (sha256 `79eb2326354861a8`); HANDOFF s58 | MEASURED |
| K4 | A loss realised from an inherited layer was already in that fleet's open MTM before the round: realised counts it, equity does not (it moves from open to closed) | arithmetic; `equity_score.py` E3 | VERIFIED |
| K5 | The holdout (C125) and the roll gate (C133) are already judged on equity | holdout criteria s2 V; backlog C133 | VERIFIED |
| K6 | `equity_score.py`: tests first E1-E13 (11 failing at the stub; E12 the guard that `compass_score.decide` is unchanged), 13/13, seventeen mutations caught; no IC bid/ask dump exists for round 1, so its first real run is round 2 | `research/compass/` | VERIFIED |

## 1. WHY

Under re-roll, WHEN a loss is realised is set by each fleet's inherited book,
not by the lever the probe tests (K2, K3): two fleets that traded a pair-side
alike in the round can differ by tens of dollars of realised loss because an
old layer happened to close on one of them inside the window. Realised P&L
then scores history, and GC-1 (the control's gaps) can only widen the
threshold against it, not remove the bias. On equity, an inherited loss
realised in the window nets out against the open MTM it carried at the start
(K4); what is left is how each book did on the same ticks.

## 2. THE RULE AS FIRST DRAFTED (plain equity; SUPERSEDED by s7: the cohort decides)

Per instance side and window (a, b) of the round:
- change = cash + mark(b) - mark(a);
- cash = open commissions of layers opened in [a, b) + closeby_net and exit
  commission of layers closed in [a, b);
- mark(t) = open MTM of the side's layers open at the end of the minute ending
  at t, at the MID close, pips x USD per pip (`compass_score.pip_values`).
Score = sum of the windows' changes / days. Margin = probe - comparator (the
anchor). WIN if margin > GC-1, LOSE if < -GC-1, else REPEAT; no add-probe
gates. GC-1 = max(the round file's threshold, the median of the control pair's
six same-settings EQUITY gaps). UNPRICED (not decided) when a marked layer has
no open price. Cuts and VOID as before. Realised margins are printed beside.

## 3. WHAT THE SCORING NEEDS (round 2, Fri 9 Oct after the close)

1. `archive_counts.py --export-archive` (every layer's open price, however old:
   the 14-day study export may miss layers opened before it).
2. The IC bid/ask dump from BEFORE the round: `grind_bidask_dump.mq5` on wine-c
   with `InpFrom` = `2026.10.07 23:00` (server; = 7 Oct 20:00Z), so the mark at
   7 Oct 22:00Z exists.
3. `python research/compass/equity_score.py --export <archive> --round
   research/compass/round2.json --bidask <folder>` (decides), then
   `compass_score.py` (realised, reported) and `fill_slippage.py` as planned.
   (s7: `equity_score.py` decides on the cohort; `round2.json` `equity_end`
   = 9 Oct 20:45Z, then 8 Oct 22:30Z when round 2 was moved to start at the
   build and end Thu 8 22:00Z, s8.)

## 4. NOT CHANGED

`compass_score.py` (realised; still run and reported); the round windows, the
probes, the control, GC-1's base; promotion to FTMO (compass-round s8); the
holdout. The scorer is not changed during the round: `equity_score.py` is
fixed at the commit that carries this document.

## 5. KNOWN LIMITS

- Equity is noisier than realised (open books swing); the control's equity
  gaps carry the same noise, so GC-1 rises with it.
- A probe's lever changes its book, so part of an equity margin is the
  inventory the lever built: that is the lever's effect, wanted.
- Accrued swap is in the close (cash) but not in the marks: cents a night at
  0.01.
- Two days a round: as before, REPEATs pool over rounds while the structure
  is unchanged (GC-2).

## 6. FOR GEMINI (attack the premises; say which fact is missing)

- **GQ7-1. Marks at the mid of the 21:59Z minute.** The window boundaries are
  22:00Z, inside IC's rollover hour (wide spreads). Mid marks keep that spread
  out of each side's MTM; the alternative is marks at 22:30Z (holdout T3c's
  time), which then differ from the cash windows' boundaries. Which, and why?
- **GQ7-2. No add-probe gates.** The entry-time split and per-layer-hour gates
  guarded against an add probe "winning" realised by timing; equity counts the
  open inventory the probe built. Any reason to keep a gate?
- **GQ7-3. Attribution.** An alternative is a cohort score: only layers opened
  inside the round (their cash plus their end mark), so inherited inventory
  drops out entirely, but so does the inherited inventory's price risk that a
  lever changes (a wider exit leaves more layers open into the round). Is
  plain equity the right unit, or the cohort?
- **GQ7-4.** What fact is missing for a two-day round decided on equity?

## 7. GEMINI'S RULINGS (7 OCT ~15:05Z), CLAUDE'S CHECK AND THE OUTCOME

Gemini read this file as an attachment; his answers pasted by the operator.
- **GQ7-3 ACCEPTED: the COHORT decides** (operator ~15:07Z "proceed"). Plain
  equity still carries every inherited layer's price change through the
  round (a 7-layer side moving 50 pips is ~$35), larger than a one-pip edge,
  and the fleets' inherited books differ. The cohort counts only layers
  OPENED inside the round: open commissions + closes before the end + the
  mid mark at the end of those still open (`cohort_side`). Inherited
  inventory, including K3's old EURUSD layers, counts nothing. A lever's
  longer effects show in the pooled REPEATs (GC-2). Plain equity and
  realised margins are printed beside the cohort's.
- **GQ7-1 ACCEPTED in effect, mechanism unverified.** A cohort has no start
  mark (it starts at zero). The end mark moves off the boundary: round 2
  ends at Friday's close, so `equity_end` = **9 Oct 20:45Z** (the holdout's
  Friday mark, T3c), before the thin last minutes; a weekday end later uses
  22:30Z. His "skewed mid in the rollover hour" was not measured; moving the
  mark costs nothing.
- **GQ7-2 REJECTED as a gate, reported.** His premises do not hold here (cap
  8, not 10; slots bind, not margin; FTMO is not in the compass). Cohort
  equity per layer-hour is printed for each probe.
- **GQ7-4 AGREED as a watch.** If the control's cohort gaps exceed any
  one-pip edge, rounds REPEAT: GC-1 is printed every round, and the cohort
  is far less noisy than plain equity.
- **8. ROUND 2 MOVED (operator 7 Oct ~15:27Z).** Round 2 starts at the build
  (7 Oct 02:25Z, after the last gate Load 02:22:50Z; nothing structural since)
  and ends Thu 8 Oct 22:00Z, scored Thursday evening; round 3 reloads Fri 9.
  Under the cohort a round needs no 22:00Z start. `equity_end` = 8 Oct
  22:30Z (a weekday end). Set after a partial look at 7 Oct data (the roll
  counts; EURUSD long B vs C realised); no probe's cohort P&L was computed
  (`round2.json` `window_note`). The IC dump must start by 7 Oct 02:25Z:
  `InpFrom` `2026.10.07 04:00` (server).
- Built: `equity_score.py` `cohort_side`, `round_span`; tests C1-C9, E14
  (C1-C8 and E11 failing at the tests-first commit; C9 and E14 for two
  mutation survivors); 23/23; fifteen mutations caught (re-run without
  bytecode caching after a stale-.pyc trap).

Line count: 132
