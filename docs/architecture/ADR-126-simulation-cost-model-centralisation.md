# ADR-126: Centralise Simulation Cost Model and Correct P&L Accounting Bugs

## Status

Accepted — 2026-09-05. Implements Gemini Staff Architect rulings on Gates 2, 4, and 7,
plus ratified amendments 2, 3, and 5. Draft recorded alongside Step 2 implementation;
not committed until Khalid clears the two-step commit gate.

## Context

The Python grid simulation family (`grid_sim_v7_real_signal.py` and duplicate
implementations in analysis scripts) drives geometry selection, risk gating, and
EURGBP cross-pair validation. Step 1 (confirmation-only audit) established that
recorded geometry margins were computed under a flawed P&L function with three
independent accounting bugs and a drawdown-criterion mismatch against FTMO rules.

### Mental model (market maker)

This system posts resting limit orders on both sides and never crosses the spread.
A completed scalp banks the difference between our own two limit prices. Spread
affects **when** orders fill, not the price transacted. Broker commission is
3.00 USD per lot per side (0.03 USD per leg at 0.01 lots). There are no
stop-losses; risk is managed by size and account limits.

### Bug 1 — Phantom spread in P&L

Fill triggers correctly apply half-spread for crossing detection
(`grid_sim_v7_real_signal.py` entry ~218, exit ~245). Layers store the limit
fill price as `entry_price` (~226). P&L then charged spread **again** at
realised exit (~263–264) and at both unrealised marking sites (~147–149,
~323–325) by re-pricing entry at ask (long) or bid (short). This deducts a full
spread per scalp the market maker never pays.

The same pattern existed in:
- `scripts/run_layer_depth_analysis.py` (~190–192, ~201–202, ~235–236)
- `temp/eurgbp_v7_validation_analysis.py` (~73, ~87, ~144–145) — **this script
  is the EURGBP validation path most distorted by Bug 3; phantom spread compounded
  the error.**

### Bug 2 — Missing commission

No commission anywhere in the v7 engine or in `run_width_exit_sweep.py` prior to
this change. At 0.01 lots, each completed round trip should cost 0.06 USD.

### Bug 3 — Flat pip value

`USD_PER_PIP = 10.0 * LOT_SIZE = 0.10` (`grid_sim_v7_real_signal.py` ~28–30),
applied via `price_diff_to_usd` (~142). Correct only for USD-quoted pairs.
EURGBP profit accrues in GBP and was not converted via GBPUSD, undervaluing every
EURGBP pip by roughly 35%. `point = 0.0001` was hardcoded (~46, ~49, ~91, ~347),
wrong by 100× for JPY pairs.

### Ordering constraint

Commission is an absolute dollar amount; pip value is a scale on P&L. Adding
commission while EURGBP P&L is still ~35% low makes commission relatively ~35% too
expensive on that pair, biasing geometry toward wider spacing. **Bug 3 must be
fixed before or in the same change as Bug 2.** All three bugs are fixed in one
change.

### Drawdown-criterion mismatch

Prior implementation gated on 3%/4% **fractional daily loss** against a
hardcoded 10,000 balance. FTMO constraints for a 10k account are **absolute USD**:
Gate A — max daily equity drawdown 500 USD (5% of **initial** capital); Gate B —
peak-to-trough drawdown 1,000 USD (10% of initial). Daily boundary was
`pd.Timestamp(times[i+1]).normalize()` (~307), i.e. midnight in the timestamp's
own zone, not 00:00 Europe/Prague (CE(S)T). An offset boundary can split one
continuous drawdown across two days and hide a lethal breach.

`equity_peak` was tracked (~304) but never exported; peak-to-trough drawdown did
not exist in sweep output.

## Decision

1. **Create `scripts/sim_costs.py`** as the single owner of pair specifications
   (point, pip size, quote currency, contract size), spread constants (fill timing
   only, documented), commission helpers, pair-aware pip value, deterministic
   `pnl()`, Prague calendar-day helper, and `evaluate_risk_gates()` for dual
   FTMO gates.

2. **Fix `grid_sim_v7_real_signal.py` in one surgical change:**
   - Remove phantom spread from P&L; keep spread only in fill triggers.
   - Replace `USD_PER_PIP` / `price_diff_to_usd` with `sim_costs`.
   - De-hardcode `point` from pair spec.
   - Add per-leg commission on entry and exit; open layers carry sunk entry
     commission in unrealised marking.
   - Export `equity_peak`, `max_absolute_drawdown_usd`,
     `max_daily_equity_drawdown_usd`, `gate_a_daily_loss_breach`,
     `gate_b_total_loss_breach`; retain 3%/4% fractional flags as telemetry only.
   - Roll daily boundary at 00:00 Europe/Prague.

3. **Refactor duplicate implementations** to import `sim_costs`:
   - `scripts/run_layer_depth_analysis.py`
   - `scripts/run_spread_multiplier_sweep.py`
   - `temp/eurgbp_v7_validation_analysis.py`

4. **EURGBP conversion policy:** per-bar GBPUSD close series when available in
   `data/GBPUSD_{window}.csv` (aligned to EURGBP timestamps); otherwise explicit
   constant rate with policy recorded in output — never silent default to 1.0.

5. **Mandatory unit tests** `scripts/test_sim_costs.py` (T1–T8) as regression
   targets for pip value, commission, no-spread-in-P&L, JPY point size, Prague
   day boundary, and both risk gates.

## Consequences

- All prior sweep rankings, geometry margins, and EURGBP validation figures
  computed before this ADR are **not comparable** to post-fix results without
  re-running sweeps.
- Legacy engines `grid_sim_v4_fixed.py`, `grid_sim_v5_real_data.py`,
  `grid_sim_v6_dynamic_spacing.py` and diagnostic scripts (`trace_divergence_only.py`,
  `trace_both_seeds.py`, etc.) still contain local cost models — listed as
  deprecation candidates, not deleted.
- Fill-trigger logic, Brownian bridge, sub_steps, straddle/triangular/signal
  quote-level logic, spread constant **values**, and `ea/` MQL5 tree are unchanged.

## References

- Step 1 confirmation audit (incorporated in Cursor Step 2 spec, 2026-09-05)
- Gemini amendment 2 (dual FTMO absolute USD gates, Prague midnight)
- `scripts/sim_costs.py`, `scripts/test_sim_costs.py`
- `docs/architecture/ADR-091-grid-spacing-geometry.md` (geometry evidence base)
