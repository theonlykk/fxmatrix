//+------------------------------------------------------------------+
//| fxmatrix_v2_signal_experimental.mqh — TEMP ONLY                   |
//| Return-based native sigma (3-point log-return dispersion 6/12/48).|
//| NOT for production — used by fxmatrix_v2_eurgbp_experimental.mq5  |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_SIGNAL_EXPERIMENTAL_MQH
#define FXMATRIX_V2_SIGNAL_EXPERIMENTAL_MQH

//+------------------------------------------------------------------+
//| Native return sigma: stdev of log returns c0/c6, c0/c12, c0/c48 |
//+------------------------------------------------------------------+
bool V2_ReturnSigmaFromCloses(const double &closes[],
                              double &sigma_out)
{
   if(ArraySize(closes) < 49)
      return false;

   double c0  = closes[0];
   double c6  = closes[6];
   double c12 = closes[12];
   double c48 = closes[48];
   if(c0 <= 0.0 || c6 <= 0.0 || c12 <= 0.0 || c48 <= 0.0)
      return false;

   double r6  = MathLog(c0 / c6);
   double r12 = MathLog(c0 / c12);
   double r48 = MathLog(c0 / c48);
   double mean = (r6 + r12 + r48) / 3.0;
   sigma_out = MathSqrt(((r6 - mean) * (r6 - mean) +
                         (r12 - mean) * (r12 - mean) +
                         (r48 - mean) * (r48 - mean)) / 3.0);
   return (sigma_out >= 0.0);
}

#endif // FXMATRIX_V2_SIGNAL_EXPERIMENTAL_MQH
