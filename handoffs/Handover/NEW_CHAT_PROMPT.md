This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-27 ~02:45Z (SUNDAY, EARLY)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s17
and ALL of s18 (26-27 Sep, with its continuations); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 to 2026-09-27;
`handoffs/Handover/08_BACKLOG.md` (above all C47, C51, C63, C68, C70);
`docs/architecture/cycle4-live-geometry-search.md` s8 (rev 3) and **s8.12
(THE ROADMAP)**; `docs/architecture/ADR-163-rebuild-at-start.md`;
`docs/architecture/fleet-b.md` (amendment B1); `handoffs/Handover/06_LINUX_WINE_BOX.md`
s3, s4, s7 and **s9 (box 2)**; `docs/architecture/ADR-162-virtual-lattice.md`
s13-s18; `docs/architecture/ARCHITECT.md` s10; `handoffs/Handover/03_COOKBOOK.md`;
then this.

---

## 0. THE MOST IMPORTANT FACTS

**One EA.** `main`'s EA (== `2ff62f4`, grind v2.1) IS the dual add/exit
EA: six per-side inputs (`InpWidthPipsLong/Short`, `InpAddPipsLong/Short`,
`InpExitPipsLong/Short`; -1 = inherit the base input), ADR-163 rebuild at
start (a changed EXIT reprices the resting exits at init instead of
halting on I6; label GVs `GRIND_GEO_EXIT_<magic>_L/_S` gate it), and the
ADR-162 lattice (default OFF). Suite 2220/2220. **Deployed nowhere yet:
both fleets run `5685e4f`.**

