//+------------------------------------------------------------------+
//| fxmatrix_v2_preset_gbpusd.mqh — GBPUSD structural preset         |
//| Magic exit: entry + V2_EXIT_MAGIC_OFFSET (2) per logic.mqh.      |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_PRESET_GBPUSD_MQH
#define FXMATRIX_V2_PRESET_GBPUSD_MQH

#include "fxmatrix_v2_pair_preset.mqh"

const V2PairPreset g_preset =
{
   "GBPUSD",              // chart_symbol
   "MM_LONG_V2",          // tel_instance_long
   "MM_SHORT_V2",         // tel_instance_short
   "fxmatrix_v2",         // ea_name
   20260901,              // magic_long
   20260902,              // magic_short
   20260903,              // magic_long_exit  (20260901 + 2)
   20260904,              // magic_short_exit (20260902 + 2)
   V2_SIGNAL_BC_NATIVE,   // signal_slot
   "",                    // leg_ac_symbol_default
   "",                    // leg_bc_symbol_default
   false,                 // l0_deadband_vol_scale_enabled
   0.0,                   // l0_deadband_spread_ref_pips
   V2_CAP_GBP_ONLY        // cap_profile
};

#endif // FXMATRIX_V2_PRESET_GBPUSD_MQH
