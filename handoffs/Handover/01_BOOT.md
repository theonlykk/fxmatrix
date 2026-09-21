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

**As of 2026-09-21 05:10Z, market OPEN.** Evidence: `HANDOFF_2026-09-21.md`,
status read `c70`.

| | |
|---|---|
| fxmatrix main | `29df88f` |
| VPS running | `5454358`, compiled 01:18:50Z 20-Sep. **DETACHED HEAD**. Terminal verified byte-identical, 66 of 66 files |
| Delta main vs VPS | F1 barbell, **ADR-153** (geometry independence, recentre API budget), 12 presets (cycle 2, superseded), tooling. **None deployed** |
| MQL5 suite | `main` **1387/1387**, verified on two charts (GBPUSD, AUDCAD) 2026-09-21. Runs from `MQL5\Scripts\` |
| Fleet | 16 attached, **0 halted**, all `recon_ok` / `invariant_ok`. NZDCHF never attached |
| Book | 104 positions, 60 orders, 30 resting entries. **Guard 194** |
| Account | demo 1514582088, MTM -207; both AUDCAD arms capped short 8/8. **New account Wednesday** |
| Next fleet | **9 pairs x 1 arm, cap 8** -- see `HANDOFF_2026-09-21.md` s2 |
| Carry | OFF in all presets. `OnInit` FATAL guard intact |
| Tags | `vps-19b6faa` (K=1/H=0), `vps-5454358` (current) |
| Second machine | Vultr Ubuntu/Wine box, 207.148.14.197 -- algo OFF. See `06_LINUX_WINE_BOX.md` |

**The stale-offset fix has now run live and priced correctly.** At 21:09:17Z
AUDCAD ALT's capped short side released: the deepest short exit filled
(+0.82), rank rotation promoted L06, and its exit was placed at 0.99414 =
entry 0.99594 - 10 pips exactly, with no stale offset. Fleet-wide
`exit_penetration_pips_mean` 0.0 and `exit_touch_revert_count` 0 through the
Sunday open.

**THE VPS IS IN DETACHED HEAD.** `deploy.ps1` begins with
`git pull origin main` and would reintroduce F1. **Do not run it until you
mean to.**

**`MQL5\Presets` already holds the NEW geometry** (written by
`deploy_presets.ps1`, which injects the telemetry key from
`c:\fxmatrix-local\telemetry.key`, outside the repo because it is public).
Chart inputs still carry the old values: no EA has been attached or detached
since Friday, only compiled, and a compile reinitialises with the chart's
existing inputs. So nothing has changed -- but **reattaching any chart picks
up the new grid, and for six arms that halts the instance.**

**Reattach hazard.** I6 checks every resting exit against the CURRENT
`InpExitPips` (`fxgrind.mq5:149` -> `g_grind_recon_exit_pips` ->
`grind_recon.mqh:502-536`, 2-point tolerance). Six arms change `exit_pips`:
EURUSD OPT, EURUSD ALT, EURGBP ALT, AUDCAD ALT, AUDCHF ALT, CADCHF ALT. All
six hold resting exits priced to the old value. Reattaching any of them with
the new preset fails I6 in `OnInit` and halts in place -- same mechanism as
F1 below. **Until geometry is staged, an emergency reattach must use the OLD
values.**

**Geometry cycle 2 is superseded, not ratified.** It had no spec, no DeepSeek
audit (mandatory for grid spacing, ARCHITECT s2) and no pre-registered
holdout (s12); its derivation is now committed at
`docs/architecture/geometry-cycle2-derivation.md` with a source-review
addendum. Six of its presets cannot start at all: `OnInit` enforces
`add_pips == 2.0 x width_pips` (`fxgrind.mq5:119`, ADR-125).

**What replaces it is geometry cycle 3**, in
`prompts/gemini_memo_geometry_cycle3.md` with Gemini's ruling in
`prompts/gemini_ruling_geometry_cycle3.md`. Objective: maximise pips per day
AND even the distribution across pairs (4.2x top-to-bottom today), judged on
trade volume from fills. Every pair except GBPUSD gets a tighter add; GBPUSD
is the benchmark and same-week control. Open with the operator: keep the
width link (width = add / 2, presets only) or break it (code + ADR); even in
pips or in dollars (`InpLots`); fleet size against the 200 limit.

**The exit question is settled for now.** A pre-registered counterfactual on
the real fills (`prompts/exit_counterfactual_prereg.md`, results in
`prompts/exit_counterfactual_results.md`) found only one clear result --
EURGBP should widen to about 11, pending a swap check. Majors keep 7/10;
crosses inconclusive. Its limit: it held entries FIXED, so it could not see
the entry-volume problem that cycle 3 addresses.

### F1 halted the fleet tonight. It is merged and must not be redeployed.

Deployed 01:08Z, all 16 halted on `I3_LONG_NAKED` within two minutes,
reverted 01:20Z, all 16 recovered with books intact.

**Cause:** the barbell requires an exit on the most underwater layer
(`rank == depth - 1`). Every existing book was built under the PREFIX rule, so
no such layer has one. Reconstruction runs I3 before the queue can place the
missing exits, and **a failed reconstruction in `OnInit` is a PERMANENT halt
in any market**: `Grind_RetryMissingExits` sits in the `else` branch at
`fxgrind.mq5:170`, the halt path sets `g_grind_halted`, `OnTick` does nothing
while halted, and `OnInit` never enters quarantine.

**The shut market was incidental.** The `[Market closed]` lines were the halt
path cancelling ENT orders (`Grind_CancelOwnEntryOrders`), not exits being
refused. The same compile in a live market halts all 16 the same way.
(Corrected 2026-09-20; the first version of this block said the halt was
normally self-healing. It was never checked against source.)

**F1 needs a migration path before it ships.** See `02_TRAPS`.

### What IS live

**ADR-151 K=1/H=0 PREFIX queue.** Per side only the nearest exit rests;
everything deeper is held (`has_exit_order false`, formula `exit_target`).
The most underwater layer has NO resting exit -- that is the defect F1 was
built to fix.

**The stale-offset fix** (`241a905`) -- `GRIND_CARRY_SHIFT_` is now cleared on
cancel and on unclamped placement. Closed a live latent halt that would fire
on a clamp, demotion, then unclamped re-placement.

**F2 held-layer carry accrual** -- `GRIND_CARRY_ACCRUED_<ticket>`, written
only by the carry pass, read by the queue and I6 alongside the clamp shift.
**Inert while carry is off.**

**THE BINDING CONSTRAINT IS THE COMMITMENT GUARD, NOT THE ACCOUNT.**
Entries need `positions + orders + resting_entries <= 194`. Currently 195.
Exits need 1 free slot and are unaffected.

**A compile or reattach clears a halt** (`OnInit`). There is no "parked across
a compile". To keep an instance out, detach it.

**Carry is OFF and that is a known economic leak**, not a safe default. F2
made the mechanism correct; enabling it is a separate decision and needs the
pipshed carry table fixed first -- it builds the pips columns from
`mult_tomorrow`, which is 0 at weekends, so **the table was displaying the
weekend, not a fault.**
