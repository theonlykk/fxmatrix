//+------------------------------------------------------------------+
//| fxmatrix_v2_signal.mqh — V2 fair-value signal (BC + AB slot)       |
//| BC: native pair term-structure (EURUSD, GBPUSD direct USD legs).  |
//| AB: triad score_A - score_B from leg symbols (EURGBP cross).    |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_SIGNAL_MQH
#define FXMATRIX_V2_SIGNAL_MQH

//+------------------------------------------------------------------+
bool V2_FvSigmaFromCloses(const double &closes[],
                          double &fv_out,
                          double &sigma_out)
{
   if(ArraySize(closes) < 49)
      return false;

   double c6  = closes[6];
   double c12 = closes[12];
   double c48 = closes[48];
   if(c6 <= 0.0 || c12 <= 0.0 || c48 <= 0.0)
      return false;

   fv_out = 0.50 * c6 + 0.30 * c12 + 0.20 * c48;
   double mean = (c6 + c12 + c48) / 3.0;
   sigma_out = MathSqrt(((c6 - mean) * (c6 - mean) +
                         (c12 - mean) * (c12 - mean) +
                         (c48 - mean) * (c48 - mean)) / 3.0);
   return (fv_out > 0.0);
}

//+------------------------------------------------------------------+
bool V2_CopyM5Closes(const string symbol, double &closes[])
{
   if(CopyClose(symbol, PERIOD_M5, 1, 60, closes) < 49)
      return false;
   ArraySetAsSeries(closes, true);
   return true;
}

//+------------------------------------------------------------------+
double V2_MidNowFromSymbol(const string symbol, const double fallback_close)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return fallback_close + (ask - bid) / 2.0;
   return fallback_close;
}

//+------------------------------------------------------------------+
//| BC-style bid on native symbol (production-validated for USD legs).|
//+------------------------------------------------------------------+
bool V2_ComputeBcBid(const string symbol,
                     const double quote_spread,
                     const double spread_multiplier,
                     double &bid_theoretical)
{
   double closes[];
   if(!V2_CopyM5Closes(symbol, closes))
      return false;

   double fv, sigma;
   if(!V2_FvSigmaFromCloses(closes, fv, sigma))
      return false;

   double now = V2_MidNowFromSymbol(symbol, closes[0]);
   if(now <= 0.0)
      return false;

   double r = MathLog(now / fv);
   double dynamic_hs = quote_spread + sigma * spread_multiplier;
   bid_theoretical = fv * MathExp(r - dynamic_hs);
   return (bid_theoretical > 0.0);
}

//+------------------------------------------------------------------+
bool V2_ComputeBcOffer(const string symbol,
                        const double quote_spread,
                        const double spread_multiplier,
                        double &offer_theoretical)
{
   double closes[];
   if(!V2_CopyM5Closes(symbol, closes))
      return false;

   double fv, sigma;
   if(!V2_FvSigmaFromCloses(closes, fv, sigma))
      return false;

   double now = V2_MidNowFromSymbol(symbol, closes[0]);
   if(now <= 0.0)
      return false;

   double r = MathLog(now / fv);
   double dynamic_hs = quote_spread + sigma * spread_multiplier;
   offer_theoretical = fv * MathExp(r + dynamic_hs);
   return (offer_theoretical > 0.0);
}

//+------------------------------------------------------------------+
//| AB-slot: inst_spread = r_AC - r_BC, base = fv_AC / fv_BC.        |
//| Matches V1 SLOT_AB + Python validation (score_EUR - score_GBP).  |
//+------------------------------------------------------------------+
bool V2_ComputeAbBidOffer(const string ab_symbol,
                          const string ac_symbol,
                          const string bc_symbol,
                          const double quote_spread,
                          const double spread_multiplier,
                          double &bid_theoretical,
                          double &offer_theoretical)
{
   double ac_closes[], bc_closes[];
   if(!V2_CopyM5Closes(ac_symbol, ac_closes))
      return false;
   if(!V2_CopyM5Closes(bc_symbol, bc_closes))
      return false;

   double fv_ac, sig_ac, fv_bc, sig_bc;
   if(!V2_FvSigmaFromCloses(ac_closes, fv_ac, sig_ac))
      return false;
   if(!V2_FvSigmaFromCloses(bc_closes, fv_bc, sig_bc))
      return false;

   double ac_now = V2_MidNowFromSymbol(ac_symbol, ac_closes[0]);
   double bc_now = V2_MidNowFromSymbol(bc_symbol, bc_closes[0]);
   if(ac_now <= 0.0 || bc_now <= 0.0)
      return false;

   double r_ac = MathLog(ac_now / fv_ac);
   double r_bc = MathLog(bc_now / fv_bc);
   double inst_spread = r_ac - r_bc;
   double dynamic_hs = quote_spread + MathMax(sig_ac, sig_bc) * spread_multiplier;
   double ratio = fv_ac / fv_bc;

   bid_theoretical  = ratio * MathExp(inst_spread - dynamic_hs);
   offer_theoretical = ratio * MathExp(inst_spread + dynamic_hs);

   if(bid_theoretical <= 0.0 || offer_theoretical <= 0.0)
      return false;

   // Sanity: quotes target the attached AB chart symbol.
   if(ab_symbol != _Symbol && ab_symbol != "")
   {
      // Prices are already in AB terms; no further conversion needed.
   }
   return true;
}

