This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-08 ~19:40Z (THURSDAY EVENING; THE REPLAY HARNESS RUNS ITS SUITE 266 / 267; NEXT: THE REPLAY'S INPUT FILES; ROUND 2 SCORED ~22:35Z)

**Handover prepared 8 Oct ~19:40Z (HANDOFF s71).** The EURUSD replay
calibration (`docs/research/replay-calibration-eurusd.md`) is ruled by
Gemini; T0 PASSED (867 / 867); plan s4.1 PASSED (B, C, D trade ONE EURUSD
feed: an hour dumped on all three boxes hashes identical); s4.2 checks 1-4
done (s12). The engine is (c), an MQL5 harness on the EA's own engine,
built by Cursor on branch `replay-harness` (base + fixes 1-5; tip
`8cea613` = the third run's log; code `53fbe90`), never merged. **It runs
its suite on `D:\mt5-replay`** (a portable copy of the desktop's
FTMO-branded MT5, IC 53077984 with the READ-ONLY password; Cursor starts
it by `[StartUp]`): **267 run, 266 pass**. The one failure (RT15 "swap
after first tick") is a test asserted after all its ticks; its fix goes
into the NEXT harness prompt (not its own cycle). The runner
`fxgrind_replay.mq5` has never run on real input files: the replay's
input files (Python, Claude) come first.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP; s6 the state);
`handoffs/HANDOFF_2026-09-24.md` **s68-s71** (s71's NEXT SESSION list is
the one to follow); `handoffs/Handover/02_TRAPS.md` sections dated
**2026-10-08** (early, early morning, day, afternoon, night, night late);
`docs/research/replay-calibration-eurusd.md` (all; s3 seeding, s6 the
marks, s12 the rulings and record); `prompts/cursor_replay_harness.md`
and `..._fix1.md` .. `..._fix5.md` in order (each has Gemini's rulings at
the end; fix 4 s1 and s5 are the close-by evidence); the branch
`replay-harness` in git (`ea/fxgrind_replay_core.mqh`,
`ea/fxgrind_replay_tests.mq5`, `ea/fxgrind_replay.mq5`,
`research/replay/runs/`); `scripts/grind_tick_dump.mq5`;
`handoffs/Handover/08_BACKLOG.md` (C135, C118, C137-C143);
`docs/research/grid-as-variance-trade.md` (s9-s12);
`docs/runbooks/ftmo-ic-start.md` (s12, s14); `docs/runbooks/compass-round.md`
(s4, s11) with `research/compass/round2.json`;
`docs/research/compass-equity-amendment.md` (s7, s8);
`handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW = round 2); pipshed
`sr_table.py`, `archive_worker.py`; then this.

**YOUR FIRST REPLY, after the reading (operator's request, 2 Oct):**
1. A short restate of the state as you found it in git (HEADs, fleets,
   anything in the docs that disagrees with itself).
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block. Short, answerable in a
   line each; at most ~12.
Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME:**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC at B's round-2 anchor (`ea/presets/*_opt_a_r2.set`),
  seven `_OPT` instances, `main` `9346e42` (EA `5bb5fdb`), tag
  `vps-9346e42`. No input change for the trial (to ~21 Oct) except a defect
  fix. 8 Oct 15:11Z: api 556 (the 1,000-by-14:00Z watch not tripped), 68
  scalps, no roll, equity $10,027.59.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe),
  D (wine-d, 53077984, exit probe):** nine instances each, EA `5bb5fdb`
  since 7 Oct 01:57-02:23Z, roll gate 0 on all 27, re-roll ON, breaker off.
  wine-c's charts load the Scripts `.ex5` (C88).
- **Compass round 2 = 7 Oct 02:25Z - 8 Oct 22:00Z** (`round2.json`),
  scored Thu ~22:35Z; the COHORT's EQUITY decides; round 3 reloads Fri 9.
- **pipshed `d1ad256`**: S/R table, one-minute `state_snapshots`, /fleets
  ~0.6 s. A's card shows day P&L null and old API thresholds (C143).

**Operator rulings (do not re-open):** the static FTMO-IC trial; the
COHORT's EQUITY decides a compass round; equity decides the holdout and
the roll gate; NZDCAD the control; IC keeps nine pairs; no twins; no API
limit may stop trading; no broker contact; post-once execution, one
2,000-request pool; the 200 positions+orders limit holds on IC too; cap 8
this week; no time-series analysis or price signals (extract from our own
trade history); a replay is trusted only once it reproduces our trades;
pipshed may be pushed outside 20:50-21:00Z; a missing `swaps.csv` aborts
the harness (8 Oct).

**Reading live state:** pipshed through the desktop app's built-in
browser pane (`/api/g/<token>/fleets/<n>`: the operator gives the URL; the
token is not in the repo); parse the JSON with the pane's JavaScript tool;
quote `generated_at`. Downloads must be GRANTED each session; deliverables
go there under NEW names, read back by hash.

**Watch every night on B, C, D:** no chart edits 20:50-21:15Z; carry pass
20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after ~21:00Z, from
`D:\pipshed` via `railway ssh`: 34 summaries).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | **this patch on `ef4c662` (s71, tree `d4afded0`).** EA code `5bb5fdb`, live on A, B, C, D |
| fxmatrix `replay-harness` | base `f0b2445`/`a280736`; fixes 1-5; code tip `53fbe90`; run logs `da81664` (rt_6e63d50), `6a3dfc0` (rt_7d10bc9), `8cea613` (rt_53fbe90). Three new files in `ea/` only + `research/replay/runs/` |
| `D:\mt5-replay` | portable MT5 (copy of `C:\Program Files\FTMO Global Markets MT5 Terminal`), IC 53077984 READ-ONLY ("trading has been disabled - investor mode"), Algo off, no EA. Cursor copies `ea\*` to `MQL5\Scripts\fxmatrix\`; the operator compiles BOTH replay files in ITS MetaEditor (IDE button), then closes it; Cursor runs |
| pipshed `main` | `d1ad256` (tree `f95f8cc9`) |
| Ticks | `ticks_53077984_EURUSD_w1.csv` on wine-d (1 Oct 06:30 - 8 Oct 05:42 server, sha256 `556b33c682c5c5e5`); `..._t0b_a.csv`; `ticks_<login>_EURUSD_cmp.csv` on all three boxes (8 Oct 12:00-13:00 server, identical) |
| Data in Downloads | `study_2026-10-08_0110.jsonl`; `archive_EURUSD_OPTB/OPTC/OPTD_2026-10-08.jsonl` (`--export-archive`, ~16:32-16:37Z) |

## 2. NEXT, IN ORDER (= HANDOFF s71 NEXT SESSION)

1. The questions for the previous chat.
2. Carry pass check after ~21:00Z (if not done).
3. Thu 8 ~22:35Z: score round 2; the tick dump's tail on wine-d to 22:30Z;
   T0 rerun on the scoring export; round 3's table.
4. The replay's input files (Python, Claude; tests first): run spec for
   the 23 segments (plan s2), seeds (true positions at each init; swap
   from the nightly rollovers), `real_<tag>.csv`, `swaps.csv` (from
   CARRY_SNAPSHOTs and the OUT_BY swaps: CHECK which rollover IC triples;
   the EA's carry pass assumes the one into Wednesday), D's
   `API_SOFT_WARN` interval (server `2026.10.01 22:30:58` -
   `2026.10.02 00:00:00`); no BOM. Then the next harness prompt (the
   runner's first real run; RT15's fix) to Gemini and Cursor.
5. Fri 9 >= 03:00Z: T0b's `t0b_b` and `cmp`. Fri 9: round 3's reload.
6. The IC-vs-FTMO rewrite to Gemini; pipshed C140, C143; C142 (skew) later.

## 3. TRAPS (full list in 02_TRAPS)

- PowerShell drops INNER double quotes in `ssh box '...'`: glob the
  spaces (`Program*Files/MetaTrader*5`), `cd` through the glob, no
  `"TICKS|"`; `e3b0c442...` is the hash of empty input.
- Cursor leaves the desktop on its branch: `git checkout main` and check
  the branch before every `git am`.
- The replay terminal's tick value is 0 for ~2 s after a scripted start;
  a test whose expected value uses the live value passes 0 = 0.
- Gemini's tell: commendations and a sign-off. Check every ruling in
  source; his premises were wrong three times on 8 Oct (fix 3 GH3-1, the
  tick cache, GH4-3).
- One shell step per message; say which window; grep logs, never paste.
- Verify every agent claim in committed source; count every line.

## 4. WORKING PRACTICE

- **One shell step per message**; plain-text pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, `git format-patch`,
  checks `git am` on a clean clone at the base, delivers to Downloads,
  reads it back by hash; the operator `git am`s, checks the tree, pushes;
  Claude verifies on GitHub and resets its sandbox. **Claude never pushes.**
- Harness changes: a prompt (RESTATE AND STOP, exact counts) -> Gemini ->
  Cursor on `replay-harness` -> Claude reads the commits -> the operator
  compiles in `D:\mt5-replay` -> Cursor runs -> Claude reads the log.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 149
