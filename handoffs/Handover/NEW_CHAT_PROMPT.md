This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-25 ~05:00Z

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Read, in order:
`handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` sections
7 to 12 (s12 is the newest); the five newest sections of
`handoffs/Handover/02_TRAPS.md`; `handoffs/Handover/08_BACKLOG.md`;
`docs/architecture/ADR-162-virtual-lattice.md` s12-s13;
`docs/architecture/geometry-cycle3.md` A4-A5; then this. Verify HEADs in
git before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACTS

**Both fleets run `main` `5685e4f` since 25 Sep** (Fleet B 04:42:55Z, VPS
04:50:36Z): the C52 carry-pass fix, plus ADR-161 (OFF) and ADR-162 Phase
A (inert). Its first live test is the carry window of Fri 25 Sep
(~20:50Z if the broker runs GMT+3): confirm CARRY_PASS_SUMMARY on both
fleets and no I6 near the window.

**NEVER run `fxgrind_tests` on a terminal with live EAs** (VPS, Linux
box): it deletes shared GVs by prefix and would trip I6 fleet-wide. Only
the desktop (no EAs attached) runs the suite.

**Cycle 3 is FROZEN** except for defect fixes. The FTMO account dies on
the DAILY limit ($500 from day-start balance, equity includes open MTM);
ADR-158 breaker and ADR-160 gate are the defences.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `5685e4f` or a docs-only descendant; EA == `5685e4f`: `git diff --stat 5685e4f origin/main -- ea/ scripts/ tools/` must be empty |
| branch `adr162-phase-b1` | head `73b1a8d`; EA == `3188f72`, 2002/2002; NOT merged (C54 next) |
| pipshed `main` | `2f3e749` (verify 23/23) |
| VPS (cycle 3) | `5685e4f`, tag `vps-5685e4f`, restore `vps-a01a5d4`; FTMO 1514731800; `pipshed.com` |
| Box 1 (Fleet B) | `5685e4f` since 04:42:55Z; presets `85cd555`; IC 53066709; `linux.pipshed.com` |
| Suite | 1887/1887 at `5685e4f` (desktop); 2002/2002 at `3188f72` |

---

## 2. DONE IN THE LAST CHAT

- ADR-162 Phase B1 built and audited on its branch (ADR-162 s13).
- C52 found (DeepSeek T-4 on B1), fixed, tested (race reproduced first,
  both symbols), audited (DeepSeek `e7202e8`; CR4/CR5 added from its test
  gaps), merged `5685e4f`, deployed to both fleets (HANDOFF s12,
  pre-registration A5).

---

## 3. NEXT, IN ORDER

1. **Confirm tonight's carry pass** on both fleets (archive, banner).
2. **C54:** B1 post-audit patch (DeepSeek T-3: an unselectable exit order
   is "closing", no ROLL_REFUSED, no backoff; T-10 tests), both suites,
   merge `adr162-phase-b1` `--no-ff` (the test include and registration
   lines in `fxgrind_tests.mq5` conflict with C52's: keep both).
3. **C55** ADR-162 B2 (M1 catch-up, ROLL_STRANDED); **C56** pipshed.
4. **Fleet C (C51)** after 2-3. Fleet B group A dials Mon 28 Sep before
   London (A4) unchanged.
5. **Watch daily (22:00Z):** red banner, Carried, gated hours,
   guard_total, carry clamps (C26); observations C58, C59.

---

## 4. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in git; count lines mechanically.
- Check an advisor's premise, not only his conclusion.
- A red-team finding can predate the change it audits.
- `ArrayResize` does not clear structs; an assertion in an `if` can pass
  by not running; read fixtures, not only assertion names.
- PowerShell: quote `'HEAD^{tree}'`; `-match` is case-insensitive (use
  `-cmatch`). Log greps: drop `HEARTBEAT` lines; compare before/after.
- Keep downloads out of the repo; Cursor leaves its branch checked out.

---

## 5. WORKING PRACTICE

- One shell step per message; the operator pastes output back.
- Docs and small fixes: Claude commits in its sandbox, hands over
  `git format-patch` files (present_files card, byte size, expected tree
  hash); the operator `git am`s from Downloads and pushes; Claude
  verifies on GitHub.
- Features and fixes: spec (bookends, Gemini questions inside) -> Gemini
  -> Cursor on a branch, tests first, failures predicted BY NAME, told to
  PUSH (the operator may paste the spec straight in, with a bookend
  check line) -> Claude reads both commits -> the operator runs each
  suite state on the DESKTOP (checkout, `desktop_sync.ps1`, GUI compile,
  run) -> DeepSeek for anything that places, moves or cancels orders ->
  merge `--no-ff`.
- Deploy: desktop EA compile -> Fleet B first (git pull on the box, copy
  to Experts and Scripts, `cmp`, compile `fxgrind.mq5`, check) -> VPS
  (`deploy.ps1`, compile, check) -> tag `vps-<sha7>` on the desktop.
- Operator stance: boring is best; live trade history is the evidence.
- **Watch the chat's length;** propose a handoff before close code work.

Line count: 106
