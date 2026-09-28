This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-28 ~00:15Z (SUNDAY EVENING ET)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s18
and s19 (with its continuations); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 to 2026-09-27;
`handoffs/Handover/08_BACKLOG.md` (above all C7, C9, C63, C72-C74);
`docs/architecture/cycle4-live-geometry-search.md` s8 (rev 3) and **s8.12
(THE ROADMAP)**; `docs/architecture/ADR-163-rebuild-at-start.md`;
`docs/architecture/fleet-b.md` (B1, applied); **`docs/architecture/fleet-c.md`**
(s2 pass criteria, s5 record, A1); `handoffs/Handover/06_LINUX_WINE_BOX.md`
s4, s7 and s9; `docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`docs/architecture/ARCHITECT.md` s10; `handoffs/Handover/03_COOKBOOK.md`;
then this.

---

## 0. THE MOST IMPORTANT FACTS

**Three fleets live** since Sunday evening 27 Sep:
- **Cycle 3** (VPS, FTMO 1514731800, `5685e4f`): FROZEN except defect
  fixes.
- **Fleet B** (box 1, IC 53066709, `5685e4f`): the graded add dial B1
  applied 23:05-23:51Z 27 Sep.
- **Fleet C** (box 2, IC 53071896, `main` v2.1 = the dual add/exit EA):
  attached 23:57Z-00:07Z at Fleet B's settings, per-side inputs -1,
  lattice off. PHASE 1 CODE CHECK RUNNING: verdict after Monday 28 Sep
  17:00 ET plus that night's carry pass (fleet-c.md s2).

**The EA code on `main` is FROZEN until C63** (what Fleet C checks is
what box 1 gets). Pipshed and docs may change.

**One view of everything** (plain-text URL; change the last segment every
fetch; ask the fetch tool for exact quotes):

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

Per fleet: `/ejection` on `pipshed.com` (A), `linux.` (B), `linuxc.` (C).

Never reattach, reload inputs or deploy with the market closed, or with
spreads wider than the pairs' widths (Sunday open: about two hours).
**Never run `fxgrind_tests` on a terminal with live EAs** (all three
now). **Box 1: RDP is locked out**; x11vnc on `:10` over SSH (06 s4).
Box 2: RDP via `ssh -L 3391:localhost:3389 root@64.177.116.219`.

**The telemetry key was fully visible in a chat screenshot on 27 Sep:**
rotate it at C63 (C9). Never screenshot the EA Inputs tab's last rows.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `f15ccb8` or a docs-only descendant; `git diff --stat 6a1e9ad origin/main -- ea/*.mq5 ea/*.mqh tools/` must be empty |
| pipshed `main` | `4faaf1b`: fleet strip (`/fleets`, badge, alerts, legend; `verify_fleet_strip.py` 30/30) on `3184c88` (Fleet C selection) |
| VPS (cycle 3) | `5685e4f`, `pipshed.com`; a MetaTrader LiveUpdate is pending (answered Later): install only at a planned in-session restart |
| Box 1 (Fleet B) | 207.148.14.197; `5685e4f`; B1 applied (fleet-b.md) |
| Box 2 (Fleet C) | 64.177.116.219; `main` `e2ac9fe` compiled; 11 live; `linuxc.pipshed.com` |

---

## 2. NEXT, IN ORDER

1. **Monday 28 Sep: Fleet C's code check.** Pass (fleet-c.md s2): no
   FATAL, CRITICAL, `INVARIANT_FAIL` or halt on any C instance through
   17:00 ET; scalps booking; and the carry pass after 21:00Z clean for
   the eleven C ids (`archive_counts.py --carrypass --hours 2`, 01_BOOT).
   Read it from the strip and `/critical`; write the verdict in
   fleet-c.md s5. Optional: fresh-ladder scalps on B vs C.
2. **Pipshed batch before C63** (one spec -> Gemini -> Cursor in
   `D:\pipshed`): C72 (the strip must take balance and equity from the
   instance that carries them, the MAE reporter; fixtures like
   production), C74 (hide released `QUARANTINE_ENTER`), C7 rest (API
   count against its cap, each book against the 200 limit), C66
   (reconciliation gross basis), C64 (summary commission from the
   ledger).
3. **C63, Tue or Thu in session:** compile `main` on box 1 (first v2.1
   init strict, labels written) with lattice presets
   (`InpVirtualLattice=true`, `InpAutoEject=false`); box 2 the same, same
   day (fleet-c.md s3, amendment first); ROTATE the telemetry key in the
   same reattach (new key in Railway, presets rebuilt, every chart
   reloaded, the VPS too).
4. **A few days watching rolls**, then one EA batch v2.2 (C57, C62, C65,
   C60, C68, C42) by the full route (DeepSeek: it moves orders).
5. Box 3 (Fleet D) and compass rounds; C61 (Friday: swap booked for
   Friday night?); C73 (gap slippage on the cards). Before real money:
   C9, C31, C18 (operator's commitment).

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
- `verify_ejection_telemetry` needs a FRESH database for every run.
- Twin charts (AUDNZD, NZDCAD): read `InpTelemetryInstance` and
  `InpMagic` before Load; the Experts log is named by UTC date.

---

## 4. WORKING PRACTICE

- One shell step per message; the operator pastes output back. Say WHERE
  each command runs (desktop PowerShell, box 1 SSH, box 2 SSH, GUI).
- Docs and small fixes: Claude commits in its sandbox and hands over
  `git format-patch` files (byte size, expected tree hash); the operator
  `git am`s from Downloads, checks the tree, pushes; Claude verifies on
  GitHub. Claude never pushes (decline the stop hook's push request).
- Features: spec (Gemini questions inside, tests first, failures
  predicted BY NAME, line count at the bottom) -> Gemini -> Cursor on a
  branch -> Claude reads the commits -> DeepSeek for anything that moves
  orders -> merge `--no-ff`. One document at a time for Gemini.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 128
