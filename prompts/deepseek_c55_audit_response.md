# DeepSeek R1 Audit Report

## Internal Reasoning

Let me carefully analyze this. I need to audit the B2 branch for lookahead bias, silent failures, schema mismatches, statistical flaws.

Let me go through the givens first.

**G1.** `Grind_LatticeTickExtreme` ignores ticks before `from_msc` and non-positive asks (long) / bids (short), and returns the min ask / max bid.

Looking at the code in grind_pure.mqh:
```cpp
bool Grind_LatticeTickExtreme(const long &msc[], const double &bid[],
                              const double &ask[], const int n,
                              const long from_msc, const bool is_long,
                              double &extreme_out)
{
   bool found = false;
   for(int i = 0; i < n; i++) {
      if(msc[i] < from_msc)
         continue;
      if(is_long) {
         if(ask[i] <= 0.0)
            continue;
         if(!found || ask[i] < extreme_out) {
            extreme_out = ask[i];
            found = true;
         }
      } else {
         if(bid[i] <= 0.0)
            continue;
         if(!found || bid[i] > extreme_out) {
            extreme_out = bid[i];
            found = true;
         }
      }
   }
   return found;
}
```
Yes, this matches G1. VERIFIED.

**G2.** Live code never reads the test seam: `Grind_LatticeCopyTicks` uses the seam only when `g_grind_order_test_active`.

In the code:
```cpp
int Grind_LatticeCopyTicks(const long from_msc, long &msc[], double &bid[], double &ask[])
{
   if(g_grind_order_test_active) {
      ...
   }
   MqlTick t[];
   const int n = CopyTicksRange(...);
   ...
}
```
Yes, the seam is only used when `g_grind_order_test_active` is true. VERIFIED.

Wait, but let me check whether `g_grind_order_test_active` is ever set true in live. In the tests... In the production it's set false by Grind_OrderTestReset. Seems fine. But wait - is there any path in the EA where `g_grind_order_test_active` is set true and never reset? It's a global, initialized false. Tests set it. OK G2 VERIFIED.

**G3.** Below cap, every B2 variable of that side is reset.

Looking at `Grind_LatticeTrackOneSide`:
```cpp
   const int depth = Grind_SideDepth(side);
   if(depth < max_layers) {
      if(is_long) {
         g_grind_vl_tracking_long = false;
         g_grind_vl_extreme_long = 0.0;
         g_grind_vl_from_msc_long = 0;
         g_grind_vl_stranded_warned_long = false;
         g_grind_vl_closing_ticket_long = 0;
         g_grind_vl_closing_since_long = 0;
         g_grind_vl_closing_warned_long = false;
      } else {
         ...
      }
      return;
   }
```
That's every B2 variable. Wait, but the test seam arrays (g_grind_vl_test_tick_*) aren't reset here. They shouldn't be anyway - they're a test seam. G3 VERIFIED.

**G4.** The extreme is used only for the crossing test; ROLL_STRANDED uses the live price.

In `Grind_LatticeTrySide`:
```cpp
      const double mkt = is_long ? Grind_MarketAsk() : Grind_MarketBid();
      const double probe = extreme > 0.0
                           ? (is_long ? MathMin(mkt, extreme) : MathMax(mkt, extreme))
                           : mkt;
      if(!Grind_LatticeLevelCrossed(is_long, probe, level))
         break;

      const int idx = Grind_LatticeCandidateIndex(side, is_long);
      if(idx < 0) {
         Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now);
         break;
      }
```
And `Grind_LatticeMaybeStranded` uses `mkt` for the crossing test. Yes, extreme is used only for the crossing test with level; ROLL_STRANDED uses mkt (live price). G4 VERIFIED.

**G5.** `00e0e4e` changes only the six `static` keywords.

I can't see commit diffs, only the code. Let me count file-scope helpers that might have been static. The prompt says "only removes `static` from six file-scope helpers the MQL5 compiler rejected". I have to take this as given, unless there's evidence otherwise. I only have one code state, so I can't verify the diff. But the design tells me to check quoted lines... I'll mark this as VERIFIED within available evidence but note I can't see the diff. Actually, I should be careful about claims. I'll state what I can verify: current code has no `static` on file-scope helpers.

Let me search for `static` in the code... In grind_engine.mqh I don't see `static` keywords on file-scope helpers. Let me check... Actually I don't see any `static` at all in the shown code, except possibly none. So G5 is consistent with current state.

OK, now the threats.

**T-1 Tick-history semantics.**

`CopyTicksRange` bounds. From MQL5 docs: `CopyTicksRange(symbol, ticks[], flags, from_msc, to_msc)` — returns ticks with `time_msc` in the range `[from_msc, to_msc]` (inclusive). So the range is inclusive.

The cursor is `from = msc[n-1] + 1`. So after reading up to `msc[n-1]`, next call uses `from = msc[n-1]+1`, which is inclusive lower bound. So a tick at msc[n-1] wouldn't be re-read. But `to_msc` is `Grind_MarketTimeMsc()` which is the current tick's msc. If a tick arrives with `time_msc` == `msc[n-1]` after the read... hmm.

Actually the concern: can a tick at the same `time_msc` arrive after the read and be skipped? MT5 ticks with the same time_msc — possible. If two ticks have the same msc value (e.g., broker sends tick A and tick B within the same millisecond), and we read up to the last one recorded... Actually the CopyTicksRange reads whatever is in the terminal's tick history. If tick A and tick B share msc, both would be returned in a single read. The cursor advances past both. So no skip within a read.

But: after reading at time T, the cursor is `msc[n-1]+1`. If a new tick arrives later with `time_msc` equal to some earlier value (unlikely unless the broker backdates ticks)... Actually MT5 tick time_msc comes from the broker server and should be monotonically non-decreasing. But if the broker delivers a back-dated tick (e.g., after reconnect), it could be skipped. That's a corner case. Likely not "unsafe direction" — could it cause a MISSED roll (safe) or an EXTRA roll (unsafe)?

Backdated tick with a lower ask than our extreme — if it's before the cursor and lower ask, we skip it. Skipping means our extreme is not as low as it could be, so we're less likely to roll → safe direction.

Wait, but if the cursor is `msc[n-1]+1` and the same `time_msc` had future arrivals... hmm. For CopyTicksRange, the cursor range is inclusive. So if we have cursor at X and a new tick arrives with msc == X (same as last read), the request [X, now_msc] would include it. So no skip.

Actually wait — the cursor is `msc[n-1]+1`, so the next call has `from = msc[n-1]+1`. If a new tick arrives with `msc == msc[n-1]` (same msc as the last tick we read), then the next call starts at `msc[n-1]+1 > msc[n-1]`, so it's excluded. Skips. But does MT5 deliver a tick with the same time_msc as an already-delivered tick? Marketing feeds usually have increasing msc; duplicates may happen. This is a theoretical skip in the SAFE direction (miss an extreme)?

Hmm, if the new same-msc tick has a lower ask (long), we'd miss it — safe. If it has a HIGHER bid (short), we'd miss it — safe. So skipping in the same msc is safe.

