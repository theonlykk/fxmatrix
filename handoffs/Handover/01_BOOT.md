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

**DeepSeek -- adversarial red-team audits.** Pre-implementation critique and
pre-merge audits of anything that places, moves or cancels orders. Reached by
the API through the in-repo runner `tools/r1_audit/r1_audit.py --config
prompts/<audit>_config.json`; Cursor runs it from a runner task and commits the
inputs and the response (`docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`).
It overstates and mis-assumes: check every verdict against source.

**The operator (Khalid) merges, compiles and deploys.** You never do.

---

## 2. SPEC CONVENTIONS -- NOT DECORATION

**Gemini reads only files ATTACHED to his chat** (no GitHub, no desktop; traps 4 Oct early): send him the document; give verified facts with file and lines.

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

**Every Cursor prompt opens with RESTATE AND STOP (operator, 29 Sep).**
Its first section tells Cursor to restate each change in one line,
quoting the prompt, and to list the tests it adds, then STOP until the
operator replies "go". The prompt is COMMITTED before Gemini sees it and
Cursor is pointed at `prompts/<file>` at that hash, so Gemini reviews the
bytes Cursor reads. One paste per step, for agents too. If Cursor drifts,
the prompt was not good enough: an instruction added outside the
reviewed prompt makes Gemini's review impossible. Before sending, check
every design line against every "do not" line (29 Sep: a prompt that
forbade changing `Grind_ProcessDeal`'s signature while needing it to
report forced Cursor to improvise).

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
`ea\presets\*.set` into `MQL5\Presets`; `scripts\deploy_presets.ps1` does, with the
telemetry key injected (an untracked copy at the VPS repo root is a leftover --
do not run it). The
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
(K=1/H=0, carry off), `vps-5454358` (stale-offset fix + F2, carry still off),
`vps-a01a5d4` (cycle 3: ADR-159 + ADR-160, eleven presets; lightweight, and
created FROM THE VPS on 2026-09-24 against this rule -- do not repeat).

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

**Long chats:** keep working and keep the docs current as you go. Propose
a handoff (docs patch + fresh chat) only when a chat is genuinely near its
limit (replies slowing, earlier detail slipping), not after one or two
pieces of work: the operator found chats rolling over too early
(2026-09-25).

## 6. CURRENT STATE -- REWRITE THIS BLOCK EVERY SESSION

