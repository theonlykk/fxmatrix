# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. We have code snippets, no docs. Need reason deeply. Need identify what breaks when removing add==2*width, changing stranded convention, new checks, effective threshold claim, floor formula for current presets, invariants/reconstruction.

We need inspect code for assumptions. We only have fxgrind.mq5, grind_pure.mqh, grind_engine.mqh. Not state/recon/config/comment. But enough? Need audit questions:

1 Does anything else in ea/ assume add == 2 x width?
- GRIND_ADD_WIDTH_MULTIPLE only in validation, error print. Search in provided code: macro used in OnInit error string and pure. No other code uses multiple. But maybe tests? Not provided. Need infer.
- But geometry: L0 legs at mid ± width. Add target from deepest entry ± add. If add != 2*width, lattice gone. Does exit queue rely on add spacing relative to width? Need inspect Grind_ExitQ... maybe ranks/target formulas. Not included fully? In engine includes grind_exitq.mqh (not provided), but Grind_ExitQ functions used. Need know whether exitq assumes add spacing. Provided only calls. We can audit visible assumptions.

2 Effective recentre threshold really width + deadband? Let's derive.

Grind_TryRecenterOppositeL0:
- l0 pending on opposite side, depth 0.
- resting = order price open (L0 initially placed at straddle from mid at placement). dist_pips = |resting - current_mid| pips.
- gate: dist > stranded_thresh_pips.
- target = straddle price from current_mid: if long: mid - width; if short: mid + width.
- clamp maybe changes target.
- marketability check: for long, target must be < ask (buy limit below ask); for short target > bid (sell limit above bid). Usually yes if width > spread/2.
- deadband check: if |resting - clamped| < deadband_pips -> return. So modify only if new target at least deadband from old.

They claim effective threshold = width + deadband. Let's check: resting = mid_old ± width (for opposite side). target = mid_new ± width. Difference target - resting = mid_new - mid_old (same sign side? For long target = mid_new - width; resting = mid_old - width. Difference = mid_new - mid_old. For short: target = mid_new + width; resting = mid_old + width; diff = mid_new - mid_old). Absolute difference = |mid_new - mid_old|. Deadband gate needs |mid_new - mid_old| >= deadband (strictly not within: Grind_PriceWithinDeadband returns |target-resting| < band -> return; so modify allowed if >= deadband). Stranded gate is dist = |resting - current_mid|. For long resting = mid_old - width. dist = |mid_old - width - mid_new|. If mid moved down (for long side resting below old mid) then current mid < resting, dist = mid_old - width - mid_new = (mid_old - mid_new) - width. Gate dist > stranded. Combined with deadband requiring mid_old - mid_new >= deadband. Then dist = drift - width. Gate requires drift - width > stranded => drift > width + stranded. Wait for long with mid moved down. If mid moved up, resting below mid, dist = mid_new - (mid_old - width)= drift + width, always > stranded likely. But can target be marketable? For long buy limit target = mid_new - width. If mid moved up, target above old resting; could be close to ask? Buy limit must be < ask. If mid_new - width < ask, yes if width > half-spread. But deadband? Difference = drift, so if drift >= deadband, modify. If mid moved up, the resting buy limit is now further below market; it may be "stranded" in sense far from mid? dist = drift + width, gate opens quickly, but target move up. However recenter only when opposite side flat. Hmm.

Let's read ADR claim: "A re-quote needs the gate open (dist > stranded) AND the new price at least deadband from the old, which needs dist >= width + deadband." That seems suspect. Let's derive generally. Resting is stale L0 placed at old mid ± width. New target at current mid ± width. Distance from current mid to resting = |(old_mid ± width) - new_mid|. Distance from target to resting = |new_mid ± width - (old_mid ± width)| = |new_mid - old_mid|. Deadband requires target-to-resting >= deadband => |Δmid| >= deadband. But the gate uses dist_mid_pips = |resting - current_mid|, not |Δmid|. These are not same. Let Δ = new_mid - old_mid. For same side sign s = +1 for sell at mid+width? Let's set resting = old_mid + s*width where s = +1 for short sell (opposite_is_long false), s=-1 for long buy. Current mid = old_mid + Δ. dist = |resting - current_mid| = |s*width - Δ|. deadband requires |target-resting| = |Δ| >= deadband (since target = current_mid + s*width, difference = Δ).

So need |s*w - Δ| > stranded and |Δ| >= deadband. The claim "needs dist >= width + deadband" is wrong in general. Let's solve worst case? If Δ has opposite sign to s, i.e., mid moved away from the resting side? For long s=-1 resting = old_mid - width. If Δ > 0 (mid up), dist = |-w - Δ| = w + Δ, so dist >= w + deadband automatically once Δ>=deadband. If Δ < 0 (mid down), dist = | -w - Δ| = |Δ + w|? Wait s=-1: resting = old_mid - w. current = old_mid + Δ. dist = |old_mid - w - old_mid - Δ| = | -w - Δ| = |w + Δ|. If Δ negative and |Δ| < w, dist = w - |Δ|. Gate requires w - |Δ| > stranded => |Δ| < w - stranded. That conflicts with |Δ| >= deadband if deadband >= w - stranded. Combined: deadband <= |Δ| < w - stranded, possible if deadband < w - stranded. Wait the ADR says effective threshold width + deadband, but here drift needed is < width - stranded, not >=. Let's be careful.

They say effective threshold = width + deadband. For EURGBP width 3, deadband 4, stranded 6. width+deadband=7. They observed churn? Wait if stranded=6, width=3, deadband=4. Condition to modify: dist > 6 and |Δ| >=4. dist = |w + Δ * sign?| Let's derive for long: resting = old_mid - w. dist = |old_mid - w - (old_mid+Δ)| = | -w - Δ| = |w + Δ|. Gate: |w+Δ| > 6. With w=3, |3+Δ| >6. If Δ negative (mid down), 3+Δ negative if Δ<-3; |3+Δ| = -3-Δ >6 => -Δ >9 => Δ < -9 (drift down >9). If Δ positive, 3+Δ >6 => Δ>3. So gate opens if Δ > 3 or Δ < -9. Deadband requires |Δ| >=4. So if Δ > 3 and >=4 (Δ >=4), modify; if Δ < -9, modify. Effective threshold: Δ > 4 (for up) or Δ < -9 (for down). Not width+deadband=7. Hmm.

For short: resting = old_mid + w. dist = |old_mid + w - (old_mid+Δ)| = |w - Δ|. Gate >6. If Δ positive, w-Δ negative for Δ>3, |...|=Δ-3>6 => Δ>9. If Δ negative, 3-Δ >6 => -Δ>3 => Δ<-3. Deadband |Δ|>=4. So modify if Δ<-4 or Δ>9. So effective drift thresholds are asymmetric: in direction away from resting? Actually if market moves toward the resting order's side? Let's define: For long resting below mid. If mid falls toward/through resting, gate may close because dist decreases. Wait if mid falls, resting - current = -w - Δ? Example old mid 100, long buy at 97 (w=3). New mid 95 (Δ=-5): resting=97, dist=2, gate false. New mid 90 (Δ=-10): dist=7, gate true. Deadband |Δ|=10 >=4, modify target to 87. So it re-quotes after market has moved well below the resting order (catching down). For Δ positive, new mid 105: resting 97, dist=8, gate true, deadband 5>=4, target 102. But wait target 102 is above old mid 100 and close to current mid 105. Buy limit at 102 < ask? ask ~105+spread, yes. So modify buy limit up. So threshold up is Δ>3 (gate) and Δ>=4 (deadband) -> Δ>=4. Down threshold is Δ<-9 (gate and deadband automatically if >9). So effective threshold is not width+deadband uniformly. The ADR's claim seems wrong. Need verify.

But maybe they define dist as |resting - mid| and new price at least deadband from old "needs dist >= width + deadband" maybe assuming target is on same side and price moves toward resting? Let's solve condition for modify perhaps they consider only when market moved against resting? Let's derive condition for both gates:
For a long L0 at old_mid - w. To have target (new_mid - w) at least deadband from old (old_mid - w): |new_mid - old_mid| >= d. To have gate open: |old_mid - w - new_mid| > s. These are two conditions on Δ. The intersection is not "dist >= width+deadband". If we require dist > s and |Δ| >= d. The minimum |Δ| that satisfies both depends on direction. It can be as low as d if d > s - w? Let's derive all.

Let Δ = new - old. dist = |w + s?| For long resting = old - w, dist = | -w - Δ| = |w+Δ|. For short resting = old + w, dist = |w - Δ|. Gate requires |w ± Δ| > s. Deadband requires |Δ| >= d.

If s = width? Then for long gate |w+Δ| > w. This holds if w+Δ > w => Δ>0, or w+Δ < -w => Δ < -2w. So gate open for any upward move >0? Wait if Δ small positive, dist = w+Δ > w, yes true! That means with stranded = width (not 2x), gate is true at placement? At placement Δ=0, dist = w, gate requires > w false exactly, but any upward move >0 opens. Downward move must exceed 2w. So not permanently open unless stranded < width. ADR says "when stranded < width the gate is true at placement and never goes false". If stranded < width, at Δ=0 dist=w > stranded true. Then as mid moves, dist = |w+Δ|. It goes false when |w+Δ| <= stranded. That requires w+Δ between -stranded and stranded => Δ between -w-stranded and stranded-w. Since stranded < w, upper bound negative? stranded-w <0. Lower -w-stranded. So there is an interval of Δ negative (downward for long) where gate false. But at placement and for Δ >=0 true. So not never goes false; but if market moves up, gate remains true. The deadband then controls. The ADR says flat side's L0 follows mid in deadband steps. Yes.

But their effective threshold claim: "A re-quote needs the gate open (dist > stranded) AND the new price at least deadband from the old, which needs dist >= width + deadband." They might reason: if target moved by deadband, then distance from mid to old resting must be at least width + deadband? Let's test: old resting at mid_old - width. New target at mid_new - width. If new target is deadband below/above old resting, |mid_new - mid_old| = deadband. Distance from new mid to old resting = |mid_old - width - mid_new|. If mid moved up by d, distance = width + d. If mid moved down by d, distance = |width - d|. So not always width+deadband. The minimum distance from mid to old resting after a deadband move is |width - deadband|, not width+deadband. Actually if d >= width, distance = d - width. So gate could be open at smaller |Δ| in one direction.

Let's see their EURGBP example: width 3, deadband 4. If mid moves up 4 pips (for a long resting below), dist = 3+4=7 > stranded 6 -> gate open, modify. Effective threshold 4 pips, not 7. If mid moves down 4 pips, dist = |3-4|=1 <6 -> gate closed. To modify down, need Δ < -(stranded+width)? Wait dist = |w+Δ|. For Δ negative, dist = |w - |Δ||. To exceed s, need |w - |Δ|| > s. If |Δ| < w, dist = w - |Δ| <= w. To be > s, need w - |Δ| > s => |Δ| < w - s. If s > w, impossible. If s < w, possible for small |Δ|, but deadband requires |Δ| >= d. So if d > w - s, no downward modify. If |Δ| > w, dist = |Δ| - w > s => |Δ| > w + s. So downward threshold is w+s. Upward threshold is max(d, s-w) roughly. For s=2w (old), upward threshold max(d, w) = 2w if d<=w? For w=5,d=4,s=10: Δ > max(4, -5?) gate |5+Δ|>10 -> Δ>5 or Δ<-15. So up threshold 5 (deadband 4, gate 5) = w, not 2w. Wait with old stranded=10, add=10, width=5, deadband=4. If mid moves up 5, dist=10, gate >10 false (strict). Need >5? Actually |5+Δ|>10 => 5+Δ>10 => Δ>5. So Δ>5. Deadband >=4. So effective up threshold 5 (width), down threshold 15 (3w). That contradicts ADR claim "every other pair it is 10" (they said effective threshold width+deadband = 5+4=9? Wait they wrote "For EURGBP that is 7 pips of mid drift against a 3-pip quote; for every other pair it is 10." Let's parse: "The effective threshold is width + deadband, not stranded. ... For EURGBP that is 7 pips of mid drift against a 3-pip quote; for every other pair it is 10." For every other pair width=5, deadband=4? width+deadband=9, not 10. Hmm maybe they mean add=2*width=10? Actually "for every other pair it is 10" might be 2*width? If width=5, 2*width=10. But they say width+deadband = 5+4=9. Inconsistent. Maybe deadband=5? Wait EURGBP width 3, deadband 4, stranded 6. width+deadband=7. They said effective threshold is width + deadband, not stranded. For EURGBP that is 7. For every other pair it is 10. That implies width=6? Or width+deadband=10 => deadband=5 if width=5. Maybe presets have deadband=5? In ADR: "EURGBP at width 3 gives 6 > 7 FALSE" for 2x width > width + deadband. That is 6 > 7 false. So width+deadband=7. For width >=5, "2 x width > width + 4" => 2w > w+4 => w>4. So they assume deadband=4 for every other pair. Then width+deadband = 5+4=9, not 10. Yet they wrote "for every other pair it is 10." Maybe they mean stranded = 2*width =10 for width 5. But they specifically say effective threshold width+deadband. Contradiction. Let's re-read ADR evidence:

