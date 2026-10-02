This message has a line count at the bottom

# FLEET D -- WINE-D (IC MARKETS DEMO 53077984): PRE-REGISTRATION

Status: D0 written by Claude 1 Oct ~04:35Z on the operator's decision
("lets go with your recommendation - we want to make compass probe part
of our routine"). D0 is not reviewed by Gemini: it changes nothing that
B or C run, and the probe design (D1) is the document that goes to him.
Box: `06_LINUX_WINE_BOX.md` s10; backlog C85; cycle-4 note s8.3-s8.5,
s8.12 step 5.

## 1. SETUP

| | |
|---|---|
| Account | IC Markets demo **53077984**, `ICMarketsSC-Demo`, Hedge, Raw Spread, USD, 1:100, $10,000 |
| Box | wine-d, 216.128.158.33, Ubuntu 24.04, Wine 9.0 (06 s10); RDP via tunnel to local 3392 |
| Code | `main` `0335f25` (v2.1 + ADR-164 + C77), as on B and C; Experts and Scripts copies identical to the repo (06 s10), suite 2368/2368 once before any attach |
| Presets | `ea/presets_d/*_d_lat.set` (11): `presets_c` `_lat` files with only `InpTelemetryInstance` (`_OPTD`/`_ALTD`) and `InpConfigWarning` changed |
| Telemetry | key from `~/.fxgrind_telemetry.key` (sha `fc6b3d9c56a8`); page `https://linuxd.pipshed.com`; pipshed `GRIND_D_INSTANCES` = the 11 ids |
| History | starts with the C78 probe's deals (magic 99078001, 1 Oct 02:50-02:52Z): exclude them from any study |

## 2. PHASES

**D0 -- anchor settings, lattice on (from the attach, 1 Oct).** Fleet B's
current settings exactly (the B1 dial, cap 8, `InpVirtualLattice=true`,
`InpAutoEject=false`, carry on, commanded eject on, breaker on, session
off), starting FLAT. What it gives before any probe: the box proven live
(WebRequest, telemetry, Wine), and a fresh-ladder fleet on the same
settings as B and C, whose books are inherited (fleet-c.md s2's optional
comparison, now a whole fleet).

**D1 -- the first compass probe (after the roll-watch).** Per the
cycle-4 note s8.4: B holds the anchor, C and D the probes, one lever one
pip from the anchor per pair and side, on the side the evidence points
to. The first directions (s8.11 OPEN) go to Gemini as this file's D1
amendment, with the roll-watch and study evidence; deployed by preset
reload in session (v2.1 rebuilds exits on a live book). Operator, 1 Oct:
compass rounds are to become routine; ~05:25Z: "i really want to put the
correct compass probe points on fleet d" -- D1 is next, ahead of the
roll-watch (HANDOFF s26 NEXT SESSION item 2 lists the anchors and the
decisions in order).

## 3. ATTACH (D0)

In session, spreads well under every width, not 20:50-21:00Z, not
within 30 minutes of a tier-1 release.
1. Presets staged on wine-d with the key; 11 `SAME_EXCEPT_KEY key_len=43`.
2. The log checker (`c63-commands.md` s1) installed on wine-d.
3. Algo Trading ON first. Eleven charts (nine symbols; two each for
   AUDNZD and NZDCAD), each with fxgrind dragged from
   **Navigator -> Expert Advisors -> fxmatrix -> fxgrind (the Experts
   copy, never Scripts: 02_TRAPS 1 Oct C63)**, its `_d_lat` preset
   loaded and every input read back before OK. GBPUSD first as the
   pilot, until `grind telemetry POST ok`.
4. Pass per chart: `replay=ready`, `lattice=true`, `rebuild=false/false`,
   geometry = the register's B/C row, POST ok, no BAD line.
5. After: every `chart*.chr` `path=` reads `Experts\fxmatrix\fxgrind.ex5`;
   `LATTICE_CONFIG` for the 11 D ids.

STOP before the next chart on FATAL, CRITICAL, `INVARIANT_FAIL`,
`RECON_FAIL`, a `geo=` different from the register, `REPLAY_INIT_DEFERRED`
in session, or no POST ok.

## 4. KNOWN LIMITS

- Same broker, pairs and settings as B and C; a different account and a
  flat start, so fleet totals differ from B and C by the books.
- pipshed's strip shows D as NOT ATTACHED until its entry's `placeholder`
  is flipped and `cycle_start` set (C85 (f), a pipshed change).
- The ejection study does not read D until C84 is scored (C85 (d)).
- Geometry register: D's rows open at the attach (same values as B/C).

## 5. RECORD

- **D0 attached 1 Oct 05:10-05:19Z** (Asia session; spreads single-digit
  points), over VNC after the X display was unwedged (02_TRAPS 1 Oct
  wine-d). Presets staged 04:33Z (`MQL5/Presets` created first: a fresh
  box has none), 11 `SAME_EXCEPT_KEY key_len=43`; log checker installed;
  `Experts/fxmatrix/fxgrind.ex5` 317,844 bytes, 30 Sep 18:58, source =
  repo.
- GBPUSD pilot 05:10:32Z: `replay=ready(0) lattice=true geo=L5/9/10
  S5/9/10 rebuild=false/false`, POST ok. The other ten 05:12:58-05:19:23Z,
  each `lattice=true rebuild=false/false`, geometry = the table, twins
  add 8 / 10, BAD 0. AUDCHF first attached on H1 (05:15:04), removed and
  re-attached on M5 (05:15:34): one instance, its resting orders adopted.
- `LATTICE_CONFIG` for all 11 D ids; no `DEAL_EVENT_MISSED`, no
  `REPLAY_SEED_FAILED`. Geometry register: D rows opened at these times.
- Left: pipshed strip flip (`placeholder` off, `cycle_start` 2026-10-01;
  C85 (f); BUILT 05:40Z in `pipshed_c9_and_fleet_d_card.patch`, tree
  `fbed4e6c`, not pushed); every chart was dragged from Expert Advisors -> fxmatrix
  (the operator's attach; the chart profiles are written on exit, so the
  `path=` check waits for the next MT5 restart).


## 6. D1 -- THE FIRST COMPASS ROUND (FOR GEMINI)

Written by Claude 1 Oct ~06:30Z. Every decision below is the operator's,
taken one at a time in chat on 1 Oct 05:55-06:05Z on Claude's
recommendations ("i am sure we will fine tune this process each round").
Evidence: `research/compass/d1_evidence.py` (this patch) on the export
`study_export_1001early.jsonl` (sha256 `dde95342e203335b`, last close
1 Oct 01:58Z) and wine-c's bid/ask dump (24 Sep 00:00 server -> 30 Sep
15:40Z). Nothing is deployed by this document: presets follow Gemini.

