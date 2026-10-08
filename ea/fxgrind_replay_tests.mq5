//+------------------------------------------------------------------+
//| fxgrind_replay_tests.mq5 — replay harness RT1–RT21 (fix1 s5)       |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.01"
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
const string   RPL_DEALS_HEADER =
   "seg_id,sync_idx,time_ms,deal,order,position,entry_type,deal_type,role,side,layer,price";

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

void Rpl_FillRT3Ticks(RplTick &ticks[], const int n)
{
   ArrayResize(ticks, n);
   for(int i = 0; i < 2 && i < n; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.10000;
      ticks[i].ask = 1.10002;
   }
   if(n > 2) {
      ticks[2].time_msc = RplMs(RPL_T0, 2);
      ticks[2].bid = 1.09979;
      ticks[2].ask = 1.09981;
   }
   if(n > 3) {
      ticks[3].time_msc = RplMs(RPL_T0, 3);
      ticks[3].bid = 1.10081;
      ticks[3].ask = 1.10083;
   }
}

void AssertDealRow(const string prefix,
                   const int index,
                   const long deal_type,
                   const string role,
                   const string side,
                   const int layer,
                   const double price,
                   const long time_ms)
{
   RplDealRow row;
   AssertTrue(prefix + " get", Rpl_GetDealRow(index, row));
   AssertTrue(prefix + " deal_type", row.deal_type == deal_type);
   AssertEqStr(prefix + " role", row.role, role);
   AssertEqStr(prefix + " side", row.side, side);
   AssertTrue(prefix + " layer", row.layer == layer);
   AssertNear(prefix + " price", row.price, price, 1e-9);
   AssertTrue(prefix + " time", row.time_ms == time_ms);
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
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);
   const long t2 = RplMs(RPL_T0, 2);
   const long t3 = RplMs(RPL_T0, 3);
   AssertTrue("RT3 deals count 4", Rpl_DealsCount() == 4);
   AssertDealRow("RT3 row0", 0, DEAL_TYPE_BUY, "ENT", "L", 0, 1.09981, t2);
   AssertDealRow("RT3 row1", 1, DEAL_TYPE_SELL, "EXT", "L", 0, 1.10081, t3);
   AssertDealRow("RT3 row2", 2, DEAL_TYPE_SELL, "ENT", "L", 0, 1.09981, t3);
   AssertDealRow("RT3 row3", 3, DEAL_TYPE_BUY, "EXT", "L", 0, 1.10081, t3);
   AssertTrue("RT3 long depth 0", Rpl_LongDepth() == 0);
   AssertContains("RT3 scalp rolled false", Rpl_ScalpEventPeek(), "\"rolled\":false");
}

void Test_RT3b_EarlyBook()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 3);
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 3);
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 3, cfg);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT3b L00 EXT", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT3b L00 EXT px", p, 1.10081, 1e-9);
   AssertTrue("RT3b L01 ENT", Rpl_FindOrderByRoleLayer("L", 1, "ENT", p, tk));
   AssertNear("RT3b L01 ENT px", p, 1.09911, 1e-9);
   AssertTrue("RT3b long depth 1", Rpl_LongDepth() == 1);
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

void Test_RT5a_RollAccepted()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.to_ms = RplMs(RPL_T0, 5);
   RplTick ticks[5];
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
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 5, cfg);
   AssertTrue("RT5a ROLL_ACCEPTED count", Rpl_CountEventsWithCode("ROLL_ACCEPTED") == 1);
   bool found_json = false;
   for(int i = 0; i < Rpl_EventsCount(); i++) {
      RplEventRow ev;
      if(!Rpl_GetEventRow(i, ev))
         continue;
      if(ev.code != "ROLL_ACCEPTED")
         continue;
      if(StringFind(ev.json, "1.09841") >= 0 && StringFind(ev.json, "1.09941") >= 0)
         found_json = true;
   }
   AssertTrue("RT5a roll json", found_json);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT5a L00 EXT", Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk));
   AssertNear("RT5a L00 EXT px", p, 1.09941, 1e-9);
   AssertTrue("RT5a long depth 2", Rpl_LongDepth() == 2);
   AssertTrue("RT5a no deal t4", Rpl_DealsCount() <= 3);
}

