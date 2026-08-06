//+------------------------------------------------------------------+
//| fxmatrix_v2_eurgbp_config.mqh — EURGBP instance isolation config  |
//| Include BEFORE fxmatrix_v2_logic.mqh in fxmatrix_v2_eurgbp.mq5    |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_EURGBP_CONFIG_MQH
#define FXMATRIX_V2_EURGBP_CONFIG_MQH

#define MM_LONG_V2   20260921
#define MM_SHORT_V2  20260922

#define V2_TEL_INSTANCE_LONG   "MM_LONG_EURGBP"
#define V2_TEL_INSTANCE_SHORT  "MM_SHORT_EURGBP"

#define V2_EA_NAME               "fxmatrix_v2_eurgbp"
#define V2_PAIR_LABEL            "EURGBP"

// Sim-calibrated spread reference (CSV mean full_quarter); live signal uses InpQuoteSpread.
#define V2_PAIR_SPREAD_PIPS_REF  0.63

// AB-slot leg symbols for multi-pair signal (score_EUR - score_GBP).
#define V2_LEG_AC_SYMBOL         "EURUSD"
#define V2_LEG_BC_SYMBOL         "GBPUSD"

#endif // FXMATRIX_V2_EURGBP_CONFIG_MQH
