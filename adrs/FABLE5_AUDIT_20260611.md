# FXMatrix EA — Fable 5 Full Audit Report
# Date: 2026-06-11
# Auditor: Claude (Fable 5), adversarial architect + lead engineer pass
# Scope: all 7 EA files @ HEAD 0bba98c
# Evidence: logs/20260611_run46_patch7.log (13 concatenated tester
#   passes; final pass = lines 1684271–1705588 = the true Patch 7 run)

---

## EXECUTIVE SUMMARY

Both Tier 1 blockers are solved with log-verified root causes:

1. **add_next=3.35863** — the `-1.0` passivity sentinel from
   `InvertSpreadToPrice()` leaks into `ComputeNextLayerPrice()`'s
   differential. Arithmetic verified exactly:
   `3.35863 = deal_price 1.17932 + (price_next 1.17931 − (−1.0))`.
2. **−$35.80 loss** — position #121 (EURUSD BUY 0.01 @ 1.18251,
   filled 2026.04.17 17:10) was stranded for 7 weeks and force-closed
   at end of test (2026.06.05 23:54:59 @ 1.15220): −303.1 pips =
   −$30.31 + ~7 weeks of negative swap ≈ −$35.80.

Beyond the brief, the audit found **two systematic formula defects**
that explain why EURUSD/GBPUSD "don't contribute": in the entire
final pass the EA placed **EURUSD BUY ×19, GBPUSD BUY ×16,
EURGBP SELL ×12, and ZERO entries in the other three routings**:

3. **EURGBP BUY formula is wrong** (mirror-image price; never passive;
   never enters). The "EURGBP unchanged" locked ruling is incorrect
   for the BUY case.
4. **Close-as-mid assumption is wrong** (MT5 closes are BID): SELL
   entries on EURUSD/GBPUSD compute to bid+half = mid < ask → fail
   passivity 100% of the time. USD-pair SELL routings never trade.

Also confirmed: an EA-halt state corruption class (April 28 pass-1
cross-symbol layer inheritance), a halted-EA-keeps-trading defect,
and several smaller state risks. Details below.

---

## TIER 1 — BLOCKERS

### 1. add_next=3.35863 — ROOT CAUSE (verified)

`ComputeNextLayerPrice()` (ExecutionEngine.mqh:199-221) calls
`InvertSpreadToPrice()` twice (T = −current_threshold, −next_threshold)
and computes `price_offset = price_next − price_current`.

`InvertSpreadToPrice()` ends with the passivity guard
(MathEngine.mqh:207-214): **it returns −1.0 when the computed price is
not passive.** Neither leg's return value is checked.

At fill time the market is, by construction, sitting at the
current-threshold level (the entry limit just filled there). For a BUY:

- `price_current` (T=−0.0004) ≈ deal price ≈ current bid →
  `IsPassive` requires `price < bid` strictly → **fails → −1.0**
- `price_next` (T=−0.0006) is ~2.4 pips lower → passes → 1.17931

```
price_offset = 1.17931 − (−1.0)      = 2.17931
add_next     = 1.17932 + 2.17931     = 3.35863   ← exact log match
freeze log:  distance = bid − price  = 1.17931 − 3.35863 = −2.17932 ✓
```

Both failure polarities occur:

- **BUY layers**: add_next ≈ deal+price+1 is far ABOVE market → BUY
  passivity/freeze fails → "PlaceNextEntryLimit skipped" → **layering
  silently dead** (log lines 1685131, 1694136, …).
- **SELL layers (incl. EURGBP)**: corrupted price is far above market,
  which for a SELL limit *passes* passivity AND freeze → **garbage
  orders actually placed**: tickets 85, 98, 110 at 2.73854/2.73867/
  2.73922 (= EURGBP deal ≈0.871 + price_next ≈0.868 + 1.0). These
  unfillable orders occupy `g_pending_entry_ticket` (Highlander slot)
  while the pod is open — the nudge block requires inventory==0, so
  they are never corrected. **Grid mechanism fully dead.**

This single bug explains: no layering, single-layer pods, the frozen
April 17 → June 5 dead state, and (indirectly) the −$35.80.

**FIX (Patch 8 spec — preserves the locked passivity-guard ruling):**

1. Add parameter `bool enforce_passivity=true` to
   `InvertSpreadToPrice()`. The guard stays intact and on by default
   for every order-placement call site. `ComputeNextLayerPrice()`
   passes `false` for both legs — it needs the pure mathematical
   inversion (the ± half-spread terms cancel in the differential
   anyway, so the result is exact).
