//+------------------------------------------------------------------+
//| fxgrind_replay_tests.mq5 — replay harness RT1–RT52 (fix5 T24–T26) |
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
   const bool ok = (MathAbs(got - expected) <= tol);
   if(!ok)
      Print("FAIL-DETAIL | ", name, " | got=", DoubleToString(got, 8),
            " | expected=", DoubleToString(expected, 8), " | tol=", DoubleToString(tol, 8));
   AssertTrue(name, ok);
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
   Rpl_SegmentConfigDefaults(cfg);
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

void AssertOrderRow(const string prefix,
                    const int index,
                    const long time_ms,
                    const string stage,
                    const string action,
                    const ulong ticket,
                    const double price)
{
   RplOrderRow row;
   AssertTrue(prefix + " get", Rpl_GetOrderLogRow(index, row));
   AssertTrue(prefix + " time", row.time_ms == time_ms);
   AssertEqStr(prefix + " stage", row.stage, stage);
   AssertEqStr(prefix + " action", row.action, action);
   AssertTrue(prefix + " ticket", row.ticket == ticket);
   AssertNear(prefix + " price", row.price, price, 1e-9);
}

void Test_RT48_OrderLogDiff()
{
   Rpl_ResetAll();
   const string c1 = GrindCommentBuild(RPL_SLOT_DEFAULT, "L", 2, "EXT");
   Grind_OrderTestUpsert(5901UL, (long)RPL_MAGIC_DEFAULT, c1, 1.10100, ORDER_TYPE_SELL_LIMIT);
   Rpl_OrderLogDiff(1000, "A");
   Grind_OrderTestUpsert(5901UL, (long)RPL_MAGIC_DEFAULT, c1, 1.10108, ORDER_TYPE_SELL_LIMIT);
   Rpl_OrderLogDiff(2000, "B");
   Rpl_OrderLogDiff(2500, "B2");
   Grind_OrderTestRemove(5901UL);
   Rpl_OrderLogDiff(3000, "C");
   const string c2 = GrindCommentBuild(RPL_SLOT_DEFAULT, "S", 1, "ENT");
   Grind_OrderTestUpsert(5902UL, (long)RPL_MAGIC_DEFAULT, c2, 1.10570, ORDER_TYPE_SELL_LIMIT);
   Rpl_OrderLogDiff(3500, "D");
   Grind_OrderTestRemove(5902UL);
   Rpl_WriteDealOutput(4000, 7001UL, 5902UL, 7101UL, DEAL_ENTRY_IN, DEAL_TYPE_SELL, "ENT", "S", 1, 1.10570);
   Rpl_OrderLogDiff(4000, "E");
   AssertTrue("RT48 count", Rpl_OrderLogCount() == 5);
   AssertOrderRow("RT48 r0", 0, 1000, "A", "PLACE", 5901UL, 1.10100);
   RplOrderRow r0;
   Rpl_GetOrderLogRow(0, r0);
   AssertEqStr("RT48 r0 side", r0.side, "L");
   AssertTrue("RT48 r0 layer", r0.layer == 2);
   AssertEqStr("RT48 r0 role", r0.role, "EXT");
   AssertTrue("RT48 r0 type", r0.type == ORDER_TYPE_SELL_LIMIT);
   AssertOrderRow("RT48 r1", 1, 2000, "B", "MODIFY", 5901UL, 1.10108);
   RplOrderRow r1;
   Rpl_GetOrderLogRow(1, r1);
   AssertNear("RT48 r1 old", r1.old_price, 1.10100, 1e-9);
   AssertOrderRow("RT48 r2", 2, 3000, "C", "REMOVE", 5901UL, 1.10108);
   AssertOrderRow("RT48 r3", 3, 3500, "D", "PLACE", 5902UL, 1.10570);
   AssertOrderRow("RT48 r4", 4, 4000, "E", "FILL", 5902UL, 1.10570);
}

