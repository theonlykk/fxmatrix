//+------------------------------------------------------------------+
//| fxgrind_replay_tests.mq5 — replay harness RT1–RT14                 |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "fxgrind_replay_core.mqh"

int g_tests_run = 0;
int g_tests_passed = 0;

void AssertTrue(const string name, const bool condition)
{
   g_tests_run++;
   if(condition) {
      g_tests_passed++;
      Print("PASS | ", name);
   } else {
      Print("FAIL | ", name);
   }
}

void AssertFalse(const string name, const bool condition)
{
   AssertTrue(name, !condition);
}

void AssertNear(const string name, const double got, const double expected, const double tol)
{
   AssertTrue(name, MathAbs(got - expected) <= tol);
}

void AssertEqStr(const string name, const string got, const string expected)
{
   AssertTrue(name, got == expected);
}

void AssertContains(const string name, const string haystack, const string needle)
{
   AssertTrue(name, StringFind(haystack, needle) >= 0);
}

const datetime RPL_T0 = D'2026.10.06 10:00:00';
const double   RPL_SPREAD = 0.00002;

long RplMs(const datetime t, const int sec_offset = 0)
{
   return ((long)t + sec_offset) * 1000;
}

void Rpl_DefaultConfig(RplSegmentConfig &cfg)
{
   cfg.seg_id = 1;
   cfg.instance = "GRIND_TEST";
   cfg.magic = RPL_MAGIC_DEFAULT;
   cfg.from_ms = RplMs(RPL_T0, 0);
   cfg.to_ms = RplMs(RPL_T0, 100);
   cfg.width_l = 2.0;
   cfg.width_s = 15.0;
   cfg.add_l = 7.0;
   cfg.add_s = 7.0;
   cfg.exit_l = 10.0;
   cfg.exit_s = 10.0;
   cfg.cap = 8;
   cfg.stranded = 50.0;
   cfg.deadband = 2.0;
   cfg.lattice = true;
   cfg.reroll = false;
   cfg.gate = -1;
   cfg.carry = false;
   cfg.fill_time_place = true;
   cfg.reserve = 8;
   cfg.sync = false;
   cfg.skip_lattice_preload = false;
}

void Test_RT1_FillRule()
{
   Rpl_ResetAll();
   Rpl_BrokerReset();
   const long t0 = RplMs(RPL_T0, 0);
   const long t1 = RplMs(RPL_T0, 1);
   const long t2 = RplMs(RPL_T0, 2);
   Rpl_BrokerPlaceLimit(ORDER_TYPE_BUY_LIMIT, 1.09981, "buy", t0);

   bool filled = false;
   double fp = 0.0;
   long ft = 0;
   Rpl_BrokerFillOnTick(t0, 1.09979, 1.09981, filled, fp, ft);
   AssertFalse("RT1 buy tick0 same ask", filled);
   Rpl_BrokerFillOnTick(t1, 1.09980, 1.09982, filled, fp, ft);
   AssertFalse("RT1 buy tick1 ask above", filled);
   Rpl_BrokerFillOnTick(t2, 1.09979, 1.09981, filled, fp, ft);
   AssertTrue("RT1 buy tick2 filled", filled);
   AssertNear("RT1 buy price", fp, 1.09981, 1e-9);
   AssertTrue("RT1 buy time", ft == t2);

   Rpl_BrokerReset();
   Rpl_BrokerPlaceLimit(ORDER_TYPE_SELL_LIMIT, 1.10081, "sell", t0);
   Rpl_BrokerFillOnTick(t0, 1.10080, 1.10082, filled, fp, ft);
   AssertFalse("RT1 sell bid below", filled);
   Rpl_BrokerFillOnTick(t1, 1.10081, 1.10083, filled, fp, ft);
   AssertTrue("RT1 sell filled", filled);
   AssertNear("RT1 sell price", fp, 1.10081, 1e-9);
}

