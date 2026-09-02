# ADR-097 Phase 2 Findings — Initial Multi-Window Backtest Results

**Status: Five of five canonical windows now tested with default thresholds (InpEaseDepthStart=2, InpEaseDepthFull=5, InpSpreadMultiplierEased=0.0, InpPassivityBuffer=0.5). The Q1 2024 Chop quote-lag question is resolved (Section 3). The double-deep tail-risk question is provisionally closed against the correct benchmark — FTMO's 5% daily loss limit, not generic solvency (Section 6) — with peak net exposure tracked as an ongoing hard gate, not a fully settled question. Remaining outstanding: out-of-sample threshold validation, floor-alone generalization check.**

**Date:** 2026-07-27/28.

---

## 1. Mechanism confirmed live, not just in unit tests

DIAG logging (`event=l0_ease`) was added and confirmed firing correctly across every window tested, with `effective_multiplier` values matching the exact ramp formula (e.g. `opposite_depth=3` → `effective_multiplier=0.333333`, matching `0.5 − (1/3)×0.5` precisely). This is genuine, live confirmation beyond the isolated unit tests — the mechanism engages exactly as designed under real historical price action.

## 2. Results across five windows (GBPUSD, SM=0.5, cap=0, all else default)

| Window | Baseline P&L | Eased P&L | Δ | Light side | Light-side fill count direction |
|---|---|---|---|---|---|
| Truss Crisis | $161.84 | $190.61 | **+$28.77** | SHORT | ↑ across the board |
| Q1 2024 Chop | $125.22 | $106.87 | **−$18.35** | SHORT | ↓ roughly halved |
| Vaccine Rally* | $257.71 | $254.45 | **−$3.26** | LONG heavy, SHORT light | ↑ across the board |
| Full Quarter | $119.93 | $116.29 | **−$3.64** | LONG light | ↓ modestly |

*Vaccine Rally: lower tick-confidence, likely synthetic-tick era. Included for directional signal, not weighted as heavily as the other three.

**Updated net read, now with all five windows complete: three of four real-tick-confidence windows cluster near-flat-to-slightly-negative, with Truss Crisis as the clear standout benefit.** This is a more tempered picture than the earlier 2-2 read — the aggregate lean is closer to "small net cost in most windows, real benefit concentrated specifically in the most extreme crisis window" than an even split.

## 6. Double-deep tail-risk investigation — two methodology corrections, then a direct, sufficient answer

Gemini's mandated Phase 2 safety check (does easing create new tail risk when both sides simultaneously carry real depth) was attempted three times today, with two real self-caught errors along the way — worth recording precisely, since the corrections matter as much as the final answer.

**Attempt 1 — realized-balance drawdown, CloseBy-exclusion bug.** Initial double-deep episode detection and drawdown reconstruction excluded all `"close X by Y"` deal rows from the running-balance calculation — the exact rows that carry the actual realized profit for a completed round-trip (confirmed earlier this week: one leg of each CloseBy pair shows the real profit, the other shows 0). This meant the reconstructed "balance" only reflected commission/swap drag, not real trading P&L, producing implausibly tiny drawdowns (0.01%–0.58%) across every window. Caught before being reported to Gemini as a finding.

**Attempt 2 — corrected balance calculation, but a deeper structural problem.** After including CloseBy rows, final balances matched the already-confirmed in-test P&L figures exactly (e.g. $10,161.84 = $10,000 + $161.84 Truss baseline) — confirming the balance-tracking fix was correct. But max drawdown came back at **0.00% across every single window, both baseline and eased.** This is not a real result either — it's a structural limitation of using realized-balance-only as an equity curve in a system where every layer holds until a fixed profit target (or forced window-end closure), never closing underwater. A position sitting deep in an adverse move contributes nothing to "realized balance" until it eventually resolves — so realized balance is structurally incapable of showing the actual risk being measured (unrealized, mark-to-market exposure while stacks are deep). A proper fix (mark-to-market equity reconstruction using OOS CSV price data plus per-ticket open-position floating P&L) was scoped with Cursor and confirmed feasible, but deliberately **deferred, not built today** — logged as a named follow-up for a more rigorous future Phase 2 sign-off, not abandoned.

