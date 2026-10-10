This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-10 ~12:50Z (SATURDAY; PLAN 2 RUN AND CLASSIFIED; FIX 7 + GEMINI NEXT)

**Handover prepared 10 Oct ~12:50Z (HANDOFF s78 continued 11).** The
EURUSD replay is in its SECOND pre-registration,
`docs/research/replay-calibration-eurusd-2.md` (plan 2): the first plan's
marks unchanged, plus a broker timing model R1-R5 measured from send_logs
(`research/replay/measure_timing.py`). The engine is an MQL5 harness on
the EA's own engine (branch `replay-harness`, never merged; run in
`D:\mt5-replay` by `tools/replay_run.ps1`, `-Timing 0|1`, `-Sens`). Plan
2's deciding run, harness code `868bcc3` (suite 448 / 448):

| Fleet | T1 matched / touchable | Replay-only | T1 | UNPRICED share | T2 |
|---|---|---|---|---|---|
| B | 95.6% | 2.8% | PASS | 18.6% (segs 2, 3) | PASS |
| C | 95.3% | 3.6% | PASS | 55.7% (12, 13, 16, 19) | FAIL |
| D | 95.9% | 3.2% | PASS | 60.0% (21, 23, 24) | FAIL |

**Not a pass.** Plan 2 s15 classifies the two segments `timing = 1` newly
left UNPRICED:
- **D 24: a harness defect in R5.** The TIMER stage gives the carry code
  the newest tick's time as "server now", so its 120 s tick-freshness
  check never fails and a carry pass runs on Saturday 3 Oct 23:50 server
  (all fleets, every timed run). Live's `TimeTradeServer()` runs on, so
  live's pass does no work (`CARRY_PASS_INCOMPLETE`). Fixed, D 24 is
  priced (90 / 94).
- **C 19: timing (M3), one deal** (109 / 115; 110 passes).
- R4's market re-read matches live's PLACEMENT price 93.5-96.1% against
  78.7-83.3% at `timing = 0`: the timing model is a real improvement.
- **Fixing D 24 leaves T2 FAILING** on C (23.7%) and D (34.6%), on the
  segments that fail at `timing = 0` too, each by one or two deals.

**Open: s8's branch** (a rule fail, M4-M10, with up to three attempts;
or "fail in M1-M3 again"), for the operator and Gemini.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP; s6 the state).
2. `handoffs/HANDOFF_2026-09-24.md` **s78 through s78 continued 11**.
   Follow the last NEXT SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-10**.
4. `docs/research/replay-calibration-eurusd-2.md`: ALL of it (s3 the
   model, s4 the marks, s8 what a result means, s11 / s13 Gemini's
   rulings, s14 the result, **s15 the classification**).
5. `docs/research/replay-calibration-eurusd.md` s6 (the marks), s8, the
   miss categories M1-M13 (~line 277).
6. `prompts/cursor_replay_fix6.md` (s0-s12 the spec, s13-s15 the defects
   C1-C10 and the runs record). Fix 7 follows its form.
7. The branch `replay-harness` in git (tip `e4fda38`, code `868bcc3`):
   `ea/fxgrind_replay_core.mqh` (timing: `Rpl_TmSeedMarketAt` ~679,
   `Rpl_TmRunStage` ~893, the TIMER branch ~927, `Rpl_TmRunTimerHandler`
   ~1024; the instant path `Rpl_ProcessOneTickInstant` ~2640);
   `ea/fxgrind_replay_tests.mq5`; `tools/replay_run.ps1`;
   `research/replay/runs/eurusd_*_868bcc3*/` (each run's `timing.csv` is
   on the desktop only).
8. The EA: `ea/grind_carry.mqh` 160-165 (`Grind_CarryServerTime`),
   280-321 (the gate), 798-824 (`Grind_CarrySessionReady`), 1190-1260
   (the pass step); `ea/fxgrind.mq5` ~428 (`carry_now =
   TimeTradeServer()`).
9. On `main`, `research/replay/`: `compare.py` (`--t0-price order`),
   `measure_timing.py` (+ tests), `results/timing_20261008/timing.md`,
   `results/eurusd_20261008_868bcc3/` (`report*.md`, `misses.csv`,
   `classify/`).