void Test_RT49_OrderLogEngineExit()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 5951UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[4];
   const double bids[4] = {1.10050, 1.10100, 1.10108, 1.10050};
   for(int i = 0; i < 4; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = bids[i];
      ticks[i].ask = bids[i] + RPL_SPREAD;
   }
   Rpl_RunTicks(ticks, 4, cfg);
   int i = -1;
   for(int k = 0; k < Rpl_OrderLogCount(); k++) {
      RplOrderRow row;
      if(!Rpl_GetOrderLogRow(k, row))
         continue;
      if(row.action == "PLACE" && row.side == "L" && row.layer == 0 && row.role == "EXT") {
         i = k;
         break;
      }
   }
   RplOrderRow r;
   AssertTrue("RT49 placed", i >= 0);
   Rpl_GetOrderLogRow(i, r);
   AssertTrue("RT49 at T0", r.time_ms == RplMs(RPL_T0, 0));
   AssertEqStr("RT49 stage", r.stage, "ENGINE");
   AssertNear("RT49 price", r.price, 1.10100, 1e-9);
   int j = -1;
   for(int k = 0; k < Rpl_OrderLogCount(); k++) {
      RplOrderRow row;
      if(!Rpl_GetOrderLogRow(k, row))
         continue;
      if(row.action == "FILL" && row.ticket == r.ticket) {
         j = k;
         break;
      }
   }
   RplOrderRow q;
   AssertTrue("RT49 filled", j >= 0);
   Rpl_GetOrderLogRow(j, q);
   AssertTrue("RT49 fill at T1", q.time_ms == RplMs(RPL_T0, 1));
   AssertEqStr("RT49 fill stage", q.stage, "FILL");
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
   AssertDealRow("RT3 row2", 2, DEAL_TYPE_SELL, "ENT", "L", 0, 1.10081, t3);
   AssertDealRow("RT3 row3", 3, DEAL_TYPE_BUY, "EXT", "L", 0, 1.09981, t3);
   AssertTrue("RT3 long depth 0", Rpl_LongDepth() == 0);
   AssertContains("RT3 scalp rolled false", Rpl_ScalpEventPeek(), "\"rolled\":false");
   AssertContains("RT3 scalp exit px", Rpl_ScalpEventPeek(), "\"exit_price\":1.10081");
   AssertContains("RT3 scalp pnl", Rpl_ScalpEventPeek(), "\"gross_pnl\":1.00");
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
   AssertTrue("RT5b deals count 5", Rpl_DealsCount() == 5);
   AssertDealRow("RT5b ext fill", 2, DEAL_TYPE_SELL, "EXT", "L", 0, 1.09941, t5);
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
   double tb_vl7001 = 0.0;
   for(int i = 0; i < g_rpl_true_book_count; i++) {
      if(g_rpl_true_book[i].ticket == 7001UL) {
         tb_vl7001 = g_rpl_true_book[i].vl;
         break;
      }
   }
   AssertNear("RT8b true VL7001", tb_vl7001, 1.09771, 1e-9);
   AssertTrue("RT8b held 7001 not rolled", !Grind_VLHas(7001UL));
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
   AssertNear("RT9 tick value 1.0", tick_val, 1.0, 1e-9);
   const double expected = -0.08111;
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
   for(int i = 0; i < Rpl_EventsCount(); i++) {
      RplEventRow ev;
      if(!Rpl_GetEventRow(i, ev))
         continue;
      if(StringFind(ev.code, "CARRY_") == 0)
         Print("RT10-EVENT | ", ev.code, " | ", ev.json);
   }
   double p = 0.0;
   ulong tk = 0;
   const bool found_ext = Rpl_FindOrderByRoleLayer("L", 0, "EXT", p, tk);
   Print("RT10-ORDER | found=", found_ext, " | price=", DoubleToString(p, 8));
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
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt11.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(ticks[i].time_msc), DoubleToString(ticks[i].bid, 5),
                DoubleToString(ticks[i].ask, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "run_rt11.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt11.csv");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   AssertTrue("RT11 run files", Rpl_RunReplayFiles("rt11", false));
   int h = FileOpen("replay\\out_rt11_deals.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   AssertTrue("RT11 open deals", h != INVALID_HANDLE);
   string hdr = FileReadString(h);
   for(int k = 1; k < 12; k++)
      hdr += "," + FileReadString(h);
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
   const int s3 = g_grind_closeby_test_send_calls;
   Test_RT5b_RollScalp();
   const int s5 = g_grind_closeby_test_send_calls;
   Test_RT8_SyncReset();
   AssertTrue("RT12 api delta 0", Grind_ApiCounterRead() - api0 == 0);
   AssertTrue("RT12 closeby sends RT3", s3 > 0);
   AssertTrue("RT12 closeby sends RT5b", s5 > 0);
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
   Rpl_AppendTestSwap("2026.10.06", -8.111, 1.409, 1.0);
   Rpl_AppendTestSwap("2026.10.07", -8.067, 1.364, 1.0);
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
   RplSegmentConfig cfg2_pre;
   Rpl_DefaultConfig(cfg2_pre);
   cfg2_pre.from_ms = cfg2.from_ms;
   cfg2_pre.to_ms = RplMs(D'2026.10.06 23:59:59', 0) + 1;
   Rpl_ConfigureEngine(cfg2_pre);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(D'2026.10.06 09:00:00', 0), 6101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick t2_pre[2];
   t2_pre[0].time_msc = RplMs(D'2026.10.06 10:00:00', 0);
   t2_pre[0].bid = 1.10000;
   t2_pre[0].ask = 1.10002;
   t2_pre[1].time_msc = RplMs(D'2026.10.06 23:59:59', 0);
   t2_pre[1].bid = 1.10000;
   t2_pre[1].ask = 1.10002;
   Rpl_RunTicks(t2_pre, 2, cfg2_pre);
   AssertNear("RT15 swap before midnight", Rpl_GetPositionSwap(6101UL), 0.0, 1e-9);
   Rpl_ResetAll();
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
   AssertNear("RT15 swap 10.07 night", Rpl_GetPositionSwap(6101UL), -0.08067, 1e-9);
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
   const long t2 = RplMs(RPL_T0, 2);
   const long t3 = RplMs(RPL_T0, 3);
   AssertTrue("RT18 deals count 5", Rpl_DealsCount() == 5);
   AssertDealRow("RT18 row0", 0, DEAL_TYPE_BUY, "ENT", "L", 0, 1.09981, t2);
   AssertDealRow("RT18 row1", 1, DEAL_TYPE_SELL, "ENT", "S", 0, 1.10151, t3);
   AssertDealRow("RT18 row2", 2, DEAL_TYPE_SELL, "EXT", "L", 0, 1.10081, t3);
}

string Rpl_ReadWholeFile(const string rel_path);

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
   for(int k = 1; k < 12; k++)
      hdr += "," + FileReadString(h);
   AssertEqStr("RT19 header", hdr, RPL_DEALS_HEADER);
   FileClose(h);
   string l19[];
   AssertTrue("RT19 five lines", StringSplit(Rpl_ReadWholeFile(dir + "out_rt19_deals.csv"), '\n', l19) == 5);
   AssertTrue("RT19 summary", FileIsExist(dir + "out_rt19_summary.txt"));
}