void Test_RT2_FlatL0s()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 2);
   RplTick ticks[2];
   ticks[0].time_msc = RplMs(RPL_T0, 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   ticks[1].time_msc = RplMs(RPL_T0, 1);
   ticks[1].bid = 1.10000;
   ticks[1].ask = 1.10002;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 2, cfg);

   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT2 L00 ENT", Rpl_FindOrderByRoleLayer("L", 0, "ENT", p, tk));
   AssertNear("RT2 L00 price", p, 1.09981, 1e-9);
   AssertTrue("RT2 S00 ENT", Rpl_FindOrderByRoleLayer("S", 0, "ENT", p, tk));
   AssertNear("RT2 S00 price", p, 1.10151, 1e-9);
}

void Test_RT3_Scalp()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   RplTick ticks[4];
   for(int i = 0; i < 2; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000;
      ticks[i].ask = 1.10002;
   }
   ticks[2].time_msc = RplMs(RPL_T0, 2);
   ticks[2].bid = 1.09979;
   ticks[2].ask = 1.09981;
   ticks[3].time_msc = RplMs(RPL_T0, 3);
   ticks[3].bid = 1.10081;
   ticks[3].ask = 1.10083;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);

   AssertTrue("RT3 long depth 0", Rpl_LongDepth() == 0);
   AssertTrue("RT3 deals count 4", Rpl_DealsCount() == 4);
   AssertTrue("RT3 EXT L00", Rpl_OrderExistsForLayer("L", 0, "EXT") == false);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT3 short L0 unfilled", Rpl_FindOrderByRoleLayer("S", 0, "ENT", p, tk));
   AssertContains("RT3 scalp rolled false", Rpl_ScalpEventPeek(), "\"rolled\":false");
   AssertContains("RT3 scalp entry", Rpl_ScalpEventPeek(), "1.09981");
   AssertContains("RT3 scalp exit", Rpl_ScalpEventPeek(), "1.10081");
}

void Test_RT4_AddExitQueue()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   RplTick ticks[4];
   for(int i = 0; i < 2; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000;
      ticks[i].ask = 1.10002;
   }
   ticks[2].time_msc = RplMs(RPL_T0, 2);
   ticks[2].bid = 1.09979;
   ticks[2].ask = 1.09981;
   ticks[3].time_msc = RplMs(RPL_T0, 3);
   ticks[3].bid = 1.09909;
   ticks[3].ask = 1.09911;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);

   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT4 L01 EXT", Rpl_FindOrderByRoleLayer("L", 1, "EXT", p, tk));
   AssertNear("RT4 L01 EXT px", p, 1.10011, 1e-9);
   AssertTrue("RT4 L00 EXT", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT4 L00 EXT px", p, 1.10081, 1e-9);
   AssertTrue("RT4 L02 ENT", Rpl_FindOrderByRoleLayer("L", 2, "ENT", p, tk));
   AssertNear("RT4 L02 ENT px", p, 1.09841, 1e-9);
}

void Test_RT5_CapRoll()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.to_ms = RplMs(RPL_T0, 6);
   RplTick ticks[6];
   for(int i = 0; i < 2; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000;
      ticks[i].ask = 1.10002;
   }
   ticks[2].time_msc = RplMs(RPL_T0, 2);
   ticks[2].bid = 1.09979;
   ticks[2].ask = 1.09981;
   ticks[3].time_msc = RplMs(RPL_T0, 3);
   ticks[3].bid = 1.09909;
   ticks[3].ask = 1.09911;
   ticks[4].time_msc = RplMs(RPL_T0, 4);
   ticks[4].bid = 1.09839;
   ticks[4].ask = 1.09841;
   ticks[5].time_msc = RplMs(RPL_T0, 5);
   ticks[5].bid = 1.09941;
   ticks[5].ask = 1.09943;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 6, cfg);

   AssertTrue("RT5 ROLL_ACCEPTED", Rpl_CountEventsWithCode("ROLL_ACCEPTED") >= 1);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT5 L00 exit moved", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT5 L00 exit px", p, 1.09941, 1e-9);
   AssertContains("RT5 scalp rolled true", Rpl_ScalpEventPeek(), "\"rolled\":true");
}

