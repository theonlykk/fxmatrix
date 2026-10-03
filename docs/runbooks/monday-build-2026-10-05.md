This message has a line count at the bottom

# RUNBOOK -- THE MONDAY BUILD, 5 OCT

| | |
|---|---|
| Status | **REVIEWED 3 Oct** (Claude's draft; Gemini GB-1..GB-5, s9). Runs Monday after 22:00Z on the operator's go |
| Backlog | C95 (ADR-165 ON), C96 (twins retire), C88 (wine-c loads the Scripts copy), C105 (DONE 3 Oct: `main` `2859be6`) |
| Sources | ADR-165 s4, s7, s9-s10; 02_TRAPS 2 Oct day (which `.ex5` loads) and afternoon (retiring by hand); HANDOFF s32 (the hotfix deploy, the pattern followed here); `docs/runbooks/compass-round.md` |
| When | Mon 5 Oct, AFTER 22:00Z (round 1's last window closes; the twins carry round-1 probe data until then). Never 20:50-21:15Z (IC break, ADR-165's rollover pause) |

## 1. WHAT CHANGES

- **Code:** IC fleets B, C, D move from `893e065` (`hotfix-api-stop`) to
  `main` `2859be6`. The only trading-code difference is ADR-165
  (`3df13f0`, `87c9207`): `grind_engine.mqh`, `grind_pure.mqh`,
  `fxgrind.mq5` (+ tests). With `InpLatticeReroll=false` trading is
  unchanged (ADR-165 s7). Suite 2447/2447 on GBPUSD and EURUSD at
  `2859be6` (desktop, 3 Oct).
- **Input:** `InpLatticeReroll=true` on every remaining IC chart (requires
  `InpVirtualLattice=true`, which all IC charts have; else FATAL at init).
- **Instances:** the six twins retire: `GRIND_AUDNZD_ALT{B,C,D}` (magic
  22260902) and `GRIND_NZDCAD_ALT{B,C,D}` (22260802). Each fleet then runs
  nine instances, one per pair (compass round 2).
- **Not changed:** FTMO (cycle 3, `aa6970a`); cap (8), widths, add, exit,
  deadband, `InpStrandedThreshPips`, breaker off. Cap 10 and the fixed
  widths are the NEXT session (C99), a separate structural step.
- **Structural** (runbook compass-round s4.1): round 2 starts after this
  build AND the cap-10 reload.

## 2. BEFORE (desktop, Monday before 22:00Z)

1. Presets commit (Claude, patch): `InpLatticeReroll=true` added to every
   live IC preset (`presets_b/*_b_lat`, `presets_c/*_c_lat` and `*_c_p1`,
   `presets_d/*_d_lat` and `*_d_p1`), so a later reattach does not turn it
   off. The twins' `*_dup_*` files stay in the repo (history), unused.
2. pipshed patch READY (C119, built 3 Oct: `99980da` tests, `4d294a6`
   fix, tree `e3b23a94`, 39/39 suites; in Downloads as
   `pipshed_c119_APPLY_MONDAY_AFTER_TWINS_RETIRED.patch`; deployed in s6,
   NEVER before the twins are gone): the six twins into
   `GRIND_RETIRED_INSTANCES`; the fleet strip lists B, C, D become the nine
   `_OPT` ids (as A's did, C107); each fleet's page keeps eleven tiles.
3. Round 1 is scored from the archive after 22:00Z; nothing in this build
   touches the archive, so scoring can run before or after the build.
4. Tunnels open: VNC 5912 (wine-d), 5911 (wine-c), 5910 (wine-test).

## 3. PER BOX (wine-d first, then wine-c, then wine-test)

**3.1 Read the box (read-only).** pipshed card: all instances LIVE, none
halted. Note each twin's open positions and resting orders (Trade tab,
filter by comment `GRIND|ALT|`).

**3.2 Retire the two twins (VNC, by hand; 02_TRAPS 2 Oct afternoon).**
For each twin chart (read `InpTelemetryInstance` and `InpMagic` in F7,
then Cancel: F7 then OK is a restart, not a removal):
1. Right-click the chart -> Expert Advisors -> Remove. Experts log:
   `deinit reason=1`.
2. Delete the twin's resting orders, ENTRIES FIRST (`...|ENT`), then exits
   (`...|EXT`): an entry that fills after removal is unmanaged.
3. Close By the twin's longs against its shorts (twin and primary tickets
   are near-identical: match the comment `|ALT|`, never the ticket).
4. Close the rest at market. On a demo the realised loss equals the open
   MTM equity already carried; the operator's go covers it (GB-1).
5. Trade tab: no position or order with `|ALT|` left.

**3.3 Repo to `main` (shell, as root).**

    sudo -u khalid git -C /home/khalid/fxmatrix-repo fetch -q origin
    sudo -u khalid git -C /home/khalid/fxmatrix-repo checkout -q main
    sudo -u khalid git -C /home/khalid/fxmatrix-repo pull -q --ff-only
    sudo -u khalid git -C /home/khalid/fxmatrix-repo diff --stat 2859be6 HEAD -- ea/

The last line must print nothing (no EA change after `2859be6`).

**3.4 Copy the sources to BOTH copies** (Experts/fxmatrix and
Scripts/fxmatrix), as khalid, then `cmp` every `ea/*.mq5 ea/*.mqh` against
both: drift 0.

