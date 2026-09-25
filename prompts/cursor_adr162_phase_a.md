This message has a line count at the bottom

# CURSOR PROMPT -- ADR-162 PHASE A: EFFECTIVE-ENTRY PLUMBING (INERT)

Repo `D:\fxmatrix`, from `main` at `b133621` (EA code == tested `238bb66`).
Branch `adr162-phase-a`. Record: `docs/architecture/ADR-162-virtual-lattice.md`
(read s2, s5, s11 first). Gemini reviews this prompt BEFORE you start; his
rulings are pasted at the bottom. Where a ruling changes a default below,
follow the ruling. If a ruling is ambiguous, STOP and report.

## AUDIT TRAIL (read in source at b133621 by Claude)

| # | finding | where | status |
|---|---|---|---|
| A1 | Add anchor = entry of highest `layer_index`; a target above the market is clamped to bid - min dist (ADR-162 s3 claim) | engine 1294-1305, 1509-1517; pure 174-186 | verified |
| A2 | Every exit target is `ExitPrice(entry) + accrued + eject_offset (+ shift)`, computed in FIVE places: exitq 243 `Grind_ExitQFormulaTarget`, recon 133 (I6 detail), recon ~376 `Grind_ReconExitMatchesEntry`, carry 906/915 (pass base), engine 403-409 (eject accept) | as listed | verified |
| A3 | Callers of `Grind_ExitQFormulaTarget` (engine 1457 append, engine 2415 queue release, recon 1125/1141 rebuild) are covered by substituting INSIDE it | as listed | verified |
| A4 | Rank sites build `entries[]` from `entry_price`: engine 483/491 (command), 553/565 (auto), 2392 (queue), recon 445 (I3) | as listed | verified |
| A5 | MISSED by ADR-162 s5: carry sign guard blocks a long exit `<= entry` (carry 425-432, 605-613); a rolled exit sits below its ACTUAL entry, so every carry pass would skip it | carry 605 | new |
| A6 | MISSED: eject accept computes `raw` from the ACTUAL entry; with a VL, `FormulaTarget` would be off by `entry - VL` and I6 halts the layer | engine 403-409 | new |
| A7 | MISSED: GV hygiene for the new prefix -- prune (carry 930-960), close path (engine 1992), close-out script prefix list, test reset helper | carry 944; engine 1992; `scripts/grind_gv_clean.mq5` 28-40; tests 2441 | new |
| A8 | Reporting stays on the ACTUAL entry (G1): heartbeat `entry_price`, archive `entry` (engine 420), I6/I3 detail `entry`, `scalp_closed` | heartbeat 249-254; engine 420; recon 152/171 | unchanged |
| A9 | pipshed reads heartbeat layer keys with `.get`, so an extra key is ignored | pipshed `app.py` 514-532 | verified |

## WHAT PHASE A IS

One new per-position GV, `GRIND_VL_<ticket>` (a price, entry space), and
one function, the effective entry, substituted at the lattice sites. No
roll ever fires, no input is added, nothing ever SETS the GV outside tests.
So on a live book every change below is a no-op BY CONSTRUCTION: with no
VL GV the effective entry IS the entry, bit for bit.

## COMMIT 1 -- TESTS AGAINST STUBS

New file `ea/fxgrind_tests_adr162.mqh`, included from `fxgrind_tests.mq5`
beside `fxgrind_tests_adr152.mqh`; register every test in `OnStart` after
the last existing registration. Add `GlobalVariablesDeleteAll("GRIND_VL_");`
to `Grind_TestClearCarryState` (tests 2441) in this commit (test isolation).

Stubs in `ea/grind_carry.mqh`, directly after `Grind_EjectIsEjected`,
bodies TRIVIAL (no logic in the stub commit):

    string Grind_VLName(const ulong position_ticket)        { return ""; }
    double Grind_VLGet(const ulong position_ticket)         { return 0.0; }
    bool   Grind_VLHas(const ulong position_ticket)         { return false; }
    void   Grind_VLSet(const ulong position_ticket, const double level) { }
    void   Grind_VLDelete(const ulong position_ticket)      { }
    double Grind_EffectiveEntry(const double entry, const ulong position_ticket)
                                                            { return entry; }