"The effective threshold is `width + deadband`, not `stranded`. A re-quote needs the gate open (`dist > stranded`) AND the new price at least `deadband` from the old, which needs `dist >= width + deadband`. For EURGBP that is 7 pips of mid drift against a 3-pip quote; for every other pair it is 10. Cycle 3 would have taken EURGBP to width 2, dropping it to 6. Hence the floor in Decision 2: at width 2 it yields stranded 7, and it changes nothing on any pair whose `2 x width` already clears it."

Wait "For EURGBP that is 7 pips of mid drift against a 3-pip quote; for every other pair it is 10." If width=5, deadband=4, width+deadband=9. Unless deadband=5 for others. Maybe presets have deadband 5? The code default InpDeadbandPips=4.0. But presets could be 5. ADR says "EURGBP at width 3 gives 6 > 7 FALSE" uses deadband 4. For width 5: 2*width=10 > width+deadband = 9 if deadband 4. So 10 > 9 true. They then say "for every other pair it is 10" maybe they mean stranded (2*width) is 10, not effective threshold. The sentence is ambiguous: "The effective threshold is width + deadband... For EURGBP that is 7... for every other pair it is 10." That suggests they think effective threshold for others is 10, i.e., width+deadband=10, so deadband=5. But then the condition 2x width > width+deadband for width 5 would be 10 > 10 false, not true. They wrote "2 x width > width + 4 for every width >= 5" so they use deadband 4. Then effective threshold for width 5 is 9. So the "10" is just wrong or refers to stranded. This is a red flag.

Need audit systematically.

Let's identify assumptions in code that add == 2*width. Search all occurrences of width/add both? In engine, width used only for L0 straddle and recenter. add used only for add targets and add near market. No direct relation. But there could be invariants in state/recon. Not provided. We need say cannot fully verify, but visible code doesn't assume. However there are indirect geometry assumptions:

- Grind_AddTargetNearMarket(clamped, mid, add_pips): returns |target - mid| <= add_pips price + eps. This is used to determine `near_market` for slot reservation. If add is smaller than distance from deepest entry to mid? It's just comparing target to mid. No width relation.
- ExitQ ranks and target formula may assume spacing? Not provided. But exit target is per layer entry ± exit. ExitQ may require certain number of layers/rank. With add != 2w, ladder spacing changes, but exitq probably operates on ranks and entries. Could break if add < exit? If add spacing less than exit? Let's think.

Cycle 3 geometry: width 5, add 4, exit 10. L0 legs at ±5. Adds every 4. If long L0 fills at mid-5, add target at entry -4. Exit at entry+10. So after add fills, deepest entry lower; next add target lower by 4. Exit for each layer at entry+10. If add=4 and exit=10, then when deepest layer's exit at entry+10, the previous layer's exit at entry_prev+10 = (entry+4)+10 = entry+14. So exits are spaced 4 apart too. The exit queue may place exits only for some ranks. This seems okay.

But if add < exit? There might be "add target near market" uses add pips to decide near_market for slot. If add is small, target near mid? Not a problem.

Potential issue: `Grind_AddTargetNearMarket` takes add_pips, and `Grind_ComputeAddTarget` uses deepest entry. If add != 2w, the add target can be on the same side of mid as L0? For long, L0 at mid-width. Add target at L0 - add. If add < 2w? Actually L0 at mid-w. Add at mid-w-add. Distance from mid = w+add. If add < w? It's still below mid. If add >? Always below mid. So no cross.

But recenter: the opposite side L0 is at mid ± width. When one side has layers and other flat, the flat side L0 may be recentered. With add != 2w, the filled side's deepest entry could be at mid ± (w + k*add). The flat side L0 at mid ∓ width. They don't interact.

What about invariants? `Grind_CheckBookInvariants` not provided. It may check that orders are at expected prices? Maybe it checks L0 at mid ± width? Or add spacing? Need mention not visible. But ADR asks "does anything else in ea/ assume add == 2 x width". We can search code for `GRIND_ADD_WIDTH_MULTIPLE`, only in pure and fxgrind error. So no direct compile-time assumption. But there may be tests or reconstruction that use comment labels only. Reconstruction likely from orders/comments, not geometry. So removing equality likely doesn't expose invariant unless invariants check price relationships.

The new fatal check: `stranded_thresh_pips > width_pips + deadband_pips`. But `Grind_ValidateAddWidthRelationship` is called before magic lock, and `InpDeadbandPips` is not passed to validation. The new check as described in ADR: "New OnInit check, fatal: stranded_thresh_pips > width_pips + deadband_pips". But the current `Grind_ValidateGeometryInputs` only takes width, exit, max_layers, stranded, add. It does not take deadband. `Grind_ValidateAddWidthRelationship` only takes width, add. So to implement check, need pass deadband. The ADR says "New OnInit check, fatal" but not where. The audit should note that current signature cannot enforce it; need change. More importantly, the proposed check uses strict `>` but the recenter gate is strict `>` and deadband check is strict `<`. Let's align boundaries.

The ADR testing says: `stranded` at `width + deadband` exactly (reject) and one point above (accept). Wait check is `stranded_thresh_pips > width_pips + deadband_pips` fatal. So if stranded == width+deadband, check `>` false -> accept. But testing says "at width + deadband exactly (reject) and one point above (accept)". That is opposite of the check as written! Let's read: "New OnInit check, fatal: stranded_thresh_pips > width_pips + deadband_pips. Below that bound the stranded gate is permanently open..." Wait if stranded <= width+deadband, gate condition? They say below that bound the stranded gate is permanently open. But they also say check fatal if stranded > width+deadband. That means they want to reject stranded greater than bound? That contradicts "Below that bound the stranded gate is permanently open and the deadband becomes de facto control." Let's analyze.

They want to ensure stranded > width + deadband? Actually from their derivation: effective threshold = width+deadband. If stranded < width+deadband, then the gate opens before deadband permits, so deadband controls. That's what they call "gate permanently open" (from perspective of deadband). They want to prevent `stranded < width+deadband` because then stranded doesn't bind. They want stranded >= width+deadband? Wait their floor: `stranded = max(2 x width, width + deadband + 1)`. That ensures stranded > width+deadband. So they want stranded to be strictly greater than width+deadband. Thus fatal check should be `stranded <= width + deadband` (or `< width+deadband+1`), not `>`. But the ADR text says "New OnInit check, fatal: stranded_thresh_pips > width_pips + deadband_pips". That would fail when stranded is sufficiently large, exactly the safe case. This is a severe sign error. Let's re-read context:

"New OnInit check, fatal:
    stranded_thresh_pips > width_pips + deadband_pips
Below that bound the stranded gate is permanently open and the deadband becomes the de facto control. Failing at startup makes the mistake impossible to ship."

Actually "Below that bound" refers to below `width+deadband`? If the check is fatal when `stranded > width+deadband`, then below that bound (<=) is allowed? No, fatal when >, so allowed when <=. But they say below that bound the gate is permanently open, which is the mistake. So they have inverted the inequality. They should fail when `stranded_thresh_pips <= width + deadband_pips` (or `< width+deadband+1` to enforce strict). The Testing section confirms: "`stranded` at `width + deadband` exactly (reject) and one point above (accept)." That means reject when equal, accept when above. So the check should be fatal when `stranded <= width + deadband`. The Decision text has `>` likely typo. This is a major audit finding.

Also note: the floor formula `max(2 x width, width + deadband + 1)`. If deadband is 4, width 3: max(6, 3+4+1=8) = 8. But ADR says "EURGBP at width 3 gives 6 > 7 FALSE" and "at width 2 it yields stranded 7". Wait floor for width 2, deadband 4: max(4, 2+4+1=7) = 7. Yes. For width 3: max(6, 8) = 8. But they said EURGBP already runs width 3, stranded 6, and it has been below bound. Under new convention, if they apply floor, EURGBP should become 8, not 6. The ADR says "Nothing changes for today's fleet. Every live preset satisfies both the new range check (ratio exactly 2.0) and the new stranded bound (2 x width > width + 4 for every width >= 5; EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions)." Wait they claim nothing changes for today's fleet, but then admit EURGBP fails the bound. That means EURGBP is not unchanged; either it fails startup (if check enforced) or if they don't enforce? The ADR says new OnInit check is fatal. If implemented as intended (reject when <=), EURGBP with width 3, deadband 4, stranded 6 would be rejected: 6 <= 7, fatal. That contradicts "Nothing changes for today's fleet." They note "EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions" but Open Questions not included. This is a critical inconsistency: the proposed fatal check would prevent EURGBP from starting on Monday, unless its preset is updated to stranded 8. The ADR claims nothing changes for today's fleet, but it does for EURGBP. And the Evidence section says EURGBP already churns because it's below bound. So the ADR is proposing to fix it, but then says nothing changes. Contradiction.

Also the floor formula: `stranded = max(2 x width, width + deadband + 1)`. For current presets with width >=5, 2*width >=10, width+deadband+1 = width+5. For width 5: max(10,10)=10. 2*width = 10, width+deadband+1 = 10. So stranded = 10, which is not strictly greater than width+deadband=9. The ADR wants `stranded > width+deadband`. For width 5, deadband 4: 2*width=10 >9, so okay. The floor gives 10. For width 3: 2*width=6, width+deadband+1=8, gives 8. But current EURGBP has 6. So if they apply the new convention, EURGBP changes to 8. If they don't apply, it fails the new fatal check. Either way, "nothing changes" is false.

Wait, the floor formula uses `width + deadband + 1`. Why +1? Because inputs are doubles, not necessarily integer pips. The check is `>` not `>=`. To ensure `stranded > width+deadband`, they add 1. But if deadband is 4, width 3, 2*width=6, floor gives 8. That's a big jump. But they said "at width 2 it yields stranded 7" (2+4+1=7). For width 3, it yields 8. So EURGBP would need stranded 8, not 6. That would change recenter behavior significantly. The ADR's "Nothing changes for today's fleet" is false for EURGBP.

Also the claim "2 x width > width + 4 for every width >= 5" is true for width >4. But for width=3, false. EURGBP width=3. So it's the exception. They acknowledge but then say nothing changes. Audit should highlight.

Now, effective recentre threshold. Let's derive precisely and compare to ADR claim. We need see if `width + deadband` is correct. We already found it's not generally. Let's formalize.

In `Grind_TryRecenterOppositeL0`:
- `resting` = price of opposite L0 order.
- `current_mid` = mid now.
- `dist_pips = |resting - current_mid| / pip`.
- Gate: `dist_pips > stranded_thresh_pips`.
- `target` = straddle opposite side from current_mid: if long, `current_mid - width`; if short, `current_mid + width`.
- `clamped` may alter target due to stops/ask/bid. Assume no clamp.
- Deadband: `Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point)` returns true if `|clamped - resting| < deadband`. If true, return. So modify only if `|clamped - resting| >= deadband`.

Let `s = +1` for short (sell at mid+width), `s = -1` for long (buy at mid-width). `resting = mid0 + s*width`. `target = mid1 + s*width`. `Δ = mid1 - mid0`. Then `target - resting = Δ`. Deadband requires `|Δ| >= d`.
`dist = |resting - mid1| = |mid0 + s*w - mid1| = |s*w - Δ|`.
For short s=+1: dist = |w - Δ|. Gate: |w - Δ| > S.
For long s=-1: dist = |-w - Δ| = |w + Δ|. Gate: |w + Δ| > S.

Case short:
- If Δ >= 0 (mid up): dist = |w - Δ|. For Δ <= w, dist = w - Δ. Gate > S => w - Δ > S => Δ < w - S. Since S typically >= w (to avoid permanent open), w - S <=0, impossible for Δ>=0. For Δ > w, dist = Δ - w. Gate > S => Δ > w + S. So upward drift must exceed w + S.
- If Δ < 0 (mid down): dist = w - Δ = w + |Δ|. Gate > S => |Δ| > S - w. Since S >= w, this is always true if S>w? Actually if S=2w, S-w=w, so |Δ|>w. If S=w, |Δ|>0. Combined with deadband |Δ| >= d. So downward drift threshold is max(d, S - w). For S=2w, max(d, w). So short modifies on downward drift of >= max(d, w) pips.

Case long:
- Δ > 0 (mid up): dist = w + Δ. Gate > S => Δ > S - w. Combined with deadband: Δ >= max(d, S - w). For S=2w, max(d, w).
- Δ < 0 (mid down): dist = |w + Δ|. For |Δ| <= w, dist = w - |Δ|. Gate > S => w - |Δ| > S => |Δ| < w - S. Since S>=w, impossible. For |Δ| > w, dist = |Δ| - w. Gate > S => |Δ| > w + S. Combined with deadband: |Δ| >= w + S. For S=2w, |Δ| > 3w.

