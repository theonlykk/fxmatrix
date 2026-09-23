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
standing ruling. Both were caught by checking. He rules on design, not on
repo mechanics: branch topology and commit layout follow the conventions in
this folder and do not need a ruling.

**His failure mode is not over-agreement, it is reasoning from general
architecture rather than from this codebase.** On 2026-09-18 he proposed
lowering `InpMaxLayers` to shed inventory (this engine cannot close a
position, and lowering the cap below a side's depth trips I7, which is not
quarantinable), and stated that MT5 would fill a passed held-exit target with
positive slippage (a held exit has no order at the broker at all). Both are
correct for a system that is not ours. Both were caught only by reading
source. **The tell is a sign-off with commendations and no questions** --
that means persuasive, not correct.

**And the larger share is ours.** Both of those errors followed premises we
supplied: a retracted operator preference, and a backwards description of the
exit-queue ranking. He ruled correctly on what he was given. State which
claims are verified in source and which are inferred, and flag when a premise
is the operator's judgement rather than a measurement -- especially when that
judgement is finely balanced.

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

**Do not ask Cursor to run the suite in the same prompt that forbids a
compile.** The suite needs a compiled `.ex5`, so the two instructions conflict
and Cursor resolves the conflict by doing more, not less. If the operator is to
compile, say so and say the suite figure is pending -- do not also ask for it.

---

## 3. MACHINES

**Desktop** (`D:\fxmatrix`, `D:\pipshed`) -- the working machine. Git, Cursor,
MetaEditor for compiling and running the suite. **Cursor runs HERE and nowhere
else:** it never touches the VPS or the Surface. An MT5 terminal is installed
and Cursor can drive it; no EAs are attached and algo is OFF, and it stays off.
**It is logged into the same FTMO account as the VPS,** so it sees live
positions, orders and history. A position list or a screenshot taken here is
real fleet data, not a sandbox. Compiling here does NOT reload the fleet; only
the VPS compile does that. Sync sources with `.\desktop_sync.ps1`, which copies
`ea/` into the terminal's Experts and Scripts folders and hash-verifies each
file. There is no git pull step in it: the desktop repo IS the working copy.

**VPS** (`C:\fxmatrix`, terminal hash `81A933A9AFC5DE3C23B15CAB19C63850`) --
**where the fleet actually trades.** Fleet size in section 6, algo ON. Reached by RDP.
`.\deploy.ps1` copies files; **only the MetaEditor compile reloads the EAs**,
and a compile REINITIALISES every attached instance (which resets in-memory
daily counters -- use the archive for daily totals). `deploy.ps1` does NOT copy
`ea\presets\*.set` into `MQL5\Presets`; that is a manual step (17e s4). The
terminal hash above identifies the install path, not the machine: the desktop
install shares it, so it does not tell you which box you are on.

**The VPS PULLS. Do not push from it.** On 2026-09-19 a tag was pushed from
the VPS, which revealed it holds write credentials to the repo. Tags are
additive so no harm was done, but a mistaken `git push` from a machine whose
job is to run could overwrite `main` with whatever state the trading box is
in. **Create tags on the desktop** -- it has the same repo and the SHA is the
same from either box -- and treat any push from the VPS as a mistake.

**Tag every VPS build before deploying over it.** The convention is
`vps-<sha7>` with an annotated message giving the UTC compile time and what
is live:

    git tag -a vps-5454358 -m "VPS build 2026-09-19 20:53Z: ..." 5454358
    git push origin vps-5454358

That makes the restore path `git checkout vps-<sha7>`, `.\deploy.ps1`,
compile -- named rather than remembered. Existing tags: `vps-19b6faa`
(K=1/H=0, carry off), `vps-5454358` (stale-offset fix + F2, carry still off).

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
- **Fail closed.** Invariants halt rather than compound. This applies to input
  defaults too: a kill switch must default OFF so that a missing or stale
  preset leaves a pilot on baseline instead of releasing a change fleet-wide
  (ADR-152 Rollout).
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