Prices: point 0.00001, 1 pip = 10 points, exit 3 pips, add 10 pips. Every
expected value below is derived by hand; do not change one to match output.

| test | setup | assertion (name: expected) | stub |
|---|---|---|---|
| VL1_GvRoundTrip | ticket 1001 | "VL1 absent": `VLHas` false | PASS |
| | | "VL1 name": `VLName(1001) == "GRIND_VL_1001"` | FAIL |
| | `g_grind_gv_dirty=false; VLSet(1001,1.10000)` | "VL1 has": true | FAIL |
| | | "VL1 get": 1.10000 | FAIL |
| | | "VL1 gv literal": `GlobalVariableCheck("GRIND_VL_1001")` | FAIL |
| | | "VL1 dirty": `g_grind_gv_dirty` true | FAIL |
| | `VLDelete(1001)` | "VL1 gone": literal check false | PASS |
| VL2_EffectiveEntry | none | "VL2 unrolled": `Eff(1.10500,1001)` = 1.10500 | PASS |
| | `VLSet(1001,1.10000)` | "VL2 rolled": 1.10000 | FAIL |
| | | "VL2 other ticket": `Eff(1.10400,1002)` = 1.10400 | PASS |
| | GV `"GRIND_VL_0"`=1.0 literal | "VL2 ticket 0": `Eff(1.10500,0)` = 1.10500 | PASS |
| VL3_FormulaTargetRolled | VL 1001=1.10000 | "VL3 long": `FormulaTarget(1.10500,3,pt,true,1001)` = 1.10030 | FAIL |
| | VL 1002=1.11000 | "VL3 short": `(1.10500,...,false,1002)` = 1.10970 | FAIL |
| | none on 1003 | "VL3 unrolled": `(1.10500,...,true,1003)` = 1.10530 | PASS |
| VL4_FormulaTargetRolledAccrued | VL 1.10000, accrued 0.00010 | "VL4 target": 1.10040 | FAIL |
| VL5_I6AcceptsRolledExit | VL 1.10000 | "VL5 rolled ok": `ReconExitMatchesEntry(1.10500,1.10030,3,pt,true,0,false,1001)` true | FAIL |
| | | "VL5 actual rejected": same with exit 1.10530 false | FAIL |
| | delete VL | "VL5 no vl": exit 1.10030 false | PASS |
| VL6_I6DetailExpected | Y13 pattern; entry 1.10500, exit 1.10030, VL 1.10000 | "VL6 expected": contains `"expected":1.10030` | FAIL |
| | | "VL6 entry actual": contains `"entry":1.10500` | PASS |
| VL7_QueueRanksByEffective | F1_3 pattern; market 1.09998/1.10000; L0 1.10500 t5301 VL 1.10000; L1 1.10400 t5302; L2 1.10300 t5303; L3 1.10200 t5304; `ExitQManageSide(...,3.0)` | "VL7 two resting" | PASS |
| | | "VL7 rolled L0 rests" | PASS |
| | | "VL7 oldest unrolled L1 rests" | FAIL |
| | | "VL7 deepest real L3 bare" | FAIL |
| | | "VL7 rolled exit price": L0 `exit_target` 1.10030 | FAIL |
| VL8_RebuildRolledBook | Y12 pattern, same four layers; EXT 2001 at 1.10030 (L0), EXT 2002 at 1.10430 (L1); L2, L3 no EXT; VL 1001=1.10000 | "VL8 with vl": rebuild true | FAIL |
| | delete VL | "VL8 without vl": false | PASS |
| VL9_AddAnchor | long, `Grind_ComputeAddTarget(side,true,10.0)`; s3 book: L0 1.21400 VL 1.20600, L1 1.21300 VL 1.20500, L2 1.21200 VL 1.20400, L3 1.21100 VL 1.20300, L5 1.20900, L6 1.20800, L7 1.20700 (no L4) | "VL9 s3 re-add": 1.20200 | FAIL |
| | delete all VL | "VL9 unrolled": 1.20600 | PASS |
| | no VL; L0 1.10500, L1 1.10300, L2 1.10400 (idx2 above idx1) | "VL9 index anchor kept": 1.10300 | PASS |
| VL10_CarryPassBaseRolled | Y15 pattern, entry 1.10500 t1001, VL 1.10000 | "VL10 one work item" | PASS |
| | | "VL10 base": 1.10030 | FAIL |
| VL11_SignGuardEffective | VL 1001=1.10000 | "VL11 rolled not blocked": `AppliesAtShift(1001,1.10500,1.10030,true)` false | FAIL |
| | | "VL11 rolled below vl blocked": exit 1.09990 true | PASS |
| | no VL on 1002 | "VL11 ordinary blocked": `(1002,1.10500,1.10030,true)` true | PASS |
| VL12_PruneOrphanVL | Y10 pattern; literal GV `"GRIND_VL_8888"`=1.10000, no position | "VL12 orphan pruned" | FAIL |
| VL13_CloseDeletesVL | F2_7 pattern, pos 99207; literal GV `"GRIND_VL_99207"` | "VL13 vl gone" | FAIL |
| VL14_HeartbeatVirtualLevel | existing heartbeat fixture (heartbeat_detail ~325); build the layer JSON | "VL14 absent when unrolled": no `virtual_level` | PASS |
| | literal GV `"GRIND_VL_8000"`=1.24000 | "VL14 present": contains `"virtual_level":1.24000` | FAIL |
| | | "VL14 once": exactly one occurrence | FAIL |
| VL15_EjectRolledOffset | order-test mode; L0 1.10500 t1001 VL 1.10000 with a resting EXT; call `Grind_EjectAcceptLayer(true,idx,magic,3.0,"TEST")`; T = the price the EXT was modified to | "VL15 offset": `EjectOffsetGet(1001)` = T - 1.10030 | FAIL |
| VL16_ParseL100 | G5 ruling | "VL16 parses": `GrindCommentParse("GRIND|OPT|L|L100|EXT")` ok | PASS |
| | | "VL16 index": 100 | PASS |

