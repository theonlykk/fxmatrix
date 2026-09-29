This message has a line count at the bottom

# CURSOR -- ADR-164 AUDIT FIXES, ROUND 2 (fail-count signal, deferred init)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor
chat. Branch `adr164-deal-replay`, head `32e2a96`. `git pull --ff-only`
first; STOP if the head is not `32e2a96`. Written by Claude from source
at `32e2a96`, 29 Sep ~00:05 ET. Not yet compiled or run by the operator.

**Gemini: GB1 and GB2 at the end are for you. Cursor: start only when
the operator says so.**

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| R1 | Round 1's premise (Claude's, accepted by Gemini as GA1) was WRONG. Moving mark-seen after processing does not close DeepSeek T-2: if the HANDLER's select fails and the later mark-seen select succeeds, the deal is seen and never handled, exactly as before. `Grind_ProcessDeal` returns true whatever its handlers did | `grind_engine.mqh` `Grind_ProcessDeal`, `Grind_OnTradeTransactionEngine` at `32e2a96` | VERIFIED in source |
| R2 | Cursor's DR19 models exactly that case (4th select = the short handler) and WILL FAIL at `32e2a96`: selects are 1 ProcessDeal's new top select, 2 archive, 3 long handler, 4 short handler FAILS, then `Grind_ProcessDeal` returns true and mark-seen (5) marks it seen. Its 3 non-guard assertions fail | `fxgrind_tests_adr164.mqh` DR19 | VERIFIED by derivation |
| R3 | DR20 (fail on select 1) also fails at `32e2a96`: the new top select in `Grind_ProcessDeal` is select 1, so nothing is processed and nothing is seen, while DR20 expects seen, depth 1, sweep 0 | DR20 | VERIFIED by derivation |
| R4 | `Grind_ReplayWindowFrom` at `32e2a96` returns 0 when `init_time <= 0`. With a server time of 0 at init, every sweep selects the account's WHOLE history from epoch and replays every unseen deal of this magic: ENT deals of long-closed positions append GHOST layers and place exits for them. On `7ff1c97` the same init either does that once (signed `datetime`) or kills the sweep (wrapping `datetime`). Whether `TimeCurrent()` can be 0 in `OnInit` is unverified (likely only before a terminal's first ever connection), but the outcome must be safe | `grind_replay.mqh` `Grind_ReplayWindowFrom`, `Grind_ReplayInit` | VERIFIED in source; trigger UNVERIFIED |

Cursor's round-1 deviations KEPT: `Grind_ProcessDeal` returns `bool`;
its top select and symbol/magic filter; the call-count seam
(`g_grind_hist_test_select_fail_on_call`, `g_grind_hist_test_deal_select_call`).

## 1. WHAT TO CHANGE

**1a (R1).** A select-failure counter, test and live alike:
```
int g_grind_deal_select_fail_count = 0;   // next to g_grind_deal_test_active
```
In `Grind_DealSelect`, EVERY branch that returns false increments it
(the hist-test branch, the deal-test branch and the live
`HistoryDealSelect`). `Grind_ProcessDeal`: take
`const int f0 = g_grind_deal_select_fail_count;` as its FIRST statement;
keep the top select and filter (return false); after the halted return
and after the handlers, `return (g_grind_deal_select_fail_count == f0);`
(also on the halted path). The event path and the sweep stay as at
`32e2a96`: mark seen / replayed only when `Grind_ProcessDeal` returns
true. A deal whose handler could not select it is left unseen; the next
sweep replays it and the processed list, the SQ4 guards and pipshed's
`UNIQUE (instance_id, deal_ticket)` absorb whatever had already happened.

**1b (R4).** Deferred init. New global `bool g_grind_replay_init_pending`
(cleared by `Grind_ReplayReset`). In `Grind_ReplayInit`, after the reset:
if `Grind_HistNow() <= 0`: set pending true, leave ready false,
`Grind_ArchiveMarker("WARN", "REPLAY_INIT_DEFERRED", "", 0, "{}")`,
`Print(Grind_LogTag(), "WARN GRIND_REPLAY init deferred: no server time")`,
return 0. `Grind_ReplayOnTimer`, FIRST statement:
`if(!g_grind_replay_ready && g_grind_replay_init_pending && Grind_HistNow() > 0) Grind_ReplayInit(magic, now_ms);`
Deals older than the deferred init's time minus 120 s are never
replayed (they are in the book or they are history).

**1c.** `Grind_ReplayWindowFrom`: DELETE `if(init_time <= 0) return 0;`
(init time is never 0 once ready). Keep the margin clamp
(`last_sweep_time <= margin_s` -> `init_time`).

## 2. TESTS (commit 1 of this round; tests only)

Conventions as the spec s5. Derive every assertion against `32e2a96`.

