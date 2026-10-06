# DeepSeek R1 Audit Report

## Internal Reasoning

Let me carefully audit this ADR-166 roll gate branch. We need findings with file/function/quote evidence.

Let me start with the GIVENS.

G1. With `InpRollGateOpposite = -1` every path behaves exactly as before: `Grind_RollGateHolds(-1, x)` is false, and the only other new statement on that path clears the new deferred latch.

Look at `Grind_LatticeTrySide`:

```
   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
      Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);
      return 0;
   }
   if(is_long)
      g_grind_vl_deferred_noted_long = false;
   else
      g_grind_vl_deferred_noted_short = false;
```

With gate = -1, `Grind_RollGateHolds(-1, x)` returns `gate >= 0 && ...` = false. So the ungated path executes the latch clear. That's the only new statement. VERIFIED. But careful: `Grind_LatticeRollDeferredNote` does not run when gate is -1, but the SIDE effect... G1 says the only other new statement on that path clears the new deferred latch. Indeed.

G2. The roll-gate FATAL in `OnInit` runs before `Grind_MagicLockClaim`. In OnInit: the FATAL `if(!Grind_ValidateRollGateInputs(...)) { Print("FATAL: InpRollGateOpposite must be -1, or >= 0 with InpVirtualLattice=true (ADR-166)"); return INIT_FAILED; }` appears before `const bool api_inputs_ok = ...` and before `if(!Grind_MagicLockClaim(InpMagic)) {`. VERIFIED.

G3. The gated path sends no order request, writes no VL, emits no ROLL_STRANDED, and leaves the closing state, the backoff and the fail count unchanged.

The gated path: `if(Grind_RollGateHolds(roll_gate, opposite_depth)) { Grind_LatticeRollGateRestartExtreme(is_long); Grind_LatticeRollDeferredNote(...); return 0; }`. It returns before the candidate loop. It does touch `g_grind_vl_deferred_noted_*` inside `Grind_LatticeRollDeferredNote` (sets latch true) — that's not "closing state" etc. No modify/place/remove. No VL set. No stranded. Backoff/fail count unchanged. Closing state unchanged (since it returns before the final `Grind_LatticeResetClosingState`). 

Wait: `Grind_LatticeRollDeferredNote` uses `Grind_LatticeLevelCrossed` — no orders. OK. So VERIFIED.

However, note the deferred latch is state that G3 doesn't count.

G4. `opposite_depth` is the other side's filled-layer count at the moment of the call (`Grind_SideDepth`), never a resting entry. In `Grind_LatticeOnTick`:
```
      Grind_LatticeTrySide(g_grind_long, true, magic, slot, lots, exit_pips, add_pips, max_layers,
                           enabled, blocked, now, g_grind_vl_extreme_long, reroll, roll_gate,
                           Grind_SideDepth(g_grind_short));
```
and `Grind_SideDepth` = `ArraySize(side.layers)`. VERIFIED. But note `Grind_SideDepth(g_grind_long)` is read AFTER the long call, i.e. after the long side may have rolled (which doesn't change layer count) — roll doesn't change depth. Fine. But there's a subtlety: the long side's call can remove/add layers? No, TrySide doesn't append/remove layers (roll only modifies exit). Actually `Grind_LatticeRollLayer` calls `Grind_ExitQManageSide` which can cancel/place exit orders — not layers. So depth unchanged.

Hmm, but wait: the short's opposite depth is read after the long call returns. Within the long call, the long side cannot change the short side's layers. So the value is the same as at the start of OnTick. VERIFIED.

Actually one subtlety: `Grind_LatticeTrySide` for the long could... no. OK.

G5. `Grind_LatticeRollGateRestartExtreme` touches only the gated side's tracking, extreme and from_msc. Look:

```
void Grind_LatticeRollGateRestartExtreme(const bool is_long)
{
   const long t = Grind_MarketTimeMsc();
   if(is_long) {
      g_grind_vl_tracking_long = true;
      g_grind_vl_extreme_long = 0.0;
      g_grind_vl_from_msc_long = t + 1;
   } else {
      ...
   }
}
```
VERIFIED.

G6. `ROLL_DEFERRED` goes to the archive only (no telemetry emit) and at most once per gated episode per side. `Grind_LatticeRollDeferredNote` uses `Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", ...)` and `Print(...)`, no `Grind_TelemetryEmit`. And latch guard at top. VERIFIED, except nuance: "at most once per gated episode" — the latch is cleared when the ungated call runs (the C8 clear after the gate block), so if the market oscillates (gated -> not gated (opposite depth drops <= gate) -> gated), the marker re-arms. That's per episode, not spam. But consider: within a single call, both sides are evaluated. The long side's `TrySide` clears the long's latch if ungated; the short's clears the short's. Each latch is per-side. OK.

Hmm, but there's a subtle one: `Grind_LatticeRollDeferredNote` returns if latch is true FIRST (before the depth/crossed check). Fine.

Now let's think about the THREATS.

T-1. Gate decision staleness.

OnTick evaluates long then short in one call. The long call reads `Grind_SideDepth(g_grind_short)` — the short's filled layers — and vice versa. "Any path where the depth is stale (a fill processed between the two calls, a layer array mid-update)?"

In MQL5, OnTradeTransaction and OnTick are called on the same thread (the EA is single-threaded per instance). Fill processing happens in `OnTradeTransaction` which is a separate callback; it cannot interleave with `OnTick`'s two calls. So depth cannot change between the two calls within one OnTick. ASSUMED that MQL5 dispatches callbacks sequentially on the same thread (documented).

But — there is a real staleness issue: the gate decision for the LONG side is made using the SHORT's depth. The long side's gate check happens BEFORE the short side's `Grind_LatticeTrySide`. But consider the re-roll loop: the long side rolled nothing (gated). Then the short side is evaluated. That's fine.

Now the deeper issue: "where the gate decision for one side changes the other's". The gate is per-side: the long's gate depends on the short's depth; the short's gate depends on the long's depth. If both are capped (8/8) and N=0, both gates hold: neither rolls. Ruled acceptable (GR6-5).

"where `blocked` / backoff ordering lets a gated side act?" The gate check is AFTER `!enabled || blocked` and after the backoff check. So a blocked or backoff side returns before the gate check. That means: a side in backoff doesn't restart its extreme and doesn't clear the deferred latch — because it returns at the backoff check before the gate block. Conversely the ungated latch clear (which happens after the gate block) is skipped.

Wait, critical: **the deferred latch is cleared BELOW cap too** (`Grind_LatticeTrackOneSide`), and in `Grind_LatticeResetBackoff`. But what about the case where the side is *blocked* (halt/quarantine) or in *backoff*: the latch stays set. When the side is unblocked... it'll clear on the first ungated call. Fine.

Hmm, but here's a real problem for T-1: **the deferred latch clear happens AFTER the gate check but the `Grind_LatticeTrackOneSide` below-cap clear only clears the latch when that particular side's depth < max_layers**. Consider: the LONG is at cap and gated; the marker is set (`deferred_noted_long = true`). Now the SHORT drops below cap (its layer exits). On the next tick, the LONG's gate no longer holds, so `TrySide` for long clears the latch and rolls. Good.

Now T-1 other path: **the backoff check ordering**. Order: disabled/blocked → backoff → gate → latch clear. Consider a side that is gated and ALSO in backoff (from a previous failed roll before the gate engaged). While gated, the backoff expires; the gate holds; fine. But: while in backoff, the gate block is skipped, so `Grind_LatticeRollGateRestartExtreme` is NOT called. This means: **the extreme keeps accumulating while the side is in backoff AND gated** — reintroducing P4 for the duration of the backoff. Specifically, a roll modify failed earlier (backoff 60s, doubling to 1800s), then the opposite side fills to > N, the gate engages, but the side is in backoff → `TrySide` returns at the backoff check → the extreme is NOT restarted → the extreme continues to fold ticks during the deferral. When both the backoff expires and the gate is later open... Actually the gate-restart only matters while gated. Hmm, let's trace: the extreme is used as `probe = min(mkt, extreme)` at the moment of an ungated roll. If the side is in backoff while gated, the extreme is not reset; when the backoff expires and the gate still holds, the restart happens (extreme = 0). So the extreme is reset at the first gated call after the backoff. But between the backoff expiry within a gated period and the next call, the extreme would have been reset anyway. Actually the concern: while in backoff and gated, the extreme accumulates. If the gate then opens on the SAME call the backoff expires... the new code checks backoff FIRST, returns 0 (backoff still active, `now < backoff`). Next call: backoff expired → gate check → gate holds → restart. If the gate opened during that window: backoff expired → gate open → latch cleared → roll with an extreme that includes ticks from the gated period. Hmm, is that actually replaying? The extreme accumulated during the deferral includes ticks during the gated period, and at the release it probes min(mkt, extreme). That's exactly P4's defect. But it only happens if the side was in backoff while gated. It's an edge but real: **the extreme-restart is skipped for a side in backoff.**

Actually wait — more importantly, the same applies to `blocked`: `if(!enabled || blocked) return 0;` happens before the gate check, but also before `Grind_LatticeTrackExtremes`? No — `Grind_LatticeTrackExtremes` is called in `Grind_LatticeOnTick` before the blocked check:

```
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;
```

So even when blocked, the extremes are tracked. And the gate block never runs when blocked. So a blocked (halted/quarantined) side while gated accumulates the extreme. When the block lifts, the gate may still hold → the restart happens at the first call, discarding. Hmm, so the extreme accumulated during the block+gated is discarded at the first gated call. OK.

But the backoff case: the restart only happens on a call that reaches the gate block. In backoff, the call returns early. So the extreme accumulates. When the backoff expires: if the gate still holds, the restart resets. If the gate does NOT hold at that first call after the backoff, the latch clear runs and the roll proceeds with the stale extreme → potentially replaying the dip. This is the P4 hazard resurfacing. Is this a genuine break of T-2? T-2 asks: "Can any of them replay a dip from the held period...?" The backoff case: yes, if a modify failure put the side in backoff during the gated period and the gate opens before the first post-backoff call. Hmm, but the modify failure itself would have prevented any roll. Actually think about the sequence: The side is capped, gated. A modify failure cannot happen while gated (no rolls). So the backoff would have to be set BEFORE the gate engaged. Then the gate engages while the side is in backoff. While in backoff + gated, ticks accumulate in the extreme. Then the gate opens; the backoff is still active → returns before the gate check → but the gate is open now, so no restart; the latch isn't cleared either (unused, it was never set — the note never ran while in backoff). Next call after the backoff expires: gate does not hold → latch clear → roll with extreme including the gated period's dip → the roll replays the dip. Yes. This is real but narrow. Also a `blocked` state is similar? Blocked returns before gate; but `Grind_LatticeTrackExtremes` runs. When unblocked, the first call: if the gate holds, the restart happens (extreme discarded). If the gate has already opened before the unblock... same hazard. Hmm, but blocked is a rare global state.

Actually, wait. Let's re-read: `Grind_LatticeTrackOneSide` resets the whole tracking when `depth < max_layers`. And the gate block restarts the extreme EVERY gated call. So the extreme is essentially always "since the last gated call or since tracking started". But since the restart happens every gated call and the side is called every tick, the extreme is effectively 0 → the "live market" is folded in `Grind_LatticeFoldExtreme` on the tracking path. Hmm, wait: restart sets extreme = 0 and from_msc = t+1. Then `Grind_LatticeTrackOneSide` is called at the START of `Grind_LatticeOnTick`, BEFORE `TrySide`. So the order per tick is: TrackExtremes (fold ticks since from_msc, extreme = min(extreme, folded, live)) → TrySide (gate check → restart extreme to 0, from_msc = t+1). So within one tick, after the restart, extreme = 0. Next tick, TrackExtremes runs (tracking is true, from_msc = previous t+1, so it copies ticks from that time, essentially the tick(s) since the restart), folds them and the live price. Then TrySide: if gated, restart again. So the extreme is reset each tick while gated. Good — that's the design.

Now the actual hazard: the restart sets `from_msc = t + 1` where t = current market time. If a tick arrives with the SAME msc as the restart time... The next TrackExtremes calls `Grind_LatticeCopyTicks(from_msc, ...)` = copies ticks with `msc >= from_msc` i.e. >= t+1, so the tick at time t is excluded. Good. But if a tick arrives with the same time_msc as the previous restart... ignored. Fine.

T-2's cases:
- dead market: no newer tick, so `from_msc > market time`. `CopyTicksRange(from_msc, to = market time)` with from > to. What does MT5 do? It returns 0 (or -1). The code: `if(n < 0) return;` — a return without folding. So the extreme stays 0 and no ticks. Fine. And nothing gets stuck longer than a tick because the live price is folded... wait, if `n < 0`, `Grind_LatticeTrackOneSide` returns BEFORE folding the live price. Hmm: 
```
      const int n = Grind_LatticeCopyTicks(g_grind_vl_from_msc_long, msc, bid, ask);
      if(n < 0)
         return;
      Grind_LatticeFoldExtreme(...)
```
So on `n < 0`, the live price is NOT folded this tick. But the next tick retries. So a real crossing could be missed for one tick. Actually the threat says "leave the extreme stuck so that a real crossing after release is MISSED for longer than one tick?" With `n == 0`, `Grind_LatticeFoldExtreme` is called and folds the live price. With `n < 0`, no fold. So only one tick. OK.

Hmm, wait — there's a subtle issue in `Grind_LatticeCopyTicks`: the test path returns `n` counting all ticks >= from_msc, and the production path uses `CopyTicksRange(..., COPY_TICKS_INFO, from_msc, Grind_MarketTimeMsc())`. On the release call, the gate is open, so no restart. The tracking continues from wherever. Fine.

- The gate releasing on the same tick it last held: The restart happened at the end of the last gated call, setting from_msc = t+1. On the next tick, if the gate is open, `TrySide` proceeds to roll with the extreme from the tracking that ran at the start of this tick (which folded ticks with msc >= t+1 up to now, plus the live price). That's correct — the extreme contains only post-restart data. Good.

But: what if the gate releases and the tick that releases it is the tick where the opposite's layer filled? The fill happens in OnTradeTransaction, which may run BEFORE or AFTER OnTick. If after, then OnTick sees the old depth (still gated). Next tick, OnTick sees the new depth: `TrackExtremes` folds the ticks since the last restart (covering the release moment), then TrySide rolls with the extreme. The extreme now includes the market move since the last restart. If the market dipped during the gated period AFTER the last restart... no, the restart happens every gated call, so the extreme is reset each tick. So the extreme at release = ticks since the last gated call's restart + live. That's fine (that's the "one tick window").

Hmm, but there IS a hole: between the last gated call and the release call, the market might dip and the extreme is only folded at the start of the release call — from `from_msc` (last restart + 1) to now. So the extreme includes the dip that happened between the two calls. That is intended? "a dip during the deferral is not replayed at release" — the dip during the gated period is not replayed, but a dip between the last gated call and the release call IS included. That's just the normal between-call catch-up. Fine.