void Test_RT5b_RollScalp()
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
   const long t5 = RplMs(RPL_T0, 5);
   AssertDealRow("RT5b ext fill", Rpl_DealsCount() - 1, DEAL_TYPE_SELL, "EXT", "L", 0, 1.09941, t5);
   AssertContains("RT5b rolled true", Rpl_ScalpEventPeek(), "\"rolled\":true");
   AssertContains("RT5b entry px", Rpl_ScalpEventPeek(), "1.09981");
   AssertContains("RT5b exit px", Rpl_ScalpEventPeek(), "1.09941");
   AssertFalse("RT5b no L00 EXT", Rpl_OrderExistsForLayer("L", 0, "EXT"));
   AssertTrue("RT5b long depth 1", Rpl_LongDepth() == 1);
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
   AssertTrue("RT7 ROLL_DEFERRED count", Rpl_CountEventsWithCode("ROLL_DEFERRED") == 1);
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
   string rows[1];
   rows[0] = IntegerToString(RplMs(RPL_T0, 2) - 1) + ",OUT_BY,L,2,1.09841,7003,";
   Rpl_SetSyncRealKindRows(rows, 1);
   RplTick ticks[4];
   for(int i = 0; i < 4; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.09900;
      ticks[i].ask = 1.09902;
   }
   Rpl_RunTicks(ticks, 4, cfg);
   AssertFalse("RT8 has 7003", Rpl_HasPosition(7003UL));
   AssertTrue("RT8 long depth 2", Rpl_LongDepth() == 2);
   AssertTrue("RT8 sync_idx", Rpl_CurrentSyncIdx() == 0);
   AssertFalse("RT8 L02 EXT gone", Rpl_OrderExistsForLayer("L", 2, "EXT"));
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT8 L01 EXT", Rpl_FindOrderByRoleLayer("L", 1, "EXT", p, tk));
   AssertNear("RT8 L01 EXT px", p, 1.10011, 1e-9);
   AssertTrue("RT8 L02 ENT add", Rpl_FindOrderByRoleLayer("L", 2, "ENT", p, tk));
   AssertNear("RT8 L02 add px", p, 1.09841, 1e-9);
}

void Test_RT8b_SyncEntRoll()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   cfg.to_ms = RplMs(RPL_T0, 3);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3600), 7001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -1800), 7002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   string rows[2];
   rows[0] = IntegerToString(RplMs(RPL_T0, 1) - 1) + ",ENT,L,2,1.09841,7003,";
   rows[1] = IntegerToString(RplMs(RPL_T0, 1) - 1) + ",ROLL,L,0,,7001,1.09771";
   Rpl_SetSyncRealKindRows(rows, 2);
   RplTick ticks[3];
   for(int i = 0; i < 3; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.09900;
      ticks[i].ask = 1.09902;
   }
   Rpl_RunTicks(ticks, 3, cfg);
   AssertTrue("RT8b depth 3", Rpl_LongDepth() == 3);
   AssertTrue("RT8b has 7001", Rpl_HasPosition(7001UL));
   AssertTrue("RT8b has 7002", Rpl_HasPosition(7002UL));
   AssertTrue("RT8b has 7003", Rpl_HasPosition(7003UL));
   AssertNear("RT8b VL7001", Grind_VLGet(7001UL), 1.09771, 1e-9);
   AssertTrue("RT8b sync_idx", Rpl_CurrentSyncIdx() == 1);
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
   AssertNear("RT9 swap", Rpl_GetPositionSwap(6001UL), expected, 1e-9);
}

