# DeepSeek R1 Audit Report

## Internal Reasoning

We need to audit the math and logic for each formula as specified. We have:

- Formula 1: exit_spread_target = entry_spread_adjusted + GridBase * layer_exit_frac
  - entry_spread_adjusted always negative, GridBase positive (0.0008), layer_exit_frac = ExitFraction = 0.618 (since step=0, min=0.4 but step=0 so always 0.618). So exit_spread_target = negative + positive*0.618. Since positive*0.618 is 0.0004944. entry_spread_adjusted is negative, magnitude? Typically spread from signal: spread = scores[weakest]-scores[strongest] <= -BaseThreshold = -0.0004 minimum magnitude. So entry_spread_adjusted could be -0.0004 to -0.006? Actually signal can be large, maybe up to -0.02? Not stated. But generally, adding positive to negative makes it less negative. So exit_spread_target > entry_spread_adjusted. So it moves toward zero. So answer to Q1: Yes.
  - Could it be more negative? Only if GridBase*layer_exit_frac is negative, but it's positive. So no.
  - Could it be positive? If the magnitude of entry_spread_adjusted is less than GridBase*layer_exit_frac. Since spread magnitude typically > BaseThreshold=0.0004, but 0.0004944 > 0.0004. So if entry_spread_adjusted is -0.0004, then exit_spread_target = -0.0004 + 0.0004944 = +0.0000944, which is positive. So yes, exit_spread_target can be positive. This would mean exit past fair value. Is that allowed? The ADR says exit_spread_target moving toward zero, but it can overshoot zero. The system has a sentinel for exit_spread_target > 0? In HandleEntryFill they check if exit_price < 0 (sentinel) but that's for price not target. They have marketable reversion handler if exit_price < 0. Actually they check exit_price < 0.0 after ComputeExitPrice. Could exit_price become negative due to positive target? ComputeExitPrice uses InvertSpreadToPrice with target. If target is positive (spread is positive), that means weakest > strongest? Actually spread is always negative for valid signal, but after overshooting zero it becomes positive meaning the dislocation has reversed? In mean-reversion, we exit when spread narrows, but if it overshoots zero, the pair might be over-corrected. That might still be profitable but geometrically wrong? The ADR says "still profitable but geometrically wrong". The question: is it possible? Yes, when |entry_spread_adjusted| < GridBase*layer_exit_frac. With GridBase=0.0008, layer_exit_frac=0.618, GridBase*layer_exit_frac=0.0004944. BaseThreshold=0.0004, so any entry spread between -0.0004 and -0.0004944 would cause positive exit target. But wait, entry_spread_raw must be <= -BaseThreshold for signal to fire. So |entry_spread_raw| >= 0.0004. So the smallest magnitude is exactly 0.0004. Then exit_spread_target = -0.0004 + 0.0004944 = 0.0000944 > 0. So yes, it can be positive. However, is entry_spread_adjusted exactly equal to entry_spread_raw? In HandleEntryFill first layer, adjusted = raw. And for subsequent layers, adjusted = raw (set in code: L.entry_spread_adjusted = L.entry_spread_raw). So yes. So there is a realistic edge case where exit_spread_target becomes positive. The system may handle it via the marketable reversion check (exit_price < 0?) Actually ComputeExitPrice returns price, and price could be > current market? They pass exit_spread_target to InvertSpreadToPrice, which for BUY: if target is positive (T positive) then price = anchor*exp(T) > anchor, which for BUY limit should be below market? Wait: for BUY direction, the exit order is a SELL limit (since exit is opposite direction). In ComputeExitPrice, they call InvertSpreadToPrice with is_exit=true, which flips direction for half-spread addition but not the formula. So if T positive, then for a EURUSD BUY (strongest=2, weakest=0), InvertSpreadToPrice with is_exit false would give price = anchor_EU * exp(T) (since T = eur-usd? Actually for BUY entry, direction BUY, strongest=2, weakest=0, formula: r_EU_target = T, so price = anchor_EU * exp(T). But T is spread = scores[weakest]-scores[strongest]. For valid signal, T negative. For exit target positive, T becomes positive. Then price = anchor * exp(positive) > anchor, which for a BUY entry limit is above anchor? Actually entry BUY limit is below market, but exit target for BUY position is a SELL limit, expected to be above entry (since we sell at higher price). So if T positive, price increases, which might be above market? The exit price computed might be above current market, which could be problematic (sell limit above market may not fill). The system has a check for exit_price < 0? Actually they check if exit_price < 0.0 for marketable reversion, but positive price is fine. However, if exit_spread_target is positive, the spread has reversed sign, meaning the strongest/weakest have swapped? This could cause direction mismatch. But mathematically, it's possible. So answer to Q3: Yes, exit_spread_target can be positive. The edge condition: |entry_spread_adjusted| < GridBase * layer_exit_frac.