Predicted (operator runs both on GBPUSD and EURUSD; you do NOT run them):
stub commit **1849/1873**, failing exactly the 24 FAIL rows above; real
commit **1873/1873**. If VL15 cannot be built (FAILURE MODES), 1848/1872
and 1872/1872. The 19 PASS rows pass in both states BY DESIGN (they lock
inertness or state preconditions); list them in your report as such.

## COMMIT 2 -- IMPLEMENTATION

1. Helpers (carry, replacing the stubs), mirroring `Grind_EjectOffset*`
   exactly, including `Grind_GvMarkDirty()` on Set and Delete. `VLHas` =
   `GlobalVariableCheck(name)`. `Grind_EffectiveEntry` returns `entry` when
   `position_ticket == 0` or no GV, else `VLGet`.
2. Substitute INSIDE the functions that already take the ticket:
   `Grind_ExitQFormulaTarget` (exitq 243), `Grind_InvariantDetailI6`
   `expected` only (recon 133; the `entry` key stays actual),
   `Grind_ReconExitMatchesEntry` (recon ~376), and
   `Grind_CarrySignGuardAppliesAtShift` (carry 605: pass the effective
   entry to `Grind_CarrySignGuardBlocks`; the ejected exemption stays).
3. Carry pass base (carry 906, 915): `ExitPrice(Eff(entry, ticket))`.
   The `entry_price` passed on to the work list stays as it is.
4. Rank sites: `entries[i] = Grind_EffectiveEntry(entry_price, ticket)`
   at engine 483, 491, 553, 565, 2392 and recon 445 (recon keys by
   `position_id`, as it does for the offset GV).
5. Add anchor (engine 1509): if ANY layer on the side has a VL, anchor on
   the lowest effective entry (long) / highest (short); otherwise call
   today's code unchanged. Today's `Grind_FindDeepestLayerArrayIndex`
   stays as is (its callers and CM tests are untouched).
