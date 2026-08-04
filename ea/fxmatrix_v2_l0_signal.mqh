//+------------------------------------------------------------------+
//| fxmatrix_v2_l0_signal.mqh — unified L0 dispatch (Phase A)          |
//| Pure core: V2_L0CoreComputeBc/Ab (no broker calls).              |
//| Wrapper: V2_L0ComputeBid/Offer (market data + core).               |
//| Extracted from production inlined signal logic, not signal stubs. |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_L0_SIGNAL_MQH
#define FXMATRIX_V2_L0_SIGNAL_MQH

#include "fxmatrix_v2_pair_preset.mqh"
#include "fxmatrix_v2_signal.mqh"

//+------------------------------------------------------------------+
struct V2L0BcInputs
{
   double closes[];
   double bid;
   double ask;
   double quote_spread;
   double spread_multiplier;
   double spread_multiplier_eased;
   int    ease_depth_start;
   int    ease_depth_full;
   double live_spread_price;
   double passivity_buffer_price;
   bool   quoting_side_flat;
   int    opposite_depth;
   bool   compute_bid;
};

struct V2L0AbInputs
{
   double ac_closes[];
   double bc_closes[];
   double ac_bid;
   double ac_ask;
   double bc_bid;
   double bc_ask;
   double quote_spread;
   double spread_multiplier;
   double spread_multiplier_eased;
   int    ease_depth_start;
   int    ease_depth_full;
   double live_spread_price;
   double passivity_buffer_price;
   bool   quoting_side_flat;
   int    opposite_depth;
   bool   compute_bid;
};

struct V2L0SignalContext
{
   double quote_spread;
   double spread_multiplier;
   double spread_multiplier_eased;
   int    ease_depth_start;
   int    ease_depth_full;
   double passivity_buffer_pips;
   int    opposite_depth;
   bool   quoting_side_flat;
   string leg_ac;
   string leg_bc;
};

//+------------------------------------------------------------------+
//| Diagnostics populated alongside theoretical (BC/AB).                |
//+------------------------------------------------------------------+
struct V2L0CoreDiagnostics
{
   double sigma;
   double effective_multiplier;
   double dynamic_hs;
   double sig_ac;
   double sig_bc;
   double fv_ac;
   double fv_bc;
   double ac_now;
   double bc_now;
   double ratio;
   double inst_spread;
   string leg_ac;
   string leg_bc;
   double ac_close0;
   double bc_close0;
   double ac_bid;
   double ac_ask;
   double bc_bid;
   double bc_ask;
};

//+------------------------------------------------------------------+
//| Pure BC path — mirrors production fxmatrix_v2*.mq5 inlined BC.   |
//+------------------------------------------------------------------+
bool V2_L0CoreComputeBc(const double &closes[],
                        const V2L0BcInputs &in,
                        double &theoretical,
                        V2L0CoreDiagnostics &diag)
{
   if(ArraySize(closes) < 49)
      return false;

   double fv, sigma;
   if(!V2_FvSigmaFromCloses(closes, fv, sigma))
      return false;

   double bc_now = closes[0] + (in.ask - in.bid) / 2.0;
   if(fv <= 0.0 || bc_now <= 0.0)
      return false;

   double r_bc = MathLog(bc_now / fv);
   double effective_multiplier = in.spread_multiplier;
   if(in.quoting_side_flat)
   {
      effective_multiplier = V2_EffectiveSpreadMultiplier(
         in.opposite_depth,
         in.ease_depth_start,
         in.ease_depth_full,
         in.spread_multiplier,
         in.spread_multiplier_eased);
   }

   double dynamic_hs = V2_L0DynamicHalfSpread(
      in.quote_spread,
      sigma,
      effective_multiplier,
      in.live_spread_price,
      in.passivity_buffer_price);

   if(in.compute_bid)
      theoretical = fv * MathExp(r_bc - dynamic_hs);
   else
      theoretical = fv * MathExp(r_bc + dynamic_hs);

   diag.sigma = sigma;
   diag.effective_multiplier = effective_multiplier;
   diag.dynamic_hs = dynamic_hs;
   diag.sig_ac = 0.0;
   diag.sig_bc = 0.0;
   diag.fv_ac = 0.0;
   diag.fv_bc = 0.0;
   diag.ac_now = 0.0;
   diag.bc_now = 0.0;
   diag.ratio = 0.0;
   diag.inst_spread = 0.0;
   diag.leg_ac = "";
   diag.leg_bc = "";
   diag.ac_close0 = 0.0;
   diag.bc_close0 = 0.0;
   diag.ac_bid = 0.0;
   diag.ac_ask = 0.0;
   diag.bc_bid = 0.0;
   diag.bc_ask = 0.0;

   return true;
}

