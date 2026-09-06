//+------------------------------------------------------------------+
//| grind_preset_eurusd.mqh — EURUSD OPT/ALT preset constants        |
//| Magic allocation: 2226 PP SS — PP=02 EURUSD, SS=01 OPT / 02 ALT |
//| Order budget: MaxLayers=12 => 26/instance, 52 both slots.       |
//| Account total both slots: GBPUSD 52 + EURUSD 52 + EURGBP 36=140 |
//| FTMO hard limit 200; project soft gate 180.                    |
//+------------------------------------------------------------------+
#ifndef GRIND_PRESET_EURUSD_MQH
#define GRIND_PRESET_EURUSD_MQH

#include "grind_preset.mqh"

#define GRIND_EURUSD_OPT_MAGIC           22260201UL
#define GRIND_EURUSD_ALT_MAGIC           22260202UL
#define GRIND_EURUSD_MAX_LAYERS          12
#define GRIND_EURUSD_WIDTH_PIPS_PLACE    -1.0
#define GRIND_EURUSD_EXIT_PIPS_PLACE     -1.0
#define GRIND_EURUSD_CAP_LEG_A           "EUR"
#define GRIND_EURUSD_CAP_LEG_B           "USD"
#define GRIND_EURUSD_TEL_OPT             "GRIND_EURUSD_OPT"
#define GRIND_EURUSD_TEL_ALT             "GRIND_EURUSD_ALT"

#endif // GRIND_PRESET_EURUSD_MQH