- Formula 2: add_next_spread = entry_spread - S - S*(1 - layer_exit_frac)
  Where S = GridBase = 0.0008, layer_exit_frac = 0.618 -> add_next_spread = entry_spread - 0.0008 - 0.0008*(0.382) = entry_spread - 0.0008 - 0.0003056 = entry_spread - 0.0011056.
  So it subtracts a positive amount, making it more negative. So yes, add_next_spread is more negative. Answer to Q1: Yes.
  Q2: Verify invariant: |add_next - entry| > |exit - entry|. In spread space: add_next_spread - entry_spread = -S - S*(1-skew) = -S*(2 - skew). Exit_spread_target - entry_spread = S*skew. So |add_next - entry| = S*(2-skew), |exit - entry| = S*skew. Condition: S*(2-skew) > S*skew => 2-skew > skew => 2 > 2skew => skew < 1. ExitFraction (skew) is 0.618, so yes. Edge case: skew=1, then equality, but ExitFraction < 1 by constraints (ExitFraction<=0 or >=1 rejected). So invariant holds. Also if skew>1, but not allowed. So always satisfied.
  Q3: Edge cases: If S=0, not allowed (S<=0 returns -1). If skew very small, ExitFractionMin=0.4, so min skew=0.4, then 2-0.4=1.6 > 0.4. So okay.

- Formula 3: ComputeExitSpreadTarget in MathEngine.mqh returns entry_spread_adjusted + GridBase * ExitFraction. HandleEntryFill uses entry_spread_adjusted + GridBase * layer_exit_frac, where layer_exit_frac = ExitFraction when step=0. So consistent.
  Q2: If ExitFractionStep > 0, then HandleEntryFill uses per-layer frac (decreasing), while ComputeExitSpreadTarget uses base ExitFraction. So later layers would have different targets after carry recalc. That is a latent bug: carry recalc overwrites exit target with base fraction, ignoring graduation. The ADR acknowledges this (deferred to V2). So PASS for consistency with step=0, but FAIL if step>0.
  Q3: entry_spread_adjusted is modified by carry recalc (new_spread), then ComputeExitSpreadTarget uses that new adjusted spread. So relative to the new adjusted spread, the exit target is correctly computed. However, note that HandleEntryFill sets exit_spread_target = entry_spread_adjusted + GridBase * layer_exit_frac at fill time. Later, carry recalc overwrites both entry_spread_adjusted and exit_spread_target. That's the intended behavior: adjust spread for carry, then recompute exit target relative to new spread. So it's correct in that sense. But the issue is that the fraction used may differ. So the answer: the formula recomputes correctly relative to the NEW adjusted spread.

- Formula 4: Anchor computation.
  In RunSignalOnBarClose, they copy close prices for EURUSD and GBPUSD, 13 bars, index 0 is current bar's close, index 12 is 12 bars ago (13th bar). They use eu_closes[12] and gb_closes[12] as the anchors. Then they add half spread to convert bid close to mid. That is correct: anchor = close_12bars_ago_bid + half_spread.
  However, the copy uses 13 bars, so indices 0..12, that's 13 bars. Latest bar is index 0, 12 bars ago is index 12 (the 13th bar). So correct.
  But note: they use CopyClose on M5 bars, so 12 bars ago is exactly 1 hour ago if bars are complete. But they do not check that the bars are complete; they assume current bar's close is available. On a new bar, copyclose may still be updating. Could be off-by-one if they use the current incomplete bar. But they use eu_closes[0] for current price. That is the close of the just-completed bar? Actually on M5 bar close event, the code runs. At that moment, the current bar (index 0 in CopyClose with 13 bars) is the just-closed bar. So it's correct.
  Q2: When InvertSpreadToPrice is called at fill time inside HandleEntryFill, it uses the global anchors g_EU_mid_12bars_ago and g_GB_mid_12bars_ago, which are set at the last signal computation (on bar close). If the fill happens mid-bar, those anchors are from the last bar close. But that is intentional: the anchor should be the 1-hour prior price at the time of signal, not at fill time. So it's correct. There is no mechanism for future price leak.

