This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-01 ~05:45Z (THURSDAY; C63 DONE; FLEET D LIVE; D1 NEXT)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 has the RESTATE-AND-STOP rule;
s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s22 to **s26** (s26
ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-28 to 2026-10-01 (above
all "1 Oct C63"); `handoffs/Handover/08_BACKLOG.md` (above all C9, C78,
C84-C88); **`docs/runbooks/c63-commands.md` s5a and s6 (the roll-watch)**;
`docs/architecture/c63-deploy.md` s12; `docs/architecture/ADR-162-virtual-lattice.md`
s13-s19; `docs/architecture/fleet-b.md` (B1, B2) and `fleet-c.md` (A2);
`docs/architecture/ADR-164-missed-deal-replay.md` s11;
`docs/research/ejection-value-study.md` s10-s12; `docs/research/grid-thesis.md`
s1, s6, s10, s11; `research/swap_day/README.md`;
`docs/architecture/cycle4-live-geometry-search.md` s8.5, s8.12-s8.14;
`handoffs/Handover/06_LINUX_WINE_BOX.md` s4, s7, s9, s10;
`docs/architecture/v2.2-scope.md` and `c9-key-rotation.md` (both DRAFT);
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/03_COOKBOOK.md`; `handoffs/Handover/09_EVENT_LOG.md`
(add to it); `handoffs/Handover/10_GEOMETRY_REGISTER.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live, 11/11 each. Call the boxes by HOSTNAME** (operator):
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes; still EJECTS at cap (the comparison). `https://pipshed.com`.
- **Fleet B** (wine-test, 207.148.14.197, IC 53066709): `main` `0335f25`,
  **lattice ON since 1 Oct 04:02Z**, B1 dial; charts load the Experts copy.
- **Fleet C** (wine-c, 64.177.116.219, IC 53071896): `main` `0335f25`,
  **lattice ON since 04:16Z**. **Its charts load `Scripts\fxmatrix\
  fxgrind.ex5`: a build there means compiling `Scripts/fxmatrix/
  fxgrind.mq5`** until C88 re-attaches them from Experts. GUI x11vnc 5911.
- **Fleet D** (wine-d, 216.128.158.33, IC 53077984): **LIVE since
  05:19Z**, D0 = anchor settings + lattice from a flat start
  (`fleet-d.md`). **D1 = the first compass probe: the operator wants
  it NOW** (HANDOFF s26 NEXT SESSION item 2 has the anchors and the
  order of decisions). Strip says NOT ATTACHED until the pipshed patch
  is pushed (C85 (f), built).
  History starts with the C78 probe's deals (magic 99078001). GUI: x11vnc
  `-noipv6 -forever` on 5912 (02_TRAPS 1 Oct early morning).

**C63 is DONE** (1 Oct 03:20-04:20Z, c63-deploy.md s12): no rollback, no
bad line, ADR-164 live on B and C (the VPS keeps the C76 gap until cycle
3 ends). **The roll-watch is running** (runbook s6): the first lattice
anywhere. `ROLL_STRANDED`, `ROLL_CLOSING_STUCK`, `DEAL_EVENT_MISSED` come
to the chat; nothing is done by hand before `ROLL_STRANDED`. Operator:
**no wind-down brake** on long trends (ADR-162 s19).

**Answered 1 Oct:** C86 confirmed (the triple swap is on the rollover
Wednesday's pass prices: Mon 1 / Tue 1 / Wed 3 / Thu 1 / Fri 1; the EA
is one day off; fix in v2.2). C78 (1): IC counts positions + pending
orders against 200, like FTMO (about 11-12 instances an account at cap
8). **Operator: no broker contact** ("low profile"): measure, never ask.

**The live telemetry key IS the key committed in `ea/Globals.mqh` since
June** (C9): anyone reading the repo can push telemetry. The pipshed
second-key commits wait in Downloads inside
`pipshed_c9_and_fleet_d_card.patch` (four commits on `052c72a`, tree
`fbed4e6c`: C9, then the Fleet D live card); rotation timing is the
operator's.

**Watch every night on B and C (C87):** IC's rollover (21:00Z) rejects
"market closed" for 1-2 min, and on 30 Sep held requests 3 minutes.
`ROLL_REFUSED` there is expected (backoff 60 s doubling to 30 min).

**The ejection study's replay is FROZEN as "replay v1" (`ab5d4c8`)**;
1-7 Oct is the true holdout (C84). `research/ejection_value` must not
change until C84 is scored (C85(d) waits).

**The operator grants this chat his Downloads folder** when the desktop
app is linked: read his exports there; deliver patches there.

**One view of everything** (plain-text URL; change the last segment every
fetch; the fetch tool can invent text and caches 404s: for exact values
have the operator save the raw JSON with `Invoke-WebRequest` into
Downloads):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths. **Never run `fxgrind_tests` on a
terminal with live EAs.** **Compile ONE file, the one the charts load**
(read the chart profiles' `path=` first). The telemetry key is never
pasted in chat, never committed, never screenshotted (crop the Inputs
dialog above `TelemetryAPIKey`); presets carry `TelemetryAPIKey=` blank.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | docs to the Fleet D records and this handoff (1 Oct ~05:45Z); EA code = `0335f25` (live on B, C, D) |
| pipshed `main` | `052c72a`; `pipshed_c9_and_fleet_d_card.patch` in Downloads (tree `fbed4e6c`; push now, not 20:50-21:00Z) |
| VPS (cycle 3) | `5685e4f`; MetaTrader LiveUpdate pending (Later) |
| wine-test (Fleet B) | `ssh box1`, VNC `ssh box1-vnc` + `localhost:5910`; repo `main`; log checker `/root/c63_logcheck.awk` |
| wine-c (Fleet C) | `ssh box2`; x11vnc 5911 (06 s9); repo `b6ad868` (ea = main); charts on the Scripts copy (C88); log checker installed |
| wine-d (Fleet D) | root@216.128.158.33; repo `dc40203`; D0 live, Algo ON; log checker installed |

---

## 2. NEXT, IN ORDER (= HANDOFF s26 NEXT SESSION)

1. Apply and push `pipshed_c9_and_fleet_d_card.patch` (tree
   `fbed4e6c`); check D's card; C9 rotation timing.
2. **D1: the first compass probe on Fleet D** (the operator's priority;
   HANDOFF s26 item 2: lever split, direction per pair and side with
   its evidence, twins, round; then `fleet-d.md` D1 -> Gemini).
3. The roll-watch (runbook s6); tonight 21:00-21:15Z with C87 in mind,
   then `--carrypass --hours 2` (44; the first pass over rolled layers).
4. C88 in a quiet in-session slot.
5. Friday: weekly exports (C83), `gt_report.py`.
6. Later: a ring-design note (three balanced sevens); the v2.2 note to
   Gemini; C84 after 7 Oct; 07 gate.

---

## 3. TRAPS (full list in 02_TRAPS)

- A chart loads the `.ex5` at the path it was attached from; a parameter
  reload keeps the loaded binary (1 Oct C63).
- PowerShell splits an unquoted comma list: `--codes 'A,B'`.
- Verify every agent claim in committed source; RUN every verify script
  yourself; look at the rendered page, not only its JSON.
- A "failed" count is not a retcode: read `send_logs` first.
- PowerShell: always `git rev-parse "HEAD^{tree}"` (quoted); no trailing
  backslash inside quotes.
- Under Wine the log folder is lowercase `MQL5/logs`; options in `Config/`.
- M1 bar spread is the minute's MINIMUM: use the bid/ask dump.
- Sandbox PG: role `verify`, port 55432, fresh database per suite.
- Mutation checks: `PYTHONDONTWRITEBYTECODE=1`, clear `__pycache__`.
- The pipshed web never holds `DATABASE_URL`; never `git clean`
  `D:\pipshed`; avoid pushing pipshed `main` at 20:50-21:00Z.
- Twin charts (AUDNZD, NZDCAD): read `InpTelemetryInstance` and
  `InpMagic` before Load; the log checker interleaves twins.
- The card, not the remote desktop, says whether a fleet is alive.

---

## 4. WORKING PRACTICE

- **One shell step per message**; the operator pastes output back. Say
  WHERE each command runs (desktop PowerShell, `ssh box1` = wine-test,
  `ssh box2` = wine-c, wine-d, GUI). Plain-text pipshed URLs.
- Docs and small fixes: Claude commits in its sandbox, builds
  `git format-patch`, checks it with `git am` on a clean clone at the
  base, delivers it to Downloads with the expected tree hash (and reads
  the file back from Downloads); the operator `git am`s, checks the tree,
  pushes; Claude verifies on GitHub. **Claude never pushes.**
- Pipshed: tests first (failures predicted BY NAME, guards marked), then
  the fix; all suites on a fresh scratch PG; break each rule once.
- Features: spec (Gemini questions inside, RESTATE AND STOP first),
  committed -> Gemini -> Cursor at that hash on a branch -> Claude reads
  the commits -> operator runs the suite -> DeepSeek for anything that
  moves orders -> merge `--no-ff`. One document at a time for Gemini.
  One paste per step, for the operator and for agents.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 165
