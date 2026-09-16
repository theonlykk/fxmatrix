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
**where the fleet actually trades.** Fleet size in section 6, algo ON. Reached by RDP.
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

**As of 2026-09-16, ~16:00Z.** Reasoning and evidence: `HANDOFF_2026-09-16.md`.

| | |
|---|---|
| fxmatrix main | `46b1749` (ADR-150 sixteen-magic tables, NZDCAD/AUDNZD presets) |
| VPS compiled at | **UNKNOWN** -- ADR-150 is EA code; check `config_events` before assuming |
| pipshed main | `4e5bef4` -- dashboard rings rendered from `GRIND_RINGS` |
| MQL5 suite | 1038 per ADR-150 text; SUMMARY not re-pasted -- treat as unverified |
| Python suites | 71 as of 09-15, plus `scripts/verify_dashboard_rings.py` in pipshed |
| Fleet | 14 EAs attached: EUR/GBP/USD and AUD/CAD/CHF triangles (12) + NZDCAD OPT + AUDNZD OPT. NZDCAD ALT and AUDNZD ALT DETACHED 2026-09-16 with residual positions and exits. NZDCHF never attached |
| Account | demo 1514582088, hedging, **ACCOUNT_LIMIT_ORDERS=200 on positions + orders** |

**THE BINDING CONSTRAINT IS THE ACCOUNT LIMIT, NOT API REQUESTS.** At 200
positions+orders the terminal refuses new orders locally (retcode 10040,
`duration_ms=0`). The refused order is an EXIT, the layer goes I3_NAKED, the
3 s quarantine cannot outlast the limit, the instance halts. Three halts on
09-16 (NZDCAD_ALT 12:55Z, AUDNZD_ALT 12:59Z, GBPUSD_OPT 14:09Z). Book ~190 at
session end. **No new instances until exits outrank entries in the EA**
(DeepSeek + Gemini required). API requests are fine: ~23/hour fleet-wide.

**Detached ALT residuals.** Five positions with exits resting. On this hedging
account a filled exit OPENS an opposite position; nothing nets it while
detached. Close By by exact ticket only -- the pair table is in the handoff
s3. OPT trades within pips; a Close By against an OPT ticket halts OPT.

**Layer cap.** GBPUSD/EURUSD run 12, crosses 8. Lowering is under discussion,
not decided. I7 halts immediately if depth > cap on reinit, and a resting add
at the new cap index is kept and would fill to cap+1. See handoff s7.

**ADR-150's calibration-only exception was never ruled by Gemini.** AUDNZD
ALT 7/7 matches neither barbell peak.

**Still true from 09-15:** NZDCHF REJECTED (ADR-146), presets not to be
attached. Cap thresholds 0.0; leg-isolated (ADR-149) but arming now needs a
per-currency judgement (topology non-uniform; today's largest concentration
was short USD). AUDJPY carry figures before ADR-147 are VOID. Barbell arms
approved (ADR-148), not deployed on any pair.

**ARCHITECT s1 and s11 are stale** (L0 re-quote; cap missing-GV semantics).
Correct them before the next Gemini or DeepSeek brief.

**Suite count is a BASELINE, not just a gate.** `Test_I5g_L2ReconstructionPasses`
re-runs L2's assertions; a regression in `Grind_RebuildBookFromTickets`
presents as a lower TOTAL, not a FAIL line.