So the recenter is directional: it re-quotes when the market moves **toward** the resting order (for long, market falls; for short, market rises) by more than `S - w` (or deadband), and when market moves **away** from the resting order (for long, market rises; for short, market falls) by more than `S + w`. Wait let's map: For short, resting is above mid (sell limit). If market moves up (Δ>0), it moves toward the resting sell order? Actually sell limit is above mid; if market rises, it approaches the sell limit. That's toward. Gate for Δ>0 requires Δ > w + S (large). If market moves down (Δ<0), it moves away from sell limit; gate requires |Δ| > S - w (small). So it re-quotes more readily when market moves away from the resting order? Let's check: short L0 at mid+5. Market drops 5 pips (Δ=-5). New mid = old-5. Resting = old+5. dist = 10. S=10. Gate >10 false (strict). If S=10, need |Δ| > S - w = 5, so Δ<-5 (e.g., -6) -> dist=11 >10. Deadband d=4 satisfied. Target = new mid +5 = old. So sell limit recentered to old mid. So when market drops, the sell limit is far above; it moves it down to follow mid. When market rises, resting sell limit is approached; if market rises 15, dist = |5 - 15| = 10, not >10; need >15. So it doesn't chase up as readily. This asymmetry is not captured by `width + deadband`.

What does ADR claim? "A re-quote needs the gate open (dist > stranded) AND the new price at least deadband from the old, which needs dist >= width + deadband." This is false. The deadband condition is about `|Δ|`, not `dist`. The relationship between `dist` and `Δ` is `dist = |w ± Δ|`. The minimum `dist` for a given `|Δ|` is `||Δ| - w|`. So to have both `dist > S` and `|Δ| >= d`, the required `|Δ|` is:
- If `S >= w`, then either `|Δ| > S + w` (moving away? actually one direction) or `|Δ| > S - w` (the other direction), with deadband floor.
- The threshold is not `w + d`. For EURGBP w=3, d=4, S=6: thresholds are downward for short: max(4, 6-3=3) = 4; upward: > 6+3=9. So effective thresholds 4 and 9, not 7. For long: upward max(4,3)=4; downward >9. So one direction 4, other 9. The ADR says 7. Wrong.

The ADR's evidence table shows EURGBP churn. The actual thresholds explain why churn is bursty: when market moves away from the flat side's L0 by just 4 pips, the deadband allows a modify, and the gate is open if S < w? Wait for EURGBP S=6, w=3. For short, downward move Δ=-4: dist = |3 - (-4)| = 7 >6, deadband |Δ|=4 >=4, so modify. So threshold 4 pips. For upward move Δ=+10: dist = |3-10|=7 >6, deadband 10>=4, modify. So threshold 10? Actually Δ>9. So it re-quotes on a 4-pip drop or a 10-pip rise. That's asymmetric. The ADR's "effective threshold 7" is wrong and understates the sensitivity in one direction. This explains 139 modifies: small adverse moves of 4 pips trigger modify. The deadband alone isn't the control; the gate opens easily in one direction because stranded=6 < w+d? Wait gate condition for downward: dist = w + |Δ| = 3+4=7 >6, so yes gate open. So even though stranded=6, a 4-pip move away opens gate. The ADR's floor of stranded=7 for width 2 would make downward threshold? w=2, S=7, d=4. Downward (short): dist = w + |Δ| = 2+4=6, not >7. So no modify at 4 pips. Need |Δ| > S - w = 5. So threshold 5. Upward: need Δ > S + w = 9. So floor changes churn. But the ADR claims floor at width 2 gives stranded 7 and changes nothing on pairs whose 2x width clears it. For width 2, 2x=4, floor gives 7. So it changes EURGBP if width drops to 2.

But the critical audit point: the effective threshold is not `width + deadband`; it's direction-dependent: `max(deadband, stranded - width)` for moves away from the resting order, and `stranded + width` for moves toward it (with deadband floor). Let's derive general condition:

Let `r` be the side: for long (buy limit below mid), resting = mid0 - w. For short, resting = mid0 + w. Let `Δ = mid1 - mid0`.
For long:
- Gate: `| -w - Δ | > S` => `|w + Δ| > S`.
- Deadband: `|Δ| >= d`.
For short:
- Gate: `|w - Δ| > S`.