2. Defense in depth: in `ComputeNextLayerPrice()`, if either leg
   returns ≤ 0, return −1.0. In `HandleEntryFill()` /
   `PlaceNextEntryLimit()`, skip placement when `add_next <= 0`,
   and never store a corrupted add_next in the layer.
3. Sanity clamp: reject add_next that deviates more than X% (e.g. 5%)
   from deal_price — physical prices cannot jump that far in one
   layer step. Log SEV-2 if tripped.

### 2. −$35.80 catastrophic loss — ROOT CAUSE (verified)

Final pass, line 1695291 onward:

- 2026.04.17 17:10 — entry #121 EURUSD BUY 0.01 filled @ 1.18251
  (Layer 0). Exit SELL limit #122 placed ≈1.1841; carry recalc nudged
  it daily at 17:00 (1.18409 → 1.18373 → …).
- add_next was corrupted/skipped (bug #1) → no further layers.
- With `ArraySize(g_inventory) > 0`, the PLAIN MATRIX ENTRY block is
  locked out → **the EA did nothing else for 7 weeks**.
- EURUSD slid 1.1825 → 1.1522; the exit limit above market never
  filled; there is no stop-loss; MaxPodDrawdown (2% = $200) never
  trips on a −$30 open loss.
- 2026.06.05 23:54:59 — "position closed due end of test at 1.15220
  [#121 buy 0.01 EURUSD 1.18251]" = −303.1 pips = −$30.31, plus
  ~49 days of negative swap (long EUR vs USD) ≈ −$5.5 → **≈ −$35.80**.

The "April 15-16" estimate from the graph was the *entry* era; the
loss itself books at end of test. The brief's "~305 pip adverse move"
hypothesis was correct.

**FIX:** bug #1 restores layering/grid; additionally the strategy has
no tail-risk control for a non-reverting dislocation. Recommend a
time-based or distance-based abort (e.g. close pod if spread widens
beyond ComputeLayerThreshold(MaxLayers) or after N days), sized so
FTMO daily-DD math holds (see §12).

### 3. Symbols=1 in tester report — ARTIFACT (with a real asymmetry)

Genuine multi-symbol trading is proven by deals in the final pass
(EURUSD #121/#142, GBPUSD #122, EURGBP #140/#141 …). The report
header's Symbols counter reflects the tester's chart/market-watch
configuration, not traded symbols. **However**, participation is
asymmetric for real reasons — see §4b/§4c: three of six routings can
never enter.

---

## TIER 2 — ADVERSARIAL MATHEMATICAL AUDIT

Notation: r_EU = log(EU_now/anchor_EU); usd = −(r_EU+r_GB)/3;
eur = r_EU+usd; gbp = r_GB+usd. Identities: **eur−usd = r_EU,
gbp−usd = r_GB, eur−gbp = r_EU−r_GB.**

### 4. InvertSpreadToPrice() — all 6 routings re-derived

| Routing | T (entry) | Current market | Formula gives | Verdict |
|---|---|---|---|---|
| EURGBP SELL (s=0,w=1) | gbp−eur = −(r_EU−r_GB) | EG_hist·exp(r_EU−r_GB) = EG_hist·exp(−T) | EG_hist·exp(−T) | ✓ = current |
| EURGBP BUY (s=1,w=0) | eur−gbp = r_EU−r_GB | EG_hist·exp(T) | EG_hist·exp(**−T**) | ✗ **WRONG** |
| EURUSD SELL (s=0,w=2) | usd−eur = −r_EU | anchor·exp(r_EU) = anchor·exp(−T) | anchor·exp(−T) | ✓ = current |
| EURUSD BUY (s=2,w=0) | eur−usd = r_EU | anchor·exp(T) | anchor·exp(T) | ✓ = current |
| GBPUSD SELL (s=1,w=2) | usd−gbp = −r_GB | anchor·exp(−T) | anchor·exp(−T) | ✓ = current |
| GBPUSD BUY (s=2,w=1) | gbp−usd = r_GB | anchor·exp(T) | anchor·exp(T) | ✓ = current |

**4a. EURGBP BUY is mathematically wrong.** The brief asked "same
formula for both BUY and SELL — is this correct?" **No.** For BUY,
T = r_EU−r_GB (negative), current EG = EG_hist·exp(T) — *below* the
anchor ratio. The formula returns EG_hist·exp(−T) — *above* it, the
mirror image, 2|T| away from the market on the wrong side. A BUY
limit above market always fails `price < bid` → **EURGBP BUY entries
have never been placed** (log: 0 occurrences across the entire final
pass vs 12 EURGBP SELLs). Exit side of a hypothetical BUY pod is also
wrong: exit lands at EG_hist·exp(+0.3|T|) instead of
EG_hist·exp(−0.3|T|) — a 1.3|T| reversion target instead of 0.7|T|.
**Fix: EURGBP BUY must use `MathExp(T)` (or equivalently
`MathExp(-T)` only for the SELL case).** This invalidates the
"EURGBP unchanged" portion of the Patch 7 locked ruling — flagged for
Gemini re-ruling with this derivation as evidence.

**4b. Close-as-mid is false → USD-pair SELL entries never place.**
`RunSignalOnBarClose()` uses `CopyClose()`, which returns **BID**
closes in MT5. So anchor_EU and r_EU are bid-frame quantities and the
"target mid" reconstructed by every ✓-row above is actually the
**current bid**, not the mid. Consequences:

- SELL entry: price = bid + half_spread = mid < ask →
  `IsPassive (price > ask)` fails **always** → EURUSD SELL and
  GBPUSD SELL never enter (log: 0 placements of either in the final
  pass vs 19+16 BUYs).
- BUY entry: price = bid − half_spread < bid → passes always, but
  sits half a spread below the optimal level (a real fill-rate cost,
  not a correctness bug).
- EURGBP is partially shielded because anchor_EU/anchor_GB (bid/bid
  ratio) lands near the cross mid — hence its 12 SELL placements with
  many borderline passivity failures (log: repeated
  `price=0.86618 T=-0.000783` skips).

**Fix options (Gemini ruling needed):** (i) reconstruct mid-frame
anchors by adding the current half-spread to bid closes; or (ii) keep
bid-frame anchors and make the half-spread adjustment direction-aware
of the frame (SELL: price = bid_frame + full_spread; BUY: price =
bid_frame). Option (ii) is exact under constant-spread assumption.
This also moots the `gemini_close_as_mid_ruling` — re-open it.

### 5. Exit price computation — VERIFIED CORRECT (USD pairs)

EURUSD BUY layer: entry at anchor·exp(r_EU_entry) (= market at fill);
exit_spread_target = 0.3·entry_spread (smaller-magnitude negative);
exit = anchor·exp(0.3·r_EU_entry) > entry since r_EU_entry < 0. Exit
is a SELL limit above market at placement → passive ✓. Direction flip
via `is_exit` ✓. Mean-reversion geometry correct. Same for GBPUSD and
for EURGBP SELL pods. (EURGBP BUY exit is wrong per §4a, but such
pods cannot currently form.)

### 6. CarryEngine sign convention — CORRECT, with two operational risks

`scores_fwd[weakest] − scores_fwd[strongest]` over forward-adjusted
prices is consistent with the entry convention. Direction check: long
EUR vs USD pays carry (r_EUR < r_USD) → EURUSD_fwd < spot → spread
more negative → exit target moves closer to market → EA exits sooner
when paying carry. Economically coherent. Risks:

- **R1 (halt risk):** `OrderSend(MODIFY)` on `exit_tickets[]` without
  verifying the ticket is still a live pending order. The market-hedge
  path stores a *market order* ticket in exit_tickets; a 17:00 recalc
  in that window → modify fails → `g_halted = true`. Verify with
  `OrderSelect()` first; treat missing ticket as skip, not halt.
- **R2:** mixed reference frames (entry_price_eurusd at fill vs
  inherited _1h anchors) — accepted V1 approximation, documented.

### 7. Hysteresis state override (Patch 6) — SAFE with one wart

- CarryEngine reads layer fields, not globals → uncorrupted ✓.
- Override persists only until next bar's `RunSignalOnBarClose()`
  recomputes everything from scratch → no accumulation across
  consecutive rejections ✓.
- Nudge block: with a pending order, inventory==0 required; it
  recomputes from the locked routing → consistent ✓.
- **Wart:** `g_signal_active = (MathAbs(g_entry_spread) > BaseThreshold)`
  accepts a *sign-flipped* dislocation (pending labeling now positive
  spread) as "active". Downstream damage is blocked only because
  ComputeEntryPrice then produces a non-passive price (−1.0). Should
  be `g_entry_spread < -BaseThreshold` to encode the invariant.

### 8. HandleEntryFill reverse derivation — Layer 0 correct; inheritance path is the April 28 corruption

Layer-0 mapping matches `GetImpliedIndices()` and Patch 7 ✓. But the
`layer_idx > 0` path **inherits instrument/direction from Layer 0 and
ignores `deal_symbol` entirely**. Log-proven catastrophe (pass 1,
pre-5a binary, 2026.04.28): stale GBPUSD BUY limit #505 (orphaned by
the then-_Symbol-filtered CancelAllPendingEntries) filled into an
EURUSD SELL pod → Layer recorded as "EURUSD SELL, entry 1.35007" →
EURUSD exit limits placed against GBPUSD positions → CloseBy paired
GBPUSD #511 with EURUSD #512 → "Inconsistent symbols … halting" →
4 stranded positions force-closed at end of test (−$33.45 in pass 1).

Patch 5a closes the *main* orphan source, but the inheritance path is
still unguarded. **Fix:** in `HandleEntryFill`, if
`ArraySize(g_inventory) > 0`, validate `deal_symbol` (and deal_type
direction) against Layer 0's instrument/direction; on mismatch, do
NOT inherit — log SEV-1 and halt (or hedge-close the alien fill).

Two adjacent defects:
- **CancelAllPendingEntries early-return** (FXMatrix.mq5:311): if
  `g_pending_entry_ticket == 0` it returns without sweeping — orphaned
  EA-magic orders (ticket lost, e.g. after state reload) are never
  cancelled. The function's whole point post-5a is the sweep; drop the
  early-return.
- **Halted EA keeps trading:** `OnTradeTransaction` → HandleEntryFill/
  HandleExitFill have no `g_halted` check. Log-proven: after the
  April 28 halt, order #513 filled at 17:32:40 and the "halted" EA
  built a new layer and placed exit orders. Add `if (g_halted) return;`
  at the top of `OnTradeTransaction` (after logging the dropped event).

### 9. CloseBy queue race — two failure modes confirmed

- **Gone ≠ not-yet-on-ledger:** `PositionSelectByTicket` failing may
  mean the position closed permanently; the task can never succeed,
  burns 10 retries, then **halts the EA** (SEV-1) for a benign race.
  Distinguish via `HistorySelectByPosition()` — if the position has a
  closing deal in history, discard the task with an INFO log.
- **Retry cadence:** retries increment once per tick; 10 ticks can
  elapse in <1 s in fast markets — far shorter than realistic desync
  windows. Gate retries by time (e.g. min 1 s between attempts) or
  bar, not tick.
- The symbol-consistency check correctly caught the April 28
  corruption — keep it, but it should also requeue-protect: it halts
  while the *other* queue tasks are discarded silently on early return.

### 10. Radar removal — CONFIRMED SAFE

`GetBestRadarTarget()` has zero call sites (grep: only its definition
in MathEngine.mqh:267-318; `RadarTarget` struct only in
LayerStruct.mqh:68-75 + the function's internals). Cursor patch
generated: `prompts/cursor_patch_radar_removal.md`.

---

## TIER 3 — STRATEGIC

### 11. Multi-pod architecture

Current blockers: ~15 pod-scoped globals (g_inventory,
g_pending_entry_ticket, g_strongest/g_weakest, g_entry_spread,
g_signal_active, score globals, anchors, closeby queue, peak equity)
are singletons; state file is per-_Symbol; EA_MAGIC is single.
Required changes:

1. `struct Pod { Layer inventory[]; ulong pending_ticket; int
   strongest, weakest; double entry_spread; bool signal_active;
   double anchors[2]; CloseByTask queue[]; string symbols[3];
   ulong magic; }` — array of pods.
2. `RunSignalOnBarClose(Pod&)` parameterized by the pod's currency
   triplet; CopyClose per pod symbols.
3. magic = EA_MAGIC + pod_index; all fill routing
   (OnTradeTransaction) dispatches by deal magic first, then ticket.
4. Per-pod state files; CheckForOrphans must scan ALL pod symbols
   (today it only scans _Symbol — pre-existing gap, see §8).
5. Risk: circuit breakers become two-level (per-pod unrealized,
   global equity) — MaxPodDrawdown currently reads account-wide
   ACCOUNT_PROFIT and is per-pod in name only.

Verdict: extensible with a contained refactor (~2-3 sessions);
do it AFTER Tier 1/2 fixes — multi-pod multiplies every state bug.

### 12. Risk sizing for $500 target

Run 39 baseline: +$122 / 3 months, max DD 0.75% ($75), 0.01 lots.
Linear scale to $500 ⇒ **BaseLotSize = 0.04** (+$488, expected DD ~3%
total, ~$300). FTMO limits: daily 5% ($500), total 10% ($1000).

BUT the binding constraint is tail risk, not expectancy:
- The −$35.80 stranded-position event at 0.04 = **−$143**; with the
  add_next fix the same dislocation builds layers — 5 layers × 0.04 ×
  300 pips = **−$600+ → daily-DD breach.**
- Pre-conditions for any size-up: Tier 1 fixes + a pod abort rule
  whose worst case is computable: worst_loss ≈ MaxLayers_effective ×
  BaseLotSize × abort_distance. Solve for daily limit:
  e.g. 6 layers × 0.03 × 150 pips = $270 < $500 ✓.
- **Recommendation: 0.02 immediately after Patch 8 (validation
  period), 0.04 only after the abort rule exists and a 3-month
  3-symbol backtest shows max DD < 2.5%.** If all 3 symbols
  contribute post-§4 fixes, expectancy likely rises (more
  opportunities), so 0.03 may already hit $500 — re-baseline first.

### 13. Batch ADRs

Generated as `adrs/ADR-BATCH-20260611.md` (ADR-004 … ADR-014),
covering: physical ledger ground truth, Highlander rule, CloseBy
exits, linear thresholds, passivity sign convention (T direct),
value-based hysteresis, pending entry invalidation, cross-symbol
cancel sweep, carry spread sign, MaxLayers=20, No-delays canonical
test mode.

---

## CONSOLIDATED FINDINGS REGISTER

| # | Sev | Finding | File:Line | Status |
|---|-----|---------|-----------|--------|
| F1 | SEV-1 | −1.0 sentinel leaks into add_next differential; garbage orders placed on SELL side; layering dead | ExecutionEngine.mqh:199-221 | Patch 8 spec §1 |
| F2 | SEV-1 | EURGBP BUY inversion formula sign-wrong (mirror image); routing permanently dead | MathEngine.mqh:151-157 | needs Gemini re-ruling |
| F3 | SEV-1 | Bid-close treated as mid; EURUSD/GBPUSD SELL entries never passive; systematic half-spread bias | MathEngine.mqh:12-34, 197-205 | needs Gemini re-ruling |
| F4 | SEV-1 | Layer inheritance ignores deal_symbol → cross-symbol pod corruption (proven Apr 28) | ExecutionEngine.mqh:321-359 | fix spec §8 |
| F5 | SEV-1 | OnTradeTransaction ignores g_halted; halted EA keeps trading (proven Apr 28 17:32) | ExecutionEngine.mqh:614 | fix spec §8 |
| F6 | SEV-2 | No tail-risk abort; stranded pod rode −303 pips for 7 weeks (the −$35.80) | design | §2, §12 |
| F7 | SEV-2 | CancelAllPendingEntries early-return skips orphan sweep | FXMatrix.mq5:311 | fix spec §8 |
| F8 | SEV-2 | CloseBy queue halts EA after 10 sub-second retries; can't distinguish closed vs desynced position | FXMatrix.mq5:342-405 | fix spec §9 |
| F9 | SEV-2 | Carry OrderModify on unverified tickets → halt risk | CarryEngine.mqh:89-115 | fix spec §6 R1 |
| F10 | SEV-2 | CheckForOrphans scans only _Symbol; EURUSD/GBPUSD orphans invisible on restart | StateEngine.mqh:254-276 | extend to all pod symbols |
| F11 | SEV-3 | DEAL_ENTRY_OUT_BY deals dropped → LAYER_EXIT gross_pnl always 0.00 (known issue, mechanism now confirmed) | ExecutionEngine.mqh:617,660 | handle OUT_BY for P&L only |
| F12 | SEV-3 | Hysteresis override accepts sign-flipped spread via MathAbs | FXMatrix.mq5:171 | `< -BaseThreshold` |
| F13 | SEV-3 | MaxPodDrawdown reads account-wide ACCOUNT_PROFIT — per-pod in name only | FXMatrix.mq5:252-262 | note for multi-pod |
| F14 | SEV-4 | Radar code dead — remove | MathEngine.mqh:267-318, LayerStruct.mqh:67-75 | patch generated |
| F15 | SEV-4 | Run 46/47 log contains 13 passes from ≥3 different binaries (passes 1-7 pre-5a: "on EURGBP" suffix); cross-pass conclusions unsafe | process | one log file per run; log build hash in OnInit |

## RECOMMENDED SEQUENCE

1. Patch 8: sentinel fix (F1) + add_next guards — restores layering.
2. Patch 9: state hardening (F4, F5, F7, F8, F9, F10).
3. Gemini rulings: EURGBP BUY formula (F2), bid-frame anchors (F3).
   These change entry math — re-run the Run 39 baseline after.
4. Re-baseline 3-symbol backtest; only then risk sizing (§12) and
   multi-pod design (§11).
