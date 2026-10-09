This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-09 ~21:50Z (FRIDAY EVENING; THE REPLAY RUNS END TO END; T1 STILL FAILS; FIX 3 RULED, NEXT TO CURSOR)

**Handover prepared 9 Oct ~21:50Z (HANDOFF s76).** The EURUSD replay
calibration (`docs/research/replay-calibration-eurusd.md`, plan) runs end
to end. The engine is an MQL5 harness on the EA's own engine. Cursor
builds it on branch `replay-harness`, which is never merged. It runs in
`D:\mt5-replay`, a portable MT5 on IC 53077984 with the READ-ONLY login.
Its 29 segments run on the committed inputs
(`research/replay/inputs/eurusd_20261008/`, 66 files) and the w2 ticks.
`research/replay/compare.py` scores the runs on the ORDER price, against
plan s6's marks. **T1 FAILS** at `b8adb15` (after fixes 1 and 2):

| Fleet | Matched | Replay-only |
|---|---|---|
| B | 87.6% | 12.1% |
| C | 91.1% | 8.4% |
| D | 91.4% | 4.3% |

**The next cause is the EA's carry ledger.** It lives in the terminal GV
`GRIND_CARRY_ACCRUED_<ticket>`, which survives a real restart; the harness
deletes it. **Fix 3** (`prompts/cursor_replay_fix3.md`, `main` `26d9f1f`,
164 lines, Gemini's GF3 rulings checked in s7) does four things:
- seeds that value at each init (seed column 9; 174 of 174 checked against
  send_logs);
- keeps the value for sync re-seeds (A2);
- adds one run script, `tools/replay_run.ps1`, for one allowlistable
  command;
- adds tests RT43-RT45 (332 in all).

**It has NOT gone to Cursor yet.**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP; s6 the state).
2. `handoffs/HANDOFF_2026-09-24.md` **s73-s76**. Follow s76's NEXT
   SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-08** and
   **2026-10-09**.
4. `docs/research/replay-calibration-eurusd.md`: all of it (s3 seeding,
   s6 the marks, s12 the rulings and the record).
5. The prompts `prompts/cursor_replay_first_run.md`, `cursor_replay_first_run_fix1.md`,
   `cursor_replay_fix2.md` and **`cursor_replay_fix3.md`**. Each has
   Gemini's rulings at its end.
6. The branch `replay-harness` in git:
   - `ea/fxgrind_replay_core.mqh`
   - `ea/fxgrind_replay_tests.mq5`
   - `ea/fxgrind_replay.mq5`
   - `research/replay/runs/*_b8adb15/`
7. On `main`, `research/replay/`:
   - `build_swaps.py`, `build_segments.py`, `build_seeds.py`,
     `build_real.py`, `build_inputs.py`, `build_orders.py` and
     `compare.py`, with their tests;
   - `results/eurusd_20261008_b8adb15/` (`report.md`, `misses.csv`).
8. The EA, `ea/grind_carry.mqh` 700-730 and 1080-1170 (the carry GVs and
   the pass) and `ea/grind_exitq.mqh` 241-255.
