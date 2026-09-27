This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-27 ~05:20Z (SUNDAY, EARLY)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s18
(with its continuations) and s19; every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 to 2026-09-27;
`handoffs/Handover/08_BACKLOG.md` (above all C7, C47, C63, C68, C70, C71);
`docs/architecture/cycle4-live-geometry-search.md` s8 (rev 3) and **s8.12
(THE ROADMAP)**; `docs/architecture/ADR-163-rebuild-at-start.md`;
`docs/architecture/fleet-b.md` (amendment B1); **`docs/architecture/fleet-c.md`**;
`handoffs/Handover/06_LINUX_WINE_BOX.md` s3, s4, s7 and s9 (box 2 and its
lessons); `docs/architecture/ADR-162-virtual-lattice.md` s13-s18;
`docs/architecture/ARCHITECT.md` s10; `handoffs/Handover/03_COOKBOOK.md`;
then this.

---

## 0. THE MOST IMPORTANT FACTS

**One EA.** `main`'s EA (== `2ff62f4`, grind v2.1) IS the dual add/exit
EA: six per-side inputs (-1 = inherit), ADR-163 rebuild at start (label
GVs `GRIND_GEO_EXIT_<magic>_L/_S`), the ADR-162 lattice (default OFF).
Suite 2220/2220. **Cycle 3 (VPS) and Fleet B (box 1) run `5685e4f`.**
Box 2 (Fleet C) has `main` compiled and waits for Monday.

**Three fleets, three pages** (plain-text URLs; change the last segment
every fetch; 503 = view missing or stale, never zero):

    https://pipshed.com/api/g/k7m9p2x4q/ejection/a1?hours=96
    https://linux.pipshed.com/api/g/k7m9p2x4q/ejection/b1?hours=96
    https://linuxc.pipshed.com/api/g/k7m9p2x4q/ejection/c1?hours=96

**The roadmap is the cycle-4 note s8.12.** Never reattach, reload inputs
or deploy with the market closed (opens Sunday 17:00 ET = 21:00Z).
**Never run `fxgrind_tests` on a terminal with live EAs** (box 2 ran it
once, before any attach; never again). Cycle 3 is FROZEN except for
defect fixes. **Box 1: RDP is locked out**; x11vnc on `:10` over SSH
(06 s4); never reboot it. Box 2: RDP works via `ssh -L
3391:localhost:3389 root@64.177.116.219`, then `mstsc localhost:3391`.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `9ba02a5` or a docs-only descendant; `git diff --stat 6a1e9ad origin/main -- ea/*.mq5 ea/*.mqh tools/` must be empty |
| pipshed `main` | `3184c88` (Fleet A/B/C selection by `GRIND_FLEET`, `/status_b`, `/status_c`) |
| VPS (cycle 3) | `5685e4f`, FTMO 1514731800, `pipshed.com` |
| Box 1 (Fleet B) | 207.148.14.197; `5685e4f`; IC 53066709; `linux.pipshed.com`. Graded add dial (fleet-b.md B1) STAGED in `MQL5/Presets`, NOT yet reloaded |
| Box 2 (Fleet C) | 64.177.116.219; IC **53071896** (`ICMarketsSC-Demo`, Hedge, $10k, 1:100); `main` `e2ac9fe` compiled 0/0; suite 2220/2220; `presets_c` staged with the key; Algo OFF, nothing attached; `linuxc.pipshed.com` (Railway "pipshed Fleet C") 11 instances, 0 live. MT5 is started detached (06 s9), not from the Wine menu |

---

## 2. NEXT, IN ORDER

1. **Sunday daytime: the fleet summary strip (pipshed; backlog C7).**
   Operator 27 Sep: four cards at the top of every pipshed page
   (`pipshed.com`, `linux.`, `linuxc.`): cycle 3, Fleet B, Fleet C, and
   an empty Fleet D placeholder. Every web service reads the same Redis,
   so any host can summarise any fleet; reuse the shared status helper
   `_fleet_summary(instances)` (pipshed `3184c88`, Gemini GC-2). Card
   proposal (operator to confirm or trim): header (fleet, broker,
   account, build); health (live/total, halted, oldest heartbeat,
   red if any halted or silent); money (realised today, open MTM,
   closed net today from the ejection view); risk (open layers per
   side, deepest side, breaker/gate). Open: scalps today; day P&L as a
   share of the $500 limit. Spec -> Gemini -> Cursor in `D:\pipshed` on
   a branch -> Claude runs every verify script. Web reads Redis only
   (ARCHITECT s10). Do not push pipshed `main` at 20:50-21:00Z.
2. **Sunday 27, in session (from ~19:00 ET):** reload the nine Fleet B
   `_opt_b` charts from the staged presets over VNC (Properties, Load,
   OK). Per chart: deinit reason 5; a CONFIG line with the new
   `InpAddPips`; `ea_build` unchanged; clean recon; POST ok. STOP on
   FATAL, CRITICAL, `INVARIANT_FAIL`, `STARTUP_EXIT_SHORTFALL` or
   `RECON_FAIL`. Record the reload times in fleet-b.md B1.
3. **Monday, in session:** attach box 2 per fleet-c.md s2 (Algo ON
   first, pilot GBPUSD until POST ok, then ten; pass lines and STOP list
   there). Watch the session; that night's carry pass for the C ids.
4. **C63, Tue or Thu in session:** compile `main` on box 1 (first v2.1
   init strict, labels written) + lattice presets
   (`InpVirtualLattice=true`, `InpAutoEject=false`); box 2 the same,
   same day (fleet-c.md s3, amendment first).
5. **Every night:** `archive_counts.py --carrypass --hours 2` after 21:00Z
   (01_BOOT). Later: box 3 (Fleet D; 06 s9 lessons), compass rounds,
   C57, C61 (week of 28 Sep), C62, C64-C68, C71.

---

## 3. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in committed source; RUN every verify script
  yourself. Predict tests-first failures by asking what answers BEFORE
  the code exists (a missing Flask route returns an HTML 404).
- Name the workspace (`D:\fxmatrix` or `D:\pipshed`) in every Cursor
  prompt; a new Cursor chat per task.
- PowerShell eats braces: always write `git rev-parse "HEAD^{tree}"`.
- The pipshed web never holds `DATABASE_URL`; never `git clean`
  `D:\pipshed`.
- The telemetry key lives in `~/.fxgrind_telemetry.key` on each box and
  never in git or chat (compare boxes by `sha256sum | cut -c1-12`).
- Read a box's state without its GUI where you can (Journal logs over
  SSH, UTF-16): a live terminal's dialogs are one click from a change.

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

Line count: 125
