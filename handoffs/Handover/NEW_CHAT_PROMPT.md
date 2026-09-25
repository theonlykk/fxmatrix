This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-25 ~04:00Z

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Read, in order:
`handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` sections
7 to 11 (s11 is the newest); the four newest sections of
`handoffs/Handover/02_TRAPS.md`; `handoffs/Handover/08_BACKLOG.md` (C52-C57
are new); `docs/architecture/ADR-162-virtual-lattice.md` s12-s13; then
this. Verify HEADs in git before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACTS

**A LIVE DEFECT comes first (backlog C52).** The nightly carry pass
(23:50-00:00 broker time) captures each layer's exit ticket at
`Grind_CarryExitPassBegin`, then works 2 items per minute. A layer the
queue releases mid-pass gets its accrual committed while its new exit
stays at yesterday's accrual: I6 fails, quarantine cannot repair it, the
instance HALTS, and a restart likely fails reconstruction. Latent, not
fired (VPS logs 24-25 Sep). Cycle 3 and Fleet B both run carry ON. If it
fires: red banner, INVARIANT_FAIL `I6_*_EXIT` near the window; do NOT
restart that instance.

**Two fleets are LIVE; cycle 3 is FROZEN** except for defect fixes (C52
is one). The FTMO account dies on the DAILY limit ($500 from day-start
balance, equity includes open MTM); ADR-158 breaker and ADR-160 gate are
the defences.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | a docs-only descendant of `8f72d00`; EA code == tested `9466b22`: `git diff --stat 9466b22 origin/main -- ea/ scripts/ tools/` must be empty |
| branch `adr162-phase-b1` | head `73b1a8d` (DeepSeek response); EA code == `3188f72`, suite 2002/2002 GBPUSD+EURUSD; NOT merged (C54 first) |
| pipshed `main` | `2f3e749` (verify 23/23; migration 003 applied) |
| VPS (cycle 3) | `a01a5d4`, tag `vps-a01a5d4`, 11 live, FTMO 1514731800, `pipshed.com` |
| Box 1 (Fleet B) | built from `87765be`, presets `85cd555`, 11 live, IC 53066709, `linux.pipshed.com` |
| Suite | 1875/1875 at `9466b22`; 2002/2002 at `3188f72` (B1 branch) |

---

## 2. BUILT IN THE LAST CHAT (ADR-162 s13 has the detail)

- ADR-162 Phase B1: spec `prompts/cursor_adr162_phase_b1.md` (branch);
  Gemini GB1-GB10, GB5 amended by Claude (the daily API count is ONE GV
  for the fleet); Cursor `5865060`, `f95d4b8`; Claude patches `a949d65`,
  `867d3c8`, `d5cf777`, `3188f72` (compile fix, two test faults, int
  overflow in the backoff); DeepSeek `73b1a8d`, every verdict checked.
- Operator: no layer is ever rolled twice; roll on demand deferred (C53).
- C52 found by DeepSeek T-4, checked in source, evidence in HANDOFF s11.

---

## 3. NEXT, IN ORDER (operator, 2026-09-25)

1. **C52 carry-pass race (defect fix).** Read in source BEFORE citing:
   `Grind_CarryExitPassBegin`, `Grind_CarryExitPassStep`,
   `Grind_CarryExitShiftLayer` (its `exit_order_ticket == 0` branch),
   `Grind_CarryWorkBase`, the retry list, `Grind_ExitQManageSide` and
   `Grind_ExitQHoldCancelLayer`, and the quarantine rules
   (`grind_quarantine.mqh`: I6 quarantinable, halt after 3 s and 3
   checks). Confirm the race and its halt sequence; include the second
   case (a captured exit cancelled mid-pass loses that night's accrual).
   DeepSeek's smallest fix: at shift time re-read the layer's CURRENT
   exit ticket from the book by position ticket. Pin the window from the
   archive (`CARRY_PASS_SUMMARY` times; broker GMT offset unverified).
   Spec with bookends, tests first with stub failures predicted BY NAME,
   Gemini questions inside -> Cursor -> both suites -> DeepSeek -> merge
   -> deploy to the VPS and Fleet B at a moment the operator picks (tag
   first). Every compile restarts a fleet.
2. **C54** B1 post-audit patch (T-3 fix, T-10 tests), both suites, merge
   `adr162-phase-b1` `--no-ff`.
3. **C55** ADR-162 B2 (M1 catch-up, ROLL_STRANDED); **C56** pipshed.
4. **Fleet C (C51) waits** until 1-3 are done. Fleet B group A dials Mon
   28 Sep before London (A4) are unchanged.
5. **Watch daily (22:00Z):** the red banner near the carry window, Carried
   (first real value Fri), gated hours, guard_total, carry clamps (C26).

---

## 4. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in git; count lines mechanically.
- A red-team finding can predate the change it audits (C52).
- Check an advisor's premise, not only his conclusion (GB5).
- `ArrayResize` does not clear structs; an assertion in an `if` can pass
  by not running; read fixtures, not only assertion names.
- Test headers need no forward declarations (a mistyped one broke the
  compile).
- PowerShell: quote `'HEAD^{tree}'`. Log greps: drop `HEARTBEAT` lines.
- Cursor leaves its branch checked out: `git switch main` before a docs
  patch or a merge.

---

## 5. WORKING PRACTICE

- One shell step per message; the operator pastes output back.
- Docs and small fixes: Claude commits in its sandbox, hands over
  `git format-patch` files (present_files card, byte size); the operator
  `git am`s from Downloads (never inside the repo); Claude gives the
  expected tree hash; Claude verifies the pushed tree on GitHub.
- Features and fixes: spec with bookends and Gemini questions inside ->
  Gemini -> Cursor on a branch, tests first, stub failures predicted BY
  NAME, told to PUSH -> Claude reads both commits in source -> the
  operator runs each suite state (checkout, `desktop_sync.ps1`, GUI
  compile, run) -> DeepSeek for anything that places, moves or cancels
  orders -> operator merges `--no-ff`.
- Operator stance: boring is best; live trade history is the evidence.
- **Watch the chat's length.** Propose a handoff (docs patch + fresh
  chat) BEFORE work that needs close reading of code.

Line count: 119
