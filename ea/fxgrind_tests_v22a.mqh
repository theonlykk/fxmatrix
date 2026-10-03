//+------------------------------------------------------------------+
//| fxgrind_tests_v22a.mqh — v2.2a C93 recon scan + C100 API limits  |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_V22A_MQH
#define FXGRIND_TESTS_V22A_MQH

const ulong V22A_MAGIC = 22260101UL;

//+------------------------------------------------------------------+
void Test_RS1_AppendUnique()
{
   GrindReconTicket t[];
   int n = 0;
   int d = 0;
   const string comment_a = GrindCommentBuild("OPT", "L", 1, "ENT");
   n = Grind_ReconAppendUnique(t, n, 9001UL, V22A_MAGIC, comment_a, 0.85774,
                               GRIND_RECON_TICKET_ORDER, d);
   AssertEqInt("RS1a (G)", n, 1);
   n = Grind_ReconAppendUnique(t, n, 9001UL, V22A_MAGIC, comment_a, 0.85774,
                               GRIND_RECON_TICKET_ORDER, d);
   AssertEqInt("RS1b (F)", n, 1);
   n = Grind_ReconAppendUnique(t, n, 9001UL, V22A_MAGIC,
                               GrindCommentBuild("OPT", "L", 0, "ENT"), 0.85900,
                               GRIND_RECON_TICKET_POSITION, d);
   AssertEqInt("RS1c (F)", n, 2);
   n = Grind_ReconAppendUnique(t, n, 9002UL, V22A_MAGIC,
                               GrindCommentBuild("OPT", "S", 1, "ENT"), 0.85600,
                               GRIND_RECON_TICKET_ORDER, d);
   AssertEqInt("RS1d (F)", n, 3);
   AssertEqInt("RS1e (F)", d, 1);
   AssertTrue("RS1f (F)",
              t[2].ticket == 9002UL && t[2].kind == GRIND_RECON_TICKET_ORDER);
   AssertTrue("RS1g (G)",
              t[0].ticket == 9001UL && t[0].magic == V22A_MAGIC &&
              t[0].comment == comment_a && t[0].price == 0.85774 &&
              t[0].kind == GRIND_RECON_TICKET_ORDER);
}

//+------------------------------------------------------------------+
void Test_RS2_C93Replay()
{
   const string n1_comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   GrindReconTicket raw[];
   int raw_count = 0;
   Grind_TestAppendReconTicket(raw, raw_count, V22A_MAGIC, 9001UL,
                               GRIND_RECON_TICKET_ORDER, n1_comment, 0.85774);
   Grind_TestAppendReconTicket(raw, raw_count, V22A_MAGIC, 9001UL,
                               GRIND_RECON_TICKET_ORDER, n1_comment, 0.85774);
   GrindSideState lo;
   GrindSideState so;
   string reason = "";
   AssertFalse("RS2a (G)",
               Grind_RebuildBookFromTickets(raw, 2, V22A_MAGIC, "OPT",
                                            3.0, 12, 0.00001,
                                            lo, so, reason));
   AssertEqStr("RS2b (G)", reason, "AMBIGUOUS_ADD_LONG");
   Grind_ReconFailureClear();
   Grind_TestResetSideState();

   GrindReconTicket dd[];
   int dd_count = 0;
   int dupes = 0;
   dd_count = Grind_ReconAppendUnique(dd, dd_count, 9001UL, V22A_MAGIC, n1_comment,
                                      0.85774, GRIND_RECON_TICKET_ORDER, dupes);
   dd_count = Grind_ReconAppendUnique(dd, dd_count, 9001UL, V22A_MAGIC, n1_comment,
                                      0.85774, GRIND_RECON_TICKET_ORDER, dupes);
   GrindSideState lo2;
   GrindSideState so2;
   string reason2 = "";
   AssertTrue("RS2c (F)",
              Grind_RebuildBookFromTickets(dd, dd_count, V22A_MAGIC, "OPT",
                                           3.0, 12, 0.00001,
                                           lo2, so2, reason2));
   AssertEqStr("RS2d (F)", reason2, "");
   Grind_ReconFailureClear();
   Grind_TestResetSideState();
}

//+------------------------------------------------------------------+
void Test_RS3_ScanStable()
{
   AssertTrue("RS3a (G)", Grind_ReconScanStable(5, 10, 5, 10));
   AssertFalse("RS3b (F)", Grind_ReconScanStable(5, 10, 5, 9));
   AssertFalse("RS3c (F)", Grind_ReconScanStable(5, 10, 6, 10));
   AssertFalse("RS3d (F)", Grind_ReconScanStable(5, 10, 6, 9));
   AssertTrue("RS3e (G)", Grind_ReconScanStable(0, 0, 0, 0));
}

