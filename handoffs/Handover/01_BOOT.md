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

**As of 2026-10-03 ~22:15Z (Saturday, between round 1's windows; HANDOFF s48; handover to a new chat). FXMatrix is the main focus; MyFundedPerps (`theonlykk/mfperp`, its own `handoff/HANDOFF.md`) is a side project for dead time only (operator 3 Oct, s48).** Cycle 3 (FTMO 1514731800, `aa6970a`) runs SEVEN instances (the ring; geometry-cycle3 A7; 2,000 requests a day, C106). IC B, C, D: 11/11 each on `893e065` until the Monday build (Mon 5 Oct after 22:00Z: twins retire, repo to `main` `2859be6`, `InpLatticeReroll=true`; `docs/runbooks/monday-build-2026-10-05.md`; then pipshed C119). `main` EA code `2859be6` (ADR-165 + the API hotfix, C105 DONE; suite 2447/2447). Round 1 scored Monday from the archive (`docs/runbooks/compass-round.md`; cuts, MTM and disconnect reports built). Backlog split C1 / C2 / C3 (s40). C107 DONE on FTMO (gv scripts). **v2.2a built and tested on branch `v22a-recon-api` (`8a3ec0c`, NOT merged: runbook s3.3): C93 dedupe + re-walk + local `RECON_TICKETS`; C100 API limits as inputs, warnings only (operator: "api limits are not a hard line"); `RECON_SCAN_RACE` throttled to one a minute per instance (DeepSeek T-3); suite 2525/2525 on GBPUSD and EURUSD.** Monday build runbook amended (s44: s3.3 pathspec; no account-level backstop once re-roll is ON; the twins' close asked on the night). Operator rulings: IC keeps nine pairs; realised P&L decides, MTM reported; hand-eject cuts with salvage; NZDCAD control; post-once execution with one 2,000-request pool; the 200 positions+orders limit holds on IC too.
Evidence: `HANDOFF_2026-09-24.md` s26 (1 Oct night: C63, Fleet D), s27 (1 Oct morning: D1), s28 (1 Oct day: CHF trend, C94) s29 (1 Oct evening: ADR-165 merged, the FTMO stall, C97) and **s30 (1 Oct night: IC breaker off; rings, no twins, cap 10)**; **s31 (2 Oct early: carry check, NZDCHF ejects, L0 re-quote)**; **s32 (2 Oct day: pipshed outage and gunicorn; API stop hotfix)**; **s33 (2 Oct afternoon: FTMO warning; cycle 3 to seven)**; **s34 (pipshed clean-up: C107-C109)**; **s35 (handover)**; **s36 (new chat; pipshed saturated; C110)**; **s37 (IC review; tables C113-C115; rulings on the objective and width)**; **s38 (FTMO's day count; exports; rings; post-once execution)**; **s39 (history dumps; 21-pair spreads; compass runbook and cuts)**; **s40 (reported checks; backlog split)**; **s41 (C105 merged; the Monday build prepared)**; **s42 (C93 explained; C107 done)**; **s43 (the v2.2a prompt; handover)**; **s44 (new chat; runbook and register fixed)**; **s45 (v2.2a through Gemini, Cursor, DeepSeek and the suite)**; **s46 (AUDUSD scout; no FTMO email)**; **s47 (AUDUSD presets, geometry, pipshed C121)**; **s48 (mfperp side project; handover)**; s18-s25 for the week before.

| | |
|---|---|
| fxmatrix main | **docs to 3 Oct ~21:45Z (`49fc41e`, s47; AUDUSD presets `4694471`); v2.2a prompt `1bb077a` (amended after Gemini); branch `v22a-recon-api` `8a3ec0c` (v2.2a, not merged); EA code `2859be6` (3 Oct: `3df13f0` + `87c9207` + the API hotfix merged, C105); presets `4a1e30e` carry `InpLatticeReroll=true`.** Before: EA code `3df13f0` (1 Oct ~19:10Z) = `--no-ff` merge of `adr165-reroll` (tip `7644941`): ADR-165 `InpLatticeReroll` (default OFF, FATAL without the lattice): with every layer of a capped side rolled, re-roll the rolled layer with the highest VL (long; lowest short), skipping hand-ejected layers, at most one per side per call, none 23:50-00:15 server; `ROLL_ACCEPTED` gains `"reroll"`/`"from_level"`. With the input OFF the EA trades exactly as `0335f25`. Before it: D1 records (`7b85dec`, `de73e46`); `0335f25` = `--no-ff` merge of `adr164-deal-replay` (tip `97a2cd1`) into `9c0217c`. ADR-164 (live on B, C, D): `ea/grind_replay.mqh` (SEEN set; `Grind_ReplayInit` in `OnInit` BEFORE reconstruction, DEFERRED to the first timer call if the server time is 0; sweep on every `OnTimer` and, throttled to 1 s, on the tick path before the quarantine step; markers `DEAL_REPLAYED`, `DEAL_EVENT_AFTER_REPLAY`, `DEAL_EVENT_MISSED` (60 s), `CONNECTION_RESTORED`, `REPLAY_INIT_DEFERRED`); `Grind_ProcessDeal` returns false if any deal select failed during it (the deal stays unseen and is replayed); handler guards (ENT already a layer, EXT already attached); C77: exit-deal lookup reads by ticket. No input. `DEAL_REPLAYED` rows from the timer on healthy days are EXPECTED (the timer ran before the fill's queued event); `DEAL_EVENT_MISSED` is the C76 fault signal. The VPS runs `5685e4f`; wine-test and wine-c run `0335f25` since C63 (1 Oct) |
| pipshed main | **`bb6bb7a` (2 Oct ~20:23Z): C113 books, C114 quote gap, C115 best bid / offer tables under the fleet cards (strip response `books`, `gaps`, `quotes`; FLEET_STRIP `lattice`); 38/38 suites.** Before: **`830f04b` (2 Oct ~17:35Z): C110 one scalp-list reader `_scalp_history_records` (re-reads only new rows; premise LPUSH + LTRIM only) and `pollNoOverlap` on all 13 page pollers (`8dcb60b` tests first); 35/35 suites.** Before: **`0fd1a86` (2 Oct ~16:17Z): C109 page opens on `GRIND_DEFAULT_INSTANCE`; `00a89ad` C108 `GRIND_RETIRED_INSTANCES`; `94c7630` C107 A strip = seven; `RAILWAY.md` (gunicorn, C102); 34/34 suites.** Before: `eb19e5c` (1 Oct ~19:35Z): C97 `ORPHAN_EXT` -- one amber strip alert per EXT position in a heartbeat's book whose engine layer has no exit position ("not paired: reattach the chart"); on `bb228e0` (1 Oct ~16:25Z): C94 stale `ROLL_STRANDED` greys when no side is fully rolled at cap; on `cfa1a6e` (C90 `DUPLICATE_MAGIC` greys when the instance runs again; Fleet D commission 0.08) on `687b9af` (C9 second key + D live card). Web services: `pipshed.com` (A), `linux.` (B), `linuxc.` (C), `linuxd.` (D) |
| VPS running | **`aa6970a` (`hotfix-api-stop-ftmo`, tag `vps-aa6970a`, 2 Oct 14:55Z; = `5685e4f` + the C100 constants), 7 instances.** Before: `main` at `5685e4f`, tag `vps-5685e4f` (compiled 2026-09-25 04:50:36Z); restore `vps-a01a5d4`; a MetaTrader LiveUpdate is PENDING on the VPS terminal (answered Later 27 Sep): install only at a planned in-session restart, never with the market closed |
| MQL5 suite | **2525/2525** on GBPUSD and EURUSD at `8a3ec0c` (v2.2a branch, 3 Oct); **2447/2447** on GBPUSD and EURUSD at `87c9207` (= `main` `3df13f0` EA code, ADR-165); 2368/2368 at `97a2cd1` (= `0335f25`, live on B, C, D); 2220/2220 at `2ff62f4` (v2.1); **1887/1887** at `5685e4f` and on `aa6970a` (the live build, 2 Oct). Desktop ONLY: never on a terminal with live EAs (traps 2026-09-25 C52). Runs from `MQL5\Scripts\`: `.\desktop_sync.ps1` after every checkout. The desktop terminal is logged in to FTMO 1514731800 (kept by the operator; 0 `Trades '` lines in its Journals 25 Aug-1 Oct) |
| Fleet | **7 live since 2 Oct ~15:40Z** (geometry-cycle3 A7): EURUSD, GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD `_OPT`. Retired 2 Oct: `GRIND_AUDNZD_ALT` (22260902), `GRIND_NZDCAD_ALT` (22260802) 15:14Z; `GRIND_AUDCAD_OPT` (22260401), `GRIND_NZDCHF_OPT` (22260701) ~15:40Z. 11 live 24 Sep-2 Oct |
| Account | FTMO free trial **1514731800**, $10k, $500/day. Cycle 2 (1514582088) ENDED on the daily limit 23 Sep: `docs/FULL_TRIAL_RECORD_1514582088.md` |
| Defences | ADR-158 breaker (80%, latched, adopted by every instance per tick); ADR-160 entry gate (floating loss 50% on / 40% off); both in every preset |
| Carry / ejection | ON in all eleven presets (seven still live) (A2 point 2): carry, commanded and auto ejection, W 5, k 1.5 |
| **Fleet B** | IC Markets demo **53066709** on wine-test, 11 live since ~02:50Z 24 Sep (`docs/architecture/fleet-b.md`); ids `GRIND_<PAIR>_OPTB`/`_ALTB`; dashboard `https://linux.pipshed.com`; **B1 graded add dial applied 27 Sep 23:05-23:51Z** (fleet-b.md B1); **C63 1 Oct (fleet-b.md B2): `main` `0335f25`, lattice ON / auto-eject OFF from 03:51-04:02Z; charts load the Experts copy; repo on `hotfix-api-stop` since 2 Oct (C105)** |
| **Cycle 3** | FROZEN for the whole cycle (geometry-cycle3 A4); first Daily row 24 Sep: realised $82.96, 111 scalps, gated 0.0h |
| **Fleet C** | = wine-c (box 2), 64.177.116.219, IC demo **53071896** (Hedge), 11 live since 00:07Z 28 Sep at B1 settings. **C63 1 Oct (fleet-c.md A2): `main` `0335f25`, lattice ON / auto-eject OFF from 04:12-04:16Z.** **Its charts load `Scripts\fxmatrix\fxgrind.ex5` (C88): compile THAT file for a build there.** GUI: x11vnc on port 5911 + `ssh -L 5911:localhost:5911 box2` (06 s9); MT5 restarted 1 Oct 04:08Z (06 s9 start line). Page `https://linuxc.pipshed.com` **D1 (1 Oct 06:45-06:50Z, fleet-c.md A3): ADD probe one pip tighter (EURGBP, NZDCHF +1 at the floor); the twins carry it (add 7), NZDCAD/AUDNZD OPTC on the anchor.** |
| **Fleet D** | = wine-d (box 3), 216.128.158.33, IC demo **53077984**; D0 live since 1 Oct 05:19Z (anchor + lattice from flat). **D1 (06:19-06:35Z): EXIT probe one pip tighter (10 -> 9, EURGBP 5 -> 4); the twins carry it (5/8/9, 7/8/9), NZDCAD/AUDNZD OPTD on the anchor; `rebuild=true/true` clean.** NZDCAD_OPTD off 06:24-06:32Z (twin preset on the wrong chart; 02_TRAPS 1 Oct D1). Page `https://linuxd.pipshed.com` (strip: LIVE card). GUI: x11vnc `-noipv6 -forever` on 5912 over `ssh -o ServerAliveInterval=15 -L 5912:localhost:5912 root@216.128.158.33` |
| **Ejection study** | C16: does ejecting at cap beat holding? `docs/research/ejection-value-study.md` (s9-s11; GQ6-GQ13 rulings), `research/ejection_value/` (`ev_replay.py`, `ev_caps.py`, `ev_report.py`; README). Replay v1 FROZEN at `ab5d4c8` (GQ12); true holdout 1-7 Oct (C84). Data: `--export-study --days 14` + `grind_bidask_dump.mq5` (true ask; M1 bars under-state the ask) and `grind_bar_dump.mq5` on the desktop FTMO terminal and wine-c. **s12 (30 Sep evening, the interim report):** reconciliation 18/33; closed P&L rises with cap, closed + open flattens around cap 8-9 (s11's 'flat from 6-7' WITHDRAWN: a basket effect, GQ13), risk 2-4x from cap 5 to 10; V_strict negative at 24 h on every fleet (15 of 22 chains); Q1 small. s12.7: the swap day from the ledger (C86). Final ~9 Oct after the C84 holdout |
| **Next** | The NEXT SESSION list at the end of HANDOFF s48 (= s47's list plus the boot; mfperp in dead time only) (AUDUSD presets `4694471`; pipshed C121 in Downloads, after C119): this docs patch; v2.2a built and tested (NOT merged before the Monday build); Sunday checks; Mon 5 Oct after 22:00Z score round 1, the Monday build, pipshed C119, IC twin GVs; then C99 (cap 10 + widths) and round 2 |
| Linux boxes | **B, C, D run `893e065` (`hotfix-api-stop`, 2 Oct 14:16-14:21Z: `0335f25` + the C100 constants; repo checkouts on that branch); x11vnc `-forever` on all three.** wine-test 207.148.14.197 (Fleet B, anchor, Algo ON), wine-c 64.177.116.219 (Fleet C, add probe, VNC 5911, charts on the Scripts copy), wine-d 216.128.158.33 (Fleet D, exit probe, VNC 5912; all three repos on `hotfix-api-stop` since 2 Oct, back to `main` with the Monday build, C105; history starts with the C78 probe's deals, magic 99078001). See `06_LINUX_WINE_BOX.md` s7, s9, s10 |

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

Expect one `CARRY_PASS_SUMMARY` per instance (40 since 2 Oct: 7 FTMO +
33 IC; 34 after the Monday build retires the six IC twins), `incomplete`
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
