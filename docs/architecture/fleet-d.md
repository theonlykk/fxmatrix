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
- **Decision per pair and side:** threshold = max($1/day, that side's
  same-settings gap over 28-30 Sep: |B - C| for the primaries; A's own
  OPT vs ALT, identical settings, for the twins). A probe that beats the
  anchor by more than the threshold becomes the anchor (if both C's and
  D's probes do, the larger margin; the other lever probes again next
  round around the new anchor); one that loses by more FLIPS across the
  anchor (s8.4); within the threshold, **the same probe runs again next
  round** instead of flipping on noise.

Thresholds ($/day) from `d1_evidence.py` part 1:

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

- **Scoring code:** `research/compass/` (tests first, hand-derived
  expected values), built during this review; it does not exist today
  (pipshed cards have no side split or FTMO-day history).

### 6.6 DEPLOY (after Gemini; one paste per step)

1. Presets `ea/presets_c/*_c_p1.set` and `ea/presets_d/*_d_p1.set` (the
   nine changed instances each): the `_lat` file with only `InpAddPips`
   or `InpExitPips` (and for the D twins both) and `InpConfigWarning`
   changed; key blank; staged with the key, 9 `SAME_EXCEPT_KEY` per box.
2. In session, spreads under every width, not 20:50-21:00Z, not within 30
   minutes of a tier-1 release. **wine-d first** (the first live exit
   rebuild), GBPUSD as the pilot; then wine-c. Twins: read
   `InpTelemetryInstance` and `InpMagic` before Load.
3. Pass per chart (log checker): wine-d `deinit=5 lattice=true
   rebuild=true/true`, geo = 6.4, `REBUILD_SUMMARY` per side, POST ok;
   wine-c `deinit=5 lattice=true rebuild=false/false`, geo = 6.4.
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

## 7. AMENDMENTS (records)

- D1 (above) supersedes s2's "D1 ... after the roll-watch": the operator
  moved it ahead (1 Oct ~05:25Z).

Line count: 267
