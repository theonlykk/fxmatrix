This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-16 ~22:05Z (FRIDAY; PLAN 4 FROZEN, ITS WINDOW OPEN; A'S BREAKER OFF; FLEET D TWO-ARM RING PROPOSED)

**Prepared 16 Oct ~22:05Z at the hand-over of the s84 chat (HANDOFF s84 and its continued blocks 1-8;
patches s84a-s84i).** The EURUSD replay (an MQL5 harness on the EA's own engine) is under its fourth
pre-registration: **plan 4** (`docs/research/replay-calibration-eurusd-4.md`). Its development gate PASSED
on both seen windows at timing 1 and it is **FROZEN: harness `replay-plan4` `8044284`, builders
`plan4-tools` `a335ef0`** (s2's one amendment, `159e388^`). Its window runs **Fri 16 Oct 00:00 to Wed 21 Oct
01:00 server**; the export is **Tue 20 Oct from 22:10Z**, then the window's runs and the verdict.

**What the s84 chat did (in order):** the calibration window's 12 gate runs and score (PASS; s84a); the
freeze (s84b); status, carry, the IC request budget (IC accepts more than 2,000 a day, C78), C150 (s84c);
the evening's strategy discussion documented (s84d); A's missing offers = ADR-160's float gate; **the
operator turned A's breaker OFF** (s84e); why the range bleeds, measured: a rolled layer's exit trails one
exit behind the extreme, so rolls realise at every turn of a range wider than the stack (s84f,
`research/roll_recovery/`); a "lazier" rolled exit considered and **REJECTED** by the operator (s84g); **fleet
D as a two-arm ring PROPOSED** (s84h, C157); Friday's carry pass and this hand-over (s84i).

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git
first, including `plan4-tools`, `replay-plan4` and the `review/*` branches. **If `main` has moved past
s84i, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s84 and all its "continued" blocks (1-8)**; follow the LAST NEXT
   SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-15** and **2026-10-16**.
4. `docs/research/replay-calibration-eurusd-4.md` (all of it, with s2's amendment).
5. `docs/runbooks/plan3-holdout-export.md` (the export runbook plan 4 s3 reuses with new names).
6. `docs/research/roll-geometry-notes-2026-10-15.md` (s1-s8) and
   `docs/research/fleet-d-two-arm-ring-2026-10-16.md`.
7. `handoffs/Handover/08_BACKLOG.md`: C78, C150-C157.
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, plan 4's freeze line, the fleets, the
   time to the next time-gated step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the operator to copy and paste
   across in ONE block, at most ~12, each answerable in a line.

Do not start any fleet action, run or export before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):** seven `_OPT` instances, EA
  `5bb5fdb`. **Breaker OFF since 16 Oct ~13:44-13:45Z** (operator, F7 on all seven; ADR-160's float gate
  had blocked every entry from 08:25:52Z). With it off, nothing on A stops new entries before FTMO's $500.
  **The repo presets (`ea/presets/*_opt_a_r2.set`) and `scripts/ic_presets.py` still say true: DO NOT
  load A's presets.** Trial ends ~21 Oct. Follow its EQUITY, not realised.
- **IC B (wine-test, 53066709), C (wine-c, 53071896), D (wine-d, 53077984):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off; round 3 geometry, FROZEN until plan 4's window closes
  (Tue 20 Oct 22:00Z). **IC access (C150):** the web login refused since 12 Oct; the MT5 logins work (all
  three connected 15 Oct). **Do not advise re-verifying with different details.**
- **The carry pass runs 20:50-20:59Z nightly.** Fridays: `failed` 3-4 per instance (10025),
  `mult_tomorrow` 0: not news. 16 Oct: 34 / 34 clean, no marker.

**Operator rulings (do not re-open):**
- A's breaker OFF (16 Oct: "keeping a trial clean that we dont want makes no sense"); the trial runs to
  its end otherwise unchanged.
- Plan 4 frozen (harness `8044284`, builders `a335ef0`); no mark, tolerance, match rule or window changes;
  timing 1 decides, timing 0 is reported. Its blind period was EMPTY (the freeze came first): EURUSD can be
  read any time.
- No time-series analysis or price signals: work from our own trades.
- The lazy rolled exit is REJECTED (16 Oct; reasons in the roll-geometry notes s7).
- **Fleet D becomes a two-arm ring after Tue 20 Oct 22:00Z (C157, PROPOSED / agreed in principle):**
  USDCAD, EURUSD, EURGBP, GBPCHF, AUDCHF, AUDCAD; OPT + a wide ALT each; **cap 7 on D**. Elsewhere the cap
  stays 8; rolls only at 8/0 (roll gate 0).
- Compass rounds stopped; ADR-167 parked; the slower light side dropped.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `b5c6302` (s84h) + s84i (this patch). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-plan4` / `plan4-tools` | `8044284` / `a335ef0`: FROZEN for plan 4; never merged |
| `replay-harness` | `efada62` (plan 3's `145f092`) |
| `review/*` | `cursor-restate-fix1` `66a4c35`, `argon-fix1` `ce6f6ef`, `deepseek-f2` `da2dcb0`, `argon-commits-f1f4` `35fa3d3`, `cursor-restate` `e4d96f4`, `argon-r5` `417a2bb` |
| Gate | inputs `research/replay/inputs/eurusd_20261008_p4`, `eurusd_holdout_p4`; runs `runs_gate_hold/`, `runs_gate_cal/`; scores `research/replay/results/plan4/` |
| Research added in s84 | `research/roll_recovery/` (rolled closes and recovery; tests), `research/pair_choice/` (pair costs, FTMO 21-pair minute bars) |
| `D:\mt5-replay` | the `8044284` build; `Files\replay` holds the calibration set and its timing-0 outputs |
| `D:\fxmatrix` | on `main` |
| Bridge | grants are per session: ask for `~/Downloads` alone; `D:\mt5-replay\MQL5\Files\replay` and `D:\fxmatrix\research\replay\runs` together |
| pipshed `main` | `6ea487e` |
| Linux boxes | `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...` |

## 2. NEXT, IN ORDER

1. The operator applies s84i; tree checked; pushed.
2. **Sat 17 Oct: the insurance copies** (plan 4 s3; C150): a EURUSD tick dump on wine-d and `send_logs`
   exports for B, C, D (`archive_counts.py --export-sends --instance ...`), copied to Downloads under NEW
   names and hashed.
3. **Tue 20 Oct from 22:10Z: the export** (`docs/runbooks/plan3-holdout-export.md` with new names), hashed;
   then **plan 4 s7 step 4**: the window's inputs with `build_holdout.py` at `a335ef0` (`--sends-extra-*`
   joining the `_2210` sends; `--window-end-ms 1792544400000`), manifest, T0, the 12 runs on `8044284`,
   `compare.py --t0-price order`, `score_plan3.py --tol results/plan3/live_spread_n3.txt --cut-ms
   1792108800000`; the verdict read by plan 4 s5.
4. **C157 prep, no fleet change before Tue 22:00Z:** the operator's answer on "running 0.04 lots" (per
   layer, per arm or net per pair?); ALT's adds per pair from our own fills ("the pips that would have
   worked these last few days"); the D runbook (retire GBPUSD, CADCHF, NZDCHF, NZDCAD, AUDNZD safely; cap
   8 -> 7 without tripping I7; the ALT presets and ids; pipshed's strip).
5. After the trial (~21 Oct): C153 (the autopsy: the note's s5-s8, the hurdle), C155 (a float gate that
   blocks only the loaded side), C156 (pipshed "no roll" under re-roll); C154 after the export.

## 3. TRAPS (full list in 02_TRAPS)

- Every patch step starts with `git checkout main`; build every patch on `git checkout -B main
  origin/main` from a fresh fetch; test `git am` on a fresh clone of GitHub (a local clone's main can lag).
- **Never reuse a patch's file name in Downloads**; read every saved patch back and hash it; give the tree.
- **PowerShell turns an unquoted `a,b,c` into one space-joined string:** quote comma lists
  (`--codes "A,B"`); read the header line back before trusting "none".
- **A sync run needs `-Sync`;** check `RPL|RUN|<tag>|sync=` and `RPL|TIMING|` against the label and the
  outputs' mtime before staging. `ORDERS_KEPT|16|3/4` on C runs is expected.
- **An archive's OUT_BY rows carry the OTHER position's entry as `deal_price`:** never a market price.
- **Cap 8 -> 7 on a live side holding 8 layers trips I7 (not quarantinable):** never a blind F7.
- **No entries on an A pair with no halt:** read the float gate first (only while a chart runs the
  breaker on).
- **Reviewers invent when they summarise** (Argon, Grok): every quote with its line and commit, checked.
- Give a time-gated step only when its time has come. Your sandbox: `.md` files check out CRLF.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs (`Select-String`); never ask
  for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git format-patch`, checks `git am` on a
  fresh clone of GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back,
  hashes it and gives the tree hash. The operator runs `git am`, checks the tree and pushes. **Claude
  never pushes.** Document as you go (operator: "we end up forgetting stuff"); refresh THIS file in the
  patch that hands over.
- **Replay or EA changes:** a prompt in an artifact (questions for the reviewer inside it) -> review ->
  Claude checks every point -> Cursor RESTATES AND STOPS -> Claude checks the restate -> "go" -> Claude
  reads the commits -> the operator compiles -> the suite -> runs -> Claude reads the outputs. No change to
  `8044284` / `a335ef0` while plan 4 runs.
- If Cursor drifts from a prompt, the prompt was not good enough: fix the prompt.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 147
