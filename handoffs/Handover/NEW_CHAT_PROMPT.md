This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-03 ~17:20Z (SATURDAY; ROUND 1 BETWEEN WINDOWS)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s29 to **s43**
(s43 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-01, **2026-10-02** (early,
day, afternoon, late afternoon, night) and **2026-10-03** (early, morning, afternoon x2, late afternoon); `handoffs/Handover/08_BACKLOG.md` (above
all section C1, the critical path; C93, C96, C99, C100, C117); `docs/architecture/fleet-d.md` s6 (D1, the compass
round) and s7 (all round-1 amendments);
`docs/architecture/geometry-cycle3.md` A7 (FTMO cut to seven);
`docs/architecture/ADR-165-continuous-reroll.md` (s4, s9, s10);
`docs/runbooks/monday-build-2026-10-05.md` and `docs/runbooks/compass-round.md`
(both in full: Monday's two jobs); `prompts/cursor_v22a_c93_c100.md`
(the open prompt); `docs/architecture/MEMO_2026-10-03_post_once_execution.md`;
`docs/architecture/ADR-162-virtual-lattice.md` s13-s19;
`docs/architecture/ADR-153-geometry-independence.md` (the L0 re-quote:
drift max(D, S - W)); `docs/architecture/cycle4-live-geometry-search.md`
s8 (the compass); `research/compass/README.md` (C91 scorer);
`docs/runbooks/c63-commands.md` s6 (roll-watch);
`handoffs/Handover/06_LINUX_WINE_BOX.md` s7, s9, s10;
`handoffs/Handover/07_ROADMAP.md` (s1 FTMO's rule; GATE BEFORE REAL
MONEY); `handoffs/Handover/09_EVENT_LOG.md` (add to it);
`handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

**YOUR FIRST REPLY, after the reading (operator's request, 2 Oct):**
1. A short restate of the state as you found it in git (HEADs, fleets,
   anything in the docs that disagrees with itself).
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block: whatever the docs
   leave unclear or that only the previous chat would know (live state
   after the docs were written, half-finished steps, exact commands it
   used, rulings it heard but may not have written down). Short,
   specific, answerable in a line each; at most ~12. The operator pastes
   the answers back; then follow s43's NEXT SESSION list.
Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME:**
- **Cycle 3** (VPS, FTMO 1514731800, `aa6970a`): **SEVEN instances**
  since 2 Oct ~15:40Z (the ring: EURUSD, GBPUSD, EURGBP, AUDCHF, CADCHF,
  NZDCAD, AUDNZD, all `_OPT`; geometry-cycle3 A7) after FTMO's warning:
  **2,000 requests a day including modifications and cancellations,
  repeats -> account disabled (C106)**. Reply sent by email (nothing on
  method; "we definitely dont want to imply we are market making").
  Keeps the ADR-160 gate and ADR-158 breaker ($500 limit is real).
  After any `connection ... lost`, check for orphans (strip:
  ORPHAN_EXT). `https://pipshed.com`.
- **Builds since 2 Oct 14:16-14:55Z (API entry stop OFF, C100 hotfix):**
  IC `893e065` (`hotfix-api-stop`), FTMO `aa6970a` (`hotfix-api-stop-ftmo`,
  tag `vps-aa6970a`). Never run `deploy.ps1` on a branch (it pulls main).
  C105 DONE 3 Oct: `main` `2859be6` = ADR-165 + the hotfix (2447/2447).
- **Fleet B** (wine-test, IC 53066709): the ANCHOR, 11/11. Lattice ON.
- **Fleet C** (wine-c, IC 53071896): D1 ADD probe, 11/11. Charts load
  `Scripts\fxmatrix\fxgrind.ex5` (C88).
- **Fleet D** (wine-d, IC 53077984): D1 EXIT probe, 11/11.
- **B, C, D:** `InpBreakerEnable=false` (since 1 Oct 21:16-21:28Z) and
  `InpStrandedThreshPips` = width + 1 (since 2 Oct 02:55-03:05Z; deadband
  4): the empty side's L0 re-quotes after 4 pips of drift.
- **IC stays at 11 instances until the Monday build** (Mon 5 Oct after
  22:00Z): the six twins (magics 22260902, 22260802) retire by hand, the
  repo goes to `main`, ONE file is compiled (wine-c: the Scripts copy),
  `InpLatticeReroll=true` by F7 per chart; then pipshed C119. IC keeps
  all nine pairs (compass data points; operator 3 Oct).

**Stuck sides:** a capped side with every layer rolled cannot roll once
the market passes its next level until ADR-165 goes ON in the Monday
build. Until then: commanded eject (Global Variable `GRIND_EJECT_<magic>`
= ticket of the highest effective entry, long), the operator's call each
time; read the Trade tab first; VNC paste does not reach MT5 (type
tickets). Round 1's hand ejects are in `research/compass/round1.json`.

**D1 round 1:** FTMO days Fri 2 Oct + Mon 5 Oct; scored Mon 5 Oct after
22:00Z (`research/compass/compass_score.py` + `round1.json`, runbook
compass-round s4.2: study export, wine-c bid/ask, journals ->
`disconnects.py`). Realised P&L decides; MTM reported only; hand ejects
cut with salvage (>= 1 day) else VOID; NZDCAD is the control pair.

**Operator rulings (do not re-open):** rings of seven pairs, each currency
twice, NO twins, compass fleet against fleet, the SAME seven pairs on B,
C, D (C96); cap 10 after the rings (C99); ADR-165 after round 1 (= an EA
BUILD on B, C, D); C103: no depth gate ("boring is best"); no API limit
may stop trading ("i do not want an api limit to stop trading"); FTMO
cut by fewer instances, not a lower stop ("a sledgehammer"); no wind-
down brake; no broker contact; FTMO stays on the desktop test terminal;
post-once execution (C117) with ONE 2,000-request pool, first come first
served; the 200 positions+orders limit holds on IC too ("software
limitation. we tested this"); MyFundedPerps probably skipped.

**Reading live state:** WebFetch of `https://pipshed.com/api/telemetry/live?instance=<id>`
works (summarised); the browser pane on the operator's desktop is
allowed on pipshed.com (site) and can run page JS. For exact numbers the
operator saves `/api/g/k7m9p2x4q/status{,_b,_c,_d}/<new segment>` to
Downloads; Claude fits bid/ask from the books and infers VLs from exit
targets (traps 2 Oct early). Downloads and `D:\fxmatrix\temp` must be
GRANTED each session (device folder access).

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z;
carry pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after
~21:00Z: 40 summaries, 34 after Monday; BOOT s6).

**The ejection study's replay is FROZEN** (`ab5d4c8`); 1-7 Oct holdout
(C84). **Never run `fxgrind_tests` on a terminal with live EAs. Compile
ONE file, the one the charts load.** The telemetry key is never pasted,
committed or screenshotted (crop so `TelemetryURL` is the last row).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `1bb077a` pushed (v2.2a prompt amended; then the s45 docs patch). Branch `v22a-recon-api` `8a3ec0c`: v2.2a complete (C93 + C100 + the RECON_SCAN_RACE throttle), suite 2525/2525, DeepSeek done, NOT merged. EA code = `2859be6` (ADR-165 merged, default OFF; the API hotfix merged 3 Oct, C105); presets `4a1e30e` (`InpLatticeReroll=true`); IC boxes run `893e065` until the Monday build; suite 2447/2447 |
| pipshed `main` | `bb6bb7a` (C113-C115 tables); 38/38 suites. Local, NOT pushed: `99980da` tests + `4d294a6` C119 (retire the six twins, B/C/D strips = nine), tree `e3b23a94`, 39/39; in Downloads as `pipshed_c119_APPLY_MONDAY_AFTER_TWINS_RETIRED.patch`: apply only AFTER the twins are removed |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances; MetaTrader LiveUpdate pending (Later) |
| wine-test (B) | `893e065`; `ssh box1`; VNC: `ssh -L 5910:localhost:5910 box1` (x11vnc `-forever`) |
| wine-c (C) | `893e065` (Scripts copy); `ssh box2`; VNC 5911 the same way |
| wine-d (D) | `893e065`; `root@216.128.158.33`; VNC 5912, x11vnc `-forever` |

---

## 2. NEXT, IN ORDER (= HANDOFF s45 NEXT SESSION; backlog C1 is the critical path)

1. The questions for the previous chat (above).
2. DONE 3 Oct 17:20Z: both patches pushed (`c92d9c2`, `27e1e77`); s44
   (runbook and register fixes) next.
3. DONE 3 Oct ~19:30Z (s45): v2.2a through Gemini (twice), Cursor,
   DeepSeek and the audit fix; `8a3ec0c` 2525/2525. **No merge into
   `main` before the Monday build** (runbook s3.3); merge after it.
4. Sunday open checks.
5. Mon 5 Oct after 22:00Z: score round 1; the Monday build; pipshed C119;
   the IC twins' Global Variables (runbook s7, the gv scripts).
6. Operator any time: files to the Surface; FTMO email on TP / SL vs the
   200 (C117); the scouting decision (C96).
7. After Monday: C99 (cap 10 + fixed widths, one reload per chart; fixes
   C88), round 2, v2.2a deploy; later C98, C103 (own ADR), C117 ADR,
   C118, C84 after 7 Oct.

---

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names (`InpBreakerEnable` = "ADR-158
  account daily-loss breaker"); `InpStrandedThreshPips` and
  `InpDeadbandPips` show their names and are in the CONFIG line. Read
  `InpTelemetryInstance` first (twins), never Load, change one row, OK.
- The L0 re-centre has no direction check: keep S >= W - D.
- "Stuck" comes one add step before `ROLL_STRANDED`.
- Retiring an instance: remove the EA (deinit 1, not F7 -> OK = 5),
  entries first, Close By, then market; then pipshed's retired list.
- PowerShell: quote `"HEAD^{tree}"`. Before `git am`, check
  `git log origin/main..HEAD` (a patch applied but not pushed).
- Grep logs, never paste them (UTF-16: `iconv`); `Select-String
  -CaseSensitive`; Wine logs `MQL5/logs`, field 3 is the time; one shell
  step per message.
- Verify every agent claim in committed source; count every line.
- Sandbox PG for pipshed suites: role `verify`, fresh database per suite.
- Avoid pushing pipshed `main` at 20:50-21:00Z.

---

## 4. WORKING PRACTICE

- **One shell step per message**; say WHERE each command runs.
  Plain-text pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, `git format-patch`,
  checks `git am` on a clean clone at the base, delivers to Downloads with
  the expected tree (and reads it back); the operator `git am`s, checks
  the tree, pushes; Claude verifies on GitHub. **Claude never pushes.**
- Features: spec (Gemini questions inside, RESTATE AND STOP first) ->
  Gemini -> Cursor on a branch -> Claude reads the commits -> suite ->
  DeepSeek for anything that moves orders -> merge `--no-ff`. pipshed
  fixes: tests first (predicted failures), then the fix, every suite on
  a fresh scratch PG. One document at a time; one paste per step.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 184