double Test_RT10_ExitPrice()
{
   Rpl_ResetAll();
   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
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
   Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk);
   const double pip = 10.0 * _Point;
   const double P_pips = -(swap_long) * 3.0 / 10.0;
   const double expected = 1.10081 + (0.8 + P_pips) * pip;
   AssertNear("RT10 exit shifted", p, expected, 0.05 * pip);
   return p;
}

void Test_RT10_CarryShift()
{
   Test_RT10_ExitPrice();
}

void Test_RT16_CarryTwice()
{
   const double p1 = Test_RT10_ExitPrice();
   Rpl_ResetAll();
   const double p2 = Test_RT10_ExitPrice();
   AssertNear("RT16 same exit run2", p2, p1, 0.05 * 10.0 * _Point);
}

void Test_RT11_Outputs()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);
   AssertTrue("RT11 run files", Rpl_RunReplayFiles("rt11", false));
   int h = FileOpen("replay\\out_rt11_deals.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   AssertTrue("RT11 open deals", h != INVALID_HANDLE);
   string hdr = FileReadString(h);
   AssertEqStr("RT11 header", hdr, RPL_DEALS_HEADER);
   long prev_t = 0;
   for(int r = 0; r < 4; r++) {
      FileReadString(h);
      FileReadString(h);
      const long tm = (long)StringToInteger(FileReadString(h));
      AssertTrue("RT11 time order", tm >= prev_t);
      prev_t = tm;
      FileReadString(h);
      FileReadString(h);
      FileReadString(h);
      FileReadString(h);
      const long dtype = (long)StringToInteger(FileReadString(h));
      const string role = FileReadString(h);
      if(r == 0) {
         AssertTrue("RT11 r0 BUY", dtype == DEAL_TYPE_BUY);
         AssertEqStr("RT11 r0 ENT", role, "ENT");
      }
      if(r == 1) {
         AssertTrue("RT11 r1 SELL", dtype == DEAL_TYPE_SELL);
         AssertEqStr("RT11 r1 EXT", role, "EXT");
      }
      FileReadString(h);
      FileReadString(h);
      FileReadString(h);
   }
   FileClose(h);
   AssertTrue("RT11 summary", FileIsExist("replay\\out_rt11_summary.txt", FILE_COMMON) ||
              FileIsExist("replay\\out_rt11_summary.txt"));
}

