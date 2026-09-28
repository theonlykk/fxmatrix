This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-28 ~14:30Z (MONDAY, IN SESSION)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s18,
s19 (with its continuation) and **s20**; every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 to 2026-09-28;
`handoffs/Handover/08_BACKLOG.md` (above all C7, C9, C16, C63, C72-C75);
**`docs/research/ejection-value-study.md`**; `docs/architecture/fleet-c.md`
(s2 pass criteria, s5 record); `docs/architecture/fleet-b.md` (B1);
`docs/architecture/cycle4-live-geometry-search.md` s8.12 (THE ROADMAP)
and s8.13; `docs/architecture/ADR-163-rebuild-at-start.md`;
`handoffs/Handover/06_LINUX_WINE_BOX.md` s4, s7 and s9;
`docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/03_COOKBOOK.md`; then this.

---

## 0. THE MOST IMPORTANT FACTS

**Three fleets live, 11/11 each; no halt on any fleet since 25 Sep:**
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes.
- **Fleet B** (box 1, IC 53066709, `5685e4f`): B1 graded add dial.
- **Fleet C** (box 2, IC 53071896, `main` v2.1): PHASE 1 CODE CHECK;
  verdict after Monday 28 Sep 17:00 ET plus that night's carry pass
  (fleet-c.md s2), written in fleet-c.md s5.

**First live auto ejections 28 Sep** (18 by 13:22Z: A 5, B 9, C 4; all
clean). **The ejection value study** (C16 revived) tests the operator's
thesis -- "we can only control our pnl by trading; layer 8 means we
can't trade; ergo it is bad" -- with numbers. Tools are merged; no
data pulled yet; analysis code not yet written.

**The EA code on `main` is FROZEN until C63.** Pipshed and docs may
change.

**Box 2's GUI is broken (C75):** RDP gives a teal screen, x11vnc hung;
MT5 trades on. Fix it (read-only look first, 06 s9) BEFORE C63, which
needs the GUI there. Box 1: RDP locked out; x11vnc over `ssh box1-vnc`.

**One view of everything** (plain-text URL; change the last segment every
fetch; ask the fetch tool for exact quotes):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths. **Never run `fxgrind_tests` on a
terminal with live EAs.** The telemetry key was visible in a screenshot
on 27 Sep: rotate at C63 (C9); never screenshot the Inputs tab's last
rows.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `91dd953` or a docs-only descendant; `git diff --stat 6a1e9ad origin/main -- ea/*.mq5 ea/*.mqh tools/` must be empty |
| pipshed `main` | `99a75a3`: `archive_counts.py --export-study` (5/5) on `4faaf1b` (fleet strip, 30/30) |
| VPS (cycle 3) | `5685e4f`, `pipshed.com`; MetaTrader LiveUpdate pending (Later) |
| Box 1 (Fleet B) | 207.148.14.197 (`ssh box1`); `5685e4f`; B1 applied |
| Box 2 (Fleet C) | 64.177.116.219 (`ssh box2`); `main` `e2ac9fe`; 11 live; `linuxc.pipshed.com`; GUI broken (C75) |

---

## 2. NEXT, IN ORDER

1. **Monday 28 Sep after 17:00 ET:** Fleet C verdict (fleet-c.md s2:
   no FATAL, CRITICAL, `INVARIANT_FAIL` or halt on any C id; scalps
   booking) from the strip and `/critical`; after 21:00Z the carry pass
   including the eleven C ids (`--carrypass --hours 2`, 01_BOOT).
2. **Box 2 GUI (C75)**, in daylight: `ssh box2`, the read-only commands
   in 06 s9; propose a fix that does not stop MT5; screen locker off on
   both boxes.
3. **Ejection study data** (docs/research/ejection-value-study.md s3):
   a. Bar dump, desktop FTMO terminal (prices for fleet A): copy
      `D:\fxmatrix\scripts\grind_bar_dump.mq5` into the terminal's
      `MQL5\Scripts\fxmatrix\`, compile in MetaEditor (0/0, read the
      log, not the CLI), open a spare chart, drag the script on, check
      the Experts tab for `BARDUMP|BEGIN` ... nine `n=` lines ...
      `BARDUMP|END`; files are `MQL5\Files\bars_<login>_<SYM>.csv`.
   b. The same on BOX 1 (IC prices; box 1 and box 2 share
      `ICMarketsSC-Demo`, and box 2's GUI is down) over x11vnc, on a
      spare chart, never on an EA's chart; `scp` the CSVs back.
   c. Export, desktop `D:\pipshed`, weekly (fill_logs keep 14 days):
      `railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-study --days 7 | Set-Content -Encoding utf8 <file>`
   d. Claude writes `research/ejection_value/` (depth timeline, episodes
      and chains, E/H/F/V, hours at cap, GQ5-F controls) with tests on
      synthetic cases, runs it on the files, commits by patch.
   Interim report Thu 1 Oct; final ~9 Oct (>= 30 episodes). GQ5-F is
   with Gemini (study s7); code all three controls either way.
4. **Pipshed batch before C63** (one spec -> Gemini -> Cursor in
   `D:\pipshed`): C72, C74, C7 rest (API count, 200 limit), C66, C64.
5. **C63, Tue or Thu in session, once C75 is fixed:** `main` + lattice
   on box 1 and box 2 (fleet-c.md s3 amendment first); ROTATE the
   telemetry key in the same reattach. From C63 B and C roll instead of
   ejecting; A keeps ejecting; the study scores rolls the same way.
6. A few days watching rolls; EA batch v2.2 (C57, C62, C65, C60, C68,
   C42) by the full route. Then box 3 (Fleet D). Before real money:
   07_ROADMAP gate (C9, C31, C18, C14/C23).

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

Line count: 144