//+------------------------------------------------------------------+
void Test_RS4_TicketsLogLine()
{
   GrindReconTicket t[2];
   t[0].ticket = 1001UL;
   t[0].kind = GRIND_RECON_TICKET_POSITION;
   t[0].comment = "";
   t[0].price = 0.0;
   t[0].magic = V22A_MAGIC;
   t[1].ticket = 9001UL;
   t[1].kind = GRIND_RECON_TICKET_ORDER;
   t[1].comment = "";
   t[1].price = 0.0;
   t[1].magic = V22A_MAGIC;
   AssertEqStr("RS4a (F)",
               Grind_ReconTicketsLogLine("I3_LONG_NAKED", t, 2),
               "RECON_TICKETS reason=I3_LONG_NAKED n=2 P:1001 O:9001");
   GrindReconTicket empty[];
   AssertEqStr("RS4b (F)",
               Grind_ReconTicketsLogLine("X", empty, 0),
               "RECON_TICKETS reason=X n=0");
   GrindReconTicket f6[];
   int f6_count = 0;
   Grind_TestAppendReconTicket(f6, f6_count, V22A_MAGIC, 1001UL,
                               GRIND_RECON_TICKET_POSITION,
                               GrindCommentBuild("OPT", "L", 0, "ENT"), 1.25000);
   for(int i = 0; i < 40; i++) {
      Grind_TestAppendReconTicket(f6, f6_count, V22A_MAGIC,
                                  9000UL + (ulong)i,
                                  GRIND_RECON_TICKET_ORDER,
                                  GrindCommentBuild("OPT", "S", i, "ENT"),
                                  1.24000 - i * 0.00010);
   }
   const string line_l = Grind_ReconTicketsLogLine("I3_LONG_NAKED", f6, f6_count);
   AssertTrue("RS4c (F)", StringFind(line_l, "O:9038 +1 more") >= 0);
   AssertTrue("RS4d (G)", StringFind(line_l, "O:9039") < 0);
}

