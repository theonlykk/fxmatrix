//+------------------------------------------------------------------+
//| fxmatrix_v2_entry_ab.mqh — Parallel dumb-entry A/B (straddle arm) |
//| Pure identity + straddle placement helpers (unit-test target).    |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_ENTRY_AB_MQH
#define FXMATRIX_V2_ENTRY_AB_MQH

#include "fxmatrix_v2_pair_preset.mqh"

#define V2_DUMB_MAGIC_OFFSET 1000000

//+------------------------------------------------------------------+
bool V2_IsLiveV2EntryMagic(const long magic)
{
   const long live_magics[] =
   {
      20260901, 20260902, 20260903, 20260904,
      20260911, 20260912, 20260913, 20260914,
      20260921, 20260922, 20260923, 20260924
   };
   for(int i = 0; i < ArraySize(live_magics); i++) {
      if(magic == live_magics[i])
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void V2_InitPresetCapNamespace(V2PairPreset &preset)
{
   if(preset.cap_namespace == "")
      preset.cap_namespace = preset.chart_symbol;
}

//+------------------------------------------------------------------+
void V2_ApplyStraddleIdentityTransform(V2PairPreset &preset)
{
   preset.magic_long       += V2_DUMB_MAGIC_OFFSET;
   preset.magic_short      += V2_DUMB_MAGIC_OFFSET;
   preset.magic_long_exit  += V2_DUMB_MAGIC_OFFSET;
   preset.magic_short_exit += V2_DUMB_MAGIC_OFFSET;
   preset.tel_instance_long  = preset.tel_instance_long + "_DUMB";
   preset.tel_instance_short = preset.tel_instance_short + "_DUMB";
   preset.cap_namespace = preset.chart_symbol + "_DUMB";
}

//+------------------------------------------------------------------+
double V2_DumbStraddleMid(const double bid, const double ask)
{
   return (bid + ask) * 0.5;
}

//+------------------------------------------------------------------+
double V2_DumbStraddleBuyPrice(const double mid,
                               const double straddle_pips,
                               const double point)
{
   return mid - straddle_pips * point * 10.0;
}

//+------------------------------------------------------------------+
double V2_DumbStraddleSellPrice(const double mid,
                                const double straddle_pips,
                                const double point)
{
   return mid + straddle_pips * point * 10.0;
}

//+------------------------------------------------------------------+
//| ADR-122/123: straddle feed staleness + place-once pure helpers.  |
//+------------------------------------------------------------------+
bool V2_FeedStaleElapsed(const ulong now_local,
                         const ulong last_seen_local,
                         const ulong max_age_ms)
{
   return (now_local - last_seen_local) > max_age_ms;
}

bool V2_FeedStaleAfterTick(const long tick_msc,
                           long &last_feed_tick_msc,
                           ulong &last_feed_seen_local,
                           const ulong now_local,
                           const ulong max_age_ms)
{
   if(tick_msc != last_feed_tick_msc) {
      last_feed_tick_msc = tick_msc;
      last_feed_seen_local = now_local;
      return false;
   }
   return V2_FeedStaleElapsed(now_local, last_feed_seen_local, max_age_ms);
}

bool V2_StraddleL0BuyMarketable(const double buy_price, const double ask)
{
   return (buy_price < ask);
}

bool V2_StraddleL0SellMarketable(const double sell_price, const double bid)
{
   return (sell_price > bid);
}

bool V2_StraddleL0ShouldPlaceLeg(const bool side_flat, const bool leg_is_ours_live)
{
   return (side_flat && !leg_is_ours_live);
}

bool V2_StraddleL0TickAllowsAction(const bool feed_stale,
                                   const bool long_flat,
                                   const bool short_flat)
{
   if(feed_stale)
      return false;
   return (long_flat || short_flat);
}

double V2_StrandedDriftPipsPure(const double placement_mid,
                                const double current_mid,
                                const double point)
{
   return MathAbs(current_mid - placement_mid) / (point * 10.0);
}

double V2_StrandedDistFromMidPipsPure(const double resting_price,
                                      const double current_mid,
                                      const double point)
{
   return MathAbs(resting_price - current_mid) / (point * 10.0);
}

bool V2_StrandedFlagPure(const double drift_from_mid_pips,
                         const double thresh_pips)
{
   return (drift_from_mid_pips > thresh_pips);
}

long V2_StrandedRestDurationSecPure(const datetime now_time,
                                    const datetime placement_time)
{
   if(placement_time <= 0)
      return 0;
   return (long)(now_time - placement_time);
}

bool V2_DumbShouldRecenterPure(const double dist_mid_pips,
                               const double thresh_pips)
{
   return (dist_mid_pips > thresh_pips);
}

bool V2_DumbRecenterEligiblePure(const bool entry_straddle,
                                 const bool opposite_flat,
                                 const bool opposite_has_l0,
                                 const double dist_mid_pips,
                                 const double thresh_pips)
{
   if(!entry_straddle)
      return false;
   if(!opposite_flat)
      return false;
   if(!opposite_has_l0)
      return false;
   return V2_DumbShouldRecenterPure(dist_mid_pips, thresh_pips);
}

#endif // FXMATRIX_V2_ENTRY_AB_MQH
