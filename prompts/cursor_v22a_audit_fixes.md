This message has a line count at the bottom

# CURSOR PROMPT -- v2.2a POST-AUDIT FIX: THROTTLE RECON_SCAN_RACE (DeepSeek T-3)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat
in that workspace. Branch `v22a-recon-api`, at the commit that carries
THIS file (on top of `1997d73`, the DeepSeek response; EA code ==
`24b886d`, suite 2508/2508 on GBPUSD and EURUSD). Background: the
v2.2a prompt `prompts/cursor_v22a_c93_c100.md` and the audit
`prompts/deepseek_v22a_audit_response.md` (T-3). Written by Claude from
source at `1997d73`, 3 Oct ~18:30Z. Line numbers are that code.

## 0. RESTATE AND STOP (do this first, then wait)

1. `git fetch origin`; `git switch v22a-recon-api`; `git pull --ff-only`.
   `git diff --stat 24b886d HEAD -- ea/` must be EMPTY. If not, STOP.
2. Restate each change in s2 in ONE line, quoting this prompt's words,
   and list every test name in s4 with its assertion count.
3. Then STOP. Do not edit anything until the operator replies "go".

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | The collector emits `RECON_SCAN_RACE` (archive marker) and a `WARN GRIND_RECON_SCAN` Print on EVERY raced walk, with no throttle: `if(Grind_ReconScanRaced(dupes_total, walks)) { ... }` | `ea/grind_recon.mqh` 1317-1321 | VERIFIED |
| A2 | It runs on every tick of every instance while not halted, and once at init | DeepSeek G6, verified | VERIFIED |
| A3 | The archive queue holds `g_grind_archive_queue_max` = 5000 events per instance; when full, `Grind_ArchiveEnqueue` drops the OLDEST event (`Grind_ArchiveQueueRemoveFront(1)`) | `ea/grind_archive.mqh` 19, 262-283 | VERIFIED |
| A4 | `Grind_ArchiveTick()` returns `GetTickCount64()`, or `g_grind_archive_test_tick` when `g_grind_archive_test_tick_active` (tests) | `ea/grind_archive.mqh` 118-123 | VERIFIED |
| A5 | Test helpers: `Grind_ArchiveTestReset()`, `Grind_ArchiveTestConfigureCommon()` (archive ON, test tick 1500), `Grind_ArchiveQueueCount()`, `Grind_ArchiveQueuePeek(i)` | `ea/grind_archive.mqh` 36; `ea/fxgrind_tests.mq5` 5761-5773 | VERIFIED |
| A6 | Globals of `grind_recon.mqh` sit at its top (`g_grind_recon_exit_shortfall_short`, 30); `#define GRIND_RECON_SCAN_MAX_WALKS 3` at 36; `Grind_ReconScanDetail` at 1263 | `ea/grind_recon.mqh` | VERIFIED |
| A7 | Last v2.2a test call: `Test_AL7_PublishAndCheck();` (`fxgrind_tests.mq5` 9444); `fxgrind_tests_v22a.mqh` ends at `#endif` (276) | as listed | VERIFIED |

## 1. WHAT TO BUILD (summary)

The race note is reported at most once a minute per instance, and the
marker says how many races were NOT reported since the previous one
(`"suppressed":N`), so nothing is lost: the races in a period = the
markers + the sum of their `suppressed`. The first race after start is
always reported. Detection, the walk loop, deduplication and every
trading path are unchanged.

## 2. CHANGES

| # | File | Change |
|---|---|---|
| X1 | `ea/grind_recon.mqh` | after `#define GRIND_RECON_SCAN_MAX_WALKS 3` (36): `#define GRIND_RECON_SCAN_WARN_MIN_MS 60000` and three globals: `ulong g_grind_recon_scan_last_warn_tick = 0;` `bool g_grind_recon_scan_warned = false;` `int g_grind_recon_scan_suppressed = 0;` |
| X2 | `ea/grind_recon.mqh` | after `Grind_ReconScanDetail` (1263-1267): `bool Grind_ReconScanWarnDue(const ulong now_tick, const ulong last_tick, const bool warned, const ulong min_ms)` returns `!warned \|\| now_tick < last_tick \|\| now_tick - last_tick >= min_ms` |
| X3 | `ea/grind_recon.mqh` | after X2: `void Grind_ReconScanNoteReset()` sets the three X1 globals to `0`, `false`, `0` |
| X4 | `ea/grind_recon.mqh` | after X3: `bool Grind_ReconScanNote(const int dupes, const int walks, const bool stable)` as in s2.1 |
| X5 | `ea/grind_recon.mqh` | in `Grind_ReconCollectBrokerTickets`, REPLACE the whole block `if(Grind_ReconScanRaced(dupes_total, walks)) { ... }` (1317-1321, the `if`, its three body lines and the closing brace) with the one line `Grind_ReconScanNote(dupes_total, walks, stable);`. Nothing else in the collector changes |
| T1 | `ea/fxgrind_tests_v22a.mqh` | append the s4 tests (and the two helpers) after `Test_AL7_PublishAndCheck` and before the `#endif` |
| T2 | `ea/fxgrind_tests.mq5` | call `Test_RN1_WarnDue(); Test_RN2_NoteThrottles();` right after `Test_AL7_PublishAndCheck();` (9444) |