**The roadmap is the cycle-4 note s8.12** (operator, 27 Sep, "a good
starting point"): box 2 (Fleet C) and its page tonight -> Monday: box 2
runs `main` at Fleet B's settings as a CODE check, no flattening -> C63
(Tue or Thu, in session): `main` + lattice on box 1, box 2 matched -> a
few days watching rolls, fixes in `main` -> box 3 (Fleet D) and compass
rounds, box 1 the anchor -> best values into box 1 -> FTMO add-only until
cycle 3 ends (or the operator ends it).

**The market is closed until Sunday 17:00 ET (21:00Z).** Never reattach,
reload inputs or deploy with the market closed. **Never run
`fxgrind_tests` on a terminal with live EAs.** Cycle 3 (VPS, FTMO) is
FROZEN except for defect fixes. **Box 1: RDP is locked out**; use x11vnc
on `:10` over an SSH tunnel (06 s4); never reboot it.

**Read what a fleet did from pipshed, not logs** (plain-text URLs; change
the last segment every fetch; 503 = view missing or stale, never zero):

    https://linux.pipshed.com/api/g/k7m9p2x4q/ejection/a1?hours=96

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `a9a52c4` or a docs-only descendant; `git diff --stat 6a1e9ad origin/main -- ea/ tools/` must be empty (6a1e9ad = v2.1 merge) |
| pipshed `main` | `3184c88`: Fleet C (`GRIND_FLEET=C`, ids `_OPTC`/`_ALTC`, `/api/g/<token>/status_c`); Railway redeployed, Fleet B page checked after |
| VPS (cycle 3) | `5685e4f`, FTMO 1514731800, `pipshed.com` |
| Box 1 (Fleet B) | 207.148.14.197; `5685e4f`; IC 53066709; `linux.pipshed.com`. Graded add dial (fleet-b.md B1) STAGED in `MQL5/Presets`, NOT yet reloaded; backups in `/home/khalid/preset_backup_20260926`; box repo fetched only (HEAD `5685e4f`) |
| Box 2 (Fleet C) | NOT created at handover: the operator was about to create the Vultr instance and open the IC demo |
| Suite | 2220/2220 GBPUSD+EURUSD at `2ff62f4`; 1887/1887 at `5685e4f` |

---

## 2. NEXT, IN ORDER

1. **Box 2 build** (06 s9), one step per message, the operator pasting
   output: s3 as root (ufw; apt upgrade; xfce4 + xrdp; i386 + wine64
   wine32 winbind, Wine 9 from Ubuntu, no WineHQ; adduser khalid + sudo;
   `.xsession`; xrdp; PAM prompt = No), MT5 as khalid, then s7 steps 2-9
   as adapted in s9 (account login, WebRequest `https://pipshed.com`, One
   Click Trading off, repo clone at `main`, copy `ea/*` to Experts and
   Scripts, compile 0/0, suite ONCE before any attach, key file).
2. **Claude: `ea/presets_c` + `docs/architecture/fleet-c.md`** as one
   patch. Eleven `*_c.set` copied from `presets_b` AFTER the dial (dd4761e
   values), changing only: `InpTelemetryInstance` to
   `GRIND_<PAIR>_OPTC`/`_ALTC`, and six explicit per-side lines at -1.
   Diff each against its `_b` twin and list the changed lines. fleet-c.md:
   setup (box, account, ids, page), phase 1 = code check (pass: clean init
   with `GRIND_GEOMETRY`, `GRIND_REBUILD`, `GRIND_LATTICE enable=false`,
   recon and POST ok; a full session with no FATAL, CRITICAL,
   `INVARIANT_FAIL` or halt; scalps booking), no flattening, optional
   fresh-ladder comparison (scalps on ladders whose L0 opened after box 2's
   start, on both fleets), phase 2 = matched lattice at C63.
3. **Operator: Fleet C page.** Third Railway web service from pipshed:
   `GRIND_FLEET=C`, `GRIND_FLEET_LABEL` (e.g. "Fleet C - IC Markets
   <account>"), the same Redis URL, NO `DATABASE_URL`; proxied Cloudflare
   CNAME as for `linux.pipshed.com`. Check
   `https://pipshed.com/api/g/k7m9p2x4q/status_c/<n>` answers (11
   instances, 0 live until Monday).
4. **Sunday 27, in session (from ~19:00 ET):** reload the nine Fleet B
   `_opt_b` charts from the staged presets over VNC (Properties, Load,
   OK). Per chart: deinit reason 5; a CONFIG line with the new
   `InpAddPips`; `ea_build` unchanged; clean recon; POST ok. STOP on
   FATAL, CRITICAL, `INVARIANT_FAIL`, `STARTUP_EXIT_SHORTFALL` or
   `RECON_FAIL`. Record the reload times in fleet-b.md B1.
5. **Monday, in session:** attach box 2 (Algo ON first, pilot GBPUSD
   until POST ok, then ten). Watch the session against step 2's pass.
6. **C63, Tue or Thu in session:** compile `main` on box 1 (first v2.1
   init strict, labels written) + lattice presets (`InpVirtualLattice=true`,
   `InpAutoEject=false`); box 2 the same, same day.
7. **Every night:** `archive_counts.py --carrypass --hours 2` after 21:00Z
   (01_BOOT). Later: box 3, compass rounds, C57, C61 (week of 28 Sep),
   C62, C64-C68.

---

## 3. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in committed source; RUN every verify script
  yourself. Predict tests-first failures by asking what answers BEFORE
  the code exists (a missing Flask route returns an HTML 404).
- Name the workspace (`D:\fxmatrix` or `D:\pipshed`) in every Cursor
  prompt; a new Cursor chat per task.
- PowerShell eats braces: always write `git rev-parse "HEAD^{tree}"`.
- The pipshed web never holds `DATABASE_URL`; never `git clean`
  `D:\pipshed`; avoid pushing pipshed `main` at 20:50-21:00Z.
- The telemetry key lives in `~/.fxgrind_telemetry.key` on each box and
  never in git or chat.

---

## 4. WORKING PRACTICE

- One shell step per message; the operator pastes output back. Say WHERE
  each command runs (desktop PowerShell, box SSH, GUI).
- Docs and small fixes: Claude commits in its sandbox and hands over
  `git format-patch` files (byte size, expected tree hash); the operator
  `git am`s from Downloads, checks the tree, pushes; Claude verifies on
  GitHub. Claude never pushes (decline the stop hook's push request).
- Features: spec (Gemini questions inside, tests first, failures
  predicted BY NAME, line count at the bottom) -> Gemini -> Cursor on a
  branch -> Claude reads the commits -> DeepSeek for anything that moves
  orders -> merge `--no-ff`. One document at a time for Gemini.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 137
