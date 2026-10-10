This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-10 ~18:45Z (SATURDAY; PLAN 3 RULED; NOTHING IN FLIGHT UNTIL TUE 13)

**Prepared 10 Oct ~18:45Z (HANDOFF s79 continued 9).** The EURUSD replay
(an MQL5 harness on the EA's own engine, branch `replay-harness`, never
merged) has been through three pre-registrations:
- **Plan 1** closed (M1-M3).
- **Plan 2** (a broker timing model measured from our sends; fixes 6 and 7)
  closed under its s8 (b): T1 passes (one decision at a time the replay
  reproduces 95.5-97.3% of our deals), but free-running it drifts
  deal-for-deal (read-moment timing; the 2 Oct payrolls burst, when IC
  slowed sends to 1.2-5.8 s and refused modifies).
- A **Fable consult** (`docs/research/replay-consult-fable.md`, its findings
  verified) showed the free-run COUNTS match outside the burst.
- **Plan 3** (`docs/research/replay-calibration-eurusd-3.md`) is RULED: the
  replay is judged for COUNT-level use, on the free-run scalps S, roll closes
  R and roll acceptances A per fleet and side, within tolerances from the
  live day-to-day spread, plus bias and fleet-difference marks. The harness
  is frozen at `145f092`. The scorer `research/replay/score_plan3.py` is
  committed (tests first). The holdout is 9-13 Oct, unseen.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6
   the state).
2. `handoffs/HANDOFF_2026-09-24.md` **s79 through its last "continued"
   block**. Follow the last NEXT SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-10**.
