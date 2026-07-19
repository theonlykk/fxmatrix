//+------------------------------------------------------------------+
//| fxmatrix_v2_cross_exposure_cap.mqh — generic cross-instance cap   |
//| Replaces fxmatrix_v2_gbp_cap.mqh for Phase 1 refactored EAs.      |
//| Net = sum(peer.coef * GV layers). Gates widening adds only.       |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_CROSS_EXPOSURE_CAP_MQH
#define FXMATRIX_V2_CROSS_EXPOSURE_CAP_MQH

#define V2_CROSS_CAP_TRIGGERS_GV "V2GBP_CAP_TRIGGERS"

// Generic naming (future cutover): V2X_<InstanceID>_<LONG|SHORT>
#define V2X_GBPUSD_LONG   "V2X_GBPUSD_LONG"
#define V2X_GBPUSD_SHORT  "V2X_GBPUSD_SHORT"
#define V2X_EURGBP_LONG   "V2X_EURGBP_LONG"
#define V2X_EURGBP_SHORT  "V2X_EURGBP_SHORT"

// Legacy keys (parity with fxmatrix_v2_gbp_cap.mqh during validation)
#define V2_LEGACY_GBP_LONG   "V2GBP_L_GBPUSD"
#define V2_LEGACY_GBP_SHORT  "V2GBP_S_GBPUSD"
#define V2_LEGACY_EGP_LONG   "V2GBP_L_EURGBP"
#define V2_LEGACY_EGP_SHORT  "V2GBP_S_EURGBP"

struct V2CrossCapPeer
{
   string instance_id;
   string gv_key;
   double coef;
};

struct V2CrossExposureCapConfig
{
   string group_id;
   int    threshold;
   string local_instance_id;
   string local_gv_long;
   string local_gv_short;
   double local_long_delta;
   double local_short_delta;
   V2CrossCapPeer peers[];
};

long V2_CrossCapReadLayers(const string gv_key)
{
   if(gv_key == "" || !GlobalVariableCheck(gv_key))
      return 0;
   return (long)GlobalVariableGet(gv_key);
}

void V2_CrossCapPublishLayers(const string gv_key, const int layers)
{
   if(gv_key == "")
      return;
   GlobalVariableSet(gv_key, (double)layers);
}

void V2_CrossCapClearPeers(V2CrossExposureCapConfig &cfg)
{
   ArrayResize(cfg.peers, 0);
}

void V2_CrossCapAddPeer(V2CrossExposureCapConfig &cfg,
                        const string instance_id,
                        const string gv_key,
                        const double coef)
{
   int n = ArraySize(cfg.peers);
   ArrayResize(cfg.peers, n + 1);
   cfg.peers[n].instance_id = instance_id;
   cfg.peers[n].gv_key      = gv_key;
   cfg.peers[n].coef        = coef;
}