- EA restart while gated: globals re-initialised (tracking=false, extreme=0, from_msc=0). After restart, `Grind_LatticeTrackOneSide` re-initialises from the newest layer's open time. The gate is re-evaluated. During the restart, the extreme starts fresh. No replay from the held period... well, `from_msc` = max(newest+1, now - 86400) — that's up to 24h of ticks! On restart, the extreme is initialised to the min ask over the last 24h (capped by the newest layer's open). That's the PRE-EXISTING VC10 behaviour, not new. But if the EA restarts while gated, the extreme will include the deferral period's dip (up to 24h back). That's a restart concern: `Grind_LatticeRollGateRestartExtreme` is only called on a gated `TrySide`, which happens after `TrackExtremes` has already rebuilt and folded 24h of history. Then the gate check: if the gate holds, the restart resets the extreme → OK. If the gate has opened by the time the EA restarted... then the first TrySide rolls with the extreme built from up to 24h of history (including the deferral dip) → replays the dip. But that's the existing VC3/VC10 behaviour with the catch-up, which P4 says exists for ticks missed between calls. Hmm, on a restart, is that a "dip during the held period"? Yes. So restart-while-gated + gate open at the first call → replay. But the gate would only be open if the opposite side emptied. It's a restart, so state is rebuilt; the opposite depth is whatever. This is a genuine (if narrow) hole, but it's arguably pre-existing catch-up. Let me note it as a NEEDS-FIX or a noted hazard.

Hmm, actually here's a bigger one for T-2: **the restart happens on EVERY gated call, so the extreme never contains more than one tick's worth during a hold. But when the gate is open, `Grind_LatticeRollDeferredNote` is not called and the latch is cleared. Fine.**

Now, a REAL bug candidate in T-2: `Grind_LatticeRollGateRestartExtreme` sets `from_msc = t + 1` where `t = Grind_MarketTimeMsc()`. In production, `Grind_MarketTimeMsc()` returns `SYMBOL_TIME_MSC` of the last tick. But `TrySide` is called with `now = TimeCurrent()` (seconds). The `CopyTicksRange` upper bound is `Grind_MarketTimeMsc()`. If the restart is at t+1 and the very next tick's time_msc == t (same millisecond), then from_msc = t+1 > tick msc → the tick is not copied, and the upper bound = t → CopyTicksRange(from=t+1, to=t) with from > to. Returns -1? Either way, the tick at time t is never folded. But that tick is the "live" price which IS folded... no wait, if n < 0 the function returns before folding the live price. So the tick at time t is neither in the tick range nor folded. Hmm, but the restart happened at the END of the previous call using the live price at that time. Actually the restart zeroes the extreme; then the next call's tracking folds the live price (if n >= 0). If n<0, it doesn't. Then TrySide: if gated, restart again. If NOT gated (release), the roll probes `min(mkt, extreme)` where extreme might be 0.0 → `probe = extreme > 0.0 ? ... : mkt` → probe = mkt (the branch `extreme > 0.0 ? ... : mkt`). So extreme=0 is handled by using mkt. Good — `if(extreme <= 0.0) extreme = live;` in FoldExtreme. And in TrySide: `const double probe = extreme > 0.0 ? (...) : mkt;`. So extreme = 0 is safe (uses mkt). OK.

So the risk of a stuck extreme is at most a tick.

Hmm, but here's the "gate releasing on the same tick it last held" case: the restart at the end of the last call sets from_msc = t+1. The release call runs; at its start, `TrackExtremes` folds ticks from t+1 to now plus live. That's fine, EXCEPT: the restart threw away the extreme (say the market dipped to 1.20190 during the gated period). At release, the market is at 1.20600, and the level is 1.20600. probe = min(mkt, extreme) = 1.20600 (extreme = the min over the last tick window, likely 1.20590 or so). So the roll happens if the market is at/below the level. That's the intended fix. But note: if the market is at 1.20600 exactly (crossed) it rolls. Hmm, the release rolls when "the market crosses the next level" — this is a genuine release trigger. Fine.

T-3. The deferred latch. "Set on the first gated call that finds a roll due; cleared when an ungated call runs, below cap, or in the test reset. Any path where it spams the archive (cleared every call while still gated), or never re-arms after a real release?"

The clear is: `if(is_long) g_grind_vl_deferred_noted_long = false; else ...` — this runs on every call that passes the gate check (i.e., NOT gated). If the gate holds, we return before the clear. So while gated, the latch stays set → no spam. Good.

"never re-arms after a real release?" After release, the latch is cleared on the ungated call. Then if the gate re-engages (opposite refills), the next gated call with a roll due re-arms. RG9 tests exactly this. OK.

Hmm — but consider the **below-cap clear**: `Grind_LatticeTrackOneSide` clears the side's own latch when ITS OWN depth < max_layers. So when the gated side drops below cap, the latch clears. Fine.

Now, subtle: the latch is per side, but the clear in `TrySide` happens only if that side is evaluated. `Grind_LatticeOnTick` only calls `TrySide` for a side if `Grind_SideDepth(side) >= max_layers`. So a side below cap: `TrackOneSide` clears its latch. Fine.

What about the case where the gate holds but the side has NOTHING to roll (no level crossed)? `Grind_LatticeRollDeferredNote` checks `Grind_LatticeLevelCrossed`. So no marker. And the latch isn't set. Then the next gated call that DOES cross sets it. Fine.

But WAIT: a real spam path. `Grind_LatticeRollDeferredNote` sets the latch only if the level is crossed. But `Grind_LatticeRollGateRestartExtreme` is called on EVERY gated call, unconditionally. And the archive marker is guarded by the latch. So no spam. OK.

Hmm, another: the latch is set to true only at the end of the note. But if the note returns early due to `level <= 0.0` or not crossed, the latch is NOT set and the restart already happened. So on a tick where the level is not crossed, the extreme is restarted but no note. Fine.

T-4. Release. "When the opposite side empties the next call rolls every level the CURRENT market has crossed (first rolls unthrottled, re-rolls one per call)."

The loop: `for(int iter = 0; iter < max_layers; iter++)`. First rolls: up to max_layers per call (8). Each roll = 1 modify (or 1 place) + up to 1 remove + 1 place from `Grind_ExitQManageSide`. So a burst of up to ~8 modifies + 8 removes + 8 places = up to 24 requests per side per release call. With nine instances → 216 requests in one tick? Well, on the same terminal there are nine instances on nine charts; each ticks. The doc's GR6-1 estimates ~24 per side per call.

Actually, the "burst" is bounded by the gap over `add`. In a continuation, the market is ~1 level past; so typically 1 level. The worst is a big gap (LB7: five). OK.

Hazards: "a roll placed while the counter side's new L0 is about to fill". The gate counts filled layers; the opposite L0 resting is not counted. At the moment the counter layer's exit fills (scalp out), the opposite depth goes 1 → 0, so the gate opens. Then the capped side rolls. Meanwhile the empty side places its L0 at mid ± width on the next call (`Grind_TryPlaceL0` in OnTickEngine). Anyway, ruled.

Now, is there a case where the gate opens and the roll is placed but the exit queue's restructure... Not our concern.

"interaction with the pause": `Grind_LatticeRerollPaused` is checked INSIDE the loop, for the re-roll branch. First rolls are not paused. So at release during 23:50-00:15, first rolls happen. That's as before (`InpLatticeReroll` semantics). Fine.

Hmm — there is a genuine T-4 issue: **at release, the restart has set `from_msc` to the last gated call's t+1, and the `TrackExtremes` runs BEFORE `TrySide`**. Wait, let me check the ordering at release. The release call: `Grind_LatticeOnTick` → `Grind_LatticeTrackExtremes` (folds ticks since last restart) → `TrySide` (gate now open → clears latch → rolls with the extreme). The extreme includes the ticks since the last gated call's restart. That's up to one tick's worth (plus the live price). So the roll uses the current market and the recent extreme. Good.

But hold on: does the gate decide based on the opposite depth at the START of the release call? Yes. And that same call rolls. So the roll can be based on a dip that occurred... no, the extreme is fresh.

Hmm, what about the case where the gate releases because the opposite side dropped below cap, and simultaneously the market dipped in the SAME tick. Fine.

Let me look for the real bug in T-4: **`Grind_LatticeRollDeferredNote` when the gate opens: it's never cleared** — no, it's cleared in `TrySide`.

Hmm, but the C8 clear: `if(is_long) g_grind_vl_deferred_noted_long = false; else ...` runs after the gate block. But note it's NOT guarded by `depth >= max_layers` — well, TrySide is only called at cap. And it's a global clear, so calling the short's TrySide clears only the short's latch. Good.

T-5. Interactions.

- Nightly carry pass and I6: the gate writes no VL (no roll), so I6 (price from the VL) is unaffected while gated. But: the carry pass can MODIFY the exit order of a gated side? Let's think. The carry pass (`Grind_CarryOnTimerStep`) rewrites exit prices based on the entry + shift. While gated, the side's exits are at their original (entry + exit_pips) or last-rolled values. The carry pass may shift them. Then at release, the roll modifies the exit and `Grind_LatticeRollLayer` does `Grind_CarryShiftDelete(pos)` or `Grind_CarryRecordShift`. That's existing behaviour. Hmm, but the deferred roll at release would MODIFY an exit that the carry pass just moved. Note the gate does not stop the carry pass. Fine, but there's a real interaction: the deferred note's `level` is computed at release-time; the roll then clamps passive (C55 VC3) and fills. That's P4's hazard mitigated. OK.

- Reconstruction / ADR-163 rebuild after a restart while gated: the new globals `g_grind_vl_deferred_noted_*` are initialised to false, and `Grind_LatticeResetBackoff` clears them. But is `Grind_LatticeResetBackoff` called on reconstruction? A8 says it's a test reset only, no production caller. So after a restart, the latch is false (fresh globals). Fine. But the `from_msc`/extreme on restart as discussed.

- `ROLL_CLOSING_STUCK` (only evaluated inside the ungated loop: a closing layer during a long hold never warns). Yes: `Grind_LatticeNoteClosing` is called inside the loop after the gate block. While gated, the side returns before the loop, so a layer that started closing (exit_order_ticket=0, exit_position_ticket!=0) will never warn. Is that a problem? It's a designed consequence of the gate (no roll attempt). But consider: a layer's exit order filled (deal not processed) → `GRIND_ROLL_CLOSING`. While gated, we never reach `Grind_LatticeRollLayer`, so we never detect the closing. The layer's exit_position_ticket is set only by the deal processing in `Grind_HandleSideDealFill`. Hmm, the closing state is detected when `side.layers[idx].exit_position_ticket != 0` (the loop check) or when `Grind_LatticeRollLayer` returns `GRIND_ROLL_CLOSING`. While gated, the side never rolls, so a stuck closing layer is never warned. And more importantly: **the closing state (`g_grind_vl_closing_*`) is never RESET while gated** — but also never set. So it's inert. Acceptable? T-5 says "a closing layer during a long hold never warns". That's a designed loss of observability. I'd call it NEEDS-FIX or at least note. The smallest fix: nothing? Hmm. Since the gate holds, no roll is attempted, and the layer's exit will fill or the deal will be processed and the layer removed. The `ROLL_CLOSING_STUCK` warning is about a roll being blocked by a layer that can't be rolled. While gated we don't roll, so the warning is arguably irrelevant. But the closing state may PERSIST from before the gate engaged: e.g., the closing latch was set (ticket 7001, since T). Then the gate engages. The latch stays. `ROLL_CLOSING_STUCK` won't fire. Then at release, `TrySide` runs the loop: the candidate check... hmm, `Grind_LatticeCandidateIndex` skips layers with VL; the closing layer (exit_position_ticket != 0) → the loop detects it and calls `Grind_LatticeNoteClosing` → warns if the elapsed time >= 60s. So at release it warns. OK.

- ADR-155 commanded eject: `Grind_EjectPollCommand` runs in OnTick before the lattice. Unaffected. Unaffected by the gate.

- The breaker and quarantine: `blocked` short-circuits everything. Fine.

- "Anything that relied on TrySide running its loop every call at cap?" — the loop also handles the `ROLL_STRANDED` latch reset and the closing-state reset. The gate skips them. `Grind_LatticeResetClosingState` is skipped while gated → a stale closing latch persists. Also: `if(Grind_LatticeCandidateIndex(side, is_long) >= 0) { stranded latch = false; }` is skipped while gated → the stranded latch persists. Both are fine-ish.

T-6. Inputs and presets.

- A preset without `InpRollGateOpposite` takes the default -1. MT5 behaviour: ASSUMED (documented? MT5 uses the compiled default for inputs not present in the .set). I'll mark ASSUMED.
- Values above `max_layers`: e.g. N = 100 → the gate never holds (depth can't exceed 8... well, depth can exceed max_layers? `ArraySize(layers)` can be up to max_layers normally; but reconstruction or manual. So N=100 = effectively off. Should it FATAL? The design only validates -1 or >= 0 with lattice. So N=100 is accepted and is a no-op. Reasonable.
- Negative values below -1: `Grind_ValidateRollGateInputs` returns `gate == -1 || (gate >= 0 && lattice)`. For gate = -2: `-2 == -1` false; `(-2 >= 0)` false → returns false → FATAL. Good. RG1e tests it.
- The gate on with re-roll off: allowed. The gate blocks first rolls too — RG11 tests it (the side would strand without the gate). Hmm, RG11 says: at Adr165_Fixture with reroll OFF, today this side strands (LB8); with the gate it does not. OK.
- Anything that should FATAL and does not? `gate >= 0 && lattice` — what about gate >= 0 with lattice but reroll off? Allowed by design.
- What about gate == -1 and lattice true? Fine.

Hmm — one thing: the input is `int`. A preset with a double like `-1.0`? MT5 would reject or truncate. Not our concern.

T-7. Cost. Let me count the burst. At release, the loop runs up to max_layers = 8 first rolls, each `Grind_LatticeRollLayer` → 1 modify (if exit_order_ticket != 0) then `Grind_ExitQManageSide` → cancels holders and places required. Hmm. In the LB7 case, 5 rolls → 5 modify + 5 remove + 5 place = 15 requests. Plus at release the exit queue's restructure. So per side per release ~ up to 24. Nine instances → 216 requests in a short window if all release simultaneously. Realistically the releases are staggered. Fine.

But there's a subtle cost point: the gate holds → the held side sends nothing. But `Grind_LatticeTrySide` is still called every tick and returns 0 — no requests. But `Grind_LatticeTrackExtremes` runs every tick → `CopyTicksRange` every tick per side. That's a CPU cost, not a request. Fine.

T-8. Tests.

Which behaviour has no test that fails without it? Let me look for assertions that pass vacuously.

RG3d: `Adr162b_ArchiveFind("ROLL_DEFERRED", 0) != ""` — fails at the stubs (C7 stub = empty body, so no marker) → F. Good. But could it pass because of an earlier fixture's marker? `Adr162b_SeedLong8()` calls `Adr162b_Reset()` which calls `Grind_ArchiveTestReset()`. Let's check: `Adr162b_Reset()` → `Grind_TestEjectHarnessReset(); Grind_ArchiveTestReset(); Grind_LatticeResetBackoff(); Adr151_TestResetAll();`. So the archive queue is cleared. Good. But wait — `Adr162b_SeedLong8` calls `Adr162b_Reset` FIRST, then seeds. So the queue is empty at the start of each RG test. And `Grind_ArchiveTestConfigureCommon` re-enables. So `ArchiveFind` is meaningful.

BUT: does `Grind_ArchiveMarker` actually enqueue in the test mode? Need `Grind_ArchiveTestConfigureCommon` — the RG3 test relies on it via `Adr162b_SeedLong8`. OK.

Now, RG9b: after call 2 (gated, no new roll due since the level is already crossed? hmm). Let me trace RG9 carefully, since the prompt asks about RG7c specifically.

RG9: LB6 setup: SeedLong8, market 1.20590/1.20600. Level = 1.20600 (lowest entry 1.20700 minus add 10 pips = 1.20600). Crossed (ask 1.20600 <= 1.20600). 
- Call 1 `TryLong(T0, false, 0, 1)`: gate holds (1 > 0) → restart, note: depth 8 >= 8, level = 1.20600, mkt = ask = 1.20600, crossed → marker #0 + latch set. Returns 0.
- Call 2 `TryLong(T0+1, false, 0, 1)`: gate holds → restart; note: latch true → return. So no marker. RG9b: ArchiveFind("ROLL_DEFERRED", 1) == "" → G. Passes at both (at stubs, the stub note does nothing → also ""). Hmm — RG9b is a G because at the stubs no marker exists at all → index 1 is "". So it passes vacuously at the stubs. That's expected for a guard. But at the implementation it's real. OK.
- Call 3 `TryLong(T0+2, false, 0, 0)`: gate open (0 > 0 false) → clear latch → loop: level = 1.20600, mkt = ask 1.20600, crossed → candidate 7001 → roll → rc = 1. RG9c F: passes at the implementation, fails at the stubs (stub gate false → also rolls → rc = 1!). Wait: at the stubs, `Grind_RollGateHolds` returns false always, so call 3 rolls → rc = 1 → RG9c would PASS at the stubs?? Hmm. Let me re-check: RG9c is tagged F (fails at commit 1). Let's see: at commit 1, stub C3 `return false`, stub C6 empty, stub C7 empty. Call 3 with gate 0, opp 0 → stub holds false → proceeds to roll. So rc = 1 → the assertion passes at the stubs. So RG9c should NOT be F! But the prompt says the 31 tagged F all fail at the stubs, and RG9c is tagged F. Hmm, wait — the `AssertEqInt("RG9c (F)", Adr166_TryLong(ADR166_T0 + 2, false, 0, 0), 1);`. At the stubs, call 1 and call 2 also roll (the stub gate never holds!). Call 1: rolls 7001 (VL set). Call 2 (`TryLong(T0+1, false, 0, 1)`): the stubs ignore the gate → after call 1, 7001 has a VL; the candidate is now 7002; the level = `Grind_ComputeAddTarget` with any_vl → the anchor is the min effective = 1.20600 (VL of 7001) → level = 1.20600 - 0.00100 = 1.20500. Market ask 1.20600 → not crossed → break → rc = 0. So no second roll. So at the stubs, call 3: candidate = 7002, level = 1.20500, ask 1.20600 not crossed → rc = 0 → RG9c FAILS at the stubs (expects 1). Yes! So RG9c is F because prior calls in the same test rolled. Interesting.

Then `Grind_MarketTestSeed(1.20490, 1.20500, 0, 0)`: level = 1.20500, ask 1.20500 crossed. Call 4 `TryLong(T0+3, false, 0, 1)`: gate holds (opp 1 > 0) → restart, note: latch? At the implementation, call 3 cleared the latch (ungated), so the latch is false. Level = 1.20500 (the anchor is the VL of 7001 = 1.20600 → 1.20600 - 0.00100 = 1.20500). mkt = ask 1.20500, crossed → marker #1. RG9d F (marker #1 exists). Passes at the implementation; at the stubs, the gate never holds so the note never runs → marker #1 doesn't exist → fails. Good.

Hmm wait, at the stubs call 4 would ROLL (gate ignored): candidate 7002, level 1.20500, ask 1.20500 crossed → roll → no marker. So RG9d fails at the stubs. Good.

RG9e: `def0` contains `"opposite_depth":1` and `"gate":0`. The first marker is from call 1 with opp=1, gate=0. Good.

Now the prompt's claim about RG7c. RG7: `Adr162b_SeedShort8(); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);` Short levels: entries 1.18600..1.19300 (L0=7101 at 1.18600, ..., L7=7108 at 1.19300). The add level for a short = the HIGHEST effective entry + add = 1.19300 + 0.00100 = 1.19400. The bid 1.19400 >= 1.19400 → crossed. The candidate = 7101 (the lowest entry, i.e. the highest? `Grind_LatticeCandidateIndex` for a short picks the smallest entry: 1.18600 → 7101). RG7a: `TryShort(T0, false, 0, 1)` → gate holds → rc = 0 → F. At the stubs: no gate → rolls 7101 → rc = 1 → RG7a fails at the stubs. Good. RG7b: `Grind_VLHas(7101UL)` false. At the stubs, 7101 has a VL → fails. Good. 

Then `TryShort(T0+1, false, 0, 0)`: RG7c expects rc = 1. At the implementation: gate open → clear latch → roll. After RG7a ran (gated, no roll), the candidate is 7101, level = 1.19400, bid = 1.19400 crossed → roll → rc = 1. So RG7c passes at the implementation.

At the stubs: RG7a already rolled 7101 (rc=1). Now the second call `TryShort(T0+1, false, 0, 0)`: candidate = 7102 (the next unrolled lowest = 1.18700). Level: any_vl = true → anchor = the max effective of a short = 1.19400 (VL of 7101) → level = 1.19400 + 0.00100 = 1.19500. The bid = 1.19400 >= 1.19500? No → not crossed → rc = 0. So RG7c FAILS at the stubs (expects 1, gets 0). The prompt says RG7c is labelled (G) but actually fails at the stubs for this reason. Confirmed: the prompt's reading is CORRECT. RG7c is mis-tagged: it should be F. So the count "31 F" would be 32 F, and 2548/2580 = 32 failing. Indeed the prompt says: "failing exactly the 32 tests tagged to fail (31 tagged F plus RG7c, whose '(G)' label is a derivation slip: it fails at the stubs for the reason in T-8)". So the prompt has already flagged this. My job: confirm. Yes, confirmed. The fix: re-tag RG7c as F (a label, not code). 

Hmm, but wait: this means the design's claim "31 F, 24 G" is wrong by one; the actual is 32 F, 23 G. The suite count at commit 1 would be 2548 passing = 2580 - 32. That matches the prompt's "2548/2580". And 2580 total with 55 new assertions... 2525 + 55 = 2580. Good. So the test file as attached has RG7c tagged (G). The smallest fix: change the label to (F). Good.

Now, other test issues. Let me look for genuinely vacuous assertions.

RG4d: `Adr162b_ArchiveFind("ROLL_DEFERRED", 0) == ""` — G. At the stubs it passes (no marker). At the implementation it passes (gate open). But: is there any prior marker in the queue? RG4 starts with `Adr162b_SeedLong8()` which resets. Good.

RG3e: `ROLL_STRANDED` == "" — G. Fine.

RG5d: `ROLL_STRANDED` == "" — G. But at the implementation, does the gated path avoid stranding? Yes. At the stubs, the Adr165_Fixture with reroll=... hold on, RG5 calls `Adr166_TryLong(T0, true, 0, 1)` with reroll = true. At the stubs (gate false), the re-roll path: Adr165_Fixture = all eight long rolled, VLs 1.20600 down to 1.19900, market 1.19000/1.19010. The candidate is -1 (all rolled). The level = the max effective... anchor = the min effective = 1.19900 (VL of 7008)? Wait, for a long, `Grind_ComputeAddTarget` with any_vl: anchor = the min effective entry = the VLs: 1.20600 for 7001 down to 1.19900 for 7008 → min = 1.19900 → level = 1.19900 - 0.00100 = 1.19800. The probe: min(mkt, extreme). The extreme = 0 (not set in the fixture?) → probe = mkt = ask 1.19010. 1.19010 <= 1.19800 → crossed. Then reroll: `Grind_LatticeRerollIndex` → the highest VL = 1.20600 (7001). Reroll 7001 to 1.19800?? Hmm, the design says RR4: Adr165_Fixture, re-roll: VL(7001) → 1.19800. Yes. So at the stubs, the re-roll happens (rc=1) → RG5a expects 0 → fails. RG5b: `Grind_VLGet(7001) == 1.20600` at the stubs → 1.19800 → fails (expects 1.20600). RG5c: no marker at the stubs → fails. RG5d: `ROLL_STRANDED` == "" → at the stubs, does `Grind_LatticeMaybeStranded` fire? No: the reroll succeeded (no stranded). So "" → passes at both. G. OK.

RG11: `Adr165_Fixture(); Adr166_TryLong(T0, false, 0, 1)` with reroll FALSE. At the implementation: gated → restart + note + return → no `ROLL_STRANDED` (the note doesn't strand) → RG11a F (passes at the implementation, fails at the stubs where the side strands). At the stubs: reroll=false, candidate -1 → `if(!reroll || paused)` → `Grind_LatticeMaybeStranded(level=1.19800, mkt=1.19010)`: the stranded level = 1.19800 - (2-1)*0.00100 = 1.19700; is the market crossed? 1.19010 <= 1.19700 → yes → warns → RG11a fails at the stubs. Good.

RG12: `Adr165_Fixture(); Adr166_OneShort();` → short depth 1. `Adr166_OnTick(T0, true, 0)`: the long's opp = the short's depth = 1 → the gate holds (1 > 0) → the long is gated → no reroll. RG12a expects `VLGet(7001) == 1.20600` (unchanged). At the implementation: passes. At the stubs: the gate never holds → the long re-rolls → VL = 1.19800 → RG12a fails. Good (F).

Then `Adr166_OnTick(T0+1, true, -1)`: gate off → reroll → 1.19800. RG12b G: passes at both (at the stubs it already re-rolled in the previous call, so it's already 1.19800; but wait, at the stubs the first call set it to 1.19800 and the second call would try to reroll AGAIN: `Grind_LatticeRerollIndex` → the highest VL. After the first reroll, 7001's VL = 1.19800; the others are 1.20500...1.19900. The highest VL is now 7002's 1.20500? Hmm, wait, the fixture set VLs 1.20600 down to 1.19900 for 7001..7008. After rerolling 7001 to 1.19800, the highest VL is 7002 = 1.20500. So the second call rerolls 7002 → its VL becomes... the level = the min effective = 1.19800 (7001) → level = 1.19800 - 0.00100 = 1.19700. Probe = min(1.19010, extreme) → 1.19010 <= 1.19700 crossed → reroll 7002 to 1.19700. So RG12b expects 7001's VL == 1.19800 → still true at the stubs. So G passes. Good.

Hmm, but that means RG12b doesn't verify that the second call re-rolls 7001; it just checks 7001 is still 1.19800. Vacuous-ish but passes either way. Fine as a G.

RG12c: `Adr162b_Reset(); Adr162b_SeedShort8(); Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.18000, 7001UL, 0, 5.0); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0); Adr166_OnTick(T0, false, 0);` → the short's opp = the long's depth = 1 → the gate holds → no roll → `Grind_VLHas(7101)` false. F: at the stubs the short rolls → true → fails. Good.

Hmm, careful: `Adr162b_SeedShort8` calls `Adr162b_Reset` which calls `Adr151_TestResetAll` — does that clear the long layers? Presumably yes. Then `Adr151_TestSetupLongLayer` sets 1 long layer at 1.18000. So the long depth = 1. Good.

RG13: the dip test. Let me trace at the implementation.

`C55_Reset(); Adr162b_SeedLong8(); C55_OpenTimes(true, D'2026.09.28 09:00'); Adr166_OneShort();` → the long has 8 layers with open times 09:00, 09:01, ..., 09:07. The short has 1 layer (7101 at 1.20800). 

`Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);` → bid 1.20690, ask 1.20700.
`Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);` → a test tick at 09:30 with ask 1.20590.
`Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:00' * 1000);` → market time = 10:00.
`Adr166_OnTick(D'2026.09.28 10:00', false, 0);`

`OnTick` → `Grind_LatticeTrackExtremes(magic, 8, now=10:00)`:
- Long: depth 8 = cap. tracking false initially → newest open = 09:07 (7008) → from_msc = max(09:07:01, 10:00 - 24h) = 09:07:01. tracking = true. CopyTicks(from = 09:07:01) → the test tick at 09:30 qualifies (09:30 >= 09:07:01) → n=1 → FoldExtreme: the tick extreme = 1.20590; the live ask = 1.20700 → extreme = min(1.20590, 1.20700) = 1.20590. from_msc = 09:30:00.001.
- Short: depth 1 < 8 → the short's tracking resets, deferred latch cleared, etc.

Then the long's `TrySide` with roll_gate = 0, opp = `Grind_SideDepth(g_grind_short)` = 1 → the gate holds → `RollGateRestartExtreme(true)`: extreme = 0, from_msc = 10:00:00.001. Then the note: depth 8 >= 8; level = 1.20600; mkt = ask = 1.20700; crossed? 1.20700 <= 1.20600? No → no marker. Latch stays false.

RG13a: `Grind_VLHas(7001)` false → at the implementation, no roll → false → passes (F). At the stubs: no gate → the loop: probe = min(mkt=1.20700, extreme=1.20590) = 1.20590 <= 1.20600 → crossed → roll 7001 → VL set → RG13a fails. Good.

Then `ArrayResize(g_grind_short.layers, 0); Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:01' * 1000); Adr166_OnTick(D'2026.09.28 10:01', false, 0);`

- TrackExtremes: the long, tracking true, from_msc = 10:00:00.001 → CopyTicks(10:00:00.001) → the upper bound = MarketTimeMsc() = 10:01:00.000. The test tick at 09:30 is < from_msc → skipped → n=0 → FoldExtreme: no tick extreme → extreme stays 0 → then the live ask 1.20700 → extreme = 1.20700. (Note: `Grind_LatticeFoldExtreme` folds the live price ALWAYS.)
- The short: depth 0 < 8 → reset.
- The long's TrySide: gate: opp = 0 → 0 > 0 false → the gate is open → clear the latch → the loop: level = 1.20600; mkt = 1.20700; probe = min(1.20700, extreme=1.20700) = 1.20700; crossed? 1.20700 <= 1.20600? No → break → rc = 0. No roll.
- RG13b: `Grind_VLHas(7001)` false → passes at the implementation. At the stubs: the same computation (the extreme = 1.20700) → no roll. Hmm, wait, at the stubs, call 1 already rolled 7001 (RG13a failed). So at the stubs, `Grind_VLHas(7001)` = TRUE at RG13b → the assertion expects false → RG13b FAILS at the stubs. Good. Yes, the design says a and b fail at commit 1.

Then `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0); Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:02' * 1000); Adr166_OnTick(D'2026.09.28 10:02', false, 0);`
- TrackExtremes: from_msc = 10:00:00.001 → CopyTicks to 10:02 → no test ticks → n=0 → extreme = the live ask = 1.20600.
- TrySide: gate open (opp = 0) → clear latch → level = 1.20600, mkt = 1.20600, probe = 1.20600 → crossed → roll 7001 → VL = 1.20600. RG13c G: passes at both? At the stubs: 7001 was already rolled in call 1 with VL 1.20600; then in call 3 (10:02) would the stub re-attempt? At the stubs, after call 1, the candidate = 7002 (7001 has a VL); level = the min effective = 1.20600 → 1.20600 - 0.00100 = 1.20500; the probe = min(1.20600, extreme) → is 1.20600 <= 1.20500? No → no roll. So 7001's VL stays 1.20600 → RG13c passes at the stubs. Good, G.

Hmm, but at the implementation: does `Adr166_OnTick` at 10:00 also PLACE anything? The `Grind_LatticeRollLayer`→`Grind_ExitQManageSide`. Fine.

Hmm, RG13: is the market-time seam cleared? `Grind_MarketTestReset()` is called at the end. Good. But if RG13 fails mid-way (at the stubs, `AssertFalse` records but continues), the seam is reset at the end. OK.

Wait, one issue with RG13: at the implementation, at 10:01 the gate is OPEN (opp=0), so the `ROLL_DEFERRED` latch is cleared and the loop runs but doesn't roll. Fine.

Now, potential vacuous tests. Let me look for the classic issues:

(a) RG3c: `g_grind_order_test_modify_calls == 0`. `Adr162b_SeedLong8` calls `Adr162b_Reset` → `Grind_TestEjectHarnessReset` (which presumably resets the order counters) — hmm, does `Adr162b_Reset` reset `g_grind_order_test_modify_calls`? `Adr162b_Reset` calls `Grind_TestEjectHarnessReset()`. We don't have that source. `Adr162b_SeedLong8` itself calls `Grind_OrderTestUpsert` (not modify). Then `Grind_ArchiveTestConfigureCommon`. Hmm. The order counters `g_grind_order_test_modify_calls` are reset by `Grind_OrderTestReset()`. Is that called by `Adr162b_Reset`? `Grind_TestEjectHarnessReset` — likely yes (the LB tests rely on `modify_calls == 1` after seeding). In LB6, `AssertTrue("LB6 calls", g_grind_order_test_modify_calls == 1 && ...)` after seeding and one roll → so the counters must be zeroed by the seed. So yes, likely `Grind_TestEjectHarnessReset` calls `Grind_OrderTestReset()`. I'll assume it.

Hmm, actually `Adr162b_SeedLong8` calls `Adr162b_Reset()` which calls `Grind_TestEjectHarnessReset()`. Then `Adr151_TestSeedSlotSeams(200,100,0)`. The counters. OK, ASSUMED.

(b) RG8: the extreme restart. Let's trace at the implementation:
```
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Grind_MarketTestSeedTimeMsc(1790000000000);
   g_grind_vl_extreme_long = 1.20190;
   g_grind_vl_tracking_long = false;
   g_grind_vl_from_msc_long = 1000;
   Grind_LatticeTrySide(g_grind_long, true, ..., now=ADR166_T0, extreme=1.20190, false, 0, 1);
```
Note: this calls `TrySide` DIRECTLY (not via OnTick), so `TrackExtremes` does NOT run. The gate holds (opp=1) → restart: extreme = 0, tracking = true, from_msc = 1790000000000 + 1. RG8a/b/c: pass at the implementation. At the stubs (C6 empty): extreme stays 1.20190, tracking stays false, from = 1000 → fail. Good.

But: the test sets `g_grind_vl_tracking_long = false` then calls TrySide directly. In production, `TrySide` is only called after `TrackExtremes`, so tracking would be true. Fine.

Hmm, RG8 does NOT test the "dead market / from_msc > market time" or `CopyTicksRange` -1/0 cases. The threat T-2 mentions them. So a test gap: no test for the release-call behaviour when no new tick exists (the extreme stuck / the missed-crossing case). And no test that a gated restart does not clobber the OTHER side's tracking (T-2's "touches only the gated side" — G5 verified by code, untested; actually RG8 only checks the long; a mirror would be needed. The short mirror is missing but the code is symmetric... Actually the code is symmetric, and RG7 covers the short gate but not the short restart. Low risk.)

(c) RG14: the closing state and backoff. At the implementation, the gated path returns before the loop → the closing state and fail count are untouched. RG14c: `g_grind_vl_fail_count_long == 2`. At the stubs: the gate never holds → the loop rolls 7001 → a successful roll → `g_grind_vl_fail_count_long = 0` → RG14c fails (expects 2). Good. RG14a: the closing ticket. At the stubs: the loop: `side.layers[idx].exit_position_ticket != 0` — for 7001, exit_position_ticket = 0 in the seed (only the exit order 8001 exists). Hmm, the test sets `g_grind_vl_closing_ticket_long = 7001` but the LAYER's exit_position_ticket is 0. So the loop proceeds to roll 7001 (the exit_order_ticket 8001 exists → modify). After the roll, at the end `if(!closing_stop) Grind_LatticeResetClosingState(true)` → the closing ticket → 0 → RG14a fails (expects 7001). Good. RG14b similarly. RG14d: `ROLL_CLOSING_STUCK` == "" → G at both.

So RG14 is fine.

(d) Is there a test that fails WITHOUT the extreme restart? RG13a/b: at commit 1 the C6 stub is empty AND the gate... wait, at commit 1, C3 is stubbed `return false`, so the gate never holds, so `RollGateRestartExtreme` is never called, so testing C6 requires C3. At commit 2 both are implemented. Hmm: so the "F" tests for RG8 fail at commit 1 due to the C6 stub (empty) — but at commit 1 the C3 stub means the gate block never runs, so `Grind_LatticeRollGateRestartExtreme` is never CALLED. RG8 calls `TrySide` directly via its own call — no wait, RG8 calls `Grind_LatticeTrySide` directly. With C3 stubbed (holds = false), the gate block is skipped entirely → `RollGateRestartExtreme` is not called → the empty stub doesn't matter. So RG8 fails at commit 1 because the gate block is skipped (extreme stays 1.20190). Correct — it's testing the gate+restart combination. Fine.

(e) What behaviour has NO test that fails without it? Let's enumerate the changes:
- C1 input: tested implicitly (RG4g, RG6).
- C2 validate: RG1.
- C3 holds: RG2.
- C4 globals: implicitly.
- C5 clears: the below-cap clear → tested? T-3 says "cleared when... below cap". Is there a test that the latch clears below cap and re-arms? RG9 tests re-arm after an ungated call. The below-cap clear: no test. `Grind_LatticeResetBackoff` clear: no test (RG14 doesn't). Hmm: the C5 change in `Grind_LatticeResetBackoff` sets both deferred latches to false. Is that needed? `Adr162b_Reset` calls `Grind_LatticeResetBackoff`, so all RG tests rely on it to clear the latch between tests! Without C5's ResetBackoff clear, the latch would leak across tests. Would any test fail? RG9 sets the latch, then `Adr162b_Reset` at the end. RG9d relies on the latch being re-armed — call 3 clears it (ungated). So RG9 doesn't need the reset clear. Hmm. But some test might: RG3 sets the latch; then `Adr162b_Reset()`; the next test RG4 (gate open) → the ungated clear handles it. RG5 (gate holds) → the note would return immediately if the latch were stale → RG5c would fail! Let's check the order of tests: RG1, RG2 (no note), RG3 (sets the long's latch), RG4 (gate open → clears), RG5 (gate holds → sets), RG6... Actually the order matters. Suppose C5's ResetBackoff clear were absent: after RG3, the long's latch = true. RG4's first call is ungated → the C8 clear sets it false → then RG5 is fine. But what about RG3's own start? RG1/RG2 don't set it. So RG3 is the first to set it. So actually the tests might pass without C5's reset clear, meaning C5's `ResetBackoff` change is untested. That's fine (it's a hygiene fix).

Hmm, but there's a subtle issue: the tests are run as one big suite in `fxgrind_tests.mq5`. Order: all the ADR166 tests are called in order after `Test_RN2_NoteThrottles()`. Within ADR166: RG1..RG14. But are there OTHER tests AFTER ADR166 that could be affected by a leaked latch? Don't know. The reset clear handles it.

Hmm, OK.

(f) A vacuous assertion: RG4e `modify_calls == 1` — fine. RG6a `rc == 1` — at the stubs, the gate never holds so it also rolls → rc = 1 → passes at both. G. OK. But wait: RG6a sets gate=2, opp=2 → `Grind_RollGateHolds(2,2)` = (2>=0 && 2>2) = false → so even the real implementation doesn't gate. And the test expects rc=1. So RG6a is a "boundary" guard: it passes at both commits. Good.

RG10: `Grind_MarketTestSeed(1.20690, 1.20700, 0, 0)` → level 1.20600, mkt 1.20700 → not crossed → rc = 0, no marker. G at both. Good.

Hmm, but RG10a: at the implementation, the gate holds (opp=1) → `RollGateRestartExtreme` + the note (no marker, not crossed) → return 0. rc = 0. Good. At the stubs: the loop: level 1.20600, probe = min(1.20700, extreme=0) → the `extreme > 0.0` check: extreme = 0 → probe = mkt = 1.20700 → not crossed → rc = 0. Good.

(g) Now the missing test: **the deferred latch is not cleared when the gate holds but no roll is due.** RG9 covers call 1 (roll due, marker) then call 2 (still gated, no new roll due since the level is already crossed — hmm, actually call 2 has the same market, so the level IS still crossed; the latch blocks the second marker). OK.

(h) Missing test: the ROLL_DEFERRED archive-only (no telemetry emit). G6 says no `Grind_TelemetryEmit`. Is there a test that the telemetry emit count is unchanged? Probably not. Test gap.

(i) Missing test: the `ROLL_DEFERRED` for the short side (the mirror). RG7 tests the short gate but not the short's marker. Gap (low).

(j) Missing test: `InpRollGateOpposite` FATAL ordering (G2). RG1 tests the pure function; no test that OnInit returns INIT_FAILED. Gap but the pure function is tested.

(k) Missing test: the `LATTICE_CONFIG` `roll_gate` field. No test. Gap.

Now, the BIG question: are there any actual BUGS in the implementation?

Let me look very carefully at `Grind_LatticeOnTick` and the `blocked` flag:

```
void Grind_LatticeOnTick(..., const bool reroll = false, const int roll_gate = -1)
{
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;

   if(Grind_SideDepth(g_grind_long) >= max_layers)
      Grind_LatticeTrySide(g_grind_long, ..., reroll, roll_gate, Grind_SideDepth(g_grind_short));
   if(Grind_SideDepth(g_grind_short) >= max_layers) {
      ...
      Grind_LatticeTrySide(g_grind_short, ..., reroll, roll_gate, Grind_SideDepth(g_grind_long));
   }
}
```

The short's `opposite_depth` is `Grind_SideDepth(g_grind_long)` evaluated at the moment of the short's call — after the long's TrySide. Since the long's TrySide cannot change the LONG's depth (no layer add/remove in rolls), this equals the pre-call depth. Fine. UNLESS... `Grind_LatticeRollLayer` → `Grind_ExitQManageSide` → `Grind_ExitQHoldCancelLayer` → `Grind_ExitQFindExitDealPosition` → no layer changes. And the roll fills aren't processed synchronously. So the long's depth is stable within the call. VERIFIED for T-1.

Hmm, BUT: consider the long's TrySide invoking `Grind_LatticeRollLayer` which places a new exit order... no depth change. OK.

Now, is there a path where the gate decision for one side changes the other's? The gate is a pure function of (roll_gate, opposite_depth). The long's TrySide can't change the short's depth. So no. VERIFIED.

Now let me check the `Grind_LatticeRollDeferredNote` for a subtle bug: it uses `Grind_ComputeAddTarget(side, is_long, add_pips)` — the same level the loop uses. Good. And `Grind_LatticeLevelCrossed(is_long, mkt, level)`. Fine.

But: the note checks `if(Grind_SideDepth(side) < max_layers) return;` — TrySide is only called at cap, so redundant. Fine.

Hmm — what about `level <= 0.0`? `Grind_Normalize(Grind_ComputeAddTarget(...))`. If the add target is negative (unlikely), returns. Fine.

Now the deferred marker's `"depth"` and `"opposite_depth"` are ints. Fine.

Now let's hunt for the ACTUAL flaw. Let me reconsider the ordering in `Grind_LatticeTrySide`:

```
   if(!enabled || blocked)
      return 0;

   datetime backoff = is_long ? g_grind_vl_backoff_long : g_grind_vl_backoff_short;
   if(now < backoff)
      return 0;

   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
      Grind_LatticeRollDeferredNote(...);
      return 0;
   }
   if(is_long)
      g_grind_vl_deferred_noted_long = false;
   else
      g_grind_vl_deferred_noted_short = false;
```

Interesting: the deferred latch clear happens on an ungated call. Consider: the gate holds, the note fires (latch = true). Then the gate holds but the market moves away (no roll due). Then the gate opens but the market is far away (no roll possible). The latch is cleared → OK, and re-arms if the gate re-engages and a roll becomes due. Fine.

Now, "at most once per gated episode per side" — what defines an episode? Gated → ungated → gated. RG9 covers that.

Hmm, but consider oscillation on ALTERNATE ticks: gate holds, ungated, holds, ungated... Each "episode" is one tick, so the marker could fire once per episode → spam. Actually no: the note fires only if a roll is DUE (level crossed). If the gate oscillates every tick, the ungated tick would ROLL (if due), clearing the situation. So no spam. OK.

Now let's look at a real potential defect: **`Grind_LatticeRollGateRestartExtreme` resets `from_msc` to `market time + 1` EVERY gated call. But `Grind_LatticeTrackOneSide` advances `g_grind_vl_from_msc_long = msc[n-1] + 1` when n > 0. And the restart sets it to `t+1`. If the market's tick time is behind the wall clock (e.g., in the tester or a stale feed), the restart could push from_msc far into the future, causing `CopyTicksRange(from > to)` forever → the extreme never folds ticks, only the live price. Then at release, the extreme = the live price at the last gated call... no: at release, `TrackExtremes` runs with from_msc = (last gated call's t)+1; if that's in the future, CopyTicksRange returns -1 or 0 → with -1, return early (no live fold); with 0, fold the live price → extreme = live. So the release roll uses `min(mkt, extreme) = mkt`. That means the roll happens on the CURRENT market only. That's the intended "restart" semantics. Fine.

Hmm, but a nastier one: **the restart sets `tracking = true` unconditionally, so `TrackOneSide` SKIPS the below-cap... no, the below-cap check happens first. So if the side is at cap, tracking = true → the init block is skipped → from_msc stays t+1. Good.

But here's a subtle interaction with **`GRIND_VL_CATCHUP_MAX_SEC`**: The restart sets from_msc = t+1, discarding the 24h catch-up. So a restart at release... The restart happens while gated. Fine.

Now let me look for the flaw with the "closing state" (T-5): the gated path skips `Grind_LatticeResetClosingState`. Consider: the side had a closing layer noted (ticket 7001, since T0). Then the closing resolves (the layer's exit fills and the layer is removed). While gated, `Grind_LatticeResetClosingState` is never called, so `g_grind_vl_closing_ticket_long` stays 7001 and `since` stays T0. Then the gate opens. The first ungated call: the loop runs; if the candidate list is empty (all rolled), `Grind_LatticeMaybeStranded`... hmm, the loop: `if(Grind_LatticeCandidateIndex(...) >= 0)` → if a candidate exists, clear the stranded latch. Then the loop: level, probe, crossed? If not crossed → break → `if(!closing_stop) Grind_LatticeResetClosingState(true)` → resets. So the stale closing ticket is reset when an ungated call runs (regardless of the crossing). Wait — the reset happens at the end `if(!closing_stop) Grind_LatticeResetClosingState(is_long);` which is reached whenever the loop breaks normally. So even if no level is crossed, the reset runs. Good, so the stale latch is cleared on the first ungated call. Unless the loop breaks via... `break` statements all lead to the end. So yes, the reset runs. Fine. So no issue for T-5's closing state, except during the hold (no warning). Acceptable.

Hmm, but WAIT. There's a real bug here: **the closing state is reset on the first ungated call even if the layer is still closing.** No — the reset is skipped if `closing_stop`. Fine.

Let me now check the **`Grind_LatticeResetBackoff`** (C5): it sets the deferred latches false, and also `Grind_LatticeTestTicksReset()`. Fine.

Now, T-6: the input validation and the FATAL ordering (G2). Verified.

Hmm, now let me look at something the prompt hints at: "The `OnInit` prints `GRIND_ROLL_GATE opposite_max=`". That's a NEW log line. A14 says the log checker reads `GRIND_REROLL enable=` by pattern; a new line doesn't disturb. Fine.

Now let me look for a genuine flaw in the newly added code in fxgrind.mq5's OnInit: the FATAL is placed AFTER `Grind_ValidateRerollInputs` and BEFORE `Grind_MagicLockClaim`. Good.

Hmm, now: **`LATTICE_CONFIG` detail becomes `{"enable":%s,"reroll":%s,"roll_gate":%d}`**. In the code:
```
   Grind_ArchiveMarker("INFO", "LATTICE_CONFIG", "", 0,
                       StringFormat("{\"enable\":%s,\"reroll\":%s,\"roll_gate\":%d}",
                                    InpVirtualLattice ? "true" : "false",
                                    InpLatticeReroll ? "true" : "false",
                                    InpRollGateOpposite));
```
Fine.

Now let me examine the **test-mechanics fixes at `634c7ea`**: "the implementation with three test-mechanics fixes". Which three? Probably RG7c's tag, and...? Hmm, the prompt says the implementation with three test-mechanics fixes gets 2580/2580. The attached test file has RG7c tagged (G) — so the fix would change it to (F)? But then 2580/2580 requires ALL assertions to pass at commit 2, both F and G. Let me check whether at commit 2 RG7c passes: yes, rc = 1. So the tag doesn't matter for the commit-2 count. The three test-mechanics fixes are probably things like: `Adr166_OneShort` setting `exit_target` via `Grind_ExitQFormulaTarget`, `Grind_MarketTestReset()` calls in RG8/RG13, and... Let me look for something that would BREAK at commit 2 in the attached test file.

Hmm! Let me check RG8: `Grind_LatticeTrySide(g_grind_long, true, ..., ADR166_T0, 1.20190, false, 0, 1)`. The extreme parameter is passed as 1.20190. The gate holds → restart. Then the note: depth 8, level = 1.20600, mkt = ask. `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0)` → ask = 1.20600 → crossed → the note fires (marker). That's fine; RG8 doesn't assert on the marker. Then `Grind_MarketTestReset()` and `Adr162b_Reset()`. Fine.

Hmm, RG8's `Grind_MarketTestSeedTimeMsc(1790000000000)` sets the time to a 2026-09-17-ish msce... 1790000000000 ms = 2026-09-17? Let me compute: 1790000000 s ≈ 56.7 years after 1970 → 2026-09. OK. And ADR166_T0 = 2026-09-28. The restart uses `Grind_MarketTimeMsc()` = 1790000000000 → from_msc = ...001. RG8c checks that. Fine.

Now let me examine RG12 more carefully at commit 2, because I suspect a problem.

`Adr165_Fixture()` — we don't have the source, but per A11: "Adr165_Fixture (all eight long rolled, VLs 1.20600 down to 1.19900, market 1.19000 / 1.19010), ADR165_T0". And `Adr166_OneShort()` adds one short layer with entry 1.20800, ticket 7101.

`Adr166_OnTick(ADR166_T0, true, 0)`: `Grind_LatticeOnTick(magic, "OPT", 0.01, true, 5.0, 10.0, 8, false, now, 5.0, 10.0, true, 0)`.

Inside: `Grind_LatticeTrackExtremes(magic, 8, now)`:
- Long: depth 8 = cap; tracking? The fixture may or may not set tracking. If tracking is false: the init block needs `Grind_CarryPositionOpenTime(pos, magic, ot)` for each layer. In `Grind_OrderTestActive` mode... `Grind_CarryPositionOpenTime` — is it stubbed in the test harness? If it fails for any layer, `return` (the whole tracking for that side returns). Hmm, the fixture presumably seeds open times. If it returns early, the extreme stays 0. Then `TrySide` with extreme = 0 → probe = mkt.
- The gate: the long's opp = the short's depth = 1 → the gate holds → restart → the note: level = `Grind_ComputeAddTarget(g_grind_long, true, 10.0)` → all rolled → anchor = the min effective = 1.19900 → level = 1.19900 - 0.00100 = 1.19800. mkt = ask = 1.19010. Crossed? 1.19010 <= 1.19800 → YES → the marker fires (ROLL_DEFERRED #0). Then `TrySide` returns 0.

So RG12a: `Grind_VLGet(7001) == 1.20600` → at commit 2, unchanged → passes. Good.
Then `Adr166_OnTick(ADR166_T0 + 1, true, -1)`: gate off → clear the latch → `TrySide` with extreme = g_grind_vl_extreme_long. Hmm, what is the extreme here? At the start of this OnTick, `TrackExtremes` runs: the long's tracking = true (set by the restart), from_msc = the restart's t+1. In the test, `Grind_MarketTimeMsc()` — is the market-time seam seeded? `Adr165_Fixture` presumably calls `Grind_MarketTestSeed(1.19000, 1.19010, ...)` but maybe NOT the time seam. So `Grind_MarketTimeMsc()` returns `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` — the REAL symbol time in the tester! Hmm. In the strategy tester, SYMBOL_TIME_MSC is the current tester time. And `Grind_LatticeCopyTicks` in the test mode (g_grind_order_test_active = true) uses the test tick arrays. So `Grind_LatticeTickExtreme` folds the test ticks (none) and the live price (ask 1.19010). So the extreme = 1.19010. Then `TrySide`: reroll, gate off → candidate = -1 → `Grind_LatticeRerollIndex` → the highest VL = 7001 (1.20600) → reroll 7001: level = 1.19800. probe = min(mkt=1.19010, extreme=1.19010) = 1.19010 <= 1.19800 → crossed → modify 8001(?) → VL(7001) = 1.19800. RG12b: passes.

Hmm, wait: does `Adr165_Fixture` set the extreme or leave tracking false? Doesn't matter much.

Now, the potential issue: `Grind_LatticeCopyTicks` in the test mode filters by `from_msc` from the test tick array; there are no test ticks in RG12, so n = 0 → `Grind_LatticeFoldExtreme` folds the live price → extreme = 1.19010. Fine.

OK so RG12 works.

Now let me think about **whether the attached test file (as given) actually yields 2580/2580 at commit 2**, i.e., whether there's a hidden failure. The prompt says the implementation with three test-mechanics fixes (`634c7ea`) gets 2580/2580 on both. So the attached test file might be the FIXED version already? Hmm — "the attached files" include `fxgrind_tests_adr166.mqh`. The prompt says the branch is tested: at the stubs 2548/2580 failing exactly the 32; the implementation with three test-mechanics fixes 2580/2580. So the attached test file may be either version. Since RG7c is still tagged (G) in the attached file, and the prompt says the "(G)" label is a derivation slip... So the attached test file is the PRE-fix (commit 1) version? Or the fixes are elsewhere. Hmm.

Let me hunt for a test that would FAIL at commit 2 with the attached file. Let me re-check RG13c at commit 2 in detail.

RG13 at commit 2: at the 10:00 call, the long is gated (opp = 1). The restart sets from_msc = 10:00:00.001. At the 10:01 call, opp = 0 (the short's layers resized to 0) → the gate is open → clear the latch → the loop does not roll. Then at 10:02: the market is 1.20590/1.20600, gate open, level 1.20600, crossed → roll → VL(7001) = 1.20600. RG13c passes.

Hmm, but hold on: at the 10:01 call, `Grind_LatticeOnTick` → `TrackExtremes` → the long's tracking is TRUE (from the restart), from_msc = 10:00:00.001 → `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, 10:00:00.001, MarketTimeMsc())`. In the TEST mode, this is `Grind_LatticeCopyTicks` which uses the test ticks — n = 0 → fold the live ask 1.20700 → extreme = 1.20700. Then the loop: probe = min(1.20700, 1.20700) = 1.20700, level 1.20600 → not crossed → no roll. Good.

Then at 10:02: `TrackExtremes` → from_msc = 10:00:00.001 (unchanged since n = 0) → n = 0 → extreme = the live ask 1.20600. The loop: probe = 1.20600, level = 1.20600 → crossed → roll. Good.

Now, is `C55_OpenTimes` giving the layers open times 09:00 + 60*i? Yes: `Grind_CarryTestSetOpenTime(pos, first + 60 * i)`. So layer 7008 (i=7) opens at 09:07. `Grind_CarryPositionOpenTime` in the test mode returns that. So the init: newest = 09:07 → from_msc = 09:07:01. The test tick at 09:30 qualifies. Good.

Hmm, is `Grind_CarryPositionOpenTime` hooked to the test seam? `C55_OpenTimes` uses `Grind_CarryTestSetOpenTime`, so yes.

OK. Now, let's check `RG13a` at commit 2 again: at 10:00, `TrackExtremes` folds the 09:30 tick → extreme = 1.20590, then `TrySide` is gated → restart → extreme = 0. RG13a checks `Grind_VLHas(7001)` false → passes. Good. And the gate's restart DID discard the 09:30 dip. 

Now the critical question for T-2: **is the 09:30 dip truly not replayed at release?** At the 10:01 call, from_msc = 10:00:00.001 → the 09:30 tick is excluded → extreme = the live ask only → no replay. Good. But note: the release (10:01) uses `Grind_LatticeCopyTicks(from_msc=10:00:00.001, ...)`. If the EA had NOT restarted the extreme (e.g., the side was in backoff when gated), the dip WOULD be replayed. That's the hole I identified. Let me nail it down with quotes.

Path: the side is capped; `now < backoff` → `return 0;` happens BEFORE the gate block, so `Grind_LatticeRollGateRestartExtreme` is not called. How can the side be in backoff while the gate engages/held? Backoff is set on a roll modify failure. Scenario: the side is gated (gate holds) — no roll attempt, so no new backoff. The backoff must come from BEFORE the gate engaged. Timeline: T0: the long rolls; the modify fails → backoff_long = T0 + 60. At T0+1: the short fills a layer (or already had layers) → the gate now holds for the long. From T0+1 to T0+59, the long's TrySide returns at the backoff check → NO restart → the extreme keeps folding (TrackExtremes runs before TrySide in OnTick, independent of the gate). At T0+60: the backoff expires. If the gate still holds → the restart happens (the extreme is discarded). If the gate has opened by T0+60 (the short's layer exited/scalped) → the latch clear + the loop with the extreme folding the dip from [T0+1, T0+60] → the roll replays the dip that occurred during the deferral → P4's defect resurfaces. 

Is this reachable? It requires the opposite side to hold > N layers during the backoff (so the gate "held") and to drop to <= N at the first post-backoff tick. Yes, plausible: the short scalps out at exactly that moment. And the modify failure is plausible (broker reject). So the "extreme restart while gated" has a hole: it is skipped for a side in backoff. The smallest fix: move the gate block BEFORE the backoff check? But then a gated side would return before the backoff (that's fine, no roll happens anyway), and the restart would run every gated tick regardless of the backoff. But careful: the ordering matters for the design (the design explicitly says "After the disabled / blocked / backoff returns and BEFORE anything else"). So the design chose the ordering. Hmm, but the design's premise P4 fix is violated in the backoff case. Is this worth reporting? The prompt says "Do not call anything fatal that has a fix: give the smallest fix." I'll report it as a NEEDS-FIX (small: also call the restart in the backoff return path when the gate holds, or move the gate check before the backoff). Hmm, but that changes the ruled ordering? The ruling GR6-3 is about from_msc = market time + 1 ms, not about the ordering relative to the backoff. And the design's C8 says "Insert immediately AFTER the backoff check (after 1213)". So the ordering is part of the design. I'll flag it as a residual hazard with a minimal fix, noting it doesn't change the ruled behaviours.

Actually, let me double check whether the backoff return path even matters given `TrackExtremes` is called before. Consider the sequence where the side is NOT in backoff at the gate's first holding call: the restart happens each gated call → the extreme is fresh. Then a roll attempt can't happen (gated), so no new backoff. So the ONLY way to be in backoff while gated is a pre-existing backoff. And the backoff max is 1800 s = 30 min. So there's a <= 30 min window. And the gate could hold for hours. So the hole is: for the first up-to-30-min of a hold, if the gate opens exactly at the backoff's expiry, the extreme from that window is replayed. It's a real but bounded hole. Report as NEEDS-FIX with the smallest fix: in the backoff branch, when `Grind_RollGateHolds(roll_gate, opposite_depth)` is true, also call the restart (and the note?) before returning. Simplest: move the gate block above the backoff check. Hmm, but the note should probably not fire while in backoff (no roll is due anyway... actually a roll IS due; the note is about a roll being deferred by the gate). If the gate holds and the side is in backoff, the roll is deferred by both. I'd say: smallest fix = move the gate-check block above the backoff check (the gated path sends no requests, so the backoff is irrelevant while gated; the deferred note is still gated-accurate). But then the deferred latch clear would also run... no, the clear is after the gate block; if the gate holds we return. Fine. Actually moving the gate block before the backoff check means: while gated, the backoff no longer suppresses the restart. And when the gate opens, the backoff still applies (the loop's roll is not attempted because... wait, the backoff check would then be AFTER the gate block: if the gate doesn't hold, we fall through to the backoff check → return 0. Same as before. So the only change is that the restart+note run while gated-with-backoff. And the note might fire during the backoff — is that a problem? The note says the roll is deferred because of the gate; the actual roll would also be blocked by the backoff. Minor. Alternatively, just add the restart to the backoff branch. I'll present "move the gate block above the backoff check" as the smallest structural fix, or add a one-line restart in the backoff branch.

Hmm, hold on. Let me reconsider. Is the extreme actually folded during the backoff? In `Grind_LatticeOnTick`: `Grind_LatticeTrackExtremes` runs before the blocked check and before TrySide. Yes. So the extreme folds ticks regardless of the backoff. And `Grind_LatticeTrackOneSide` only resets tracking below cap. So yes, the extreme accumulates during the backoff.

Now, is there an analogous hole with `blocked` (halt/quarantine)? If the EA is halted/quarantined while gated, `Grind_LatticeOnTick` returns before TrySide → no restart. When the halt lifts, the gate check runs: if the gate holds → restart (discard). If the gate opened during the halt → the loop with a stale extreme. Same hole. But during a halt, if the halt was triggered by an invariant failure, the EA is halted until a restart. Meh. The backoff case is the more likely one.

Hmm, let me reconsider whether there is a much more serious bug that I'm missing. Let me look at the whole picture from the "auditor" angle: lookahead bias, silent failures, schema mismatches, statistical flaws.

**Silent failure candidate:** `Grind_LatticeRollDeferredNote` is called with `side` (a `const GrindSideState&`). It calls `Grind_SideDepth(side)`. Fine.

**Schema mismatch candidate:** the marker detail uses `"gate":%d` and `"opposite_depth":%d`. Fine. The prompt says `{"side":"L"/"S","depth":<n>,"opposite_depth":<n>,"gate":<n>,"level":<5dp>,"market":<5dp>}` with `Grind_ArchiveJsonDouble(x,5)`. The code matches.

**The Print** `Print("INFO ROLL_DEFERRED ", detail);` — matches the design. Fine.

**Now the count/statistical angle:** P2 says 250/257 roll fills happened while the opposite side held >= 1 layer. The premise is measured. Not my job.

Let me look at the "silent failure" of the ROLL_DEFERRED info going to the archive — `Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", is_long ? "L" : "S", 0, detail)`. The ticket argument is 0. Fine.

Hmm, let me check `Grind_ArchiveMarker`'s signature: `Grind_ArchiveMarker(level, code, side, ticket, detail)`. Used elsewhere as `Grind_ArchiveMarker("WARN", "ROLL_STRANDED", is_long ? "L" : "S", 0, detail)`. Consistent.

Now the telemetry: `Grind_LatticeMaybeStranded` uses `Grind_TelemetryEmit`. The note doesn't. G6 VERIFIED.

Now let me check whether the **`ROLL_DEFERRED` note can fire when the gate is OFF but... no, it's only called inside the gate block.

Now, T-3: "never re-arms after a real release?" Let's think of a nasty case: the gate holds; the note fires (latch = true). Then the gate opens and the ungated `TrySide` runs → the latch is cleared. But what if the side is below cap at that moment? `Grind_LatticeTrackOneSide`'s below-cap branch clears the latch. Fine. What if the side is at cap but `blocked`? Then TrySide returns before the gate block → the latch stays set. When the block lifts and the gate opens → cleared. Fine.

What if the gate opens but the ungated call does NOT reach the clear because... the backoff! `if(now < backoff) return 0;` — before the clear. So: the gate holds, the note fires (latch = true). Then the gate opens, but the side is in backoff → return before the clear → the latch stays true. Hmm, but the backoff means the roll doesn't happen anyway. Then the backoff expires → the ungated call → clears the latch → rolls. Fine.

Hmm, but here's a RE-ARM MISS: the gate holds → the note fires → the latch = true. Then the gate opens and the side ROLLS (the latch is cleared first, so fine). Then the gate re-engages later → the note can fire again. Fine.

What about: the gate holds → the note fires (latch true) → the gate opens → the ungated call clears the latch AND rolls → but the roll's modify FAILS → the backoff is set. Now the level is still crossed. The next calls: backoff → return. After the backoff, the ungated loop retries. Fine.

Now, hmm, one more re-arm path: **the latch is cleared by `Grind_LatticeTrackOneSide` below cap, but NOT when the side is at cap and the gate never engages**. Not needed.

OK, T-3 seems fine except possibly the "spam" question. Let me consider a spam path: the gate holds, the note fires, the latch = true. Now the side's OWN depth drops below cap momentarily? Then TrackOneSide clears the latch. Then it re-caps → the gate may still hold → the note fires again. That's a new gated episode (the side left and re-entered the cap). Reasonable.

Another spam path: `Grind_LatticeTrySide` clears the latch on an ungated call... but ONLY if the call passes the backoff check. If the side oscillates gated/ungated while never actually rolling (e.g., the level is not crossed when ungated), then: ungated → clear; gated → note fires only if a roll is due. So no spam.

OK.

Now, T-1: is there a path where `blocked`/backoff ordering lets a GATED side act? The gate check is after the backoff; a gated side returns 0 either way. But what about `enabled == false`? Returns 0. Fine.

Hmm, here's a thought: **the short side's `opposite_depth` is read as `Grind_SideDepth(g_grind_long)` AFTER the long's TrySide. If the long side is NOT at cap, the long's TrySide isn't called; the depth is still correct.** Fine.

Now, a REAL T-1 candidate: **the gate's `opposite_depth` is the OPPOSITE side's filled layers, but `Grind_LatticeTrackOneSide` for the opposite side runs BEFORE the TrySide calls, and it can return early without resetting... no, the depth is from the array, not from tracking.

OK. Let me now consider the **`InpRollGateOpposite = 0` fleet deployment**: the gate holds when the opposite depth > 0, i.e., ANY filled layer. P2 says 97% of rolls happened with the opposite >= 1 layer. So at N=0, rolls become rare. Fine.

Now, an important deployment question: **nine instances per terminal, one symbol and magic each**. Wait — "one symbol and magic each". So nine instances on nine charts? If each instance has a distinct magic, fine. The `Grind_MagicLockClaim` prevents duplicate magic.

Hmm, the **cost T-7**: "a release can send up to `max_layers` modifies plus the exit queue's remove / place." Let me count precisely for a first-roll burst of K rolls in one call. Each `Grind_LatticeRollLayer`:
- If `layer.exit_order_ticket != 0`: 1 modify (`Grind_ModifyPendingPrice`). Then `Grind_VLSet` etc. Then `Grind_ExitQManageSide(side, ...)`.
- `Grind_ExitQManageSide`: cancels holders not allowed (`Grind_ExitQHoldCancelLayer` → 1 remove each), then places required (`Grind_PlaceLimit` → 1 place each).
So for LB7 (5 rolls): 5 modify + 5 remove + 5 place = 15 requests, per the LB7 test. The design's GR6-1 says "about three requests each" and "up to ~24". Hmm, LB7 asserts exactly 5 modify, 5 remove, 5 place. So 3 per roll = 15 for 5. So the "up to ~24" for max_layers (8) = 24. OK. Per side per release call. Nine instances → 216 requests in the worst case if all release in the same tick. That's a burst but the API counter stop is at 1,000,000/day. Fine. The cost of the held side is zero requests. Good.

Now let me look at the **`ExitQ` interaction at release**: the roll modifies the exit order to a price that may be clamped passive at the market (C55 VC3), which fills immediately. That's the P4 hazard, and the design accepts the fix (the restart). Fine.

Hmm, now let me reconsider T-2's "the gate releasing on the same tick it last held". The restart at the END of the last gated call sets from_msc = t+1. The next call (release) folds ticks from t+1 to now. Suppose the market dipped to 1.20190 BETWEEN the last gated call and the release call (a fraction of a second). The extreme = 1.20190 → at release, the probe = min(mkt, 1.20190) → the roll happens at the level but... hmm, is that a "replay"? No, that's a genuine between-call catch-up (VC3's purpose). Fine.

Now T-2: "a dead market (no newer tick, so from_msc > market time)". `Grind_LatticeCopyTicks` production: `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, from, to)` where to = the market time (the last tick's time). If from > to... MT5's CopyTicksRange returns 0 or -1. The doc: "returns the number of ticks or -1 on error". If from > to, I believe it returns 0 (empty range). With 0: FoldExtreme folds the live price → extreme = live → OK. With -1: `return` without folding → the extreme stays 0 → the next tick retries. Then at the release, if the extreme is 0, TrySide uses `probe = mkt` (the `extreme > 0.0 ? ... : mkt` branch). So a crossing is not missed. Fine — at most one tick.

Hmm, but hold on: the `if(n < 0) return;` in `Grind_LatticeTrackOneSide` also skips updating `from_msc`. So the next call re-copies from the same from_msc. Fine.

Now let's examine a **subtle severe issue: the restart also sets `g_grind_vl_tracking_long = true`, which means the below-cap reset is skipped... no, the below-cap check is first. Fine.

But: the restart sets tracking = true even if the side's layer set is EMPTY? TrySide is called at cap. Fine.

BIG ONE: **the restart happens even when the gate holds and the side is at cap but the side has NO rollable candidate and the tracking was never initialised.** E.g., the long's layers have `position_ticket == 0` or `Grind_CarryPositionOpenTime` fails. Then the normal tracking init `return`s, leaving tracking false and from_msc = 0. But the restart sets tracking = true and from_msc = t+1 → subsequent TrackOneSide calls copy ticks from t+1. That's fine (no stale).

Hmm, now let me reconsider: is there a case where the restart makes the extreme STALE IN THE OTHER DIRECTION, i.e., a real crossing after release is missed for more than one tick? The extreme = 0 after the restart; the next TrackOneSide folds the live price (if n >= 0) → extreme = live. If `n < 0` (CopyTicksRange error) → return without folding → extreme stays 0. Then the next call: from_msc unchanged; if the copy fails repeatedly (a persistent error), the extreme stays 0 forever, but `TrySide` with extreme = 0 uses mkt → OK. So no missed crossing. Actually wait: if the extreme is 0 and the market has moved far, then the roll uses probe = mkt only — that's LESS aggressive than using the extreme, so a crossing could be missed that the extreme would have caught (a dip between calls). But that's the normal VC3 catch-up. With a persistent copy failure, the catch-up is lost. That's pre-existing (VC9 tests the retry).

Hmm, so actually the restart's `from_msc = t+1` combined with a copy failure means the extreme = 0 and the roll relies on the live market only. Not a new bug.

Now let me hunt T-8 harder for a vacuous test. The prompt explicitly asks: "Any assertion in fxgrind_tests_adr166.mqh that passes vacuously (state left from an earlier fixture, a reset that does not clear the new latch, the market-time seam left seeded, an ArchiveFind that would pass if nothing ran)?"

- **`Adr162b_Reset()` does not call `Grind_MarketTestReset()`** — the market-time seam persists! RG8 and RG13 call `Grind_MarketTestReset()` at the end. RG13 calls `Grind_MarketTestReset()` then `C55_Reset()`. RG8 calls `Grind_MarketTestReset()` then `Adr162b_Reset()`. So RG8 and RG13 clean up. But all the OTHER RG tests do NOT seed the time... they don't seed it either. Hmm, but does any RG test depend on the market-time seam being unset? RG3-RG7, RG9-RG12, RG14 do not seed the time. So no issue... UNLESS an earlier test in the suite left the seam seeded. The seam is cleared only by `Grind_MarketTestReset` (A9) and `Grind_OrderTestReset` (which calls `Grind_MarketTestReset`). Does `Adr162b_Reset` → `Grind_TestEjectHarnessReset()` call `Grind_OrderTestReset`? If so, the seam is cleared. Hmm, `Grind_TestEjectHarnessReset` — the name suggests the eject harness. Let me think about what's certain: `Adr162b_Reset` (as quoted) = `Grind_TestEjectHarnessReset(); Grind_ArchiveTestReset(); Grind_LatticeResetBackoff(); Adr151_TestResetAll(); g_grind_order_test_send_ok = true;`. If `Grind_TestEjectHarnessReset` includes `Grind_OrderTestReset`, then `Grind_MarketTestReset` is called (since `Grind_OrderTestReset` calls `Grind_MarketTestReset`). We can't see it. A9 says the seam is cleared ONLY by `Grind_MarketTestReset` (not by `Adr162b_Reset`/`Adr151_TestResetAll`, `fxgrind_tests_adr151.mqh` 58-77). A9's wording: "cleared only by `Grind_MarketTestReset` (NOT by `Adr162b_Reset` / `Adr151_TestResetAll`)".

So `Adr162b_Reset` does NOT clear the seam! That means a test that seeds the time and doesn't reset it leaks into later tests. RG8 and RG13 do reset. But are there other tests in the whole suite that seed the time and don't reset? Out of scope. However — the ORDER matters: RG8 comes before RG9-RG14 and after RG1-RG7. RG8 resets. RG13 resets. So within ADR166, OK.

Hmm, but here's a thought: **if RG13's assertions FAIL (at the stubs), does the code still reach `Grind_MarketTestReset()`?** `AssertFalse` presumably records a failure and continues (not an abort). The standard pattern in these suites. So yes. OK.

- **`Adr162b_ArchiveFind` that would pass if nothing ran**: RG3e (`ROLL_STRANDED` == ""), RG5d, RG10b, RG14d are all "assert empty" → vacuously true if the mechanism didn't run. E.g., RG5d asserts no `ROLL_STRANDED`, but if the archive configuration were off, everything would be empty and RG5d would pass vacuously. RG3e is a G and is guarded by RG3d (the marker must be non-empty), so the archive works. So RG5d and RG14d are meaningful only because other assertions in the same test prove the archive works... RG5d: RG5c asserts the marker is non-empty in the same test → the archive works. RG14d: RG14a-c prove the code ran. RG10b: RG10a asserts rc == 0 (the call ran). OK.

- **RG3c `modify_calls == 0`**: the counters must be zeroed by the seed. If `Adr162b_SeedLong8` doesn't zero the modify counter, RG3c could pass vacuously or fail spuriously. The LB6 test asserts `modify_calls == 1` after one roll, so the counters must be zeroed by the seed → RG3c is meaningful.

Hmm, hold on. There's a REAL vacuous test: **RG4g**. `Adr162b_Reset(); Adr162b_SeedLong8(); Grind_MarketTestSeed(1.20590, 1.20600, 0, 0); AssertEqInt("RG4g (G)", Adr166_TryLong(ADR166_T0, false, -1, 5), 1);`. At the stubs, the gate never holds → rc = 1 → passes. At the implementation, -1 → no gate → rc = 1 → passes. So it's a genuine G. Fine.

**RG1/RG2** test the pure functions; they'd pass at commit 2 and fail (or pass) at commit 1: RG1d/e and RG2b/d are F (C2/C3 stubbed as `return true`/`return false` → RG1d expects false but the stub returns true → fails; RG2b expects true but the stub returns false → fails). Good.

Now, the **"reset that does not clear the new latch"** — `Adr162b_Reset` → `Grind_LatticeResetBackoff` (which clears the latches due to C5). So it does clear. But the PROMPT's attached `grind_engine.mqh` shows `Grind_LatticeResetBackoff` includes the latches. Good.

Hmm, but here's a subtle one: **the deferred latch is per side and cleared by `Adr162b_Reset` only via `Grind_LatticeResetBackoff`. But `Adr162b_SeedLong8` calls `Adr162b_Reset` FIRST — so the latch is cleared before the seed. Fine.

OK, now: **`Adr166_OneShort` does not add the ticket 7101 to any position-test registry or the order-test records.** `Grind_LatticeRollDeferredNote` doesn't need orders. Fine. But RG13's `ArrayResize(g_grind_short.layers, 0)` empties the short. Fine.

Hmm, `Adr166_OneShort` sets `exit_order_ticket = 0` and `exit_target` — but doesn't create a corresponding order test record. Not needed for the ADR166 tests (the short is never rolled at commit 2 in RG12/RG13... wait, RG7 uses `Adr162b_SeedShort8`, not OneShort. In RG12, the short is only the gate source. In RG13, same. OK.

Now, let me check whether **RG12's first OnTick at commit 2 might ALSO roll the SHORT side**. `Adr166_OnTick(T0, true, 0)`: the short's depth = 1 < 8 → not evaluated. Fine.

And the long's `TrySide` is called with `opposite_depth = Grind_SideDepth(g_grind_short) = 1`. Good.

Now let me carefully consider **whether the long's `TrySide` in RG12 at commit 2 also fires the note and thus RG12a's VL check is unaffected** — yes.

Now let me look at a potential **RG9 bubble**: RG9c asserts `Adr166_TryLong(ADR166_T0 + 2, false, 0, 0) == 1`. At commit 2, call 3 (gate open, opp 0) → the latch clear → the loop: level = ? After call 1 and 2 (both gated, no rolls), the long still has 8 unrolled layers, VLs none → anchor = the deepest entry = 1.20700 → level = 1.20600. The market ask = 1.20600 (unchanged; `Grind_MarketTestSeed` was set at the start and not re-seeded in calls 2/3). The extreme: the calls are direct `TrySide` (not OnTick), so no TrackExtremes. `Adr166_TryLong` passes `extreme = 0.0` → probe = mkt = 1.20600 → crossed → roll 7001 → rc = 1. RG9c passes. 

Then `Grind_MarketTestSeed(1.20490, 1.20500, 0, 0)`: the ask = 1.20500. Call 4 `TryLong(T0+3, false, 0, 1)`: the gate holds (opp 1 > 0) → restart + note: level = `Grind_ComputeAddTarget` → any_vl (7001 now has a VL = 1.20600) → anchor = 1.20600 → level = 1.20600 - 0.00100 = 1.20500. mkt = ask = 1.20500 → crossed → marker #1. RG9d passes. Good. And RG9e checks marker #0's fields: opp=1, gate=0. Good.

So RG9 works at commit 2.

Now the **test-mechanics fixes** — 3 of them. Let me guess what breaks at commit 2 in the attached file... Let me look for something concretely wrong.

RG4f: `AssertContains("RG4f (G)", acc, "\"auto\"")`. The roll detail for a first roll has `"source":"auto"`. Good.

RG3d et al. Fine.

Hmm, RG13: `C55_Reset(); Adr162b_SeedLong8();` — note the ORDER: `C55_Reset` calls `Adr162b_Reset` first. Then `Adr162b_SeedLong8()` calls `Adr162b_Reset()` AGAIN (which does NOT reset the test ticks; C55_Reset does `Grind_LatticeTestTicksReset()`). So the order: C55_Reset (clears ticks), SeedLong8 (resets again, no tick clear), then `Grind_LatticeTestAddTick`. Fine.

But `Adr162b_SeedLong8` → `Adr162b_Reset` → `Grind_LatticeResetBackoff` → `Grind_LatticeTestTicksReset()` (per the code: `Grind_LatticeResetBackoff` ends with `Grind_LatticeTestTicksReset();`). Wait!! Let me re-read `Grind_LatticeResetBackoff`:

```
void Grind_LatticeResetBackoff()
{
   ...
   g_grind_vl_deferred_noted_long = false;
   g_grind_vl_deferred_noted_short = false;
   Grind_LatticeTestTicksReset();
}
```

Yes, it resets the test ticks. So in RG13, the sequence is: C55_Reset (ticks cleared), SeedLong8 → Adr162b_Reset → ResetBackoff (ticks cleared), then `C55_OpenTimes`, `Adr166_OneShort`, `Grind_MarketTestSeed`, `Grind_LatticeTestAddTick(09:30)`. So the tick is added after all resets. Good.

Hmm, in RG13 the order is `C55_OpenTimes(true, 09:00)` BEFORE `Adr166_OneShort()`. Fine.

Now let me examine RG13's C55_OpenTimes: it iterates `g_grind_long.layers` and sets the open time for each non-zero position ticket. The long has 8 (7001-7008). Fine.

Now, is `Grind_CarryPositionOpenTime` in the test mode reading from `Grind_CarryTestSetOpenTime`? Yes (C55 tests use it).

OK. Now let me think about the THREE test-mechanics fixes at 634c7ea. Possibly:
1. RG7c's tag (G→F)? That wouldn't matter for the run.
2. RG8: adding `Grind_MarketTestReset()` (the seam cleanup) — needed because otherwise the seam leaks into RG9! Indeed: RG8 seeds the time to 1790000000000 and RG11/RG12 use times... hmm, RG9 uses `ADR166_T0` (2026-09-28 10:00) with the seam at 1.79e12 (2026-09-17). If the seam leaked, `Grind_MarketTimeMsc()` would return 1790000000000 while `now` = ADR166_T0. Does that matter for RG9? RG9 uses direct TrySide calls with extreme = 0 → the restart sets from_msc = the seam value. `Grind_LatticeRollDeferredNote` doesn't use from_msc. So RG9 is unaffected. RG11/RG12: `Adr165_Fixture` + direct calls; the restart sets from_msc; no CopyTicks (direct TrySide). RG12 uses OnTick → TrackExtremes → CopyTicks(from_msc = the seam+1) with the test tick array empty → n = 0 → fold the live price. Fine. RG13 seeds its own time. And RG14 is direct calls. So the seam leak matters little for the ADR166 tests, but it would matter for LATER tests in the suite (and for the ADR166 tests if the seam > the `now` used... e.g., RG13 seeds its own). So fix #2 might be exactly the `Grind_MarketTestReset()` in RG8 and RG13.

Actually the prompt's design says: "Every test ends with `Adr162b_Reset()` (RG13 with `C55_Reset()`); RG8 and RG13 first call `Grind_MarketTestReset()`". And the attached file: RG8 has `Grind_MarketTestReset();` at the END (before Adr162b_Reset). RG13 has `Grind_MarketTestReset(); C55_Reset();` at the end. Hmm, the design says "RG8 and RG13 first call Grind_MarketTestReset()" — the attached file calls it at the END. Whatever — the effect is the same as long as the seam is cleared before the next test.

Hmm, "first call" might mean "call it early in the test body to ensure a clean state". If the seam were left seeded by an earlier test, RG8's assertions might behave differently. Eh.

3. Maybe `Adr166_OneShort`'s exit_target or `Adr151_TestSetupLongLayer` signature.

I can't determine the three fixes definitively; the prompt asks me to find what tests can't see, not to enumerate the fixes. But T-8 asks: "Which behaviour has no test that fails without it?" Let me be systematic about the C-changes vs the F tests:

- C1 (input): no test fails without it (the input is only exercised via the .set/presets; RG4g passes -1 explicitly). Hmm: is there a test that the input default is -1? No. A preset missing the key → -1 → ASSUMED MT5 behaviour. Test gap.
- C2: RG1.
- C3: RG2.
- C4 (globals): implicitly.
- C5: the below-cap clear → no test fails without it. The ResetBackoff clear → no test fails without it (as analyzed; the C8 clear covers the tests). Actually hold on, let me re-check: is there a test that would fail if `Grind_LatticeResetBackoff` did NOT clear the latch? Consider the sequence RG3 → RG4. RG3 sets the latch (gated, note fired). RG3 ends with `Adr162b_Reset()`. RG4's first call is ungated → the C8 clear zeroes the latch → then RG4d asserts no marker → passes. Then RG4 ends with Reset; RG4g is a fresh seed; the ungated call clears any latch. Hmm, but the latch from RG4g? Gate -1 → the loop... the C8 clear runs on every ungated call. So all tests clear the latch on their first ungated call. EXCEPT the tests whose FIRST call is gated: RG5 (gated, but the latch was cleared by RG4's ungated calls), RG9 (call 1 gated — the latch must be false at the start; it was cleared by RG8's direct call? RG8's call is gated! Let's see: the sequence RG7 → RG8. RG7's last call is `TryShort(T0+1, false, 0, 0)` — ungated → clears the SHORT's latch (but not the LONG's). Hmm, the LONG's latch: RG5 set it (gated, marker); RG6a (ungated, gate=2/opp=2 → holds? `RollGateHolds(2,2)` = false → ungated → clears the LONG's latch + rolls); RG6b (gated → the LONG's latch was cleared by RG6a) → sets the latch again! Then RG7 (short side only: `Adr162b_SeedShort8` → Reset → ResetBackoff clears both latches). Ah, the Reset does clear it. So the C5 ResetBackoff clear IS load-bearing for the test suite: without it, after RG6b the LONG's latch = true, and RG7's seed calls `Adr162b_Reset` → without the C5 clear, the LONG's latch would stay true into RG8's direct gated call → RG8 doesn't check markers. RG9's call 1 is gated → if the latch were stale-true, RG9a would FAIL (the marker wouldn't fire). So the C5 ResetBackoff clear IS tested by RG9a (in the chain RG6b → ... → RG9a). Interesting, so it's covered, though indirectly and only via the full-suite ordering. Hmm, but wait: RG8's direct call is gated → `RollGateRestartExtreme` + the note (the latch is irrelevant to the restart). With the latch stale-true from RG6b (absent the C5 clear), RG8's note wouldn't fire — RG8 doesn't check. Then RG9's call 1 is gated → the note returns due to the stale latch → RG9a fails. So yes, RG9a indirectly pins the ResetBackoff clear, GIVEN the suite order. Fragile but covered. I'll mention it.

- C6: RG8, RG13.
- C7: RG3d, RG5c, RG9, RG10b.
- C8 (the gate block + clear): RG3-RG7, RG9-RG14.
- C9 (the pass-through): RG12.
- C10: RG1 + the input; the Print/LATTICE_CONFIG → untested.
- C11/C12: the tests themselves.

So the gaps: the FATAL wiring in OnInit (RG1 tests only the pure function, not that OnInit aborts), the new log line / LATTICE_CONFIG field, the telemetry-absence for ROLL_DEFERRED, the short-side restart (mirror of RG8), the backoff-while-gated restart hole, the `CopyTicksRange` failure modes while gated (n = -1 / 0), the EA-restart-while-gated (globals re-init), and the deferred latch's re-arm after the gate opens without a roll.

Hmm, one more gap: **RG9 tests the re-arm via call 3 (gate open) but not that the marker is suppressed while gated across MANY ticks with the level still crossed** — actually calls 1-2 cover 2 ticks. Fine.

Now let me reconsider **T-8's "the market-time seam left seeded"**. In the attached file, RG8 calls `Grind_MarketTestSeedTimeMsc(1790000000000)` and at the end `Grind_MarketTestReset()`. OK. But WAIT: RG8 sets the seam AFTER `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0)`. `Grind_MarketTestReset()` clears everything. Fine.

Hmm, what about **RG13's seam**: `Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:00' * 1000)` → 10:00 in server time. And `Adr166_OnTick(D'2026.09.28 10:00', ...)`. Consistent. Then at 10:01 the seam is updated. Then at 10:02 the seam is updated. Then `Grind_MarketTestReset()`. Good.

Now, is there a bug in RG13 at commit 2? Let me re-check the 10:00 call: the long's `TrySide` is gated → restart. But BEFORE that, `TrackExtremes` ran and folded the 09:30 tick. Hmm, at the 10:00 call, the short's depth = 1 → the gate holds for the LONG. But what about the SHORT's TrySide? The short's depth = 1 < 8 → not evaluated. Good.

Then `ArrayResize(g_grind_short.layers, 0)` → the short depth = 0. At the 10:01 call, the long's gate: opp = 0 → open. Good.

Hmm, one thing: at the 10:01 call, `TrackExtremes` for the SHORT: depth 0 < 8 → the below-cap reset → clears the short's latch etc. Fine.

OK. Now let me look for a **severe** bug I might have missed. Let me re-read the gate block and the loop's interaction with `Grind_LatticeTrySide`'s `side` parameter and the C8 clear.

```
   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
      Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);
      return 0;
   }
```

`Grind_LatticeRollDeferredNote` takes `side` by const ref. It calls `Grind_ComputeAddTarget(side, is_long, add_pips)`. OK.

Hmm, `Grind_LatticeRollDeferredNote` is declared AFTER `Grind_LatticeRollGateRestartExtreme` but BEFORE `Grind_LatticeTrySide` in the file (the order in the attached file: RestartExtreme, then RollDeferredNote, then TrySide). And MQL5 resolves functions defined later. Fine.

Now, let me examine the **`Grind_SideDepth(g_grind_short)` argument** in the long's TrySide call: `Grind_SideDepth(g_grind_short)` is a function call on a global; MQL5 evaluates arguments before the call. Fine.

Now — **HOLD ON**. Big one. In `Grind_LatticeOnTick`, the long's TrySide is passed `Grind_SideDepth(g_grind_short)`. But `Grind_LatticeTrySide`'s 12th parameter is `opposite_depth`. Let me count the parameters of `TrySide`:

1 side, 2 is_long, 3 magic, 4 slot, 5 lots, 6 exit_pips, 7 add_pips, 8 max_layers, 9 enabled, 10 blocked, 11 now, 12 extreme, 13 reroll, 14 roll_gate, 15 opposite_depth.

The long's call:
```
      Grind_LatticeTrySide(g_grind_long, true, magic, slot, lots, exit_pips, add_pips, max_layers,
                           enabled, blocked, now, g_grind_vl_extreme_long, reroll, roll_gate,
                           Grind_SideDepth(g_grind_short));
```
13 args + ... that's 15 args. Good: extreme = g_grind_vl_extreme_long, reroll, roll_gate, opposite = the short's depth. Correct.

The short's call:
```
      Grind_LatticeTrySide(g_grind_short, false, magic, slot, lots, exit_s, add_s,
                           max_layers, enabled, blocked, now, g_grind_vl_extreme_short, reroll,
                           roll_gate, Grind_SideDepth(g_grind_long));
```
Correct.

And `Adr166_TryLong`: `Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, now, 0.0, reroll, gate, opp);` → 15 args. Correct.

`Adr166_OnTick`: `Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now, 5.0, 10.0, reroll, gate);` → the signature: magic, slot, lots, enabled, exit_pips, add_pips, max_layers, blocked, now, exit_pips_short, add_pips_short, reroll, roll_gate → 13 args. Correct.

Now the existing call sites: `Adr162b_TryLong(now)` → `Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, now);` → 11 args → the trailing defaults apply. Good, compiles unchanged.

`C55_OnTick` → `Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now);` → 9 args + defaults. Good.

`fxgrind.mq5`'s OnTick call passes `InpRollGateOpposite` as the last argument → 13 args. Good.

Now, the **existing tests' expected values must not change** (s6 negative space). Do they? With the gate at -1, `Grind_RollGateHolds` is false → the C8 clear runs → the loop as before. Also the C5 change: `Grind_LatticeTrackOneSide` clears the deferred latch below cap — no behavioural change. `Grind_LatticeResetBackoff` clears the latches — no change. So the existing tests are unaffected. And the LB/RR/VC tests call `TrySide`/`OnTick` without the new args → gate = -1 → unchanged. VERIFIED. Also the existing tests that call `Grind_LatticeOnTick` with 9 args → roll_gate = -1 → the long's opp = the short's depth (with the gate -1, `RollGateHolds(-1, x)` = false) → no change. Good.

Hmm, so with gate = -1, `Grind_LatticeRollGateRestartExtreme` is never called → the extreme behaves as before. Good.

Now the **PREMISE VERDICT**: is the branch safe to merge with -1 and to set N = 0 on one fleet?

Potential merge blockers: (1) RG7c's mis-tag (a test-label slip, not code) — the prompt already acknowledges. (2) The backoff-while-gated restart hole (a NEEDS-FIX, but it does NOT affect the -1 path; it affects N=0 live). (3) Anything else?

Let me think about the FLEET deployment: "one fleet at N = 0, the others at -1". At N = 0, the gate holds whenever the opposite depth >= 1. Per P2, 97% of rolls happened with the opposite >= 1. So at N=0, the capped side essentially never rolls while the opposite holds any layer. And GR6-5: at 8/8, both sides gate each other → neither rolls until a side drops below cap. In a strong trend, the counter side has 1 layer and the trend side 8 → the counter's layer exits (scalps), then the trend side rolls. Hmm, but the counter side's L0 keeps being re-placed after it scalps, so the depth oscillates 0/1. Fine.

Now, a REAL deployment concern: **the release roll happens on the first call after the opposite empties. But the opposite side re-places its L0 on the next `OnTickEngine` call... AFTER `Grind_LatticeOnTick` has already run in that same tick.** Order in OnTick: `Grind_LatticeOnTick` (the roll) → ... → `Grind_OnTickEngine` (the L0 placement). So the roll happens BEFORE the counter's L0 re-fill in the same tick. Confirms P3. Good.

Hmm, another deployment concern: **the gate's interaction with the `Grind_ApiCounterEntryStopped`** — irrelevant.

Let me now also verify the **`LATTICE_CONFIG`** schema change doesn't break the log checker: A14 says the checker reads `GRIND_REROLL enable=`. The new `LATTICE_CONFIG` adds a field. The archive JSON consumers (pipshed) might expect a fixed schema... `"roll_gate":%d` is appending a new key. If pipshed parses strictly, it might break. A14 only mentions the LOG checker (the Linux boxes reading the EA log), not the archive consumer. The new `GRIND_ROLL_GATE opposite_max=` Print is a new line — fine. The `LATTICE_CONFIG` archive detail is a schema change to an existing marker. Hmm, that's a potential silent consumer break. The design explicitly lists it (C10). I'll note it as a low-risk observation (the design intends it).

Now let me look for anything about the **"one symbol and magic each"** and nine instances — the magic lock. Not relevant.

Let me re-examine T-4's "burst of modifies (count them per side and per instance)". Per side per release call: up to max_layers first rolls × (1 modify + 1 remove + 1 place) = 24, per the design. Plus the re-rolls: one per call. And the exit queue. Per instance. Nine instances → 216. But the ADD path also sends: at release, if the market moved, the add entries also reprice. Eh.

Hmm, wait. There's a subtle cost issue: at release, the rolls go to levels the CURRENT market has crossed. Each roll's new exit is `level + exit` clamped passive at the market → often immediately marketable → fills on the next tick → the exit queue promotes the next rank → a place. So the cost is bounded. Fine.

Now, one more potential correctness issue at release: **the loop's `iter < max_layers` bound and the re-roll's one-per-call**. With the gate open, first rolls fill up to max_layers. Fine.

Now, let me look at T-5's I6: "the gate writes no VL". So during the deferral, the exits remain at the pre-gate levels (e.g., 1.20650 for 7001's exit if previously rolled, or entry+5 for unrolled). Hmm, WAIT. Here's a real one: the side is capped with all 8 layers. The gate holds. The `Grind_ExitQManageSide` continues to run on every... no, it runs inside `Grind_LatticeRollLayer` (rolls) and in `Grind_HandleSideDealFill` (fills) and in `Grind_RetryMissingExits` (every tick in OnTickEngine: `Grind_RetryMissingExits(magic, slot, lots)` → `Grind_ExitQManageSide` for both sides). So while gated, the exit queue still manages the resting rank 0 / highest rank. So the exits are maintained. Fine.

Now the carry pass: `Grind_CarryOnTimerStep` (every telemetry interval). It modifies the exits of layers with carry shifts. While gated, no VL changes, so the carry pass sees the pre-gate state. At release, the roll modifies the exit and calls `Grind_CarryShiftDelete` or `Grind_CarryRecordShift`. Hmm, but if the carry pass set a shift based on the pre-gate level, and then the roll deletes the shift... existing behaviour after a roll. Fine.

OK, now let me also double-check the claim in G3: "leaves the closing state, the backoff and the fail count unchanged". The gated path returns 0 — yes, no writes to those. VERIFIED.

And G3: "sends no order request" — `Grind_LatticeRollGateRestartExtreme` and `...DeferredNote` send no orders. VERIFIED.

Now let me check G1 again very carefully: "the only other new statement on that path clears the new deferred latch". With gate = -1: `Grind_RollGateHolds(-1, x)` → false → skip the block → run the clear. But the clear is a NEW statement on the path (unconditionally executed). Is there any OTHER new statement on the -1 path? `Grind_LatticeTrySide` has the new trailing params (no statements). `Grind_LatticeOnTick` passes `Grind_SideDepth(g_grind_short)` — an extra read, no side effect. `Grind_LatticeTrackOneSide` has the new below-cap clear statements — those run on the -1 path too! And `Grind_LatticeResetBackoff` has the new clears. So G1's phrasing "the only other new statement on that path" is... the -1 path includes the below-cap reset and the test reset. But G1 says "every path behaves exactly as before this branch: `Grind_RollGateHolds(-1, x)` is false, and the only other new statement on that path clears the new deferred latch." Strictly, the below-cap clears in `TrackOneSide` are also new statements on the -1 path (they clear the new latch). And Ryzen... The intent is "the only other new statement affecting behaviour on that path". The latch clears are behaviour-neutral for trading. I'd mark G1 VERIFIED with a caveat: the C5 clears in `Grind_LatticeTrackOneSide`/`Grind_LatticeResetBackoff` are also new statements on the -1 path (they only touch the new latch, which is never set with -1). Hmm, but the latch CAN be set with -1? No: the latch is set only in `Grind_LatticeRollDeferredNote`, called only inside the gate block, which requires the gate to hold, impossible with -1. So the latch is always false with -1 → the clears are no-ops. VERIFIED (with the note).

Now, G4: "opposite_depth is the other side's filled-layer count at the moment of the call (Grind_SideDepth), never a resting entry." VERIFIED. But hmm — at the moment of the SHORT's call, the long's depth was already read... The claim is about the value, and `Grind_SideDepth` = `ArraySize(side.layers)` = filled layers (the resting entries are tracked in `l0_pending_ticket`/`add_pending_ticket`, not in the array). VERIFIED. Note: `layers` can contain a layer with `position_ticket == 0`? `Grind_AppendLayer` sets it from the deal; `Adr151_TestSetupLongLayer` can set 0 (LB20 test: a layer with a 0 ticket). If a layer with ticket 0 existed in production, `Grind_SideDepth` would count it as "filled" though it isn't. In production, layers are only appended on ENT fills with a real position id, and removed on exit fills. So `ArraySize(layers)` = filled. Except: ADR-163 rebuild — `Grind_RebuildBookFromTickets` builds layers from position tickets, so all real. OK, VERIFIED. Though a corner: could a layer remain in the array after its position closed? `Grind_RemoveLayerAt` on the fill. If a deal is missed, the array could hold a closed layer → counted as filled → the gate holds spuriously. That's the general stale-state risk, not new.

Hmm, actually here's a REAL one related to G4/T-1: **a layer whose exit has FILLED but whose deal wasn't processed yet** (the `GRIND_ROLL_CLOSING` state: `exit_order_ticket != 0 && !Grind_SelectOurOrder(...)`, or `exit_position_ticket != 0`). Such a layer is still in the array → counted in `Grind_SideDepth` as a "filled layer", even though the position is effectively closing/closed. So the gate could hold because of a layer that is in the process of closing. That's a transient (one tick). Fine, not worth flagging... Actually it could matter more: `exit_position_ticket != 0` means the close-by is queued; the layer stays in the array until the OUT_BY deal arrives. Meanwhile the layer still represents an open position (the close-by is a pending opposite position — hedging account, so both exist until the close-by executes). So counting it is correct. Fine.

Now let me examine T-7's "Requests saved and added". While gated: the `TrySide` sends nothing, but `Grind_LatticeTrackExtremes` still runs `CopyTicksRange` every tick per side. No requests. And `Grind_OnTickEngine` still does its entry repricing etc. So the saved requests are the roll modifies. Fine.

Let me now think REALLY hard about whether there's a hidden bug in the restart/extreme interplay that the tests miss and that would cause a REAL trading problem at N=0.

Consider a long hold (say 6 hours) with the gate holding. Every tick: TrackExtremes folds from from_msc to now (a few ms) + the live price; then TrySide restarts (extreme = 0, from_msc = now+1). So the extreme is effectively always ~0 between calls, and the tracked value = the live price at the start of the next tick. So the extreme is useless while gated — which is intended.

At release: TrackExtremes (folds from the last restart) → TrySide → the loop with probe = min(mkt, extreme).

Hmm, WAIT. Here's something: at the release call, `TrackExtremes` runs FIRST, and it folds the ticks from the last gated call's restart to now. But the restart happened at the END of the previous call (the previous tick). So the folded range is one tick. Fine.

But what about **the `from_msc` after the restart when the market time is the WALL CLOCK but the ticks' msc are the SERVER time**? `Grind_MarketTimeMsc()` returns `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` — the last tick's time in ms, which is the server time. And `CopyTicksRange` uses the same clock. Consistent. In the tester with a custom seed, consistent. Fine.

Hmm, what about the restart setting from_msc = t+1 where t = the last tick's time, and then `CopyTicksRange(from = t+1, to = the last tick's time at the next call)`. If no new tick arrived, from > to → 0 or -1. Discussed.

Hmm, here's a possible real bug: **`Grind_LatticeCopyTicks` in the PRODUCTION path uses `COPY_TICKS_INFO`, which returns bid/ask ticks. If the broker only provides trade ticks... eh, pre-existing (C55/ADR-162b).

Let me now look at the **`Grind_LatticeRollDeferredNote`'s use of `Grind_MarketAsk()`/`Grind_MarketBid()`** vs the loop's use. Consistent.

Now let me reconsider T-3's "at most once per gated episode per side" in the case where BOTH sides are gated (8/8, N=0). The long's TrySide is gated → its note (if due) → the long's latch. The short's TrySide is gated → its note → the short's latch. Both sides can emit ROLL_DEFERRED in the same tick (one each). That's "once per episode per side". Fine.

Hmm, now: **is the emitted `opposite_depth` correct in the 8/8 case?** The long's mark shows opposite_depth = 8. Fine.

Now let me look at something in T-6: "Values above `max_layers`... Anything that should FATAL and does not, or FATALs and should not?" Hmm: `Grind_ValidateRollGateInputs(true, 100)` → true → no FATAL. Is that OK? The gate would never hold (depth <= 8). So it's an off switch. Fine. What about `gate >= 0` with `InpVirtualLattice = false` → FATAL. Good. And `gate = -1` with lattice false → OK. Good. And the gate with reroll off → OK.

Now — an interesting one: **the design says the input requires the lattice. But the gate is applied inside `TrySide`, which is only called from `OnTick` when `InpVirtualLattice` is true (the `enabled` param). So the FATAL is redundant but harmless. Fine.

Hmm, let me now reconsider whether the FATAL could break an EXISTING preset. If any existing .set (FTMO, other fleets) has `InpVirtualLattice=false` and no `InpRollGateOpposite` key → the default -1 → `ValidateRollGateInputs(false, -1)` → true → no FATAL. Good. But what if a preset EXPLICITLY has `InpRollGateOpposite=0`? None do (it's new). Fine.

Hmm, ASSUMED for T-6: MT5 loads a .set key that's missing → the compiled default. Actually, MT5's behavior: when you load a .set file with missing keys, the missing inputs keep their current values (the compiled defaults, since the EA is freshly attached... actually, MT5 remembers the last-used input values per chart/instance in the terminal's config, not just the .set). Hmm, this is a real subtlety: MT5 saves the inputs with the chart profile. If a chart was previously run with a different default... The design assumes the default -1. I'll flag it as ASSUMED with a note: the safest is to verify the .set files on the fleets, or rely on the new `GRIND_ROLL_GATE opposite_max=` log line to confirm.

Now let me think about the **TEST GAPS** section comprehensively.

Also — hold on. Let me revisit RG2b: `AssertTrue("RG2b (F)", Grind_RollGateHolds(0, 1));` — at commit 1 the stub is `return false` → the assertion fails. Good, F. And RG2d `(2,3)` → true. F. Good.

And RG1d `(false, 0)` → the stub `return true` → AssertFalse fails. F. RG1e `(true,-2)` → the stub true → AssertFalse fails. F. Good.

So RG1: 3 G + 2 F = 5 assertions. Matches.

Now let me recount the tags in the attached file:
RG1: G,G,G,F,F = 2F.
RG2: G,F,G,F,G = 2F.
RG3: F,F,F,F,G,F = 5F.
RG4: G,G,G,G,G,G,G = 0F.
RG5: F,F,F,G = 3F.
RG6: G,F = 1F.
RG7: F,F,G,G = 2F (with RG7c mis-tagged).
RG8: F,F,F = 3F.
RG9: F,G,F,F,F = 4F.
RG10: G,G = 0F.
RG11: F,F = 2F.
RG12: F,G,F = 2F.
RG13: F,F,G = 2F.
RG14: F,F,F,G = 3F.
Total F = 2+2+5+0+3+1+2+3+4+0+2+2+2+3 = 31. Yes, 31 tagged F, and RG7c actually behaves as F → 32 failing at the stubs. The prompt states this. Confirmed.

And the total assertions: 5+5+6+7+4+2+4+3+5+2+2+3+3+4 = 55. Good.

Now — the prompt says "the implementation with three test-mechanics fixes (634c7ea) 2580/2580 on both". So at commit 2, all 55 pass. Let me verify each F at commit 2:
RG1d: `Validate(false,0)` → `0 == -1 || (0>=0 && false)` = false → AssertFalse passes. ✓
RG1e: `(true,-2)` → false → passes. ✓
RG2b: `(0,1)` → true → passes. ✓
RG2d: `(2,3)` → true. ✓
RG3a-f: a rc=0 ✓; b no VL ✓; c modify 0 ✓; d marker ✓; e no stranded ✓; f no ROLL_ACCEPTED ✓.
RG5a-d: a rc=0 ✓; b VL unchanged ✓; c marker ✓ (level 1.19800 crossed by 1.19010); d ✓.
RG6b: gate 2, opp 3 → holds → rc=0 ✓.
RG7a: rc=0 ✓; b no VL ✓; c rc=1 ✓; d VL=1.19400 ✓.
RG8a-c: ✓.
RG9a-e: ✓.
RG11a,b: ✓.
RG12a: ✓; c ✓.
RG13a,b: ✓.
RG14a-c: ✓.
All 55 pass at commit 2. ✓.

But wait — I should double check RG5c at commit 2: `Adr162b_ArchiveFind("ROLL_DEFERRED", 0) != ""`. The gate holds (opp=1) → the note: `Grind_SideDepth(g_grind_long)` = 8 >= 8; level = the min effective... Adr165_Fixture: all 8 long layers rolled with VLs 1.20600 down to 1.19900 → anchor = 1.19900 → level = 1.19800; mkt = ask = 1.19010; crossed (1.19010 <= 1.19800) → marker. ✓. And the latch was false at the start (Adr165_Fixture presumably calls Adr162b_Reset). ✓.

Hmm, but does `Adr165_Fixture` call `Adr162b_Reset`? If not, stale state from RG4 could leak. RG4 ends with `Adr162b_Reset()`. So the latch is cleared. And RG5's first call is gated — the latch is false. ✓.

Now RG12a at commit 2: the long's gate holds (opp=1). ✓ (passes).

OK so the 2580/2580 holds.

Now, what are the "three test-mechanics fixes"? Possibly:
1. RG7c: the assertion itself is fine at commit 2; no fix needed.
2. RG8's `Grind_MarketTestReset()` (the seam cleanup) — the design says RG8/RG13 call it.
3. RG13's `C55_Reset()` at the end / the `ArrayResize(g_grind_short.layers, 0)`.
Whatever. Not required.

Hmm, hold on. Let me look for a test that might not pass at commit 2 for a subtle reason — the prompt says the attached test file yields 2580/2580 with three fixes, so the ATTACHED file may be the version WITH those fixes (i.e., the final one). Since the attached file's RG7c is tagged (G), and the prompt says the "(G)" label is a derivation slip, maybe one of the three fixes is exactly to change RG7c's tag to (F)? That doesn't change the pass count. Hmm, "three test-mechanics fixes" — the count 2580/2580 is what matters.

Whatever. Let me now also consider: does any EXISTING test change at commit 2 due to C5/C6/C7/C8/C9 with the gate defaulting to -1? The existing tests call `TrySide`/`OnTick` without the gate → -1 → the C8 clear runs → the loop as before. The restart is never called. `Grind_LatticeTrackOneSide`'s new clear (below cap) sets the latch false — no other effect. `Grind_LatticeResetBackoff` clears the latch — no other effect. So no existing test changes. ✓.

Hmm, but hold on! `Adr165_Fixture` — the ADR-165 tests (RR*) call `TrySide` with reroll=true and no gate → unchanged. ✓.

Now let me examine the **negative space** claim: "Do not change `Grind_LatticeTrackExtremes`". The attached `Grind_LatticeTrackExtremes` is unchanged. ✓.

Now let me write up the T-1..T-8 verdicts.

T-1: HOLDS (with a note that the depth is stable within a call; no path where a gated side acts; the gate is after blocked/backoff so a blocked/backoff side returns 0 anyway). Hmm, T-1 explicitly asks: "where `blocked` / backoff ordering lets a gated side act?" — no; a gated side returns 0 in all orderings. But the ordering has the SIDE EFFECT that the extreme restart/note are skipped in the backoff path (which I'll report under T-2/T-3). Verdict for T-1: HOLDS.

Hmm, actually, wait. Let me reconsider one T-1 case: "a fill processed between the two calls". In MQL5, `OnTradeTransaction` and `OnTick` are both called by the terminal; the terminal processes events sequentially on the same thread. So no interleaving within `Grind_LatticeOnTick`. ASSUMED (documented MQL5 behaviour: the EA runs in a single thread). I'll state that.

But hmm — what about `Grind_LatticeTrySide` calling `Grind_ExitQManageSide` → `Grind_PlaceLimit` → `Grind_OrderEngineSend` → in production, `Grind_OrderSendCounted` → `OrderSend`. `OrderSend` is synchronous; a fill is reported via OnTradeTransaction later. So no re-entrancy. ✓.

Now T-2: BREAKS or NEEDS-FIX (the backoff/blocked hole). Let me formulate the evidence with quotes.

Evidence 1 (orders): `Grind_LatticeTrySide`:
```
   datetime backoff = is_long ? g_grind_vl_backoff_long : g_grind_vl_backoff_short;
   if(now < backoff)
      return 0;
```
before the gate block:
```
   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
```
And `Grind_LatticeTrackExtremes` runs unconditionally before the blocked check:
```
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;
```
So while `now < backoff` or `blocked`, the extreme folds (via TrackExtremes) but the restart is skipped → a dip inside the held period survives into the release when the gate opens at the first post-backoff draw. Smallest fix: hoist the gate block above the backoff check (the gated path sends nothing, so the backoff is irrelevant while gated) — or add the restart to the backoff branch. I'll quote both lines.

Hmm, also the `blocked` case: `Grind_LatticeOnTick` returns before TrySide when blocked, so the gate block is skipped; the extreme is folded in TrackExtremes before that return. Same hole when the block lifts with the gate already open. But when a halt is set, no new positions... eh. The blocked case: `g_grind_halted || g_grind_quarantined` → the lattice stops. If the halt lifts (quarantine recovery), the gate may be open → a roll with the stale extreme. Same fix (the LatticeOnTick blocked return would need the restart too). Hmm, the smallest single fix: in `Grind_LatticeTrySide`'s backoff branch, add `if(Grind_RollGateHolds(roll_gate, opposite_depth)) { Grind_LatticeRollGateRestartExtreme(is_long); }` before returning; and in `Grind_LatticeOnTick`, before the `if(blocked) return;`... hmm, that's messier. Actually, the cleanest: put the restart in `Grind_LatticeTrackOneSide` when... no.

I'll present: recommendation = call `Grind_LatticeRollGateRestartExtreme` whenever the gate holds, before the early returns (i.e., move the gate-held restart above the backoff check in `TrySide`, and note that the `blocked` path in `OnTick` needs the same treatment). Severity: NEEDS-FIX (bounded: only matters if the gate opens exactly at the first ungated draw after a backoff/halt that overlapped a hold; the impact is a replayed dip → a rolled exit clamped passive → a fill at the worst point, exactly P4). Since the design's premise P4 is the reason for the whole feature, and this path silently defeats it, I'd call it NEEDS-FIX (not fatal, has a small fix).

Hmm, is there another T-2 hole: the EA restart while gated (globals re-init). After a restart, `g_grind_vl_tracking_* = false`, `g_grind_vl_from_msc_* = 0`. Then the first `TrackOneSide` rebuilds from `newest+1` capped at 24h → the extreme covers up to 24h (VC10). If the gate holds at the first TrySide, the restart discards it → fine. If the gate is open at the first TrySide (the opposite side emptied during the downtime, or the reconstruction... wait, on restart the opposite depth is reconstructed from the broker). Then the first roll uses a 24h extreme → replays dips from the deferral (and beyond). Hmm! This is a REAL hole: the EA restart while gated drops the "gated" state (there's no persisted flag that the side was gated), so the extreme catch-up (up to 24h) replays the deferral period's dip. But note: this is the pre-existing behaviour on any restart (the 24h catch-up), and VC10/VC3 pin it. The design's C6 only restarts the extreme when the GATE IS EVALUATED AS HOLDING. On a restart, the first evaluation: if the gate holds → the restart (fix). If not → the 24h catch-up. So a restart whose first lattice call finds the gate OPEN (opposite empty) rolls with the 24h extreme → replays. Is that reachable? Yes: the EA restarts while the long is gated with 8 layers and the short has, say, 1 layer; during the restart (a few seconds) the short's layer exits → after the restart, the short has 0 → the gate is open → the long rolls with the extreme = the min ask over the last 24h (or since the newest layer opened). Wait — since the newest layer's open: `from_msc = MathMax(newest+1, now - 24h)`. The newest long layer was opened... during the deferral the long didn't add layers (it's capped). So the newest layer's open could be hours ago → the extreme covers those hours → replays the dip from the held period. So YES, a restart-while-gated with the gate open on the first call replays. The design has no test for this (RG8/RG13 don't restart). Fix: persist the gated state, or (simplest) on the FIRST lattice call after an EA start, restart the extreme for a capped side whose gate is... hmm, that changes first-roll behaviour. Or: cap the catch-up when a gate is configured. Honestly the smallest pragmatic fix: treat the EA restart like the gate: if the gate is configured (>= 0) and a side is at cap on the first evaluation, restart its extreme (i.e., don't use the 24h catch-up when a gate is enabled). Hmm, that changes the VC10/VC3 catch-up semantics for gated fleets only. I'd present it as a NEEDS-FIX / documented residual risk with the minimal fix: after `Grind_ReconstructState`, if `InpRollGateOpposite >= 0`, call `Grind_LatticeRollGateRestartExtreme` for both sides (they'll be re-restarted on the first gated call anyway, and for an open gate this prevents the 24h replay). That's a one-line-ish fix in OnInit. Good, that's a clean small fix.

Hmm, but careful: is the restart at OnInit harmful for the non-gated path? It would discard the catch-up for a fleet with the gate ON, which is the intent (the gate's purpose is to not replay held-period dips). OK.

Actually wait, I need to be careful about whether the 24h catch-up on a restart is really "the held period". If the EA restarts, the deferral continues (the gate still holds by depth). The extreme restart on each gated call then discards. So the only risk is the FIRST call. Yes, as analyzed. I'll include it.

T-3: HOLDS (with the note that the latch clear is skipped when the side is in backoff/blocked — but that's harmless for spam; and the re-arm works, RG9).

Hmm, but let me check one more T-3 spam path: the note fires only if the latch is false AND a roll is due. After firing, the latch = true. Now consider: the gate holds for the LONG; the note fires. Then the LONG's depth drops below cap (a layer exits) → `TrackOneSide` clears the latch. Then the LONG re-fills to cap (the add path) → the gate still holds (the short still has > N) → the note fires again on the next due tick. New episode. Fine.

Another: `Grind_LatticeResetBackoff` is a test-only reset (A8: no production caller) → no spam there. ✓.

Another: the clear in `TrySide` runs on any ungated call — including calls where the side is at cap but the gate is open and nothing is due. Then if the gate re-holds later and a roll is due, the marker fires. That's a new episode (the gate reopened in between). Fine.

T-4: the burst. Let me count with quotes: LB7's expected `g_grind_order_test_modify_calls == 5 && remove == 5 && place == 5` for 5 rolls → 15 requests. At release, up to 8 first rolls → 24 requests per side per call. Nine instances → 216 in the worst tick, and the API counter. Verdict: HOLDS (accepted by GR6-1) but note the re-roll path is one per call (throttled) and the pause. Also the "roll placed while the counter side's new L0 is about to fill": the gate has already opened (the counter's L0 is empty), and the roll's new exit is clamped passive at the market and can fill immediately — that's the designed release behaviour (C55 VC3), and the design accepts it. Hmm, and the P3 claim: the counter's L0 re-fill happens later in the same OnTick (in `Grind_OnTickEngine` → `Grind_TryPlaceL0`) — so the roll is placed BEFORE the counter's L0 re-fill, confirming P3. Evidence: the OnTick order:
```
   Grind_LatticeOnTick(InpMagic, ...);
   Grind_SessionStep(...);
   Grind_BreakerOnTick(...);
   ...
   Grind_OnTickEngine(InpMagic, ...);
```
So the lattice roll precedes the L0 placement. ✓ (P3 confirmed).

T-5: Let me enumerate:
- I6 / carry: the gate writes no VL, so I6's `price from the VL` is unaffected; but the carry pass still modifies exits while gated (it runs on a timer, not gated), and the deferred roll at release then overwrites the carry shift (`Grind_CarryShiftDelete(pos)`), which is the normal roll behaviour. HOLDS with a note: nothing in ADR-166 stops the carry pass from shifting a gated side's exit (by design, the gate only stops rolls).
Hmm, is that a problem? The gate's intent: while the opposite side holds layers, don't roll (don't pay the roll cost). The carry pass continues to shift exits. Fine.
- Reconstruction: the new globals are not persisted (like all the VL globals) — after a restart, the deferred latch is false → the marker could fire once per restart. Fine. See the T-2 restart hole.
- ADR-155 eject: unaffected (it runs before the lattice, and `Grind_EjectPollCommand` targets the deepest rank; if that layer is one the gate would roll, the eject still works). Hmm — one interaction: ADR-155 ejects the deepest layer by moving its exit to a "worse" passive target. If the gate holds, the deepest layer's eject proceeds... wait, "deepest" = rank depth-1 = the highest rank resting. The eject is independent of the lattice. Fine.
- ROLL_CLOSING_STUCK: while gated, no warning can be emitted (the note is only called inside the loop). But the state is reset on the first ungated call (the trailing `if(!closing_stop) Grind_LatticeResetClosingState(is_long);` is not reached while gated... hmm, the gated path returns BEFORE that line, so the closing STATE is left as-is; that's the design (RG14 pins it). So a layer that is closing during a long hold never warns — an observability loss, not a trading fault. Verdict: HOLDS (accepted), with a note.
- The breaker/quarantine: `blocked` → the whole lattice is skipped → the gate is inert. Fine.
- "Anything that relied on TrySide running its loop every call at cap?": the loop also (a) clears the stranded latch when a candidate exists, (b) resets the closing state, (c) resets the fail count after a successful roll, (d) sets the backoff on failure. While gated, none of these run for a gated side. The fail count: a stale fail count from before the gate persists (RG14c pins that) → when the gate opens, the first failure doubles from the stale count (a longer backoff). Minor. Verdict: HOLDS with a note.

T-6: HOLDS with the ASSUMED .set behaviour, plus: values above max_layers are accepted as effectively off (should they be? design says >= 0 with lattice is valid; fine); negative below -1 → FATAL (RG1e); the gate on with reroll off → allowed and tested (RG11); the gate does NOT fatal when `InpVirtualLattice=false` and the gate is -1 (correct). Anything that should FATAL but doesn't: hmm, what about `gate >= 0` with `InpVirtualLattice=true` but `InpMaxLayers<1`? Caught by the geometry checks. OK. What about a gate value like 0 with the lattice and the reroll on and the pause? Fine.

Hmm, one more: the input is `int InpRollGateOpposite = -1`. MT5 inputs can't be negative...? They can (int). Fine.

T-7: as analyzed. Let me also count the WORST plausible day: at N=0, the held side sends nothing; each release sends up to 24 requests. On a trending day with, say, 20 releases per side per instance → ~500 requests per side per day per instance… nine instances → ~4500/day. Way below the 1e6 counter. Verdict: HOLDS.

Hmm, but I should also count the `Grind_LatticeTrackExtremes` → `CopyTicksRange` per tick per side per instance: 2 per tick per instance; nine instances → 18 calls/tick. A CPU cost, not a request. Could be a terminal-wide CPU concern on a busy symbol. Worth a note.

T-8: the RG7c confirmation + the vacuous/short-circuit analysis + the missing tests.

Let me also double check the claim in T-8: "the market-time seam left seeded". In the attached file, RG8 seeds the time and clears it at the end; RG13 too. But note: RG8's `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0)` is BEFORE `Grind_MarketTestSeedTimeMsc(...)`. And the cleanup `Grind_MarketTestReset()` clears both. OK. Are there other tests in the suite (not attached) that seed the time? Out of scope.

Hmm, one thing: **RG8 does not call `Grind_MarketTestReset()` before seeding** — if a previous test leaked the seam, RG8's own `Grind_MarketTestSeedTimeMsc` overwrites it anyway. And the extreme/from_msc are set explicitly. So RG8 is robust.

**RG13 does not call `Grind_MarketTestReset()` before seeding** — it calls `C55_Reset()` (which does NOT clear the seam, per A9!). If a previous test (e.g., RG8, which resets) left the seam... RG8 clears it. But if RG12 or another test leaked the seam, RG13 sets it explicitly before use. So OK. Hmm, but `Grind_MarketTestSeed(1.20690, 1.20700, 0, 0)` happens BEFORE `Grind_MarketTestSeedTimeMsc`; both are set. Fine.

Now, RG13's first OnTick at 10:00 relies on the market time being exactly 10:00:00.000 (the seed), and the restart → from_msc = 10:00:00.001. Then at the 10:01 call... but note `Grind_LatticeTestAddTick(D'2026.09.28 09:30', ...)` sets the tick's msc = 09:30 * 1000. The comparison `g_grind_vl_test_tick_msc[i] < from_msc` → 09:30 < 10:00:00.001 → skipped. ✓.

Now, a REAL question for RG13: at the 10:00 call, does `TrackExtremes` for the LONG actually fold the 09:30 tick? `from_msc` = max((newest+1)*1000, (now - 86400)*1000) where newest = 09:07 and now = 10:00. (09:07+1) = 09:07:01 → 09:07:01*1000. The test tick msc = 09:30*1000 = 09:30:00.000 >= 09:07:01 → included. ✓. And the upper bound in the test path: `Grind_LatticeCopyTicks` ignores the upper bound (it filters only `>= from_msc`)! Hmm:

```
      int n = 0;
      for(int i = 0; i < ArraySize(g_grind_vl_test_tick_msc); i++) {
         if(g_grind_vl_test_tick_msc[i] < from_msc)
            continue;
         ...
      }
```
So in the TEST path there's NO upper bound — ticks NEWER than the current market time are also copied! In production, `CopyTicksRange(from, to=MarketTimeMsc())` bounds it. RG13's 09:30 tick < 10:00 → fine. But a test that adds a tick AFTER the market time would see it. Not an issue here. But it IS a test-harness fidelity gap: the test double has no upper bound, so a test cannot catch a bug where the code copies future ticks. Worth a mention in TEST GAPS. Hmm, actually is it a real gap? The ADR-166 branch doesn't touch CopyTicks. Low.

Now, let me look for something I might have missed regarding the **`from_msc = t + 1` overflow or `(long)` cast** — no.

Let me now check the **`Grind_LatticeRollGateRestartExtreme` when `Grind_MarketTimeMsc()` returns 0** (no ticks ever, or the test seam unset in the tester where SYMBOL_TIME_MSC might be 0). Then from_msc = 1. Then `TrackOneSide` (tracking true) copies ticks from >= 1 → in production, `CopyTicksRange(from=1)` → all ticks since the epoch → a huge copy (or MT5 caps it). Hmm! If `Grind_MarketTimeMsc()` returns 0 (e.g., the terminal hasn't received a tick yet, or a symbol with a zero SYMBOL_TIME_MSC), the restart sets from_msc = 1 and the extreme folds ALL available ticks (the full history range) → the extreme = the historical min ask → a stale extreme on release. Is `Grind_MarketTimeMsc() == 0` plausible? `SYMBOL_TIME_MSC` is the last tick's time; in OnTick it's non-zero. But the restart also happens on the FIRST call (e.g., right after OnInit before any tick?... OnTick requires a tick). So non-zero in practice. And in the tester, `Grind_MarketTestSeedTimeMsc` may be unset → `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` in the tester returns the modelled time in ms (non-zero). OK, low risk, but worth noting: `from_msc = t + 1` with t = 0 would open the CopyTicksRange to the whole history. Hmm, in the tests, `Adr166_TryLong` calls TrySide directly with the seam possibly unseeded (RG3-RG7, RG9-RG12 don't seed the time!) → `Grind_MarketTimeMsc()` = the tester's SYMBOL_TIME_MSC (non-zero) → the restart sets from_msc = that + 1 → fine (the direct calls never call CopyTicks). OK. But it means RG3-RG7 etc. leave `g_grind_vl_from_msc_long` at the real tester time + 1. Harmless.

Now let me reconsider T-2's "the gate releasing on the same tick it last held" once more, for a REAL miss: The restart sets from_msc = now+1 (now = the last tick's time). The RELEASE call runs `TrackExtremes` with the SAME market time if no new tick arrived (e.g., a timer-driven or a duplicate OnTick). Then CopyTicksRange(from = t+1, to = t) → empty → n = 0 (or -1). With n = 0, the live price is folded → the extreme = the live ask. Fine. With n = -1, the function returns → the extreme stays 0 → TrySide uses mkt. Fine. So no miss. ✓.

Hmm, what if the release call happens with a market time equal to the restart time (the same tick) and the extreme is 0 → probe = mkt. So the roll requires the CURRENT market to be crossed (not the extreme). That is the "restart" semantics. Fine.

OK. Now let me also examine the possibility of a **schema mismatch in the marker details**: RG9e checks `"opposite_depth":1` and `"gate":0`. The code emits `"gate":0` — yes `IntegerToString(gate)`. ✓.

Now let me write the PREMISE VERDICT: 
- P1: an operator judgement, measured; the branch implements the mechanism. Not falsifiable by me.
- P2: measured (250/257). Consistent with the mechanism.
- P3: DERIVED from source. I can confirm the ordering (the lattice roll runs before `Grind_OnTickEngine`'s L0 placement in the same OnTick). And the gate counts the filled layers, and the counter side's L0 re-fill happens after. So P3 holds, WITH the caveat that the counter side's L0 re-fill can also happen in `OnTradeTransaction` (via `Grind_TryPlaceAddAtFill` → but that places the ADD layer, not L0 — the L0 is placed in `Grind_OnTickEngine`'s `Grind_TryPlaceL0` or the fill handler? For an empty side, the next layer is placed by `Grind_TryPlaceL0` in OnTickEngine. So the re-fill is on the next OnTick after the exit. And the gate's release roll happens in the SAME OnTick, before OnTickEngine's L0 place. ✓ P3 confirmed.
- P4: VERIFIED in source (the fold + probe) — and the branch's fix (restart) addresses it EXCEPT in the backoff/blocked/restart paths.

Merge safety: the input -1 → safe. N=0 on one fleet: the code paths are safe except the restart holes (bounded, NEEDS-FIX) and the observability loss (ROLL_CLOSING_STUCK suppressed while gated). Also the RG7c mis-tag is a test-label issue only. I'd say: safe to merge with -1 (the -1 path is provably unchanged); setting N=0 on one IC fleet is acceptable for a single-fleet experiment, but I'd fix the backoff/restart holes first (one line each) since they silently defeat the P4 mitigation that the whole feature's scoring depends on. Hmm, "would the hole materially change the experiment?" — it's rare. I'll say: merge with -1 OK; N=0 acceptable with the caveat that the deferred-extreme restart should be hoisted above the backoff (small fix), OR the restart hole documented. Let me be decisive: merge WITH THE ONE-LINE FIX (the gate restart above the backoff), or merge as-is and accept the residual. Given "Do not call anything fatal that has a fix: give the smallest fix", I'll MARK T-2 as NEEDS-FIX and give the fix, and say the merge with -1 is safe (the fix doesn't affect the -1 path at all) while the N=0 fleet should get the fix first (it's on the live path).

Hmm, wait. Let me double check the backoff-hole claim once more by re-reading the code order in the attached engine:

```
   if(!enabled || blocked)
      return 0;

   datetime backoff = is_long ? g_grind_vl_backoff_long : g_grind_vl_backoff_short;
   if(now < backoff)
      return 0;

   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
      Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);
      return 0;
   }
```

Yes. Confirmed.

And is `g_grind_vl_backoff_*` used with `now` = `TimeCurrent()` (seconds)? Yes: `if(now < backoff)`. And the backoff is set to `now + (int)sec` with the same `now`. So a backoff of up to 1800 s.

Now, one more possible hole in T-2: **`Grind_LatticeRollGateRestartExtreme` is called per side in `TrySide`, which is only called for a side at cap. Fine.

Let me also check the `blocked` hole in OnTick:
```
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;
```
Yes: while blocked, the extremes are tracked but not restarted. When the block lifts with the gate open → a stale extreme. Same family. I'll mention both.

Now let me also reconsider: is the extreme restart even NEEDED on every call, or would it be better to only restart once per gated episode (i.e., when the latch is not yet set)? Restarting every call means the extreme is always fresh → the release uses only the current market + the last tick. That's the design (GR6-3). But note: the between-call catch-up at release is thus limited to the interval between the LAST GATED CALL and the RELEASE call — i.e., one tick. So a dip that happened 1 second before the release but after the last gated call IS replayed. Since OnTick fires on every tick, that window is tiny. Fine.

Hmm, now here's an interesting consequence I should mention under T-4/T-2: because the restart happens on every gated call, the release roll uses only the last tick's range → the "first roll at release" requires the CURRENT market to be at/through the level (or a dip in the last tick). So at a release where the market has moved BACK (e.g., the counter side's exit filled because the market reversed), the capped side rolls only if the current market is still through the next level. That's intended.

Now let me write the GIVENS with quotes. I need exact quotes. Let me pick concise ones.

G1: `grind_pure.mqh`, `Grind_RollGateHolds`: "return gate >= 0 && opposite_depth > gate;" → for gate = -1, false. And `grind_engine.mqh`, `Grind_LatticeTrySide`: the clear "if(is_long)\n      g_grind_vl_deferred_noted_long = false;" — I'll quote "g_grind_vl_deferred_noted_long = false;". Also caveat: C5's below-cap clears in `Grind_LatticeTrackOneSide` also execute on the -1 path (no-ops since the latch is never set with -1: it is set only in `Grind_LatticeRollDeferredNote`, reachable only when the gate holds). VERIFIED.

G2: `fxgrind.mq5`, `OnInit`: quote "if(!Grind_ValidateRollGateInputs(InpVirtualLattice, InpRollGateOpposite)) {" and "if(!Grind_MagicLockClaim(InpMagic)) {" — the first precedes the second. VERIFIED.

G3: `grind_engine.mqh`, `Grind_LatticeTrySide`: the block "if(Grind_RollGateHolds(roll_gate, opposite_depth)) {" ... "return 0;" precedes the loop; quote "Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);\n      return 0;". And no order ops/VL/stranded in `Grind_LatticeRollGateRestartExtreme`/`...DeferredNote`. VERIFIED.

G4: `grind_engine.mqh`, `Grind_LatticeOnTick`: "Grind_SideDepth(g_grind_short));" and `Grind_SideDepth`: "return ArraySize(side.layers);". VERIFIED.

G5: `Grind_LatticeRollGateRestartExtreme`: quote "g_grind_vl_from_msc_long = t + 1;". VERIFIED.

G6: `Grind_LatticeRollDeferredNote`: quote "Grind_ArchiveMarker(\"INFO\", \"ROLL_DEFERRED\", is_long ? \"L\" : \"S\", 0, detail);" and the top guard "if(g_grind_vl_deferred_noted_long)\n      return;". VERIFIED (no `Grind_TelemetryEmit` in the function).

Now the T-sections. I need quotes for each claim.

Let me be careful to keep the output structured and not too enormous but complete. The prompt demands evidence with quotes for every claim. Let me now compose.

For T-1, quote the OnTick ordering and the SideDepth read; verdict HOLDS.

For T-2, quote the backoff return and the restart, the TrackExtremes-before-blocked; verdict NEEDS-FIX; give the fix.

For T-3, quote the latch guard and the clear; verdict HOLDS.

For T-4, quote the LB7 expected request counts (from the test file) and the loop bound; verdict HOLDS (accepted).

For T-5, quote the closing-state reset line and the NoteClosing; verdict HOLDS with notes; maybe NEEDS-FIX? The prompt says ROLL_CLOSING_STUCK never warns during a hold — that's an observability gap, not a fault. I'll say HOLDS (documented) plus a note that the fail count / backoff are frozen while gated (RG14 pins it deliberately).

For T-6, verdict HOLDS (ASSUMED MT5 .set default).

For T-7, verdict HOLDS.

For T-8, RG7c CONFIRMED; list the vacuous/short-circuit items and the untested behaviours.

PREMISE VERDICT and TEST GAPS.

Let me also double check one more potential real bug: **`Grind_LatticeRollDeferredNote`'s `depth` field** — it reports the side's depth (8), fine.

And one more: the note is emitted BEFORE the restart? No: the restart is first, then the note. The note doesn't use the extreme. Fine.

Hmm, let me reconsider the note's "once per gated episode" vs the actual code once more for a subtle spam: Suppose the gate holds and the level is crossed → the note fires, latch = true. Now the market moves AGAINST the side so the level is no longer crossed (e.g., for a long, the ask rises above the level). The latch stays true. Then the market crosses again → no new note (the latch is true). Good, no spam. And the "episode" is the whole gate-held period. ✓.

But here's a subtle one: the latch is cleared on ANY ungated call. Consider the gate holding for the long, but the long is NOT at cap... then TrySide isn't called; TrackOneSide clears the latch below cap. And the ungated clear. Fine.

Hmm, here's one more T-3 case: **the gate holds and the note fires; then the OTHER side's TrySide runs in the same tick.** The short's `TrySide` clears the SHORT's latch (if its gate is open). Independent. ✓.

Now let me reconsider whether the ROLL_DEFERRED note could fire when the side is NOT actually deferred — i.e., the gate holds but the side couldn't roll anyway (e.g., a closing layer, or no candidate)? The note only checks the level crossing. So it could report ROLL_DEFERRED when, at release, the roll would fail for another reason (closing). Minor.

And: the note fires even if the roll would have been blocked by the PAUSE (reroll only). Fine — the marker says "deferred", and the pause also defers.

Now let me also double check that the note does NOT fire when the gate holds but the side's level is crossed only because of the EXTREME (the missed-dip case). The note uses `mkt` (the live market), NOT the extreme:
```
   const double mkt = is_long ? Grind_MarketAsk() : Grind_MarketBid();
   if(!Grind_LatticeLevelCrossed(is_long, mkt, level))
      return;
```
So the note is emitted ONLY when the LIVE market is through the level — consistent with the design's "only when the live market crosses the next level". ✓. Hmm, but that's interesting: if the extreme (a dip) is through the level but the live market is not, the note does NOT fire, yet `TrySide`'s loop would have rolled (the probe = min(mkt, extreme))! So there's a mismatch: while gated, a roll that WOULD have happened (via the extreme) does not produce a ROLL_DEFERRED marker. So ROLL_DEFERRED under-reports the deferrals: it only records the live-market crossings. Is that per design? Yes: "only when the live market crosses the next level". So a deferral of an extreme-driven roll is silent. Hmm, worth noting in T-3 as a designed observability gap (the marker count is not the number of deferred rolls). Actually it's ruled (GR6-4 and C7). I'll note it as a limitation, not a break. But it does matter for the experiment's telemetry: the operator may see fewer ROLL_DEFERRED than actual suppressed rolls. Worth a TEST GAPS / note.

Hmm, and conversely: at release, the roll CAN fire off the extreme (a dip within the last tick) even if the live market never crossed during the hold. Fine.

Now, let me also verify: does the gated path suppress the roll that the EXTREME would have triggered? Yes: the gate block returns before the loop, so `probe = min(mkt, extreme)` is never evaluated while gated. And the restart zeroes the extreme each tick anyway. So a dip during the hold never triggers a roll. ✓ (that's the point).

OK. Now let me also think about whether the gate can cause a PERMANENT strand that would otherwise not happen: with the gate holding, the side never rolls, so it never reaches `Grind_LatticeMaybeStranded` → no ROLL_STRANDED warning even if the market is 2 steps past the level. So pipshed shows nothing amber for a gated side that is deeply stranding. The design rules this (GR6-4: a designed state must not light pipshed amber). But: the side is genuinely stuck (no rolls) for the whole hold, and the operator loses the amber signal for the whole hold. The ROLL_DEFERRED INFO exists instead. Acceptable per the ruling. I'll note it in T-5/T-8 as an observability trade (ruled).

Hmm, but here's a REAL one: **is the side permanently unable to roll if the opposite side is permanently >= 1 layer?** In a strong trend, the counter side's L0 keeps scalping and re-filling, so the gate keeps re-engaging; the deferrals continue. In a "continuation" the counter side's L0 is deep in profit... hmm, the counter side has at most 1 layer (the L0 at mid+width) which scalps at +exit. In a strong trend, the counter L0 fills, then its exit (5 pips against the trend) fills quickly → the gate opens for a moment. So the capped side rolls in those windows. P3. OK.

Now let me make sure about the "one fleet at N = 0, the others at -1" and the `GRIND_ROLL_GATE opposite_max=` print — the only way to verify the input took. ✓ (A14).

Now let me write the TEST GAPS:
1. RG7c's tag (label fix).
2. No test for the backoff/blocked-restart hole (T-2).
3. No test that `OnInit` FATALs / the FATAL ordering (G2) — RG1 only unit-tests the pure function.
4. No test for the new log line / the `LATTICE_CONFIG` `roll_gate` field.
5. No test that `ROLL_DEFERRED` does NOT emit telemetry (G6's "no telemetry emit") — would need a telemetry counter assertion.
6. No short-side mirror of RG8 (the short restart) — RG7 covers the short gate, not the restart.
7. No test for the deferred latch surviving while the level stays crossed for many ticks (only 2 calls in RG9) — minor.
8. No test for `CopyTicksRange` returning -1/0 on the gated/release path (VC9 covers the pre-gate path only).
9. No test for the EA-restart-while-gated (the 24h catch-up replay) — RG8/RG13 use the test seam within one "session".
10. The test double `Grind_LatticeCopyTicks` has no upper bound (it ignores `Grind_MarketTimeMsc()`), unlike the production `CopyTicksRange(..., (ulong)Grind_MarketTimeMsc())` — so a future-tick bug can't be caught, and RG13's "no replay" reasoning relies on the lower bound only.
11. The below-cap latch clear (C5) is only indirectly pinned via the suite ordering (RG9a depends on the latch being false at the start).
12. No test that the F-inputs gate is actually WIRED into `OnTick` (RG12 tests OnTick but only the long/short depth pass-through; the input → OnTick wiring is only `fxgrind.mq5`).

Hmm, and: RG4d/RG10b/RG14d are "assert empty" assertions that rely on other assertions in the same test to prove the archive is live — note it but they're fine.

Also, T-8 asks: "an assertion ... that passes vacuously (state left from an earlier fixture, ...)". Let me name RG9b (it passes at both commits because at the stubs no marker exists at all → the assertion is vacuous at commit 1; its meaning at commit 2 depends on RG9a's marker). And RG6a (passes at both because the boundary means no gate). And RG4g/RG12b similar. These are G by design. I'll mention RG9b as the notable one: it's a G but its purpose (no second marker) is only meaningful because RG9a proves a first marker exists — so it's not vacuous at commit 2, but it IS vacuous at commit 1 (which is fine for a G).

Hmm, and one more potential vacuous one: RG14d (`ROLL_CLOSING_STUCK` == "") passes at both because neither commit reaches `Grind_LatticeNoteClosing` in this test (at commit 1 the roll succeeds; at commit 2 the side is gated). So RG14d never fails at either commit → truly vacuous (it can't distinguish). Same for RG3e, RG5d, RG11a? No: RG11a fails at commit 1 (stranded fires) — meaningful. RG3e: at commit 1, does ROLL_STRANDED fire? RG3 rolls 7001 successfully → no stranded → "" → passes. At commit 2 → "". So RG3e is vacuous at both (it only guards against a regression where the gated path strands). It's a guard, so vacuous-by-design but still useful as a regression guard. Fine.

Let me now also double-check the claim "RG14d G" — yes, tagged G, and it can never fail in this test as written (neither commit calls NoteClosing). I'll note that RG14d is a guard that cannot fail for the current code paths; the assertion that actually pins the closing state is RG14a/b (the ticket/since unchanged).

OK, one more sweep for real bugs in the new code... Let me re-read `Grind_LatticeRollDeferredNote`:

```
void Grind_LatticeRollDeferredNote(const GrindSideState &side, const bool is_long,
                                   const double add_pips, const int max_layers,
                                   const int gate, const int opposite_depth)
{
   if(is_long) {
      if(g_grind_vl_deferred_noted_long)
         return;
   } else if(g_grind_vl_deferred_noted_short) {
      return;
   }
   if(Grind_SideDepth(side) < max_layers)
      return;
   const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));
   if(level <= 0.0)
      return;
   const double mkt = is_long ? Grind_MarketAsk() : Grind_MarketBid();
   if(!Grind_LatticeLevelCrossed(is_long, mkt, level))
      return;
   const int depth = Grind_SideDepth(side);
   const string detail = ...
   Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", is_long ? "L" : "S", 0, detail);
   Print("INFO ROLL_DEFERRED ", detail);
   if(is_long)
      g_grind_vl_deferred_noted_long = true;
   else
      g_grind_vl_deferred_noted_short = true;
}
```

Note: the level uses the ANCHOR from `Grind_ComputeAddTarget` which uses the VL when any layer is rolled. During a hold, no new VLs → the level is stable. But as the carry pass accrues shifts, `Grind_EffectiveEntry(entry, pos)` = entry + shift? Let's see: `Grind_ComputeAddTarget` uses `Grind_EffectiveEntry(side.layers[i].entry_price, side.layers[i].position_ticket)` when any_vl — the effective entry includes the carry shift/eject offset. And `Grind_ComputeAddTarget`'s `any_vl` branch uses the effective entries of ALL layers. So the carry pass changes the level over time. That means the level the note uses can drift as carry accrues. The loop uses the same computation. Consistent. ✓.

Hmm, interesting: `Grind_ComputeAddTarget` returns the anchor (min/max effective) then `Grind_AddTargetPrice(anchor, add, point, dir)`. Fine.

Another: the note's `level` is NORMALIZED; the loop's `level` is also normalized. ✓.

Let me check `Grind_ArchiveJsonDouble(level, 5)` for the level and market — fine.

Now, is there any chance the note's `Print` spams the LOG? Guarded by the latch. ✓.

Now let me re-examine the C8 "and right after that block: if(is_long) g_grind_vl_deferred_noted_long = false;". This clears on the ungated path only. But consider the VERY common case with gate = -1: the clear runs EVERY call for every capped side (both sides) → a global write per side per tick. Harmless.

Now, the **`Grind_LatticeTrySide` return-value semantics**: the gated path returns 0, the same as "nothing rolled". Callers: `Grind_LatticeOnTick` ignores the return. Tests assert on it. Fine.

Let me also verify that `Grind_LatticeTrySide`'s new params are trailing and defaulted so that the existing calls compile. Yes.

Hmm, one more: `Grind_LatticeOnTick`'s new trailing param `const int roll_gate = -1` — the existing calls (LB19, C55_OnTick) pass 9 args → defaults for exit_pips_short (0), add_pips_short (0), reroll (false), roll_gate (-1). ✓.

Wait, LB19: `Grind_LatticeOnTick(22260101UL, "OPT", 0.01, false, 5.0, 10.0, 8, false, now);` → enabled = false → returns immediately. ✓.

OK. Now, one more thought on T-1: the gate uses the OTHER side's depth read at the moment of the call. But `Grind_LatticeOnTick` calls `Grind_LatticeTrackExtremes` FIRST, which can... no layer changes. ✓.

Hmm, and: is there a case where `Grind_SideDepth(g_grind_short)` is read but the short's layers are mid-update from a deal processed in `OnTradeTransaction` in the SAME OnTick? MQL5 doesn't interleave. But the ORDER of OnTick vs OnTradeTransaction: the terminal may call OnTick and then process trade transactions, or vice versa. Either way, they're sequential. So within one OnTick the depth is stable. ✓ (ASSUMED: single-threaded event dispatch, which MQL5 documents.)

Now let me also sanity-check the claim in T-1 "where the gate decision for one side changes the other's". The long's gate uses the short's depth; the short's uses the long's. Neither side's roll changes the self depth. So no. ✓.

Alright, now let me also consider: **could the gate cause the exit queue to misbehave?** While gated, no VLs are written and no `Grind_ExitQManageSide` is invoked by the lattice. But `Grind_RetryMissingExits` runs every OnTick in OnTickEngine → `Grind_ExitQManageSide` for both sides → the rank 0 / highest rank are maintained. So the queue is fine. ✓.

Hmm, now the **`Grind_RetryMissingExits` while gated**: it may PLACE an exit for the highest rank. The gate doesn't block that. So while gated, exits are placed/removed as usual. That's fine (the gate only stops rolls).

Hmm, but hold on — this means the "cost" claim (a held side sends nothing) is not exactly right: the held side still sends exit-queue place/remove requests via `Grind_RetryMissingExits` and the normal management. The gate only saves the roll modifies. T-7 should note that: "a held side sends nothing" (the design's GR6-... claim) is an overstatement — the exit queue still manages. Hmm, is that a "premise" issue? The design says "Requests saved and added: a held side sends nothing" in T-7's wording, which I must verdict. The precise truth: the held side sends no ROLL requests, but the exit queue and the entry path still send. So "a held side sends nothing" is FALSE as stated; the correct statement is "a held side sends no roll modifies". Let me verify: while gated, `Grind_LatticeTrySide` returns before touching orders; but `Grind_ExitQManageSide` is called each tick by `Grind_RetryMissingExits` and on fills, and it can place/cancel exits. So requests are still sent. So T-7's accounting must include those (they're pre-existing, not "added" by the gate). I'll say: HOLDS with the correction that the gated side still emits exit-queue traffic; the gate saves only the roll requests. Evidence: the OnTick call order (the lattice then OnTickEngine → Grind_RetryMissingExits → Grind_ExitQManageSide → Grind_PlaceLimit).

Hmm, is `Grind_RetryMissingExits` a no-op when the exits are intact? `Grind_ExitQManageSide`: for ranks not required, cancel if not allowed; for required ranks, place if missing. If intact, no requests. So the steady-state gated side sends nothing in the steady state, but any fill triggers the queue. Fine. I'll phrase it carefully.

Now, let me write the final answer. I need to keep the quotes accurate. Let me collect the exact quotes I'll use (from the attached code):

1. `grind_pure.mqh` `Grind_RollGateHolds`: `return gate >= 0 && opposite_depth > gate;`
2. `grind_engine.mqh` `Grind_LatticeTrySide`: `if(Grind_RollGateHolds(roll_gate, opposite_depth)) {`
3. `...`: `Grind_LatticeRollGateRestartExtreme(is_long);`
4. `...`: `Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);`
5. `...`: `datetime backoff = is_long ? g_grind_vl_backoff_long : g_grind_vl_backoff_short;` and `if(now < backoff)`
6. `...`: `g_grind_vl_deferred_noted_long = false;`
7. `grind_engine.mqh` `Grind_LatticeOnTick`: `Grind_LatticeTrackExtremes(magic, max_layers, now);` and `if(blocked)` `return;` and `Grind_SideDepth(g_grind_short));`
8. `grind_engine.mqh` `Grind_SideDepth`: `return ArraySize(side.layers);`
9. `grind_engine.mqh` `Grind_LatticeRollGateRestartExtreme`: `g_grind_vl_from_msc_long = t + 1;`
10. `grind_engine.mqh` `Grind_LatticeRollDeferredNote`: `if(g_grind_vl_deferred_noted_long)` `return;`; `if(!Grind_LatticeLevelCrossed(is_long, mkt, level))` `return;`; `Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", is_long ? "L" : "S", 0, detail);`
11. `grind_engine.mqh` `Grind_LatticeTrackOneSide`: `g_grind_vl_deferred_noted_long = false;` (below cap)
12. `grind_engine.mqh` `Grind_LatticeResetBackoff`: `g_grind_vl_deferred_noted_long = false;`
13. `fxgrind.mq5` OnInit: `if(!Grind_ValidateRollGateInputs(InpVirtualLattice, InpRollGateOpposite)) {` and `if(!Grind_MagicLockClaim(InpMagic)) {`
14. `fxgrind.mq5` OnTick: `Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice,` ... and `Grind_OnTickEngine(InpMagic,` (the ordering).
15. Tests: `AssertEqInt("RG7c (G)", Adr166_TryShort(ADR166_T0 + 1, false, 0, 0), 1);`
16. `fxgrind_tests_adr162b.mqh` LB7: `g_grind_order_test_modify_calls == 5 && g_grind_order_test_remove_calls == 5` `&& g_grind_order_test_place_calls == 5`
17. The loop bound: `for(int iter = 0; iter < max_layers; iter++) {`
18. `Grind_LatticeNoteClosing` call sites: `Grind_LatticeNoteClosing(is_long, side.layers[idx].position_ticket, now);` (inside the loop).
19. The trailing reset: `if(!closing_stop)` `Grind_LatticeResetClosingState(is_long);`
20. RG8's restart test lines and RG13's.
21. `Grind_LatticeCopyTicks` test path (no upper bound): `if(g_grind_vl_test_tick_msc[i] < from_msc)` `continue;` vs the production `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc,` `(ulong)Grind_MarketTimeMsc());`

Good. Now let me also decide on the T-2 verdict wording: "BREAKS"? The prompt's verdict options: HOLDS / BREAKS / NEEDS-FIX. The P4 mitigation has a hole in two paths (backoff, blocked, and EA restart). I'd say NEEDS-FIX for the backoff/blocked hoist, and note the restart hole as a separate NEEDS-FIX (or document). Since it's not fatal and has a small fix, NEEDS-FIX.

Hmm, let me reconsider whether the restart hole (EA restart while gated) warrants a fix or a note. The deployment: nine instances, IC demo, and the plan involves restarts (builds, terminal restarts). The gate holds a lot (N=0 → 97% of the time). So an EA restart while gated is LIKELY (any recompile/restart during a hold). And on the first lattice call after the restart, if the gate is open (the opposite side is flat at that moment — plausible since the opposite is often 1 layer that scalps), the capped side rolls using the 24h/since-newest-layer extreme → exactly the P4 defect (the rolled exit clamps passive and fills on the next uptick). Hmm, and even worse: the extreme since the newest layer's open could be a deep dip from hours ago → the roll target is a level the market touched long ago → `Grind_LatticeRollLayer` writes VL = level, and the exit clamps passive at the market → a near-certain immediate fill on the wrong side. That's a real risk. I'd elevate it: NEEDS-FIX with a small fix in OnInit (restart both sides' extremes when the gate is configured) — or better, the fix should also cover... hmm, OnInit runs before the reconstruction (the layers are built in `Grind_ReconstructState`). The restart just sets the globals; the tracking flag = true with from_msc = now+1 and extreme = 0, so the subsequent TrackOneSide skips the init and folds from now+1 → no 24h catch-up. So calling `Grind_LatticeRollGateRestartExtreme(true); ...(false);` in OnInit after the reconstruction when `InpRollGateOpposite >= 0` would do it. One line each. OK.

Hmm, but careful: is `Grind_LatticeRollGateRestartExtreme`'s global side effect acceptable at OnInit? It sets tracking = true. If the side is below cap, the next TrackOneSide resets it. Fine. If at cap, it skips the init (which is exactly the intent). Good.

But hmm, does this break the VC-related expectations for gated fleets? Only when the gate is enabled (N >= 0). For N = -1 (the other eight fleets), no change. ✓.

Hmm, but is the restart-at-OnInit too aggressive for the N=0 experiment? It means: after every EA restart, the catch-up is discarded for capped sides → the first roll requires the live market to be through the level. That's consistent with the gate's semantics. ✓.

I'll present both fixes (backoff hoist; OnInit restart) under T-2, marking the family NEEDS-FIX, and note that neither touches the -1 path (so the merge with -1 is safe).

Now let me also double check: does the design/doc mention the restart at OnInit? No. So it's a gap.

One more thing to check for the "blocked" path: `Grind_LatticeOnTick` returns when blocked → when the block lifts, the first call tracks (folding from from_msc = the last restart's t+1) and then TrySide: if the gate holds → restart (discard) → fine; if the gate is open → the loop with the extreme from [last restart, now] — which spans the blocked period! Because while blocked, TrackExtremes was NOT running (OnTick returns before it? No: `Grind_LatticeTrackExtremes(magic, max_layers, now); if(blocked) return;` — the tracking DOES run while blocked). So the extreme folds during the block. Then at the unblock with the gate open: the extreme covers the block period... but only since the last restart or since tracking started. If the last restart was at the last gated call before the block, the extreme covers [that call, now] = the block period. So the dip during the block → replayed at the unblock. Hmm, so the blocked path is a hole too: during the block, the extreme is folded but never restarted (because TrySide isn't called). So the fix for the blocked path: the gate restart should happen even when blocked — e.g., in `Grind_LatticeOnTick`, if the gate holds for a side, restart it before returning on blocked. Hmm, that requires reading the side depths in OnTick. The cleanest single fix: hoist the gate restart into `Grind_LatticeOnTick` before the blocked return, and in `TrySide` for the backoff. Or: make `Grind_LatticeTrackOneSide` not fold while the gate holds... that's a bigger change.

Alternative minimal fix that covers ALL paths: in `Grind_LatticeTrackExtremes` (or TrackOneSide), when the gate is active and the side's gate holds, reset the extreme. But TrackOneSide doesn't know the gate. Hmm.

I'll present the smallest fix as: in `Grind_LatticeTrySide`, do the gate-held restart BEFORE the backoff check (move 3 lines up); and in `Grind_LatticeOnTick`, before `if(blocked) return;`, restart the extremes for any side whose gate holds (needs the new arg + the depths — a 2-4 line change). Hmm, that's not a one-liner. Alternatively: pass the gate into `TrackExtremes`/`TrackOneSide` so that a gated side's extreme is always reset at the top of the tick. That's the cleanest conceptual fix: "while a side is gated, don't accumulate the extreme" — do it in the tracking function, which runs on every path where the lattice is enabled. That's ~4 lines (compute `Grind_RollGateHolds(roll_gate, opp)` per side in OnTick and skip/zero the extreme). I'll propose that as the smallest robust fix, and mention the minimal-if-you-only-care-about-backoff variant.

Hmm, I should be careful: the prompt says "If you assume a value, say ASSUMED and why" and "give the smallest fix". I'll give a concrete smallest fix per hole.

Let me now think about how to phrase T-2's verdict: BREAKS? The threat asks: "Can any of them replay a dip from the held period, or leave the extreme stuck so that a real crossing after release is MISSED for longer than one tick?" — The answer: YES, the backoff/blocked/EA-restart paths can replay a dip from the held period. So T-2 BREAKS (in those paths). I'll say BREAKS (narrow but real), with fixes. Hmm, "BREAKS" might be too strong if the paths are rare... but the threat explicitly asks whether any of those cases can replay a dip. The answer is yes. So BREAKS (with the smallest fix). But the prompt also says "Do not call anything fatal that has a fix". BREAKS ≠ fatal. I'll use "BREAKS (narrow; fix = ...)".

Hmm, let me reconsider the EA-restart case once more to be sure it's real. On an EA restart:
- OnInit → `Grind_ReconstructState()` → builds `g_grind_long.layers` from the broker positions (8 layers at cap).
- The VL globals: are they persisted? `Grind_VLSet` writes a global variable `GRIND_VL_<ticket>` (persistent across restarts via the terminal's GV store). So the rolled state survives. ✓.
- The deferred latch globals: NOT persisted (they're plain globals, re-initialised to false). So after a restart, the marker can fire again — fine.
- `g_grind_vl_tracking_long` = false, `g_grind_vl_from_msc_long` = 0 → the first TrackOneSide: depth 8 = cap → the init block → the newest layer's open time → from_msc = max(newest+1, now-24h) → the extreme = the min ask over [from_msc, now]. So the extreme includes the deferral period (since the newest layer's open, up to 24h).
- The first TrySide: if the gate holds → the restart (discard) → SAFE. If the gate does NOT hold → the loop with the stale extreme → the roll replays the dip → the P4 defect.
So the hole is real. The probability: the opposite side must be <= N (=0 → empty) at the first lattice call after the restart. With N=0, that's when the opposite side is flat. Over a long hold, the opposite side is flat for a decent fraction of the time (between scalps). And the recap happens at the first call, so P(opposite flat at the restart moment) is maybe ~30-50%. So this is NOT rare. I'd say this is the most material finding. NEEDS-FIX before enabling N=0 live.

Hmm, and note: even without a restart... wait, are there other "first call" situations? If the sides drop below cap and re-cap, `TrackOneSide` resets the tracking below cap; then at re-cap, the init uses the newest layer's open time (a recent fill) → from_msc ≈ now → a small catch-up. So no long replay. The restart is the main way to get a long catch-up while gated. Also: if the side's tracking is reset below cap while the gate still holds (e.g., the side drops to 7 and re-adds to 8 within the same trend), the catch-up is short. Fine.

Hmm, another path to a long catch-up while gated: the `Grind_CarryPositionOpenTime` failure → the init `return`s (tracking stays false) → the next call retries. Not a replay.

OK. So T-2 BREAKS with two concrete paths (backoff/blocked overlap, and EA restart). Both fixable.

Now, let me reconsider T-2's "leaves the extreme stuck so that a real crossing after release is MISSED": with `n < 0` the fold is skipped, but the extreme = 0 → TrySide uses mkt → not missed. With a persistent `n < 0` (e.g., CopyTicksRange unsupported on the symbol/broker?), the extreme stays 0 forever and every roll uses mkt, losing the between-call dip catch (VC3's whole point). Hmm — is `CopyTicksRange` returning -1 persistently plausible? The doc: CopyTicksRange returns -1 if "the symbol is not selected" or the copy fails. The existing VC9 test covers a transient failure. If the gate's restart is active every tick, then after release... the restart only happens while gated. At release, the fold runs with the normal from_msc. So a persistent failure is pre-existing. Not new. I'll mention that the new restart makes the extreme more sensitive to CopyTicksRange failures ONLY while gated (extreme = 0), which is benign.

Now let me write the T-5 detail about the restart: "reconstruction / ADR-163 rebuild after a restart while gated" → the answer above.

Now, let me write everything. I'll structure:

GIVENS CHECK
T-1 ... T-8
PREMISE VERDICT
TEST GAPS

Let me keep each verdict crisp: verdict line, evidence with quotes, fix.

Let me also make sure to answer T-8's specific question about RG7c with a confirmation and the reason (quote the two lines: `Grind_LatticeRerollIndex`... no, the reason is in TrySide's level computation: quote `const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));` and note that after the stub rolls 7101, the anchor moves to the VL 1.19400 and the next level is 1.19500, unreachable at bid 1.19400). Actually the confirmation reason: at commit 1, RG7's first call rolls 7101 (the stubs ignore the gate), so the second call finds the next level (1.19300+VL anchor) = 1.19500, and the bid 1.19400 does not cross it → rc = 0 ≠ 1. Quote the RG7 lines:
```
   AssertEqInt("RG7a (F)", Adr166_TryShort(ADR166_T0, false, 0, 1), 0);
   AssertFalse("RG7b (F)", Grind_VLHas(7101UL));
   AssertEqInt("RG7c (G)", Adr166_TryShort(ADR166_T0 + 1, false, 0, 0), 1);
```
CONFIRMED. And the fix: relabel RG7c as (F) — no code change. Note the suite totals: 32 failing at commit 1 (not 31), i.e. 2548/2580, which matches the operator's run.

Hmm, one thing: does the prompt say the operator's commit-1 run showed 2548/2580 with exactly 32 failing (31 tagged F + RG7c)? Yes. So the label slip is only in the doc/section-5 totals ("31 F, 24 G" → actually 32/23). I'll note the count correction: 55 assertions = 32 F + 23 G.

Let me double check the G count: 55 - 32 = 23. Yes (24 G in the design's accounting includes RG7c as G).

Now let me make sure about the "one line" quoting rule: "cite file, function and QUOTE the line (one line, or part of one)". I'll do that.

Let me also include a note in T-8 about the tests that can't distinguish (RG14d, RG3e) and the "reset does not clear the new latch" question: `Adr162b_Reset` → `Grind_LatticeResetBackoff` DOES clear it (C5) — quote `g_grind_vl_deferred_noted_long = false;` in ResetBackoff. And the market-time seam: RG8/RG13 clear it; A9 says `Adr162b_Reset` does NOT — so the discipline relies on each test. Note that `Adr162b_Reset` is missing `Grind_MarketTestReset()` so a test that seeds the time and fails to clear it leaks; RG8/RG13 clear explicitly (they are the only two that seed).

Wait, I should double check that: is the leak actually harmless for the tests AFTER RG8? RG8 clears the seam. RG13 seeds and clears. So nothing leaks out of ADR166... unless RG8's `Grind_MarketTestReset()` is placed such that... it's at the end. Fine. But what if an assertion aborts the test early? In these suites `Assert*` typically just records. OK.

Hmm, but hold on: RG8 is tagged F and at commit 1 the assertions fail — but the code continues to `Grind_MarketTestReset()`. ✓.

One more possible test gap: `Adr166_OnTick` passes `5.0, 10.0` for both exit/add (long and short) — fine.

Now let me write the answer. I'll aim for a thorough but readable audit. Length is fine.

Let me draft the final text.

---

Also, I should double check the T-4 quote for the burst: the design's GR6-1 says "up to ~24 at once on one side". And LB7 shows 3 requests per roll. I'll quote the LB7 assertion.

And for T-7, the "nine instances": quote... nothing in the code. I'll reference the deployment line from the prompt? The prompt says nine instances per terminal. There's no code quote for that; the prompt says a claim without a quote is discarded — but that's for claims about the code. For counting I'll quote the code that sends (Grind_PlaceLimit / Grind_ModifyPendingPrice / Grind_CancelPendingOrder) and the LB7 counts.

Let me write it.

One more consideration on T-6: "Values above max_layers, negative below -1, the gate on with re-roll off. Anything that should FATAL and does not, or FATALs and should not?" — Answer: gate = 8..INT_MAX is accepted and is a silent no-op (the gate can never hold since depth <= max_layers... unless `ArraySize(layers) > max_layers` can happen — e.g., a reconstruction with more positions than max_layers: `Grind_RebuildBookFromTickets` is given `max_layers` = 12 in LB30, hmm, and `Grind_AppendLayer` is bounded by `Grind_CanPlaceEntryLayer(n, max_layers)` in the entry path. So the depth should be <= max_layers; if it ever exceeded, then N = 8 with depth 9 would hold and gate forever. Edge. I'll note: if the reconstructed depth ever exceeds `max_layers` (a restart with extra manual positions), a gate N >= max_layers is no longer a guaranteed no-op. Minor.

Also, "the gate on with re-roll off" → allowed; the gate then blocks FIRST rolls too (the primary effect). RG11 pins that the gated side doesn't strand. Should it FATAL? No: the operator may want the gate with reroll off (the first-roll-only gate). Fine.

Now write. I'll be careful to keep the file/function attributions right:

- `ea/grind_pure.mqh` `Grind_RollGateHolds`, `Grind_ValidateRollGateInputs`.
- `ea/grind_engine.mqh` `Grind_LatticeTrySide`, `Grind_LatticeOnTick`, `Grind_LatticeRollGateRestartExtreme`, `Grind_LatticeRollDeferredNote`, `Grind_LatticeTrackOneSide`, `Grind_LatticeResetBackoff`, `Grind_LatticeFoldExtreme`, `Grind_LatticeCopyTicks`, `Grind_LatticeTrackExtremes`, `Grind_LatticeNoteClosing`, `Grind_LatticeRollLayer`, `Grind_LatticeMaybeStranded`, `Grind_SideDepth`.
- `ea/fxgrind.mq5` `OnInit`, `OnTick`.
- `ea/fxgrind_tests_adr166.mqh` the RG tests.
- `ea/fxgrind_tests_adr162b.mqh` `Test_LB7_GapFiresEveryLevel`, `Adr162b_Reset`.

Let me write the final answer now.

I also want to double-check one claim I might make: "the long's TrySide cannot change the short's depth" — `Grind_LatticeRollLayer` → `Grind_ExitQManageSide(side, ...)` where side is the LONG's state → only the long's layers are touched. And `Grind_ExitQHoldCancelLayer` touches only that side's layers. ✓.

Also `Grind_LatticeRollLayer` → `Grind_ModifyPendingPrice` → `Grind_SelectOurOrder` → no state change to the other side. ✓.

OK, and one last look for a bug in the `Grind_LatticeRollDeferredNote` guard order: it returns early if the latch is set — BEFORE checking the depth/cross. So if the latch is stale-true (e.g., the side dropped below cap and re-capped without the below-cap clear ever running? The below-cap clear runs in TrackOneSide which is called every lattice tick for both sides — but ONLY if `Grind_LatticeOnTick` is reached, i.e., `enabled`. If the lattice is disabled... then TrySide isn't called either. Fine.)

Hmm, one more: the below-cap clear is in `Grind_LatticeTrackOneSide`, which is called with `side` = the LIVE global. ✓.

Alright. Also the T-3 question "or never re-arms after a real release?" — Answer: it re-arms (RG9 pins it), provided the ungated call reaches the clear; the only paths where the clear is skipped are disabled/blocked/backoff (and below cap, which clears it elsewhere). Since those paths also can't roll, no re-arm miss. HOLDS.

Now writing. For length, I'll be dense but complete. Let me produce the final output.

One more: for T-8, "Which behaviour has no test that fails without it?" Let me be precise per change:
- C6's restart on the blocked path / backoff path: no test.
- C6's restart for the SHORT side: no test.
- C5's below-cap clear: no test fails without it.
- C5's ResetBackoff clear: no test fails without it directly; it is only indirectly required by RG9a if the suite order leaves the long's latch true from RG6b (and RG8's direct gated call doesn't clear it). Hmm, let me re-verify this chain because I want to state it correctly. Without the C5 clear in ResetBackoff: after RG6b (gated call → the note fires → latch_long = true), the tests RG7 (short only; `Adr162b_SeedShort8` → `Adr162b_Reset` → without the clear, latch_long stays true), RG8 (the long's direct gated call → RestartExtreme; the note returns due to the latch → doesn't fire; no assertion on it), RG9 call 1 (the long, gated → the note returns → no marker → RG9a FAILS). So YES, RG9a would fail without the C5 ResetBackoff clear. Good, so it IS pinned (indirectly). I'll say that.
- C10's Print/LATTICE_CONFIG: no test.
- C10's FATAL wiring: no test (RG1 tests the predicate only).
- The telemetry-absence: no test.
- C9's pass-through: RG12.
- C8's clear: RG9.
- C8's gate-in-front-of-the-loop: RG3-RG7.

Good. Also, the fact that with the gate = -1 the behaviour is unchanged is pinned only implicitly by the existing 2525 tests passing (which is a strong guard). I'll note that.

Writing now.

Actually, hold on. Let me reconsider one potential REAL bug in the gate: **the gate blocks a side from rolling, but does it also block the side from ADDING layers?** No — the add path is separate (`Grind_EnsureAddNext`), and the gate only affects the lattice. At cap, no adds anyway. But if the side is at cap and the gate holds, and the side drops below cap (a layer exits), then `TrySide` isn't called (depth < max_layers) → the lattice stops rolling → and the add path re-adds to cap. OK. ✓.

And: **at cap with the gate holding, could the side's exit queue strand the side (no exits resting)?** The queue maintains rank 0 + highest. Fine.

OK, writing.

Let me also mention in T-4 the "count them per side and per instance" precisely: per release call per side: <= max_layers * 3 = 24 (modify+remove+place) plus the queue's own remove/place from `Grind_ExitQManageSide` inside each roll. Hmm, the 3 per roll INCLUDES the queue's remove/place (per LB7: 5 rolls → 5/5/5). So 24 per side per call. Nine instances → 216 per terminal tick worst case. And the order of magnitude per day: bounded by the number of release events.

Also the modify calls: at release, each first roll = 1 modify. So ~8 modifies per side burst.

OK, final answer time.

Also for T-1, I should explicitly address "a layer array mid-update": `ArrayResize(side.layers, ...)` happens in `Grind_AppendLayer`/`Grind_RemoveLayerAt`, called from `Grind_HandleSideDealFill` (OnTradeTransaction) — sequential with OnTick. Quote: `ArrayResize(side.layers, n + 1);` in `Grind_AppendLayer` — and note no interleaving. ✓.

Now write.

## Final Report

## GIVENS CHECK

**G1 — VERIFIED (with one caveat).** `ea/grind_pure.mqh`, `Grind_RollGateHolds`: `return gate >= 0 && opposite_depth > gate;` — with `gate = -1` this is false for every `x`, so the gate block is never entered. The only new statement then executed in `Grind_LatticeTrySide` is the latch clear: `g_grind_vl_deferred_noted_long = false;` (and `..._short`). Caveat: the C5 clears in `Grind_LatticeTrackOneSide` (`g_grind_vl_deferred_noted_long = false;` in the below-cap block) and in `Grind_LatticeResetBackoff` also execute on the -1 path, but they are no-ops because the latch is written in exactly one place, `Grind_LatticeRollDeferredNote`, reachable only from inside the gate block. Behaviour is unchanged.

**G2 — VERIFIED.** `ea/fxgrind.mq5`, `OnInit`: `if(!Grind_ValidateRollGateInputs(InpVirtualLattice, InpRollGateOpposite)) {` / `return INIT_FAILED;` appear before `if(!Grind_MagicLockClaim(InpMagic)) {`.

**G3 — VERIFIED.** `ea/grind_engine.mqh`, `Grind_LatticeTrySide`: the block `if(Grind_RollGateHolds(roll_gate, opposite_depth)) {` ends in `return 0;` *before* `if(Grind_LatticeCandidateIndex(side, is_long) >= 0) {` and the loop. `Grind_LatticeRollGateRestartExtreme` writes only `g_grind_vl_tracking_* / _extreme_* / _from_msc_*` (`g_grind_vl_from_msc_long = t + 1;`) and `Grind_LatticeRollDeferredNote` writes only the latch plus an archive marker; no `Grind_ModifyPendingPrice`, `Grind_PlaceLimit`, `Grind_CancelPendingOrder`, `Grind_VLSet`, `Grind_LatticeMaybeStranded`, `g_grind_vl_backoff_*` or `g_grind_vl_fail_count_*` write on that path.

**G4 — VERIFIED.** `Grind_LatticeOnTick` passes `Grind_SideDepth(g_grind_short));` to the long call and `Grind_SideDepth(g_grind_long));` to the short, and `Grind_SideDepth`: `return ArraySize(side.layers);`. Resting entries live in `l0_pending_ticket` / `add_pending_ticket`, not in `layers`.

**G5 — VERIFIED.** `Grind_LatticeRollGateRestartExtreme` — the long branch writes `g_grind_vl_tracking_long = true;`, `g_grind_vl_extreme_long = 0.0;`, `g_grind_vl_from_msc_long = t + 1;`, nothing else; the short branch is the mirror.

**G6 — VERIFIED.** `Grind_LatticeRollDeferredNote` begins `if(g_grind_vl_deferred_noted_long)` / `return;`, and ends `Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", is_long ? "L" : "S", 0, detail);` plus `Print(...)`. No `Grind_TelemetryEmit` anywhere in the function. Once-per-episode is the latch itself.

---

## T-1 Gate decision — **HOLDS**

Ordering (`ea/grind_engine.mqh`, `Grind_LatticeOnTick`): long first, then short, each with the other's depth read at the moment of the call: `Grind_SideDepth(g_grind_short));` / `Grind_SideDepth(g_grind_long));`.

- Depth cannot be stale between the two calls: MQL5 dispatches `OnTick`, `OnTradeTransaction`, `OnTimer` sequentially on the EA's single thread (**ASSUMED**, documented MQL5 model), and the long call cannot touch the short's array — its only mutations are `side.layers[idx].exit_target = price;` (own side) and `Grind_ExitQManageSide(side, …)` (own side). Layer array resizes happen only in `Grind_AppendLayer` (`ArrayResize(side.layers, n + 1);`) and `Grind_RemoveLayerAt`, both reached from `Grind_HandleSideDealFill` in the transaction callback.
- One side's decision cannot change the other's: `Grind_RollGateHolds` reads only `(roll_gate, opposite_depth)`; no roll changes the count of filled layers.
- `blocked` / backoff ordering lets nothing act: `if(!enabled || blocked)` `return 0;` and `datetime backoff = …;` `if(now < backoff)` `return 0;` both precede the gate and both return 0. A gated side always returns 0. (The side effect of that ordering — the restart being skipped — is T-2.)

## T-2 The extreme restart — **BREAKS (narrow, real; fixable in ≤4 lines)**

The restart is placed **after** the backoff return and is reached only from `TrySide`:

```
   datetime backoff = is_long ? g_grind_vl_backoff_long : g_grind_vl_backoff_short;
   if(now < backoff)
      return 0;
```
```
   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {
      Grind_LatticeRollGateRestartExtreme(is_long);
```

whereas the extreme keeps folding on every lattice tick regardless of backoff/blocked, because tracking runs first and unconditionally: `Grind_LatticeTrackExtremes(magic, max_layers, now);` / `if(blocked)` `return;`. Three replay paths therefore survive:

1. **Backoff inside a hold.** A roll modify failed *before* the gate engaged (backoff up to `GRIND_VL_RETRY_BACKOFF_MAX_SEC` 1800 s). While `now < backoff`, `TrySide` returns before the gate, so the extreme folds the deferral; at the first call where the backoff has expired *and* the gate has opened (the counter layer scalped out exactly then) the loop probes `min(mkt, extreme)` with a dip from the held period and rolls to it — exactly P4.
2. **`blocked` inside a hold.** `Grind_LatticeOnTick` tracks (`Grind_LatticeTrackExtremes`) then `if(blocked)` `return;` — never reaching the restart. When the quarantine/halt lifts with the gate already open (empty opposite side), the first roll uses the whole blocked-period extreme.
3. **EA restart while gated.** `g_grind_vl_tracking_* = false` / `from_msc = 0` after init, so the first `Grind_LatticeTrackOneSide` re-initialises with the 24 h catch-up (`MathMax((long)(newest + 1) * 1000, (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000)`). If the gate is **already open** at that first call (the opposite side is flat — common at N = 0, since the counter side sits at 0/1 layer), the restart never runs and the roll replays the held-period dip. RG8/RG13 seed the seam inside one process; no test covers a restart.

Dead market / `CopyTicksRange` −1 or 0 / release-on-the-same-tick are **safe**: with `n < 0` the function `return`s with `extreme = 0`, and the loop handles zero with `const double probe = extreme > 0.0 ? (…) : mkt;`, so no crossing is missed for more than the one tick; with `n == 0` `Grind_LatticeFoldExtreme` folds the live price (`const double live = is_long ? Grind_MarketAsk() : Grind_MarketBid();`). `from_msc = t + 1` is the right seam; a tick at time `t` is never double-counted.

**Smallest fix:** make the gated side's extreme not accumulate while the gate holds, whatever the early return. In `Grind_LatticeOnTick`, before `if(blocked)` `return;`, and in `TrySide` before the backoff return, do the restart when `Grind_RollGateHolds(roll_gate, Grind_SideDepth(other))`; or equivalently hoist the 3-line gate block above the backoff check and call the two restarts in `OnTick` when `blocked`. Additionally, for the restart-while-gated case, call `Grind_LatticeRollGateRestartExtreme(true/false)` once in `OnInit` when `InpRollGateOpposite >= 0` (after `Grind_ReconstructState()`), so a post-restart capped side cannot fold the 24 h catch-up. None of these touches the `-1` path.

## T-3 The deferred latch — **HOLDS**

Guard first, set last (`Grind_LatticeRollDeferredNote`): `if(g_grind_vl_deferred_noted_long)` / `return;` … `g_grind_vl_deferred_noted_long = true;`, so it cannot spam while gated; the only clearing sites are the ungated `TrySide` line, the below-cap block in `Grind_LatticeTrackOneSide`, and `Grind_LatticeResetBackoff` (test-only, no production caller). The ungated clear runs before the loop, so a real release always re-arms; RG9 pins exactly that (call 3 ungated rolls, call 4 re-fires). Paths where the clear is skipped (`disabled`, `blocked`, backoff) also cannot roll, so no re-arm is lost.

Two designed limitations worth recording: the note requires the **live** market to cross (`if(!Grind_LatticeLevelCrossed(is_long, mkt, level))` `return;`), so a deferral of an *extreme-driven* roll emits nothing and `ROLL_DEFERRED` under-counts suppressed rolls; and the latch is an in-memory global, so an EA restart re-arms the marker for a still-running episode (archive noise, not incorrect).

## T-4 Release — **HOLDS (accepted by GR6-1); the burst is bounded and countable**

Loop bound: `for(int iter = 0; iter < max_layers; iter++) {` with first rolls unthrottled and re-rolls gated by `if(reroll && rerolls >= 1)` / `break;`. Per first roll the request count is 3 (modify + one queue remove + one queue place), pinned by `Test_LB7_GapFiresEveryLevel`: `g_grind_order_test_modify_calls == 5 && g_grind_order_test_remove_calls == 5` `&& g_grind_order_test_place_calls == 5`. Worst burst per side per release call = 8 × 3 = 24; nine instances = 216 requests in the worst single tick, one order of magnitude below the daily counter. The pause only gates re-rolls (`if(!reroll || Grind_LatticeRerollPaused(now))`), so a post-pause release still fires first rolls — unchanged from ADR-162.

"Roll placed while the counter L0 is about to fill": the roll precedes the L0 replacement in the same tick, so P3 is confirmed by construction — in `ea/fxgrind.mq5`, `OnTick` calls `Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice,` … before `Grind_OnTickEngine(InpMagic,` (which is where `Grind_TryPlaceL0` sits). The immediate-fill clamp of the released exit is C55/VC3 behaviour, ruled.

## T-5 Interactions — **HOLDS, with two accepted observability losses and one residual**

- Carry pass / I6: the gate writes no VL (G3), so I6's "price from the VL" cannot desync; the carry pass is *not* gated and keeps shifting exits during the hold, and the release roll overwrites that shift through the normal path (`Grind_CarryShiftDelete(pos);` / `Grind_CarryRecordShift(...)`).
- `ROLL_CLOSING_STUCK`: `Grind_LatticeNoteClosing` is reached only from inside the loop (`Grind_LatticeNoteClosing(is_long, side.layers[idx].position_ticket, now);`), and the trailing reset `if(!closing_stop)` `Grind_LatticeResetClosingState(is_long);` is also skipped while gated — so during a long hold a closing layer is neither warned nor reset. It is not silently lost: the first ungated call either detects it (loop check `if(side.layers[idx].exit_position_ticket != 0)`) or resets the latch. Observability only.
- `ROLL_STRANDED`: dead by design while gated (GR6-4); the side can be genuinely 2+ steps past its level for hours with nothing amber. Ruled, but it means the only live signal is `ROLL_DEFERRED`, which (T-3) under-reports.
- ADR-155 eject and the breaker/quarantine run outside the gate; when `blocked`, the lattice is skipped entirely, so the gate is inert (and see T-2 case 2).
- Frozen state while gated: the fail count and backoff are deliberately untouched (RG14: `g_grind_vl_fail_count_long == 2`). Consequence: the first failure after a long hold doubles from a stale count, i.e. up to a 1800 s backoff. Harmless.
- Reconstruction after a restart while gated: the latch/`from_msc` globals are not persisted; the VLs are GVs and survive. See T-2 case 3.

## T-6 Inputs and presets — **HOLDS**

`Grind_ValidateRollGateInputs`: `return gate == -1 || (gate >= 0 && lattice);` — `-2` FATALs (RG1e), `0` with lattice off FATALs (RG1d), gate on with re-roll off is allowed and is exactly what RG11 covers (gated side no longer strands), gate ≥ 0 with lattice is allowed. Above `max_layers` is accepted and is a silent no-op **unless** a rebuilt book ever exceeds `max_layers` (then N = 8 would gate permanently) — a theoretical edge only, since entries go through `Grind_CanPlaceEntryLayer(n, max_layers)`. Missing key in a .set → compiled default `-1`: **ASSUMED** (MT5 keeps the input value for a key absent from the .set), which is why the new `GRIND_ROLL_GATE opposite_max=` line must be read on each fleet before the run. The `LATTICE_CONFIG` detail is a schema change: `"{\"enable\":%s,\"reroll\":%s,\"roll_gate\":%d}"` — the log checker of A14 reads `GRIND_REROLL enable=` by pattern and is unaffected, but any strict consumer of `LATTICE_CONFIG` must tolerate the new key.

## T-7 Cost — **HOLDS (with a wording correction)**

The gated side sends no *roll* requests (`Grind_LatticeTrySide` returns before the loop), but it is not request-free: `Grind_OnTickEngine` → `Grind_RetryMissingExits` → `Grind_ExitQManageSide` still cancels/places exits (`Grind_PlaceLimit(otype, price, lots, magic, comment);`) on every fill and on rank changes. Saved: the roll modifies/removes/places. Added: up to 24 per side per release, plus the re-rolls (one per side per call) and the ordinary add/exit traffic. Nine instances × one trending day stays far below the counter stop. The real new cost is CPU, not requests: `CopyTicksRange` for two sides on every tick of every instance.

## T-8 Tests — **RG7c CONFIRMED as a mis-tag; several untested behaviours**

**RG7c.** Confirmed. At the stubs `Grind_RollGateHolds` returns false, so `AssertEqInt("RG7a (F)", Adr166_TryShort(ADR166_T0, false, 0, 1), 0);` actually rolls 7101. The second call then computes its level from the *rolled* anchor (the loop uses `const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));`), i.e. 1.19300 + 0.00100 on top of VL 1.19400 = 1.19500, which the bid 1.19400 does not cross, so `AssertEqInt("RG7c (G)", Adr166_TryShort(ADR166_T0 + 1, false, 0, 0), 1);` returns 0 and fails. RG7c is an F; the header totals are 32 F / 23 G, not 31/24 — consistent with the operator's 2548/2580. Fix: relabel the assertion `(F)`; no code change.

Vacuous/weak assertions: `RG14d` (`ARCHIVE ROLL_CLOSING_STUCK #0 == ""`) cannot fail on either commit — neither `Grind_LatticeNoteClosing` call site is reached (commit 1 the roll succeeds, commit 2 the side is gated); the load-bearing assertions are RG14a/b/c. RG3e is likewise a pure regression guard. `RG9b` passes at commit 1 only because no marker exists at all; it is meaningful only next to RG9a. The "reset does not clear the new latch" question is answered: `Adr162b_Reset()` → `Grind_LatticeResetBackoff()` does clear it (`g_grind_vl_deferred_noted_long = false;`), and that C5 line is genuinely load-bearing for the suite (without it, the long latch set in RG6b survives into RG9's first gated call and RG9a fails). The market-time seam is not cleared by `Adr162b_Reset` (A9) — RG8 and RG13 are the only seeders and each ends with `Grind_MarketTestReset();`.

Behaviour with **no** failing test: the restart on the backoff/blocked paths and after an EA restart (T-2); the short-side restart (RG8 is long-only); `ROLL_DEFERRED` having no telemetry emit (G6 — needs a telemetry counter assertion); the `OnInit` FATAL wiring and its position before `Grind_MagicLockClaim` (G2 — RG1 tests only the predicate); the new `GRIND_ROLL_GATE` line and the `roll_gate` field of `LATTICE_CONFIG`; the below-cap latch clear.

Harness fidelity gap: the test double has **no upper bound** — `if(g_grind_vl_test_tick_msc[i] < from_msc)` `continue;` — while production is bounded by `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc,` `(ulong)Grind_MarketTimeMsc());`, so RG13's "no replay" proof rests on the lower bound alone and a future-tick bug is invisible.

---

## PREMISE VERDICT

**Safe to merge to `main` with `InpRollGateOpposite = -1`: yes.** Every -1 path is provably unchanged (G1; the gate block, the restart and the note are unreachable, the two latch clears are no-ops), the new parameters are trailing with defaults so all existing call sites compile unchanged, and the 2525 pre-existing assertions are the guard. The only -1-path artifacts are the new log line and the extra `LATTICE_CONFIG` key.

**Setting N = 0 on one IC fleet: not yet — fix T-2 first.** The gate mechanism itself is sound (T-1, T-3, T-4, T-6, T-7 hold), but the P4 mitigation — the entire reason the extreme is restarted — silently fails whenever the gated side is in backoff, is blocked, or has been restarted, and in those cases the release roll replays a held-period dip to a level the market touched long ago and clamps its exit passive at the market (C55/VC3). With N = 0 the gate holds ~97 % of the time (P2), so these windows are a material fraction of the experiment, not an edge case. Apply the ≤4-line fix from T-2 (restart the gated side's extreme on every lattice tick where the gate holds, independent of backoff/blocked, plus one restart per side after reconstruction when the gate is configured) and relabel RG7c; then the fleet comparison remains a clean test of P1 rather than a test contaminated by replayed dips.

## TEST GAPS

1. RG7c's tag (F, not G) — cosmetic, but the s5/s10 totals must be corrected to 32 F / 23 G.
2. No test where a gated side is in backoff (or blocked) and the gate opens at the first post-backoff draw — the T-2 replay. A test would be: seed LB6 + `g_grind_vl_fail_count_long = 1`, set `g_grind_vl_backoff_long = ADR166_T0 + 30`, add a 09:30 dip into the test ticks, call gated (opp 1) at T0, then ungated (opp 0) at T0+31, and assert no roll off the dip.
3. No test of the EA-restart-while-gated path (globals re-initialised, 24 h catch-up, gate open on the first call).
4. No short-side mirror of RG8 (the restart for `_short`).
5. No test that `OnInit` FATALs on a bad gate value, or that the check precedes `Grind_MagicLockClaim` (G2).
6. No test that `ROLL_DEFERRED` emits no telemetry (G6) — only the archive is checked.
7. No test of the `GRIND_ROLL_GATE opposite_max=` print or of the `"roll_gate"` field in `LATTICE_CONFIG`.
8. No test of the below-cap latch clear in `Grind_LatticeTrackOneSide`; the `Grind_LatticeResetBackoff` clear is pinned only indirectly (RG9a, via suite order).
9. No test of the gated path when `CopyTicksRange` fails (VC9 covers only the ungated path), and the test double lacks the production upper bound.
10. No test that the gated path leaves the exit queue untouched (the gate blocks rolls only, but `Grind_RetryMissingExits` still runs) — a natural RG14 extension.

<!-- finish_reason=stop -->
