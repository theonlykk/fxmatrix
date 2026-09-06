//+------------------------------------------------------------------+
//| grind_preset.mqh — shared preset struct for fxgrind deploy       |
//+------------------------------------------------------------------+
#ifndef GRIND_PRESET_MQH
#define GRIND_PRESET_MQH

struct GrindPairPreset
{
   string chart_symbol;
   string slot;
   ulong  magic;
   double width_pips;          // PLACEHOLDER until sweep injects
   double add_pips;            // MUST be GRIND_ADD_WIDTH_MULTIPLE x width_pips
   double exit_pips;           // PLACEHOLDER until sweep injects
   int    max_layers;
   double stranded_thresh_pips;
   string cap_leg_a;
   string cap_leg_b;
   string telemetry_instance;
};

#endif // GRIND_PRESET_MQH
