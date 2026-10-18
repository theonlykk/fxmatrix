This message has a line count at the bottom

# REVIEW OF `docs/runbooks/twoarm-build-e.md` AT `81f7d70`

Reviewed against commit `81f7d70` on `main` (`fxmatrix`, EA source unchanged since `5bb5fdb`). Every passage cited below is accompanied by its file path, line numbers, and exact verbatim quoted text at `81f7d70`.

---

## 1. VERIFIED BASELINE FACTS AT `81f7d70`

1. **EA source tree (`s1.5`, `s1.9`):** `git diff --stat 5bb5fdb 81f7d70 -- 'ea/*.mq5' 'ea/*.mqh'` is empty (`0` files changed), and `ea/*.mq5` plus `ea/*.mqh` totals `79` files, matching `docs/runbooks/twoarm-build-e.md:75-77` and `docs/runbooks/twoarm-build-e.md:109-113`:

```75:77:docs/runbooks/twoarm-build-e.md
**1.5 The repo** (expected: the commit of `main`, e.g. `ceab0f7`, and an EMPTY diff line):

    sudo -u khalid git clone -q https://github.com/theonlykk/fxmatrix /home/khalid/fxmatrix-repo && sudo -u khalid git -C /home/khalid/fxmatrix-repo log --oneline -1 | cut -c1-10 && sudo -u khalid git -C /home/khalid/fxmatrix-repo diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh'
```