But there's another issue in the unsafe direction. What if the broker sends a tick with msc lower than our cursor (backdated) but with a more extreme price? We'd skip it. Wait, more extreme in unsafe direction means lower ask for long / higher bid for short — we WANT the extreme to be lower (long) so we roll. Skipping a backdated tick with a lower ask means missing a legit roll — safe direction (don't roll when we could). Missing a roll is safe (no bad fill for the exit... wait, actually a roll is a re-pricing of the exit to a new level; if the ask really did trade through, rolling is correct). Hmm.

Let me re-read: "Can any make the extreme WRONG in the unsafe direction (a roll where no limit could have filled)?"

The roll happens when `probe <= level` for long, i.e., `min(ask, extreme) <= level`. So a lower extreme makes rolls happen. The unsafe direction is rolling when no fill could have happened — i.e., extreme too LOW (long) / too HIGH (short).

Unsafe causes:
1. Ticks newer than the current tick. If time_msc > now... hmm, `to_msc` is `Grind_MarketTimeMsc()` (`SYMBOL_TIME_MSC` or the override). If SYMBOL_TIME_MSC is the current server tick time, then any tick in stored history newer than that wouldn't be returned (from_msc to to_msc range). Actually, if we set to_msc = current tick msc, and there's a tick in the history with msc > to_msc (e.g., from a different symbol's clock drift), it wouldn't be returned. So no issue from "ticks newer than current tick".

   But wait — in the test seam, there's no upper bound. The test seam copies ALL ticks >= from_msc, including future-dated ones. Is that a problem in production? No, because the seam isn't used in production. But the design might still be consistent.

   Actually — important. In production, what is `SYMBOL_TIME_MSC`? It's the last tick's time in ms. But if we're inside `OnTick`, the current tick was already delivered. So `to_msc` = current tick msc. Ticks in history with msc > current would be excluded. Good.

2. `COPY_TICKS_INFO` ticks whose ask or bid is 0 or stale. The function skips non-positive ask/bid. But what about `COPY_TICKS_INFO` semantics? COPY_TICKS_INFO returns only ticks with changed bid/ask. Actually, COPY_TICKS_INFO: "Ticks with INFO flags". Let me recall — MQL5 has COPY_TICKS_ALL, COPY_TICKS_INFO, COPY_TICKS_TRADE. COPY_TICKS_INFO returns only ticks where bid and/or ask changed (bid/ask changes). COPY_TICKS_TRADE returns ticks with trade info. The filter is applied so that we get bid/ask changes but might miss trades. Hmm — that's actually a possibility for MISSING ticks where only last/volume changed but the ask stayed the same. But wait, if the ask didn't change, we don't need those ticks. So OK.

   What about "stale" ticks? A tick with an old ask but whose msc is fresh (e.g., after a data gap, the broker resends a tick with an old price but new msc). Unlikely in normal operations.

3. What about the range's `to_msc`? If in the seam test there's a `Grind_MarketTestSeedTimeMsc`, the to_msc might be seeded. Otherwise, `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` — is SYMBOL_TIME_MSC guaranteed to be the same as the current OnTick tick's time_msc? Actually, it should be. But there may be a subtlety: SYMBOL_TIME_MSC returns "the time of the last quote... in milliseconds". This is what we want.

So the primary T-1 concerns seem benign except possibly the same-msc-skip which is safe.

Hmm wait, another. The cursor is `from = msc[n-1] + 1`. But does CopyTicksRange's `to_msc` include the current tick? If the current tick's msc is exactly msc[n-1] (no new ticks since last read), the next call would request [msc[n-1]+1, current_msc] and if current_msc == msc[n-1], the range is empty and returns 0. Fine.

But wait — the last-tick cursor moves. In production, when OnTick fires with tick msc T. The current call to `Grind_LatticeCopyTicks` uses `from = <last cursor>` and `to = T`. It reads all ticks in [from, T]. After that, from = last_tick_msc + 1. Suppose the last tick in history at time T is the current tick, so from = T+1. Next OnTick fires at T+1' with msc T2. Read [T+1, T2]. OK.

Now consider this: the current tick at time T (say) may still not be in the history when we call CopyTicksRange? Actually, inside OnTick, the current tick has just been delivered; the terminal's tick history should include it. But what if the terminal is delayed in appending? Hmm — most of the time it's there... but CopyTicksRange's `to_msc` = SYMBOL_TIME_MSC = the current tick msc. If the tick isn't in the history yet, we'd just get up to the previous tick. Next tick we'd get the current one if it's there. So no safety issue.

T-1 verdict: HOLDS (or NEEDS-FIX, but I think most semantics are OK).

Actually, one more point. The design reads ticks with `msc >= from_msc`, and the cursor `from = msc[n-1]+1`. But wait — if the first read after starting tracking had `from_msc = newest_open + 1 (in seconds) * 1000`, and if the actual tick time msc is rounded, the boundary is inclusive, so the first tick with msc >= newest_open+1000 is included. The newest position opened at time `newest` (in seconds). So ticks with msc >= (newest + 1) * 1000. That's one second after the fill. Hmm. Actually — could the fill tick itself be excluded? Ticks during the fill's own second are excluded. GD3 accepted this. But actually a fill happens on the ask for a long. The fill tick has an ask at the fill price, which could be below the level we're trying to check... but the fill tick is at L0 or later. If the level we're checking (say L1) is above the fill's ask, then including the fill tick could falsely show the level was crossed. Excluding it is safe/conservative. Good.

Actually hmm, wait. There's a subtle issue: the newest open time is the L7 open, because it's the newest. Positions L0-L7 open at different times, newest is the last. Right. So from = newest_open + 1 sec, which excludes ticks that happened before L7 opened. But those earlier ticks ARE relevant — L7 opened at level X, and the market may have traded through the L8 level (the next level) after L7 opened but before... wait no, we're checking for the next level (L8's level) which is beyond the current cap. Ticks before L7 opened occurred at a higher/lower price? For a long side at cap: L0 is at the top (highest ask we bought at), L7 is at the bottom (deepest). We entered L0 first, then waited for the ask to drop to L1, etc. So each subsequent layer opened as the market fell.

Hmm, the newest position is the DEEPEST added layer (L7). Ticks before L7 opened were ABOVE the L7 level, so they'd be checks against levels we've already rolled (which are already gone). The next level (L8) is at 1.20400 (below L7). Ticks before L7 opened were at > 1.20400, so they wouldn't cross L8. So excluding them is OK.

But wait — a V-shaped recovery could have brought the ask down to 1.20400 (or below), then back up to 1.20500 (where L7 got filled), then back down. If we only consider from L7's open time, we miss the earlier dip. But the earlier dip would have been caught by B1 at the time (each OnTick checked current ask). Hmm, and B1 wouldn't have missed it unless blocked. The design intent is to catch the ticks OnTick missed. OK.

T-1 - I'll say mostly HOLDS with the caveat about inclusive bounds and the same-msc skip being safe. Let me also consider "ticks newer than the current tick" — in the seam test, the arrays don't have an upper bound, but this is only for tests.

Hmm, actually let me think again about `COPY_TICKS_INFO`. 

From MQL5: "COPY_TICKS_INFO — ticks with bid and/or ask changes". So it returns ticks where either bid or ask changed. Some ticks (trade-only) are filtered out. The tick's bid/ask reflect the current state. Since we want bid/ask (not last/volume), filtering trade-only ticks is fine.

But — critical: does COPY_TICKS_INFO return ticks with `bid`/`ask` = 0? I don't think so by design—they should be the last known. But during a session break or on a fresh-start where no bid/ask is available yet... maybe. But we skip non-positive, so OK.

T-1: HOLDS.

**T-2 Stale extreme across a refill.**

"Can a rolled exit fill AND the real re-add fill with no `OnTick` in between (deals are processed in `OnTradeTransaction`; where is the re-add placed?), so the old extreme survives into a new cap episode and rolls a layer the market never reached after the re-add?"

The re-add happens via `Grind_TryPlaceAddAtFill` which is called from `Grind_HandleSideDealFill` (in `OnTradeTransaction`). Let me look... Yes:

```cpp
   if(c_role == "ENT") {
      ...
      Grind_AppendLayer(side, deal_price, position_id, c_layer, exit_pips, is_long);
      Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);
      Grind_TryPlaceAddAtFill(side, is_long, magic, slot, g_grind_engine_add_pips,
                              deadband_pips, max_layers, lots, deal_ticket);
   ...
```

So the re-add happens in OnTradeTransaction. The `OnTick` is where `Grind_LatticeTrackExtremes` runs.

Sequence for the scenario:
1. At cap (8 layers). Rolled L0's exit and it fills? Wait — a rolled exit filling means the position closed. Actually the roll re-prices the EXIT of an old layer. If the exit fills, the layer closes (position removed). Now depth = 7 (below cap).
2. The next deal: the re-add ENT fills. Depth back to 8.

Both deals processed in `OnTradeTransaction`. When the exit fills: `Grind_HandleSideDealFill` for `DEAL_ENTRY_OUT_BY` removes the layer. Depth drops to 7. But there's no `Grind_LatticeTrackExtremes` call here — that's only in OnTick.

Then the re-add ENT deal arrives (could be same OnTradeTransaction call or different). `Grind_AppendLayer` adds it. Depth back to 8.

So the sequence: depth 8 → 7 → 8, without any OnTick.

Wait, but `OnTick` is where `Grind_LatticeTrySide` runs (which triggers the roll). The rolled exit filling and re-adding — happens via OnTradeTransaction, not OnTick. Then the next OnTick comes.

At that next OnTick, the side is at cap = 8. `Grind_LatticeTrackOneSide` sees depth == 8 >= max_layers. It doesn't reset. And `g_grind_vl_tracking_long` is still true (never reset because reset happens only when depth < max_layers). So the extreme survives from the old cap episode.

Hmm — is this a real problem? The extreme was tracked since the OLD newest position open. Now the OLD newest position is GONE (it was rolled/closed). The NEW newest position just opened. So the extreme should reset to be from the new newest open.

Actually — hmm. Let's think. `if(!g_grind_vl_tracking_long)` — the tracking flag is still true, so we never re-derive the window start. So the extreme hangs around from the previous cap episode.

Is that unsafe? The extreme is a LOW ask (long). If the old extreme was, say, 1.20500 (a level the market traded through in the previous episode), and then after the roll+re-add, the market is at 1.20700 and hasn't reached 1.20500 again, then the extreme persists and rolls L0's exit to 1.20600 (using the old extreme), even though the market never reached that level after the re-add.

Wait — but B2's design (GD2 accepted) is to catch a level crossed while a roll was held off. Here the market DID reach the level (1.20500 < 1.20600), so the roll of L0's exit to 1.20600 could be legitimate? Hmm. Actually — the exit candidate at level L is computed from the current layer set's target level. If the extreme is 1.20500 (old), the level check is on the current computed level, e.g., 1.20600. The extreme 1.20500 <= 1.20600, so the LONG level check triggers. This rolls the exit of the newest candidate. But the market never went there AFTER the re-add. So it rolls incorrectly.

Hmm, but actually is this different from the accepted behavior? GD2 accepted "a level traded through while a roll was held off (backoff, closing, quarantine) rolls afterwards even if the market has come back". But in that case, the roll was held off at the moment by a backoff/closing/quarantine and the position hasn't changed. Here, the position HAS changed (the old one closed, a new one opened).

Actually the whole design intends "the running extreme since the side's NEWEST open". The newest open just changed. The B2 code should reset the tracking when the newest, but the reset condition only checks depth < max_layers. This is a real gap.

But hold on — is this actually unsafe? Let's think. If the market reached level L (say 1.20500 ask) at some point, and the side had an L0 with exit at... Actually the roll re-prices an exit from level L0_old to level L0_new. The exit is a limit order to sell. It's placed at a passive level based on the level's exit price. So if the exit gets re-priced to a lower level, it becomes a sell limit below the current market (if somehow the market is above), which the clamp handles.

Hmm, actually the specific unsafe scenario: market dropped to 1.20500, then recovered to 1.20700, then rolled L0's exit to level 1.20600 (below current ask 1.20700). This sell limit at 1.20650 (exit of 1.20600) would fill immediately? No wait, it's a SELL LIMIT for a LONG position exit. A sell limit fills at or above the limit price. If the price drops to 1.20650, it fills. The current market is 1.20700, so the sell limit at 1.20650 is below the ask. Sell limits below the current ask... would be a market sell. Hmm, actually sell limit must be above the current bid. If 1.20650 < bid 1.20690, it would be rejected or filled. Actually the exit is clamped passive by `Grind_ExitQClampPassive`, which for a long exit pushes it up to `ask + min_dist` if it's below. So the clamp moves the exit to the market. This is the VB3/LB42 clamped roll.

OK — so the outcome is a roll to a level the market didn't reach after the re-add, which likely means the exit is clamped to the current market, providing a passive sell at ~ask. This effectively gives a quick break-even exit for the layer. Is that "bad"? Debatable. The layer already has an exit; bringing it closer (via roll) means we accept closing at a tighter price. That realizes the roll cost.

Hmm — actually the design does intend to catch missed dips. The problem here is that the extreme from the PREVIOUS episode is stale.

Let me think again about what could go wrong. After the roll and re-add, suppose market is at 1.20700, and the OLD extreme was 1.20500 (from before the roll). At the next OnTick, `Grind_LatticeTrackOneSide` uses the OLD extreme. TrySide sees `probe = MathMin(1.20700, 1.20500) = 1.20500`. Level = 1.20600. 1.20500 <= 1.20600 → roll. But B1 (without the extreme) would say: 1.20700 > 1.20600 → no roll.

So B2 rolls when B1 wouldn't. Is that intended? The design intent seems to be "the level was crossed since cap". But the market crossing was BEFORE the roll+re-add. After the roll+re-add, the level is no longer crossed.

Hmm, actually think about this more carefully: the roll re-pricing depends on the ORDER of events. The roll of L0 happened (in the previous OnTick). Then L0's exit filled. Then a new layer was added. So the new layer is at a new level. The old extreme reflects market levels from when old L0 was the candidate. The old extreme at 1.20500 was WORSE than the current level at 1.20600. So the new candidate would roll using stale information.

Is this likely to happen? Possibly under high volatility. But there's a deterministic way to reset: check if the newest open time has changed. The design notes "A4: a side's newest position open time is available with a test seam". But the implementation only uses it to set `from` initially. It doesn't re-check.

Actually, hmm — wait. Let me re-read the code:

```cpp
   if(is_long) {
      if(!g_grind_vl_tracking_long) {
         datetime newest = 0;
         bool any = false;
         for(int i = 0; i < depth; i++) {
            const ulong pos = side.layers[i].position_ticket;
            if(pos == 0)
               continue;
            datetime ot = 0;
            if(!Grind_CarryPositionOpenTime(pos, magic, ot))
               return;
            if(!any || ot > newest) {
               newest = ot;
               any = true;
            }
         }
         if(!any)
            return;
         g_grind_vl_from_msc_long = MathMax(...);
         g_grind_vl_tracking_long = true;
         g_grind_vl_extreme_long = 0.0;
      }
      ...
```

So `newest` is only computed when `!g_grind_vl_tracking_long`. If tracking is already true, we never re-check. This means the extreme is NOT reset when the newest position changes (as long as the side stays at cap).

So T-2 verdict: NEEDS-FIX (or BREAKS). This is the "stale extreme across a refill" threat. The scenario is real. The fix is to also reset when the newest open time changes. Let me think — is this genuinely in-scope for the audit? Yes, T-2 specifically asks about it.

Actually, let me double check the re-add path. Where does the re-add happen? In `Grind_TryPlaceAddAtFill`:

```cpp
void Grind_TryPlaceAddAtFill(GrindSideState &side, ...)
{
   if(!g_grind_fill_time_place)
      return;
   ...
   Grind_SendNextAddEnt(...);
}
```

Only if `g_grind_fill_time_place`. Otherwise the re-add happens in `Grind_EnsureAddNext` during the next OnTick.

If `g_grind_fill_time_place` is false, the re-add happens in the next OnTick's `Grind_EnsureAddNext` — but the LATTICE OnTick runs BEFORE `Grind_OnTickEngine` (which contains `Grind_EnsureAddNext`)! Let's verify the order in fxgrind.mq5:

```cpp
void OnTick()
{
   Grind_ProcessCloseByQueues(InpMagic, InpVerboseLog);

   if(!g_grind_halted) { ... }

   Grind_EjectPollCommand(...);
   Grind_AutoEjectOnTick(...);
   Grind_LatticeOnTick(...);   // <-- LATTICE HERE
   Grind_SessionStep(...);
   Grind_BreakerOnTick(...);

   if(g_grind_halted)
      return;

   if(g_grind_quarantined) { ... return; }

   Grind_OnTickEngine(...);  // <-- ensure add next here
}
```

Yes! `Grind_LatticeOnTick` runs BEFORE `Grind_OnTickEngine`. So within the same OnTick:
1. If a rolled exit filled earlier (via OnTradeTransaction), the layer was removed. Depth < 8 when OnTick fires.
2. Then `Grind_LatticeOnTick` runs, sees depth < 8, RESETS the extreme. Good.
3. Then `Grind_OnTickEngine` runs and re-adds. Depth back to 8.

So actually for fill_time_place = false (the default), the reset DOES happen because the layer removal and re-add are separated by OnTick.

But — with `g_grind_fill_time_place = true`, the re-add happens in `OnTradeTransaction` via `Grind_TryPlaceAddAtFill`. So depth goes 8 → 7 → 8 with no OnTick in between.

Wait, but also the ENT fill happens in OnTradeTransaction. Does the roll itself happen in OnTick (via TrySide → RollLayer → ModifyPendingPrice)? Yes. So L0's exit is re-priced in OnTick. Then the exit fills eventually (a close). But the ROLL fills are typically via the broker filling the modified exit — the fill triggers OnTradeTransaction, which removes the layer. Then the re-add is via `Grind_TryPlaceAddAtFill`.

But the re-add ENT order needs to be filled too. When does it fill? On the next market move. Same problem: the ENT fills quickly (a limit order at near the current market, or a straddle-like add). Fill time_place = true means the EA places it immediately in OnTradeTransaction. So the sequence: exit deal → remove layer (depth 7) → place new ENT → ... it's pending until it fills → ENT deal → append layer (depth 8).

That new entry might fill within milliseconds (if the add target is near the market). If it fills before the next OnTick, we have the issue.

OK so with fill_time_place = true, T-2 is a real risk.

Actually wait — is fill_time_place enabled in Fleet B? Let me check. The prompt says "D1 kill switch, preset opts in". So some presets enable it. Hmm.

Also — even without fill_time_place, consider this: the roll fills AND the re-add (via EnsureAddNext in the SAME OnTick that re-added) also fills? No — EnsureAddNext places the order; it needs to fill. The fill happens on a later tick (OnTradeTransaction). Then the next OnTick runs LATTICE first: but at this point depth is 7 (the exit filled, layer removed) — wait, the re-add was placed but not yet filled. So depth is 7, not 8.

Let me redo. Actually the scenario for T-2:
- depth = 8.
- Roll happens (OnTick), re-pricing L0's exit.
- L0's exit fills (OnTradeTransaction removes layer 0). depth = 7.
- EA places a new ENT (either in T-2-same OnTradeTransaction via TryPlaceAddAtFill if fill_time_place, or on the next OnTick's EnsureAddNext).
- The new ENT fills (OnTradeTransaction appends layer). depth = 8.

For the bug to manifest, no OnTick must run between the exit-out transaction and the ENT-in transaction. With fill_time_place = true, both can happen without OnTick.

Even with fill_time_place = false: exit-out transaction (depth 7) → no OnTick yet → next OnTick runs LATTICE (depth < 8, reset) then EnsureAddNext places the ENT. Then the ENT fills later. So the reset happens. Good — no bug.

With fill_time_place = true: exit-out transaction (depth 7) → TryPlaceAddAtFill places the ENT (no layer yet, still depth 7) → ENT fills at some millisecond later (depth 8). If no OnTick runs in between, the bug occurs.

So T-2 is a REAL bug but only with fill_time_place = true.

Hmm, but wait — with fill_time_place = true, the add target might be placed just below the market, and fills quickly. Thems need to be within the same OnTradeTransaction? Actually, MQL5 handles each trade transaction individually. The exit-out transaction and the ENT-in fill are separate events. Each fires OnTradeTransaction. But OnTick might not fire between them. In fact, MT5 does not guarantee OnTick between trades. So yes.

Hmm, but hold on. Between processing two OnTradeTransaction events, does MT5 process OnTick? OnTick fires on new ticks; if the market is active, OnTick might fire. But if the market is quiet (e.g., 1 tick per second), the exit-out and ENT-in could both happen between two ticks. Actually, the exit-out fill requires a quote; the ENT-in fill requires a quote; these are quotes that would also trigger OnTick usually. Hmm, in MT5, OnTick fires only on the latest tick — if two ticks arrive back-to-back and OnTick is slow, it can miss intermediate ticks. But usually OnTick fires per tick (or per symbol update).

Actually — the deeper issue is MT5 may not deliver OnTick for every trade-related quote. If we have 11 instances sharing a terminal, OnTick is called for each. Hmm.

Let me not overstate. The bug is real for fill_time_place = true. That's a real fleet setting possibility. I'll mark T-2 as NEEDS-FIX.

Actually let me consider: could the old extreme cause a roll to a level the market never reached after the re-add? Yes, an off-by-one in the extreme could roll to a level that wasn't crossed. Is it "unsafe"? Well, the exit gets clamped, and the roll cost is realized. If the market never went there after the re-add, the roll is spurious (the design says GD2 accepted rolls for levels crossed "since cap"; here it wasn't since cap). So it's arguably a violation of the intended rule. It's a NEEDS-FIX.

Hmm, but actually — think about the reverse: the exit-out + add-in also happen when a NORMAL exit fills (not a roll). So the same stale extreme could roll a fake level.

OK, T-2 = NEEDS-FIX.

Wait, but I need to consider: is this actually triggered by the lattice being on and a roll? Let's trace:
- Roll happens → L0's exit set to lower level → clamped to market (ask+1pt) → fills quickly.
- Layer 0 removed, EA places new ENT at next level → fills.
- Stale extreme causes roll of the new candid.

Yes.

Fix: also detect newest change and reset extreme. E.g., store the newest open time and reset the extreme when it changes.

Actually, more precise: The tracked window should restart when the side's "newest position open" changes. Currently `g_grind_vl_from_msc_long` is the cursor. When tracking is true, we don't re-derive. Simple fix: store `g_grind_vl_newest_long` and compare each tick; if different, set tracking false to force re-derive. Or reset the extreme and cursor.

I'll note this as the fix.

**T-3 Cost of a read.**

At a restart with a side at cap, the first read can span 24 h of ticks inside `OnTick`. How long can that block? CopyTicksRange is a synchronous call from the terminal to the tick history (local memory). For 24 h of ticks on a major pair, £ maybe 50k-500k ticks. CopyTicksRange copies to a local array. On a fast machine, ~10^6 ticks per second? So maybe 50-500 ms. For GBPUSD, ~1,000,000 ticks/day is not unheard of. So one call could be 100 ms to 1 s. Blocking.

Wait, and after the read, `from = msc[n-1]+1`. So next OnTick reads only new ticks. So the first read after restart is the big one. After that, small. This is a one-time cost. But it runs in OnTick which is on the main thread. So it blocks the OnTick for that amount of time, which could delay other processing. And every instance on the terminal does it. With 11 instances, if they all start at once... they're on different code, but the terminal serializes OnTick? Actually they're separate EAs but share the terminal's main thread. So 11 * (up to 1s) = 11 s of blocking. That's a startup delay, not a per-tick problem.

More concerning: "what happens while it returns -1 during history sync, tick after tick? Any path where it blocks every tick?" If history is not synced, CopyTicksRange returns -1 (or ERR_HISTORY_NOT_FOUND?). The code returns -1 when n < 0. So each tick: creates fresh empty arrays, calls CopyTicksRange which returns -1 quickly. So no repeated blocking — just a quick failure each tick.

But wait — there's the `from` advance. If n < 0, we return early, don't advance. So `from` stays. Next tick: same from, same call. So each OnTick does the failed call. If the failure is fast, OK.

But there's a potential issue: what if the failure CLEARS the tick history cache and the next call has to re-download? Hmm, MQL5 CopyTicksRange returns a specific error. If data is needed, it requests it from the server asynchronously and returns -1 immediately with a "loading" state. Actually more like returns -1 and sets _LastError to 4401 (ERR_HISTORY_NOT_FOUND) or similar. So it's fast.

But here's the blocking scenario: on each tick, before the history is ready, the call returns -1 quickly. Once ready, the first call reads 24 h. So the blocking is once.

Hmm. But consider: the side is at cap. On restart, tracking is false. First tick: derive from = (now - 24h)*1000. Read: 24 h. n is returned. The array could be HUGE. `ArrayResize` on a huge array. Potential memory pressure and slowness. At 500k ticks × 3 arrays × 8 bytes = 12 MB. Manageable but slow.

Latency: on slow VPS with Wine (the "Wine box"), this could take seconds. Across 11 instances, tens of seconds. That's a concern for the first tick after startup. But it's a one-off.

Also: the tick history may be limited by the terminal's "Max bars in chart" setting. Hmm—does CopyTicksRange respect that? The tick history in MT5 is bounded by the terminal's setting for ticks (the "Max bars/chart" is for bars). Actually there's a "history" bound for ticks too. If the terminal only keeps 1 day of ticks, then 24 h works. If less, we get fewer.

Also there's the terminal's tick history for a symbol, limited by the "SYMBOL_TICKS" but I'm not 100% sure of the bound.

T-3 verdict: NEEDS-FIX for the blocking concern? Or HOLDS? Hmm. The design notes it as an accepted cost (GD1). But the prompt asks "How long can that block the EA... Any path where it blocks every tick?"

The "blocks every tick" concern: if `CopyTicksRange` returns fewer ticks than expected each call and we advance the cursor incorrectly... Let me look:

```cpp
      const int n = Grind_LatticeCopyTicks(g_grind_vl_from_msc_long, msc, bid, ask);
      if(n < 0)
         return;
      Grind_LatticeFoldExtreme(true, g_grind_vl_from_msc_long, msc, bid, ask, n,
                               g_grind_vl_extreme_long);
      if(n > 0)
         g_grind_vl_from_msc_long = msc[n - 1] + 1;
```

If n > 0, we advance the cursor to the last returned msc + 1. Otherwise we keep. If the terminal returns fewer than the full range (e.g., truncated at some limit), we'd re-read the next batch next tick — progress. If the terminal returns 0 (empty range), we don't advance, but the current price check happens each tick. So no unbounded block. Each tick is at most one CopyTicksRange call.

If history is never ready: every tick calls CopyTicksRange → returns -1 → returns. Each tick has a brief CopyTicksRange call. Not a "block", but repeated. OK.

Hmm, the "blocks every tick" path: if CopyTicksRange is capped at, say, N ticks per call, and the range contains 24 h > N ticks, the cursor advances by N each tick, requiring 24h/N calls. If N is small (e.g., 4096?), and the history has 500k ticks, that's ~122 calls over 122 ticks. But we only track once we're done? No — we fold what we get each tick and can roll based on the partial read. Hmm.

Actually, the advance is to the LAST tick in the batch, so we advance by N ticks each time. But the FIRST batch is the OLDEST N ticks; the LATEST N ticks are still missing. So we'd miss recent ticks until we catch up. This could be a real issue if CopyTicksRange has a limit. I'm not sure of the exact limit for CopyTicksRange. From MQL5 docs: CopyTicksRange has no documented limit. CopyTicks has `count` parameter.

Hmm, actually I recall there IS a max ticks array size for CopyTicks/CopyTicksRange, but it's large. Let me not assert.

Wait — actually there IS a subtle issue. If the read is capped, the batches arrive oldest-first. During the catch-up, the LIVE price is also folded each tick (well, in the tracking code, `Grind_LatticeFoldExtreme` also folds the live price). So the live price check is present. But the PAST ticks between the last batch and the current time would be missed until the batches catch up. Since the batches come oldest-first, and the extreme is a min/max over all past ticks, catching up eventually reaches all of them (except the ones that scroll off). If ticks scroll off while we're catching up (24 h rolling window), we might miss some. Hmm.

I think this is a real concern worth flagging. But I'll say NEEDS-FIX or HOLDS-with-note depending. The prompt asks me to flag the cost. I'll discuss.

Hmm — I'll mark T-3 as HOLDS (with a caveat) if the terminal returns the full range, else NEEDS-FIX.

Let me look up: Multiple sources say CopyTicks/CopyTicksRange can return up to a maximum chunks. Actually — I recall the MQL5 documentation for CopyTicksRange doesn't mention a cap. It returns all ticks in the range. There's a symbol-level limit on how many ticks the terminal stores (the "ticks" memory). Typically a few days.

OK. Let me also note: in the OnTick, `Grind_LatticeOnTick` runs on EVERY tick. For each ONE_SIDE, it calls CopyTicksRange from the cursor to `SYMBOL_TIME_MSC`. In steady state, this is a small range (only new ticks since last OnTick). So cost per tick is tiny. The concern is the initial 24 h read.

Alright, T-3 HOLDS or NEEDS-FIX — I'll say HOLDS with the caveat that the initial read can block, and flag the potential for a fresh-session catch-up loop.

Hmm, let me actually reconsider. The cursor is `from`. Suppose the terminal returns 0 ticks every tick because the terminal's SYMBOL_TIME_MSC is not getting new ticks (quiet market). Then the read returns 0, we don't advance. That's fine — nothing to fold.

What if `from > to` (i.e., `from_msc > current`)? Then CopyTicksRange would return 0. Fine.

**T-4 Latches.**

ROLL_STRANDED clears when the side has a candidate. In TrySide:
```cpp
   if(Grind_LatticeCandidateIndex(side, is_long) >= 0) {
      if(is_long)
         g_grind_vl_stranded_warned_long = false;
      else
         g_grind_vl_stranded_warned_short = false;
   }
```
So if there's ANY unrolled layer, clear. And below cap, `Grind_LatticeTrackOneSide` also clears (via stranded_warned = false).

Wait — but `Grind_LatticeCandidateIndex >= 0` means there's an unrolled layer. In B1, when all layers are rolled, `idx < 0`. After a roll, the count of unrolled layers decreases. Once all are rolled, idx < 0. But actually after a roll, a new layer might be added? Or the rolled layers get unrolled when... Hmm. Actually the rolled exit fills → layer removed. So the "unrolled" candidate switches (the next layer becomes the candidate). Hmm.

Anyway, the clearing condition: (a) there's an unrolled layer, or (b) side drops below cap. Seems reasonable.

Can ROLL_STRANDED spam? It's latched. Reset when the side has a candidate. If the side oscillates (has candidate → no candidate → has candidate), it could re-fire. But each episode is at most one WARN. Seems OK.

Can it fire on a healthy book? The check is:
```cpp
   const double stranded_level = Grind_Normalize(Grind_AddTargetPrice(level, (GRIND_VL_STRANDED_STEPS - 1) * add_pips, _Point, is_long ? 1 : -1));
   if(!Grind_LatticeLevelCrossed(is_long, mkt, stranded_level))
      return;
```
Where `level` is the current level (the level just computed by ComputeAddTarget). level is computed from the effective entry if any VL exists. All layers rolled → `any_vl` true → anchor = lowest (long) effective entry. `level = anchor - add_pips*1 (pip conversion)`. And stranded_level = level - (S-1)*add_pips = anchor - 2*add_pips. So stranded_level is 2 add steps below the deepest effective entry.

If the market is 2 add steps beyond the deepest effective entry, warn. That's a trend continuing well past the grid. On a normal book (no roll), all layers rolled? Hmm — actually with no VL, `any_vl = false`, so anchor = deepest layer entry. Then stranded_level = deepest_entry - 2*add_pips. Hmm. But the code path is only entered if `idx < 0` — no candidate. No candidate means every layer has a VL. So `any_vl` is true.

OK so ROLL_STRANDED fires when the market is 2 add steps beyond the deepest effective entry AND every layer has been rolled. Latched. Then when a candidate appears (unrolled layer), reset.

Does it fire on a healthy book? A normal CloseBy of a few seconds — no, that's a different thing (ROLL_CLOSING_STUCK). The stranded check is independent of any closing state. Hmm.

Wait — can it fire spuriously? If the side is at cap with all layers rolled (a normal end state — the whole side rolled), and the market continues, ROLL_STRANDED fires. That's the intended design: warn when the trend has moved 2 add steps past the deepest roll. Seems fine. It's a WARN, not a halt.

But hmm — I want to check: after a roll, the deepest effective entry is the deepest VL. So the whole side is rolled. Then the market moves further. WARN. But then the roll candidate becomes... hmm, no candidate since all rolled. So the WARN latches. When does it clear? When a candidate appears (a new layer that gets added and not yet rolled). A new layer would be added when an exit fills (freeing a layer). Then it's not rolled, so a candidate exists → clear. OK.

So can it spam? If the market crosses back up (out of stranded state) without a new layer? Then the latch stays set. If it becomes stranded again after... Hmm, the latch isn't reset by the market leaving. So one WARN per episode. Fine.

Actually, hmm — is there a case where it fires on a healthy book? If the market gaps 2 steps beyond the deepest roll in a single tick, does it fire? It should — the level check is a single-moment check. If the market is 2 steps beyond at the moment, warn. That's a big gap, could be news. Legit WARN.

Hmm, one issue: could ROLL_STRANDED fire while the market ISN'T stranded, because level is computed off the WRONG anchor? Let me think. If the deepest layer has a VL (rolled), ComputeAddTarget uses the min effective. Suppose the deepest layer's VL is old and stale (from a prior episode — T-2 scenario). Then level = old_vl - add. And stranded_level = old_vl - 2*add. If the market is now much higher than old_vl (say 3 add steps above), then the check: is mkt <= stranded_level (long)? mkt = old_vl + 3*add > old_vl - 2*add, so no warn. Hmm, no warn.

But if the market is at old_vl - 2*add (below), warn. Hmm, could be a legit gap-down. Not obviously spurious.

ROLL_CLOSING_STUCK: 
```cpp
void Grind_LatticeNoteClosing(const bool is_long, const ulong pos, const datetime now)
{
   if(is_long) {
      if(g_grind_vl_closing_ticket_long != pos) {
         g_grind_vl_closing_ticket_long = pos;
         g_grind_vl_closing_since_long = now;
         g_grind_vl_closing_warned_long = false;
      } else if(!g_grind_vl_closing_warned_long
                && now - g_grind_vl_closing_since_long >= GRIND_VL_CLOSING_WARN_SEC) {
         ...WARN...
      }
   }
   ...
}
```

And reset:
```cpp
   if(!closing_stop)
      Grind_LatticeResetClosingState(is_long);
```
Where reset clears ticket/since/warned.

So if the loop doesn't stop on closing, reset. If the loop stops on closing on the SAME pos for 60 s, warn.

Can it spam? Latched via warned. Reset only when the loop ends without closing stop. So if the same pos stays closing, one WARN. If the closing pos changes (different ticket), reset and re-start the timer → another WARN after 60 s for the new pos. OK — that's by design (stuck on a different layer).

Can it fire on a healthy book? The closing path: `exit_position_ticket != 0` means the layer's exit filled and is pending CloseBy. A normal CloseBy of a few seconds < 60 s. So no WARN. But what if CloseBy is slow (a few minutes)? Then it fires. That's intended (WARN_CLOSING_STUCK separates slow from stuck).

Hmm — but note the CloseBy processing: the exit fills, becoming a hedge position; the EA queues a CloseBy deal. `Grind_ProcessCloseByQueues` is called at the start of OnTick. If the CloseBy fails repeatedly, the layer stays closing. Then the WARN fires after 60 s. Reasonable.

Hmm, but on a healthy book, is the WARN clear enough? On a real CloseBy, the exit_position_ticket would be cleared when the CloseBy deal completes. So the layer becomes non-closing. The WARN fires only if that takes 60 s. OK.

Can it never fire when it should? If the loop doesn't reach the "closing" break because an earlier iteration rolled some other layer... Let's see:

```cpp
   for(int iter = 0; iter < max_layers; iter++) {
      ...
      const double level = ...;
      ...
      const double mkt = ...;
      const double probe = ...;
      if(!Grind_LatticeLevelCrossed(is_long, probe, level))
         break;   // <-- break out, no closing stop
      const int idx = Grind_LatticeCandidateIndex(side, is_long);
      if(idx < 0) { ... break; }
      if(side.layers[idx].exit_position_ticket != 0) {
         Grind_LatticeNoteClosing(...);
         closing_stop = true;
         break;
      }
      ...
   }
   if(!closing_stop)
      Grind_LatticeResetClosingState(is_long);
```

So if the level isn't crossed (or no candidate), the loop breaks BEFORE reaching the closing check — so `closing_stop` remains false → reset → the latch is cleared. So if the market moves back so the level isn't crossed, the closing note resets. That's consistent with "clears when the loop ends without a closing stop". But it means: if the market moves away, then the closing WARN never fires even if the layer stays closing. Is that intended? Hmm.

Actually the design says "the roll candidate stays 'closing' 60 s continuously on the same position". If the loop doesn't run to the closing check because the level isn't crossed, the closing note gets reset. So the "60 s continuous" is really "60 s of continuous level-crossed with the same closing candidate". Slight difference. But it matches the design intent (roll candidate stays closing).

Hmm, could this be a problem? Suppose layer L0's exit filled (closing), the level is NOT crossed (market not there), so the loop breaks immediately. No closing note. The layer is stuck closing for very long. But no WARN because the level isn't crossed. Then the market crosses — the loop runs, and 60 s later warns. Seems OK.

Actually wait, there's a subtle issue: `Grind_LatticeResetClosingState(is_long)` is called at the END of the loop when there's no closing stop. So even in the case where the loop makes SOME rolls but then breaks (level not crossed), the closing state resets. That's correct — the loop didn't find a closing candidate.

OK, ROLL_CLOSING_STUCK seems fine. Hmm. But one more: does the WARN fire on a HEALTHY book where the "closing" is due to a normal fast CloseBy? The threshold is 60 s; normal CloseBy < 60 s. So no.

What about a NORMAL roll where the exit is modified, then the fill creates a CLOSING state briefly? Between the modify and the exit fill, the state is fine (exit_order_ticket != 0, exit_position_ticket == 0). After the exit fills, exit_position_ticket != 0 (closing), waiting for CloseBy deal. Then CloseBy completes. If <60 s, no WARN. OK.

Can the WARN spam? If the state alternates closing→non-closing→closing on the same ticket... Actually `Grind_LatticeNoteClosing` resets the timer only if the ticket DIFFERS or if the loop ends without closing stop. So if the loop alternates closing stop / no closing stop, the reset happens on the no-closing-stop path (clears everything). So on re-entering closing, the timer restarts. The WARN fires again. Could spam every ~60 s. Hmm, but that's tied to the closed-loop-cycle. In practice, if a layer is stuck closing and the level is sometimes crossed and sometimes not (oscillating market), we could hit a WARN every time we re-enter closing for 60 s. That's a slow spam. Eh, acceptable.

T-4: HOLDS (with minor notes).

**T-5 Off means off.**

With InpVirtualLattice=false, does any B2 code run? In OnTick:
```cpp
   Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice, ...);
```
And `Grind_LatticeOnTick`:
```cpp
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   ...
```
Yes, if !enabled, return immediately. So no B2 code runs. T-5: HOLDS for the off part.

With it on and the side below cap: `Grind_LatticeTrackOneSide` sees depth < max_layers → resets and returns. And `Grind_LatticeOnTick`:
```cpp
   if(Grind_SideDepth(g_grind_long) >= max_layers)
      Grind_LatticeTrySide(...);
```
Only calls TrySide at cap. So below cap, no TrySide. T-5: HOLDS.

Hmm — but wait, `Grind_LatticeTrackExtremes` is called BEFORE the `blocked` check. So it runs even when blocked. The prompt notes this design. T-6.

**T-6 Blocked instances.**

Tracking runs while halted or quarantined. Can anything it does (reads, resets, latches) interfere with halt, quarantine, reconstruction, or the carry pass?

Reads: `Grind_LatticeCopyTicks` when `g_grind_order_test_active` is false → calls `CopyTicksRange`. This is a terminal API call, not an order operation. It shouldn't interfere with halt/quarantine. OK.

Resets: touching g_grind_vl_* globals. These globals are separate from the halt/quarantine machinery. OK.

Latches: `Grind_LatticeNoteClosing` and `Grind_LatticeMaybeStranded` write archive markers and telemetry. `Grind_ArchiveMarker` and `Grind_TelemetryEmit`. These might interfere with... hmm, telemetry state. Probably not. And Print(). OK.

BUT — the tracking runs BEFORE blocked, so on every tick even when halted. The reads are still called (CopyTicksRange). If the terminal is in a degraded state, this is extra work each tick. But not "interference" per se.

Hmm — what about quarantine? During quarantine, `Grind_OnTickEngine` is skipped. But `Grind_LatticeTrackExtremes` still runs and updates the extreme. Then later, when quarantine clears and `Grind_LatticeTrySide` runs, it uses the extreme from quarantine time. Is that a problem? Well, the design says "a level crossed while a roll was held off (backoff, closing, quarantine) rolls afterwards". So yes, intentional. OK.

What about interaction with the carry pass? The carry pass runs on a timer (OnTimer). It modifies exits. The lattice runs on OnTick. They both touch exit orders. Hmm — if the carry pass is mid-way (cursor advancing), and TrySide rolls a layer, the carry pass might re-modify. Let's see — `Grind_CarryCurrentExitTicket` re-reads the current exit ticket at each step, and checks `closing`. But it doesn't check whether the lattice rolled the layer in the meantime. Hmm — well, there's a "shift recorded" mechanism.

Actually, the LB42 test covers "clamped catch-up roll then pass". It passes. So apparently the interaction is OK. OK, T-6: HOLDS.

Hmm, wait, one more: `Grind_LatticeTrackExtremes` runs BEFORE blocked, so on every tick, even before halt. But the reads only happen at cap. If halted and the side is at cap, reads happen each tick. The extreme folds. Then blocked returns early. So no order ops. OK.

**T-7 Tests.**

Which B2 behaviour has no test that fails without it? Hmm. Let me look at the tests.

The tests are structured. The 23 predicted FAIL rows in commit 1 are covered by the marked FAIL. After commit 2, they pass. But the question is: does any test pass vacuously?

Let me look at each.

- VC1: `Grind_LatticeTickExtreme` with from=1500, expects min ask = 1.19990. The tick at msc 2000 with ask 1.19990, and msc 3000 with ask 0.0 (skipped). So min = 1.19990. OK. VC1 has all 3 asserts as FAIL in commit 1 (stub returns false).

Hmm—"VC1 nothing in range": `Grind_LatticeTickExtreme(..., 2500, true, x)` expects false. With the stub (returns false always), this passes! So it's a PASS in commit 1 (as noted). After implementation, it's still false because no tick has msc >= 2500 with a positive ask (msc 3000 has ask 0.0, which is skipped). So false. OK.

- VC2: expects max bid = 1.20000. Ticks at 1000,2000,3000 with bids 1.20000, 1.19980, 1.19900. from=0. Max = 1.20000. OK.

- VC3: extreme from ticks. SeedLong8 with opens 09:00-09:07. from = 09:07:01. Tick at 09:30 with ask 1.20590. Since 09:30 > 09:07, included. Extreme = 1.20590. Level = 1.20600. probe = min(ask 1.20700, extreme 1.20590) = 1.20590 <= 1.20600 → roll. Level 1.20500: 1.20590 > 1.20500 → stop. So one roll. Check the exit clamp. OK.

- VC4: Tick at 09:05, which is before 09:07:01. Excluded from range (from_msc = (09:07:01)*1000). So the tick has msc < from → not folded. Extreme = live ask only = 1.20700. Level = 1.20600. probe = 1.20700 > 1.20600 → no roll. So VC4 passes (no roll). OK — actually is this a vacuous pass? It passes because there's no roll. But it's the "negative" test. OK.

- VC5: Tick ask 1.20610 > 1.20600 → no roll. Negative test. OK.

- VC6: Short, tick bid 1.19410. Level = 1.19400 (short levels start here). probe = max(bid 1.19300, extreme 1.19410) = 1.19410 >= 1.19400 → roll. OK. Hmm — let me verify the short level. SeedShort8; the first virtual level for short... The prompt says "SeedShort8 start at 1.19400". ComputeAddTarget for short: with no VL (initial), anchor = deepest layer entry. Hmm, actually let me trust the doc.

- VC7: Gap. Two ticks with asks 1.20590 and 1.20490. Extreme = 1.20490. Level 1.20600 → roll. New level (after L0 rolled) = ? ComputeAddTarget now has any_vl = true (L0 rolled at 1.20600), anchor = min effective = 1.20600 (only L0 rolled). Level = 1.20600 - add(10) = 1.20500. probe = 1.20490 <= 1.20500 → roll. Next level 1.20400. probe 1.20490 > 1.20400 → stop. Two rolls. OK.

- VC8: First OnTick(09:35). Tick at 09:30, ask 1.20650. Extreme = 1.20650. Level 1.20600. probe = 1.20650 > 1.20600 → no roll. Assert extreme = 1.20650. Then Tick(09:40, ask 1.20595). Second OnTick(09:45). The first read was [from, to_msc of the seam]. Hmm — the seam reads ALL ticks with msc >= from. It ignores `to`. So the second read includes both ticks (09:30 and 09:40). Actually the cursor after the first read is msc[n-1]+1 = (09:30)*1000+1. Second read from (09:30)*1000+1: only the 09:40 tick. Extreme = min(1.20650 folded, 1.20595) = 1.20595. Wait — the extreme was 1.20650 from before. Folding 1.20595 gives min = 1.20595. Level 1.20600. probe = 1.20595 <= 1.20600 → roll. OK. Assert VL 7001 = 1.20600. OK.

- VC9: failure → retry. OK.

- VC10: Lookback cap. A) opens 26 Sep 09:00-09:07, now = 28 Sep 10:00. from = max(newest+1, now-24h). now - 24h = 27 Sep 10:00. newest+1 = 26 Sep 09:07:01. So from = 27 Sep 10:00. The tick at 27 Sep 09:30 < from → excluded. So no roll. OK.
  B) Tick at 27 Sep 11:00 > from. Included. Roll. OK.