You have standing latitude to draft consults to Gemini or to the previous chat
whenever you judge one is warranted. You do not need to ask first.

---

## 6. CURRENT STATE -- REWRITE THIS BLOCK EVERY SESSION

**As of 2026-09-23 00:45Z, market OPEN.** Evidence: `HANDOFF_2026-09-23.md`.

| | |
|---|---|
| fxmatrix main | `95c89c6` |
| pipshed main | `5153977` |
| VPS running | `5454358`, DETACHED HEAD, cycle-2 presets. **Nothing newer deployed** |
| Delta main vs VPS | F1 barbell, **ADR-156 startup exit shortfall**, **ADR-155 commanded ejection (A+B, switch off)**, ADR-153, suite fix, **cycle-3 presets** (9 x OPT), `scripts/grind_gv_clean.mq5`, tooling |
| MQL5 suite | `main` **1538/1538**, GBPUSD. Runs from `MQL5\Scripts\` |
| Fleet | 16 attached (cycle 2), 0 halted. AUDCAD rolled four times by hand -- see `docs/runbooks/roll-log.md` |
| Account | demo 1514582088, $10k, FTMO daily limit $500 -- **worst day -$420**. Nothing in the EA enforces it (backlog C17) |
| **Next** | **Close out cycle 2** (`docs/runbooks/account-close-out.md`), then start cycle 3 when its readiness gate is met (`docs/runbooks/cycle3-start.md`). **No deadline between them** |
| After that | Cycle-3 readiness gate: C17 breaker, C24/C19 pipshed, A5, carry ON in presets, pre-registration amendment. C15 ejection DONE (dormant) |
| Carry | OFF in all presets |
| Second machine | Vultr Ubuntu/Wine box, 207.148.14.197 -- algo OFF. See `06_LINUX_WINE_BOX.md` |

**Wednesday deploys `3f72b9f`: F1 + ADR-156 on a FLAT book.** F1 must
still never go onto a book built under the PREFIX rule (the 2026-09-20
halt, 02_TRAPS).

**F1 changed what a RESTART needs; ADR-156 answers it.** The barbell
requires an exit on `depth - 1`. Before ADR-156, `OnInit` halted
permanently on any missing required exit, and EVERY manual roll produced
one. Now startup rebuilds, places the missing exits, and logs `WARN
STARTUP_EXIT_SHORTFALL`; the OnTick check stays strict. Caveat: ticks
during a close-only window can still escalate quarantine to a halt
(backlog C18) -- no restarts near rollover.

**THE VPS IS IN DETACHED HEAD** until Wednesday. `deploy.ps1` begins with
`git pull origin main`. Do not run it before the runbook says so.

**Cycle-2 books (VPS, until Wednesday):** `MQL5\Presets` already holds
new geometry and the chart inputs hold the old values. Reattaching any
cycle-2 chart with the new preset halts on I6 for the six arms whose exit
changed. An emergency reattach before Wednesday must use the OLD values.
The VPS build (`5454358`) is PREFIX rule, so rolls there are safe.

**Geometry cycle 3** is pre-registered in
`docs/architecture/geometry-cycle3.md` (nine pairs, one OPT arm, cap 8,
lots 0.01). ADR-153 removed the `add == 2 x width` rule; `OnInit` guards
add/width inside [0.5, 4.0]. Exit and cap may not change mid-cycle
(I6/I7); add, width, stranded and deadband may (amendment A1).

**Cycle 4 idea** (not scheduled): live per-side geometry search,
`docs/architecture/cycle4-live-geometry-search.md`.

**Live on the VPS until Wednesday:** `5454358` -- ADR-151 K=1/H=0 PREFIX
queue, the stale-offset fix (`241a905`), F2 carry accrual (inert, carry
off).

**Standing facts.** The binding constraint is the commitment guard
(entries need `positions + orders + resting_entries <= 194`; exits need 1
free slot). A compile or reattach clears a halt and re-runs `OnInit`.
Carry is OFF in every preset -- decided after the C10 measurement.
