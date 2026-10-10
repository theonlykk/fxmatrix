This message has a line count at the bottom

# REPLAY CALIBRATION ON EURUSD (B / C / D) -- PRE-REGISTERED PLAN

| | |
|---|---|
| Status | **PRE-REGISTERED; RULED** (draft 8 Oct ~02:20Z; Gemini GRC-1..8 ~02:10Z local paste, checked by Claude, operator ~02:16Z: s12). Engine (c) first, the Python port after it (s5). Nothing is built or run before the Cursor prompt for (c) has been through Gemini. The marks in s6 are fixed BEFORE any tick is read; a mark changed after a run is a new pre-registration, recorded as such |
| Origin | Operator 8 Oct ~01:22Z-01:31Z: "we were loathe to do a backtest because we felt it did not replicate real life ... pick a fxpair with a lot of trade points we can calibrate against and see if we can replicate the trade history we observed"; "getting a reliable replay would be a huge result" (`grid-as-variance-trade.md` s12; backlog C135 as rewritten) |
| Rules it keeps | Our trade history is the gold standard; a replay is trusted only once it reproduces our trades. No time-series analysis or price signals (operator 8 Oct ~01:07Z): the ticks only drive our own rules; no statistic of price is computed or used. Nothing a replay says changes a rule, a geometry or a compass verdict before s8's holdout has passed and the operator has ruled |
| Supersedes | `scalps-per-roll.md` s7 "reconcile on round 2" (one fleet, minute bars, counts only) |

## 0. AUDIT TRAIL

Source facts at `main` EA code `5bb5fdb` (live on B, C, D since 7 Oct); line
numbers are this commit's. Archive facts from `study_2026-10-08_0110.jsonl`
(K17), counted with a sandbox script (not committed).

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | Order of work per tick: close-by queues, invariants / quarantine, commanded and auto eject, the lattice (rolls), session, breaker, then the engine (L0, re-centre, adds) | `fxgrind.mq5` 438-494 | VERIFIED |
| K2 | A flat side's L0 is placed ONCE at mid -/+ W and left alone (ADR-123), clamped to rest behind the touch | `grind_engine.mqh` 3181-3238 (`Grind_OnTickEngine`), 2049-2101 (`Grind_TryPlaceL0`); `grind_pure.mqh` 198-210 | VERIFIED |
| K3 | The EMPTY side opposite a loaded side: its L0 is moved to mid -/+ W when it sits more than S (`InpStrandedThreshPips`) from mid and the move exceeds the deadband; skipped while the API soft warn is active | `grind_engine.mqh` 3026-3071; `grind_pure.mqh` 164-171, 241-252 | VERIFIED |
| K4 | The add: one add beyond the deepest layer (by effective entry once a layer is rolled); placed at the ENT fill when `InpFillTimePlace` is on; re-quoted only when its target moves by the deadband or more (0.05 pip once after an init) | `grind_engine.mqh` 2250-2287, 2405-2429, 2483-2583 | VERIFIED |
| K5 | The exit: entry +/- exit (+ accrued carry; from the virtual level once rolled). Only the nearest layer (rank 0) and the farthest (rank depth-1) rest at the broker; the others are held; a marketable target is clamped passive | `grind_engine.mqh` 3451-3511; `grind_exitq.mqh` 43-60; `grind_config.mqh` 7-8 (K 1, H 0) | VERIFIED |
| K6 | An EXT fill opens an opposite position; the pair closes by close-by (two OUT_BY deals); the scalp is recorded at the OUT_BY | `grind_engine.mqh` 2857-3023 | VERIFIED |
| K7 | Roll (ADR-162): at cap, once the side's tick extreme since its newest layer (lowest ASK long, highest BID short, read with `CopyTicksRange`) crosses the virtual level (one add beyond the deepest effective entry), the highest-entry unrolled layer's exit moves to level +/- exit + accrued; a gap rolls several levels in one call | `grind_engine.mqh` 796-891, 1025-1096, 1268-1388; `grind_pure.mqh` 454-459 | VERIFIED |
| K8 | Re-roll (ADR-165, `InpLatticeReroll`): with every layer rolled, the rolled layer with the highest level (long; lowest short) re-rolls, at most one per call, none 23:50-00:15 server | `grind_engine.mqh` 964-991, 1319-1332; `grind_pure.mqh` 431-437 | VERIFIED |
| K9 | Roll gate (ADR-166, `InpRollGateOpposite` = 0): no roll while the opposite side holds a layer; while held the extreme restarts at the current tick, so a crossing during a hold does not count after it | `grind_pure.mqh` 444-447; `grind_engine.mqh` 1208-1220, 1278-1282 | VERIFIED |
| K10 | Carry pass (`InpEnableCarryPass`, ON at every EURUSD init in the window): in the nightly window held exits shift by the accrued swap | `grind_carry.mqh` 1189-1270; window 20:50-20:59Z (BOOT s6); config_events `enable_carry_pass` | VERIFIED |
| K11 | Every init (compile, F7 + Load, terminal restart): state rebuilt from the broker's positions and orders; resting exits repriced to the CURRENT exit dial (ADR-163); the one-shot add reprice | `fxgrind.mq5` 265-294; `grind_engine.mqh` 3074-3148 | VERIFIED |
| K12 | Slots are ACCOUNT-wide: entries need positions + orders + resting entries <= limit - (2 + 4 + reserve); an exit needs one free slot (`PositionsTotal() + OrdersTotal()`, all nine instances) | `grind_exitq.mqh` 125-131, 165-183; preset `InpSlotNearReserve=8` | VERIFIED |
| K13 | Builds in the window: `0335f25` to 2 Oct ~14:16-14:21Z, `893e065` (= `0335f25` + the API constants) to 5 Oct ~22:38-23:16Z, `2859be6` to 7 Oct ~01:57-02:18Z, then `5bb5fdb`. `git diff 0335f25 5bb5fdb` on the modelled paths: re-roll and the gate (both behind inputs that default off: `InpLatticeReroll` false, `InpRollGateOpposite` -1); the API entry stop 1,900 / soft warn 1,800 (constants until the hotfix, inputs after); v2.2a's recon scan dedupe (C93) in the init rebuild. Nothing else in K2-K7, K10 | git; config_events `ea_build` per init | VERIFIED (diff); "inputs off = old behaviour" is ADR-165 / ADR-166's claim, covered by the suite, not re-tested here |
| K14 | The EURUSD inits in the window, per fleet, with geometry, S and deadband: s2's table | config_events (INIT rows: `ea_time_ms`, `ea_build`, width / add / exit, stranded, deadband) | VERIFIED (archive) |
| K15 | Inputs the archive does not carry (lattice, re-roll, gate, breaker): lattice ON from B 1 Oct 03:58:52Z, C 04:14:28Z (the C63 loads), D from its attach; breaker + float gate ON on IC until the 1 Oct night re-inits (B 21:27:06Z, C 21:23:30Z, D 21:20:23Z), then OFF; re-roll ON from the Monday build's loads (B 5 Oct 23:19:53Z, C 23:01:47Z, D 22:42:44Z); gate 0 from the Wednesday build's loads (B 7 Oct 02:21:20Z, C 02:12:36Z, D 02:01:36Z) | `fleet-d.md` s7; HANDOFF s58, s64; init times from config_events | VERIFIED (docs + archive times); the markers themselves to read (s4.2) |
| K16 | Round-2 preset (B): W 2, add 7, exit 10, cap 8, S 3, deadband 2, carry ON, commanded eject ON, auto-eject OFF, lattice + re-roll ON, gate 0, breaker OFF, session OFF, fill-time place ON, reserve 8, horizon 0, API 1,000,000 / 999,000 | `ea/presets_b/eurusd_opt_b_r2.set` | VERIFIED |
| K17 | Ground truth now: `study_2026-10-08_0110.jsonl`, 21,690,852 bytes, sha256 `e01ac3038bafdc79`, UTF-8 with BOM: fill_logs 21,999, scalp_history 5,195, ea_events 4,418 (EJECT_ / ROLL_ / CARRY_ only), config_events 1,393 | staged 8 Oct ~01:52Z and hashed | VERIFIED |
| K18 | EURUSD from each fleet's window start (s2) to the export: B 259 IN deals (131 ENT, 128 EXT), 88 scalps, 32 roll closes, 41 `ROLL_ACCEPTED` (3 re-rolls); C 294 (149, 145), 99, 35, 50 (9); D 314 (162, 152), 115, 30, 33 (0). The previous chat's figures from 05:30Z reproduce exactly (D 115 / 30, 314 + 304; C 98 / 35, 292 + 288; B 87 / 32, 257 + 254). From 7 Oct 02:25Z (received): B 15 / 4, C 20 / 4, D 16 / 5. Last EURUSD fills before the export: B 7 Oct 16:18Z, C 17:10Z, D 18:05Z | scalp_history (broker close time - offset), fill_logs (broker msc - 3 h; within 10 s of `ea_time_ms`), ea_events | VERIFIED |
| K19 | `CopyTicksRange` returns ticks on the IC boxes; how far back IC serves EURUSD ticks is UNKNOWN | C63 probe (`scripts/grind_tick_probe.mq5`) | VERIFIED / UNKNOWN |
| K20 | No eject on EURUSD B, C or D in the window: the 16 `EJECT_ACCEPTED` (B 11, C 5) are all `source: auto`, 29-30 Sep, before the lattice; every one filled. No `scalp_history` close in the window is flagged ejected | ea_events, scalp_history | VERIFIED |
| K21 | The MT5 Strategy Tester starts every run from an empty account: it cannot hold a book opened at historical prices | MT5 behaviour | KNOWN, not tested here |
| K22 | No IC terminal without live EAs exists | previous chat | REPORTED |
| K23 | C's old EURUSD layers were realised on the Monday-build night by RE-ROLLS: C 5 Oct 23:01:47Z - 6 Oct 03:27:12Z, 9 re-rolls, 10 roll closes, 1 scalp (B and C had `ROLL_STRANDED` long, depth 8, all rolled, 5 Oct 02:43Z / 02:49Z, with re-roll still off) | ea_events, scalp_history | VERIFIED |

