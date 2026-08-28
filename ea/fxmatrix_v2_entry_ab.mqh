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
bool V2_DumbShouldRePlace(const double last_ref_mid,
                          const double mid,
                          const double band_pips,
                          const double point)
{
   if(last_ref_mid <= 0.0)
      return true;
   const double drift_pips = MathAbs(mid - last_ref_mid) / (point * 10.0);
   return drift_pips > band_pips;
}

//+------------------------------------------------------------------+
//| ADR-121: straddle L0 decouple-and-retry pure helpers.             |
//+------------------------------------------------------------------+
bool V2_StraddleLegShouldAttempt(const bool leg_live, const bool mid_drifted)
{
   if(!leg_live)
      return true;
   return mid_drifted;
}

bool V2_StraddleL0BuyMarketable(const double buy_price, const double ask)
{
   return (buy_price < ask);
}

bool V2_StraddleL0SellMarketable(const double sell_price, const double bid)
{
   return (sell_price > bid);
}

bool V2_StraddleL0CooldownBlocks(const ulong cooldown_until, const ulong now_ms)
{
   return (cooldown_until > 0 && now_ms < cooldown_until);
}

bool V2_StraddleRefMidShouldAdvance(const bool long_flat,
                                    const bool short_flat,
                                    const bool long_leg_live,
                                    const bool short_leg_live)
{
   return (long_flat && short_flat && long_leg_live && short_leg_live);
}

void V2_StraddleRefMidApplyGoalpost(const bool long_flat,
                                    const bool short_flat,
                                    const bool long_leg_live,
                                    const bool short_leg_live,
                                    const double mid,
                                    double &ref_mid)
{
   if(V2_StraddleRefMidShouldAdvance(long_flat, short_flat, long_leg_live, short_leg_live))
      ref_mid = mid;
}

bool V2_StraddleL0ApplySendOutcome(const bool replace_ok,
                                   ulong &cooldown_until,
                                   const ulong now_ms,
                                   const int cooldown_ms)
{
   if(replace_ok)
      return true;
   cooldown_until = now_ms + (ulong)cooldown_ms;
   return false;
}

#endif // FXMATRIX_V2_ENTRY_AB_MQH
