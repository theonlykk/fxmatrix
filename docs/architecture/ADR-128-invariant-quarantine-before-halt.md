# ADR-128: Invariant quarantine before halt

Status: Proposed
Date: 2026-09-11

## Context

`OnTick` (`ea/fxgrind.mq5` ~180–204) runs `Grind_ProcessCloseByQueues`, then
`Grind_CheckBookInvariants` on every tick when not halted. On any failure it
sets `g_grind_halted = true` and returns before `Grind_OnTickEngine`.

`Grind_CheckBookInvariants` (`ea/grind_recon.mqh` ~837) rebuilds the book from
broker positions (collected first) then orders (collected second). It is not
an atomic snapshot of the book.

A fill or CloseBy moves the book through intermediate states. Proven live:
AUDCHF_ALT halted `I3_LONG_NAKED` at 10:35:40.980 UTC; the Journal logged the
exit fill that covered it at 10:35:41.071 UTC, 91 ms later. Four earlier I3
halts share the signature.

A halted EA ignores all later trade transactions (`grind_engine.mqh` ~993), so a
transient halt becomes real damage: no CloseBy, later fills left with no exit.

Exit retry for layers with no exit lives only in `Grind_OnTickEngine`
(`grind_engine.mqh` ~967–976). It is keyed on the EA's own layer record
(`exit_order_ticket == 0 && exit_position_ticket == 0`), not the broker book.

DeepSeek Phase 1 (`prompts/deepseek_grind_fill_race_stale_state_response.md`)
rated P1 (invariant quarantine) AMEND: correct target but must retain exit
retry and prefer event-based release over time-only grace.

## Decision

1. Quarantinable reasons are those a single legitimate fill or CloseBy can
   produce momentarily:
   - `I3_*_NAKED` — proven live (entry visible before its exit is visible).
   - `I4_*_ORPHAN_EXIT` — derived: a CloseBy removes two positions; the
     terminal can expose one removal before the other.
   - `I2_*_EXIT_DUP` — derived: positions are collected before orders; an exit
     order's fill can show the new exit position while the order is still
     listed.
   Everything else halts immediately, unchanged.

2. Halt only when the failure persists for BOTH at least 3000 ms (monotonic
   local clock) AND at least 3 consecutive failing checks. Checks do not run
   during a blocking send, so time alone could halt on the first check after a
   long stall; checks alone could halt within milliseconds. MQL5 queues at most
   one NewTick event, so trade transactions queued behind it run between
   consecutive checks.

3. Any passing check ends quarantine and resets the clock and check count.

4. While quarantined the engine is frozen for the whole instance, except exit
   retry (`Grind_RetryMissingExits`), which still runs on both sides. Exit retry
   is safe during a transient because it keys on the EA's own record: in the
   proven transient the layer still holds its exit order ticket (or is not yet
   in the record at all), so no duplicate exit is sent.

5. `Grind_CheckBookInvariants` stores the failure reason in
   `g_grind_invariant_reason`; `OnTick` sets `g_grind_halt_reason` only when
   actually halting, so the dashboard never shows a halt reason for an instance
   that is merely quarantined.

6. Reconstruction in `OnInit` is unchanged: any failure at attach still halts.

## Alternatives considered

1. **Immediate halt as today.** Rejected: 91 ms transients become permanent
   damage when `OnTradeTransactionEngine` ignores post-halt fills.

2. **Time-only grace.** Rejected: a single check after a long blocking send
   could halt despite a legitimate in-flight exit; checks alone are also
   insufficient without a minimum elapsed time.

3. **Event-keyed release only.** Deferred: correct primitive for fill/invariant
   ordering but adds coupling to transaction dispatch; dual threshold (time +
   checks) is simpler and sufficient for proven transients.

4. **Side-scoped freeze.** Deferred: DeepSeek recommended per-side gating;
   whole-instance freeze with exit retry is simpler and quarantine is expected
   to last well under a second.

## Consequences

- A genuinely naked position now halts after >= 3 s and >= 3 checks instead of
  at once, with exit retry active meanwhile.
- P2–P4 stale-state defects (duplicate L0, wrong-layer exit, stray pending
  reconciliation) are not addressed here (ADR-129).
- OnInit reconstruction unchanged: attach-time invariant failure still halts
  immediately.
- Heartbeat gains `quarantined`, `quarantine_reason`, and
  `quarantine_episodes` fields.

## Evidence

- AUDCHF_ALT 2026-09-11 10:35:40.980 UTC: `I3_LONG_NAKED` halt; exit fill
  journal at 10:35:41.071 UTC (91 ms later).
- Four earlier I3 halts with the same fill-after-halt signature.
- DeepSeek P1 AMEND: retain exit-retry during quarantine.

## Tests

Q1–Q11 in `fxgrind_tests.mq5`:
- Q1: transient I3 released within 91 ms class.
- Q2: persistent I3 halts when both 3000 ms and 3 checks met.
- Q3: time alone without 3 checks does not halt.
- Q4: checks alone without 3000 ms do not halt.
- Q5: non-quarantinable reasons halt immediately.
- Q6: non-quarantinable reason during quarantine halts immediately.
- Q7: passing check resets clock and check count.
- Q8: quarantinable reason set membership.
- Q9: reason change within episode keeps clock.
- Q10: `Grind_RetryMissingExits` places only uncovered layers.
- Q11: heartbeat carries quarantine fields.