void Test_RT22_CsvHeaderLine()
{
   const string path = "replay\\ticks_rt22.csv";
   int w = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   FileWrite(w, "# comment, with, commas");
   FileWrite(w, "time_msc_server,bid,ask,flags");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 0)) + ",1.10000,1.10002,6");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 1)) + ",1.10010,1.10012,2");
   FileClose(w);
   RplTick ticks[];
   int n = 0;
   AssertTrue("RT22 load ok", Rpl_LoadTicksCsv("ticks_rt22.csv", ticks, n));
   AssertTrue("RT22 count 2", n == 2);
   AssertTrue("RT22 t0 ms", ticks[0].time_msc == RplMs(RPL_T0, 0));
   AssertNear("RT22 t0 bid", ticks[0].bid, 1.10000, 1e-9);
   AssertNear("RT22 t0 ask", ticks[0].ask, 1.10002, 1e-9);
   AssertTrue("RT22 t1 ms", ticks[1].time_msc == RplMs(RPL_T0, 1));
   AssertNear("RT22 t1 bid", ticks[1].bid, 1.10010, 1e-9);
   AssertNear("RT22 t1 ask", ticks[1].ask, 1.10012, 1e-9);
}

string Rpl_ReadWholeFile(const string rel_path)
{
   int h = FileOpen(rel_path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return "";
   string all = "";
   while(!FileIsEnding(h)) {
      all += FileReadString(h);
      if(!FileIsEnding(h))
         all += "\n";
   }
   FileClose(h);
   return all;
}

void Test_RT23_MultiSegmentOutputs()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt23.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(ticks[i].time_msc), DoubleToString(ticks[i].bid, 5),
                DoubleToString(ticks[i].ask, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "run_rt23.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 2)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt23.csv");
   FileWrite(w, "2,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 2)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt23.csv");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   AssertTrue("RT23 run", Rpl_RunReplayFiles("rt23", false));
   const string dl = Rpl_ReadWholeFile(dir + "out_rt23_deals.csv");
   AssertTrue("RT23 deals nonempty", StringLen(dl) > 0);
   const int hdr_at = StringFind(dl, RPL_DEALS_HEADER);
   AssertTrue("RT23 deals hdr", hdr_at == 0);
   AssertTrue("RT23 one header", StringFind(dl, RPL_DEALS_HEADER, StringLen(RPL_DEALS_HEADER)) < 0);
   const string sum = Rpl_ReadWholeFile(dir + "out_rt23_summary.txt");
   string lines[];
   const int nl = StringSplit(sum, '\n', lines);
   AssertTrue("RT23 summary lines", nl == 2);
   AssertTrue("RT23 sum seg1", StringFind(lines[0], "seg_id=1") == 0);
   AssertTrue("RT23 sum seg2", StringFind(lines[1], "seg_id=2") == 0);
}

void Test_RT24_BreakerGated()
{
   string kinds[1];
   long from_ms[1];
   long to_ms[1];
   kinds[0] = "BREAKER_GATED";
   from_ms[0] = RplMs(RPL_T0, 0);
   to_ms[0] = RplMs(RPL_T0, 1);
   Rpl_ResetAll();
   Rpl_SetTestIntervals(kinds, from_ms, to_ms, 1);
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 1);
   RplTick ticks[1];
   ticks[0].time_msc = RplMs(RPL_T0, 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 1, cfg);
   AssertFalse("RT24 tick0 no L00 ENT", Rpl_OrderExistsForLayer("L", 0, "ENT"));
   Rpl_ResetAll();
   Rpl_SetTestIntervals(kinds, from_ms, to_ms, 1);
   cfg.to_ms = RplMs(RPL_T0, 2);
   RplTick ticks2[2];
   ticks2[0] = ticks[0];
   ticks2[1].time_msc = RplMs(RPL_T0, 1);
   ticks2[1].bid = 1.10000;
   ticks2[1].ask = 1.10002;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks2, 2, cfg);
   double p = 0.0;
   ulong tk = 0;
   AssertTrue("RT24 tick1 L00 ENT", Rpl_FindOrderByRoleLayer("L", 0, "ENT", p, tk));
   AssertNear("RT24 L00 px", p, 1.09981, 1e-9);
}

void Test_RT25_SyncRealFile()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt25.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(RplMs(RPL_T0, i)), "1.09900", "1.09902", "0");
   FileClose(w);
   w = FileOpen(dir + "seed_rt25.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer,entry,open_ms,ticket,vl,swap,volume");
   FileWrite(w, "L,0,1.09981," + IntegerToString(RplMs(RPL_T0, -3 * 3600)) + ",7001,0,0,0.01");
   FileWrite(w, "L,1,1.09911," + IntegerToString(RplMs(RPL_T0, -2 * 3600)) + ",7002,0,0,0.01");
   FileWrite(w, "L,2,1.09841," + IntegerToString(RplMs(RPL_T0, -3600)) + ",7003,0,0,0.01");
   FileClose(w);
   w = FileOpen(dir + "real_rt25.csv", FILE_WRITE | FILE_TXT | FILE_ANSI);
   FileWrite(w, "time_ms,kind,side,layer,price,position_id,level");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 2) - 1) + ",OUT_BY,L,2,1.09841,7003,");
   FileClose(w);
   w = FileOpen(dir + "run_rt25.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt25.csv,ticks_rt25.csv");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   AssertTrue("RT25 run sync", Rpl_RunReplayFiles("rt25", true));
   int h = FileOpen(dir + "out_rt25_book.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   AssertTrue("RT25 book open", h != INVALID_HANDLE);
   for(int k = 0; k < 7; k++)
      FileReadString(h);
   int long_rows = 0;
   while(!FileIsEnding(h)) {
      const string seg = FileReadString(h);
      const string side = FileReadString(h);
      if(side == "L")
         long_rows++;
      for(int k = 0; k < 5; k++)
         FileReadString(h);
   }
   FileClose(h);
   AssertTrue("RT25 two long rows", long_rows == 2);
   AssertTrue("RT25 layer0", StringFind(Rpl_ReadWholeFile(dir + "out_rt25_book.csv"), ",L,0,") >= 0);
   AssertTrue("RT25 layer1", StringFind(Rpl_ReadWholeFile(dir + "out_rt25_book.csv"), ",L,1,") >= 0);
}