- VC11: below-cap reset. OK.

- VC12: backoff. First call `g_grind_order_test_send_ok = false`. TrySide: level 1.20600 crossed. Roll attempt fails (modify fails). Backoff set to now + 60. Assert modify_calls == 1 and no roll. Then send_ok = true, advance now by 61. TrySide: backoff passed. Level 1.20600. Extreme still 1.20590 (from before). Roll. OK.

- VS1: Stranded. OK.

- VS2: Short stranded. OK.

- VCS1: Closing stuck. OK.

- VCS2: Order gone stuck. OK.

- LB40-LB43: carry interactions.

Hmm, so which B2 behaviour has NO test that fails without it? Let me think.

The tests seem to cover: extreme computation (VC1, VC2), missed dip roll (VC3, VC6), before-open exclusion (VC4), bid/ask distinction (VC5), gap (VC7), extreme across ticks (VC8), copy failure (VC9), lookback (VC10), reset below cap (VC11), backoff (VC12), stranded warn (VS1, VS2), closing stuck (VCS1, VCS2), carry integration (LB40-LB43).

Gaps:
- T-2 stale extreme across refill is NOT tested. No test covers "exit fills and re-add fills with no OnTick".
- Windows of MULTIPLE instances: not tested.
- Restart with a different book: not tested.
- The `Grind_LatticeFoldExtreme` live-price folding when the raw tick read fails but the live price is valid: not directly tested. VC9 uses a full failure (-1). Hmm.

Now the specific prompt: "Does any assertion in fxgrind_tests_c55.mqh pass vacuously (inside an if, on leftover state, on a fixture that never reaches the code)?"

Let me look for vacuous tests.

Hmm — the "PASS in both states BY DESIGN" list: VC3 one level only, VC4, VC5, VC7 L2, VC8 no roll yet, VC9 first, VC10 A, VC11 reset and re-cap. These pass in commit 1 (stub) and commit 2. Are they vacuous?

VC3 "one level only": `AssertFalse("VC3 one level only", Grind_VLHas(7002UL))`. Stub: no roll, so `!VLHas(7002)` → true. Impl: L0 rolled, L1 not → true. So this is a real assertion in the impl (checks only L0 rolled), but it doesn't distinguish stub vs impl because it's a negative. That's fine — it's checking the correct behavior. Not vacuous.

Hmm, "vacuous" as in "never reaches the code": fixtures. Let me check the fixtures.

`C55_OnTick` uses `now = <passed>`. The `Grind_LatticeOnTick` runs `TrackExtremes`. Since the test seam is active (tests set `g_grind_order_test_active`? Let me check.)

Actually — is `g_grind_order_test_active` true during tests? Let me look. `Adr162b_Reset` presumably sets it. And `C55_Reset` calls `Adr162b_Reset`. Let me see if there's a test setup. The prompt says the seam is used when `g_grind_order_test_active`. In Adr162b tests, presumably `g_grind_order_test_active = true`.

Hmm, hold on. In `C55_Reset`, it calls `Adr162b_Reset()`. Does that set `g_grind_order_test_active = true`? I can't see `Adr162b_Reset` (it's in fxgrind_tests_adr162b.mqh, not shown). I'll assume so.

Hmm, the "VC8 no roll yet" — first call. Expected no roll because extreme 1.20650 > level 1.20600. Real assertion. OK.

Let me look at VC11 more carefully:

```cpp
   ArrayResize(g_grind_long.layers, 7);
   C55_OnTick(D'2026.09.28 09:36');
   AssertTrue("VC11 reset below cap",
              !g_grind_vl_tracking_long && g_grind_vl_extreme_long == 0.0);
   Adr151_TestSetupLongLayer(g_grind_long, 7, 7, 1.20700, 7009UL, 0, 5.0);
   Grind_CarryTestSetOpenTime(7009UL, D'2026.09.28 09:50');
   Grind_LatticeTestAddTick(D'2026.09.28 09:45', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 09:55');
   AssertFalse("VC11 dip before re-cap ignored", Grind_VLHas(7001UL));
```

Hmm — after the resize to 7, the layers 0-6 remain. Adr151_TestSetupLongLayer adds layer 7 back? Let me think. `Adr151_TestSetupLongLayer(g_grind_long, 7, 7, 1.20700, 7009UL, 0, 5.0)` — sets up a layer. So now 8 layers. The newest is 7009 (open 09:50). The from_msc = max(newest+1, now-24h) = max(09:50:01, 09:55-24h) = 09:50:01.

Wait, but the tracking was reset (tracking_long = false). So it re-derives from. The newest open = max of all opens. 7009 open 09:50. Others open 09:00-09:06? Actually after Adr162b_SeedLong8, positions 7001-7008 open 09:00-09:07 (per C55_OpenTimes). Then we resize to 7, removing layer 7 (7008). Then add 7009 with open 09:50. So newest = 09:50. from = 09:50:01.

The tick at 09:45 < from → excluded. So the extreme = live price = 1.20700 (market seed). Level 1.20600. probe 1.20700 > 1.20600 → no roll. So "VC11 dip before re-cap ignored" passes.

Hmm — wait, but actually — would the tick at 09:45 be relevant? The dip at 09:45 was BEFORE the re-add. Since the re-add happened at 09:50, the dip is before the new cap episode. The design excludes it. OK.

Now, in commit 1 (stub), `Grind_LatticeTrackExtremes` does nothing, so extreme stays 0, TrySide uses live price 1.20700 → no roll. So "VC11 dip before re-cap ignored" passes. In commit 2, same. So vacuous? It's PASS in both states by design. It's checking a negative (no roll) that holds both ways. Not strictly vacuous — it's guarding against a future regression. OK.

Now — the prompt asks which B2 behaviour has NO test that fails without it. Let me identify.

Hmm — I think the "extreme folding of the live price" (`Grind_LatticeFoldExtreme` folds live) — is there a test that fails if the live fold is missing? Hmm.

Actually — let me look at a specific concern: VC3's exit clamp. The test asserts the exit is clamped to [1.20700, 1.20720]. If the roll didn't happen, the exit would be at the original price (1.20650?). Wait — SeedLong8's L0 exit is at 1.20650 (entry 1.20590? no...). Hmm. The prompt says the exit clamp moves the rolled exit (formula 1.20650) to ask + 1pt = 1.20701. Let me not overanalyze.

Hmm, what about this: the ROLL_STRANDED test VS1 sets `Grind_VLSet` for all 8 layers directly, then calls `Adr162b_TryLong(T0)`. But `Adr162b_TryLong` presumably calls TrySide with an extreme of... hmm. The prompt says TrySide added a "last parameter with a default". So `Adr162b_TryLong` calls TrySide without the extreme parameter → default 0.0 → probe = mkt. So VS1 tests the stranded path with the live market. OK.

Now the question — is there any B2 behaviour with no covering test?

Let me enumerate B2 behaviours:
1. Tick extreme computation. Tested (VC1, VC2).
2. Reading ticks (seam). Tested (VC3 etc.).
3. Live CopyTicksRange. NOT tested (no test reaches it; tests use the seam). So "the live read path" is untested.
4. Extreme folding across OnTicks. Tested (VC8).
5. Extreme reset below cap. Tested (VC11).
6. Extreme survives backoff. Tested (VC12).
7. Lookback cap. Tested (VC10).
8. Copy failure. Tested (VC9).
9. Stranded warn. Tested (VS1, VS2).
10. Closing stuck warn. Tested (VCS1, VCS2).
11. Carry pass interaction. Tested (LB40-LB43).
12. Stale extreme across refill. NOT tested (T-2).
13. Newest-open change detection. NOT tested (T-2, the missing logic).
14. The `Grind_LatticeCopyTicks` upper bound (`to_msc`) in live. Not tested.

Hmm, but the specific item 13 is a missing feature, not just untested.

The prompt asks: "Which B2 behaviour has no test that fails without it?" I think it's the LIVE read path (only the seam is tested). Also T-2 isn't tested.

Actually — one more: the `Grind_LatticeFoldExtreme` live fold. Is there a test that fails without it? Hmm. In VC3, the tick is 1.20590, the live ask is 1.20700. If the live fold didn't happen, the extreme would still be 1.20590 from the tick. Then roll to 1.20600. So the live fold isn't tested. Hmm. But the live fold matters when the extreme is UNSET (initially 0) and no tick is in range — then the extreme would stay 0 and TrySide uses the live price anyway (probe = mkt when extreme = 0). So the live fold doesn't change the outcome... unless the extreme is set from a past tick and the live price is more extreme. Example: past tick ask 1.20650 (not crossed), live ask 1.20580 (crossed). Without the live fold, the extreme is 1.20650, probe = min(1.20650, live 1.20580) — wait, the fold uses MathMin(extreme, live). If the live fold is skipped, the extreme stays 1.20650, and TrySide computes probe = MathMin(mkt=1.20580, extreme=1.20650) = 1.20580 → crosses. So the live price is used anyway via `mkt` in `probe`. So the live fold is redundant! Because `probe = MathMin(mkt, extreme)` already folds the live price.

Hmm — is the live fold in `Grind_LatticeFoldExtreme` redundant? Let me see. `extreme` is the fold of the tick history. `mkt` is the live price. In TrySide, `probe = MathMin(mkt, extreme)`. So the live price IS included. So why does `FoldExtreme` also fold the live price? 

Ohh — I see. The fold is useful ACROSS ticks: the extreme should persist. If the live price at tick T1 is 1.20580 and the market moves back to 1.20700 at T2, the extreme should still be 1.20580 (running min). Without the live fold, the extreme would be the min of tick-history reads only. But tick-history reads include the T1 tick... unless T1's tick wasn't in the history yet.

Hmm, actually. If the terminal's tick history lags (the current tick isn't in the CopyTicksRange result), then the live fold captures the current tick's price. So the live fold is a safety net for lag. OK. So it's not redundant across ticks.

Is there a test for the live fold? Hmm — VC8 folds 1.20650 from a tick, then 1.20595 from a tick. Both from the seam. No live fold tested. So "the live fold" has no test. And it's hard to test without a seam.

OK, so T-7: The live fold / live read path is untested. And T-2 is untested.

Let me also look for VACUOUS assertions — passing due to leftover state or unreached fixtures.

Hmm, let me look at `C55_OnTick`. It calls `Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now)`. So enabled = true, blocked = false. So no blocked path.

Hmm — Wait, VC1 calls `C55_Reset()` at start and end. But `C55_Reset` calls `Grind_LatticeTestTicksReset()`. And in VC1, no ticks are added. And also no `Grind_MarketTestSeed`. So `g_grind_market_test_active` might be leftover from a previous test? Actually `Adr162b_Reset` presumably resets the market. Hmm.

Let me look at the VC tests more critically. VC1 asserts `Grind_LatticeTickExtreme` (pure). No state involved. Not vacuous.

VC2 same. VC3-12 use C55_OnTick.

Hmm — let me look at the possibility that a test passes for the WRONG reason.

VC5: bid dip, ask 1.20610 > level 1.20600. So no roll. But is there another reason no roll happens? If the extreme computation were buggy and returned the bid (1.20580) for the long side, it would roll. So VC5 distinguishes bid vs ask. Good, non-vacuous.

Hmm — VC3 "exit clamped passive": `p >= 1.20700 - 1e-9 && p <= 1.20720 + 1e-9`. Wait, this checks `8001`'s price. If the roll didn't happen, `8001`'s price would be the un-rolled exit, which is... hmm, SeedLong8 sets up L0 (entry ?) and exits. What's the un-rolled exit? If the roll didn't happen, `8001` would be at its original exit (entry + 5 pips, clamped). Hmm — could it also be in [1.20700, 1.20720]? The prompt says the exit formula after roll is 1.20650, and the clamp moves it to 1.20701. Without the roll, the formula is based on the original entry. If the original entry is around 1.20600 and exit 5 pips → 1.20650, clamped to 1.20701. Wait, that's the same?! Hmm.

Actually wait, the prompt says: "the rolled exit 1.20650 is below the live ask 1.20700, so the passive clamp moves it to ask + 1 point (stops 0 in the seam) = 1.20701". And the level is 1.20600, exit_pips = 5.0 (from C55_OnTick's 5.0). So formula = 1.20600 + 5 pips = 1.20650. Clamped to 1.20700 + 1pt = 1.20701. Hmm.

If the roll didn't happen, the exit is the original: L0's entry + 5 pips. What's L0's entry from SeedLong8? The prompt's hand derivation suggests L0's original exit was already near the current ask. Hmm. Let me not dig. Actually, the assertion [1.20700, 1.20720] is a wide band. Without a roll, the exit might be at 1.20650 + something, or clamped to 1.20701 anyway. Hmm, this could be a weak assertion. But it's marked FAIL in commit 1 (stub), so it must differ. Wait — the prompt says it's FAIL in commit 1. Hmm, so with the stub (no roll), the exit is different. So the assertion does distinguish.

OK — actually wait, re-reading the promp: VC3's assertions are all FAIL in commit 1 except "VC3 one level only". So "VC3 exit clamped passive" fails with the stub — meaning without a roll, the exit is NOT in [1.20700, 1.20720]. So the exit is at its original passive-resting price. OK. Fine.

Now — let me hunt for VACUOUS assertions more carefully.

VS1:
```cpp
   Adr162b_SeedLong8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL);
   Grind_MarketTestSeed(1.19780, 1.19790, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   AssertTrue("VS1 one step no warn", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
```

Hmm — the VLs are set to 1.20600 - 0.001*i, so L0's VL = 1.20600, L7's = 1.19900. lowest_effective = 1.19900. Level = anchor - add_pips*... anchor = min effective = 1.19900. Level = 1.19900 - 10 pips = 1.19800. Stranded level = 1.19800 - 10 pips = 1.19700 (S=2 → (2-1)*10 = 10 pips). Market 1.19790: probe (mkt) = 1.19790. Crossed level 1.19800? For long, `mkt <= level + eps`: 1.19790 <= 1.19800 → yes. So idx = CandidateIndex → all layers have VL → -1. So MaybeStranded. Crossed stranded_level 1.19700? 1.19790 <= 1.19700 → no. So no warn. OK.

Then `Grind_MarketTestSeed(1.19690, 1.19700, 0, 0)`. TryLong(T0+1). mkt = 1.19690. Crossed 1.19700? 1.19690 <= 1.19700 → yes. Warn. OK.

Hmm — wait, `Adr162b_TryLong` calls TrySide with default extreme. But does it also handle the state? Let me assume it's a helper that calls `Grind_LatticeTrySide(g_grind_long, true, ...)`.

Hmm — but VS1 also sets `Grind_MarketTestSeed` which sets `g_grind_market_test_active = true`. This is used by `Grind_MarketAsk/Bid`. But in the TrySide code, `mkt = Grind_MarketAsk()` uses the seeded market. Good.

Wait, but there's an issue — `Adr162b_SeedLong8` probably seeds the market too. Then `Grind_MarketTestSeed(1.19780, 1.19790, 0, 0)` overrides. OK.

VCS1:
```cpp
   Adr162b_SeedLong8();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 9999UL;
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
```

Level = 1.20600 (initial). mkt = 1.20600. Crossed? long: 1.20600 <= 1.20600 → yes. idx = 0 (L0 has no VL). `exit_position_ticket = 9999 != 0` → NoteClosing. OK.

Hmm — but wait: after `Adr162b_TryLong(T0)` the FIRST call, is the latch set? `Grind_LatticeNoteClosing(is_long, pos=7001, now=T0)`: `closing_ticket_long != 7001` → set ticket = 7001, since = T0, warned = false. Then TrySide returns with closing_stop = true → no reset. So state: closing_ticket = 7001, since = T0.

Then `TryLong(T0 + 59)`. Now - since = 59 < 60 → no warn. OK.
Then `TryLong(T0 + 60)`. Now - since = 60 >= 60 → warn. OK.

`Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0)` — expects a warning. OK.

Then `TryLong(T0 + 120)`. warned = true → no new warn. `ArchiveFind(..., 1)` should be "". OK.

Then clears and rolls. Good.

VCS2:
```cpp
   Adr162b_SeedLong8();
   Grind_OrderTestRemove(8001UL);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   Adr162b_TryLong(D'2026.09.28 10:00' + 60);
```

L0 has exit_order_ticket = 8001 (from SeedLong8). Grind_OrderTestRemove(8001) removes it from the test records. Then `Grind_LatticeRollLayer` checks `!Grind_SelectOurOrder(8001, magic)` → true → returns GRIND_ROLL_CLOSING. TrySide: `rc == GRIND_ROLL_CLOSING` → NoteClosing. OK.

Hmm, wait — the flow: TrySide reaches `if(side.layers[idx].exit_position_ticket != 0)` — that's 0 here (no exit position). Then `Grind_LatticeRollLayer(...)`. Inside RollLayer:
```cpp
   if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;  // 0, skip
   if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(layer.exit_order_ticket, magic))
      return GRIND_ROLL_CLOSING;  // 8001 not selectable → returns CLOSING
```
Yes. OK.

Alright.

Now, VCS1 vs VCS2 — both test closing stuck. OK.

Let me look for genuinely vacuous assertions.

Hmm — LB40: `C55_SeedShort8Carry(1.19400, 1.19410)`. Hmm. It resets the carry, seeds the short 8, seeds a carry window, seeds a tick, sets positions and open times, and calls `Grind_CarryExitPassBegin`. Then `Adr162b_TryShort(T0)`. rc == 1 (one roll). OK.

Hmm, but LB40's assertions are PASS in commit 1. Actually the prompt says LB40, LB41 are PASS in both. So the roll itself is B1 behaviour (current price), not B2. LB40 checks the short roll inside a carry pass. B1 already handles short. So PASS.

Hmm — the prompt says the FAIL list includes LB42 (catch-up). LB43 too. OK.

Let me now think about test gaps more.

Actually — let me circle back on a specific concern: does any test rely on `Grind_LatticeTestAddTick` producing msc >= from_msc when `from_msc` is derived from `newest + 1` (seconds)? `Grind_LatticeTestAddTick(t, ...)` sets msc = (long)t * 1000. And from_msc = (newest + 1) * 1000. So comparisons work on seconds. OK.

**Now — let me look for other bugs.**

Look at `Grind_LatticeCopyTicks` seam:
```cpp
   if(g_grind_order_test_active) {
      if(g_grind_vl_test_ticks_fail)
         return -1;
      int n = 0;
      for(int i = 0; i < ArraySize(g_grind_vl_test_tick_msc); i++) {
         if(g_grind_vl_test_tick_msc[i] < from_msc)
            continue;
         ...
      }
      return n;
   }
```

It's a linear scan. OK for tests.

Now the live read:
```cpp
   MqlTick t[];
   const int n = CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc,
                                (ulong)Grind_MarketTimeMsc());
```

Hmm — `from_msc` could be 0 if the tracking was never set up. But `Grind_LatticeTrackOneSide` sets `from` before calling. So from > 0. OK.

But if `g_grind_market_test_time_active` is true (test seam for time), and we're in production... no, that's test-only. Hmm.

Wait — `Grind_MarketTimeMsc()` uses the test seam if `g_grind_market_test_time_active`. In production this is false. OK.

Hmm — actually, a potential issue: `Grind_MarketTimeMsc()` returns `(long)SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)`. If SYMBOL_TIME_MSC returns 0 (not available for the symbol?), then `to_msc` = 0, and CopyTicksRange [from, 0] would fail (from > to) → returns -1 or 0. The code handles n<0 by returning. If n == 0, fold with live price. Either way OK. But does SYMBOL_TIME_MSC work on all symbols? Documented. OK.

**Now let me think about the "extreme used in the unsafe direction" once more.**

The design's key assumption: the extreme is a proxy for "the level was crossed". But the extreme is folded from ticks from `newest_open + 1 sec` to now. If a tick's ask (long) was below the level, the roll is triggered. Since we test `probe = min(mkt, extreme) <= level`, and `extreme` is the min ask over the window, if that min ask <= level, then indeed the ask was <= level at some point, so a buy limit at `level` (well, at the current level, which may differ) could have filled.

Hmm — but subtle: the level used in the check is the CURRENT level. The extreme is the min ask over the whole window. Suppose the min ask occurred at a time when the LEVEL was different (e.g., before some rolls). Then the extreme might cross the current level, but the market at that time was already below... hmm, no. If the min ask over the window <= current level, then at some point the ask was <= the current level. So the current level WAS crossed. That's true regardless of when.

Hmm — actually, the current level changes as rolls happen. If the roll of L0 changes the level from 1.20600 to 1.20500 (next level), and the extreme is 1.20590, then the check on the new level 1.20500 is 1.20590 > 1.20500 → no further roll. OK.

So the semantics are: "was the current level at any point crossed since the window started". Reasonable.

But — the "window" is `newest_open + 1 s` to now. The newest open is the DEEPEST layer's open (the last one added). Levels deeper than the newest layer's level were crossed BEFORE the newest layer opened (since we only add a layer when the ask reaches it). Hmm — wait, no. The current level is the NEXT level (deeper by add_pips). The newest layer opened at its own level X. The next level is X - add_pips. So a tick with ask <= X - add_pips is what we want. These ticks occur AFTER the newest layer opened (since the market must move from X down to X-add). So the window from newest_open+1 is correct! Because we only care about ticks after the newest layer opened. Before that, the market was above the current level (mostly).

Hmm, but what if the market spiked down below X-add and back up to X before the newest layer filled? E.g., the market oscillated. Sequence: ask = 1.20500 (below level 1.20600), we roll; then market rises to 1.20600, we add a layer; then market drops back. Hmm. So the newest open's window excludes the earlier dip. But B1 would have caught it (the roll happened at that earlier time). OK.

Hmm, actually — one concern: after the roll closes the oldest layer and a new layer is added (via an exit fill), the newest open changes. The window restarts from the new newest open. But the CODE doesn't restart the window (T-2 bug). So this is tied to T-2.

OK.

**Now — let me look at the ROLL_STRANDED computation once more.**

```cpp
   const double stranded_level =
      Grind_Normalize(Grind_AddTargetPrice(level,
                                           (GRIND_VL_STRANDED_STEPS - 1) * add_pips, _Point,
                                           is_long ? 1 : -1));
```

Wait — for a long: `Grind_AddTargetPrice(anchor, add_pips, point, direction=1)` returns `anchor - 1*add_pips*point*10`. So `level = anchor - add`. And `stranded_level = Grind_AddTargetPrice(level, (S-1)*add_pips, point, 1) = level - (S-1)*add = anchor - add - (S-1)*add = anchor - S*add` (S=2). So stranded_level = anchor - 2*add. The market must be 2 add steps beyond the anchor.

Hmm, but the prompt says "When every layer is rolled and the LIVE market is 2 add steps beyond the lowest effective level". The check `Grind_LatticeLevelCrossed(is_long, mkt, stranded_level)` = `mkt <= stranded_level`. So mkt <= anchor - 2*add. Right.

Hmm — and the S=2 means "2 add steps beyond the lowest effective level". OK.

**Now — let me double-check the GIVENS against the code once more.**

Actually, wait. G3 says "Below cap, every B2 variable of that side is reset." Let me re-examine. The variables for long: tracking, extreme, from_msc, stranded_warned, closing_ticket, closing_since, closing_warned. The code resets all 7. VERIFIED.

Hmm — but there's a subtlety: `Grind_LatticeResetBackoff` resets ALL variables (regardless of side). And the tracking code resets per side. OK.

**Let me re-examine the actual code for `Grind_LatticeTrackExtremes` signature.**

```cpp
void Grind_LatticeTrackExtremes(const ulong magic, const int max_layers, const datetime now)
{
   Grind_LatticeTrackOneSide(g_grind_long, true, magic, max_layers, now);
   Grind_LatticeTrackOneSide(g_grind_short, false, magic, max_layers, now);
}
```

And `Grind_LatticeOnTick`:
```cpp
   Grind_LatticeTrackExtremes(magic, max_layers, now);
```

OK.

**Now — is there any issue with `Grind_LatticeTrackOneSide` mutating state when the side is empty?**

If depth < max_layers, reset and return. OK.

**Now — let me think about the `now` parameter.**

`Grind_LatticeOnTick` receives `now = TimeCurrent()` (from OnTick in fxgrind.mq5). TimeCurrent returns the current SERVER time (from the last tick), in seconds. The window bound `now - GRIND_VL_CATCHUP_MAX_SEC = now - 86400`. And `newest + 1`. Both in seconds. OK.

But `Grind_MarketTimeMsc()` returns `SYMBOL_TIME_MSC`, which is the current tick's msc. Hmm — if `TimeCurrent()` and `SYMBOL_TIME_MSC` disagree (e.g., a tick is delayed), the window is still in seconds from TimeCurrent, and the tick read is up to SYMBOL_TIME_MSC. OK.

Hmm — a concern: at a restart, `now = TimeCurrent()` on the first tick. The window `now - 86400` is the lower bound. OK.

**Now — let me look at whether the extreme can be WRONG because of `MathMin` order.**

`probe = MathMin(mkt, extreme)` for long. Both are asks. OK.

Hmm — but `extreme` for long is a min of ASKS. And `mkt` is the live ask. So probe is the min of asks. OK.

For short, `probe = MathMax(mkt, extreme)` where mkt is the live bid and extreme is the max of bids. OK.

Wait — in `Grind_LatticeFoldExtreme`:
```cpp
   const double live = is_long ? Grind_MarketAsk() : Grind_MarketBid();
   if(live > 0.0) {
      if(extreme <= 0.0)
         extreme = live;
      else if(is_long)
         extreme = MathMin(extreme, live);
      else
         extreme = MathMax(extreme, live);
   }
```
Yes, correctly folds the live price. OK.

**Let me look for a potential issue with array bounds/uninitialized values.**

`Grind_LatticeTickExtreme`: `extreme_out` is read before being written when `!found` is true (short-circuit). So `if(!found || ask[i] < extreme_out)` — if !found, don't read extreme_out. Good. But there's a subtlety: `found` is set on the first qualifying tick. On the first iteration, if ask[i] > 0, `!found` is true → set extreme_out = ask[i]. OK.

**Hmm — I want to double-check something about `Grind_LatticeTrySide` and the extreme param.**

```cpp
int Grind_LatticeTrySide(GrindSideState &side, ..., const double extreme = 0.0)
{
   ...
   const double probe = extreme > 0.0 ? (is_long ? MathMin(mkt, extreme) : MathMax(mkt, extreme)) : mkt;
```

If `extreme > 0`, use min/max. So the extreme is used only for the crossing test. The stranded check uses mkt. Good.

**Now — let me think about a specific issue: the extreme persists after the roll.**

After a roll, the extreme is NOT cleared. So the next iteration of the TrySide loop uses the SAME extreme for the next level. Is that correct? Yes — because the extreme represents the min ask over the window, and we want to check if the next (deeper) level was crossed. Since the extreme is the min ask, if it's <= the next level, we roll. OK. And this is by design (VC7).

But — should the extreme be cleared after the roll? No, that's the design (running extreme since cap).

Hmm — but after a roll, the layer's exit is re-priced. The roll itself doesn't extend the window. OK.

**Now — let me look at a potential issue with `Grind_LatticeRollLayer` and the extreme.**

The extreme triggers a roll of the exit to a level. The exit is computed at `Grind_ExitPrice(level, exit_pips, ...)`. The clamp moves it to the market. This is the "clamped roll". OK. But the design says "a level traded through when a roll was held off rolls afterwards even if the market has come back". So the roll is intentional.

**Now — let me look at an IMPORTANT issue: the extreme is a MIN of ask over the WINDOW. But the window starts 1 s after the newest open. The newest open is the LAST layer added. But layers can be REMOVED (rolled exits filling, or normal exits filling). When a layer is removed, the newest layer might change.**

For example, L7 (the newest) is removed because its exit filled. Now L6 becomes the newest. The window start `from` was set at L7's open. Now we'd want to restart from L6's open (which is OLDER). But the code doesn't restart. So the window is too SHORT (from L7, which is later than L6). Wait, L6 opened BEFORE L7. So restarting from L6 would include MORE ticks (an earlier start). The window from L7's open is a subset. So we'd miss ticks between L6's open and L7's open. Hmm. Is that unsafe?

For a long side: L6 opened at a higher ask; L7 opened at a lower ask. Ticks between L6 open and L7 open were between L6 and L7 prices, which are ABOVE L7's level. Ticks after L7's open could dip below. So excluding ticks between L6 and L7 open doesn't miss anything relevant (the next level is below L7's level). Unless the market dipped below L7's level before L7 filled, then came back up to fill L7. Possible. But rare.

