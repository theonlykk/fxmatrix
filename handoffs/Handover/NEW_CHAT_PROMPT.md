This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-14 ~02:30Z (WEDNESDAY; PLAN 3 s7 UNDER WAY: INPUTS BUILT, T0 PASSES, THE RUNS NEXT)

**Prepared 14 Oct ~02:30Z (HANDOFF s81 continued 5; the s81 chat ran out of
space).** The EURUSD replay (an MQL5 harness on the EA's own engine, branch
`replay-harness`, never merged) is being judged on its pre-registered
holdout (plan 3, `docs/research/replay-calibration-eurusd-3.md`): COUNT-level
use (free-run scalps S, roll closes R, roll acceptances A per fleet and
side) within tolerances from the live day-to-day spread. Harness FROZEN at
`145f092`. **No code change once the first holdout run starts.**

**Since 12 Oct (HANDOFF s81, all of it):**
- **ADR-167 PARKED; the slower light side DROPPED** (operator: "trying to
  guess the type of bounce back we see is not a useful direction").
- **sweep7** (eight weeks carried, no Monday reset; live width vs 0.2):
  worse than flat every Monday on 7 of 9 pairs; width 0.2 about the same.
- **Where the grid stands** (`docs/research/grid-edge-assessment-2026-10-12.md`):
  on a driftless market the scalps pay for the rolls exactly, so the grid
  loses its costs; only EURGBP chops above chance on sweep7's path (rho by
  roll STEPS, C151). Operator ~02:49Z 13 Oct: "fx is a difficult asset
  class. spot fx is probably the hardest to make money from ... let keep
  going with the ftmo trial - but it does feel like we are exhausting
  options".
- **Compass rounds STOPPED after round 3** (operator: "in hindight the
  compass probe idea looks quite silly now"): no promotion; B, C, D frozen.
- **Plan 3's holdout exported and hashed** (Tue 13, 22:13Z; the `_2210`
  set), then **s7 begun**: the frozen harness restored (suite 461 / 461),
  the holdout inputs built (`build_holdout.py`, set `eurusd_holdout`), T0
  PASSES (B 69 / 69, C 72 / 72, D 59 / 59). **No run yet.**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6
   the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s81 and all its "continued" blocks**;
   follow the LAST NEXT SESSION list (s81 continued 5): it has the run
   commands step by step.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-12**,
   **2026-10-13** and **2026-10-14**.
4. `docs/research/replay-calibration-eurusd-3.md`: s3 (the marks), s4 (what
   a result means), s5, s7 with ALL its notes.
5. `research/replay/build_holdout.py`, `research/replay/inputs/eurusd_holdout.sha256`,
   `research/replay/results/plan3/holdout_t0.txt`; `research/replay/score_plan3.py`
   and `compare.py` (their CLIs); on branch `replay-harness`,
   `tools/replay_run.ps1` (Inputs and Run modes).
6. `docs/research/grid-edge-assessment-2026-10-12.md`.
7. `handoffs/Handover/08_BACKLOG.md`: C148, C150, C151.
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, the
   fleets, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action or holdout run before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC, seven `_OPT` instances, EA `5bb5fdb`. No input
  change until the trial ends (~21 Oct), except a defect fix. Follow its
  EQUITY, not realised.
- **IC B (wine-test, 53066709), C (wine-c, 53071896), D (wine-d,
  53077984):** nine instances each, EA `5bb5fdb`, roll gate 0, re-roll ON,
  breaker off; round 3 geometry, FROZEN (no round 4). **IC access (C150):**
  the web login is refused since 12 Oct; the MT5 logins still work (13 Oct).
  At every status read check each IC terminal's journal. **Do not advise
  re-verifying with different details.**
- **The carry pass runs 20:50-20:59Z nightly.** Fridays show `failed` 3-4
  per instance (retcode 10025): not news. `mult_tomorrow` 3 on a Tuesday is
  C144, known.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is, to its end.