```109:113:docs/runbooks/twoarm-build-e.md
**1.9 The EA into Experts ONLY, then compile.** Experts only, so no chart can ever load a Scripts copy (C88).
As root by ssh (expected `cmp ok=79 bad=0`, the count of `ea/*.mq5` + `ea/*.mqh` at `ceab0f7`; Claude
re-counts on the day):

    R=/home/khalid/fxmatrix-repo; M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; sudo -u khalid mkdir -p "$M/Experts/fxmatrix" && sudo -u khalid cp $R/ea/*.mq5 $R/ea/*.mqh "$M/Experts/fxmatrix/" && ok=0; bad=0; for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "$M/Experts/fxmatrix/$(basename "$f")"; then ok=$((ok+1)); else bad=$((bad+1)); fi; done; echo "cmp ok=$ok bad=$bad"
```

2. **Fleet E presets (`s0`, `s1.10`, `s11`):** All `12` files `ea/presets_e/*_t1.set` exist, have blank `TelemetryAPIKey=`, match every cell of the geometry table in `docs/runbooks/twoarm-build-e.md:31-44`, and produce the exact combined sha256 fingerprint `a448f4abb8a6` (`docs/runbooks/twoarm-build-e.md:9`, `docs/runbooks/twoarm-build-e.md:119-122`, `docs/runbooks/twoarm-build-e.md:256`):

```9:9:docs/runbooks/twoarm-build-e.md
| Uses | `main` `ceab0f7` or later: `ea/presets_e/<pair>_{opt,alt}_e_t1.set` (12 files, fingerprint `a448f4abb8a6`); `scripts/build_logcheck.awk`; pipshed `twoarm-fleets` `320afe6` (merged at D's s7) and a small pipshed patch for E's card (s9) |
```

```31:44:docs/runbooks/twoarm-build-e.md
| Chart | Magic | Instance | `geo=` (L w/a/e S w/a/e) | Stranded | Warning starts |
|---|---|---|---|---|---|
| GBPUSD OPT (pilot) | 22260101 | `GRIND_GBPUSD_OPTE` | L2.5/9/9 S2.5/9/9 | 3.5 | `FLEET E two-arm t1 GBPUSD OPT -` |
| EURUSD OPT | 22260201 | `GRIND_EURUSD_OPTE` | L2/7/7 S2/7/7 | 3.0 | `... EURUSD OPT -` |
| EURGBP OPT | 22260301 | `GRIND_EURGBP_OPTE` | L1/3/3 S1/3/3 | 2.0 | `... EURGBP OPT -` |
| AUDCAD OPT | 22260401 | `GRIND_AUDCAD_OPTE` | L1.5/6/6 S1.5/6/6 | 2.5 | `... AUDCAD OPT -` |
| AUDCHF OPT | 22260501 | `GRIND_AUDCHF_OPTE` | L1/4/4 S1/4/4 | 2.0 | `... AUDCHF OPT -` |
| CADCHF OPT | 22260601 | `GRIND_CADCHF_OPTE` | L1/4/4 S1/4/4 | 2.0 | `... CADCHF OPT -` |
| GBPUSD ALT | 22260102 | `GRIND_GBPUSD_ALTE` | L6/24/24 S6/24/24 | 7.0 | `... GBPUSD ALT q90` |
| EURUSD ALT | 22260202 | `GRIND_EURUSD_ALTE` | L6/23/23 S6/23/23 | 7.0 | `... EURUSD ALT q90` |
| EURGBP ALT | 22260302 | `GRIND_EURGBP_ALTE` | L4/16/16 S4/16/16 | 5.0 | `... EURGBP ALT q90` |
| AUDCAD ALT | 22260402 | `GRIND_AUDCAD_ALTE` | L7/27/27 S7/27/27 | 8.0 | `... AUDCAD ALT q90` |
| AUDCHF ALT | 22260502 | `GRIND_AUDCHF_ALTE` | L5.5/21/21 S5.5/21/21 | 6.5 | `... AUDCHF ALT q90` |
| CADCHF ALT | 22260602 | `GRIND_CADCHF_ALTE` | L2.5/9/9 S2.5/9/9 | 3.5 | `... CADCHF ALT q90` |
```

```119:122:docs/runbooks/twoarm-build-e.md
**1.10 Stage E's presets with the key** (as D's s2.3-2.4; expected `a448f4abb8a6`, `12`, then 12 lines
`SAME_EXCEPT_KEY key_len=43`):

    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_e/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_e/*_t1.set | wc -l)
```

3. **E's twelve magics (`E3`):** `22260101` through `22260602` are all in `GRIND_CAP_ALL_MAGICS` (`ea/grind_cap.mqh:18-31`):

```18:31:ea/grind_cap.mqh
const ulong GRIND_CAP_ALL_MAGICS[18] =
{
   22260101UL, 22260102UL,
   22260201UL, 22260202UL,
   22260301UL, 22260302UL,
   22260401UL, 22260402UL,
   22260501UL, 22260502UL,
   22260601UL, 22260602UL,
   22260801UL, 22260802UL,
   22260901UL, 22260902UL,
   22260701UL, 22260702UL
};

#define GRIND_CAP_MAGIC_COUNT 18
```

---

## 2. ANSWERS TO `s12` QUESTIONS (`GE-1` TO `GE-8`)

### GE-1: `MQL5/Experts/fxmatrix` Only (`s1.9`), No `Scripts/fxmatrix` Copy

Runbook question (`docs/runbooks/twoarm-build-e.md:266-267`):

```266:267:docs/runbooks/twoarm-build-e.md
- **GE-1.** The EA in Experts only (s1.9), no Scripts copy: anything in the build, the suite or the scripts
  we run on a box (tick and history dumps, GV tools) that needs `Scripts\fxmatrix`?
```

**Answer: Nothing in the EA build (`fxgrind.mq5`), the test suite (`fxgrind_tests.mq5`), or the standalone box scripts (`scripts/grind_*.mq5`) needs `Scripts\fxmatrix`, but `s1.9` does not copy `scripts/grind_*.mq5` to `MQL5/Scripts` and `s6` omits the Navigator subtree for `fxgrind_tests`:**

1. **`fxgrind.mq5` and `fxgrind_tests.mq5` compile and run cleanly from `MQL5/Experts/fxmatrix`:**
   - Both `ea/fxgrind.mq5:9-12` and `ea/fxgrind_tests.mq5:8-18` use relative `#include "..."` directives for headers in the same folder:

```9:12:ea/fxgrind.mq5
#include "grind_engine.mqh"
#include "grind_snapshot.mqh"
#include "grind_magic_lock.mqh"
#include "grind_config.mqh"
```

```8:18:ea/fxgrind_tests.mq5
#property script_show_inputs
#property strict

#include "grind_comment.mqh"
#include "grind_archive.mqh"
#include "grind_archive_flush.mqh"
#include "grind_engine.mqh"
#include "grind_snapshot.mqh"
#include "grind_pnl.mqh"
#include "grind_magic_lock.mqh"
#include "grind_config.mqh"
```

   - Because `ea/fxgrind_tests.mq5:8778-8781` defines `void OnStart()`, MT5 runs it as a one-shot script even when compiled inside `MQL5\Experts\fxmatrix\`, and omitting `MQL5\Scripts\fxmatrix\fxgrind.ex5` prevents the `C88` wrong-subtree attach (`handoffs/Handover/02_TRAPS.md:1254-1259`):

```1254:1259:handoffs/Handover/02_TRAPS.md
- **Compile ONE file in MetaEditor.** `Scripts/fxmatrix` holds copies of
  the whole EA; compiling the folder builds them there (harmless: live
  EAs run `Experts/fxmatrix/fxgrind.ex5`). **CORRECTED 1 Oct: WRONG for
  wine-c, whose charts load `Scripts\fxmatrix\fxgrind.ex5`: that 30 Sep
  15:22 compile rebuilt the live EAs' binary (same source, so no harm).** Check that file's date and
  the log for `deinit` if unsure; never RUN `fxgrind_tests` on a live box.
```

2. **Missing fact in `s1.9`: the standalone box scripts (`scripts/grind_*.mq5`) live in `$R/scripts/`, not `$R/ea/`, so none of them is installed on `wine-e`:**
   - The operator scripts (`grind_tick_dump.mq5`, `grind_bidask_dump.mq5`, `grind_bar_dump.mq5`, `grind_history_dump.mq5`, `grind_gv_list.mq5`, `grind_gv_delete_exact.mq5`, `grind_gv_clean.mq5`, `grind_eject.mq5`, `grind_limit_probe.mq5`) live in `/home/khalid/fxmatrix-repo/scripts/` and none of them `#include`s any `ea/grind_*.mqh` header.
   - Because `s1.9` (`docs/runbooks/twoarm-build-e.md:109-113`) only copies `$R/ea/*.mq5 $R/ea/*.mqh` into `$M/Experts/fxmatrix/`, `MQL5/Scripts` on `wine-e` lacks all 9 operator scripts (the same trap hit on `wine-d` in `handoffs/Handover/02_TRAPS.md:1703-1707`):

```1703:1707:handoffs/Handover/02_TRAPS.md
- **wine-d's `Scripts/fxmatrix` lacks the research scripts** (its repo is
  on `hotfix-api-stop`). Install one without changing the branch:
  `sudo -u khalid git -C /home/khalid/fxmatrix-repo fetch -q origin`, then
  `git show origin/main:scripts/<file>` into the Scripts folder with
  `install -o khalid -g khalid -m 664`; check the sha; compile ONE file.
```

   - Copying `sudo -u khalid cp $R/scripts/grind_*.mq5 "$M/Scripts/"` in `s1.9` installs the dump, GV, and eject scripts into `MQL5/Scripts` without placing any `ea/*` file under `Scripts`.
3. **Navigator path in `s6` (`docs/runbooks/twoarm-build-e.md:186-191`):**

```186:191:docs/runbooks/twoarm-build-e.md
## 6. THE SUITE, ONCE, BEFORE ANY EA (Algo OFF)

On a GBPUSD chart (M5): drag `fxgrind_tests` from the Navigator; it places no order (06 s7 step 5).
Expected `SUMMARY` 2597 / 2597 (the EA suite at `5bb5fdb`, BOOT s6), then close that chart; F3 (Global
Variables): EMPTY. **Never run it again on wine-e once an EA is attached** (it deletes shared GVs by prefix:
02_TRAPS 25 Sep, C52). A different total: STOP, tell Claude.
```

   - Because `fxgrind_tests.mq5` is compiled in `MQL5\Experts\fxmatrix\`, in the Navigator it sits under **`Navigator -> Expert Advisors -> fxmatrix -> fxgrind_tests`** (not `Navigator -> Scripts`), and `#property script_show_inputs` (`ea/fxgrind_tests.mq5:8`) opens an inputs dialog where the operator clicks **OK**.

---

### GE-2: Running `fxgrind_tests` Once on the New FTMO Account Before Any EA (`s6`)

Runbook question (`docs/runbooks/twoarm-build-e.md:268-269`):

```268:269:docs/runbooks/twoarm-build-e.md
- **GE-2.** The suite once on the new FTMO account before any EA (s6): can it place a request, start the
  trial's clock, or leave state an EA reads (GVs, files in `MQL5\Files`)?
```

**Answer: No, provided `OnStart()` completes (`SUMMARY: 2597/2597 passed`) and `F3` confirms `Global Variables` is empty:**

1. **Zero broker requests and cannot start FTMO's 14-day trial clock:**
   - The only `OrderSend` call in the `fxgrind` codebase is `Grind_OrderSendCounted` (`ea/grind_api_counter.mqh:190-195`):

```190:195:ea/grind_api_counter.mqh
bool Grind_OrderSendCounted(MqlTradeRequest &request, MqlTradeResult &result)
{
   const ulong t0 = GetTickCount64();
   const bool ok = OrderSend(request, result);
   const long duration_ms = (long)(GetTickCount64() - t0);
   Grind_ApiCounterIncrement();
```

   - `Grind_OrderSendCounted` is only called from `Grind_OrderEngineSend` (`ea/grind_engine.mqh:268-274`) and `Grind_CloseBySend` (`ea/grind_closeby.mqh:126-140`), both of which intercept every call when unit-test hooks (`g_grind_order_test_active` / `g_grind_closeby_test_active`) are active:

```268:274:ea/grind_engine.mqh
bool Grind_OrderEngineSend(MqlTradeRequest &request, MqlTradeResult &result)
{
   if(!g_grind_order_test_active)
      return Grind_OrderSendCounted(request, result);

   if(request.action == TRADE_ACTION_REMOVE) {
      g_grind_order_test_remove_calls++;
```

```126:140:ea/grind_closeby.mqh
bool Grind_CloseBySend(MqlTradeRequest &req, MqlTradeResult &res)
{
   if(g_grind_closeby_test_active) {
      g_grind_closeby_test_send_calls++;
      if(g_grind_closeby_test_success_ticket1 > 0
         && (req.position != g_grind_closeby_test_success_ticket1
             || req.position_by != g_grind_closeby_test_success_ticket2)) {
         res.retcode = (uint)TRADE_RETCODE_REJECT;
         return false;
      }
      res.retcode = (uint)g_grind_closeby_test_send_retcode;
      return g_grind_closeby_test_send_ok;
   }
   return Grind_OrderSendCounted(req, res);
}
```

   - Furthermore, `s6` runs with `Algo OFF` (`docs/runbooks/twoarm-build-e.md:186-191`), so the terminal would reject any order locally before reaching `FTMO-Demo`.
   - `Grind_TelemetryWebPostStatus` (`ea/grind_telemetry.mqh:60-72`) also short-circuits on empty URL/key or `g_grind_telemetry_test_active`:

```60:72:ea/grind_telemetry.mqh
   if(url == "" || api_key == "")
      return -1;

   if(g_grind_telemetry_test_active) {
      g_grind_telemetry_test_post_calls++;
      g_grind_telemetry_test_last_url = url;
      g_grind_telemetry_test_last_payload = payload;
      if(g_grind_telemetry_test_force_status != 0)
         return g_grind_telemetry_test_force_status;
      if(g_grind_telemetry_test_force_fail)
         return -1;
      return 200;
   }
```

2. **Zero files in `MQL5\Files`:**
   - Neither `ea/fxgrind_tests.mq5`, `ea/fxgrind_tests_*.mqh`, `ea/fxgrind.mq5`, nor any `ea/grind_*.mqh` header calls `FileOpen` or `FileWrite`.
3. **Global Variables are wiped at entry and exit of `OnStart()`:**
   - `Test_SuiteResetGlobals()` (`ea/fxgrind_tests.mq5:95-108`) deletes every Global Variable whose name starts with `"GRIND"`, and `OnStart()` (`ea/fxgrind_tests.mq5:8778-8781`, `ea/fxgrind_tests.mq5:9464-9467`) calls it both before the first test and after the summary line:

```95:108:ea/fxgrind_tests.mq5
int Test_SuiteResetGlobals()
{
   int deleted = 0;
   const int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--) {
      const string name = GlobalVariableName(i);
      if(StringFind(name, "GRIND") == 0) {
         if(GlobalVariableDel(name))
            deleted++;
      }
   }
   Print("SUITE: cleared ", deleted, " GRIND GlobalVariables");
   return deleted;
}
```

```8778:8781:ea/fxgrind_tests.mq5
void OnStart()
{
   Test_SuiteResetGlobals();
   Test_SuiteCleanupMagicLocks();
```

```9464:9467:ea/fxgrind_tests.mq5
   Test_RG17_ShortRestartWhileGated();
   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");
   Test_SuiteResetGlobals();
}
```

   - Because individual tests write `"GRIND..."` GVs during the run, `s6`'s gate (`docs/runbooks/twoarm-build-e.md:189-190`: `Expected SUMMARY 2597 / 2597 ... F3 (Global Variables): EMPTY`) is essential: if `OnStart()` were ever interrupted before line `9466`, test GVs would remain until deleted.

---

### GE-3: `E4` Box Clock (`Etc/UTC` + NTP) vs `TimeGMT()`, `TimeTradeServer()`, and `TimeCurrent()`

Runbook question (`docs/runbooks/twoarm-build-e.md:270-272`):

```270:272:docs/runbooks/twoarm-build-e.md
- **GE-3.** E4: is there any place where the EA or the telemetry derives the FTMO day or a snapshot key from
  anything but `TimeGMT()` and `TimeTradeServer()` (e.g. `TimeCurrent()` on the dashboard's side), so that a
  wrong box clock would still matter, or not matter?
```

**Answer: The EA uses three clock primitives (`TimeGMT()`, `TimeTradeServer()`, and `TimeCurrent()`), and a wrong box clock or non-UTC timezone on `wine-e` WOULD break `TimeGMT()`, the FTMO `DAILY_SNAPSHOT` boundary and deal window, `scalp_closed` UTC offsets, archive event timestamps, and the `s5`/`s7` log checks:**

1. **`TimeGMT()` under Wine is derived from the Linux host's system clock (`E4`), and drives the FTMO day key, `DAILY_SNAPSHOT`, `scalp_closed` offset, and archive timestamps:**
   - `Grind_PragueUtcOffset`, `Grind_FtmoDayStartGmt`, and `Grind_FtmoDayKey` (`ea/grind_pure.mqh:526-551`) compute Prague time from `TimeGMT()`:

```526:551:ea/grind_pure.mqh
int Grind_PragueUtcOffset(const datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   const datetime dst_start = Grind_LastSundayMonthUtc(dt.year, 3);
   const datetime dst_end = Grind_LastSundayMonthUtc(dt.year, 10);
   if(gmt >= dst_start && gmt < dst_end)
      return 2;
   return 1;
}

//+------------------------------------------------------------------+
datetime Grind_FtmoDayStartGmt(const datetime gmt)
{
   const int off = Grind_PragueUtcOffset(gmt);
   const long local = (long)gmt + (long)off * 3600L;
   const long day_start_local = local - (local % 86400L);
   return (datetime)(day_start_local - (long)off * 3600L);
}

//+------------------------------------------------------------------+
string Grind_FtmoDayKey(const datetime gmt)
{
   const int off = Grind_PragueUtcOffset(gmt);
   return TimeToString(gmt + off * 3600, TIME_DATE);
}
```

   - `Grind_SnapshotOnTimer()` (`ea/grind_snapshot.mqh:354-367`, called every second from `OnTimer` at `ea/fxgrind.mq5:414`) uses `Grind_FtmoDayKey(TimeGMT())` to detect the `00:00` Prague rollover and claim `GRIND_SNAPSHOT_CLAIM`, and `Grind_SnapshotEmit` (`ea/grind_snapshot.mqh:261-266`) uses `off = (int)(TimeTradeServer() - TimeGMT())` to shift the Prague day window into broker deal-history time:

```261:266:ea/grind_snapshot.mqh
   const datetime now_gmt = TimeGMT();
   const int off = (int)(TimeTradeServer() - TimeGMT());
   const datetime start_next = Grind_FtmoDayStartGmt(now_gmt);
   const datetime start_ended = Grind_FtmoDayStartGmt(start_next - 1);
   const datetime win_from = start_ended + off;
   const datetime win_to = start_next + off - 1;
```

   - Every `scalp_closed` payload (`ea/grind_engine.mqh:2905-2921`) stamps `close_time` from `DEAL_TIME` (broker server time) and passes `(long)(TimeTradeServer() - TimeGMT())` as `broker_utc_offset_s`:

```2905:2921:ea/grind_engine.mqh
         const datetime close_time = (datetime)Grind_DealGetInteger(deal_ticket, DEAL_TIME);
         const ulong closed_position = side.layers[i].position_ticket;
         const bool was_ejected = Grind_EjectIsEjected(closed_position);
         const bool was_rolled = Grind_VLHas(closed_position);
         Grind_QueueScalpClosedEvent(g_grind_telemetry_instance,
                                     _Symbol,
                                     is_long ? "LONG" : "SHORT",
                                     entry_price,
                                     deal_price,
                                     layer_depth,
                                     stack_depth,
                                     net_pnl,
                                     close_time,
                                     was_ejected,
                                     (long)(TimeTradeServer() - TimeGMT()),
                                     AccountInfoInteger(ACCOUNT_LOGIN),
                                     was_rolled);
```

   - `Grind_ArchiveConfigure` (`ea/grind_archive.mqh:107-115`) anchors `ts_ms` for all archive events to `(long)((ulong)TimeGMT() * 1000)`:

```107:115:ea/grind_archive.mqh
   Grind_ArchiveConfigureAt(enabled,
                            telemetry_url,
                            api_key,
                            instance,
                            magic,
                            (long)((ulong)TimeGMT() * 1000),
                            GetTickCount64(),
                            verbose);
}
```

2. **Other day keys in the EA use `TimeTradeServer()` or `TimeCurrent()` (`Grind_LocalDayKey` in `ea/grind_pnl.mqh:86-91` is unused dead code):**
   - `Grind_ReadServerTime()` and `Grind_ServerDayKey()` (`ea/grind_pnl.mqh:70-91`), `Grind_MaeInit()` / `Grind_MaeOnTimer()` (`ea/grind_mae.mqh:187-210`), and `Grind_CarryServerTime()` (`ea/grind_carry.mqh:160-165`, called via `Grind_CarryOnTimerStep` at `ea/fxgrind.mq5:428-430`) key the broker day (`YYYYMMDD`, `GRIND_MAE_ANCHOR_<YYYYMMDD>`, `GRIND_MAE_EQUITY_LOW_<YYYYMMDD>`, `GRIND_CARRY_DAY_<magic>`) from `TimeTradeServer()`:

```70:91:ea/grind_pnl.mqh
datetime Grind_ReadServerTime()
{
   if(g_grind_pnl_test_active)
      return g_grind_pnl_test_server_time;
   return TimeTradeServer();
}

//+------------------------------------------------------------------+
string Grind_ServerDayKey(const datetime server_time)
{
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   return StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
string Grind_LocalDayKey(const datetime local_time)
{
   MqlDateTime dt;
   TimeToStruct(local_time, dt);
   return StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
}
```

```187:210:ea/grind_mae.mqh
void Grind_MaeInit()
{
   const string day_key = Grind_ServerDayKey(Grind_MaeReadNow());
   const double balance = Grind_MaeReadBalanceLive();
   const double equity = Grind_MaeReadEquityLive();
   g_grind_mae_day_key = day_key;

   const double loaded_low = Grind_MaeReadEquityLowGv(day_key);
   if(loaded_low >= 0.0) {
      g_grind_mae_equity_low = loaded_low;
      Grind_MaeRefreshDistToFloor(day_key);
   } else {
      Grind_MaeSeedCurrentDay(day_key, equity, balance);
   }
}

//+------------------------------------------------------------------+
void Grind_MaeOnTimer()
{
   const string day_key = Grind_ServerDayKey(Grind_MaeReadNow());
   const double balance = Grind_MaeReadBalanceLive();
   const double equity = Grind_MaeReadEquityLive();
   Grind_MaeCoreUpdate(day_key, equity, balance);
}
```

```160:165:ea/grind_carry.mqh
datetime Grind_CarryServerTime()
{
   if(g_grind_carry_test_server_time > 0)
      return g_grind_carry_test_server_time;
   return TimeTradeServer();
}
```

   - `Grind_ApiCounterTodayYmd()` (`ea/grind_api_counter.mqh:30-36`) keys `GRIND_DAILY_API_DATE` (`YYYYMMDD` at broker midnight `21:00Z`) from `TimeCurrent()`:

```30:36:ea/grind_api_counter.mqh
double Grind_ApiCounterTodayYmd()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string today_str = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   return (double)StringToInteger(today_str);
}
```

3. **Why `E4` (`Etc/UTC` + NTP synchronized in `s1.3`, `docs/runbooks/twoarm-build-e.md:62-69`) also matters for the box's logs (`docs/runbooks/twoarm-build-e.md:182`, `docs/runbooks/twoarm-build-e.md:209`):**

```62:69:docs/runbooks/twoarm-build-e.md
**1.3 The clock, then Wine 9 from Ubuntu** (06 s2: NEVER the WineHQ repository; Wine 11 does not run MT5).
After the reboot, one block (expected: `Time zone: Etc/UTC (UTC, +0000)`, `System clock synchronized: yes`,
then `wine-9.0`):

    uname -r; timedatectl | grep -E 'Time zone|synchronized'; dpkg --add-architecture i386 && apt update && apt -y install wine64 wine32 winbind xfce4 xfce4-goodies xrdp x11vnc git && wine --version

STOP if the zone is not UTC or the clock is not synchronised (E4): `timedatectl set-timezone Etc/UTC`, then
read again.
```

```180:182:docs/runbooks/twoarm-build-e.md
  line; the journal is UTF-16LE, named by the UTC day):

      L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/logs/$(date -u +%Y%m%d).log"; iconv -f UTF-16LE -t UTF-8 "$L" | grep -a -o "'[0-9]*': authorized on [^ ]*" | tail -2; iconv -f UTF-16LE -t UTF-8 "$L" | grep -a -i 'hedging' | tail -1
```

   - MT5 names its daily Journal and Experts log files (`YYYYMMDD.log`) and stamps every log line (`HH:MM:SS.mmm`) in the host OS's local timezone. Both `$(date -u +%Y%m%d).log` in `s5` (`docs/runbooks/twoarm-build-e.md:182`) and `$(date -u +%Y%m%d).log` + `-v from=HH:MM:00` in `s7` (`docs/runbooks/twoarm-build-e.md:209`) require the box timezone to be `Etc/UTC` and NTP-synchronized.
4. **Missing calendar fact in `s10` (`docs/runbooks/twoarm-build-e.md:243-251`) during E's 14-day window (21 Oct - 4 Nov):**

```243:251:docs/runbooks/twoarm-build-e.md
## 10. THE FIRST FTMO DAY (Thu 22 Oct, 22:00Z to 22:00Z)

- Status reads as A's: live, halts, recon and invariant ok, `api_count`, the day's P&L against FTMO's daily
  limit (the breaker is off: nothing stops at it, E7).
- **Requests (C106, E6):** above 1,700 by 14:00Z (A's GF-4 trigger of 1,000 for seven, x 12 / 7), or above
  2,000 for a day: tell Claude the same hour. Any FTMO email about requests: tell Claude at once. The EA's
  counter resets at server midnight (21:00Z), the FTMO day at 22:00Z.
- The first scalp per arm, the first roll, the first `DAILY_SNAPSHOT` at 22:00Z.
- E is not changed during the trial except for a defect (as A, ftmo-ic-start s10).
```

   - `Grind_PragueUtcOffset` (`ea/grind_pure.mqh:526-535`) switches Prague from CEST (`UTC+2`) to CET (`UTC+1`) on the last Sunday of October (`2026-10-25 01:00:00Z`), one week before US/broker DST ends on `2026-11-01`.
   - Therefore, from **Sunday 25 Oct 2026** onward, the FTMO day rollover and `DAILY_SNAPSHOT` shift from **`22:00Z` to `23:00Z`** (`00:00` CET), while the broker midnight (`21:00Z`) and carry pass (`20:50-20:59Z`) remain unchanged until **Sunday 1 Nov 2026**.

---

### GE-4: Slot Guard at `180-192` of `194` on 12 Instances at Cap 7 (`E6`)

Runbook question (`docs/runbooks/twoarm-build-e.md:273-274`):

```273:274:docs/runbooks/twoarm-build-e.md
- **GE-4.** Twelve instances on one FTMO account, cap 7 (E6): the slot guard (`grind_exitq.mqh` 105-161) at
  about 180-192 of 194; does anything other than refused entries happen near the guard (exits keep 1 slot)?
```

**Answer: Two distinct entry thresholds operate inside `180-194` (`186` for far-market adds vs `194` for near-market entries), while exits, exit-queue promotions, Virtual Lattice rolls, and CloseBy are completely unaffected because `Grind_SlotExitAllowed` checks `used` (`PositionsTotal() + OrdersTotal() <= 199`) without double-counting `resting_ent`:**

1. **Inside `180-192`, far-market adds are blocked at `used + resting_ent > 186` (`InpSlotNearReserve=8`):**
   - Look at `GRIND_SLOT_MARGIN` (`ea/grind_config.mqh:9`), `Grind_SlotAccountLimit` / `Grind_SlotUsed` / `Grind_SlotRestingEnt` / `Grind_SlotExitAllowed` / `Grind_SlotEntryAllowed` (`ea/grind_exitq.mqh:115-189`), and `Grind_AddTargetNearMarket` (`ea/grind_engine.mqh:2290-2295`, `ea/grind_engine.mqh:2375-2381`):

```9:9:ea/grind_config.mqh
#define GRIND_SLOT_MARGIN             4
```

```115:189:ea/grind_exitq.mqh
long Grind_SlotAccountLimit()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_limit;
   if(Grind_OrderTestActive())
      return 0;
   return AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
}

//+------------------------------------------------------------------+
int Grind_SlotUsed()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_used + g_grind_slot_test_delta;
   if(Grind_OrderTestActive())
      return 0;
   return PositionsTotal() + OrdersTotal();
}

//+------------------------------------------------------------------+
int Grind_SlotRestingEnt()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_resting_ent;
   if(Grind_OrderTestActive())
      return Grind_OrderTestRestingEntFleetCount();

   int resting_ent = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;

      const long magic = OrderGetInteger(ORDER_MAGIC);
      if(!Grind_IsFleetMagic(magic))
         continue;

      string slot, side, role;
      int layer_index;
      const string comment = OrderGetString(ORDER_COMMENT);
      if(GrindCommentParse(comment, slot, side, layer_index, role)) {
         if(role == "EXT")
            continue;
      }
      resting_ent++;
   }
   return resting_ent;
}

//+------------------------------------------------------------------+
bool Grind_SlotExitAllowed(const long limit, const int used)
{
   if(limit <= 0)
      return true;
   return ((long)used <= limit - 1);
}

//+------------------------------------------------------------------+
bool Grind_SlotEntryAllowed(const long limit,
                            const int used,
                            const int resting_ent,
                            const bool near_market)
{
   if(limit <= 0)
      return true;
   const long reserve = near_market ? 0 : (long)g_grind_slot_near_reserve;
   const long needed = 2 + GRIND_SLOT_MARGIN + reserve;
   return ((long)(used + resting_ent) <= limit - needed);
}

//+------------------------------------------------------------------+
bool Grind_SlotEntryAllowed(const long limit, const int used, const int resting_ent)
{
   return Grind_SlotEntryAllowed(limit, used, resting_ent, true);
}
```

```2290:2295:ea/grind_engine.mqh
bool Grind_AddTargetNearMarket(const double target,
                               const double mid,
                               const double add_pips)
{
   return (MathAbs(target - mid) <= Grind_PipsToPrice(add_pips, _Point) + GRIND_PRICE_EPS);
}
```

```2375:2381:ea/grind_engine.mqh
   if(!Grind_SlotEntryAllowed(limit, used, resting_ent, near_market)) {
      if(!near_market)
         g_grind_near_reserve_blocks++;
      Grind_SlotLockRelease(slot_token);
      Grind_Adr152ClearDueForSide(is_long);
      return false;
   }
```

   - With `limit = 200`, `GRIND_SLOT_MARGIN = 4` (`ea/grind_config.mqh:9`), and `InpSlotNearReserve = 8`, `limit - needed` is **`186`** when `near_market == false` (any add whose clamped target is farther than `add_pips` from `mid`, which increments `g_grind_near_reserve_blocks` once `used + resting_ent >= 187`), and **`194`** when `near_market == true` (`L0` entries and normal adds within `add_pips` of `mid`).
   - When an add is refused at fill time (`Grind_TryPlaceAddAtFill` -> `Grind_SendNextAddEnt`), `Grind_Adr152ClearDueForSide(is_long)` clears the fill-time due flag and `Grind_EnsureAddNext` places the missing add on the first subsequent tick where `used + resting_ent` drops back within `limit - needed`.
2. **Exits, exit-queue promotions, and Virtual Lattice rolls are unaffected at `guarded = 180..194`:**
   - `Grind_SlotExitAllowed(200, used)` (`ea/grind_exitq.mqh:165-170`) checks `used <= 199` (`PositionsTotal() + OrdersTotal()`), whereas `guarded = used + resting_ent` counts every resting `ENT` order twice (`ea/grind_exitq.mqh:125-161`). When `guarded` is `180..194` with `12..24` resting `ENT` orders across 12 instances, actual `used` is only `156..182`, leaving `17..43` real broker slots below `199`.
   - Furthermore, `Grind_ExitQManageSide` (`ea/grind_engine.mqh:3474-3488`) cancels any non-rank-0 `EXT` order **before** checking `Grind_SlotExitAllowed` and placing the new rank-0 `EXT` order, and `Grind_LatticeRollLayer` either modifies an existing `EXT` order in place (`Grind_ModifyPendingPrice`) or updates the virtual level and calls `Grind_ExitQManageSide`:

```3474:3488:ea/grind_engine.mqh
   for(int i = 0; i < n; i++) {
      if(!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0)
         Grind_ExitQHoldCancelLayer(side.layers[i], is_long, magic);
   }

   for(int i = 0; i < n; i++) {
      if(!Grind_ExitQRequired(ranks[i], n))
         continue;
      if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0)
         continue;

      const long limit = Grind_SlotAccountLimit();
      const int used = Grind_SlotUsed();
      if(!Grind_SlotExitAllowed(limit, used))
         continue;
```

---

### GE-5: Breaker Off on FTMO (`E7`) -- Paths That Do and Do Not Depend on `InpBreakerEnable`

Runbook question (`docs/runbooks/twoarm-build-e.md:275-276`):

```275:276:docs/runbooks/twoarm-build-e.md
- **GE-5.** Breaker off on FTMO (E7): any path in the EA that assumes the breaker is on for an FTMO account
  (the pre-midnight halt, the day anchor, the archive's DAILY rows)?
```

**Answer: `DAILY_SNAPSHOT` and the intraday MAE reporter run unconditionally even when `InpBreakerEnable=false` (while the pre-midnight halt, float gate, and 80% trip are disabled as intended), EXCEPT for one missing fact in `grind_snapshot.mqh`: attaching after `22:00Z` (`22:05Z`, `s7`) on a fresh terminal leaves `GRIND_SNAPSHOT_START_DAY` unset for all of FTMO day 1 (`2026.10.22`), so the first `DAILY_SNAPSHOT` at `22:00Z` Thu 22 Oct (`s10`) emits `"start_known":false` and `"equity_start":null`, `"inventory_pnl":null`, `"total":null`, `"swap_day":null`:**

1. **What `InpBreakerEnable=false` disables (`ea/grind_engine.mqh:1582-1587`, `ea/grind_engine.mqh:1698-1702`, `ea/grind_pure.mqh:655-681`):**
   - `Grind_BreakerOnTick(InpMagic, InpSlot, InpBreakerEnable)` (`ea/fxgrind.mq5:470-471`, `ea/grind_engine.mqh:1698-1702`) sets `g_grind_breaker_enabled = false` and returns immediately:

```470:471:ea/fxgrind.mq5
   Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), true);
   Grind_BreakerOnTick(InpMagic, InpSlot, InpBreakerEnable);
```

```1582:1587:ea/grind_engine.mqh
bool Grind_BreakerBlocksEntries()
{
   return g_grind_breaker_enabled
          && (g_grind_breaker_tripped || g_grind_breaker_premidnight
              || g_grind_breaker_gated);
}
```

```1698:1702:ea/grind_engine.mqh
void Grind_BreakerOnTick(const ulong magic, const string slot, const bool enabled)
{
   g_grind_breaker_enabled = enabled;
   if(!enabled)
      return;
```

```655:681:ea/grind_pure.mqh
bool Grind_BreakerShouldTrip(const double equity, const double anchor,
                             const double allowance, const double frac)
{
   if(anchor <= 0.0 || allowance <= 0.0)
      return false;
   return (equity <= anchor - frac * allowance);
}

//+------------------------------------------------------------------+
bool Grind_BreakerPreMidnightHalt(const int sec_into_day, const double equity,
                                  const double balance, const double allowance)
{
   if(sec_into_day < 82800)
      return false;
   return ((balance - equity) >= 0.5 * allowance);
}

//+------------------------------------------------------------------+
bool Grind_BreakerFloatGate(const bool was_gated, const double floating,
                            const double allowance)
{
   if(allowance <= 0.0)
      return false;
   if(!was_gated)
      return (floating >= 0.5 * allowance);
   return (floating > 0.4 * allowance);
}
```

   - This disables `Grind_BreakerShouldTrip` (`80%` of `5%` = `$400`), `Grind_BreakerPreMidnightHalt` (`sec_into_day >= 82800` and `balance - equity >= $250`), and `Grind_BreakerFloatGate` (`balance - equity >= $250`, clearing at `$200`, `ea/grind_pure.mqh:655-681`), so `Grind_BreakerBlocksEntries()` (`ea/grind_engine.mqh:1582-1587`) is always `false` and `s.breaker_tripped`, `s.premidnight_seen`, and `s.gated_seconds` in `DAILY_SNAPSHOT` (`ea/grind_snapshot.mqh:333-336`) read `false`, `false`, and `0`.
2. **What still runs unconditionally when `InpBreakerEnable=false` (`ea/fxgrind.mq5:413-430`, `ea/grind_snapshot.mqh:306-316`, `ea/grind_mae.mqh:187-210`):**
   - In `OnTimer` (`ea/fxgrind.mq5:413-430`), `Grind_SnapshotOnTimer()` (`:414`) and `Grind_MaeOnTimer()` (`:421`) are not gated by `InpBreakerEnable`:

```413:430:ea/fxgrind.mq5
   Grind_GvFlushIfDirty();
   Grind_SnapshotOnTimer();
   Grind_ArchiveFlush(false);
   Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), false);

   const ulong now_tick = GetTickCount64();
   if(Grind_TimerTelemetryDue(now_tick, g_grind_last_telemetry_tick, TelemetryIntervalSec)) {
      Grind_ResetDailyPnlIfNewDay();
      Grind_MaeOnTimer();
      Grind_GateAccumulate("GRIND_SNAPSHOT_GATED_S_" + Grind_FtmoDayKey(TimeGMT()),
                            g_grind_mae_is_reporter, g_grind_breaker_gated, TimeGMT(),
                            2 * TelemetryIntervalSec);
      Grind_ProcessPendingExitMicrostructure();
      Grind_DrainScalpEventQueue();
      Grind_EmitHeartbeat();
      const datetime carry_now = TimeTradeServer();
      Grind_CarryOnTimerStep(_Symbol, InpMagic, g_geo_exit_long, InpEnableCarryPass, carry_now,
                             g_geo_exit_short);
```

   - Inside `Grind_SnapshotEmit` (`ea/grind_snapshot.mqh:306-316`), `Grind_BreakerLoadInitialDeposit()` and `Grind_BreakerDayAnchor(...)` are called directly even when `InpBreakerEnable=false`, so the history fallback for `balance_start` still works:

```306:316:ea/grind_snapshot.mqh
   Grind_BreakerLoadInitialDeposit();
   double amounts[];
   datetime times[];
   int n = 0;
   Grind_BreakerCollectDealHistory(start_ended + off, TimeTradeServer() + 60,
                                   amounts, times, n);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double hist_bal_start = Grind_BreakerDayAnchor(balance_now, amounts, times, n,
                                                        start_ended + off,
                                                        g_grind_breaker_initial_deposit,
                                                        g_grind_breaker_initial_time);
```

3. **Missing fact on E's first `DAILY_SNAPSHOT` (`2026.10.22`) when attaching after `22:00Z` (`s7`, `s10`):**
   - Look at `Grind_SnapshotCompute`, `Grind_SnapshotJson`, `Grind_SnapshotEmit`, and `Grind_SnapshotOnTimer` (`ea/grind_snapshot.mqh:130-150`, `ea/grind_snapshot.mqh:164-168`, `ea/grind_snapshot.mqh:291-304`, `ea/grind_snapshot.mqh:333-367`):

```130:150:ea/grind_snapshot.mqh
   if(start_known) {
      s.balance_start = stored_bal_start;
      s.balance_start_source = "stored";
   } else {
      s.balance_start = hist_bal_start;
      s.balance_start_source = "history";
   }
   s.balance_end = bal_end;
   s.equity_end = eq_end;
   s.realised = bal_end - s.balance_start;
   if(start_known) {
      s.equity_start = stored_eq_start;
      s.inventory_pnl = (eq_end - bal_end) - (stored_eq_start - s.balance_start);
      s.total = eq_end - stored_eq_start;
      s.swap_day = deal_swap_day + (pswap_now - stored_pswap_start);
   } else {
      s.equity_start = 0.0;
      s.inventory_pnl = 0.0;
      s.total = 0.0;
      s.swap_day = 0.0;
   }
```

```164:168:ea/grind_snapshot.mqh
   const string eq_start = Grind_SnapshotJsonFieldMoney(s.equity_start, s.start_known);
   const string inv = Grind_SnapshotJsonFieldMoney(s.inventory_pnl, s.start_known);
   const string total = Grind_SnapshotJsonFieldMoney(s.total, s.start_known);
   const bool swap_known = s.start_known && s.history_ok;
   const string swap_day = Grind_SnapshotJsonFieldMoney(s.swap_day, swap_known);
```

```291:304:ea/grind_snapshot.mqh
   const bool day_exists = GlobalVariableCheck(GRIND_SNAPSHOT_START_DAY);
   const int stored_day = day_exists ? (int)GlobalVariableGet(GRIND_SNAPSHOT_START_DAY) : 0;
   const bool login_exists = GlobalVariableCheck(GRIND_SNAPSHOT_START_LOGIN);
   const long stored_login = login_exists ? (long)GlobalVariableGet(GRIND_SNAPSHOT_START_LOGIN) : 0;
   const bool start_known = Grind_SnapshotStartKnown(day_exists, stored_day, ended_num,
                                                     login_exists, stored_login, login_now);
   double stored_bal = 0.0;
   double stored_eq = 0.0;
   double stored_pswap = 0.0;
   if(start_known) {
      stored_bal = GlobalVariableGet(GRIND_SNAPSHOT_START_BAL);
      stored_eq = GlobalVariableGet(GRIND_SNAPSHOT_START_EQ);
      stored_pswap = GlobalVariableGet(GRIND_SNAPSHOT_START_PSWAP);
   }
```

```333:367:ea/grind_snapshot.mqh
   s.breaker_tripped = GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + ended_key);
   s.premidnight_seen = GlobalVariableCheck("GRIND_BREAKER_PREMID_" + ended_key);
   const string gated_gv = "GRIND_SNAPSHOT_GATED_S_" + ended_key;
   s.gated_seconds = GlobalVariableCheck(gated_gv) ? (int)GlobalVariableGet(gated_gv) : 0;

   const string current_key = Grind_FtmoDayKey(now_gmt);
   const int current_num = Grind_FtmoDayNum(current_key);
   GlobalVariableSet(GRIND_SNAPSHOT_START_DAY, (double)current_num);
   GlobalVariableSet(GRIND_SNAPSHOT_START_BAL, bal_end);
   GlobalVariableSet(GRIND_SNAPSHOT_START_EQ, eq_end);
   GlobalVariableSet(GRIND_SNAPSHOT_START_PSWAP, pswap_now);
   GlobalVariableSet(GRIND_SNAPSHOT_START_LOGIN, (double)login_now);
   Grind_GvMarkDirty();

   const string json = Grind_SnapshotJson(s);
   Grind_TelemetryEmit(g_grind_telemetry_instance, "DAILY_SNAPSHOT", json);
   Grind_ArchiveMarker("INFO", "DAILY_SNAPSHOT", ended_key, 0, json);
   Grind_ArchiveFlush(true);
}

//+------------------------------------------------------------------+
void Grind_SnapshotOnTimer()
{
   const string key = Grind_FtmoDayKey(TimeGMT());
   if(g_grind_snapshot_day_key == "") {
      g_grind_snapshot_day_key = key;
      return;
   }
   if(!Grind_SnapshotRollDue(g_grind_snapshot_day_key, key))
      return;
   const string ended = g_grind_snapshot_day_key;
   g_grind_snapshot_day_key = key;
   if(Grind_SnapshotClaim(GRIND_SNAPSHOT_CLAIM, Grind_FtmoDayNum(key)))
      Grind_SnapshotEmit(ended);
}
```

   - `GRIND_SNAPSHOT_START_DAY`, `GRIND_SNAPSHOT_START_BAL`, `GRIND_SNAPSHOT_START_EQ`, `GRIND_SNAPSHOT_START_PSWAP`, and `GRIND_SNAPSHOT_START_LOGIN` are **only** written inside `Grind_SnapshotEmit` when a `22:00Z` rollover occurs while an EA is already running!
   - Because `s7` attaches E from `22:05Z` Wed 21 Oct (`docs/runbooks/twoarm-build-e.md:193`), after the `22:00Z` rollover into `"2026.10.22"` has already passed, `Grind_SnapshotOnTimer()` sets `g_grind_snapshot_day_key = "2026.10.22"` and returns without creating `GRIND_SNAPSHOT_START_DAY`.
   - Consequently, at `22:00Z` Thu 22 Oct (`s10`, `docs/runbooks/twoarm-build-e.md:250`), E's first `DAILY_SNAPSHOT` (`ftmo_day: "2026.10.22"`) has `start_known == false`, so `Grind_SnapshotCompute` (`ea/grind_snapshot.mqh:130-150`) and `Grind_SnapshotJson` (`ea/grind_snapshot.mqh:164-168`) emit `"start_known":false`, `"balance_start":10000.00`, `"balance_start_source":"history"`, and **`"equity_start":null`, `"inventory_pnl":null`, `"total":null`, `"swap_day":null`** (`start_known` becomes `true` from the second day `"2026.10.23"` onward).
   - If the operator wants `"start_known":true` and non-null `equity_start`, `inventory_pnl`, `total`, and `swap_day` on E's first `DAILY_SNAPSHOT` (`2026.10.22`), seed `GRIND_SNAPSHOT_START_DAY = 20261022`, `GRIND_SNAPSHOT_START_BAL = 10000`, `GRIND_SNAPSHOT_START_EQ = 10000`, `GRIND_SNAPSHOT_START_PSWAP = 0`, and `GRIND_SNAPSHOT_START_LOGIN = <new_login>` in `F3` after `s6` (when GVs are empty) and before `22:00Z` Thu 22 Oct.

---

### GE-6: The Attach Rule in `s7` -- Spread Hold at `2 x OPT width` and From `22:05Z`

Runbook text and question (`docs/runbooks/twoarm-build-e.md:193-198` and `277`):

```193:198:docs/runbooks/twoarm-build-e.md
## 7. ATTACH (from 22:05Z; the pilot, then five OPT, then six ALT)

**Spreads first** (Market Watch, points): hold a pair whose spread is above 2 x its OPT width (EURUSD 40,
GBPUSD 50, AUDCAD 30, EURGBP / AUDCHF / CADCHF 20); 7 Oct at 22:07Z the CHF crosses read 10-12 and the NZD
crosses 61-88 (held until 22:15Z). **Algo Trading ON** (on this terminal an EA attached with Algo off stays
inactive, so each EA trades from its OK: the read-back is the only gate, ftmo-ic-start GF-1).
```

```277:277:docs/runbooks/twoarm-build-e.md
- **GE-6.** The attach rule (s7): the spread hold at 2 x OPT width, and from 22:05Z; enough, or too strict?
```

**Answer: The manual spread-hold threshold `2 x OPT width` (`40, 50, 30, 20` points) in `s7` is the exact mechanical boundary where the EA's ADR-013 passive clamp activates (because the EA itself has NO spread hold on `L0` placement), so `2 x OPT width` is the bare minimum and slightly tight on the `1.0`-pip width pairs (`EURGBP`, `AUDCHF`, `CADCHF`), not too strict:**

1. **Why the manual Market Watch check in `s7` is necessary (`ea/grind_pure.mqh:124-137`, `ea/grind_pure.mqh:198-226`, `ea/grind_engine.mqh:2062-2075`, `ea/grind_engine.mqh:3214-3229`):**
   - In `Grind_OnTickEngine` (`ea/grind_engine.mqh:3214-3229`), `buy_target = mid - width` and `sell_target = mid + width`:

```124:137:ea/grind_pure.mqh
double Grind_StraddleBuyPrice(const double mid,
                              const double width_pips,
                              const double point)
{
   return mid - Grind_PipsToPrice(width_pips, point);
}

//+------------------------------------------------------------------+
double Grind_StraddleSellPrice(const double mid,
                               const double width_pips,
                               const double point)
{
   return mid + Grind_PipsToPrice(width_pips, point);
}
```

```198:226:ea/grind_pure.mqh
bool Grind_Adr013ClampBuy(const double theoretical,
                          const double bid,
                          const double point,
                          const long stops_level_points,
                          double &out_price)
{
   const double min_dist = MathMax(point, stops_level_points * point);
   if(theoretical >= bid)
      out_price = MathMin(theoretical, bid - min_dist);
   else
      out_price = theoretical;
   return (MathAbs(out_price - theoretical) > point * 0.1);
}

//+------------------------------------------------------------------+
bool Grind_Adr013ClampSell(const double theoretical,
                           const double bid,
                           const double ask,
                           const double point,
                           const long stops_level_points,
                           double &out_price)
{
   const double min_dist = MathMax(point, stops_level_points * point);
   if(theoretical <= ask)
      out_price = MathMax(theoretical, ask + min_dist);
   else
      out_price = theoretical;
   return (MathAbs(out_price - theoretical) > point * 0.1);
}
```

```2062:2075:ea/grind_engine.mqh
   if(side.l0_pending_ticket != 0) {
      if(!Grind_SelectOurOrder(side.l0_pending_ticket, magic)) {
         if(Grind_SelectOurPosition(side.l0_pending_ticket, magic))
            return false;
         side.l0_pending_ticket = 0;
      } else {
         // ADR-123 place-once: our L0 is resting; leave it untouched.
         // Re-centering is ADR-124's job and is fill-triggered.
         return false;
      }
   }

   if(g_grind_ent_sent_this_tick)
      return false;
```

```3214:3229:ea/grind_engine.mqh
   double buy_target = Grind_StraddleBuyPrice(mid, width_pips, _Point);
   double sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);
   Grind_Adr013ClampBuy(buy_target, bid, _Point, stops, buy_target);
   Grind_Adr013ClampSell(sell_target, bid, ask, _Point, stops, sell_target);

   if(Grind_SideDepth(g_grind_long) == 0 && Grind_BuyLimitMarketable(buy_target, ask))
      Grind_TryPlaceL0(g_grind_long, true, buy_target, magic, slot, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) == 0 && Grind_SellLimitMarketable(sell_target, bid))
      Grind_TryPlaceL0(g_grind_short, false, sell_target, magic, slot, max_layers, lots);

   if(Grind_SideDepth(g_grind_long) > 0 && Grind_SideDepth(g_grind_short) == 0)
      Grind_TryRecenterOppositeL0(g_grind_short, false, mid, magic, slot,
                                  width_s, stranded_thresh_pips, deadband_pips);
   if(Grind_SideDepth(g_grind_short) > 0 && Grind_SideDepth(g_grind_long) == 0)
      Grind_TryRecenterOppositeL0(g_grind_long, true, mid, magic, slot,
                                  width_pips, stranded_thresh_pips, deadband_pips);
```

   - Because `mid = (bid + ask) * 0.5`, `buy_target >= bid` and `sell_target <= ask` occur whenever `ask - bid >= 2 * width_pips` (`40` points on `EURUSD`, `50` on `GBPUSD`, `30` on `AUDCAD`, `20` on `EURGBP / AUDCHF / CADCHF`).
   - If an `OPT` chart is attached while `spread >= 2 * OPT width`, `Grind_Adr013ClampBuy` / `Grind_Adr013ClampSell` clamps `L0` to `bid - min_dist` and `ask + min_dist` (`1` point outside the wide quote) and places it immediately; and because `Grind_TryPlaceL0` (`ea/grind_engine.mqh:2062-2071`) is ADR-123 place-once and `Grind_TryRecenterOppositeL0` (`ea/grind_engine.mqh:3224-3229`) only fires when one side has `depth > 0` and the other has `depth == 0`, wide-clamped `L0` orders are not re-centered while both sides remain at depth `0`.
2. **Is `2 x OPT width` enough or too strict?**
   - It is **never too strict**; for `ALT` (`width = 2.5..7.0` pips = `25..70` points, `2 x ALT width = 50..140` points), `2 x OPT width` gives a `2.5x..5.5x` safety margin.
   - For the three `width = 1.0` (`10`-point) `OPT` charts (`EURGBP`, `AUDCHF`, `CADCHF`), at `spread = 19` points (`just` under `20`), `mid - width` is only `0.5` points (`0.05` pips) below `bid`, so a 1-point wobble fills `L0` immediately. Waiting until `EURGBP / AUDCHF / CADCHF` read `<= 15` points (as on 7 Oct at `22:07Z`, when the CHF crosses already read `10-12` points) gives at least `2.5` points (`0.25` pips) of clearance between `L0` and `bid`/`ask`.

---

### GE-7: Closing A (`s3`) and Destroying the Windows VPS (`s4`) Before E Attaches (`s7`)

Runbook question (`docs/runbooks/twoarm-build-e.md:278-279`):

```278:279:docs/runbooks/twoarm-build-e.md
- **GE-7.** The order: A off and the VPS closed (s3-s4) before E attaches (s7), with the desktop terminal
  still on 1514878887. Any reason to keep the VPS until E's first day is clean?
```

**Answer: The order (`s3` -> `s4` -> `s5` -> `s7`) is sound because `wine-e` is already built and compiled in `s1`, the desktop terminal retains read-only access to `1514878887` (`s3.4`), and opening E's new FTMO free trial (`s5`) requires closing `1514878887` in FTMO's client area first (`E5`). However, `s3.3` and `s4.2` miss two critical flush/backup steps before the VPS is destroyed:**

1. **Close MT5 on the Windows VPS after `s3.3` and before `s4.2` zips `MQL5\Logs` and `logs`:**
   - Look at `s3.3` (`docs/runbooks/twoarm-build-e.md:142-144`), `s4.2` (`docs/runbooks/twoarm-build-e.md:160-164`), `OnDeinit` (`ea/fxgrind.mq5:396-405`), and `Grind_ArchiveFlush` (`ea/grind_archive_flush.mqh:40-43`):

```142:144:docs/runbooks/twoarm-build-e.md
3. **VPS: Algo Trading OFF**, then remove the EA from all seven charts (right-click -> Expert Advisors ->
   Remove). Experts tab: seven `fxgrind deinit reason=1`. Positions and orders are left as they are (the
   trial is closed with them; the dump below records them).
```

```160:164:docs/runbooks/twoarm-build-e.md
2. **The files only the VPS holds**, zipped: `C:\fxmatrix-local` (cycle 3's binary, the checker's copies), the
   Experts logs (`MQL5\Logs`) and the Journal (`logs`), each under its own name (the two `logs` folders
   would collide in one zip root):

       $T = "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850"; $Z = "C:\vps_final_2026-10-21"; New-Item -ItemType Directory -Force $Z | Out-Null; Copy-Item -Recurse C:\fxmatrix-local "$Z\fxmatrix-local"; Copy-Item -Recurse "$T\MQL5\Logs" "$Z\experts_logs"; Copy-Item -Recurse "$T\logs" "$Z\journal_logs"; Compress-Archive -Path "$Z\*" -DestinationPath "$Z.zip"; Get-FileHash "$Z.zip" -Algorithm SHA256
```

```396:405:ea/fxgrind.mq5
void OnDeinit(const int reason)
{
   Grind_ArchiveRecordDeinit(InpMagic, reason, TimeCurrent(), g_grind_archive_anchor_ms);

   GlobalVariablesFlush();
   EventKillTimer();
   Grind_MagicLockRelease(InpMagic);
   if(InpVerboseLog)
      Print("fxgrind deinit reason=", reason);
}
```

```40:43:ea/grind_archive_flush.mqh
   const long now_ms = Grind_ArchiveNowMs();
   if(!force && g_grind_archive_last_flush_ms != 0 &&
      now_ms - g_grind_archive_last_flush_ms < 2000)
      return;
```

   - While MT5 is still open on Windows, it buffers `MQL5\Logs\20261021.log` and `logs\20261021.log` in memory. If `s4.2` copies `MQL5\Logs` and `logs` without closing MT5 first, the final lines (including the seven `fxgrind deinit reason=1` lines from `s3.3`) can still be in memory and absent from `$Z.zip`.
   - Also, in `s3.3`, wait at least `3` seconds after turning `Algo Trading OFF` before removing the 7 EAs so `OnTimer` (`Grind_ArchiveFlush(false)` at `ea/fxgrind.mq5:415`, `2000` ms throttle at `ea/grind_archive_flush.mqh:40-43`) flushes any queued archive events (`OnDeinit` at `ea/fxgrind.mq5:396-405` does not call `Grind_ArchiveFlush`).
2. **Include `$T\profiles\gvs.dat` (the VPS terminal's Global Variables) in `s4.2`'s zip:**
   - The desktop terminal logged in to `1514878887` (`s3.4`) sees broker deal history, **not** the VPS terminal's local Global Variables (`GRIND_VL_*`, `GRIND_CARRY_SHIFT_*`, `GRIND_CARRY_ACCRUED_*`, `GRIND_SNAPSHOT_*`, `GRIND_DEINIT_*`). Closing MT5 on the VPS after `s3.3` flushes `profiles\gvs.dat` to disk; adding `Copy-Item "$T\profiles\gvs.dat" "$Z\gvs.dat"` to `s4.2` preserves A's terminal GV state before `s4.3` destroys the VPS.

---

### GE-8: Failures Not on `s11` and Missing Facts in `docs/runbooks/twoarm-build-e.md`

Runbook question (`docs/runbooks/twoarm-build-e.md:280`):

```280:280:docs/runbooks/twoarm-build-e.md
- **GE-8.** What failure is not on s11? What fact is missing?
```

In addition to the `s1.9` missing `scripts/grind_*.mq5` copy (`GE-1`), the `25 Oct` Prague DST shift from `22:00Z` to `23:00Z` (`GE-3`), the `start_known: false` first `DAILY_SNAPSHOT` when attaching after `22:00Z` (`GE-5`), and closing MT5 + saving `gvs.dat` before `s4.2` zips the VPS (`GE-7`), the following **five failures and missing facts** are not in `docs/runbooks/twoarm-build-e.md` at `81f7d70`:

#### 1. Brand-New MT5 Install (`s5`, `s7`): Enabling the Six Traded Symbols in Market Watch Before `s7`

- **Runbook text (`docs/runbooks/twoarm-build-e.md:184`, `docs/runbooks/twoarm-build-e.md:195`, `docs/runbooks/twoarm-build-e.md:200-201`):**

```184:184:docs/runbooks/twoarm-build-e.md
- Toolbox -> Trade: $10,000, zero positions, zero orders. STOP on a netting account (Close By needs hedging).
```

```195:195:docs/runbooks/twoarm-build-e.md
**Spreads first** (Market Watch, points): hold a pair whose spread is above 2 x its OPT width (EURUSD 40,
```

```200:201:docs/runbooks/twoarm-build-e.md
Per chart: File -> New Chart -> the symbol, M5; drag **Navigator -> Expert Advisors -> fxmatrix ->
fxgrind**; Inputs -> Load `<pair>_<arm>_e_t1.set` -> read back BEFORE OK: `InpMagic`, `InpSlot`,
```

- **Missing fact:**
  - On a brand-new MT5 install (`wine-e`) logging into `FTMO-Demo` for the first time (`s5`), MT5's default Market Watch list does not automatically show all four crosses (`EURGBP`, `AUDCAD`, `AUDCHF`, `CADCHF`).
  - Both `s7`'s spread check in Market Watch (`:195`) and `File -> New Chart` (`:200`) only show symbols enabled in Market Watch, and `SymbolInfoTick` only receives quotes for subscribed symbols.
  - Add a step at the end of `s5` to enable `GBPUSD`, `EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, and `CADCHF` in **Market Watch** (`Ctrl+M` -> right-click -> `Symbols` / `Ctrl+U`, or type each symbol in `+ click to add...`) and confirm live bid/ask quotes are ticking on all six.

#### 2. `s1.8` / `s7`: Unticking `Show trade levels` (`handoffs/Handover/02_TRAPS.md:112-115`)

- **Runbook text (`docs/runbooks/twoarm-build-e.md:104-107`):**

```104:107:docs/runbooks/twoarm-build-e.md
**1.8 Terminal options (GUI).** Tools -> Options -> Expert Advisors: "Allow WebRequest for listed URL"
ticked, `https://pipshed.com` typed in the list; Trade: One Click Trading OFF. **Algo Trading OFF** (toolbar).
No account yet. (A MetaTrader LiveUpdate right after install may refresh components: let it, nothing is
attached.)
```

- **Trap (`handoffs/Handover/02_TRAPS.md:112-115`):**

```112:115:handoffs/Handover/02_TRAPS.md
**Dragging an order line on an MT5 chart modifies it INSTANTLY** -- no
confirmation, no undo. The operator moved an exit 5 pips while trying to
maximise a chart and I6 halted the instance. Mitigation: chart Properties ->
Show -> untick "Show trade levels" on VPS charts.
```

- **Missing fact:**
  - `s1.8` sets `One Click Trading OFF` under `Tools -> Options -> Trade`, but omits unticking **`Show trade levels`** right below it (or per-chart `F8 -> Show -> Show trade levels` in `s7`). With 12 charts in one VNC desktop on `wine-e`, clicking a chart can drag a resting `EXT` line and immediately halt the instance on `I6_LONG_EXIT_TARGET` / `I6_SHORT_EXIT_TARGET`.

#### 3. `s7` (`docs/runbooks/twoarm-build-e.md:207-213`): MT5 Log Buffer and First-Heartbeat Timing After Clicking `OK`

- **Runbook text (`docs/runbooks/twoarm-build-e.md:207-213`), `OnInit` end (`ea/fxgrind.mq5:390-393`), `Grind_TelemetryEmit` (`ea/grind_telemetry.mqh:92-95`), `scripts/build_logcheck.awk:13`, `Grind_FeedStaleAfterTick` (`ea/grind_pure.mqh:255-262`), and `handoffs/Handover/02_TRAPS.md:2745-2747`:**

```207:213:docs/runbooks/twoarm-build-e.md
The checker (as D's s4; FROM = the minute before the chart's OK; one row per chart since FROM):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /home/khalid/fxmatrix-repo/scripts/build_logcheck.awk; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 '{if(match($0,/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) && substr($0,RSTART,8)>=from && /telemetry dropped/) n++} END{print "telemetry dropped since FROM:", n+0}'

Expected per chart: `deinit=- replay=ready(0) lattice=true reroll=true gate=0 api=1000000/999000 geo=` as
s0, `rebuild=false/false`, BAD 0 (no `duplicate magic`, no `STARTUP_EXIT_SHORTFALL`: a flat attach has no
exit to place), a POST ok, `telemetry dropped since FROM: 0`; two L0 orders resting about `width` from mid.
```

```390:393:ea/fxgrind.mq5
   Grind_ApiLimitsPublishAndCheck();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
```

```92:95:ea/grind_telemetry.mqh
   if(verbose_log) {
      if(http_status == 200)
         Print("INFO: grind telemetry POST ok url=", url);
      else if(http_status == -1)
```

```13:13:scripts/build_logcheck.awk
  if ($0 ~ /grind telemetry POST ok/) { post[src]++; next }
```

```255:262:ea/grind_pure.mqh
bool Grind_FeedStaleAfterTick(const long tick_msc,
                              long &last_feed_tick_msc,
                              const long max_age_ms = GRIND_FEED_STALE_MS)
{
   if(last_feed_tick_msc <= 0) {
      last_feed_tick_msc = tick_msc;
      return false;
   }
```

```2745:2747:handoffs/Handover/02_TRAPS.md
- **The EA sends at most ONE entry order per engine call** (`g_grind_ent_sent_this_tick`): on a
  fresh tick with both sides empty only the long L0 goes; an empty side's L0 takes the one
  entry before any add. A test that needs an add to rest must seed the other side's L0.
```

- **Missing fact:**
   - `OnInit()` (`ea/fxgrind.mq5:390-393`) does not call `Grind_EmitHeartbeat()` or `Grind_ArchiveFlush()`; the first `INFO: grind telemetry POST ok url=...` (`ea/grind_telemetry.mqh:92-95`, matched by `scripts/build_logcheck.awk:13`) is emitted on the first `OnTimer()` tick (`EventSetTimer(1)` at `ea/fxgrind.mq5:391`), and MT5 buffers `MQL5/logs/YYYYMMDD.log` in memory before flushing to disk.
  - Also, `g_grind_ent_sent_this_tick` (`ea/grind_engine.mqh:2074-2075`, `handoffs/Handover/02_TRAPS.md:2745-2747`) limits the EA to **one entry order per tick** (and `Grind_FeedStaleAfterTick` at `ea/grind_pure.mqh:255-262` seeds `last_feed_tick_msc` on the first tick after attach).
  - Therefore, after clicking `OK` in `s7`, wait ~5-10 seconds (at least 3 ticks on that symbol so `Grind_FeedStaleAfterTick` seeds on tick 1, long `L0` places on tick 2, and short `L0` places on tick 3; and right-click `Experts` -> `Open` if needed to flush MT5's file buffer) before running the `s7` log-checker command and checking for both resting `L0` orders.

#### 4. `s3.1-3.2` (`docs/runbooks/twoarm-build-e.md:139-141`): Account `1514878887`'s 14-Day Trial (`7-21 Oct`) May Already Have Expired Before `21:00Z` Wed 21 Oct

- **Runbook text (`docs/runbooks/twoarm-build-e.md:7`, `docs/runbooks/twoarm-build-e.md:21`, `docs/runbooks/twoarm-build-e.md:139-141`):**

```7:7:docs/runbooks/twoarm-build-e.md
| Status | **DRAFT for review** (Claude, 18 Oct ~04:45Z). Built from D's and C's REVIEWED runbooks (`twoarm-build-d.md` `c39d59d`, `twoarm-build-c.md`), the box recipe (`handoffs/Handover/06_LINUX_WINE_BOX.md` s3, s9, s10) and the last FTMO switch (`ftmo-ic-start.md` s3-s12, run 7 Oct) |
```

```21:21:docs/runbooks/twoarm-build-e.md
| E5 | FTMO free trials run 14 days from the first trade; opening a new trial meant closing the old one in FTMO's client area (7 Oct, 1514731800) | `ftmo-ic-start.md` s12 (s4, s5) | RECORDED |
```

```139:141:docs/runbooks/twoarm-build-e.md
1. The carry pass for every fleet as usual (BOOT s6), A's seven included: then A is no longer needed.
2. **A's final status** (pipshed status read, fresh URL segment, plain text; saved whole): live, halts,
   `api_count`, balance, equity, open MTM. VPS Toolbox: balance, equity, positions, orders (written here).
```

- **Missing fact:**
  - Account `1514878887`'s 14-day FTMO free trial started on **Wed 7 Oct** (`docs/runbooks/twoarm-build-e.md:7`, `docs/runbooks/twoarm-build-e.md:21`). Depending on the exact hour on 7 Oct when the first trade started the 14-day clock (or FTMO's trial expiry check), FTMO may disable trading (`SYMBOL_TRADE_MODE` no longer `FULL`) or disconnect `1514878887` **before** the `20:50-20:59Z` carry pass on Wed 21 Oct.
  - If `1514878887`'s trial expires earlier on Wed 21 Oct, A's `20:50-20:59Z` carry pass (`s3.1`) will skip shifting exits (`Grind_CarrySessionReady(symbol)` returns `false` when `SYMBOL_TRADE_MODE != SYMBOL_TRADE_MODE_FULL`), which is benign because `1514878887` is being retired in `s3.3`; `s3.1` should note that an already-expired trial on `1514878887` does not block proceeding to `s3.2`-`s3.5`.

#### 5. Additions Needed on `s11` (`STOP` List, `docs/runbooks/twoarm-build-e.md:253-260`)

```253:260:docs/runbooks/twoarm-build-e.md
## 11. STOP (before the next step)

D's s8 list, all of it, plus: the box clock not UTC or not synchronised; `wine --version` not 9.0; `cmp bad`
not 0; a compile not 0 / 0; the presets fingerprint not `a448f4abb8a6` or any MISMATCH; a key not 44 bytes or
not `fc6b3d9c56a8`; a login not on `FTMO-Demo`, a netting account, or a balance not $10,000; the suite not
2597 / 2597, or GVs not empty after it; any `STARTUP_EXIT_SHORTFALL` at a flat attach; a row other than
`rebuild=false/false`; s4.1 showing an unpushed commit or a tag not on origin (the VPS is not destroyed
then); an FTMO email about requests or a breach.
```

- Add to `s11`:
  - Any of the 6 symbols (`GBPUSD`, `EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, `CADCHF`) missing from Market Watch (`s5`/`s7`) or with spread `>= 2 x OPT width` at attach (`s7`).
  - `Show trade levels` still ticked in `Tools -> Options -> Trade` (`s1.8`).
  - MT5 still running on the Windows VPS when `s4.2` zips `MQL5\Logs` and `logs`, or `profiles\gvs.dat` omitted from `$Z.zip`.
  - Any `telemetry dropped` line (`telemetry dropped since FROM` != `0`) in `s7`.

Line count: 1137
