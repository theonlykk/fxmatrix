//+------------------------------------------------------------------+
//| grind_preset_eurgbp.mqh — EURGBP OPT/ALT preset constants        |
//| Magic allocation: 2226 PP SS — PP=03 EURGBP, SS=01 OPT / 02 ALT |
//| MaxLayers=8 => 2*(8+1)=18 per instance, 36 both slots.          |
//+------------------------------------------------------------------+
#ifndef GRIND_PRESET_EURGBP_MQH
#define GRIND_PRESET_EURGBP_MQH

#include "grind_preset.mqh"

#define GRIND_EURGBP_OPT_MAGIC           22260301UL
#define GRIND_EURGBP_ALT_MAGIC           22260302UL
#define GRIND_EURGBP_MAX_LAYERS          8
#define GRIND_EURGBP_WIDTH_PIPS_PLACE    -1.0
#define GRIND_EURGBP_EXIT_PIPS_PLACE     -1.0
#define GRIND_EURGBP_CAP_LEG_A           "EUR"
#define GRIND_EURGBP_CAP_LEG_B           "GBP"
#define GRIND_EURGBP_TEL_OPT             "GRIND_EURGBP_OPT"
#define GRIND_EURGBP_TEL_ALT             "GRIND_EURGBP_ALT"

#endif // GRIND_PRESET_EURGBP_MQH
