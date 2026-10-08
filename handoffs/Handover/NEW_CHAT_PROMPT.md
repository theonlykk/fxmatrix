This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-08 ~04:15Z (THURSDAY EARLY, HANDOVER; FIRST TASK: THE REPLAY HARNESS, FIX 3 TO CURSOR; FTMO 1514878887 RUNS THE IC STRATEGY STATIC; ROUND 2 ENDS 8 OCT 22:00Z)

**Handover 8 Oct ~04:15Z (end of HANDOFF s68, at s68k).** The replay
calibration plan (`docs/research/replay-calibration-eurusd.md`) is written,
ruled by Gemini (s12) and pushed; T0 PASSED (867 / 867). The engine is (c),
an MQL5 harness on the EA's own engine and test seams, which Cursor builds
on branch `replay-harness` and will run itself; the Python port (C118)
follows, proven equal to (c). Cursor has built the base prompt, fix 1 and
fix 2 (`f0b2445` .. `fc0fb26`). Claude read `fc0fb26` and wrote fix 3
(`prompts/cursor_replay_harness_fix3.md`, E1-E7, Z1-Z4, RT28-RT29); it has
NOT gone to Cursor yet. The first task is HANDOFF s68 NEXT SESSION items
2-3: the desktop compile of both replay files at `fc0fb26`, then fix 3.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED.
Do not read or ask about it unless the operator brings it back.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 the state); `handoffs/HANDOFF_2026-09-24.md` **s67-s68** (s68's
NEXT SESSION list is the one to follow); `handoffs/Handover/02_TRAPS.md`
sections dated 2026-10-07 and **2026-10-08** (early, night, night late);
`docs/research/replay-calibration-eurusd.md` (all; s12 the rulings and
record); `prompts/cursor_replay_harness.md`, `..._fix1.md`, `..._fix2.md`,
`..._fix3.md` (in that order; each has Gemini's rulings at the end); the
branch `replay-harness` in git (`ea/fxgrind_replay_core.mqh`,
`ea/fxgrind_replay_tests.mq5`, `ea/fxgrind_replay.mq5`);
`scripts/grind_tick_dump.mq5`;
`handoffs/Handover/08_BACKLOG.md` (C1; C135, C137-C141);
`docs/research/grid-as-variance-trade.md` (all; s9-s12 new);
`docs/research/scalps-per-roll.md` (s1-s6); `docs/runbooks/ftmo-ic-start.md`
(s12, s14); `docs/research/compass-equity-amendment.md` (s7);
`docs/runbooks/compass-round.md` (s4.3, s11); `research/compass/README.md`
with `round2.json`; `scripts/grind_bidask_dump.mq5` (the tick source for
the calibration); backlog C118 (the Python engine port);
`handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW = round 2); pipshed
`sr_table.py`, `archive_worker.py` (build_sr_table, state snapshots) and
`ejection_view.py` (C102); then this.

**YOUR FIRST REPLY, after the reading (operator's request, 2 Oct):**
1. A short restate of the state as you found it in git (HEADs, fleets,
   anything in the docs that disagrees with itself).
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block: live state after the
   docs were written, half-finished steps, exact commands, rulings heard
   but not written down. Short, answerable in a line each; at most ~12.
Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME:**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC at B's round-2 anchor (`ea/presets/*_opt_a_r2.set`:
  lattice, re-roll, gate 0, breaker + float gate ON, auto-eject OFF), seven
  `_OPT` instances, `main` `9346e42` (EA `5bb5fdb`), tag `vps-9346e42`. No
  input change for the trial (14 days from its first trade, ~21 Oct) except
  a defect fix. First-day watch: `api_count` > 1,000 by 14:00Z Thu 8 ->
  tell Claude. Cycle 3 (1514731800) RETIRED 7 Oct 21:23Z; restore
  `vps-aa6970a` + `*_opt.set`.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe),
  D (wine-d, 53077984, exit probe):** nine instances each, EA `5bb5fdb`
  (v2.2a + ADR-166) since 7 Oct 01:57-02:23Z, `InpRollGateOpposite=0` on
  all 27, re-roll ON, breaker off. wine-c's charts load the Scripts `.ex5`
  (C88).
- **Compass round 2 = 7 Oct 02:25Z - 8 Oct 22:00Z** (`round2.json`),
  scored Thu ~22:35Z; the COHORT's EQUITY decides (amendment s7); round 3
  reloads Fri 9 in session.
- **pipshed (`d1ad256`):** the Scalps per roll table (C137: S, R, S/R, k*,
  k* paid, S/R - k*; today / 5 days / cycle; `/api/g/<token>/sr` JSON /
  CSV), one-minute `state_snapshots` since 8 Oct 00:00Z (34 rows a minute;
  balance / equity from ONE instance per account), /fleets ~0.6 s (C102;
  was 9-11 s), A shown as "FTMO-IC 1514878887".

**Operator rulings (do not re-open):** the static FTMO-IC trial as above;
the COHORT's EQUITY decides a compass round (realised reported; S/R, k*
and now rho reported, never deciding); equity decides the holdout and the
roll gate; NZDCAD the control; IC keeps nine pairs; no twins; no API limit
may stop trading; no broker contact; post-once execution, one 2,000-request
pool; the 200 positions+orders limit holds on IC too; cap 8 this week;
**8 Oct: no time-series analysis or price signals - extract what we can
from our own trade history; a replay is trusted only once it reproduces
our trades (calibrate first, EURUSD B / C / D); pipshed may be pushed
outside 20:50-21:00Z.**

**Reading live state:** pipshed through the desktop app's built-in
browser pane: open the `/api/g/<token>/fleets/<n>` URL the operator gives
and parse the JSON with the pane's JavaScript tool; quote `generated_at`;
the `Server-Timing` header gives the strip's build time by part. The
pane's JavaScript call times out at 45 s: start long loops, store on
`window`, read back in a second call. Downloads must be GRANTED each
session; deliverables go there under NEW file names, read back by hash;
the folder is too large to list (stage by exact name).

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z; carry
pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after ~21:00Z:
34 summaries: 7 FTMO + 27 IC).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | **this patch (s68k: fix 3 prompt + handover) on `aad272e` (s68j, tree `acf1c4f8`).** EA code `5bb5fdb`, live on A, B, C, D |
| fxmatrix `replay-harness` (Cursor) | `f0b2445`, `a280736` (base), `0c3d5ef`, `8a92e22` (fix 1), `22aa998`, `fc0fb26` (fix 2). Never merged; never run yet. The desktop is left on this branch after a compile: `git checkout main` |
| pipshed `main` | **`d1ad256` (tree `f95f8cc9`): C102 on `2385d24` (C137, tree `882c43da`) on `9b1faba`; 45/45 suites; migration 005 applied** |
| VPS (A) | `main` `9346e42` (EA `5bb5fdb`), tag `vps-9346e42`, FTMO 1514878887 |
| wine-test (B), wine-c (C), wine-d (D) | EA `5bb5fdb` since 7 Oct, gate 0 on all 27; repos at `565ea53`; `ssh box1` / `ssh box2` / `root@216.128.158.33`; VNC 5910 / 5911 / 5912 |
| Ticks on wine-d | `ticks_53077984_EURUSD_w1.csv` (405,245 ticks from 1 Oct 06:30 server; sha256 `556b33c682c5c5e5`); `..._t0b_a.csv` (2,144 ticks, 8 Oct 05:00-06:00 server) |
| Data in Downloads | `study_2026-10-08_0110.jsonl` (export-study 16 days: fill_logs, scalp_history, ROLL_* / EJECT_* / CARRY_* events, config_events from 22 Sep); `history_1514731800.csv` and `bidask_ftmo_2026-10-07\` (cycle 3, C125) |

## 2. NEXT, IN ORDER (= HANDOFF s68 NEXT SESSION)

1. The questions for the previous chat (above).
2. The desktop syntax compile of BOTH replay files at `fc0fb26`; errors go
   into fix 3 (a follow-up patch) before Cursor sees it. Then fix 3 to
   Cursor (restate and stop; exact assertion counts; "go"); read both
   commits in git; compile again.
3. Operator one-time: `D:\mt5-replay` portable MT5, IC 53077984 INVESTOR
   login; Cursor runs the RT suite via `[StartUp]`; Claude reads the log.
4. Thu 8 morning: a status read; A's `api_count`; A's first scalp / roll.
5. Thu 8 ~22:35Z: score round 2; tick-dump tail to 22:30Z; T0 rerun on the
   scoring export; round 3's table, Gemini, `_r3` presets.
6. Fri 9 >= 03:00Z: T0b's second dump (`t0b_b`) and `cmp`.
7. The replay input files from the archive (Python, Claude).
8. The IC-vs-FTMO rewrite to Gemini (one document at a time); pipshed
   C140 charts; Fri 9 round 3's reload.

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names; read `InpTelemetryInstance`
  first; F7 on the chart, never the Navigator; read back before OK.
- PowerShell: quote `"HEAD^{tree}"`. Before `git am`, check
  `git log origin/main..HEAD`. `git am` re-stamps hashes: cite trees.
- Cursor prompts: name the exact line an insertion goes after;
  `AssertTrue(name, x == y)` for longs; never pull Cursor's branches; the
  suite count must equal the prediction exactly.
- Grep logs, never paste them (UTF-16: `iconv`); one shell step per
  message; say which window each command runs in.
- Realised-only ratios flatter a trend (count the open book); per-day
  ratios filtered to days with a roll are biased low.
- Profile on the server (Server-Timing), not by guessing.
- MQL5 CSV: one `FileReadString` on a `FILE_CSV` handle reads ONE field,
  not a line; `FileIsLineEnding` is set by a read, so test it after
  reading, never before. Cursor's tests have carried both bugs.
- Read Cursor's commits before trusting its tests or its fail counts;
  compile EVERY `.mq5` it touches (the runner went uncompiled to fix 2).
- Claude works only inside a turn: "meanwhile" means now or not at all.
- Verify every agent claim in committed source; count every line; clock
  times from the clock tool.

## 4. WORKING PRACTICE

- **One shell step per message**; say WHERE each command runs. Plain-text
  pipshed URLs. One question at a time when the operator asks for them.
- Docs and small fixes: Claude commits in its sandbox, `git format-patch`,
  checks `git am` on a clean clone at the base, delivers to Downloads with
  the expected tree (and reads it back); the operator `git am`s, checks the
  tree, pushes; Claude verifies on GitHub and resets its sandbox. **Claude
  never pushes.**
- Features: spec (Gemini questions inside, RESTATE AND STOP first) ->
  Gemini -> Cursor on a branch -> Claude reads the commits -> suite ->
  DeepSeek for anything that moves orders -> merge `--no-ff`. Research
  code and pipshed: Claude builds, tests first (predicted failures),
  hand-derived values, a mutation round (`PYTHONDONTWRITEBYTECODE=1`,
  `python -B`), the full suite on a fresh scratch PG per suite.
- Long chats: keep docs current; tell the operator when the chat is
  getting long; propose a handoff only near the limit ("we should be happy
  to roll - we have a good handover process").

Line count: 176