10. `handoffs/Handover/08_BACKLOG.md`; `docs/runbooks/compass-round.md`
    with `research/compass/round3.json`;
    `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW).
11. Then this.

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
  the IC strategy STATIC at B's round-2 anchor, seven `_OPT` instances, EA
  `5bb5fdb`, tag `vps-9346e42`. No input change until the trial ends (~21
  Oct), except a defect fix.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe)
  and D (wine-d, 53077984, exit probe):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off. **Round 3 reloaded 9
  Oct 04:24-04:32Z** on four charts (D EURUSD exit 9 / 11; AUDCHF width
  1.5 on B, C and D; C add 5 / 3; D exit 11 / 9). Window Mon 12 + Tue 13;
  **scored Tue 13 ~22:35Z**; the COHORT's EQUITY decides.
- **The carry pass runs 20:50-20:59Z nightly.** Every Friday shows
  `failed` 3-4 per instance: retcode 10025, a MODIFY to the unchanged price (plan 2 s15); not news.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is.
- The COHORT's EQUITY decides a compass round.
- NZDCAD is the control. IC keeps nine pairs. No twins. No broker contact.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades; it is the
  veteran (ranges and stability, not optima).
- **The FIRST plan's holdout (9 Oct ~22:40Z; superseded by plan 2's):** only D's EURUSD
  re-inited on 9 Oct (04:24:14Z); B and C run on from their 7 Oct inits
  (no synthetic init) to **Tue 13 22:00Z**; all three scored on deals
  after 9 Oct 04:32Z; B and C read w2 + the holdout dump joined at w2's
  01:30 server seam.
- **Plan 2 (operator 10 Oct ~01:53Z):** a NEW pre-registration with a
  broker timing model; the 9-13 Oct EURUSD data are ITS holdout: export
  and hash on Tue 13, nobody reads them until plan 2 allows it.
- **Operator (10 Oct):** "keep going as we are - but be aware that we can
  ask for help if there is a real blocker". No fleet actions.

**The replay's facts:**
- Server time is UTC+3. The archive's `ea_time_ms` is UTC on the EA's
  clock, which leads the broker's by ~0.6 s; harness files use server ms.
- The replay terminal's log is in the desktop's LOCAL time.
- send_logs keep 14 days: the holdout's must be exported soon after Tue 13.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `2a8e6bc` + two patches (s78 continued 11: plan 2 s15; then this handover). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-harness` | tip `e4fda38` (code `868bcc3`; suite 448 / 448; the 48-run matrix: t0, base, limitpx, thru01, lat250, lat1000, p10, p90 x B / C / D x sync / free) |
| `D:\mt5-replay` | Copy BEFORE compiling (`replay_run.ps1 -Mode Copy`); the OPERATOR compiles in the MetaEditor GUI (never a CLI build); `-Mode Suite` / `-Mode Run` start it and it shuts itself down |
| pipshed `main` | `6ea487e` (`--export-sends`) |
| Data on the desktop (Downloads) | `archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl`, `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl`, `ticks_53077984_EURUSD_w2.csv` (sha256 `db2ea941...`). Stage them with the device tools |
| Inputs | `research/replay/inputs/eurusd_20261008/` + `.sha256` |

## 2. NEXT, IN ORDER (= HANDOFF s78 continued 11, NEXT SESSION)

1. The questions for the previous chat.
2. **`prompts/cursor_replay_fix7.md`, in an artifact**, with the questions
   for Gemini INSIDE it (no separate brief): (a) fix 7: in the TIMER stage
   `g_grind_carry_test_server_time` = the timer moment (`cursor / 1000`),
   the analogue of `TimeTradeServer()`; a test of a Saturday timer step
   with a Friday tick (no modify; `CARRY_PASS_INCOMPLETE` at the window's
   close, as live's archives show); the `(long)` casts at core 959 / 1124;
   exact suite counts; RESTATE AND STOP. (b) For Gemini: s8's branch on
   s15, and whether fix 7 is attempt 1 (M9). Gemini reads only the
   attached file; check every ruling in source.
3. Cursor -> Claude reads the commits -> the operator compiles -> R1 ->
   base and `t0` (the sensitivities if Gemini asks) -> `compare.py
   --t0-price order` -> plan 2's record.
4. On each box: `git -C /home/khalid/fxmatrix-repo log --oneline -1`.
5. **Tue 13 after 22:00Z: the holdout's data exported and hashed ONLY**
   (send_logs 9-13 Oct, the archives, one tick dump on wine-d from
   `2026.10.09 01:30` server to `2026.10.14 01:00` or later); ~22:35Z
   round 3 scored (cohort equity).

## 3. TRAPS (full list in 02_TRAPS)

- Cursor leaves the desktop on its branch: every patch step starts with
  `git checkout main`. Quote `"HEAD^{tree}"` in PowerShell.
- Gemini's premises are often wrong even when the finding is right. Check
  every ruling in source.
- Cursor may compile from the command line: the prompt says "if the
  `.ex5` is stale, STOP and ask the operator to compile".
- A replay stage's clocks must be the ones live reads (s15: the carry's
  "server now").
- Count what a fix can change before selling it as the route to a pass.
- The deals output's close-by leg also reads `EXT`; count exit fills with
  entry_type 0.
- Your sandbox: `git fetch` and `git reset --hard origin/main` before every
  patch. Check a patch on a clone reset to the REAL base hash. `.md` files
  check out CRLF: take LF bytes with `git show HEAD:<path>`.
- A count with no committed check is not a fact.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs
  (`Select-String`); never ask for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git
  format-patch`, checks `git am` on a clean clone at the base, saves the
  patch STRAIGHT to Downloads and gives the tree hash. The operator runs
  `git am`, checks the tree and pushes. **Claude never pushes.**
- **Harness changes:** a prompt (RESTATE AND STOP, exact counts, questions
  for Gemini inside it) in an artifact -> Gemini -> Claude checks his
  rulings in -> Cursor -> Claude reads the commits -> the operator compiles
  -> Cursor runs -> Claude reads the outputs.
- One document at a time for Gemini. One paste per step, for agents too.
  Count every line mechanically.
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 194
