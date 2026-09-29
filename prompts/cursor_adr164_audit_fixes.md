This message has a line count at the bottom

# CURSOR -- ADR-164 POST-AUDIT FIXES (event-path order, window clamp)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor
chat. Branch `adr164-deal-replay`, head `6e49b87` (the DeepSeek response
on top of `7ff1c97`; suite 2350/2350 on GBPUSD and EURUSD at `7ff1c97`).
`git pull --ff-only` first; STOP if the head is not `6e49b87`. Written by
Claude from source at `6e49b87`, 28 Sep ~23:45 ET.

**Gemini: GA1 and GA2 at the end are for you (reply only if you object).
Cursor: start only when the operator says so.**

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| F1 | The event path marks a deal SEEN (`Grind_ReplayMarkSeenIfOurs`, its own select) BEFORE `Grind_ProcessDeal` selects it again (archive, then each handler). If a later select of the same ticket failed, the deal would be seen, never handled, and skipped by every sweep: the C76 failure again (DeepSeek T-2). The trigger needs `HistoryDealSelect` to succeed and then fail on the same local ticket microseconds later: not observed (ASSUMED by DeepSeek), but the reorder is two lines | `grind_engine.mqh` `Grind_OnTradeTransactionEngine` | VERIFIED in source; trigger INFERRED |
| F2 | With the reorder, any residual transient errs the SAFE way: processed but not seen -> the sweep replays it -> the handler's processed list and the SQ4 guards absorb it; the second `fill_log` row is dropped by pipshed's `UNIQUE (instance_id, deal_ticket)`. It also closes DeepSeek T-1's inverse case | same | VERIFIED in source |
| F3 | `Grind_ReplayWindowFrom` computes `last_sweep_time - margin_s`; the seed computes `init - GRIND_REPLAY_MARGIN_S`. If the time is below 120 (e.g. `TimeCurrent()` 0 at an init before any quote) and MQL5 `datetime` arithmetic wraps, `from` becomes huge, `HistorySelect` fails, the last sweep time never advances: the sweep is dead until restart (DeepSeek T-2). Whether `datetime` wraps is UNKNOWN; DR10 cases 4-5 measure it | `grind_replay.mqh` | VERIFIED in source; wrap UNKNOWN |

## 1. WHAT TO CHANGE

**1a (F1, F2).** `Grind_OnTradeTransactionEngine`: move
`Grind_ReplayMarkSeenIfOurs(trans.deal, magic);` to AFTER the
`Grind_ProcessDeal(...)` call. Nothing else in the function changes:
```
if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
if(Grind_ReplayNoteEvent(trans.deal)) { <marker DEAL_EVENT_AFTER_REPLAY>; return; }
Grind_ProcessDeal(trans.deal, <same arguments>);
Grind_ReplayMarkSeenIfOurs(trans.deal, magic);   // still only after its own successful select (GQ2)
```

