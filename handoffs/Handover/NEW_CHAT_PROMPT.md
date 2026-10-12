This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-12 ~20:50Z (MONDAY; SWEEP6 SCORED; IC ACCESS IN DOUBT; PLAN 3 HOLDOUT EXPORT TUE 13)

**Prepared 12 Oct ~20:50Z (HANDOFF s80 continued 9; the s80 chat ran out of
space).** The EURUSD replay (an MQL5 harness on the EA's own engine, branch
`replay-harness`, never merged) has been through three pre-registrations:
- **Plans 1 and 2** closed (plan 2 under its s8 (b): T1 passes, the free run
  drifts deal for deal).
- **Plan 3** (`docs/research/replay-calibration-eurusd-3.md`) is RULED: the
  replay is judged for COUNT-level use (free-run scalps S, roll closes R,
  roll acceptances A per fleet and side) within tolerances from the live
  day-to-day spread. Harness frozen at `145f092`. The holdout is 9-13 Oct,
  unseen: export and hash ONLY on Tue 13
  (`docs/runbooks/plan3-holdout-export.md`).

**Since 11 Oct (HANDOFF s80, all of it):**
- **ADR-167** (C142, the operator's "layer equaliser": the light side's add
  shrinks as the depth gap grows; a fraction table, no pip floor) was
  written, Gemini-reviewed, built in the REPLAY ONLY on branch
  `replay-adr167` (`ed5d052`, suite 493 / 493, off-switch byte-equal to
  `145f092`), and tested as **sweep6** on the eight weeks (pre-registered):
  **NO VERDICT for all three tables, 0 of 9 pairs better, summed -540 to
  -699 pips; scalps +10-14%, roll closes +9-15%.** Claude's lean: park.
  Not ruled.