//+------------------------------------------------------------------+
//| Legacy GBP triad — byte-compatible with fxmatrix_v2_gbp_cap.mqh |
//| net = (L_GBPUSD - S_GBPUSD) - (L_EURGBP - S_EURGBP)              |
//+------------------------------------------------------------------+
void V2_CrossCapInitGbpTriadLegacy(V2CrossExposureCapConfig &cfg,
                                   const string local_pair_label,
                                   const int threshold)
{
   V2_CrossCapClearPeers(cfg);
   cfg.group_id           = "GBP_TRIAD_LEGACY";
   cfg.threshold          = threshold;
   cfg.local_instance_id  = local_pair_label;

   V2_CrossCapAddPeer(cfg, "GBPUSD_LONG",  V2_LEGACY_GBP_LONG,  +1.0);
   V2_CrossCapAddPeer(cfg, "GBPUSD_SHORT", V2_LEGACY_GBP_SHORT, -1.0);
   V2_CrossCapAddPeer(cfg, "EURGBP_LONG",  V2_LEGACY_EGP_LONG,  -1.0);
   V2_CrossCapAddPeer(cfg, "EURGBP_SHORT", V2_LEGACY_EGP_SHORT, +1.0);

   if(local_pair_label == "GBPUSD") {
      cfg.local_gv_long        = V2_LEGACY_GBP_LONG;
      cfg.local_gv_short       = V2_LEGACY_GBP_SHORT;
      cfg.local_long_delta     = +1.0;
      cfg.local_short_delta    = -1.0;
   } else if(local_pair_label == "EURGBP") {
      cfg.local_gv_long        = V2_LEGACY_EGP_LONG;
      cfg.local_gv_short       = V2_LEGACY_EGP_SHORT;
      cfg.local_long_delta     = -1.0;
      cfg.local_short_delta    = +1.0;
   } else {
      cfg.local_gv_long        = "";
      cfg.local_gv_short       = "";
      cfg.local_long_delta     = 0.0;
      cfg.local_short_delta    = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Modern V2X_* GV naming (same coefficients, for post-cutover use). |
//+------------------------------------------------------------------+
void V2_CrossCapInitGbpTriadModern(V2CrossExposureCapConfig &cfg,
                                   const string local_pair_label,
                                   const int threshold)
{
   V2_CrossCapClearPeers(cfg);
   cfg.group_id          = "GBP_TRIAD_V2X";
   cfg.threshold         = threshold;
   cfg.local_instance_id = local_pair_label;

   V2_CrossCapAddPeer(cfg, "GBPUSD_LONG",  V2X_GBPUSD_LONG,  +1.0);
   V2_CrossCapAddPeer(cfg, "GBPUSD_SHORT", V2X_GBPUSD_SHORT, -1.0);
   V2_CrossCapAddPeer(cfg, "EURGBP_LONG",  V2X_EURGBP_LONG,  -1.0);
   V2_CrossCapAddPeer(cfg, "EURGBP_SHORT", V2X_EURGBP_SHORT, +1.0);

   if(local_pair_label == "GBPUSD") {
      cfg.local_gv_long     = V2X_GBPUSD_LONG;
      cfg.local_gv_short    = V2X_GBPUSD_SHORT;
      cfg.local_long_delta  = +1.0;
      cfg.local_short_delta = -1.0;
   } else if(local_pair_label == "EURGBP") {
      cfg.local_gv_long     = V2X_EURGBP_LONG;
      cfg.local_gv_short    = V2X_EURGBP_SHORT;
      cfg.local_long_delta  = -1.0;
      cfg.local_short_delta = +1.0;
   } else {
      cfg.local_gv_long     = "";
      cfg.local_gv_short    = "";
      cfg.local_long_delta  = 0.0;
      cfg.local_short_delta = 0.0;
   }
}

double V2_CrossCapNetExposure(const V2CrossExposureCapConfig &cfg)
{
   double net = 0.0;
   for(int i = 0; i < ArraySize(cfg.peers); i++)
      net += cfg.peers[i].coef * (double)V2_CrossCapReadLayers(cfg.peers[i].gv_key);
   return net;
}

double V2_CrossCapDeltaForAdd(const V2CrossExposureCapConfig &cfg, const bool is_long)
{
   if(cfg.local_gv_long == "" && cfg.local_gv_short == "")
      return 0.0;
   return is_long ? cfg.local_long_delta : cfg.local_short_delta;
}

bool V2_CrossCapBlocksNewAdd(const V2CrossExposureCapConfig &cfg, const bool is_long)
{
   if(cfg.threshold <= 0)
      return false;

   double delta = V2_CrossCapDeltaForAdd(cfg, is_long);
   if(delta == 0.0)
      return false;

   double net = V2_CrossCapNetExposure(cfg);
   double new_net = net + delta;

   if(MathAbs(new_net) <= MathAbs(net) + 1e-9)
      return false;

   return MathAbs(new_net) > (double)cfg.threshold;
}

void V2_CrossCapSyncInstance(const V2CrossExposureCapConfig &cfg,
                             const bool is_long,
                             const int layer_count)
{
   string key = is_long ? cfg.local_gv_long : cfg.local_gv_short;
   if(key != "")
      V2_CrossCapPublishLayers(key, layer_count);
}

void V2_CrossCapRecordBlock()
{
   double n = GlobalVariableCheck(V2_CROSS_CAP_TRIGGERS_GV)
              ? GlobalVariableGet(V2_CROSS_CAP_TRIGGERS_GV)
              : 0.0;
   GlobalVariableSet(V2_CROSS_CAP_TRIGGERS_GV, n + 1.0);
}

#endif // FXMATRIX_V2_CROSS_EXPOSURE_CAP_MQH