**As of 2026-10-10 ~12:20Z (HANDOFF s78 continued 10): plan 2 RUN (harness `868bcc3`, 448 / 448; timing 0 = Part A byte for byte): T1 PASSES on B, C, D (95.6 / 95.3 / 95.9%); T2 PASSES on B, FAILS on C and D (C 19, D 24 newly unpriced); classification next (plan 2 s14).** **As of 2026-10-10 ~04:40Z (HANDOFF s78 continued 8): fix 6 Part A THROUGH (`cb28224`, 393 / 393, runs `0c7c3e2`: as predicted, T2 unchanged); Part B (`e63753e`) read: seven defects (fix 6 s13 C1-C7), commits 6-8 to come after Gemini's GTP3-1; 448 run.** **As of 2026-10-10 ~03:45Z (HANDOFF s78 continued 7): fix 6 RULED (Gemini s10 + s12, checked); ready for Cursor (Part A H1 first; 445 run at the end of Part B).** **As of 2026-10-10 ~03:40Z (HANDOFF s78 continued 6): Gemini GTP-1..7 on fix 6 checked (s10; four wrong premises); D9 the timer on its own clock, D7 (h), D8 sync, RT60; Copilot's point adopted (per-stage timing rows, RT55 R4 assertion); 445 run; GTP2-1 to Gemini (s11).** **As of 2026-10-10 ~03:05Z (HANDOFF s78 continued 5): `prompts/cursor_replay_fix6.md` written for Gemini (Part A H1 the CB_DONE fix, 393 run; Part B H2 the timing model behind `timing`, 440 run; GTP-1..7).** **As of 2026-10-10 ~02:40Z (HANDOFF s78 continued 4): plan 2 RULED (Gemini s11 + s13, checked): the timing model R1-R5 with R1's price rule, T0 on the order price (`compare.py --t0-price order`), the deal-at-limit sensitivity; next the Cursor prompt (H1, H2) through Gemini.** **As of 2026-10-10 ~02:35Z (HANDOFF s78 continued 3): Gemini GTM-1..8 checked (plan 2 s11); R1 amended: IC prices a deal at the market at the deal time (1046 of 1052; the EA's exits follow the deal price, the harness's deals carry the order price); R5 restated; T0 on the order price proposed (1047 of 1052); GTM2-1..4 to Gemini (s12).** **As of 2026-10-10 ~02:15Z (HANDOFF s78 continued 2): the broker's timing measured from send_logs (`research/replay/measure_timing.py`: sends ~287 ms, close-by 294, remove 43; the deal 261 ms after the touch; the close-by on the first tick after the fill); the second pre-registration drafted for Gemini (`docs/research/replay-calibration-eurusd-2.md`, GTM-1..8).** **As of 2026-10-10 ~02:00Z (HANDOFF s78 continued): Gemini GRC2 checked (plan s12): s8's M1-M3 branch governs, so EURUSD is NOT calibrated under this plan (tick-level not trusted, count-level not allowed: T2 fails) and the holdout does not run. Operator ~01:53Z: a NEW pre-registration (a broker timing model measured from send_logs, the CB_DONE fix, s6's sensitivities; same marks), with 9-13 Oct as its holdout: export and hash only, nobody looks.** **As of 2026-10-10 ~01:50Z (HANDOFF s78, new chat): boot verified in git (`main` `b636b11`, `replay-harness` `6972e16`, code `90fbce4`); the previous chat's twelve answers in; plan s12 ends with GRC2-1..6 for Gemini (which s8 branch governs; does the holdout run with T2 failing; its marks for single segments; fix 6 or freeze; rho's open book). Nothing ruled; no fleet action.** **As of 2026-10-10 ~01:45Z (HANDOFF s77 continued 2, HANDOVER to a new chat): fixes 4 (the replay's order log) and 5 (prices on one grid; sync keeps the replay's own rolls) THROUGH; `replay-harness` `6972e16` (code `90fbce4`), suite 390 / 390. **T1 PASSES on all three fleets** (B 96.0% / 3.4%, C 96.1% / 4.5%, D 96.5% / 2.4%); **T2 FAILS on the UNPRICED share only** (B 31.9%, C 36.2%, D 34.6%; mark 20%). Misses left mostly timing; one small harness defect (a CB_DONE placement cannot fill on the next tick). Two questions for Gemini at the end of plan s12; the harness must be frozen before the holdout.** **As of 2026-10-09 ~23:40Z (HANDOFF s77): fix 3 THROUGH (Gemini three rounds; A3 added: the sync true book rolls its swap and copies each held layer's accrued; `prompts/cursor_replay_fix3.md` `44edcc9`); `replay-harness` `a08fb0d` (code `624a29b`, script `8a58547`), suite 338 / 338; T1 still FAIL but B 92.3% / 3.4%, C 93.0% / 4.2%, D 93.8% / 2.4% (replay-only within 5% on all three); first-pass classification `classified.csv` (open 37: needs the replay's own order log, the next harness prompt). Operator: holdout B / C run on from their 7 Oct inits, scored after 9 Oct 04:32Z.** **As of 2026-10-09 ~21:50Z (HANDOFF s76, HANDOVER to a new chat): fix 3 written and ruled, not yet with Cursor (`prompts/cursor_replay_fix3.md`, `main` `26d9f1f`, 164 lines): seed column 9 `accrued` (the EA's carry ledger GV at each init, 174 / 174 against send_logs; inputs `4bd2f3d`, 66 files), A1 seed it, A2 keep it for sync re-seeds, P1 `tools/replay_run.ps1` (one allowlistable command; replaces the `taskkill`), RT43-RT45 (332). Next: fix 3 through Cursor, rerun, `compare.py`, classify; the holdout's data; Tue 13 round 3 scored.** **As of 2026-10-09 ~21:15Z (HANDOFF s75): the replay RUNS end to end on EURUSD B / C / D (`replay-harness` `b8adb15`, suite 318 / 318; fix 1 the lattice backfill, fix 2 the init's resting book adopted and sync's EXT rule); `research/replay/compare.py` (on the ORDER price): T1 FAIL, B 87.6% / 12.1% replay-only, C 91.1% / 8.4%, D 91.4% / 4.3%; next cause the carry GVs (fix 3). The 1 Oct entry gate DID bind (reporter-only marker; intervals from send_logs). pipshed `--export-sends` (`6ea487e`; send_logs keep 14 days). Carry pass Fri 9 clean. Next: fix 3 and `tools/replay_run.ps1`; the holdout's data (sends, archives, ticks); Tue 13 round 3 scored.** **As of 2026-10-09 ~04:45Z (HANDOFF s74): s73 pushed (`9425141`); T0b PASSED; ROUND 3 RELOADED 04:24-04:32Z on four charts (D EURUSD exit 9 / 11; AUDCHF width 1.5 on B, C, D, C add 5 / 3, D exit 11 / 9), BAD 0; `round3.json` (Mon 12 + Tue 13); the other 23 charts on round 2's geometry. Next: the runner's first real run (harness prompt), carry pass Fri, round 3 scored Tue 13.** **As of 2026-10-08 ~23:35Z (HANDOFF s73): the replay's inputs are BUILT (`research/replay/` build_seeds, build_real, build_inputs; tests first) and committed for the first real run (`research/replay/inputs/eurusd_20261008/`, 29 segments, swaps.csv in EFFECTIVE points to 9 Oct); the swap model made EXACT (nearest snapshot, each night rounded to the cent: 626 of 626; s72's 622 was within a tolerance); ticks w2 (1 Oct 04:00 - 9 Oct 01:30 server, 476,821, sha256 `db2ea94173a4d0c8`, Downloads) equal w1 in time / bid / ask; T0 1052 / 1052 on the scoring export. Round 2 SCORED (cohort equity, GC-1 $1.19); round 3 DECIDED: no promotion, EURUSD L D exit 9, AUDCHF L C add 5 / L D exit 11, AUDCHF width 1.5; reload Fri 9 (four charts), window Mon 12 + Tue 13. Carry pass 8 Oct clean (34 / 34). `main` = this patch on `fc04d59` (s72b on GitHub is `64f5dfa` + `41768bd`, re-hashed: s72's `8b2c878` / `b402142` do not exist).** **As of 2026-10-08 ~20:10Z (HANDOFF s72, HANDOVER to a new chat): the replay's input files have begun in Python (`research/replay/`, tests first, no BOM): `build_swaps.py` (the swap model, 622 of 622 closed EURUSD ENT positions: x3 into Thursday, x0 into Sat / Sun; the EA's carry pass triples one night early, backlog C144) and `build_segments.py` (29 run rows = plan s2's 23 Load segments + 6 compile inits; geometries and IN counts match s2). The archive's `ea_time_ms` is UTC; harness files are server ms. Next: seeds, then `run_<tag>.csv`, `real_<tag>.csv`, `intervals_<tag>.csv`, `swaps.csv` rebuilt to 9 Oct; then the next harness prompt. `main` s72c on `b402142` (s72b).** **As of 2026-10-08 ~19:35Z (HANDOFF s70-s71): the replay harness (engine (c), branch `replay-harness`, last `8cea613`: fixes 1-5, never merged) RUNS its suite on `D:\mt5-replay` (portable copy of the FTMO-branded MT5, IC 53077984 READ-ONLY login; Cursor starts it by `[StartUp]`, .ini UTF-16 LE): rt_53fbe90 267 run, 266 pass (RT15 asserted at the wrong time; fixed in the next prompt). Fix 4: close-bys at the opposite open price, whole profit on the ENT leg (489 of 489 real pairs); the EA's OnInit gate restart; fix 5: wait ~2 s for a non-zero tick value. Plan s4.1 PASSED (one EURUSD feed on B, C, D); s4.2 checks 1-4 done (one interval: D API_SOFT_WARN 1 Oct 19:30:58-21:00Z). Next: the replay's input files (Python), then the runner's first real run. `main` `ef4c662` (tree `d4afded0`). Status 15:11Z: 34 / 34 live; A api 556, 68 scalps, no roll. Backlog C142 (skewed books), C143.** **As of 2026-10-08 ~04:55Z (HANDOFF s68-s69): the replay calibration plan for EURUSD B / C / D (`docs/research/replay-calibration-eurusd.md`) ruled by Gemini; tick dump `w1` on wine-d; T0 PASS 867 / 867; engine (c), an MQL5 harness on the EA's own engine, built by Cursor on `replay-harness` (base, fix 1, fix 2; `fc0fb26`), both files compile 0 errors 0 warnings on the desktop (8 Oct ~04:42Z); fix 3 (E1-E11, Z1-Z5) to Gemini, then Cursor. `main` `1fa85de` (s68k, tree `eb1e5b4b`) + this patch. Open: plan s4.1 comparison hour, s4.2 archive checks, `D:\mt5-replay`.** **As of 2026-10-08 ~01:40Z: HANDOVER to a new chat (HANDOFF s67; its NEXT SESSION list: the replay calibration plan for EURUSD B / C / D first). New in `docs/research/grid-as-variance-trade.md`: s9 the literature read, s10 three scales (W, e, D), s11 the edge ratio rho = (S + R) e / (R D) (random walk 1; hurdle e / (e - c)), s12 calibration before any replay. Operator: no time-series analysis or signals; our own trade history first.** **As of 2026-10-08 ~00:40Z: pipshed C102 LIVE (`d1ad256`, tree `f95f8cc9`): /fleets 0.55-0.70 s (was 9-11 s). Next tonight: the literature; Thu 8: charts (C140).** **As of 2026-10-08 ~00:05Z (HANDOFF s66; the new chat continues): pipshed C137 LIVE (`2385d24`, tree `882c43da`): the Scalps per roll table on pipshed.com (S, R, S/R, k*, k* paid, S/R - k*, per fleet / pair side / window), `/api/g/<token>/sr`, one-minute `state_snapshots` since 00:00Z (migration 005), A on the strip as "FTMO-IC 1514878887" (lattice, commission 0.06), C136 relabelled, C122 fixed. The /fleets slowness is the ejection view (8.7 of 8.8 s; C102, the next fix). Carry pass 7 Oct 34/34 clean. C139 (carry in k*) added.** **As of 2026-10-07 ~22:55Z: HANDOVER to a new chat (HANDOFF s65 end; its NEXT SESSION list: pipshed C137 first). `main` after s65 = `c203758` (tree `965fa76d`) + this patch. New: `docs/research/grid-as-variance-trade.md` (the grid = a corridor variance trade; three dials -> two scales e and D, k* + 1 = D/e).** **As of 2026-10-07 ~22:30Z (Wednesday night; HANDOFF s65: FTMO cycle 3 RETIRED with 1514731800 (detached 21:23Z, dumps taken, account closed); the NEW free trial **1514878887** ($10k) runs the IC strategy STATIC at B's round-2 anchor (`ea/presets/*_opt_a_r2.set`; lattice, re-roll, gate 0, breaker + float gate on, auto-eject off) since 22:08-22:17Z, BAD 0 (`docs/runbooks/ftmo-ic-start.md` s12, Gemini s14; tag `vps-9346e42`); Thu 8 is its first full FTMO day; first-day watch: A's `api_count` > 1,000 by 14:00Z -> tell Claude. C125 ends with Tue 6 + Wed 7 reported, NO verdict (criteria s8). `docs/research/scalps-per-roll.md`: k* = N*a/e - 1, S/R = k* under a random walk (C135); pipshed S/R table + one-minute snapshots (C137) to build; FTMO to Linux at the trial's end (C138).)** Before: **As of 2026-10-07 ~15:20Z (Wednesday; HANDOFF s64: `main` `00cbdaf` (tree `698673c9`). The gate checked in the field to 13:36Z: 59 rolls after the Loads, none while the opposite side held a filled layer; operator: no grace period. **From round 2 the COHORT's EQUITY decides the compass** (layers opened in the round; `research/compass/equity_score.py`; `docs/research/compass-equity-amendment.md` s7, Gemini GQ7-1..4; round 2 end mark Fri 9 Oct 20:45Z; plain equity and realised reported). Before: THE WEDNESDAY BUILD RUN 01:57-02:23Z: B, C, D on `main` (`5bb5fdb` EA code: v2.2a + ADR-166), `InpRollGateOpposite=0` on all 27 IC charts, BAD 0 (runbook s10; event log). Before it: new chat; operator ~20:37Z: the roll gate at 0 on ALL THREE IC fleets, built by `docs/runbooks/wednesday-build-2026-10-07.md` (v2.2a + ADR-166; compile, then F7 + Load of the regenerated `_r2` presets, which now carry `InpRollGateOpposite=0` and the API inputs); round 2 moves to Thu 8 + Fri 9; round 3 reload Mon 12, days Tue 13 + Wed 14. Before: HANDOFF s63: C132 fill slippage built; pipshed C123 + C131 `9b1faba`; v2.2a merged into `main` (`509705f`); ADR-166 roll gate (`InpRollGateOpposite`, default -1 = off) through Gemini, Cursor, the suite (2597/2597) and DeepSeek, merged `d57fe9b`; NOT deployed: IC still runs `2859be6`, FTMO `aa6970a`; IC build Fri 9 Oct with round 3. Before: HANDOFF s62: new chat; the round-2 geometry checked on pipshed at 04:01Z (all 27 IC cells = the table, probes only on their own lever, NZDCAD none); status reads 04:01Z and 14:23Z: 34/34 live, no halt, A 440 requests at 14:23Z; pipshed read through the desktop app's browser pane (traps 6 Oct day). Before: HANDOFF s61: the round-2 reload done 03:18-03:35Z on D, C, B (BAD 0); round 2 = Wed 7 + Thu 8; `round2.json`. Before: HANDOFF s60: pipshed C129 geometry table `b023565`. Before: HANDOFF s59: Gemini on round 2; operator: no promotion this round, the winners repeat as probes; probes as planned; open MTM reported, realised decides; wine-c by F7 + Load; an FTMO C93 halt restarted by F7. Before: HANDOFF s58: round 1 scored, GC-1 $2.55 decides (promoted EURUSD L add 6, AUDCAD L exit 9, AUDNZD S add 7); the Monday build done 22:20-23:21Z: the six IC twins closed by hand, B, C, D on `main` (`2859be6` EA code), re-roll ON on all 27 charts, nine instances per IC fleet; pipshed C119 `96e0fba`; round 2's 27 `_r2` presets `5e7a412` (`646a387` before `git am`; EURGBP L C add 2.5, half pip); FTMO replied on last week's request count (C106). Before: as of 2026-10-05 ~19:45Z (Monday; HANDOFF s57: FTMO GBPUSD halt 13:41-13:52Z (C93 again, repaired by restart); C124 pass probability first run; C125 holdout ACCEPTED: the verdict is FTMO's daily equity over Tue 6 - Fri 9 Oct, FTMO not changed until it; operator: cap 8 this week, tightest widths, deadband 2 on B, C, D, one round-2 reload Tuesday; memo 2026-10-05).** Then (to 7 Oct; history): cycle 3 (FTMO 1514731800, `aa6970a`) ran SEVEN instances, frozen for the C125 holdout (2,000 requests a day, C106); retired 7 Oct 21:23Z. IC B, C, D: nine each on `main` (`5bb5fdb` EA code, v2.2a + ADR-166) since 7 Oct 01:57-02:23Z, roll gate 0, round 2's geometry then (round 3 on four charts from 9 Oct; register LIVE NOW). FXMatrix only: MyFundedPerps PARKED. Operator rulings: IC keeps nine pairs; **the COHORT's EQUITY decides the compass from round 2** (7 Oct ~14:53Z / ~15:07Z; `equity_score.py`; plain equity and realised reported); equity decides the holdout; NZDCAD control; the roll gate on every IC fleet (no ungated fleet); post-once execution with one 2,000-request pool; the 200 positions+orders limit holds on IC too; cap 8 this week; cap 10 and AUDUSD deferred.
Evidence: **s64 (new chat; the gate on all three IC fleets; the Wednesday build runbook)**; `HANDOFF_2026-09-24.md` s26 (1 Oct night: C63, Fleet D), s27 (1 Oct morning: D1), s28 (1 Oct day: CHF trend, C94) s29 (1 Oct evening: ADR-165 merged, the FTMO stall, C97) and **s30 (1 Oct night: IC breaker off; rings, no twins, cap 10)**; **s31 (2 Oct early: carry check, NZDCHF ejects, L0 re-quote)**; **s32 (2 Oct day: pipshed outage and gunicorn; API stop hotfix)**; **s33 (2 Oct afternoon: FTMO warning; cycle 3 to seven)**; **s34 (pipshed clean-up: C107-C109)**; **s35 (handover)**; **s36 (new chat; pipshed saturated; C110)**; **s37 (IC review; tables C113-C115; rulings on the objective and width)**; **s38 (FTMO's day count; exports; rings; post-once execution)**; **s39 (history dumps; 21-pair spreads; compass runbook and cuts)**; **s40 (reported checks; backlog split)**; **s41 (C105 merged; the Monday build prepared)**; **s42 (C93 explained; C107 done)**; **s43 (the v2.2a prompt; handover)**; **s44 (new chat; runbook and register fixed)**; **s45 (v2.2a through Gemini, Cursor, DeepSeek and the suite)**; **s46 (AUDUSD scout; no FTMO email)**; **s47 (AUDUSD presets, geometry, pipshed C121)**; **s48 (mfperp side project; handover)**; **s49 (new chat; answers; docs fixed; round-1 thresholds both reported)**; **s50 (C91 GC-1 built; mfperp parked; cap-10 runbook drafted)**; **s51 (Gemini on the cap-10 runbook; 1.5 widths stand)**; **s52 (IC presets generator; provisional per-side sets)**; **s53 (docs pushed; night wrap-up)**; **s54 (Sunday open; Monday night rehearsed)**; **s55 (pipshed C123 built)**; **s56 (the EUR grind; markout and variance study)**; **s57 (GBPUSD halt; C124; C125 accepted; cap 8 this week)**; **s58 (round 1 scored; the Monday build; C119; round-2 presets)**; **s59 (Gemini on round 2; no promotion)**; **s60 (pipshed C129 geometry table)**; **s61 (the round-2 reload)**; **s62 (new chat; round-2 geometry checked)**; **s63 (C132; pipshed C123, C131; v2.2a and ADR-166 merged)**; s18-s25 for the week before.

| | |
|---|---|
| fxmatrix main | **Now (10 Oct ~04:40Z): this patch (fix 6 s13; s78 continued 8) on `a07974e`.** Before: **(10 Oct ~03:45Z): fix 6 s12 on `2f573d1`.** Before: **(10 Oct ~03:40Z): fix 6 s10-s11 on `d2f30cc`.** Before: **(10 Oct ~03:05Z): the fix 6 prompt on `65292a8`.** Before: **(10 Oct ~02:40Z): compare.py --t0-price and plan 2 s13 on `a42138e`.** Before: **(10 Oct ~02:35Z): M8 and plan 2 s11-s12 on `b8944f6`.** Before: **(10 Oct ~02:15Z): measure_timing and s78 continued 2 on `3e8ef41` (s78 continued).** Before: **(10 Oct ~02:00Z): s78 continued on `70658d9` (s78).** Before: **(10 Oct ~01:50Z): s78 on `b636b11` (s77i, the handover; `6a9bc39` the fix-5 results before it).** Before: **(10 Oct ~01:45Z): s77 continued 2 on `972a5a6` (fix 5 s10). `replay-harness` `6972e16` (code `90fbce4`; never merged). EA code still `5bb5fdb`, live on A, B, C, D.** Before: **(9 Oct ~23:40Z): this patch (s77) on `44edcc9` (fix 3 s11). `replay-harness` `a08fb0d` (never merged). EA code still `5bb5fdb`, live on A, B, C, D.** Before: **this patch (s65 docs) on `9346e42` (7 Oct ~20:15Z, tree `335dadab`: scalps per roll) on `7ebeb60` (~17:08Z, tree `96b7d457`: FTMO-IC presets `926e8df`/`afb65f7` on GitHub + the runbook) on `4ac31dc`. EA code still `5bb5fdb`, now LIVE on A, B, C, D.** Before: **`00cbdaf` (7 Oct ~15:16Z, tree `698673c9`): the cohort equity scorer and amendment (`c898d23` tests first, `7cf9282`, `00cbdaf`); before it `cfeab97` the equity amendment (`a069d24`, `594732d`), `b768583` the gate field check, `82ba9c4` / `80d2cd9` the build record, `565ea53` / `17ed12e` the Wednesday runbook, `10b1222` / `86aefb6` presets with the gate. EA code = `5bb5fdb`, LIVE on B, C, D since 7 Oct.** Before: **after this patch: s63 docs on `d57fe9b` (6 Oct ~20:05Z, tree `e44f78c2`): `--no-ff` merge of `adr166-roll-gate` (tip `5bb5fdb`; EA code on `main` = `5bb5fdb`) into `b63ddce`; before it `509705f` v2.2a merge (`8a3ec0c`, C93 + C100), `24bcc4c` C132, `360ee75` s62 docs.** Before: **s62 docs on `326bfd9` (s61 handover, tree `4ad5178f`; `007eaca` s61 docs; `52e41f4` round2.json + register) on `7551580` (s60).** Before: **s60 docs on `15b5f30` s59 docs (tree `7f454155`), `b438420` round-2 presets without promotion; on `dd71202` s58 docs (tree `343d3a90`): `5e7a412` round-2 presets + register, `e14fd5d` half-pip rule, `6656097` its tests, `613af08` C125 T3 window.** Before: **`7ebcfe8` (5 Oct ~19:35Z): presets stage `round` (`9c0ea540`); `6b15b07` memo; `67e5f02` C125 accepted; `7a52e27` T3 driver; `9672415` C124; `f5f0c93`, `239a45d`, `bb8b81d` (s57).** Before: **docs to 5 Oct ~03:25Z (s56 `54f0738` on `3164070` s55; `f48f66c` s54; `0c266b6` s53; `63b8107` s52; `d3bdf7b` IC presets generator + provisional `_c10` / `_p2` presets, `ee431da` its tests; `c0f833d` s51; `ff4ad7e` s50; `36a7ff3` C91 GC-1 threshold, `e488274` its tests; `38079c9` s49; `9be4bd3` s48; `49fc41e` s47; AUDUSD presets `4694471`); v2.2a prompt `1bb077a` (amended after Gemini); branch `v22a-recon-api` `8a3ec0c` (v2.2a, not merged); EA code `2859be6` (3 Oct: `3df13f0` + `87c9207` + the API hotfix merged, C105); presets `4a1e30e` carry `InpLatticeReroll=true`.** Before: EA code `3df13f0` (1 Oct ~19:10Z) = `--no-ff` merge of `adr165-reroll` (tip `7644941`): ADR-165 `InpLatticeReroll` (default OFF, FATAL without the lattice): with every layer of a capped side rolled, re-roll the rolled layer with the highest VL (long; lowest short), skipping hand-ejected layers, at most one per side per call, none 23:50-00:15 server; `ROLL_ACCEPTED` gains `"reroll"`/`"from_level"`. With the input OFF the EA trades exactly as `0335f25`. Before it: D1 records (`7b85dec`, `de73e46`); `0335f25` = `--no-ff` merge of `adr164-deal-replay` (tip `97a2cd1`) into `9c0217c`. ADR-164 (live on B, C, D): `ea/grind_replay.mqh` (SEEN set; `Grind_ReplayInit` in `OnInit` BEFORE reconstruction, DEFERRED to the first timer call if the server time is 0; sweep on every `OnTimer` and, throttled to 1 s, on the tick path before the quarantine step; markers `DEAL_REPLAYED`, `DEAL_EVENT_AFTER_REPLAY`, `DEAL_EVENT_MISSED` (60 s), `CONNECTION_RESTORED`, `REPLAY_INIT_DEFERRED`); `Grind_ProcessDeal` returns false if any deal select failed during it (the deal stays unseen and is replayed); handler guards (ENT already a layer, EXT already attached); C77: exit-deal lookup reads by ticket. No input. `DEAL_REPLAYED` rows from the timer on healthy days are EXPECTED (the timer ran before the fill's queued event); `DEAL_EVENT_MISSED` is the C76 fault signal. (Running builds: the VPS and Linux boxes rows below.) |
| pipshed main | **Now: `6ea487e` (9 Oct: `--export-sends`; send_logs keep 14 days).** Before: **`d1ad256` (pushed 8 Oct 00:25Z, tree `f95f8cc9`): C102 the ejection view indexed by position, FTMO-day helpers cached (`f601be2` tests); 45/45.** Before: **`2385d24` (pushed 7 Oct 23:55Z, tree `882c43da`): C137 the Scalps per roll table, `state_snapshots` (005 applied), `/sr` export, Server-Timing on /fleets, A = FTMO-IC 1514878887; C136, C122; `8122cff` tests; 44/44.** Before: **`9b1faba` (6 Oct ~15:30Z, tree `b43a77f1`): C123 each side's own add (`ab565be`), C131 `ROLL_STRANDED` "resolved: re-rolled since"; 42/42.** Before: **`b023565` (6 Oct ~02:00Z): C129 the geometry table per pair and fleet (`ad41089` tests; tree `b40a0834`); 40/40.** Before: **`96e0fba` (5 Oct ~23:25Z): C119 the IC twins retire (`f9b45a0` tests; tree `e3b23a94`): B, C, D strips = the nine `_OPT`; 39/39.** Before: **`bb6bb7a` (2 Oct ~20:23Z): C113 books, C114 quote gap, C115 best bid / offer tables under the fleet cards (strip response `books`, `gaps`, `quotes`; FLEET_STRIP `lattice`); 38/38 suites.** Before: **`830f04b` (2 Oct ~17:35Z): C110 one scalp-list reader `_scalp_history_records` (re-reads only new rows; premise LPUSH + LTRIM only) and `pollNoOverlap` on all 13 page pollers (`8dcb60b` tests first); 35/35 suites.** Before: **`0fd1a86` (2 Oct ~16:17Z): C109 page opens on `GRIND_DEFAULT_INSTANCE`; `00a89ad` C108 `GRIND_RETIRED_INSTANCES`; `94c7630` C107 A strip = seven; `RAILWAY.md` (gunicorn, C102); 34/34 suites.** Before: `eb19e5c` (1 Oct ~19:35Z): C97 `ORPHAN_EXT` -- one amber strip alert per EXT position in a heartbeat's book whose engine layer has no exit position ("not paired: reattach the chart"); on `bb228e0` (1 Oct ~16:25Z): C94 stale `ROLL_STRANDED` greys when no side is fully rolled at cap; on `cfa1a6e` (C90 `DUPLICATE_MAGIC` greys when the instance runs again; Fleet D commission 0.08) on `687b9af` (C9 second key + D live card). Web services: `pipshed.com` (A), `linux.` (B), `linuxc.` (C), `linuxd.` (D) |
| VPS running | **`main` `9346e42` (EA code `5bb5fdb`; `fxgrind.ex5` 21:44:29Z 7 Oct; tag `vps-9346e42`), FTMO 1514878887, 7 instances `_OPT` on `*_opt_a_r2.set` from 22:08-22:17Z. Restore cycle 3: `vps-aa6970a` + `*_opt.set` (`C:\fxmatrix-local\cycle3\fxgrind_aa6970a.ex5` kept). A stray untracked `deploy_presets.ps1` at the repo root: use `scripts\`.** Before: **`aa6970a` (`hotfix-api-stop-ftmo`, tag `vps-aa6970a`, 2 Oct 14:55Z; = `5685e4f` + the C100 constants), 7 instances.** Before: `main` at `5685e4f`, tag `vps-5685e4f` (compiled 2026-09-25 04:50:36Z); restore `vps-a01a5d4`; a MetaTrader LiveUpdate is PENDING on the VPS terminal (answered Later 27 Sep): install only at a planned in-session restart, never with the market closed |
| MQL5 suite | **Replay harness (not the EA suite): 393 / 393 at `cb28224` (fix 6 Part A, 10 Oct ~04:10Z).** Before: **390 / 390 at `90fbce4` on `D:\mt5-replay` (10 Oct).** Before: **338 / 338 at `624a29b` (9 Oct).** EA suite: **2597/2597** on GBPUSD and EURUSD at `5bb5fdb` (= `main` `d57fe9b` EA code: v2.2a + ADR-166, 6 Oct); **2525/2525** on GBPUSD and EURUSD at `8a3ec0c` (v2.2a branch, 3 Oct); **2447/2447** on GBPUSD and EURUSD at `87c9207` (= `main` `3df13f0` EA code, ADR-165); 2368/2368 at `97a2cd1` (= `0335f25`, live on B, C, D); 2220/2220 at `2ff62f4` (v2.1); **1887/1887** at `5685e4f` and on `aa6970a` (the live build, 2 Oct). Desktop ONLY: never on a terminal with live EAs (traps 2026-09-25 C52). Runs from `MQL5\Scripts\`: `.\desktop_sync.ps1` after every checkout. The desktop terminal was logged in to FTMO 1514731800 until it closed 7 Oct (log it in to 1514878887 with the INVESTOR password for dumps) |
| Fleet | **A: 7 live on FTMO 1514878887 since 7 Oct 22:08-22:17Z (GBPUSD 22:08:59 pilot; EURUSD, AUDCHF, CADCHF, NZDCAD, AUDNZD 22:13:51-22:15:48; EURGBP 22:17:40), the IC strategy static; same ids and magics as cycle 3.** Before: **7 live since 2 Oct ~15:40Z** (geometry-cycle3 A7): EURUSD, GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD `_OPT`. Retired 2 Oct: `GRIND_AUDNZD_ALT` (22260902), `GRIND_NZDCAD_ALT` (22260802) 15:14Z; `GRIND_AUDCAD_OPT` (22260401), `GRIND_NZDCHF_OPT` (22260701) ~15:40Z. 11 live 24 Sep-2 Oct |
| Account | **FTMO free trial 1514878887, $10k, $500/day (5% basis read from the first deposit by the breaker), FTMO-Demo; 14 days from the first trade (~21 Oct). 1514731800 (cycle 3) closed 7 Oct.** Before: FTMO free trial **1514731800**, $10k, $500/day. Cycle 2 (1514582088) ENDED on the daily limit 23 Sep: `docs/FULL_TRIAL_RECORD_1514582088.md` |
| Defences | **A (FTMO-IC): ADR-158 breaker and ADR-160 float gate ON ($400 trip, entries gated from $250 floating on $10k); B, C, D off (B's floating $182.72 on 7 Oct ~17:20Z: the gate can bind on A where B has none, reported per day).** Before: **FTMO (cycle 3) only:** ADR-158 breaker (80%, latched, adopted by every instance per tick); ADR-160 entry gate (floating loss 50% on / 40% off); both in every FTMO preset. **IC B, C, D: OFF** since 1 Oct 21:16-21:28Z (`InpBreakerEnable=false` turns off the breaker, the gate and the pre-midnight halt together; fleet-d.md s7); no account-level backstop once re-roll is ON (monday-build s1) |
| Carry / ejection | **A (from 7 Oct 22:08Z): carry ON, commanded eject ON, auto-eject OFF, lattice + re-roll ON, gate 0 = as B.** Before: **FTMO:** ON in all eleven cycle-3 presets (seven still live) (A2 point 2): carry, commanded and auto ejection, W 5, k 1.5. **IC B, C, D:** carry ON, auto-eject OFF, lattice ON (ADR-162 requires it), commanded eject by hand only |
| **Fleet B** | **Now: round 3's anchor (register LIVE NOW: AUDCHF width 1.5 from 9 Oct 04:32Z; the other charts round 2's), `main` `5bb5fdb` with the roll gate at 0 since 7 Oct ~02Z.** IC Markets demo **53066709** on wine-test, nine live since the Monday build (5 Oct; 11 from ~02:50Z 24 Sep) (`docs/architecture/fleet-b.md`); ids `GRIND_<PAIR>_OPTB`/`_ALTB`; dashboard `https://linux.pipshed.com`; **B1 graded add dial applied 27 Sep 23:05-23:51Z** (fleet-b.md B1); **C63 1 Oct (fleet-b.md B2): `main` `0335f25`, lattice ON / auto-eject OFF from 03:51-04:02Z; charts load the Experts copy; repo on `hotfix-api-stop` since 2 Oct (C105)** |
| **Cycle 3** | **RETIRED 7 Oct 21:23Z with 1514731800 (870 scalps, realised +$45.29, 123 ejections 24 Sep - 7 Oct broker day; `history_1514731800.csv` 5,582 deals; MetriX PDF in Downloads).** Before: FROZEN for the whole cycle (geometry-cycle3 A4); first Daily row 24 Sep: realised $82.96, 111 scalps, gated 0.0h |
| **Fleet C** | **Now: round 3's ADD probes (register LIVE NOW: AUDCHF width 1.5, add 5 L / 3 S from 9 Oct 04:29Z; the other charts round 2's), `main` `5bb5fdb` with the roll gate at 0 since 7 Oct ~02Z; still on the Scripts `.ex5` (C88).** = wine-c (box 2), 64.177.116.219, IC demo **53071896** (Hedge), nine live since the Monday build (5 Oct; 11 from 00:07Z 28 Sep at B1 settings). **C63 1 Oct (fleet-c.md A2): `main` `0335f25`, lattice ON / auto-eject OFF from 04:12-04:16Z.** **Its charts load `Scripts\fxmatrix\fxgrind.ex5` (C88): compile THAT file for a build there.** GUI: x11vnc on port 5911 + `ssh -L 5911:localhost:5911 box2` (06 s9); MT5 restarted 1 Oct 04:08Z (06 s9 start line). Page `https://linuxc.pipshed.com` **D1 (1 Oct 06:45-06:50Z, fleet-c.md A3): ADD probe one pip tighter (EURGBP, NZDCHF +1 at the floor); the twins carry it (add 7), NZDCAD/AUDNZD OPTC on the anchor.** |
| **Fleet D** | **Now: round 3's EXIT probes (register LIVE NOW: EURUSD exit 9 L / 11 S from 9 Oct 04:24Z; AUDCHF width 1.5, exit 11 L / 9 S from 04:26Z; the other charts round 2's), `main` `5bb5fdb` with the roll gate at 0 since 7 Oct ~02Z; the D1 text below is history.** = wine-d (box 3), 216.128.158.33, IC demo **53077984**; D0 live since 1 Oct 05:19Z (anchor + lattice from flat). **D1 (06:19-06:35Z): EXIT probe one pip tighter (10 -> 9, EURGBP 5 -> 4); the twins carry it (5/8/9, 7/8/9), NZDCAD/AUDNZD OPTD on the anchor; `rebuild=true/true` clean.** NZDCAD_OPTD off 06:24-06:32Z (twin preset on the wrong chart; 02_TRAPS 1 Oct D1). Page `https://linuxd.pipshed.com` (strip: LIVE card). GUI: x11vnc `-noipv6 -forever` on 5912 over `ssh -o ServerAliveInterval=15 -L 5912:localhost:5912 root@216.128.158.33` |
| **Ejection study** | C16: does ejecting at cap beat holding? `docs/research/ejection-value-study.md` (s9-s11; GQ6-GQ13 rulings), `research/ejection_value/` (`ev_replay.py`, `ev_caps.py`, `ev_report.py`; README). Replay v1 FROZEN at `ab5d4c8` (GQ12); true holdout 1-7 Oct (C84). Data: `--export-study --days 14` + `grind_bidask_dump.mq5` (true ask; M1 bars under-state the ask) and `grind_bar_dump.mq5` on the desktop FTMO terminal and wine-c. **s12 (30 Sep evening, the interim report):** reconciliation 18/33; closed P&L rises with cap, closed + open flattens around cap 8-9 (s11's 'flat from 6-7' WITHDRAWN: a basket effect, GQ13), risk 2-4x from cap 5 to 10; V_strict negative at 24 h on every fleet (15 of 22 chains); Q1 small. s12.7: the swap day from the ledger (C86). Final ~9 Oct after the C84 holdout |
| **Next** | **Now: the NEXT SESSION list at the end of HANDOFF s77.** Before: **The NEXT SESSION list at the end of HANDOFF s65** (tonight: pipshed C137 S/R table and snapshots, and the S/R literature; Thu: the IC-vs-FTMO rewrite to Gemini (window from Fri 9), round-2 scoring ~22:35Z, round 3's table; Fri 9 round 3's reload; C125's two days from the dumps). Before: **The NEXT SESSION list at the end of HANDOFF s64** (round 2 = 7 Oct 02:25Z (the build) - 8 Oct 22:00Z, operator ~15:27Z; Thu ~22:35Z: the IC dump from `2026.10.07 04:00` server + `--export-archive`, `equity_score.py` decides on the cohort (end mark 8 Oct 22:30Z), `compass_score.py` and `fill_slippage.py` reported; round 3's table and presets; Fri 9 in session round 3's reload (Fri + Mon 12); Sat holdout scoring). Before: the NEXT SESSION list at the end of HANDOFF s63 (the carry pass after ~21:00Z; Thu 8 Oct round-2 scoring with `fill_slippage.py`; round 3 with the roll gate at N = 0 on wine-d; the IC build from `main` Fri 9 Oct; Sat holdout scoring). Before: the NEXT SESSION list at the end of HANDOFF s62 (the carry pass after ~21:00Z; the fill-slippage report C132 before Thu 22:00Z; Thu 8 Oct round-2 scoring; round 3 by `docs/runbooks/round-reload.md`; Sat holdout scoring). Before: the NEXT SESSION list at the end of HANDOFF s61 (a status read; the carry pass; Thu 8 Oct round-2 scoring; round 3 by `docs/runbooks/round-reload.md`; Sat holdout scoring). Before: the NEXT SESSION list at the end of HANDOFF s58 (Gemini on the round tables; Tuesday's round-2 reload; quiet slots; Saturday's holdout scoring). Before: the NEXT SESSION list at the end of HANDOFF s57 (tonight's runbook; the `_r2` presets; Tuesday's reload; Saturday's holdout scoring). Before: HANDOFF s56 (FXMatrix only; mfperp parked) (AUDUSD presets `4694471`; pipshed C121 in Downloads, after C119): this docs patch; v2.2a built and tested (NOT merged before the Monday build); Sunday checks; Mon 5 Oct after 22:00Z score round 1, the Monday build, pipshed C119, IC twin GVs; then C99 (cap 10 + widths) and round 2 |
| Linux boxes | **Now: round 3's `_r3` presets loaded 9 Oct 04:24-04:32Z on four charts (presets only, no compile; EA code `5bb5fdb`); repos pulled at the reload, believed `9425141` (to confirm on each box: `git -C /home/khalid/fxmatrix-repo log --oneline -1`).** Before: **Since the Wednesday build (7 Oct 01:57-02:23Z): repos at `565ea53`; `main` compiled on wine-d (Experts 01:57:27), wine-c (Scripts 02:06:35, C88), wine-test (Experts 02:17:49); the `_r2` presets with the gate staged (fingerprints D `f02163b4e417`, C `6f8a3d3b1a5f`, B `fce104ecbacf`).** Before: **Since the round-2 reload (6 Oct 03:18-03:35Z): repos at `7551580`, the nine `_r2` presets staged in `MQL5/Presets` with the key (fingerprints D `3b2cd4808889`, C `8c42b0b03c31`, B `5a09afdf5bd6`). x11vnc: wine-d `-forever` (5912); wine-test (5910) and wine-c (5911) started with `-once` for the reload (it exits when the viewer disconnects): check `pgrep -a x11vnc` first.** Before: **B, C, D run `main` (`2859be6` EA code; repos at `83a8f0d`) since the Monday build, 5 Oct: wine-d compile 22:38:05Z (Experts), wine-c 22:59:00Z (Scripts, C88), wine-test 23:16:36Z (Experts); `InpLatticeReroll=true` on all 27 charts by 23:20:51Z; nine instances each (twins retired).** Before: **B, C, D run `893e065` (`hotfix-api-stop`, 2 Oct 14:16-14:21Z: `0335f25` + the C100 constants; repo checkouts on that branch); x11vnc `-forever` on all three.** wine-test 207.148.14.197 (Fleet B, anchor, Algo ON), wine-c 64.177.116.219 (Fleet C, add probe, VNC 5911, charts on the Scripts copy), wine-d 216.128.158.33 (Fleet D, exit probe, VNC 5912; all three repos on `hotfix-api-stop` since 2 Oct, back to `main` with the Monday build, C105; history starts with the C78 probe's deals, magic 99078001). See `06_LINUX_WINE_BOX.md` s7, s9, s10 |

**Nothing lands in the EA mid-cycle** except a defect fix; every compile or
reattach restarts the fleet. Pipshed and docs may change.

**The VPS clock is UTC** (the terminal reports GMT+0), so `TimeGMT()` and
the FTMO day (22:00Z in summer) are right.

**Both brokers' servers run GMT+3** (VERIFIED 2026-09-25: every nightly
`CARRY_SNAPSHOT`, written at 23:50 server, arrived at 20:50Z on all 22
instances). The carry window is 20:50-20:59Z; IC Markets closes Fridays at
23:57 server (20:57Z). NY-close brokers usually move to GMT+2 when US DST
ends (1 Nov): re-check then (inferred, not verified).