We can express in terms of direction relative to resting. Let `x = Δ` for long? Better to define `m = mid1 - mid0`. The distance from new mid to old resting is `|w ± m|`. The condition `|w ± m| > S` and `|m| >= d`.
The solution set for `m`:
For long: `m > S - w` or `m < -(S + w)` (if S>w; if S<w, also m > - (S+w)? Let's just say).
For short: `m < -(S - w)` or `m > S + w`.
So the threshold for moving in the direction that increases distance from the resting order (long: m negative; short: m positive) is `S - w` (floor d). The threshold for moving toward the resting order (long: m positive; short: m negative) is `S + w` (floor d). Wait for long, m negative means mid down, resting below mid, distance increases: threshold `-(S+w)`? Let's test long w=5, S=10. m=-10: dist = |5-10|=5, not >10. Actually long resting = mid0 - w. If mid1 = mid0 - 10 (m=-10), dist = |mid0 - w - (mid0 -10)| = |10 - w| = 5. That's smaller. So moving down toward the resting order? Wait resting is below mid. If mid falls, it approaches the resting buy limit. So m negative is toward the resting order. m positive (mid rises) moves away from the buy limit (which is below). For m positive, dist = w + m. Gate > S => m > S - w. So away threshold S-w. For m negative, dist = |w + m|. For |m| > w, dist = |m| - w. Gate > S => |m| > S + w. So toward threshold S+w. So:
- Long: away (mid up) threshold max(d, S-w); toward (mid down) threshold S+w.
- Short: away (mid down) threshold max(d, S-w); toward (mid up) threshold S+w.

Thus the minimum drift to trigger a recenter is `max(d, S - w)`, not `w + d`. The ADR claims `w + d`. For S=2w, `S-w = w`, so threshold = max(d, w). For w=5, d=4, S=10: threshold = max(4,5)=5. ADR says width+deadband=9. For w=3, d=4, S=6: threshold = max(4,3)=4. ADR says 7. So ADR overestimates threshold by a lot. This means the recenter is more sensitive than claimed, especially for small width. The floor formula `max(2w, w+d+1)` ensures S > w+d, but the effective threshold is still max(d, S-w). With floor, S >= w+d+1 => S-w >= d+1, so threshold = S-w for away direction. So floor makes away threshold S-w, which is at least d+1. But it doesn't make threshold w+d; it makes it S-w. For w=2, d=4, S=7: away threshold = 5. Toward threshold = 9. So min threshold 5. The ADR's "effective threshold width+deadband = 6" is wrong; actual min is 5. For w=3, d=4, S=8 (floor): away threshold = 5, toward = 11. ADR says 7. So the floor does not control to width+deadband.

The new fatal check `stranded > width + deadband` (if corrected) ensures S > w+d. Then away threshold S-w > d, so deadband is not the binding constraint; the gate binds. Toward threshold S+w > 2w+d. So the check prevents deadband from dominating in the away direction. But the ADR's derivation of effective threshold is still wrong. The check should be `stranded > width + deadband` to ensure `S - w > deadband`, i.e., gate binds before deadband in the away direction. That matches their intent: "Below that bound the stranded gate is permanently open and the deadband becomes the de facto control." Actually if S <= w+d, then S-w <= d, so the away threshold is max(d, S-w) = d. So deadband controls. If S > w+d, then S-w > d, so gate controls. So the bound `S > w+d` is correct for ensuring gate binds in the away direction. But their stated effective threshold `width+deadband` is not the actual threshold; it's the bound for S. The actual away threshold is `S-w`. The ADR confuses the bound with the threshold. This is a major statistical/mechanical flaw. The floor `max(2w, w+d+1)` ensures S > w+d, so gate binds. But the effective threshold is `S-w`, which for S=2w is w. So for width 5, d=4, S=10, away threshold = 5. The ADR claims 9/10. That means the recenter triggers on 5-pip drift, not 9. This could increase API usage, not decrease, if cycle 3 changes add but leaves stranded=2w. Wait cycle 3 proposes width 5, add 4, stranded 10 (from testing: "A cycle-3 geometry (width 5, add 4, exit 10, stranded 10) starts clean."). With w=5, S=10, d=4: away threshold = max(4, 10-5=5) = 5. So recenter triggers on 5-pip move. The ADR says effective threshold is 10 (or 9). So the cycle-3 geometry will recenter more often than they think. This is a critical audit finding: the proposed geometry may not reduce churn; it may increase it, because the gate opens at width (5) in one direction. For EURGBP, width 3, S=6, away threshold 3? Actually max(4, 6-3=3) = 4, so deadband dominates. So EURGBP churn at 4 pips. With floor S=8, away threshold max(4, 5)=5. So churn reduces from 4 to 5 pips. But not to 7.

Let's verify with the actual code's strict inequalities. `Grind_ShouldRecenter`: `dist_mid_pips > thresh_pips`. `Grind_PriceWithinDeadband`: `MathAbs(target - resting) < band` -> return. So modify if `dist > S` and `|Δ| >= d`. For away direction, dist = w + |Δ|. Condition: w + |Δ| > S => |Δ| > S - w. Deadband: |Δ| >= d. So threshold = max(d, S-w) with care for strict. If S-w is integer, need > S-w, so next point. The ADR's floor adds +1 to S, so S-w = d+1, then threshold = d+1. So away threshold = S-w (if S-w > d). For cycle 3 w=5, S=10, d=4: S-w=5 >4, so threshold = 5 (strict >5? Actually S-w=5, need >5, so 6? Let's compute: w=5, S=10. Away: dist = 5 + |Δ|. Gate >10 => |Δ| >5. So |Δ| = 5.1 triggers. Deadband >=4. So threshold just over 5 pips. If pips are integer, 6 pips. So effective threshold ~6 pips, not 10. The ADR says 10. Big difference.

For EURGBP w=3, S=6, d=4: away: dist = 3 + |Δ|. Gate >6 => |Δ| >3. Deadband >=4. So threshold 4 pips (since |Δ|>=4). So deadband controls. That matches evidence: 4-pip drift triggers modify. The ADR says effective threshold 7, but actual is 4. This explains why EURGBP churns: it's not that 2x width > width+deadband false (6>7 false), but that the away threshold is max(deadband, S-w)=4. The bound S > w+d would be 6 > 7 false, so gate does not bind; deadband binds. If S were 8, away threshold = max(4, 5)=5. So raising S to 8 reduces threshold from 4 to 5. Not huge.

Wait, if S=6, w=3, d=4: S-w=3. Deadband 4. So threshold 4. If S=8, S-w=5, deadband 4 -> threshold 5. So floor raises threshold by 1 pip. The ADR thinks it raises from 7 to 8? No, they think effective threshold is width+deadband=7, and floor makes stranded 8. So they think threshold goes from 7 to 8. Actually it goes from 4 to 5. So the churn reduction is modest, but the ADR's reasoning is off.

Now, does the proposed floor formula hold for every current preset? Let's compute for current presets if known. We don't have all presets. ADR mentions EURGBP width 3, stranded 6, deadband 4. Others width >=5, ratio 2.0, so add=2w, stranded=2w? They say "InpStrandedThreshPips equals the old add (= 2 x width) in every preset today." So for width 5, stranded=10. Deadband likely 4 (default). Floor: max(2w, w+4+1) = max(10, 10) = 10. So unchanged. For width 3, floor: max(6, 8) = 8. So current EURGBP preset would not satisfy the new convention if it is applied. The ADR says "Nothing changes for today's fleet. Every live preset satisfies both the new range check ... and the new stranded bound (2 x width > width + 4 for every width >= 5; EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions)." This is self-contradictory: it admits EURGBP fails the bound. If the new fatal check is implemented, EURGBP fails startup. If the check is not implemented for existing presets, then the ADR's "fatal" check is not enforced. The "Open Questions" might address whether to update EURGBP preset. But as written, the decision says fatal check, so it breaks EURGBP.

Also the floor formula uses `width + deadband + 1`. If deadband is not an integer (it's double, default 4.0), adding 1 is arbitrary. The check is `stranded > width + deadband`. To ensure strict `>`, if all are doubles, you don't need +1; you can set stranded = max(2w, width+deadband) and check `>=`? But they want strict. The +1 is a magic number assuming pips are integer and the minimum increment is 1 pip. But `InpStrandedThreshPips` is a double; it could be set to 7.5. The code compares doubles. The floor formula `max(2w, w+d+1)` may be overly conservative and changes behavior. Also if deadband is e.g. 4.5, +1 gives 5.5 offset. Not a principled bound.

Now, the new range check: `0.5 <= add/width <= 4.0`. Does this expose any geometry the invariants or reconstruction cannot handle? Consider `add` < `width`. The L0 legs at ±width. Adds at deepest entry ± add. If add < width, the add ladder is tighter than the initial straddle. Could the add target be inside the opposite L0? For long side, L0 at mid-width. Add at L0 - add. Opposite short L0 at mid+width. They don't cross. But what about the exit queue? If add is very small relative to exit, you could stack many layers quickly. Max layers limits. If add is 0.5*width, and width=5, add=2.5. Exit=10. The deepest layer's add target is 2.5 below previous entry. The exit target for deepest is entry+10. The previous layer's exit is entry+2.5+10 = entry+12.5. So exits are spaced 2.5. ExitQ may place exits only for certain ranks. If many layers, exit orders may be close. But no direct invariant.

What if `add` > `exit`? Range allows add up to 4*width, and exit could be small. If add > exit, then when a layer fills, its exit target is above its entry (for long) by exit. The next add target is below entry by add. So exit of new layer is below exit of previous? Actually long: L0 entry E0. Add target E0 - add. Exit for L0 = E0 + exit. If add > exit, then when add fills at E1 = E0 - add, its exit = E1 + exit = E0 - add + exit < E0. So the new layer's exit is below the previous layer's entry. This could affect exit queue ranking? ExitQ might require exits to be placed in a certain order. The ADR doesn't mention exit. The range check only constrains add/width, not add/exit. The ADR's testing includes "A cycle-3 geometry (width 5, add 4, exit 10, stranded 10) starts clean." But add=4, exit=10, okay. However the range check allows add=20, width=5, exit=10. Then add > exit. Does the engine handle that? Let's see `Grind_ComputeAddTarget`: anchor deepest entry, target = anchor - add (long). `Grind_AddTargetNearMarket`: |target - mid| <= add. If add is large, target far from mid. `Grind_SendNextAddEnt` clamps to marketability: for long buy limit, `clamped` must be < ask. If add is huge, target far below mid, clamped may be target (since target < bid? Actually buy limit below mid, so target < bid < ask, marketable). It will place a buy limit far below. That's fine. But exit for that layer at target+exit. If exit is 10, exit is still below current mid maybe. It might be placed as sell limit above? For long, exit is sell limit at entry+exit. If entry is far below mid, exit might still be below mid, so sell limit would be below bid, not marketable? `Grind_ExitQManageSide` places exit via `Grind_PlaceLimit` without checking marketability? It uses `Grind_ExitQClampPassive` maybe clamps. Not provided. But if exit target is below current bid, a sell limit below bid is invalid (sell limit must be above bid? Actually sell limit must be above current price? For a sell limit, price must be above ask? MT5 requires sell limit price >= ask + stops. If exit target is below bid, it's marketable and would be rejected or clamped). The exitq clamp pass likely handles. But with add very large, exit targets for new layers may be far below market, causing many clamped promotions. The ADR's range check allows add/width up to 4, e.g., width=1, add=4. Then L0 at mid-1, add at L0-4 = mid-5. Exit at mid-5+10 = mid+5. That's okay if exit=10. But if exit=2, exit at mid-3, below mid. Could be problematic.

But the audit task specifically: "does removing the equality check expose any geometry the invariants or reconstruction cannot handle." We need identify any code that assumes add and width produce a certain ordering of prices. Let's inspect invariants not provided. But we can reason from visible code: `Grind_ValidateAddLabelIndex` only checks label index equals computed depth. `Grind_SideNextIndex` uses max layer_index +1. Layer index is from comment, assigned at placement. If add != 2w, the layer labels still increment by 1. No geometry.

However, there is a subtle issue: `Grind_ComputeAddTarget` uses `Grind_FindDeepestLayerArrayIndex` which finds max `layer_index`. If layers are not filled in order? The add target is always based on deepest layer entry. If add spacing changes, the deepest layer is the one with max layer_index. That's fine.

What about `Grind_TryRecenterOppositeL0`? It only recenters the opposite L0 when the other side has depth >0. The recenter target is based on `width`, not `add`. So if add != 2w, the flat side L0 remains at ±width from mid. The filled side's layers are at mid ± (width + k*add). The recenter may bring the flat side L0 closer to or further from the filled side's layers. Could it cross? For long filled side, layers below mid. Opposite short L0 is above mid. Recenter targets short L0 at mid+width. Always above mid. Layers are below mid. No crossing. If add is negative? No, add>0. So no crossing.

But what if `add < width`? Then the filled side's add targets are closer to mid than the initial L0? For long, L0 at mid-w. Add at L0 - add = mid - w - add. If add < w, then mid - w - add > mid - 2w? Actually it's further below. Wait mid - w - add is more negative than mid - w. So add is further away from mid. So ladder goes downward. The flat side short L0 at mid + w. No interaction.

What if `add` is small and many layers fill? The deepest entry could be far below mid. The recenter of flat side L0 uses current mid, so it stays at mid+w. The distance between flat side L0 and deepest filled entry increases. No crossing.

So geometry likely safe.

Now, the new check `stranded > width + deadband` is fatal. But the code's `Grind_ValidateAddWidthRelationship` is called before `InpDeadbandPips` is used. To implement, need pass deadband. Also the check should be in `Grind_ValidateGeometryInputs` maybe. But note: `Grind_ValidateGeometryInputs` is also used in `Grind_TestOnInitGeometryCheck`, a test stub, which does not check add-width relationship nor stranded bound. If they add the new check only in `fxgrind.mq5`, the test stub may not enforce it, causing tests to pass while live fails. The ADR says tests first, but the test stub `Grind_TestOnInitGeometryCheck` does not include the add-width check currently. So any test using that stub won't catch the new fatal check unless updated. This is a testing gap.

Also, `Grind_ValidateAddWidthRelationship` is in `grind_pure.mqh` and currently returns bool. The ADR changes it to range check. But the error print in `fxgrind.mq5` still says `InpAddPips != GRIND_ADD_WIDTH_MULTIPLE x InpWidthPips`. That error message will be wrong. Minor.

Now, the ADR says "The simulator diverges from the EA". That's outside code.

Let's look for other assumptions. The macro `GRIND_ADD_WIDTH_MULTIPLE` is used only in validation and error print. If they change validation to range, the macro might be removed or kept for error? Not important.

Search in engine for `width_pips` usages: 
- `Grind_TryRecenterOppositeL0` uses width.
- `Grind_OnTickEngine` computes buy_target/sell_target with width.
- `Grind_StraddleBuyPrice/SellPrice`.
No other. `add_pips` used in:
- `Grind_ApplyEntryHorizon` floor_price = add_pips.
- `Grind_ComputeAddTarget`.
- `Grind_AddTargetNearMarket`.
- `Grind_SendNextAddEnt`.
- `Grind_EnsureAddNext`.
- `Grind_OnTickEngine` passes add.
- `Grind_TryPlaceAddAtFill`.
No relation.

But note: `Grind_ApplyEntryHorizon` uses `floor_price = Grind_PipsToPrice(add_pips, _Point)`. It computes `dist = |add_target - mid|`. Then `in_floor = dist <= floor_price + eps`. This logic assumes that when the add target is within `add_pips` of mid, it is at the "floor" (closest allowed). Actually `add_target` is deepest entry - add. The distance from mid to add_target could be anything. `in_floor` is true if the add target is within `add` pips of mid. That means the market has moved close to the add target. This is used for entry horizon. It uses `add_pips` as a distance threshold. If add != 2w, this still works as a distance threshold. But note: `Grind_AddTargetNearMarket` also uses `add_pips` as threshold. So if add is smaller, these thresholds smaller. No direct width relation.

Potential issue: `Grind_ApplyEntryHorizon` computes `H_price = entry_horizon_pips`. If `entry_horizon_pips` is set relative to add? Not in ADR. Not relevant.

Now, the effective recentre threshold claim is the big one. Let's double-check with actual code: `Grind_StrandedDistMidPips(resting, current_mid, _Point)` returns `MathAbs(resting_price - current_mid) / (point * 10.0)`. So dist is distance between resting order price and current mid. The gate is `dist > stranded`. The deadband check uses `Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point)`. `clamped` is the new target price. So yes, it's `|target - resting| < deadband`. So the ADR's statement "A re-quote needs the gate open (dist > stranded) AND the new price at least deadband from the old, which needs dist >= width + deadband" is mathematically wrong. Let's produce a concrete counterexample with their numbers. EURGBP: width=3, stranded=6, deadband=4. Suppose mid moves from 100 to 96 (down 4 pips). For short side (opposite), resting = 103. current_mid=96. dist = 7 > 6, gate open. target = current_mid + 3 = 99. |99-103| = 4, deadband check: 4 < 4? false (since strict <), so modify allowed. Thus a 4-pip mid drift triggers a modify. The ADR says effective threshold is 7 pips. So they are off by 3 pips. This is exactly why EURGBP churns: 4-pip moves trigger. With stranded=8, resting=103, current_mid=96, dist=7 not >8, so no modify. At current_mid=95, dist=8 not >8, no. At 94, dist=9 >8, target=97, |97-103|=6 >=4, modify. So threshold becomes 6 pips down. So raising stranded to 8 reduces churn from 4 to 6 pips. Still not 7.

Thus the ADR's evidence section misdiagnoses the cause: it says "For EURGBP that is 7 pips of mid drift... Cycle 3 would have taken EURGBP to width 2, dropping it to 6. Hence the floor... at width 2 it yields stranded 7". But actual threshold for width 2, stranded 6? If width 2, stranded 6, deadband 4: away threshold = max(4, 6-2=4) = 4. So still 4. Floor at width 2 gives stranded 7: away threshold = max(4, 7-2=5) = 5. So floor raises threshold from 4 to 5, not from 6 to 7. The ADR's numbers are all shifted.

Also, the ADR says "The effective threshold is width + deadband, not stranded." Actually the effective threshold is `max(deadband, stranded - width)` for the away direction, and `stranded + width` for the toward direction. The bound `stranded > width + deadband` ensures `stranded - width > deadband`, so the away threshold becomes `stranded - width`. So the effective threshold is not `width + deadband`; it's `stranded - width` (once gate binds). The ADR confuses the condition for gate binding with the threshold itself. This is a significant analytical error.

Now, does the proposed floor formula hold for every current preset? We need compute. Current presets: ratio add=2w. stranded = old add = 2w. Deadband? ADR says "EURGBP runs width 3, stranded 6, deadband 4". For others, likely deadband 4 (default). The floor formula: `max(2w, w+4+1)`. For w>=5, 2w >=10, w+5 <= 2w? For w=5: 10 vs 10 -> equal. For w>5: 2w > w+5. So floor yields 2w. So for w>=5, stranded=2w unchanged. For w=4: max(8, 9)=9. If any preset has width 4, it would change from 8 to 9. For w=3: max(6, 8)=8. So EURGBP changes from 6 to 8. The ADR claims "Nothing changes for today's fleet" but that's false if EURGBP is live. It says "EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions." So they are aware but not resolving. The audit should flag that the ADR cannot be accepted as "nothing changes" while also adding a fatal check that EURGBP fails. Either the check is not fatal for existing presets (contradicting Decision 3) or EURGBP must be updated (changing behavior).

Also, the new range check `0.5 <= add/width <= 4.0` allows add/width = 0.5. If width=5, add=2.5. The floor formula for stranded: max(2w=10, w+deadband+1=10) = 10. So stranded=10. Effective recenter away threshold = max(d, S-w) = max(4, 5) = 5. So with add=2.5, the add ladder is tighter than the recenter threshold? Not directly related. But consider: if add < width, the add targets are closer to the initial L0? Actually add=2.5, width=5. L0 at mid-5. First add at mid-7.5. Second add at mid-10. The recenter threshold for opposite side is based on width 5 and stranded 10: away threshold 5. So if mid moves 5 pips, the opposite L0 is recentered. Meanwhile the filled side's add targets are at mid-7.5 etc. No interaction.

What about the invariants? There may be an invariant that checks that L0 orders are exactly at mid ± width. If mid moves, L0 is not recentered unless opposite side has depth. That's existing. The new geometry doesn't change that.

Could removing add==2w break `Grind_ExitQ`? Let's think about exit queue ranks. `Grind_ExitQManageSide` ranks entries and decides which layers require exits. If add spacing is different, the rank thresholds might be based on entry prices. But the code uses `Grind_ExitQRanks(entries, layer_indices, n, is_long, ranks)`. Not provided. Could it assume that entry prices are equally spaced by add? Possibly. If add != 2w, the entries are still equally spaced by add (since each add is anchor - add). So the spacing is uniform per side. The initial L0 is at mid-w, first add at mid-w-add. So the spacing between L0 and first add is add. All subsequent adds are spaced by add. So the ladder is uniform with spacing `add`. The only non-uniformity is between the two L0 legs (2w apart) and the add spacing (add). But per side, spacing is uniform `add`. So exitq likely doesn't care about width. It might care about add spacing? If it uses entry prices to rank, uniform spacing is fine. If it assumes spacing == exit? Not sure.

What about `Grind_ComputeAddTarget` when the deepest layer is not the one with max layer_index? It uses `Grind_FindDeepestLayerArrayIndex` which finds max `layer_index`, not max/min price. If add != 2w, layer_index still increments. The deepest layer is the last added. Its entry is the lowest for long. So add target is entry - add. That's correct.

Potential issue: `Grind_SendNextAddEnt` checks `if(is_long && !Grind_BuyLimitMarketable(clamped, ask)) return false;` and for short `!Grind_SellLimitMarketable(clamped, bid)`. If add is very small, the add target may be very close to mid. For a long, add target = deepest entry - add. If the deepest entry is already below mid by a lot, add target is even lower, so it's marketable (buy limit below ask). If add is large, add target far below, marketable. So no issue.

What if add is so large that the add target is above mid? For long, add target = entry - add. Entry is below mid. If add is larger than entry's distance below mid, add target could be above mid. But entry is at least mid-w (L0). The first add target is mid-w-add. If add < w, it's below mid. If add > w, it could be above mid? mid-w-add > mid if -w-add >0 => add < -w, impossible. So add target is always below mid for long, because entry <= mid (actually L0 at mid-w, adds below). So add target always below mid. For short, above mid. So marketable.

Now, the new check `stranded > width + deadband` is fatal. But the code's `Grind_TryRecenterOppositeL0` uses `stranded_thresh_pips` and `deadband_pips`. If `stranded` is only just above `width+deadband`, the away threshold is `stranded - width`, which is just above `deadband`. So the deadband is nearly binding. That's intended. But note the strict inequalities: `Grind_ShouldRecenter` uses `>`, `Grind_PriceWithinDeadband` uses `<`. So if `stranded = width + deadband + epsilon`, the away threshold is `deadband + epsilon` (strict >). The deadband check allows if difference >= deadband. So the gate is the binding constraint. Good.

But the ADR's proposed check says `stranded > width + deadband`. If `stranded` is exactly `width + deadband`, away threshold is `deadband` (gate requires > deadband, deadband allows >= deadband). So deadband binds. So the check should be `stranded >= width + deadband`? Actually they want to fail when `stranded <= width+deadband` because then deadband binds. So fatal should be `stranded <= width + deadband`. Their text says `>`. The Testing section says reject at exactly `width+deadband` and accept one point above. So fatal should be `stranded <= width+deadband` (reject) and accept `>`. So the Decision text is inverted. This is a clear bug.

Also, the floor formula `max(2 x width, width + deadband + 1)` ensures `stranded >= width+deadband+1`, so it passes the corrected check. But if deadband is 4.0 and width is 3.0, floor gives 8.0. The check `stranded > width+deadband` => 8 > 7 true. Good. But the ADR says "at width 2 it yields stranded 7". For width 2, deadband 4: max(4, 2+4+1=7) = 7. Check: 7 > 6 true. So floor passes. But the ADR's testing says "stranded at width + deadband exactly (reject) and one point above (accept)". If width=2, deadband=4, width+deadband=6. Floor gives 7, which is one above. So that matches.

Now, what about the range guard `0.5 <= add/width <= 4.0`? Does it keep ADR-125's drift protection? A typo of 40 instead of 4 would give ratio 10? If width=1, add=40 -> ratio 40 >4, fails. Good. But the band is quite wide. If a preset has width=5, add=2.5 (ratio 0.5), that's allowed. Is that sane? The ADR says "sane band". But does anything assume add > width? Let's check `Grind_ApplyEntryHorizon`: `floor_price = add_pips`. `in_floor = dist <= floor_price`. If add is small, floor is small, so entry horizon logic may place adds only when very close to mid? Not sure. But not a direct invariant.

What about `Grind_AddTargetNearMarket(clamped, mid, add_pips)`: returns true if add target within add pips of mid. If add is small, near_market is harder to satisfy, so slot reservation may block. Not a bug.

Now, let's look for any tests or code that might assume `add == 2*width` in the not-provided files. The ADR mentions `scripts/grid_sim_v7_real_signal.py`. That's outside ea/. But audit task says "does anything else in ea/ assume add == 2 x width". We can only see provided files. In provided files, only `GRIND_ADD_WIDTH_MULTIPLE` and error message. So answer: no other direct assumption in visible code. But indirect assumptions via geometry? The uniform lattice is used by recenter? The recenter uses width only. The add ladder uses add only. So no.

However, there is a potential issue in `Grind_TryRecenterOppositeL0`: it only recenters the opposite L0 if the other side has depth > 0. The recenter target is based on `width`. If add != 2w, the filled side's layers are at prices that may not align with the recentered L0. But that's aesthetic.

What about the invariants? `Grind_CheckBookInvariants` might check that the number of layers on a side is consistent with the distance from mid? Or that L0 is at mid ± width? If it checks that the L0 price is within some tolerance of the straddle price, then when mid moves and L0 is not recentered (because other side has depth), the invariant might fail? But that's existing behavior. The invariant probably doesn't check L0 price against current mid because L0 is allowed to be stranded until recenter. Not sure.

Potential invariant: `Grind_ValidateAddLabelIndex` checks computed depth equals label index. That's independent.

Reconstruction: `Grind_ReconstructState` reads orders and comments. It likely reconstructs layers from comments. It doesn't need add/width. But if add != 2w, the reconstruction might try to infer layer_index from price? The code uses comment labels. So no.

Now, the ADR's claim "Nothing changes for today's fleet" is false for EURGBP. Also, the new fatal check if implemented as written (`stranded > width + deadband`) would fail every current preset? Let's check: current presets have stranded = 2w. For width 5, stranded=10, width+deadband=9. 10 > 9 true. So the check as written (`stranded > width+deadband`) would **pass** (not fatal) for width 5. For EURGBP width 3, stranded=6, width+deadband=7. 6 > 7 false. So the check as written (`if stranded > width+deadband then fatal`) would **not** fire for EURGBP because 6 > 7 is false. Wait the check is fatal if `stranded > width+deadband`. For EURGBP, 6 > 7 is false, so it would **not** fail. That means the check as written allows the bad case (6 <= 7) and would only fail the good cases (e.g., if someone sets stranded=20). That's completely backwards. The ADR's Decision text says "fatal: stranded_thresh_pips > width_pips + deadband_pips". That would fail when stranded is too high, not too low. They then say "Below that bound the stranded gate is permanently open and the deadband becomes the de facto control." So they want to fail below that bound. So the inequality is inverted. If implemented literally, it would not catch EURGBP, and would reject safe large stranded values. This is a critical bug.

The Testing section confirms they intend to reject at `width+deadband` exactly and accept one above. So the fatal condition should be `stranded <= width + deadband` (or `<` if they want to allow equality? They say reject at exactly, so `<=`). So the Decision text is wrong.

Also, the floor formula uses `max(2 x width, width + deadband + 1)`. For current presets with width 5, deadband 4: max(10, 10) = 10. This satisfies `stranded > width+deadband` (10 > 9). So it passes the corrected check. For EURGBP width 3: max(6, 8) = 8. 8 > 7, passes. So if the floor is applied, EURGBP preset must be updated to 8. But the ADR says "InpStrandedThreshPips follows WIDTH, not add, with a floor: stranded = max(2 x width, width + deadband + 1)". That means the EA itself computes stranded? Or the preset must be set to that? The input is `InpStrandedThreshPips`. The ADR says "follows WIDTH" meaning the convention for setting presets, not that the EA overrides the input. The EA does not compute it; it's an input. The code checks `stranded_thresh_pips > 0` and now would check bound. So the preset must be updated. The ADR says "Nothing changes for today's fleet" but the floor would change EURGBP to 8 if they follow the convention. They might not update it, then it fails the new check (if corrected). Either way, inconsistency.

Let's examine the "Evidence" section more: "EURGBP runs width 3, stranded 6, deadband 4 -- so 2 x width (6) does NOT exceed width + deadband (7), and it has been below the bound since deployment." So they know EURGBP is below bound. They then say "The --l0churn view ... counts 139 modifies ...". They argue this is because effective threshold is width+deadband. They want to fix by floor. But then "Nothing changes for today's fleet" is false because EURGBP must change. They even say "EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions." So Open Questions likely asks whether to update EURGBP. But the Decision says fatal check, which would prevent EURGBP from starting if not updated. The ADR cannot be approved as is without resolving this.

Now, let's consider if the new range check allows `add == width`? Ratio 1.0 allowed. Then L0 at mid-w, first add at mid-2w. The spacing between L0 and first add is w. The uniform lattice with spacing w? Actually L0 legs at ±w, so spacing between L0 legs is 2w. First add on long at mid-2w. The short L0 at mid+w. So the lattice is not uniform. But no mechanical issue.

What about `Grind_ExitQ` if add < exit? Let's think about exit queue rank logic. It likely places exits for layers based on rank: e.g., only the best-ranked layer gets an exit, others held. If add is small, many layers can be placed, but exits may be limited. The max_layers limits. Not a direct break.

Potential issue: `Grind_ApplyEntryHorizon` uses `add_pips` to define `floor_price`. If add is small, the floor is small, so `in_floor` only when add target within small distance of mid. This affects when adds are placed. If add is large, floor is large. This is independent of width.

Now, the audit task asks: "does removing the equality check expose any geometry the invariants or reconstruction cannot handle." We need hypothesize about invariants. Since we don't have `grind_state.mqh`, `grind_recon.mqh`, we can't be exhaustive. But we can note that the provided code does not contain any other geometry assumption. The invariants likely check order book consistency (e.g., no overlapping orders, exit orders exist for layers). With add != 2w, orders may be spaced differently but not overlapping. The only potential overlap is if `add` is very small, the add targets could be closer than the minimum stops level, causing clamp and possibly invalid prices. The range check allows add/width as low as 0.5. If width=1, add=0.5. On a 5-digit symbol, 0.5 pips = 5 points. Stops level might be e.g., 5 points. So add target could be within stops level of market, causing clamp. That's handled by `Grind_Adr013ClampBuy/Sell`. But it could cause the add target to be clamped to a different price, breaking the uniform ladder. If add is too small, the clamp may place orders at the same price multiple times, leading to label mismatches? Let's see: `Grind_SendNextAddEnt` computes `add_target`, clamps to `clamped`. If clamp changes the price, the actual placed order price may not be `anchor - add`. The next add target is computed from the deepest layer's actual entry price (from deal fill), so the clamp doesn't affect the anchor for the next add? Actually `Grind_ComputeAddTarget` uses `side.layers[depth_idx].entry_price`, which is the actual fill price. So if the first add was clamped and filled at a different price, the next add is based on that fill price. So the ladder spacing may not be uniform. But that's existing behavior even with add=2w. The range check doesn't prevent this.

What about `Grind_AddTargetNearMarket` and `near_market` slot reservation? If add is small, `near_market` is true only if add target within add pips of mid. This could allow more orders? Not sure.

Now, let's consider the new fatal check `stranded > width + deadband`. If implemented in `OnInit`, it needs `InpDeadbandPips`. But `InpDeadbandPips` is an input with default 4.0. The check would be:
```
if(InpStrandedThreshPips <= InpWidthPips + InpDeadbandPips) { fail }
```
This would fail EURGBP (6 <= 7). So if the fleet deploys this EA, EURGBP won't start. That's a breaking change. The ADR says "Nothing changes for today's fleet" but it does. The Open Questions likely addresses whether to update EURGBP preset. But as written, it's a contradiction.

Also, the check should be in `Grind_ValidateGeometryInputs` or a new function. The current `Grind_ValidateGeometryInputs` takes `stranded_thresh_pips` but not `deadband`. So they must modify signatures. The test stub `Grind_TestOnInitGeometryCheck` does not call `Grind_ValidateAddWidthRelationship` nor the new check. So tests using the stub won't test the new checks unless updated. The ADR's Testing section says "Tests first, and they must fail before the change". But the existing test stub won't fail because it doesn't include the checks. So they need to add the checks to the stub or write new tests. This is a testing gap.

Now, let's formulate the audit findings.

We need produce a quantitative audit report. Structure:
1. Direct assumptions of add == 2*width: only `GRIND_ADD_WIDTH_MULTIPLE` in validation and error print. No other code in provided files uses the relation. However, the uniform lattice is relied upon by the recenter logic? No, recenter uses width only. Add ladder uses add only. So removing equality is mechanically safe in visible code. But we cannot verify invariants/reconstruction. Need mention missing files.

2. Effective recentre threshold: The ADR claims `width + deadband`. This is false. Derive actual condition. Let Δ = mid drift, w = width, S = stranded, d = deadband. The modify occurs if `|w ± Δ| > S` and `|Δ| >= d`. The minimum drift to trigger is direction-dependent: `max(d, S - w)` when moving away from the resting L0, and `S + w` (with deadband floor) when moving toward it. For EURGBP w=3, S=6, d=4: away threshold = max(4, 3) = 4 pips, not 7. This explains the churn. The ADR's bound `S > w + d` is the condition for the gate to bind over the deadband in the away direction, but the effective threshold is `S - w`, not `w + d`. The ADR conflates the two. This is a critical analytical error that invalidates the floor rationale and the claimed churn reduction.

3. Floor formula and current presets: Current presets have S = 2w. For w >=5, 2w >= w+4+1? Let's compute: w=5: 10 >= 10, so floor = 10. For w>5, 2w > w+5, floor = 2w. For w=3, floor = max(6, 8) = 8. EURGBP currently has 6, so it fails the new convention. If the new fatal check is corrected to reject S <= w+d, EURGBP (6 <= 7) fails startup. If the check is left as written (fatal when S > w+d), it fails to catch EURGBP and instead rejects safe large S. Either way, "nothing changes for today's fleet" is false. Also, if any preset has width 4, floor gives max(8,9)=9, changing from 8. Need know presets. The ADR says six of eight pairs need add != 2w, so there are at least 8 pairs. We don't have all widths. The claim "every width >=5" may not cover all. The ADR itself says "six of eight pairs need an add that is not twice their width". That means at least six pairs have add != 2w under cycle 3. But current presets all have add=2w. So current presets pass the range check. The stranded bound: for current presets, S=2w. The condition S > w+d is 2w > w+d => w > d. For d=4, w>4. So any pair with width <=4 fails. EURGBP width 3 fails. If there are other pairs with width 4, they fail too. The ADR only mentions EURGBP, but may be others. So the floor changes those.

4. New range check exposes geometry: The range `0.5 <= add/w <= 4.0` allows add < w and add > exit. No visible invariant breaks, but the range check does not constrain `add` relative to `exit` or `deadband`. If `add` is very small, the add ladder may be tighter than the deadband, causing frequent modifies? Actually `Grind_EnsureAddNext` uses deadband to decide whether to modify an existing add order. If add is small, the add target may move by less than deadband, so it won't modify. That's fine. If add is large, the add target may move far, causing modifies. Not an invariant break. However, the range check's upper bound 4.0 with width=1 gives add=4. If exit=10, fine. But if exit is small, say exit=2, add=4, then add > exit. As discussed, the new layer's exit target could be below the previous layer's entry, potentially causing exit queue rank inversions. The ADR does not test add > exit. The testing only includes cycle-3 (add=4, exit=10). So the range check may allow geometries that break exit queue assumptions. We need flag that the range check should also constrain `add` vs `exit` or `deadband`. But without exitq code, we can't be certain.

5. Testing stub gap: `Grind_TestOnInitGeometryCheck` does not call `Grind_ValidateAddWidthRelationship` nor any stranded bound check. So the new fatal checks cannot be tested via the existing stub. The ADR's test plan requires tests to fail first, but the stub would pass. This is a process/implementation gap.

6. Error message mismatch: The OnInit error print still references `GRIND_ADD_WIDTH_MULTIPLE` and equality, which will be misleading.

7. The fatal check signature: `Grind_ValidateGeometryInputs` does not take `deadband`, so adding the check requires changing interfaces. If placed in `fxgrind.mq5`, it's fine, but the pure test stub won't cover it. Also, the check should use strict `>` as per testing, but Decision says `>`. Need clarify.

8. The ADR's claim "The floor exists because the EFFECTIVE threshold is not stranded alone -- see the evidence section." But the evidence section's derivation is wrong. So the floor's justification is flawed. The actual effective threshold is `max(d, S-w)`, so to ensure the gate binds, we need `S > w + d`. The floor `max(2w, w+d+1)` ensures this for w>0? Let's check w=1, d=4: max(2, 6)=6. S=6 > 5, yes. So floor ensures `S > w+d`. But the actual threshold becomes `S-w`, which for w=1, S=6 is 5, not 6. The ADR thinks threshold is w+d=5. Actually it is S-w=5. So it matches in this case? Wait w=1, d=4: w+d=5. S=6. Actual away threshold = max(4, 6-1=5) = 5. So threshold = w+d = 5. For w=3, d=4: w+d=7. S=8. Actual away threshold = max(4, 8-3=5) = 5. Not 7. So the ADR's threshold formula only accidentally matches when S-w = w+d => S = 2w+d. The floor gives S = max(2w, w+d+1). For w >= d+1, 2w >= w+d+1 => w >= d+1. For w=3, d=4, w < d+1, so floor gives w+d+1 = 8. Then S-w = d+1 = 5. So actual threshold = d+1 = 5. The ADR says effective threshold = w+d = 7. So it's off by w-1. For w=3, off by 2. So the floor does not achieve the claimed threshold; it achieves `S-w`, which is smaller.

In summary, the ADR's core arithmetic is wrong. The effective threshold is not `width + deadband`. The correct condition for the gate to bind is `stranded > width + deadband`, but the resulting threshold is `stranded - width` (away) and `stranded + width` (toward). The floor sets `stranded` to at least `width+deadband+1`, so the away threshold becomes at least `deadband+1`. It does not set the threshold to `width+deadband`. Therefore, the churn reduction is smaller than claimed, and the reasoning about EURGBP is incorrect.

Let's also verify the ADR's statement: "For EURGBP that is 7 pips of mid drift against a 3-pip quote; for every other pair it is 10." If width=5, deadband=4, the claimed effective threshold is 9, not 10. The 10 is likely 2*width. This suggests they are confusing stranded with effective threshold. Actually they say "The effective threshold is width + deadband, not stranded. ... For EURGBP that is 7 ... for every other pair it is 10." If width=5, deadband=4, width+deadband=9. So "10" doesn't fit. Maybe deadband=5 for others? But default is 4. The ADR says "EURGBP at width 3 gives 6 > 7 FALSE" using deadband 4. So for others, deadband=4. Then width+deadband for width 5 is 9. So "10" is inconsistent. This is a factual error in the ADR.

Now, let's consider the "stranded = max(2 x width, width + deadband + 1)" floor. For current presets, if width=5, deadband=4, floor = max(10, 10) = 10. This is the current value. So no change. But if width=6, floor = max(12, 11) = 12. Current = 12. So no change. If width=4, floor = max(8, 9) = 9. Current = 8. So change. If there is a preset with width 4, it changes. The ADR says "EURGBP at width 3 gives 6 > 7 FALSE". So it only considers width 3 as the exception. But if any width 4 exists, it also fails the bound `2w > w+4` => 8 > 8 false. So width 4 would also fail. The ADR's statement "2 x width > width + 4 for every width >= 5" is correct for strict >? For width 5: 10 > 9 true. For width 4: 8 > 8 false. So width 4 also fails. The ADR only mentions EURGBP width 3. If there are presets with width 4, they are also affected. The audit should flag that the ADR's "nothing changes" claim requires verifying all presets, not just assuming width >=5.

Now, let's look at the new range check: `0.5 <= add/w <= 4.0`. If add/w is exactly 0.5, and width=5, add=2.5. The floor formula for stranded uses width and deadband, independent of add. So stranded=10. The recenter threshold away = max(4, 10-5=5) = 5. The add spacing is 2.5. So the add ladder is tighter than the recenter threshold. Could this cause the recenter to cancel/add orders? Not directly.

What about the interaction between `Grind_TryRecenterOppositeL0` and `Grind_EnsureAddNext`? Both can modify pending orders. If the opposite side is flat, its L0 is recentered. The filled side's add orders are managed by `Grind_EnsureAddNext`. They use different deadbands? Both use `deadband_pips`. No conflict.

Now, let's consider the "invariants" that might check that add == 2*width. The ADR mentions `Grind_CheckBookInvariants` but we don't have it. It might check that the distance between L0 and first add is `add`, and that `add == 2*width`? Unlikely. But we can't rule out. The audit should state that the provided code does not contain such an invariant, but the audit is limited to provided files. If invariants exist in `grind_state.mqh` or `grind_recon.mqh`, they must be checked. The ADR should have included that.

Now, let's prepare the final answer. It should be a structured audit report with findings, evidence, and recommendations. We need be exhaustive.

Let's outline:

**Finding 1: No direct add==2*width assumption in visible code, but verification incomplete.**
- `GRIND_ADD_WIDTH_MULTIPLE` only used in `Grind_ValidateAddWidthRelationship` and the error print in `OnInit`.
- No other occurrence in `fxgrind.mq5`, `grind_pure.mqh`, `grind_engine.mqh`.
- However, `grind_state.mqh`, `grind_recon.mqh`, `grind_exitq.mqh` not provided. The ADR must confirm no invariants/reconstruction assume the lattice. The uniform lattice is lost, but per-side ladder remains uniform with spacing `add`. The recenter uses `width` only. So mechanically safe in visible code.

**Finding 2: Effective recentre threshold derivation is wrong.**
- Actual condition: modify if `|w ± Δ| > S` and `|Δ| >= d`.
- Minimum drift: `max(d, S - w)` away from resting L0, and `S + w` toward.
- For EURGBP w=3, S=6, d=4: away threshold = 4 pips, not 7. This explains churn.
- The bound `S > w + d` ensures gate binds over deadband, but the resulting threshold is `S - w`, not `w + d`. The ADR conflates the binding condition with the threshold.
- This invalidates the floor rationale and the claimed churn reduction.

**Finding 3: New fatal check inequality is inverted.**
- Decision text: fatal if `stranded > width + deadband`. This would fail safe large values and not catch EURGBP (6 > 7 false).
- Testing says reject at exactly `width+deadband` and accept one above. So fatal should be `stranded <= width + deadband` (or `<` if allowing equality? They say reject at exactly, so `<=`).
- This is a critical sign error.

**Finding 4: Floor formula breaks "nothing changes" for EURGBP and possibly width 4.**
- Current EURGBP: w=3, d=4, S=6. Floor: max(6, 8) = 8. So S must change to 8. If not, corrected fatal check rejects startup.
- For width 4: floor max(8, 9) = 9, current S=8. Fails bound `2w > w+d` (8 > 8 false). ADR only mentions width 3, but width 4 also fails.
- The claim "2 x width > width + 4 for every width >=5" is true, but ignores width <=4. Six of eight pairs need add != 2w, so there may be width <=4 pairs. Need enumerate all presets.

**Finding 5: New range check allows geometries that may break exit queue or invariants.**
- Range `0.5 <= add/w <= 4.0` does not constrain `add` vs `exit` or `deadband`.
- If `add > exit`, new layer's exit target can be on the wrong side of previous entries, potentially breaking exit queue rank logic. The ADR only tests cycle-3 (add=4, exit=10). Need test add > exit, add < deadband, etc.
- If `add` is very small, add targets may be within stops level, causing clamps and non-uniform ladder. Not necessarily a break, but untested.

**Finding 6: Testing stub doesn't cover new checks.**
- `Grind_TestOnInitGeometryCheck` does not call `Grind_ValidateAddWidthRelationship` nor any stranded bound check. So tests using it will not fail before the change. The ADR's test plan requires failing tests; the stub must be updated or new tests written.

**Finding 7: Error message and signature issues.**
- `OnInit` error print still references `GRIND_ADD_WIDTH_MULTIPLE`.
- `Grind_ValidateGeometryInputs` signature lacks `deadband`, so new check requires interface change. If placed in `fxgrind.mq5`, pure tests won't cover it.

**Finding 8: ADR arithmetic inconsistency for "other pairs it is 10".**
- If w=5, d=4, `w+d=9`, not 10. The "10" is likely `2w`. This suggests confusion between stranded and effective threshold.

Now, let's double-check the actual recenter threshold derivation with strict inequalities and point normalization. The code uses `_Point` and pips = point*10. So `dist_pips = |resting - mid| / (point*10)`. `stranded_thresh_pips` is in pips. The deadband check: `band = deadband_pips * point * 10`. `Grind_PriceWithinDeadband` returns `|target - resting| < band`. So modify if `|target - resting| >= band`. So my derivation holds.

Let's write a small proof:

Let `m0` = old mid, `m1` = new mid, `Δ = m1 - m0`.
For long L0: `resting = m0 - W`. `target = m1 - W`.
`dist = |resting - m1| = |m0 - W - m1| = | -W - Δ | = |W + Δ|`.
Gate: `|W + Δ| > S`.
Deadband: `|target - resting| = |m1 - W - (m0 - W)| = |Δ| >= D`.
For short L0: `resting = m0 + W`. `target = m1 + W`.
`dist = |m0 + W - m1| = |W - Δ|`.
Gate: `|W - Δ| > S`.
Deadband: `|Δ| >= D`.

So for long:
- If Δ >= 0: `W + Δ > S` => `Δ > S - W`. Combined with `Δ >= D`: `Δ >= max(D, S - W)`. (If S - W <= D, threshold D; else S - W).
- If Δ < 0: let `x = -Δ > 0`. `|W - x| > S`. If `x <= W`, `W - x > S` => `x < W - S`. Since S typically >= W, this is impossible. If `x > W`, `x - W > S` => `x > S + W`. Combined with `x >= D`: `x >= S + W`.
So long: up threshold `max(D, S-W)`, down threshold `S+W`.
For short:
- If Δ >= 0: `|W - Δ| > S`. If Δ <= W, `W - Δ > S` => `Δ < W - S` (impossible if S>=W). If Δ > W, `Δ - W > S` => `Δ > S + W`. So up threshold `S+W`.
- If Δ < 0: let `x = -Δ > 0`. `|W + x| > S` => `W + x > S` => `x > S - W`. Combined with `x >= D`: `x >= max(D, S-W)`.
So short: down threshold `max(D, S-W)`, up threshold `S+W`.

Thus the away direction (long up, short down) has threshold `max(D, S-W)`. The toward direction (long down, short up) has threshold `S+W`. The ADR's `width + deadband` is neither. For S=2W, away threshold = max(D, W). For W=5, D=4, away threshold = 5. For W=3, D=4, S=6, away threshold = max(4, 3)=4. So EURGBP churns at 4 pips. The ADR says 7. This is a factor of ~1.75.

The bound `S > W + D` ensures `S - W > D`, so away threshold = S - W. So if they set S = W + D + 1, away threshold = D + 1. For W=3, D=4, S=8, away threshold = 5. So floor raises threshold from 4 to 5. The ADR thinks it raises from 7 to 8. So the actual improvement is much smaller.

Now, does the floor formula `max(2W, W+D+1)` hold for every current preset? Current S = 2W. The floor is `max(2W, W+D+1)`. For the floor to equal current S, we need `2W >= W+D+1` => `W >= D+1`. With D=4, W >= 5. So for W >=5, floor = 2W = current S. For W <5, floor > current S. So any preset with W <5 will have its S changed if the convention is applied. The ADR says "EURGBP at width 3 gives 6 > 7 FALSE -- see Open Questions." It doesn't mention W=4. If there is a preset with W=4, it also fails `2W > W+4` (8 > 8 false). So the floor would change it to 9. The ADR's "every other pair" may include W=4. The audit should ask for the full preset table. The ADR says "six of eight pairs need an add that is not twice their width" under cycle 3. That implies there are 8 pairs. Current presets all have add=2W. So current W for those 8 pairs? The ADR mentions AUDCHF OPT quotes its L0 legs 10 pips apart (2 x width) while adding every 4. So for AUDCHF, width=5 (2*5=10), add=4. So W=5. EURGBP W=3. Maybe others are W=5,6, etc. If all others are >=5, then only EURGBP changes. But the ADR should state that.

Now, let's consider the new fatal check if implemented as `stranded > width + deadband` fatal. For current presets with W=5, S=10, D=4: 10 > 9 true -> fatal! Wait, if the check is `if (stranded > width + deadband) return INIT_FAILED;`, then for W=5, S=10, D=4, 10 > 9 is true, so it would fail startup for every width 5 preset! That's even worse. Let's re-read: "New OnInit check, fatal: stranded_thresh_pips > width_pips + deadband_pips". If this is the condition to fail, then any preset with stranded > width+deadband fails. But the floor formula produces exactly that for W>=5. So the check as written would fail all current presets. The ADR says "Nothing changes for today's fleet" but the check would prevent them from starting. This is a catastrophic sign error. Let's verify: For W=5, D=4, S=10. width+deadband = 9. 10 > 9 true. So fatal. For EURGBP W=3, D=4, S=6. 6 > 7 false, so it would NOT fail. So the check as written would reject the good presets and accept the bad one. This is a complete inversion. The Testing section says "stranded at width + deadband exactly (reject) and one point above (accept)". That means reject when equal, accept when above. So the fatal condition should be `stranded <= width + deadband`. The Decision text says `>`. This is a critical bug that would brick the fleet if implemented literally. The audit must highlight this prominently.

Also, note that the floor formula `max(2W, W+D+1)` ensures `S >= W+D+1`, so `S > W+D`. If the check is `S > W+D` fatal, then the floor guarantees the fatal condition! So the EA would never start. This is a showstopper.

Now, let's consider the range check implementation. The ADR says: "Grind_ValidateAddWidthRelationship no longer tests equality. OnInit fails only when the geometry is outside a sane band: width_pips > 0, add_pips > 0, 0.5 <= add_pips / width_pips <= 4.0". This is fine. But the function name `Grind_ValidateAddWidthRelationship` still exists. The error print in `OnInit` still says `InpAddPips != GRIND_ADD_WIDTH_MULTIPLE x InpWidthPips`. That's cosmetic.

Now, what about the `InpStrandedThreshPips` convention? The ADR says "InpStrandedThreshPips follows WIDTH, not add, with a floor." This means the preset value should be computed as `max(2*width, width+deadband+1)`. The code does not compute it; it's an input. So the EA cannot enforce the floor unless it computes it internally. The ADR says "follows WIDTH" as a convention, but the new fatal check enforces `stranded > width+deadband`. So if the preset is set to the floor, it passes. But the ADR says "The floor exists because..." It sounds like the EA should compute `stranded` from width, or at least the preset should be set to that. If the EA computes it, it would override the input, which is not mentioned. If it's a preset convention, then the fatal check ensures it's at least `width+deadband+?`. But the check only ensures `> width+deadband`, not the `2*width` floor. So a preset with `stranded = width+deadband+0.1` would pass the check but not satisfy the `2*width` floor if `2*width` is larger. For W=5, D=4: `width+deadband+0.1 = 9.1`, but `2*width = 10`. The floor says `max(10, 10)=10`. The check `9.1 > 9` passes, but the floor is not enforced. So the EA does not enforce the `2*width` floor; it only enforces `> width+deadband`. That means the "floor" is not guaranteed. The ADR says "The floor exists because..." and gives formula, but the fatal check only enforces a lower bound of `width+deadband`, not the `2*width` part. So if someone sets `stranded = 9.1` for W=5, D=4, it passes the check but violates the floor convention. The ADR's claim "The floor exists" is not enforced by code. The code only enforces `stranded > width+deadband`. The `max(2*width, ...)` part is a preset convention, not a code check. This is a gap: if the intent is to enforce the floor, the fatal check should be `stranded >= max(2*width, width+deadband+1)` or similar. But the ADR says the new check is `stranded > width + deadband`, which is weaker. So the floor formula is not enforced.

Wait, the ADR says: "2. InpStrandedThreshPips follows WIDTH, not add, with a floor. stranded = max(2 x width, width + deadband + 1)". This is a convention for setting the input. Then "3. New OnInit check, fatal: stranded_thresh_pips > width_pips + deadband_pips". So the check only enforces the `width+deadband` part. The `2*width` part is not enforced. But for W>=5, `2*width >= width+deadband+1` (since W>=D+1), so the `max` is `2*width`. The check `stranded > width+deadband` is weaker than `stranded >= 2*width` when W>D+1. For W=6, D=4: `2*width=12`, `width+deadband=10`. Check allows `stranded=10.5`, which is below the floor of 12. So the floor is not enforced. This could matter if someone sets a lower stranded. The ADR says "the floor exists because..." but it's not enforced. The audit should flag this.

Now, let's consider the "stranded = max(2 x width, width + deadband + 1)" formula. If W=5, D=4: max(10, 10) = 10. So no change from current. If W=3, D=4: max(6, 8) = 8. So EURGBP must change. If W=2, D=4: max(4, 7) = 7. The ADR mentions this. So the floor formula is a preset convention. The new fatal check `stranded > width+deadband` would allow `stranded=8` for W=3, which is the floor. It would also allow `stranded=7.1` for W=3, which is below the floor of 8. So the floor is not enforced. This is a hole.

Now, let's summarize all findings in a clear, exhaustive manner. The user wants a quantitative audit hunting for lookahead bias, silent failures, schema mismatches, statistical flaws. This is an ADR audit, so we focus on the code and math.

We should also mention: The ADR says "DeepSeek audit and Cursor implementation outstanding." So we are the auditor.

Let's write the final answer with sections:

- Executive summary: The ADR has a critical sign error in the new fatal check, an incorrect effective threshold derivation, and a false "nothing changes" claim for EURGBP. The range check is likely safe in visible code, but unverified in missing files.

- Detailed findings:

1. Fatal check inequality inverted.
   - Quote Decision 3 and Testing.
   - Show that `stranded > width+deadband` fatal would reject all W>=5 presets and accept EURGBP.
   - Correct condition: `stranded <= width+deadband` fatal (or `<` if strict).

2. Effective recentre threshold is not `width+deadband`.
   - Derive `max(D, S-W)` and `S+W`.
   - Counterexample EURGBP: W=3, S=6, D=4 -> 4 pips, not 7.
   - Consequence: churn reduction is smaller; floor rationale flawed.

3. Floor formula and current presets.
   - Current S=2W. For W>=5, floor=2W (unchanged). For W<5, floor > current S. EURGBP W=3 -> 8, current 6. If any W=4, floor=9, current 8.
   - If fatal check corrected, EURGBP fails startup unless preset updated. "Nothing changes" false.
   - Floor `2*width` part is not enforced by the new check; only `> width+deadband`.

4. Range check and geometry.
   - No direct add==2*W assumption in visible code.
   - But range allows add < W, add > exit, add > 4*W? No, max 4.0.
   - Potential exit queue issues if add > exit. Need test.
   - Missing files (state, recon, exitq) must be audited.

5. Testing gaps.
   - `Grind_TestOnInitGeometryCheck` doesn't call the new checks.
   - Error message still references old multiple.
   - Signature of `Grind_ValidateGeometryInputs` lacks deadband.

6. Arithmetic inconsistency in ADR.
   - "for every other pair it is 10" vs width+deadband=9 for W=5,D=4.

7. Recommendation: Do not implement as written. Fix inequality, correct threshold math, update EURGBP and any W<=4 presets, add tests, enforce floor if desired, verify missing files.

Let's make it concise but thorough. The desired oververbosity is 5, but this is a complex audit. We'll aim for a detailed report.

We should also mention that the code's `Grind_TryRecenterOppositeL0` uses `OrderGetDouble(ORDER_PRICE_OPEN)` directly instead of `Grind_OrderGetPriceOpen`, which means in order test mode it won't use the test record. That's an existing bug not related to ADR, but maybe worth noting? The audit task is about ADR. But lookahead bias? Not relevant.

Actually, in `Grind_TryRecenterOppositeL0`, it calls `Grind_SelectOurOrder(opposite_side.l0_pending_ticket, magic)` then `OrderGetDouble(ORDER_PRICE_OPEN)`. In order test mode, `Grind_SelectOurOrder` uses the test record, but `OrderGetDouble` is an MT5 function that won't work in tests. So the recenter is not testable with the order test hooks. This is a pre-existing test gap. Could be relevant to "tests first". The ADR's testing plan says "The ADR-124 recentre is unchanged when stranded = 2 x width: same modify count as today on a fixture where mid drifts." But the recenter function cannot be tested with the existing order test hooks because it uses `OrderGetDouble` directly. Let's verify: In `Grind_TryRecenterOppositeL0`:
```
if(!Grind_SelectOurOrder(opposite_side.l0_pending_ticket, magic)) return;
const double resting = OrderGetDouble(ORDER_PRICE_OPEN);
```
There is a helper `Grind_OrderGetPriceOpen(ticket)` that handles test mode. But the recenter function uses the raw `OrderGetDouble`. So if `g_grind_order_test_active` is true, `Grind_SelectOurOrder` will return true based on test records, but `OrderGetDouble` will return 0.0 because there is no real order. Then `dist_pips` = |0 - mid| huge, gate opens, and it may try to modify. This is a bug in testability. The ADR's test plan for recenter may fail or behave incorrectly. This is a notable finding! The ADR says "The ADR-124 recentre is unchanged... same modify count as today on a fixture where mid drifts." But the fixture likely uses order test hooks. The recenter function bypasses the test hook for getting the resting price. So the test would not work as intended. This is a critical testing flaw. Let's check: `Grind_OrderGetPriceOpen` is defined in engine and handles test mode. `Grind_TryRecenterOppositeL0` should use it. This is a real bug that would prevent the proposed test from passing or being meaningful. The ADR's testing section is therefore flawed. We should include this.

Also, `Grind_TryRecenterOppositeL0` uses `OrderGetDouble` which is not wrapped. So any test of recenter with order test active will get 0.0. This is a lookahead/silent failure? It's a test harness mismatch.

Let's add this to findings.

Now, let's write the final answer. We'll structure as:

**Critical findings**
1. Inverted fatal check.
2. Wrong effective threshold.
3. EURGBP preset contradiction.
4. Recenter test harness bug (uses raw OrderGetDouble).
5. Floor not enforced.

**Secondary findings**
6. Range check untested for add>exit, add<deadband.
7. Missing files.
8. Error message.

We'll provide the math for the threshold.

Let's be precise with the threshold derivation and include the exact condition.

Also, note that the ADR's claim "A re-quote needs the gate open (dist > stranded) AND the new price at least deadband from the old, which needs dist >= width + deadband" is a non sequitur. The deadband condition is `|Δ| >= D`, not `dist >= W+D`. The only way `dist >= W+D` is a sufficient condition for `|Δ| >= D`? Actually if `dist = |W ± Δ| > S` and we want `|Δ| >= D`, the minimum `dist` that guarantees `|Δ| >= D` is not `W+D`. For example, if `Δ = D` and `W` is large, `dist = |W ± D|` which is about W, not W+D. So the implication is wrong.

Let's double-check: If `|Δ| >= D`, the minimum `dist` can be `||Δ| - W|`. For `|Δ| = D`, min dist = |D - W|. This can be much less than W+D. So `dist >= W+D` is not necessary for a re-quote. The ADR's reasoning is backwards.

Now, let's consider the new fatal check if corrected. The ADR says "Below that bound the stranded gate is permanently open and the deadband becomes the de facto control." Actually if S <= W+D, then away threshold = max(D, S-W) = D (since S-W <= D). So the deadband controls in the away direction. The gate is not "permanently open"; it opens at D. So the bound S > W+D ensures the gate controls instead of deadband. The fatal check should reject S <= W+D. The Testing section matches this. So the Decision text has a simple typo: should be `stranded_thresh_pips <= width_pips + deadband_pips` fatal. We'll state that.

Now, let's write the final answer.

We'll also mention that the range check `0.5 <= add/w <= 4.0` is very wide. If `add/w = 0.5`, and `deadband = 4`, the add spacing is smaller than deadband. This could cause `Grind_EnsureAddNext` to never modify an add order because the target moves less than deadband. That might be intended. But if `add` is very small, the add target near market threshold is small, affecting slot reservation. Not a break.

Let's finalize.

## Final Report

## Audit report: ADR-153 geometry independence

**Verdict: do not implement as written.** The ADR contains a critical sign error in its proposed fatal check, a mathematically incorrect derivation of the effective recentre threshold, and a self-contradictory claim that “nothing changes for today’s fleet.” The range check itself is probably safe in the visible code, but the recentre logic and the proposed test plan have concrete defects.

---

## 1. Critical: the new fatal check is inverted

ADR Decision 3 says:

> **3. New `OnInit` check, fatal:**
> ```
> stranded_thresh_pips > width_pips + deadband_pips
> ```

But the Testing section says:

> `stranded` at `width + deadband` exactly (reject) and one point above (accept).

If the fatal condition is `stranded > width + deadband`, then:
- A safe large stranded value (e.g. `width=5, deadband=4, stranded=10`) satisfies `10 > 9` and **fails startup**.
- The known-bad EURGBP value (`width=3, deadband=4, stranded=6`) satisfies `6 > 7` as false, so it **passes startup**.

That is exactly backwards. The condition must be:

```cpp
if(stranded_thresh_pips <= width_pips + deadband_pips) return INIT_FAILED;
```

or, if equality is to be allowed, `<`. The Testing section confirms rejection at equality, so `<=` is the correct form.

**Impact:** implemented literally, the EA would refuse to start every current preset with `width >= 5` and would happily start EURGBP, the one pair the ADR is trying to fix. This is a fleet-bricking sign error.

---

## 2. Critical: the effective recentre threshold is not `width + deadband`

The ADR claims:

> A re-quote needs the gate open (`dist > stranded`) AND the new price at least `deadband` from the old, which needs `dist >= width + deadband`.

That implication is false. Let:

- `W` = `width_pips`
- `S` = `stranded_thresh_pips`
- `D` = `deadband_pips`
- `Δ` = `current_mid - placement_mid`

The stale L0 sits at `placement_mid ± W`. The new target sits at `current_mid ± W`. The deadband checks `|target - resting| = |Δ|`. The stranded gate checks `dist = |resting - current_mid| = |W ∓ Δ|`.

The actual condition to modify is:

```text
|W ∓ Δ| > S   AND   |Δ| >= D
```

Solving this gives **direction-dependent** thresholds:

| Side | Market moves away from resting L0 | Market moves toward resting L0 |
|---|---:|---:|
| Long  | `Δ >= max(D, S - W)` (mid up) | `|Δ| >= S + W` (mid down) |
| Short | `|Δ| >= max(D, S - W)` (mid down) | `Δ >= S + W` (mid up) |

The minimum drift that can trigger a recentre is therefore `max(D, S - W)`, **not** `W + D`.

### EURGBP counterexample

EURGBP: `W=3`, `S=6`, `D=4`.

Suppose mid drops 4 pips. The short L0 is resting at `old_mid + 3`. New mid = `old_mid - 4`.

- `dist = |(old_mid + 3) - (old_mid - 4)| = 7 > 6` → gate open.
- `|target - resting| = |Δ| = 4`, and `4 < 4` is false → deadband allows modify.

So a **4-pip mid move triggers a re-quote**, not 7 pips. That is exactly why EURGBP churns: the away-direction threshold is `max(4, 6-3) = 4`.

The ADR’s stated bound `S > W + D` is the condition for the gate to bind instead of the deadband. It is **not** the effective threshold. Once `S > W + D`, the away-direction threshold becomes `S - W`, which is generally smaller than `W + D`.

**Impact:** the floor rationale is wrong. For cycle-3 geometry `W=5, S=10, D=4`, the away threshold is `max(4, 10-5) = 5` pips, not 10 (or 9). The churn reduction is much smaller than claimed, and the proposed floor may not achieve the intended API-usage reduction.

---

## 3. Critical: “nothing changes for today’s fleet” is false

The ADR admits:

> EURGBP runs width 3, stranded 6, deadband 4 — so `2 x width` (6) does NOT exceed `width + deadband` (7)

and later:

> EURGBP at width 3 gives 6 > 7 FALSE — see Open Questions.

But the Decision says the new stranded convention is:

```text
stranded = max(2 x width, width + deadband + 1)
```

For EURGBP `W=3, D=4`:

```text
max(6, 3 + 4 + 1) = max(6, 8) = 8
```

So the floor changes EURGBP from 6 to 8. If the corrected fatal check is enforced, the current EURGBP preset (`stranded=6 <= 7`) **will not start**. The claim “Nothing changes for today’s fleet” is therefore false for EURGBP.

The same applies to any preset with `width <= 4` when `deadband=4`:
- `W=4`: `2W=8`, `W+D=8`, so `2W > W+D` is false. The floor gives `max(8, 9) = 9`.
- `W=3`: fails as above.
- `W=2`: `2W=4`, `W+D=6`, floor gives `max(4, 7) = 7`.

The ADR only mentions EURGBP, but if any other live preset has `width=4`, it is also affected. The audit must request the full preset table before accepting the “nothing changes” claim.

---

## 4. The floor’s `2 x width` component is not enforced by the proposed check

Decision 2 defines `stranded = max(2 x width, width + deadband + 1)`, but Decision 3 only enforces:

```text
stranded > width + deadband
```

That is weaker than the floor. For `W=6, D=4`:
- Floor: `max(12, 11) = 12`
- Check: `stranded > 10` is satisfied by `10.5`

So a preset can pass the fatal check while violating the `2 x width` floor. If the floor is meant to be mandatory, the check must be:

```cpp
if(stranded_thresh_pips < MathMax(2.0 * width_pips,
                                   width_pips + deadband_pips + 1.0))
   return INIT_FAILED;
```

or the EA must compute `stranded` internally. As written, the floor is a convention, not a guard.

---

## 5. Recentre test plan is broken by a test-harness mismatch

The ADR says:

> The ADR-124 recentre is unchanged when `stranded = 2 x width`: same modify count as today on a fixture where mid drifts.

But `Grind_TryRecenterOppositeL0` (`grind_engine.mqh:1482-1524`) does not use the order-test wrapper for reading the resting price:

```cpp
if(!Grind_SelectOurOrder(opposite_side.l0_pending_ticket, magic))
   return;
const double resting = OrderGetDouble(ORDER_PRICE_OPEN);
```

In order-test mode, `Grind_SelectOurOrder` returns true from the test record, but `OrderGetDouble` is the raw MT5 function and will return `0.0`. The recentre logic then computes a huge `dist` and may attempt a modify. Any fixture using the existing order-test hooks will not exercise the real recentre path correctly.

The code already has a wrapper for this:

```cpp
double Grind_OrderGetPriceOpen(const ulong ticket)
```

`Grind_TryRecenterOppositeL0` should use `Grind_OrderGetPriceOpen`. Until that is fixed, the proposed recentre test cannot pass as written.

---

## 6. Range check is safe in visible code, but unverified in missing files

In the provided files, the only direct use of `add == 2 * width` is:

- `GRIND_ADD_WIDTH_MULTIPLE` in `grind_pure.mqh`
- `Grind_ValidateAddWidthRelationship`
- The error print in `fxgrind.mq5:119`

No other visible code assumes the relation. `width` is used only for L0 straddle placement and recentre. `add` is used only for add targets and entry-horizon distances. The per-side ladder remains uniform with spacing `add`; only the cross-side lattice is lost. So mechanically, removing the equality check does not break the visible engine.

However, the following files were not included in the audit packet and must be checked:

- `grind_state.mqh`
- `grind_recon.mqh`
- `grind_exitq.mqh`
- `grind_cap.mqh`
- `grind_comment.mqh`
- all `.set` presets

Any invariant that checks price relationships between the two sides, or any reconstruction that infers layer indices from price spacing, could still assume `add == 2 * width`. The ADR should require an explicit grep for `add`, `width`, and `GRIND_ADD_WIDTH_MULTIPLE` across the full `ea/` tree before approval.

---

## 7. The wide range permits untested exit-queue geometry

The proposed range is:

```text
0.5 <= add / width <= 4.0
```

This allows `add > exit`. For example, `width=1, add=4, exit=2`. In that case, a new add layer fills at `previous_entry - 4` (long), and its exit target is `previous_entry - 4 + 2 = previous_entry - 2`, which is **below** the previous layer’s entry. That can invert the exit queue’s rank ordering and may cause exit orders to be placed on the wrong side of the market or clamped unexpectedly.

The ADR’s only cycle-3 test uses `add=4, exit=10`, which avoids this. The range check does not constrain `add` relative to `exit` or `deadband`. The audit should require tests for:
- `add > exit`
- `add < deadband`
- `add` so small that clamping to stops level dominates

---

## 8. Testing stub does not cover the new checks

`Grind_TestOnInitGeometryCheck` (`grind_pure.mqh:47`) currently calls only `Grind_ValidateGeometryInputs` and checks `magic != 0`. It does **not** call `Grind_ValidateAddWidthRelationship` and does not know about `deadband`. Therefore:

- The proposed add/width ratio tests will not fail before the change if they use this stub.
- The proposed stranded-bound tests cannot be expressed through this stub without changing its signature.

The ADR’s “tests first, and they must fail before the change” requirement is not satisfiable with the current test surface.

---

## 9. Minor: stale error message and signature drift

- `OnInit` still prints:
  ```cpp
  Print("FATAL: InpAddPips (", InpAddPips, ") != ",
        GRIND_ADD_WIDTH_MULTIPLE, " x InpWidthPips (", InpWidthPips, ")");
  ```
  This will be misleading once the equality check is replaced.

- `Grind_ValidateGeometryInputs` does not accept `deadband_pips`, so the new fatal check cannot be added there without changing its signature. If the check is added only in `fxgrind.mq5`, the pure test stub will not cover it.

---

## 10. Arithmetic inconsistency in the ADR evidence

The ADR says:

> The effective threshold is `width + deadband`, not `stranded`. … For EURGBP that is 7 pips … for every other pair it is 10.

For `width=5, deadband=4`, `width + deadband = 9`, not 10. The “10” appears to be `2 * width` (the old stranded value). This is further evidence that the ADR conflates the binding condition (`S > W + D`) with the threshold itself (`max(D, S - W)`).

---

## Required corrections before approval

1. **Fix the fatal check inequality.** It must reject `stranded <= width + deadband`, not `>`.
2. **Correct the effective-threshold math.** Document the real away/toward thresholds: `max(D, S - W)` and `S + W`.
3. **Resolve the EURGBP preset.** If the corrected check is enforced, EURGBP must be updated from `stranded=6` to at least `8` (or the check must be made non-fatal for existing presets, contradicting Decision 3). Verify all presets with `width <= 4`.
4. **Enforce the floor if it is intended to be mandatory.** The current check does not.
5. **Fix `Grind_TryRecenterOppositeL0` to use `Grind_OrderGetPriceOpen`** so the recentre test can actually run.
6. **Extend the geometry test stub** to cover the add/width range and the stranded bound.
7. **Grep the full `ea/` tree** for any invariant, reconstruction, or exit-queue assumption that depends on `add == 2 * width`.
8. **Add tests for `add > exit` and `add < deadband`** before widening the range guard.

Until these are addressed, ADR-153 should remain in **Proposed** and must not be implemented.

<!-- finish_reason=stop -->
