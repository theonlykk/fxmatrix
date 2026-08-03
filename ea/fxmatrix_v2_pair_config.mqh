//+------------------------------------------------------------------+
//| fxmatrix_v2_pair_config.mqh — per-instance pair preset (Phase 1)  |
//| Define exactly one V2_PRESET_* before including this header.      |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_PAIR_CONFIG_MQH
#define FXMATRIX_V2_PAIR_CONFIG_MQH

#ifdef V2_PRESET_GBPUSD

#ifndef MM_LONG_V2
#define MM_LONG_V2              20260901
#endif
#ifndef MM_SHORT_V2
#define MM_SHORT_V2             20260902
#endif
#define V2_TEL_INSTANCE_LONG    "MM_LONG_V2"
#define V2_TEL_INSTANCE_SHORT   "MM_SHORT_V2"
#define V2_EA_NAME              "fxmatrix_v2"
#define V2_PAIR_LABEL           "GBPUSD"
#define V2_PAIR_SPREAD_PIPS_REF 0.64
#define V2_USE_CROSS_EXPOSURE_CAP 1
#define V2_CAP_PRESET           "GBP_TRIAD_LEGACY"

#endif // V2_PRESET_GBPUSD

#ifdef V2_PRESET_EURUSD

#ifndef MM_LONG_V2
#define MM_LONG_V2              20260911
#endif
#ifndef MM_SHORT_V2
#define MM_SHORT_V2             20260912
#endif
#define V2_TEL_INSTANCE_LONG    "MM_LONG_EURUSD"
#define V2_TEL_INSTANCE_SHORT   "MM_SHORT_EURUSD"
#define V2_EA_NAME              "fxmatrix_v2_eurusd"
#define V2_PAIR_LABEL           "EURUSD"
#define V2_PAIR_SPREAD_PIPS_REF 0.18

#endif // V2_PRESET_EURUSD

#ifdef V2_PRESET_EURGBP

#ifndef MM_LONG_V2
#define MM_LONG_V2              20260921
#endif
#ifndef MM_SHORT_V2
#define MM_SHORT_V2             20260922
#endif
#define V2_TEL_INSTANCE_LONG    "MM_LONG_EURGBP"
#define V2_TEL_INSTANCE_SHORT   "MM_SHORT_EURGBP"
#define V2_EA_NAME              "fxmatrix_v2_eurgbp"
#define V2_PAIR_LABEL           "EURGBP"
#define V2_PAIR_SPREAD_PIPS_REF 0.63
#define V2_SIGNAL_AB_SLOT       1
#define V2_LEG_AC_SYMBOL        "EURUSD"
#define V2_LEG_BC_SYMBOL        "GBPUSD"
#define V2_USE_CROSS_EXPOSURE_CAP 1
#define V2_CAP_PRESET           "GBP_TRIAD_LEGACY"

#endif // V2_PRESET_EURGBP

#endif // FXMATRIX_V2_PAIR_CONFIG_MQH