void Test_RT6_Seed()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 2);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3 * 3600), 7001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -2 * 3600), 7002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 2, 1.09841, RplMs(RPL_T0, -3600), 7003UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[2];
   ticks[0].time_msc = RplMs(RPL_T0, 0);
   ticks[0].bid = 1.09900;
   ticks[0].ask = 1.09902;
   ticks[1].time_msc = RplMs(RPL_T0, 1);
   ticks[1].bid = 1.09900;
   ticks[1].ask = 1.09902;
   Rpl_RunTicks(ticks, 2, cfg);

   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT6 L02 EXT", Rpl_FindOrderByRoleLayer("L", 2, "EXT", p, tk));
   AssertNear("RT6 L02 EXT px", p, 1.09941, 1e-9);
   AssertTrue("RT6 L00 EXT", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT6 L00 EXT px", p, 1.10081, 1e-9);
   AssertFalse("RT6 no L01 order", Rpl_OrderExistsForLayer("L", 1, "EXT")
               || Rpl_OrderExistsForLayer("L", 1, "ENT"));
   AssertTrue("RT6 S00 ENT", Rpl_FindOrderByRoleLayer("S", 0, "ENT", p, tk));
   AssertNear("RT6 S00 px", p, 1.10051, 1e-9);
   AssertTrue("RT6 L03 ENT", Rpl_FindOrderByRoleLayer("L", 3, "ENT", p, tk));
   AssertNear("RT6 L03 px", p, 1.09771, 1e-9);
}

void Test_RT7_Gate()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.gate = 0;
   cfg.to_ms = RplMs(RPL_T0, 2);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3600), 7101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -1800), 7102UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("S", 0, 1.09870, RplMs(RPL_T0, -3600), 7201UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[2];
   ticks[0].time_msc = RplMs(RPL_T0, 0);
   ticks[0].bid = 1.09900;
   ticks[0].ask = 1.09902;
   ticks[1].time_msc = RplMs(RPL_T0, 1);
   ticks[1].bid = 1.09839;
   ticks[1].ask = 1.09841;
   Rpl_RunTicks(ticks, 2, cfg);

   AssertTrue("RT7 no ROLL_ACCEPTED", Rpl_CountEventsWithCode("ROLL_ACCEPTED") == 0);
   AssertTrue("RT7 ROLL_DEFERRED", Rpl_CountEventsWithCode("ROLL_DEFERRED") >= 1);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT7 L00 exit", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT7 L00 exit px", p, 1.10081, 1e-9);
}

void Test_RT8_SyncReset()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   cfg.to_ms = RplMs(RPL_T0, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3 * 3600), 7001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -2 * 3600), 7002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 2, 1.09841, RplMs(RPL_T0, -3600), 7003UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplRealDeal rd[1];
   rd[0].time_ms = RplMs(RPL_T0, 2) - 1;
   rd[0].entry_type = DEAL_ENTRY_OUT_BY;
   rd[0].deal_type = DEAL_TYPE_SELL;
   rd[0].role = "EXT";
   rd[0].side = "L";
   rd[0].layer = 2;
   rd[0].price = 1.09841;
   rd[0].position_id = 7003UL;
   Rpl_SetRealDeals(rd, 1);

   RplTick ticks[4];
   for(int i = 0; i < 4; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.09900;
      ticks[i].ask = 1.09902;
   }
   Rpl_RunTicks(ticks, 4, cfg);

   AssertFalse("RT8 L02 EXT gone", Rpl_OrderExistsForLayer("L", 2, "EXT"));
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT8 L01 EXT rank0", Rpl_FindOrderByRoleLayer("L", 1, "EXT", p, tk));
   AssertNear("RT8 L01 EXT px", p, 1.10011, 1e-9);
   AssertTrue("RT8 L02 ENT relabel", Rpl_FindOrderByRoleLayer("L", 2, "ENT", p, tk));
   AssertNear("RT8 L02 add px", p, 1.09841, 1e-9);
   if(Rpl_DealsCount() > 0) {
      RplDealRow row;
      Rpl_GetDealRow(Rpl_DealsCount() - 1, row);
      AssertTrue("RT8 sync_idx", row.sync_idx == 0);
   }
}

