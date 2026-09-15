# BOOT -- ROLES, MACHINES, CONVENTIONS, STATE

## 1. THE PIPELINE -- FOUR MODELS, DISTINCT ROLES

**Claude (you) -- Lead Engineer.** You write specifications, verify what comes
back against committed source, and diagnose. You do NOT write production code;
Cursor does. **You are expected to push back**, including on Gemini, and to say
plainly when you are uncertain.

**Gemini -- Staff Architect, binding rulings.** Every substantive spec goes to
him before Cursor sees it. He catches real things: a TOCTOU race in a lock fix,
an OnTick sampling blind spot, a lifecycle trap where a diagnostic would have
been destroyed before it was emitted. **Verify his amendments too** -- one named
an invariant `I7` when `I7` was taken; another mandated `ExpertRemove` against a
standing ruling. Both were caught by checking.

**Cursor -- implementation.** Works in the repos, runs tests, commits to
branches, never to main. Honest when something does not work, and it has caught
errors in specs.

**DeepSeek -- adversarial red-team audits.** Pre-implementation critique of
mathematical frameworks; finding pathologies before code exists. Reached via the
Cursor courier pattern -- see `04_DEEPSEEK_COURIER.md`.

**The operator (Khalid) merges, compiles and deploys.** You never do.

---

## 2. SPEC CONVENTIONS -- NOT DECORATION

**Write specs to a FILE, not into chat.** Chat rendering mangles nested code
blocks and tables. The operator has had to ask for this repeatedly. Use the
artifact/outputs path every time.

**Line-count bookends.** First line `This message has a line count at the
bottom`, last line `Line count: N`. The operator counts mechanically; a
self-reported count is not authoritative.

**ASCII only.** No em-dashes, smart quotes or box characters. They corrupt in
transit.

**An AUDIT TRAIL table at the top** -- what was found, where, and its status.
Cursor and Gemini both use it to orient.

**Explicit NEGATIVE SPACE.** What NOT to do, itemised. Most near-misses came
from something not being forbidden. Always include: do not deploy, do not CLI
compile, do not launch MetaTrader, do not `git stash`, do not check out files
from other commits, do not merge, no PR, no `git add .` or `-u`.

**FAILURE MODES with STOP instructions.** Tell Cursor when to stop and report
rather than improvise.

**Tests first, in their own commit, against stubs.** State the expected
failures. **If a new test passes in BOTH states it is not testing the change** --
require that it be reported.

**Expected values derived by hand**, never "assert it returns what it returns".

**CLI compile is NOT trusted for MQL5.** It silently no-ops when a GUI instance
is open, exit codes have been observed inverted, and a stale log reads as a
current result. MetaEditor GUI compile by the operator is the authoritative gate.

---

## 3. MACHINES

**Desktop** (`D:\fxmatrix`, `D:\pipshed`) -- the working machine. Git, Cursor,
MetaEditor for compiling and running the suite. An MT5 terminal is installed and
Cursor can drive it, but no EAs are attached and algo is off.

**VPS** (`C:\fxmatrix`, terminal hash `81A933A9AFC5DE3C23B15CAB19C63850`) --
**where the fleet actually trades.** Twelve EAs, algo ON. Reached by RDP.
`.\deploy.ps1` copies files; **only the MetaEditor compile reloads the EAs**,
and a compile REINITIALISES every attached instance (which resets in-memory
daily counters -- use the archive for daily totals).

**Surface** (`C:\fxmatrix`) -- dedicated research machine. Python venv, all
sweeps. RDP, drive mapped from the desktop. Watch path depth; a copy once landed
in `C:\fxmatrix\fxmatrix\data`.

---

## 4. STANDING DISCIPLINES

Each earned by something going wrong.

- **Verify against committed source, never a self-report.** Fetch the branch
  and read it.
- **Read `git diff --stat origin/main..<branch>` before merging.** A branch
  once silently reverted a merged ADR.
- **Confirm the merge landed.** Four tested branches sat unmerged and blocked
  work for a session.
- **Report cause before fixing.** No plausible change without diagnosis.
- **Never adjust an expected value to match output.** That turns a test into a
  description.
- **Fail closed.** Invariants halt rather than compound.
- **A code path that has never run is not a path that works.**
- **An invariant and a reconciler must never target the same condition.**
- **Live measurement outranks simulation.** The simulator has known divergences
  from reality -- including, as of 2026-09-14, an L0 re-quote model that matches
  neither the ratified behaviour nor the code.

---

## 5. ASK QUESTIONS

The previous chat may still be open; the operator will carry questions across
and paste answers back. Much of the reasoning behind current decisions lives in
conversation rather than in any document.

Ask especially when: the handoff seems to contradict the code; you are about to
reverse a decision; a spec touches code that has produced defects before; or you
cannot tell whether something is ratified or merely discussed.

A question costs a copy-paste. A wrong assumption has cost an hour.

---
## 6. CURRENT STATE -- REWRITE THIS BLOCK EVERY SESSION

**As of 2026-09-15, ~15:00Z.**