## 1. THE QUESTION

Given IC's own EURUSD ticks, does a replay of our rules produce the deals
B, C and D actually made: the same side, role (ENT / EXT), layer, price and
time; the same scalps, rolls and re-rolls? One tick stream, three
geometries, three observed histories: a replay that reproduces all three
has the rules, not a fit. A pass makes later geometry sweeps (rho ranges
per pair, `grid-as-variance-trade.md` s11-s12) trustworthy; a fail says
which rule we do not understand.

## 2. THE WINDOW AND ITS SEGMENTS

**Window:** from each fleet's first init with the lattice on (B 1 Oct
03:58:52Z, C 04:14:28Z, D 05:12:58Z, D's flat attach) to the end of round 2
(**8 Oct 22:00Z**). The ground truth is the study export taken at round 2's
scoring (~22:35Z; sha256 recorded), which adds Thursday's trading.

**Segments:** cut at every init (K11: each one rebuilds the book from the
broker, and every input change is an init). Inits from the archive, with
the deals (IN), scalps (S), roll closes (R) and `ROLL_ACCEPTED` (RA, re-rolls
in brackets) each segment holds up to the 01:10Z export (K18). W / add /
exit; S = stranded threshold; DB = deadband.

| fleet | from (Z) | why | build | W/a/e; S; DB | other inputs (K15) | IN | S | R | RA |
|---|---|---|---|---|---|---:|---:|---:|---:|
| D | 1 Oct 05:12:58 | flat attach | 0335f25 | 7/7/10; 14; 4 | breaker on | 1 | 0 | 0 | 0 |
| D | 1 Oct 06:21:27 | D1 exit probe | 0335f25 | 7/7/9; 14; 4 | breaker on | 74 | 30 | 3 | 7 |
| D | 1 Oct 21:20:23 | breaker off | 0335f25 | 7/7/9; 14; 4 | | 6 | 2 | 1 | 0 |
| D | 2 Oct 03:03:09 | S = W + 1 | 0335f25 | 7/7/9; 8; 4 | | 54 | 17 | 3 | 1 |
| D | 2 Oct 14:16:00 | API hotfix | 893e065 | 7/7/9; 8; 4 | | 94 | 37 | 10 | 10 |
| D | 5 Oct 22:42:44 | Monday build (compile 22:38:01) | 2859be6 | 7/7/9; 8; 4 | re-roll | 4 | 1 | 1 | 1 |
| D | 6 Oct 03:20:21 | round 2 | 2859be6 | 2/7/11; 3; 2 | re-roll | 36 | 12 | 6 | 7 |
| D | 7 Oct 02:01:36 | Wednesday build (compile 01:57:38) | 5bb5fdb | 2/7/11; 3; 2 | re-roll, gate 0 | 45 | 16 | 6 | 7 |
| C | 1 Oct 04:14:28 | C63 lattice | 0335f25 | 7/7/10; 14; 4 | breaker on | 2 | 1 | 0 | 1 |
| C | 1 Oct 06:46:09 | D1 add probe | 0335f25 | 7/6/10; 14; 4 | breaker on | 45 | 16 | 7 | 13 |
| C | 1 Oct 21:23:30 | breaker off | 0335f25 | 7/6/10; 14; 4 | | 7 | 2 | 1 | 0 |
| C | 2 Oct 03:00:24 | S = W + 1 | 0335f25 | 7/6/10; 8; 4 | | 64 | 14 | 5 | 1 |
| C | 2 Oct 14:19:10 | API hotfix | 893e065 | 7/6/10; 8; 4 | | 60 | 27 | 1 | 8 |
| C | 5 Oct 23:01:47 | Monday build (compile 22:58:59) | 2859be6 | 7/6/10; 8; 4 | re-roll | 14 | 1 | 10 | 10 (9) |
| C | 6 Oct 03:27:12 | round 2 | 2859be6 | 2/6/10; 3; 2 | re-roll | 52 | 18 | 7 | 7 |
| C | 7 Oct 02:12:36 | Wednesday build (compile 02:06:51) | 5bb5fdb | 2/6/10; 3; 2 | re-roll, gate 0 | 50 | 20 | 4 | 10 |
| B | 1 Oct 03:58:52 | C63 lattice | 0335f25 | 7/7/10; 14; 4 | breaker on | 43 | 16 | 6 | 12 |
| B | 1 Oct 21:27:06 | breaker off | 0335f25 | 7/7/10; 14; 4 | | 5 | 2 | 0 | 0 |
| B | 2 Oct 02:56:16 | S = W + 1 | 0335f25 | 7/7/10; 8; 4 | | 55 | 13 | 5 | 1 |
| B | 2 Oct 14:20:52 | API hotfix | 893e065 | 7/7/10; 8; 4 | | 67 | 26 | 6 | 11 |
| B | 5 Oct 23:19:53 | Monday build (compile 23:16:34) | 2859be6 | 7/7/10; 8; 4 | re-roll | 6 | 2 | 1 | 0 |
| B | 6 Oct 03:33:43 | round 2 | 2859be6 | 2/7/10; 3; 2 | re-roll | 45 | 14 | 10 | 7 |
| B | 7 Oct 02:21:20 | Wednesday build (compile 02:18:03) | 5bb5fdb | 2/7/10; 3; 2 | re-roll, gate 0 | 38 | 15 | 4 | 10 (3) |

The compile inits (a minute or three before each Load) hold no deals; they
are segments of their own but empty. C also re-inits at 04:08:05Z and
04:10:52Z on 1 Oct (a terminal restart and a compile, before its window).
Totals: 867 IN deals, 302 scalps, 97 roll closes, 124 `ROLL_ACCEPTED`.

**Why the whole window, not only the current regime:** from 7 Oct 02:25Z
EURUSD has only 15-20 scalps and 4-5 roll closes per fleet (K18): too few
to tell a right rule from a lucky one. Across the window: ~300 scalps and
~100 rolls, seven input sets, a flat start and deep books, the EUR sell-off
(7 Oct) and quieter days. The cost is K13: four builds, settled in s4.3.
GRC-4 asks Gemini.

## 3. THE STARTING BOOK: SEED ONLY AT AN INIT

