//+------------------------------------------------------------------+
//| fxmatrix_v2_signal_dispatch.mqh — BC/AB signal dispatch (Phase 1)  |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_SIGNAL_DISPATCH_MQH
#define FXMATRIX_V2_SIGNAL_DISPATCH_MQH

#ifndef FXMATRIX_V2_SIGNAL_MQH
#include "fxmatrix_v2_signal.mqh"
#endif

bool Long_ComputeBidSignal(double &bid_theoretical)
{
#ifdef V2_SIGNAL_AB_SLOT
   string leg_ac = V2_LEG_AC_SYMBOL;
   string leg_bc = V2_LEG_BC_SYMBOL;
   if(StringLen(InpLegAC) > 0)
      leg_ac = InpLegAC;
   if(StringLen(InpLegBC) > 0)
      leg_bc = InpLegBC;
   return V2_ComputeAbBid(_Symbol, leg_ac, leg_bc,
                          InpQuoteSpread, InpSpreadMultiplier, bid_theoretical);
#else
   return V2_ComputeBcBid(_Symbol, InpQuoteSpread, InpSpreadMultiplier, bid_theoretical);
#endif
}

bool Short_ComputeOfferSignal(double &offer_theoretical)
{
#ifdef V2_SIGNAL_AB_SLOT
   string leg_ac = V2_LEG_AC_SYMBOL;
   string leg_bc = V2_LEG_BC_SYMBOL;
   if(StringLen(InpLegAC) > 0)
      leg_ac = InpLegAC;
   if(StringLen(InpLegBC) > 0)
      leg_bc = InpLegBC;
   return V2_ComputeAbOffer(_Symbol, leg_ac, leg_bc,
                            InpQuoteSpread, InpSpreadMultiplier, offer_theoretical);
#else
   return V2_ComputeBcOffer(_Symbol, InpQuoteSpread, InpSpreadMultiplier, offer_theoretical);
#endif
}

#endif // FXMATRIX_V2_SIGNAL_DISPATCH_MQH