void Test_RT9_RolloverSwap()
{
   Rpl_ResetAll();
   const double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   Rpl_SetTestSwaps("2026.10.06", -8.111, 1.409, 1.0);
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.from_ms = RplMs(D'2026.10.05 23:59:00', 0);
   cfg.to_ms = RplMs(D'2026.10.06 00:00:01', 0);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(D'2026.10.05 12:00:00', 0), 6001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[2];
   ticks[0].time_msc = RplMs(D'2026.10.05 23:59:59', 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   ticks[1].time_msc = RplMs(D'2026.10.06 00:00:00', 0);
   ticks[1].bid = 1.10000;
   ticks[1].ask = 1.10002;
   Rpl_RunTicks(ticks, 2, cfg);
   const double expected = -8.111 * 1.0 * tick_val * RPL_LOTS_DEFAULT;
   AssertNear("RT9 swap tick_val=" + DoubleToString(tick_val, 4),
              Rpl_GetPositionSwap(6001UL), expected, 1e-9);
}

void Test_RT10_CarryShift()
{
   Rpl_ResetAll();
   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   Print("RT10 live SYMBOL_SWAP_LONG=", DoubleToString(swap_long, 4));
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.carry = true;
   cfg.from_ms = RplMs(D'2026.10.06 23:49:30', 0);
   cfg.to_ms = RplMs(D'2026.10.06 23:52:00', 0) + 1000;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(D'2026.10.06 12:00:00', 0), 8001UL, 0.0, -0.08, RPL_LOTS_DEFAULT);
   const int n = (int)((cfg.to_ms - cfg.from_ms) / 1000) + 1;
   RplTick ticks[];
   ArrayResize(ticks, n);
   for(int i = 0; i < n; i++) {
      ticks[i].time_msc = cfg.from_ms + (long)i * 1000;
      ticks[i].bid = 1.09900;
      ticks[i].ask = 1.09902;
   }
   Rpl_RunTicks(ticks, n, cfg);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT10 exit order", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   const double pip = 10.0 * _Point;
   const double P_pips = -(swap_long) * 3.0 / 10.0;
   const double expected = 1.10081 + (0.8 + P_pips) * pip;
   AssertNear("RT10 exit shifted", p, expected, 0.5 * pip);
}

void Test_RT11_Outputs()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   RplTick ticks[4];
   for(int i = 0; i < 2; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000;
      ticks[i].ask = 1.10002;
   }
   ticks[2].time_msc = RplMs(RPL_T0, 2);
   ticks[2].bid = 1.09979;
   ticks[2].ask = 1.09981;
   ticks[3].time_msc = RplMs(RPL_T0, 3);
   ticks[3].bid = 1.10081;
   ticks[3].ask = 1.10083;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);
   AssertTrue("RT11 four deals", Rpl_DealsCount() == 4);
   RplDealRow row;
   for(int i = 0; i < 4; i++) {
      AssertTrue("RT11 deal row", Rpl_GetDealRow(i, row));
      AssertTrue("RT11 seg_id", row.seg_id == 1);
      AssertTrue("RT11 sync_idx", row.sync_idx == -1);
   }
}