void Test_RT26_SyncRemoveSeams()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   cfg.to_ms = RplMs(RPL_T0, 2);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.09981, RplMs(RPL_T0, -3600), 7001UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09911, RplMs(RPL_T0, -1800), 7002UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   string rows[1];
   rows[0] = IntegerToString(RplMs(RPL_T0, 1) - 1) + ",OUT_BY,L,1,1.09911,7002,";
   Rpl_SetSyncRealKindRows(rows, 1);
   RplTick ticks[2];
   for(int i = 0; i < 2; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = 1.09900;
      ticks[i].ask = 1.09902;
   }
   Rpl_RunTicks(ticks, 2, cfg);
   AssertFalse("RT26 no pos 7002", Rpl_HasPosition(7002UL));
   AssertFalse("RT26 pos seam", Rpl_PositionSeamHas(7002UL));
   AssertFalse("RT26 closeby seam", Rpl_CloseBySeamHas(7002UL));
   AssertFalse("RT26 pos meta", Rpl_PosMetaHas(7002UL));
}

void Test_RT27_SummaryCounts()
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
   AssertTrue("RT27 run", Rpl_RunReplayFiles("rt19", false));
   const string sum = Rpl_ReadWholeFile(dir + "out_rt19_summary.txt");
   string lines[];
   StringSplit(sum, '\n', lines);
   AssertTrue("RT27 line1 seg", StringFind(lines[0], "seg_id=1,ticks=") == 0);
   AssertContains("RT27 fills", lines[0], "fills=2,");
   AssertContains("RT27 scalps", lines[0], "scalps=1,");
}

void Test_RT28_CsvReadLine()
{
   int w = FileOpen("replay\\ticks_rt28.csv", FILE_WRITE | FILE_TXT | FILE_ANSI);
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 0)) + ",1.10000,1.10002,6");
   FileClose(w);
   RplTick t28[];
   int n28 = 0;
   AssertFalse("RT28 no header fail", Rpl_LoadTicksCsv("ticks_rt28.csv", t28, n28));
   w = FileOpen("replay\\ticks_rt28b.csv", FILE_WRITE | FILE_TXT | FILE_ANSI);
   FileWrite(w, "time_msc_server,bid,ask,flags");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 0)) + ",1.10000,1.10002,6");
   FileWrite(w, "");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 1)) + ",1.10010,1.10012,2");
   FileClose(w);
   RplTick t28b[];
   int n28b = 0;
   AssertTrue("RT28b load ok", Rpl_LoadTicksCsv("ticks_rt28b.csv", t28b, n28b));
   AssertTrue("RT28b count 2", n28b == 2);
   AssertNear("RT28b tick1 bid", t28b[1].bid, 1.10010, 1e-9);
}

void Test_RT29_BadRunRow()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "run_rt29.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   AssertFalse("RT29 run abort", Rpl_RunReplayFiles("rt29", false));
}

void Test_RT30_MissingSwaps()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "run_rt30.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt19.csv");
   FileClose(w);
   FileDelete("replay\\swaps.csv");
   AssertFalse("RT30 run abort", Rpl_RunReplayFiles("rt30", false));
   AssertFalse("RT30 no deals out", FileIsExist(dir + "out_rt30_deals.csv"));
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
}

void Test_RT31_EmptyTicksFile()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "run_rt31.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,");
   FileClose(w);
   AssertFalse("RT31 run abort", Rpl_RunReplayFiles("rt31", false));
}

void Test_RT31b_TrailingComma()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "run_rt31b.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt19.csv,");
   FileClose(w);
   AssertTrue("RT31b run ok", Rpl_RunReplayFiles("rt31b", false));
   string l31b[];
   AssertTrue("RT31b five lines", StringSplit(Rpl_ReadWholeFile(dir + "out_rt31b_deals.csv"), '\n', l31b) == 5);
}

void Test_RT33_GateInitRestart()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.gate = 0;
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
   AssertTrue("RT33 init restart no roll", Rpl_CountEventsWithCode("ROLL_ACCEPTED") == 0);
}

void Test_RT34_LatticePrune()
{
   Rpl_ResetAll();
   const datetime T = RPL_T0;
   Grind_LatticeTestAddTick(T - 10, 1.10000, 1.10002);
   Grind_LatticeTestAddTick(T - 400, 1.20000, 1.20002);
   Grind_LatticeTestAddTick(T - 300, 1.30000, 1.30002);
   Grind_LatticeTestAddTick(T - 301, 1.40000, 1.40002);
   Rpl_PruneLattice((long)T * 1000);
   const int n = ArraySize(g_grind_vl_test_tick_msc);
   AssertTrue("RT34 size 2", n == 2);
   AssertTrue("RT34 msc0", g_grind_vl_test_tick_msc[0] == RplMs(T, -10));
   AssertTrue("RT34 msc1", g_grind_vl_test_tick_msc[1] == RplMs(T, -300));
   AssertNear("RT34 bid0", g_grind_vl_test_tick_bid[0], 1.10000, 1e-9);
   AssertNear("RT34 bid1", g_grind_vl_test_tick_bid[1], 1.30000, 1e-9);
   AssertNear("RT34 ask0", g_grind_vl_test_tick_ask[0], 1.10002, 1e-9);
   AssertNear("RT34 ask1", g_grind_vl_test_tick_ask[1], 1.30002, 1e-9);
   AssertTrue("RT34 retained", g_rpl_retained_from_ms == RplMs(T, -300));
}

