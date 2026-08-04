//+------------------------------------------------------------------+
//| fxmatrix_v2_preset_eurgbp.mqh — EURGBP structural preset         |
//| Magic exit: entry + V2_EXIT_MAGIC_OFFSET (2) per logic.mqh.      |
//| V2_PAIR_SPREAD_PIPS_REF 0.63 exists in production but is unused  |
//| for deadband — l0_deadband_vol_scale_enabled remains false.      |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_PRESET_EURGBP_MQH
#define FXMATRIX_V2_PRESET_EURGBP_MQH

#include "fxmatrix_v2_pair_preset.mqh"

const V2PairPreset g_preset =
{
   "EURGBP",              // chart_symbol
   "MM_LONG_EURGBP",      // tel_instance_long
   "MM_SHORT_EURGBP",     // tel_instance_short
   "fxmatrix_v2_eurgbp",  // ea_name
   20260921,              // magic_long
   20260922,              // magic_short
   20260923,              // magic_long_exit  (20260921 + 2)
   20260924,              // magic_short_exit (20260922 + 2)
   V2_SIGNAL_AB_TRIAD,    // signal_slot
   "EURUSD",              // leg_ac_symbol_default (InpLegAC default)
   "GBPUSD",              // leg_bc_symbol_default (InpLegBC default)
   false,                 // l0_deadband_vol_scale_enabled
   0.0,                   // l0_deadband_spread_ref_pips (unused — not 0.63)
   V2_CAP_DUAL_GBP_EUR    // cap_profile
};

#endif // FXMATRIX_V2_PRESET_EURGBP_MQH
