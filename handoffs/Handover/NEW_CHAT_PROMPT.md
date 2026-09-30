This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-30 ~19:15Z (WEDNESDAY, HOLIDAY; C63 TOMORROW)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 has the RESTATE-AND-STOP rule;
s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s18 to **s24** (s24
ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 to 2026-09-30;
`handoffs/Handover/08_BACKLOG.md` (above all C9, C16, C63, C78, C82-C85);
**`docs/architecture/c63-deploy.md`** and `c63-presets.md` (tomorrow);
`docs/architecture/ADR-164-missed-deal-replay.md` (s11: what shipped);
`docs/research/ejection-value-study.md` (s8-s11) and
`research/ejection_value/README.md`; `docs/research/grid-thesis.md`
(the operator's thesis; s10 Gemini); `docs/architecture/fleet-c.md` (s2,
s3, s5); `docs/architecture/fleet-b.md` (B1);
`docs/architecture/cycle4-live-geometry-search.md` s8.12 (THE ROADMAP)
and s8.13; `handoffs/Handover/06_LINUX_WINE_BOX.md` s4, s7, s9, **s10**;
`docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/03_COOKBOOK.md`; `handoffs/Handover/09_EVENT_LOG.md`
(add to it); `handoffs/Handover/10_GEOMETRY_REGISTER.md` (a row at every
geometry change); then this.

---

## 0. THE MOST IMPORTANT FACTS

**Three fleets live, 11/11 each. Call the boxes by HOSTNAME** (operator):
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes. `https://pipshed.com`.
- **Fleet B** (wine-test, 207.148.14.197, IC 53066709, `5685e4f`): B1
  graded add dial. Its repo checkout STAYS on `5685e4f`.
- **Fleet C** (wine-c, 64.177.116.219, IC 53071896, `main` v2.1
  `e2ac9fe`): phase 1 verdict PASS; GUI by x11vnc on 5911 (RDP broken).
- **Fleet D** (wine-d, 216.128.158.33, IC 53077984): BUILT 30 Sep, NOT
  ATTACHED (after the roll-watch; C85). RDP works (tunnel to 3392).

**C63 is THURSDAY 1 Oct, in session:** `main` `0335f25` (v2.1 + ADR-164
+ C77) with the lattice presets, **wine-c first, then wine-test**, with
the CURRENT key, per `c63-deploy.md`. P1 and P2 MET. The key rotation
(C9) is NOT this week: operator, "closer to going live".

**The EA code on `main` is FROZEN until C63.** Pipshed and docs may
change. MT5 reinitialises an EA only when an input changes: to reattach,
append " x" to `InpConfigWarning`.

**The ejection study's replay is FROZEN as "replay v1" (`ab5d4c8`)**
(Gemini GQ12): tonight's rerun changes data, not code. 1-7 Oct is the
true holdout (C84). Interim report Thursday; final ~9 Oct.

**The operator's thesis** (`grid-thesis.md`): no magic distance; add is
partly leverage; we want the capital to be able to visit the clusters;
trade history is the gold standard (C83: all three accounts' histories
exported and reconciled 30 Sep).

**The operator grants this chat his Downloads folder** when the desktop
app is linked: read his exports there; deliver patches there.

**One view of everything** (plain-text URL; change the last segment every
fetch; the fetch tool can invent text: for exact values have the
operator save the raw JSON with `Invoke-WebRequest` into Downloads):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths. **Never run `fxgrind_tests` on a
terminal with live EAs** (wine-d ran it once, empty; never again there).
**Compile ONE file in MetaEditor.** The telemetry key is never pasted in
chat, never committed, never screenshotted (the Inputs tab's last rows);
presets carry `TelemetryAPIKey=` blank and the key is injected on the box.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | the 30 Sep evening handoff patch on `7ca65e2`; EA code = `0335f25`: `git diff --stat 0335f25 origin/main -- ea/ tools/` must be empty |
| pipshed `main` | `bb19652` (C33, C66, C83) on `608e546` (C80, C74, C81). If still `bb19652`: `pipshed_fleet_d.patch` in Downloads is NOT applied yet (tree `4e4f1987f062923f4bb43a02e5c1ff3b2ccc7788`); operator applies and pushes |
| VPS (cycle 3) | `5685e4f`; MetaTrader LiveUpdate pending (Later) |
| wine-test (Fleet B) | `ssh box1`, VNC `ssh box1-vnc` + `localhost:5910`; `5685e4f`; lattice presets staged (P2) |
| wine-c (Fleet C) | `ssh box2`; x11vnc line in 06 s9, port 5911; `e2ac9fe` compiled; repo at `b6ad868` or later; lattice presets staged (P2) |
| wine-d (Fleet D) | root@216.128.158.33; repo `7ca65e2`; key in place (sha `fc6b3d9c56a8`); WebRequest URL unconfirmed |

---

## 2. NEXT, IN ORDER (= HANDOFF s24 NEXT SESSION)

1. Verify HEADs; the pipshed Fleet D patch if not pushed (not at
   20:50-21:00Z); confirm wine-d's WebRequest lists `https://pipshed.com`.
2. **21:00-22:00Z:** check C81 on the live page (the card keeps the
   finished broker day until the 22:00Z FTMO roll).
3. **After 21:00Z:** `--carrypass --hours 2` (01_BOOT s6).
4. **Study data:** `--export-study --days 14` into Downloads; bar AND
   bid/ask dumps on the desktop FTMO terminal and wine-c; rerun
   `ev_caps.py` / `ev_report.py`; write study s12 (final interim numbers;
   GQ13 wording: per-pair = this week's paths, fleet comparisons reflect
   the reconciled basket; GQ11-13 rulings) -> one docs patch.
5. **Thursday: C63** per `c63-deploy.md` (wine-c first). Record in the
   event log and geometry register.
6. Later: roll-watch, then `fleet-d.md` (C85); C84 after 7 Oct; C82
   measurements; v2.2 batch; wine-c RDP repair (closed-market slot);
   C9 closer to going live; 07 gate before real money.

---

## 3. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in committed source; RUN every verify script
  yourself; look at the rendered page, not only its JSON.
- PowerShell: always `git rev-parse "HEAD^{tree}"` (quoted); no trailing
  backslash inside quotes.
- Under Wine the log folder is lowercase `MQL5/logs`.
- M1 bar spread is the minute's MINIMUM: use the bid/ask dump.
- Cycle 2 shares fleet A's instance ids: filter by session -> account.
- Sandbox PG: role `verify`, port 55432, fresh database per suite (start
  line in 02_TRAPS 30 Sep afternoon).
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
  the fix; all suites on a fresh scratch PG.
- Features: spec (Gemini questions inside, RESTATE AND STOP first),
  committed -> Gemini -> Cursor at that hash on a branch -> Claude reads
  the commits -> operator runs the suite -> DeepSeek for anything that
  moves orders -> merge `--no-ff`. One document at a time for Gemini.
  One paste per step, for the operator and for agents. Ask Gemini
  without leading him.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 149