void Test_RT35_TickLoader()
{
   const string path = "replay\\rt35_ticks.csv";
   int w = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   FileWrite(w, "# rt35");
   FileWrite(w, "time_msc_server,bid,ask,flags");
   for(int i = 0; i < 200000; i++) {
      const long ms = 1790812800000L + 500L * i;
      const double bid = 1.10000 + (double)(i % 100) * 0.00001;
      const double ask = bid + 0.00002;
      FileWrite(w, IntegerToString(ms) + "," + DoubleToString(bid, 5) + "," + DoubleToString(ask, 5) + ",6");
   }
   FileClose(w);
   RplTick ticks[];
   int n = 0;
   const uint t0 = GetTickCount();
   const bool ok = Rpl_LoadTicksCsv("rt35_ticks.csv", ticks, n);
   const uint load_ms = GetTickCount() - t0;
   Print("RT35-LOAD-MS|", load_ms);
   AssertTrue("RT35 load ok", ok);
   AssertTrue("RT35 count", n == 200000);
   AssertTrue("RT35 t0 ms", ticks[0].time_msc == 1790812800000L);
   AssertTrue("RT35 tLast ms", ticks[199999].time_msc == 1790912799500L);
   AssertNear("RT35 tLast bid", ticks[199999].bid, 1.10099, 1e-9);
   AssertNear("RT35 tLast ask", ticks[199999].ask, 1.10101, 1e-9);
}

void Test_RT36_OutputSuffix()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt36.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   RplTick ticks[];
   Rpl_FillRT3Ticks(ticks, 4);
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(ticks[i].time_msc), DoubleToString(ticks[i].bid, 5),
                DoubleToString(ticks[i].ask, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "run_rt36.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,,ticks_rt36.csv");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt36.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   Rpl_SetOutputSuffix("_free");
   AssertTrue("RT36 run", Rpl_RunReplayFiles("rt36", false));
   AssertTrue("RT36 deals file", FileIsExist(dir + "out_rt36_free_deals.csv"));
   AssertTrue("RT36 summary file", FileIsExist(dir + "out_rt36_free_summary.txt"));
   Rpl_SetOutputSuffix("");
}

void Test_RT37_PreloadLattice()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.from_ms = RplMs(RPL_T0, 5);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 6201UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   ArrayResize(g_rpl_all_ticks, 3);
   g_rpl_all_tick_count = 3;
   g_rpl_all_ticks[0].time_msc = RplMs(RPL_T0, 0) + 250;
   g_rpl_all_ticks[0].bid = 1.10000;
   g_rpl_all_ticks[0].ask = 1.10002;
   g_rpl_all_ticks[1].time_msc = RplMs(RPL_T0, 2) - 1;
   g_rpl_all_ticks[1].bid = 1.10010;
   g_rpl_all_ticks[1].ask = 1.10012;
   g_rpl_all_ticks[2].time_msc = RplMs(RPL_T0, 2);
   g_rpl_all_ticks[2].bid = 1.10020;
   g_rpl_all_ticks[2].ask = 1.10022;
   Rpl_PreloadLatticeFromTicks(cfg);
   const int n = ArraySize(g_grind_vl_test_tick_msc);
   AssertTrue("RT37 size 3", n == 3);
   AssertTrue("RT37 msc0", g_grind_vl_test_tick_msc[0] == RplMs(RPL_T0, 0));
   AssertTrue("RT37 msc1", g_grind_vl_test_tick_msc[1] == RplMs(RPL_T0, 1));
   AssertTrue("RT37 msc2", g_grind_vl_test_tick_msc[2] == RplMs(RPL_T0, 2));
   AssertNear("RT37 bid0", g_grind_vl_test_tick_bid[0], 1.10000, 1e-9);
   AssertNear("RT37 bid1", g_grind_vl_test_tick_bid[1], 1.10010, 1e-9);
   AssertNear("RT37 bid2", g_grind_vl_test_tick_bid[2], 1.10020, 1e-9);
}

void Test_RT38_LatticeBackfill()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.cap = 2;
   cfg.from_ms = RplMs(RPL_T0, 0);
   cfg.to_ms = RplMs(RPL_T0, 3);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("S", 0, 1.10500, RplMs(RPL_T0, -900), 9101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("S", 1, 1.10570, RplMs(RPL_T0, -600), 9102UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 0, 1.09900, RplMs(RPL_T0, -60), 9103UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   RplTick ticks[903];
   int k = 0;
   for(int off = -900; off <= 2; off++) {
      ticks[k].time_msc = RplMs(RPL_T0, off);
      ticks[k].bid = (off == -300) ? 1.10300 : 1.10000;
      ticks[k].ask = ticks[k].bid + RPL_SPREAD;
      k++;
   }
   Rpl_RunTicks(ticks, 903, cfg);
   AssertFalse("RT38 no abort", Rpl_WasAborted());
   AssertTrue("RT38 short tracking", g_grind_vl_tracking_short);
   AssertNear("RT38 short extreme", g_grind_vl_extreme_short, 1.10300, 1e-9);
   AssertTrue("RT38 one backfill", g_rpl_lattice_backfills == 1);
}

void Test_RT39_SeededRestingExit()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 5101UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedOrder("L", 0, "EXT", 1.10108, 5111UL, ORDER_TYPE_SELL_LIMIT);
   AssertTrue("RT39 exit linked", g_grind_long.layers[0].exit_order_ticket == 5111UL);
   RplTick ticks[4];
   const double bids[4] = {1.10050, 1.10100, 1.10108, 1.10050};
   for(int i = 0; i < 4; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = bids[i];
      ticks[i].ask = bids[i] + RPL_SPREAD;
   }
   Rpl_RunTicks(ticks, 4, cfg);
   AssertDealRow("RT39 ext", 0, DEAL_TYPE_SELL, "EXT", "L", 0, 1.10108, RplMs(RPL_T0, 2));
}

