//+------------------------------------------------------------------+
//| fxmatrix_v2_eurusd_config.mqh — EURUSD instance isolation config  |
//| Include BEFORE fxmatrix_v2_logic.mqh in fxmatrix_v2_eurusd.mq5    |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_EURUSD_CONFIG_MQH
#define FXMATRIX_V2_EURUSD_CONFIG_MQH

#define MM_LONG_V2   20260911
#define MM_SHORT_V2  20260912

#define V2_TEL_INSTANCE_LONG   "MM_LONG_EURUSD"
#define V2_TEL_INSTANCE_SHORT  "MM_SHORT_EURUSD"

#define V2_EA_NAME               "fxmatrix_v2_eurusd"
#define V2_PAIR_LABEL            "EURUSD"

// Sim-calibrated spread reference (Python PAIR_SPREAD_PIPS); live signal uses InpQuoteSpread.
#define V2_PAIR_SPREAD_PIPS_REF  0.18

#endif // FXMATRIX_V2_EURUSD_CONFIG_MQH