**3.5 Compile ONE file, the one the charts load** (MetaEditor, F7):
wine-d and wine-test `Experts/fxmatrix/fxgrind.mq5`; **wine-c
`Scripts/fxmatrix/fxgrind.mq5` (C88)**. 0 errors, 0 warnings. The charts
re-initialise on the new `.ex5`. **On wine-c (GB-5):** compiling the
Experts copy there, or dragging the EA onto a chart from the Navigator,
leaves charts on two different builds; 3.6's `ea_build` check on all nine
catches it.

**3.6 Check the re-init** (Experts log or the box's MQL5 log, grep): 9
`CONFIG` lines, 9 `REPLAY ready`, 9 `GRIND_REROLL enable=false`, FATAL 0,
each `ea_build` = the compile time; inputs kept (spot-read one D1 probe's
add/exit and `InpStrandedThreshPips`).

**3.7 Turn re-roll ON, chart by chart** (F7 ON THE CHART ->
`InpLatticeReroll=true` -> OK; one row changed; read the instance first;
never re-attach from the Navigator, least of all on wine-c): `deinit=5`, then
`GRIND_REROLL enable=true`, `LATTICE_CONFIG` with `"reroll":true`, FATAL 0.
Pilot GBPUSD; then the other eight.

**STOP before the next chart or box on:** FATAL, CRITICAL,
`INVARIANT_FAIL`, `RECON_FAIL`, any `REBUILD_*` failure, a missing POST
ok, a `CONFIG` with changed geometry, a twin order or position still
present, `ROLL_ACCEPTED` with `"reroll":true` bursting on more than a
few sides at once (expected only where a side is fully rolled and the
market has crossed a fresh level), or **two re-rolls of the same side with
the same EA timestamp** (`ea_time_ms`: one call; the throttle is one per
side per call, GB-4). Several re-rolls of one side within a second on
successive ticks are a backlog clearing, as designed (ADR-165 s4.7).

## 4. AFTER EACH BOX

- pipshed card: nine instances LIVE (the twins show stale until s6).
- Record: box, compile time, `.ex5` path and size, re-init counts, the F7
  times, the twins' realised P&L.

## 5. EXPECTED AFTER RE-ROLL ON

Sides that are fully rolled and already past their next level (e.g.
NZDCHF long) may re-roll on the first ticks: one re-roll per side per tick
(ADR-165 s4.7), each a modify (one request), its exit moved to about one
add step and one exit from the market. `ROLL_STRANDED` stops repeating on
those sides. No new position or market order comes from this path.

## 6. pipshed (after all three boxes)

Deploy the retire patch (s2.2): `git am`, tree check, push, Railway
deploy; then the strip shows B, C, D at 9/9 and the twins' critical rows
as resolved.

## 7. WHAT IS LEFT FOR NEXT SESSION

Cap 10 and the fixed widths in one reload per chart (C99), from new
presets that also carry `InpLatticeReroll=true`; on wine-c the reload
attaches from `Experts/fxmatrix/fxgrind` (fixes C88 for good, with the
`chart*.chr` `path=` check). The twins' Global Variables (magics 22260902,
22260802) on the three IC terminals: list read-only, delete by hand later
(as C107 for FTMO).

## 8. QUESTIONS PUT TO GEMINI (3 OCT)

- **GB-1. Closing the twins' books at market.** On the IC demos the
  realised loss equals open MTM already in equity, and round 2 scores
  per instance from its own start. Any reason to keep the twins trading
  to flat instead (there is no stop-entries input; ADR-157/162 would keep
  adding)?
- **GB-2. Order: retire first, then compile.** Retiring first means the
  compile re-initialises nine charts, not eleven, and the twins never run
  the new build. Any reason to compile first?
- **GB-3. Re-roll ON by F7 on a live book.** The input is read at init;
  `Grind_LatticeTrySide` takes the re-roll path on the next tick. Sides
  already fully rolled and past a level will re-roll at once (s5). Is
  turning it on fleet-wide in one evening sound, or B first and C/D a
  day later (that would make round 2's fleets differ structurally)?
- **GB-4. The STOP list (s3).** What failure at this build is not on it?
- **GB-5. C88.** Compiling wine-c's Scripts copy keeps its charts on
  the Scripts `.ex5` until the cap-10 reload re-attaches them from
  Experts. Acceptable for one more session?

## 9. GEMINI'S RULINGS (3 OCT) AND CLAUDE'S CHECK

- **GB-1 ACCEPTED** (close at market). His reason "round 2 scores from a
  flat start" is wrong (inherited books are territory, never flattened);
  the ruling stands on GB-1's own premise.
- **GB-2 ACCEPTED** (retire first).
- **GB-3 ACCEPTED** (all three fleets the same evening).
- **GB-4 ACCEPTED, corrected:** his "more than 1 per side in the same
  second" would fire on a designed backlog (one re-roll per side per
  CALL, several calls a second); the STOP is two re-rolls of one side
  with the same `ea_time_ms`.
- **GB-5 ACCEPTED as a warning, mechanism corrected:** F7 on a chart
  re-opens that chart's own EA; the risks are a Navigator drag or an
  Experts compile on wine-c. Warned in 3.5 and 3.7; caught by 3.6.

Line count: 172