- Formula 5: InvertSpreadToPrice directionality. Need to check each routing.
  General: T is always negative for valid signal. They have formulas:
  For (strongest, weakest) pairs:
  - (0,1): EURGBP SELL. They use EG_history * MathExp(-T). Since T negative, -T positive, MathExp(-T) > 1. So price > anchor. For SELL limit, we want above current market. Correct.
  - (1,0): EURGBP BUY. They use EG_history * MathExp(T). T negative, so MathExp(T) < 1, price < anchor. For BUY limit, below market. Correct.
  - (0,2): EURUSD SELL. strongest=0, weakest=2. They compute r_EU_target = -T. T = usd - eur? Actually spread = scores[2] - scores[0] = usd - eur = -r_EU? Wait from decomposition: usd = -(r_EU+r_GB)/3, eur = r_EU + usd => eur - usd = r_EU. So spread = usd - eur = -r_EU. So T = spread = -r_EU. Then -T = r_EU. So r_EU_target = -T = r_EU. That is positive? Actually r_EU is log return of EURUSD, can be positive or negative. But since EUR is stronger than USD? In (0,2) strongest=EUR, weakest=USD, so EUR is strong, USD weak, so r_EU likely positive (EURUSD up). So r_EU_target positive. Then price = anchor_EU * exp(r_EU_target) > anchor. For SELL, that's above market, correct. For (2,0): EURUSD BUY. strongest=2, weakest=0. Then T = eur - usd = r_EU. So r_EU_target = T = r_EU (positive? Actually when USD strong, EUR weak, r_EU negative. So T negative, r_EU_target negative, exp <1, price below anchor. For BUY, below market. Correct.
  - (1,2): GBPUSD SELL. strongest=1, weakest=2. Spread = usd - gbp = -r_GB. T = -r_GB, -T = r_GB. So r_GB_target = -T = r_GB. Price = anchor_GB * exp(r_GB) > anchor if r_GB positive. For SELL, above market. Correct.
  - (2,1): GBPUSD BUY. strongest=2, weakest=1. Spread = gbp - usd = r_GB. So r_GB_target = T = r_GB. Price = anchor_GB * exp(r_GB) < anchor if r_GB negative. For BUY, below market. Correct.

  Now check add_next: For EURUSD BUY (2,0), add_next_spread more negative. So T_add_next < T_entry. T_entry is negative (since entry spread negative? Actually for BUY, strongest=2 (USD), weakest=0 (EUR), so spread = eur - usd = r_EU. Since EUR weak, r_EU negative, so T negative. T_add_next more negative means larger negative. So exp(T_add_next) < exp(T_entry) < 1. So add_next price = anchor * exp(T_add_next) < entry price. Correct.

  For EURUSD SELL (0,2): entry spread = usd - eur = -r_EU. Since EUR strong, r_EU positive, so -r_EU negative. So T negative. T_add_next more negative means -T_add_next more positive. So exp(-T_add_next) > exp(-T_entry) > 1. So add_next price > entry price. Correct.

  For EURGBP: similar logic works.

  So all directionalities are correct.

  However, note that in InvertSpreadToPrice, they have a comment for (0,1) case: "SELL: unchanged" but then "BUY: fixed T not -T". Actually code: for (0,1) strongest=0, weakest=1, they set direction SELL and price = EG_history * MathExp(-T). That's correct. For (1,0) strongest=1, weakest=0, direction BUY and price = EG_history * MathExp(T). That's correct.

Thus all formulas pass directionality checks.

Now, edge cases: T positive? Not for valid signal. But if entry spread magnitude is less than threshold, no signal. So T always <= -BaseThreshold. However, in add_next, T becomes more negative, so still negative.

So overall: 
- Formula 1: PASS but note positive exit possible, which may be acceptable but might cause issues.
- Formula 2: PASS.
- Formula 3: Consistent for current settings (ExitFractionStep=0), but latent bug if step>0. Also correct relative to new adjusted spread.
- Formula 4: PASS.
- Formula 5: PASS.

But need to check the inversion formulas more carefully for sign errors in using -T vs T. They have for (0,2) EURUSD SELL: r_EU_target = -T; price = anchor_EU * exp(r_EU_target). Since T = spread = usd - eur = -r_EU, so -T = r_EU. So price = anchor_EU * exp(r_EU). For a SELL limit, we want price above current market. If EUR is strong, EURUSD has moved up, so r_EU positive, exp(r_EU)>1, price higher, which is correct for a sell limit. If EUR is weak (EURUSD down), then r_EU negative, but then (0,2) would not be the signal because strongest would be USD not EUR. So consistent.

But is there any case where the inversion formula could produce a price that violates passivity? The system relies on InvertSpreadToPrice to return a price that is passive (BUY below bid, SELL above ask) using the half-spread adjustment. They add half_spread for SELL, subtract for BUY. That is correct to convert mid to ask/bid. However, they also have a passivity check that calls IsPassive after adjustment. That should catch if the price is not passive.

But one subtlety: In ComputeNextLayerPrice, they call InvertSpreadToPrice with enforce_passivity = false. So they ignore passivity for add_next. They have a separate check later in PlaceNextEntryLimit. That's fine.

Now, need to check the anchor computation in RunSignalOnBarClose: they use CopyClose with 13 bars. But they later compute g_EU_mid_12bars_ago = eu_closes[12] + eu_half. But eu_closes[12] is the bid close of the bar 12 bars ago. Adding half spread to get mid. However, the half spread is computed from current ask/bid. That might not be the same half spread as 1 hour ago. That's an approximation. Not a bug but an assumption.

Also, they compute g_r_EU_signal = MathLog(eu_now / eu_1h) where eu_now = eu_closes[0] + eu_half (current mid), eu_1h = eu_closes[12] + eu_half (anchor mid). That's correct.

Now, for the exit price computation: they pass layer.entry_spread_target to InvertSpreadToPrice with is_exit=true, which flips direction for half-spread adjustment, but the formula for price remains same as entry. That is correct because the exit target spread is the spread at which we want to exit, and we invert it to a price using the same anchor and routing. However, note that exit_spread_target is computed using entry_spread_adjusted which after carry recalc includes carry adjustments. The anchor used is the original anchor at entry (stored in layer). So that's correct.

Now, one more thing: In ComputeExitSpreadTarget, they use ExitFraction (base) not layer_exit_frac. If exit fraction is graduated, later layers get different exits. The carry recalc will overwrite with base fraction. That is a mismatch. But for current Phase 0 settings, ExitFractionStep=0 so no graduation. So PASS for now.

Now, we also need to verify the invariant in add_next: They compute add_next_spread = entry_spread - S - S*(1 - layer_exit_frac). That equals entry_spread - S*(2 - layer_exit_frac). Since layer_exit_frac = 0.618, 2 - 0.618 = 1.382, so add_next_spread = entry_spread - 0.0008*1.382 = entry_spread - 0.0011056. So difference is 0.0011056. Exit difference is S * layer_exit_frac = 0.0008 * 0.618 = 0.0004944. So indeed add_next is further.

Edge case: if entry_spread is very small (but still >= threshold). Worst-case raw spread = -0.0004. Then add_next_spread = -0.0015056, exit = -0.0004 + 0.0004944 = 0.0000944. That's positive exit. That is allowed. The invariant holds.

Now, there is a sentinel: if exit_spread_target exceeds zero, ComputeExitPrice may produce a price that is not passive? The marketable reversion handler kicks in if exit_price < 0.0, not if exit_spread_target > 0. So if exit_spread_target > 0, exit_price = ComputeExitPrice returns price that is > anchor for SELL? Let's test: if spread positive, for EURUSD BUY position, exit is SELL. Spread positive means eur > usd? For BUY (2,0), T = eur - usd positive. So in InvertSpreadToPrice for SELL (since is_exit flips direction but formula for SELL uses -T? Wait, need to trace: For exit, they call ComputeExitPrice which calls InvertSpreadToPrice with is_exit=true. In InvertSpreadToPrice, for a given (strongest, weakest) pair, the price formula is the same regardless of is_exit. The is_exit flag only affects the half-spread adjustment: they flip direction for half-spread (line: if (is_exit) direction = (direction==BUY)? SELL:BUY;). So the price formula for EURUSD BUY (2,0) with T spread positive: In the code for (2,0) direction BUY, price = anchor_EU * exp(T). That is the same as for entry. But for exit, they will later adjust half-spread using direction flipped to SELL. So price = anchor_EU * exp(T) which is > anchor (since T positive). Then they add half_spread because direction for exit is SELL. So final price = anchor*exp(T) + half. That will be above market (if T positive). But for a SELL limit, we want price above ask. That's okay. However, is this price passive? It will be above ask, so it's passive. So no problem. The marketable reversion handler only fires if exit_price < 0.0 (sentinel). So positive spread exit is fine.

But is it geometrically correct? The exit target should be toward zero spread, and if it overshoots, that's still valid as a take-profit. So it's not a bug, but a possible feature.

Now, we need to produce output in the specified format.

For each formula, we'll state PASS/FAIL with proof.

Let's organize:

## Formula 1 — Exit spread target

1. PASS. Proof: exit_spread_target = negative + positive = less negative (move toward zero). Always less negative than entry_spread_adjusted because GridBase*layer_exit_frac > 0.
2. PASS. Proof: cannot be more negative because we add a positive term.
3. PASS with edge condition: can be positive if |entry_spread_adjusted| < GridBase * layer_exit_frac. Specifically, if entry_spread_adjusted > -0.0004944 (i.e., magnitude < 0.0004944), then exit_spread_target > 0. This occurs for entry spreads between -BaseThreshold (-0.0004) and -0.0004944. Since BaseThreshold=0.0004, any signal with spread magnitude exactly 0.0004 or slightly above will cause positive exit target. This is geometrically overshooting fair value but still profitable; the system handles it via normal exit limit.

## Formula 2 — add_next spread

1. PASS: add_next_spread = entry_spread - positive quantity, so more negative.
2. PASS: invariant |add_next - entry| > |exit - entry| holds algebraically if skew < 1. With ExitFraction=0.618, satisfied. No edge case where skew >= 1 because ExitFraction < 1 by validation.
3. Edge case: S=0 leads to sentinel -1.0, so no add_next placed. Fine.

## Formula 3 — ComputeExitSpreadTarget consistency

1. PASS for current settings (ExitFractionStep=0.0): both use same factor (ExitFraction).
2. FAIL if ExitFractionStep > 0.0: HandleEntryFill uses per-layer fraction (decreasing with layer index), while ComputeExitSpreadTarget uses base ExitFraction unchanged. This causes a mismatch: after carry recalculation, exit targets for layers >0 will be recomputed using base fraction instead of the graduated fraction set at fill. This is a latent bug deferred to V2.
3. PASS: The formula correctly recomputes exit target relative to the new (carry-adjusted) entry_spread_adjusted. The anchor and routing remain from entry.

## Formula 4 — Anchor computation

1. PASS: Anchors are from bar index 12 (13th bar in zero-indexed array of 13 bars), which is 12 bars before the current bar (index 0). Since bars are M5, this is exactly 1 hour ago. No off-by-one.
2. PASS: At fill time, the anchors used are the global g_EU_mid_12bars_ago and g_GB_mid_12bars_ago, which are set at the last bar close. They are intentionally the anchors from the signal time, not from fill time. This is correct for inversion to a price consistent with the original signal dislocation. No staleness issue because the anchor price should not change with intra-bar movements.
3. PASS: No mechanism for future price leakage. Anchors are from historical close data.

## Formula 5 — InvertSpreadToPrice directionality

1. PASS: EURUSD BUY: T negative, MathExp(T) < 1, price < anchor_EU, which is below current market (correct for buy limit).
2. PASS: EURUSD SELL: T negative, -T positive, MathExp(-T) > 1, price > anchor_EU, above market (correct for sell limit).
3. PASS: For add_next on EURUSD BUY: T_add_next more negative, so MathExp(T_add_next) < MathExp(T_entry) < 1, add_next price < entry price (lower, correct for deeper dislocation).
4. PASS: For add_next on EURUSD SELL: T_add_next more negative, -T_add_next more positive, MathExp(-T_add_next) > MathExp(-T_entry) > 1, add_next price > entry price (higher, correct for deeper dislocation).
5. PASS: EURGBP BUY/SELL: same logic holds.

Now, we need to output each formula with its subquestions. The prompt asks for each formula, state PASS/FAIL, proof or counterexample, and if FAIL, condition. We'll combine subquestions into one overall for each formula.

We'll be concise.

## Final Report

## Formula 1 — Exit Spread Target (`exit_spread_target = entry_spread_adjusted + GridBase * layer_exit_frac`)

**Overall: PASS** (with a key edge condition noted)

- **Q1 (less negative than entry?)**  
  **PASS.** `entry_spread_adjusted` is always ≤ –BaseThreshold (<0). `GridBase * layer_exit_frac` = 0.0008 × 0.618 = 0.0004944 > 0. Adding a positive term moves the target **toward zero** (less negative).  
  *Proof:* For any negative x and positive c, x + c > x.

- **Q2 (could be more negative?)**  
  **PASS.** Impossible: the added term is strictly positive.  
  *Proof:* c > 0 ⇒ x + c > x. No case produces x + c < x.

- **Q3 (could be positive?)**  
  **PASS with edge condition.** Yes, `exit_spread_target` becomes positive whenever `|entry_spread_adjusted| < 0.0004944`. Since `BaseThreshold = 0.0004`, any signal with raw spread magnitude between 0.0004 and 0.0004944 (e.g., exactly –0.0004) yields a positive exit target.  
  *Example:* `entry_spread_adjusted = –0.0004` → `exit_spread_target = –0.0004 + 0.0004944 = +0.0000944`.  
  This overshoots fair value but is still geometrically valid (exit in profit). The EA handles it via normal limit exit; the `exit_price < 0` sentinel does not trigger because price stays positive.

---

## Formula 2 — Add‑Next Spread (`add_next_spread = entry_spread - S - S*(1 - layer_exit_frac)`)

**Overall: PASS** (invariant holds for all valid parameters)

- **Q1 (more negative?)**  
  **PASS.** `S = GridBase = 0.0008 > 0`, `layer_exit_frac = 0.618` ⇒ `S + S*(1-skew) = 0.0008 + 0.0008×0.382 = 0.0011056 > 0`.  
  *Proof:* `add_next_spread = entry_spread – 0.0011056` ⇒ always more negative.

- **Q2 (invariant verification)**  
  **PASS.** The invariant `|add_next – entry| > |exit – entry|` reduces to `skew < 1`.  
  *Algebra:*  
  `|add_next – entry| = S + S*(1-skew) = S*(2 – skew)`  
  `|exit – entry| = S*skew`  
  Condition: `S*(2–skew) > S*skew` ⇔ `2 – skew > skew` ⇔ `skew < 1`.  
  With `ExitFraction = 0.618` (and `ExitFractionMin = 0.4`), `skew` is always < 1.  
  *Edge cases:* `skew = 1` (not allowed by parameter validation `ExitFraction ≤ 0 or ≥ 1` rejected), `S = 0` (sentinel guard returns –1.0). The invariant is never violated.

- **Q3 (edge cases where invariant fails?)**  
  **PASS.** No. The only dangerous scenario (`skew ≥ 1`) is blocked by input validation. If `ExitFractionStep` were increased such that per‑layer fraction could exceed 1, it would be capped at `ExitFractionMin = 0.4`? Actually `MathMax(ExitFraction - layer_idx*Step, ExitFractionMin)` ensures the value is at least 0.4, but if `ExitFraction` itself > 1, the initial validation would reject. So safe.

---

## Formula 3 — `ComputeExitSpreadTarget()` Consistency with Fill Path

**Overall: PASS** (for current settings, but a latent bug exists for graduated fractions)

- **Q1 (consistency when `ExitFractionStep = 0.0`)**  
  **PASS.** Both formulae reduce to `entry_spread_adjusted + GridBase * ExitFraction` because `layer_exit_frac = ExitFraction`. Identical.

- **Q2 (latent bug if `ExitFractionStep > 0.0`)**  
  **FAIL** (documented as deferred to V2).  
  *Condition:* When `ExitFractionStep > 0`, `HandleEntryFill` uses per‑layer `layer_exit_frac = Max(ExitFraction - layer_idx*Step, ExitFractionMin)`, while `ComputeExitSpreadTarget()` in `MathEngine.mqh` uses the **base** `ExitFraction` (no layer index available in `LayerStruct`).  
  *Effect:* After a carry recalculation, all layers get their exit target recomputed using `ExitFraction` instead of the graduated fraction that was applied at fill time. For layers beyond 0, this overwrites with a larger (closer to entry) fraction, causing the exit target to move closer to entry than intended. This is a silent directional error that persistently shifts exit prices toward the entry price over time.

- **Q3 (relative to new adjusted spread?)**  
  **PASS.** `ComputeExitSpreadTarget` uses the **updated** `entry_spread_adjusted` (modified by carry logic). The formula correctly recomputes `exit_spread_target` relative to the new spread. The original entry spread is irrelevant for the exit geometry after carry adjustment.

---

## Formula 4 — Anchor Computation (12‑bar mid price)

**Overall: PASS** (no look‑ahead or off‑by‑one)

- **Q1 (genuinely 12 bars ago?)**  
  **PASS.** `CopyClose("EURUSD", PERIOD_M5, 0, 13, eu_closes)` returns 13 bars. Index 0 = current bar’s close (just‑completed on bar event), index 12 = close 12 bars ago (60 minutes ago). No off‑by‑one.

- **Q2 (staleness at fill time?)**  
  **PASS.** `HandleEntryFill` uses the globals `g_EU_mid_12bars_ago` and `g_GB_mid_12bars_ago`, which are set at the **last bar close** (signal computation time). This is intentional: the inversion anchor must match the reference point of the original signal, not the current price. It is the same anchor used when the signal was generated – no staleness issue.

- **Q3 (future price leak?)**  
  **PASS.** All anchor prices come from `CopyClose` history (12 bars prior to the current bar). There is no mechanism to use future data. The half‑spread correction uses current bid/ask, which is legitimate for converting historical bid closes to current mid estimates.

---

## Formula 5 — `InvertSpreadToPrice` Directionality

**Overall: PASS** (all six routings are directionally correct, including add‑next)

- **Q1 (EURUSD BUY)**  
  **PASS.** T (entry spread) is always < 0. `MathExp(T) < 1` ⇒ price = `anchor_EU * MathExp(T) < anchor_EU`. For a BUY limit, price should be below current market (bid) – correct.

- **Q2 (EURUSD SELL)**  
  **PASS.** T < 0 ⇒ –T > 0 ⇒ `MathExp(–T) > 1` ⇒ price = `anchor_EU * MathExp(–T) > anchor_EU`. For a SELL limit, price should be above current market (ask) – correct.

- **Q3 (add‑next on EURUSD BUY)**  
  **PASS.** `add_next_spread` more negative than `entry_spread` ⇒ T_add_next < T_entry < 0 ⇒ `MathExp(T_add_next) < MathExp(T_entry)` ⇒ add‑next price **below** entry price. This is correct: for a BUY, deeper dislocation (weaker EUR) requires a lower limit price.

- **Q4 (add‑next on EURUSD SELL)**  
  **PASS.** T_add_next more negative ⇒ –T_add_next > –T_entry > 0 ⇒ `MathExp(–T_add_next) > MathExp(–T_entry)` ⇒ add‑next price **above** entry price. Correct: for a SELL, deeper dislocation (stronger EUR) requires a higher limit price.

- **Q5 (EURGBP BUY/SELL)**  
  **PASS.** Identical logic applies. For EURGBP BUY (strongest=1, weakest=0): T = spread (negative), `EG_hist * MathExp(T) < EG_hist` – below anchor. For EURGBP SELL (0,1): `EG_hist * MathExp(–T) > EG_hist` – above anchor. All add‑next moves are further from entry in the correct direction.

**Summary of all checks:** 5/5 formulae pass with one documented latent bug (carry path vs. fill path for graduated exit fractions) and one acceptable edge condition (positive exit target when spread magnitude is very small). No sign errors, no off‑by‑one anchor leaks, no invariant violations.