//+------------------------------------------------------------------+
//| grind_preset_gbpusd.mqh — GBPUSD OPT/ALT preset constants        |
//| Magic allocation: 2226 PP SS — PP=01 GBPUSD, SS=01 OPT / 02 ALT |
//| Order budget: per side at depth n => n exits + 1 entry => 2n+2   |
//| per instance. MaxLayers=12 => 26/instance, 52 both slots.        |
//| Account total both slots: GBPUSD 52 + EURUSD 52 + EURGBP 36=140  |
//| FTMO hard limit 200; project soft gate 180.                    |
//+------------------------------------------------------------------+
#ifndef GRIND_PRESET_GBPUSD_MQH
#define GRIND_PRESET_GBPUSD_MQH

#include "grind_preset.mqh"

#define GRIND_GBPUSD_OPT_MAGIC           22260101UL
#define GRIND_GBPUSD_ALT_MAGIC           22260102UL
#define GRIND_GBPUSD_MAX_LAYERS          12
#define GRIND_GBPUSD_WIDTH_PIPS_PLACE   -1.0   // inject before deploy
#define GRIND_GBPUSD_EXIT_PIPS_PLACE    -1.0   // inject before deploy
#define GRIND_GBPUSD_CAP_LEG_A           "GBP"
#define GRIND_GBPUSD_CAP_LEG_B           "USD"
#define GRIND_GBPUSD_TEL_OPT             "GRIND_GBPUSD_OPT"
#define GRIND_GBPUSD_TEL_ALT             "GRIND_GBPUSD_ALT"

#endif // GRIND_PRESET_GBPUSD_MQH
