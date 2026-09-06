//+------------------------------------------------------------------+
//| grind_stubs.mqh — Spec B entry points (fail-closed until Spec B) |
//+------------------------------------------------------------------+
#ifndef GRIND_STUBS_MQH
#define GRIND_STUBS_MQH

// Spec B: rebuild layer table from broker comments on restart.
bool Grind_ReconstructState()
{
   return false;
}

// Spec B: CAS currency exposure cap check before new entry.
bool Grind_CapAllows(const string leg_a,
                     const string leg_b,
                     const double lots,
                     const int direction)
{
   return false;
}

#endif // GRIND_STUBS_MQH
