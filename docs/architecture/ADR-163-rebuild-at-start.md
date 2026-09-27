This message has a line count at the bottom

# ADR-163 -- GRIND V2.1: REBUILD AT START (EXIT AND ADD CHANGES ON A LIVE BOOK)

Status: BUILT AND MERGED (`main` `6a1e9ad`, 2026-09-27 ~01:45Z; s11).
Drafted ~00:05Z; Gemini ruled ~00:15Z (s9); operator confirmed the gate
label ~01:00Z (s10). Written by Claude from
source at `main` `dd4761e` (EA == `669da60`). Builds on v2.0, merged since as
`8f1f42d` (`prompts/cursor_grind_v2_per_side.md`; inherit by default).
Record: cycle-4 note s8.6 (rebuild, operator ruling by acceptance),
backlog C46/C47, geometry-cycle3 A6, 02_TRAPS 2026-09-26 (cycle 4).

## 1. THE PROBLEM

A reattach with a new EXIT halts the instance today. At init,
`Grind_ReconstructState` runs every invariant; I6 checks each resting
exit against `ExitPrice(effective entry, CURRENT exit) + accrued +
eject offset + shift` within 2 points (`Grind_ReconExitMatchesEntry`,
`grind_recon.mqh` 366-388) and fails on a mismatch. The compass (s8.4)
changes exits every two days on live books, so every exit probe would
halt. An ADD change does not halt (A6) but leaves a side's resting add
at the old distance while the change is inside the 4-pip deadband;
the operator ruled that resting adds move on a settings change
("absolutely"), ignoring the deadband.

## 2. OPERATOR RULINGS THIS BUILDS ON

- R1 (s8.6, by acceptance): REBUILD, not delta. Each exit is recomputed
  from its facts at start; the old exit value is NOT used to price.
- R2 (s8.6): resting adds move to the new distance at start, ignoring
  the deadband ("the deadband is for noise, not settings").
