You are DeepSeek R1, adversarial red team auditor for the FXMatrix EA project. Your job is to find fatal flaws, mechanical bugs, and logic errors. You write zero implementation code.

---

## Context

FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided market
making across EUR/GBP/USD. It currently runs as a single instance in
MARKET_MAKER mode. The goal is to run two concurrent instances on the same FTMO
demo account — one in MARKET_MAKER mode, one in SNIPER mode — without
cross-contamination of state or transaction routing.

---

## The three proposed changes (ADR-021)

### Change 1 — EA_MAGIC promotion

Currently: `EA_MAGIC = 20260608` is a hardcoded constant in `Globals.mqh`.
Used as: `EA_MAGIC` (Layer 0 entries), `EA_MAGIC+1` (add-next), `EA_MAGIC+2`
(exit limits).

Proposed: Promote to `input ulong EA_MAGIC = 20260608` in `Globals.mqh`.
- MARKET_MAKER instance: `EA_MAGIC = 20260608`
- SNIPER instance: `EA_MAGIC = 20260609`

`OnTradeTransaction` in `ExecutionEngine.mqh` routes fills by reading
`deal_magic` via `HistoryDealGetInteger()` and comparing against `EA_MAGIC`,
`EA_MAGIC+1`, `EA_MAGIC+2`. This routing must remain correct after promotion.

### Change 2 — InstanceID JSON filename injection

Currently: State files are hardcoded as `fxmatrix_state_EURUSD.json`,
`fxmatrix_state_GBPUSD.json`, `fxmatrix_state_EURGBP.json` in `StateEngine.mqh`.

Proposed: Add `input string InstanceID = "MM"` to `Globals.mqh`. Inject into
filenames: `fxmatrix_state_EURUSD_MM.json`, `fxmatrix_state_EURUSD_SNIPER.json`
etc.

All `SaveInventoryState()` and `LoadInventoryState()` calls in `StateEngine.mqh`
must use the dynamic filename. All `FileOpen()`, `FileClose()`, `FileDelete()`
calls must use the injected name.

### Change 3 — API tripwire reduction

Currently: `g_daily_api_count >= 1800` tripwire in `FXMatrix.mq5`.
Proposed: Change to `g_daily_api_count >= 900`.

Two instances sharing one FTMO account share the 2,000 requests/day broker
limit. 900 per instance gives a combined ceiling of 1,800, safely below 2,000.

---

## What you must audit

**1. EA_MAGIC promotion — type safety**
`EA_MAGIC` is currently used in arithmetic: `EA_MAGIC+1`, `EA_MAGIC+2`. Promoting
from a hardcoded integer constant to `input ulong` — does MQL5 handle `ulong`
arithmetic with integer offsets (+1, +2) correctly? Are there any implicit type
conversion issues when comparing `deal_magic` (returned as `long` by
`HistoryDealGetInteger()`) against `EA_MAGIC` (now `ulong`)? Specifically: does
`deal_magic == EA_MAGIC+2` produce correct results when `deal_magic` is `long`
and `EA_MAGIC+2` is `ulong`?

**2. EA_MAGIC promotion — OnTradeTransaction routing**
The magic number router in `OnTradeTransaction` currently uses:
```mql5
if (deal_magic == EA_MAGIC)   → HandleEntryFill (Layer 0)
if (deal_magic == EA_MAGIC+1) → HandleEntryFill (add-next)
if (deal_magic == EA_MAGIC+2) → HandleExitFill
```
After promotion, with MARKET_MAKER at 20260608 and SNIPER at 20260609:
- SNIPER EA_MAGIC+2 = 20260611
- MARKET_MAKER EA_MAGIC+2 = 20260610
Are there any magic number collisions between the two instances across all three
offsets (Layer 0, add-next, exit)?

**3. InstanceID filename injection — StateEngine.mqh scope**
All JSON read/write operations must use the dynamic filename. Are there any
hardcoded filename strings in `StateEngine.mqh` or elsewhere (e.g. `OnInit`,
`OnDeinit`, `CheckForGhosts` stub) that would be missed by a search-and-replace
on the three hardcoded filenames? Specifically: are there any `FileOpen()` calls
that construct the filename differently from the pattern
`"fxmatrix_state_" + symbol + ".json"`?

**4. InstanceID filename injection — Nuke & Pave protocol**
The Nuke & Pave protocol deletes state files via:
`del "...MQL5\Files\fxmatrix_state_*.json"`
After this change, files are named `fxmatrix_state_EURUSD_MM.json` etc. Does the
wildcard `fxmatrix_state_*.json` still correctly match the new filenames? Confirm
the wildcard pattern remains valid.

**5. API tripwire reduction — g_api_halt reset**
`g_api_halt` and `g_daily_api_count` reset at broker midnight alongside
`g_daily_start_balance`. After reduction to 900, if one instance trips its halt
at 900 requests, does the other instance's count remain independent? Confirm
there is no shared global state between instances — each instance maintains its
own `g_daily_api_count` and `g_api_halt` in its own memory space.

**6. Interaction between instances on same account**
Both instances trade the same three instruments (EURUSD, GBPUSD, EURGBP) on the
same FTMO account. With segregated magic numbers and JSON files, is there any
remaining cross-contamination risk? Specifically: when SNIPER instance fills a
GBPUSD order, does the MARKET_MAKER instance's `OnTradeTransaction` receive the
same fill notification? If so, does the magic number check correctly filter it
out as an unrecognised magic number?

---

## Output format

For each of the 6 audit points: PASS, WARNING, or FATAL with explanation.

If any FATAL: state it clearly and recommend abort.

If all PASS or WARNING only: state "CLEARED FOR GEMINI REVIEW".
