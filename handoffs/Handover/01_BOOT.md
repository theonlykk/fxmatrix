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
mathematical frameworks; finding pathologies before code exists. Reached by the
API through `D:\candlelab\scripts\r1_audit.py`, which Cursor edits and runs --
see `04_DEEPSEEK_COURIER.md` (the old "switch Cursor to DeepSeek" courier is not
how it is actually done).

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

**As of 2026-09-17, ~03:54Z.** Evidence: `HANDOFF_2026-09-17.md` (deploy),
`HANDOFF_2026-09-17b.md` (closes, cap 8, NZD ALT arms).

| | |
|---|---|
| fxmatrix main | `2b570a3` + 17b addendum; EA source at `c39fb84` (ADR-151 Phase A) |
| VPS compiled at | `c39fb84`, 02:15:57Z. **ADR-151 Phase A is LIVE** |
| pipshed main | `4e5bef4` |
| MQL5 suite | **1136/1136** on desktop at `5bc5a88` (baseline 1038 confirmed) |
| Fleet | **16 attached, 0 halted.** NZDCHF never attached. **GBPUSD/EURUSD OPT+ALT at `InpMaxLayers` 8 via dialog; presets still 12 -- fix first (17b s4)** |
| Account | demo 1514582088, hedging, limit 200 on positions + orders; **152/200** at 03:54Z. Daily-loss headroom est. ~$100, UNVERIFIED in MetriX (17b s1) |
| Rollback | `rollback/adr151-k99-r2` @ `f7e2123` (merge, deploy, compile). Never restore the ADR-150 ex5 while any layer is held |

**THE BINDING CONSTRAINT IS NOW THE COMMITMENT GUARD, NOT THE ACCOUNT.**
Entries need `positions + orders + resting_entries <= 194`. It bound at 196
(02:53Z); after the 03:2x closes it is ~183 and entries flow. Exits
need 1 free slot and are unaffected. Capacity design is the next question.

**How ADR-151 behaves, as seen live:** per side only the 2 nearest exits must
rest (+1 may); deeper exits are held (`has_exit_order false`, formula
`exit_target`). A fill places its exit in ~100-200 ms and cancels the exit
that fell to rank 3. One entry send per instance per tick. Halt cancels own
entries. A front-exit release and the hold-cancel race have NOT run yet.

**A compile or reattach clears a halt** (`OnInit`). There is no "parked
across a compile". To keep an instance out, detach it.

**Carry pass is OFF in all 18 presets;** Phase A refuses to start if on.
**That is a live economic leak, not a safe default:** exits must move by
accrued carry (ADR-135b; sweep priced it, `725391f`). Phase B priority is
open -- see `HANDOFF_2026-09-17c.md`.

**Still true:** majors cap 12 / crosses 8 (12 -> 8 is a follow-on ADR, I7
trap; the memo's capacity table does not justify it, see handoff s3); NZDCHF
rejected (ADR-146); cap thresholds 0.0; ARCHITECT s1, s3 and s11 stale.
