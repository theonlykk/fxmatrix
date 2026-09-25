This message has a line count at the bottom

# ADR-162 -- THE GRID CONTINUES PAST CAP: VIRTUAL LAYERS, REAL EXITS

**Status:** Phase A MERGED `c12901a` 2026-09-25 (inert plumbing, s12);
Phase B not started. Drafted 2026-09-24. Replaces ADR-157's trigger
(backlog C45). Not mid-cycle 3 (auto-eject is pre-registered ON there);
default-OFF input for a Fleet B phase or cycle 4. Operator's standard:
simple, boring, predictable. Every site below was read in `main` at
`5b81baf` (EA code = tested `238bb66`).

## 1. THE RULE (operator)

The grid never stops. Past cap, each further grid level is a VIRTUAL
layer: no entry order, but a real exit, paid for by the OLDEST remaining
layer. A virtual level fires the moment the market trades through its
ENTRY (never through its exit), with no delay; a gap through several
levels fires them all. Everything stays passive: a rolled exit is only
ever placed on the far side of the market, so it fills on a retrace.
No march, no stability test, no spread test, no N dial. V-shaped
recoveries are not designed against: their cost is bounded (s4).

## 2. THE MODEL: EFFECTIVE ENTRY

A roll does one thing: it re-labels the oldest position's EFFECTIVE
entry to the virtual level ("assume the most underwater layer is
actually layer 9"). Everything else follows from using the effective
entry wherever the grid reasons about levels:

    effective_entry(layer) = VL(ticket) if the position has a virtual
                             level, else entry_price
    exit_target(layer)     = ExitPrice(effective_entry) + accrued (+ carry shift)

For an unrolled book effective_entry == entry_price everywhere, so
nothing changes for a book that never reaches cap.

## 3. WORKED EXAMPLE (long, add 10, exit 5, cap 8; prices in pips)

    L0 140 ... L6 80 (exit 85), L7 70 (exit 75)            depth 8 = cap
    market falls to 19:
      level 60 crossed -> L0 effective 60, exit 65
      level 50 crossed -> L1 effective 50, exit 55
      level 40, 30, 20 -> L2, L3, L4 effective 40, 30, 20; exits 45, 35, 25
    market lifts to 25: L4's rolled exit (a SELL at 25) fills
      depth 7 -> the engine places ONE REAL add (a BUY). Virtual adds are
      never placed; only their exits are.
      today's code anchors that buy on the highest layer_index = the last
      REAL layer, L7 at 70 -> target 60 -> above the market -> clamped
      passive to ~25 (enters at the market, lattice out of step)
      with the effective entry it anchors on the last VIRTUAL level held,
      L3's 30 -> buy at 20, below the market, exactly where a real grid
      would re-add (as a normal scalp re-opens its own level today:
      L0 100 / L1 90 / L1 exits at 95 -> the add returns to 90, not 85).

## 4. COST: FIXED AND BOUNDED

Every roll realises `entry(Lk) - (level + exit)`; on a uniform ladder
that is `cap x add - exit` (8 x 10 - 5 = 75 pips), whatever the depth.
At most `cap` layers can be rolled on a side at any one time, so the
worst case per episode is `cap x (cap x add - exit)` (600 pips; $60 on
GBPUSD at 0.01 lots).

## 5. CODE SITES (verified)

| site | today | change |
|---|---|---|
| Add anchor: `Grind_ComputeAddTarget` (`grind_engine.mqh` 1509) | anchors on `Grind_FindDeepestLayerArrayIndex` (highest `layer_index`, 1294) | anchor on the LOWEST effective entry (long) / highest (short). Identical for an unrolled book; after a rolled fill it re-adds at the lattice, not near market (s3) |
| Exit ranks: `Grind_ExitQRanks` (`grind_exitq.mqh` 84) fed `entry_price` at engine 483/491 (command), 553/565 (auto), 2392 (queue), recon 445 | rank by entry | feed EFFECTIVE entries (== rank by exit price). Barbell unchanged: rank 0 + highest rank rest; the highest rank is automatically the oldest UNROLLED layer, which holds a live ticket for the next roll |
| Exit target: `Grind_ExitQFormulaTarget` (exitq 243), recon I6 expected (recon 133, 376), carry formula (carry 906/915), layer add (engine 1457), recon rebuild (recon 1125/1141) | `ExitPrice(entry) + accrued + eject_offset` | `ExitPrice(effective_entry) + accrued` for a rolled layer (see G2 on the offset) |
| Roll: new, beside `Grind_EjectAcceptLayer` (engine 379) | ADR-155 moves the exit to the market (`Grind_EjectTargetPrice`) | modify the oldest unrolled layer's exit to `level +/- exit`, store `VL`, archive `ROLL_ACCEPTED` (ticket, entry, level, target, cost) |
| Trigger: new, per side in `OnTick` beside `Grind_AutoEjectOnTick` (`fxgrind.mq5` 320) | ADR-157 stability + spread tests | at cap: `next = lowest_effective -/+ add`; fire while ask <= next (long) / bid >= next (short); loop for a gap |
| Detection catch-up | none | the M1 bar low/high since the last check (bars are bid-based: add the spread for longs; never fire earlier than a real limit would fill) for ticks skipped while busy and a restart mid-gap |
| Persistence: new GV `GRIND_VL_<ticket>` beside `GRIND_EJECT_OFFSET_<ticket>` (carry 547) | offset GV, deleted when the position closes (engine 1992) | VL GV with the same hygiene; reconstruction reads it; nothing else to store (k is the count of VL GVs on the side) |
| Next layer index: `Grind_SideNextIndex` (engine 1280) | max + 1 | unchanged; indices keep climbing after rolled fills (L08, L09 ...); see G5 |

## 6. WHAT IT RETIRES AND WHAT STAYS

Retires (for instances with the new input ON): ADR-157's W/k stability
test, its M1 stability data, backoff and orphan trailing. Stays: the
ADR-155 command path, gaining a "roll here" mode = fire the next level
now at the lattice level beyond the market (manual tail). A side whose
market sits more than `S` add steps beyond its lowest effective level
with nothing left to roll raises WARN `ROLL_STRANDED` (pipshed).

## 7. INPUTS

`InpVirtualLattice = false` (default OFF). With it ON, `InpAutoEject`
must be OFF or `OnInit` refuses (fail closed). `S` for the WARN is a
compiled constant until data says otherwise.

## 8. TESTS TO WRITE (names later, tests first as always)

Effective entry (unrolled == entry); add anchor on the lowest effective
entry (s3's re-add at 20, not near 25); ranks by effective entry
(rolled layer ranks 0, oldest unrolled is the highest rank); the
trigger fires through the entry not the exit (64 fires nothing, 60
fires); a gap fires every level in order (60 -> L0 ... 20 -> L4); cost
per roll is `cap x add - exit` on a uniform ladder; worst case stops at
`cap`; VL GV round-trips through reconstruction and I6; OFF is inert.

## 9. EVIDENCE BEFORE BUILD

Cycle 3's live ejections at week end (none so far: deepest side 4 of 8
on both fleets at 22:18Z 24 Sep) and cycle 2's deep books: how often
sides reached cap, how far past, and what the lattice would have
realised against what ADR-155/157 did.

## 10. FOR GEMINI

- **G1.** The effective-entry model: one substitution (effective entry
  for entry) at the sites in s5 instead of special-casing rolled
  layers. Any site that reasons about levels that we missed?
- **G2.** Store the virtual level (entry space) in a new GV, not
  ADR-155's exit offset (exit space, entangled with nightly carry
  accrual). Keep reading offset GVs for legacy ejected positions.
  Accept, or reuse the offset?