**Attempt 3 — the actual sufficient answer, using data already in hand.** Reframed to the simpler, more directly decision-relevant question: does easing push the eased side's peak layer depth meaningfully toward the system's actual hard structural ceiling (`InpMaxLayers=20`)? Using `max_layers` already reported in every `V2_STATS` line pulled today:

| Window | Light (eased) side | Baseline max_layers | Eased max_layers | Δ |
|---|---|---|---|---|
| Truss Crisis | SHORT | 6 | 5 | −1 |
| Q1 2024 Chop | SHORT | 5 | 5 | 0 |
| Vaccine Rally | SHORT | 6 | 6 | 0 |
| Full Quarter | LONG | 5 | 6 | +1 |

**Across all four windows, the eased side's peak depth is essentially unchanged** — one window down a layer, one up a layer, two flat. The highest value observed anywhere, in any run, either configuration, is 8 — well under half of the 20-layer structural ceiling. **Reframed on Khalid's correction: net exposure, not layer count, is the right lens.** The layer-ceiling check (above) is a reasonable proxy but conflates gross depth with actual directional risk. The more precise, more relevant metric for a strategy run as a going concern (never voluntarily closing at a loss, recycling scalps as the core business) is **net exposure** — long lots minus short lots — since that's what actually drives margin usage and capital tied up, not gross layer count on either side individually. Tracked directly from existing HTML deal data (no new backtest, no CSV price reconstruction needed):

| Window | Max \|net lots\| baseline → eased | Max gross lots baseline → eased | Time-avg \|net\| baseline → eased |
|---|---|---|---|
| Truss Crisis | 0.04 → 0.04 | 0.10 → 0.09 | 0.0178 → 0.0169 |
| Q1 2024 Chop | 0.05 → 0.05 | 0.09 → 0.09 | 0.0167 → 0.0152 |
| Vaccine Rally | 0.06 → 0.07 | 0.11 → 0.11 | 0.0304 → 0.0240 |
| Full Quarter | 0.07 → 0.07 | 0.09 → 0.09 | 0.0195 → 0.0192 |

Peak net exposure barely moves anywhere (at most +0.01 lots), and time-averaged net exposure is flat or **lower** under easing in three of four windows — consistent with the mechanism's premise (letting the light side engage sooner pulls net position back toward neutral faster, not left to drift).

**Correction, made explicitly rather than left standing: the initial framing targeted the wrong constraint.** A genuine flash crash is an accepted, un-engineerable cost of running a market-making book — no design change makes it meaningfully survivable, and it isn't the risk worth checking against. **The actual, immediate operational constraint is FTMO's 5% daily loss limit** — verified directly: calculated on equity (including floating P&L) against the higher of balance or equity at day-start, and on this project's $10,000 test account size, a hard **$500/day**. Breach it once, the account terminates, independent of trading edge.

Redone against the correct constraint, the risk profile bifurcates clearly:

- **Observed worst-case net exposure (0.07 lots, $0.70/pip):** breaching $500 requires a **~714-pip single-day move** — nothing short of a genuine flash-crash event reaches this. Safe at this tier.
- **Theoretical worst-case net exposure (0.20 lots, one side fully maxed at `InpMaxLayers=20`, $2.00/pip, never actually observed in any test):** breaching $500 requires only **~250 pips** — and this is *not* a rare tail event. It sits within the range of ordinary volatile sessions already documented (a 366-pip day cited for 2022; 200-pip single-session moves described as routine during 2016-2018 news-heavy stretches). At this theoretical exposure ceiling, an entirely ordinary volatile day — not a black swan — would breach the FTMO limit.

**Revised status: the tail-risk gate is provisionally closed, not definitively closed.** Real, strong evidence across four independent windows shows easing does not push net exposure meaningfully toward the 0.20-lot theoretical ceiling (max observed increase: +0.01 lots) — genuinely good. But four windows, however carefully chosen, do not prove the gap between the observed ceiling (0.07) and the theoretical one (0.20) never closes under an untested condition. **Going forward, the FTMO 5% daily limit is the sole benchmark for tail-risk evaluation, and peak net exposure will be tracked continuously through the remaining Phase 2 work (out-of-sample threshold validation, floor-alone check) as a hard gate** — if any threshold recalibration pushes peak net exposure meaningfully toward the 0.20-lot ceiling, that is treated as an immediate architectural failure, not a tradeable cost.

