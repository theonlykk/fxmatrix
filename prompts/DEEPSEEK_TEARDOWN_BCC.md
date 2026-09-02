<!-- SENTINEL-FIRST: FXMATRIX-BCC-TEARDOWN-BEGIN -->
# DeepSeek Teardown Commission -- Book-Consistency Check (BCC) + Exit-Lifecycle Audit

Phase 1 (Red Team Prime). You are the adversarial quant. Write ZERO
implementation code. This commission is deliberately TIGHT: cadence and the
HALT_21 question are already resolved by source inspection (stated below as
GIVENS) -- do not re-litigate them. Spend your effort on the two threats that
genuinely need adversarial eyes (T-1, T-3) plus the upstream audit (T-5).

<!-- context so you do not retail-judge the system -->
## 0. Frame (do NOT retail-judge)

FXMatrix V2 is a market-making / liquidity-provision going concern, not a
retail directional strategy. Per-side independent grids (MM_LONG / MM_SHORT).
No stops; held inventory; MTM-not-realized; short-gamma. Do NOT critique "no
stops" or "why hold inventory" -- that is the thesis. BCC is a passive
observability feature: it DETECTS and ALERTS on book inconsistency; it never
cancels or closes (reconciliation stays a human action on the live account).
The burden is correctness and no-false-alarms, not P&L.

## 1. Motivating incident (Aug 14, source-verified)

A live VPS reattach after a routine deploy halted 3 of 6 sides and needed a
4-pass manual reconciliation. Two failure modes were INVISIBLE to all tooling:
- ORPHAN EXIT: a resting exit-hedge order (magic 9x3/9x4) whose position was
  gone (left by a manual close the EA never observed). It sat resting,
  unflagged, and would re-trigger a halt on the next reattach.
- ONE-LEGGED SIDE: an instance quoting only one leg (a reattach was missed).
Pipshed showed no warning because (verified) its telemetry payload sends
"working_orders":{} (empty) and its alert banner only relays EA-emitted
alerts. So the check must live IN THE EA.

## 2. GIVENS (resolved by source at commit 24c02d9 -- do NOT attack these)

G1. HALT_21 is NOT a bug and needs no matcher change. The SRE reconstruction
    matcher (V2_SRE_AssignRecurse) requires a PERFECT assignment: every
    position paired to an eligible exit AND every managed exit consumed. An
    exit no position can justify breaks the search -> HALT_21. It correctly
    fail-closes on an inconsistent book. Do NOT propose loosening it.

G2. Orphan creation is UPSTREAM, not in the SRE. Normal layer removal always
    cancels the exit (Long_RemoveLayerAt -> V2_CancelExitOrder). Orphans arise
    from (a) the async CloseBy window and (b) external/manual closes the EA
    never observes.

G3. Cadence is resolved. Long_/Short_AuditExitLimits() runs EVERY TICK and
    already walks g_*_layers[] (position_live vs exit_live per layer), clears
    stale exit tickets, re-places missing exits, and emits alerts on the
    existing rail (V2_PushSystemAlert / V2_EscalateExitAlert). BCC's per-layer
    checks piggyback this for zero added API cost.

G4. The existing audit is LAYER-FIRST (position -> exit): it only inspects
    exits referenced by a layer. It structurally CANNOT see an exit order
    whose layer is already gone -- which is exactly why the orphan was
    invisible. BCC's core new logic is the COMPLEMENTARY direction, exit ->
    position: enumerate broker exit orders (9x3/9x4) and ask "does a live
    position justify this?"

## 3. The proposed BCC (attack THIS)

Runs per side after reconstruction (OnInit, on a non-halted side) and on the
existing per-tick audit cadence. Four checks, each emitting a structured
system_alert on a PERSISTENT inconsistency:

- C1 ORPHAN EXIT (the new exit-first scan): for every managed exit order
  (magic 9x3/9x4) from OrdersTotal, is there a live position that justifies it
  under SRE-equivalent eligibility (same symbol/direction/volume; price ~=
  entry +/- exit_pips within tolerance, carry-drift tolerant)? No justifying
  position -> ORPHAN.
- C2 NAKED POSITION: every live entry-magic position (9x1/9x2) has a live
  resting exit (largely already covered by AuditExitLimits).
- C3 ONE-LEGGED / DEAD SIDE: a side with inventory or that should be quoting
  is emitting neither a fresh quote nor a resting entry over M ticks; cross-
  checked against halt state so a by-design HALT (e.g. ADR-113 HALT_09) is
  reported as HALTED, not a spurious BCC alert.
- C4 DUPLICATE PENDING: more resting entry orders (9x1/9x2) on a side than the
  grid state expects.

