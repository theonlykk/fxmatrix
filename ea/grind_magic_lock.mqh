//+------------------------------------------------------------------+
//| grind_magic_lock.mqh — duplicate-magic boot guard (GlobalVariableTemp) |
//+------------------------------------------------------------------+
#ifndef GRIND_MAGIC_LOCK_MQH
#define GRIND_MAGIC_LOCK_MQH

#define GRIND_MAGIC_LOCK_PREFIX "GRIND2226_MAGIC_LOCK_"

//+------------------------------------------------------------------+
string Grind_MagicLockKey(const ulong magic)
{
   return GRIND_MAGIC_LOCK_PREFIX + IntegerToString((long)magic);
}

//+------------------------------------------------------------------+
void Grind_MagicLockRelease(const ulong magic)
{
   const string key = Grind_MagicLockKey(magic);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

//+------------------------------------------------------------------+
void Grind_MagicLockReleaseAllKnown()
{
   const ulong magics[6] =
   {
      22260101UL, 22260102UL,
      22260201UL, 22260202UL,
      22260301UL, 22260302UL
   };
   for(int i = 0; i < 6; i++)
      Grind_MagicLockRelease(magics[i]);
   Grind_MagicLockRelease(22269901UL);
}

//+------------------------------------------------------------------+
bool Grind_MagicLockIsClaimed(const ulong magic)
{
   return GlobalVariableCheck(Grind_MagicLockKey(magic));
}

//+------------------------------------------------------------------+
bool Grind_MagicLockClaim(const ulong magic)
{
   const string key = Grind_MagicLockKey(magic);
   if(GlobalVariableCheck(key))
      return false;
   if(!GlobalVariableTemp(key))
      return false;
   GlobalVariableSet(key, (double)TimeCurrent());
   return true;
}

#endif // GRIND_MAGIC_LOCK_MQH