**1b (F3).** `Grind_ReplayWindowFrom`: `margin_back` = `last_sweep_time -
margin_s` when `last_sweep_time > margin_s`, else 0. `Grind_ReplayInit`:
the seed's `from` = `init - GRIND_REPLAY_MARGIN_S` when `init >
GRIND_REPLAY_MARGIN_S`, else 0. Compare as `long` casts if needed; no
other change.

**1c (test seam, test-only globals in `grind_engine.mqh` next to
`g_grind_hist_test_select_fail_ticket`).**
```
ulong g_grind_hist_test_select_fail_nth_ticket = 0;  // this ticket's Nth select fails
int   g_grind_hist_test_select_fail_nth = 0;         // N (1-based); 0 = off
int   g_grind_hist_test_select_nth_count = 0;        // selects of that ticket so far
```
In `Grind_DealSelect`'s `g_grind_hist_test_active` branch, BEFORE the
existing fail-ticket check: if the ticket equals the nth ticket and N > 0,
increment the count; if the count == N, return false (list unchanged).
`Grind_HistTestReset` clears all three.

## 2. TESTS (add to `ea/fxgrind_tests_adr164.mqh`; call after EQH2)

Same conventions as the spec (`docs/architecture/ADR-164-cursor-spec.md`
s5): both test flags, `Adr164_*` helpers, reset at start and end.

- **DR19_EventSelectTransientNeverLoses.** `Adr164_SeedEntHarness`,
  archive configured, `Adr164_ReplayInitAtI`, ENT_S (L00, 19:27:19)
  appended after init. Seam: nth ticket = ENT_S, N = 4. Deliver its
  DEAL_ADD via `Grind_OnTradeTransactionEngine`, then one timer sweep.
  Derivation (write it as a comment): ENT_S is selected in this order.
  OLD order: 1 mark-seen (ok, marked), 2 archive (ok), 3 long handler
  (ok, side mismatch), 4 short handler (FAILS: no layer); the deal is
  seen, so the sweep skips it: short depth 0, sweep 0 -- LOST. NEW
  order: 1 archive, 2 long handler, 3 short handler (ok: layer appended,
  deal processed), 4 mark-seen (FAILS: not marked); the sweep replays
  it: select 5 ok, the handler returns on the processed list.
  Assertions: `DR19 sweep returns 1`; `DR19 short depth 1`;
  `DR19 one layer for 1970173871` (count of short layers with that
  position == 1). All three FAIL at the tests commit, PASS after 1a.
- **DR10 cases 4 and 5 (probe).** `Grind_ReplayWindowFrom(0, 0, 120)` ==
  0 and `Grind_ReplayWindowFrom(0, 60, 120)` == 0, named
  `DR10 case4 (probe)` and `DR10 case5 (probe)`. At the tests commit
  they PASS if MQL5 `datetime` subtraction does not wrap and FAIL if it
  does: either is a result, report it. Both must PASS after 1b.

Prediction at the tests commit: `2350 + 2 + probes_passing` passed; the
3 DR19 assertions and any failing probe fail; nothing else changes.
After the fix: `2355/2355`.

## 3. COMMITS

1. Tests and the 1c seam (`ADR-164 audit fixes: tests first`): the seam
   globals, the `Grind_DealSelect` branch and the reset are test-only
   and change no existing behaviour (N = 0 by default). Push.
2. 1a and 1b (`ADR-164 audit fixes: mark seen after processing; clamp
   the window`). Push.

The operator compiles in the MetaEditor GUI and runs the suite on the
DESKTOP after each commit. You do not compile or run the suite.

## 4. NEGATIVE SPACE -- DO NOT

- Do not deploy, CLI compile, launch MetaTrader or run the suite.
- Do not `git stash`, check out files from other commits, merge, open a
  PR, `git add .` or `git add -u` (add files by name).
- Do not change any existing test or expected value; if one breaks, STOP.
- Do not change the signatures of `Grind_HandleSideDealFill`,
  `Grind_OnTradeTransactionEngine`, `Grind_ExitQHoldCancelLayer`,
  `Grind_ExitQFindExitDealPosition` or `Grind_ProcessDeal`.
- Do not touch the sweep, the guards, prune, the missed detector, the
  connection step, `fxgrind.mq5`, recon, quarantine, presets or inputs.
- No `HistoryDealSelect` anywhere except inside `Grind_DealSelect`.
- ASCII only. Do not touch pipshed or docs.

## 5. STOP AND REPORT

- The head is not `6e49b87`, or `git diff --stat 7ff1c97 HEAD -- ea/` is
  not empty before you start.
- DR19's derivation does not match the source (the select order differs).
- Anything here contradicts the source: quote both.

## 6. REPORT

Both commit hashes, `git diff --stat 6e49b87..HEAD`, the line count of
each changed file, the new assertions with PF at the tests commit as you
derive them, and every deviation with its reason.

## 7. FOR GEMINI (Cursor: ignore)

DeepSeek's audit (`prompts/deepseek_adr164_audit_response.md` on the
branch) rated T-2 BREAKS and the branch NOT SAFE on F1; Claude rates it a
cheap fix on an assumed trigger. Rejected with reasons (not changed):
T-7 (the sort and scans cover one instance's unseen deals; the exit
burst after a resync is what the lost events would have sent), T-8
(`down_ms` -1 when started disconnected is the spec; a missed event is
reported whoever owns the deal), G4 (`Grind_HistNow` is `TimeCurrent()`,
correct), T-9's DR5 point (DR15 tests the seed).
- **GA1.** Mark SEEN after `Grind_ProcessDeal`, not before. GQ2's
  condition still holds (only after the mark's own successful select);
  the residual becomes a duplicate delivery that the processed list, the
  SQ4 guards and pipshed's unique key absorb. Accept?
- **GA2.** Clamp both window subtractions at 0. Accept?

Line count: 135