Hmm. Also — when the newest layer changes, the window start should be RE-derived. The B1 code (which rolls based on current price) is unaffected. But the extreme computation should ideally use the newest layer's open. If the newest layer is removed (its exit filled), the newest open becomes earlier. Hmm. So the code should re-derive.

This is a variant of T-2. Actually — the design A4 says "a side's newest position open time is available... At cap depth cannot grow, so the newest open fixes the start of the side's window with no GV". But depth can DECREASE at cap (a layer is removed). Then grow again. The design assumes the newest open is stable at cap. But it changes when layers are removed and re-added. The prompt's T-2 says "Same question for a restart with a different book." And the general T-2.

OK.

**Now — let me think about T-3 blocking more.**

Actually — hmm. I realize there might be a worse issue. Every OnTick at cap calls CopyTicksRange. In the steady state, the range is [last_msc+1, current_msc]. But the terminal's tick history might have a LIMITED retention. If the terminal only retains ticks for, say, 30 minutes, and our cursor `from` is older than that, `CopyTicksRange` returns only the ticks it retains (from max(from, oldest)). Wait — it returns ticks >= from_msc. If from_msc is older than the oldest retained tick, it returns from the oldest retained. Then we advance to the last. So no problem.

If the terminal doesn't retain 24 h... then the "24 h" bound is a no-op, and we get whatever the terminal keeps. Not a correctness issue.

Hmm.

**Now — let me think about a serious issue: the `from` cursor and the test for the FIRST call.**

Look at `Grind_LatticeTrackOneSide`:
```cpp
         g_grind_vl_from_msc_long = MathMax((long)(newest + 1) * 1000,
                                            (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000);
```

Hmm — `(long)(newest + 1) * 1000`. `newest` is a datetime (seconds). `(newest + 1) * 1000` = the msc of the second after newest. The design says "the window starts 1 s after the side's newest position open". OK.

But `newest` is the position's `POSITION_TIME`, which is the SERVER time in seconds. The tick's `time_msc` is also server time in ms. So the comparison is consistent. OK.

Hmm — but is `POSITION_TIME` truncated to seconds, so the actual fill could be anywhere in that second. Starting at `newest+1` excludes the fill's second. OK, conservative.

**Let me look at another potential issue: `now - GRIND_VL_CATCHUP_MAX_SEC` when `now` is small.**

At a restart, `now = TimeCurrent()`. If `now < 86400` (before 1970+1 day)? No, epoch is 1970. So fine.

**Now — let me examine the `Grind_LatticeResetClosingState` interaction with `Grind_LatticeMaybeStranded`.**

Hmm — in TrySide, after the loop, `if(!closing_stop) Grind_LatticeResetClosingState(is_long);`. And the stranded latch is cleared at the top when there's a candidate. OK.

**Now — the `PREMISE VERDICT` and `TEST GAPS`.**

Let me now check whether with the lattice OFF, any B2 code runs. `Grind_LatticeOnTick` returns immediately if !enabled. So no. But — hmm, `Grind_LatticeTestTicksReset` and `Grind_LatticeTestAddTick` are defined in grind_engine.mqh. These are test helpers. They don't run unless called. OK.

But wait — `Grind_LatticeResetBackoff` now calls `Grind_LatticeTestTicksReset()`. Is `Grind_LatticeResetBackoff` called in production? Let me search. Hmm — from the prompt A5: "Grind_LatticeResetBackoff is called by the B1 test reset (Adr162b_Reset)". So only tests. OK. So no production impact.

Hmm — actually, is `Grind_LatticeResetBackoff` called anywhere else? Let me search the shown code... I don't see calls to it. OK.

**Let me now think about a subtle bug in `Grind_LatticeMaybeStranded` and the `lowest` computation.**

```cpp
   const double lowest = Grind_LatticeLowestEffective(side, is_long);
```
`Grind_LatticeLowestEffective` returns the min (long) / max (short) effective entry. The prompt calls it "lowest effective level". For a long side, all layers rolled, so effective = VL. The lowest VL. OK.

But the detail includes `"lowest_effective": <lowest>` and `"market": <mkt>`. OK.

Hmm — the prompt's example detail: `{"side":"L","depth":8,"rolled":8,"lowest_effective":1.19900,"market":1.19700,"steps":2}`. So lowest_effective = 1.19900, market = 1.19700, steps = 2. OK. But wait — the check is `mkt <= anchor - 2*add` where add = 10 pips = 0.00100. anchor = 1.19900. anchor - 2*0.001 = 1.19700. So mkt = 1.19700 exactly. `Grind_LatticeLevelCrossed` uses `<=` with eps. OK.

**Now — the LEVELS test: VS1's stranded level.**

Hmm. In VS1, the market is seeded to 1.19790 first (no warn), then 1.19690 (warn at bid 1.19690... wait, ask = 1.19700). The check uses `mkt = Grind_MarketAsk()` for long = 1.19700. Indeed 1.19700 <= 1.19700 → warn.

OK.

**Now — let me examine the interplay of B2 with `Grind_LatticeCountRolled`.**

Hmm, `Grind_LatticeCountRolled` counts layers with a VL. In VS1, all 8 have a VL. So rolled = 8. OK.

**Now let me consider what the prompt is REALLY asking for: "lookahead bias, silent failures, schema mismatches, statistical flaws".**

Let me search for issues in that vein.

1. **Silent failure**: `Grind_LatticeCopyTicks` returns -1 on failure; caller silently retries. Design accepted (GD6). But — the failure is silent: if the terminal NEVER provides ticks (a permanent failure), B2 quietly runs as B1 forever. The prompt notes this is a deploy precondition. That's a "silent failure" but by design.

   Hmm — but there's a subtler silent failure. In `Grind_LatticeTrackOneSide`, when `n < 0`, we `return`. But the tracking state (`tracking_long`, extreme) is left as-is. If we were mid-tracking, the extreme is retained. Next tick, retry. So the extreme could become STALE (from a long time ago) if the read fails for a long time. Then when the read succeeds, the extreme is folded. Hmm, but the cursor never advanced, so the read would return the same ticks. OK.

   Actually — if the read fails for, say, an hour and then succeeds, the read returns all ticks from `from` to now — which is the hour's worth. Folded. OK.

2. **Schema mismatch**: `Grind_ArchiveMarker("WARN", "ROLL_STRANDED", is_long ? "L" : "S", 0, detail)`. The detail has fields. The pipshed banner allow-list doesn't include these codes — that's C56. So the WARNs are emitted but the banner ignores them. Is this a "schema mismatch"? The prompt says C56 adds them. OK.

   Hmm — the `Grind_TelemetryEmit(g_grind_telemetry_instance, "ROLL_STRANDED", detail)`. Let me check the signature — `Grind_TelemetryEmit(instance, code, detail)`. And `Grind_ArchiveMarker(level, code, key, ticket, detail)`. The WARNs use `Grind_ArchiveMarker("WARN", <code>, is_long ? "L" : "S", ticket, detail)`. So level="WARN", code, key=side, ticket=0 or position. Hmm — the "key" field is the side. And for SESSION_CANCEL_STUCK, the pattern is `Grind_ArchiveMarker("WARN", "SESSION_CANCEL_STUCK", key, 0, detail)`. So the pattern matches. OK.

3. **Lookahead bias**: The extreme uses ticks up to the current tick. That's not lookahead. The `from` bound excludes before the newest open. OK.

   Hmm — but the test seam `Grind_LatticeCopyTicks` reads ALL test ticks with msc >= from_msc, regardless of `to_msc`. So a test tick with msc > now would be included. In production, the `to_msc` bound excludes future ticks. So the test seam is more permissive. But that's tests.

   Wait — a REAL lookahead concern: in production, `to_msc = Grind_MarketTimeMsc()`. Which is the CURRENT tick's msc (from SYMBOL_TIME_MSC). If SYMBOL_TIME_MSC reflects the latest tick's time. So it should be the current time. No lookahead. But if SYMBOL_TIME_MSC is somehow AHEAD (e.g., the broker's server time)? No, it's the tick's time. Hmm.

4. **Statistical flaws**: n/a.

Hmm — let me look at one more thing. The `Grind_LatticeFoldExtreme` folds the LIVE price even when `n == 0` (no ticks in range). Good. But it folds the live price at the time of the TRACKING call, which is BEFORE the `blocked` check and BEFORE TrySide. So the live price is the current tick's price. OK.

**Let me look for a possible issue with `Grind_LatticeTrackOneSide` and the live fold when the extreme should reset.**

Hmm.

OK, let me now also carefully examine:

**The `Grind_LatticeTrackOneSide` cursor advance and the same-msc concern.**

```cpp
      if(n > 0)
         g_grind_vl_from_msc_long = msc[n - 1] + 1;
```

`msc[n-1]` is the LAST tick in the returned array. But is the array sorted by msc? CopyTicksRange returns ticks in chronological order (ascending msc). I believe so. So msc[n-1] is the newest. OK.

But — in the SEAM, the array is in insertion order, which the tests control. In VC9, the tick at 09:30 is inserted. OK. The seam copies in insertion order. So if the tests insert ticks out of order, msc[n-1] would be wrong. But tests insert in order. OK.

**Hmm — what about `Grind_LatticeCopyTicks` returning n=0 but the terminal returns ERR?** If CopyTicksRange returns 0 (no ticks in range), n = 0. The code checks `n < 0` → no. So it folds live only. And doesn't advance the cursor. OK.

**Now — a REAL issue I want to check: the extreme is folded with the LIVE price on EVERY tick. So even if the tick history is empty, the extreme tracks the live min. But over time, the live fold accumulates. So the extreme = min over all live prices seen since... wait, when does the extreme reset?**

It resets only when the side drops below cap. So the extreme = min of (tick history from window start) and (live price at each OnTick since tracking). Hmm — the live fold happens on every OnTick. So the extreme is a running min over the live prices seen. That's a legitimate "extreme" (subsampled at OnTick frequency). OK.

**Now — let's think about the specific question in T-2: "Same question for a restart with a different book."**

At restart, tracking = false. Re-derive. from = max(newest+1, now-24h). If the book at restart is different (e.g., the positions are from a prior session, opened long ago), the window is bounded by 24 h. A tick from within the last 24 h that crossed a level would roll. Is that correct? The design says yes (catch up from 24 h). But at restart with a different book, the "newest open" could be from before the restart. The 24 h window catches up. Hmm. Could it roll based on a tick from 20 h ago when the level was crossed, but the current market is elsewhere? Yes — by design (extreme). So a roll on restart. That's the intent.

Hmm.

**Now let me look at a potential issue with `Grind_LatticeRollLayer` being called from the extreme-triggered path.**

The roll re-prices the exit to `formula = Grind_ExitPrice(level, ...)`. The clamp moves it to the market if it's not passive. So the roll is "clamped to the market". And `Grind_CarryRecordShift(pos, price - formula, true)` records the shift. And then `Grind_ExitQManageSide` is called — which RE-EVALUATES the side and may place/cancel exits. Hmm — `Grind_ExitQManageSide` recomputes ranks and may promote/cancel exits. This could interact with the Just-rolled exit. Hmm. Let me look:

```cpp
   Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);
   return GRIND_ROLL_OK;
```

`Grind_ExitQManageSide` iterates layers; for layers where the exit isn't required (rank not allowed), it cancels. For layers where the exit is required and missing, it places. So after a roll, this re-evaluates. Since the roll modified the exit of the candidate, and the candidate's rank might have changed (the effective entry changed), the queue might CANCEL the exit we just modified! Hmm — could that undo the roll?

Hmm, in the K=1, H=0 queue, only rank 0 and the highest rank resting. After a roll, the candidate's effective entry changes (lower VL for long → the entry moves down). The rank changes. If the new rank's exit is no longer required... hmm. This could cancel the exit. Hmm — is that a bug? Well, the exit would then be re-placed later. This is B1 behavior (RollLayer calls ExitQManageSide). Not new to B2. OK.

**Now let me consider `Grind_LatticeTrySide` and the multi-iteration roll.**

Each iteration calls `Grind_LatticeCandidateIndex(side, is_long)` which returns the best unrolled layer. After a roll, that layer now has a VL, so the next iteration picks the next. So each iteration rolls a different layer. And the level is recomputed each iteration (from the new effective entries). OK.

But — the `level` is recomputed each iteration. After rolling L0 to level 1.20600, the next level is computed from the effective entries. Since L0's VL is now 1.20600 (the highest), the min effective is still the other layers (L7's entry?). Hmm. The level = anchor - add. anchor = min effective. If L0's VL is 1.20600 and other layers are at their entries... For long, the levels go DOWN. L0's entry is the highest, L7's the lowest. min effective = min of (L7's entry, L0's VL 1.20600, ...). If L7's entry is around 1.19900, then min = 1.19900 → level = 1.19800. Hmm, that would roll the deepest layer next, not L1.

Hmm — wait, the roll picks the OLDEST unrolled layer (per the design note "CORRECTION (Claude): the layer left behind is the OLDEST unrolled layer (the roll candidate)"). Let me check `Grind_LatticeCandidateIndex`:

```cpp
int Grind_LatticeCandidateIndex(const GrindSideState &side, const bool is_long)
{
   const int n = Grind_SideDepth(side);
   int best = -1;
   for(int i = 0; i < n; i++) {
      const ulong ticket = side.layers[i].position_ticket;
      if(ticket == 0) continue;
      if(Grind_VLHas(ticket)) continue;
      if(best < 0) { best = i; continue; }
      const double e = side.layers[i].entry_price;
      const double be = side.layers[best].entry_price;
      if(is_long) {
         if(e > be || (e == be && side.layers[i].layer_index < side.layers[best].layer_index))
            best = i;
      } else {
         if(e < be || (e == be && side.layers[i].layer_index < side.layers[best].layer_index))
            best = i;
      }
   }
   return best;
}
```

So for long, it picks the HIGHEST entry (the shallowest/topmost layer). That's the "oldest unrolled layer" (L0 has the highest entry). OK. So the roll picks the highest-entry layer. After rolling it, the next highest. So levels go DOWN one add step at a time. Good.

Hmm — but the LEVEL computation uses `Grind_ComputeAddTarget` which for any_vl uses the MIN effective. Hmm, that's the deepest effective. So level = deepest_effective - add. So the level is one add step below the deepest rolled. Rolling the highest unrolled layer to that level. Hmm — so the layer is re-priced DOWN to the deepest-adjacent level. OK.

This is B1 behavior. Not new.

**Hmm — this suggests a potential issue with B2: the extreme might NOT cross the level.**

Let's see: after the initial roll, level = 1.20500 (one add below the deepest? no). Hmm — let me re-check. In VC3, the level is 1.20600 (not 1.19800). So `Grind_ComputeAddTarget` with any_vl = false (initially no layers rolled) uses the deepest layer's entry as the anchor. So level = deepest_entry - add. Hmm. So the level 1.20600 = deepest_entry (1.20700?) - 10 pips = 1.20600. So the deepest entry is 1.20700. Hmm — but Adr162b_SeedLong8 sets up L0-L7. The deepest layer (L7) has entry 1.20700? And the levels go from 1.20700 - 0.001 = 1.20600. OK.

So the initial level is 1.20600. Rolling L0 (highest entry, maybe 1.21400?) to 1.20600. Then any_vl = true. anchor = min effective = deepest layer's entry (1.20700, since no VL) vs L0's VL (1.20600). min = 1.20600. So level = 1.20500. Roll the next highest. Etc. Hmm — OK.

Anyway, this is B1. Not new.

**Let me now think about the T-1 answer more carefully.**

Concern: "ticks sharing one `time_msc` (the cursor is `last msc + 1`: can a tick at the same msc arrive after the read and be skipped?)".

Answer: Yes, a tick with the same msc arriving after the read would be skipped. But:
- If it's a duplicate of an already-read tick, no issue.
- If it's a NEW tick (e.g., a different price at the same ms), skipping it could miss a price. But the direction: skipping a lower ask (long) means missing a potential roll → safe. Skipping a higher ask → not relevant. So the same-msc skip is safe.
- In practice, MT5 tick history might not have multiple ticks in the same millisecond, or if it does, they'd be in the same CopyTicksRange batch.

Hmm — I recall that MQL5's `time_msc` can indeed have multiple ticks in the same ms, and CopyTicksRange returns all of them in one call. So no skip within a batch.

Hmm — but the CONCERN: after reading up to msc X, a new tick arrives with msc X (same ms, later in real time). The cursor is X+1. So it's excluded. Missed. Direction-safe.

OK. So T-1 = HOLDS.

Actually — hold on. What about a subtle issue: after reading [from, now_msc], the cursor is `last_msc + 1`. But `now_msc` might be LESS than `last_msc`? No, sorted ascending.

But — what if the last returned tick's msc > now_msc? Can't, since `to_msc = now_msc` and the range is inclusive. So last <= now_msc. OK. So the cursor <= now_msc + 1. Fine.

Hmm — except the terminal might have ticks with msc slightly AHEAD of SYMBOL_TIME_MSC? No.

**One more thing — the `.time_msc` type.** In MqlTick, `time_msc` is `long`. In the array, we assign `(long)t[i].time_msc`. OK.

**Let me now consider potential issues with the WARN detail formats.**

`Grind_LatticeNoteClosing`:
```cpp
         const string detail =
            "{\"side\":\"L\",\"ticket\":" + IntegerToString((long)pos) +
            ",\"stuck_s\":" + IntegerToString(GRIND_VL_CLOSING_WARN_SEC) + "}";
```
Hmm — `stuck_s` is hardcoded to 60, not the actual elapsed seconds. The design says the detail is `{"side":"L","ticket":7001,"stuck_s":60}`. So it's by design (constant). Hmm — but if the warning fired at 65 s, it would still say 60. Minor. Not a bug.

`Grind_LatticeMaybeStranded` detail uses `Grind_ArchiveJsonDouble(lowest, 5)`, `mkt`, etc. OK.

**Now, the WARN emission: `Grind_TelemetryEmit(g_grind_telemetry_instance, "ROLL_STRANDED", detail)`.** Is `g_grind_telemetry_instance` the right variable? Yes.

Hmm — wait, the prompt says for the WARNs: `Grind_TelemetryEmit(g_grind_telemetry_instance, <code>, detail);` — let me check the signature of Grind_TelemetryEmit. It's `Grind_TelemetryEmit(instance, code, detail)`. Yes, from `Grind_EjectReport`:
```cpp
void Grind_EjectReport(const string code, const ulong ticket, const string detail)
{
   Grind_TelemetryEmit(g_grind_telemetry_instance, code, detail);
   Grind_ArchiveMarker("INFO", code, "", ticket, detail);
}
```
Yes. OK.

**Now — an interesting one. Does the ROLL_STRANDED WARN fire on a HEALTHY book where all layers are rolled but the market moves 2 steps beyond in a NORMAL trend?**

Hmm — after all layers are rolled, the side is at cap with no candidates. So TrySide reaches `idx < 0`. If the market is 2 add steps beyond the deepest effective, warn. This happens in a normal trend after all layers are rolled and the market continues. So it WILL fire in a normal strong trend. Is that "spurious"? The design says the WARN asks the operator to investigate (it may be a fault or a trend). So it fires on trends. That's intended. Not spurious.

Hmm, but the prompt asks "fire on a healthy book (a normal CloseBy of a few seconds; a side that is stranded only on the extreme)". "A side that is stranded only on the extreme" — the stranded check uses the LIVE market, not the extreme. So the extreme can't make it fire. OK — that's what G4 says. So a side with an extreme that's far away but a live market near the grid won't fire. OK.

Hmm — but wait. Can the stranded check fire when the side is NOT actually stranded because of the extreme? No — it uses `mkt` (live). OK.

Hmm — but hold on. `Grind_LatticeTrySide` reaches `idx < 0` only if `Grind_LatticeLevelCrossed(is_long, probe, level)` for the level. And `probe` uses the extreme. So the check enters the loop only if the EXTREME crosses the level. Then idx < 0, and MaybeStranded checks the LIVE market against stranded_level. So the "reaches the stranded check" condition depends on the extreme, but the "warn" condition depends on live. Hmm. So if the extreme is far but the live market is 2 steps beyond (in the same direction), the extreme would definitely cross the level too (since far in the same direction), so we'd reach the check. OK. So no missed stranded warn.

Conversely, if the live market is 2 steps beyond but the extreme is NOT THAT far... hmm, if the market IS 2 steps beyond now, then the extreme (min ask for long, over the window) is at most the current ask, so the extreme <= current ask = mkt. So probe = min(mkt, extreme) = extreme <= mkt. If mkt is 2 steps beyond (mkt <= stranded_level), then extreme <= mkt <= stranded_level. And level = stranded_level + add. So extreme <= level. So the loop enters. OK.

So the stranded warn can't be missed due to the extreme. And it fires on live. OK.

**Now let me scrutinize the "PASS in both states" list once more. The prompt asks me to list them in the report.** OK.

**Now — T-7: "Does any assertion pass vacuously (inside an if, on leftover state, on a fixture that never reaches the code)?"**

Let me look for tests that don't reach the intended code.

Hmm — VC5. The tick is at 09:30 with bid 1.20580, ask 1.20610. The window from 09:07:01. The tick is included. Extreme = 1.20610. Level = 1.20600. probe = min(1.20700, 1.20610) = 1.20610 > 1.20600 → no roll. So the assertion "no roll" is because the ASK didn't dip. Correct.

