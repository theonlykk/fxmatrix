This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-06 ~00:05Z (TUESDAY; AFTER THE MONDAY BUILD, BEFORE THE ROUND-2 RELOAD)

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED
(operator 3 Oct: "lets focus on fxmatrix - even when we dont have urgent
fixes"). Do not read or ask about it unless the operator brings it back.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s49 to **s59**
(s59 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-03, 2026-10-04 and
**2026-10-05** (early, day, night); `handoffs/Handover/08_BACKLOG.md` (section C1;
C93, C99, C123-C130); `docs/runbooks/monday-night-2026-10-05.md` and
`docs/runbooks/monday-build-2026-10-05.md` (RUN 5 Oct: their status rows);
`docs/runbooks/compass-round.md` (the loop; this week at cap 8; s11 round 1);
`docs/architecture/MEMO_2026-10-05_width_depth_counter_side.md` (today's
rulings: cap 8, tight widths, deadband 2, the counter side);
`docs/research/holdout-verdict-criteria.md` (ACCEPTED: the window opens
5 Oct 22:00Z; nothing of it is computed before Friday's close);
`docs/research/ftmo-pass-probability.md` (C124);
`docs/research/markout-variance-study.md`; `scripts/ic_presets.py` (stage
`round`, the half-pip rule) with `scripts/ic_geometry_r2.json` (round 2 from
round 1's verdict; 27 `_r2` presets);
`research/compass/README.md` and `round1.json`; `research/holdout/README.md`;
`docs/architecture/ADR-165-continuous-reroll.md` (s4, s9, s10);
`docs/architecture/fleet-d.md` s6-s7; `handoffs/Handover/06_LINUX_WINE_BOX.md`
s7, s9, s10; `handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/09_EVENT_LOG.md` (add to it);
`handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

**YOUR FIRST REPLY, after the reading (operator's request, 2 Oct):**
1. A short restate of the state as you found it in git (HEADs, fleets,
   anything in the docs that disagrees with itself).
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block: live state after the
   docs were written, half-finished steps, exact commands, rulings heard
   but not written down. Short, answerable in a line each; at most ~12.
Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME:**
- **Cycle 3** (VPS, FTMO 1514731800, `aa6970a`): SEVEN instances (EURUSD,
  GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD `_OPT`); 2,000 requests a
  day including modifications and cancellations (C106); ADR-160 gate and
  ADR-158 breaker ($500 daily limit is real; the breaker closes nothing).
  **FTMO decides the holdout verdict: no input change on A until the
  verdict (Fri 9 Oct close, or 16 Oct if extended).** C93 can halt it
  (`AMBIGUOUS_ADD_*`, 5 Oct GBPUSD): repair per traps 5 Oct day.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe),
  D (wine-d, 53077984, exit probe):** nine instances each (the twins
  retired 5 Oct night), on `main` (EA code `2859be6`) since the Monday
  build, re-roll ON on all 27 charts (wine-c's charts still load the
  Scripts `.ex5`, C88). Breaker off: no account-level backstop. Re-roll
  walks far rolled levels to the market and their old layers realise on
  the next bounce (traps 5 Oct night).
- **This week (operator 5 Oct): compass rounds at cap 8.** Round 1 scored
  (GC-1 $2.55; promoted EURUSD L add 6, AUDCAD L exit 9, AUDNZD S add 7).
  **No promotion this round** (GR2-1, operator 6 Oct): the winners repeat
  as probes. Round 2's reload Tue 6 Oct in session from the 27 `_r2`
  presets (tight widths, S = W + 1, deadband 2; EURGBP L C add 2.5, the one
  half-pip probe; `docs/research/compass-round2-review.md` s6).
  Round 2 = Wed 7 + Thu 8; round 3 reload Fri 9, its days Mon 12 + Tue 13.
  Cap 10, the fixed-width table and AUDUSD are DEFERRED.
- **Operator 6 Oct:** wine-c reloads by F7 + Load (C88 later); an FTMO C93
  halt in the window is restarted by F7 and listed with the results; open
  MTM reported every round, realised decides.

**Operator rulings (do not re-open):** realised P&L decides a compass
round (scalp P&L reported); equity decides the holdout; the one-hour
markout is a proxy (no entry optimisation; C103 as ruled: "boring is
best"); the flat side enters as fast as possible, passively (tight width);
the deadband stays for requests; cap 8 this week; NZDCAD control; IC keeps
nine pairs; no twins; no API limit may stop trading; no broker contact;
post-once execution with one 2,000-request pool (C117); the 200
positions+orders limit holds on IC too; mfperp parked.

**Reading live state:** WebFetch of
`https://pipshed.com/api/telemetry/live?instance=<id>` works (summarised);
for exact numbers the operator saves `/api/g/<token>/status{,_b,_c,_d}/<n>`
to Downloads. Downloads and `D:\fxmatrix\temp` must be GRANTED each
session (device folder access). **The bridge can keep the first version of
a Downloads file name: re-deliver a corrected file under a NEW name and
read it back** (traps 5 Oct day).

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z; carry
pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after ~21:00Z:
34 summaries since the Monday build: 7 FTMO + 27 IC).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | the s58 patch on `83a8f0d`: `6895c59` C125 T3 window, `51c27b8` / `e121fe2` half-pip probe rule, `646a387` round-2 table + 27 `_r2` presets + register, then the s58 docs (pre-am hashes: verify by TREE). EA code `2859be6`; branch `v22a-recon-api` `8a3ec0c` (v2.2a: C93 + C100 + the RECON_SCAN_RACE throttle, 2525/2525, NOT merged) |
| pipshed `main` | `96e0fba` (C119, tree `e3b23a94`), 39/39. C121 (AUDUSD) WAITS for AUDUSD; C123 must be REBUILT on `96e0fba`; C129, C131 to build |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances, frozen for the holdout (window 5 Oct 22:00Z - 9 Oct 21:00Z) |
| wine-test (B), wine-c (C), wine-d (D) | `main` since 5 Oct 22:38 / 22:59 / 23:16Z (D / C / B), re-roll ON; `/root/mon_logcheck.awk` installed; `ssh box1` / `ssh box2` / `root@216.128.158.33`; VNC 5910 / 5911 (both `-once`) / 5912 |

## 2. NEXT, IN ORDER (= HANDOFF s59 NEXT SESSION)

1. The questions for the previous chat (above).
2. (Done 6 Oct ~01:40Z: Gemini on the round tables; s59.)
3. Tue 6 Oct in session: the round-2 reload on B, C, D (`_r2`, F7 + Load,
   read back; wine-d first, GBPUSD pilot; done before 22:00Z); register
   rows; `round2.json` (windows 6 Oct 22:00Z - 8 Oct 22:00Z, control,
   reload times).
4. Quiet slots: the twins' Global Variables (monday-build s7); C123
   rebuilt on `96e0fba`; C131; C129; the width-guard change and C127 to
   Gemini (one document).
5. Sat 10 Oct: holdout scoring (criteria s5): FTMO bid / ask and deal
   history dumps, the archive export, `research/holdout/holdout_verdict.py`.
6. Later: v2.2a merge and deploy; C128 (cap 5 vs 8 round); C130.

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names; read `InpTelemetryInstance` first,
  never Load on the wrong chart, change one row, OK.
- Retiring an instance: remove the EA (deinit 1), entries first, Close By,
  then market; then pipshed's retired list.
- Lowering the cap halts a deeper side (I7). FTMO's re-quote drift is S - W
  (5-7 pips), not the deadband.
- PowerShell: quote `"HEAD^{tree}"`. Before `git am`, check
  `git log origin/main..HEAD`.
- Grep logs, never paste them (UTF-16: `iconv`); `Select-String
  -CaseSensitive`; one shell step per message.
- Verify every agent claim in committed source; count every line; clock
  times from the clock tool.

## 4. WORKING PRACTICE

- **One shell step per message**; say WHERE each command runs. Plain-text
  pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, `git format-patch`,
  checks `git am` on a clean clone at the base, delivers to Downloads with
  the expected tree (and reads it back); the operator `git am`s, checks the
  tree, pushes; Claude verifies on GitHub and resets its sandbox. **Claude
  never pushes.**
- Features: spec (Gemini questions inside, RESTATE AND STOP first) ->
  Gemini -> Cursor on a branch -> Claude reads the commits -> suite ->
  DeepSeek for anything that moves orders -> merge `--no-ff`. Research
  code and pipshed: tests first (predicted failures), hand-derived values,
  a mutation round. One document at a time; one paste per step.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 153
