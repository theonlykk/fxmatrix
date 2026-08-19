//+------------------------------------------------------------------+
//| fxmatrix_v2_pair_preset.mqh — structural pair identity (Phase A) |
//| Behavioral parameters live in shell input declarations only.     |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_PAIR_PRESET_MQH
#define FXMATRIX_V2_PAIR_PRESET_MQH

enum V2SignalSlot
{
   V2_SIGNAL_BC_NATIVE,
   V2_SIGNAL_AB_TRIAD
};

enum V2CapProfile
{
   V2_CAP_GBP_ONLY,
   V2_CAP_EUR_ONLY,
   V2_CAP_DUAL_GBP_EUR
};

enum V2EntryMode
{
   ENTRY_SIGNAL   = 0,
   ENTRY_STRADDLE = 1,
   ENTRY_RANDOM   = 2   // reserved — not implemented this pass
};

struct V2PairPreset
{
   // Identity (non-overridable)
   string         chart_symbol;
   string         cap_namespace;
   string         tel_instance_long;
   string         tel_instance_short;
   string         ea_name;
   long           magic_long;
   long           magic_short;
   long           magic_long_exit;
   long           magic_short_exit;

   // Signal routing (non-overridable)
   V2SignalSlot   signal_slot;
   string         leg_ac_symbol_default;
   string         leg_bc_symbol_default;

   // L0 deadband vol-scale (structural enable + ref when enabled)
   bool           l0_deadband_vol_scale_enabled;
   double         l0_deadband_spread_ref_pips;

   // Cap profile tag (telemetry/validation; dispatch via shell bridge)
   V2CapProfile   cap_profile;
};

#endif // FXMATRIX_V2_PAIR_PRESET_MQH
