This message has a line count at the bottom

# RUNBOOK -- THE CAP-10 RELOAD (IC FLEETS B, C, D)

| | |
|---|---|
| Status | **REVIEWED 4 Oct ~03:05Z** (Claude's draft s50; Gemini GW-1..GW-6, s9; the operator on GW-4). The width TABLE is filled from round 1's verdict (Mon 5 Oct after 22:00Z) and reviewed with the round's verdict table (compass-round s4 step 7) |
| Backlog | C99 (cap 10 + fixed widths), C96 (AUDUSD scout), C88 (wine-c loads the Scripts copy), C91 (round 2 scoring) |
| Sources | compass-round s3, s4, s6, s7; monday-build (the pattern); 02_TRAPS 1 Oct C63, D1, 2 Oct day, 3 Oct afternoon; ADR-123, ADR-153, ADR-162 s13-s15, ADR-165; source at `36a7ff3` (EA code = `2859be6`) |
| When | The first in-session slot after Monday's scoring AND the Monday build: in session, spreads normal, never 20:50-21:15Z, not within 30 minutes of a tier-1 release, never with the market closed. Operator picks the slot |

## 0. AUDIT TRAIL (source at `36a7ff3`; EA code `2859be6`, the build B, C, D run after Monday)

| # | Fact used | Where | Status |
|---|---|---|---|
| K1 | Raising `InpMaxLayers` cannot trip I7: it fails only on `count > max_layers` | `grind_recon.mqh` 483-491 | VERIFIED |
| K2 | The lattice acts only at `depth >= max_layers` (`Grind_LatticeTrySide` breaks below cap); below cap the side adds through `Grind_EnsureAddNext` | `grind_engine.mqh` `Grind_LatticeTrySide` (loop head) | VERIFIED |
| K3 | The add target anchors on the deepest layer's entry, or, once ANY layer on the side has a VL, on the lowest effective entry (long; highest short) minus add. VLs persist (one GV per position): a side rolled at cap 8 keeps its VLs at cap 10 | `grind_engine.mqh` 2170-2207; ADR-165 R4 | VERIFIED |
| K4 | An add target already passed by the market is clamped PASSIVE (`Grind_Adr013ClampBuy` / `ClampSell`: to the passive side of bid / ask by the stops level) and placed: a side whose next level was already crossed gets its add at the market and it fills on the next touch | `grind_engine.mqh` `Grind_EnsureAddNext` (after `Grind_ComputeAddTarget`) | VERIFIED |
| K5 | A flat side's resting L0 is place-once (ADR-123): `Grind_TryPlaceL0` leaves a resting L0 untouched; a new width applies at the NEXT L0 placement (after that L0 fills and its layer closes) | `grind_engine.mqh` 1969-1990 | VERIFIED |
| K6 | An empty side opposite a holding side re-centres its L0 to mid +/- W only when it sits more than S from mid AND the move is at least the deadband D (strict `<` inside); with S = W + 1 and D = 4 the drift that re-quotes stays max(D, S - W) = 4 | `grind_engine.mqh` 2946-2990, 3144-3149; `grind_pure.mqh` 249-252; ADR-153 | VERIFIED |
| K7 | Guard: a near-market entry needs `positions + orders + resting_ent <= 200 - 2 - GRIND_SLOT_MARGIN(4)` = 194; a far entry also needs `InpSlotNearReserve` (8 in every preset) more: 186 | `grind_exitq.mqh` 173-183; `grind_config.mqh` 9 | VERIFIED |
| K8 | `OnInit` refuses add / width outside [0.5, 4.0] on the base inputs and on each resolved side (FATAL, the EA is UNLOADED: A17 of the v2.2a prompt) | `fxgrind.mq5` 174-200; `grind_pure.mqh` 41-52 | VERIFIED |
| K9 | The CONFIG line prints `InpWidthPips`, `InpAddPips`, `InpExitPips`, `InpMaxLayers`, `InpStrandedThreshPips`, `InpDeadbandPips`, the instance and `key=` STATUS (never the key); `GRIND_GEOMETRY` prints each resolved side; `GRIND_REROLL enable=` and `LATTICE_CONFIG` follow | `grind_config.mqh` 59-90; `fxgrind.mq5` 352-367 | VERIFIED |
| K10 | A chart loads the `.ex5` at the path it was attached from; a reason-5 reload keeps it; wine-c's charts load `Scripts\fxmatrix\fxgrind.ex5`; MT5 writes chart profiles only on exit, so the proof of the loaded build is the INIT record's `ea_build` = the `.ex5` modified time | 02_TRAPS 1 Oct C63, 2 Oct day; backlog C88 | VERIFIED (traps) |
| K11 | The Monday build compiles wine-c's Scripts copy only (runbook monday-build 3.5); its Experts copy gets the same sources (3.4) but its `.ex5` is not rebuilt that night | monday-build 3.4-3.5 | VERIFIED (runbook) |
| K12 | AUDUSD presets B, C, D exist: magic 22261001, `GRIND_AUDUSD_OPT{B,C,D}`, 2 / 6 / 10, cap 10, S 3, D 4, lattice + re-roll on, breaker off, auto-eject off, key blank | `ea/presets_{b,c,d}/audusd_opt_*_c10.set` (`4694471`) | VERIFIED |
| K13 | `compass_score.py` reports the control-pair threshold (GC-1) from a round file's `control` block; scout baseline gaps are NOT pooled (GW-6: they stay out) | `research/compass/compass_score.py` (`36a7ff3`) | VERIFIED |
| K14 | One resting add per side: `Grind_SendNextAddEnt` refuses while the side's add order is selectable, the next index is the deepest layer index + 1, and one ENT is sent per tick (`g_grind_ent_sent_this_tick`); so after a cap rise L9 must FILL before L10 is placed, and L10 anchors on L9's entry: two adds cannot stack at one price (Gemini's K4 re-check) | `grind_engine.mqh` `Grind_SendNextAddEnt`, `Grind_EnsureAddNext`, 1941-1952 | VERIFIED |
| K15 | The magic lock: `Grind_MagicLockClaim` fails if the lock GV exists; `OnDeinit` releases it (C89: even after a failed init) | `grind_magic_lock.mqh` 18-48; `fxgrind.mq5` 220, 379 | VERIFIED |
| K16 | The API thresholds are 999000 (soft warn) and 1000000 (entry stop) since the 2 Oct hotfix (C100): `WARN_API_SOFT_LIMIT` / `WARN_API_ENTRY_STOP` cannot fire on an IC day | `grind_api_counter.mqh` 14; `grind_config.mqh` 11 | VERIFIED |
| K17 | IC spreads (wine-c dump, 24-30 Sep, every minute, nine pairs): median 0.1-0.5 pips; spread > 2 x the s2 width in 0.00% of minutes outside 21Z (NZDCHF 0.06%); inside the 21Z hour 94-100% on the crosses at 1.5, and at 2.5 still 99-100% on all but EURGBP (31%); today's widths 46-96% on the crosses there (s9 GW-4) | `bidask_ic_0930.tar.gz` (Downloads), minute closes | MEASURED |

## 1. WHAT CHANGES

- **Cap 8 -> 10** on every IC chart (27 + the three AUDUSD).
- **Width fixed per pair** (compass-round s6, GC-7): (anchor add + 2) / 4,
  rounded UP to the half pip, from round 1's VERDICT anchors (s49:
  not today's B values). `InpStrandedThreshPips` = new width + 1
  (keeps S >= W - D, K6). Deadband stays 4.
- **AUDUSD scout attached** on B, C and D (ten instances per fleet;
  baseline round, the same geometry everywhere, GC-3).
- **wine-c's charts re-attached from `Experts/fxmatrix/fxgrind`** (C88
  fixed for good).
- **Not changed:** code (`2859be6` from Monday; v2.2a is a separate
  step after this reload, s49), lattice and re-roll ON, breaker off,
  carry on, auto-eject off, FTMO untouched.
- **Round 2's probes are a SECOND reload** (GW-1): this reload carries
  each chart's CURRENT add and exit (B's, C's and D's as they run
  after Monday) with the new cap, width and S only; the probe reload
  follows the hour's watch (s6).
