//+------------------------------------------------------------------+
//| fxmatrix_v2_instrumentation.mqh — TEMP verification counters only |
//| ADR-013 clamp events + L0 deadband skips + clamped-fill attribution |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_INSTRUMENTATION_MQH
#define FXMATRIX_V2_INSTRUMENTATION_MQH

#include "../ea/fxmatrix_v2_logic.mqh"

struct V2SideInstrumentStats {
   int clamp_events;
   int l0_deadband_skip;
   int l0_fills_total;
   int l0_fills_from_clamped;
   int l0_fills_from_unclamped;
   bool pending_l0_from_clamped;
};

V2SideInstrumentStats g_v2_inst_long;
V2SideInstrumentStats g_v2_inst_short;

//+------------------------------------------------------------------+
//| Pure clamp core (unit-testable — no SymbolInfo calls).            |
//+------------------------------------------------------------------+
bool V2_Adr013ClampCoreBuy(const double theoretical,
                           const double bid,
                           const double point,
                           const int stops_level,
                           const int digits,
                           double &out_price)
{
   const double min_dist = MathMax(point, (double)stops_level * point);
   if(theoretical >= bid)
      out_price = NormalizeDouble(MathMin(theoretical, bid - min_dist), digits);
   else
      out_price = NormalizeDouble(theoretical, digits);
   return (MathAbs(out_price - theoretical) > point * 0.1);
}

bool V2_Adr013ClampCoreSell(const double theoretical,
                            const double ask,
                            const double point,
                            const int stops_level,
                            const int digits,
                            double &out_price)
{
   const double min_dist = MathMax(point, (double)stops_level * point);
   if(theoretical <= ask)
      out_price = NormalizeDouble(MathMax(theoretical, ask + min_dist), digits);
   else
      out_price = NormalizeDouble(theoretical, digits);
   return (MathAbs(out_price - theoretical) > point * 0.1);
}

//+------------------------------------------------------------------+
//| Pure deadband check (unit-testable — no order ticket lookup).     |
//+------------------------------------------------------------------+
bool V2_PriceWithinL0Deadband(const double resting_price,
                               const double new_price,
                               const double quote_spread,
                               const double multiplier = 1.0,
                               const double pair_spread_pips_ref = 0.0)
{
   if(resting_price <= 0.0)
      return false;
   const double deadband = V2_L0RequoteDeadband(quote_spread, multiplier, pair_spread_pips_ref);
   return (MathAbs(new_price - resting_price) < deadband);
}

//+------------------------------------------------------------------+
//| Runtime recording helpers                                         |
//+------------------------------------------------------------------+
void V2_InstResetSide(V2SideInstrumentStats &s)
{
   s.clamp_events = 0;
   s.l0_deadband_skip = 0;
   s.l0_fills_total = 0;
   s.l0_fills_from_clamped = 0;
   s.l0_fills_from_unclamped = 0;
   s.pending_l0_from_clamped = false;
}

void V2_InstRecordClampEvent(const bool is_long)
{
   if(is_long)
      g_v2_inst_long.clamp_events++;
   else
      g_v2_inst_short.clamp_events++;
}

void V2_InstRecordDeadbandSkip(const bool is_long)
{
   if(is_long)
      g_v2_inst_long.l0_deadband_skip++;
   else
      g_v2_inst_short.l0_deadband_skip++;
}

void V2_InstOnL0QuotePlaced(const bool is_long, const bool quote_was_clamped)
{
   if(is_long)
      g_v2_inst_long.pending_l0_from_clamped = quote_was_clamped;
   else
      g_v2_inst_short.pending_l0_from_clamped = quote_was_clamped;
}

void V2_InstRecordL0Fill(const bool is_long)
{
   if(is_long) {
      g_v2_inst_long.l0_fills_total++;
      if(g_v2_inst_long.pending_l0_from_clamped)
         g_v2_inst_long.l0_fills_from_clamped++;
      else
         g_v2_inst_long.l0_fills_from_unclamped++;
      g_v2_inst_long.pending_l0_from_clamped = false;
   } else {
      g_v2_inst_short.l0_fills_total++;
      if(g_v2_inst_short.pending_l0_from_clamped)
         g_v2_inst_short.l0_fills_from_clamped++;
      else
         g_v2_inst_short.l0_fills_from_unclamped++;
      g_v2_inst_short.pending_l0_from_clamped = false;
   }
}

void V2_InstPrintSideStats(const string prefix, const V2SideInstrumentStats &s)
{
   Print(prefix,
         " adr013_clamp_events=", s.clamp_events,
         " l0_deadband_skip=", s.l0_deadband_skip,
         " l0_fills_total=", s.l0_fills_total,
         " l0_fills_clamped=", s.l0_fills_from_clamped,
         " l0_fills_unclamped=", s.l0_fills_from_unclamped);
}

#endif // FXMATRIX_V2_INSTRUMENTATION_MQH