### 6.0 AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| E1 | Anchor = Fleet B's live row, cap 8, lattice on: GBPUSD 5/9/10, EURUSD 7/7/10, EURGBP 3/3/5, AUDCAD 5/6/10, AUDCHF 5/4/10, CADCHF 5/4/10, NZDCHF 3/3/10, NZDCAD 5/8/10 (ALT 5/10/10), AUDNZD 7/8/10 (ALT 7/10/10) (width/add/exit) | `10_GEOMETRY_REGISTER.md`; `ea/presets_d/*_d_lat.set` read back | VERIFIED |
| E2 | Add/width guard 0.5-4.0, checked in `OnInit` on the base inputs and on each resolved side; every probe below is inside it (lowest 0.6, AUDCHF/CADCHF add 3 on width 5) | `grind_pure.mqh` 9-10, 41-52; `fxgrind.mq5` 174-200 | VERIFIED |
| E3 | A changed exit on a live book: `Grind_GeoExitChanged` against the stored label `GRIND_GEO_EXIT_<magic>_L/_S` sets the rebuild flag; recon tolerates the old exit price; each RESTING exit is repriced to `ExitPrice(effective entry, new exit) + accrued + eject offset` (rolled layers by their VL); commanded-eject exits keep their price; queued exits (no order) are placed later at the formula; then the labels are written and the resting adds move once at start | `grind_recon.mqh` 1294-1311; `grind_engine.mqh` 2934-3027; `grind_exitq.mqh` 241-255; `fxgrind.mq5` 266-279 | VERIFIED |
| E4 | D's labels were written at the D0 attach, so a D exit reload shows `rebuild=true/true`; an add-only reload (C) shows `rebuild=false/false` and still moves the resting adds once (start reprice) | E3; fleet-b.md B2 (labels written 03:46Z on B) | VERIFIED in source (labels written at every successful init, so at D0's) |
| E5 | Same settings, same broker, different account and book: B vs C closed net per side differs by up to $5.25/day over 28-30 Sep (AUDCHF S 1.13 vs 6.39; CADCHF S -2.11 vs 2.38; EURUSD L -3.57 vs 0.16) | `d1_evidence.py` part 1 | VERIFIED (ledger; scalps cross-check A 410/410, B 491/491, C 480/478 with `scalp_history`) |
| E6 | B1's step (B, C at the B1 add vs A at the old add, same days): 9 pair-sides pass "step > max($1, B-C gap)" and every one follows the week's trend: the tighter add LOST on the trending side (GBPUSD S, EURUSD S, AUDCAD L, AUDCHF L, AUDNZD L) and WON on the counter-trend side (EURGBP S, AUDCAD S, NZDCAD S, AUDNZD S) | part 1; `grid-thesis.md` s3 (add is partly leverage) | VERIFIED numbers; the reading is Claude's |
| E7 | IC price path, ladder at the anchor add: $ per day per side moves by under $0.40 between exit X-1, X and X+1 on every pair (fewer, larger scalps cancel more, smaller ones). No cap, depth or lattice | part 2 | VERIFIED; first-order, not reconciled |
| E8 | Roll cost per roll = cap x add - exit (ADR-162 s4): a 1-pip tighter add saves 8 pips a roll, a 1-pip tighter exit costs 1 | ADR-162 s4 | VERIFIED |