- **DR19** unchanged. At `32e2a96`: `not seen on handler select fail`,
  `sweep 1`, `depth 1` FAIL; `depth 0 (guard)` passes.
- **DR20** REWRITTEN as `DR20_MarkSeenSelectFailErrsToDuplicate`: fail
  on call 5 for ENT_S (1 top, 2 archive, 3 long, 4 short: layer
  appended, 5 mark-seen FAILS). Assertions, all `(guard)` (the round-1
  reorder already handles this case): depth 1 after the event; not seen;
  a timer sweep returns 1; still exactly ONE short layer with position
  1970173871 (the replay is absorbed by the processed list).
- **DR10**: replace `DR10 init zero` with `DR10 init zero natural`:
  `(0, 19:30:00, 120)` == `19:28:00` (FAILS at `32e2a96`: it returns 0);
  add `DR10 probe 0 0 (guard)`: `(0, 0, 120)` == 0 and
  `DR10 probe 0 60 (guard)`: `(0, 60, 120)` == 0.
- **DR21_InitDeferredWithoutServerTime (NEW).** `g_grind_hist_test_now = 0`;
  `Grind_ReplayInit` -> `DR21 not ready when deferred` (FAILS at
  `32e2a96`: it sets ready); `DR21 deferred marker` (exactly one
  `REPLAY_INIT_DEFERRED`; FAILS); `DR21 sweep while deferred 0 (guard)`.
  Then append an OLD deal of ours (deal 1583900001, order = position
  1970000001, `GRIND|OPT|S|L00|ENT`, `D'2026.09.20 10:00:00'`) and ENT_S
  (L00, 19:27:19); set now = I (19:27:00); call `Grind_ReplayOnTimer(<P>,
  5000)`. `DR21 ready after timer (guard)`; `DR21 old deal not replayed`
  (FAILS at `32e2a96`: the window from epoch replays it); `DR21 ENT_S
  seeded not replayed` (FAILS at `32e2a96`). Then LAYER_L00, EXT_L
  (19:27:22), now = 19:27:35, a timer sweep: `DR21 later deal replayed
  (guard)` (returns 1).

Prediction at the tests commit (on `32e2a96` code): 2368 run, 2360
passed, 8 failed = DR19 x3, `DR10 init zero natural`, DR21 x4 (not
ready, marker, old deal, ENT_S). Every FAIL name lacks "(guard)".
After the fix: 2368/2368. Report your own derivation if it differs.

## 3. COMMITS

1. `ADR-164 audit fixes 2: tests first` (s2 only). Push.
2. `ADR-164 audit fixes 2: select-failure count, deferred init` (s1). Push.
The operator compiles in the MetaEditor GUI and runs the suite on the
DESKTOP after each commit. You do not compile or run the suite.

## 4. NEGATIVE SPACE -- DO NOT

- Do not deploy, CLI compile, launch MetaTrader or run the suite.
- Do not `git stash`, check out files from other commits, merge, open a
  PR, `git add .` or `git add -u`.
- Do not change any test other than DR10, DR20 and the new DR21; if any
  other breaks, STOP.
- Do not change the signatures of `Grind_HandleSideDealFill`,
  `Grind_OnTradeTransactionEngine`, `Grind_ExitQHoldCancelLayer` or
  `Grind_ExitQFindExitDealPosition`.
- Do not touch the guards, prune, the missed detector, the connection
  step, `fxgrind.mq5`, recon, quarantine, presets or inputs.
- No `HistoryDealSelect` anywhere except inside `Grind_DealSelect`.
- ASCII only. Do not touch pipshed or docs.

## 5. STOP AND REPORT

The head is not `32e2a96`; a derivation in s2 does not match the source
(quote both); anything else here contradicts the source.

## 6. REPORT

Both hashes, `git diff --stat 32e2a96..HEAD`, line counts of changed
files, every new or changed assertion with its PF at the tests commit as
you derive it, every deviation with its reason.

## 7. FOR GEMINI (Cursor: ignore)

GA1 (round 1) rested on Claude's premise that moving mark-seen after
processing makes every residual a duplicate. It does not (R1): a handler
select that fails followed by a mark-seen select that succeeds still
loses the deal. Your ruling repeated that premise ("mathematically
guarantee"); Cursor's test DR19 exposed it before any run.
- **GB1.** Signal "processed" by a select-failure counter across
  `Grind_ProcessDeal` (no handler signature change): false if any
  `Grind_DealSelect` failed during it, so the deal stays unseen and is
  replayed; duplicates are absorbed. Accept?
- **GB2.** With no server time at init, DEFER the replay init to the
  first timer call that has one, instead of a window from epoch (R4:
  ghost layers) or a dead sweep. Residual: a deal that fills while the
  terminal has never had a server time is seeded, not replayed (the
  C76 gap, in a doubly rare case). Accept?

Line count: 142
