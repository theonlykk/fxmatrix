This message has a line count at the bottom

# ADR-156 -- STARTUP EXIT SHORTFALL: PLACE, THEN CHECK

**Status:** Approved by Gemini 2026-09-21 (rev 2 folds in his ruling,
`prompts/gemini_adr156_ruling.md`). DeepSeek audit pending (it changes
when orders are placed; ARCHITECT s2). Backlog C2.
**Base:** `main` `5124bd2`. All line numbers below are at that SHA.

---

## 1. PROBLEM

F1, the barbell exit queue, requires a resting exit on rank 0 AND on rank
`depth - 1` (`Grind_ExitQRequired`, `grind_exitq.mqh:49-59`). At startup
`OnInit` runs `Grind_ReconstructState()`. If any REQUIRED rank has no exit
coverage, I3 fails and the instance halts in place (`fxgrind.mq5:175-180`).
`Grind_RetryMissingExits` is only in the `else` branch, so nothing ever
places the missing exit. A reattach fails the same way. **The halt is
permanent until the code changes.**

Three ways to reach it on the new account:

| # | trigger | how often |
|---|---|---|
| T1 | **Manual roll** (`docs/runbooks/manual-roll.md`): close the deepest layer, reattach. The new deepest is the old middle layer, which the barbell leaves uncovered | EVERY roll |
| T2 | Restart (compile, reattach, VPS crash, terminal crash, Windows Update) inside the gap between a deepest-exit fill and the placement for the new `depth - 1`. Placement is in the same handler (`grind_engine.mqh:1410`, `:1437`), so the gap is normally milliseconds | rare |
| T3 | Restart while an exit is held back by a gate: slot limit (`Grind_SlotExitAllowed`, `grind_exitq.mqh:169`, `used <= limit - 1`), broker reject, shut market | rare, but can last hours |

T2 and T3 also existed for rank 0 under the prefix rule. F1 widens them,
and T1 is new with F1. Cycle 3 plans mid-cycle reattaches (group A Friday
2026-09-25, group B Tuesday 2026-09-29), and C17 ships by a compile of all
nine instances at once.

---

## 2. SOURCE FACTS THE DESIGN RESTS ON

- **F-1.** The rebuild already gives an uncovered layer a formula exit
  target: `grind_recon.mqh:1091-1096` (long) and `:1107-1112` (short) call
  `Grind_ExitQFormulaTarget`. So a book rebuilt WITHOUT the coverage
  requirement is well formed. The requirement is the only thing
  standing between rebuild and placement.
- **F-2.** `Grind_RetryMissingExits` (`grind_engine.mqh:1530-1536`) is
  `Grind_ExitQManageSide` on both sides. It places every rank that
  `Grind_ExitQRequired` demands, `depth - 1` included.
- **F-3.** The I3 coverage test appears TWICE on the rebuild path: in
  `Grind_RebuildBookFromTicketsInner` (`grind_recon.mqh:1033-1043` long,
  `:1050-1060` short), then again in `Grind_ReconCheckInvariants`
  (`:493-497` long, `:520-524` short).
- **F-4.** The OnTick invariant path (`fxgrind.mq5:280-292`) calls
  `Grind_CheckBookInvariants()`, which calls the SAME rebuild. I3 is
  quarantinable (`grind_quarantine.mqh:37`). While quarantined, OnTick
  runs `Grind_RetryMissingExits` when `Grind_GuardsAllowTrading` allows
  (`fxgrind.mq5:297-301`). Escalation to halt needs >= 3000 ms AND >= 3
  checks.
- **F-5.** The feed-staleness guard blocks ONE tick only.
  `Grind_FeedStaleAfterTick` (`grind_pure.mqh:231-242`) compares against
  the previous tick and then updates it. After `OnInit`,
  `g_grind_last_feed_tick_msc` is 0, so the first call returns "not
  stale". This closes the 02_TRAPS note that called the post-weekend
  retry UNVERIFIED.
- **F-6.** `Grind_ReconstructState()` has two callers: `OnInit`
  (`fxgrind.mq5:175`) and `Grind_TestStubHaltPath` (`:333`).
  `Grind_CheckBookInvariants()` does not call it.

---

## 3. DECISION

**At startup only, a missing exit on a REQUIRED rank is a shortfall to
place, not a halt.** Everywhere else, I3 stays exactly as it is.

1. `Grind_RebuildBookFromTicketsInner`, `Grind_RebuildBookFromTickets` and
   `Grind_ReconCheckInvariants` take a new last parameter,
   `const bool tolerate_exit_shortfall = false`. When it is true, the
   `no_exit_coverage` I3 branch is skipped (F-3, all four sites).
   Nothing else changes. When it is false, behaviour is byte-for-byte as
   today.
2. The rebuild counts skipped layers PER SIDE in two new globals,
   `g_grind_recon_exit_shortfall_long` and `_short`. Both are reset to 0
   at the start of every rebuild and counted ONLY in the Inner loop
   (`:1033-1060`), so a layer is counted once, not twice.
3. `Grind_ReconstructState()` passes `true`. `Grind_CheckBookInvariants()`
   keeps the default `false`.