### 2.1 X4 (exact shape)

    bool Grind_ReconScanNote(const int dupes, const int walks, const bool stable)
    {
       if(!Grind_ReconScanRaced(dupes, walks))
          return false;
       const ulong now = Grind_ArchiveTick();
       if(!Grind_ReconScanWarnDue(now, g_grind_recon_scan_last_warn_tick,
                                  g_grind_recon_scan_warned, GRIND_RECON_SCAN_WARN_MIN_MS)) {
          g_grind_recon_scan_suppressed++;
          return false;
       }
       const string base = Grind_ReconScanDetail(dupes, walks, stable);
       const string detail = StringSubstr(base, 0, StringLen(base) - 1) +
                             StringFormat(",\"suppressed\":%d}", g_grind_recon_scan_suppressed);
       Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail);
       Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail);
       g_grind_recon_scan_last_warn_tick = now;
       g_grind_recon_scan_warned = true;
       g_grind_recon_scan_suppressed = 0;
       return true;
    }

`Grind_ReconScanDetail` is unchanged (RS6 still pins it); the marker
detail becomes `{"dupes":D,"walks":W,"stable":S,"suppressed":N}`.

## 3. COMMITS

1. **Tests first, against stubs.** X1, X3, X5, T1, T2 as written. STUBS:
   X2 `return true;` (no other line); X4 = TODAY's behaviour, exactly:
   `if(!Grind_ReconScanRaced(dupes, walks)) return false; const string detail = Grind_ReconScanDetail(dupes, walks, stable); Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail); Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail); return true;`
   With these stubs the EA behaves exactly as `24b886d`. Commit message:
   tests first, the predicted failures (8) and guards (9).
2. **Implementation:** the X2 and X4 bodies as written. Nothing else.

Do not compile (the operator compiles and runs the suite in MetaEditor on
the desktop and reports the counts; do NOT report a suite figure yourself).

## 4. TESTS (append to `ea/fxgrind_tests_v22a.mqh`; F = fails at commit 1, G = passes at both)

Helpers (new, in the same file): `int V22A_CountSubstr(const string needle)`
counts archive queue entries containing `needle` (loop
`Grind_ArchiveQueueCount()` / `Grind_ArchiveQueuePeek(i)`, `StringFind >= 0`);
`string V22A_MarkerNth(const string code, const int nth)` returns the nth
queue entry containing `code`, or `""`.

**RN1 WarnDue** (5): a G `Grind_ReconScanWarnDue(0, 0, false, 60000)` true
(never warned); b F `(1000, 0, true, 60000)` false; c G
`(60000, 0, true, 60000)` true (boundary); d F `(59999, 0, true, 60000)`
false; e G `(500, 1000, true, 60000)` true (clock behind the last warn).

