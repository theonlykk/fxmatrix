# Phase 1 Audit Request — EUR-Side Cross-Instance Exposure Cap

## Role reminder
This is a Phase 1 Red Team submission per ARCHITECT.md. Mechanical and
mathematical audit only — no implementation code in the response. This
mirrors an existing, already-shipped mechanism (the GBP cap), so the
ask is specifically to find where the mirroring breaks down, not to
re-litigate the overall design.

## Background
`fxmatrix_v2_gbp_cap.mqh` (production, currently shipped with
`InpGbpCapThreshold=0`, off by design pending a live dry run) gates
combined GBP exposure across GBPUSD and EURGBP:

```
GBP_exp = (long_GBPUSD - short_GBPUSD) - (long_EURGBP - short_EURGBP)
```

It gates only widening `V2_Add` calls (not reload, not L0, not exits),
via four GlobalVariables (`V2GBP_L_GBPUSD`, `V2GBP_S_GBPUSD`,
`V2GBP_L_EURGBP`, `V2GBP_S_EURGBP`), recompute-and-overwrite on every
`AppendLayer`/`RemoveLayerAt` and on `OnInit` (confirmed: not an
independent counter, no drift risk beyond what's already reviewed —
see the OnInit/OnDeinit lifecycle note below). Missing GV reads as 0
(permissive).

A separate combined cross-pair exposure analysis found EURUSD and
EURGBP's shared EUR leg produces the same kind of correlated risk the
GBP cap already addresses — but no analogous mechanism exists for it.
EURUSD currently has zero cap infrastructure of any kind.

## Proposed design
New file, `fxmatrix_v2_eur_cap.mqh`, same architecture as the GBP cap:

```
EUR_exp = (long_EURUSD - short_EURUSD) + (long_EURGBP - short_EURGBP)
```

**The sign is addition, not the GBP cap's subtraction.** Being long
EURGBP means long EUR and short GBP. The short-GBP leg offsets
GBPUSD's GBP exposure (subtraction, correct in the existing cap). The
long-EUR leg reinforces EURUSD's EUR exposure rather than offsetting
it — hence addition here. This sign flip is the single most important
thing to verify; getting it backwards would produce a cap that either
never triggers or triggers on exactly the wrong condition.

New GV keys: `V2EUR_L_EURUSD`, `V2EUR_S_EURUSD`, `V2EUR_L_EURGBP`,
`V2EUR_S_EURGBP` — distinct from the existing `V2GBP_*` keys.

New input: `InpEurCapThreshold`, default `0` (off), same convention as
`InpGbpCapThreshold`.

Same gating scope as the GBP cap: blocks only a widening `V2_Add`,
skips reload/L0/exits. Same recompute-and-overwrite publish pattern —
no independent counter, no incremental state to drift.

**Known, already-reviewed lifecycle behavior, not new to this audit:**
`OnInit` immediately overwrites an EA's own GV keys with its live
`ArraySize(g_*_layers)`, which is 0 on a fresh restart. `OnDeinit`
never touches the GV. Layers are never rebuilt from a broker scan on
restart — if an EA is recompiled while holding open positions, the
orphan guard halts the instance rather than reconstructing state
(this is a known, backlogged issue — a "State Reconstruction Engine"
item — not something this cap design needs to solve). The standing
operational rule is that recompiles only happen on a confirmed-flat
chart. Flag only if the EUR cap introduces any NEW lifecycle risk
beyond what's already accepted for the GBP cap — do not re-litigate
the already-accepted risk itself.

**What's genuinely new here, not just a copy:**
1. EURUSD has never participated in any cap before. This is first-time
   construction on that file — new input, new include, new sync calls
   at `OnInit`/`Long_AppendLayer`/`Long_RemoveLayerAt`/
   `Short_AppendLayer`/`Short_RemoveLayerAt` — not a threshold change
   on existing wiring.
2. EURGBP will carry TWO independent caps simultaneously once this
   lands — its existing GBP-cap sync calls stay as-is, and a second,
   separate set of EUR-cap sync calls gets added at the same call
   sites. Confirm this dual-publish is safe: does each `AppendLayer`/
   `RemoveLayerAt` event need to fire both caps' sync functions, and is
   there any risk of one cap's GV state going stale relative to the
   other, or any interaction between the two blocking checks (e.g.
   could the GBP cap block an add that the EUR cap would separately
   have allowed, or vice versa, in a way that produces confusing or
   contradictory logging)?

## Explicit questions for Red Team critique

1. **Sign convention.** Is `EUR_exp = EURUSD_net + EURGBP_net` correct
   given the two pairs' actual quote-direction conventions, or does
   this need to be checked more carefully against exactly how
   "long"/"short" is defined for EURGBP specifically (recall EURGBP
   already required care here — its AB-slot signal path treats
   EURUSD and GBPUSD as the two legs of a triangulated cross;
   confirm the cap's long/short net convention aligns with that same
   definition of direction, not a naive assumption)?

2. **Dual-cap coexistence on EURGBP.** With two independent
   4-GV-key groups both being synced from the same layer-append/
   remove call sites, is there any mechanical risk of one cap's sync
   call being accidentally omitted, duplicated, or ordered incorrectly
   relative to the other? Should both syncs happen in the same
   function call, or does call-site duplication risk one being missed
   in a future edit?

3. **Threshold interaction.** If both `InpGbpCapThreshold` and
   `InpEurCapThreshold` are eventually enabled simultaneously on
   EURGBP, could a single widening add ever be blocked by one cap and
   simultaneously appear to have "passed" the other's check in a
   confusing log sequence? Should the two checks be combined into one
   gate function that evaluates both, rather than two independent gate
   calls?

4. **GV key collision or naming risk.** Confirm `V2EUR_L_EURUSD`,
   `V2EUR_S_EURUSD`, `V2EUR_L_EURGBP`, `V2EUR_S_EURGBP` don't collide
   with any existing GlobalVariable name in use (the `V2GBP_*` keys,
   `V2GBP_CAP_TRIGGERS`, or anything else already published).

5. **Unification question, informational only.** Is maintaining two
   separate single-purpose cap files (`gbp_cap.mqh`, `eur_cap.mqh`)
   architecturally sound, or does having EURGBP as a dual-participant
   argue for a single generalized "cross-pair exposure cap" module
   now rather than two parallel ones? Flag your view; this is also
   being put to the Staff Architect in parallel — Red Team's mechanical
   opinion is a useful independent input, not the deciding vote.

## What Red Team must NOT do
Do not write implementation code. Do not propose a specific threshold
value (no calibration numbers) — that is separate future work, exactly
as it was for the GBP cap (built and validated, shipped off, pending
its own live dry run). Flag anything that should block this from
proceeding to a Staff Architect ruling and, eventually, a Cursor
implementation prompt.
