This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-18 ~04:00Z (SUNDAY; PLAN 4 FROZEN, ITS WINDOW OPEN; PRESETS MERGED; D's AND C's RUNBOOKS REVIEWED; FTMO's SERVER RUNBOOK NEXT)

**Prepared 18 Oct ~04:00Z during the s85 session (HANDOFF s85 and its continued blocks 1-13; patches
s85a-s85o).** The EURUSD replay (an MQL5 harness on the EA's own engine) is under its fourth
pre-registration: **plan 4** (`docs/research/replay-calibration-eurusd-4.md`), **FROZEN: harness
`replay-plan4` `8044284`, builders `plan4-tools` `a335ef0`** (s2's one amendment, `af9f227`). Its window runs
**Fri 16 Oct 00:00 to Wed 21 Oct 01:00 server**; its insurance copies are taken and hashed
(`research/replay/inputs/eurusd_window_p4_raw.sha256`); **the export is Tue 20 Oct from 22:10Z**, then the
window's runs and the verdict.

**What the s85 session did (in order):** booted from s84i and verified it in git (s85); plan 4's insurance
copies, the dump reading `bad_px=1` (s85a); "0.04 lots" answered: exposure per currency (s85b); D's first
pair set (s85c); **ALT's adds measured from D's own fills** (`research/alt_adds/`, s85d); **next week's
layout RULED** (s85e); **the geometry RULED: exit = add on both arms, cap 7, ALT q90 on FTMO and q95 on D
and C** (s85f); the reload path read in source (s85g); **the two-arm presets** (`ic_presets.py` stage
`twoarm`, 30 `_t1` presets for E (FTMO), D, C; Argon reviewed, Cursor built, verified byte for byte; merged
`2426f94`, s85h-s85j); **pipshed `twoarm-fleets` `320afe6`** (built, verified, PARKED: merged only after D
and C); **D's runbook** (s85k, REVIEWED s85l: the stranded `|L07|ENT` at a cap cut found in source) and
**C's runbook** (s85m, REVIEWED s85n: C88 closes; gap fills); handover docs refreshed (s85o).

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git
first, including `plan4-tools`, `replay-plan4` and the `review/*` branches. **If `main` has moved past
s85o, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s85 and all its "continued" blocks (1-13)**; follow the LAST NEXT
   SESSION list. s84's blocks for anything they point back to.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-15** to **2026-10-18**.
4. `docs/research/fleet-d-two-arm-ring-2026-10-16.md` **s7-s12** (exposure, the measured adds, the layout,
   the geometry, the reload path) and `research/alt_adds/results_2026-10-17.md`.
5. **`docs/runbooks/twoarm-build-d.md` and `docs/runbooks/twoarm-build-c.md`** (REVIEWED; their last
   section records each review and which reviewer claims were void).
6. `docs/research/replay-calibration-eurusd-4.md` (all of it) and `docs/runbooks/plan3-holdout-export.md`
   (the export runbook plan 4 s3 reuses with new names).
7. `handoffs/Handover/08_BACKLOG.md`: C78, C88, C106, C150-C159.
8. Then this.

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
| fxmatrix `main` | `e5f6b92` (s85n) + s85o (this patch). EA code `5bb5fdb`, live on A, B, C, D. The `_t1` presets: `ea/presets_{e,d,c}/*_t1.set` (30; fingerprints D `eb0d6a097694` (12), C `72ba0e3c19f6` (6)) |
| `replay-plan4` / `plan4-tools` | `8044284` / `a335ef0`: FROZEN for plan 4; never merged |
| `replay-harness` | `efada62` |
| `review/*` (s85) | `argon-presets-twoarm` `ce53c05`, `cursor-restate-presets-twoarm` `6882fce`, `argon-runbook-d` `f61fe96`, `argon-runbook-c` `de1c107`; older: `cursor-restate-fix1` `66a4c35`, `argon-fix1` `ce6f6ef`, `deepseek-f2` `da2dcb0`, `argon-commits-f1f4` `35fa3d3`, `cursor-restate` `e4d96f4`, `argon-r5` `417a2bb` |
| Plan 4 inputs | insurance `eurusd_window_p4_raw.sha256` (sends B, C, D; `ticks_53077984_EURUSD_win_ins.csv`, `bad_px=1`); w2h `fe37e42a...` not in git, in `D:\mt5-replay\MQL5\Files\replay` |
| Research added in s85 | `research/alt_adds/` (the excursion script, tests, `solve_exit_eq_add.py`, results, inputs hashed) |
| Bridge | the patch goes straight to `~/Downloads` (device commit); the operator checks it with `Get-FileHash` |
| pipshed `main` | `fb0f9c8`; branch **`twoarm-fleets` `320afe6`** verified and PARKED (merge after D AND C: D's runbook s7) |
| Linux boxes | repos `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...`; the runbooks pull `main` first |

## 2. NEXT, IN ORDER

1. The operator applies s85o; tree checked; pushed.
2. **The runbook for the new server and FTMO's fleet E (C158)**: a new Linux + wine server (not wine-d),
   a NEW FTMO demo, the `presets_e` `_t1` set (12; q90 ALT), the box clock, the request budget (~2,500 a
   day), a fifth pipshed page service `linuxe` (Railway "pipshed Fleet E", D's runbook s7). Through review
   like D's and C's.
3. Sun 18 Oct before the open (~21:05Z): A's status read (equity, the day, any marker since 16 Oct 13:45Z).
4. Mon 19 Oct 20:50-20:59Z: the carry pass.
5. **Tue 20 Oct from 22:10Z: the export** (the runbook with new names; the tick dump `2026.10.14 01:30` to
   `2026.10.21 01:30` server: `bad_px` 1 expected, more is a stop), hashed; then plan 4 s7 step 4 on
   `8044284` / `a335ef0` (`build_holdout.py --sends-extra-* --window-end-ms 1792544400000`; manifest; T0;
   the 12 runs; `compare.py --t0-price order`; `score_plan3.py --cut-ms 1792108800000 --tol
   results/plan3/live_spread_n3.txt`); the verdict by plan 4 s5.
6. **From Wed 21 Oct in market hours: D, then C, by their runbooks** (never at the same time); pipshed
   `twoarm-fleets` merged after both; FTMO when its server is up and the trial ended.
7. After the trial (~21 Oct): C153, C155, C156; C154 after the export; C159 before any fleet nears the
   194 guard with GBPCHF or USDCAD.

## 3. TRAPS (full list in 02_TRAPS)

- **A cap cut strands the next add:** a side at 7 under cap 8 rests `|L07|ENT`; after a cap-7 reload the EA
  neither cancels nor re-uses it, and a fill halts the chart on I7. Reload only with both sides <= 6
  (Trade tab, not pipshed) and delete any resting `|L07|ENT` (the runbooks s4). A side above the new cap
  halts at once. **An exit change on a reload is supported** (the exit label GV); never move a live chart
  to a new terminal.
- **Remove-then-Attach (C's re-attach):** an entry filled in the gap prints one `STARTUP_EXIT_SHORTFALL`
  (BAD to the checker): allowed at 1 per side with its `|EXT` resting; 2 is a STOP.
- **The desktop shell is PowerShell:** `Get-FileHash`, not `sha256sum`; quote `'HEAD^{tree}'` (unquoted it
  prints the PARENT commit); `$HOME\Downloads`, not `~`; `;`, not `&&`; quote comma lists.
- **Argon leaves the operator's copy on its review branch:** every patch step starts with `git status -sb`
  and `git switch main`.
- **One `git am` per command line:** a line re-applying an applied patch stops halfway; `git am --abort`.
- Build every patch on a fresh fetch; test `git am` on a fresh clone of GitHub. **Never reuse a patch's
  file name in Downloads**; hash it; give the tree.
- **An archive's OUT_BY rows carry the OTHER position's entry as `deal_price`:** never a market price.
- **`bad_px` counts ticks the dumper dropped;** wine-d's dump dialog shows the chunk input's old comment.
- **Reviewers invent when they quote** (Argon on both runbooks: whole passages that are not in the file):
  every quote with its line and commit, checked.
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

Line count: 165