**RN2 NoteThrottles** (12). Start: `Grind_ArchiveTestReset();
Grind_ArchiveTestConfigureCommon(); Grind_ReconScanNoteReset();` (test
tick 1500). Then, in order:
a G `Grind_ReconScanNote(0, 1, true)` false (no race);
b G `V22A_CountSubstr("RECON_SCAN_RACE") == 0`;
c G `Grind_ReconScanNote(1, 1, true)` true (first race, reported);
d G count == 1;
e F `StringFind(V22A_MarkerNth("RECON_SCAN_RACE", 0), "{\"dupes\":1,\"walks\":1,\"stable\":true,\"suppressed\":0}") >= 0`
(stub: no `suppressed`);
`g_grind_archive_test_tick = 11500;` (10 s later)
f F `Grind_ReconScanNote(0, 2, true)` false (throttled; stub reports);
g F count == 1 (stub 2);
h F `g_grind_recon_scan_suppressed == 1` (stub 0);
`g_grind_archive_test_tick = 61500;` (60 s after c)
i G `Grind_ReconScanNote(0, 3, false)` true;
j F count == 2 (stub 3);
k F `StringFind(V22A_MarkerNth("RECON_SCAN_RACE", 1), "{\"dupes\":0,\"walks\":3,\"stable\":false,\"suppressed\":1}") >= 0`
(stub: the second marker is f's, without `suppressed`);
l G `g_grind_recon_scan_suppressed == 0` (reset after a report; stub never
counted).
End: `Grind_ReconScanNoteReset(); Grind_ArchiveTestReset();`.

Totals: **17 assertions; 8 F, 9 G** (RN1 5 = 2F 3G; RN2 12 = 6F 6G). At
commit 1 the operator's suite reads 2525 total, 2517 passing, exactly the
8 F failing; at commit 2 2525/2525. ANY other count, any G failing, or
any existing test changing: STOP and report (s6).

## 5. NEGATIVE SPACE

- Do not change the walk loop, `Grind_ReconAppendUnique`,
  `Grind_ReconScanStable`, `Grind_ReconScanRaced`, `Grind_ReconScanDetail`,
  `RECON_TICKETS`, the API limit code, any invariant, the quarantine or
  any trading path.
- No ticket number in any marker, the heartbeat or telemetry.
- No heartbeat or pipshed change (the count rides in the marker).
- Do not change any existing test or its expected values.
- Do not compile, do not launch MetaTrader, do not run the suite, do not
  CLI compile. Do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no force-push, no `git add .` or `-u`
  (add each file by name). Push the branch after commit 2:
  `git push origin v22a-recon-api`.

## 6. FAILURE MODES: STOP AND REPORT

- Step 0's diff is not empty.
- A line named in s2 is not where or what s2 says.
- A design line conflicts with another (report both; do not choose).
- After commit 1 your re-derivation of any F/G tag disagrees (report
  which; do not change it).

## 7. REPORT

Per commit: hash, files, `git diff --stat`; the 17 assertion names with
their tags; for commit 1 your own re-derivation of each F/G against the
stubs. No suite figure. Then the push output.

## 8. DEEPSEEK'S VERDICTS (`1997d73`) AND CLAUDE'S CHECK

- **G1-G6 VERIFIED**: each re-read in source; agreed.
- **T-1 HOLDS**: agreed (tickets and position identifiers are unique; the
  kind separates a position from its opening order).
- **T-2 HOLDS**: agreed, and checked beyond his list: a skip cannot raise
  `I5_*` (`Grind_ReconLayerIndicesValid` checks negative and duplicate
  indices only, not gaps), `I8` (the pending ticket comes from the same
  list), `I1` (a skip cannot add an exit) or `I6_*_EXIT` (a skipped
  position with a resting exit is `I4` first). A skip of an entry order
  can HIDE a real `AMBIGUOUS_*` for a tick: the accepted GV-2 risk.
- **T-3 NEEDS-FIX ACCEPTED, premise narrowed.** "Many times per tick on
  every instance" overstates it: a race needs another EA's request (or a
  fill) to land inside one walk (well under a millisecond for ~200
  entries, inferred). Estimate: ~1,500-3,000 requests a day per terminal
  x nine instances x a few ticks a second x the walk time = order of a
  hundred raced walks a day per terminal, a burst of perhaps one every
  ten seconds on an FOMC-like day (16 Sep: ~2 requests a second). Far
  below the 5000-row queue (A3), but unmeasured, unbounded, and on the
  path that runs every tick: the throttle above costs little and keeps
  every race counted.
- **T-4, T-5, T-6 HOLD**: agreed.
- **T-7 test gap ACCEPTED in part.** This fix makes the emission and the
  throttle testable (RN2). A seam that lets a test change the broker
  lists mid-walk means test hooks inside the halt-critical collector: its
  own small change, to the backlog (C93 follow-up), not v2.2a. AL7f
  passing against the stub is a guard by design (AL7d catches an
  always-false implementation).
- **PREMISE VERDICT** ("not safe until T-3 is fixed"): v2.2a is not
  merged before the Monday build in any case; with this fix it goes to
  the merge decision after Monday.

## 9. FOR GEMINI (on this prompt, before Cursor starts)

- **GX-1** 60 s per instance (not per terminal): the first race always
  reported, later ones counted in `suppressed`. Too long, too short, or
  should it be per terminal (a Global Variable)?
- **GX-2** A race in the last minute before a halt or restart is counted
  but never reported (the count is in memory). Acceptable, given that a
  halt reports its own failure?
- **GX-3** T-3's premise as narrowed in s8: any reason to expect raced
  walks far more often than estimated (MT5 list updates batched per
  trade transaction, the terminal's own fills)?
- **GX-4** Re-derive RN1 and RN2's F/G tags against the stubs of s3.

Line count: 206
