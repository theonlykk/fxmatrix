This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-25 ~22:00Z (FRIDAY CLOSE)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Read, in order:
`handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` sections
12 to 16 (s16 is the newest and holds the weekend plan); the four newest
sections of `handoffs/Handover/02_TRAPS.md`; `handoffs/Handover/08_BACKLOG.md`;
`docs/architecture/ADR-162-virtual-lattice.md` s13-s15;
`docs/architecture/geometry-cycle3.md` s4-s5 and A4-A5;
`docs/architecture/fleet-b.md`; the archive table in
`handoffs/Handover/03_COOKBOOK.md`; then this. Verify HEADs in git first.

---

## 0. THE SINGLE MOST IMPORTANT FACTS

**Both fleets run `5685e4f` (C52) and the market is CLOSED until Sunday
17:00 ET.** `main` carries ADR-162 COMPLETE (Phase A, B1 + C54, B2) with
`InpVirtualLattice` default OFF; nothing of it is deployed.

**Passive ejection is the operator's priority** -- "one of the central
planks of this approach": entries are random, so no loyalty to a
position, "especially if they are wildly underwater". The other plank:
using the trade data we accrue (cycle 4). ROADMAP s6.

**NEVER run `fxgrind_tests` on a terminal with live EAs** (VPS, Linux
box). Only the desktop runs the suite. **Never reattach or deploy with the
market closed** (traps): in the session, once spreads settle.

**Cycle 3 (VPS, FTMO) is FROZEN** except for defect fixes. Dials and the
lattice go to **Fleet B (the Linux box, IC Markets)** only.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `d6d2d7a` or a docs-only descendant; EA == `669da60`: `git diff --stat 669da60 origin/main -- ea/ scripts/ tools/` must be empty |
| pipshed `main` | `5e8b904` (`--codes`, `--depth`; `--carrypass` at `c0a5f44`) |
| VPS (cycle 3) | `5685e4f`, tag `vps-5685e4f`, restore `vps-a01a5d4`; FTMO 1514731800; `pipshed.com` |
| Box 1 (Fleet B) | `5685e4f` since 25 Sep 04:42:55Z; IC 53066709; `linux.pipshed.com` |
| Suite | 2114/2114 at `00e0e4e` (EA of `669da60`); 1887/1887 at `5685e4f` (live build) |
| Brokers | both servers GMT+3 (verified); carry window 20:50-20:59Z |

---

## 2. DONE IN THE LAST CHAT (25 Sep, HANDOFF s13-s16)

- C54 (B1 post-audit) merged `db86ede`; C55 (B2: tick-history catch-up,
  running extreme since cap, ROLL_STRANDED, ROLL_CLOSING_STUCK) merged
  `669da60`; DeepSeek verdicts checked (ADR-162 s14-s15).
- C52's first live carry pass CLEAN on both fleets; C60 confirmed
  (Friday: 78 no-change modifies, refused locally, harmless).
- pipshed `--carrypass`, `--codes`, `--depth`. 48 h evidence: no
  ejections, no side at cap (deepest 7, AUDCAD short).

---

## 3. NEXT, IN ORDER (the weekend; HANDOFF s16)

1. **Resting-add trace** (Claude, source only): what the engine does to a
   RESTING add when a reattach changes `InpAddPips` (geometry-cycle3 s5:
   untraced). Needed before Sunday's dials.
2. **Tick-history probe** for the box: a read-only script,
   `CopyTicksRange(COPY_TICKS_INFO)` over the last 24 h (count, first/
   last time, min ask, max bid). Works with the market closed. Clears
   ADR-162 s15's GD6 precondition (C63).
3. **C56 pipshed** (spec with Gemini questions inside -> Gemini -> Cursor,
   tests on a real PostgreSQL): `rolled` column, rolled fills out of
   scalp counts and the Daily card, ROLL_STRANDED and ROLL_CLOSING_STUCK
   on the banner allow-list, roll counts.
4. **Fleet B lattice pre-registration** (`fleet-b.md` amendment) and
   `presets_b` (`InpVirtualLattice=true`, `InpAutoEject=false`), as
   patches. OPEN QUESTION for the operator: all 11 instances, or a subset
   kept on ADR-157 as a comparison.
5. **Group A dials** (after 22:00Z Fri, any time this weekend):
   `s4_scalps.py --days 2`; compute the `_OPTB` ratios yourself (the
   script does `_OPT` only); patch `presets_b`; the operator reattaches
   those charts on the box Sunday ~19:00-21:00 ET or before 03:00 ET
   Monday. Preview: AUDCHF and NZDCHF tighten add 6 -> 5.
6. **Deploy the lattice on Fleet B** (C63): Tuesday or Thursday during the
   session (not a dial day).
7. **Every night:** `archive_counts.py --carrypass --hours 2` after 21:00Z.

---

## 4. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in git; count lines mechanically.
- Check an advisor's premise, not only his conclusion; a DeepSeek
  "BREAKS" can be a ruling it did not know (C54 T-6).
- MQL5 rejects `static` on file-scope functions.
- `CARRY_SNAPSHOT` is also written at every EA init: use `--carrypass`,
  not `--carry`, for the night.
- `send_logs` `duration_ms` 0 = refused by the terminal, not the broker.
- PowerShell: quote `'HEAD^{tree}'`; `-match` is case-insensitive.

---

## 5. WORKING PRACTICE

- One shell step per message; the operator pastes output back.
- Docs and small fixes: Claude commits in its sandbox, hands over
  `git format-patch` files (present_files card, byte size, expected tree
  hash); the operator `git am`s from Downloads and pushes; Claude
  verifies on GitHub.
- Features: spec (bookends, Gemini questions inside, tests first,
  failures predicted BY NAME) -> Gemini -> Cursor on a branch, told to
  PUSH -> Claude reads the commits -> the operator runs each suite state
  on the DESKTOP -> DeepSeek (runner prompt by patch) for anything that
  places, moves or cancels orders -> merge `--no-ff`.
- Pipshed changes: tested on a real PostgreSQL in Claude's sandbox,
  delivered by patch; pushing redeploys the archive worker (not inside
  the carry window).
- Long chats: keep working and keep docs current; propose a handoff only
  near the real limit (BOOT).

Line count: 122
