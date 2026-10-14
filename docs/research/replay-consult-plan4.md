This message has a line count at the bottom

# CONSULT: THE REPLAY AFTER PLAN 3's FAIL -- TWO CAUSES, TWO FIXES, A PLAN 4 (FOR GEMINI)

| | |
|---|---|
| Written | 14 Oct 2026 ~03:35Z (HANDOFF s82), by Claude (Lead Engineer), at the operator's request |
| What it is | A consult BEFORE any spec or prompt. Nothing here is ruled. No code changes until you rule and the operator agrees |
| Repos | `theonlykk/fxmatrix`: `main` `83689e9` (plan 3's record); `replay-harness` `efada62` (harness code `145f092`, frozen for plan 3) |
| Read with it | `docs/research/replay-calibration-eurusd-3.md` (plan 3: s3 the marks, s4 what a result means, s7 the verdict note of 14 Oct ~03:10Z); `ea/fxgrind_replay_core.mqh` at `efada62`; `research/replay/results/plan3/holdout_score_145f092.md`, `holdout_compare_145f092/misses.csv`; backlog C152 |
| Evidence words | MEASURED (from data files named), READ IN SOURCE (file and lines given), INFERRED (Claude's reading, not checked) |

## 0. FIRST, AN ACCESS CHECK (if you can read the repo)

Before anything else, quote these two things exactly, or say you cannot read them:

1. `ea/fxgrind_replay_core.mqh` at commit `efada62`, the `else if(rd.kind == "OUT_BY")` branch
   (about lines 2571-2579).
2. The first line of `research/replay/results/plan3/holdout_score_145f092.md` at `83689e9`.

If you cannot read the repo, work from this file only and mark every claim about our code as
"from the consult, not read". Reason from THIS codebase, not from how replays or brokers
usually work: where the two differ, the code wins.

## 1. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| A1 | Plan 3 FAILED on T1 only: B 67 / 69 = 97.1%, C 68 / 72 = 94.4%, D 56 / 59 = 94.9% (mark >= 95%; replay-only <= 5%). T0, the count, bias and difference marks pass; counts S 10/10, 15/14, 16/17, 14/14, R and A equal | `results/plan3/holdout_score_145f092.md` | MEASURED |
| A2 | Nine real deals missed after the cut (9 Oct 04:32Z): five at the Mon 12 Oct open, four elsewhere (s3) | `results/plan3/holdout_compare_145f092/misses.csv` | MEASURED |
| A3 | The open: Friday's last quote 23:56:59.456 server, ask 1.12019; Monday's first 00:00:00.188, bid 1.11847 / ask 1.11903; the next quotes 00:01:00.170 and 00:01:00.372 (the same prices), then 00:02:00.174 | ticks `ticks_53077984_EURUSD_w2h.csv` (not in git; sha256 in `inputs/eurusd_holdout.sha256`) | MEASURED |
| A4 | Live, IC filled the resting buy limits above 1.11903 at 00:01:00.640-00:01:00.700, all at 1.11903, and did the close-bys at 00:02:00.456-457. The replay filled them at 00:00:00.449 at each order's own price (B long L7 1.11909, B short exit L5 1.11917, C long L8 1.11911, C short exit L2 1.11921, D short exit L5 1.11907) | `inputs/eurusd_holdout/real_eurusd_*.csv`; `runs_holdout/eurusd_*_sync_145f092/` | MEASURED |
| A5 | IC does not trigger pending orders on the 00:00 quote, only from the 00:01 quotes | -- | **INFERRED**. The symbol's trade session has NOT been read yet (the operator will read it from the terminal's Specification window) |
| A6 | In both windows (1-14 Oct) the only live EURUSD fills within 5 minutes of a midnight are those of the Mon 12 Oct open. No fill happened at the 5 Oct open, so the calibration never met this case | real deals of `inputs/eurusd_20261008` and `inputs/eurusd_holdout` | MEASURED |
| A7 | The timed replay fills any touched order on any tick, at the order's own price, at the tick time plus a latency: `Rpl_TmBrokerStep` (core 1117-1135; `rec.price = Rpl_BkPriceAt(ticket, t)`, `Rpl_TmEnqueueDealEvent(t + g_rpl_tm_lam, ...)`). It knows no trade session | `ea/fxgrind_replay_core.mqh` | READ IN SOURCE |
| A8 | SYNC applies the real deals before the broker and EA steps of each tick (`Rpl_ProcessOneTickTimed`, core 2762-2763). In `Rpl_ApplySyncDealsUpTo` (core 2539-2595) an `EXT` row removes the side's newest layer at that number from the true book, and `Rpl_SyncResetToTrueBook` then resets the engine's book. So the layer leaves the engine's book at the EXIT deal's time | `ea/fxgrind_replay_core.mqh` | READ IN SOURCE |
| A9 | FREE models the close-by's completion as its own timed stage, `CB_DONE` (`Rpl_TmRunCloseByDoneHandler`, core 1005-1020; `Rpl_ProcessCloseByDone`, 2291) | `ea/fxgrind_replay_core.mqh` | READ IN SOURCE |
| A10 | Live, after a short exit fills with the long side at 8, the EA sends: CLOSE_BY; then the long side's roll (MODIFY, REMOVE, PENDING); then the new first short (L0). The replay's sync run sends the same orders at the same prices except the L0, which it places earlier, on an earlier quote | sends `sends_EURUSD_OPT{C,D}_2026-10-13_2210.jsonl`; `runs_holdout/eurusd_{c,d}_sync_145f092/out_*_orders.csv` | MEASURED |
| A11 | Caution on clocks: a send's `ea_time_ms` (UTC; + 3 h for server) can read about 1 s BEFORE the broker's deal time it follows (D 13 Oct: CLOSE_BY sent 16:57:02.114, the exit deal 16:57:03.252). Compare sends with deals by ORDER and PRICE, not by milliseconds | the same files | MEASURED |
| A12 | In both D cases (s3) the FREE run matched live: L0 placed at 1.11800 (live 1.11800), moved to 1.11780 and 1.11760 at 14:07:11 / 14:11:48 (live 14:07:10 / 14:11:47), filled 14:18:16 (live 14:18:15); the long L7 entry 1.11895 filled 16:57:10.2 (live 16:57:10.2). C's free run had taken another path by then, so C cannot be checked this way | `runs_holdout/eurusd_d_free_145f092/` | MEASURED |

## 2. CAUSE 1: THE WEEKLY OPEN (five of nine misses)

**Example in prices.** B has a buy limit (long layer 7) resting at 1.11909 over the weekend.
Monday's first quote, 00:00:00.188, has the ask at 1.11903, below it. The replay fills it at
00:00:00.449 at 1.11909. IC filled it at 00:01:00.640 at 1.11903. The match rule needs 60 s
and 0.2 pip; these are 60.2 s and 0.6 pip apart: one MISS and one replay-only deal. The same
moment gives two such pairs on B, two on C and one on D.

## 3. CAUSE 2: SYNC TAKES THE LAYER OUT AT THE EXIT, NOT AT THE CLOSE-BY (four of nine)

**Example in prices** (C, Mon 12 Oct, server time). C's short L0 exit fills at 17:16:14, at
1.11720, with the long side at 8.

- **Live:** CLOSE_BY; two long rolls (MODIFY, REMOVE, PENDING); then the new short L0 sell
  limit at **1.11737**. It is never moved, and fills at 17:23:06 at 1.11737.
- **Replay, sync:** the layer leaves the book at the exit (A8), so the rolls and the new L0
  come a few seconds early, on an earlier quote: L0 at **1.11740**, 0.3 pip higher. At 17:18:28
  (mid about 1.11699) both orders are beyond the 3-pip stranded threshold and the L0's target
  is 1.11719. From the replay's 1.11740 that is a 2.1-pip move, at least the 2-pip deadband, so
  it modifies; from live's 1.11737 it is 1.8 pips, under the deadband (strict `<`), so live's
  stays. The replay's L0 fills at 1.11719 at 17:20:05. A 0.3-pip difference at placement
  became a deal three minutes early at another price.

| case | live L0 / order | replay sync L0 / order | what followed |
|---|---|---|---|
| C 12 Oct 13:00 | 1.11822 | 1.11823 | the bid reached 1.11822 (13:02:03.879), not 1.11823; live filled 13:02:04 and sync then took live's fill and removed its own order |
| C 12 Oct 17:16 | 1.11737 | 1.11740 | the example above |
| D 12 Oct 14:01 | 1.11800 | 1.11798 | re-quoted at other moments (14:07:24, 14:12:18 vs live 14:07:10, 14:11:47) to 1.11757 vs 1.11760; filled 14:15:21 vs live 14:18:15 |
| D 13 Oct 16:57 (long L7 entry) | 1.11895, never moved | moved to 1.11894 at 16:57:05 after the close-by | the ask reached 1.11895 (16:57:09.939), not 1.11894 before the replay removed it (16:57:11.667): live filled 16:57:10, the replay never did |

Claude's reading (INFERRED from A8-A12, not proven): every one of the four is the sync run
acting on a book that live did not yet have, because sync drops the layer at the exit deal.
The free run, which models the close-by as a stage (A9), matched live where it could be
checked (A12).

## 4. FIXES CLAUDE PROPOSES (NOT RULED; NO CODE YET)

- **F1, the weekly open.** The broker step does not fill a pending order before the symbol's
  trade session opens (Monday 00:01:00 server if A5 holds: an input read from the
  specification, not a constant in code); and an order the market has gapped through fills at
  the quote (ask for a buy limit, bid for a sell limit), not at its own price. F1 changes the
  free run as well as sync. Close-bys at the open (live 00:02:00) need a rule too.
- **F2, sync and the close-by.** In sync, an `EXT` row does not take the layer out of the true
  book; the real `OUT_BY` rows (already in `real_*.csv`) do, at their own time. So between an
  exit and its close-by the engine sees the book live saw. F2 changes SYNC only (T1); the free
  run and every count are untouched.
- Both are harness changes: a prompt, your ruling, Cursor, the suite, the calibration window
  re-run (it must still pass T0 and T1 and reproduce P5's counts), then plan 4 (s5).

## 5. PLAN 4, ITS SHAPE (PROPOSED)

- The same question, marks, match rule, tolerances and scorer as plan 3 (no mark is relaxed).
- **A NEW window, pre-registered before any of it exists.** Proposal: from Thu 15 Oct 00:00
  server (after US CPI, 14 Oct 08:30 ET = 15:30 server) to Tue 20 Oct 22:00Z; it contains the
  Mon 19 Oct open (F1's test) and the German ZEW (20 Oct). Export Tue 20 from 22:10Z, as plan 3.
- Plan 3's record stays FAIL. The plan 3 holdout becomes development data (seen), as the
  calibration window is; neither is evidence for plan 4.
- Risks: IC access (backlog C150; the terminals still log in); B, C, D stay frozen (no geometry
  change in the window); one feed (P7).

## 6. NEGATIVE SPACE

- No fleet action, no EA change, no change to plan 3's record or its scorer's outputs.
- No change to T1's 95%, the 60 s / 0.2 pip match, the count tolerances or the cut rule for
  plan 3. For plan 4, a mark changes only by your ruling, with reasons, BEFORE its window opens.
- No fix tuned on plan 4's window. No code before you rule and the operator agrees.
- This is not a Cursor prompt. Do not write code.

## 7. QUESTIONS (attack the premises; say which fact is missing)

- **G4-1.** Are the two causes right? Check A7-A9 in the source. Is there a third mechanism in
  the nine misses that we have folded into these two?
- **G4-2.** F1: should the session come from the symbol's specification as an input, and is
  "fill at the quote when gapped through" right for IC's limit orders? Should the daily
  rollover (00:00 each night) be gated the same way, given A6 shows no fill there to test it?
- **G4-3.** F2: removing the layer at the real `OUT_BY` time vs modelling the close-by's delay
  as the free run does. Which is right for a run whose purpose is to follow live? What could F2
  break: `ROLL` rows, the roll gate, the exit queue, a re-roll in the same second?
- **G4-4.** Fixing causes found on the holdout, then testing on a NEW window with the plan 3
  record left as FAIL: is that sound? What status should the calibration and plan 3 windows
  have after the fixes?
- **G4-5.** The window: start after CPI (proposed) or include it and say so in advance? Does
  n = 3 in the tolerance still fit a window of about 3.9 server days?
- **G4-6.** T1 at 95% on 59-72 deals a fleet: one deal is 1.4-1.7 points. We do NOT propose
  changing it. Is it a sound gate at this size? Rule only with reasons, and only before the
  window opens.
- **G4-7.** What fact is missing?

Line count: 130
