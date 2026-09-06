//+------------------------------------------------------------------+
//| grind_cap.mqh — CAS cross-instance currency exposure cap (Spec B)|
//+------------------------------------------------------------------+
#ifndef GRIND_CAP_MQH
#define GRIND_CAP_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"
#include "grind_telemetry.mqh"

#define GRIND_CAP_LOCK_GV           "GRIND2226_CAS_LOCK"
#define GRIND_CAP_STALE_SECONDS     300
#define GRIND_CAP_MAXED_VALUE       1.0e12
#define GRIND_CAP_CAS_MAX_RETRIES   50

// All six fxgrind instance magics (2226xxxx namespace).
const ulong GRIND_CAP_ALL_MAGICS[6] =
{
   22260101UL, 22260102UL,
   22260201UL, 22260202UL,
   22260301UL, 22260302UL
};

double g_grind_cap_thresh_a = 0.0;
double g_grind_cap_thresh_b = 0.0;
double g_grind_cap_own_leg_a = 0.0;
double g_grind_cap_own_leg_b = 0.0;
double g_grind_cap_total_leg_a = 0.0;
double g_grind_cap_total_leg_b = 0.0;
bool   g_grind_cap_peer_read_failed = false;
bool   g_grind_cap_test_lock_held = false;

//+------------------------------------------------------------------+
string Grind_CapExposureKey(const ulong magic, const string leg)
{
   return "GRIND2226_" + IntegerToString((long)magic) + "_" + leg;
}

//+------------------------------------------------------------------+
string Grind_CapTimestampKey(const string exposure_key)
{
   return exposure_key + "_time";
}