void Test_RT40_SeededAddAndL00()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 3);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("S", 0, 1.10500, RplMs(RPL_T0, -3600), 5201UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedOrder("S", 0, "EXT", 1.10400, 5211UL, ORDER_TYPE_BUY_LIMIT);
   Rpl_SeedOrder("S", 1, "ENT", 1.10570, 5212UL, ORDER_TYPE_SELL_LIMIT);
   Rpl_SeedOrder("L", 0, "ENT", 1.10481, 5213UL, ORDER_TYPE_BUY_LIMIT);
   AssertTrue("RT40 short ext linked", g_grind_short.layers[0].exit_order_ticket == 5211UL);
   AssertTrue("RT40 short add linked", g_grind_short.add_pending_ticket == 5212UL);
   AssertTrue("RT40 long L00 linked", g_grind_long.l0_pending_ticket == 5213UL);
   RplTick ticks[3];
   const double bids[3] = {1.10500, 1.10570, 1.10500};
   for(int i = 0; i < 3; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = bids[i];
      ticks[i].ask = bids[i] + RPL_SPREAD;
   }
   Rpl_RunTicks(ticks, 3, cfg);
   AssertDealRow("RT40 add", 0, DEAL_TYPE_SELL, "ENT", "S", 1, 1.10570, RplMs(RPL_T0, 1));
}

void Test_RT41_SyncExtClosesLayer()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   cfg.to_ms = RplMs(RPL_T0, 6);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("S", 0, 1.10500, RplMs(RPL_T0, -3600), 5301UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   string rows[1];
   rows[0] = IntegerToString(RplMs(RPL_T0, 2) + 300) + ",EXT,S,0,1.10400,5302,";
   Rpl_SetSyncRealKindRows(rows, 1);
   RplTick ticks[6];
   for(int i = 0; i < 6; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = (i == 0) ? 1.10450 : 1.10398;
      ticks[i].ask = ticks[i].bid + RPL_SPREAD;
   }
   Rpl_RunTicks(ticks, 6, cfg);
   int n = 0;
   long ext_ms = 0;
   for(int i = 0; i < Rpl_DealsCount(); i++) {
      RplDealRow row;
      if(!Rpl_GetDealRow(i, row))
         continue;
      if(row.role == "EXT" && row.side == "S" && row.entry_type == DEAL_ENTRY_IN) {
         n++;
         ext_ms = row.time_ms;
      }
   }
   AssertTrue("RT41 one exit", n == 1);
   AssertTrue("RT41 exit at T1", ext_ms == RplMs(RPL_T0, 1));
}

void Test_RT42_OrdersFile()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt42.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   const double bids[4] = {1.10050, 1.10100, 1.10108, 1.10050};
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(RplMs(RPL_T0, i)), DoubleToString(bids[i], 5),
                DoubleToString(bids[i] + RPL_SPREAD, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "seed_rt42.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer,entry,open_ms,ticket,vl,swap,volume");
   FileWrite(w, "L,0,1.10000," + IntegerToString(RplMs(RPL_T0, -3600)) + ",5101,0,0,0.01");
   FileClose(w);
   w = FileOpen(dir + "orders_rt42.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer,role,price,ticket,type");
   FileWrite(w, "L,0,EXT,1.10108,5111,SELL_LIMIT");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt42.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   w = FileOpen(dir + "run_rt42.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file,orders_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt42.csv,ticks_rt42.csv,orders_rt42.csv");
   FileClose(w);
   AssertTrue("RT42 run", Rpl_RunReplayFiles("rt42", false));
   AssertTrue("RT42 kept exit",
              StringFind(Rpl_ReadWholeFile(dir + "out_rt42_deals.csv"), ",EXT,L,0,1.10108") >= 0);
   w = FileOpen(dir + "run_rt42m.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file,orders_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt42.csv,ticks_rt42.csv,orders_none.csv");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt42m.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   AssertFalse("RT42 missing orders", Rpl_RunReplayFiles("rt42m", false));
}

double Rpl_TestTrueBookSwap(const ulong ticket)
{
   for(int i = 0; i < g_rpl_true_book_count; i++) {
      if(g_rpl_true_book[i].ticket == ticket)
         return g_rpl_true_book[i].swap;
   }
   return -999.0;
}

void Test_RT43_SeededAccruedExit()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.to_ms = RplMs(RPL_T0, 4);
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 5401UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedAccrued(5401UL, 0.00008);
   AssertNear("RT43 accrued", Grind_CarryAccruedGet(5401UL), 0.00008, 1e-12);
   RplTick ticks[4];
   const double bids[4] = {1.10050, 1.10100, 1.10108, 1.10050};
   for(int i = 0; i < 4; i++) {
      ticks[i].time_msc = RplMs(RPL_T0, i);
      ticks[i].bid = bids[i];
      ticks[i].ask = bids[i] + RPL_SPREAD;
   }
   Rpl_RunTicks(ticks, 4, cfg);
   AssertDealRow("RT43 ext", 0, DEAL_TYPE_SELL, "EXT", "L", 0, 1.10108, RplMs(RPL_T0, 2));
}

void Test_RT44_SeedField9()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt44.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   const double bids[4] = {1.10050, 1.10100, 1.10108, 1.10050};
   for(int i = 0; i < 4; i++)
      FileWrite(w, IntegerToString(RplMs(RPL_T0, i)), DoubleToString(bids[i], 5),
                DoubleToString(bids[i] + RPL_SPREAD, 5), "0");
   FileClose(w);
   w = FileOpen(dir + "seed_rt44.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued");
   FileWrite(w, "L,0,1.10000," + IntegerToString(RplMs(RPL_T0, -3600)) + ",5401,0,0,0.01,0.00008000");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt44.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   w = FileOpen(dir + "run_rt44.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt44.csv,ticks_rt44.csv");
   FileClose(w);
   AssertTrue("RT44 run", Rpl_RunReplayFiles("rt44", false));
   AssertTrue("RT44 shifted exit",
              StringFind(Rpl_ReadWholeFile(dir + "out_rt44_deals.csv"), ",EXT,L,0,1.10108") >= 0);
}

