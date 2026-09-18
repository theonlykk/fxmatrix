This message has a line count at the bottom

# ADR-152 -- Entry purgatory: fill-time placement, priority band, entry horizon

| | |
|---|---|
| Status | **DRAFT** -- Gemini approved the shape (2026-09-17); this is the consolidated spec for Cursor |
| Date | 2026-09-17 |
| Design record | `prompts/entry_purgatory_memo.md` (rev 1, `4859570`), `prompts/entry_purgatory_memo_rev2.md` (`40c4f27`) |
| Red team | DeepSeek R1: purgatory rev 1 `f3ebc31`; ADR-152a `bbdf464`. Every load-bearing claim re-verified against source by Claude |
| Rulings | Gemini 2026-09-17 on rev 2 (approved with amendments); Gemini 2026-09-17 on the fold (Q4-bis accepted, Q7 accepted with a hard amendment) |
| Supersedes | **ADR-152a is abandoned**, not implemented |
| Source baseline | EA `c39fb84` |

## Context

`Grind_SlotEntryAllowed` (grind_exitq.mqh ~161) allows an entry only while
`used + resting_ent <= limit - (2 + GRIND_SLOT_MARGIN)`, i.e. 194 of 200.
`Grind_SlotUsed` counts positions + orders; `Grind_SlotRestingEnt` counts every
fleet pending order whose role is not EXT, so **each resting entry costs two
units**. Placement is serialised by `Grind_SlotLockAcquire` but unordered.

Live 2026-09-17: book 170-174 of 200 all afternoon, resting entries 24-25,
guard total 195-198. Most resting entries were adds 8-16 pips from mid. Two
at-market GBPUSD foothold adds waited 5 and 11 minutes behind them; at 18:30Z
nine sides that should have had an entry had none. The binding constraint is
the guard, not the account, and the orders consuming it are the ones least
likely to fill.

**Why ADR-152a was abandoned.** Gemini's first ruling split the fill-path timing
change out as a prerequisite. The teardown showed the split itself was the
defect: (a) a due flag serviced on the next tick reorders work but does not
remove the tick boundary, so the verified repro still misses; (b) servicing due
adds before L0 lets a far add take the last guard unit ahead of an at-market L0
-- the purgatory defect, reproduced inside the prerequisite. Placement timing
and the priority band are one coupled problem. This ADR designs them together
and isolates risk by rollout phase instead.

## Decision

### D1. Fill-time placement (optimistic lock)

In the `c_role == "ENT"` branch of `Grind_HandleSideDealFill`, after
`Grind_ExitQManageSide`:

    attempt the slot lock ONCE via GlobalVariableSetOnCondition
    if acquired:
        evaluate Grind_SlotEntryAllowed with the D2 band
        place the next add for this side if allowed
        release the lock
    else:
        set g_grind_add_due_<side>; the next tick services it

**Hard amendment (Gemini Q7):** this path MUST contain zero retry loops and
zero `Sleep()` calls. `Grind_SlotLockAcquire` is NOT reused here; a separate
single-attempt helper is required. Exits already send from this handler, so a
conditional entry send introduces no new threading risk provided it never
blocks.

### D2. Priority band (reserved units)

An entry whose target is within **one add step** of mid may use the full
ceiling. Any other entry may place only while
`used + resting_ent <= 194 - Q`, with `Q = 8` (`GRIND_SLOT_NEAR_RESERVE`).
Applies to adds AND L0, evaluated locally: no cross-instance ranking, no shared
state beyond the existing lock.

### D3. Entry horizon (the withholding itself)

Adds only. L0 unchanged.

- Place while `|target - mid| <= H_place`, `H_place = 2 x add_pips`.
- Cancel once `|target - mid| > H_cancel`, `H_cancel = 4 x add_pips`.
- A held add has no broker order and no ticket; its target is recomputed from
  the deepest layer each tick, as held exits are recomputed from entry price.
- **Floor:** an add within one add step of mid ALWAYS rests, whatever the
  horizon says. This bounds gap exposure to far adds only.
- Comparisons use `GRIND_PRICE_EPS` (teardown T-3).

### D4. Churn and request budget

- Per side, per broker day: at most `GRIND_ENTRY_TRANSITIONS_MAX = 20`
  place/cancel transitions, reset with the API counter's broker-date reset.
  Worst case 16 x 2 x 20 x 2 = 1,280 sends/day.
- When a side's budget is exhausted the add **stays resting** (fails toward
  today's behaviour) and telemetry flags it.
- **Hard entry stop at 1,900 requests/day** (`GRIND_DAILY_API_ENTRY_STOP`):
  new entries are refused; exits, cancels and CloseBy are never blocked. This
  is the FTMO 2,000/day compliance fix and is independent of the horizon.

### D5. Flag lifecycle

`g_grind_add_due_long` / `g_grind_add_due_short` are cleared on: successful
placement, re-price, cap reached, label-validation failure, guard refusal
(after one attempt in that tick -- no same-tick retry, teardown T-6),
quarantine entry and exit, halt, and `OnInit` before reconstruction
(teardown T-3).