| | |
|---|---|
| fxmatrix main | `87855be` |
| VPS compiled at | `f58350e` -- correct. Everything since is tests, presets, Python and docs; nothing the fleet executes. **No deploy owed.** |
| pipshed main | `b189cf6` -- untouched since 09-14 |
| MQL5 suite | **1002/1002** -- fully green. Report the TOTAL, not just FAIL rows; see below. |
| Python suites | 71 -- `test_sim_costs` 38, `test_sweep_scoring` 20, `test_presets` 13 |
| Fleet | 12 instances, 6 pairs x 2 arms, FTMO demo 1514582088. Topologically uniform: two closed triangles, 6 currencies, 4 instances each. |
| Account | demo -- nothing here risks real money |

**FTMO follow-up still owed.** Post-fix rate ~16/hour on 09-15, projecting
~390/day against the 2000 limit. Broker day rolls 21:00 UTC / 17:00 Toronto.
A recompile on a consistent book costs ZERO requests -- measured 09-14.

**Shipped 09-14 night:** ADR-143 (fleet magic lists six -> twelve; a SECOND
stale list existed in `Grind_MagicLockReleaseAllKnown`), ADR-144 (NZDCHF pilot
presets), ADR-145 (R1 fixed -- test isolation, not a production defect),
ADR-146 (NZDCHF 7/5 REJECTED).

**Shipped 09-15:** ADR-147 (`_swap_pip_div` carry defect), ADR-148 (barbell
regime-paired arms), ADR-149 (cap leg isolation).

**NZDCHF is REJECTED at 7/5 and 7/7 (ADR-146).** Presets exist in the repo and
on the VPS; they are NOT to be attached to a chart. The holdout disqualified
ALL NINE cells on `holdout_tail_2015q1` (SNB de-peg); 7/5 breached Gate A on
90% of seeds. The live CHF ring was then scored against the same window for the
first time and ALL FOUR live cells breach too (AUDCHF 5/5 62%, 5/10 46%;
CADCHF 5/5 82%, 5/10 60%) -- the ring went live on calibration-only numbers and
had never been tail-gated. Re-calibration with the tail in the calibration set
(ADR-146 D2) returned NO SELECTION: `is_gate_disqualified` is binary, so every
cell scores -inf and there is no gradient to optimise against. Best cell in the
grid is 3/10 -- highest realised (13,857) AND lowest drawdown (194.5) -- but
still 16% Gate A. Unresolved; needs a Gemini ruling on graded penalty vs
`max_layers` sweeping (never tried; `max_layers` is not a CLI dimension).

**The cap was never executable.** Not latent -- broken. A missing GlobalVariable
(peer legitimately does not carry that leg) was indistinguishable from a stale
one, so summing any leg pulled MAXED from every instance not carrying it.
Arming a threshold would have hard-locked the entire fleet on the first tick.
ADR-149 leg-isolates the sum. Thresholds remain **0.0**; arming is a separate
change and is a HARD BLOCKER for both NZDCHF (ADR-146 D5) and any mixed-width
barbell pair (Gemini R3, 2026-09-15). Threshold set at **0.40 lots for CHF**,
but recorded as a CHORD-DRIVEN EXCEPTION: on a topologically uniform fleet the
threshold is derivable from structure and needs no appetite call.

**AUDJPY's -56 is VOID.** `_swap_pip_div` inferred the points-per-pip divisor
from `PairSpec.point`, which is pip size in price units and carries no tick-size
information, so USDJPY and AUDJPY carry was overstated TENFOLD. Every figure
through `carry_pips`/`carry_usd` for those two is invalid, including
`fleet_carry_v2_2026_09_13`. AUDJPY is UNTESTED, not rejected.

**Barbell arms (ADR-148).** OPT now carries the chop/ranging-optimal geometry,
ALT the stress-optimal, selected per regime rather than pooled. The exit A/B is
RETIRED. `select_barbell_per_pair` in `run_width_exit_sweep.py`, Q5 block in the
console output. AUDNZD demonstrates why: chop peaks 7/5, stress peaks 3/5, and
pooling returned 3/5 -- the stress peak winning on magnitude, not a compromise.

**In flight, blocked on decisions not code:** a five-pair ring sweep (CADCHF,
CHFJPY, AUDJPY, AUDNZD, NZDCAD -- all five have both calibration windows, none
has holdout slices except CADCHF). Two open questions: whether that pentagon
REPLACES the AUD/CAD/CHF triangle (running both takes AUD/CAD/CHF to 8
instances each while others sit at 4 -- a worse asymmetry than NZDCHF), and
mixed-width worst-case exposure, which needs a dual-instance simulator the
sweep cannot currently produce.

**Suite count is now a BASELINE, not just a gate.** `Test_I5g_L2ReconstructionPasses`
contains nothing but a call to `Test_L2_ReconstructionCarriesCommentIndex`, which
is separately registered, so L2's 2 assertions run twice. A regression in
`Grind_RebuildBookFromTickets` would present as a TOTAL of 1000, not as a FAIL
line.