//+------------------------------------------------------------------+
bool V2_L0CoreComputeBc(const V2L0BcInputs &in,
                        double &theoretical,
                        V2L0CoreDiagnostics &diag)
{
   return V2_L0CoreComputeBc(in.closes, in, theoretical, diag);
}

//+------------------------------------------------------------------+
//| Pure AB path — mirrors production fxmatrix_v2_eurgbp.mq5 inlined.|
//+------------------------------------------------------------------+
bool V2_L0CoreComputeAb(const double &ac_closes[],
                        const double &bc_closes[],
                        const V2L0AbInputs &in,
                        double &theoretical,
                        V2L0CoreDiagnostics &diag)
{
   if(ArraySize(ac_closes) < 49 || ArraySize(bc_closes) < 49)
      return false;

   double fv_ac, sig_ac, fv_bc, sig_bc;
   if(!V2_FvSigmaFromCloses(ac_closes, fv_ac, sig_ac))
      return false;
   if(!V2_FvSigmaFromCloses(bc_closes, fv_bc, sig_bc))
      return false;

   double ac_now = ac_closes[0];
   if(in.ac_bid > 0.0 && in.ac_ask > 0.0)
      ac_now = ac_closes[0] + (in.ac_ask - in.ac_bid) / 2.0;
   double bc_now = bc_closes[0];
   if(in.bc_bid > 0.0 && in.bc_ask > 0.0)
      bc_now = bc_closes[0] + (in.bc_ask - in.bc_bid) / 2.0;
   if(ac_now <= 0.0 || bc_now <= 0.0)
      return false;

   double r_ac = MathLog(ac_now / fv_ac);
   double r_bc = MathLog(bc_now / fv_bc);
   double inst_spread = r_ac - r_bc;
   double ratio = fv_ac / fv_bc;

   double effective_multiplier = in.spread_multiplier;
   if(in.quoting_side_flat)
   {
      effective_multiplier = V2_EffectiveSpreadMultiplier(
         in.opposite_depth,
         in.ease_depth_start,
         in.ease_depth_full,
         in.spread_multiplier,
         in.spread_multiplier_eased);
   }

   double dynamic_hs = V2_L0DynamicHalfSpread(
      in.quote_spread,
      MathMax(sig_ac, sig_bc),
      effective_multiplier,
      in.live_spread_price,
      in.passivity_buffer_price);

   if(in.compute_bid)
      theoretical = ratio * MathExp(inst_spread - dynamic_hs);
   else
      theoretical = ratio * MathExp(inst_spread + dynamic_hs);

   if(theoretical <= 0.0)
      return false;

   diag.sigma = MathMax(sig_ac, sig_bc);
   diag.effective_multiplier = effective_multiplier;
   diag.dynamic_hs = dynamic_hs;
   diag.sig_ac = sig_ac;
   diag.sig_bc = sig_bc;
   diag.fv_ac = fv_ac;
   diag.fv_bc = fv_bc;
   diag.ac_now = ac_now;
   diag.bc_now = bc_now;
   diag.ratio = ratio;
   diag.inst_spread = inst_spread;

   return true;
}