void Test_RT45_SyncReseedAccrued()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 5401UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedAccrued(5401UL, 0.00008);
   Rpl_SeedLayer("L", 1, 1.09900, RplMs(RPL_T0, -1800), 5402UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedAccrued(5402UL, 0.00008);
   Rpl_RemoveLayerByTicket(g_grind_long, 5401UL);
   Grind_CarryAccruedDelete(5401UL);
   Grind_CarryAccruedSet(5402UL, 0.00011);
   AssertTrue("RT45 removed", ArraySize(g_grind_long.layers) == 1);
   Rpl_SyncResetToTrueBook();
   AssertTrue("RT45 reseeded", ArraySize(g_grind_long.layers) == 2);
   AssertNear("RT45 restored", Grind_CarryAccruedGet(5401UL), 0.00008, 1e-12);
   AssertNear("RT45 held kept", Grind_CarryAccruedGet(5402UL), 0.00011, 1e-12);
}

void Test_RT46_TrueBookSwapRollover()
{
   Rpl_AppendTestSwap("2026.10.07", -8.067, 1.364, 1.0);
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   cfg.from_ms = RplMs(D'2026.10.06 10:00:00', 0);
   cfg.to_ms = RplMs(D'2026.10.07 00:00:00', 0) + 1000;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(D'2026.10.06 09:00:00', 0), 6201UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_TrueBookAdd("L", 1, 1.09900, 6202UL, 0.0, RPL_LOTS_DEFAULT, RplMs(D'2026.10.06 12:00:00', 0), 0.0);
   RplTick ticks[3];
   ticks[0].time_msc = RplMs(D'2026.10.06 10:00:00', 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   ticks[1].time_msc = RplMs(D'2026.10.06 23:59:59', 0);
   ticks[1].bid = 1.10000;
   ticks[1].ask = 1.10002;
   ticks[2].time_msc = RplMs(D'2026.10.07 00:00:00', 0);
   ticks[2].bid = 1.10000;
   ticks[2].ask = 1.10002;
   Rpl_RunTicks(ticks, 3, cfg);
   AssertNear("RT46 held swap", Rpl_GetPositionSwap(6201UL), -0.08067, 1e-9);
   AssertNear("RT46 true seeded", Rpl_TestTrueBookSwap(6201UL), -0.08067, 1e-9);
   AssertNear("RT46 true only", Rpl_TestTrueBookSwap(6202UL), -0.08067, 1e-9);
}

void Test_RT47_SyncReseedLatestAccrued()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 5701UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedAccrued(5701UL, 0.00008);
   Grind_CarryAccruedSet(5701UL, 0.00011);
   Rpl_SyncResetToTrueBook();
   AssertNear("RT47 held", Grind_CarryAccruedGet(5701UL), 0.00011, 1e-12);
   Rpl_RemoveLayerByTicket(g_grind_long, 5701UL);
   Grind_CarryAccruedDelete(5701UL);
   Rpl_SyncResetToTrueBook();
   AssertTrue("RT47 reseeded", ArraySize(g_grind_long.layers) == 1);
   AssertNear("RT47 latest", Grind_CarryAccruedGet(5701UL), 0.00011, 1e-12);
}

void Test_RT50_SyncResetLeavesHeldVl()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.sync = true;
   Rpl_ConfigureEngine(cfg);
   Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0, -3600), 6301UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   Rpl_SeedLayer("L", 1, 1.09930, RplMs(RPL_T0, -1800), 6302UL, 0.0, 0.0, RPL_LOTS_DEFAULT);
   for(int i = 0; i < g_rpl_true_book_count; i++) {
      if(g_rpl_true_book[i].ticket == 6301UL)
         g_rpl_true_book[i].vl = 1.09500;
   }
   Grind_VLSet(6302UL, 1.09400);
   Rpl_SyncResetToTrueBook();
   AssertTrue("RT50 held not marked", !Grind_VLHas(6301UL));
   AssertNear("RT50 own roll kept", Grind_VLGet(6302UL), 1.09400, 1e-9);
   Rpl_RemoveLayerByTicket(g_grind_long, 6301UL);
   Rpl_SyncResetToTrueBook();
   AssertTrue("RT50 reseeded", ArraySize(g_grind_long.layers) == 2);
   AssertNear("RT50 reseed takes true vl", Grind_VLGet(6301UL), 1.09500, 1e-9);
}

void Test_RT51_ExactTouchBuyLimit()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt51.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 0)), "1.12550", "1.12552", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 1)), "1.12505", "1.12505", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 2)), "1.12520", "1.12522", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 3)), "1.12520", "1.12522", "0");
   FileClose(w);
   w = FileOpen(dir + "seed_rt51.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued");
   FileWrite(w, "S,0,1.12605," + IntegerToString(RplMs(RPL_T0, -3600)) + ",6401,0,0,0.01,0");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt51.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   w = FileOpen(dir + "run_rt51.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt51.csv,ticks_rt51.csv");
   FileClose(w);
   AssertTrue("RT51 run", Rpl_RunReplayFiles("rt51", false));
   AssertTrue("RT51 exact touch fills",
              StringFind(Rpl_ReadWholeFile(dir + "out_rt51_deals.csv"), ",EXT,S,0,1.12505") >= 0);
}