## 3. The Q1 2024 Chop loss — mechanistically investigated, refined through direct verification

A genuine anomaly was flagged and chased down rather than accepted at face value: SHORT's fill count dropped ~50% under easing, the opposite direction from what "easing = friendlier entry" naively predicts. Multiple hypotheses were tested in sequence, with each refined or discarded based on direct evidence rather than plausible reasoning alone:

**Floor binding wider than baseline — ruled out.** Of 187 logged `l0_ease` instances, the floor never bound — 0 of 187. An initial investigation reported a mathematically impossible sigma-path figure (0.9 pips, below the 4-pip `quote_spread` floor that term can never go under); root-caused to a units error (division by 100,000 instead of 10,000) and corrected before the conclusion was trusted.

**Deadband-damping mechanism — confirmed real and substantial, but NOT depth-dependent between the two depths that account for most easing in this window.** Direct DIAG logging (`event=l0_lag`, added specifically for this investigation) was added to capture resting-order-vs-theoretical-price gap and deadband-skip outcome on every eased bar. Initial hand-picked Journal segments suggested skip/staleness might concentrate at intermediate ramp depths — this hypothesis was **directly tested against the full distribution and refuted**:

| Depth | n (matched events) | Skip rate | Mean gap, skip=true | Mean gap, skip=false |
|---|---|---|---|---|
| 3 | 2,205 | 34.8% | 0.45 pips | 2.83 pips |
| 4 | 1,049 | 36.0% | 0.45 pips | 3.01 pips |
| 5 | 17 | 17.6% | 0.37 pips | 3.39 pips |

Depths 3 and 4 (the overwhelming majority of eased conditions in this window) are statistically indistinguishable. Depth 5 looks different but has far too few observations (n=17) in this window to draw any conclusion from. **Corrected understanding: being eased at all produces a consistent ~35% deadband-skip rate and consistent gap distribution in this window — there is no evidence of a "mid-ramp is worst" effect.** The original hand-picked-segment hypothesis was a reasonable read of limited data that did not survive full-distribution scrutiny.

**Methodological note, worth remembering for future log-based investigations:** the first full-distribution attempt showed only a 30.3% match rate between `l0_ease` and `l0_lag` events, which looked like a real logging bug. Root cause: the shared MT5 tester log file (`20260728.log`) contained six separate backtest run headers from the day's full session, and the `l0_lag` DIAG line had only been added to the codebase partway through — meaning earlier runs in the same file (Vaccine Rally, an earlier Q1 2024 Chop attempt) never had it at all. Isolating strictly to the lines between the correct run's header and the next header resolved this to a 100% match. **Any future full-log-distribution analysis on a shared tester log file must isolate to the specific run's header boundaries first** — this is now a standing practice, not a one-off fix.

## 4. What this does and doesn't establish so far

**Does establish:** the mechanism works correctly at the code level (verified via unit test and live DIAG confirmation); it produces real, non-trivial behavioral and P&L effects; the effects are regime-dependent in a way that lines up with an identifiable, derivable mechanism rather than appearing as unexplained noise.

**Does not yet establish:** that the net effect across a full, representative sample of market conditions is positive; whether the discovery-sample thresholds (2/5) are well-calibrated or coincidentally convenient; whether the mechanism introduces any double-deep tail risk beyond what's already measured; whether the quote-lag hypothesis for Q1 2024 Chop actually holds up under direct verification.

## 7. Outstanding Phase 2 items (per original proposal, Section 6)

1. ~~Full Quarter backtest~~ — **done.** See Section 2.
2. ~~Direct verification of the quote-lag hypothesis~~ — **resolved.** See Section 3.
3. Out-of-sample threshold validation, per pair — still outstanding.
4. ~~Explicit double-deep tail-risk measurement~~ — **provisionally closed** against the correct benchmark (FTMO's 5% daily loss limit, $500 on this account size, not generic solvency). Observed net exposure is safe; the theoretical 0.20-lot ceiling is not, if ever reached alongside ordinary (not extreme) volatility. Peak net exposure now tracked as a continuous hard gate through remaining Phase 2 work, not treated as fully settled.
5. Isolated floor-alone impact simulation — largely addressed incidentally (0/187 binding in Q1 2024 Chop) — worth confirming this holds in other windows, particularly ones with more extreme sigma readings, before treating it as general.
