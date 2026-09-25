This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-162 PHASE A (EFFECTIVE ENTRY, INERT PLUMBING)

You are auditing an IMPLEMENTATION before it merges. It is tested: suite
1875/1875 on GBPUSD and EURUSD at `9466b22`; the stub commit `cb4c51f`
failed exactly the 24 predicted assertions. Find what tests cannot see.
Cite `file:line` for EVERY claim; a claim without a line is discarded.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders, hedging account). Eleven instances (one per magic) share
terminal global variables (GVs). Each side holds filled layers, each with
one exit; an exit queue (ADR-151, K=1, H=0) keeps only rank 0 and the
highest rank resting, and I3 (reconciler) requires the SAME ranks.
Nightly carry shifts exits by accrued swap. ADR-155 lets the operator
eject a layer by hand (per-ticket offset GV `GRIND_EJECT_OFFSET_<ticket>`).

**ADR-162** (attached, with Gemini's rulings G1-G6) is a virtual lattice
past the layer cap: a roll re-labels the oldest layer's EFFECTIVE entry
to a virtual level and moves its exit there. **Phase A (this branch,
`adr162-phase-a`, attached Cursor prompt with rulings GA1-GA5)** adds only
the plumbing: a per-position GV `GRIND_VL_<ticket>` (a price) and
`Grind_EffectiveEntry`, substituted at the lattice sites. No roll fires;
nothing outside tests sets the GV. Reporting keeps the ACTUAL entry.
**Do not re-open the design** (ruled). Attack the implementation.
Two defects were already found after Cursor and fixed on the branch:
the carry shift base `Grind_CarryWorkBase` (carry 976) was missed by the
spec; VL10's setup lost its VL to the prune inside `PassBegin`.

## GIVENS -- verify each, cite the line

- G1. `Grind_EffectiveEntry` (`grind_carry.mqh:617`) returns `entry` when
  the ticket is 0 or `GRIND_VL_<ticket>` does not exist, else its value.
  `Grind_VLSet`/`Grind_VLDelete` call `Grind_GvMarkDirty` (flush <= 1 s).
- G2. No non-test code calls `Grind_VLSet`, so a live terminal holds no
  `GRIND_VL_` GV unless one is created by hand.
- G3. Every exit-price formula substitutes the effective entry:
  `grind_exitq.mqh:253`; `grind_recon.mqh:133` (I6 detail), `:378` (I6
  match); `grind_carry.mqh:952`, `:962` (stored base), `:976` (shift
  base used for the modify); `grind_engine.mqh:408` (eject raw).
- G4. Every rank array substitutes it: `grind_engine.mqh:484`, `:493`
  (command), `:556`, `:569` (auto-eject), `:2426` (queue);
  `grind_recon.mqh:447` (I3 and rebuild).
- G5. `Grind_ComputeAddTarget` (`grind_engine.mqh:1514`) anchors on the
  lowest (long) / highest (short) effective entry when ANY layer on the
  side has a VL, else runs the pre-existing index-based code unchanged.
- G6. `Grind_CarrySignGuardAppliesAtShift` (`grind_carry.mqh:650`) keeps
  the ejected exemption first, then tests the EFFECTIVE entry.
- G7. Hygiene: deleted on close (`grind_engine.mqh:2026`); pruned when
  the position is gone (`grind_carry.mqh:997`; prune runs from
  `PassBegin` `:969` and `OnInit` `fxgrind.mq5:195`); close-out script
  prefix list (`scripts/grind_gv_clean.mq5:37`, not attached).
- G8. The heartbeat adds `virtual_level` only for a layer with a VL
  (`grind_heartbeat_detail.mqh:248`, not attached: 6 changed lines).
- G9. Reporting stays on the actual entry: archive `entry`
  (`grind_engine.mqh:421`), I3/I6 detail `entry`, `scalp_closed`.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Inertness.** With no `GRIND_VL_` GV, is every changed path
  bit-identical to before? Look for a divergence: `Grind_VLHas` on a
  ticket-0 layer in the anchor loop (`grind_engine.mqh:1524`, no ticket
  guard there); a GV name colliding with the prefix; the added
  `GlobalVariableCheck` calls per tick (bound them per OnTick).
- **T-2 Missed site.** Any remaining place that computes an exit price,
  a rank, a depth order or a "deepest layer" from `entry_price` and
  would disagree with the effective entry once a VL exists: other
  invariants (I1-I8), the ADR-142 exit-fill tolerance, CloseBy pairing,
  the carry shift bound and release marker, `Grind_EjectValidate`, the
  ADR-157 trailing path (`grind_engine.mqh:600`), other callers of
  `Grind_FindDeepestLayerArrayIndex`. For each: line, and whether it is
  harmless in Phase A but must change before a roll can fire.
- **T-3 Prune deletes a live VL.** The prune deletes a VL whenever
  `PositionSelectByTicket` fails. Can it fail for an EXISTING position
  (terminal start before history loads, disconnect, symbol context)?
  If a live VL were deleted, what happens next (I6, ranks, exit)? The
  same rule already governs offset GVs: is there evidence it is safe?
- **T-4 Eject a rolled layer (GA3).** After a hand eject of a layer with
  a VL, do `Grind_ExitQFormulaTarget`, I6, the carry base, the sign
  guard and the queue agree on its exit? Are both GVs deleted when that
  exit fills?
- **T-5 Sign guard on the effective entry (GA2).** Any wrong block or
  wrong permit for a rolled layer, long or short.
- **T-6 Anchor in VL mode (GA1).** Short-side mirror; layers with
  `position_ticket` 0; interaction with `Grind_SideNextIndex` and
  `Grind_ValidateAddLabelIndex`.
- **T-7 Restart.** A reinit with a VL present: rebuild ranks, exit
  targets, I3/I6 (including ADR-156 startup tolerance) consistent?
- **T-8 Tests.** Which substitutions have NO test that fails without
  them (e.g. command ranks `:484/:493`, auto ranks `:556/:569`, short
  side of I6)? Which new assertion passes vacuously?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G9, each VERIFIED or FALSE
with line), `T-1` ... `T-8` (verdict, evidence, smallest fix if any),
`PREMISE VERDICT` (is "effective entry at lattice sites, actual entry
for reporting" consistent; name any misclassified site), `TEST GAPS`.
No preamble. If you assume a value (a timeout, a default, an order of
calls), say ASSUMED and why.

Line count: 102