### 6.1 LEVERS (operator, decision a)

B holds the ANCHOR; **D probes EXIT; C probes ADD** (cycle-4 s8.4: one
lever per probe fleet). Reasons: the exit reload is the first live run
of the ADR-163 rebuild on a live book (E3), and D (flat at 05:19Z) has
the smallest book; an add reload is the routine kind (B1 on B, 27 Sep).
Fleet C stops being B's replica from the D1 reload (C63 kept them
matched on purpose; C63 is done).

### 6.2 DIRECTIONS (operator, decision b): every row "none: default"

No pair-side has direction evidence: same-settings noise (E5) exceeds the
$1/day margin, the B1 step measures the week's trend (E6, cycle-4 R3),
and exit's harvest curve is flat (E7). Defaults, both sides alike (base
inputs change; the six per-side inputs stay -1):
- **D: exit one pip TIGHTER everywhere** (10 -> 9; EURGBP 5 -> 4):
  value flat (E7), so tighter is the free direction; layers turn over
  sooner (less inventory, fewer rolls) for +1 pip a roll (E8); the
  operator favours tight; no exit has ever been below 10 (5 on EURGBP).
  Cost: commission a larger share (EURGBP 4 pips ~ $0.53 gross vs $0.07).
- **C: add one pip TIGHTER, continuing B1** (its aim, scalp volume, was
  met: about 1.5-2x A's scalps on B and C); cheaper rolls under the
  lattice (E8). **EURGBP and NZDCHF sit at the add-3 floor: their probe is
  +1 (add 4).** Half pips and an add below 3 stay OPEN (s8.11).

### 6.3 TWINS (decision c, the operator left it to Claude)

On C and D the TWIN carries the probe and the primary stays on the
anchor, so each probe fleet holds a same-account, same-tick pair that
differs in exactly the probe lever (the one comparison free of E5's
account-and-book noise; on D both started flat at the same minute).
B keeps its two add-10 twins (controls). C and D lose theirs.

### 6.4 THE PROBE TABLE (width / add / exit; changed value in brackets)

| instance | B (anchor, unchanged) | C (add probe) | D (exit probe) |
|---|---|---|---|
| GBPUSD OPT | 5/9/10 | 5/[8]/10 | 5/9/[9] |
| EURUSD OPT | 7/7/10 | 7/[6]/10 | 7/7/[9] |
| EURGBP OPT | 3/3/5 | 3/[4]/5 (floor) | 3/3/[4] |
| AUDCAD OPT | 5/6/10 | 5/[5]/10 | 5/6/[9] |
| AUDCHF OPT | 5/4/10 | 5/[3]/10 | 5/4/[9] |
| CADCHF OPT | 5/4/10 | 5/[3]/10 | 5/4/[9] |
| NZDCHF OPT | 3/3/10 | 3/[4]/10 (floor) | 3/3/[9] |
| NZDCAD OPT | 5/8/10 | 5/8/10 (anchor) | 5/8/10 (anchor) |
| NZDCAD ALT | 5/10/10 (control) | 5/[7]/10 | 5/[8]/[9] |
| AUDNZD OPT | 7/8/10 | 7/8/10 (anchor) | 7/8/10 (anchor) |
| AUDNZD ALT | 7/10/10 (control) | 7/[7]/10 | 7/[8]/[9] |

Nine reloads on wine-d and nine on wine-c (NZDCAD and AUDNZD OPT
untouched); cap 8, width, lattice, carry and every other input unchanged.

### 6.5 THE ROUND AND THE SCORE (operator, decision d)

- **Round:** two full FTMO days (22:00Z to 22:00Z) after the LAST D1
  reload; the weekend does not count. A Thursday reload -> Fri 2 Oct
  (US payrolls 12:30Z) + Mon 5 Oct.
- **Score per pair and side:** closed net per day (scalps + rolls + any
  ejection; profit + swap + commission, all-in from the ledger),
  attributed by CLOSE time (cycle-4 s8.1; right for exits, since D's
  rebuild reprices inherited layers). Each probe side vs the same side on
  B; on C and D also the twin vs its primary (same account). Reported
  beside it, not deciding: the ENTRY-time split (only layers opened after
  the reload), open MTM at the end, each side's depth at the reload.
- **Decision per pair and side (amended after Gemini, s6.8):**
  threshold **$1.19/day for every side** = max($1, the POOLED median of
  the 18 primary sides' same-settings gaps |B - C| over 28-30 Sep: 1.185;
  quartiles 0.50 / 1.19 / 2.19). Twin pairs: the twin vs its own primary
  DECIDES (same account), the cross-fleet comparison is reported; their
  threshold is max($1.19, A's identical-settings OPT vs ALT gap): AUDNZD
  long $1.40, the other three twin sides $1.19.
  - A probe that beats the anchor by more than the threshold becomes the
    anchor (if both C's and D's probes do, the larger margin; the other
    lever probes again next round around the new anchor); one that loses
    by more FLIPS across the anchor (s8.4); within the threshold **the
    same probe runs again**, and the next decision scores it over ALL its
    rounds' days pooled (noise shrinks as days accumulate).
  - **ADD probes (C) have two extra gates before promotion:** (1) the
    ENTRY-time split (layers opened after the reload) must not lose to
    the anchor's by more than the threshold (GD1-4); (2) closed net per
    layer-hour (each 0.01 layer's hours open inside the round, inherited
    layers counted from the round start, open layers to its end) must be
    no worse than the anchor's (GD1-5). A probe that wins raw but fails a
    gate repeats; it is not promoted.
  - Superseded (kept for the record): the per-side thresholds below
    (max($1, that side's own 3-day gap)), replaced by the pooled value on
    Gemini's GD1-2 (a single 3-day gap of $5.25 would freeze a side).

Per-side max($1, same-settings gap) ($/day, `d1_evidence.py` part 1; SUPERSEDED as
thresholds, kept as the noise record):

| pair | long | short |
|---|---|---|
| GBPUSD | 2.46 | 1.00 |
| EURUSD | 3.73 | 1.00 |
| EURGBP | 2.10 | 1.00 |
| AUDCAD | 1.00 | 1.27 |
| AUDCHF | 1.00 | 5.25 |
| CADCHF | 1.97 | 4.49 |
| NZDCHF | 1.97 | 1.72 |
| NZDCAD OPT / twin | 1.10 / 1.00 | 1.00 / 1.00 |
| AUDNZD OPT / twin | 1.00 / 1.40 | 1.00 / 1.00 |

- **Scoring code:** `research/compass/compass_score.py` with
  `round1.json` (backlog C91, built 1 Oct after the reloads; tests first,
  hand-derived; README there). Run after Mon 5 Oct 22:00Z on a fresh
  export.

### 6.6 DEPLOY (after Gemini; one paste per step)

1. Presets `ea/presets_c/*_c_p1.set` and `ea/presets_d/*_d_p1.set` (the
   nine changed instances each; COMMITTED with s6.8, each checked against
   6.4: 37 inputs, key blank, per-side -1, guard ratio in range): the `_lat` file with only `InpAddPips`
   or `InpExitPips` (and for the D twins both) and `InpConfigWarning`
   changed; key blank; staged with the key, 9 `SAME_EXCEPT_KEY` per box.
2. In session, spreads under every width, not 20:50-21:00Z, not within 30
   minutes of a tier-1 release. **wine-d first** (the first live exit
   rebuild), GBPUSD as the pilot; then wine-c. Twins: read
   `InpTelemetryInstance` and `InpMagic` before Load.
3. Pass per chart (log checker): wine-d `deinit=5 lattice=true
   rebuild=true/true`, geo = 6.4, `REBUILD_SUMMARY` per side, POST ok;
   wine-c `deinit=5 lattice=true rebuild=false/false`, geo = 6.4.
   Expected on wine-d: an exit whose new target is already past the
   market is clamped PASSIVE (ask/bid + minimum distance; the EA sends no
   market orders) and may fill within seconds as a scalp at or above its
   new target: read `REBUILD_SUMMARY` `clamped` and record it (s6.8
   GD1-6), not a STOP.
4. Register rows (close the old row, open the new one at the reload
   time from the log); fleet-c.md A3 and this file's record.

STOP before the next chart on FATAL, CRITICAL, `INVARIANT_FAIL`,
`RECON_FAIL`, `REBUILD_EXIT_FAILED`, `REBUILD_EXIT_UNREADABLE`, a `geo=`
or `rebuild=` different from step 3, or no POST ok.

**Negative space:** no EA change, no compile, no B change, no cap, width
or lattice change, no flattening, no reattach of wine-c's charts (C88 is
separate), no reload with the market closed.

### 6.7 FOR GEMINI

Attack the premises; say which fact is missing.
- **GD1-1.** With no direction evidence (E5-E7), uniform defaults: exit
  -1 on D, add -1 on C (+1 at the add-3 floor). Right, or should
  directions be MIXED across pairs (some +1, some -1) to learn more per
  round?
- **GD1-2.** The noise-gated rule (threshold = max($1, a 3-day same-
  settings gap); within it, repeat the probe). Is a single 3-day gap a
  usable threshold, or should it be pooled (e.g. the median gap over all
  sides, about $1.2) or re-measured each round (and from what, once no
  two fleets share settings)?
- **GD1-3.** For the two twin pairs, should the same-account comparison
  (twin vs primary) DECIDE, with the cross-fleet one reported, or the
  reverse?
- **GD1-4.** Close-time attribution: on C (inherited book) layers opened
  at the old add close inside the round and count for the add probe. Does
  that bias the add comparison enough to make the entry-time split decide
  for C (while close time decides for D)?
- **GD1-5.** A tighter add wins raw closed P&L on calm or counter-trend
  days and loses on trend days (E6, leverage). Comparing the same side
  across fleets puts both through the same trend. Is that enough, or does
  C's probe also need a per-inventory score (closed net per lot-hour)?
- **GD1-6.** D's reload runs the ADR-163 rebuild on a live book for the
  first time (E3). Any failure mode at reload not on the STOP list?
- **GD1-7.** The first round includes US payrolls (Fri 2 Oct). Proceed,
  or start the count on Monday 5 Oct?

### 6.8 GEMINI'S RULINGS (1 OCT ~06:15Z) AND CLAUDE'S CHECK

His answers pasted by the operator; checked in source and data by Claude;
the operator accepted every verdict below ("proceed", 1 Oct ~06:12Z).
- **GD1-1 ACCEPTED** (uniform, all tighter). His reason (mixing would
  confound correlated pairs) is weaker than the ruling: each side is
  compared with the same side on B, so a macro move hits both alike.
- **GD1-2 ACCEPTED: one POOLED threshold** ($1.19, s6.5). His missing
  fact, answered from the ledger: the largest gaps are mostly tail events
  (ejections: AUDCHF S 4 on B vs 1 on C, CADCHF S 3 vs 0, EURUSD L 5 vs
  3); some smaller ones are scalp counts (GBPUSD L 30 vs 37; CADCHF L 11
  vs 6; NZDCHF L 12 vs 7). Under the lattice, ejections become rolls, so
  today's gaps say little about the rolled regime. Claude's addition: a
  repeated probe is scored over all its rounds pooled.
- **GD1-3 ACCEPTED: the twin decides for the two twin pairs.** His
  "strips out the E5 noise entirely" overstates it: A's identical twins
  differed by $1.40/day (AUDNZD long), hence that side's threshold; on C
  the twin and the primary also hold different inherited books.
- **GD1-4 ACCEPTED as a gate** (close time decides; the entry-time split
  must not lose by more than the threshold, else repeat).
- **GD1-5 ACCEPTED as a gate** (closed net per layer-hour no worse than
  the anchor's). Note: on 30 Sep (grid-thesis s10, GT-1) he argued
  against a per-lot-hour normaliser; this ruling reverses that, and the
  reversal is right for an add probe (leverage). His "relentlessly tighten
  to cap" is also bounded by the add-3 floor and by rolls being realised
  (closed) losses under the lattice.
- **GD1-6 REJECTED (premise wrong).** "An avalanche of EXT market orders":
  the EA sends no market orders (no `TRADE_ACTION_DEAL` in the trading
  code; every exit is a limit), and the rebuild clamps a target already
  past the market to the passive side (`Grind_ExitQClampPassive` ->
  `Grind_CarryClampLongExit`/`ShortExit`, `grind_carry.mqh` 443-475: a
  long's exit to ask + minimum distance). Only RESTING exits are repriced
  (at most two per side, ADR-151). Worst case: one or two clamped exits
  per side fill within seconds as scalps at or above the new target.
  Recorded as expected in 6.6 step 3, not a STOP.
- **GD1-7 ACCEPTED** (the round includes payrolls).

## 7. AMENDMENTS (records)

- D1 (above) supersedes s2's "D1 ... after the roll-watch": the operator
  moved it ahead (1 Oct ~05:25Z).

- **D1 APPLIED 1 Oct (Asia session, spreads under widths; wine-d over
  VNC, then wine-c).** Presets staged 06:16Z on wine-d and ~06:40Z on
  wine-c (repos ff to `de73e46`; 9 `SAME_EXCEPT_KEY key_len=43` each).
  - **wine-d (exit probe):** GBPUSD pilot 06:19:13Z, then EURUSD
    06:21:27, EURGBP 06:21:39, AUDCAD 06:21:51, AUDCHF 06:22:06, CADCHF
    06:22:17, NZDCHF 06:22:31, AUDNZD_ALTD 06:25:42, NZDCAD_ALTD
    06:35:12. Every row `deinit=5 lattice=true rebuild=true/true`, geo =
    s6.4: **the first live ADR-163 exit rebuild, clean**. Archive:
    `REBUILD_SUMMARY` x2 for all nine, `EXIT_REBUILT` x5 (GBPUSD, EURUSD,
    AUDCAD, AUDCHF, AUDNZD_ALTD: the only sides with a resting exit),
    `LATTICE_CONFIG`; no `DEAL_EVENT_MISSED`, `REPLAY_SEED_FAILED` or
    `STARTUP_EXIT_SHORTFALL`.
  - **Incident (06:24:17-06:32:18Z):** `nzdcad_dup_d_p1.set` was first
    loaded on the NZDCAD PRIMARY chart (22260801): the dialog shows the
    preset's magic after Load and both charts carry the same title, so
    the readback could not tell. That chart deinitialised (reason 5),
    then failed init `FATAL: duplicate magic 22260802` (reason 8) and
    was unloaded; NZDCAD_OPTD's book was unmanaged for 8 minutes.
    Re-attached 06:32:18Z from Experts with `nzdcad_opt_d_lat.set`
    (`rebuild=false/false`, geo 5/8/10, no shortfall); the twin then
    reloaded correctly (magic read BEFORE Load). No geometry row for the
    re-attach (unchanged). Findings: 02_TRAPS 1 Oct D1; backlog C89 (a
    failed init frees the live holder's magic lock).
  - **wine-c (add probe):** GBPUSD pilot 06:45:12Z, then EURUSD 06:46:09,
    EURGBP 06:46:22, AUDCAD 06:46:35, AUDCHF 06:46:55, CADCHF 06:47:05,
    NZDCHF 06:47:24, NZDCAD_ALTC 06:49:16, AUDNZD_ALTC 06:49:39. Every
    row `deinit=5 lattice=true rebuild=false/false`, geo = s6.4, BAD 0.
  - **Round 1 = FTMO days Fri 2 Oct + Mon 5 Oct** (ends Mon 5 Oct 22:00Z;
    the last reload was 06:49:39Z Thursday). Register rows opened.

- **1 Oct afternoon (CHF trend, before round 1 opens):** commanded ejects
  (by hand, to unstrand) on AUDCHF long B, C, D, CADCHF long C and NZDCHF
  long B, 15:30-16:00Z (event log 1 Oct ~14:00Z). All are BEFORE the
  round's windows (from Thu 22:00Z), so no round-1 score includes them;
  they change those sides' starting books (recorded as depth at the
  reload). Scoring unchanged.

- **1 Oct night (round-1 amendment, before window 1): breaker and gate
  OFF on B, C and D.** Operator ~20:25Z: "i dont like these gates - we
  need to trade". ADR-160's entry gate (on at floating loss >= 50% of
  the $500 allowance, off below 40%; `grind_pure.mqh` 658-666) had
  blocked every entry on both sides of B (floating $249-278) and C
  ($240-268) since the CHF trend, while D ($152) traded: the round
  would have opened with the anchor and the add probe unable to enter.
  The IC demo accounts have no daily limit. `InpBreakerEnable=false`
  (gate + ADR-158 80% breaker + pre-midnight halt; one input) set by F7
  on every chart: wine-d 21:16-21:21Z, wine-c to ~21:25Z, wine-test to
  ~21:28Z (each box: 11/11 `CONFIG` re-inits since 21:10Z, FATAL 0).
  Outcome: B book/guard 102/102 -> 123/144, C 103/103 -> 124/145 (21
  resting entries each), D unchanged 152/174; B's newest books show 2
  entry orders on every instance (1 on NZDCAD_OPTB, long at cap). Same
  change on all three fleets, so round 1 stays like-for-like; FTMO
  keeps the gate (real limit, frozen cycle). Presets: 51 IC files set
  to `InpBreakerEnable=false` (repo). No geometry row (not geometry).
- **Compass method from round 2 (operator 1 Oct ~20:10Z): no twins.**
  Each IC fleet becomes one ring of seven pairs (each currency exactly
  twice, C96), one instance per pair; probes are fleet against fleet
  (B anchor, C and D one lever each per round). Round 1 runs to the end
  as designed, twins included ("twins decide" used one last time).

- **2 Oct, window 1 (round-1 amendments, all by the operator):**
  - **Hand ejects, NZDCHF long B and C** (operator ~02:22Z: "lets unstick
    the fx pairs that are stuck"). Both sides were at cap with all eight
    layers rolled and the ask past the next level (B 0.46530 vs 0.46534,
    C vs 0.46535; status files 02:19Z): no roll candidate on `0335f25`.
    Commanded eject (ADR-155) of the highest effective entry: B L01
    1970247358 (`EJECT_ACCEPTED` 02:26:15Z, target 0.46542, `EJECT_FILLED`
    02:26:43Z), C L00 1971349402 (02:29:27Z, 0.46550, filled 02:30:19Z);
    about -$7.90 and -$8.20 realised INSIDE window 1 (scored as they
    fall). Books clean after (no EXT position; new adds at 0.46534 B,
    0.46537 C). NZDCHF D (one roll left) and AUDCHF C (all rolled, 3.6
    pips from the next level) were not ejected. Claude had recommended
    leaving stuck sides alone during the round (the anchor's realised
    loss is not matched on D); the operator decided otherwise; B and C
    were treated alike.
  - **Hand eject, AUDCHF long C** (status 03:41:41Z: all eight rolled,
    ask 0.57509 past the next level 0.57527; operator "eject i think"):
    L10 1978509127, magic 22260501, `EJECT_ACCEPTED` 03:51:45Z target
    0.57502, `EJECT_FILLED` 03:52:31Z (~-$6.80, C's AUDCHF only). C is the
    add probe there (add 3 vs B's 4): a tighter add spends its rolls
    sooner, so the stuck side and its eject are part of what the probe
    measures.
  - **`InpStrandedThreshPips` = width + 1 on all 33 IC charts** (F7, one
    row): wine-test 02:55:15-02:58:16Z, wine-c 03:00:14-03:01:49Z,
    wine-d 03:03:03-03:04:54Z (archive INIT rows, 11 each, `deinit=5`;
    CONFIG lines read back per box, FATAL 0). Width 3 -> S 4 (was 8),
    width 5 -> 6 (was 10), width 7 -> 8 (was 14); `InpDeadbandPips` stays
    4. Effect (ADR-153: the empty side's L0 re-quotes after a drift of
    max(D, S - W) away from it): 4 pips on every pair, from 5 (7 on EURUSD
    and AUDNZD); the empty-side L0 now sits W to W + 4 from mid. It runs
    whenever one side holds >= 1 layer and the other none (not only deep
    books). Operator: "i want to see the impact"; a deadband of 1 was
    discussed and rejected to spare requests ("we have to be somewhat
    deferential"). S = W + 1 is above W - D on every pair, so the L0
    never re-quotes AWAY from a market approaching it. Same change on B,
    C and D: round 1 stays like for like. Not geometry: no register row.

Line count: 424