- **D's first segment** starts flat (its first fill, an L0, 06:01:36Z).
- **Every other segment** starts at an init from the TRUE positions at that
  moment, rebuilt from fill_logs: each open ENT position (entry, layer from
  the comment, open time), its roll level (latest `ROLL_ACCEPTED` per
  ticket), its accrued carry (`CARRY_*` events). The replay then runs the
  EA's own rebuild (K11): exits re-placed at the current dial, the add and
  L0 recomputed.
- **Why only at an init:** resting orders are not in fill_logs. Mid-segment
  the real book had resting orders (an add re-quoted under the deadband, a
  held exit, an L0 placed earlier at another mid) that cannot be rebuilt;
  at an init the EA itself threw that state away. So B and C start at their
  lattice inits, not at D's attach, and T1's re-synchronisation (s6) resets
  positions only. (Superseded in part, s12: each segment also adopts its
  init's resting orders (fix 2); the sync true book carries each layer's
  swap and accrued carry for re-seeds (fix 3); a sync reset leaves the
  replay's own rolls alone (fix 5).)
- Seeding at every init means one wrong deal cannot carry into the next
  segment; a whole-window run from flat (D only) is reported (T3).

## 4. DATA

### 4.1 Ticks

- A read-only script `scripts/grind_tick_dump.mq5` (the
  `grind_bidask_dump.mq5` pattern: written by Claude, compiled and run by
  the operator; places, modifies and deletes nothing; no Global Variables):
  one CSV per symbol, `time_msc, bid, ask` from `CopyTicksRange(...,
  COPY_TICKS_INFO, ...)` (the EA's own call), a header with account,
  server, digits and server - GMT; chunked; a partial file is deleted.
- **Run on wine-d** (D's own feed), EURUSD, from `2026.10.01 06:30` to
  `2026.10.09 01:30` server (1 Oct 03:30Z - 8 Oct 22:30Z). First a
  one-chunk run to read the earliest tick IC serves (K19); if 1 Oct 03:30Z
  is not served, STOP and bring it back (the window shrinks; s8).
- **One hour on wine-test and on wine-c** (8 Oct 12:00-13:00 server): each
  must equal wine-d's tick for tick; if not, that fleet gets its own dump
  (each fleet replays on its own feed).
- Never 20:50-21:15Z; no chart is touched.

### 4.2 Checks on the archive before any run

1. `LATTICE_CONFIG` markers (`archive_counts.py --codes LATTICE_CONFIG`)
   confirm K15's re-roll and gate per init (the study export does not carry
   them).
2. **Breaker and float gate on 1 Oct** (until each fleet's ~21:20-21:27Z
   re-init): the breaker's gated seconds and any gate or trip rows for B, C,
   D. If the gate bound on EURUSD, its on / off times enter the replay as
   DATA (an account-level state: it depends on all nine pairs' floating
   loss, which a one-pair replay cannot compute).
3. **The API soft warn before the 2 Oct hotfix** (1,800 a terminal day,
   K13): any `WARN_API_SOFT_LIMIT` on B, C, D before 2 Oct 14:21Z. While
   active, the empty side's L0 does not re-centre (K3); if it happened, its
   times enter as data too.
4. `DEAL_EVENT_MISSED` and `DEAL_REPLAYED` counts (`--codes
   DEAL_EVENT_MISSED,DEAL_REPLAYED --hours 200`); no quarantine or halt on
   the three instances.
5. K18 recomputed on the scoring export (the 7 Oct afternoon onwards adds
   to each last segment).

### 4.3 Four builds (settled from the diff, K13)

The modelled paths differ across the builds only through (1) re-roll and
the gate, both behind inputs that were off until the loads in K15, (2) the
API constants (check 4.2.3), and (3) the recon scan dedupe at an init
(C93: an enumeration race, harmless when the scan sees each order once).
**So ONE model with each segment's inputs**, plus the API soft-warn state
as data where 4.2.3 finds it. If a miss in an early segment traces to a
build difference, that is category M10 / M13 and is reported as such.

## 5. THE ENGINE (RULED: (c) FIRST, THEN (b) PROVEN EQUAL TO IT; s12)

**(a) MT5 Strategy Tester with the real EA on IC's real ticks.** The real
compiled code. But K21: the tester starts every run from an empty account,
so it can run only from a flat start with constant inputs: D's first
segment alone, 68 minutes holding ONE deal (an L0 fill). It also needs an
IC terminal with no live EAs (K22) and shows one instance's slots, not the
account's (K12). **Not a calibration; at most a smoke check.**

**(b) A Python replay (C118's engine, research code).** Ported rule by rule
from K1-K12 with hand-derived tests first (one per rule, from the cited
lines), standard library, `research/replay/`, read-only on its inputs;
built by Claude (research code: tests first, a mutation round). Seeding at
inits and T1's re-synchronisation are easy; fast enough for later sweeps
over months of ticks. Risk: a porting error looks like a rule miss; T1's
per-rule miss table is there to separate them.

**(c) An MQL5 replay harness on the real engine.** A script on the desktop
(like the suite) driving the EA's own functions through its test seams
(`Grind_MarketTestSeed`, the `Grind_OrderTest*` book, the `Grind_DealTest*`
deals, `Grind_LatticeTestAddTick`; `grind_engine.mqh` 32-318, 715-767,
2618-2856) with a simulated broker in the harness. The real code,
seedable. Risks: the seams were built for unit tests and not every live
call is seamed (the position open time behind the lattice's extreme, swap
accrual: an audit first); slower; a Cursor build (production-adjacent
MQL5), Gemini and the suite.

**Ruled (s12): (c) first, as the calibration REFERENCE; then (b).** (c)
runs the EA's own rules, so a miss cannot be a porting error. It is not the
Strategy Tester: it drives one engine holding BOTH sides, as live. Cursor
builds it on a branch (RESTATE AND STOP; the prompt through Gemini first)
and RUNS it on the desktop, as it runs the suite (operator ~02:16Z: "i
hate having to set up test runs - i would want cursor to do it"). Then (b),
the Python port (C118), is proven EQUAL to (c) on the same tick streams
(layer events, as C118's equality test) and becomes the sweep engine,
multi-process on the Surface (operator: "if we could at some point test in
python then we would be able to run multithreaded process on the Surface
... the scope of what we could achieve with [the terminal] will be less").
A pass of (c) calibrates the RULES; (b) inherits the calibration only
through its equality with (c).

**What (c) does not run as real code** (Claude's check of GRC-1): the init
rebuild `Grind_ReconstructState` reads the live terminal with no test seam
(`grind_recon.mqh` 1321-1356), so a seeded segment sets the engine's state
directly and M10's rebuild path is the harness's, not the EA's; the
simulated broker is new code; slots read 0 under the order seams
(`grind_exitq.mqh` 125-131: M11, as planned). The lattice's position open
time IS seamed (`grind_carry.mqh` 232). The prompt opens with a seam audit
of every live call on K1-K11's paths. (a) is out by K21.

## 6. THE TESTS AND THE PASS MARKS (FIXED BEFORE ANY RUN)

A "deal" is a fill_logs IN deal (ENT or EXT); OUT_BY rows are bookkeeping
(K6). A deal MATCHES when side, role and layer agree, the price is within
0.2 pip and the time within 60 s.

**Fill rule (fixed):** a buy limit fills at its price on the first tick
with ask <= price; a sell limit on the first tick with bid >= price; an
order placed on a tick can fill from the next tick; every stored tick is
processed. Sensitivities (reported, never deciding): fill only 0.1 pip
through; 250 ms and 1 s placement latency.

- **T0, the floor (no engine):** for every real IN deal, a touching tick
  (ask <= price for a buy, bid >= price for a sell) in [fill - 2 s,
  fill + 0.5 s]. **Mark: >= 95% of real deals, each fleet.** Below it the
  ticks or the fill rule cannot carry a tick-level replay: STOP, back to
  Gemini before any engine is built.
- **T0b, history against near-live (GRC-8):** one hour dumped within 10
  minutes of its end, then the same hour dumped again 24 h later, compared
  tick for tick. **Mark: identical (count, times, prices).** A difference
  means IC thins its history after the fact: STOP, back to Gemini (the
  dump would not be the stream the EA traded on).
- **T1, one step at a time (re-synchronised):** after every real deal the
  replay's POSITIONS are reset to the true ones (its resting orders are its
  own, s3) and it must produce the next real deal. **Marks, per fleet:
  >= 95% of the real deals T0 finds touchable matched (GRC-3, on T0's
  base: rules net of data); replay-only deals (fills that did not happen)
  <= 5% of the real count.** The match rate over ALL real deals is
  reported beside it. Tests the rules one decision at a time; one miss
  cannot cascade.
- **T2, free-running blocks:** from the true book at each init (s3), the
  replay runs alone to the next init. Per fleet and side, summed over
  segments: **scalps S and roll closes R within 10% (or 1, whichever is
  larger); `ROLL_ACCEPTED` within 10% (or 1); rho = (S + R) e / (R D) with
  the open book at each segment end (`grid-as-variance-trade.md` s11)
  within 0.1.** Per-segment errors reported. **A segment whose own T1
  falls below T1's mark is UNPRICED for T2** (GRC-2: its free run follows a
  phantom book) and left out of T2's sums; **if UNPRICED segments hold
  more than 20% of a fleet's real deals, T2 FAILS for that fleet** (so T2
  cannot pass by dropping its worst segments).
- **T3, the whole window from flat (D only), reported, never deciding:**
  the time of the first divergence, deals matched before it, S, R and rho
  per side at the end.

**PASS = T0, T0b, T1 and T2 pass on all three fleets.**

## 7. MISSES: EACH ONE GETS ONE CATEGORY

Assigned in this order (the first that fits):

| | category | evidence |
|---|---|---|
| M1 | data: no touching tick in our dump at the real fill | T0 |
| M2 | fill model: touch without fill, partial fill, queue | ticks vs fills |
| M3 | timing: order live later than the touch; ticks coalesced in OnTick | placement vs touch |
| M4 | L0: place-once, re-centre, S, deadband (K2-K3) | |
| M5 | add: target, fill-time place, deadband re-quote, one-shot reprice (K4) | |
| M6 | exit queue: held exits, passive clamp (K5) | |
| M7 | roll / re-roll: level, extreme, gap, 23:50-00:15 pause (K7-K8) | `ROLL_ACCEPTED` |
| M8 | roll gate: hold, extreme restart (K9) | `ROLL_DEFERRED` |
| M9 | carry: the nightly shift, accrued swap (K10) | `CARRY_*` |
| M10 | init: rebuild, repricing to the new exit, recon (K11, K13) | INIT rows |
| M11 | account-level state: slots (K12), the 1 Oct breaker / float gate, the API soft warn (s4.2) | the account's book from all nine instances; archive rows |
| M12 | hand actions (none in the window, K20) | |
| M13 | unexplained | |

## 8. WHAT A RESULT MEANS

- **What a calibrated replay is FOR** (operator 9 Oct ~05:03Z;
  `grid-as-variance-trade.md` s14): the statistics of our own trading,
  per pair and side, as RANGES and their week-to-week STABILITY, not a
  single optimum; the first-principles toy (s13 there) is the ruler.
- **Pass:** a HOLDOUT on data the replay has not seen, with NO code
  change: from round 3's reload (Fri 9 Oct) to **Tue 13 Oct 22:00Z**
  (GRC-6: three trading days, not a Friday and a Monday alone), EURUSD on
  B, C, D, each segment's own inputs, same marks. **Operator 9 Oct ~22:40Z:**
  only D's EURUSD re-inited on 9 Oct (04:24:14Z), so B and C run on from
  their 7 Oct inits (no synthetic init: the real EA did not restart) to Tue
  13 22:00Z, and all three fleets are scored on the deals after 9 Oct
  04:32Z; B and C read w2 + the holdout dump joined at w2's 01:30 server
  seam (checked for no gap and no overlap). Only after the holdout passes is the
  replay "calibrated on EURUSD" and sweeps on EURUSD allowed. Another pair
  needs its own T0-T2 on its own history first (GBPUSD and AUDCHF next).
- **Fail in M4-M10 (a rule):** that rule's model is wrong. Fix it (cause
  first, BOOT s4), re-run, recorded as attempt 2; at most three attempts on
  this window, then the plan comes back to Gemini. The holdout decides
  either way: fixes on the calibration window never count as a pass on
  their own.
- **Fail in M1-M3 (data, fill model, timing):** a tick-level replay cannot
  be trusted. T2 alone then decides whether COUNT-level use is allowed
  (S, R, rho per segment for sweeps, labelled "count-level").
- **M11 above 2% of real deals:** a one-pair replay cannot stand in for a
  fleet near its limits; account-level state must be modelled from all
  nine pairs before any sweep at deep books.
- **T1 passes, T2 fails:** the rules are right but rare paths compound;
  the largest segments are read first.

## 9. NOT MODELLED (AND WHY)

Money (pips only; the commission per close c enters rho's hurdle, as
pipshed); telemetry, archive, Global Variables, flushes; invariants,
quarantine and halts (none expected: checked, s4.2); the 1 Oct breaker /
float gate and the pre-hotfix API soft warn (account- or terminal-level:
entered as data where they bound, s4.2); session, entry horizon,
auto-eject (off, K16; auto-eject off on IC since the C63 loads); commanded
eject (none in the window, K20); account-wide slots (M11, measured).

## 10. ORDER OF WORK (AFTER GEMINI AND THE OPERATOR'S GO)

1. `scripts/grind_tick_dump.mq5` (Claude; the operator compiles on wine-d,
   runs a one-chunk check, then the window; the wine-test and wine-c hour).
2. T0 on the current export (no engine): the floor, reported at once;
   T0b's two dumps of one hour.
3. s4.2's archive checks, written into s12.
4. Engine (c): a Cursor prompt (RESTATE AND STOP; the seam audit first;
   the harness's broker tested first against hand-derived fills; Cursor
   runs it), through Gemini, then built, run and read by Claude in the
   committed source and output. Then (b): the Python port, tests first,
   equality with (c) on the same ticks, then the sweeps on the Surface.
5. Thu 8 ~22:35Z: the round-2 scoring export becomes the ground truth.
6. T1, T2, T3 and the miss table; a report to the operator.
7. The holdout after Tue 13 Oct 22:00Z.

Negative space: no fleet action and no chart edit; no run before the marks
are ruled; no time-series or price statistic from the ticks; no sweep
before the holdout passes; the replay never decides a compass round or
changes a preset; no mark adjusted to fit a result.

## 11. FOR GEMINI (attack the premises; say which fact is missing)

- **GRC-1.** The engine: (b) the Python replay, (c) the MQL5 harness on the
  real engine, or both? Is (a) rightly out by K21?
- **GRC-2.** The test design: T1 (positions re-synchronised after every
  real deal) and T2 (free-running from each init) decide; T3 is reported.
  Is the split right, and is seeding only at inits (s3: resting orders are
  not archived) sound?
- **GRC-3.** The marks: T0 >= 95%; T1 >= 90% matched (0.2 pip, 60 s) with
  <= 10% replay-only deals; T2 S, R and roll counts within 10% (or 1), rho
  within 0.1. Too loose or too tight for 867 deals, ~300 scalps and ~100
  rolls?
- **GRC-4.** The whole window across four builds and seven input sets
  (s2, s4.3), or the current regime only (15-20 scalps, 4-5 rolls per
  fleet)?
- **GRC-5.** The fill rule (touch, next tick, no latency) fixed in advance
  with sensitivities reported: right, or should T0 choose it?
- **GRC-6.** The holdout (Fri 9 + Mon 12, round 3's geometry, no code
  change) and the three-attempt limit.
- **GRC-7.** M11: account-level state (slots, the 1 Oct gate, the API soft
  warn) as data or a miss category, not modelled, in a one-pair replay.
- **GRC-8.** What fact is missing?

## 12. RULINGS AND RECORD

**Gemini's rulings (pasted 8 Oct ~02:10Z), Claude's check, the operator.**
- **GRC-1: (c), the MQL5 harness, ACCEPTED** (porting errors removed from
  the calibration). His "if (c) fails, the tick data or fill model is
  wrong, definitively" CORRECTED: the init rebuild has no seam, the
  harness's broker is new code, and slots are unmodelled (s5). **Operator
  ~02:16Z: "fine as a first step"; the destination is Python (both sides
  at once, multi-process on the Surface), and Cursor runs the test runs.**
- **GRC-2: UNPRICED ACCEPTED, with a guard** (Claude): UNPRICED segments
  over 20% of a fleet's deals fail T2 (s6).
- **GRC-3: T1 >= 95% ACCEPTED on T0's base** (Claude: T1 cannot exceed T0's
  coverage, so 95% of ALL deals would demand perfect ticks AND perfect
  rules); replay-only deals tightened to 5% to match; the all-deals rate
  reported.
- **GRC-4: the whole window ACCEPTED** (as drafted).
- **GRC-5: the fill rule fixed ACCEPTED** (as drafted).
- **GRC-6: holdout EXTENDED to Tue 13 Oct 22:00Z** (Claude: his
  Friday-liquidity claim is not measured here; the point that two days is
  thin stands, so three days).
- **GRC-7: M11 ACCEPTED.** His "186-slot limit" is the far-from-market
  guard (used + resting <= 200 - 14); near the market it is 194
  (`grind_exitq.mqh` 180-182). Unchanged: M11 is measured, not modelled.
- **GRC-8: historical vs live ticks ACCEPTED as the largest uncontrolled
  variable.** Partly bounded already: the EA's own lattice reads
  `CopyTicksRange` live (K7), the same tick database; T0 measures touches
  at real fills. Added: T0b (s6).
- Operator ~02:16Z on the amendments: taken as accepted with "fine as a
  first step" (Claude said so in the reply; to be corrected if not).

**Record.**
- **K19 answered (8 Oct 02:39Z, wine-d, `grind_tick_dump.mq5` probe):** IC
  serves EURUSD ticks from the window start: first tick at or after
  `2026.10.01 06:30` server = 06:30:00.134 (gap 0 s); the first hour 1,772
  ticks.
- **Dump `w1` (02:42:49-02:43:06Z, wine-d, account 53077984):**
  `ticks_53077984_EURUSD_w1.csv`, 13,947,871 bytes, sha256
  `556b33c682c5c5e5`: 405,245 ticks, 1 Oct 06:30:00.134 - 8 Oct 05:42:44.895
  server, bad_px 0, time_back 0, 168 hourly chunks, no empty weekday hour.
  The tail to 8 Oct 22:30Z is a second dump after round 2 closes.
- **T0 on the 01:10Z export (pre-registered window and rule; reported at
  once, s10.2): PASS, 867 / 867 real IN deals touched (B 259 / 259, C 294 /
  294, D 314 / 314; ENT and EXT alike).** Checks that the test is not
  trivial (reported, not marks): the first touching tick precedes every
  fill (touch - fill from -1,959 to -45 ms, median -260 ms: IC's fill
  latency after the touch); in 861 of 867 the last tick at or before the
  fill sits exactly AT the limit (fills at the touch, not through it);
  moving every limit 0.5 / 1 / 2 pips against drops the rate to 4.8% /
  1.8% / 0.6% (the ticks are exact to the price); the same prices 5
  minutes later touch 48%. B's and C's fills match wine-d's ticks as well
  as D's (one feed, inferred; the wine-test / wine-c hour of s4.1 still
  runs). T0 is re-run on the round-2 scoring export.
- **s4.1 PASSED: one feed (8 Oct 16:10-16:24Z, operator).**
  `grind_tick_dump.mq5` (`main` `dc74051`, sha256 `4fdbb601f3b816db`, on
  wine-test and wine-c; wine-d's `eae09b4` copy differs by a comment) on a
  fresh EURUSD chart, inputs `2026.10.08 12:00` to `13:00` server, probe off,
  tag `cmp`: wine-test 53066709, wine-c 53071896 and wine-d 53077984 each
  3,689 ticks, 12:00:00.163-12:59:59.567, bad_px 0, time_back 0; the files
  without their `#` header line (it names the account) hash IDENTICAL,
  `1dcf00db198632c9` over 3,690 lines. B, C and D trade one EURUSD feed:
  every fleet replays on wine-d's ticks (no per-fleet dump).
- **s4.2 checks 1-4 DONE (8 Oct 16:30-16:46Z; Claude on `--export-archive`
  of `GRIND_EURUSD_OPTB` / `OPTC` / `OPTD` (1,131,962 / 1,113,415 / 917,307
  bytes, Downloads, 8 Oct ~16:32-16:37Z) and the boxes' Experts logs).**
  (1) `LATTICE_CONFIG` at every init = K15 on all three (re-roll false at
  the Monday compile init, true from the Load; gate -1 at the Wednesday
  compile init, 0 from the Load). (2) No `BREAKER_GATE_ON` / `_OFF` on any
  EURUSD instance (archived since `6c57830`, before `0335f25`): the float
  gate never bound; no `BREAKER_GATED` interval. (3) `WARN_API_SOFT_LIMIT`
  is a terminal log line only (`fxgrind.mq5` 432), not archived: on
  wine-d's 1 Oct log, 88 EURUSD lines, one a minute, 19:31:58-20:59:31Z
  (the log clock is UTC: it stops at the 21:00Z server-day reset); 2 Oct
  none; wine-test and wine-c none either day. **One interval: D,
  `API_SOFT_WARN` from 1 Oct 19:30:58Z (the earliest onset; up to 60 s
  early) to 21:00:00Z = server `2026.10.01 22:30:58` to `2026.10.02
  00:00:00`, inside D's D1 segment.** (4) `DEAL_EVENT_MISSED` 0 on all
  three; `DEAL_REPLAYED` paired with `DEAL_EVENT_AFTER_REPLAY` (B 283, C
  326, D 330: the healthy timer-first pattern); in-window quarantines, all
  2 Oct around the 12:30Z US payrolls, none halted: C `I3_SHORT_NAKED`
  12:33:51Z (1.3 s), `I3_LONG_NAKED` 12:52:10Z (1.4 s); D `I3_SHORT_NAKED`
  12:30:20Z (1.5 s), `I6_LONG_EXIT_FILL_ADVERSE` 12:30:31Z (1.6 s); B's one
  (1 Oct 01:24Z) is before its window. About 6 s of skipped engine calls
  in all: recorded as data, not modelled (inside T1's 60 s; M11 if a miss
  traces to one). Check (5), K18 on the scoring export, tonight.
- **The swap model for `swaps.csv` (8 Oct ~19:50Z, Claude, the three
  EURUSD archives).** Every closed EURUSD ENT position on B, C, D since 24
  Sep (622 of 622) has the swap, to the cent, of: per rollover INTO server
  date D, the latest `CARRY_SNAPSHOT` rate before D 00:00 server, x3 into
  THURSDAY (Wednesday night), x0 into Saturday and Sunday, x1 on every
  other night (into Monday included: x0 there breaks 32). One-night longs:
  into Thu 1 Oct -0.25 (10 positions), into Thu 8 Oct -0.24 (7); into Wed
  30 Sep / 7 Oct -0.08. `research/replay/build_swaps.py` (tests first, 9
  tests, a mutation round) writes the file. Limit: the archive's swaps are
  rounded to 0.01 per position, so rate changes under ~0.5 points a night
  are not resolved. **The EA's carry pass applies its triple one night
  early** (backlog C144); the harness runs that code as it is.
- **The segment table (8 Oct ~20:00Z, Claude,
  `research/replay/build_segments.py`, 10 tests, a mutation round 16 of
  16).** The archive's `ea_time_ms` is UTC; run-file times are server ms
  (+3 h). On the three archive exports: B 9 rows, C 10, D 10 = **29 = the
  23 Load segments of s2 + 6 compile inits** (each holds 0 IN deals; they
  stay in the run file as segments of their own). Every W / add / exit, S,
  DB, re-roll and gate matches the s2 table, and the IN deals per Load
  segment to the 01:10Z export match s2's IN column on all 23.

- **The swap model CORRECTED (8 Oct ~20:35Z, HANDOFF s73).** s72's "622
  of 622 to the cent" held within half a cent; measured EXACTLY it matched
  600 of 626. The rule that matches **626 of 626 exactly** (every closed
  EURUSD ENT position of B, C, D since 24 Sep): per position and per night,
  round(rate x mult x tick_value x volume, 2), the rate of the
  CARRY_SNAPSHOT NEAREST to D 00:00 server (no snapshot on Mon 5 Oct night:
  the night into Tue 6 Oct is priced at the 6 Oct 01:38 init snapshot,
  1.409 short, not Saturday's 1.508). The same model equals the EA's own
  carry ledger (`CARRY_EXIT_SHIFT` `accrued_ledger_pips`) on 69 of 69.
  **`swaps.csv` carries EFFECTIVE points** (operator ~20:37Z): each row =
  that night's cents at 0.01 lot / (mult x 0.01), so the harness's
  unrounded booking (base s3.4 step 1) equals the broker's cent; a `#`
  line says so. Built to 9 Oct from tonight's archives (sha256
  `dc7da509b35e6846`); booked the harness's way it reproduces every
  closed position whose nights fall in 1-8 Oct (116 of 116).
- **The replay's inputs BUILT (8 Oct ~20:30-21:25Z; `research/replay/`,
  tests first, mutation rounds all caught):** `build_seeds.py` (seed =
  open ENT positions at the init from fill_logs; vl = the latest
  ROLL_ACCEPTED `detail.level`; swap = the model above), `build_real.py`
  (fix 1 A1's ENT / EXT / OUT_BY / ROLL rows; intervals), `build_inputs.py`
  (per fleet: run_eurusd_b / c / d, seg_id B 1-9, C 10-19, D 20-29,
  seed_<seg_id>.csv, flat = empty). At every one of the 29 inits: no open
  EXT position; D's REBUILD_SUMMARY counts and every EXIT_REBUILT price
  (1 Oct 09:21, 6 Oct 06:20 server) agree with the seeds' entries, VLs and
  swaps. On the 8 Oct ~22:38Z archives (B sha256 `4b584882a288681f`, C
  `c51dd5b5fec41502`, D `3866d5ff6324266f`; each a superset of the
  afternoon copy, no row changed): 37 files, real 684 / 765 / 763 rows.
- **Ticks `w2` (8 Oct 22:45Z, wine-d):** IC serves EURUSD from 1 Oct
  04:00:00.097 server (probe 21:30Z), so w2 = `2026.10.01 04:00` -
  `2026.10.09 01:30`: 476,821 ticks, 190 chunks, bad_px 0, time_back 0,
  no empty weekday hour; 16,430,291 bytes, sha256 `db2ea94173a4d0c8`.
  Needed because C seg 11 (1 Oct 09:46 server) seeds a long side AT CAP
  whose newest open is 06:01:24, before w1. **Against w1:** time, bid and
  ask identical on all 405,245 overlapping ticks; only `flags` differ in
  w1's last ~12,800 ticks (bit 128 added later; not read by the harness).
  Every run row names w2.
- **T0 on the scoring export (`study_2026-10-08_2235.jsonl`, sha256
  `577b777bfb7d2270`) with w2: PASS 1052 / 1052** real EURUSD IN deals
  from each fleet's window start to 8 Oct 22:00Z (B 323, C 359, D 370);
  touch before every fill (median -260 ms, range -1,959 to -42 ms).
  Check (5) of s4.2: these are the window's IN deals.

- **T0b PASSED (9 Oct 04:20Z, wine-d):** `t0b_b` (the same inputs as
  `t0b_a`: `2026.10.08 05:00` - `06:00` server) against `t0b_a` (dumped 8
  Oct 03:02Z, within 10 minutes of the hour's end): 2,144 ticks each;
  time, bid and ask identical (sha256 of the three columns `a4061adcd02f5c70`
  on both). Only `flags` differ (bit 128 added after the fact, as w1 / w2).
  With T0 (1052 / 1052), T0b and s4.1, the data marks of s6 have passed.
- **D's EURUSD reloaded for round 3 (9 Oct 04:24:14Z: exit 9 L / 11 S,
  `rebuild=true/false`)**: one more init inside the holdout (s8), run with
  its own inputs.

- **The first real runs (9 Oct, branch `replay-harness`).** At `86c1194`
  (first-run prompt) five runs aborted `LATTICE_HISTORY`: the preload began
  at the newest open across BOTH sides, the EA tracks a capped side from its
  OWN newest open, and the 300 s prune dropped a capped side's history in
  sync. Fix 1 (`prompts/cursor_replay_first_run_fix1.md`, Gemini GF1-1..4):
  the lattice is backfilled from the ticks in memory, once per capped
  episode, by the EA's own formula (`32c90be`; suite 295 / 295): all six runs
  complete.
- **The comparison tool (`research/replay/compare.py`, tests first, a
  mutation round).** A deal matches on segment, side, role, layer, price
  within 0.2 pip and time within 60 s, one to one (nearest first, then the
  largest number of pairs). **The price is the ORDER's** (fill_logs
  `order_price_open`; Gemini GF2-4): IC fills carry price improvement (D: 237
  of 370 IN deals not at the order price, up to 2.3 pips) that the fixed fill
  rule (GRC-5) does not model; the deal-price T1 is reported beside it.
  Results: `research/replay/results/eurusd_20261008_<harness>/`.
- **T1 at `32c90be`: FAIL** (matched / touchable; replay-only): B 88.5% /
  28%, C 92.2% / 20%, D 91.1% / 11%. Most matched deals agree to the point,
  ~0.26 s before the real fill (the broker's latency after the touch).
  Causes found: (H1) the real EA keeps its resting orders across an init (no
  send in 2 min after 23 of the 29 window inits; the other six explained),
  the replay placed new ones; (H2) sync re-opened a layer the replay had
  already exited (17 / 13 / 9 replay-only exits); (H3) the 1 Oct gate below.
- **s4.2 check 2 CORRECTED: the 1 Oct ADR-160 entry gate DID bind** on B and
  C (and on D for half an hour). `BREAKER_GATE_ON` is written only by an
  account's REPORTER instance (`Grind_BreakerGateTransition`), and none is
  archived on any instance (200 h query, 9 Oct): its absence on EURUSD
  proved nothing. The event log (1 Oct 21:16Z) recorded the gate. From
  send_logs: each EA placed its short L00 through the gate check at 17:51:06
  (B), 17:50:43 (C), 17:46:35 (D) server, then did NOT place the fill-time
  add after the short L00 filled at 18:36:5x; D placed again at 19:07:24. In
  the inputs as `BREAKER_GATED` (the EARLIEST ON time the record allows,
  Gemini GF2-3; off at B's / C's re-init and D's 19:07:24.789).
- **send_logs exported** (pipshed `--export-sends`, `6ea487e`; send_logs keep
  14 days): `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl` (Downloads; 1,623 /
  1,722 / 1,403 rows from 25 / 28 Sep / 1 Oct). The rebuilt order book
  (`research/replay/build_orders.py`) equals the order price, side, layer
  and role of EVERY real fill (B 439, C 461, D 370). Only 2-6 orders rest at
  an init (the exit queue, K = 1, H = 0, holds the rest).
- **Fix 2** (`prompts/cursor_replay_fix2.md`, Gemini GF2-1..5): each
  segment adopts its init's resting book (`orders_<seg_id>.csv`, run field
  23); a real EXT row drops its layer from the true book; a print-only guard
  `RPL|ORDERS_KEPT`. `b8adb15` (suite 318 / 318 at `e76c5af`: Cursor
  corrected RT41's count to the exit fills, the close-by leg also reads
  `EXT`; Claude's spec error). **T1 at `b8adb15`: still FAIL**: B 87.6% /
  12.1%, C 91.1% / 8.4%, D 91.4% / 4.3% (D's replay-only now within its
  mark). T2 fails on the UNPRICED share (most segments miss T1's mark on
  their own); on the priced segments S, R, ROLL_ACCEPTED and rho agree.
- **The next cause (fix 3): the carry ledger lives in terminal Global
  Variables** (`GRIND_CARRY_ACCRUED_<ticket>`, `ea/grind_carry.mqh`
  703-729; also `_SHIFT_`, `GRIND_VL_`, `GRIND_CARRY_DAY_`), which survive a
  restart; the harness deletes them (`Rpl_ClearCarryGvs`) and seeds only the
  VL. An exit the queue places later in a segment then lacks its accrued
  carry: the remaining 0.8 / 1.6-pip exit pairs (B seg 1, 7; C seg 11, 13).
  The accrued value at an init is readable from send_logs (every exit
  placement = formula + accrued). Then to classify: 1 Oct short L00
  placements (M4), the 2 Oct 12:30Z news burst (M3), B's L07 exits on 5 Oct,
  C's first minutes after its 6 Oct re-roll reload.
- **Fix 3** (`prompts/cursor_replay_fix3.md`, Gemini GF3-1..4; written 9
  Oct, not yet run): seed column 9 `accrued` (`build_seeds.accrued_price`:
  the last weekday 23:50 server pass before the init; ledger = swap so far,
  pending = the pass snapshot's points x the EA's multiplier for TOMORROW
  (x3 into Wednesday, C144; x0 Sat / Sun); -direction x pips x 0.0001; 0
  when opened after it), 174 of 174 checked against the exit placements in
  send_logs; the harness sets the GV at each init (A1) and keeps it in the
  sync true book for re-seeds (A2). Expected: the 15 paired exit misses at
  `b8adb15` (0.8-1.6 pips; B 9, C 4, D 2) go. Sync-only residue: a re-seed
  after an in-segment pass carries the pre-pass value until the next pass,
  and the true book's swap does not roll.
- **Fix 3's count and check CORRECTED (9 Oct ~22:15Z, new chat).** "15
  (B 9, C 4, D 2)" was a miscount: in the committed b8adb15 `misses.csv`,
  real exits with a replay exit of the same layer 0.8-1.6 pips lower within
  60 s are B 8, C 4, D 2 (18 at any distance in time). "174 of 174" could
  not be reproduced; `research/replay/check_accrued.py` re-derives it with
  two written rules: rule N (init to the next pass) 108 of 118 seed rows
  with a placement agree, rule W (pass to pass) 217 of 241, every difference
  a non-carry cause (C's 6 Oct re-roll burst, D's rebuilds with new exit
  pips, one roll timing). The Mon 5 Oct pass DID run on EURUSD B, C, D (2
  snapshots each; s73's "no snapshot" did not hold for EURUSD).
- **Fix 3 through Gemini three times** (`prompts/cursor_replay_fix3.md`,
  `44edcc9`, 349 lines; s8 second round, s9-s10 third, s11 his rulings
  checked): GF3b-4 (real, wider than stated) added **A3**: the sync true
  book rolls its swap nightly and copies each held layer's accrued GV at
  every sync reset (a real ENT entered it with swap 0 / accrued 0 and the
  seeded swap stayed frozen; ~110 in-segment and ~47 seeded layers held
  across a pass). RT43-RT47; 338 run. P1 `tools/replay_run.ps1` made
  explicit (the `Script=` ini; 9 Oct's B and C r4 inis read `Expert=`).
- **Fix 3 built and run (9 Oct ~23:00-23:20Z, `replay-harness`):** tests
  `438a00b`, core `624a29b` (A1-A3), script `4e624fc` + `8a58547` (Claude's
  read found four departures from P1: the `$Root` prefix without `\`, the
  next day's log lines dated today, input names checked while writing, a
  trailing LF in the ini; fixed, nothing new added). Suite **338 / 338**
  (`rt_624a29b`); six runs, no ABORT, ORDERS_KEPT below seeded only on C
  seg 16 (3/4, 2/4, as before); outputs `a08fb0d`.
- **T1 at `624a29b`: still FAIL, much closer.** Matched / touchable: **B
  92.3%, C 93.0%, D 93.8%** (b8adb15: 87.6 / 91.1 / 91.4); replay-only **B
  3.4%, C 4.2%, D 2.4%** (12.1 / 8.4 / 4.3): **within the 5% mark on all
  three.** Short of 95% matched by B 9, C 8, D 5 deals. No exit miss is left
  with a replay exit 0.8-1.6 pips lower within 60 s (the carry pairs are
  gone). T2: five of six sides pass on the priced segments (B short S 28
  real / 31 replay); T2 still FAILS on the UNPRICED share. Results:
  `research/replay/results/eurusd_20261008_624a29b/`.
- **The 73 misses and 35 replay-only deals, first pass**
  (`research/replay/classify_misses.py` -> `classified.csv`; rules in its
  header). Misses: **M3 16** (the 2 Oct 12:30Z payrolls burst; and L00
  placements: the replay's close-by completes at once (B 1 Oct 11:12:11.208:
  the EXT and both close-by legs on one tick), so it places the new L0 at
  that tick's mid; the real EA places it after the broker's close-by (EXT
  11:12:11.489, OUT_BY 11:12:12.497, L0 11:12:13.026) at another mid, and
  the touch reaches one price and not the other (there 1.13025 real against
  1.13034 replay, touch 1.13027); twice the replay filled at exactly the
  predicted price 0.7-9 s before the real), **M4? 11** (L00 re-centred before its fill: the
  tick that re-centred decides the price), M10 3 (C seg 16), M11 1 (D's 1 Oct
  gate edge), M9 1 (D 5 Oct 23:50:01), M13? 4, **open 37** (22 exits of held
  or rolled layers, 14 deep adds, 1 L00 exit). Replay-only: M3 21, M4? 3,
  M10 2, M13? 1, open 8. The open rows cannot be read without the replay's
  OWN order log (placements, modifies, removals and their prices): the
  harness writes deals and events only.
- **For the operator and Gemini (not ruled):** (1) the M3 placement case is
  the simulated broker's close-by latency (0 in the harness; the real
  close-by follows its EXT by 0.35-14 s, median 0.84 s on B): s6
  pre-registered placement-latency sensitivities (250 ms, 1 s) as REPORTED,
  never deciding; s8 reads a fail in M1-M3 as "tick-level cannot be
  trusted". (2) Fixes 1-3 corrected the harness's state (seeding, resting
  orders, GVs), not a rule's model; whether they count toward s8's three
  attempts is not ruled. Next: a harness prompt that writes the replay's
  order log (observability only), then the open rows.


- **Fix 4: the replay's own order log** (`prompts/cursor_replay_fix4.md`,
  `d318aa5`; Gemini GO4-1..4: the close-by latency stays a REPORTED
  SENSITIVITY, s6, and fixes 1-3 do NOT count toward s8's three attempts).
  Built `6386a22` / `8d05796` / `298d9c1` (Claude's read: four extra
  assertions and one default removed); suite **381 / 381**; six runs
  `7fd02d3`. The deals and books are byte-identical to `624a29b`'s, the
  events differ only in the run clock: the log only observes.
- **The 37 open misses read against it** (`research/replay/read_orders.py`
  -> `results/eurusd_20261008_624a29b/orders_reading.csv`): **14
  AT_PRICE_TOUCHED** (a replay order sat at the real price, a tick reached
  it exactly, no replay fill), **16 OTHER_PRICE_ROLLED** (the real rolled
  the layer, the replay did not), 4 OTHER_PRICE (two adds 1 point apart, two
  rolled exits with replay lattice rows), 3 NO_ORDER (adds after earlier
  misses). Two harness defects found:
  (1) **exact touches never fill at 14 price values** (84 touches in all six
  runs; 600 other values always fill; no value both): order prices are
  NormalizeDouble'd at the send, tick prices StringToDouble'd from the file,
  compared raw; (2) **sync marks a held layer rolled before the replay can
  roll it**: the sync reset sets the true VL on every layer, and a ROLL row
  carries the EA's clock, 0.57-0.60 s ahead of the crossing tick (B 6 Oct S
  L01 / L02); ROLL_ACCEPTED sync vs free B seg 4 0 / 10, seg 7 0 / 7, C seg
  11 0 / 13, D seg 24 0 / 10. The L00 cases are confirmed: the replay
  placed L0 one tick after its close-by (B 1 Oct 11:12:11.412 at 1.13033;
  real 11:12:13.026 at 1.13025); the three M13? L00 rows are the same timing
  (a replay order 1 point away). Fix 5 (`prompts/cursor_replay_fix5.md`):
  P1 every file price on the symbol grid; S2 the sync reset leaves a held
  layer's VL alone; to Gemini.
- **Fix 5** (`prompts/cursor_replay_fix5.md`, Gemini GF5-1..4, GF5b-1 for
  RT8b): built `bafe936` / `58e3c0f` / `90fbce4`; suite **390 / 390**
  (`rt_90fbce4`); six runs `6972e16`, no ABORT, ORDERS_KEPT short only on C
  seg 16 (3/4, as before). ROLL_ACCEPTED sync vs free now agree (B seg 4
  11 / 10, seg 7 7 / 7; C seg 11 13 / 13; D seg 24 10 / 10).
- **T1 at `90fbce4`: PASS on all three fleets.** Matched / touchable **B
  96.0%, C 96.1%, D 96.5%** (310 / 323, 345 / 359, 357 / 370); replay-only
  **B 3.4%, C 4.5%, D 2.4%**. **T2: FAIL on all three, on the UNPRICED share
  alone** (B 31.9%: segs 1, 2, 3; C 36.2%: 11, 12, 13, 16; D 34.6%: 21, 23;
  mark 20%); the per-side sums (S, R, ROLL_ACCEPTED, rho) pass on all six
  sides. Two of the unpriced segments fail on one miss (B 2: 4 / 5; C 12:
  6 / 7); B 3, C 13 and D 23 (the 2 Oct payrolls burst) fail on replay-only
  deals (9, 8, 5). Results: `research/replay/results/eurusd_20261008_90fbce4/`.
- **The 40 misses and 36 replay-only deals** (`classified.csv`,
  `orders_reading.csv`): misses M3 16, M4? 11, M13? 4, open 5, M10 2 (C seg
  16), M11 1, M9 1; replay-only M3 21, open 9, M4? 3, M10 2, M13? 1. The 32
  misses fix 5 aimed at are gone: exact touches now fill at every price
  value (621 values; no value never fills). Six of the open / M4? rows read
  by hand from the order logs and send_logs are timing: (a) an ADD placed
  after a close-by (B 2 Oct 16:57, B 6 Oct 14:25: the replay places it on
  the next tick, the real after its close-by at another mid; the replay
  fills, the real does not); (b) the EA's sends are serial (B 1 Oct 13:00:
  the real re-centres L0 0.6 s after the replay, behind two other sends, at
  another mid); (c) the broker's fill after a touch (C 8 Oct 19:17: both
  sides' L05 at 1.11983; the bid 0.5 pip through it for 1.8 s without a real
  fill, then the EA moved the order; the real L05 at 1.12007 filled 2.2 s
  after its first touch); (d) a placement difference carried forward (D 1
  Oct: the real L0 1.1 pip from the replay's after a close-by, so only the
  replay crossed the 14-pip stranded mark at 10:31 and re-centred).
- **One harness defect left (Claude's read of `90fbce4`):** an order placed
  in `Rpl_ProcessCloseByDone` (stage CB_DONE) gets its placement time at
  the NEXT tick's scan (`Rpl_ScanNewOrders` runs before it), so it cannot
  fill on the first tick after it is placed, against s6's fill rule. 4 sync
  cases where that tick touched (B 3, C 13 twice, D 23; the C 13 14:44:22
  replay-only exit filled one tick late).
- **For the operator and Gemini (not ruled):** (1) T1 passes and T2 fails
  on the UNPRICED share only, with the misses left mostly timing: does s8's
  "T1 passes, T2 fails" or its "fail in M1-M3" govern? (2) Before the
  holdout (no code change after it starts): fix the CB_DONE defect and run
  s6's placement-latency sensitivities (250 ms, 1 s; reported, never
  deciding), or freeze `90fbce4` as it is?

- **Before the holdout (10 Oct ~01:35-01:50Z, new chat; NOTHING RULED).**
  The new chat's boot found that this plan puts the holdout after a PASS
  (s6: T0, T0b, T1 and T2 on all three fleets), and T2 fails. Nobody has
  ruled that the holdout runs anyway (previous chat, ~01:40Z). Its data
  are collected whatever is ruled (send_logs keep 14 days). The facts
  below were checked in the committed outputs of the current harness:
  - **Why each UNPRICED segment is unpriced** (s6: a segment fails T1's
    mark when matched is below 95% of its touchable deals, or replay-only
    is above 5% of its real deals):
    - B 1: 40 of 43 matched (93.0%).
    - B 2: 4 of 5.
    - B 3: 9 replay-only of 55 (allowance 2.75).
    - C 11: 42 of 45 (93.3%).
    - C 12: 6 of 7.
    - C 13: 8 replay-only of 64 (allowance 3.2).
    - C 16: 12 of 14 (85.7%).
    - D 21: 69 of 74 (93.2%).
    - D 23: 5 replay-only of 54 (allowance 2.7).
  - **The CB_DONE defect cannot move T2's verdict.** In the harness's
    tick, `Rpl_ScanNewOrders` (which stamps each order's placement time)
    runs before `Rpl_ProcessCloseByDone`, and `Rpl_FillsOnTick` skips an
    order whose placement time is not before the tick. So an order placed
    after a close-by can fill only from the second tick after it. The
    defect touches at most one replay-only deal in each of B 3, C 13 and
    D 23, and those segments are above their allowance by more than one.
    The TIMER stage also runs after the scan. In the six runs it placed no
    order (the order logs: TIMER PLACE 0; the carry pass moves exits by
    MODIFY, which keeps the placement time).
  - **s6's three sensitivities were pre-registered and never run:** fill
    only 0.1 pip through; 250 ms and 1 s placement latency.
  - **The holdout has not started:** the harness has read no tick after
    w2's end (9 Oct 01:30 server). The holdout's deals begin at 9 Oct
    04:32Z (07:32 server).
- **For Gemini (GRC2; attack the premises; say which fact is missing).
  Answer only these.**
  - **GRC2-1.** T1 passes on all three fleets. T2 fails only because
    UNPRICED segments hold more than 20% of each fleet's real deals (B
    31.9%, C 36.2%, D 34.6%); the per-side sums (S, R, ROLL_ACCEPTED, rho)
    pass on all six sides. The misses left are mostly timing (M3: 16 of 40
    misses, 21 of 36 replay-only deals). s8 has two branches that could
    apply. "T1 passes, T2 fails" says the rules are right and rare paths
    compound. "Fail in M1-M3" says a tick-level replay is not trusted and
    T2 alone decides count-level use, and T2 fails. Which governs, and
    what does it allow?
  - **GRC2-2.** Does the holdout run with T2 failing on the window? s8
    puts it after a PASS. If it runs, what does a holdout pass or fail
    then mean?
  - **GRC2-3.** If it runs:
    - (a) Is each segment's T1 mark (for UNPRICED) taken over the deals
      after 9 Oct 04:32Z only, as s8 scores them?
    - (b) B and C each run ONE segment, from their 7 Oct inits (no
      synthetic init: the real EA did not restart). D also has one after
      its 9 Oct 04:24Z init. So for each fleet the UNPRICED share is 0% or
      100%. Is the 20% rule still the right guard there? If not, what form,
      fixed before any holdout run?
    - (c) T2's free run for B and C starts from the 7 Oct true book (no
      init on 9 Oct) and is scored on the deals after 04:32Z: right?
  - **GRC2-4.** No code change is allowed once the holdout starts.
    Before it, which: (a) fix the CB_DONE defect, run s6's three
    sensitivities (reported, never deciding), then freeze; or (b) freeze
    the harness as it is? GO4-2 ruled "no latency model in the harness".
    Would a placement-latency input that defaults to 0, and is used only
    for s6's reported runs, stay inside that ruling? And does s6's latency
    delay every placement and modify, or only placements after a close-by?
  - **GRC2-5.** rho with the open book (s6). `compare.py` computes rho =
    sum (S + R) e / sum R_eff D, with R_eff = R + max(0, -open pips) /
    (D - e). Open losses are rolls in waiting with no closes yet, so they
    go in the denominator only (`grid-as-variance-trade.md` s11). s6's
    words "rho = (S + R) e / (R D) with the open book" do not say where the
    open book goes. Is `compare.py` right?
  - **GRC2-6.** What fact is missing?

Line count: 803
