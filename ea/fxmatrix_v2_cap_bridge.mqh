//+------------------------------------------------------------------+
//| fxmatrix_v2_cap_bridge.mqh — cap bridge declarations (Phase A)     |
//| Implementations live in each thin shell before engine include.    |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_CAP_BRIDGE_MQH
#define FXMATRIX_V2_CAP_BRIDGE_MQH

bool V2_Cap_CheckBlocks(const bool is_long);
void V2_Cap_Sync(const bool is_long, const int layer_count);
void V2_Cap_RecordBlock(const bool is_long);

#endif // FXMATRIX_V2_CAP_BRIDGE_MQH