4. `docs/research/replay-calibration-eurusd-3.md`: ALL of it (s3 the marks
   and tolerance table, s5 the known limits, s7 the holdout steps, s10
   Gemini's rulings).
5. `docs/research/replay-consult-fable.md` s5-s9;
   `docs/research/replay-calibration-eurusd-2.md` s3 (the timing model),
   s7 (the holdout as first written), s14-s18.
6. `research/replay/`: `score_plan3.py` + `test_score_plan3.py`,
   `live_spread.py` + tests, `compare.py` (`--t0-price order`),
   `results/plan3/`, `results/eurusd_20261008_145f092/`.
7. `prompts/cursor_replay_fix7.md` s4 (how the runs are made) and s10 (what
   went wrong in them); `tools/replay_run.ps1` on `replay-harness`.
8. `handoffs/Handover/08_BACKLOG.md` (C135); `docs/runbooks/compass-round.md`
   with `research/compass/round3.json`;
   `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW).
9. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, the
   fleets, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC at B's round-2 anchor, seven `_OPT` instances, EA
  `5bb5fdb`, tag `vps-9346e42`. No input change until the trial ends (~21
  Oct), except a defect fix.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe)
  and D (wine-d, 53077984, exit probe):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off. Round 3 reloaded 9 Oct
  04:24-04:32Z on four charts (D EURUSD exit 9 / 11; AUDCHF width 1.5 on
  B, C and D; C add 5 / 3; D exit 11 / 9). Window Mon 12 + Tue 13; **scored
  Tue 13 ~22:35Z**; the COHORT's EQUITY decides.
- **The carry pass runs 20:50-20:59Z nightly.** Fridays show `failed` 3-4 per
  instance (retcode 10025, a MODIFY to an unchanged price): not news.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is.
- The COHORT's EQUITY decides a compass round.
- NZDCAD is the control. IC keeps nine pairs. No twins. No broker contact.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades; it is "the
  veteran" (ranges and stability, not optima).
- **No synthetic init** for B and C: their holdout free runs continue from
  their 7 Oct inits; all fleets are scored on deals after 9 Oct 04:32Z.
- **Plan 3 (10 Oct ~17:28-17:37Z):** count-level gate as drafted on Claude's
  proposals; holdout 9-13 Oct; score everything (no burst exclusion).
- **The 9-13 Oct EURUSD data are the holdout:** export and hash on Tue 13;
  nothing reads them until plan 3 s7 allows it.

**The replay's facts:**
- Server time is UTC+3. The archive's `ea_time_ms` is UTC on the EA's
  clock (leads the broker's by ~0.6 s); harness files use server ms.
- B, C and D trade ONE feed: three geometries, one test.
- send_logs keep 14 days: the holdout's must be exported soon after Tue 13.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `13d129d` + this docs patch (s79 continued 9). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-harness` | tip `efada62`; code **`145f092`, FROZEN for plan 3**; suite 461 / 461 at `252aae5`; the 48-run matrix `research/replay/runs/eurusd_*_145f092*/` (each run's `timing.csv` is on the desktop only) |
| `D:\mt5-replay` | Copy BEFORE compiling (`replay_run.ps1 -Mode Copy`); the OPERATOR compiles in the MetaEditor GUI (never a CLI build); R1 (suite), then R2 (inputs), then R4 (runs), no suite between R2 and R4 (the suite rewrites `swaps.csv`) |
| pipshed `main` | `6ea487e` (`--export-sends`) |
| Data on the desktop (Downloads) | `archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl`, `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl`, `ticks_53077984_EURUSD_w2.csv` (sha256 `db2ea941...`). Stage them with the device tools (Downloads is granted to the chat) |
| Linux boxes | believed `9425141`; NOT checked since 9 Oct |

## 2. NEXT, IN ORDER

1. On each box: `git -C /home/khalid/fxmatrix-repo log --oneline -1`.
2. **Tue 13 after 22:00Z: the holdout's data exported and hashed ONLY**
   (send_logs 9-13 Oct via pipshed `--export-sends`, the archives, one tick
   dump on wine-d from `2026.10.09 01:30` server to `2026.10.14 01:00` or
   later); ~22:35Z round 3 scored (cohort equity), apart.
3. **Plan 3 s7, each step committed before the next:** the holdout inputs
   (the existing builders; a manifest of hashes); T0 (>= 95% or STOP); the
   runs at `145f092` (B, C, D x SYNC, FREE; `timing = 1`, base; `t0`
   reported); `compare.py --t0-price order`; `score_plan3.py --cut-ms <9 Oct
   04:32Z as server ms> --tol research/replay/results/plan3/live_spread_n3.txt`;
   the verdict (PASS / FAIL / INCONCLUSIVE) to the operator.
4. No mark, tolerance, window or code changes once any holdout file is read.

## 3. TRAPS (full list in 02_TRAPS)

- Cursor leaves the desktop on its branch: every patch step starts with
  `git checkout main`. Quote `"HEAD^{tree}"` in PowerShell.
- Gemini's premises are often wrong even when the finding is right; a
  sign-off with no questions is the tell. Check every ruling in source.
- Cursor may run the suite before the operator's compile and may fix a
  failing test itself: the operator's line says "on any failure STOP and
  report, do not fix".
- Specify tests from a REAL output row (fill_log rows have an empty code
  column; the type is in the json).
- Count what a fix can change before selling it; compute a figure with a
  committed script before quoting it.
- Your sandbox: `git fetch` and `git reset --hard origin/main` before every
  patch. `.md` files check out CRLF: compare LF bytes (`git show
  HEAD:<path>`).

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs
  (`Select-String`); never ask for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git
  format-patch`, checks `git am` on a clean clone at the base, saves the
  patch STRAIGHT to Downloads and gives the tree hash. The operator runs
  `git am`, checks the tree and pushes. **Claude never pushes.**
- **Harness changes** (none under plan 3): a prompt (RESTATE AND STOP,
  exact counts, questions for Gemini inside it) in an artifact -> Gemini ->
  Claude checks his rulings -> Cursor -> Claude reads the commits -> the
  operator compiles -> Cursor runs -> Claude reads the outputs.
- One document at a time for Gemini. One paste per step, for agents too.
  Count every line mechanically.
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 159
