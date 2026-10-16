This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-15 ~17:00Z (THURSDAY; PLAN 4: GATE PASSED ON BOTH WINDOWS; FROZEN AT 8044284 + a335ef0; THE EXPORT NEXT)

**Prepared 15 Oct ~17:00Z (HANDOFF s84 continued; refreshed in s84a and s84b; s84c and s84d add the evening).** The EURUSD replay (an MQL5
harness on the EA's own engine) FAILED plan 3 on T1 (C 94.4%, D 94.9%). **Plan 4**
(`docs/research/replay-calibration-eurusd-4.md`, REVIEWED and AGREED) asks the same question on a NEW
window, Fri 16 Oct 00:00 to Wed 21 Oct 01:00 server, with the harness `145f092` + fixes F1-F4, frozen by
ONE amendment to its s2 before the export.

**Since the s82 hand-over (HANDOFF s83, its "continued" blocks 1-7, and s84):**
- Cursor's F1-F4 commits read (clean; two gaps); Argon's and DeepSeek's reviews checked quote by quote;
  the suite at `7d8fa13` found five wrong test values; **fix 1** (`prompts/cursor_plan4_f1f4_fix1.md`)
  through Grok's review, Cursor (Grok 4.7), the suite: **`replay-plan4` `8044284` 573 / 573**, builders
  **`plan4-tools` `a335ef0`** (Python 196 OK on the desktop).
- **The development gate (plan 4 s4), at timing 1 (deciding): PASS on both seen windows.**
  - Holdout (s83 continued 7; `runs_gate_hold/`, n 3, cut `1791531120000`): T1 100.0% for B, C and D,
    replay-only 0 (plan 3: FAIL).
  - Calibration (s84; `runs_gate_cal/`, n 6, no cut): T1 B 98.8%, C 98.3%, D 97.3%, replay-only
    1.9 / 1.7 / 1.9%; one OUT side (D long S), as plan 3's calibration.
  - Timing 0 (reported, never deciding): FAIL on both windows (C154). FREE counts equal `145f092` at
    both timings on both windows.
- **FROZEN (s84b, plan 4 s2's one amendment): harness `8044284`, builders `a335ef0`** (the operator
  agreed both: F2's clock fix lives in the builders, and they build the window's inputs).

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git
first, including `plan4-tools`, `replay-plan4` and the `review/*` branches. **If `main` has moved past
s84h, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s83, its "continued" blocks, and s84**; follow the LAST NEXT
   SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-14** and **2026-10-15**.
4. `docs/research/replay-calibration-eurusd-4.md` (all of it); plan 3's s3, s4 and s7 notes.
5. `research/replay/results/plan4/` (the four scores: `holdout_score_8044284[_t0].md`,
   `cal_score_8044284[_t0].md`).
6. `prompts/cursor_plan4_f1f4.md` and `prompts/cursor_plan4_f1f4_fix1.md` (the changes, not the line
   detail); `review/deepseek-f2` `da2dcb0` (T-3, T-5: recorded limits, HANDOFF s83 continued 2).
7. `handoffs/Handover/08_BACKLOG.md`: C150, C151, C152, C153, C154; and `docs/research/roll-geometry-notes-2026-10-15.md` (for C153; s7 the rolled exit measured, the lazy exit rejected; s8 ALT); `docs/research/fleet-d-two-arm-ring-2026-10-16.md` (C157, after Tue 20 Oct 22:00Z).
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, the freeze amendment as found in plan 4 s2,
   the fleets, the time to the next time-gated step, and anything in the docs that disagrees with
   itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the operator to copy and paste
   across in ONE block, at most ~12, each answerable in a line.

Do not start any fleet action, run or export before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):** the IC strategy STATIC,
  seven `_OPT` instances, EA `5bb5fdb`. **Breaker OFF since 16 Oct ~13:45Z** (operator, F7 on all seven;
  the repo presets still say true: DO NOT load them); otherwise no input change. Follow its EQUITY, not realised. Last read q18 (15 Oct 03:53Z): about 211 left of FTMO's daily
  limit that day; the operator: "we have to run this to the bitter end" (C153).
- **IC B (wine-test, 53066709), C (wine-c, 53071896), D (wine-d, 53077984):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off; round 3 geometry, FROZEN. **IC access (C150):** the
  web login is refused since 12 Oct; the MT5 logins still work. At every status read check each IC
  terminal's journal. **Do not advise re-verifying with different details.**
- **The carry pass runs 20:50-20:59Z nightly.** Fridays show `failed` 3-4 per instance (retcode
  10025): not news. `mult_tomorrow` 3 on a Tuesday is C144, known.

