This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-23 02:35Z

You are picking up mid-project. **Read `handoffs/Handover/01_BOOT.md`,
then `handoffs/HANDOFF_2026-09-23.md`, then `02_TRAPS.md`**, then this
document. Verify `main`'s HEAD SHA against BOOT before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACT

**The account switch and the start of cycle 3 are now SEPARATE jobs.**
Close out cycle 2 with `docs/runbooks/account-close-out.md`; start cycle
3 with `docs/runbooks/cycle3-start.md` only when its readiness gate is
met. There is no deadline between them: the code is finished first, so a
pre-registered cycle is not blended with mid-cycle changes. Work each
top
to bottom. Every check in it exists because something went wrong once.

**F1 (the barbell exit queue) DOES deploy on Wednesday.** It halted all 16
instances on 2026-09-20 because every existing book was built under the
old prefix rule. The new account starts FLAT, so there is nothing to
migrate. **It must still never go onto an EXISTING book** (backlog C2).

---

## 1. STATE

| | |
|---|---|
| fxmatrix `main` | `ce6e985` |
| pipshed `main` | `5153977` |
| VPS running | `5454358`, DETACHED HEAD, 16 instances, cycle-2 presets |
| Suite | `main` **1619/1619**, GBPUSD |
| Account | demo 1514582088, $10k, FTMO daily limit $500. **Worst day -$420** |
| Next | Wednesday: new account, 9 instances, one arm each |

---

## 2. WHAT WEDNESDAY DEPLOYS

`main`: F1 barbell + ADR-153 (add/width lock removed, recentre stops at
the 1,800 API soft-warn) + ADR-156 (startup places missing exits) +
the suite fix + nine cycle-3 presets.

Cycle 3 (`docs/architecture/geometry-cycle3.md`, the pre-registration):
GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, NZDCAD, AUDNZD, NZDCHF
(ADR-154). One arm each on the OPT magic, cap 8, lots 0.01, carry off.
**Exit and cap may not change mid-cycle** (I6/I7 halt); add, width,
stranded and deadband may.

---

## 3. NEXT, IN ORDER

**Done:** C2 / ADR-156 (`3f72b9f`), C15 / ADR-155 commanded passive
ejection (`95c89c6`), C25 / carry unblocked plus GlobalVariable flushing
(`f870598`), and C27 / ADR-157 automatic passive ejection trigger
(`ce6e985`); both ejection switches default off. Close-out and the cycle-3
start are SEPARATE: close out before the demo expires; start cycle 3
only when its readiness gate is met (`docs/runbooks/cycle3-start.md`).

1. **Close-out** (`docs/runbooks/account-close-out.md`) -- today.
2. **C17 account daily-loss circuit breaker.** First pin how FTMO
   computes today's permitted loss and when the day resets.
3. **C24 daily snapshot and C19 CRITICAL events** in pipshed.
4. **A5 account identity; carry ON and auto-eject ON in the nine
   presets; the pre-registration amendment** (carry ON, ejection, USD
   reported with no target) -- all before the first fill.

---

## 4. TRAPS THAT BIT THIS WEEK (full list in 02_TRAPS)

- **Presets in `MQL5\Presets` must match what is attached**, or a reattach
  halts on I6. **Read every input back before OK** -- loading a preset
  silently resets values typed before it.
- **Never close a position under a running EA** -- quarantine, then halt.
  Detach first (`docs/runbooks/manual-roll.md`).
- **Check the suite TOTAL**, not just the FAIL rows. The suite runs from
  `MQL5\Scripts\`; `desktop_sync.ps1` is at the repo ROOT and does not
  copy the repo's `scripts\` folder.
- **Cursor leaves the repo on its branch.** `git branch --show-current`
  before every commit.
- **Cursor's self-reported hashes and line counts are wrong after an
  amend.** Verify against origin; count every file.

---

## 5. WORKING PRACTICE

- Verify against committed source. Never trust an agent's claim or CLI
  compile output.
- Specs for Cursor go in the repo; Gemini BRIEFS stay in chat, his
  RULINGS go in the repo (`05_GIT_AS_TRANSPORT.md`).
- Gemini catches mechanical traps well, but his premises are only as good
  as what he is told -- and he has at least once reviewed the wrong file.
  Ask him to quote the line he is commenting on.
- DeepSeek via `r1_audit.py` is mandatory for anything that changes when
  orders are placed (ARCHITECT s2).
- Tests first; a new test must FAIL before the change. Write the negative
  twin of any test that asserts something happens.

Line count: 105