4. In `OnInit`, after a successful reconstruction with any shortfall:
   print one WARN line and write one archive marker
   `WARN STARTUP_EXIT_SHORTFALL` with detail `{"long":a,"short":b}`. If
   EITHER side's shortfall is 2 (with K = 1 that is every required exit on
   the side), also call `Grind_TelemetryCritical` with event
   `STARTUP_EXIT_SHORTFALL_SIDE`. The decision is a pure helper,
   `Grind_StartupShortfallCritical(long_n, short_n)`. **No halt** (Gemini
   ruling item 3, revised). Then the existing `Grind_RetryMissingExits`
   runs (it is already in the `else` branch).
5. The first OnTick runs the STRICT check. If the placement worked, the
   check passes. If it did not, the instance enters quarantine, retries
   each tick, and halts after 3 s and 3 checks if the exit still cannot be
   placed. That is today's OnTick behaviour for any missing exit, so C2
   adds no new halt path and removes one.

**This IS place-before-check** (02_TRAPS, "The rule"): rebuild without
the requirement, place, then check under the full rule on the first tick.

---

## 4. WHAT DOES NOT CHANGE

- I3 `no_position`, I1, I2, I4, I5, I6, I7 and I8 still fail
  reconstruction at startup and still halt.
- The OnTick check is strict. The quarantine constants, the list of
  quarantinable reasons and `Grind_ExitQRequired` are untouched.
- No new order type, no new placement path, no input and no preset
  change. Exits are placed only by the existing `Grind_ExitQManageSide`.
- The halt path, `Grind_CancelOwnEntryOrders` and telemetry for a real
  failure are all unchanged.

---

## 5. CONSEQUENCES

- **T1 fixed.** A manual roll's reattach rebuilds cleanly, then places the
  new deepest exit. `manual-roll.md` becomes valid again once this is
  live.
- **T2 and T3 fixed** for startup. An exit that cannot be placed ends in
  the same quarantine-then-halt as it would without a restart.
- **Weekend restart** (VPS maintenance with the market shut): the rebuild
  passes, placement fails (market closed), and no ticks arrive so there is
  no escalation. At the open the first tick quarantines and retries (F-5:
  not stale), the second tick passes.
- **Risk: a bug that drops exits is now invisible at startup.** It is not
  invisible for long: the strict OnTick check sees it on the first tick,
  and the archive marker records the count. A shortfall on a clean flat
  start is a defect signal.

---

## 6. TESTS (hand-derived; exit 3.0 pips, point 0.00001, magic 22260101)

Fixtures: long ENT positions L0 1.25000, L1 1.24900, L2 1.24800. Long
ranks sort by the lowest entry, so L2 is rank 0 and L0 is rank 2, the
deepest. EXT orders sit at entry + 0.00030. Short mirror: S0 1.25000, S1
1.25100, S2 1.25200. S2 is rank 0 and S0 is the deepest. EXT sits at
entry - 0.00030.

| id | book | call | expect |
|---|---|---|---|
| X1 | long, EXT on L2 + L0 | strict | ok, shortfall 0 |
| X2 | long, EXT on L2 only | strict | FAIL `I3_LONG_NAKED` |
| X3 | long, EXT on L2 only | tolerant | ok, shortfall 1; L0 rebuilt `exit_target` 1.25030, `exit_order_ticket` 0 |
| X4 | ROLL: L1 + L2 only, EXT on L2 only | strict / tolerant | FAIL `I3_LONG_NAKED` / ok, shortfall 1 |
| X5 | short, EXT on S2 only | tolerant | ok, shortfall 1; S0 `exit_target` 1.24970 |
| X6 | long no EXT at all + short EXT on S2 only | tolerant | ok, shortfall 3 |
| X7 | long, EXT on L2 + L0, L0's EXT at 1.25040 | tolerant | FAIL `I6_LONG_EXIT` |
| X8 | X1 + EXT order for layer 5, no position | tolerant | FAIL `I4_LONG_ORPHAN_EXIT` |
| X9 | X2, 10-argument call (default) | default | FAIL `I3_LONG_NAKED` |
| X10 | helper truth table | -- | (2,1) T, (0,2) T, (1,1) F, (1,0) F, (0,0) F; on X6 counts T, on X3 and X4 counts F |

Shortfalls are per side (long/short): X1 0/0, X3 1/0, X4 1/0, X5 0/1,
X6 2/1. X3-X6 and X10's TRUE cases must FAIL against a stub that accepts
the parameter and ignores it, and a helper that returns false.
X1, X2, X7, X8 and X9 are regression locks that pass in both states.
Report them as such.

---

## 7. QUESTIONS FOR REVIEW -- ANSWERED (Gemini, 2026-09-21)

Q1: all required ranks (approved). Q2: no halt; critical telemetry when a
side's shortfall is 2 (revised after the reconsider memo: `INIT_FAILED`
unloads the EA, add/width cannot create a shortfall, and a halt would
recreate the unrecoverable state). The quarantine-counting issue is out
of scope, for a separate ADR. Q3: open, for DeepSeek (T-2).

Original questions:

- Q1. Should the tolerance cover rank-0 shortfalls too, or only
  `depth - 1`? It is proposed as ALL required ranks: rank 0 is T2/T3
  under the old rule too, and placement is identical.
- Q2. Is a WARN marker enough, or should a shortfall above some N (for
  example more than 2 per instance) halt anyway, as a sign that something
  wiped many exits at once?
- Q3. Any path where `Grind_RetryMissingExits` inside `OnInit`, which runs
  before `Grind_MaeInit` and `Grind_CapPublishOwnExposure`, depends on
  state not yet initialised? It already runs there today.

Line count: 186
