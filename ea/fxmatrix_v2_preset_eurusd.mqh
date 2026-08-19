//+------------------------------------------------------------------+
//| fxmatrix_v2_preset_eurusd.mqh — EURUSD structural preset         |
//| Magic exit: entry + V2_EXIT_MAGIC_OFFSET (2) per logic.mqh.      |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_PRESET_EURUSD_MQH
#define FXMATRIX_V2_PRESET_EURUSD_MQH

#include "fxmatrix_v2_pair_preset.mqh"

V2PairPreset g_preset =
{
   "EURUSD",              // chart_symbol
   "EURUSD",              // cap_namespace
   "MM_LONG_EURUSD",      // tel_instance_long
   "MM_SHORT_EURUSD",     // tel_instance_short
   "fxmatrix_v2_eurusd",  // ea_name
   20260911,              // magic_long
   20260912,              // magic_short
   20260913,              // magic_long_exit  (20260911 + 2)
   20260914,              // magic_short_exit (20260912 + 2)
   V2_SIGNAL_BC_NATIVE,   // signal_slot
   "",                    // leg_ac_symbol_default
   "",                    // leg_bc_symbol_default
   true,                  // l0_deadband_vol_scale_enabled
   0.18,                  // l0_deadband_spread_ref_pips (V2_PAIR_SPREAD_PIPS_REF)
   V2_CAP_EUR_ONLY        // cap_profile
};

#endif // FXMATRIX_V2_PRESET_EURUSD_MQH