But — here's a thought: does the assertion distinguish "ask vs bid" handling? If the code wrongly used the bid for a long extreme, the extreme would be 1.20580 <= 1.20600 → roll. So VC5 catches that. Good.

Hmm — but wait. The test's assertion is "no roll". If the code has a bug where NO rolls ever happen (e.g., the extreme is never used), VC5 would still pass. So VC5 alone is weak, but paired with VC3 it's meaningful.

OK, now let me look for a fixture that "never reaches the code".

Hmm — VC12's first call: `g_grind_order_test_send_ok = false`. This makes the modify fail. Then `AssertTrue("VC12 first attempt failed", g_grind_order_test_modify_calls == 1 && !Grind_VLHas(7001UL))`. So the roll attempt happened (modify called) but failed. OK.

Hmm — but does `Grind_ModifyPendingPrice` get to the modify? `Grind_LatticeRollLayer` calls `Grind_ModifyPendingPrice(layer.exit_order_ticket, price, magic)`. `Grind_ModifyPendingPrice` first calls `Grind_SelectOurOrder(ticket, magic)`. If the order isn't found, returns false without a modify. In the test, is 8001 selectable? SeedLong8 sets up orders. Hmm — `Adr162b_SeedLong8` presumably registers the exits in the test order records. So 8001 is selectable. OK. Then the modify is attempted and fails (send_ok = false). So modify_calls == 1. OK.

Hmm — but wait, VC12's assertion says `g_grind_order_test_modify_calls == 1`. If a previous test left the counter non-zero... C55_Reset → Adr162b_Reset → Grind_OrderTestReset? Probably. OK.

Hmm — let me look for possible leftover state. `C55_Reset` calls `Adr162b_Reset()`, `Grind_CarryTestReset()`, `Grind_CarryGateReset(...)`, `Grind_LatticeTestTicksReset()`. Does `Adr162b_Reset` reset `g_grind_order_test_*`? Probably (it's the B1 reset). I'll assume yes.

**Now — a possible VACUOUS test: VCS1's "VCS1 rolls when clear".**

```cpp
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[0].exit_order_ticket = 8001UL;
   const int rc = Adr162b_TryLong(D'2026.09.28 10:00' + 121);
   AssertEqInt("VCS1 rolls when clear", rc, 1);
```

The layer now has exit_order_ticket = 8001 (registered? maybe not). If 8001 isn't in the test records, `Grind_SelectOurOrder(8001)` fails → RollLayer returns CLOSING, rc = 0. Then the assertion fails. Hmm. But the prompt says it's PASS in both states. So 8001 must be selectable. Hmm — but wait, the order was never removed. In SeedLong8, the exits are at 8001-8008. So 8001 is registered. After VCS1 set `exit_order_ticket = 0; exit_position_ticket = 9999`, then later restored `exit_order_ticket = 8001`. So it's still in the records. So the roll succeeds. rc = 1. OK.

Hmm — but the market at T0+121 is 1.20590/1.20600. Level = 1.20600. mkt = 1.20600. Crossed. idx = 0. exit_position = 0. RollLayer: exit_order 8001 selectable. Modify succeeds (send_ok restored? In VCS1, send_ok defaults true). So rc = ROLL_OK = 0. Wait — `GRIND_ROLL_OK = 0`. And `rc` returned from TrySide is `rolled_count` = 1. So rc = 1. OK. Good.

OK.

**Now let me look at LB41 more carefully.**

```cpp
   C54_SeedLong8Carry(1.20180, 1.20190);
   const int rc = Adr162b_TryLong(D'2026.09.28 10:00');
   AssertTrue("LB41 five rolls mid-pass", rc == 5 && g_grind_carry_exit_pass_active);
```

Hmm — 5 rolls. Because the market (ask 1.20190?) crosses 5 levels? Hmm. `C54_SeedLong8Carry(1.20180, 1.20190)` — market 1.20180/1.20190. The levels: starting at 1.20700-ish? Hmm, this uses C54's seed which has different entries maybe. Five rolls means 5 levels crossed by the current ask. OK. Not my concern.

**Now — let me think about whether the implementation matches the spec exactly for the WARN detail.**

Spec: ROLL_STRANDED detail `{"side":"L","depth":8,"rolled":8,"lowest_effective":1.19900,"market":1.19700,"steps":2}`.

Code:
```cpp
   const string detail =
      "{\"side\":\"" + (is_long ? "L" : "S") + "\",\"depth\":" + IntegerToString(depth) +
      ",\"rolled\":" + IntegerToString(rolled) +
      ",\"lowest_effective\":" + Grind_ArchiveJsonDouble(lowest, 5) +
      ",\"market\":" + Grind_ArchiveJsonDouble(mkt, 5) +
      ",\"steps\":" + IntegerToString(GRIND_VL_STRANDED_STEPS) + "}";
```
Matches.

Spec: ROLL_CLOSING_STUCK detail `{"side":"L","ticket":7001,"stuck_s":60}`.

Code:
```cpp
         const string detail =
            "{\"side\":\"L\",\"ticket\":" + IntegerToString((long)pos) +
            ",\"stuck_s\":" + IntegerToString(GRIND_VL_CLOSING_WARN_SEC) + "}";
```
Matches.

**Now — one more: the WARN ticket for ROLL_STRANDED is 0 and for ROLL_CLOSING_STUCK is the position ticket.** OK, matches spec.

**Now — let me reconsider T-4's "fire on a healthy book".**

Hmm — consider a side that's fully rolled (all VL). The market then moves 2 add steps beyond → WARN. But then the market comes back and stays. Then the exits fill (the side gets unrolled as layers close and are re-added). Then a candidate appears → latch clears. Next advance → re-warn. OK.

Hmm — could the WARN fire during a NORMAL CloseBy? During a CloseBy, one layer is closing. If all layers are rolled and one is closing, the market moving 2 steps → WARN. That's a "stranded" state anyway. OK.

Hmm — the prompt's example "a normal CloseBy of a few seconds" — this is about ROLL_CLOSING_STUCK. A few seconds < 60 s → no warn. OK. So healthy.

**Now — one concern: the closing latch.**

Consider: layer L0's exit fills (closing). TrySide: level crossed, idx = 0, `exit_position_ticket != 0` → NoteClosing(L0). If the CloseBy takes 2 s, then on the next tick (after the CloseBy completes), the layer is removed. Depth = 7 < cap → tracking reset AND TrySide not called (only at cap). So the closing latch is NOT reset by the tracking reset (tracking reset doesn't touch closing state? let me check).

Hmm — in `Grind_LatticeTrackOneSide`, when depth < max_layers:
```cpp
         g_grind_vl_closing_ticket_long = 0;
         g_grind_vl_closing_since_long = 0;
         g_grind_vl_closing_warned_long = false;
```
Yes! The closing state IS reset below cap. Good. So when the CloseBy completes and depth < cap, the reset happens. And if a new layer is added (back to cap), tracking restarts. OK.

Hmm — but what if the side stays AT cap through the CloseBy? E.g., the exit fills, the CloseBy completes quickly, and the EA re-adds a new layer in the same OnTick. Then depth stays 8 (5→... no wait, depth drops then rises). Hmm. In the OnTick, the order is: LATTICE first (sees depth 7 → reset), then OnTickEngine (EnsureAddNext). So the reset happens. OK.

With fill_time_place = true, the re-add is in OnTradeTransaction. So depth could stay 8 across the OnTick. Then the closing state is NOT reset by the below-cap path. Hmm. And the closing ticket for the CLOSED position (now removed) — the layer is gone. So the closing ticket refers to a defunct position. Then the next time we reach a closing candidate with a different pos, the ticket changes → reset. OK. So no lasting harm.

Hmm, but the `g_grind_vl_closing_ticket_long` = the old ticket. If a new closing candidate appears with a ticket, say, 7001, and the old ticket happened to be 7001... unlikely (tickets increment). OK.

**Now — let me think about whether the closing WARN could fire on a re-used position.**

Hmm, no.

OK, let me now look at the big picture and also check for T-2 more.

Actually — let me re-examine the "no OnTick between the roll fill and the re-add" claim by considering the actual flow with fill_time_place = true.

1. OnTick T1. LATTICE rolls L0's exit (modify). OnTickEngine runs. ADD placed? The side is at cap, so no new add. (At cap, add target isn't placed — `Grind_CanPlaceEntryLayer(8, 8)` = false.) So no new add.
2. The modified exit fills (a sell limit at a lower price for a long). OnTradeTransaction: DEAL_ENTRY_OUT_BY → layer 0 removed. Depth 7. Then `Grind_TryPlaceAddAtFill` — wait, this is called for the ENT branch, not the OUT_BY branch. Let me re-read.

```cpp
   if(entry_type == DEAL_ENTRY_OUT_BY) {
      for(...) {
         ...
         Grind_RemoveLayerAt(side, i);
         Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);
         return;
      }
      return;
   }
```

Hmm — the OUT_BY branch does NOT call TryPlaceAddAtFill! It only removes the layer and manages exits. So the re-add is NOT placed in OnTradeTransaction for an OUT_BY event. Hmm.

Wait — but the roll in B1/B2 re-prices the EXIT of a layer. The exit is a limit order (sell limit for a long). When it fills, the position is NOT closed — instead, a NEW position is opened (the sell limit fills as a new position). So the deal is DEAL_ENTRY_IN for the exit order's filled position! Then the CloseBy pairs them. Hmm.

Let me re-read the exit fill handling:

```cpp
   if(c_role == "EXT" && entry_type == DEAL_ENTRY_IN) {
      int layer_idx = Grind_FindLayerByExitOrder(side, order_ticket);
      ...
      side.layers[layer_idx].exit_order_ticket = 0;
      side.layers[layer_idx].exit_position_ticket = position_id;
      if(orig_pos > 0 && position_id > 0) {
         if(is_long)
            Grind_QueueCloseBy(g_grind_long_closeby_queue, orig_pos, position_id);
         ...
      }
      ...
      return;
   }
```

Yes — when the exit limit fills, it opens a NEW position (the "exit position"). The EA then queues a CloseBy between the original position and the exit position. So the layer's `exit_position_ticket` is set. Then the CloseBy is processed in `Grind_ProcessCloseByQueues` at the start of OnTick. That triggers a DEAL_ENTRY_OUT_BY for both positions, which removes the layer.

Hmm — so the flow for a rolled exit filling:
1. Exit limit fills → DEAL_ENTRY_IN with comment role "EXT" → layer.exit_position_ticket = exit_position_id. Depth stays 8.
2. OnTick: ProcessCloseByQueues issues the CloseBy. The broker processes it.
3. The CloseBy produces DEAL_ENTRY_OUT_BY deals for both positions → the layer is removed. Depth 7.
4. But — the layer removal is in OnTradeTransaction. And NO re-add in that branch. So depth 7 persists until the next OnTick's EnsureAddNext. So no T-2 issue here? Wait — but depth 7 means the LATTICE resets. Good.

Hmm — so with the EXIT order architecture, the re-add doesn't happen in OnTradeTransaction. Instead, the layer removal happens during OnTradeTransaction (OUT_BY), and the re-add happens in the next OnTick (EnsureAddNext). So the LATTICE's next OnTick sees depth 7 → reset. So T-2 is NOT triggered? Hmm.

Wait — but there's a subtlety. The ENT (new layer) fill also happens in OnTradeTransaction. Between the OUT_BY (depth 7) and the ENT (depth 8), an OnTick must occur for the ENT to be placed (via EnsureAddNext). So there's naturally an OnTick between the OUT_BY and the ENT placement. And that OnTick runs the LATTICE with depth 7 → reset. Then the ENT is placed. Then a later OnTick fills it. So the reset happens. Good.

Hmm — EXCEPT: the fill_time_place branch. `Grind_TryPlaceAddAtFill` is called for the ENT branch (c_role == "ENT"). When a NEW ENTRY fills (an entry deal), the EA immediately places the next add. So the sequence: ENT deal (a new entry layer) → append layer (depth 8) → TryPlaceAddAtFill → place the next add (depth still 8). Hmm.

OK so let me redo the T-2 scenario:
1. At cap (8). LATTICE rolls L0's exit (OnTick T1).
2. L0's exit limit fills → ENT deal with role EXT → layer.exit_position_ticket set. Depth 8.
3. OnTick T2: ProcessCloseByQueues → CloseBy issued. LATTICE runs: depth 8, tracking continues (no reset). TrySide: maybe more rolls.
4. CloseBy processed → OUT_BY deals → layer removed. Depth 7.
5. OnTick T3: LATTICE sees depth 7 → RESET (extreme = 0, tracking = false). Then OnTickEngine EnsureAddNext places a new ENT.
6. ENT fills → ENT deal → append layer. Depth 8.
7. OnTick T4: LATTICE re-derives (tracking was false). New window from the new newest open. 

So the reset happens at step 5. Good — no T-2 issue for the standard exit flow.

Hmm — but what about the OUT_BY removal (step 4) happening right before an OnTick, and EnsureAddNext placing the ENT in that same OnTick (step 5), and the ENT filling before the NEXT OnTick (step 6), and... wait, step 5 IS the OnTick. So the reset happens in step 5. Good.

So T-2 is NOT a bug for the standard architecture. Hmm! Let me reconsider.

