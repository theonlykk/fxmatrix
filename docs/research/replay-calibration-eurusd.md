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
  positions only.
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

- **Pass:** a HOLDOUT on data the replay has not seen, with NO code
  change: from round 3's reload (Fri 9 Oct) to **Tue 13 Oct 22:00Z**
  (GRC-6: three trading days, not a Friday and a Monday alone), EURUSD on
  B, C, D, each segment's own inputs, same marks. Only after the holdout passes is the
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

Line count: 521
