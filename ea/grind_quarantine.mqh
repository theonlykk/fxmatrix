//+------------------------------------------------------------------+
//| grind_quarantine.mqh — invariant quarantine before halt (ADR-128) |
//+------------------------------------------------------------------+
#ifndef GRIND_QUARANTINE_MQH
#define GRIND_QUARANTINE_MQH

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
   return false;
}

//+------------------------------------------------------------------+
int Grind_QuarantineStep(const bool invariant_ok,
                         const string reason,
                         const ulong now_ms)
{
   return GRIND_INV_OK;
}

#endif // GRIND_QUARANTINE_MQH