void Test_RT52_ExactTouchSellLimit()
{
   const string dir = "replay\\";
   int w = FileOpen(dir + "ticks_rt52.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "time_msc_server", "bid", "ask", "flags");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 0)), "1.12390", "1.12392", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 1)), "1.12434", "1.12434", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 2)), "1.12410", "1.12412", "0");
   FileWrite(w, IntegerToString(RplMs(RPL_T0, 3)), "1.12410", "1.12412", "0");
   FileClose(w);
   w = FileOpen(dir + "seed_rt52.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued");
   FileWrite(w, "L,0,1.12334," + IntegerToString(RplMs(RPL_T0, -3600)) + ",6501,0,0,0.01,0");
   FileClose(w);
   w = FileOpen(dir + "swaps.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "server_date,points_long,points_short,mult");
   FileWrite(w, "2026.10.06,-8.111,1.409,1");
   FileClose(w);
   w = FileOpen(dir + "intervals_rt52.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "kind,from_ms,to_ms");
   FileClose(w);
   w = FileOpen(dir + "run_rt52.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   FileWrite(w, "seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file");
   FileWrite(w, "1,GRIND_TEST,22260201," + IntegerToString(RplMs(RPL_T0, 0)) + "," +
             IntegerToString(RplMs(RPL_T0, 4)) + ",2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt52.csv,ticks_rt52.csv");
   FileClose(w);
   AssertTrue("RT52 run", Rpl_RunReplayFiles("rt52", false));
   AssertTrue("RT52 exact touch fills",
              StringFind(Rpl_ReadWholeFile(dir + "out_rt52_deals.csv"), ",EXT,L,0,1.12434") >= 0);
}

void Test_RT21_GapReport()
{
   Rpl_ResetAll();
   RplSegmentConfig cfg;
   Rpl_DefaultConfig(cfg);
   cfg.from_ms = RplMs(D'2026.10.06 10:00:00', 0);
   cfg.to_ms = RplMs(D'2026.10.06 10:02:00', 0) + 1000;
   RplTick ticks[3];
   ticks[0].time_msc = RplMs(D'2026.10.06 10:00:00', 0);
   ticks[0].bid = 1.10000;
   ticks[0].ask = 1.10002;
   ticks[1].time_msc = RplMs(D'2026.10.06 10:00:30', 0);
   ticks[1].bid = 1.10000;
   ticks[1].ask = 1.10002;
   ticks[2].time_msc = RplMs(D'2026.10.06 10:02:00', 0);
   ticks[2].bid = 1.10000;
   ticks[2].ask = 1.10002;
   Rpl_ConfigureEngine(cfg);
   Rpl_RunTicks(ticks, 3, cfg);
   AssertTrue("RT21 one gap", Rpl_GapReportCount() == 1);
   long from_ms = 0;
   long secs = 0;
   AssertTrue("RT21 gap row", Rpl_GapReportAt(0, from_ms, secs));
   AssertTrue("RT21 gap from", from_ms == RplMs(D'2026.10.06 10:00:30', 0));
   AssertTrue("RT21 gap 90s", secs == 90);
   Rpl_ResetAll();
   RplSegmentConfig cfg2;
   Rpl_DefaultConfig(cfg2);
   cfg2.from_ms = RplMs(D'2026.10.06 23:55:00', 0);
   cfg2.to_ms = RplMs(D'2026.10.06 23:57:00', 0) + 1000;
   RplTick ticks2[2];
   ticks2[0].time_msc = RplMs(D'2026.10.06 23:55:00', 0);
   ticks2[0].bid = 1.10000;
   ticks2[0].ask = 1.10002;
   ticks2[1].time_msc = RplMs(D'2026.10.06 23:57:00', 0);
   ticks2[1].bid = 1.10000;
   ticks2[1].ask = 1.10002;
   Rpl_ConfigureEngine(cfg2);
   Rpl_RunTicks(ticks2, 2, cfg2);
   AssertTrue("RT21 window gap not reported", Rpl_GapReportCount() == 0);
}

void OnStart()
{
   Print("RPL|MIRRORS_EA|", RPL_MIRRORS_EA);
   if(!Rpl_WaitSymbolReady(60000)) {
      Print("RPL|SUMMARY|run=0|pass=0");
      return;
   }
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
   Test_RT22_CsvHeaderLine();
   Test_RT23_MultiSegmentOutputs();
   Test_RT24_BreakerGated();
   Test_RT25_SyncRealFile();
   Test_RT26_SyncRemoveSeams();
   Test_RT27_SummaryCounts();
   Test_RT28_CsvReadLine();
   Test_RT29_BadRunRow();
   Test_RT30_MissingSwaps();
   Test_RT31_EmptyTicksFile();
   Test_RT31b_TrailingComma();
   Test_RT33_GateInitRestart();
   Test_RT34_LatticePrune();
   Test_RT35_TickLoader();
   Test_RT36_OutputSuffix();
   Test_RT37_PreloadLattice();
   Test_RT38_LatticeBackfill();
   Test_RT39_SeededRestingExit();
   Test_RT40_SeededAddAndL00();
   Test_RT41_SyncExtClosesLayer();
   Test_RT42_OrdersFile();
   Test_RT43_SeededAccruedExit();
   Test_RT44_SeedField9();
   Test_RT45_SyncReseedAccrued();
   Test_RT46_TrueBookSwapRollover();
   Test_RT47_SyncReseedLatestAccrued();
   Test_RT48_OrderLogDiff();
   Test_RT49_OrderLogEngineExit();
   Test_RT50_SyncResetLeavesHeldVl();
   Test_RT51_ExactTouchBuyLimit();
   Test_RT52_ExactTouchSellLimit();
   Print("RPL|SUMMARY|run=", g_tests_run, "|pass=", g_tests_passed);
}