<!-- SENTINEL-MID: BCC-T1-CLOSEBY-WINDOW -->

## 4. THREATS -- spend here

### T-1 (false positives from legitimately-transient inconsistency) -- PRIMARY
The book is legitimately, transiently inconsistent by design. Specifically the
async CloseBy window: when an exit fills, the exit-hedge position is QUEUED for
CloseBy netting (V2_QueueCloseBy) and the layer removed on the SAME tick, but
the CloseBy is PROCESSED on a LATER tick (V2_ProcessCloseByQueue in OnTick). So
for a window of >=1 tick, a hedge/exit legitimately exists with its
counterparty mid-net. A naive C1 exit-first scan will call this an ORPHAN and
alert-storm on every single normal harvest.
DIRECTIVE: prove a debounce/gating rule that fires C1 ONLY on a PERSISTENT
orphan (e.g. same unmatched exit across >=2 consecutive audits AND not present
in either CloseBy queue) and NEVER on a mid-CloseBy exit. Exhibit any fill/
crash/tick sequence that defeats the gating (a real orphan suppressed, or a
transient flagged). Also consider: partial fills, requotes, and the exit-retry
/ re-place path (AuditExitLimits re-places a missing exit) as additional
transient sources.

### T-3 (is the exit-first scan actually sufficient?) -- PRIMARY
C1 must catch the Aug-14 orphan: an exit NO layer references. Confirm the scan
is genuinely broker-first (OrdersTotal-driven), not layer-driven -- a
layer-driven scan reproduces the exact blind spot (G4) and misses the orphan
it exists to catch. Then attack the eligibility test: can a real orphan MASQUERADE
as justified (an unrelated live position whose entry +/- exit_pips happens to
land within tolerance of the orphan's price), causing a false-NEGATIVE (orphan
missed)? Consider carry-drifted exits (ADR-114): the tolerance must admit a
carry-shifted exit as justified, but that same widened tolerance may let an
orphan be spuriously "justified" by a nearby position. Characterize the
false-negative surface.

### T-2 (BCC vs SRE view drift) -- SECONDARY
BCC reconciles against g_*_layers[], which the SRE rebuilds at OnInit. Prove
BCC's OnInit call site runs AFTER reconstruction commits (or is a no-op on a
halted side), so BCC never reports phantom inconsistencies off a half-built
layer array. Confirm BCC's eligibility mirrors the SRE's Tier1/Tier2 so a book
BCC calls clean will also reconstruct clean (and vice versa) -- if they
diverge, BCC gives false confidence exactly where it matters.

### T-4 (cadence / API budget) -- LIKELY RESOLVED, confirm only
Given G3 (per-tick audit already enumerates), confirm C1's added OrdersTotal
scan does not materially consume the daily API budget, or state the minimum
cadence at which C1 is safe (orphans are persistent, so C1 need not run every
tick). Short answer expected; do not over-invest.

### T-5 (upstream exit-lifecycle audit) -- the PREVENT half
BCC DETECTS orphans; this asks whether we can PREVENT them. Attack the exit
lifecycle for every path where a position closes WITHOUT the layer's
V2_CancelExitOrder running: the async CloseBy window (does a crash between
V2_QueueCloseBy and V2_ProcessCloseByQueue strand the exit?), CloseBy failure/
partial, and external/manual closes (which the EA cannot observe at all). For
each, state whether it is preventable in-EA or is inherently a
detect-only-via-BCC case. Do NOT propose auto-remediation.

## 5. Negative space

- Do NOT re-litigate G1-G4 (HALT_21, orphan-is-upstream, cadence, layer-first
  blind spot) -- all source-verified. Challenge one ONLY with a concrete proof
  it is wrong.
- Do NOT propose auto-remediation (cancel/close). Detect + alert only.
- Do NOT judge by retail metrics. Do NOT write implementation code.
- Do NOT over-flag. Every claimed exploit needs a concrete mechanism / minimal
  repro (a fill/tick/crash sequence), not a hand-wave. Unsupported flags will
  be checked against source and discarded.

## 6. Required output format (independently verifiable)

For EACH of T-1, T-2, T-3, T-4, T-5:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE.
- LOAD-BEARING CLAIM: stated so Claude can check it in source -- name the
  file / function / invariant it depends on.
- MINIMAL REPRO / MECHANISM: the concrete sequence or condition.
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic.
Plus a final OVERRIDE CHECK: does any finding invalidate the BCC premise
(passive exit-first detector on the existing audit rail), or are all findings
fixable within it? Last line.

<!-- SENTINEL-LAST: FXMATRIX-BCC-TEARDOWN-END -->