9. `handoffs/Handover/08_BACKLOG.md` (C142-C146).
10. `docs/research/grid-as-variance-trade.md` (s11-s14).
11. `docs/runbooks/compass-round.md` with `research/compass/round3.json`.
12. `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW).
13. pipshed `scripts/archive_counts.py` (`--export-sends`,
    `--export-archive`, `--carrypass`).
14. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, the
   fleets, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block. Keep them short and
   answerable in a line each, at most ~12.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  - Runs the IC strategy STATIC at B's round-2 anchor, as seven `_OPT`
    instances.
  - EA `5bb5fdb`, tag `vps-9346e42`.
  - No input change until the trial ends (~21 Oct), except a defect fix.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe)
  and D (wine-d, 53077984, exit probe):**
  - Nine instances each, EA `5bb5fdb`, roll gate 0, re-roll ON, breaker
    off.
  - **Round 3 reloaded 9 Oct 04:24-04:32Z** on four charts: D EURUSD exit
    9 / 11; AUDCHF width 1.5 on B, C and D; C add 5 / 3; D exit 11 / 9.
  - Its window is Mon 12 + Tue 13; it is **scored Tue 13 ~22:35Z**. The
    COHORT's EQUITY decides.
- **The carry pass runs 20:50-20:59Z nightly.** Fri 9 was clean (34 / 34).
  Every Friday shows `failed` 3-4 per instance; this is not news.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is.
- The COHORT's EQUITY decides a compass round; equity decides the holdout
  and the roll gate.
- NZDCAD is the control. IC keeps nine pairs. No twins.
- No API limit may stop trading. No broker contact.
- Post-once execution with one 2,000-request pool.
- The 200 positions+orders limit holds on IC too.
- No time-series analysis or price signals: work from our own trade
  history.
- A replay is trusted only once it reproduces our trades. The replay is the
  veteran: ranges and stability, not optima.
- The desktop FTMO terminal never trades. Cursor's `taskkill /IM
  terminal64.exe /F` is allowlisted until the script replaces it.

**The replay's facts:**
- Server time is UTC+3. The archive's `ea_time_ms` is UTC; harness files
  use server ms.
- The real EA keeps its resting orders across an init (fix 2 adopts them).
- The exit queue is K = 1, H = 0.
- IC fills carry price improvement, so compare on the order price.
- The 1 Oct ADR-160 gate bound on B, C and D. Its marker is reporter-only;
  the intervals come from send_logs.
- send_logs keep 14 days.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `26d9f1f` + the s76 patch. EA code `5bb5fdb`, live on A, B, C, D |
| `replay-harness` | tip `b933a2f` (code `b8adb15`, tests `e76c5af`, suite 318 / 318). Fix 3 will add three commits (tests; core; `tools/replay_run.ps1`) |
| `D:\mt5-replay` | Its MetaEditor compiles `MQL5\Scripts\fxmatrix\`: copy BEFORE compiling. Close it before runs. Runs start it with `/portable /config:<ini>` (UTF-16 LE) and it shuts itself down |
| pipshed `main` | `6ea487e` (`--export-sends`) |
| Data on the desktop (Downloads) | `archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl`, `study_2026-10-08_2235.jsonl`, `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl`, `ticks_53077984_EURUSD_w2.csv` (sha256 `db2ea941...abd28`). Downloads must be GRANTED each session |
| Inputs | `research/replay/inputs/eurusd_20261008/` + `eurusd_20261008.sha256` (66 lines; seeds have 9 columns since `4bd2f3d`) |

## 2. NEXT, IN ORDER (= HANDOFF s76 NEXT SESSION)

1. The questions for the previous chat.
2. **Fix 3 to Cursor.**
   - The operator's line: read `prompts/cursor_replay_fix3.md` from
     `main` at `26d9f1f` BEFORE switching branches; do s0; STOP.
   - Check the restate: A1, A2 and P1, one line each; RT43 has 8
     assertions, RT44 2, RT45 4; commit 1 fails 5. Then "go".
   - After commit 3, read all three commits, the script line by line
     against P1 (step 0 included), before "go run".
   - Then R0-R5: copy; the operator compiles; 332 / 332; inputs from
     `26d9f1f`; six runs; commit the outputs.
3. Run `compare.py --inputs <dir> --runs <runs dir> --harness <sha7> --ticks
   <w2> --archive-b/-c/-d <archives> --out
   research/replay/results/eurusd_20261008_<sha7>/`. Expect the 15 paired
   exit misses to go. Then classify what remains:
   - the 1 Oct short L00s (M4);
   - the 2 Oct 12:30Z news burst (M3);
   - B's L07 exits on 5 Oct;
   - C's 6 Oct re-roll reload (seg 16);
   - the S L0 entries the replay missed on 1 Oct.
4. Get the holdout's data before retention drops it: send_logs for 9-13
   Oct, the archives, and a tick dump from `2026.10.09 01:30` server.
5. Tue 13 ~22:35Z: score round 3; the replay holdout ends.
6. The IC-vs-FTMO rewrite to Gemini; pipshed C140 and C143; C142 and
   C144-C146 for the operator to rank.

## 3. TRAPS (full list in 02_TRAPS)

- Cursor leaves the desktop on its branch: run `git checkout main` before
  every `git am`. Quote `"HEAD^{tree}"` in PowerShell.
- Gemini's premises are often wrong even when the finding is right (GF3-4
  on 9 Oct). Check every ruling in source.
- Cursor must STOP when it thinks a test is wrong (fix 2's RT41 was edited
  without stopping).
- The deals output's close-by leg also reads `EXT`. Count exit fills with
  entry_type 0.
- Your sandbox: `git fetch` and `git reset --hard origin/main` before every
  patch. Check a patch on a clone reset to the REAL base hash.
- Exports open with `utf-8-sig`. There is no pytest: use `python -B -m
  unittest`.

## 4. WORKING PRACTICE

- **One shell step per message.** Grep logs (`Select-String`); never ask
  for pasted logs. pipshed URLs go in plain text.
- **Docs and small fixes:**
  - Claude commits in its sandbox and runs `git format-patch`.
  - Claude checks `git am` on a clean clone at the base.
  - Claude delivers the patch STRAIGHT to Downloads and gives its hash.
  - The operator runs `git am`, checks the tree and pushes.
  - **Claude never pushes.**
- **Harness changes:** a prompt (RESTATE AND STOP, exact counts, questions
  for Gemini inside it) -> Gemini -> Claude checks his rulings into s7 ->
  Cursor -> Claude reads the commits -> the operator compiles -> Cursor
  runs -> Claude reads the outputs.
- Count every line mechanically. Verify every agent claim in committed
  source.
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 199
