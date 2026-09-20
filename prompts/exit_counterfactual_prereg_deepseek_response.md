# DeepSeek R1 Audit Report

## Internal Reasoning

The user has provided a pre-registration document for an FX trading counterfactual study and a derivation memo, but the "CODE TO AUDIT" section is empty. Let me re-read the prompt.

The message says:
- "This message has a line count at the bottom"
- Shows EXIT_PIPS COUNTERFACTUAL -- PRE-REGISTRATION (184 lines)
- Shows DOCUMENTATION: GEOMETRY-CYCLE2-DERIVATION.MD (343 lines)
- Then "## CODE TO AUDIT" with nothing after it.

So there's no code provided. The user is a "quantitative auditor hunting for lookahead bias, silent failures, schema mismatches, and statistical flaws in FX algorithmic trading infrastructure." They have access to "the full codebase and documentation."

But the actual code is empty. So I need to work with what's provided — the pre-registration and the derivation memo — and audit those documents for the issues stated.

Actually, the task says "You have access to the full codebase and documentation." And it says "## CODE TO AUDIT" as a header. Since no code follows, maybe the intent is for me to audit the methodology described in these documents.

Wait — this looks like it could be a test where the actual content is the documentation, and I need to audit the methodology/pre-registration for lookahead bias, silent failures, schema mismatches, and statistical flaws.

Let me think about this carefully. The prompt is asking me to be an auditor and find issues. The "CODE TO AUDIT" is empty, so I should audit what's given: the pre-registration doc (s4-s10 especially) and the derivation memo.

Let me carefully read the pre-registration and identify issues.

Key sections:
- s4: The fill rule
- s5: Manual closes
- s6: Layers still open
- s7: Costs
- s8: Objective and output
- s9: Parity
- s10: Selection and holdout
- s12: Known biases

Let me hunt for issues:

### s4 Fill rule

"**Primary:** the first eligible minute is the one AFTER the entry minute. **Sensitivity S1:** include the entry minute."