- R3 (26 Sep, this chat): a COMMANDED-EJECT exit stays where the
  operator put it ("we probably want to get the roll done asap so market
  level and not backing it off is correct"). A rolled exit (lattice) is
  NOT an ejected exit: it is rebuilt from its virtual level like any
  other (effective entry = VL).
- R4: fail closed. A change must never leave an instance trading on a
  book its invariants do not describe.

## 3. THE KEY FACT THAT MAKES THIS SMALL (verified)

The engine already knows how to put an exit exactly where I6 expects it:
`Grind_ExitQManageSide` (engine 3009-3063) places a missing required
exit at `Grind_ExitQFormulaTarget` (exitq 241-254: `ExitPrice(eff, exit)
+ accrued + eject offset`), clamps it passive
(`Grind_ExitQClampPassive`), and records the clamp as a carry SHIFT with
a release marker (`Grind_CarryRecordShift`, carry 534-543) or deletes the
shift when unclamped. The documented manual repair for an I6 halt
(BOOT s6, C52) is exactly this: delete the mispriced exit, reattach,
and the startup shortfall path re-places it at the formula.

So the rebuild is: at init, for every RESTING exit whose price differs
from the formula at the CURRENT exit, MODIFY it to the formula (clamped,
shift recorded or deleted exactly as `ManageSide` does). No new pricing
rule. The only new state decision is the ejected layer (R3).

## 4. THE DESIGN

**D1. Reconstruction tolerates exit PRICE at init only.** A new mode in
`Grind_ReconCheckInvariants` (a last parameter, default false, true only
from `Grind_ReconstructState`): an I6 mismatch on a RESTING exit order
(`has_exit_order`, not `has_exit_position`) does not fail; the layer's
position id goes on a rebuild list. Everything else stays strict: I1-I5,
I7, I8, I3, and the FILLED-exit adverse check
(`I6_*_EXIT_FILL_ADVERSE`). `Grind_CheckBookInvariants` (every tick)
never tolerates.

**D2. `Grind_RebuildExitsAtStart(magic)`**, called in `OnInit` directly
after `Grind_RetryMissingExits` (only when reconstruction succeeded).
Per side, per layer on the rebuild list:
- ejected (an eject offset GV exists, no VL): KEEP the order where it
  is; re-derive the offset so I6 holds at the new exit:
  `offset = resting price - (ExitPrice(eff, exit_side) + accrued +
  shift)`. No broker call. (R3; needs no old value.)
- otherwise: `target = Grind_ExitQFormulaTarget(entry, exit_side, ...)`,
  clamp passive, `Grind_ModifyPendingPrice`; on success record or delete
  the shift as `ManageSide` does and set the layer's `exit_target`.
- any modify FAILS: halt at once, reason `REBUILD_EXIT_FAILED`,
  `CRITICAL` with the ticket and retcode; entries cancelled as for any
  halt. The unmodified exits are valid orders at the old distance; the
  operator reattaches in session. No retry loop at init (API budget).
- Emits one `EXIT_REBUILT` archive marker per layer (ticket, old price,
  new price, clamped, ejected_kept) and one `REBUILD_SUMMARY` per side
  (repriced, ejected_kept, clamped, failed).

**D3. Held exits need nothing.** Under K=1/H=0 only rank 0 and the
highest rank rest; held layers have no order, and the queue places each
from the formula at the CURRENT exit when released. Only resting exits
(at most two per side) are rebuilt: at most four modifies per instance.

**D4. Resting adds and L0 (R2).** A per-side one-shot flag set at init;
the first `Grind_EnsureAddNext` after init compares the resting add with
its target using a band of HALF A POINT instead of the deadband (so an
unchanged add is not modified: C60's no-change request), then clears
the flag. The same for a resting L0 on a flat side against its
straddle target at the current width (today L0 is place-once, ADR-123).

**D5. The nightly carry pass is unchanged.** It already rebuilds each
resting exit from entry + current exit + carry every night (C52); with
per-side exits (v2.0) it uses the side's exit.

**D6. Carry at start.** The rebuild uses the STORED accrual (the nightly
pass's committed value), not a fresh ledger read. s8.6 said "at start:
ledger only"; after the rollover the two agree to the broker's rounding,
and the stored value is what I6 and the carry pass already use. A
reattach inside the carry window (20:50-21:00Z) is forbidden anyway.
Ledger recompute (which would also heal a lost accrual GV, C57) is left
for later.

**D7. What stops being caught.** Today a corrupted exit at init (a lost
shift or accrual GV, a hand-moved order) halts on I6. With D1 it is
silently repriced to the formula. Mitigation proposed: store the exit
each side's book was last priced for (GV `GRIND_GEO_EXIT_<magic>_L/_S`,
written after a clean init), used ONLY for reporting: a rebuild that
reprices exits while the stored value equals the current input emits
`CRITICAL REBUILD_WITHOUT_CHANGE` (the instance keeps trading, the
operator investigates). The operator's rule "only VL and eject offset
are stored" is about PRICING; this label never prices.

## 5. SEQUENCE AT INIT (after v2.1)

1. Resolve and validate inputs (v2.0).
2. `Grind_ReconstructState`: structure strict; missing exits tolerated
   (ADR-156, today); resting-exit PRICE tolerated and listed (D1).
3. `Grind_RetryMissingExits` (today).
4. `Grind_RebuildExitsAtStart` (D2); halt on any failure.
5. Set the one-shot add/L0 flags (D4).
6. Everything else as today. From the first tick, I6 is strict.

## 6. TESTS TO WRITE (names later; tests first as always)

- RB1 long exit 10 -> 7, two resting exits: both modified to entry + 7
  (eff), I6 strict passes after.
- RB2 short mirror.
- RB3 ejected layer: order untouched, zero modifies for it, offset
  re-derived, I6 strict passes at the new exit.
- RB4 rolled layer (VL set): rebuilt from VL + new exit.
- RB5 carry-shifted layer (accrued != 0): new price keeps the accrual.
- RB6 new exit inside the spread: clamped, shift and release marker
  recorded, I6 strict passes.
- RB7 unchanged exit: zero modifies (the half-point band), no markers.
- RB8 a modify fails: halted, `REBUILD_EXIT_FAILED`, the other exit
  not left half-done (order of operations stated in the spec).
- RB9 held layers: untouched, placed later at the new exit.
- RB10 filled exit (`has_exit_position`) with an adverse price: still
  fails I6 at init (strict).
- RB11 add 6 -> 5 (inside the deadband): the resting add moves once;
  a later 1-pip wobble does not (deadband back in force).
- RB12 per-side: long exit changed, short unchanged: only long exits
  modified.
- RB13 reporting: a rebuild with the stored geometry equal to the input
  emits `REBUILD_WITHOUT_CHANGE`.

## 7. FOR GEMINI

Verified in source by Claude unless marked. Please reason from this
codebase; the premises marked OPERATOR are rulings, not measurements.

- **GR-Q1.** Tolerating I6 PRICE at init only (D1), with structure and
  filled-exit checks strict and the per-tick check untouched. Accept, or
  a narrower tolerance (for example only when the stored geometry
  differs from the input, D7)?
- **GR-Q2.** Modify in place (one request, no uncovered moment) rather
  than cancel and re-place via the startup shortfall path (two requests
  and an I3 window, C40). Accept?
- **GR-Q3.** Halt on the first failed modify at init (D2), leaving valid
  old-distance exits, rather than retrying. Accept?
- **GR-Q4.** Ejected layers keep their price; the offset is re-derived
  from the resting price (R3, OPERATOR). Any path where a re-derived
  offset is wrong (carry pass, queue release, a later roll deleting it
  per GB3)?
- **GR-Q5.** Stored accrual rather than a fresh ledger read at start
  (D6). Accept for v2.1?
- **GR-Q6.** The reporting-only geometry label and
  `REBUILD_WITHOUT_CHANGE` (D7). Accept, or is a silent reprice of a
  corrupted exit acceptable without it?
- **GR-Q7.** The one-shot half-point band for the resting add and L0
  (D4). Anything in ADR-152's fill-time path or the entry horizon that
  the one-shot must also cover?

## 8. NOT IN SCOPE

Per-layer exit tags (C46); pipshed's compass (s8.7); a new width rule
(s8.2); changes to cap, lots or deadband; the ledger recompute (D6).

## 9. GEMINI RULINGS (2026-09-27 ~00:15Z) AND OUR CHECK

- **GR-Q1 NARROWED (his amendment, accepted by Claude).** The price
  tolerance at init applies ONLY when the stored geometry differs from
  the input. Consequences written into the design (Claude):
  - per SIDE: only the side whose stored exit differs is tolerant; the
    other side's I6 stays strict at init;
  - the label (D7) is now a GATE, not reporting-only. It never prices.
    It is a third stored label beside VL and eject offset, which the
    operator's s8.6 rule ("only two labels stored") did not foresee:
    CONFIRMED by the operator (s10);
  - label ABSENT (first v2.1 init on any book): strict I6 at that init
    (no tolerance), and the label is written after the clean init. So
    the first v2.1 attach must not change the exit; the new box starts
    flat, so it cannot;
  - the label is written only AFTER every rebuild modify succeeds. A
    halt mid-rebuild leaves the old label, so the next init is tolerant
    again and finishes the job; exits already moved match the new
    formula and are not modified twice;
  - GV name `GRIND_GEO_EXIT_<magic>_L` / `_S`, flushed like the others
    (C25); not touched by `Grind_CarryPruneShiftGvs` or the suite's
    prefix cleanup (a new prefix); tests clean it themselves.
- **GR-Q6 SUPERSEDED, and `REBUILD_WITHOUT_CHANGE` is DROPPED (Claude).**
  Under GR-Q1 no reprice can happen while the label equals the input:
  a mismatch then halts on I6 as today. The event could never fire.
  Gemini's "becomes a true exception event" misses that. Corruption at
  an unchanged restart stays loud (I6 halt), which is what the event
  was for.
- **GR-Q2 ACCEPTED.** Modify in place.
- **GR-Q3 ACCEPTED.** Halt on the first failed modify.
- **GR-Q4 ACCEPTED.** (His formula is written with "- accrued"; the
  code adds it: exitq 254. Typo only; his conclusion holds: a
  re-derived offset returns the resting price through the carry pass,
  the queue and ManageSide; a roll deletes it, GB3.)
- **GR-Q5 ACCEPTED.** Stored accrual at start. (His "partial fills"
  reason does not apply at 0.01 lots, C14; the conclusion stands.)
- **GR-Q7 ACCEPTED.** One-shot half-point band for the resting add and
  L0; nothing in ADR-152 or the (disabled) entry horizon needs it.

Test changes from the rulings: RB13 becomes "label equal to input, a
resting exit mispriced: I6 HALTS at init (no reprice)"; add RB14 "label
absent: strict init, label written"; RB15 "halt mid-rebuild, label
unchanged, next init finishes"; RB16 "long label changed, short
unchanged: a mispriced SHORT exit still halts".

## 10. OPERATOR CONFIRMATION (2026-09-27 ~01:00Z)

The third stored value is accepted ("seems reasonable, agree yes"). The
rule becomes: two labels that PRICE (VL, eject offset) and one that
GATES (the exit each side's book was last priced for; it decides whether
a mismatch at startup is a deliberate change, which is rebuilt, or
corruption, which halts on I6 as today). Also ruled this chat: a
COMMANDED-EJECT exit keeps its price on a rebuild (R3), because a hand
eject means "get out at the market now".

## 11. BUILT (2026-09-27)

Spec `prompts/cursor_grind_v21_rebuild.md` (Gemini GR-S1..S6: the L0
one-shot of D4 DROPPED, since an L0 target depends on the mid and would
snap to it at every restart; a clamped resting add may be modified once
per restart). Cursor `bc16f0d` (stubs, 50 tests: 2187/2218 failing the
31 predicted) and `fbd3227` (2218/2218). DeepSeek `b31afd4`: T-1 CORRECT
(an unreadable resting exit was skipped, the labels written, and every
later init strict: no self-heal) -> fix `2ff62f4` (return false,
`REBUILD_EXIT_UNREADABLE`, test RB13; 2220/2220; Gemini GF-1); T-6
("halt with the market closed") REJECTED: the rebuild runs only after an
operator exit change, and reattaching with the market closed is
forbidden (GR-Q3, Gemini GF-2). Merged `6a1e9ad`. Deploy check: the
`GRIND_REBUILD long=... short=...` line, and `EXIT_REBUILT` /
`REBUILD_SUMMARY` / `REBUILD_EXIT_UNREADABLE` markers in `ea_events`.

Line count: 257
