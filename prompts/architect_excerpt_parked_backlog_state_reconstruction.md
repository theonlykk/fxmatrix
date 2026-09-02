## Parked Backlog

Items intentionally deferred after real investigation, not simply
undone or forgotten. Each entry states why it's parked and what would
need to be true to reopen it.

### State Reconstruction Engine

Would replace the current halt-on-orphan behavior with genuine state
rebuild from live broker data on restart, removing the need for the
flat-chart precondition. Rejected in its narrow form (Gemini's ruling,
2026-08-02) because proving the "safe" narrow envelope requires nearly
the same deal-history-replay complexity as the full engine — no real
shortcut exists. Parked indefinitely. The flat-chart rule (see
Operational Safety Rules) remains the operative safeguard. Reopen only
if willing to commit to full deal-history replay as its own dedicated
initiative.

### EURGBP Native Sigma Migration + Easing Recalibration

Would replace EURGBP's `MathMax(sig_ac, sig_bc)` half-spread sigma with
a native, EURGBP-return-based sigma, and recalibrate ADR-099's easing
thresholds under it. Parked (Gemini's ruling, 2026-08-02) due to: a
dimensional/unit mismatch in the native sigma implementation
(log-return sigma fed directly into a price-unit formula slot, ~19%
scale distortion for EURGBP); floor-dominance nonlinearity that can
make the easing ramp inert in more states than under the old sigma;
and an already-thin original calibration margin that a full
recalibration sweep isn't worth committing to before the above is
resolved.

**Reopen sequence, if ever revisited (Gate 0 per Gemini's ruling):**

1. Fix the unit conversion (native sigma must be price-consistent, not
   raw log-return dispersion).
2. Run a single minimal sanity check against `june_blowup` and
   `full_quarter` only, to check whether floor dominance consumes the
   native signal before committing further.
3. If the floor renders easing inert, stop — do not run the full
   recalibration sweep.

The underlying economic rationale (EURUSD/GBPUSD's shared USD-leg
correlation means `MathMax` overstates true EURGBP cross volatility)
was independently confirmed sound by DeepSeek; only the implementation
and verification are unresolved.

### EURGBP AddPipsFloor=2.3 (Derived Grid Geometry)

Would replace EURGBP's inherited GBPUSD `AddPipsFloor=9.0` with a
pair-derived `AddPipsFloor=2.3`, based on a DeepSeek-audited Monte
Carlo finding (n=500, zero-slippage Strategy Tester conditions)
showing +46.1% uplift. Parked after failing its own required real-tick
stress test (Gemini's Prerequisite 2) — a materially tighter grid is
mechanically far more exposed to slippage as a fraction of its own
target than the wider production geometry, and the original +46.1%
finding ran under zero-slippage, zero-latency assumptions.

**Stress test result (real MT5 Strategy Tester, Model=4, five
canonical windows, production `AddPipsFloor=9.0` vs. derived `2.3`,
exit count and direction of change):**

- truss_crisis: 436 -> 604 exits (+31%)
- q1_2024_chop: 160 -> 257 exits (+54%)
- vaccine_rally: 434 -> 380 exits (-19%)
- full_quarter: 98 -> 180 exits (+76%)
- june_blowup: 0/0 exits both geometries (inactive window)

Aggregate: +16.0% total P&L under real ticks (down sharply from the
original +46.1% zero-slippage estimate); per-scalp edge came out
worse for the derived geometry ($0.330 vs $0.359); max layer depth
increased substantially (4-5 -> 7-9) in every active window;
vaccine_rally was outright negative. DeepSeek's critique of the
stress test agreed with parking it.

**Status:** clean negative result under real execution conditions, not
a data gap or an implementation gap. No reopen condition is currently
established, unlike the other two entries in this section — revisit
only if a materially different geometry candidate or a genuine
slippage-mitigation mechanism changes the underlying tradeoff.

### CloseBy-History Layer State Replay

Parked as an explicit scope boundary of the State Reconstruction
Engine (Gemini's ruling, 2026-08-04, Option B): the engine reconstructs
layer state with confidence only on CloseBy-free history since the
anchor. The moment any CloseBy-related deal (an exit-magic position
open, or a `DEAL_ENTRY_OUT_BY`) is found in that window, the engine
halts via the existing, already-safe orphan-guard behavior rather than
attempting to reconstruct through it — it does not guess.

Scope Boundary: CloseBy-History Layer State Replay is parked. The
State Reconstruction Engine operates strictly on CloseBy-free history
windows.

Reopen Condition: Reopen full CloseBy-History Replay only if
post-deployment telemetry proves that mid-session restarts on
post-CloseBy stacks occur frequently enough to justify the engineering
complexity of historical deal-pairing.

Rationale (Gemini's ruling): building a full historical CloseBy
deal-pairing engine was assessed as a structural failure-surface risk
disproportionate to its value — MT5 hedging-mode exit fills open a new
hedge position whose own opening deal carries no reference back to the
original layer, so the mapping can only be recovered via correct
CloseBy pairing across deal history, which introduces significant edge
cases (missing/unpopulated position IDs, near-simultaneous CloseBys,
a hedge leg closed by something other than CloseBy). Option B still
eliminates the flat-chart deployment precondition for the majority of
real restarts — any stack that hasn't had a position cycle through a
CloseBy exit since it was last flat.

**Superseded 2026-08-04:** reopened via direct architectural ruling,
not the telemetry-based reopen condition specified above — that
condition never triggered. Round 3 of the Phase 1 audit sequence
found Option B's actual coverage excluded any side with even a single
exit since it was last fully flat, since every managed exit in this
system opens a hedge position, which is exactly the deal type Option
B's halt condition triggers on. Given this system's design intent is
frequent small scalp exits, that meant Option B eliminated the
flat-chart precondition only for a side that had never closed a
single layer since last flat — a narrow, likely uncommon case, not
"most restarts" as originally framed when this was approved. Gemini
ruled to abandon Option B and pursue full CloseBy-history mapping
(Option A) instead, empirically verified feasible via this account's
real deal history (129 CloseBy events, zero exceptions to the
DEAL_ORDER pairing assumption the mapping strategy depends on). See
the State Reconstruction Engine design (v5 and later) for current
status — this entry is retained as the record of Option B's
evaluation and rejection, not as an accurate description of current
scope.
