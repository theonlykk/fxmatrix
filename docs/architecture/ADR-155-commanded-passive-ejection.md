# ADR-155: Commanded Passive Ejection

## Status

Proposed -- 2026-09-21. Rev 2 after Gemini (dedicated offset, not
accrual); rev 3 after DeepSeek (`prompts/adr155_deepseek_response.md`,
branch `review/adr155-deepseek` at `ebcf171`), which found the carry pass
bypasses the formula. Rev 4 after the operator (2026-09-22): the carry pass INCLUDES ejected
    layers, base = raw + offset, replacing rev 3's skip. Backlog C15. Next: a tests-first Cursor spec
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

### 4. Durability -- a DEDICATED offset, read by the formula and by I6

The exit queue re-prices every exit from `formula + accrued`
(`Grind_ExitQFormulaTarget`, `grind_exitq.mqh:241`). A stored SHIFT is not
part of that formula, and an unclamped re-placement DELETES it (the
stale-offset fix, `grind_engine.mqh:~1847`). ADR-151's trim can cancel an
exit under slot pressure; its re-release would quietly undo an ejection
stored as a shift.

**Gemini ruled (2026-09-21) against reusing accrual** for this: once an
ejection sits inside `GRIND_CARRY_ACCRUED_`, nothing downstream can tell
carry from an operator command. So the ejection gets its own variable:

    GRIND_EJECT_OFFSET_<position>  =  ejected_price - (formula + accrued)

and it is added everywhere the exit target is computed:

| where | today | after |
|---|---|---|
| `Grind_ExitQFormulaTarget` (`grind_exitq.mqh:241`) | `exit + accrued` | `exit + accrued + eject_offset` |
| `Grind_ReconExitMatchesEntry` (`grind_recon.mqh:353`, the I6 check) | `exit + accrued + shift` | `exit + accrued + eject_offset + shift` |

**Both are required.** If the queue reads the offset but I6 does not, the
first restart after an ejection halts the instance (`I6_*_EXIT`) -- the same
failure as the F1 migration and the AUDCAD ALT reattach.

**Five more places, found by the DeepSeek audit, all verified in source:**

| where | what it does today | change |
|---|---|---|
| `Grind_CarryExitPassBegin` (`grind_carry.mqh:796`, `:804`) | builds each work item from the RAW formula, so the first rollover after an ejection would move the exit back to formula + accrued and wipe the ejection | **build the work item from `raw + eject offset`.** Do NOT skip ejected layers (rev 4, 2026-09-22): carry is a real cost on every open layer, so an ejected exit must drift with the swap it pays like any other; freezing it would leave an exit that no longer covers its funding. `Grind_CarryExitShiftLayer` is unchanged -- it adds accrual to whatever base it is given |
| `GrindLayer.exit_target` | `Grind_TryPlaceExitForLayer` places at this field (`grind_engine.mqh:840`) | the command sets `layer.exit_target` to the ejected price as well as writing the offset |
| `Grind_HandleSideDealFill`, on `DEAL_ENTRY_OUT_BY` | deletes shift and accrual when a layer closes | also `Grind_EjectOffsetDelete`. NOT folded into `Grind_CarryShiftDelete`, which also runs on a trim cancel where the offset must survive |
| `Grind_CarryPruneShiftGvs` | prunes orphan shift and release variables | also prune orphan `GRIND_EJECT_OFFSET_` -- **by that exact prefix only.** The command variable `GRIND_EJECT_<magic>` is keyed by MAGIC; pruning the broad `GRIND_EJECT_` prefix would treat a magic as a missing ticket and delete a pending command |
| `Grind_InvariantDetailI6` (`grind_recon.mqh:125`) | logs an "expected" price WITHOUT accrual -- a **pre-existing bug**: the real check at `:364` includes it | include accrual and the eject offset, and add both to the payload |

The wholesale clean-ups (`scripts/grind_gv_clean.mq5`,
`Grind_TestClearCarryState`) DO use the broad `GRIND_EJECT_` prefix, so the
command and the offset are both removed.

Lifecycle of the variable:
- **written** once, when a command is accepted
- **deleted** when the layer closes, alongside the existing
  `Grind_CarryAccruedDelete` (`grind_engine.mqh:1408`)
- **covered** by the account-switch clean-up script
  (`scripts/grind_gv_clean.mq5`) and the suite reset
  (`Grind_TestClearCarryState`) -- add the prefix `GRIND_EJECT_` to both,
  which also covers the command variable `GRIND_EJECT_<magic>`

The offset has no bound check, deliberately: an ejection is supposed to be
large.

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
- **Carry and ejection stay separable** in state and telemetry (Gemini).
- **It needs F1.** Without the barbell, the deepest layer has no resting
  exit to move.

## Rulings on the open questions (Gemini, 2026-09-21)

1. **Re-press an unfilled ejection only by a new command.** No timers or
   state machine in an operator override.
2. **Eject-and-wait is policy, for later.** Build the raw roll first; if
   the roll log and the retrace study (C16) favour waiting, change the
   engine then.
3. **Interaction with ranking:** Gemini asked that ranking stay by ENTRY
   price only, so an ejected exit price cannot reorder the barbell queue
   and drop the deepest layer's exit. **Verified in source:**
   `Grind_ExitQRanks` (`grind_exitq.mqh:84`) ranks through
   `Grind_ExitQEntryBeats`, entry only. Pinned by a test below.
   Recentre and cap guard: unaffected -- depth does not change until the
   exit fills.

## Testing (tests first)

- command on a non-deepest layer: refused, nothing modified
- command on depth 1: refused
- command with the switch off: refused
- accepted: exit modified to the passive market price;
  `GRIND_EJECT_OFFSET_<pos>` equals exactly (ejected - formula - accrued);
  accrued UNCHANGED
- **restart after an accepted ejection: reconstruction passes I6**
- trim cancels and re-releases the ejected exit: it comes back at the
  EJECTED price, not the formula price
- exit fills: CloseBy, layer removed, `GRIND_EJECT_OFFSET_` deleted,
  side's next add re-quoted
- **carry rollover after an ejection:** with the carry pass enabled and in
  its window, the ejected layer is skipped -- its exit stays at the ejected
  price and I6 still passes on a restart afterwards
- **large move then re-release:** an ejected exit trimmed and re-released
  after the market has moved far keeps its offset; nothing bound-deletes it
- **prune:** an orphan `GRIND_EJECT_OFFSET_` is pruned; a pending
  `GRIND_EJECT_<magic>` command is NOT
- **I6 detail:** the logged expected price includes accrual and the offset
- ranking after an ejection: the ejected layer keeps rank `depth - 1`, and
  its exit stays required, even when its ejected price is nearer the
  market than a newer layer's formula target
- the clean-up script and `Grind_TestClearCarryState` remove every
  `GRIND_EJECT_` variable