void Test_RT12_NoRealSend()
{
   Rpl_ResetAll();
   const long api0 = Grind_ApiCounterRead();
   Test_RT3_Scalp();
   Test_RT5b_RollScalp();
   Test_RT8_SyncReset();
   AssertTrue("RT12 api delta 0", Grind_ApiCounterRead() - api0 == 0);
   AssertTrue("RT12 closeby sends", g_grind_closeby_test_send_calls > 0);
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

void Test_RT15_SegmentRollover()
{
   Rpl_SetTestSwaps("2026.10.07", -8.067, 1.364, 1.0);
   Rpl_ResetAll();
   RplSegmentConfig cfg1;
   Rpl_DefaultConfig(cfg1);
   cfg1.from_ms = RplMs(D'2026.10.07 10:00:00', 0);
   cfg1.to_ms = RplMs(D'2026.10.07 10:00:00', 1);
   Rpl_ConfigureEngine(cfg1);
   RplTick t1[2];
   t1[0].time_msc = RplMs(D'2026.10.07 10:00:00', 0);
   t1[0].bid = 1.10000;
   t1[0].ask = 1.10002;
   t1[1].time_msc = RplMs(D'2026.10.07 10:00:01', 0);
   t1[1].bid = 1.10000;
   t1[1].ask = 1.10002;
   Rpl_RunTicks(t1, 2, cfg1);
   Rpl_ResetAll();
   RplSegmentConfig cfg2;
   Rpl_DefaultConfig(cfg2);
   cfg2.from_ms = RplMs(D'2026.10.06 10:00:00', 0);
   cfg2.to_ms = RplMs(D'2026.10.07 00:00:00', 0) + 1000;
   Rpl_ConfigureEngine(cfg2);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(D'2026.10.06 09:00:00', 0), 6101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick t2[3];
   t2[0].time_msc = RplMs(D'2026.10.06 10:00:00', 0);
   t2[0].bid = 1.10000;
   t2[0].ask = 1.10002;
   t2[1].time_msc = RplMs(D'2026.10.06 23:59:59', 0);
   t2[1].bid = 1.10000;
   t2[1].ask = 1.10002;
   t2[2].time_msc = RplMs(D'2026.10.07 00:00:00', 0);
   t2[2].bid = 1.10000;
   t2[2].ask = 1.10002;
   Rpl_RunTicks(t2, 3, cfg2);
   AssertNear("RT15 swap after first tick", Rpl_GetPositionSwap(6101UL), 0.0, 1e-9);
   const double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   AssertNear("RT15 swap 10.07 night", Rpl_GetPositionSwap(6101UL), -8.067 * tv * RPL_LOTS_DEFAULT, 1e-9);
}

void Test_RT17_PreloadRoll()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.from_ms = RplMs(RPL_T0, 0);
   cfg.to_ms = RplMs(RPL_T0, 2);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3600), 8001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -3600), 8002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[4];
   ticks[0].time_msc = RplMs(RPL_T0, -3600);
   ticks[0].bid = 1.09900;
   ticks[0].ask = 1.09902;
   ticks[1].time_msc = RplMs(RPL_T0, -60);
   ticks[1].bid = 1.09839;
   ticks[1].ask = 1.09841;
   ticks[2].time_msc = RplMs(RPL_T0, 0);
   ticks[2].bid = 1.09900;
   ticks[2].ask = 1.09902;
   ticks[3].time_msc = RplMs(RPL_T0, 1);
   ticks[3].bid = 1.09900;
   ticks[3].ask = 1.09902;
   Rpl_RunTicks(ticks, 4, cfg);
   AssertTrue("RT17 one ROLL_ACCEPTED", Rpl_CountEventsWithCode("ROLL_ACCEPTED") == 1);
   bool lvl = false;
   for(int i = 0; i < Rpl_EventsCount(); i++) {
      RplEventRow ev;
      if(Rpl_GetEventRow(i, ev) && ev.code == "ROLL_ACCEPTED")
         lvl = (StringFind(ev.json, "1.09841") >= 0);
   }
   AssertTrue("RT17 level json", lvl);
}

void Test_RT20_PreloadNoAbort()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.from_ms = RplMs(RPL_T0, 0);
   cfg.to_ms = RplMs(RPL_T0, 1);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3600), 8101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -3600), 8102UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[3];
   ticks[0].time_msc = RplMs(RPL_T0, -3597);
   ticks[0].bid = 1.09900;
   ticks[0].ask = 1.09902;
   ticks[1].time_msc = RplMs(RPL_T0, 0);
   ticks[1].bid = 1.09900;
   ticks[1].ask = 1.09902;
   ticks[2].time_msc = RplMs(RPL_T0, 1);
   ticks[2].bid = 1.09900;
   ticks[2].ask = 1.09902;
   Rpl_RunTicks(ticks, 3, cfg);
   AssertFalse("RT20 no abort", Rpl_WasAborted());
}

void Test_RT18_SameTickFills()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   RplTick ticks[4];
   for(int i = 0; i < 3; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      if(i < 2) {
         ticks[i].bid = 1.10000;
         ticks[i].ask = 1.10002;
      } else {
         ticks[i].bid = 1.09979;
         ticks[i].ask = 1.09981;
      }
   }
   ticks[3].time_msc = RplMs(RPL_T0, 3);
   ticks[3].bid = 1.10151;
   ticks[3].ask = 1.10153;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 4, cfg);
   AssertTrue("RT18 two IN same tick", Rpl_DealsCount() >= 2);
   RplDealRow a, b;
   Rpl_GetDealRow(Rpl_DealsCount() - 2, a);
   Rpl_GetDealRow(Rpl_DealsCount() - 1, b);
   AssertEqStr("RT18 first S00", a.side, "S");
   AssertEqStr("RT18 first role ENT", a.role, "ENT");
   AssertEqStr("RT18 second EXT", b.role, "EXT");
}