//+------------------------------------------------------------------+
bool Grind_CapTryAcquireLock(const int max_retries)
{
   int retries = 0;
   while(!GlobalVariableSetOnCondition(GRIND_CAP_LOCK_GV, 1.0, 0.0)) {
      if(g_grind_cap_test_lock_held) {
         Sleep(1);
         if(++retries > max_retries) {
            Print("ERROR: CAS timeout ", GRIND_CAP_LOCK_GV);
            return false;
         }
         continue;
      }
      Sleep(1);
      if(++retries > max_retries) {
         Print("ERROR: CAS timeout ", GRIND_CAP_LOCK_GV);
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
void Grind_CapReleaseLock()
{
   GlobalVariableSet(GRIND_CAP_LOCK_GV, 0.0);
}

//+------------------------------------------------------------------+
bool Grind_CapAcquireLock()
{
   return Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES);
}

//+------------------------------------------------------------------+
bool Grind_CapReadStoredPeer(const string exposure_key,
                             double &value_out,
                             bool &failed_out)
{
   failed_out = false;
   const string time_key = Grind_CapTimestampKey(exposure_key);
   const bool has_value = GlobalVariableCheck(exposure_key);
   const bool has_time = GlobalVariableCheck(time_key);

   if(!has_value || !has_time) {
      value_out = GRIND_CAP_MAXED_VALUE;
      failed_out = true;
      return true;
   }

   value_out = GlobalVariableGet(exposure_key);
   const datetime ts = (datetime)GlobalVariableGet(time_key);
   if(TimeCurrent() - ts > GRIND_CAP_STALE_SECONDS) {
      value_out = GRIND_CAP_MAXED_VALUE;
      failed_out = true;
   }
   return true;
}

//+------------------------------------------------------------------+
bool Grind_CapWriteExposureLocked(const string exposure_key, const double exposure)
{
   const string time_key = Grind_CapTimestampKey(exposure_key);
   ResetLastError();
   if(!GlobalVariableSet(exposure_key, exposure)) {
      Grind_CapReleaseLock();
      return false;
   }
   if(!GlobalVariableSet(time_key, (double)TimeCurrent())) {
      Grind_CapReleaseLock();
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
double Grind_CapComputeOwnLegExposure(const string leg,
                                      const ulong magic,
                                      const string leg_a,
                                      const string leg_b)
{
   if(leg != leg_a && leg != leg_b)
      return 0.0;

   double exposure = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic))
         continue;

      const string comment = PositionGetString(POSITION_COMMENT);
      string c_slot, c_side, c_role;
      int c_layer;
      if(!GrindCommentParse(comment, c_slot, c_side, c_layer, c_role))
         continue;
      if(c_role != "ENT")
         continue;

      const double lots = PositionGetDouble(POSITION_VOLUME);
      const bool is_long = (c_side == "L");
      if(leg == leg_a)
         exposure += is_long ? lots : -lots;
      else
         exposure += is_long ? -lots : lots;
   }
   return exposure;
}

//+------------------------------------------------------------------+
bool Grind_CapPublishOwnExposure(const ulong magic,
                                 const string leg_a,
                                 const string leg_b)
{
   g_grind_cap_own_leg_a = Grind_CapComputeOwnLegExposure(leg_a, magic, leg_a, leg_b);
   g_grind_cap_own_leg_b = Grind_CapComputeOwnLegExposure(leg_b, magic, leg_a, leg_b);

   if(!Grind_CapAcquireLock())
      return false;

   bool ok = true;
   if(leg_a != "") {
      const string key_a = Grind_CapExposureKey(magic, leg_a);
      ok = ok && Grind_CapWriteExposureLocked(key_a, g_grind_cap_own_leg_a);
      if(!ok)
         return false;
   }
   if(leg_b != "") {
      const string key_b = Grind_CapExposureKey(magic, leg_b);
      ok = ok && Grind_CapWriteExposureLocked(key_b, g_grind_cap_own_leg_b);
      if(!ok)
         return false;
   }

   Grind_CapReleaseLock();
   return ok;
}

//+------------------------------------------------------------------+
bool Grind_CapSumLegExposure(const string leg,
                             const ulong own_magic,
                             double &total_out,
                             bool &peer_failed_out)
{
   total_out = 0.0;
   peer_failed_out = false;

   if(!Grind_CapAcquireLock())
      return false;

   for(int i = 0; i < 6; i++) {
      const ulong magic = GRIND_CAP_ALL_MAGICS[i];
      const string key = Grind_CapExposureKey(magic, leg);
      double peer_value = 0.0;
      bool peer_failed = false;
      Grind_CapReadStoredPeer(key, peer_value, peer_failed);
      if(magic != own_magic && peer_failed)
         peer_failed_out = true;
      if(peer_value >= GRIND_CAP_MAXED_VALUE * 0.5)
         peer_failed_out = true;
      total_out += peer_value;
   }

   Grind_CapReleaseLock();
   return true;
}

//+------------------------------------------------------------------+
bool Grind_CapThresholdEnabled()
{
   return (g_grind_cap_thresh_a > 0.0 || g_grind_cap_thresh_b > 0.0);
}

//+------------------------------------------------------------------+
bool Grind_CapPermitsNonEntryActions()
{
   return true;
}

//+------------------------------------------------------------------+
bool Grind_CapAllowsEntry(const bool is_long, const double lots)
{
   if(!Grind_CapThresholdEnabled())
      return true;

   const double delta_a = is_long ? lots : -lots;
   const double delta_b = is_long ? -lots : lots;

   bool peer_failed = false;
   if(!Grind_CapSumLegExposure(g_grind_cap_leg_a, g_grind_recon_magic,
                               g_grind_cap_total_leg_a, peer_failed)) {
      g_grind_cap_peer_read_failed = true;
      g_grind_cap_blocked = true;
      return false;
   }
   if(!Grind_CapSumLegExposure(g_grind_cap_leg_b, g_grind_recon_magic,
                               g_grind_cap_total_leg_b, peer_failed)) {
      g_grind_cap_peer_read_failed = true;
      g_grind_cap_blocked = true;
      return false;
   }

   g_grind_cap_peer_read_failed = peer_failed;

   if(peer_failed) {
      g_grind_cap_blocked = true;
      return false;
   }

   const double new_a = g_grind_cap_total_leg_a + delta_a;
   const double new_b = g_grind_cap_total_leg_b + delta_b;

   if(g_grind_cap_thresh_a > 0.0 && MathAbs(new_a) > g_grind_cap_thresh_a) {
      g_grind_cap_blocked = true;
      return false;
   }
   if(g_grind_cap_thresh_b > 0.0 && MathAbs(new_b) > g_grind_cap_thresh_b) {
      g_grind_cap_blocked = true;
      return false;
   }

   g_grind_cap_blocked = false;
   return true;
}

//+------------------------------------------------------------------+
bool Grind_CapAllows(const string leg_a,
                     const string leg_b,
                     const double lots,
                     const int direction)
{
   return Grind_CapAllowsEntry(direction > 0, lots);
}

#endif // GRIND_CAP_MQH
