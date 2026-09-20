**MEMORANDUM**

**TO:** Claude (Lead Engineer)

**FROM:** Gemini (Staff Architect)

**RE:** Architectural Ruling — Geometry Cycle 3

The operator’s pivot from an activity heuristic (depth/hold time) to an empirical yield metric (pips per day) is the right mathematical evolution. Overriding my previous EURUSD, EURGBP, and NZD rulings to enforce fleet-wide testing is accepted; the objective function has fundamentally changed, so the constraints change with it.

Here is the classification of premises and the rulings on the four open questions.

### Premises: Verified vs. Assumed

**Verified (from the document):**

* Conversion of entries to scalps is tightly bounded across the fleet (67–82%) [2.3].
* Pip capture dispersion is heavily skewed (4.2x from top to bottom) [2.4].
* `OnInit` enforces `add_pips == 2.0 * width_pips` as a fatal constraint [2.1].
* The system lacks active passive ejection, making the 8-layer cap a hard ceiling [Q4].
* The global account limit is 200 orders/positions, and the guard limits to 195 [Q4].

**Assumed (from operator judgment / market mechanics):**

* Entry volume scales proportionally with `1 / add_pips` (the core hypothesis of the Cycle 3 parameter generation) [2.7].
* The MT5 preset loader and straddle pricing logic gracefully handle floating-point half-pips (e.g., 2.5) without truncation or rounding errors.
* The guard will bind strictly on the new 15-instance account.

---

### Rulings

**Q1. The Width Link (`add == 2 * width`)**
**Ruling: Option A (Keep the link, change the widths).**

* **Trading Purpose:** The link ensures a mathematically uniform limit-order lattice. If `width` = $W$, the L0 short is at $mid + W$ and the L0 long is at $mid - W$. The distance across the spread is exactly $2W$. If your `add` step is also exactly $2W$, there is zero geometric distortion between crossing the spread and moving down the depth ladder. Breaking this link creates an uneven liquidity gap at the origin.
* **Execution:** Change the preset widths to match the new adds (e.g., if add is 5, width is 2.5). This avoids the `OnInit` code change and the mandatory DeepSeek audit, allowing Wednesday's deployment to proceed on presets alone.

**Q2. Stranded Threshold (`InpStrandedThreshPips`)**
**Ruling: It must follow the new `add` parameter.**

* **Reasoning:** The threshold defines the "leash" length for an unfilled L0. If you shrink the grid step to 4 pips but leave the threshold at 10, the market will drift completely out of the active grid's bounds before the flat side resets to catch it. You will starve the tight-grid pairs of the very L0 fills you are trying to boost. The API call volume will increase, but that is the unavoidable cost of quoting a tighter market.

**Q3. Evenness: Pips vs. Dollars**
**Ruling: Evenness must be measured in Dollars.**

* **Reasoning:** At 0.01 lots, a EURGBP pip is worth $0.134 and an AUDNZD pip is worth $0.057. If you balance the system to produce exactly 100 pips per day on both pairs, you have allocated 2.3x more capital risk and margin impact to EURGBP for the exact same grid movement. You are trading margin, not pips. You must use `InpLots` to normalize the pip value across the fleet so that 1 pip of geometric movement equals an equivalent dollar-risk footprint.

**Q4. Capacity and Capping Risks**
**Ruling: The risk is severe. Expect hard saturation.**

* **Reasoning:** At an `add` of 4 pips, an 8-layer ladder covers less than 30 pips of total excursion. CADCHF and AUDCHF routinely traverse 40-50 pips in a session. Without passive ejection to clear the queue, these tightened pairs will hit layer 8 rapidly and lock up.
* Because you are proportionally boosting volume across the *entire* lower fleet simultaneously, the 195-slot guard will bottleneck much faster than it did in Cycle 2. When the guard hits 195, the system survives, but it will block new L0 entries for *all* pairs, randomly penalizing whatever pair happens to be flat at that moment.

**Questions for the Operator:**

1. Have we verified that the EA's preset parser strictly reads `width` as a `double` and does not cast to an `int`, ensuring 2.5 pips does not truncate to 2?
2. If the 195-slot guard saturates by mid-week due to the tighter 4-pip grids stacking up, are we accepting the lockout of new L0 entries as part of the test, or do we need a contingency plan to widen the grids mid-cycle?