This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-02 ~15:10Z (FRIDAY; ROUND 1 WINDOW 1 RUNNING)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s29 to **s32**
(s32 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-01 and **2026-10-02 early**;
`handoffs/Handover/08_BACKLOG.md` (above all C96, C99-C104);
`docs/architecture/fleet-d.md` s6 (D1, the compass round) and s7 (all
round-1 amendments); `docs/architecture/ADR-165-continuous-reroll.md`
(s4, s9, s10); `docs/architecture/ADR-162-virtual-lattice.md` s13-s19;
`docs/architecture/ADR-153-geometry-independence.md` (the L0 re-quote:
drift max(D, S - W)); `docs/architecture/cycle4-live-geometry-search.md`
s8 (the compass); `research/compass/README.md` (C91 scorer);
`docs/runbooks/c63-commands.md` s6 (roll-watch);
`handoffs/Handover/06_LINUX_WINE_BOX.md` s7, s9, s10;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/09_EVENT_LOG.md` (add to it);
`handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live, 11/11 each. Call the boxes by HOSTNAME:**
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes; ejects at cap (ADR-157); keeps the ADR-160 gate and ADR-158
  breaker ($500 limit is real). After any `connection ... lost`, check
  for orphans (strip: ORPHAN_EXT). `https://pipshed.com`.
- **Builds since 2 Oct 14:16-14:55Z (API entry stop OFF, C100 hotfix):**
  IC `893e065` (`hotfix-api-stop`), FTMO `aa6970a` (`hotfix-api-stop-ftmo`,
  tag `vps-aa6970a`). Never run `deploy.ps1` on a branch (it pulls main).
- **Fleet B** (wine-test, IC 53066709): the ANCHOR. Lattice ON.
- **Fleet C** (wine-c, IC 53071896): D1 ADD probe. Charts load
  `Scripts\fxmatrix\fxgrind.ex5` (C88).
- **Fleet D** (wine-d, IC 53077984): D1 EXIT probe.
- **B, C, D:** `InpBreakerEnable=false` (since 1 Oct 21:16-21:28Z) and
  `InpStrandedThreshPips` = width + 1 (since 2 Oct 02:55-03:05Z; deadband
  4): the empty side's L0 re-quotes after 4 pips of drift.

**Stuck sides are the night's work.** A capped side with every layer
rolled cannot roll once the market passes its next level (ADR-165 is
merged but NOT live). Operator ruling 2 Oct: unstick them by commanded
eject (Global Variable `GRIND_EJECT_<magic>` = ticket of the highest
effective entry, long), his call each time. Done in window 1: NZDCHF B
L01, NZDCHF C L00, AUDCHF C L10 (~-$7-8 each). Watch: NZDCHF D (target
L00 1978125665), NZDCHF C, AUDCHF B. Read the Trade tab first; VNC paste
does not reach MT5 (type tickets).

**D1 round 1:** FTMO days Fri 2 Oct + Mon 5 Oct; scored Mon 5 Oct after
22:00Z (`research/compass/compass_score.py` + `round1.json`); twins kept
to the end.

**Operator rulings (do not re-open):** rings of seven pairs, each currency
twice, NO twins, compass fleet against fleet, the SAME seven pairs on B,
C, D (C96); cap 10 after the rings (C99); ADR-165 after round 1 (= an EA
BUILD on B, C, D: `0335f25` has no `InpLatticeReroll`); C100 is EA code,
not agreed for Monday; C103: no depth gate ("boring is best"); no wind-
down brake; no broker contact; FTMO stays on the desktop test terminal.

**Status without pipshed in the sandbox** (proxy 403): the operator saves
`/api/g/k7m9p2x4q/status{,_b,_c,_d}/<new segment>` to Downloads; Claude
fits bid/ask from the books and infers VLs from exit targets (traps
2 Oct early). Downloads and `D:\fxmatrix\temp` must be GRANTED each
session (device folder access).

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
| fxmatrix `main` | docs to 2 Oct ~15:10Z; EA code = `3df13f0` (ADR-165 merged, default OFF; WITHOUT the API hotfix: C105); suite 2447/2447 |
| pipshed `main` | `eb19e5c`; pipshed.com runs gunicorn (Railway start command, not in the repo yet: C102) |
| VPS (cycle 3) | `5685e4f`; MetaTrader LiveUpdate pending (Later) |
| wine-test (B) | `ssh box1`; VNC: `ssh -L 5910:localhost:5910 box1` + x11vnc `-once` (keep the viewer open while working) |
| wine-c (C) | `ssh box2`; VNC 5911 the same way |
| wine-d (D) | `root@216.128.158.33`; VNC 5912, x11vnc `-forever` |

---

## 2. NEXT, IN ORDER (= HANDOFF s31 NEXT SESSION)

1. Watch: FTMO AUDCHF heartbeat; stuck sides; IC rejection codes;
   pipshed memory. pipshed start command into the repo (C102).
2. The L0 change measured: `--l0churn`, empty-side fills, `api_count`.
3. Docs: split the backlog (critical path / before real money /
   notebook); prune done rows.
4. Friday: exports (C83), `gt_report.py`, 1 Oct P&L by currency and pair
   per fleet, C103 measurement -> ring note + compass routine (C96, C104)
   to Gemini (one document).
5. Mon 5 Oct after 22:00Z: score round 1 (C91). Then C105 (merge the
   hotfix into main) and the Monday build.
6. Later: C98, C100, C101, C102, C93, C92, C88, C75, C9, C84 after 7 Oct.

---

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names (`InpBreakerEnable` = "ADR-158
  account daily-loss breaker"); `InpStrandedThreshPips` and
  `InpDeadbandPips` show their names and are in the CONFIG line. Read
  `InpTelemetryInstance` first (twins), never Load, change one row, OK.
- The L0 re-centre has no direction check: keep S >= W - D.
- "Stuck" comes one add step before `ROLL_STRANDED`.
- Grep logs, never paste them (UTF-16: `iconv`); Wine logs `MQL5/logs`,
  field 3 is the time; one shell step per message.
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
  DeepSeek for anything that moves orders -> merge `--no-ff`. One
  document at a time; one paste per step, for agents too.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 140