- **The discussion after sweep6** (`docs/research/light-side-add-discussion.md`):
  rolls happen only at 8/0 (roll gate 0); the equaliser helps only if a
  bounce fails at about 6/6; a two-sided grid gives back ~550 pips of a full
  reversion to the short leg it builds; a toy model of a SLOWER light side
  (`research/grid_thesis/light_side_toy.py`): "pause while gap >= 1" ends a
  rally back to 200 at -7 (today's rule -266), at a cost of 30 on a failed
  bounce and 70 on a 200-and-back. Operator: "we might do a sweep 7 - both
  to test the slower short add and our accessibility to IC markets".
- **IC, 12 Oct ~19:06Z:** IC phoned the operator about verifying with
  government documents; he said he lives in Ontario; IC: the service is not
  available in that jurisdiction. The IC web dashboard now refuses his
  login; the terminals stay logged in; all fleets were live after it. An
  insurance EURUSD tick dump was taken on wine-d (9 Oct 01:30 - 12 Oct
  22:00 server, sha256 `5669094b...`, in Downloads). **Do not advise
  re-verifying with different details.** Backlog C150.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6
   the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s80 through its last "continued"
   block** (s79 if you need the plan 3 history). Follow the last NEXT
   SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-11** and
   **2026-10-12**.
4. `docs/runbooks/plan3-holdout-export.md` (Tue 13, step by step; its X10).
5. `docs/research/replay-calibration-eurusd-3.md`: s3, s5, s7 (with its
   notes), s10.
6. `docs/research/light-side-add-discussion.md`; then
   `docs/architecture/ADR-167-light-side-add-by-depth-gap.md` (status line
   and s11); `research/replay/results/sweep_notes.md` (sweep4 and sweep6);
   `research/replay/results/sweep6/marks.md`.
7. `handoffs/Handover/08_BACKLOG.md`: C142, C145, C147, C148, C149, C150;
   `docs/runbooks/compass-round.md` s4.2 with `research/compass/round3.json`;
   `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW).
8. `prompts/cursor_adr167_replay.md` s4 and s10-s11 (how a replay-only
   build is specified and checked; the template for a sweep7 prompt).
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
  Oct), except a defect fix. Not affected by the IC call (FTMO).
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe)
  and D (wine-d, 53077984, exit probe):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off. Round 3 on four charts
  since 9 Oct 04:24-04:32Z; **scored Tue 13 ~22:35Z**; the COHORT's EQUITY
  decides. **IC access is in doubt (C150):** at every status read, check
  that each IC terminal is still logged in.
- **The carry pass runs 20:50-20:59Z nightly.** Fridays show `failed` 3-4
  per instance (retcode 10025): not news.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is.
- The COHORT's EQUITY decides a compass round.
- NZDCAD is the control. IC keeps nine pairs. No twins. No broker contact.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades.
- The cap stays 8. Rolls only at 8/0 (roll gate 0) are accepted ("might
  mean we fade the dead cat bounce").
- An aside is not a rule: the "3-pip minimum add" was a passing remark
  (removed from ADR-167).
- Round 3's scoring does not spoil plan 3's holdout (12 Oct ~01:39Z).
- **The 9-13 Oct EURUSD data are the holdout:** export and hash on Tue 13;
  nothing reads them until plan 3 s7 allows it. That includes the
  insurance tick file.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `ad62b51` (s80i) + this patch (s80j). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-harness` | tip `efada62`; code **`145f092`, FROZEN for plan 3**; suite 461 / 461 |
| `replay-adr167` | tip `ed5d052` (ADR-167 in the replay only; 493 / 493; never merged) |
| `D:\mt5-replay` | **holds the ADR-167 build now.** Before plan 3's holdout runs: `git checkout replay-harness`, `replay_run.ps1 -Mode Copy`, the operator's GUI compile, suite 461 / 461. It starts on IC 53077984's read-only login |
| pipshed `main` | `6ea487e` (`--export-sends`) |
| Data in Downloads | sweep4 / sweep6's eight weeks of ticks (h8w); `ticks_53077984_EURUSD_w2.csv` (`db2ea941...`); **`ticks_53077984_EURUSD_hold_early.csv`** (holdout insurance, sha256 `5669094b04844a6aece341a2a6bb8018b230b691dbccb9fd878ca23936b9cc90`, 3,793,242 bytes: copy and hash only) |
| Linux boxes | `9425141`, CONFIRMED 12 Oct ~21:30Z (s81) |

## 2. NEXT, IN ORDER

1. Mon 12 after the carry pass (20:50-20:59Z): a status read; every IC
   terminal still logged in? On each box: `sudo -u khalid git -C
   /home/khalid/fxmatrix-repo log --oneline -1` (as root without `sudo -u
   khalid`, git refuses: dubious ownership).
2. **Tue 13 from 22:10Z: `docs/runbooks/plan3-holdout-export.md`, one step
   per message.** If wine-d has lost IC by then: STOP; the insurance file
   is the fallback and a plan 3 note is the operator's call. ~22:35Z round
   3 scored, apart (it needs wine-c's bid / ask dump: IC too).
3. **Plan 3 s7, each step committed before the next** (the restore of
   `replay-harness` first).
4. The operator's O-A..O-C (`light-side-add-discussion.md` s8): ADR-167
   parked or not; sweep7 (a slower light side: a parser change on
   `replay-adr167` through the pipeline, then a pre-registration like
   sweep6); what "accessibility to IC" in sweep7 means. Never leave
   `D:\mt5-replay` on a sweep build when plan 3 needs it.
5. C145; C148.

## 3. TRAPS (full list in 02_TRAPS)

- Cursor leaves the desktop on its branch: every patch step starts with
  `git checkout main`. Quote `"HEAD^{tree}"` in PowerShell.
- **Never reuse a patch's file name in Downloads** (the old bytes can stay);
  read every saved patch back and hash it; give the tree hash.
- Gemini's premises are often wrong even when the finding is right. Check
  every ruling in source.
- Cursor may fix a failing test itself: the operator's line says "on any
  failure STOP and report, do not fix".
- A test fixture's book must be a book the EA could hold (losing layers
  under water). A toy model must follow the EA's placement rules (a limit
  behind the market goes AT the market).
- Count what a fix can change before selling it; compute a figure with a
  committed script before quoting it.
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
- **Replay or EA changes:** a prompt (RESTATE AND STOP, exact counts,
  questions for Gemini inside it) in an artifact -> Gemini -> Claude checks
  his rulings -> Cursor -> Claude reads the commits -> the operator
  compiles -> Cursor runs -> Claude reads the outputs.
- One document at a time for Gemini. One paste per step, for agents too.
  Count every line mechanically.
- **Explain with one small worked example in prices before any table**
  (operator 12 Oct: "lets make it a bit simpler").
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 182
