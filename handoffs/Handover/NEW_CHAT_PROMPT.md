This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-01 ~21:45Z (THURSDAY NIGHT; ROUND 1 RUNNING; IC GATE OFF)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 has the RESTATE-AND-STOP rule;
s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s26 to **s30** (s30
ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-01 (above all "1 Oct
evening" and "1 Oct night"); `handoffs/Handover/08_BACKLOG.md` (above
all C92-C102); `docs/architecture/fleet-d.md` s6 (D1, the compass round)
and s7 (amendments, the IC breaker-off); `docs/architecture/ADR-165-continuous-reroll.md`
(s4, s9, s10); `docs/architecture/ADR-162-virtual-lattice.md` s13-s19;
`docs/architecture/ADR-160-carried-mtm-daily-limit.md` s1 (why FTMO
keeps the gate); `research/compass/README.md` (C91 scorer);
`docs/research/ejection-value-study.md` s12; `docs/runbooks/c63-commands.md`
s6 (roll-watch); `handoffs/Handover/06_LINUX_WINE_BOX.md` s7, s9, s10;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/09_EVENT_LOG.md` (add to it);
`handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live, 11/11 each. Call the boxes by HOSTNAME** (operator):
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes; ejects at cap (ADR-157); keeps the ADR-160 gate and ADR-158
  breaker (the $500 limit is real). No ADR-164 replay: after any
  `connection ... lost` in its Journal, check for orphans (C97 now shows
  them on the strip as ORPHAN_EXT). `https://pipshed.com`.
- **Fleet B** (wine-test, IC 53066709): the ANCHOR. `0335f25`, lattice ON.
- **Fleet C** (wine-c, IC 53071896): D1 ADD probe. `0335f25`, lattice ON.
  Its charts load `Scripts\fxmatrix\fxgrind.ex5` (C88): a build there
  means compiling `Scripts/fxmatrix/fxgrind.mq5`.
- **Fleet D** (wine-d, IC 53077984): D1 EXIT probe. `0335f25`, lattice ON.
- **B, C, D run with `InpBreakerEnable=false` since 1 Oct 21:16-21:28Z**
  (operator: "we need to trade"; the IC demo has no daily limit). The
  gate had blocked every entry on B and C since the CHF trend.

**D1 round 1 is running:** FTMO days Fri 2 Oct + Mon 5 Oct (window 1
opened Thu 22:00Z); scored Mon 5 Oct after 22:00Z with
`research/compass/compass_score.py` + `round1.json`. Round 1 keeps its
twins to the end.

**Operator rulings, 1 Oct (do not re-open):** the lattice never strands
(ADR-165, MERGED `3df13f0`, default OFF, deploy after round 1); no
wind-down brake; **rings of seven pairs, each currency exactly twice, NO
twins; compass probes are fleet against fleet** (C96); **cap 10 on IC
after the rings** (C99); the API entry stop becomes an input (C100); a
side-aware gate for FTMO later (C101); FTMO stays on the desktop test
terminal (traps 1 Oct evening). **No broker contact.**

**Watch every night on B, C, D (C87):** IC's rollover (21:00Z) can hold
requests ~13 min; no chart edits 20:50-21:15Z. The nightly carry pass
runs 20:50-20:59Z (`archive_counts.py --carrypass`).

**The ejection study's replay is FROZEN** (`ab5d4c8`); 1-7 Oct is the
holdout (C84).

**The operator's Downloads and `D:\fxmatrix\temp` are connected** when
the desktop app is linked: read his exports and suite output there;
deliver patches to Downloads (and read them back).

**One view of everything** (plain text; change the last segment every
fetch; it can be slow, C102 -- then read the EA logs on the box):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Never reattach, reload inputs or deploy with the market closed, with
spreads wider than the pairs' widths, or 20:50-21:15Z. **Never run
`fxgrind_tests` on a terminal with live EAs.** **Compile ONE file, the
one the charts load.** The telemetry key is never pasted, committed or
screenshotted (crop the Inputs dialog so `TelemetryURL` is the last row).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | docs to this handoff (1 Oct ~21:45Z) incl. 51 IC presets `InpBreakerEnable=false`; EA code = `3df13f0` (ADR-165 merged, default OFF); suite 2447/2447 (GBPUSD, EURUSD) |
| pipshed `main` | `eb19e5c` (C97 ORPHAN_EXT on `bb228e0` C94) |
| VPS (cycle 3) | `5685e4f`; MetaTrader LiveUpdate pending (Later) |
| wine-test (B) | `ssh box1`; VNC: `ssh -L 5910:localhost:5910 box1` + x11vnc `-once` (restart it each time) |
| wine-c (C) | `ssh box2`; VNC 5911 the same way; charts on the Scripts copy (C88) |
| wine-d (D) | `root@216.128.158.33`; VNC 5912, x11vnc `-forever` |

---

## 2. NEXT, IN ORDER (= HANDOFF s30 NEXT SESSION)

1. The carry check for the 1 Oct 20:50Z pass (44 summaries, no I6);
   confirm the dashboard legend shows ORPHAN_EXT.
2. Watch round 1 (B, C, D un-gated; FTMO gated as before).
3. Friday: exports (C83), `gt_report.py`, the 1 Oct P&L by currency and
   pair per fleet -> the **ring note** (C96) to Gemini (one document).
4. Mon 5 Oct after 22:00Z: score round 1 (C91). Then the Monday build:
   ADR-165 ON, the rings, C100; cap 10 (C99) after the rings.
5. Later: C98, C101, C102, C93, C92, C88, C9 timing, C84 after 7 Oct.

---

## 3. TRAPS (full list in 02_TRAPS)

- The Inputs dialog shows input COMMENTS: `InpBreakerEnable` = "ADR-158
  account daily-loss breaker". Read `InpTelemetryInstance` first on
  every chart (twins!), never click Load, change one row, OK.
- Suite: `.\desktop_sync.ps1` after every checkout, confirm a new symbol
  in the `MQL5\Scripts\` copy, run on GBPUSD and EURUSD only; the
  desktop terminal is logged in to FTMO (0 trade requests ever).
- Grep logs, never paste them (UTF-16: `-Encoding Unicode` / `iconv`).
  Wine log folder is lowercase `MQL5/logs`; field 3 is the time.
- A link stall drops deals before MT5 says "lost": check every book.
- Verify every agent claim in committed source; Cursor's commit messages
  and hashes are unreliable; count every line.
- PowerShell: `git rev-parse 'HEAD^{tree}'` (quoted).
- Sandbox PG: role `verify`, port 55432, socket `/var/tmp/pgverify`
  (restart with `pg_ctl` if refused), fresh database per suite.
- Avoid pushing pipshed `main` at 20:50-21:00Z.
- The card, not the remote desktop, says whether a fleet is alive.

---

## 4. WORKING PRACTICE

- **One shell step per message**; the operator pastes output back. Say
  WHERE each command runs (desktop PowerShell, VPS PowerShell, `ssh
  box1` = wine-test, `ssh box2` = wine-c, wine-d, GUI). Plain-text
  pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, builds
  `git format-patch`, checks it with `git am` on a clean clone at the
  base, delivers it to Downloads with the expected tree hash (and reads
  it back); the operator `git am`s, checks the tree, pushes; Claude
  verifies on GitHub. **Claude never pushes.**
- Pipshed: tests first (failures predicted BY NAME, guards marked), then
  the fix; all suites on a fresh scratch PG; break each rule once.
- Features: spec (Gemini questions inside, RESTATE AND STOP first),
  committed -> Gemini -> Cursor at that hash on a branch -> Claude reads
  the commits -> operator runs the suite -> DeepSeek for anything that
  moves orders -> merge `--no-ff`. One document at a time for Gemini.
  One paste per step, for the operator and for agents.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 147
