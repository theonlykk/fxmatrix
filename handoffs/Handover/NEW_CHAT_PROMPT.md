This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-28 ~21:30Z (MONDAY NIGHT)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s18
to **s21**; every section of `handoffs/Handover/02_TRAPS.md` dated
2026-09-25 to 2026-09-28; `handoffs/Handover/08_BACKLOG.md` (above all C7,
C9, C16, C63, C74, C76-C79); **`docs/architecture/ADR-164-missed-deal-replay.md`**;
`docs/architecture/fleet-c.md` (s2, s3, s5 verdict);
`docs/research/ejection-value-study.md` (s8) and
`research/ejection_value/README.md`; `docs/architecture/fleet-b.md` (B1);
`docs/architecture/cycle4-live-geometry-search.md` s8.12 (THE ROADMAP)
and s8.13; `docs/architecture/ADR-163-rebuild-at-start.md`;
`handoffs/Handover/06_LINUX_WINE_BOX.md` s4, s7 and s9;
`docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/03_COOKBOOK.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Three fleets live, 11/11 each:**
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes.
- **Fleet B** (box 1, IC 53066709, `5685e4f`): B1 graded add dial.
- **Fleet C** (box 2, IC 53071896, `main` v2.1): phase 1 VERDICT written
  (fleet-c.md s5): code check PASS; cleared for C63 with ADR-164.

**28 Sep 16:27Z: a broker resync swallowed two fills on GBPUSD_OPTC**
(no `OnTradeTransaction` for fills during a resync: C76). A missed ENT
halts on I3; a missed EXT stalls silently. Every fleet has the same
gap. **ADR-164** (deal-history sweep, ACCEPTED rev 3, Gemini GF-1
agreed) fixes it and C77; it ships WITH C63 on **THURSDAY 1 Oct**. Its
Cursor spec is the next thing to write.

**The EA code on `main` is FROZEN until C63** (then v2.1 + ADR-164).
Pipshed and docs may change. **MT5 reinitialises an EA only when an
input changes:** to reattach, append " x" to `InpConfigWarning`.

**Box 2's GUI:** x11vnc on port 5911 works (06 s9); RDP is still broken
(repair in a closed-market slot). Box 1: `ssh box1-vnc`, port 5910.

**The operator granted this chat his Downloads folder** when the desktop
app is linked: read his exports there; deliver patches there.

**One view of everything** (plain-text URL; change the last segment every
fetch; the fetch tool can invent text: for exact values have the
operator save the raw JSON with `Invoke-WebRequest` into Downloads):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths. **Never run `fxgrind_tests` on a
terminal with live EAs.** The telemetry key sits in `ea/Globals.mqh`
since June and was seen in a screenshot 27 Sep: rotate at C63 (C9);
repo PRIVATE before real money (07 gate).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `306e38d` + the 28 Sep evening patches (docs, ADR-164, two read-only probe scripts, `research/ejection_value/`); `git diff --stat 6a1e9ad origin/main -- ea/*.mq5 ea/*.mqh tools/` must be empty |
| pipshed `main` | `15ddeb7`: fleet cards in the daily summary layout (signed pips, commission by account, net) on `bb40cc2`, `d82ff26`, `b6a03d4` |
| VPS (cycle 3) | `5685e4f`, `pipshed.com`; MetaTrader LiveUpdate pending (Later) |
| Box 1 (Fleet B) | 207.148.14.197 (`ssh box1`); `5685e4f`; B1 applied; repo stays on `5685e4f` |
| Box 2 (Fleet C) | 64.177.116.219 (`ssh box2`); `main` `e2ac9fe`; 11 live; `linuxc.pipshed.com`; GUI via VNC |

---

## 2. NEXT, IN ORDER

1. **ADR-164 Cursor spec** (workspace `D:\fxmatrix`, branch off `main`):
   tests first (DR1-DR11, EQ-H1/2 from the ADR) with failures predicted
   BY NAME, AUDIT TRAIL, negative space, ASCII only, line count at the
   bottom, open questions for Gemini inside. Then Cursor, Claude reads
   the commits, DeepSeek (it moves orders), full suite on the DESKTOP
   terminal only, merge `--no-ff`. Target: merged Wednesday.
2. **Every night after 21:00Z:** `--carrypass --hours 2` (01_BOOT). Expect
   33 summaries; the snapshot list can be short after a weekend (C79).
3. **Wednesday, ejection study data** (study s3, README):
   a. Export, desktop `D:\pipshed`, `--days 14` (fill_logs keep 14
      days; the depth timeline needs every ENT since the fleet started):
      `railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-study --days 14 | Set-Content -Encoding utf8 "$HOME\Downloads\study_export_<date>.jsonl"`
   b. Bar dump on the desktop FTMO terminal (flat `MQL5\Scripts\`) and on
      BOX 2 over VNC (IC; `Scripts/fxmatrix/`, file recipe 06 s9), each on
      a spare chart, never an EA's chart; files `MQL5\Files\bars_<login>_<SYM>.csv`.
   c. Claude runs `research/ejection_value/ev_report.py` on the files.
   Interim report Thu 1 Oct; final ~9 Oct (>= 30 episodes). After
   ADR-164: GQ6 to Gemini (F by depth, V_strict).
4. **C63, THURSDAY 1 Oct in session:** `main` (v2.1 + ADR-164) + lattice
   on box 1 and box 2 (fleet-c.md s3 amendment first); ROTATE the
   telemetry key in the same reattach (C9). From C63 B and C roll instead
   of ejecting; A keeps ejecting; the study scores rolls the same way.
5. **Pipshed, where it fits before C63** (small-fix route or one spec):
   C74 (quarantine noise), C7 rest (API count; the 200 limit on the
   cards, C78), C66.
6. A few days watching rolls; EA batch v2.2 (C57, C62, C65, C60, C68,
   C42, C79) by the full route. Then box 3 (Fleet D; operator: two full
   rings to test the 200 limit). Before real money: 07_ROADMAP gate (C9,
   C31, C18, C14/C23, repo private).

---

## 3. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in committed source; RUN every verify script
  yourself; look at a rendered page, not only its tests.
- Pull a production sample before writing fixtures (only the MAE
  reporter sends balance and equity; daily rows are keyed to the day
  that ended).
- Name the workspace (`D:\fxmatrix` or `D:\pipshed`) in every Cursor
  prompt; a new Cursor chat per task.
- PowerShell eats braces: always write `git rev-parse "HEAD^{tree}"`.
- The pipshed web never holds `DATABASE_URL`; never `git clean`
  `D:\pipshed`; avoid pushing pipshed `main` at 20:50-21:00Z.
- Sandbox PostgreSQL stops between sessions (start line in 02_TRAPS 28
  Sep); a FRESH database for every verify run.
- Twin charts (AUDNZD, NZDCAD): read `InpTelemetryInstance` and
  `InpMagic` before Load; the Experts log is named by UTC date.
- The card, not the remote desktop, says whether a fleet is alive.

---

## 4. WORKING PRACTICE

- One shell step per message; the operator pastes output back. Say WHERE
  each command runs (desktop PowerShell, `ssh box1`, `ssh box2`, GUI).
- Docs and small fixes: Claude commits in its sandbox and hands over
  `git format-patch` files (byte size, expected tree hash, checked with
  `git am` on a clean clone); the operator `git am`s from Downloads,
  checks the tree, pushes; Claude verifies on GitHub. Claude never
  pushes (decline the stop hook's push request).
- Features: spec (Gemini questions inside, tests first, failures
  predicted BY NAME, line count at the bottom) -> Gemini -> Cursor on a
  branch -> Claude reads the commits -> DeepSeek for anything that moves
  orders -> merge `--no-ff`. One document at a time for Gemini.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 145
