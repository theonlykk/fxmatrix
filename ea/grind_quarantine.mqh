//+------------------------------------------------------------------+
//| grind_quarantine.mqh — invariant quarantine before halt (ADR-128) |
//+------------------------------------------------------------------+
#ifndef GRIND_QUARANTINE_MQH
#define GRIND_QUARANTINE_MQH

#include "grind_archive.mqh"

#define GRIND_INV_OK          0
#define GRIND_INV_QUARANTINE  1
#define GRIND_INV_HALT        2
#define GRIND_QUARANTINE_MIN_MS      3000
#define GRIND_QUARANTINE_MIN_CHECKS  3

bool   g_grind_quarantined = false;
string g_grind_quarantine_reason = "";
ulong  g_grind_quarantine_start_ms = 0;
int    g_grind_quarantine_checks = 0;
int    g_grind_quarantine_episodes = 0;

//+------------------------------------------------------------------+
void Grind_QuarantineReset()
{
   g_grind_quarantined = false;
   g_grind_quarantine_reason = "";
   g_grind_quarantine_start_ms = 0;
   g_grind_quarantine_checks = 0;
   g_grind_quarantine_episodes = 0;
}

//+------------------------------------------------------------------+
bool Grind_IsQuarantinableReason(const string reason)
{
   if(reason == "I2_LONG_EXIT_DUP" || reason == "I2_SHORT_EXIT_DUP")
      return true;
   if(reason == "I3_LONG_NAKED" || reason == "I3_SHORT_NAKED")
      return true;
   if(reason == "I4_LONG_ORPHAN_EXIT" || reason == "I4_SHORT_ORPHAN_EXIT")
      return true;
   return false;
}

//+------------------------------------------------------------------+
int Grind_QuarantineStep(const bool invariant_ok,
                         const string reason,
                         const ulong now_ms)
{
   if(invariant_ok) {
      if(g_grind_quarantined) {
         ulong elapsed = 0;
         if(now_ms >= g_grind_quarantine_start_ms)
            elapsed = now_ms - g_grind_quarantine_start_ms;
         Grind_ArchiveMarker("INFO", "QUARANTINE_RELEASE", g_grind_quarantine_reason, 0,
                             StringFormat("{\"ms\":%I64u,\"checks\":%d}",
                                          elapsed, g_grind_quarantine_checks));
         Print("INFO GRIND_QUARANTINE release reason=", g_grind_quarantine_reason,
               " ms=", elapsed, " checks=", g_grind_quarantine_checks);
         g_grind_quarantined = false;
         g_grind_quarantine_reason = "";
         g_grind_quarantine_start_ms = 0;
         g_grind_quarantine_checks = 0;
      }
      return GRIND_INV_OK;
   }

   if(!Grind_IsQuarantinableReason(reason))
      return GRIND_INV_HALT;

   if(!g_grind_quarantined) {
      g_grind_quarantined = true;
      g_grind_quarantine_reason = reason;
      g_grind_quarantine_start_ms = now_ms;
      g_grind_quarantine_checks = 1;
      g_grind_quarantine_episodes++;
      Grind_ArchiveMarker("WARN", "QUARANTINE_ENTER", reason, 0, "");
      Print("WARN GRIND_QUARANTINE enter reason=", reason);
      return GRIND_INV_QUARANTINE;
   }

   g_grind_quarantine_checks++;
   g_grind_quarantine_reason = reason;

   ulong elapsed = 0;
   if(now_ms >= g_grind_quarantine_start_ms)
      elapsed = now_ms - g_grind_quarantine_start_ms;

   if(elapsed >= GRIND_QUARANTINE_MIN_MS &&
      g_grind_quarantine_checks >= GRIND_QUARANTINE_MIN_CHECKS) {
      Grind_ArchiveMarker("CRITICAL", "QUARANTINE_HALT", reason, 0,
                          StringFormat("{\"ms\":%I64u,\"checks\":%d}",
                                       elapsed, g_grind_quarantine_checks));
      Print("CRITICAL GRIND_QUARANTINE halt reason=", reason,
            " ms=", elapsed, " checks=", g_grind_quarantine_checks);
      return GRIND_INV_HALT;
   }

   return GRIND_INV_QUARANTINE;
}

#endif // GRIND_QUARANTINE_MQH