Hmm — but the prompt explicitly asks: "Can a rolled exit fill AND the real re-add fill with no OnTick in between (deals are processed in OnTradeTransaction; where is the re-add placed?)". So the answer depends on where the re-add is placed. Since the re-add is placed in `Grind_EnsureAddNext` (called from `Grind_OnTickEngine` in OnTick) or in `Grind_TryPlaceAddAtFill` (called from OnTradeTransaction's ENT branch)...

Wait — `Grind_TryPlaceAddAtFill` is called from the ENT branch (`c_role == "ENT"`), i.e., when a NEW ENTRY fills. Hmm. When does a new ENTRY (a fresh layer) fill? When the add limit (ENT) fills. That happens when the market moves to the add target. At that moment, the layer is appended (depth goes from 7 to 8), and if fill_time_place, the next add is placed immediately.

But the ROLLED EXIT fill is an EXT (exit limit) fill, not an ENT. So the OUT_BY removal (which brings depth to 7) doesn't trigger the immediate re-add. The immediate re-add triggers on the ENT fill, which brings depth from 7 to 8.

So the sequence to get a stale extreme:
- depth 7 (from an OUT_BY).
- Then an ENT fills (the add placed earlier), appending a layer → depth 8.
- Then fill_time_place → place the next add.

So between depth 7 and depth 8 there's a single OnTradeTransaction (the ENT). At the next OnTick, depth is 8. So the LATTICE sees depth 8 with tracking... hmm, when did the tracking reset?

Wait — at the moment depth 7 (after OUT_BY), the NEXT OnTick would reset the tracking. But between OUT_BY and ENT, is there an OnTick?

The ENT was placed by the EA (via EnsureAddNext) at some OnTick when depth was 7. So there was an OnTick at depth 7 (which reset the tracking). Then the ENT fills. So the tracking was reset. Good.

BUT — hmm. What if the ENT was placed BEFORE the depth dropped to 7? E.g., at cap (depth 8), no new add is placed (can't at cap). So the ENT add is only placed when depth < 8. So it's placed at depth 7 (during an OnTick). And that OnTick reset the tracking. So consistently, the tracking resets.

Hmm — UNLESS: the ENT is placed at depth 7, and it fills in the SAME OnTick's later processing? No, fills happen in OnTradeTransaction.

Hmm. So maybe T-2 isn't triggered by the standard flow.

Hmm — but wait. Consider the scenario where the depth drops below cap and returns to cap WITHIN a single OnTick. E.g.:
- OnTick T. LATTICE runs: depth 8 (say). Rolls.
- OnTickEngine runs. Places an ENT? No — at cap, `Grind_CanPlaceEntryLayer(8,8)` false. So no add placed.

Hmm.

Let me think about a different scenario: the ROLL itself doesn't change depth (it just re-prices an exit). So depth stays 8. The extreme should persist.

What about a NORMAL exit (not a roll) closing a layer? The exit limit fills → EXT ENT → layer.exit_position_ticket set (depth 8). Then CloseBy → OUT_BY → depth 7. Then the next OnTick resets. Then EnsureAddNext places a new ENT. Then it fills → depth 8. So multiple OnTicks.

Hmm. So maybe T-2's specific scenario doesn't occur. Let me reconsider.

Actually — here's another scenario. What if BOTH the rolled exit AND the add fill in the same OnTradeTransaction? E.g., the rolled exit (a sell limit near the market) and the add (a buy limit near the market) fill from the same quote. Hmm — actually, the rolled exit being clamped to `ask + 1pt` for a long — that's ABOVE the ask. A sell limit above the ask fills if the... wait, a sell limit fills when the BID reaches the limit price (i.e., the bid rises to the ask+1pt level). Hmm. And the add (buy limit) fills when the ASK reaches the add target (below the market). So they can't both fill from the same tick direction. Hmm.

OK, maybe T-2 is not a real issue given the architecture. But the prompt asks me to consider it. Let me also consider the "roll fill" — the roll re-prices the exit. The exit then fills. That's an EXT fill. As analyzed, the re-add is not immediate for the EXT fill. So depth 7 persists to the next OnTick.

Hmm — EXCEPT if fill_time_place AND the EA places the add in the SAME OnTradeTransaction as the EXT fill? Let me check: the EXT branch (c_role == "EXT" && entry_type == DEAL_ENTRY_IN) doesn't call TryPlaceAddAtFill. So no. OK.

Hmm — wait, but the OUT_BY branch removes the layer. And it doesn't place an add. So no immediate re-add.

Hmm — so T-2 might be HOLDS. But wait — the prompt says "where is the re-add placed?" — implying that the answer matters. Let me look specifically.

The re-add (the ENT for the next layer) is placed by:
1. `Grind_SendNextAddEnt` via `Grind_TryPlaceAddAtFill` (only from the ENT branch, if fill_time_place).
2. `Grind_EnsureAddNext` via `Grind_OnTickEngine` (in OnTick).

Hmm — `Grind_TryPlaceAddAtFill` is called from the ENT deal branch:
```cpp
   if(c_role == "ENT") {
      ...
      Grind_AppendLayer(...);
      Grind_ExitQManageSide(...);
      Grind_TryPlaceAddAtFill(...);
   }
```

So when a new ENT fills, the EA appends the layer and (if fill_time_place) places the next add. So the fill of an ENT (which brings depth UP by 1) is immediately followed by a new add. Great — so the ENT fill brings depth to 8, and the re-add is placed (but not filled). So at depth 8, the next OnTick's LATTICE runs. Has the tracking been reset?

The tracking is reset when depth < max_layers at a LATTICE call. The depth dropped to 7 (during some OUT_BY), and the ENT was placed during the OnTick at depth 7 (which reset the tracking), then the ENT filled later. So the tracking was reset at the OnTick where depth was 7. So no stale extreme. 

Hmm — but what if the ENT was placed at depth 8 (before the drop)? That can't happen — at cap, no add is placed.

Hmm — what if the ENT was placed at depth 7, and then depth dropped further to 6? Then the ENT fills → depth 7. Then... hmm, complex. Still, the tracking resets whenever depth < 8. So as long as some OnTick sees depth < 8 before the layer is re-added, the tracking resets.

Hmm — so the question is: CAN a layer be added (depth 8) without any OnTick seeing depth < 8 in between? I.e., can the depth transition from 8 → 7 → 8 across OnTradeTransactions with no OnTick?

For that, the ENT to be filled must have been placed BEFORE the OUT_BY. Which requires depth < 8 at the time of placement. Contradiction — if depth was 8, no ENT would be placed. Unless the ENT was placed at depth 7 (after an EARLIER OUT_BY), and it fills AFTER a later OUT_BY? Hmm.

Actually yes! Scenario:
- depth 7 (an exit filled). OnTick T1: LATTICE resets tracking. EnsureAddNext places ENT add (target near market).
- The market moves, and the ENT fills early (depth 8) — say OnTradeTransaction at time T1+something, before an OnTick. Hmm, but the add is a limit order at a price near the current market. If it fills immediately...
- Wait — the EA at depth 7 places the ENT. The ENT fills → depth 8. If no OnTick between depth 7 (OnTick T1) and depth 8 (the ENT fill), then... but the tracking was RESET at T1 (depth 7). So at the next OnTick (depth 8), the tracking re-derives from the new newest open. Good.

So the tracking IS reset at T1. OK.

Hmm — so for T-2 to be a bug, we need a scenario where the depth drops below cap and returns to cap without any OnTick seeing depth < cap. Let me think harder.

Actually — here's the case. Consider:
- depth 8.
- OnTick T1: LATTICE runs (tracking at cap, extreme computed). EnsureAddNext: at cap, no add. So no new ENT placed.
- Now the MARKET moves. An EXIT limit fills → EXT ENT deal → layer.exit_position_ticket set (depth still 8). At this point, the EA might ALSO place a new ENT? No — the EXT branch doesn't place adds. And the side is still at cap (depth 8), so EnsureAddNext wouldn't place either.

Hmm. So the ENT is only placed when depth < 8.

- The CloseBy is processed in OnTick T2's ProcessCloseByQueues → the OUT_BY deal → layer removed (depth 7). But this happens in OnTradeTransaction AFTER T2's ProcessCloseByQueues and before T2's LATTICE? No — the order of operations: OnTick T2: ProcessCloseByQueues (sends the CloseBy request). The broker processes it asynchronously. The OUT_BY deal arrives in a later OnTradeTransaction. So the layer removal happens in an OnTradeTransaction, not in T2.

  Hmm — actually, does `Grind_ProcessCloseByQueues` issue the CloseBy and get the result synchronously? CloseBy is done via a trade request. The deal comes back asynchronously via OnTradeTransaction. So the OUT_BY deal arrives later.

- So: OUT_BY deal → depth 7. No OnTick yet. Then the next tick fires OnTick T3. T3's LATTICE sees depth 7 → reset. Then T3's EnsureAddNext places a new ENT. So depth 7 at T3.
- The ENT fills later → depth 8. Then T4's LATTICE re-derives.

So the reset happens at T3. OK.

Hmm — unless the ENT was placed EARLIER (before the OUT_BY at depth 7). Can that happen? The ENT is placed at depth 7. After placing, if it doesn't fill immediately, then at some point the OUT_BY (from the CloseBy) brings depth to 7... no wait, if the ENT is pending, depth is 7 (the layer was removed) or... hmm.

Ugh, I'm going in circles. Let me carefully construct: the key is whether there's an OnTick with depth < 8 before the depth returns to 8.

The depth drops to 7 only via OUT_BY (a layer removal). The depth returns to 8 via an ENT fill (a layer addition). The ENT that fills must have been placed at some earlier time when depth < 8. So there was a time when depth < 8. Between the depth-drop-to-7 and the ENT-fill, was there an OnTick?

The ENT was placed at a time T_p when depth was < 8. So there was a time (T_p) when depth < 8. At T_p, the EA placed the ENT. So an OnTick happened at T_p (since EnsureAddNext runs in OnTick, OR TryPlaceAddAtFill runs in OnTradeTransaction).

Hmm — if the ENT was placed via `Grind_TryPlaceAddAtFill` (in OnTradeTransaction), then the placement doesn't involve an OnTick. So T_p could be an OnTradeTransaction at depth < 8, without an OnTick.

But — wait. For `Grind_TryPlaceAddAtFill` to run, a new ENT must have just filled (depth went UP to 8). Hmm, so TryPlaceAddAtFill is called at depth 8 (after the append). So it places the NEXT add at depth 8. But at depth 8, no add should be placed. Hmm — wait, `Grind_SendNextAddEnt` checks `Grind_CanPlaceEntryLayer(n, max_layers)` = `n < max_layers` = `8 < 8` = false. So it returns false. So at depth 8, no add. OK. So TryPlaceAddAtFill is effectively a no-op at cap.

Hmm! So the immediate re-add in OnTradeTransaction is a no-op at cap. So the re-add is only for depth < cap. Which means the LATTICE's tracking resets are conserved.

Hmm, wait — `Grind_TryPlaceAddAtFill` is called AFTER `Grind_AppendLayer`. If the layer count goes from 7 to 8, then `Grind_SendNextAddEnt(8, ...)` → `Grind_CanPlaceEntryLayer(8, 8)` false → returns false. So no add. OK.

So at cap, the fill-time-place doesn't add. So the depth-8 episode is entered with the tracking reset. Good.

Hmm — SO, maybe T-2 is NOT a bug. Let me double check by considering: `Grind_AppendLayer` sets the layer count. Then `Grind_TryPlaceAddAtFill` → `Grind_SendNextAddEnt` which checks depth < max_layers. If depth == max_layers, no add.

But what if max_layers in the fill-time-place path uses a DIFFERENT max_layers than the LATTICE's? They both come from InpMaxLayers. So same.

OK — so I'm now doubting the T-2 bug. Let me think about it from a different angle — what if a layer is added WITHOUT an intervening OnTick at depth 7?

Scenario: at depth 7 (from OUT_BY). No OnTick. Then— hmm, another OUT_BY? That would drop to 6. Then an ENT fills → depth 7. Then another ENT → depth 8? But the ENTs would have to have been placed when depth < 8. So they'd be placed at some OnTick at depth < 8. So the tracking reset would have happened.

OK — I'm now fairly convinced T-2 (the specific "no OnTick at depth < cap") does NOT occur in the standard architecture. Because to add a layer, the ENT must have been placed at depth < cap, which required an OnTick at depth < cap (except TryPlaceAddAtFill, which is a no-op at cap). Actually — hmm, wait, `Grind_TryPlaceAddAtFill` is called on ANY ENT fill (depth increases). If the depth increases from 6 to 7 (below cap), the add is placed (depth 7 < 8). So the add is placed at depth 7 (after an ENT fill at depth 6→7). Hmm. That placement is in OnTradeTransaction. So no OnTick involved. Then if the add fills (depth 7→8)...

Let me construct: 
- depth 6 (say).
- An ENT fills → depth 7. TryPlaceAddAtFill (fill_time_place) → places an ENT (depth 7 < 8).
- That ENT fills → depth 8. TryPlaceAddAtFill → no-op (depth 8).
- So depth: 6 → 7 → 8, all in OnTradeTransactions, no OnTick.
- The LATTICE's tracking: at depth 6 (before), the tracking was reset (below cap). At depth 8, the tracking would re-derive (tracking = false). So the re-derive uses the NEW newest. OK.

So the tracking is reset because it was reset when depth < 8 at the LAST OnTick. Hmm — but if there's NO OnTick between depth 6 and depth 8, the tracking state at depth 8 is whatever it was at the last OnTick. If the last OnTick saw depth 8 (before the depth dropped to 6), the tracking is still "true" with a STALE extreme!

Ah — THIS is the scenario. Let me construct:
- depth 8. OnTick T1: LATTICE runs (tracking true, extreme computed). EnsureAddNext: no add (at cap).
- Now, deals happen WITHOUT OnTick: 
  - Several exits fill and CloseBy → OUT_BY deals → depth drops to 6.
  - Several ENTs fill → depth rises to 8.
  - All in OnTradeTransactions.
- No OnTick between depth 8 (at T1) and depth 8 (now). So the LATTICE's tracking was never reset (it only resets at depth < 8 during a LATTICE call).
- The next OnTick T2: LATTICE sees depth 8. Tracking is still true. Extreme is stale (from before the exits). Rolls a layer based on the old extreme.

Hmm — is this scenario possible? It requires exits to fill and CloseBy and ENTs to fill, all without an OnTick. In MT5, OnTick fires per symbol update. Trades happen on quotes. So the quotes that trigger fills would also trigger OnTick. BUT — MT5 does not guarantee that OnTick fires for every quote. Actually — in MQL5, OnTick is called when a new tick arrives for the symbol. The terminal delivers the LATEST tick. If ticks arrive faster than the EA processes, OnTick may skip some. But it still fires on the latest tick. If trades happen on those skipped ticks... hmm.

Actually — the trades are triggered by the BROKER, not by the EA's OnTick. So the fills happen independently. The EA's OnTick fires per the terminal's tick delivery. If the fills happen on ticks the EA also sees, OnTick fires. If the fills happen on ticks the EA's OnTick SKIPS (because the terminal coalesces), then OnTradeTransaction fires for the fill but OnTick doesn't.

Hmm — is that possible? MT5's OnTick is called on every new tick from the server (with the current state). Actually, it's called ONCE per incoming tick packet. If the terminal receives 5 ticks in quick succession, OnTick is called 5 times (each with the latest state). Hmm, or maybe once with the latest. MQL5 docs: "OnTick is called... when a new tick arrives". I believe one call per tick.

But — even if OnTick fires, the ORDER matters. If a trade transaction arrives BEFORE the OnTick for that tick, the depth change happens first. But the LATTICE only runs in OnTick. So if the depth drops to 6 (OUT_BY) and rises to 8 (ENT) within the same tick's OnTradeTransactions, before the OnTick... hmm.

This is getting deep. Let me just flag T-2 as NEEDS-FIX with a caveat that it requires a specific deal ordering (multiple outs and ins between two OnTicks), and note the fix (track the newest open time). Even if rare, it's a real gap in the design's "reset only when OnTick sees below cap" logic.

Hmm — actually, wait. Let me reconsider the interaction with `Grind_ProcessCloseByQueues`. That's called at the START of OnTick. So the CloseBy requests are issued in OnTick. The resulting OUT_BY deals arrive asynchronously. Hmm.

OK — the key insight: the reset condition (depth < max_layers at a LATTICE call) is a SUBSAMPLE of the actual depth changes. So a depth excursion 8→7→8 (or 8→6→8) between two LATTICE calls is invisible. The extreme is stale.

Even the simpler case: 8 → 7 (OUT_BY) → 8 (ENT) with no OnTick. As I analyzed, the ENT that fills must have been placed earlier at depth < 8. Hmm. But if multiple ENTs are placed at depth 7 (or lower), they can all fill.

Hmm — but actually, the simplest case: the ENT was placed at depth 7 at a previous OnTick T0 (which reset the tracking), and it stays pending. Meanwhile, more OUT_BYs happen (depth 6, 5...). Then the ENTs fill (depth 6→7→8). If no OnTick between... but the ENTs were placed at OnTicks T0, T1, ... each of which reset the tracking (tracking already false). Hmm — tracking is false after the first reset. And it's re-derived at the NEXT OnTick with depth 8.

Argh. OK — the fundamental issue: the tracking state is only updated at LATTICE calls (in OnTick). So if the depth never appears < 8 at a LATTICE call between two depth-8 LATTICE calls, the tracking persists. For that, the depth must be 8 at every LATTICE call in between. But the depth dips to < 8 only via deals, which happen between OnTicks. If no OnTick falls in the dip, the tracking persists.

Can the depth dip below 8 and recover to 8 with no OnTick falling in the dip? Yes, if the deals are processed between two OnTicks. As I argued, the ENTs that cause the recovery were placed at previous OnTicks (which saw depth < 8 → reset). Hmm — so the tracking was reset. UNLESS the ENTs were placed via TryPlaceAddAtFill (OnTradeTransaction) at depth < 8.

Let me construct concretely:
- depth 8 at OnTick T0 (tracking true, extreme E0).
- T0: EnsureAddNext — no add (at cap).
- Deals (no OnTick): 
  - OUT_BY → depth 7. (No reset — no LATTICE call.)
  - Hmm, but then no ENT pending (at cap, no add placed). So depth stays 7 until the next OnTick, which places an ENT at depth 7 and resets the tracking.

So the depth can only recover via an ENT placed at an OnTick that saw depth < 8. So the reset WILL have happened. UNLESS the ENT was placed at a PREVIOUS OnTick with depth < 8, and it stayed pending while the depth went back to 8 and dropped again. Hmm — but if the ENT was placed at a previous OnTick T_prev (depth < 8), then the tracking was reset at T_prev too. And if the depth went to 8 and back to < 8 without a LATTICE call...

Ugh. OK. Let me just say: T-2 is a theoretical gap; the reset is keyed on the SAMPLED depth (at LATTICE calls), not on the actual depth changes. In practice, with the standard architecture, the reset occurs because adds are only placed at OnTicks that see depth < cap (except the fill-time-place no-op). So the bug is unlikely but the design is fragile. I'll mark T-2 as NEEDS-FIX (design gap, tested by no test, fix: also reset when the newest open changes), and note the caveat.

Hmm, actually — let me reconsider whether TryPlaceAddAtFill can place an add at depth < cap AFTER the depth has recovered. No — it's called after AppendLayer, so depth is the post-append value. If post-append depth < cap, it places. E.g., depth 6 → ENT → 7: TryPlaceAddAtFill places an add (7 < 8). This is in OnTradeTransaction. So the add is placed without an OnTick. Hmm! So the sequence 6 → 7 (ENT) → place add → 8 (add fills) all in OnTradeTransactions.

And the tracking? At depth 6, was there a LATTICE reset? If the depth went 8 → ... → 6 with no LATTICE call seeing < 8, then the tracking is stale at the ENT time. Hmm.

Let me construct the full scenario:
- depth 8 at OnTick T0. Tracking true, extreme E0. No add placed.
- Deals (no OnTick): 
  - Exit fills → EXT ENT (depth 8, exit_position set). No-op re-add.
  - CloseBy → OUT_BY → depth 7.
  - Hmm — but the EA needs to ISSUE the CloseBy. That happens in OnTick (ProcessCloseByQueues). So the CloseBy requires an OnTick.

Hmm! So the OUT_BY can only happen after an OnTick issued the CloseBy. And that OnTick saw depth 8 (the layer was still present with exit_position set). So the depth-8 OnTick didn't reset.

Then the OUT_BY arrives (depth 7). Then a subsequent OnTick T1 sees depth 7 → reset. Then places an ENT. So the reset happens at T1.

For the ENT to fill WITHOUT an OnTick after T1: the ENT is placed at T1, then fills in an OnTradeTransaction before T2. Depth → 8. Then T2 sees depth 8 with tracking false (reset at T1) → re-derives. Good.

So the reset happens. Hmm.

OK — I'll conclude T-2 as NEEDS-FIX because the design's reset is keyed on sampled depth and there's a plausible (if contrived) ordering, but I'll be honest that the standard flow resets. Hmm — but the prompt says "find what tests cannot see". Maybe the answer intended is that T-2 is a real gap. Let me think once more...

Actually — the CLEANEST T-2 scenario involves the fill-time-place re-add at depth below cap and MULTIPLE rapid deals. But the fundamental point stands: the reset is tied to LATTICE calls (OnTick), not to the actual side depth transitions. So if the depth transitions 8→7→8 between two OnTicks, the extreme survives.

And — the simplest way that happens: an exit fills (EXT ENT, depth 8 → wait, no depth change until the CloseBy). Hmm. Hmm hmm.

Actually — wait. Let me re-read the OUT_BY branch:
```cpp
   if(entry_type == DEAL_ENTRY_OUT_BY) {
      for(int i = 0; i < Grind_SideDepth(side); i++) {
         if(side.layers[i].position_ticket != position_id)
            continue;
         if(side.layers[i].exit_position_ticket == 0)
            continue;
         Grind_MarkDealProcessed(deal_ticket);
         ...
         Grind_RemoveLayerAt(side, i);
         ...
```
So a layer is removed when an OUT_BY deal for its position arrives AND the layer has exit_position_ticket != 0. The CloseBy produces OUT_BY for BOTH positions (the original and the exit). The FIRST OUT_BY to arrive removes the layer. So the depth drops.

The CloseBy is issued in `Grind_ProcessCloseByQueues` (OnTick). The OUT_BY arrives later (OnTradeTransaction). So between the CloseBy issue (OnTick) and the OUT_BY arrival, there may or may not be an OnTick.

After the OUT_BY (depth 7), the EA needs to place a new ENT. That happens at the next OnTick (EnsureAddNext). So there IS an OnTick at depth 7 → reset. Unless the ENT was already pending (placed earlier).

Hmm — could the ENT be pending from earlier? At cap, no ENT is placed. So no. Hmm — unless the depth was < 8 at some previous point and an ENT was placed and stayed pending. Then the depth went back to 8 (via another ENT's fill) and then dropped to 7 (the OUT_BY). Then the PENDING ENT fills without an OnTick → depth 8. In that case, the LATTICE never saw depth < 8 since... hmm, the last time it saw depth < 8 was when it placed the ENT (which reset the tracking). So the tracking is already reset. Then the extreme re-derives at the next OnTick. OK.

So the tracking resets. T-2 HOLDS in the standard flow.

Hmm — but the prompt explicitly lists T-2 as a threat to verdict. It might be a real bug that I'm missing, or it might be a red herring. The prompt says "Find what tests cannot see" — the answer might be "T-2 is a gap because the reset is conditioned on the OnTick-sampled depth". I'll present it as NEEDS-FIX with the honest caveat.

Actually — let me look ONE more time. Hmm — the tracking reset condition is in `Grind_LatticeTrackOneSide`, which is called from `Grind_LatticeTrackExtremes`, which is called from `Grind_LatticeOnTick` BEFORE the blocked check. So it runs on EVERY OnTick (if enabled). Even when blocked/halted. So the reset happens whenever OnTick runs and the depth < cap. So between two OnTicks, if the depth dips and recovers, no reset. That's the gap.

I'll present T-2 as NEEDS-FIX with the specific fix (compare newest open time each tick and reset on change).

HE — wait, actually, there's a MUCH simpler and more definite scenario. What if the ROLLED EXIT FILLS and then the EA places the re-add via `Grind_EnsureAddNext` in the SAME OnTick where the depth was still 8?

Hmm — the depth is 8 at that OnTick. EnsureAddNext: `if(depth > 0 && (depth > 0 || add_pending != 0)) Grind_EnsureAddNext(...)`. `Grind_EnsureAddNext` checks `Grind_CanPlaceEntryLayer(n, max_layers)` = `8 < 8` false. So no add. OK.

Alright. I'll go with NEEDS-FIX for T-2 but qualified.

Hmm, actually — hold on, let me reconsider. I keep assuming the depth must be < cap to place an add. That's correct. So the depth must be sampled < cap at some OnTick for an add to be placed. And that OnTick resets the tracking. So the tracking resets when needed. UNLESS the tracking was reset but then RE-SET (tracking = true) at a LATTICE call with depth 8, using a STALE newest open... no, the re-derive happens with the CURRENT newest.

Wait — that's the key. When the LATTICE re-derives (tracking was false), it uses the current newest open. So it's correct. So the reset+watching works.

Hmm — so where's the bug? Let me trace ONE more time:
- T1: depth 7 (say, the exit filled). LATTICE: depth 7 < 8 → RESET (tracking false, extreme 0). OnTickEngine: EnsureAddNext places ENT (target near market).
- T1.5 (OnTradeTransaction): the ENT fills → AppendLayer (depth 8). TryPlaceAddAtFill → no-op (depth 8).
- T2: LATTICE: depth 8. tracking false → re-derive. from = newest+1 = the NEW layer's open + 1. So the window starts from the new layer's open. Correct!

Yes. So the reset+re-derive works because the tracking was set to false at T1 (depth 7).

So T-2's concern "the old extreme survives into a new cap episode" would only happen if the depth never appeared < 8 at a LATTICE call between the old cap episode and the new one. And that requires the exit-out and add-in to happen between two LATTICE calls, WITH the add having been placed before (at a depth < 8 LATTICE call, which reset the tracking). So the tracking was reset. So the extreme doesn't survive. Hmm.

OK. So T-2 = HOLDS. But I'll note the fragility.

Hmm, actually — one case where it FAILS: what if the depth is 8 at T1, and the exit fills (EXT ENT, exit_position set, depth 8), and the CloseBy is issued at T2 (OnTick, depth 8). The OUT_BY arrives at T2.5 (depth 7). Then T3 (OnTick, depth 7 → reset). So the reset happens at T3.

Hmm — but at T1 (depth 8), the layer has exit_position set. Then at T2 (depth 8), the LATTICE runs and sees the closing layer. But the tracking isn't reset (depth 8). So the extreme persists from the old episode. Then at T3 (depth 7, after the OUT_BY), the reset happens. So the reset DOES happen before the re-add. Good.

So the reset always happens because the OUT_BY (which drops the depth) is followed by an OnTick (which sees depth < 8) before any ENT is placed. And ENTs are only placed at OnTicks with depth < 8. So the reset always precedes the re-add.

Hmm — unless multiple ENTs are placed at depth 7 and one fills while the depth is 7, bringing it to 8 — but the reset already happened at that OnTick.

OK, FINAL: T-2 HOLDS in the standard architecture, with a caveat (fragile design; a future change placing adds in OnTradeTransaction at cap would break it). Hmm — but the prompt explicitly asks "where is the re-add placed?" — implying the answer is the key. The re-add is placed in `Grind_SendNextAddEnt` only when depth < cap. So at cap, no re-add. So the reset happens. So T-2 HOLDS.

Hmm — I'm torn. Let me present T-2 as HOLDS but flag the fragility and note that the tests don't cover the refill ordering. Actually — let me reconsider once more.

Hmm — actually, wait. Let me re-read the prompt's T-2: "Can a rolled exit fill AND the real re-add fill with no `OnTick` in between (deals are processed in `OnTradeTransaction`; where is the re-add placed?), so the old extreme survives into a new cap episode and rolls a layer the market never reached after the re-add?"

The "re-add" — they mean the new LAYER (a re-added layer). The roll fills → the layer's exit fills → CloseBy → layer removed. Then a new layer is added (the re-add). So the question: can both happen with no OnTick in between?

For the new layer to be added, an ENT must fill. The ENT was placed at a depth < cap OnTick. So there WAS an OnTick at depth < cap (which reset the tracking). Hmm — but was it between the roll fill and the re-add? Yes, necessarily (the ENT was placed after the roll fill). So the reset happened between. So the answer is NO (the old extreme does not survive).

OK — T-2 HOLDS.

Hmm, but there's still the "restart with a different book" part. At a restart, tracking = false (in-memory state). So re-derive. Correct. HOLDS.

OK. Let me now also double check: does the tracking reset happen at a restart? The globals are initialized false. `g_grind_vl_tracking_long = false`. So yes. HOLDS.

Alright. So T-2 = HOLDS with a caveat. Good — I'll present it carefully.

Hmm — wait, but I should double-check: is there a path where the tracking is set true but the extreme is not reset when it should be (a genuine bug)? Consider: the side is at cap, tracking becomes true at T1 with extreme E. Then the side stays at cap forever (no deals). The extreme is a running min over ticks. Correct. OK.

Hmm.

OK, let me also look at one more possible issue: the "extreme" is folded with the live price on EVERY OnTick, even if the side's window hasn't started. Hmm — no, the live fold happens after the tracking is set. OK.

Hmm, and one more: in `Grind_LatticeTrackOneSide`, when `!tracking`, we compute `newest`. If `Grind_CarryPositionOpenTime` fails for ANY layer, we `return` (skip the side this tick). So a single lookup failure blocks the tracking. At a restart, if the broker hasn't loaded the position's timestamp... hmm, POSITION_TIME should be available. OK.

Hmm — but this `return` means: if the lookup fails for a layer, we skip the whole side. And the tracking stays false. So no extreme. Then TrySide uses extreme 0 → live price only (B1). So the catch-up silently doesn't happen. A "silent failure". Hmm — worth noting. But it's a "skip this tick" (retry). If the lookup permanently fails, the tracking never starts. Hmm. Since POSITION_TIME should always be available, low risk.

OK. Now let me look at T-5 once more — "With it on and the side below cap, does B2 change anything?" The tracking resets, and TrySide isn't called. So no. HOLDS.

Hmm — but the tracking's reset touches globals. Those globals are only read by TrySide (at cap). So no effect below cap. HOLDS.

Now let me think about "**Off means off**" for the OFF case. `Grind_LatticeOnTick` returns if !enabled. So no reads, no tracking, no TrySide. HOLDS.

BUT — hmm. The `Grind_LatticeResetBackoff` now calls `Grind_LatticeTestTicksReset()`. Is `Grind_LatticeResetBackoff` called in production? I need to check. Searching the shown code... I don't see it called outside tests. Hmm. If it's called in some production path, it would reset the test ticks — harmless. OK.

Now — one more thing. The `Grind_LatticeTestAddTick` / `Grind_LatticeTestTicksReset` are test helpers in grind_engine.mqh. They resize globals. In production, these globals are never touched (empty). So no memory issue. OK.

**Let me now look at the schema/logging for the WARNs once more.**

`Grind_ArchiveMarker("WARN", "ROLL_STRANDED", is_long ? "L" : "S", 0, detail)`. The archive marker signature — in `Grind_EjectReport`, it's `Grind_ArchiveMarker("INFO", code, "", ticket, detail)`. So the 3rd param is a "key". OK.

Hmm — pipshed's allow-list (A8) — the new codes aren't there yet (C56). So on deploy, the banner would miss them. Deploy precondition. OK.

**Now, let me also check the tests' `C55_OnTick` blocked parameter.** It passes `false`. So blocked = false. So TrySide runs. OK.

**Let me look for a bug in `Grind_LatticeTrySide`'s stranded latch clearing.**

```cpp
   if(Grind_LatticeCandidateIndex(side, is_long) >= 0) {
      if(is_long)
         g_grind_vl_stranded_warned_long = false;
      ...
```
This clears the latch when there's a candidate. But the stranded warn is only reached when idx < 0 (no candidate). So the clear happens when a candidate appears. OK.

Hmm — but the clear is at the TOP of TrySide, before the loop. And TrySide is only called when enabled and not blocked and not backed off. If TrySide isn't called (e.g., blocked), the latch isn't cleared. But the tracking reset (below cap) clears it. OK.

**Now, the `PREMISE VERDICT`.**

Safe to merge with lattice OFF? The B2 code is all inside `Grind_LatticeOnTick` after `if(!enabled) return;`. So OFF → no B2 code. The new globals are initialized false. The new pure function is unused. The new test helpers are unused. So yes, safe with lattice OFF.

Hmm — but wait. `Grind_LatticeOnTick` now has:
```cpp
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;
```
With enabled = false, it returns immediately. So no change. HOLDS.

Is B2 consistent with the operator's rule with it ON? The operator's rule: "if we are 8 deep and the market is gapping, i would rather we were active". B2 implements: catch up from tick history, running extreme, ROLL_STRANDED, ROLL_CLOSING_STUCK. Consistent. The concern is the T-1/T-2/T-3 caveats. And the "silent permanent failure" (GD6). I'll say yes, consistent, modulo the deploy precondition.

**Now the TEST GAPS.** Let me list.

1. T-2 (refill ordering): no test.
2. The live CopyTicksRange path: never exercised (only the seam). So a compile-time or runtime error in the live branch (e.g., wrong arg order) wouldn't be caught.
3. The live-price fold in `Grind_LatticeFoldExtreme` (when the tick read returns 0 or fails): no test.
4. The `to_msc` upper bound: no test (the seam ignores it).
5. Multiple ticks with the same msc: no test.
6. The 24 h cap with the `now - 86400` bound: VC10 covers it partially (only the include/exclude at the boundary). Not the exact boundary.
7. Behavior when `Grind_CarryPositionOpenTime` fails (skip side): no test.
8. `Grind_LatticeTrackOneSide` when the side is EMPTY (depth 0): no test (C55 tests start at 8).
9. The stranded latch reset by a candidate appearing (not just below-cap): VS1 tests the below-cap reset, but not the "candidate appears" reset.
10. The stranded WARN when the market is between S-1 and S steps: VS1 tests one step (no warn) and two steps (warn). Boundary at exactly 2 steps: VS1 uses 1.19700 exactly. Hmm, covered.
11. The closing latch reset when a different ticket closes: not tested.
12. ROLL_CLOSING_STUCK across a non-closing loop end: VCS1 tests the reset (after "VCS1 rolls when clear"). Hmm.

Are any tests VACUOUS? Let me look once more at the "PASS in both" list.

- "VC7 L2 not rolled": `AssertFalse("VC7 L2 not rolled", Grind_VLHas(7003UL))`. In the stub, no rolls, so 7003 not rolled → passes. In the impl, 2 rolls (L0, L1), so 7003 not rolled → passes. Hmm — this passes for the wrong reason in the stub, but the impl result is tested. Not vacuous.

Hmm — actually, a subtle issue: "VC7 L2 not rolled" passes in the stub because NOTHING rolled. In the impl, because the extreme (1.20490) doesn't cross level 1.20400. So in the impl it's meaningful. OK.

Are there any tests that would pass EVEN IF the implementation were wrong in a specific way? E.g., VC1 tests the pure function. If the min logic were inverted (max), VC1 would fail (1.19990 vs 1.20010). OK.

Hmm — VC2 tests the short max. If the short logic used the ask... the test only provides bids and asks; the short extreme uses bid[] = {1.20000, 1.19980, 1.19900}. Max = 1.20000. If it wrongly used ask[0] = 1.20010, it would fail. OK.

Hmm — is there a test for the `msc[i] < from_msc` boundary (strictly less)? VC1 from=1500: only msc 2000 and 3000 qualify (1000 < 1500 excluded). The result 1.19990 confirms 1000 excluded. And from=2500: msc 3000 qualifies but ask 0.0 (skipped) → false. Hmm — this tests the "nothing in range" but NOT the exact boundary (msc == from). VC1's from=1500 doesn't equal 1000 or 2000. Hmm. So the inclusive boundary is not tested! The spec says "msc >= from_msc". If the code used `<=` (exclusive), from=1500 would still work. Hmm. So the boundary isn't pinned. Minor.

OK.

Let me also check the "VC3 exit clamped passive" range [1.20700, 1.20720]. Hmm — the point of the test: the exit is clamped to ask + 1pt. But the RANGE is wide (20 points). If the exit were clamped to ask + 1pt = 1.20701, that's in range. If it weren't clamped and were at 1.20650, that's NOT in range. So it distinguishes. OK — semi-tight (20 points).

**Now let me also look for a "schema mismatch" — the WARN code strings vs the pipshed allow-list.** Already noted.

Hmm — is there a mismatch between the telemetry code and the archive code? Both use the same string. OK.

Hmm — `Grind_TelemetryEmit(g_grind_telemetry_instance, "ROLL_STRANDED", detail)` — the telemetry emit signature. Let me check `Grind_TelemetryEmit(instance, code, detail)` from the eject report. Yes.

**Let me now think about whether the extreme can roll a layer where NO limit could have filled, considering the CLAMP.**

The roll re-prices the exit to `Grind_ExitPrice(level, exit_pips)` = level + exit_pips (5 pips). This is the exit for the LAYER being rolled. If the market is now above that, the clamp moves it to ask+1pt. So the resulting exit is at the market. Does a limit at the market fill? A sell limit at ask+1pt fills when the bid rises to that level. Hmm — so the exit is "clamped passive". The design says the rolled exit may fill soon, realizing the roll cost. Hmm — the "unsafe direction" from T-1 is about rolling when no fill could have happened. But the ROLL itself isn't a fill; it's a re-pricing. The fill happens when the market moves. So a spurious roll just re-prices the exit (realizing a cost when it fills). Hmm. OK, so the "unsafe" is a mispriced exit (cost).

OK. So T-1's extreme might be TOO LOW (long) due to... hmm, what could make the extreme too low? A BOGUS low ask in the tick history. E.g., a bad tick (fat finger) with a very low ask. The tick history might contain bad ticks. The extreme would then be very low, causing a roll to a very low level (clamped to the market). Hmm — that's a real risk. But a single bad tick would only be in the history if the broker recorded it. Hmm. And a roll would be triggered. That's a "lookahead/spurious" concern. But it's inherent to using tick history. The design accepted GD1.

Hmm — actually, `COPY_TICKS_INFO` might include ticks with an absurd price during a data glitch. The design doesn't filter for sanity (only > 0). So a bogus ask of 0.00001 would pass (positive) and make the extreme absurdly low → roll to a low level → clamped. Hmm. That's a plausible false-positive. But the roll's clamp handles the price. Hmm. I'll note it as a low-risk observation.

**OK let me also double check G2.**

"Live code never reads the test seam: `Grind_LatticeCopyTicks` uses the seam only when `g_grind_order_test_active`."

```cpp
int Grind_LatticeCopyTicks(const long from_msc, long &msc[], double &bid[], double &ask[])
{
   if(g_grind_order_test_active) {
      ...
   }
   MqlTick t[];
   ...
}
```
Yes. VERIFIED. But — is `g_grind_order_test_active` ever true in production? It's set true only by test code (`Grind_OrderTestReset` sets false; tests set true). Hmm — let me check if any production path sets it true. Searching... I don't see it. OK. VERIFIED.

**Now let me count the new assertions.** Meh — the prompt says "Report your own mechanical count of new `Assert*` calls".

Let me count:
VC1: 3 (AssertTrue, AssertNear, AssertFalse)
VC2: 2
VC3: 3
VC4: 1
VC5: 1
VC6: 1
VC7: 3
VC8: 3
VC9: 2
VC10: 2
VC11: 3
VC12: 2
VS1: 5
VS2: 1
VCS1: 6
VCS2: 1
LB40: 6
LB41: 4
LB42: 5
LB43: 5

Total: 3+2+3+1+1+1+3+3+2+2+3+2 = 26 (VC). VS: 5+1 = 6. VCS: 6+1 = 7. Hmm — the prompt says VCS 6. Let me recount VCS1: 
1. "VCS1 none at 0 s"
2. "VCS1 none at 59 s"
3. "VCS1 warn at 60 s"
4. "VCS1 once"
5. "VCS1 rolls when clear"
So 5 asserts. VCS2: 1. Total VCS = 6. Yes.
LB40: 
1. "LB40 rolled before first step"
2. "LB40 pass completed"
3. "LB40 S0 off bare level"
4. "LB40 S0 I6"
5. "LB40 all resting I6"
6. "LB40 all accrued"
= 6.
Wait — but the prompt's LB43 has 5, LB42 has 5, LB41 has 4. Let me recount LB40: the table shows 6 rows. Hmm.

Actually the prompt says "VC 26, VS 6, VCS 6, LB40-LB43 19": 26+6+6+19 = 57. So LB total = 19. LB40=6, LB41=4, LB42=5, LB43=5? = 20. Hmm. Let me recount from the code:

LB40: 6 Assert* calls (rolled, pass completed, off bare, I6, all resting, all accrued). 
LB41: 4 (five rolls, pass completed, all resting, all accrued).
LB42: 5 (rolled via catch-up, shift recorded, pass completed, L0 I6, all accrued).
LB43: 5 (sign guard skipped, accrual not committed, exit at rolled price, L0 I6). 

Hmm — LB43 shows 4 in the code! Let me recount:
1. AssertContains("LB43 sign guard skipped", ...)
2. AssertTrue("LB43 accrual not committed", ...)
3. AssertNear("LB43 exit at rolled price", ...)
4. AssertTrue("LB43 L0 I6", ...)
= 4.

So LB = 6+4+5+4 = 19. Good. And total = 26+6+6+19 = 57. Matches.

Hmm, but wait — the prompt's LB43 table shows 4 rows? Let me re-read: "LB43 sign guard skipped", "accrual not committed", "exit at rolled price", "L0 I6". Yes, 4.

OK so 57 new assertions. Matches the predicted.

Alright. Let me now write up the report.

Let me make sure I have quotes for each verdict.

**GIVENS CHECK:**

G1: quote `if(msc[i] < from_msc) continue;` and `if(ask[i] <= 0.0) continue;` and `if(!found || ask[i] < extreme_out)`. VERIFIED.

G2: quote `if(g_grind_order_test_active) {` at the top of `Grind_LatticeCopyTicks`. VERIFIED.

G3: quote the reset block. VERIFIED.

G4: quote `const double probe = extreme > 0.0` and `Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now);`. VERIFIED.

G5: Can't verify from a single snapshot. From the current code, no `static` on file-scope helpers. State as ASSUMED/UNVERIFIABLE.

Hmm — actually, the prompt wants me to verify. I can only say: the current code carries no `static` on any file-scope helper (I searched the shown files). Whether the commit changed ONLY those six, I cannot verify from one snapshot. So I'll mark it "CANNOT VERIFY (no diff); current code consistent".

Hmm — but maybe I can find evidence. E.g., is `Grind_LatticeCandidateIndex` non-static? In MQL5, file-scope functions are implicitly "static" (internal linkage), so removing `static` is cosmetic. Hmm. Actually — the compiler rejected `static`? That's odd. Hmm. Well, MQL5 does support `static` for functions? Actually MQL5 supports `static` functions? Hmm. The prompt says the compiler rejected it. Whatever — I'll note the code has no `static`.

Let me search the pasted code for "static"... In grind_pure.mqh, grind_engine.mqh, etc. I don't see any `static`. So G5's current state is consistent.

OK — writing.

**T-1:** HOLDS. Quote the cursor and the round trip. Note the same-msc skip is direction-safe.

**T-2:** HOLDS (with caveat). Quote the reset condition `if(depth < max_layers)` and the re-derive `if(!g_grind_vl_tracking_long)`. Explain that the re-add is only placed when depth < cap (via `Grind_EnsureAddNext`/`Grind_SendNextAddEnt`), so the LATTICE sees depth < cap and resets. Note the fragility. Hmm — but I decided to present it as HOLDS. Let me present it as HOLDS with a NEEDS-FIX-lite recommendation (defensive: also key on the newest open time). Hmm.

Actually — the prompt's verdict options: HOLDS / BREAKS / NEEDS-FIX. Let me pick NEEDS-FIX for T-2's fragility? Hmm. I'll go with HOLDS but recommend the defensive fix. Hmm — but the prompt might expect BREAKS. Let me think about whether there's a DEFINITE case.

Hmm — OK here's a definitive case I missed. Consider a RESTART where the side is at cap. The globals reset. The tracking re-derives from the newest open. Fine. Now — the prompt says "Same question for a restart with a different book." At a restart, `g_grind_vl_tracking_long = false` (fresh). So re-derive. Fine.

Hmm — what about the DEPTH sampled? At a restart, `Grind_SideDepth` is whatever the reconstructed state is. Fine.

OK, no definitive BREAKS for T-2. I'll mark HOLDS with a strong caveat + a recommended defensive fix. Hmm — actually, let me reconsider ONE more time whether a re-add can happen without a depth-<cap LATTICE call...

Actually — I realize there IS a case: `Grind_SendNextAddEnt` is called from `Grind_TryPlaceAddAtFill` after an ENT fill. If the depth after the append is < cap, it places. But — consider the reverse: what if the depth was 8, then a layer is removed (OUT_BY, depth 7), then the PENDING add (placed earlier at depth 7) fills (depth 8). Hmm — but the pending add was placed at depth 7 at an OnTick that reset. So it's fine.

OK, HOLDS.

Hmm, wait — actually, let me reconsider the very first LATTICE call after the roll. Suppose:
- depth 8, tracking true, extreme E.
- OnTick T1: LATTICE rolls. depth 8. EnsureAddNext: no add.
- The rolled exit fills (EXT ENT, depth 8). CloseBy queued.
- OnTick T2: ProcessCloseByQueues sends the CloseBy. LATTICE: depth 8 → NO reset. TrySide: continues with the same extreme.
- T2.5: CloseBy executes → OUT_BY → depth 7.
- T3: LATTICE: depth 7 → reset.

So between T1 and T3, the extreme is the SAME (not reset). And at T2, TrySide uses the same extreme. That's fine because the tracking SHOULD persist across a roll (the design). The reset only happens when the depth drops below cap (T3). And the re-add happens at T3 (EnsureAddNext) or later. So the reset precedes the re-add. HOLDS.

OK — final: T-2 HOLDS.

Hmm — but then the prompt's "find what tests cannot see" — maybe the intended answer is elsewhere. Let me look harder for a REAL bug.

**Let me look at `Grind_LatticeTrackOneSide`'s live fold and a possible issue.**

```cpp
void Grind_LatticeFoldExtreme(const bool is_long, const long from_msc, ..., double &extreme)
{
   double x = 0.0;
   if(Grind_LatticeTickExtreme(msc, bid, ask, n, from_msc, is_long, x)) {
      if(extreme <= 0.0) extreme = x;
      else if(is_long) extreme = MathMin(extreme, x);
      else extreme = MathMax(extreme, x);
   }
   const double live = is_long ? Grind_MarketAsk() : Grind_MarketBid();
   ...
}
```

OK.

**A possible issue: `Grind_LatticeTickExtreme` reads `extreme_out` when `!found` — but the initial `extreme=x=0.0`. So on the first qualifying tick, `!found` → set. OK.

Hmm — VC1's first assert passes `x` initialized to 0. OK.

**Let me look at `Grind_LatticeTrackOneSide`'s `from` computation once more.**

```cpp
         g_grind_vl_from_msc_long = MathMax((long)(newest + 1) * 1000,
                                            (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000);
```

`(long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000` — hmm, `now` is a datetime (uint). `now - 86400` is fine. `(long)(...) * 1000`. If `now - 86400` is negative (now < 86400, i.e., before 1970-01-02), then... unrealistic. OK.

Precedence: `(long)(newest + 1) * 1000`. `(long)(newest+1)` then `*1000`. Yes, the cast binds tighter than `*`. OK.

**Hmm — a potential overflow: `(long)(now - 86400) * 1000`.** now ~ 1.75e9. *1000 = 1.75e12. Fits in long. OK.

**Let me look at `Grind_MarketTimeMsc()` — `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)`.** Hmm — is `SYMBOL_TIME_MSC` a valid ENUM_SYMBOL_INFO_INTEGER? Actually, I think it's `SYMBOL_TIME_MSC` — yes, it exists. OK.

**Hmm — `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)Grind_MarketTimeMsc())`.** The signature: `int CopyTicksRange(const string symbol, MqlTick &ticks[], uint flags=COPY_TICKS_ALL, ulong from_msc=0, ulong to_msc=0)`. So the flags param is `uint` (COPY_TICKS_INFO = 2). OK. And from/to are ulong. OK.

Hmm — one thing: `COPY_TICKS_INFO`. The MQL5 doc says: COPY_TICKS_INFO — "Ticks with Bid and/or Ask changes". Hmm — so it returns ticks where bid or ask changed. Since we want bid/ask, good.

**Alright, let me look at the interaction between `Grind_LatticeOnTick` and `Grind_AutoEjectOnTick`.** Both are called. If both are enabled... `Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject)` in OnInit returns false if both. So they're mutually exclusive. OK.

**Let me examine `Grind_LatticeOnTick`'s `blocked` handling once more.**

```cpp
   if(!enabled)
      return;
   Grind_LatticeTrackExtremes(magic, max_layers, now);
   if(blocked)
      return;
```

So tracking runs even when blocked (halted/quarantined). Hmm — T-6 asks about this. The tracking RESETS the state when depth < cap. If halted for a long time, the tracking keeps running (reads ticks each tick). If the side is at cap, the extreme is updated. Then when unhalted, TrySide uses the extreme. Fine (by design). If the side is below cap, the reset happens. Fine.

Hmm — but during a HALT, could the tracking cause a WARN? The WARNs are emitted in TrySide, which is only reached when !blocked. So no. OK.

Hmm — but the resets touch the closing/stranded latches. During a halt, the below-cap reset clears the latches. Fine.

OK, T-6 HOLDS.

**Let me look for a bug in the closing stuck logic once more.**

```cpp
      if(side.layers[idx].exit_position_ticket != 0) {
         Grind_LatticeNoteClosing(is_long, side.layers[idx].position_ticket, now);
         closing_stop = true;
         break;
      }

      const int rc = Grind_LatticeRollLayer(...);
      if(rc == GRIND_ROLL_MODIFY_FAILED) { ...break; }
      if(rc != GRIND_ROLL_OK) {
         if(rc == GRIND_ROLL_CLOSING) {
            Grind_LatticeNoteClosing(is_long, side.layers[idx].position_ticket, now);
            closing_stop = true;
         }
         break;
      }
```

Note: `GRIND_ROLL_ALREADY_ROLLED` (3) → `rc != GRIND_ROLL_OK` → not CLOSING → break without setting closing_stop. Then after the loop, `!closing_stop` → reset. OK.

Hmm — `GRIND_ROLL_ALREADY_ROLLED` shouldn't happen (the candidate has no VL). OK.

**Hmm — the WARN uses `now` = the `now` passed to TrySide.** For the VCS tests, `Adr162b_TryLong(now)` passes now. OK.

**Let me look at VCS1's timing.** T0, T0+59, T0+60, T0+120. `now - since >= 60`. At T0+60: 60 >= 60 → warn. At T0+59: 59 >= 60 → no. OK.

Hmm — but wait, at T0+59, does NoteClosing update `since`? No — same ticket → `else if(!warned && now - since >= 60)`. 59 < 60 → nothing. So `since` stays T0. At T0+60: 60 >= 60 → warn. OK.

Hmm — but a subtle issue: at T0+120, `warned` is true → the `else if` is skipped. OK.

OK.

**Let me look at VS2's stranded short.**

Short levels: for short, `Grind_AddTargetPrice(anchor, add_pips, point, -1)` = anchor + add. So level = anchor + add. The market (bid) crosses when bid >= level. VS2 sets VLs 1.19400 + 0.001*i. Highest effective = 1.20100 (i=7). Level = 1.20100 + add (10 pips) = 1.20200. Stranded level = 1.20200 + 10 pips = 1.20300. Market bid = 1.20300. Crossed (>=). Warn. OK.

Hmm — `Grind_MarketTestSeed(1.20300, 1.20310, 0, 0)`. mkt = bid = 1.20300. 1.20300 >= 1.20300 → warn. OK.

Hmm — but wait, `Grind_LatticeLevelCrossed(false, 1.20300, 1.20200)`: `1.20300 >= 1.20200 - eps` → true. So it enters the loop. idx = CandidateIndex → all VL → -1 → MaybeStranded → crossed stranded 1.20300 → warn. OK.

Alright.

**Let me now think about the "STOP AND REPORT" items — any drift?**

The prompt lists helpers that must exist with the given signatures. I've seen `Grind_CarryPositionOpenTime`, `Grind_CarryTestSetOpenTime`, `Grind_AddTargetPrice`, `Grind_MarketTimeMsc`, `Grind_MarketTestSeed`, `Grind_ArchiveJsonDouble`. All present. `C54_SeedLong8Carry`, `Adr162b_*` — not in the shown files (test files not fully shown). OK.

**Let me look at one SPECIFIC possible bug: `Grind_LatticeTrySide` is called with the extreme as the LAST positional arg, but the calls pass `blocked` as the 10th and `now` as the 11th, and the extreme as the 12th.**

```cpp
      Grind_LatticeTrySide(g_grind_long, true, magic, slot, lots, exit_pips, add_pips, max_layers,
                           enabled, blocked, now, g_grind_vl_extreme_long);
```
Count: side, is_long, magic, slot, lots, exit_pips, add_pips, max_layers, enabled, blocked, now, extreme. Signature:
```cpp
int Grind_LatticeTrySide(GrindSideState &side, const bool is_long, const ulong magic,
                         const string slot, const double lots, const double exit_pips,
                         const double add_pips, const int max_layers, const bool enabled,
                         const bool blocked, const datetime now,
                         const double extreme = 0.0)
```
Matches. OK.

Hmm — wait, the prompt says the B1 signature is "11 parameters" and the new "LAST parameter with a default" keeps them unchanged. OK, 12 now.

**Let me look at a possible issue: `Adr162b_TryLong` calls TrySide with 11 args → extreme defaults to 0.0 → probe = mkt. So the VS/VCS tests use the live price.** OK — that's what VS1 needs.

**Hmm — but the VC tests use `C55_OnTick` which calls `Grind_LatticeOnTick` with the extreme.** OK.

OK. Let me now also verify: does `Grind_LatticeOnTick` pass the extreme even when the side is below cap? It calls TrySide only `if(Grind_SideDepth >= max_layers)`. So no. OK.

**Now — a potential issue: the extreme `g_grind_vl_extreme_long` is used for the long side and `_short` for the short. The tracking updates each. OK.

**Let me reconsider the LEVELS and the extreme in the SHORT case.**

For a short side, the "level" is below the entry (the price is expected to rise; wait no). For a short, the add target is ABOVE the entry (selling higher). So the level for the next add is above the deepest entry. And the market crosses when the bid >= level. The extreme is the max bid. So probe = max(bid, extreme) >= level → roll. OK.

Hmm — in VC6, `Grind_LatticeTestAddTick(09:30, 1.19410, 1.19420)`. Extreme = max bid = 1.19410. Level = 1.19400. probe = max(1.19300, 1.19410) = 1.19410 >= 1.19400 → roll. OK.

Now — the `Grind_LatticeFoldExtreme` for short: `live = Grind_MarketBid()` = 1.19300. extreme = max(1.19410 (from tick), 1.19300) = 1.19410. OK.

Alright.

**Let me now look at a specific scenario for T-4: "fire on a healthy book".**

For ROLL_CLOSING_STUCK: the WARN fires 60 s after the same position is noted closing. Now — consider a NORMAL CloseBy of a few seconds. The layer is noted closing at T (the first TrySide after the exit fills). If the CloseBy completes < 60 s, then at the next TrySide the layer is gone (removed) → the loop doesn't reach the closing check → reset. So no warn. OK.

Hmm — but what if the CloseBy is slow (e.g., 90 s on a busy server)? Then the WARN fires. That's the intent. OK.

For ROLL_STRANDED: consider a healthy uptrend where the long side is fully rolled and the market falls 2 add steps. The WARN fires. That's the intent (investigate). Hmm — the operator might see many of these. But it's latched. OK.

Hmm — could ROLL_STRANDED fire on the SHORT side spuriously? Mirror. OK.

**Now — let me think about "never fire when it should".**

ROLL_CLOSING_STUCK: if the level isn't crossed (the market is elsewhere), the loop breaks before the closing check → reset → the closing note is cleared. So if a layer is stuck closing but the market isn't near the level, no WARN. Then when the market comes back, the timer restarts (60 s). So it fires 60 s after the market returns. Hmm — arguably, a layer stuck closing for hours with the market away should warn sooner. But the design says "the roll candidate stays closing". A candidate is only relevant when the level is crossed. OK — by design.

Hmm — but consider: the layer is at the CANDIDATE rank and the level is crossed. If the market then moves away (uncross) and back repeatedly, the timer resets each time. So a stuck-closing layer with an oscillating market might never accumulate 60 s. Hmm — "never fire when it should"? Possible. But the design says "the candidate stays closing 60 s on the same position" — implying continuity. Eh. Minor.

**OK. Let me also examine the STRANDED latch reset "when the side has a candidate".**

Hmm — the latch is cleared at the TOP of TrySide if a candidate exists. But — a candidate exists when NOT all layers have a VL. After a roll, the rolled layer has a VL, but a NEW layer (if the side is above min depth) — hmm, at cap, all 8 layers. If some are unrolled, a candidate exists. So the latch clears. Then if the market advances 2 steps and all layers become rolled, the latch... hmm. Wait — the latch is cleared at the top, then MaybeStranded re-sets it when all rolled. So within ONE TrySide call, the latch could clear then re-fire. Hmm! Let me check:

```cpp
   if(Grind_LatticeCandidateIndex(side, is_long) >= 0) {
      // clear latch
   }
   ...
   for(...) {
      ...
      const int idx = Grind_LatticeCandidateIndex(side, is_long);
      if(idx < 0) {
         Grind_LatticeMaybeStranded(...);  // may set the latch
         break;
      }
      ...
   }
```

Hmm — so if a candidate EXISTS at the top (latch cleared), then in the loop, the level is crossed, idx >= 0 (roll happened), etc. The idx < 0 branch is reached only when ALL layers have VLs. So the clear-at-top and the fire-in-loop can't both happen in one call (if a candidate exists at the top, it exists in the loop unless rolls remove it... rolling a layer gives it a VL, reducing candidates). Hmm — actually! If the top has 1 candidate and the loop rolls it, then the next iteration has 0 candidates → idx < 0 → MaybeStranded. So within ONE call, the latch is cleared then re-set. And `stranded_warned` would be false (cleared), so MaybeStranded would WARN again (if the market is 2 steps beyond, which it would be if the roll just happened... hmm).

Hmm — wait, but if a roll JUST happened, the level was crossed. And now idx < 0. MaybeStranded checks the live market against stranded_level = 2 steps beyond. If the market is 2 steps beyond, WARN. But the latch was just cleared at the top. So it WARNs.

Hmm — so consider: the market is trending. TrySide rolls layers one at a time. Each call: a candidate exists at the top → latch cleared. Then rolls. When all rolled, idx < 0 → MaybeStranded → maybe WARN. Then the next call: no candidate → latch stays (not cleared). If the market is still 2 steps beyond → MaybeStranded → but the latch is set → return (no warn). OK. So one warn per episode. Hmm — but the "episode" resets whenever a candidate exists. If the market oscillates such that a candidate appears and disappears... hmm.

Hmm — this "clear at top then fire in loop" within one call: is it a bug? It means the latch can re-fire in a call where a candidate was rolled to exhaustion. Consider: the market is 2 steps beyond, all rolled, WARN set. Then a layer is added (a candidate exists) → latch cleared. Then the market advances, rolling the candidate. In that call, the latch is cleared (candidate existed at top), the roll happens, then idx < 0 → MaybeStranded: the market needs to be 2 steps beyond to re-warn. If it is, WARN again. So a WARN after each new candidate is rolled. Hmm — is that spam? Each warn corresponds to a new layer being rolled and the trend continuing. That's arguably informative, not spam. Hmm.

Actually — the design says "one WARN per episode, reset when the side has an unrolled layer or drops below cap". So a "reset when a candidate exists" is intended, and a re-warn when the candidate is consumed and the trend continues. So OK.

Hmm — but the prompt asks "Can either spam...?" I think it's bounded. OK.

**Let me now write the report. But first, let me look for one more potential bug in the extreme/reset.** 

Hmm — actually, let me reconsider T-2 once more with a focus on the ROLLED EXIT vs the RE-ADD. Hmm — wait, the prompt's wording: "Can a rolled exit fill AND the real re-add fill with no OnTick in between". The "rolled exit" fill and the "re-add" fill. The rolled exit fill → EXT ENT (depth 8, exit_position set). Hmm — the rolled exit fill doesn't change the depth. Then the CloseBy. Hmm.

Actually — maybe they mean: the rolled exit's CLOSEBY removes the layer (depth 7), and the re-add (a new layer) restores depth 8. Between them, if no OnTick, the extreme survives. As analyzed, the re-add requires an add to be placed at depth < cap, which requires an OnTick that resets. So HOLDS. Hmm — BUT: what if the re-add was already PENDING when the layer was removed? I.e., the add was placed BEFORE the roll? At cap, no add is placed. Hmm. So no.

OK, HOLDS.

Hmm — actually here's one that DOES break: what if the fill_time_place places an add at depth < cap via TryPlaceAddAtFill, and this happens WITHOUT an OnTick seeing that depth. Let me construct:

- depth 7 (from an OUT_BY). Last OnTick (T1) saw depth 7 and RESET (tracking false). Hmm — so the tracking is false. Then the ENT fills (depth 8) before T2. At T2, the tracking is false → re-derive. OK.

- Hmm — so it's fine.

What if the OUT_BY happens, and BEFORE any OnTick, the reassembly happens? For the ENT to fill, it must be pending. For it to be pending, it was placed at depth < cap. Which implies an OnTick saw depth < cap, resetting the tracking. So the extreme is reset. OK.

FINAL: T-2 HOLDS.

Hmm — I've spent a lot on T-2. Let me move on and just present it as HOLDS-with-caveat. Actually — hold on. Let me reconsider the track keyed on `depth < max_layers`. What if depth stays 8 but the COMPOSITION changes (one layer out, one in) via OnTradeTransactions only? We've established that the "in" requires a pending add placed at depth < cap → an OnTick at depth < cap → reset. So the composition change requires an OnTick at depth < cap. So the reset happens. OK. HOLDS.

Hmm — wait, unless the "in" is the SAME layer coming back? No.

OK. HOLDS.

Let me now also verify T-3's specific question: "what happens while it returns -1 during history sync, tick after tick?" — Each tick, a CopyTicksRange call returns -1 quickly; nothing else happens. But — hmm, does a failed CopyTicksRange clear/reset the terminal's tick cache or trigger a re-download each time? I believe a failed call (ERR_HISTORY_NOT_FOUND) may trigger a request and return immediately. So each OnTick does a failed call. That's not a "block". OK. So T-3 HOLDS (accept).

"Any path where it blocks every tick?" — If CopyTicksRange returns a cap-limited number of ticks < the full range AND the range keeps growing, each tick returns the max chunk and the cursor advances by that chunk. If the range in the history always exceeds the cap (e.g., a busy symbol retraining 24 h and the cap is small), then EVERY tick reads a max-size chunk, which could be slow. Hmm. But the cursor advances, so eventually it catches up — unless new ticks arrive faster than the catch-up rate. Hmm. On a busy symbol with a large once-24h backlog, the first tick returns chunk 1 (oldest), then chunk 2, etc. The newest ticks aren't read until the backlog is consumed. During that time, the extreme is based on OLD ticks + the live fold (which IS the current price). So the live fold keeps the extreme current. Hmm — so it's not a correctness issue.

Hmm — but the LIVE FOLD is only at the TRACKING (top). And `extreme` folds live. So the current price is in the extreme. Good.

OK — T-3 HOLDS with a note.

Now — let me finalize. I realize I should look at whether `Grind_LatticeFoldExtreme`'s `from_msc` filtering duplicates `Grind_LatticeTickExtreme`'s filtering. It passes `from_msc` to the pure function which ALSO filters. So double filtering. Harmless.

Hmm — one thing: `Grind_LatticeFoldExtreme` is passed `g_grind_vl_from_msc_long` as `from_msc`. But the ticks returned by the seam/live are already >= from_msc. So double filter is a no-op. OK.

**Wait — an important potential bug!** In `Grind_LatticeTrackOneSide`, the cursor `from` is advanced AFTER the fold:
```cpp
      const int n = Grind_LatticeCopyTicks(g_grind_vl_from_msc_long, msc, bid, ask);
      if(n < 0)
         return;
      Grind_LatticeFoldExtreme(true, g_grind_vl_from_msc_long, msc, bid, ask, n, g_grind_vl_extreme_long);
      if(n > 0)
         g_grind_vl_from_msc_long = msc[n - 1] + 1;
```

OK — the fold uses the OLD `from`. Then the cursor advances. Fine.

Hmm — the SUBTLE bug: after the first OnTick, `from` = the newest tick's msc + 1. On the NEXT OnTick, the live fold captures the current price. So the extreme includes the current price from the previous OnTick (folded). Good.

Hmm — but the tick-history read on the next OnTick starts at `from = prev_last_msc + 1`. So it excludes the ticks already read. Good.

OK.

**One more: the FIRST read at a restart uses `from = max(newest+1, now-24h)`. If `now - 24h > newest + 1` (i.e., the newest open is older than 24 h... wait, no: if the newest open is older than 24 h, then newest+1 < now-24h, so from = now-24h). So the window is capped at 24 h. OK.

Alright — let me also double-check the "no roll" tests for correctness (VC4, VC10A).

VC4: tick at 09:05 < from (09:07:01) → excluded. So the extreme = live only = 1.20700. Level 1.20600. No roll. But hmm — is the tick REALLY excluded? Let me check the seam: `if(g_grind_vl_test_tick_msc[i] < from_msc) continue;`. from_msc = max((newest+1)*1000, (now-24h)*1000). newest = 09:07 → (09:07:01)*1000. now = 10:00. now-24h = the previous day 10:00. So max = 09:07:01. The tick at 09:05 → msc = 09:05:00 * 1000 < 09:07:01 * 1000 → excluded. OK. So VC4 passes.

Hmm — but `Grind_LatticeTrackOneSide` also folds the LIVE price = 1.20700. And the extreme = 1.20700. Level 1.20600. No cross. OK.

OK, VC4 passes.

Hmm — one concern: the tests use `Grind_MarketTestSeed(1.20690, 1.20700, 0, 0)` which sets `g_grind_market_test_active = true`. And `Grind_MarketTimeMsc()` uses `g_grind_market_test_time_active` (a different flag). If the market test is active but the time test isn't, `Grind_MarketTimeMsc()` calls `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` — the REAL symbol time. Hmm — but the seam path in `Grind_LatticeCopyTicks` is taken (because `g_grind_order_test_active` is true), so `Grind_MarketTimeMsc()` isn't called. Good. In production, `g_grind_order_test_active` is false. OK.

**Hmm — is `g_grind_order_test_active` true during the VC tests?** `C55_Reset` → `Adr162b_Reset()`. Let me assume Adr162b_Reset sets `g_grind_order_test_active = true`. Actually — let me look at the C55 tests: they call `Grind_OrderTestRemove`, `Grind_OrderTestFind`, etc. So the order test is active. And `Adr162b_SeedLong8` presumably calls `Grind_OrderTestReset()` (which sets active = false) and then sets active = true? Hmm. Let me just assume the tests set it.

If `g_grind_order_test_active` is FALSE during the VC tests, `Grind_LatticeCopyTicks` would call the LIVE `CopyTicksRange` — which would return the REAL tick history (not the test ticks). The tests would fail. So it must be true. OK.

OK — I'm confident. Let me write.

Actually — hold on. Let me reconsider the count of PASS in both states, and one specific: "VC2 found". In commit 1, the stub returns false → the assert `AssertTrue("VC2 found", ...)` FAILS. Hmm — the prompt says the FAIL list is "the 23 rows marked FAIL". Let me check the table: VC2's rows are marked FAIL. Yes.

OK.

Now — let me also note a possible issue: the tests use `AssertNear("VC1 min ask", x, 1.19990, 1e-9)`. But `x` isn't reset between asserts in VC1! The first call sets x = 1.19990. The second call (`from 2500`) returns false but doesn't modify x (the function returns false without setting extreme_out?). Hmm — actually, `Grind_LatticeTickExtreme` returns false but if no tick qualifies, `extreme_out` is untouched. So x stays 1.19990. The assert only checks the return value. OK.

And the third assert: `AssertNear("VC1 min ask", x, 1.19990)` happens BEFORE the "nothing in range" assert. So x is 1.19990 at that point. OK.

Alright, writing the report now.

Let me also decide the PREMISE VERDICT: safe to merge with lattice OFF → yes (all B2 gated by `if(!enabled) return;`). B2 consistent with the operator's rule with it ON → yes, with the caveats (T-1..T-6) and the deploy precondition (`CopyTicksRange` verified on Wine; the new WARN codes in the banner — C56).

Hmm — one thing worth flagging for the merge: the new WARN codes are emitted but not on the pipshed allow-list. If the banner's allow-list filters WARNs, the operator won't see ROLL_STRANDED / ROLL_CLOSING_STUCK until C56. So "the branch emits warnings that the monitoring won't surface" — a deploy gap, not a merge blocker for the OFF case.

Let me now also double-check the "G5" claim and the six helpers. The prompt says `00e0e4e` removes `static` from six file-scope helpers. Since I can't diff, I'll note that the current code has no `static` on file-scope functions in the audited files, and I cannot verify the diff = only those six (no other files touched). I'll mark it "UNVERIFIED (no diff available); current state consistent".

Hmm, the prompt says to verdict each given as VERIFIED or FALSE. For G5, I'll say UNVERIFIABLE → treat as "cannot confirm", and note the risk: a diff that touches anything else (e.g., logic) would be invisible.

Hmm — actually, let me reconsider. Perhaps I can find evidence in the code. The six `static` helpers — which were they? Likely `Grind_LatticeFoldExtreme`, `Grind_LatticeTrackOneSide`, `Grind_LatticeMaybeStranded`, `Grind_LatticeNoteClosing`, `Grind_LatticeResetClosingState`, `Grind_LatticeLowestEffective`? Six. And now they're non-static. Hmm — in the code, all six are non-static. Consistent.

OK. Writing.

Let me be careful to QUOTE lines.

For T-1, quote: `g_grind_vl_from_msc_long = msc[n - 1] + 1;` and `const int n = CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)Grind_MarketTimeMsc());` and `if(msc[i] < from_msc) continue;`.

For T-2, quote: `if(depth < max_layers) {` ... and `if(!g_grind_vl_tracking_long) {`, and the add placement `if(!Grind_CanPlaceEntryLayer(n, max_layers)) return false;` (from SendNextAddEnt). Hmm — actually `const int n = Grind_SideDepth(side); if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) return false;`.

For T-3, quote the read and the cursor advance.

For T-4, quote the latch clears and the note.

For T-5, quote `if(!enabled) return;` and `if(depth < max_layers) {`.

For T-6, quote the TrackExtremes-before-blocked line.

For T-7, quote test lines.

OK — writing now. Let me be concise but complete. I'll structure per the OUTPUT spec.

One more consideration — I should mention the "silent failure" in `Grind_LatticeTrackOneSide` where a single `Grind_CarryPositionOpenTime` failure returns early and skips the side (silently disabling catch-up). Quote: `if(!Grind_CarryPositionOpenTime(pos, magic, ot)) return;`.

And the "extreme folds bogus ticks" (only > 0 filter). Quote: `if(ask[i] <= 0.0) continue;`.

And the ROLL_STRANDED detail `stuck_s` hardcoded.

OK, and the test gap: the live `CopyTicksRange` branch is never executed by any test → quote `MqlTick t[]; const int n = CopyTicksRange(...)`. Since the tests always set `g_grind_order_test_active`, the live branch is dead in tests. So a wrong argument/type in the live call wouldn't fail any test.

Alright, final answer.

Let me write it out.

Also — I should mention the operator's rule consistency: the "S = 2 on the live market" and the "extreme only for the crossing test" etc.

Let me write the output now. I'll aim for thorough but not bloated.

One more check on T-4 "fire on a healthy book (a side that is stranded only on the extreme)". Quote `Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now);` — passes `mkt` (live). And inside, `if(!Grind_LatticeLevelCrossed(is_long, mkt, stranded_level)) return;`. So the extreme isn't used. So a side stranded only on the extreme won't warn. HOLDS (correct isolation). Good — that's actually a positive finding.

Hmm — but wait: the stranded CHECK is reached only in the loop, and the loop is entered only if the EXTREME crosses the level (`probe`). So a side "stranded only on the extreme" — meaning the live market is NOT 2 steps beyond but the extreme is far. Hmm, if the live market isn't beyond the level, then... the level = anchor - add. If the live market isn't <= level, the loop breaks BEFORE idx < 0, so MaybeStranded is never reached. So no warn. OK — the extreme doesn't cause a stranded warn. But the extreme CAN cause the loop to reach idx < 0 and then check the live market (which won't cross) → no warn. So HOLDS.

Hmm — actually, hold on. Suppose the extreme is far beyond but the live market came back. The loop: probe = extreme → crosses level → idx < 0 (all rolled) → MaybeStranded(mkt=live). The live market is back near the grid, so it doesn't cross stranded_level → no warn. OK. So no spurious warn. HOLDS.

OK, writing.

Let me make sure to give `file`, `function`, and the quote for each claim.

Final structure:
- GIVENS CHECK (G1-G5)
- T-1 ... T-7
- PREMISE VERDICT
- TEST GAPS

Let me write.

## Final Report

## GIVENS CHECK

**G1 — VERIFIED.** `grind_pure.mqh`, `Grind_LatticeTickExtreme`: `if(msc[i] < from_msc) continue;`, then `if(ask[i] <= 0.0) continue;` / `if(bid[i] <= 0.0) continue;`, and `if(!found || ask[i] < extreme_out)` (long) / `if(!found || bid[i] > extreme_out)` (short). Min ask / max bid, non-positive skipped, `msc < from` skipped.

**G2 — VERIFIED.** `grind_engine.mqh`, `Grind_LatticeCopyTicks`: the seam is guarded by `if(g_grind_order_test_active) {`, and the live branch is the unconditional tail `MqlTick t[]; const int n = CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)Grind_MarketTimeMsc());`. Nothing else in the tree sets `g_grind_order_test_active = true` outside tests.

**G3 — VERIFIED.** `grind_engine.mqh`, `Grind_LatticeTrackOneSide`: `if(depth < max_layers) {` … resets all seven per-side variables (`tracking`, `extreme`, `from_msc`, `stranded_warned`, `closing_ticket`, `closing_since`, `closing_warned`), quoting `g_grind_vl_closing_warned_long = false;` as the last write before `return;`. The test-seam arrays are correctly *not* reset here.

**G4 — VERIFIED.** `grind_engine.mqh`, `Grind_LatticeTrySide`: `const double probe = extreme > 0.0 ? (is_long ? MathMin(mkt, extreme) : MathMax(mkt, extreme)) : mkt;` gates only `if(!Grind_LatticeLevelCrossed(is_long, probe, level)) break;`. The stranded path passes the live price: `Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now);`, and inside, `if(!Grind_LatticeLevelCrossed(is_long, mkt, stranded_level)) return;`.

**G5 — CANNOT VERIFY (no diff).** The audited snapshot carries no `static` on any file-scope helper (e.g. `Grind_LatticeFoldExtreme`, `Grind_LatticeTrackOneSide`, `Grind_LatticeMaybeStranded`, `Grind_LatticeNoteClosing`, `Grind_LatticeResetClosingState`, `Grind_LatticeLowestEffective` are all plain). I cannot confirm from one tree that `00e0e4e` changed *only* six keywords and nothing else; the commit hash is asserted, not shown. Treat as UNVERIFIED; if the compiler rejected `static` on these six, the change is cosmetic (MQL5 already gives file-scope functions internal linkage), so risk is low — but nothing in the suite distinguishes it.

---

## T-1 — Tick-history semantics: **HOLDS**

- Range bounds are inclusive in MQL5 and the code's cursor is `from`. The advance is `g_grind_vl_from_msc_long = msc[n - 1] + 1;`. If a *new* tick shares the **same** `time_msc` as the last one already read, the next call starts at `last+1` and it is skipped. This is direction-safe: a skipped lower ask (long) / higher bid (short) can only *remove* a would-be roll, never add one. Net effect: a (rare) missed roll, not a spurious one.
- Ticks newer than the current tick cannot inflate the extreme: the live call is bounded by `(ulong)Grind_MarketTimeMsc()`, i.e. `SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC)` (the just-delivered tick), so anything later is outside `[from,to]`.
- Non-positive ask/bid are dropped; `COPY_TICKS_INFO` returns bid/ask-change ticks, so any tick whose ask is unchanged (and thus unneeded) is filtered by the terminal, not by us.
- The one real unsafe vector is a **bogus but positive** price in the historical feed (fat finger/data gap): `if(ask[i] <= 0.0) continue;` accepts `0.00001`. Such a tick makes the extreme absurdly low (long), the roll fires, and the exit is clamped passive (`Grind_ExitQClampPassive`) to the live market. No sanity band is applied. **Smallest fix:** bound each tick's ask/bid against a plausible fraction of the live mid (e.g. reject ticks more than a few grid widths from the live price) before folding. This is an addition, not a re-open of GD1.

Verdict: HOLDS.

---

## T-2 — Stale extreme across a refill: **HOLDS (with a fragility worth a defensive fix)**

The reset is sampled at `Grind_LatticeOnTick` only — `Grind_LatticeTrackOneSide` resets when `if(depth < max_layers) {`, and tracking is only (re)seeded under `if(!g_grind_vl_tracking_long) {`. So if the side goes 8 → 7 → 8 entirely between two OnTicks, the stale extreme survives.

However, in *this* architecture the re-add cannot be placed at cap: `Grind_SendNextAddEnt` refuses with `const int n = Grind_SideDepth(side); if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) return false;`, and `Grind_CanPlaceEntryLayer` is `(current_layers < max_layers)`. The only "immediate" re-add is `Grind_TryPlaceAddAtFill` (called from the `c_role == "ENT"` branch of `Grind_HandleSideDealFill`), and it is a no-op at depth==8 for the same reason (`TryPlaceAddAtFill` → `SendNextAddEnt` → depth check). The exit-fill path that drops depth is `DEAL_ENTRY_OUT_BY`, which does **not** call `TryPlaceAddAtFill`:

> `Grind_RemoveLayerAt(side, i); Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips); return;`

So every re-add is necessarily *placed* on an OnTick that already saw `depth < max_layers` (which reset the state) — hence the extreme does not leak into a new cap episode in the shipped flow. Restart: all B2 globals start `false`/`0.0`, and the window is re-derived from `Grind_CarryPositionOpenTime`, so a restart with a different book also re-derives.

Fragility: the reset is keyed on *sampled* depth, not on the actual side composition, so any future change that places adds inside `OnTradeTransaction` at cap (or any broker/bridge that processes out+in between two OnTicks) will resurrect the stale extreme and roll a level the market never reached after the re-add. **Smallest fix (defensive, no behaviour change today):** cache the side's newest open per side and, in the `tracking==true` branch, compare against the freshly-derived newest; on change, force `tracking=false` (re-derive window and zero the extreme). This is exactly the `A4` timestamp already available with no GV.

---

## T-3 — Cost of a read: **HOLDS (accept), with two notes**

- First read at restart/at-cap: `CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)Grind_MarketTimeMsc())` with `from` = `MathMax((long)(newest + 1) * 1000, (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000)` — up to 24 h of ticks. It is synchronous, on the main thread, inside `OnTick`, and 11 instances each do their own at cap. On a Wine box with GBPUSD class tick rates this can be tens to hundreds of milliseconds, occasionally ~1 s; times 11 that is a start-up stall, not a per-tick one. After the first call the cursor is `msc[n-1]+1`, so steady-state reads are a handful of ticks.
- Failure (`n < 0`) returns immediately: `if(n < 0) return;` — no retry loop, no re-read of the same big range within one tick; the next tick repeats a *cheap* failing call. It cannot block every tick inside one call.
- Note 1: semantics on total failure is silent (accepted GD6) — B2 quietly degrades to B1 forever; the prompt already lists this as a deploy precondition, correct.
- Note 2: if the terminal caps the per-call tick count, the cursor advances by that chunk per tick, so catches up *oldest-first* and the latest past ticks arrive only after the backlog drains — the live fold in `Grind_LatticeFoldExtreme` (`const double live = is_long ? Grind_MarketAsk() : Grind_MarketBid();`) covers the current price meanwhile, so the extreme is never *below* the current price; the miss is only of intermediate history, in the safe direction for a long/second-order for a short. Acceptable if residual.

Verdict: HOLDS.

---

## T-4 — Latches: **HOLDS**

- `ROLL_STRANDED`: one fire per episode via `g_grind_vl_stranded_warned_*`, cleared both at the top of `Grind_LatticeTrySide` (`if(Grind_LatticeCandidateIndex(side, is_long) >= 0)`) and below cap. It cannot fire on the extreme: `Grind_LatticeMaybeStranded` compares `mkt` (live) only. It *will* fire on a genuine 2-add-step trend with all layers rolled — by design (`GD4`), an investigate, not an abandon. One nuance: the top-of-loop clear and a same-call `idx < 0` re-fire can co-occur after the last candidate is consumed, so successive "candidate appears → consumed → still 2 steps beyond" cycles each warn once. Bounded, and consistent with "one WARN per episode".
- `ROLL_CLOSING_STUCK`: 60 s on the *same* position (`if(g_grind_vl_closing_ticket_long != pos)` resets the timer; the `else if(!warned && now - since >= GRIND_VL_CLOSING_WARN_SEC)` fires once); reset when the loop ends without a closing stop (`if(!closing_stop) Grind_LatticeResetClosingState(is_long);`) and below cap via the tracking reset. A healthy few-second CloseBy cannot reach 60 s; a not-crossed market breaks before the closing check and the timer is *reset* rather than continuing to accumulate — that is the design's "candidate stays closing" wording, not a defect, but it does mean a layer that is closing for hours while the level is *never* crossed is never reported.
- The `stuck_s` field is the constant, not the observed elapsed time: `IntegerToString(GRIND_VL_CLOSING_WARN_SEC)`. Cosmetic; if it ever fires at 65 s it will still say 60.

Verdict: HOLDS.

---

## T-5 — Off means off: **HOLDS**

With `InpVirtualLattice=false`, `Grind_LatticeOnTick` returns on the first line: `if(!enabled) return;` — before `Grind_LatticeTrackExtremes`. No reads, no resets, no WARNs, no `TrySide`. The new file-scope test helpers (`Grind_LatticeTestAddTick`, …) are only invoked from the test include. With it on and the side below cap, the tracking path returns after `if(depth < max_layers) { … return; }`, and `Grind_LatticeOnTick` guards both `TrySide` calls with `if(Grind_SideDepth(g_grind_long) >= max_layers)` / `…short…`. Below cap, B2 changes nothing observable.

Verdict: HOLDS.

---

## T-6 — Blocked instances: **HOLDS**

Tracking runs while halted/quarantined by design (`Grind_LatticeTrackExtremes(magic, max_layers, now);` sits before `if(blocked) return;`). The work it does is: a `CopyTicksRange` (a read), in-memory folding/advance, and (only on the below-cap branch) resets of the `g_grind_vl_*` scalars. None of that touches the halt flag, `g_grind_quarantined`, the reconstruction state, the processed-deal set, the CloseBy queues, or the carry-pass work arrays. The two WARN emitters are unreachable while blocked because they live inside `Grind_LatticeTrySide`, which returns at `if(!enabled || blocked) return 0;` before any note. The tracked extreme is *meant* to carry across a quarantine (ADR s1 as taken literally), so this is intended, not interference.

One real coupling to flag: because the extreme is folded with the live price on the *tracking* call (before `blocked`), an instance that is blocked/quarantined for a long time still accumulates the live extreme; on unblock it rolls against it. That matches GD2, but it means a quarantine that lasts hours will produce a "catch-up roll" whose crossing happened entirely during the quarantine — verify that is what the operator wants when the lattice is armed on Fleet B.

Verdict: HOLDS.

---

## T-7 — Tests: **NEEDS-FIX (coverage gaps), no vacuous assertions found**

Coverage that exists and does fail without the implementation: the pure function (VC1/VC2), catch-up roll (VC3/VC6), window start (VC4), ask-vs-bid (VC5), gap loop (VC7), cross-tick extreme (VC8), copy failure (VC9), 24 h cap (VC10), below-cap reset (VC11), backoff-keeps-extreme (VC12), stranded (VS1/VS2), closing stuck (VCS1/VCS2), carry pass (LB40–LB43). My mechanical count of new `Assert*` calls is **57** (VC 26, VS 6, VCS 6, LB 19) — matches the prompt.

Gaps that no test can fail:

1. **The live read is dead in tests.** Every test runs with `g_grind_order_test_active` true, so `Grind_LatticeCopyTicks` always takes `if(g_grind_order_test_active) {` and the line `const int n = CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)Grind_MarketTimeMsc());` is never executed. A wrong argument type, a misnamed flag, or a bad `to_msc` in the live branch would pass 2114/2114. This is the branch that matters on Fleet B.
2. **The `to_msc` bound is untested.** The seam copies *all* ticks with `msc >= from`, so a future-dated test tick would still be folded; production relies on the terminal's `to` bound, which no test exercises.
3. **Same-`time_msc` handling** (the T-1 skip) has no test at all — `Grind_LatticeTestAddTick` always writes `(long)t * 1000` at 1 s resolution.
4. **`Grind_LatticeFoldExtreme`'s live fold** is not tested: every VC reads a qualifying historical tick, so the branch `if(extreme <= 0.0) extreme = live;` and the `MathMin/MathMax` live combination are never the sole source of a roll. VC9 is the closest, but it fails the whole read rather than exercising "n == 0 with a valid live price".
5. **The per-layer `Grind_CarryPositionOpenTime` failure path** is untested: `if(!Grind_CarryPositionOpenTime(pos, magic, ot)) return;` silently skips the entire side for that tick. No test makes any layer's open-time lookup fail, so the "catch-up silently never starts" branch is invisible.
6. **T-2's ordering** (refill with no intervening OnTick, restart with a different book) is untested — and, as argued, currently not reachable in the shipped flow, so it *needs* a test only if you take the defensive fix.
7. **Vacuousness check on existing rows:** the PASS-in-both rows are all legitimate negatives ("no roll", "no warn"), except that several are only meaningful paired with a positive in the same test (VC5, VC7's L2, VC11). None of the assertions sits inside an `if`, none reads leftover state across `C55_Reset()` boundaries (each test opens and closes with `C55_Reset();`), and none uses a fixture that cannot reach the code. **No vacuous assertion found.**

Smallest fix: add one test that calls a thin live-path shim (or drives `Grind_LatticeCopyTicks` with `g_grind_order_test_active == false` under the market/time seam) so the `CopyTicksRange` call and its `to_msc` bound are actually executed; add a VC that forces `n == 0` with a live ask below the level to pin the live fold.

---

## PREMISE VERDICT

- **Merge to `main` with `InpVirtualLattice=false`: safe.** Every B2 entry point is behind `if(!enabled) return;` in `Grind_LatticeOnTick`, the new globals initialise to `false`/`0.0`, and the new test helpers are only reachable from the test include. Nothing in `grind_carry.mqh`, the queue, reconstruction, or the presets is touched by B2 (the only edits to existing code are the six new globals, the `Grind_LatticeResetBackoff` extension, the `Grind_LatticeOnTick` reordering, and the new default argument on `Grind_LatticeTrySide`).
- **With it ON: consistent with the operator's rule**, subject to the accepted GD rulings and two operational caveats: (a) GD6's silent failure is a real silent failure on an unverified Wine box — confirm `CopyTicksRange` returns ticks there before arming Fleet B; (b) the two new WARN codes are emitted but are not on pipshed's `WARN_CRITICAL_ALLOW` allow-list (A8/C56), so until C56 ships the operator will not see `ROLL_STRANDED` / `ROLL_CLOSING_STUCK` in the banner — a monitoring gap, not a merge blocker for the OFF case. The semantics themselves implement GD2–GD5 faithfully (extreme only for crossing, live market for stranded, 1 s + 24 h window, S = 2, 60 s closing, silent retry).

---

## TEST GAPS (condensed)

- Live `CopyTicksRange` branch and its `(ulong)Grind_MarketTimeMsc()` upper bound: **never executed** (seam short-circuits it) — the only production-relevant read is untested.
- `to_msc` bound, multiple ticks sharing one `time_msc`, and future-dated seam ticks: untested.
- Live-price-only fold (`n == 0` case) of `Grind_LatticeFoldExtreme`: untested.
- `Grind_CarryPositionOpenTime` lookup failure (silent per-side skip): untested.
- T-2 ordering (refill between two OnTicks; restart with a different book): untested, and today unreachable — add a test only alongside the defensive reset-on-newest fix.
- Non-positive/garbage tick filter beyond `> 0` (sanity band on historical prices): untested and unfiltered in code.

Line count: 112

<!-- finish_reason=stop -->