void Test_RT12_NoRealSend()
{
   Rpl_ResetAll();
   const long api0 = Grind_ApiCounterRead();
   Test_RT3_Scalp();
   Test_RT5_CapRoll();
   Test_RT8_SyncReset();
   AssertTrue("RT12 api delta 0", Grind_ApiCounterRead() - api0 == 0);
   AssertTrue("RT12 closeby sends", g_grind_closeby_test_send_calls > 0);
   AssertTrue("RT12 order book ok", Rpl_OrderSeamCount() >= 0);
}

void Test_RT13_Safety()
{
   AssertTrue("RT13 replay path",
              Rpl_SafeToRun("D:\\mt5-replay", false, 53077984, "ICMarketsSC-Demo"));
   AssertTrue("RT13 case path",
              Rpl_SafeToRun("d:\\MT5-Replay", false, 53077984, "ICMarketsSC-Demo"));
   AssertFalse("RT13 live suffix",
               Rpl_SafeToRun("D:\\mt5-replay-live", false, 53077984, "ICMarketsSC-Demo"));
   AssertFalse("RT13 subpath",
               Rpl_SafeToRun("D:\\mt5-replay\\x", false, 53077984, "ICMarketsSC-Demo"));
   AssertFalse("RT13 roaming",
               Rpl_SafeToRun("C:\\Users\\k\\AppData\\Roaming\\MetaQuotes\\Terminal\\81A9",
                             false, 53077984, "ICMarketsSC-Demo"));
   AssertFalse("RT13 trade allowed",
               Rpl_SafeToRun("D:\\mt5-replay", true, 53077984, "ICMarketsSC-Demo"));
   AssertFalse("RT13 wrong login",
               Rpl_SafeToRun("D:\\mt5-replay", false, 53066709, "ICMarketsSC-Demo"));
   AssertFalse("RT13 wrong server",
               Rpl_SafeToRun("D:\\mt5-replay", false, 53077984, "FTMO-Demo"));
}

void Test_RT14_LatticeHistory()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.to_ms = RplMs(RPL_T0, 6);
   RplTick ticks[6];
   for(int i = 0; i < 6; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000 - (i >= 4 ? 0.00161 * (i - 3) : 0.0);
      ticks[i].ask = ticks[i].bid + RPL_SPREAD;
   }
   ticks[2].bid = 1.09979;
   ticks[2].ask = 1.09981;
   ticks[3].bid = 1.09909;
   ticks[3].ask = 1.09911;
   ticks[4].bid = 1.09839;
   ticks[4].ask = 1.09841;
   ticks[5].bid = 1.09839;
   ticks[5].ask = 1.09841;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 6, cfg);
   AssertFalse("RT14 cap fill no abort", Rpl_WasAborted());

   Rpl_ResetAll();
   cfg.skip_lattice_preload = true;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -7200), 9001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -3600), 9002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick t1[1];
   t1[0].time_msc = RplMs(RPL_T0, 0);
   t1[0].bid = 1.09839;
   t1[0].ask = 1.09841;
   Rpl_RunTicks(t1, 1, cfg);
   AssertTrue("RT14 lattice abort", Rpl_WasAborted());
   AssertContains("RT14 abort reason", Rpl_AbortReason(), "LATTICE_HISTORY");
}

void OnStart()
{
   Print("RPL|MIRRORS_EA|", RPL_MIRRORS_EA);
   Test_RT1_FillRule();
   Test_RT2_FlatL0s();
   Test_RT3_Scalp();
   Test_RT4_AddExitQueue();
   Test_RT5_CapRoll();
   Test_RT6_Seed();
   Test_RT7_Gate();
   Test_RT8_SyncReset();
   Test_RT9_RolloverSwap();
   Test_RT10_CarryShift();
   Test_RT11_Outputs();
   Test_RT12_NoRealSend();
   Test_RT13_Safety();
   Test_RT14_LatticeHistory();
   Print("RPL|SUMMARY|run=", g_tests_run, "|pass=", g_tests_passed);
}