void Test_RT19_ReplayFiles()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt19.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(ticks[i].time_msc), DoubleToString(ticks[i].bid, 5),
                DoubleToString(ticks[i].ask, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "run_rt19.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt19.csv");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt19.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   AssertTrue("RT19 run", Rpl_RunReplayFiles("rt19", false));
   int h = FileOpen(dir + "out_rt19_deals.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   AssertTrue("RT19 deals file", h != INVALID_HANDLE);
   string hdr = FileReadString(h);
   AssertEqStr("RT19 header", hdr, RPL_DEALS_HEADER);
   int rows = 0;
   while(!FileIsEnding(h)) {
      FileReadString(h);
      rows++;
   }
   FileClose(h);
   AssertTrue("RT19 four rows", rows >= 5);
   AssertTrue("RT19 summary", FileIsExist(dir + "out_rt19_summary.txt"));
}

void Test_RT21_GapReport()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.from_ms = RplMs(D'2026.10.06 10:00:00', 0);
   cfg.to_ms = RplMs(D'2026.10.06 23:57:00', 0) + 1000;
   RplTick ticks[5];
   ticks[0].time_msc = RplMs(D'2026.10.06 10:00:00', 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   ticks[1].time_msc = RplMs(D'2026.10.06 10:00:30', 0);
   ticks[1].bid = 1.10000;
   ticks[1].ask = 1.10002;
   ticks[2].time_msc = RplMs(D'2026.10.06 10:02:00', 0);
   ticks[2].bid = 1.10000;
   ticks[2].ask = 1.10002;
   ticks[3].time_msc = RplMs(D'2026.10.06 23:55:00', 0);
   ticks[3].bid = 1.10000;
   ticks[3].ask = 1.10002;
   ticks[4].time_msc = RplMs(D'2026.10.06 23:57:00', 0);
   ticks[4].bid = 1.10000;
   ticks[4].ask = 1.10002;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 5, cfg);
   AssertTrue("RT21 one gap", Rpl_GapReportCount() == 1);
   long from_ms = 0;
   long secs = 0;
   AssertTrue("RT21 gap row", Rpl_GapReportAt(0, from_ms, secs));
   AssertTrue("RT21 gap from", from_ms == RplMs(D'2026.10.06 10:00:30', 0));
   AssertTrue("RT21 gap 90s", secs == 90);
}

void OnStart()
{
   Print("RPL|MIRRORS_EA|", RPL_MIRRORS_EA);
   Test_RT1_FillRule();
   Test_RT2_FlatL0s();
   Test_RT3_Scalp();
   Test_RT3b_EarlyBook();
   Test_RT4_AddExitQueue();
   Test_RT5a_RollAccepted();
   Test_RT5b_RollScalp();
   Test_RT6_Seed();
   Test_RT7_Gate();
   Test_RT8_SyncReset();
   Test_RT8b_SyncEntRoll();
   Test_RT9_RolloverSwap();
   Test_RT10_CarryShift();
   Test_RT11_Outputs();
   Test_RT12_NoRealSend();
   Test_RT13_Safety();
   Test_RT14_LatticeHistory();
   Test_RT15_SegmentRollover();
   Test_RT16_CarryTwice();
   Test_RT17_PreloadRoll();
   Test_RT18_SameTickFills();
   Test_RT19_ReplayFiles();
   Test_RT20_PreloadNoAbort();
   Test_RT21_GapReport();
   Print("RPL|SUMMARY|run=", g_tests_run, "|pass=", g_tests_passed);
}