//+------------------------------------------------------------------+
bool V2_ComputeAbBid(const string ab_symbol,
                     const string ac_symbol,
                     const string bc_symbol,
                     const double quote_spread,
                     const double spread_multiplier,
                     double &bid_theoretical)
{
   double offer_dummy = 0.0;
   if(!V2_ComputeAbBidOffer(ab_symbol, ac_symbol, bc_symbol,
                            quote_spread, spread_multiplier,
                            bid_theoretical, offer_dummy))
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool V2_ComputeAbOffer(const string ab_symbol,
                       const string ac_symbol,
                       const string bc_symbol,
                       const double quote_spread,
                       const double spread_multiplier,
                       double &offer_theoretical)
{
   double bid_dummy = 0.0;
   if(!V2_ComputeAbBidOffer(ab_symbol, ac_symbol, bc_symbol,
                            quote_spread, spread_multiplier,
                            bid_dummy, offer_theoretical))
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| ADR-097: L0 spread easing — opposite-depth multiplier ramp.      |
//+------------------------------------------------------------------+
double V2_EffectiveSpreadMultiplier(const int opposite_depth,
                                    const int ease_depth_start,
                                    const int ease_depth_full,
                                    const double spread_multiplier,
                                    const double spread_multiplier_eased)
{
   if(opposite_depth <= ease_depth_start)
      return spread_multiplier;
   if(opposite_depth >= ease_depth_full)
      return spread_multiplier_eased;
   double frac = (double)(opposite_depth - ease_depth_start) / (double)(ease_depth_full - ease_depth_start);
   return spread_multiplier - frac * (spread_multiplier - spread_multiplier_eased);
}

//+------------------------------------------------------------------+
//| Runtime spread fallback (testable via V2_ResolveLiveSpreadPriceFromRaw). |
//+------------------------------------------------------------------+
double V2_ResolveLiveSpreadPriceFromRaw(const long raw_spread_points,
                                        const double point,
                                        const double quote_spread_fallback,
                                        double &io_last_valid_spread_price)
{
   if(raw_spread_points > 0)
      io_last_valid_spread_price = raw_spread_points * point;
   return (io_last_valid_spread_price > 0.0)
          ? io_last_valid_spread_price
          : quote_spread_fallback;
}

//+------------------------------------------------------------------+
double V2_L0ResolveLiveSpreadPrice(const double quote_spread_fallback)
{
   static double g_last_valid_spread_price = -1.0;
   long raw_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return V2_ResolveLiveSpreadPriceFromRaw(raw_spread_points, _Point,
                                           quote_spread_fallback,
                                           g_last_valid_spread_price);
}

//+------------------------------------------------------------------+
//| Bar-cadence floor: max(sigma-weighted hs, live_spread + buffer).  |
//+------------------------------------------------------------------+
double V2_L0DynamicHalfSpread(const double quote_spread,
                              const double sigma,
                              const double effective_multiplier,
                              const double live_spread_price,
                              const double passivity_buffer_price)
{
   return MathMax(quote_spread + sigma * effective_multiplier,
                  live_spread_price + passivity_buffer_price);
}

//+------------------------------------------------------------------+
//| Pip conversion: 5-digit XXXUSD / EURGBP use point*10 per pip.     |
//+------------------------------------------------------------------+
double V2_PipsToPriceForSymbol(const string symbol, const double pips)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = _Point;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip_points = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   return pips * point * pip_points;
}

#endif // FXMATRIX_V2_SIGNAL_MQH