**Operator rulings (do not re-open):**
- The FTMO-IC trial runs to its end; its breaker is OFF (operator 16 Oct: "keeping a trial clean that we
  dont want makes no sense").
- Compass rounds stopped; ADR-167 parked; the slower light side dropped.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades. Plan 3 is CLOSED: FAIL. Plan 4 decides, on
  its own window; timing 1 decides, timing 0 is reported.
- **BLIND from Thu 15 Oct 21:00Z (Fri 16 Oct 00:00 server) until plan 4's freeze amendment is pushed:**
  no EURUSD fill, send, scalp, roll or journal line of B, C or D after the cut, on pipshed or a box
  (plan 4 s2 lists what is allowed). **The freeze was pushed before the window opened, so the blind period is
  empty** (s84 continued 4).
- No mark, tolerance, match rule or window changes; plan 4's ONE allowed edit is s2's freeze line.
- The cap stays 8. Rolls only at 8/0 (roll gate 0).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `aa5f1df` (s84g) + s84h (fleet D as a two-arm ring, PROPOSED: C157). EA code `5bb5fdb`, live on A, B, C, D; presets `_r3` (`fb92da8`) |
| `replay-plan4` | `8044284` (the harness that passed the gate; suite 573 / 573); never merged |
| `plan4-tools` | `a335ef0` (the builders; `build_inputs.py --sessions`, `build_holdout.py --sends-extra-*`, `--window-end-ms`); never merged |
| `replay-harness` | `efada62` (plan 3's `145f092`) |
| `review/*` | `cursor-restate-fix1` `66a4c35`, `argon-fix1` `ce6f6ef`, `deepseek-f2` `da2dcb0`, `argon-commits-f1f4` `35fa3d3`, `cursor-restate` `e4d96f4`, `argon-r5` `417a2bb` |
| `replay-adr167` | `ed5d052` (parked) |
| Gate inputs | `research/replay/inputs/eurusd_20261008_p4` (67), `eurusd_holdout_p4` (17), manifests `*_p4.sha256` |
| Gate runs | `research/replay/runs_gate_hold/`, `runs_gate_cal/` (12 runs each, `manifest.sha256`) |
| `D:\mt5-replay` | the `8044284` build; `Files\replay` holds the calibration set and its timing-0 outputs (last run D free t0, 16:44Z) |
| `D:\fxmatrix` | on `main` (s84a applied there) |
| Bridge | granted in s84: `Downloads`, `D:\mt5-replay\MQL5\Files\replay`, `D:\fxmatrix\research\replay\runs` (a new chat must ask again) |
| pipshed `main` | `6ea487e` |
| Linux boxes | `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...` |

## 2. NEXT, IN ORDER

1. The operator applies s84h; tree checked; pushed.
2. The freeze is in: no code change to `8044284` or `a335ef0`.
3. The window has been open since Thu 15 Oct 21:00Z; no blind (the freeze came first). Carry check
   20:50-20:59Z nightly; C150.
4. **Sat 17 Oct:** the insurance copies (tick dump, `send_logs`), hashed only. **Tue 20 Oct from
   22:10Z:** the export, hashed only (`docs/runbooks/plan3-holdout-export.md` with new names).
5. Plan 4 s7 step 4: the window's inputs with `build_holdout.py` at `a335ef0` (sends joined, end
   `1792544400000`), manifest, T0, the 12 runs, `compare.py --t0-price order`, `score_plan3.py` with
   `--cut-ms 1792108800000` and `live_spread_n3.txt`; the verdict.
6. A static to ~21 Oct; the nightly carry check and C150 at each read. C153 after the trial; C154 after
   the export.

## 3. TRAPS (full list in 02_TRAPS)

- Every patch step starts with `git checkout main`. Quote `"HEAD^{tree}"` in PowerShell.
- **Never reuse a patch's file name in Downloads**; read every saved patch back and hash it; give the
  tree hash. **Build every patch on `git checkout -B main origin/main`.**
- **A sync run needs `-Sync`;** check each log's `RPL|RUN|<tag>|sync=<0|1>|out=<tag>_<mode>` and
  `RPL|TIMING|<t>` against the label, and the outputs' mtime, before staging.
- `RPL|ORDERS_KEPT|16|3/4` on C runs is expected (fix 2); any other shortfall is a stop.
- The replay's outputs are named by tag and mode only: the next run of a tag and mode overwrites them;
  stage straight after each run.
- The suite rewrites `Files\replay\swaps.csv`: no suite after `-Mode Inputs`; `-SwapsSha` is the guard.
- **Reviewers invent when they summarise** (Argon, Grok): every quote with its line and commit or "not
  read"; check every quote before a ruling. Cursor's Other Models quota may switch it to Grok: check
  the model picker.
- A bridge request for several folders at once can be refused outright: ask for `~/Downloads` alone.
- PowerShell: quote comma lists (`--codes "A,B"`); C150 in a blind reads login lines and non-EURUSD trades only.
- Give a time-gated step only when its time has come.
- Your sandbox: `.md` files check out CRLF: compare LF bytes.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs (`Select-String`); never ask
  for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git format-patch`, checks `git am` on a
  clean clone at the base, saves the patch STRAIGHT to Downloads under a NEW name, reads it back,
  hashes it and gives the tree hash. The operator runs `git am`, checks the tree and pushes. **Claude
  never pushes.** Refresh THIS file in the patch that hands over.
- **Replay or EA changes:** a prompt in an artifact (questions for the reviewer inside it) -> review ->
  Claude checks every point -> Cursor RESTATES AND STOPS -> Claude checks the restate -> "go" -> Claude
  reads the commits -> the operator compiles -> the suite -> runs -> Claude reads the outputs. No code
  change after the freeze.
- If Cursor drifts from a prompt, the prompt was not good enough: fix the prompt, not with instructions
  outside it.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 156