//+------------------------------------------------------------------+
void Test_RS5_CaptureLogsLocally()
{
   Grind_ReconFailureClear();
   const ulong secret_ticket = 87654321UL;
   GrindReconTicket tickets[1];
   tickets[0].ticket = secret_ticket;
   tickets[0].magic = V22A_MAGIC;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("RS5a (G)",
               Grind_RebuildBookFromTickets(tickets, 1, V22A_MAGIC, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertEqStr("RS5b (F)", g_grind_recon_tickets_last_line,
               "RECON_TICKETS reason=I3_LONG_NAKED n=1 P:87654321");
   AssertTrue("RS5c (G)", StringFind(g_grind_recon_failure_json, "87654321") < 0);
   AssertTrue("RS5d (G)", StringFind(Grind_TestSampleHeartbeatJson(), "87654321") < 0);
   Grind_ReconFailureClear();
   AssertEqStr("RS5e (G)", g_grind_recon_tickets_last_line, "");
   Grind_TestResetSideState();
}

//+------------------------------------------------------------------+
void Test_RS6_RaceNoteHelpers()
{
   AssertEqStr("RS6a (F)", Grind_ReconScanDetail(1, 2, true),
               "{\"dupes\":1,\"walks\":2,\"stable\":true}");
   AssertEqStr("RS6b (F)", Grind_ReconScanDetail(0, 3, false),
               "{\"dupes\":0,\"walks\":3,\"stable\":false}");
   AssertFalse("RS6c (G)", Grind_ReconScanRaced(0, 1));
   AssertTrue("RS6d (F)", Grind_ReconScanRaced(1, 1));
   AssertTrue("RS6e (F)", Grind_ReconScanRaced(0, 2));
}

//+------------------------------------------------------------------+
void Test_AL1_ValidateApiLimitInputs()
{
   Grind_ApiCounterTestReset();
   AssertTrue("AL1a (G)", Grind_ValidateApiLimitInputs(1000000, 999000));
   AssertTrue("AL1b (G)", Grind_ValidateApiLimitInputs(1900, 1800));
   AssertTrue("AL1c (G)", Grind_ValidateApiLimitInputs(1900, 1900));
   AssertFalse("AL1d (F)", Grind_ValidateApiLimitInputs(1800, 1900));
   AssertFalse("AL1e (F)", Grind_ValidateApiLimitInputs(0, 0));
   AssertFalse("AL1f (F)", Grind_ValidateApiLimitInputs(1900, 0));
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void Test_AL2_EntryStopAtLimit()
{
   Grind_ApiCounterTestReset();
   Grind_ApiLimitsSet(1900, 1800);
   AssertEqInt("AL2a (F)", g_grind_api_entry_stop, 1900);
   Grind_ApiCounterTestSeed(1899);
   AssertFalse("AL2b (G)", Grind_ApiCounterEntryStopped());
   Grind_ApiCounterTestSeed(1900);
   AssertTrue("AL2c (F)", Grind_ApiCounterEntryStopped());
   Grind_ApiCounterTestSeed(1000000);
   AssertTrue("AL2d (G)", Grind_ApiCounterEntryStopped());
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void Test_AL3_SoftWarnAtLimit()
{
   Grind_ApiCounterTestReset();
   Grind_ApiLimitsSet(1900, 1800);
   Grind_ApiCounterTestSeed(1799);
   AssertFalse("AL3a (G)", Grind_ApiCounterSoftWarnActive());
   Grind_ApiCounterTestSeed(1800);
   AssertTrue("AL3b (F)", Grind_ApiCounterSoftWarnActive());
   AssertEqInt("AL3c (F)", g_grind_api_soft_warn, 1800);
   Grind_ApiCounterTestSeed(999000);
   AssertTrue("AL3d (G)", Grind_ApiCounterSoftWarnActive());
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void Test_AL4_TestResetRestoresDefaults()
{
   Grind_ApiCounterTestReset();
   Grind_ApiLimitsSet(1900, 1800);
   Grind_ApiCounterTestReset();
   AssertEqInt("AL4a (G)", g_grind_api_entry_stop, GRIND_DAILY_API_ENTRY_STOP);
   AssertEqInt("AL4b (G)", g_grind_api_soft_warn, GRIND_DAILY_API_SOFT_WARN);
   Grind_ApiCounterTestSeed(1900);
   AssertFalse("AL4c (G)", Grind_ApiCounterEntryStopped());
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void Test_AL5_DefaultsAreToday()
{
   Grind_ApiCounterTestReset();
   AssertEqInt("AL5a (G)", g_grind_api_entry_stop, 1000000);
   AssertEqInt("AL5b (G)", g_grind_api_soft_warn, 999000);
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void Test_AL6_InvalidInputsKeepDefines()
{
   Grind_ApiCounterTestReset();
   AssertTrue("AL6a (G)", Grind_ApiLimitsApplyInputs(1900, 1800));
   AssertEqInt("AL6b (F)", g_grind_api_entry_stop, 1900);
   AssertEqInt("AL6c (F)", g_grind_api_soft_warn, 1800);
   AssertFalse("AL6d (F)", Grind_ApiLimitsApplyInputs(1800, 1900));
   AssertTrue("AL6e (G)",
              g_grind_api_entry_stop == GRIND_DAILY_API_ENTRY_STOP &&
              g_grind_api_soft_warn == GRIND_DAILY_API_SOFT_WARN);
   AssertFalse("AL6f (F)", Grind_ApiLimitsApplyInputs(0, 0));
   Grind_ApiCounterTestReset();
}

//+------------------------------------------------------------------+
void V22A_DeleteApiLimitGvs()
{
   if(GlobalVariableCheck(GRIND_API_LIMIT_STOP_GV))
      GlobalVariableDel(GRIND_API_LIMIT_STOP_GV);
   if(GlobalVariableCheck(GRIND_API_LIMIT_SOFT_GV))
      GlobalVariableDel(GRIND_API_LIMIT_SOFT_GV);
}

//+------------------------------------------------------------------+
void Test_AL7_PublishAndCheck()
{
   Grind_ApiCounterTestReset();
   V22A_DeleteApiLimitGvs();
   Grind_ApiLimitsSet(1900, 1800);
   AssertFalse("AL7a (G)", Grind_ApiLimitsPublishAndCheck());
   AssertTrue("AL7b (F)",
              GlobalVariableCheck(GRIND_API_LIMIT_STOP_GV) &&
              (int)GlobalVariableGet(GRIND_API_LIMIT_STOP_GV) == 1900);
   AssertTrue("AL7c (F)",
              GlobalVariableCheck(GRIND_API_LIMIT_SOFT_GV) &&
              (int)GlobalVariableGet(GRIND_API_LIMIT_SOFT_GV) == 1800);
   Grind_ApiLimitsSet(2000, 1800);
   AssertTrue("AL7d (F)", Grind_ApiLimitsPublishAndCheck());
   AssertEqInt("AL7e (F)", (int)GlobalVariableGet(GRIND_API_LIMIT_STOP_GV), 2000);
   AssertFalse("AL7f (G)", Grind_ApiLimitsPublishAndCheck());
   V22A_DeleteApiLimitGvs();
   Grind_ApiCounterTestReset();
}

#endif // FXGRIND_TESTS_V22A_MQH
