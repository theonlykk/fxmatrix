//+------------------------------------------------------------------+
//| fxmatrix_v2_eur_cap.mqh — cross-chart EUR net-exposure add gate  |
//| Net EUR = (L_EURUSD - S_EURUSD) + (L_EURGBP - S_EURGBP)          |
//| Gates new grid adds only (not reload, not L0, not exits).         |
//| Cross-instance: MT5 terminal Global Variables (read peer, write   |
//| own key only). Missing peer GV => layer count 0 (permissive).     |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_EUR_CAP_MQH
#define FXMATRIX_V2_EUR_CAP_MQH

#define V2_EUR_CAP_GV_EUR_LONG   "V2EUR_L_EURUSD"
#define V2_EUR_CAP_GV_EUR_SHORT  "V2EUR_S_EURUSD"
#define V2_EUR_CAP_GV_EGP_LONG   "V2EUR_L_EURGBP"
#define V2_EUR_CAP_GV_EGP_SHORT  "V2EUR_S_EURGBP"

//+------------------------------------------------------------------+
//| Read peer layer count. If GV absent (peer EA not attached / not   |
//| yet synced), return 0 — permissive default, never blocks alone.  |
//+------------------------------------------------------------------+
long V2_EurCapReadLayers(const string gv_key)
{
   if(!GlobalVariableCheck(gv_key))
      return 0;
   return (long)GlobalVariableGet(gv_key);
}

//+------------------------------------------------------------------+
void V2_EurCapPublishLayers(const string gv_key, const int layers)
{
   GlobalVariableSet(gv_key, (double)layers);
}

//+------------------------------------------------------------------+
string V2_EurCapNamespaceSuffix(const string cap_namespace)
{
   if(StringFind(cap_namespace, "_DUMB") >= 0)
      return "_DUMB";
   return "";
}

//+------------------------------------------------------------------+
string V2_EurCapChartSymbol(const string cap_namespace)
{
   const int pos = StringFind(cap_namespace, "_DUMB");
   if(pos >= 0)
      return StringSubstr(cap_namespace, 0, pos);
   return cap_namespace;
}

//+------------------------------------------------------------------+
string V2_EurCapGvKey(const string cap_namespace, const bool is_long)
{
   const string pair_label = V2_EurCapChartSymbol(cap_namespace);
   const string suffix = V2_EurCapNamespaceSuffix(cap_namespace);
   if(pair_label == "EURUSD")
      return is_long ? (V2_EUR_CAP_GV_EUR_LONG + suffix) : (V2_EUR_CAP_GV_EUR_SHORT + suffix);
   if(pair_label == "EURGBP")
      return is_long ? (V2_EUR_CAP_GV_EGP_LONG + suffix) : (V2_EUR_CAP_GV_EGP_SHORT + suffix);
   return "";
}

//+------------------------------------------------------------------+
double V2_EurNetExposure(const string cap_namespace = "")
{
   const string suffix = V2_EurCapNamespaceSuffix(cap_namespace);
   long eur_l = V2_EurCapReadLayers(V2_EUR_CAP_GV_EUR_LONG + suffix);
   long eur_s = V2_EurCapReadLayers(V2_EUR_CAP_GV_EUR_SHORT + suffix);
   long egp_l = V2_EurCapReadLayers(V2_EUR_CAP_GV_EGP_LONG + suffix);
   long egp_s = V2_EurCapReadLayers(V2_EUR_CAP_GV_EGP_SHORT + suffix);
   return (double)((eur_l - eur_s) + (egp_l - egp_s));
}

//+------------------------------------------------------------------+
double V2_EurCapDeltaForAdd(const string cap_namespace, const bool is_long)
{
   const string pair_label = V2_EurCapChartSymbol(cap_namespace);
   if(pair_label == "EURUSD")
      return is_long ? 1.0 : -1.0;
   if(pair_label == "EURGBP")
      return is_long ? 1.0 : -1.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Block only a widening add that would push |net| strictly above    |
//| threshold. Landing exactly on threshold (e.g. 11 -> 12) allowed. |
//| Non-EUR pairs: delta=0 => never blocked.                         |
//+------------------------------------------------------------------+
bool V2_EurCapBlocksNewAdd(const string cap_namespace,
                           const bool is_long,
                           const int threshold)
{
   if(threshold <= 0)
      return false;

   double delta = V2_EurCapDeltaForAdd(cap_namespace, is_long);
   if(delta == 0.0)
      return false;

   double net = V2_EurNetExposure(cap_namespace);
   double new_net = net + delta;

   if(MathAbs(new_net) <= MathAbs(net) + 1e-9)
      return false;

   return MathAbs(new_net) > (double)threshold;
}

//+------------------------------------------------------------------+
void V2_EurCapSyncInstance(const string cap_namespace, const bool is_long, const int layer_count)
{
   string key = V2_EurCapGvKey(cap_namespace, is_long);
   if(key != "")
      V2_EurCapPublishLayers(key, layer_count);
}

//+------------------------------------------------------------------+
void V2_EurCapRecordBlock()
{
   string gv = "V2EUR_CAP_TRIGGERS";
   double n = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   GlobalVariableSet(gv, n + 1.0);
}

#endif // FXMATRIX_V2_EUR_CAP_MQH