Issue: The entry minute — if entry happened mid-minute, the bar after the entry minute is the correct choice (the entry minute bar includes data both before and after entry, so including it could allow lookahead/fills that couldn't have happened). Actually, the primary (exclude entry minute) is conservative and correct for avoiding lookahead. But wait — if entry happens at say 10:30:30, the M1 bar 10:30 covers 10:30:00-10:30:59. The bar at 10:31 covers the minute after. If the exit filled in the same minute as entry (10:30:45), the primary rule would miss it. That's a conservative bias, not lookahead. Actually the primary is fine — it's conservative.

But there's a subtle issue: "Fill time for hold-time purposes = the start of the fill minute." So a fill at 10:31:59 counts as 10:31:00. That slightly understates hold time for the subsequent hold. Fine.

Long fills when bid_high >= target. Short fills when ask_low <= target. This is correct for resting limit orders: a sell limit (long exit) is filled by the bid; a buy limit (short exit) is filled by the ask. Good.

But: "Fill price = the target. No penetration, no slippage." This is optimistic but stated. The memo says "exit_penetration_pips_mean 0.0" corroborates.

Wait — there's a subtle issue with the M1 bar. Within a minute, bid_high and bid_low. But the fill rule only uses bid_high for longs (top of bid range). If bid_high >= target, the order fills. That's right. But what if the bar's high was formed at a time when the ask was somewhere different? No — for a sell limit, the relevant price is the bid. If bid >= target at any point, the sell limit would be filled by a market maker's bid. Hmm, actually a sell limit order rests in the book; it's filled when someone's buy order (bid) crosses it. The bid_high is the highest bid. So bid_high >= target means the bid reached the target, so the sell limit fills. Correct.

Actually there's a real subtlety: the M1 bar is aggregated. If bid_high >= target the sell limit at target fills. Yes.

### s5 Manual closes

Rule A: if manually closed at T and the counterfactual doesn't fill before T, close at T at actual manual price.

Issue: The manual close is an operator action. In the counterfactual where the exit is different, the operator might not have manually closed. But the pre-registration says "Operator actions are held fixed, like entries." This is a stated modeling choice, consistent with the "entries fixed" bias. Fine, and it's disclosed.

But wait — there's a subtle inconsistency: if the counterfactual exit is TIGHTER (X smaller than actual), the layer might fill BEFORE the manual close time. Then it fills at the target. Good. If WIDER, it doesn't fill, then closes at T at manual price. But the "manual price" — is it the actual close price of the actual layer? That's the actual exit price. OK.

But here's a schema mismatch: rule A uses the "actual manual price". For layers that were originally scalps (not manuals), rule A presumably lets them run to the window end if they don't fill. But what about layers originally MANUAL? They get closed at their manual time/price if no fill. OK.

Hmm, but the rule says "if the layer was closed manually at time T". Only 76 manual layers. The other 612 scalps and 105 open layers... The open ones run to window end (s6). The scalps: they're not manual, so they just run to exit or window end. OK.

Actually wait, there's a deeper issue. The 612 scalps closed via CloseBy against an EXT position. So the scalp exit wasn't a limit exit — it was a CloseBy. In the counterfactual, we replay the exit. But the parity check compares to "observed as scalp". OK.

### s6 Open at window end

MTM at bar close. Long at bid_close, short at ask_close. Correct direction (selling a long gets the bid, buying back a short pays the ask). Good.

### s7 Costs

Commission: 0.03 USD per 0.01 lot per entry/exit fill/manual close. CloseBy free. So scalp = 0.06, manual = 0.06, open = 0.03. Consistent.

"To pips: USD per pip per pair = median of profit/pips over that pair's observed scalps." 

Issue: using median of profit/pips. profit/pips gives USD per pip. For a 0.01 lot, USD per pip depends on the quote currency and the pair. E.g., GBPUSD: 1 pip = 0.0001, 0.01 lot = 1000 units, so 1 pip = 0.10 USD. But profit is in USD. Actually the base pip value varies. The median over scalps is an empirical estimate. Fine, though it introduces estimation noise. Stated.

### s8 Objective

"realised pips, MTM pips, gross pips (their sum), commission pips, net pips"

"gross pips = realised + MTM". net = gross - commission. Good.

"net pips per trading day = sum of layer hold time, entry to fill, manual close, or window end)."

Wait, the text is garbled: "slot-days (sum of layer hold time, entry to fill, manual close, or window end)". Slot-days = sum of hold times. OK.

### s9 Parity

At actual live exit_pips, compare replay with observed. Classification: of observed scalps, share replay also fills >= 95%. Of observed open, share replay also leaves open >= 95%. 

Issue: The parity check uses the actual exit values, but the actual exits were subject to "clamped and carry-shifted exits" and the "held exits" from ADR-151 (s12). So a perfect parity may be impossible. The pre-registration acknowledges this.

But here's a real concern: the parity threshold for "open" is on layers observed open. But if the replay at the actual exit value uses a DIFFERENT fill rule (resting exit that could fill while the live one was held), the replay might fill layers that live stayed open. The 95% threshold would catch this.

Also: fill count within max(5%, 2 scalps). Median hold within max(10%, 15 min).

Hmm, the median hold parity — observed median hold is computed how? From the deals, paired via CloseBy. The replay's hold = entry to fill. These should match if fills match. OK.

### s10 Selection and holdout

Split by entry date, alternate days: calibration 10,14,16,18 Sep (505 layers); holdout 11,15,17 Sep (288 layers).

Wait — "seven trading days" and dates: 10,11,14,15,16,17,18. That's 7 days. But 12,13 Sep are Sat/Sun? 2026-09-10 is a Thursday... let me check. Sept 2026: Sept 1 is Tuesday. So Sept 10 = Thursday, 11 = Friday, 12 = Sat, 13 = Sun, 14 = Mon, 15 = Tue, 16 = Wed, 17 = Thu, 18 = Fri. Yes, 7 trading days.

Calibration: 10 (Thu), 14 (Mon), 16 (Wed), 18 (Fri) = 4 days. Holdout: 11 (Fri), 15 (Tue), 17 (Thu) = 3 days. 505 + 288 = 793 layers. Good, matches.

Selection rule: "among X whose pooled net pips per day is at least 90% of that pair's maximum, choose the MIDDLE value (round down)."

Issue: The "middle value (round down)" — middle of what? The range of acceptable X values. If X in {3,...,15} and acceptable values are e.g. {7,8,9,10}, the middle would be between 8 and 9 → round down → 8. That's a stated heuristic. But "middle" of a set — median. OK. It's a robustification against picking the peak.

But a concern: this is applied per pair, and there could be multiple disjoint acceptable regions (e.g., X=4 and X=11 both acceptable due to noise). Then "middle" is ambiguous. The rule doesn't address disjoint regions. Minor.

Holdout: accept X* if holdout net pips per day at X* is at least 90% of the better of the pair's two current live values on the holdout.

Issue: "the pair's two current live values" = OPT X and ALT X (the actual live exit_pips). The comparison is at those specific X on the holdout. OK. But there's a subtlety: "if the selected X differs between the two [gross and net], that difference is reported" (s7). But s10 says "The same rule is applied to GROSS pips and both selections are reported." So two selections (gross and net), but holdout acceptance — which selection does it use? Ambiguous. Probably net for the primary, gross reported. Minor.

### Now the big statistical issues:

1. **Multiple comparisons / selection on calibration then test on holdout with only 3 days.** The holdout is only 288 layers across 8 pairs. Per pair ~36 layers. Very thin. The acceptance threshold "90% of the better of the two current live values" — if both current values are bad on holdout, easy to beat. Hmm.

2. **Lookahead in the fill rule?** The primary excludes the entry minute, so no lookahead. But the MTM at window end uses the last bar. Fine.

3. **Survivorship / selection of the window:** "seven trading days, one regime, guard saturated throughout." Stated.

4. **The counterfactual ignores the coupling between exit and the rest of the strategy** — stated in s12.

5. **Commission conversion via median profit/pips** — noisy but stated.

6. **A real statistical flaw:** The selection is done on calibration (4 days) and tested on holdout (3 days). But the "middle of the acceptable region" rule applied per pair per X separately — with 8 pairs and 13 values each, that's a lot of selection. And the holdout is tiny.

7. **Swap sensitivity S3:** "inferred from the swap booked on closed layers divided by rollovers crossed." But swap for open layers is unknown; extrapolated. Also swap is charged on Wednesdays triple. The window includes a Wednesday (16 Sep)? Yes. So swap inference must account for triple-swap day. If they just divide total swap by rollovers, the average includes the tripled Wednesday. Applied uniformly, it might be OK as an average, but the counterfactual holds differ. Stated as sensitivity.

8. **"Pips" for cross pairs:** pips in the quote currency; the profit/pips conversion handles it. OK.

### Now, the actual question at the end: s13 questions for review. The doc asks:
1. Is any rule in s4-s10 biased toward wider or narrower exits not listed in s12?
2. Is the 95% parity threshold strict enough?
3. Is the selection rule robust to seven days, or should pairs be pooled?
4. Is MTM at window end the right treatment for open layers?

And says: "Answer each with the smallest fix. Do not call the method fatal for a fixable issue."

So the user wants me to audit and answer these questions, plus find lookahead bias, silent failures, schema mismatches, statistical flaws.

Let me think hard about each.

#### Bias toward wider or narrower exits not listed:

- **Primary excludes the entry minute.** For a layer entered mid-minute, if the exit would have filled in that same minute (a small X, tight exit), the primary rule misses it. This biases against SMALL X (tight exits) — it makes tight exits look worse. This is a bias toward wider exits, not listed in s12! Actually wait — is it significant? For small X, the exit is close to entry, so it may fill quickly, possibly in the entry minute. Excluding the entry minute delays the fill detection by up to 1 minute, but more importantly, if the price touched the target in the entry minute and then moved away, the primary rule would mark it as not-filled-in-that-minute and wait for a later touch. So the fill count for small X is understated. Bias against small X. S1 (include entry minute) is the sensitivity. But S1 includes the entry minute which could allow the exit to fill at a time BEFORE the entry (if the bar's high occurred before entry). That's a lookahead/fill-before-entry issue! The entry minute bar covers the whole minute; the entry occurred at some second within it; the bar's bid_high might have occurred before the entry time. So S1 can produce a fill that happened before entry — impossible. So S1 is biased toward small X (more fills) and has a lookahead-ish flaw. The primary is the safe one. But primary's bias against tight exits is real and should be listed. Actually the doc frames S1 as a sensitivity, so they know the entry minute matters. But the DIRECTION of the bias (against tight exits) isn't stated in s12. Hmm, they should note: primary understates tight-exit fills.

Actually, let me reconsider. The exit for a long is entry+X. If X is small (say 3), the target is close. In the entry minute, the price may already be above target (if the entry was on a down-move and bounced). Actually the entry is a limit fill too. Hmm. The bias is real but small for tight X.

- **Manual close rule A:** holds operator action fixed. If the counterfactual exit is WIDER, layers that would have been manually closed now close at T anyway (at manual price). So wider exits don't benefit from running past T. This biases AGAINST wider exits? Actually it caps the upside of wider exits (can't run past the manual close). So bias toward narrower? Hmm. But manual layers are only 76. And S2 tests ignoring manuals. Stated.

Wait, actually think: rule A closes at T at the actual manual price if not filled. The manual price is presumably where the operator closed (maybe at a loss or breakeven). For a wider exit X, the layer doesn't fill and closes at manual price. So wider X gets the manual price, same as actual. For a narrower X, the layer might fill before T at the target (better or worse than manual price depending). Hmm, complex. The point: rule A doesn't let wider exits benefit. Bias against wider exits? Not clearly listed. Hmm, but S2 covers it.

- **Fill at target, no penetration:** stated. This is optimistic for ALL exits. The memo says penetration mean 0.0. But actually, if there's no penetration, fills at target is fine. OK.

- **The "held exits" bias (s12):** from 17-Sep 05:16 only the nearest exit rested; deeper exits couldn't fill. The replay assumes all rest. This biases toward wider exits? Because the replay lets wider exits fill when live they couldn't. Stated in s12, S4 handles.

- **MTM at window end uses bar close.** For a long at bid_close, short at ask_close. But if the window ended with the book underwater, MTM is negative. Included. The doc asks if this is right.

- **Cost bias:** commission is per fill (entry + exit). In the counterfactual, every layer pays entry commission (already paid) + exit commission. For open layers, only entry commission. So a wider exit that causes a layer to stay open pays less commission but holds MTM. A narrower exit fills and pays exit commission. This is handled by NET. But note: the entry commission is already sunk in reality; including it in the counterfactual is fine as long as it's constant across X (it is). OK.

Hmm wait — there's a subtle commission issue. The doc says "Every entry, exit fill and manual close is charged 0.03 USD per 0.01 lot." In the counterfactual, layers that fill pay exit commission; layers that stay open don't. So commission varies with X — correct. Good.

- **Another bias:** The parity check itself. If parity fails for tight X (because live tight exits... no, parity is at actual exit values). OK.

#### Now let me look for SCHEMA MISMATCHES:

- The pre-registration says "Each layer is one IN deal whose comment matches `GRIND|<slot>|<side>|L<nn>|ENT`." Schema: slot, side, L number. Pair from symbol. OK.

- "A scalp costs 0.06 USD, a manual close 0.06, an open layer 0.03." So entry is 0.03, exit is 0.03. But for a scalp, the exit is a CloseBy which is free... wait. "Every entry, exit fill and manual close is charged 0.03 USD per 0.01 lot; CloseBy is free. A scalp costs 0.06 USD." Hmm, contradiction? A scalp is netted by CloseBy (free), but costs 0.06? Let me re-read.

"Commission: measured from the deals, not assumed. Every entry, exit fill and manual close is charged 0.03 USD per 0.01 lot; CloseBy is free. A scalp costs 0.06 USD, a manual close 0.06, an open layer 0.03."

Wait — if a scalp is netted by CloseBy (free), why does it cost 0.06? Because the scalp involves: the IN deal (entry, 0.03) and the EXT deal (the exit limit fill that created a new position, 0.03)? The CloseBy itself is free. So the scalp = entry (0.03) + the limit-fill exit position (0.03) = 0.06. And the CloseBy nets them free. OK that makes sense — the "exit fill" is a separate deal that fills as a new position, then CloseBy nets. So terminal: entry 0.03 + exit fill 0.03 = 0.06. Manual close: the OUT deal charges 0.03? Plus entry 0.03 = 0.06. Open: just entry 0.03. OK consistent.

But wait — for a manual close, is there an "exit fill"? No, it's an OUT deal at reason 0. So manual = entry 0.03 + OUT 0.03 = 0.06. OK.

For an open layer: entry 0.03 only. OK.

But hold on — in the counterfactual, a layer originally "open" that now fills at X: it would pay entry (0.03) + exit fill (0.03) = 0.06. A layer originally scalp that fills: 0.06. A layer that stays open: 0.03. Consistent.

But here's a subtle schema issue: "CloseBy is free." But the commission is "measured from the deals." If the deals show CloseBy as free (0 commission), then a scalp's total commission is entry's 0.03 + exit-fill's 0.03 = 0.06, CloseBy 0. Yes matches.

Hmm, but actually: the exit-fill position (created by the resting limit) — does it get its own commission on open? Yes, 0.03. Then CloseBy nets it. So the scalp is entry(0.03) + exit-open(0.03) = 0.06. OK.

#### Silent failures:

- The doc says nothing about validation of the M1 data gaps. "0 violations, two identical export passes." What about missing minutes (no trades in a minute)? M1 bars from MT5 typically exist for every minute during trading hours, but for illiquid crosses, there may be no tick → no bar. If a minute is MISSING (not just flat), the fill rule "first M1 minute where bid_high >= target" would skip it, potentially missing a fill that occurred in that minute (price moved through target in a gap). Actually if there's no bar, there's no tick, so no price movement — but that's wrong; a missing bar might mean data gap. This is a schema/data issue: how are gaps handled? Not stated. Could be a silent failure.

- Also: what if the entry minute itself is missing? Minor.

- **Timezone:** "broker time (UTC+3)." The M1 export and the deals must be in the same timezone. Stated.

- **The parity check "of layers observed as scalp, the share the replay also fills: at least 95%."** But "fills" at the ACTUAL exit value. The actual exit value for a scalp — is it the OPT or ALT value depending on the arm. The parity table gives OPT X and ALT X per pair. So replay with OPT X for OPT arm, ALT X for ALT arm. OK.

But here's a schema mismatch: the actual live exits were "clamped and carry-shifted" (s12) and "held" (ADR-151). So the observed scalp fill price/time may not equal entry ± exit_pips. The replay uses entry ± X. So parity might fail not because of a bug but because of these live distortions. The doc acknowledges this ("Parity will show if this matters"). OK.

#### Statistical flaws:

1. **Regime:** one regime, 7 days, guard saturated. Stated.

2. **Selection on 4 days, test on 3 days.** The holdout is small. But it's a legit split.

3. **"middle value (round down)"** — median of acceptable set. If acceptable set is even-sized, round down. OK. But if the acceptable region is an interval [a,b] (X values from a to b), the middle is a legit center. If disjoint, ambiguous.

4. **Using net pips per day as primary.** But the memo s7.1 says per-day vs per-slot depends on whether guard binds; guard is saturated → per-slot is right. The pre-registration makes per-day PRIMARY and per-slot secondary. That contradicts the memo's reasoning! s12 says "guard saturated throughout." s7.1: "When the guard binds, a slot freed early earns elsewhere, so per-slot is the right measure." Guard is saturated → guard binds → per-slot should be primary. But the pre-registration makes per-day primary. This is an inconsistency between the memo and the pre-registration. That's a meaningful finding! Actually the pre-registration defines per-day as PRIMARY and per-slot as secondary. Given the memo's own logic (guard saturated → per-slot), the choice of per-day as primary is questionable. But note: the pre-registration's counterfactual holds entries fixed, so freeing a slot doesn't actually re-earn elsewhere in the replay (first-order only). So per-day is what the replay can measure; per-slot is a proxy. Hmm. The pre-registration says pooling is valid because each layer is replayed independently. So per-day is the sum over independent layers / days. But if guard binds, the reality is layers compete for slots, so the counterfactual's independence assumption breaks. This is the core bias (s12 first bullet). The choice of per-day as primary doesn't fix it. The memo suggested per-slot when guard binds. The pre-registration overrides. Worth flagging.

5. **Parity thresholds:** 95% for classification, fill count within max(5%,2), median hold within max(10%,15min). Are these strict enough? For an exit counterfactual, the classification parity is on whether layers fill, which directly affects the totals. 95% means up to 5% misclassified — for 612 scalps, 30 layers could be wrong. Median hold within 10% — for a hold that's e.g. 200 min, 20 min tolerance, fine. Seems reasonable. But the fill-count tolerance max(5%,2) is loose for small counts (e.g., EURGBP ALT has 26 scalps; 5% = 1.3 → tolerance 2). OK.

But here's a subtle statistical flaw: the parity thresholds are on AGGREGATE per arm, not per X. So the replay could be biased in a way that cancels in the aggregate but distorts the curve. E.g., the fill rule might systematically overfill tight exits and underfill wide exits, but at the actual value the errors cancel. Parity at one point doesn't guarantee the curve is right. This is a real concern: the parity check is at a single X per arm, but the selection scans X=3..15. A rule that's correct at X=7 but biased at X=3 or X=15 would pass parity and corrupt selection. Good finding.

6. **"Portfolio" multiple testing:** 8 pairs × 13 values × 2 (gross/net) selections. The holdout guards against overfitting somewhat but 3 days is thin.

7. **The MTM of open layers:** The doc asks if it's right given the week ended underwater. Using bar close for MTM is standard. But there's a subtlety: the open layers include those the replay ALSO leaves open (at actual exit value, 105 open). For wider X, MORE layers stay open, and their MTM is at window close. If the week ended with the book underwater, wider X accumulates more negative MTM → penalizes wider exits. Is that fair? If the underwater state is a regime artifact, it biases the selection toward narrower exits. The doc's question 4. A fix: also report results excluding the last day's MTM, or use a longer window, or report the MTM distribution. Or mark to market at multiple points. The smallest fix: report the MTM contribution separately and test sensitivity to excluding the final day (which may be an anomalous close).

Actually, MTM at window end is necessary (else wider exits look free — s7.1). But the specific value at one moment is noisy. The doc could use the VWAP over the last N hours or report a band. Small fix: mark to the close but also show the curve excluding window-end MTM (i.e., only count layers that actually filled), to separate. Or extend the window.

8. **Swap inference for open layers:** open layers never paid swap, but in the counterfactual if held longer... Actually swap is only a sensitivity. But the inference "swap booked on closed layers / rollovers crossed" — closed layers are scalps/manuals; their swap covers 1-2 nights. Double check: swap is typically charged per night held, and triple on Wednesday. The window includes Wed 16 Sep. So the inferred per-night rate is an average including triple. Applying it per night to counterfactual holds overstates on non-Wednesday nights. Minor, sensitivity.

#### Answers to the 4 questions with smallest fix:

Q1: Bias not listed? The entry-minute exclusion (primary) understates fills for tight exits → biases toward WIDER exits. Not listed in s12 (only S1 is offered but the direction isn't stated). Smallest fix: state the direction, and/or report the primary and S1 curves with the difference; better, use a "same-second" rule if entry second is known (fill allowed if target reached after entry second, using tick data) — but with M1 only, the exclusion is the honest choice; just disclose the direction.

Also: manual rule A caps wider-exit upside (holds operator close fixed) → biases toward NARROWER. Not listed. S2 covers but direction unstated.

Also: fills at target with no penetration is optimistic for all, but the memo says penetration mean 0.0. Fine.

Also: the "held exits" bias toward wider is listed.

Q2: 95% parity strict enough? The problem: parity is at a single X per arm; the curve spans X=3..15. A rule could pass at X=7 and fail elsewhere. Smallest fix: run parity at MORE points (e.g., the actual value AND ± a couple pips) — but we don't have live data at other values. Alternative: add a parity check on the SHAPE — e.g., ensure the empirical fill-time distribution matches at the actual value, not just the count. Or require the misclassified layers to be randomly distributed (not systematic by side/pair/time). Smallest: report the confusion matrix broken down by side and by week-part to check for systematic error, and tighten to 97% or require the net-pips contribution of misclassified layers to be small.

Hmm, "smallest fix": add a check that the misclassified layers don't correlate with entry time (so the fill model isn't systematically wrong on a sub-population). Or simply report the fill-price/time error distribution for filled layers.

Q3: Selection rule robust to 7 days? No — 4 calibration days per pair is thin, and the per-pair selection multiplies tests. Smallest fix: pool pairs into groups (as the memo s7.4 suggested: majors, EURGBP, AUD/CAD/CHF crosses, NZD) and select per group, reducing free parameters. This is literally the memo's advice. Also/or: require the acceptable region to be contiguous, and require the pair's two arms (OPT/ALT) to agree.

Q4: MTM at window end? Necessary but noisy; if the final day is anomalous (underwater), it biases toward narrow. Smallest fix: report the curve with and without the final day's MTM (or MTM at multiple window ends / a rolling window), so the reader sees the dependence. Alternatively extend the window to accrue more days (memo s7.4 says include days after 18-Sep as they accrue).

#### Now, other issues to raise:

**Lookahead bias:**
- The exit fill rule uses the bar AFTER entry — safe. But wait: the "first eligible minute is the one AFTER the entry minute" — if the entry is at 10:30 (bar), the first eligible is 10:31. But what if the entry was at 10:29:59 and the bar is labeled 10:29? Then the "entry minute" is 10:29, first eligible is 10:30. OK, no lookahead. Actually the risk is the OPPOSITE: excluding the entry minute might exclude a valid fill (10:29:59.5 → 10:30:00). Negligible.

- The MTM at window end is known in advance — but it's the terminal value, so no lookahead.

- The manual close at time T uses the actual manual price — known. OK.

- **Selection uses calibration days, holdout uses other days.** But the selection is done AFTER seeing calibration results; the holdout is held out. But if the researcher iterated (saw holdout, re-tuned), that's a violation — the doc says amendments recorded. OK.

- **Real lookahead risk:** the "actual live exit_pips" used in parity — if the live values were chosen using the same window (they were, per the memo s1-s3), then parity is not independent. But parity is just a check. Fine.

Hmm, actually here's a genuine lookahead: the calibration/holdout split is by entry DATE. The selection on calibration uses per-pair net pips per day. The holdout test compares to "the pair's two current live values on the holdout." The current live values (OPT/ALT) were chosen using the whole 9-day window (s2 measurement used all 9 days). So the holdout comparison baseline is contaminated by holdout data. That is, the live values were tuned on data that includes the holdout days. So the holdout isn't a clean holdout for the COMPARISON baseline. Smallest fix: recompute the live-value baseline on calibration only? Or acknowledge. Hmm, this is subtle. The live values were chosen from the 9-day measurement (s2). So "better of the pair's two current live values on the holdout" uses values informed by holdout. That makes the acceptance EASIER (baseline inflated). So it's conservative in a bad way (makes acceptance easier). Actually it makes it easier to accept X*, which is anti-conservative. Worth noting.

**Silent failures:**
- Missing M1 bars / gaps handling not specified.
- What if the entry price itself isn't exactly the limit? The entry is a real deal, so price is real. OK.
- The "0.01 lot on every layer" — but the deals might have different lots? The doc asserts 0.01. If some layers have different size, pips conversion breaks. Assume uniform.
- The pips conversion: "USD per pip per pair = median of profit/pips over that pair's observed scalps." If profit includes swap/commission, then profit/pips mixes commission into the pip conversion → double counting? Need the profit to be the GROSS price P&L. Schema issue: which profit field? If the deal's profit includes commission, the median is contaminated. Smallest fix: use the raw price difference (exit - entry) for the pips and the deal's price P&L only, excluding commission/swap.

Actually re-read: "USD per pip per pair = median of profit / pips over that pair's observed scalps." If "profit" is the deal profit field (which in MT5 is the price P&L, NOT including commission — commission is a separate field), then OK. In MT5, `DEAL_PROFIT` is price P&L, `DEAL_COMMISSION` separate, `DEAL_SWAP` separate. So profit/pips is clean. Good, probably OK.

But "pips" here = exit - entry in pips. profit/pips = USD per pip. For 0.01 lot. OK.

**Schema mismatch:**
- The comment format `GRIND|<slot>|<side>|L<nn>|ENT`. And CloseBy comment `#ent by #ext`. The pairing for hold time. Any mismatch in parsing → silent wrong pairings. Not our code.

- Layer = IN deal. But a layer could be re-entered (L0 re-entries mentioned). So multiple IN deals per slot. OK.

**Statistical:**
- **"net pips per trading day"** — the denominator is trading days (7). But the calibration has 4 days, holdout 3. When selecting on calibration, per-day uses 4 days. When testing on holdout, per-day uses 3 days. OK.

- **Pooling across arms:** "Pooling is valid for the exit replay because each layer is replayed independently of its arm." But the two arms have DIFFERENT live exits (OPT/ALT), and the entries in each arm were shaped by that arm's live geometry (add, width, guard). So pooling entries across arms mixes two different regimes. The doc says "Per-arm figures are reported as a check that the two arms agree." But if they don't agree, pooling is questionable. Minor.

- **The 90% threshold "of that pair's maximum."** That's relative to the max over X. If the curve is flat within 10%, the middle is chosen. Good robustification. But with 13 values and a noisy max, the max itself is noisy. Using 90% of a noisy max → the acceptable region fluctuates. Minor.

- **Holdout acceptance "90% of the better of the two current values."** This is a one-sided test. If the current values are at the peak (overfit), the baseline is high → harder to beat → conservative. If current values are bad, easy to beat. Hmm. Reasonable.

Let me also think about the **fill semantics for shorts**: "ask_low <= target." A short's exit is a buy limit at entry - X. It fills when the ask drops to target. The ask is the price at which you can buy. A buy limit fills when the market ask <= limit. Correct. Good. And long: sell limit fills when bid >= limit. Correct.

But wait — the doc says "A buy limit can only be matched by the ask; testing it against the bid would count fills that could not have happened." Correct and good.

**MTM for shorts at ask_close** — to close a short you buy at the ask. Correct. Longs sell at bid. Correct.

**Now, a subtle issue with the entry:** For a long entry, the entry was a buy limit at mid - width, filled at the ask? Or bid? In reality, a buy limit fills at the ask (you buy at ask). The doc takes "entry price from the deal" — real fill price. For the exit target = entry + X. For a long, the exit is a sell limit at entry+X; fills when bid >= entry+X. The SPREAD means the target is based on the entry (which was ask) but the exit fills on the bid. So the NET move captured is X minus the spread? Hmm. Actually entry price for a long buy = ask. Exit sell fills at bid = target. For the bid to reach entry+X, the market must move X above the entry ask... wait. Let me think. Entry at ask price E (bought at ask). Exit sell limit at E+X fills when bid >= E+X. So the market's bid must reach E+X, meaning mid moved up more than X. The realized pips = exit - entry = X (per the doc, fill at target). But the doc counts pips as exit_price - entry_price = X. That's the nominal. But economically, you bought at ask E and sold at bid E+X, netting X. But you paid the spread on entry? No — the entry fill price is the actual price paid (ask). The exit fill is the actual price received (target). So realized = target - entry = X. OK, that's the true realized. Fine.

But here's the subtlety: the target is defined relative to the ENTRY price (which for a long is the ask). The doc says "exit target is entry + X for a long." Then "bid_high >= target." So target = ask_entry + X, and we need bid >= ask_entry + X. That requires the market to move X + spread. But the doc counts realized pips = target - entry = X. Hmm, that's self-consistent (the definition of X is the price move from entry). But is X the "exit_pips" as configured in the EA? The EA's InpExitPips presumably defines the exit distance in price from entry. So exit limit = entry + X. And fills when the opposite side reaches it. Yes consistent. OK.

Now, the "pips" for the deal: realized pips would be exit - entry = X. Good.

Hmm OK. Let me also reconsider the commission in pips: commission pips = commission USD / (USD per pip). For a scalp, 0.06 USD / (0.10 for GBPUSD) = 0.6 pips. And net pips = gross - 0.6. Fine.

**A big one: the selection uses "pooled net pips per day" across arms, but the holdout test compares to "the pair's two current live values."** The current live values are per-arm. So on the holdout, you compute net pips per day at the live OPT X and live ALT X (separately per arm?) and take the better. Then compare X*'s pooled holdout to that better single-arm value. Comparing pooled (both arms) to a single-arm value is apples-to-oranges. Hmm. Actually the doc says "the better of the pair's two current live values on the holdout." If X* is pooled over both arms and the baseline is one arm's value... The pooled has more layers → could be higher or lower. This is a subtle schema mismatch. Smallest fix: compare like with like — pooled X* vs pooled current-live (i.e., pool the two live arms' values at their respective X). Or do the comparison per arm.

Hmm, but actually maybe "the pair's two current live values" means the total net pips/day of the pair as currently run = OPT arm at OPT X + ALT arm at ALT X. "the better of the two current live values" = better of OPT-at-OPT-X and ALT-at-ALT-X? Or the sum? Ambiguous. Worth flagging as ambiguity.

Let me also consider: **the calibration selection is per pair on pooled arms; the holdout acceptance is per pair.** OK.

Let me now also think about **the "middle value" rule and monotonicity.** If the curve is monotonic increasing (wider always better within 3-15), then all X are acceptable (each within 90% of max), and the middle is X=9. But if the true optimum is at the boundary 15, the rule picks 9 — conservative. If the curve is monotonic decreasing, picks 9 too (middle of all). Hmm, if ALL values are within 90% of max, middle = 9 regardless of shape. That could be fine (flat) or bad (monotonic). Actually if it's monotonic increasing, the middle 9 is chosen, but the peak is 15. The rule is designed for a flat region; a monotonic curve means no flat region → picking the middle is arbitrary. The rule doesn't handle boundary optima. Minor.

**Let me also check: is there a lookahead in the parity using the actual exit value if the actual exit value is only known for... no.**

**Another statistical flaw:** the doc says the window is 7 trading days but the memo says 9 days (2,716 deals 2026-09-10 to 2026-09-18). 10th to 18th inclusive = 9 calendar days = 7 trading days. Consistent.

**The L0 re-entries and adds** — the entries are fixed, so the counterfactual ignores that a narrower exit frees a slot earlier → more L0 re-entries → more entries. Stated (s12 first bullet). This biases toward... hmm. If narrower exits free slots earlier and the guard is saturated, then in reality narrower exits would generate MORE entries (more L0s), hence more pips. The replay holds entries fixed → understates narrower exits' benefit. So the replay biases AGAINST narrow exits → toward wider. This is the OPPOSITE of what the memo's "per-slot" argument suggests. Actually the memo says per-slot is the right measure when guard binds. The replay's per-day with fixed entries understates narrow. So combined with the entry-minute bias (also against narrow), there are TWO biases against narrow exits, both favoring wider. Interesting. The doc lists the "entries fixed" bias but doesn't state its DIRECTION. Smallest fix: state the direction (entries fixed biases the comparison against tighter exits because tighter exits would free guard slots and admit more entries).

Wait, let me double check. Narrower exit → layer closed sooner → slot freed sooner → guard (which limits concurrent positions or inventory) admits new L0 entries sooner → more trades → more pips. Held fixed, the replay gives narrower exits no credit for this. So yes, the replay understates narrow. Bias toward wide. And the s7.1 per-slot measure is meant to capture this. But the pre-registration makes per-day primary. So the primary metric is the one with the unmodeled bias. Good finding.

Hmm, but actually per-slot (net pips per slot-day) would give narrower exits a higher rate (more pips per slot-day) — which would favor narrow. And per-day with fixed entries favors wide (because wide exits reach bigger targets). So the two metrics pull opposite ways, exactly as the memo says. The pre-registration picks per-day as primary. Given the guard is saturated (so freed slots would be used), per-slot arguably better captures reality. But per-slot also has issues (it doesn't model the re-entry either; it just normalizes by hold). Ugh. The honest answer: neither is clean; report both and note they disagree in sign of the bias. The "smallest fix" for Q1/Q3: make per-slot co-primary or at least present both prominently, and state that the per-day metric favors wider exits due to the fixed-entries assumption.

OK, I think I have plenty. Let me also look for any actual bug in the described code... but there's no code. Hmm. The "## CODE TO AUDIT" is empty. Maybe I should note that. But the instructions say "You have access to the full codebase." Perhaps the intended answer is to audit the documents. I'll audit the methodology (which is what's provided) and note the code section is empty.

Actually, wait. Let me reconsider. The user might have intended to paste code but it's empty. As an auditor, I should flag that and proceed to audit the documents, since they contain the method. I'll structure my answer as an audit report.

Let me also reconsider potential **arithmetic/consistency errors** in the docs:

- s2 table: "AUDCAD OPT 5, net/scalp 0.30, 68 scalps → 20.4 realized." 68 × 0.30 = 20.4. ✓. ALT: 39 × 0.65 = 25.35 ≈ 25.4 ✓.
- GBPUSD OPT 84 × 0.65 = 54.6 ✓. ALT 81 × 0.96 = 77.76 ≈ 77.8 ✓.
- EURUSD 44 × 0.63 = 27.7 ✓. 33 × 0.94 = 31.0 ✓.
- EURGBP 51 × 0.55 = 28.05 ✓. 26 × 0.87 = 22.6 ✓.
- AUDCHF 33 × 0.54 = 17.8 ✓. 19 × 1.13 = 21.5 ✓.
- CADCHF 25 × 0.52 = 13.0 ✓. 12 × 1.10 = 13.2 ✓.
- NZDCAD 34 × 0.30 = 10.2 ✓. 17 × 0.44 = 7.5 ✓.
- AUDNZD 25 × 0.21 = 5.25 ≈ 5.2 ✓. 21 × 0.34 = 7.14 ≈ 7.1 ✓.

All consistent. Good.

- "612 scalps per arm reproduce the memo table exactly." The memo table scalps: 84+81+44+33+51+26+68+39+33+19+25+12+34+17+25+21 = let me sum: 84+81=165, +44=209, +33=242, +51=293, +26=319, +68=387, +39=426, +33=459, +19=478, +25=503, +12=515, +34=549, +17=566, +25=591, +21=612. ✓ 612.

- "105 open = live book." and "76 manual." 612+76+105 = 793. ✓.

- Calibration 505 + holdout 288 = 793 ✓.

- The add/width ratio: add = 2×width. Table: audchf opt width 5 → required add 10, new add 7. ✓. audnzd opt width 7 → 14, new 7. audnzd alt width 7 → 14, new add 10. gbpusd alt width 5 → 10, new add 14. ✓. Consistent with s6.1.

OK.

Now let me also examine the **"sensitivity S1: include the entry minute"** more: if we include the entry minute, we may count a fill that happened BEFORE the entry. E.g., entry at 10:30:40, but bid_high of the 10:30 bar occurred at 10:30:10 (before entry). Then including it counts a fill that couldn't have happened. Since the doc says entries are fills at limit prices, the entry bar's high could be at any time. So S1 is upward-biased for fills (lookahead within the entry minute). The doc should either use tick data or shave the entry minute. Smallest fix: for S1, require the fill minute > entry minute OR (same minute AND price reached after the entry timestamp) — needs sub-minute data. Alternatively state S1 as an upper bound.

Hmm, but actually if the entry is a resting limit (passive), it filled at the limit at some time in the minute. The exit is on the other side. Within the same minute, both could occur. Without tick data you can't order them. So primary (exclude) is conservative; S1 (include) is optimistic. Present both as a bracket. That's a clean "smallest fix": present [primary, S1] as a bracket, not S1 as a mere sensitivity.

Now, the **biggest genuine methodological worry**: The parity at the actual value doesn't validate the curve across X. Let me articulate.

Also: **The window ends 2026-09-18 23:54; MTM at that bar.** For layers entered on 18 Sep late, hold time is short. Fine.

Also: **the "7 trading days" includes entry days; but the calibration/holdout split by entry date means holdout layers entered on 11,15,17 Sep still have full price paths to 18 Sep.** The doc says "Layers keep their full price path whichever day they entered." So a layer entered 11 Sep can be MTM'd on 18 Sep. Good, no truncation. But then the effective sample overlap: a layer entered 11 Sep and a layer entered 17 Sep both share the 17-18 Sep price path for MTM. That induces correlation across calibration and holdout (shared terminal). For a holdout test, sharing the terminal MTM between calibration and holdout layers could leak information? Not really lookahead. Minor.

Actually here's a subtle lookahead/leak: the calibration selection uses per-day net pips. Day = entry day. But a layer entered on day d is MTM'd at window end (18 Sep), not at end of day d. So the "per day" denominator uses entry day but the outcome includes the whole path to 18 Sep. A layer entered on 10 Sep (calibration) that doesn't fill until 17 Sep (holdout) contributes to calibration's numerator. So "per entry day" is a misnomer — the outcome is not contained in the entry day. This mixes calibration and holdout outcomes. Hmm. Is that a problem? The split is by entry date, so the layer is assigned to calibration or holdout by entry. Its FULL outcome (to 18 Sep) is used. So the holdout outcome for a 17-Sep entry uses 17-18 Sep prices only; the calibration outcome for a 10-Sep entry uses 10-18 Sep prices. So calibration and holdout are NOT independent in price-path space; but they're independent in entry space. For selection vs validation, you need the entry populations to be independent, which they are. The concern is that calibration layers "see" more of the window (longer paths) than holdout layers, so the per-day metric is systematically different between calibration and holdout (survivorship/length difference). E.g., calibration entries on 10 Sep have 8 days of path; holdout entries on 17 Sep have 1 day. This biases the comparison: wider exits need time to fill, so calibration (longer paths) favors wider exits more than holdout. So the holdout test would systematically disfavor wide exits chosen from calibration. This is a real design flaw: the split by entry date with a fixed window end induces a path-length difference between calibration and holdout, confounding the exit-width comparison. 

Hmm, is that right? Calibration days: 10, 14, 16, 18. Holdout: 11, 15, 17. Entries on 18 Sep (calibration) have ~1 day path; entries on 10 Sep (calibration) have 8 days. Holdout entries on 17 Sep have 1 day; 11 Sep have 7 days. So both sets span similar path lengths (10→8d, 14→4d, 16→2d, 18→1d; 11→7d, 15→3d, 17→1d). So the distributions are similar-ish. Calibration mean path ~3.75 days; holdout mean ~3.67 days. Close. OK so not a huge confound, but the per-day normalization by entry day doesn't equal per-path-day. Largely fine. I'll mention lightly.

Actually more important: **the metric "net pips per trading day" uses the number of trading days in the subset (4 vs 3), but the numerator sums full-window outcomes.** For calibration, sum of outcomes over calibration entries / 4 days. That's fine as a rate. OK.

Let me also think about **whether the parity "of layers observed open, the share the replay also leaves open >= 95%"** can even be met given the "held exits" and clamping. Possibly not, but they'll see.

Now, **the "smallest fix" framing** for each of the 4 questions. Let me draft:

Q1 (bias toward wide/narrow not listed):
Yes, two, both toward WIDER and unstated:
(a) Excluding the entry minute understates fills for tight X (the target is close). Direction: favors wide. Fix: present primary and S1 as a bracket [conservative, optimistic]; or use sub-minute/tick data; minimal: state the direction.
(b) Holding entries fixed with a saturated guard denies tight exits the extra entries they'd free. Direction: favors wide. This is listed as a bias but its DIRECTION is not. Fix: state direction; and/or elevate net-pips-per-slot-day to co-primary since the guard binds (per memo s7.1), so the two metrics bracket the effect.
(c) Manual rule A caps wide-exit upside → favors narrow. Listed? S2 covers, direction unstated. State it.

Actually the question asks "biased toward wider or narrower exits in a way NOT listed in s12." s12 lists: entries fixed (no direction), held exits (favors wide, since replay fills what live couldn't), clamped/carry-shifted, one regime, M1 resolution. So the unlisted ones: (a) entry-minute exclusion (favors wide), (b) direction of entries-fixed (favors wide) — it IS listed as "entries fixed" but direction not given, (c) manual rule A favors narrow (rule A is in s5, not s12). And the commission treatment etc.

Q2 (95% parity strict enough):
The flaw is it validates at ONE X per arm but selects over X=3..15. A fill rule correct at the actual value can be biased at other X. Fix: add a shape check — e.g., require the filled-layer fill-TIME distribution and the fill-PRICE (=target) to match, and check that misclassifications aren't systematic (by side, pair, time-of-day). Minimal: report the confusion matrix split by side and by entry-day, and require no sub-group below ~90%. Also tighten: since the counters are cheap, 95%→97%.

Q3 (selection robust to 7 days):
Not robust: 4 calibration days/pair, 13 X values, 8 pairs, and the "middle of acceptable region" can be a boundary artifact if the curve is monotonic or the acceptable set is disjoint. Fix (smallest): pool pairs into the groups the memo already proposed (majors, EURGBP, AUD/CAD/CHF crosses, NZD) and select one X per group — fewer free parameters. Also require the acceptable set to be a single contiguous run and the two arms to agree; if not, widen the 90% band rather than pick a middle.

Q4 (MTM at window end):
Right in principle (necessary to avoid free wide exits), but the terminal value is a single noisy/regime-laden point; with a mostly-underwater book it biases toward narrow. Fix: report the curve with MTM at the close AND with MTM at a trailing VWAP (last N hours / last day), and/or report the MTM contribution separately; and extend the window as days accrue (memo s7.4). Minimal: show the curve with and without the final day's MTM.

Now let me write up a comprehensive audit report. I'll include:
- Preliminary: the CODE TO AUDIT section is empty; auditing the supplied pre-registration + memo. If code exists, paste it.
- Findings grouped by category: lookahead bias, silent failures, schema mismatches, statistical flaws.
- Then answer the 4 questions.

Let me be thorough and specific, citing sections.

Let me also double-check a couple more potential issues:

**The pip value median:** "median of profit/pips over that pair's observed scalps." If a scalp's profit is 0 or negative, or pips small, the ratio can be wild. Median is robust though. But for pairs with few scalps (e.g., CADCHF ALT 12, NZDCAD ALT 17), the median is noisy. And the pip value should be nearly constant per pair (it is, modulo lot and quote currency), so a better estimator is the theoretical pip value or the mean of |profit|/|pips|. Median of signed ratio could be biased if profits correlate with pips sign. Actually profit/pips is signed/signed = positive if profit and pips same sign (they should be). So the ratio is positive. Median fine. Minor.

**Commission in pips conversion uses the scalp-derived USD/pip, applied to manual and open layers too.** Fine.

**Swap S3:** "per-night swap rate per pair and side, inferred from the swap booked on closed layers divided by rollovers crossed." Closed layers are scalps (hold ~hours) and manuals. Many scalps are intraday → 0 rollovers. So the denominator (rollovers crossed) might be dominated by a few overnight holds. The inferred per-night rate could be noisy. And Wednesday triple. Sensitivity. Minor. But note: if most scalps cross 0 rollovers, then swap booked = 0 for them, and dividing by total rollovers gives a per-night rate from the few overnight layers. OK.

**"Swap: excluded from the primary."** Good.

**One more: the definitions of "realised pips" and "MTM pips".** realised = for filled layers, exit - entry (signed). MTM = for open layers, mark - entry. gross = realised + MTM. But for MANUAL layers under rule A, they close at T at manual price — is that "realised"? Yes. OK.

**Potential double-counting in gross:** for a layer that fills, realised includes it; MTM should not also include it. Need to ensure MTM only for open layers. The doc implies that. OK.

**Negative: "Never dropped."** Good.

Now, is there a lookahead in how the parity's "actual live exit" is defined if some layers were clamped/carry-shifted? The replay uses raw formula; live used clamped. So the comparison is formula-vs-clamped. If clamping moved exits, parity fails → they'd have to modify. The doc says S4/S-sensitivities. OK.

Let me also reconsider: **the doc says "Every exit is a resting limit order and fills passively at its own price. Nothing in the replay crosses the spread."** But entries are real deals that DID cross/spread. And the exit target is relative to the entry price. Fine.

**Critical: The exit for a long is a sell limit; it fills when bid_high >= target. But the entry for a long was a buy at the ask. So target = ask_entry + X, and we need bid >= ask_entry + X → mid >= ask_entry + X - spread/2... The realized "pips" = X by construction.** But the pips recorded should be (exit fill - entry fill). Exit fill = target = ask_entry + X. entry fill = ask_entry. So pips = X. Yes.

But hold on — over a multi-day hold, the spread may widen/narrow. The target is fixed. The fill price = target. So pips = X regardless. So realized pips = X for every filled layer! Then "realised pips" per pair = X × (number of fills). And the curve of realized vs X is monotonic (more X, fewer fills). Hmm interesting — so gross realised pips = X × N_fill(X). And MTM for the rest. So the whole analysis is essentially N_fill(X) vs X tradeoff. That's expected for a fixed-entry exit study. Fine. But worth noting: realized pips are exactly X per fill (no slippage), so the curve is smooth. OK, not a flaw, just a property.

Actually wait, manual closes under rule A are at the manual price, not X. So those aren't exactly X. And layers that fill at target are exactly X. OK.

**Let me reconsider the fill rule and lookahead once more:** "the first eligible minute is the one AFTER the entry minute." Suppose entry at 10:30:00.000 exactly (bar 10:30). First eligible 10:31. Fine. Suppose entry at 10:30:59. First eligible 10:31 (covers 10:31:00-10:31:59). But the entry was at 10:30:59, so the next minute is 10:31:00 onward. Correct. Suppose entry at 10:30:01 and price touches target at 10:30:30 (same minute). Primary excludes → misses. That's the conservative bias. OK.

Now, **the sensitivity S1 includes the entry minute → could include a pre-entry touch** (lookahead). So neither is perfect; bracket them.

Alright. Also **the doc's claim "Limit exits filled at touch live (exit_penetration_pips_mean 0.0), so this matches."** Using "fill price = the target." But if penetration mean is 0.0, the fill price ≈ target. But MT5's M1 bid_high/ask_low is a proxy for "touch." Fine.

Let me also flag: **the replay's "first minute where bid_high >= target"** could overfill if within that minute the price's high was made by a bid that then... no, a touch fills. OK.

Let me also consider the **"fill time = start of the fill minute"** understates hold time by up to 59s → understates slot-days → inflates net pips per slot-day? Slightly. Minor, consistent across X.

OK, now let me also think about whether there's an issue with **using the actual manual close price under rule A when the counterfactual exit is TIGHTER and fills EARLIER** — then the layer fills at target (realised = X), which might be worse or better than the manual price. Fine, that's the point.

Now, the **X* selection per pair then holdout**: but "the same rule is applied to GROSS pips and both selections are reported." Then the holdout test uses "net pips per day at X*" — which X*? The net-selected or gross-selected? Ambiguity. I'll flag.

Also: **"Acceptance does not ship anything."** Fine.

Let me now consider the **question 3** more: "should pairs be pooled into groups?" The memo s7.4 says consider one exit value per group. The pre-registration does per-pair. With 4 cal days and ~63 cal layers per pair (505/8≈63), per-pair per-X averages ~5 layers per X per pair? No, all layers are used for every X (the curve). 63 layers per pair on calibration. That's thin but the curve is over the same layers for each X (correlated). Selection noise high. Pooling groups → ~126-190 layers per group. Better. So yes, pool into groups as the memo suggested. That's the smallest fix.

Hmm, but pooling arms/pairs assumes similar exit behavior; the memo's groups are sensible.

Now **question 2** smallest fix: add a second parity point. But we lack live data at other X. Alternative: split parity by side and by sub-period; require each to pass. That detects systematic fill-model error beyond the aggregate. I'll propose that.

Actually, there's a cleaner smallest fix: since we have TWO arms per pair at DIFFERENT X (OPT and ALT, e.g., 7 and 10), the parity is ALREADY effectively at two X. But for pairs where OPT≠ALT only by a bit (e.g., EURGBP 5 vs 8, AUDCAD 5 vs 10), that's two points. For GBPUSD 7 vs 10. So parity across 2 X values. Still not the full 3-15. So the range endpoints (3 and 15) are unvalidated. Suggest interpolate: require monotonic fill-count in X (more X → fewer or equal fills) as a sanity check. That's a cheap, good check: the fill count must be non-increasing in X (a wider target can't fill more often, given fixed entries). If the replay violates monotonicity, there's a bug. That's a strong smallest fix! Because realized fills are monotone in X by construction, but if the data has quirks (e.g., a layer fills at X=5 but not X=4 due to the entry-minute rule...) hmm actually with the entry-minute exclusion, a layer might fill at X=5 (later minute) but NOT at X=4 (only touched in entry minute, excluded)? No — if it touches X=4 in the entry minute and X=5 later, then at X=4 the later touch also >= X=4? No: X=5 target is further. Let me think: if it touched entry+5 at minute 10, it necessarily touched entry+4 at or before minute 10. If entry+4 was touched only in the entry minute (excluded) and entry+5 touched at minute 10 (included), then X=4 doesn't fill (entry minute excluded) but X=5 fills (minute 10). That VIOLATES monotonicity! So the entry-minute exclusion can produce non-monotone fill counts. That's a red flag / a bug to check. Good — so the monotonicity check would surface the entry-minute artifact. Nice. Actually this shows the entry-minute exclusion is problematic: a wider exit can fill when a tighter one doesn't. That's economically impossible (if the market reached entry+5, it reached entry+4 first, so a resting limit at entry+4 would have filled). So the primary rule creates impossible non-monotonicity. That's a genuine flaw! The smallest fix: also exclude the entry minute for the FIRST eligible but require that if a later minute qualifies, then all closer targets are deemed filled (monotone repair) — equivalently, when a layer fills at X, mark it filled for all smaller X at the same or earlier time. Simpler: handle the entry minute by using the entry price/time inside the minute via sub-minute (tick) data if available; else enforce monotonicity by construction (a layer fills at X iff the path (excluding entry minute) reaches X; then for X' < X it must also fill — but the exclusion breaks it). Hmm.

Actually the cleanest: the entry-minute exclusion is a conservative assumption applied at the ENTRY side, but because the exit could fill in the entry minute, excluding it introduces non-monotonicity. The fix: instead of excluding the entry minute entirely, exclude only price action up to the entry time — impossible with M1. So the practical fix: report primary and S1, AND enforce/report monotonicity, flagging any violations as the entry-minute artifact magnitude. This is a strong finding.

Let me double-check monotonicity reasoning. Fixed entry. Closer target (smaller X) is hit no later than farther target — TRUE in continuous price, because to reach entry+5 you pass entry+4. So the set of minutes hitting entry+4 is a superset. But with the entry-minute excluded, we discard hits in the entry minute. Could a layer hit entry+4 ONLY in the entry minute and entry+5 in a later minute? To hit entry+5 at a later minute, price went from entry to entry+5 after the entry minute. On the way, it crossed entry+4 at that later time. So entry+4 is ALSO hit in a later minute. Contradiction! Because if price rises monotonically from entry to entry+5 in the post-entry window, it hits entry+4 in the post-entry window too. But price might first drop then rise... still, to reach entry+5 post-entry it must cross entry+4 post-entry (assuming it starts below entry+4; it starts AT entry, which is < entry+4). So entry+4 is crossed in the post-entry window whenever entry+5 is. Hence X=5 fill ⟹ X=4 fill. Monotone. But wait, the exclusion is the entry MINUTE, and both hits could be in the same later minute — fine. So actually monotonicity holds EXCEPT along a path where... hmm, the only way X=4 fails while X=5 fills is if the entry+4 touch happens ONLY in the entry minute and entry+5 touch also only in the entry minute (then both excluded) — no. Or the price gaps: M1 bars are discrete. Bar high could jump: in one bar, low is below entry+4 and high is above entry+5. Then the bar's high >= entry+4 AND >= entry+5, so both fill that bar. If that bar is the entry minute, both excluded. If a later bar, both fill. So with bars, high >= target is per-bar; X=5 bar qualifies ⟹ X=4 also qualifies same bar. So monotone still holds. Hmm. Unless a bar has high >= entry+5 but... high >= entry+5 implies high >= entry+4. Yes. So fill_count(X) is non-increasing in X. Monotone. OK so my earlier worry is wrong due to bar-level highs. Good — so monotonicity SHOULD hold and is a valid sanity check, but the entry-minute exclusion does NOT break it. Wait, but it can: consider the entry minute bar has high >= entry+5 (so post-entry, within the entry minute, price reached entry+5). Excluded. A later bar reaches entry+3 but not entry+4. Then X=4 doesn't fill (only entry minute + later bar missing), X=5 doesn't fill (only entry minute). Both fail. X=3 fills. Fine, monotone (X=3 fills, X=4,5 don't). OK consistent.

Another: entry minute high = entry+5 (excluded). Later bar high = entry+4.5. X=4 fills (later bar >= entry+4), X=5 doesn't (only entry minute). Monotone (X=4 yes, X=5 no). ✓.

So monotonicity holds given per-bar highs and a single exclusion window. Because the exclusion is the same earliest minute for all X. So fill_count is non-increasing. Good — so it's a valid bug-detector, and the exclusion doesn't break it. I'll still propose it as a cheap invariant.

Hmm, but wait: is the exclusion "the entry minute" the same for all X? Yes. So monotone. Good.

OK so the monotonicity check is a cheap, powerful sanity check for the SELECTED curve. Good "smallest fix" for Q2.

Let me also mention the **fill count non-increasing in X** and **realised pips = X·N_fill(X) so the realised curve should be single-peaked-ish**. Eh.

Now, let me also think about **whether net pips per day could be gamed by the window length**: pairs with more holds... no.

Alright, let me also reconsider **the "middle value (round down)"**: if acceptable set = {X: net >= 0.9*max}. Round down the middle. Fine. I'll note to require contiguity.

Let me also note a **potential schema mismatch: `slot` → arm.** "arm from slot." But the memo refers to OPT/ALT arms and slots separately (slot = template slot?). "slot-days" metric uses slot as... hmm, "slot-days (sum of layer hold time...)". Wait, slot-days = sum of hold time. But "slot" is the arm/slot identifier. So slot-days is a confusing name; it should be "layer-days" or "hold-days." Because there are multiple layers per slot (adds). So "slot-days" summing hold time over layers double-counts the slot. If the guard limits SLOTS (not layers), then the right per-slot measure is the time the SLOT is occupied = from first layer to last close for that slot, not the sum of layer holds. Summing layer holds overcounts when layers overlap. This is a schema/semantic mismatch: "slot-days" as defined (sum of layer hold time) is actually "layer-days," not slot occupancy. For the per-slot metric to reflect guard pressure, you need occupancy = union of layer intervals per slot, not the sum. This is a genuine issue for the secondary metric and the memo's "per-slot" logic. Good finding.

Let me make sure: s8: "slot-days (sum of layer hold time, entry to fill, manual close, or window end)". So yes, they define slot-days = sum of layer hold time. But a slot with 4 layers each held 2h overlapping → sum = 8 layer-hours but slot occupied 2h. So the name is wrong and the metric overstates occupancy. If the guard is per-slot, the correct denominator is occupancy. Smallest fix: rename to layer-days; and additionally compute slot-occupancy-days = sum over slots of (last close - first entry), verify guard saturation.

Good.

Now let me also reconsider **"Pooling is valid for the exit replay because each layer is replayed independently of its arm."** True for the replay, but the ENTRY populations differ by arm (different add/width/x exit shaped which entries exist). So pooling mixes two entry regimes. For the SELECTION of a common X this is intended (one X per pair). But the per-day rate pooled = average of two arms; if the arms have different layer counts, the pooled rate weights by count. OK. Minor.

**Another: the entry-time / guard conditions differ across arms; the replay holds them fixed. Fine.**

Alright, I think I should also explicitly note the **lookahead in S1** (entry minute includes pre-entry touches) and the **non-lookahead of primary**.

And **the MTM "at bar close" for the last bar 23:54** — is that the last M1 bar? If the window "path to 2026-09-18 23:54", the last bar is 23:54 (i.e., 23:54:00-23:54:59). Using its close. Fine.

Let me also flag: **the doc says "Path to 2026-09-18 23:54" but entries window ends 2026-09-18.** So entries up to 18 Sep 23:54. OK.

Now, let me also double check **the parity classification "of layers observed as scalp, the share the replay also fills"**. But at the actual exit value, the replay might fill a layer that live stayed open (the "held exits" / clamping). Those go into the "observed open → replay fills" cell, reducing that 95%. Fine.

Now let me write the report. I'll aim for thorough but organized. Use headers, cite sections.

Let me also provide the 4 answers explicitly and concisely with smallest fixes, as the doc demands.

Structure:
1. Scope note (empty code block).
2. Findings — Lookahead / fill-rule.
3. Findings — Silent failures / data.
4. Findings — Schema / semantics.
5. Findings — Statistical / design.
6. Answers to s13 Q1–Q4 with smallest fixes.
7. Minor/consistency.

I'll be specific. Let me write.

For the "code to audit" being empty — I should mention it clearly but not derail.

Let me draft the findings in detail.

Finding A (fill rule / lookahead):
- A1. Primary entry-minute exclusion is conservative but creates an asymmetry: it removes a full minute of path from EVERY layer, so tight X (3–5) lose a disproportionate share of their (few) fill opportunities, while wide X are barely affected. Direction: biases the curve against tight exits → toward wider. Not in s12. Fix: bracket [primary, S1].
- A2. S1 "include the entry minute" can register a fill that occurred BEFORE the entry second (bar high/low from earlier in the entry minute). This is a within-bar lookahead and is impossible. So S1 is an upper bound, not an estimate. Fix: only use S1 as the optimistic leg of the bracket, or shave with tick data.
- A3. Fill time = start of fill minute ⇒ hold times understated by [0,59s]; consistent across X so it mostly cancels in comparisons, but it inflates slot-day counts' precision and slightly biases per-slot-day. Fix: use mid-minute or state.
- A4. MTM at the window-end bar is fine (terminal), no lookahead.

Finding B (silent failures / data validity):
- B1. Gap handling unspecified: "0 violations" is about bid≥ask; missing M1 bars (no tick) are not addressed. A missing minute could hide a touch. Fix: assert every minute in [entry, window end] for each pair exists; if gaps, treat as carry of last price or flag layers spanning gaps.
- B2. The parity is at a single X per arm; the selection ranges X=3..15. A fill rule validated at one point need not be valid across the range. Fix: (i) assert fill_count(X) is non-increasing in X (must hold: to reach entry+X you cross entry+X' for X'<X; the entry-minute window is common to all X, so no violation is legitimate); (ii) split the parity confusion matrix by side and by sub-period.
- B3. "fill price = target, penetration 0.0" — verify the 0.0 is for the same window/pairs, not the earlier parity study.
- B4. The USD-per-pip median is derived from the same scalps whose results are being reported; it's a global constant per pair so it's fine for ranking, but it must be computed from GROSS price P&L, not DEAL_PROFIT if that field already nets commission/swap. Read the actual MT5 field semantics — schema risk.
- B5. Swap sensitivity: window includes Wed 2026-09-16 (triple swap). Inferring a single per-night rate from total swap/rollovers averages the triple day in; applied uniformly it mis-weights. Fix: infer per-weekday or exclude the triple night.

Finding C (schema/semantics):
- C1. "slot-days (sum of layer hold time)" is mis-named: it is layer-days. If the guard limits SLOT occupancy, the denominator should be the union of layer intervals per slot, not the sum. Summing overlapping layer holds overstates occupancy and biases per-slot-day. Fix: rename; add true occupancy = (last close − first entry) per slot.
- C2. Arm from `slot`; pair from `symbol`. Ensure a slot maps 1:1 to arm across symbols (the preset naming opt/alt). If slot ids repeat across symbols, "arm from slot" is ambiguous. Verify mapping.
- C3. Comment regex `GRIND\|<slot>\|<side>\|L<nn>\|ENT` — ensure the deal comment also encodes the exit template for the live parity; the CloseBy pairing `#ent by #ext` must be parsed to get the ACTUAL exit price for rule A manuals; risk of mismatched pairing across days.
- C4. Commission accounting: "every exit fill ... 0.03" — but a scalp's exit is a CloseBy which is "free"; the 0.06 comes from entry(0.03)+exit-open(0.03). Make sure the exit-OPEN deal (the resting limit that becomes a position) is counted once, and the CloseBy not double counted. State the exact deal-type→charge table.
- C5. Holdout baseline ambiguity: X* selected on NET (and separately GROSS), but the holdout compares "net pips/day at X*" to "the better of the pair's two current live values." Which selection? And is the baseline the better single arm or the pooled current config? Ambiguous; fix wording.

Finding D (statistical/design):
- D1. Primary metric = net pips per DAY, but s12 says guard saturated and memo s7.1 says when the guard binds, per-SLOT is the right measure. The chosen primary is the metric whose fixed-entries assumption is most wrong under saturation, and it biases toward WIDE. Fix: make per-slot-day co-primary; report both; state the direction.
- D2. Fixed entries with saturated guard denies tight exits the extra entries they would free (biases toward wide). Listed as a bias but its direction is not stated. Fix: state direction.
- D3. Selection overfits: 4 calibration days/pair, 13 X, 8 pairs, plus gross+net. Fix: pool into the memo's groups, one X per group.
- D4. Disjoint/edge acceptable regions: "middle (round down)" undefined for multi-modal or boundary optima. Fix: require a contiguous run; if monotone, pick the knee not the middle.
- D5. Holdout baseline is contaminated: the "current live values" were derived (memo s2–s3) from the whole 9-day window, which includes the holdout days. So the acceptance bar is informed by holdout. Fix: recompute the live baseline on the calibration days only.
- D6. Comparison units mismatch: pooled X* (both arms) vs "better of two live values" (per arm). Fix: compare like-for-like.
- D7. MTM at a single terminal point in a mostly-underwater week biases toward narrow. Fix: report curve with and without the final day's MTM; extend window as days accrue.
- D8. Path-length difference: calibration entries (some 8 days of path) vs holdout (some 1 day) — the split is by entry date with a fixed window end, so calibration and holdout have different average horizons, and wider exits need horizon. Fix: normalize or at least report the horizon distribution per split. (Mild; the days interleave so it partly cancels.)
- D9. Multiple testing across 8 pairs × 2 metrics with only a 3-day holdout lacks power; a one-sided 90% bar will pass noise. Fix: state the effective false-acceptance rate, or use a stricter holdout threshold with wider bands.

Also mention: 90% "of the pair's maximum" uses a noisy max (max over 13 correlated points); using the max as the reference makes the acceptable set data-dependent. Fix: use a smoothed curve or the 90th percentile.

OK that's a lot. I'll write it up cleanly but not overwhelming. The user wants exhaustive. Let me produce a well-structured audit.

I'll be careful to say "smallest fix" for each of Q1-Q4.

Let me write the final answer.

I should note at the top that the CODE TO AUDIT block is empty, so this audits the two provided documents (the method is the artifact). I'll invite them to paste the replay script for a code-level pass.

Length: This is a detailed audit; a long answer is warranted. I'll use headers and bullets.

Let me write it.

## Final Report

# Audit — `EXIT_PIPS COUNTERFACTUAL` pre-registration + `geometry-cycle2-derivation.md`

**Scope note.** The `## CODE TO AUDIT` block is empty — no replay script, no `export_m1_bidask.mq5`, no parity harness was attached. Everything below audits the **method as specified** in the two documents (which, for a pre-registration, *is* the artifact that binds the result). If you paste the actual replay/parity code I will audit `s4` fill logic, the CloseBy pairing, the commission table and the pip conversion at the line level — several findings below (B4, C1–C5) are exactly the places where a silent implementation mismatch would hide.

I checked the arithmetic that is checkable: scalps sum to 612, 612+76+105 = 793 = 505+288, and every `scalps × net/scalp` in the memo s2 table reproduces the realised column in s6.2. The numbers are internally consistent. The problems are in the rules, not the sums.

---

## A. Fill rule / lookahead

**A1 — The primary entry-minute exclusion biases the curve toward wider exits. Not listed in s12.**
Excluding the entry minute removes a whole minute of path from *every* layer. That minute is where a tight exit (X=3–5) is most likely to fill, because the layer was just touched and the bounce is local. Wide exits (X=10–15) rarely fill in the first minute anyway, so they lose almost nothing. Net effect: `fill_count(X)` is understated at the tight end, so the per-day curve is flatter-to-worse on the left than reality. **Smallest fix:** stop treating S1 as a mere sensitivity — report `[primary, S1]` as a *bracket* on every curve and pick from the bracket, not from the conservative leg alone. State the direction in s12.

**A2 — S1 can register an impossible fill (within-bar lookahead).**
"Include the entry minute" uses the entry bar's `bid_high`/`ask_low`, but the entry itself happened at some second inside that bar. If the bar's high (bid) occurred *before* the entry second, S1 counts a sell-limit fill that happened before the layer existed. So S1 is an **upper bound**, not an estimate. **Smallest fix:** label S1 "optimistic bound," and where tick data exists for the window, shave the entry second; otherwise never present S1 as a point estimate.

**A3 — Fill time = start of fill minute understates hold.**
Up to 59 s short of the true hold, applied to every fill. It is constant across X so it largely cancels in comparisons, but it biases the *secondary* per-slot-day metric (a shorter denominator raises pips/slot-day). **Smallest fix:** use the bar midpoint for hold accounting, or state the ±1 min quantisation in the output table.

**A4 — MTM at the terminal bar is not lookahead.** It is the known end-of-window value; using `bid_close` for longs and `ask_close` for shorts is the correct side. No issue here beyond the statistical ones in D7.

---

## B. Silent failures / data validity

**B1 — Gap handling is unspecified; "0 violations" only checks bid≥ask.**
The window check is "0 violations, two identical export passes" — that validates bid/ask ordering, not completeness. An M1 bar with no tick (routine on NZDCAD, CADCHF, AUDNZD in dead hours) may be **absent**, not flat. If it is absent, `first minute where bid_high ≥ target` silently skips it and can miss a genuine touch (a level touched in the missing minute and left). **Smallest fix:** assert every minute in `[entry, window_end]` is present for each pair, then either back-fill from the last price or flag layers whose horizon spans a gap and report how many fills are gap-adjacent.

**B2 — Parity validates the rule at one X per arm; the study selects over X = 3…15.**
A fill model correct at X=7 can be biased at X=3 and X=15 and pass s9 cleanly (the errors just have to cancel at the tested point). This is the single most important verification gap. **Smallest fix (cheap, strong):** add the invariant **`fill_count(X)` must be non-increasing in X.** It is a theorem under the stated rule — to reach `entry+X` a resting limit crosses `entry+X′` for all X′<X, and the excluded entry-minute window is *the same minute for every X*, so the entry-minute exclusion does **not** license a wider X to fill where a tighter one did not. Any violation is a bug in the replay, full stop. And split the s9 confusion matrix by `side` and by sub-period so a time- or side-clustered error cannot hide in the aggregate.

**B3 — "penetration mean 0.0" provenance.** The "fill at target, no slippage" assumption is only as good as the statistic behind it. Confirm `exit_penetration_pips_mean 0.0` was measured on this window/pairs, not imported from an earlier study; if it is one regime it is a claim, not a guarantee.

**B4 — USD-per-pip median (schema risk).** "median of `profit / pips`" must use the **price P&L only**. In MT5, `DEAL_PROFIT` is price P&L and commission/swap are separate fields — good — but if the conversion is computed off a netted profit field, commission is double-counted into the pip value and then subtracted again in s7. Verify the exact field, and note the estimate is thin for CADCHF-ALT (12 scalps) and NZDCAD-ALT (17).

**B5 — Swap inference folds in the triple-swap day.** The window contains **Wed 2026-09-16**. "swap booked / rollovers crossed" averages the triple-Saturday charge into a single per-night rate, then applies it per night to every counterfactual hold. Overstates non-Wednesday nights and understates Wednesday. **Smallest fix:** infer the rate per weekday, or at minimum exclude the triple night from the rate and charge it explicitly to holds that cross Wednesday.

---

## C. Schema / semantics mismatches

**C1 — "slot-days" is mis-named and, as defined, overstates occupancy.**
s8 defines slot-days as *the sum of layer hold time*. A slot running four concurrent adds held 2 h each gives 8 "slot-hours" but the **slot was occupied 2 h**. If the guard limits *slots* (which is the whole point of the per-slot metric and the memo's s7.1 argument), the correct denominator is occupancy = `(last close − first entry)` per slot, not the sum over layers. As written it is "layer-days." **Smallest fix:** rename to layer-days; add true slot-occupancy-days; report both, and confirm occupancy saturates (s12 claims it does — this is how you check).

**C2 — "arm from slot."** If slot identifiers recur across symbols (e.g., slot 1 = OPT on every pair), `pair from symbol` + `arm from slot` is fine only if the mapping is verified. State the mapping table; a silent off-by-one there reassigns 793 layers to the wrong arm and no parity check would catch it because both arms pass.

**C3 — Manual-close price under rule A needs the paired exit.** The memo s2 says hold time is paired via the CloseBy comment `#ent by #ext` because ENT and EXT never share a `position_id`. Rule A must recover *the manual OUT price* the same way. Verify the pairing is 1:1 per layer over multiple days; a mis-pair assigns the wrong "actual manual price" and corrupts exactly the 76 layers rule A governs.

**C4 — Commission table must be explicit about deal *type*, or CloseBy gets double-counted.** The prose "a scalp costs 0.06, a manual 0.06, an open 0.03" is consistent with entry(0.03) + exit-open(0.03) for a scalp, and entry(0.03)+OUT(0.03) for a manual — but it only works if the resting-limit exit that becomes a *new position* is charged once and its later CloseBy is charged zero. Write the deal-type→charge map into the doc; the current wording ("Every exit fill and manual close is charged 0.03; CloseBy is free. A scalp costs 0.06") is one careless implementation away from charging the scalp 0.09.

**C5 — Holdout baseline is ambiguous in two ways.** (i) X* is selected twice (net rule and gross rule — s7 says report both); the holdout sentence says "net pips per day at X*" without saying which X*. (ii) The baseline is "the better of the pair's two current live values," i.e. a **per-arm** value, compared against a **pooled-across-arms** X*. Pooled and single-arm are not like-for-like. **Smallest fix:** define X*_net as the one tested; make the baseline the *pooled* current configuration (OPT-arm value at live-OPT-X + ALT-arm at live-ALT-X), or do the comparison per arm. Either way, spell it out.

---

## D. Statistical / design

**D1 — The primary metric is the one the memo says is wrong under the stated regime.** s12 says the guard is saturated *throughout*; the memo s7.1 says explicitly that when the guard binds, **per-slot-day is the right measure** and per-day is only right when it does not bind. The pre-registration makes per-day primary. Under saturation the per-day metric is exactly the metric with the worst fixed-entries bias. **Smallest fix:** make net-pips-per-slot-day co-primary and print both curves side by side; the sign of their disagreement is itself the finding.

**D2 — The "entries fixed" bias has a direction, and it points toward wide.** A tighter exit frees the slot sooner; with a saturated guard that admits more L0 re-entries and adds. Held fixed, the replay gives tight exits *zero* credit for the entries they would have admitted. Direction: understates tight, favours wide. s12 lists the bias but not its direction. **Smallest fix:** add one sentence ("this bias is one-way toward wider exits"). Combined with A1, that is **two independent unidirectional biases toward wide** in the primary metric — the reader cannot tell how much of a wide selection is bias.

**D3 — Selection is over-parameterised for the data.** 4 calibration days × 8 pairs, 13 X values, and two selections (gross + net). The memo itself (s7.4) recommended one exit per **group** (majors / EURGBP / AUD-CAD-CHF crosses / NZD). The pre-registration ignored that. **Smallest fix:** adopt the memo's groups and select one X per group; report per-pair curves only as diagnostics.

**D4 — "Middle value (round down)" is undefined for the cases that matter.** If the acceptable set (`net ≥ 0.9·max`) is disjoint (noise), or if the curve is monotone so *every* X is "within 90% of max," "middle" picks X=9 regardless of shape — arbitrary. **Smallest fix:** require the acceptable set to be a single contiguous run; if the curve is monotone over 3–15, report the boundary and refuse to pick a middle (the optimum is outside the tested range).

**D5 — The holdout baseline is contaminated by holdout data.** The two "current live values" were chosen from the 9-day measurement in the memo s2–s3, which *includes* the holdout days (11, 15, 17 Sep). So the acceptance bar is informed by the very days you are testing on — and it is a **one-sided** test against an inflated bar, i.e. anti-conservative. **Smallest fix:** recompute the live-value baseline on the calibration days only and use that as the holdout reference.

**D6 — Pooled vs per-arm unit mismatch.** See C5(ii).

**D7 — Terminal MTM in a book that is mostly underwater is a regime-loaded point.** Correct in principle (s7.1: without it a wide exit looks free), wrong as a single number. **Smallest fix:** report each curve twice — MTM at the 23:54 close, and MTM at a trailing VWAP of the last N hours (or excluding the final trading day) — so the reader sees the dependence on one moment. The memo's own remedy ("include days after 18-Sep as they accrue") should be the standing instruction.

**D8 — The by-entry-date split gives calibration and holdout different average horizons.** Entries on 10 Sep see 8 days of path; entries on 17 Sep see 1. Wider exits need horizon, so the fixed-window-end design systematically advantages the earlier entry days. The interleaving (10/14/16/18 vs 11/15/17) nearly cancels *on average* (~3.75 vs ~3.67 days), but report the horizon distribution per split so the reader can see it; do not silently assume it cancels.

**D9 — Power.** 288 holdout layers / 8 pairs ≈ 36 layers/pair, one-sided 90% bar. The effective false-acceptance rate across 8 pairs (and 2 metrics) is high; a "pass" here is weak evidence. **Smallest fix:** state the false-acceptance rate explicitly, or require the holdout band to be *narrower* (e.g. 95%) when the calibration acceptable set was contiguous, and wider when it was not.

**D10 — The 90%-of-max reference is a noisy max.** The reference is the max over 13 correlated points on ~63 layers/pair; the max is the most overfit statistic available. **Smallest fix:** reference a smoothed curve (e.g. 3-point median over X) rather than the raw max.

---

## Answers to the four s13 questions (smallest fix each)

**Q1 — Unlisted bias toward wider or narrower?** Yes, two unlisted, and both are toward **wider**: (a) the entry-minute exclusion (A1) removes the tight-edge's best fill window; (b) the fixed-entries assumption under a saturated guard denies tight exits the re-entries they would free (D2 — listed as a bias, but its direction is not). A third, toward **narrow**, is rule A capping wide-exit upside by forcing the operator's manual close (s5) — covered by S2 but its direction is unstated. **Smallest fix:** add three sentences to s12 giving the *direction* of each, and present the primary/S1 bracket (A1).

**Q2 — Is the 95% parity threshold strict enough?** Not the number — the **coverage**. Parity tests one X per arm; the result is used over X=3…15. **Smallest fix:** add the monotonicity invariant `fill_count(X)` non-increasing in X (it is a theorem under this rule; any violation is a bug) and split the confusion matrix by side and sub-period. Keep 95%, or tighten to 97% now that the counters are cheap.

**Q3 — Is the selection rule robust to seven days?** No — 4 calibration days/pair, 13 values, 8 pairs, two metrics. **Smallest fix:** select one X per the memo's own **group** (majors / EURGBP / AUD-CAD-CHF / NZD) and require the acceptable set to be contiguous (D3, D4). Report per-pair only as a diagnostic.

**Q4 — Is terminal MTM right for open layers?** Right in principle, wrong as a single point in a uniformly underwater week — it biases the selection toward narrow. **Smallest fix:** print every curve with MTM at the close **and** at a trailing VWAP (or excluding the final day) so the sensitivity is visible; keep "never drop a layer" as the rule.

---

## Bottom line

Nothing here is fatal. The frozen inputs, the commission accounting, the fill side (bid for the long exit, ask for the short exit) and the MTM sides are all correct. The material concerns are: **two unidirectional biases toward wide exits** in the primary metric (A1 + D2), a **primary metric whose own memo says it is the wrong one under the stated saturated regime** (D1), **parity that validates a point but is used as a curve** (B2 — fix with the monotonicity invariant), a **contaminated holdout baseline** (D5), and the **"slot-days" metric that is mis-named and overstates occupancy** (C1). Each has a one-line fix above. Fix those five, keep the rest, and the pre-registration is publishable.

Paste the replay + parity scripts and I will audit the implementation: the entry-minute index arithmetic, the CloseBy `#ent by #ext` pairing, the deal-type→commission map, and the `DEAL_PROFIT`-vs-commission field usage are the four places a silent mismatch would corrupt everything downstream without failing a single s9 check.

<!-- finish_reason=stop -->