- **Structural** (compass-round s4.1): pools restart; round 2 starts
  after this reload and its watch.

## 2. THE TABLE (filled Monday night from round 1's verdict)

Provisional, IF every round-1 anchor holds (B's adds today). Monday's
promotions change a pair's anchor add and so its width; each changed row
is re-derived and the add / width guard re-checked for the anchor and
both one-pip probes ((a - 1) / w >= 0.5 and (a + 1) / w <= 4.0).

| pair | anchor add (today) | width now | new width = ceil_0.5((a + 2) / 4) | S = W + 1 | guard a / w (a-1, a+1) |
|---|---|---|---|---|---|
| GBPUSD | 9 | 5 | 2.75 -> **3.0** | 4.0 | 3.00 (2.67, 3.33) |
| EURUSD | 7 | 7 | 2.25 -> **2.5** | 3.5 | 2.80 (2.40, 3.20) |
| EURGBP | 3 | 3 | 1.25 -> **1.5** | 2.5 | 2.00 (1.33, 2.67) |
| AUDCAD | 6 | 5 | 2.00 -> **2.0** | 3.0 | 3.00 (2.50, 3.50) |
| AUDCHF | 4 | 5 | 1.50 -> **1.5** | 2.5 | 2.67 (2.00, 3.33) |
| CADCHF | 4 | 5 | 1.50 -> **1.5** | 2.5 | 2.67 (2.00, 3.33) |
| NZDCHF | 3 | 3 | 1.25 -> **1.5** | 2.5 | 2.00 (1.33, 2.67) |
| NZDCAD (control) | 8 | 5 | 2.50 -> **2.5** | 3.5 | 3.20 (2.80, 3.60) |
| AUDNZD | 8 | 7 | 2.50 -> **2.5** | 3.5 | 3.20 (2.80, 3.60) |
| AUDUSD (scout) | 6 | -- | 2.00 -> **2.0** | 3.0 | 3.00 (2.50, 3.50) |

Presets: `ea/presets_{b,c,d}/<pair>_opt_<f>_c10.set` (27 new files; the
three AUDUSD exist), each = the fleet's current live preset with ONLY
`InpMaxLayers`, `InpWidthPips`, `InpStrandedThreshPips` and
`InpConfigWarning` changed (GW-1: no add or exit change in this reload).
Widths of 1.5 stand (GW-4, operator 4 Oct ~03:05Z: "if you have data consistent
with 1.5, then we use your recommendation ... we want to push the
envelope a little - especially with IC"; K17).
Read back per file: input count, key blank, per-side inputs, guard ratio
on base and each side, magic and instance = the chart's.

## 3. BEFORE (desktop and sandbox, before the slot)

1. Claude: the table (s2) from Monday's verdict; the presets; one docs
   patch (presets + this runbook's table + register rows prepared).
   Gemini reviews the table with the round's verdict table.
2. `round2.json` (Claude): windows, the control block (NZDCAD). AUDUSD's
   baseline gaps are REPORTED, not pooled (GW-6), until it has a round
   of history; compass-round s4.3's "and any scout baseline" waits for
   that.
3. pipshed C121 patch ready in Downloads (tree `ac81ba6d` on C119's
   `e3b23a94`): deployed only after the three AUDUSD charts are live.

## 4. PER BOX (wine-d first, GBPUSD pilot; then wine-c; then wine-test)

**4.1 Read the box.** pipshed card: nine LIVE, none halted; guard total
noted; from the quote tables, each capped side's distance to its next
level (italic virtual level and gap), and any side already past it
(GW-3: those add at the market, K4). `git log -1` of the box repo = `main` with the presets commit.

**4.2 Stage the presets with the key** (shell, as root; Claude writes the
exact line from the box's own key file before the night: `sed` the
`TelemetryAPIKey=` line from `~/.fxgrind_telemetry.key` into
`<MQL5>/Presets/<file>` as khalid, never printing the key), then the
`SAME_EXCEPT_KEY` check (c63-commands C1 pattern) over `*_c10.set`:
expected 10 lines `SAME_EXCEPT_KEY key_len=43`.

**4.3 wine-c only: compile the Experts copy** (MetaEditor, F7 on
`Experts/fxmatrix/fxgrind.mq5`; first `cmp` both copies against the repo:
drift 0). No chart loads it (K10), so nothing re-inits; check its `.ex5`
time.

**4.4 Reload each of the nine charts (VNC).**
- **wine-d, wine-test:** F7 on the chart -> Inputs: read
  `InpTelemetryInstance` and `InpMagic` FIRST (02_TRAPS 1 Oct D1) ->
  Load `<pair>_opt_<f>_c10.set` -> read back magic, instance, width,
  cap, S -> OK. Pass: `deinit=5`, CONFIG with the table's values,
  `GRIND_REROLL enable=true`, POST ok, FATAL 0.
- **wine-c (GW-5: Remove, then Attach; no drag over a running EA):**
  right-click the chart -> Expert Advisors -> Remove (Experts log
  `deinit reason=1`; the lock is released, K15); then drag
  `Experts/fxmatrix/fxgrind` from the Navigator onto the now-empty
  chart, Load the chart's `_c10` preset, the same read-back, OK. The
  book is unmanaged only for those seconds; a fill meanwhile is adopted
  at reconstruction (precedent: 1 Oct 06:32Z, NZDCAD_OPTD re-attached
  from Experts after a failed init, clean). Pass as above, plus the
  INIT record's `ea_build` = the Experts `.ex5` time from 4.3 (K10).

**4.5 AUDUSD.** Market Watch shows AUDUSD; open an AUDUSD M5 chart; drag
`Experts/fxmatrix/fxgrind` onto it (Algo Trading is already ON: it
trades on OK); Load `audusd_opt_<f>_c10.set`; read back every row above
`TelemetryURL` (crop: never the key row); OK. Pass: CONFIG, `GRIND_REROLL
enable=true`, `LATTICE_CONFIG` reroll true, POST ok, both L0s placed at
mid +/- 2.0.

**STOP before the next chart or box on:** FATAL (including `duplicate
magic`: a chart left with no EA name top-right, K15), CRITICAL,
`INVARIANT_FAIL`, `RECON_FAIL`, any `AMBIGUOUS_ADD_*` or `AMBIGUOUS_L0_*`
(not expected: K14), any `REBUILD_*` (no exit changes in this reload,
GW-1), a CONFIG different from the table, a magic or instance different
from the chart's, `ea_build` not the expected `.ex5` (wine-c), no POST
ok, the guard total above 194 for more than a few minutes,
`ROLL_ACCEPTED` bursting on more sides than were at cap, or a fleet's
`api_count` rising faster than ~100 in ten minutes (the warnings cannot
fire, K16: watch the count on the card instead).

## 5. EXPECTED (not STOPs)

- **Sides at cap 8 start adding again** (K2). A side whose next level was
  already crossed (fully rolled and past it; Monday's re-roll makes this
  rare) gets its add at the market and fills on the next touch (K4):
  two more lots into the move within minutes (GW-3).
- **Old widths linger** (K5, K6): a flat side's resting L0 keeps its old
  width until it fills; an empty side opposite a holding side moves only
  when more than S from mid and the move is at least 4. The pipshed quote
  tables show both until they phase in (GW-2).
- **More slots:** at cap 10 one deep side per instance is ~18 slots;
  ten instances ~180 of 194, far entries stop at 186 (K7). Watch the
  card's guard total for an hour.

## 6. AFTER ALL THREE BOXES

1. pipshed C121 (`git am`, tree `ac81ba6d`, push, Railway): B, C, D
   strips 10/10 with a "scouts" ring.
2. The hour's watch: guard totals, requests per fleet, any `ROLL_*`
   out of the ordinary, AUDUSD's first fills.
3. Records: register rows (close every IC row at its reload time from
   the log; open the cap-10 rows and AUDUSD's), event log, fleet-c.md
   (C88 closed with the `ea_build` evidence), backlog C88 / C96 / C99.
4. **Round 2's probe reload** (GW-1), after the watch: B's promoted
   anchors, C's adds, D's exits, from Monday's verdict, in `_p2`
   presets; compass-round s4 step 8 pass lines (D's exit probes run the
   ADR-163 rebuild: `rebuild=true/true` expected there, nowhere else).
5. Round 2 opens at the next 22:00Z after the probe reload (two FTMO
   days).

## 7. NEGATIVE SPACE

No EA code change, no compile except wine-c's Experts copy (4.3), no
v2.2a, no FTMO change, no change to exit or lattice / re-roll / breaker /
carry / auto-eject inputs (round 2's probes are the second reload, GW-1),
no hand deletes of resting orders (GW-2), no reload 20:50-21:15Z or with
the market closed, no Navigator drag over a running EA anywhere (wine-c:
Remove first; wine-d and wine-test: F7 only), never a screenshot
showing the key row.

## 8. FOR GEMINI (attack the premises; say which fact is missing)

- **GW-1. One reload or two?** compass-round s7 plans the cap-10 reload,
  an hour's watch, then round 2's probe reloads (two reloads per chart,
  ~57 in all). Proposal: put round 2's probe values (C's adds, D's exits,
  from Monday's verdict) into the SAME `_c10` presets, so each chart
  reloads once (30 in all). s4.1 holds either way: round 2 still starts
  after the last structural change and its watch (the watch runs before
  the next 22:00Z window). Cost: D's exit probes run the ADR-163 rebuild
  inside the same reload (live since 1 Oct, clean), and a STOP mid-box
  leaves both changes half done on that box. Claude's lean: one reload.
- **GW-2. Widths phase in** (K5, K6). Alternative: delete every flat
  side's resting L0 by hand so the EA re-places it at the new width:
  ~30 hand deletes on live charts, a path never run on purpose. Claude's
  lean: let them phase in; the change is alike on B, C, D, so the
  compass comparison is unaffected.
- **GW-3. A side past its next level when the cap rises** gets its add
  at the market (K4). Accept as expected, or hold such sides (no input
  can; only a later reload)? Claude: expected; it is what cap 10 is for.
- **GW-4. Widths of 1.5 on EURGBP and the CHF crosses.** When half the
  spread exceeds the width (rollover, news), the L0 clamps to the
  passive side (K4's clamp) rather than crossing: a wider effective
  width, no harm. IC's raw spreads per pair by hour are not measured
  (FTMO's were, 20 Sep - 2 Oct). Missing fact?
- **GW-5. wine-c's move to the Experts copy** by Navigator drag with the
  `_c10` preset (4.4). The replaced EA's deinit reason and the magic
  lock hand-over (C89: a failed init frees the live holder's lock) are
  the risks; the pass is `ea_build` = the Experts `.ex5`. Any failure
  mode not on the STOP list?
- **GW-6. AUDUSD's baseline gaps in the threshold pool** (s3.2): the
  control's six plus AUDUSD's six, median of twelve. Right, or keep the
  scout's gaps reported only until it has a round of history?

## 9. GEMINI'S RULINGS (4 OCT ~03:00Z) AND CLAUDE'S CHECK

Gemini read this file as an attachment (no repo access), so K1-K13 were
taken as Claude's verified facts; he asked for K4 to be re-checked
(K14). Two passes, the same rulings; checked in source and data by
Claude; the operator accepted (GW-4 by data, 4 Oct ~03:05Z).
- **GW-1 ACCEPTED: two reloads.** Diagnostic isolation is the reason
  that stands. His "live FTMO-track book" is wrong (IC demos), and the
  missing fact (minutes saved) is a second pass of ~27 reloads and
  probably a day on round 2's start. s1, s6.
- **GW-2 ACCEPTED: widths phase in.** His reason (a hand delete "risks
  I3_NAKED / I4_ORPHAN_EXIT") is not the mechanism: I3 is a position
  with no exit, I4 an exit with no layer; a missing resting L0 order is
  neither. Moot.
- **GW-3 ACCEPTED as expected; his re-check ANSWERED (K14):** the two
  new layers cannot stack at one price: L10 is placed only after L9
  fills and anchors on L9's entry. Margin at 0.01 lots on a $10k demo
  is small. His missing fact (how far past its level a side sits) is
  read before each box (4.1). With re-roll ON since Monday a side past
  its next level should be rare (ejected layers or the rollover pause).
- **GW-4 REJECTED on data (operator):** his premise ("1.5 consistently
  consumed by the spread", "severe API churn") fails on K17: outside
  the 21Z hour the spread never reached twice a 1.5 width in a week of
  minutes; inside it his 2.0-2.5 floor and most of today's widths are
  inside the spread too, so the floor costs a pip all day for nothing
  at 21Z. Churn: a flat side's L0 is place-once (K5), an empty side's
  moves only after 4 pips of drift (K6); L0 modifies were 1.4-2.8% of
  requests (C103 `--l0churn`). Operator: 1.5 stands ("we want to push
  the envelope a little - especially with IC").
- **GW-5 ACCEPTED: Remove, then Attach** on wine-c (4.4). His mechanism
  (overlapping OnDeinit / OnInit on one chart) is not verified either
  way; the sequential route has a clean precedent (1 Oct 06:32Z) and
  removes the question.
- **GW-6 ACCEPTED: AUDUSD's gaps reported, not pooled** for round 2
  (s3.2). His "corrupts the noise floor" overstates it (the threshold
  is a max with $1.19, it can only rise); the round of history is the
  reason that stands.
- **STOP additions:** `AMBIGUOUS_ADD_*` and a magic-lock FATAL ADDED
  (s4); `WARN_API_SOFT_LIMIT` / `WARN_API_ENTRY_STOP` cannot fire since
  the 2 Oct hotfix (K16): replaced by a watch on each fleet's
  `api_count`.

Line count: 265