- **G3.** Ranking by effective entry changes the ORDER only for rolled
  layers (and would change it for an unrolled book only if accrued
  carry exceeded one add distance). Any risk to I3 coverage or the
  trim-before-protect path during the moment of a roll?
- **G4.** Gap detection by tick plus M1 catch-up, bid bars plus spread
  for longs. Is "never earlier than a real limit" the right bias?
- **G5.** Layer indices climb past 7 after rolled fills; comments
  carry `L%02d`. Any parser, invariant or pipshed assumption that
  indices stay below the cap (or below 100)?
- **G6.** Fixed cost per roll assumes a uniform ladder; after
  re-centering or partial fills the ladder is not uniform. State the
  cost as `entry(Lk) - (level + exit)` per roll (known at firing) and
  keep the worst-case bound as `cap` rolls. Accept?

## 11. GEMINI RULINGS (2026-09-24) AND OUR VERIFICATION

His reply: 13 lines as pasted, no line-count footer.

- **G1 ACCEPTED AS A GUARD.** The effective entry is used ONLY at the
  lattice sites in s5 (add anchor, exit ranks, exit target, I6, roll,
  trigger). Reporting keeps the ACTUAL entry: the heartbeat's
  `entry_price` (`grind_heartbeat_detail.mqh` 249-254) is unchanged and
  gains a `virtual_level` field for rolled layers; P&L and MTM come from
  the broker's position profit. His "margin allocation" point has no
  target: the grind EA has no per-entry margin logic (its "margin" is
  the commitment guard's spare slots).
- **G2 ACCEPTED.** New `GRIND_VL_<ticket>` GV, entry space.
- **G3 REJECTED (verified in source).** Trim-before-protect does not
  rank by floating loss: it cancels live exits that the barbell
  predicate `Grind_ExitQRequired(rank, depth)` does not require
  (engine 2392-2405), and I3 coverage uses the SAME predicate (recon
  507, 536, 1057). Queue and I3 must rank identically or every rolled
  book fails I3. Ranking by ACTUAL entry is also what stalls the
  lattice: the rolled L0 stays the highest rank, the next candidate
  (L1) is a middle rank with no live exit, and ADR-155's validator
  refuses it (`GRIND_EJECT_NOT_DEEPEST` / `NO_EXIT_ORDER`,
  `grind_pure.mqh` 284). Effective ranks keep the oldest UNROLLED layer
  at the highest rank. "True drawdown" stays visible through G1's
  reporting rule.
- **G4 ACCEPTED.** (His backtesting remark does not apply: this is live
  detection.)
- **G5 VERIFIED SAFE, test added.** Both parsers split on `|` and read
  the integer after `L` (`GrindCommentParse`, `grind_comment.mqh`;
  pipshed `_parse_grind_comment`, `app.py` 1164), so `L100` parses.
  Layer arrays are dynamic and map labels by lookup
  (`Grind_ReconEnsureLayer`, recon 310); no bound ties `layer_index` to
  the cap (`Grind_CanPlaceEntryLayer` counts layers, not indices).
  `GRIND|OPT|L|L100|EXT` is 20 of 31 chars. Add a parse test for L100.
- **G6 CONFIRMED.** His arithmetic matches s4 (L0 140 -> 65 = -75,
  L1 130 -> 55 = -75); state the cost per roll as
  `entry(Lk) - (level + exit)`, known when it fires.

## 12. PHASE A -- MERGED `c12901a` (2026-09-25)

**Landed** (EA code = tested `9466b22`; spec with Gemini GA1-GA5, all
accepted: `prompts/cursor_adr162_phase_a.md`). GV `GRIND_VL_<ticket>`
(entry space) and `Grind_EffectiveEntry` (carry 617), substituted at
every exit-price formula (exitq 253; recon 133, 378; carry 952, 962,
976; engine 408) and every rank array (engine 484, 493, 556, 569, 2426;
recon 447). Add anchor on the effective extreme only when the side holds
a VL (engine 1514, GA1); carry sign guard on the effective entry (carry
650, GA2); a hand eject of a rolled layer is allowed (GA3). VL deleted on
close (engine 2026), pruned with its position (carry 997), in
`scripts/grind_gv_clean.mq5`; heartbeat `virtual_level` on rolled layers
only. No input, no trigger, no roll: nothing outside tests sets a VL, so
a live book is unchanged by construction. Reporting keeps the actual
entry; the `EJECT_ACCEPTED` `raw` field is effective-based by design.

**Verified:** stub `cb4c51f` 1850/1874 on GBPUSD and EURUSD, exactly the
24 predicted failures; tip `9466b22` 1875/1875 on both.

**Found after Cursor, fixed on the branch:** (1) the spec missed a sixth
exit-price site, `Grind_CarryWorkBase` (carry 976), the base the nightly
pass actually modifies to; VL10 had checked only the stored copy
(`g_grind_carry_exit_work_formula`). Test `268bde0`, fix `b982f77`.
(2) The new assertion then failed for a setup reason: `PassBegin` ends
with the prune, which deleted the test's VL (test position 1001 does not
exist); `9466b22` re-sets it after `PassBegin`, as F5 does for the offset.

**DeepSeek `6e10967`** (each verdict checked in source): G1-G9 verified;
T-2 (missed site), T-4 (eject a rolled layer), T-5 (sign guard) HOLD.
Carried to Phase B:
- **B1** (T-1/T-6): `Grind_VLHas` false for ticket 0 (the anchor loop,
  engine 1524, has no ticket-0 guard; unreachable today, every layer
  carries a position ticket).
- **B2** (T-3): when may a VL be deleted? The prune deletes it whenever
  `PositionSelectByTicket` fails. At `OnInit` it runs after
  reconstruction (`fxgrind.mq5` 195) and the EA has no connection check
  anywhere, so it rests on the premise reconstruction already rests on
  (offset and carry GVs too). A lost live VL fails I6 on the rolled
  exit. For Gemini: close path only, or prune gated on a healthy
  reconstruction.
- **B3** (T-8): tests for command ranks (engine 484/493), auto ranks
  (556/569), the short side of I6, sign guard, anchor, queue, carry base
  and close; a live VL surviving the prune; a restart with a VL through
  `Grind_ReconstructState`.
- **B4** (GA5): a rolled exit's fill is flagged in `scalp_closed` and not
  counted as a scalp (s4, Daily card).

Line count: 216
