This message has a line count at the bottom

# ADR-162 -- THE GRID CONTINUES PAST CAP: VIRTUAL LAYERS, REAL EXITS

**Status:** DRAFT for Gemini (2026-09-24). Replaces ADR-157's trigger
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

Line count: 130