**Nightly carry check** (from ~21:00Z, desktop `D:\pipshed`):

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" `
      python scripts/archive_counts.py --carrypass --hours 2

Expect one `CARRY_PASS_SUMMARY` per instance (34 since the Monday build,
5 Oct: 7 FTMO + 27 IC; 40 from 2 Oct until then), `incomplete`
false, and
no I6, `INVARIANT_FAIL`, `QUARANTINE_HALT` or CRITICAL; I3
`QUARANTINE_ENTER` transients are normal (C40), and so is `failed` > 0 on
tiny-swap sides (C60). Baseline, 24 Sep: 22 summaries at 20:51-20:54Z,
eligible 3-7. `CARRY_PASS_INCOMPLETE` on a Friday is expected only for an
instance holding more than ~14 layers (the window ends at the close).

**If an instance halts on I6 at the carry window** (C52 repair, Gemini CG5
SOUND): bring it to the chat first; do not restart it blindly. The repair:
delete the mispriced EXT order by hand in that terminal, then reattach
only that chart. ADR-156 treats the missing exit as a startup shortfall
and `Grind_RetryMissingExits` re-places it at its formula with the current
accrual.

**Operator deploy practice (2026-09-25):** deploy during market hours
("doing changes when the market is closed has its own issues"); Fleet B
first (the box is the test environment, the VPS the fallback); short
watch windows, minutes not ten, judged before/after.

**Attaching on this terminal needs Algo Trading ON first;** each EA starts
trading on OK, so every input is read back BEFORE OK.

**Geometry cycle 3** is pre-registered in
`docs/architecture/geometry-cycle3.md` (amendments A1-A3). Exit and cap may
not change mid-cycle (I6/I7); add, width, stranded and deadband may (A1).

**Standing facts.** The binding constraint is the commitment guard
(entries need `positions + orders + resting_entries <= 194`; exits need 1
free slot). A compile or reattach clears a halt and re-runs `OnInit`.
Persistent GV state is flushed to disk within 1 s of any write (C25/T-3).
The currency cap is disabled (thresholds 0.0) and cannot be enabled with a
partial fleet (C32).
