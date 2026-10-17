This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-17 ~03:10Z (SATURDAY; PLAN 4 FROZEN, ITS WINDOW OPEN; NEXT WEEK'S LAYOUT RULED; PRESETS PROMPT NEXT)

**Prepared 17 Oct ~03:10Z at the end of the s85 session (HANDOFF s85 and its continued blocks 1-6;
patches s85a-s85g).** The EURUSD replay (an MQL5 harness on the EA's own engine) is under its fourth
pre-registration: **plan 4** (`docs/research/replay-calibration-eurusd-4.md`), **FROZEN: harness
`replay-plan4` `8044284`, builders `plan4-tools` `a335ef0`** (s2's one amendment, `af9f227`). Its window runs
**Fri 16 Oct 00:00 to Wed 21 Oct 01:00 server**; its insurance copies are taken and hashed
(`research/replay/inputs/eurusd_window_p4_raw.sha256`); **the export is Tue 20 Oct from 22:10Z**, then the
window's runs and the verdict.

**What the s85 session did (in order):** booted from s84i and verified it in git (s85); plan 4's insurance
copies, the dump reading `bad_px=1` (s85a); "0.04 lots" answered: exposure per currency (s85b); D's first
pair set (s85c); **ALT's adds measured from D's own fills** (`research/alt_adds/`, s85d); **next week's
layout RULED** (s85e); **the geometry RULED: exit = add on both arms, cap 7, ALT q90 on FTMO and q95 on D
and C** (s85f); the reload path read in source and every doc brought up to date (s85g).

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git
first, including `plan4-tools`, `replay-plan4` and the `review/*` branches. **If `main` has moved past
s85g, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s85 and all its "continued" blocks (1-6)**; follow the LAST NEXT
   SESSION list. s84's blocks for anything they point back to.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-15**, **2026-10-16** and **2026-10-17**.
4. `docs/research/fleet-d-two-arm-ring-2026-10-16.md` **s7-s12** (exposure, the measured adds, the layout,
   the geometry, the reload path) and `research/alt_adds/results_2026-10-17.md`.
5. `docs/research/replay-calibration-eurusd-4.md` (all of it) and `docs/runbooks/plan3-holdout-export.md`
   (the export runbook plan 4 s3 reuses with new names).
6. `handoffs/Handover/08_BACKLOG.md`: C78, C106, C150-C158.
7. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, plan 4's freeze line, the fleets and next
   week's layout, the time to the next time-gated step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the operator to copy and paste
   across in ONE block, at most ~12, each answerable in a line.

Do not start any fleet action, run or export before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (Windows VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):** seven `_OPT`, EA `5bb5fdb`.
  **Breaker OFF since 16 Oct ~13:44-13:45Z** (F7 on all seven). The repo presets and `scripts/ic_presets.py`
  still say true: **DO NOT load A's presets.** Trial ends ~21 Oct. Not read since 13:37Z on 16 Oct: read it
  before Sunday's open.
- **IC B (wine-test, 53066709), C (wine-c, 53071896), D (wine-d, 53077984):** nine each, EA `5bb5fdb`, roll
  gate 0, re-roll ON, breaker off, round 3 geometry, FROZEN until plan 4's window closes (Tue 20 Oct
  22:00Z). **IC access (C150):** the web login refused since 12 Oct; the MT5 logins work. **Never log out
  an IC terminal** (operator, 17 Oct: "we might not be able to get back in").
- **The carry pass runs 20:50-20:59Z nightly** (first after the weekend: Mon 19 Oct).

**Next week's layout, RULED (fleet D note s10-s11):**

| Fleet | From | Pairs | Arms, cap |
|---|---|---|---|
| FTMO: a NEW demo on a NEW Linux + wine server replacing the Windows VPS (C158) | when the server is up and the trial ended | EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF | OPT + ALT, cap 7 (12) |
| D (wine-d): FTMO's mirror | Wed 21 Oct, market hours | the same six; retire NZDCHF, NZDCAD, AUDNZD | OPT + ALT, cap 7 (12) |
| C (wine-c) | after D | EURUSD, GBPCHF, AUDCAD; retire seven | OPT + ALT, cap 7 (6) |
| B (wine-test) | - | unchanged: the control | OPT, cap 8 (9) |

**The geometry (exit = add on both arms):** OPT add = exit: EURUSD 7, GBPUSD 9, EURGBP 3, AUDCAD 6, AUDCHF
4, CADCHF 4 (GBPCHF 9). ALT add = exit, **FTMO at q90:** 23, 24, 16, 27, 21, 9; **D and C at q95:** 27, 30,
19, 27, 22, 12 (GBPCHF about 24 from its range).

**Operator rulings (do not re-open):**
- Exit = add on both arms ("in a tight range trading market it is ok if ALT is completely dormant"); a kept
  chart may be flattened for a fresh start ("these are demo accounts").
- FTMO's request budget: about 2,500 a day for 12 instances against FTMO's 2,000 (C106): "i think FTMO would
  be ok with 2500". Watch the count; report any FTMO alert email.
- q90 on FTMO, q95 on D: "lets just see if there is a material difference" (not a clean probe: broker and
  add both differ; recorded).
- ALT for a pair with no fills of ours from price ranges: "any sensible guess is fine".
- A's breaker OFF; plan 4 frozen, no mark, tolerance, match rule or window changes; timing 1 decides.
- No time-series analysis or price signals: work from our own trades. The lazy rolled exit REJECTED.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `84c825e` (s85f) + s85g (this patch). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-plan4` / `plan4-tools` | `8044284` / `a335ef0`: FROZEN for plan 4; never merged |
| `replay-harness` | `efada62` |
| `review/*` | `cursor-restate-fix1` `66a4c35`, `argon-fix1` `ce6f6ef`, `deepseek-f2` `da2dcb0`, `argon-commits-f1f4` `35fa3d3`, `cursor-restate` `e4d96f4`, `argon-r5` `417a2bb` |
| Plan 4 inputs | insurance `eurusd_window_p4_raw.sha256` (sends B, C, D; `ticks_53077984_EURUSD_win_ins.csv`, `bad_px=1`); w2h `fe37e42a...` not in git, in `D:\mt5-replay\MQL5\Files\replay` |
| Research added in s85 | `research/alt_adds/` (the excursion script, tests, `solve_exit_eq_add.py`, results, inputs hashed) |
| Bridge | grants are per session: ask for `~/Downloads` alone; Downloads holds 2,000+ files (a listing truncates: test a name by staging it) |
| pipshed `main` | `6ea487e` |
| Linux boxes | `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...` |

## 2. NEXT, IN ORDER

1. The operator applies s85g; tree checked; pushed.
2. **The presets prompt** (a Cursor prompt in an artifact, questions for Gemini inside it): `ic_presets.py`
   stages for FTMO, D and C at the geometry above (it has no ALT stage today; FLEETS B / C / D only); new
   instance ids and magics; tests first. Then **the pipshed prompt** (`app.py`'s hard-coded instance lists:
   the new ids on all three fleets, the retired ones). Then **the runbooks** (D, C; the new server and
   FTMO). One document at a time through review.
3. Sun 18 Oct before the open (~21:05Z): A's status read (equity, the day, any marker since 16 Oct 13:45Z).
4. Mon 19 Oct 20:50-20:59Z: the carry pass.
5. **Tue 20 Oct from 22:10Z: the export** (the runbook with new names; the tick dump `2026.10.14 01:30` to
   `2026.10.21 01:30` server: `bad_px` 1 expected, more is a stop), hashed; then plan 4 s7 step 4 on
   `8044284` / `a335ef0` (`build_holdout.py --sends-extra-* --window-end-ms 1792544400000`; manifest; T0;
   the 12 runs; `compare.py --t0-price order`; `score_plan3.py --cut-ms 1792108800000 --tol
   results/plan3/live_spread_n3.txt`); the verdict by plan 4 s5.
6. From Wed 21 Oct in market hours: D (the mirror), then C; FTMO when the server is up and the trial ended.
7. After the trial (~21 Oct): C153, C155, C156; C154 after the export.

## 3. TRAPS (full list in 02_TRAPS)

- **A cap cut on a reload trips I7 if a side holds more layers than the new cap** (halt in place, not
  quarantinable): D's and C's kept OPT charts go 8 -> 7 only with both sides at 7 or fewer, else wait or
  flatten by hand. **An exit change on a reload is supported** (the exit label GV triggers the rebuild;
  done live 1 Oct on wine-d), as long as the label exists: never move a live chart to a new terminal.
- **One `git am` per command line:** a line re-applying an applied patch stops halfway; `git am --abort`.
- Every patch step starts with `git checkout main`; build every patch on a fresh fetch; test `git am` on
  a fresh clone of GitHub. **Never reuse a patch's file name in Downloads**; read every saved patch back
  and hash it; give the tree.
- **PowerShell turns an unquoted `a,b,c` into one space-joined string:** quote comma lists.
- **An archive's OUT_BY rows carry the OTHER position's entry as `deal_price`:** never a market price.
- **`bad_px` counts ticks the dumper dropped;** wine-d's dump dialog shows the chunk input's old comment.
- **Reviewers invent when they summarise** (Argon, Grok): every quote with its line and commit, checked.
- Give a time-gated step only when its time has come. Your sandbox: `.md` files check out CRLF.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs (`Select-String`); never ask
  for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git format-patch`, checks `git am` on a
  fresh clone of GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back,
  hashes it and gives the tree hash. The operator runs `git am`, checks the tree and pushes. **Claude
  never pushes.** Document as you go; refresh THIS file in the patch that hands over.
- **Replay, EA or generator changes:** a prompt in an artifact (questions for the reviewer inside it) ->
  review -> Claude checks every point -> Cursor RESTATES AND STOPS -> Claude checks the restate -> "go" ->
  Claude reads the commits -> the operator compiles -> the suite -> runs -> Claude reads the outputs. No
  change to `8044284` / `a335ef0` while plan 4 runs.
- If Cursor drifts from a prompt, the prompt was not good enough: fix the prompt.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 152
