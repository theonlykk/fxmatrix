This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-05 ~19:45Z (MONDAY; BEFORE THE MONDAY-NIGHT RUNBOOK)

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED
(operator 3 Oct: "lets focus on fxmatrix - even when we dont have urgent
fixes"). Do not read or ask about it unless the operator brings it back.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s49 to **s57**
(s57 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-03, 2026-10-04 and
**2026-10-05** (early, day); `handoffs/Handover/08_BACKLOG.md` (section C1;
C93, C99, C123-C130); `docs/runbooks/monday-night-2026-10-05.md` and
`docs/runbooks/monday-build-2026-10-05.md` (tonight, in full);
`docs/runbooks/compass-round.md` (the loop; this week at cap 8);
`docs/architecture/MEMO_2026-10-05_width_depth_counter_side.md` (today's
rulings: cap 8, tight widths, deadband 2, the counter side);
`docs/research/holdout-verdict-criteria.md` (ACCEPTED: the window opens
5 Oct 22:00Z; nothing of it is computed before Friday's close);
`docs/research/ftmo-pass-probability.md` (C124);
`docs/research/markout-variance-study.md`; `scripts/ic_presets.py` (stage
`round`) with `scripts/ic_geometry_r2.json` (PROVISIONAL round-2 table);
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
  D (wine-d, 53077984, exit probe):** 11/11 each on `893e065` UNTIL
  TONIGHT'S BUILD (Mon 5 Oct after 22:00Z): twins (magics 22260902,
  22260802) retire by hand, repo to `main` (EA code `2859be6`), ONE file
  compiled (wine-c: `Scripts/fxmatrix/fxgrind.mq5`, C88), re-roll ON by F7
  per chart; then pipshed C119. Breaker off on B, C, D (no account-level
  backstop once re-roll is ON).
- **This week (operator 5 Oct): compass rounds at cap 8.** Round 1 is
  scored tonight (both thresholds; the operator picks). Round 2's reload
  Tue 6 Oct in session = tight widths (the tightest the ADR-153 guard
  allows), S = W + 1, **deadband 2**, B anchor / C add probe / D exit
  probe, from `ic_presets.py --stage round` (`_r2` presets). Round 2 = Wed
  7 + Thu 8; round 3 reload Fri. Cap 10, the fixed-width table and the
  AUDUSD scout are DEFERRED.
- **Stuck sides re-roll on the first ticks after tonight's re-roll ON**
  (EURGBP long B, C, D; EURUSD long B, C; NZDCHF long B, C, D at the 5 Oct
  02:52Z read): expected, not a STOP.

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
40 summaries, 34 after tonight's build).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `7ebcfe8` (presets stage `round`, tree `9c0ea540`); `6b15b07` memo; `67e5f02` C125 accepted; `7a52e27` T3 driver; `9672415` C124; `f5f0c93`; `239a45d`; `bb8b81d`; `54f0738` s56 + this s57 docs patch. EA code `2859be6`; branch `v22a-recon-api` `8a3ec0c` (v2.2a: C93 + C100 + the RECON_SCAN_RACE throttle, 2525/2525, NOT merged) |
| pipshed `main` | `bb6bb7a`, 38/38. Patches in Downloads (go by the TREES): `pipshed_c119_APPLY_MONDAY_AFTER_TWINS_RETIRED.patch` (tree `e3b23a94`): tonight, only after the twins are removed. C121 (AUDUSD) WAITS for AUDUSD; C123 must be REBUILT on C119 alone (it sits on C121); C129 geometry table to build |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances |
| wine-test (B), wine-c (C), wine-d (D) | `893e065` until tonight; `/root/mon_logcheck.awk` installed (2688 bytes); `ssh box1` / `ssh box2` / `root@216.128.158.33`; VNC 5910 / 5911 / 5912 |

## 2. NEXT, IN ORDER (= HANDOFF s57 NEXT SESSION)

1. The questions for the previous chat (above).
2. Mon 5 Oct after 22:00Z: `docs/runbooks/monday-night-2026-10-05.md` end
   to end (score round 1; the build; pipshed C119).
3. The verdict into `scripts/ic_geometry_r2.json`; `--stage round` dry run
   then `--write`; the verdict and round-2 tables to Gemini (attached);
   `round2.json`; one docs patch.
4. Tue 6 Oct in session: the round-2 reload (wine-d first, GBPUSD pilot).
5. Quiet slots: C123 rebuilt on C119; C129; then the width-guard change and
   C127 to Gemini (one document).
6. Sat 10 Oct: holdout scoring (criteria s5): FTMO bid / ask and deal
   history dumps, the archive export, `research/holdout/holdout_verdict.py`.
7. Later: v2.2a merge and deploy; C128 (cap 5 vs 8 round); C130.

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

Line count: 151
