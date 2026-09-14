# ADR-141: Invariant Failure Detail Payloads

## Status

Accepted -- 2026-09-14.

## Context

**Live incident (2026-09-14, GRIND_GBPUSD_OPT):**

The instance halted with `I6_LONG_EXIT`, blocking CloseBy on a netted pair.
The operator closed two positions manually. Roughly one hour was spent across
fill_logs, ea_events, and the VPS Experts log; the root cause remains unknown
because the marker recorded only the string `I6_LONG_EXIT`.

**Four theories investigated and disproved:**

1. Favourable slippage (sign was backwards).
2. Systematic slippage (measured: mean +0.1 pips, 2% adverse breaches).
3. Inconsistent enforcement (CloseBy runs before the check; halt is deliberate).
4. The exit fill caused the halt (`halted_at_receipt=true` proves the halt
   came first).

**Principle (Gemini, verbatim):**

A halt is the most severe event the engine can trigger; it must always defend
its reasoning with a detailed payload. Telemetry is cheaper than your time.

`Grind_ReconCheckInvariants` knew exactly which layer failed and every number
involved at the moment it decided to fail. It discarded all of it and kept a
string. Every other ADR-132 marker carries a detail object; the single most
consequential event carried none.

**ADR-140 abandoned:**

A branch (`fix/i6-exit-fill-slippage`) was specced to widen I6 for "favourable
slippage" when the live fill was adverse. Gemini ruled NUKE -- merging it would
have blinded the fleet to broker bridge failures. This ADR records why that
fix was abandoned.

## Decision

Every invariant failure (`I1` through `I8`) emits a braced JSON object naming
the failing layer and the arithmetic involved:

1. **`g_grind_invariant_detail`** -- companion to `g_grind_invariant_reason`.
   Set at each failure site; cleared to `""` when the check passes.

2. **Per-invariant payloads** -- layer index, side, tickets, counts, signed
   `diff_points` for I6, `exit_is` ORDER vs POSITION, `failed_test` for I3,
   etc. Prices use `Grind_ArchiveJsonDouble`; strings escaped; `null` where
   a field does not apply.

3. **Telemetry** -- `Grind_TelemetryCritical` gains optional `info_json`. When
   non-empty: `{"detail":"<reason>","info":<object>}`. When empty: unchanged.

4. **Archive** -- `Grind_InvariantEmitArchive` queues
   `Grind_ArchiveMarker("CRITICAL", "INVARIANT_FAIL", reason, ticket,
   {"info":<object>})` so the row lands in Postgres. Marker ticket is the
   failing layer's `position_ticket` when available, else 0.

5. **Print prefix** -- `Grind_LogTag()` returns `[<instance>] ` and prefixes
   halt-adjacent Prints (quarantine, stray L0, reconcile) so OPT and ALT are
   distinguishable in the Experts log. Telemetry payloads unchanged.

**Unchanged:**

- Invariant thresholds, tolerances, and pass/fail logic.
- `Grind_ProcessCloseByQueues` and its position in `OnTick`.
- Telemetry field names other than adding `info`.

## Implementation

| Change | Location | Summary |
|--------|----------|---------|
| 1 | `grind_recon.mqh` | `g_grind_invariant_detail`, detail builders, all I* failure sites |
| 2 | `grind_telemetry.mqh` | Optional `info_json` on `Grind_TelemetryCritical` |
| 3 | `fxgrind.mq5` | Pass detail to telemetry + archive on INVARIANT_FAIL halt |
| 4 | `grind_state.mqh` | `Grind_LogTag()` |
| 5 | `grind_engine.mqh`, `grind_quarantine.mqh` | Prefix selected Prints |
| 6 | `fxgrind_tests.mq5` | IV1-IV6 regression tests |
| 7 | This document | ADR-141 |

## Verification

- MetaEditor compile: `fxgrind.mq5` -- 0 errors, 0 warnings.
- Unit suite: 934 total assertions (920 baseline + 14 IV).
  - **IV1:** I6 long, exit ORDER, detail contains `exit_is`.
  - **IV2:** live GBPUSD case, POSITION, `diff_points:-6`, exit ticket.
  - **IV3:** I3 naked names `failed_test`.
  - **IV4:** I7 depth carries both numbers.
  - **IV5:** passing check clears detail.
  - **IV6:** braced JSON shape; archive row contains `"info":{"layer_index":`.

## Consequences

Positive:

- The next halt explains itself in one telemetry line and one Postgres row.
- Detail is cleared when the check passes so a stale payload cannot mislead.
- OPT vs ALT Prints are distinguishable in shared-symbol Experts logs.

Negative / bounded:

- Payload size is bounded by one layer's worth of fields (well under MQL5
  Print limits).
- Non-invariant recon failures (unparseable comment, etc.) still carry only
  the reason string until separately addressed.

## References

- ADR-125: fxgrind clean slate (I6 and sibling invariants).
- ADR-128: invariant quarantine before halt.
- ADR-132: marker detail objects.
- ADR-135a: unbraced detail rejected by pipshed (CX14 regression).
- ADR-140: abandoned I6 slippage widening (see Context above).
