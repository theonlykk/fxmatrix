This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-23 03:40Z

You are picking up mid-project. **Read `handoffs/Handover/01_BOOT.md`,
then `handoffs/HANDOFF_2026-09-23.md` (read its UPDATE sections to the
end), then `02_TRAPS.md`**, then this document. Verify `main`'s HEAD SHA
against section 1 before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACT

**Cycle 2 is ending; cycle 3 starts only when its readiness gate is met.**
Close out the old demo with `docs/runbooks/account-close-out.md` BEFORE it
expires (Wednesday 2026-09-23; record equity, balance and open MTM first).
Start cycle 3 with `docs/runbooks/cycle3-start.md` when the gate is met --
no deadline. Cycle 3 is pre-registered (`docs/architecture/geometry-cycle3.md`,
amendment **A2**) and tests STRUCTURE: F1 barbell, carry ON, automatic and
manual passive ejection, the FTMO daily-loss breaker.

F1 must never go onto a book built under the old PREFIX rule (the
2026-09-20 halt). The new account starts flat, so it is safe there.

---

## 1. STATE

| | |
|---|---|
| fxmatrix `main` | `87ab20e` or a docs-only descendant (code = tested `646b526`: `git diff --stat 646b526 origin/main -- ea/ scripts/ tools/` must be empty) |
| pipshed `main` | `5153977` |
| VPS running | `5454358`, DETACHED HEAD, 16 instances, cycle-2 presets |
| Suite | `main` **1646/1646**, GBPUSD; EA compiles 0/0 |
| Account | demo 1514582088, $10k, FTMO 2-Step: $500/day. Expires Wednesday |
| Live book 03:22Z | 16 live, 0 halted; open MTM ~ -$377; five sides capped (GBPUSD x2 long, CADCHF ALT long, AUDCAD x2 short) |

---

## 2. WHAT IS BUILT (all merged, all tested)

| item | what | where |
|---|---|---|
| ADR-156 | startup places a missing required exit instead of halting | `3f72b9f` |
| ADR-155 (C15) | manual passive ejection: `scripts/grind_eject.mq5` moves the deepest exit to the best passive price; `InpEnableCommandedEject` | `95c89c6` |
| C25 | ADR-151 Phase B closed -- carry may be enabled; persistent GVs flushed to disk within 1 s (the EA had NEVER flushed) | `f870598` |
| ADR-157 (C27) | automatic passive ejection: at cap, no new extreme for W=5 of 2W min, spread <= 1.5 x hourly mean, trails an orphaned exit, 5-min backoff on a failed modify; `InpAutoEject` | `ce6e985` |
| ADR-158 (C17) | FTMO daily-loss breaker: FTMO day from GMT; anchor from deal history; 80% trip latched per day; blocks + cancels entries; exits/carry/ejection stay on; pre-midnight entry halt; `InpBreakerEnable` default true | `8df6ffa` |
| C20 | DeepSeek runner in the repo: `tools/r1_audit/`, per-audit JSON config | `e9d8d24` |
| A2 | pre-registration amendment: carry and ejection in scope; ejected fills are NOT scalps; new secondary measures in USD, no USD target | `87ab20e` |

Switch defaults in code: ejection OFF, carry OFF, breaker ON. Cycle 3's
presets turn carry and both ejections ON (A2 point 2) -- **not yet done**.

---

## 3. NEXT, IN ORDER

1. **Close-out**, Wednesday before the demo expires (~17 h after
   03:40Z): capture a fresh status URL plus terminal equity, balance, open
   MTM; then the runbook.
2. **ADR-159 = C24 + C19 (+ A5)**, two repos, est. 3-4 h:
   - EA: a `DAILY_SNAPSHOT` event at each FTMO day ROLL for the day just
     ended (realised = balance change; inventory P&L = change in equity -
     balance; total = equity change; swap), emitted ONCE per account (claim
     GV), carrying the account login (A5).
   - pipshed: `archive_worker.py` builds a daily table from those events
     (same pattern as the carry table) and a last-24h list of
     `level=CRITICAL` events -> Redis -> dashboard (a red banner; C17's
     `BREAKER_TRIPPED` is invisible until then).
   - Implement A2 point 4: ejected fills excluded from scalp counts
     (`EJECT_FILLED` marks them).
   - Draft the ADR for Gemini first; then one Cursor prompt per repo.
3. **Presets:** nine cycle-3 presets to A2 point 2 (`InpEnableCarryPass`,
   `InpEnableCommandedEject`, `InpAutoEject` true; W 5, k 1.5), byte-checked.
4. **Attach** per `cycle3-start.md`; check `TimeGMT()` on the VPS against
   real UTC (the breaker's FTMO day depends on it).

---

## 4. TRAPS (full list in 02_TRAPS; newest section is 2026-09-22/23)

- **Reviewer models complete unfilled templates.** Gemini once invented a
  whole Cursor "final report" with SHAs that do not exist. Verify EVERY
  SHA against git; never accept one from a model.
- **Cursor sometimes commits without pushing.** Every prompt ends with
  an explicit push + `git ls-remote` check. On "cursor done", fetch
  origin before reviewing.
- **Windows PowerShell 5.1** has no `Set-Content -NoNewline` and decodes
  BOM-less UTF-8 as ANSI. Edit files with
  `[System.IO.File]::ReadAllText/WriteAllText(path, text, UTF8Encoding($false))`.
- **Tests leak state through globals** (Y12 left a recon-failure record
  that broke R1). Shared resets must be complete; a test that fails a
  rebuild on purpose cleans up after itself.
- **Test names collide by letter** (old B1-B6, F1-F7 exist). Keep
  assertion names distinct and read failures by full name.
- **Presets in `MQL5\Presets` must match what is attached** (I6); read
  every input back before OK.
- **Never close a position under a running EA** -- quarantine, then halt.

---

## 5. WORKING PRACTICE

- **Workflow:** Claude writes Cursor prompts in the artifact window with
  any questions for Gemini INSIDE the prompt; the operator sends it to
  Gemini, then to Cursor. No separate Gemini briefs. Design questions go
  to Gemini as a DRAFT ADR with the questions inside.
- **Tests first, proven by a stub-check branch:** revert the
  implementation commit, predict the failing assertions BY NAME and the
  exact SUMMARY, run, then run the real branch. Every item tonight matched
  its prediction exactly.
- **DeepSeek** (`tools/r1_audit/r1_audit.py --config prompts/<audit>_config.json`,
  interpreter `D:\candlelab\venv\Scripts\python.exe`) is mandatory for
  anything that places or moves orders. Dry-run the config first; verify
  every finding in source before acting -- it both misses and overstates.
- Verify against committed source; never trust an agent's claim or CLI
  compile output. Mechanically count every file with a footer.
- The operator's stance: demo mode -- ship a clear rule, learn from the
  demo, adjust. Avoid analysis paralysis and arbitrary barriers.

Line count: 122