6. Eject accept (engine 408): `raw` from `Grind_EffectiveEntry(entry_price,
   position_ticket)`. The archive `entry` at 420 stays actual.
7. Close path (engine 1992): `Grind_VLDelete(closed_position)` beside
   `Grind_EjectOffsetDelete`.
8. Prune (carry 944): a `"GRIND_VL_"` branch like the offset branch.
9. `scripts/grind_gv_clean.mq5`: add `"GRIND_VL_"` to the prefix list.
10. Heartbeat (heartbeat_detail 249-254): for a layer with a VL, add
    `,"virtual_level":<price>` after `exit_target` (same `digits`);
    absent otherwise.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures
  are pending), do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no `git add .` or `-u`.
- Do not change any existing test, expected value or registration order.
- Do not add `InpVirtualLattice` or any input; no trigger, no roll, no
  WARN, no archive event, no M1 catch-up, no "roll here" (all Phase B).
- Do not change `scalp_closed`, the archive `entry`, the I3/I6 detail
  `entry` keys, or the heartbeat `entry_price`.
- Do not merge the five exit-target computations into one function.
- Do not change ADR-157 auto-eject logic beyond the rank substitution.
- Nothing outside `ea/` and `scripts/grind_gv_clean.mq5`. No pipshed.

## FAILURE MODES -- STOP AND REPORT

- A line cited above does not hold the code described (drift): STOP.
- Any existing test would need a change to compile or pass: STOP.
- You find another `ExitPrice(entry...) + offset` computation or rank
  `entries[]` build not listed: do not change it; report file and line.
- `Grind_EjectAcceptLayer` cannot be driven in order-test mode (the
  modify has no test path): omit VL15, say so, use the fallback counts.
- The heartbeat layer JSON cannot be built from the existing fixture:
  STOP.
- A stub body needs logic to compile: STOP.

## REPORT

Both commit hashes; `git diff --stat main..adr162-phase-a`; each test by
name with its assertion names; the PASS-in-both list; any unlisted site.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

- **GA1.** Add anchor: effective extreme ONLY when the side holds a VL,
  else today's index path (inert by construction; ADR s5 says
  "identical for an unrolled book", true in practice since clamps only
  go deeper, but not by construction). Accept?
- **GA2.** Sign guard: substitute the effective entry (a rolled layer is
  guarded against its virtual level) rather than exempt it like an
  ejected layer. Accept?
- **GA3.** The ADR-155 command stays beside the lattice, so a rolled
  layer can be ejected by hand; raw from the effective entry keeps I6
  consistent, and the position then holds a VL AND an offset. Accept,
  or should the command refuse rolled layers?
- **GA4.** Substitution inside the ticket-taking functions (step 2)
  rather than at every caller. Accept?
- **GA5.** Noted for Phase B, not built here: a rolled exit's fill is
  reported by `scalp_closed` as an ordinary scalp with a loss, so s4 and
  the Daily card would count it as a scalp. Phase B adds a flag. Agree?

## GEMINI RULINGS (2026-09-25) -- ALL FIVE ACCEPTED, NO DEFAULT CHANGES

Build exactly as written above; none of these rulings changes a step or
a test. Condensed; reasons checked in source by Claude.

- **GA1 ACCEPTED** (VL-gated anchor, step 5). His reason cites partial
  fills, which cannot occur at 0.01 lots (C14/C23), and slippage, which
  for a limit only fills deeper; the gate stands on "inert by
  construction" alone.
- **GA2 ACCEPTED** (sign guard on the effective entry, step 2).
- **GA3 ACCEPTED**: the command must NOT refuse rolled layers; VL and
  offset may coexist on one ticket. This holds only because step 6
  computes `raw` from the effective entry; VL15 locks it.
- **GA4 ACCEPTED** (substitute inside the ticket-taking functions). The
  six rank sites (step 4) still change at the caller: `Grind_ExitQRanks`
  takes a price array, not tickets.
- **GA5 AGREED** for Phase B: a rolled fill gets its own flag and is not
  counted as a scalp.

Line count: 207
