This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-02 ~16:30Z (FRIDAY; ROUND 1 WINDOW 1 RUNNING)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s29 to **s37**
(s37 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-01 and **2026-10-02** (early,
day, afternoon, late afternoon); `handoffs/Handover/08_BACKLOG.md` (above
all C96, C99-C107); `docs/architecture/fleet-d.md` s6 (D1, the compass
round) and s7 (all round-1 amendments);
`docs/architecture/geometry-cycle3.md` A7 (FTMO cut to seven);
`docs/architecture/ADR-165-continuous-reroll.md` (s4, s9, s10);
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
   the answers back; then follow s35's NEXT SESSION list.
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
  C105: merge the hotfix into main before the Monday build.
- **Fleet B** (wine-test, IC 53066709): the ANCHOR, 11/11. Lattice ON.
- **Fleet C** (wine-c, IC 53071896): D1 ADD probe, 11/11. Charts load
  `Scripts\fxmatrix\fxgrind.ex5` (C88).
- **Fleet D** (wine-d, IC 53077984): D1 EXIT probe, 11/11.
- **B, C, D:** `InpBreakerEnable=false` (since 1 Oct 21:16-21:28Z) and
  `InpStrandedThreshPips` = width + 1 (since 2 Oct 02:55-03:05Z; deadband
  4): the empty side's L0 re-quotes after 4 pips of drift.
- **IC stays at 11 instances until Monday's score** (operator: "i think
  IC markets will not complain, but we are ready if they do"); the IC
  rings go in with the Monday build.

**Stuck sides:** a capped side with every layer rolled cannot roll once
the market passes its next level (ADR-165 is merged but NOT live).
Ruling: unstick by commanded eject (Global Variable `GRIND_EJECT_<magic>`
= ticket of the highest effective entry, long), the operator's call each
time. Done: NZDCHF B L01, NZDCHF C L00, AUDCHF C L10 (~-$7-8 each). At
15:57Z the NZDCHF longs (magic 22260701) were near stuck on all three IC
fleets; targets: **B L02 1971350419, C L01 1971369014, D L00
1978125665**. Read the Trade tab first; VNC paste does not reach MT5
(type tickets). C's slot guard was 195/194 (entries paused).

**D1 round 1:** FTMO days Fri 2 Oct + Mon 5 Oct; scored Mon 5 Oct after
22:00Z (`research/compass/compass_score.py` + `round1.json`); note the
ejects, the L0 change, the hotfix and FTMO at seven.

**Operator rulings (do not re-open):** rings of seven pairs, each currency
twice, NO twins, compass fleet against fleet, the SAME seven pairs on B,
C, D (C96); cap 10 after the rings (C99); ADR-165 after round 1 (= an EA
BUILD on B, C, D); C103: no depth gate ("boring is best"); no API limit
may stop trading ("i do not want an api limit to stop trading"); FTMO
cut by fewer instances, not a lower stop ("a sledgehammer"); no wind-
down brake; no broker contact; FTMO stays on the desktop test terminal.

**Reading live state:** WebFetch of `https://pipshed.com/api/telemetry/live?instance=<id>`
works (summarised); the browser pane on the operator's desktop is
allowed on pipshed.com (site) and can run page JS. For exact numbers the
operator saves `/api/g/k7m9p2x4q/status{,_b,_c,_d}/<new segment>` to
Downloads; Claude fits bid/ask from the books and infers VLs from exit
targets (traps 2 Oct early). Downloads and `D:\fxmatrix\temp` must be
GRANTED each session (device folder access).

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z;
carry pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 3`).

**The ejection study's replay is FROZEN** (`ab5d4c8`); 1-7 Oct holdout
(C84). **Never run `fxgrind_tests` on a terminal with live EAs. Compile
ONE file, the one the charts load.** The telemetry key is never pasted,
committed or screenshotted (crop so `TelemetryURL` is the last row).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | docs to 2 Oct ~16:30Z; EA code = `3df13f0` (ADR-165 merged, default OFF; WITHOUT the API hotfix: C105); suite 2447/2447 |
| pipshed `main` | `bb6bb7a` (C113-C115 tables, 2 Oct ~20:23Z); `830f04b` (C110, 2 Oct ~17:35Z: scalp reads re-read only new rows; pollers never overlap; HANDOFF s36); `0fd1a86`: C109 page opens on GBPUSD; C108 `GRIND_RETIRED_INSTANCES` (retired rows resolved, banner grey); C107 A strip = seven; `RAILWAY.md` (gunicorn start commands, C102); 34/34 suites |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances; MetaTrader LiveUpdate pending (Later) |
| wine-test (B) | `893e065`; `ssh box1`; VNC: `ssh -L 5910:localhost:5910 box1` (x11vnc `-forever`) |
| wine-c (C) | `893e065` (Scripts copy); `ssh box2`; VNC 5911 the same way |
| wine-d (D) | `893e065`; `root@216.128.158.33`; VNC 5912, x11vnc `-forever` |

---

## 2. NEXT, IN ORDER (= HANDOFF s35 NEXT SESSION)

1. The questions for the previous chat (above), then the IC fleets:
   NZDCHF eject targets, C's slot guard, rejection codes (C78 (2)).
2. FTMO: count tonight's day of requests from the VPS Journal (C106);
   retired Global Variables, by hand (C107).
3. Friday after the close: exports (C83), `gt_report.py`, P&L by pair ->
   the ring note + compass routine (C96, C104) to Gemini (one document);
   C103 measurement (`--l0churn`); backlog split (critical path / before
   real money / notebook).
4. Mon 5 Oct after 22:00Z: score round 1 (C91); C105; the Monday build
   (ADR-165 ON on B, C, D; IC rings; then cap 10, C99).
5. Later: C98, C100, C101, C93, C92, C88, C75, C9, C84 after 7 Oct.

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

Line count: 173