//+------------------------------------------------------------------+
bool V2_L0CoreComputeAb(const V2L0AbInputs &in,
                        double &theoretical,
                        V2L0CoreDiagnostics &diag)
{
   return V2_L0CoreComputeAb(in.ac_closes, in.bc_closes, in, theoretical, diag);
}

//+------------------------------------------------------------------+
double V2_L0PassivityBufferPriceFromPips(const double pips)
{
   return pips * _Point * 10.0;
}

//+------------------------------------------------------------------+
bool V2_L0LegInputUsable(const string raw)
{
   if(StringLen(raw) == 0)
      return false;
   // Tester/.set corruption: entire pipe-delimited descriptor stored as the value.
   if(StringFind(raw, "||") >= 0)
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool V2_L0ResolveLegSymbols(const V2PairPreset &preset,
                            const V2L0SignalContext &ctx,
                            string &leg_ac,
                            string &leg_bc)
{
   leg_ac = V2_L0LegInputUsable(ctx.leg_ac) ? ctx.leg_ac : preset.leg_ac_symbol_default;
   leg_bc = V2_L0LegInputUsable(ctx.leg_bc) ? ctx.leg_bc : preset.leg_bc_symbol_default;
   return (StringLen(leg_ac) > 0 && StringLen(leg_bc) > 0);
}

//+------------------------------------------------------------------+
void V2_L0PrintAbEaseDiag(const string side,
                          const int opposite_depth,
                          const V2L0CoreDiagnostics &diag)
{
   Print("DIAG V2_", side, " | event=l0_ease | opposite_depth=", opposite_depth,
         " sig_ac=", DoubleToString(diag.sig_ac, 8),
         " sig_bc=", DoubleToString(diag.sig_bc, 8),
         " effective_multiplier=", DoubleToString(diag.effective_multiplier, 6),
         " dynamic_hs=", DoubleToString(diag.dynamic_hs, 6));
}

//+------------------------------------------------------------------+
void V2_L0PrintAbCoreDiag(const string side,
                          const V2L0CoreDiagnostics &diag,
                          const double theoretical)
{
   Print("DIAG V2_", side, " | event=l0_ab_core | leg_ac=", diag.leg_ac,
         " leg_bc=", diag.leg_bc,
         " ac_close0=", DoubleToString(diag.ac_close0, 8),
         " bc_close0=", DoubleToString(diag.bc_close0, 8),
         " ac_bid=", DoubleToString(diag.ac_bid, 8),
         " ac_ask=", DoubleToString(diag.ac_ask, 8),
         " bc_bid=", DoubleToString(diag.bc_bid, 8),
         " bc_ask=", DoubleToString(diag.bc_ask, 8),
         " ac_now=", DoubleToString(diag.ac_now, 8),
         " bc_now=", DoubleToString(diag.bc_now, 8),
         " fv_ac=", DoubleToString(diag.fv_ac, 8),
         " fv_bc=", DoubleToString(diag.fv_bc, 8),
         " sig_ac=", DoubleToString(diag.sig_ac, 8),
         " sig_bc=", DoubleToString(diag.sig_bc, 8),
         " ratio=", DoubleToString(diag.ratio, 8),
         " inst_spread=", DoubleToString(diag.inst_spread, 8),
         " effective_multiplier=", DoubleToString(diag.effective_multiplier, 6),
         " dynamic_hs=", DoubleToString(diag.dynamic_hs, 8),
         " theo=", DoubleToString(theoretical, 8));
}

//+------------------------------------------------------------------+
bool V2_L0ComputeImpl(const V2PairPreset &preset,
                    const V2L0SignalContext &ctx,
                    const bool compute_bid,
                    double &theoretical,
                    V2L0CoreDiagnostics &diag)
{
   const double passivity_buffer_price =
      V2_L0PassivityBufferPriceFromPips(ctx.passivity_buffer_pips);

   if(preset.signal_slot == V2_SIGNAL_BC_NATIVE)
   {
      double closes[];
      if(CopyClose(_Symbol, PERIOD_M5, 1, 60, closes) < 49)
         return false;
      ArraySetAsSeries(closes, true);

      V2L0BcInputs in;
      in.bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      in.ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      in.quote_spread = ctx.quote_spread;
      in.spread_multiplier = ctx.spread_multiplier;
      in.spread_multiplier_eased = ctx.spread_multiplier_eased;
      in.ease_depth_start = ctx.ease_depth_start;
      in.ease_depth_full = ctx.ease_depth_full;
      in.passivity_buffer_price = passivity_buffer_price;
      in.quoting_side_flat = ctx.quoting_side_flat;
      in.opposite_depth = ctx.opposite_depth;
      in.compute_bid = compute_bid;
      in.live_spread_price = V2_L0ResolveLiveSpreadPrice(ctx.quote_spread);
      return V2_L0CoreComputeBc(closes, in, theoretical, diag);
   }

   if(preset.signal_slot == V2_SIGNAL_AB_TRIAD)
   {
      string leg_ac, leg_bc;
      if(!V2_L0ResolveLegSymbols(preset, ctx, leg_ac, leg_bc))
         return false;

      double ac_closes[], bc_closes[];
      if(!V2_CopyM5Closes(leg_ac, ac_closes))
         return false;
      if(!V2_CopyM5Closes(leg_bc, bc_closes))
         return false;

      V2L0AbInputs in;
      in.ac_bid = SymbolInfoDouble(leg_ac, SYMBOL_BID);
      in.ac_ask = SymbolInfoDouble(leg_ac, SYMBOL_ASK);
      in.bc_bid = SymbolInfoDouble(leg_bc, SYMBOL_BID);
      in.bc_ask = SymbolInfoDouble(leg_bc, SYMBOL_ASK);
      in.quote_spread = ctx.quote_spread;
      in.spread_multiplier = ctx.spread_multiplier;
      in.spread_multiplier_eased = ctx.spread_multiplier_eased;
      in.ease_depth_start = ctx.ease_depth_start;
      in.ease_depth_full = ctx.ease_depth_full;
      in.live_spread_price = V2_L0ResolveLiveSpreadPrice(ctx.quote_spread);
      in.passivity_buffer_price = passivity_buffer_price;
      in.quoting_side_flat = ctx.quoting_side_flat;
      in.opposite_depth = ctx.opposite_depth;
      in.compute_bid = compute_bid;
      diag.leg_ac = leg_ac;
      diag.leg_bc = leg_bc;
      diag.ac_close0 = ac_closes[0];
      diag.bc_close0 = bc_closes[0];
      diag.ac_bid = in.ac_bid;
      diag.ac_ask = in.ac_ask;
      diag.bc_bid = in.bc_bid;
      diag.bc_ask = in.bc_ask;
      return V2_L0CoreComputeAb(ac_closes, bc_closes, in, theoretical, diag);
   }

   return false;
}

//+------------------------------------------------------------------+
bool V2_L0ComputeBid(const V2PairPreset &preset,
                     const V2L0SignalContext &ctx,
                     double &bid_theoretical,
                     V2L0CoreDiagnostics &diag)
{
   return V2_L0ComputeImpl(preset, ctx, true, bid_theoretical, diag);
}

//+------------------------------------------------------------------+
bool V2_L0ComputeOffer(const V2PairPreset &preset,
                       const V2L0SignalContext &ctx,
                       double &offer_theoretical,
                       V2L0CoreDiagnostics &diag)
{
   return V2_L0ComputeImpl(preset, ctx, false, offer_theoretical, diag);
}

#endif // FXMATRIX_V2_L0_SIGNAL_MQH
