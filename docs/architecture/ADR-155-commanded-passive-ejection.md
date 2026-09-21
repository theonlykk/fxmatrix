# ADR-155: Commanded Passive Ejection

## Status

Proposed -- 2026-09-21. Backlog C15. Needs Gemini, then DeepSeek
(ARCHITECT s2: it moves live orders), then a tests-first Cursor spec.
**Depends on F1** (barbell): the deepest layer must have a resting exit.
F1 goes live with cycle 3 on 2026-09-23; this ships after, mid-cycle,
behind a disabled switch.

## Context

On 2026-09-21 the operator rolled the deepest layer of AUDCAD OPT and ALT
by hand (`docs/runbooks/roll-log.md`): detach the EA, delete its entry
orders, close the position at MARKET, reattach. It worked, with three
problems:

1. **It crosses the spread.** A market close. The system otherwise only
   ever places passive limits.
2. **It needs a detach/reattach.** Closing a position under a running EA
   quarantines then halts it, so the EA must be off, and reattaching
   loads a preset -- which halted AUDCAD ALT on I6 when the preset's exit
   (7) differed from the running exit (10).
3. **It is invisible** to the EA's realised P&L and to pipshed.

The rolls also showed the design question is not settled: in a trend the
side re-capped within nine minutes. So the POLICY (when to eject, whether
to re-enter) is still being measured (roll log, backlog C16). This ADR is
the MECHANISM only.

## Decision

### 1. The command

A script `grind_eject` (inputs: magic, position ticket) writes
`GRIND_EJECT_<magic> = <position ticket>`. The EA polls it and clears it
after acting. Operator-triggered only; no rule decides on its own.

### 2. Validation -- refuse unless all hold

- the ticket is an open layer of THIS instance
- it is the layer at `rank == depth - 1` on its side (the deepest)
- that side's depth is at least 2
- the layer has a resting exit order (guaranteed by F1)
- `InpEnableCommandedEject` is true (default false)

On refusal: clear the command, log the reason, emit a telemetry event.
Never partially act.

### 3. Mechanism -- move the exit, do not close the position

Set the layer's exit target to the best PASSIVE price at the market,
clamped exactly as every exit is (`Grind_CarryClampLongExit` /
`...ShortExit`, respecting stops and freeze levels), and modify the
resting exit order to it. The layer then exits as a limit when the market
touches it. **No market order is ever sent.**

### 4. Durability -- record it as ACCRUAL, not as a shift

The exit queue re-prices every exit from `formula + accrued`
(`Grind_ExitQFormulaTarget`, `grind_exitq.mqh:241`). The stored SHIFT is
not part of that formula, and an unclamped re-placement DELETES it (the
stale-offset fix, `grind_engine.mqh:~1847`). ADR-151's trim can cancel an
exit under slot pressure; its re-release would then quietly undo an
ejection stored as a shift.

So the ejection is written as a one-off increment to
`GRIND_CARRY_ACCRUED_<position>`:

    accrued_new = accrued_old + (ejected_price - current_formula_target)

Consequences, each by existing code:
- every re-placement recomputes the ejected price (formula includes
  accrued), then clamps it passive
- I6 on restart expects `formula + accrued`, so it passes
- accrual has no bound check, so nothing deletes it
- if carry is later enabled, nightly accrual continues to add on top --
  semantically correct

### 5. After the exit fills

The normal path runs: exit fill, CloseBy, layer removed. The side is now
one below its cap, so the engine re-quotes its next add -- which lands near
the market. **That completes a roll with no extra code.** An eject-and-wait
policy would instead suppress that add; out of scope here, decided by the
data in C16.

### 6. Telemetry

An `EJECT` event on command acceptance (ticket, entry, formula target,
ejected price) and on refusal (reason). The eventual fill is a scalp with a
negative realised P&L; tag it so pipshed can separate ejections from
ordinary scalps.

## Consequences

- **No spread crossing; no detach; no preset trap; visible in pipshed.**
- **It may not fill immediately.** A passive exit at the market fills on
  the next touch. In a fast trend away from it, it trails behind. The
  ejected price is fixed at command time; a second command re-ejects.
- **Accrual changes meaning slightly:** it now carries carry AND
  ejection offsets. Telemetry must say which.
- **It needs F1.** Without the barbell, the deepest layer has no resting
  exit to move.

## Open questions

1. Should an unfilled ejection be re-pressed automatically after N
   minutes, or only by a new command?
2. Should the command also cancel the side's pending add (eject-and-wait)
   as an option, or is that policy for later?
3. Does moving the deepest exit interact with the recentre, the cap
   guard, or the slot reserve in any way not covered by I6?

## Testing (tests first)

- command on a non-deepest layer: refused, nothing modified
- command on depth 1: refused
- command with the switch off: refused
- accepted: exit modified to the passive market price; accrued increased
  by exactly (ejected - formula)
- **restart after an accepted ejection: reconstruction passes I6**
- trim cancels and re-releases the ejected exit: it comes back at the
  EJECTED price, not the formula price
- exit fills: CloseBy, layer removed, side's next add re-quoted