### D6. Gap policy

Missed gap fills on far adds are ACCEPTED (Gemini Q1). A gap through a held
target cannot be chased because the engine never crosses the spread, and
`Grind_Adr013ClampBuy` prices the late order below the new bid. The D3 floor
limits this to adds beyond one step. `add_gap_missed` telemetry is a hard
deployment gate.

## Rollout (Gemini Q4-bis: phases replace the separate ADR)

**Phase 1 -- placement mechanics and priority. No withholding.**
Ships D1, D2, D4's hard stop, D5, and all telemetry. Every add still rests
exactly as today; only WHEN and in WHAT ORDER entries are placed changes.
- Deploy to GBPUSD OPT + ALT for 48 h, then the fleet for 48 h.
- Fallback: revert to `c39fb84` behaviour by disabling D1 (`InpFillTimePlace
  = false`) and setting `Q = 0`. Both are inputs, not code paths.
- The compiled EA defaults for `InpFillTimePlace` and `InpSlotNearReserve`
  must be `false` and `0`. Pilot participation is strictly opt-in via preset
  files to enforce a fail-closed posture against missing or stale
  configuration.
- Promotion gate: zero halts, zero quarantine episodes, zero I3/I6 markers.
  Strike `entry_place_latency_ms` and `near_reserve_blocks`. The gate requires
  manual terminal log extraction of the `fill-to-placement gap` for all pilot
  fills. This gap must be recorded as the baseline for Phase 2 validation.

The standalone Phase 1 fleet rollout is cancelled due to unresolvable guard
saturation. The Phase 1 pilot remains active on GBPUSD OPT/ALT, but will
deploy to the remaining 14 instances concurrently with Phase 2.

Pilot duration requirements (e.g. 48 hours) are measured strictly in active
trading hours. Friday 21:00Z to Sunday 21:00Z pauses the promotion clock.

**Phase 2 -- the horizon.**
Ships D3, D4's transition budget, D6.
- Deploy to GBPUSD OPT + ALT for 48 h, then the fleet.
- Fallback: `InpEntryHorizonPips = 0` disables withholding; the engine reverts
  to Phase 1 behaviour with no restart required.
- Promotion gate: resting entries fleet-wide below 14, guard total below 185 at
  the daily peak, `add_gap_missed` measured (not a threshold -- a measurement),
  and requests/day below 1,800.

## Telemetry (hard gates, Gemini Q6)

Per instance per side: `add_held` (bool), `add_pending` (price or null),
`entry_transitions_used`, `add_gap_missed` (count), `entry_place_latency_ms`.
Fleet: `guard_total`, `near_reserve_blocks` (count of entries refused by the
band). pipshed must render `add_held` distinctly from `add_pending`: the
operator cannot fly blind on invisible state.

## Tests

Pure/unit:
T1. Single-attempt lock helper: no loop, no `Sleep` (timing bound in
    `T1_try_lock_does_not_block`. The no-`Sleep`/no-loop property is checked
    during verification, not by the suite: extract the body of
    `Grind_SlotLockTryAcquire` from `grind_exitq.mqh` between its opening and
    closing brace and assert no `Sleep(`, `for(` or `while(` within that range
    only. A file-level grep of `grind_exitq.mqh` MUST NOT be used and will fail
    by design, because `Grind_SlotLockAcquire` legitimately contains `Sleep(1)`.
    Separately assert that `Grind_HandleSideDealFill` reaches the lock only
    through the try-variant.)
T2. Fill-time placement occurs when the lock is free; the due flag is set when
    it is taken.
T3. Band: a far entry is refused at `used + resting_ent = 194 - Q + 1`; a near
    entry is allowed at 194.
T4. Horizon: place at `<= H_place`, cancel above `H_cancel`, no flicker between
    them, floor always rests.
T5. Transition budget exhausts, add stays resting, flag raised.
T6. Entry stop at 1,900: entries refused, exits unaffected.
T7. Flag cleared on each path in D5 (one case per path).
T8. No double-send: due flag plus ordinary `EnsureAddNext` in the same tick
    yields one add.
T9. Reconstruction: held add has no ticket; `Grind_ReconCheckPendingAddCorrupt`
    still passes; no invariant asserts a resting entry.
T10. Gap: price jumps a held target; `add_gap_missed` increments exactly once.

## Risks

R1. Fill-path change is the highest-risk edit in the engine. Mitigated by the
    no-Sleep amendment, Phase 1 isolation, and the input-level fallback.
R2. The band is local arithmetic, so two instances can still both pass it in the
    same window. Accepted (Gemini Q2): it bounds far adds, it does not rank.
R3. Held adds are invisible state; mitigated only by telemetry, which is why
    that telemetry is a gate rather than a nice-to-have.
R4. `add_gap_missed` may prove material on some symbols. Then the remedy is a
    wider floor per symbol, not abandoning the horizon.

Line count: 166