- Compass rounds stopped; ADR-167 parked; the slower light side dropped.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades (plan 3 decides).
- The cap stays 8. Rolls only at 8/0 (roll gate 0).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `f3d3854` (s81i) + this patch (s81j). EA code `5bb5fdb`, live on A, B, C, D; presets `_r3` (`fb92da8`) |
| `replay-harness` | tip `efada62`; code **`145f092`, FROZEN for plan 3**; suite 461 / 461 (restored 13 Oct) |
| `replay-adr167` | tip `ed5d052` (parked) |
| `D:\mt5-replay` | the frozen `145f092` build, compiled; `MQL5\Files\replay` holds `ticks_53077984_EURUSD_w2h.csv` (sha256 `fe37e42aa569689248296c3a06c3f1953abd413670bde9cd4e6530b7fb550392`, not in git) and still the CALIBRATION's `run_` / `out_` files until step 2a-c |
| `D:\fxmatrix` | on `main` (switch to `replay-harness` for the runs: step 2b) |
| Bridge | connected folders: `Downloads` and `D:\mt5-replay\MQL5\Files\replay` (NOT `D:\fxmatrix`) |
| pipshed `main` | `6ea487e` |
| Holdout raw files | in Downloads: `archive_` / `sends_EURUSD_OPT{B,C,D}_2026-10-13_2210.jsonl`, `ticks_53077984_EURUSD_hold.csv`; hashes in `research/replay/inputs/eurusd_holdout_raw.sha256` |
| Linux boxes | `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...` |

## 2. NEXT, IN ORDER

1. The operator applies s81j; tree checked; pushed.
2. **Plan 3 s7 step 3, THE RUNS:** HANDOFF s81 continued 5, NEXT SESSION
   2a-2f, one shell step per message: aside the calibration's outputs;
   `replay-harness`; `-Mode Inputs -Set eurusd_holdout -Commit 6734ee5`; the
   w2h hash; six runs at timing 1 (stage each run's five files before the
   next run of the same tag and mode), six at timing 0; commit; `compare.py
   --t0-price order`; `score_plan3.py --cut-ms 1791531120000 --tol
   research/replay/results/plan3/live_spread_n3.txt`; the verdict (s4).
3. A static to ~21 Oct; the nightly carry check and C150 at each read.
4. C151 (rho by roll steps in the tools). C148 stays open (the operator's
   broader direction is his call).

## 3. TRAPS (full list in 02_TRAPS)

- Every patch step starts with `git checkout main`. Quote `"HEAD^{tree}"`
  in PowerShell (unquoted, it printed the parent commit).
- **Never reuse a patch's file name in Downloads**; read every saved patch
  back and hash it; give the tree hash. `s81f` in Downloads is VOID.
- The replay's outputs are named by tag and mode only: a second run of the
  same tag and mode overwrites the first.
- The suite rewrites `Files\replay\swaps.csv`: no suite after `-Mode
  Inputs`; `-SwapsSha` is the guard (holdout `dbd8ee4a...`).
- `replay_run.ps1` from `D:\mt5-replay` needs its full path
  (`D:\fxmatrix\tools\replay_run.ps1`).
- Give a time-gated step only when its time has come.
- Your sandbox: `git fetch` and `git reset --hard origin/main` before every
  patch. `.md` files check out CRLF: compare LF bytes.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs
  (`Select-String`); never ask for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git
  format-patch`, checks `git am` on a clean clone at the base, saves the
  patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it
  and gives the tree hash. The operator runs `git am`, checks the tree and
  pushes. **Claude never pushes.**
- **Replay or EA changes:** a prompt in an artifact -> Gemini -> Claude
  checks his rulings -> Cursor -> Claude reads the commits -> the operator
  compiles -> Cursor runs -> Claude reads the outputs. (None during plan 3.)
- One document at a time for Gemini. One paste per step. Count every line
  mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 154
