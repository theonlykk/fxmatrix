This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-01 ~01:05Z (THURSDAY; C63 TODAY FROM 14:30Z)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 has the RESTATE-AND-STOP rule;
s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s22 to **s26** (s26
ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-28 to 2026-10-01;
`handoffs/Handover/08_BACKLOG.md` (above all C63, C76/C77, C84-C87);
**`docs/architecture/c63-deploy.md`**, **`docs/runbooks/c63-commands.md`**
(today's exact commands and the log checker) and `c63-presets.md`;
`docs/architecture/ADR-164-missed-deal-replay.md` s11;
`docs/research/ejection-value-study.md` s10-s12; `docs/research/grid-thesis.md`
s1, s6, s10, s11; `docs/architecture/fleet-c.md` s2, s3, s5;
`docs/architecture/fleet-b.md` (B1); `docs/architecture/cycle4-live-geometry-search.md`
s8.5, s8.12, s8.13; `handoffs/Handover/06_LINUX_WINE_BOX.md` s4, s7, s9,
s10; `docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/03_COOKBOOK.md`; `handoffs/Handover/09_EVENT_LOG.md`
(add to it); `handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Three fleets live, 11/11 each. Call the boxes by HOSTNAME** (operator):
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes. `https://pipshed.com`.
- **Fleet B** (wine-test, 207.148.14.197, IC 53066709, `5685e4f`): B1
  graded add dial. Its repo checkout moves off `5685e4f` only at C63.
- **Fleet C** (wine-c, 64.177.116.219, IC 53071896, `main` v2.1
  `e2ac9fe`); GUI by x11vnc on 5911 (RDP broken).
- **Fleet D** (wine-d, 216.128.158.33, IC 53077984): BUILT, WebRequest
  confirmed, page `linuxd.pipshed.com` live, NOT ATTACHED (after the
  roll-watch, then `fleet-d.md`; C85).

**C63 is TODAY, Thursday 1 Oct, from 14:30Z (10:30 ET, after ISM at
14:00Z)**: `main` EA `0335f25` (v2.1 + ADR-164 + C77) with the lattice
presets, **wine-c first, then wine-test**, the CURRENT key, **no
geometry change** (operator), per `c63-deploy.md` and the runbook. The
runbook's read-only log checker (`/root/c63_logcheck.awk`) is installed
on wine-c and passed a dry run on its real 28 Sep log; install it on
wine-test (runbook s1) before its stage. One row per EA init: deinit
reason, replay, lattice, geometry, rebuild; BAD lines in full.

**The EA code on `main` is FROZEN until C63** (`git diff --stat 0335f25
origin/main -- 'ea/*.mq5' 'ea/*.mqh' tools/` must be empty; the 22
`*_lat.set` presets are in `ea/` and are not code). MT5 reinitialises an
EA only when an input changes: to reattach, append " x" to
`InpConfigWarning`.

**Watch tonight on B and C (C87):** IC's rollover (00:00 server = 21:00Z)
rejects "market closed" for ~1-2 min every night, and on 30 Sep
(quarter-end) held requests for 3 minutes each (180 s timeouts). Read any
slow roll or exit move at 21:00-21:15Z with that in mind. FTMO is clean.

**New on the backlog:** C86 (the EA's pending swap multiplier is one day
off: Tue 3 / Wed 1 / Fri 0 vs the ledger's 1 / 3 / 1; economic, not a
blocker; recheck Friday, then v2.2), C87 (above).

**The ejection study's replay is FROZEN as "replay v1" (`ab5d4c8`)**;
s12 is the interim report; 1-7 Oct is the true holdout (C84). The grid
thesis measurements (s11, M1-M7) are reproducible with
`research/grid_thesis/gt_report.py` (seeded).

**The operator grants this chat his Downloads folder** when the desktop
app is linked: read his exports there; deliver patches there.

**One view of everything** (plain-text URL; change the last segment every
fetch; the fetch tool can invent text and caches 404s: for exact values
have the operator save the raw JSON with `Invoke-WebRequest` into
Downloads):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

The fleet cards now show `Book x/200 . guard y/194 . API z/2000` (C7;
guard = the EA's own entry-guard total, ~166-174 on 30 Sep) and each
instance card's layer table is in trading-level order with a `bid . ask`
market line (derived from the book; C65 would replace it).

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths. **Never run `fxgrind_tests` on a
terminal with live EAs.** **Compile ONE file in MetaEditor.** The
telemetry key is never pasted in chat, never committed, never
screenshotted (the Inputs tab's last rows); presets carry
`TelemetryAPIKey=` blank and the key is injected on the box.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | docs to HANDOFF s26 (1 Oct ~02:00Z: runbook s6, v2.2 and C9 drafts, backlog clean-up); EA code = `0335f25` (check line above) |
| pipshed `main` | `052c72a` (C9 second-key patch waiting in Downloads, push after C63) (brighter grey) on `d1733dc` (C7 card line) on `3dfe808` (layer table market line) on `fb612c6` (Fleet D page); 28 verify suites, all green on a fresh scratch PG |
| VPS (cycle 3) | `5685e4f`; MetaTrader LiveUpdate pending (Later) |
| wine-test (Fleet B) | `ssh box1`, VNC `ssh box1-vnc` + `localhost:5910`; `5685e4f`; lattice presets staged (P2) |
| wine-c (Fleet C) | `ssh box2`; x11vnc line in 06 s9, port 5911; `e2ac9fe` compiled; repo `b6ad868` or later; lattice presets staged (P2); log checker at `/root/c63_logcheck.awk` |
| wine-d (Fleet D) | root@216.128.158.33; repo `7ca65e2`; key in place (sha `fc6b3d9c56a8`); WebRequest confirmed; Algo OFF |

---

## 2. NEXT, IN ORDER (= HANDOFF s25 NEXT SESSION)

1. Verify HEADs. The log checker is on both boxes (wine-test 1 Oct
   ~01:20Z, dry run PASS). Strip JSON ~14:00Z.
2. **C63 from 14:30Z** per `c63-deploy.md` and the runbook: wine-c
   (pre-flight C1, copy C2, compile C3, check C4, pilot C5, ten C6, C7),
   then wine-test (B0-B7; its repo move to `main` decided on the B1
   output). Record: event log, fleet-b.md B2, fleet-c.md A2, backlog C63
   (and C76/C77 live on B and C), BOOT s6. No geometry register rows.
3. Tonight: `--carrypass --hours 2` (33, no I6); the first `ROLL_*`
   rows; 21:00-21:15Z on B and C read with C87 in mind.
4. Friday: `--export-study --days 14` (it includes the 30 Sep Wednesday
   rollover) -> recheck C86's Wednesday sample; weekly exports (C83);
   rerun `research/grid_thesis/gt_report.py`.
5. Later: the roll-watch, then `fleet-d.md` (C85); C84 after 7 Oct; a
   v2.2 scope note (C86, C79, C57, C62, C65, C68 + roll-watch fixes);
   C87 design (after more nights); wine-c RDP repair (closed-market
   slot); C9 closer to going live; 07 gate before real money.

---

## 3. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in committed source; RUN every verify script
  yourself; look at the rendered page, not only its JSON.
- A "failed" count is not a retcode: read `send_logs` before naming a
  cause (C60 was misread on 30 Sep).
- PowerShell: always `git rev-parse "HEAD^{tree}"` (quoted); no trailing
  backslash inside quotes.
- Under Wine the log folder is lowercase `MQL5/logs`; the terminal's
  options are in `Config/` (capital C) and `WebRequestUrl` is encoded.
- M1 bar spread is the minute's MINIMUM: use the bid/ask dump.
- Sandbox PG: role `verify`, port 55432, fresh database per suite; it
  stops between sessions (restart line in 02_TRAPS 30 Sep afternoon).
- Mutation checks: `PYTHONDONTWRITEBYTECODE=1`, clear `__pycache__`.
- The pipshed web never holds `DATABASE_URL`; never `git clean`
  `D:\pipshed`; avoid pushing pipshed `main` at 20:50-21:00Z.
- Twin charts (AUDNZD, NZDCAD): read `InpTelemetryInstance` and
  `InpMagic` before Load.
- The card, not the remote desktop, says whether a fleet is alive.

---

## 4. WORKING PRACTICE

- **One shell step per message**; the operator pastes output back. Say
  WHERE each command runs (desktop PowerShell, `ssh box1` = wine-test,
  `ssh box2` = wine-c, wine-d, GUI). Plain-text pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, builds
  `git format-patch`, checks it with `git am` on a clean clone at the
  base, delivers it to Downloads with the expected tree hash; the
  operator `git am`s, checks the tree, pushes; Claude verifies on GitHub.
  **Claude never pushes** (decline the stop hook's push request).
- Pipshed: tests first (failures predicted BY NAME, guards marked), then
  the fix; all suites on a fresh scratch PG; break each rule once.
- Features: spec (Gemini questions inside, RESTATE AND STOP first),
  committed -> Gemini -> Cursor at that hash on a branch -> Claude reads
  the commits -> operator runs the suite -> DeepSeek for anything that
  moves orders -> merge `--no-ff`. One document at a time for Gemini.
  One paste per step, for the operator and for agents. Ask Gemini
  without leading him.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 169
