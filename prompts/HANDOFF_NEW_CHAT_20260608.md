# FXMatrix EA — Full Session Handoff
# Date: 2026-06-08
# Status: Active development, 7 backtests completed, awaiting Cursor + Gemini responses

---

## WHAT THIS IS

FXMatrix is a native MQL5 Expert Advisor implementing a 3-currency FX mean-reversion 
strategy running on FTMO VPS. It is NOT a Python/Railway system — no ZMQ bridge, 
no OANDA. Pure MQL5 on MetaTrader 5.

**Repo:** theonlykk/fxmatrix
**Local:** d:\fxmatrix
**VPS:** 149.28.123.38 (Vultr, Windows Server 2022)
**MT5 account:** 1513622691, FTMO-Demo, Hedging, $10k Swing 2-Step

---

## THE STRATEGY

3-currency pod: EUR=0, GBP=1, USD=2

Currency strength decomposition from 2 pairs (EURUSD, GBPUSD):
  r_EU = log(EURUSD_now / EURUSD_1h_ago)
  r_GB = log(GBPUSD_now / GBPUSD_1h_ago)
  USD  = -(r_EU + r_GB) / 3
  EUR  = r_EU + USD
  GBP  = r_GB + USD

Spread S = score_weakest - score_strongest (always negative by construction)

Signal fires when |S| > EntryThreshold (0.0008 default)

6 routing cases:
  Case 1: S=EUR(0), W=GBP(1) → Sell EURGBP
  Case 2: S=GBP(1), W=EUR(0) → Buy EURGBP
  Case 3: S=EUR(0), W=USD(2) → Sell EURUSD
  Case 4: S=USD(2), W=EUR(0) → Buy EURUSD
  Case 5: S=GBP(1), W=USD(2) → Sell GBPUSD
  Case 6: S=USD(2), W=GBP(1) → Buy GBPUSD

Entry: passive limit order placed at threshold boundary
Exit: passive sell/buy limit at exit_spread_target = entry_spread_raw × (1 - ExitFraction)
ExitFraction = 0.70 (exit when 70% of spread has reverted)

LIFO layer system: up to MaxLayers=5 layers per pod
Each layer has its own entry price, exit target, position ticket
Deeper layers = worse prices = larger exit targets

Key math proof (Gemini-locked):
  Spread S = r_GB - r_EU = -r_EG (zero basis risk)
  Exit target is BELOW entry spread (closer to zero = partial reversion)

---

## MULTI-AGENT PIPELINE

**MANDATORY SEQUENCE — never skip steps:**

1. DeepSeek (Red Team) — adversarial code audit via r1_audit.py
2. Claude (Blue Team / Lead Engineer) — architectural analysis, Gemini questions
3. Gemini (Staff Architect) — rulings on ambiguous architecture/math questions
4. Cursor (Implementation Agent) — code changes only, never architectural decisions

**r1_audit.py** is in d:\fxmatrix\r1_audit.py
Configure FILES_TO_AUDIT, DOCS_TO_INCLUDE, PROMPT_PATH before running.
DeepSeek reads the actual source files + prompt MD file.

**ARCHITECT.md** is in d:\fxmatrix\ARCHITECT.md — governance document, 
all agents must respect it. ADR-driven development, strict sequencing.

**Gemini messages** are sent manually by Khalid — Claude drafts the message,
saves as .md to d:\fxmatrix\prompts\, Khalid copies and pastes to Gemini.
Gemini responses are pasted back as documents.

**Cursor patches** are saved as .md to d:\fxmatrix\prompts\ with exact
BEFORE/AFTER blocks. Cursor edits local files only. Never edits VPS directly.

---

## INFRASTRUCTURE

### VPS
- IP: 149.28.123.38
- OS: Windows Server 2022
- MT5: FTMO account 1513622691
- Experts folder: C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\fxmatrix\
- EA files also in: C:\fxmatrix\ea\
- Deploy script: C:\fxmatrix\deploy.ps1

### deploy.ps1 (on VPS)
```powershell
cd C:\fxmatrix
git pull origin main
xcopy ea\* "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\fxmatrix\" /I /Y
echo "Done - recompile in MetaEditor"
```

### Local machine
- d:\fxmatrix — local repo clone
- d:\fxmatrix\venv — Python venv (NOT .venv)
- d:\fxmatrix\notebooks\fxmatrix_log_analysis.ipynb — Jupyter log parser

### WinSCP
Connected to VPS via SFTP on port 22 (SSH opened on VPS Windows Firewall).
Use Commander mode. Left panel = local d:\fxmatrix\logs\, Right panel = VPS C:\fxmatrix\logs\
Used to transfer MT5 tester log files from VPS to local for Jupyter analysis.

### Git workflow for code changes:
1. Cursor edits local d:\fxmatrix\ea\*.mqh
2. git add / commit / push from local
3. On VPS: .\deploy.ps1 (git pull + xcopy)
4. MetaEditor: F7 to recompile FXMatrix.mq5
5. Strategy Tester: run backtest

### Git workflow for log files:
WinSCP drag from VPS C:\fxmatrix\logs\ to local d:\fxmatrix\logs\
(No need to push logs to git — local analysis via Jupyter)

### Jupyter
- venv activate: d:\fxmatrix\venv\Scripts\Activate.ps1
- Launch: jupyter notebook
- Log parser: notebooks\fxmatrix_log_analysis.ipynb
- Log files use utf-16-le encoding (MT5 binary format)
- Regex patterns use \s+ not \t for timestamp-message separator

### Claude Code
Used for log file analysis (7000+ line files).
Always add to prompt: "You have permission to proceed with all file 
reading and analysis operations without asking for confirmation. 
Do not ask for confirmation at any step."
Runs from d:\fxmatrix directory.

---

## EA FILE STRUCTURE

All files in d:\fxmatrix\ea\ (and mirrored to VPS Experts folder):

- **FXMatrix.mq5** — main EA, OnInit/OnTick/OnTradeTransaction
- **LayerStruct.mqh** — canonical Layer struct, enums, InitLayer()
- **Globals.mqh** — inputs, globals, InitGlobals()
- **MathEngine.mqh** — signal computation, inversion functions
- **ExecutionEngine.mqh** — entry/exit fill handlers, CloseBy intercept
- **CarryEngine.mqh** — daily carry recalculation at 17:00

---

## LAYER STRUCT KEY FIELDS

```mql5
// Immutable after Layer 0 fill — inherited by Layer 1+
double EU_mid_12bars_ago_at_entry  // EURUSD 1h-prior at signal (pod anchor)
double GB_mid_12bars_ago_at_entry  // GBPUSD 1h-prior at signal (pod anchor)
double r_EU_at_entry               // Fixed leg — INHERITED from Layer 0
double r_GB_at_entry               // Fixed leg — INHERITED from Layer 0
int    strongest_at_entry          // INHERITED from Layer 0
int    weakest_at_entry            // INHERITED from Layer 0

// Per-layer (set at each layer's fill time)
double entry_price                 // Actual fill price
double entry_spread_raw            // Matrix spread at fill using Layer 0 anchors
double entry_spread_adjusted       // Carry-adjusted spread (updated by CarryEngine)
double entry_price_eurusd_1h       // EURUSD 1h-prior at fill (carry reference)
double entry_price_gbpusd_1h       // GBPUSD 1h-prior at fill (carry reference)
double entry_price_eurusd          // Live EURUSD spot at fill
double entry_price_gbpusd          // Live GBPUSD spot at fill

// Exit tracking
double exit_spread_target          // entry_spread_adjusted × (1 - ExitFraction)
double exit_target                 // Inverted price corresponding to exit_spread_target
ulong  position_ticket             // MT5 position ID (hedging mode)
ulong  exit_tickets[]              // Dynamic array of pending exit order tickets
```

---

## MT5 HEDGING MODE — KEY CONSTRAINT

**CRITICAL:** In MT5 hedging mode, `request.position` is IGNORED on 
`TRADE_ACTION_PENDING`. Pending limit exit orders always open NEW opposing 
positions (DEAL_ENTRY_IN), not close existing ones.

**Solution (Gemini-approved Option C — CloseBy):**
1. Place passive limit exit order as normal
2. When it fills → new opposing position opens (DEAL_ENTRY_IN)
3. OnTradeTransaction intercept: check if fill ticket is in exit_tickets[]
4. If yes → route to HandleExitFill() with hedge_position_ticket
5. HandleExitFill() fires TRADE_ACTION_CLOSE_BY to merge positions

The DEAL_ENTRY_IN intercept was the critical fix that enabled CloseBy.

---

## BACKTEST PROGRESSION

All runs: EURGBP M5, 2026.03.07-2026.06.07, $10k, 1:30, Every tick

| Run | Key Fix | Net P&L | Profit Factor | Key Finding |
|-----|---------|---------|---------------|-------------|
| 1 | Baseline 0.0008 | -$4.59 | 0.63 | All long — signal routing ok |
| 2 | Exit direction (is_exit param) | -$28.07 | 0.00 | All short — threshold too high |
| 3 | CloseBy patch | -$19.80 | 0.25 | CloseBy wrong path — exits open shorts |
| 4 | Exit fill intercept | +$5.45 | 1.62 | First profit — CloseBy fires |
| 5 | Layer 0 inheritance | +$78.40 | 12.88 | All 5 layers exiting correctly |
| 6 | Per-layer spread recomputation | +$76.45 | 12.58 | Similar — instrument/direction bug found |

Theoretical P&L Run 6: +$137.26. Actual: +$78.40. Gap ~$59 = swap drag.

---

## LOCKED ADR RULINGS (do not revisit)

**MathEngine.mqh:**
- is_exit parameter in InvertSpreadToPrice() — direction flips for exit orders
- Half-spread applied AFTER direction flip based on FINAL direction
- T sign: do NOT negate for exits — Gemini proved the sign is correct

**ExecutionEngine.mqh:**
- Layer 0: reads live globals for all anchor/routing fields
- Layer 1+: inherits anchors, routing, fixed legs from g_inventory[0]
- Layer 1+: entry_spread_raw RECOMPUTED at fill using Layer 0 anchors + live mids
- Layer 1+: carry references (_1h fields) — PENDING Gemini ruling (see below)
- instrument/direction: MUST use L.strongest_at_entry/L.weakest_at_entry (THIS IS THE CURRENT PATCH)
- CloseBy intercept: DEAL_ENTRY_IN fills checked against exit_tickets[] before routing
- HandleExitFill: fires TRADE_ACTION_CLOSE_BY with hedge_position_ticket

**CarryEngine.mqh:**
- Runs daily at CarryRecalcTime=17:00
- Updates exit_spread_adjusted with forward price drift
- Calls OrderModify on exit_tickets[] — must check if order still pending before modifying

---

## PENDING ITEMS — IMMEDIATE PRIORITY

### 1. CURSOR PATCH IN PROGRESS
File: d:\fxmatrix\prompts\cursor_patch_instrument_direction.md

THREE changes to ExecutionEngine.mqh:
- Change 1: L.instrument uses L.strongest_at_entry/L.weakest_at_entry (not g_strongest/g_weakest)
- Change 2: L.direction uses L.strongest_at_entry/L.weakest_at_entry (not g_strongest/g_weakest)
- Change 3: Layer 0 entry_spread_raw recomputed at fill time (not g_entry_spread)
  Uses same matrix solve as Layer 1+ already does
  Dynamic routing: scores_l0[L.weakest_at_entry] - scores_l0[L.strongest_at_entry]

Self-review has 7 checks. Wait for Cursor output before proceeding.

### 2. GEMINI RULING PENDING
File: d:\fxmatrix\prompts\gemini_carry_1h_prior_ruling.md

Question: Should entry_price_eurusd_1h / entry_price_gbpusd_1h for Layer 1+
use Layer 0's anchor (Option A) or live g_EU_mid_12bars_ago (Option B)?

Our position: Option A (inherit Layer 0 anchor)

Expected Gemini response: short ruling, one paragraph.
Once received, draft a small follow-up Cursor patch for those two fields.

### 3. AFTER ABOVE FIXES — Run backtest 8
Expected improvement: instrument/direction bug eliminated → all layers compute
correct instrument exit prices → exits fire reliably at fill time for all 6
routing cases → fewer positions held to end-of-test → swap drag reduced further

### 4. PENDING KNOWN ISSUES (lower priority)
- MaxLayers overflow: EA places multiple entry orders simultaneously, overflow
  fills have no exit management. Fix: cancel pending entry orders when MaxLayers reached.
- LAYER_EXIT gross_pnl=0.00 (logging only — CloseBy P&L not captured)
- CarryEngine stale ticket check: should verify OrderSelect() before OrderModify()
- instrument/direction fields in LAYER_EXIT logging (reads live globals — cosmetic)

---

## GIT HISTORY (key commits this session)

- ac358ed: SYMBOL_FREEZE_LEVEL fix
- 4a5f4f0: is_exit direction fix (MathEngine)
- de9ae47: CloseBy position merge (LayerStruct + ExecutionEngine)
- 9c1b97d: Exit fill intercept — DEAL_ENTRY_IN routing (ExecutionEngine)
- e168a1a: Layer 0 inheritance (ExecutionEngine)
- 6d43500: Per-layer spread recomputation with dynamic routing (ExecutionEngine)
- Current HEAD: 6d43500 — instrument/direction patch NOT YET COMMITTED

---

## LOG FILES

All in d:\fxmatrix\logs\ (local) and C:\fxmatrix\logs\ (VPS):
- 20260608_backtest.log — Run 1
- 20260608_backtest_002.log — Run 2
- 20260608_backtest_fixed.log — Run 3
- 20260608_backtest_closeby.log — Run 4
- 20260608_backtest_intercept.log — Run 5
- 20260608_backtest_inheritance.log — Run 6
- 20260608_backtest_perlayer.log — Run 7 (current)

MT5 tester log location on VPS:
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Tester\81A933A9AFC5DE3C23B15CAB19C63850\Agent-127.0.0.1-3000\logs\20260608.log

After each run: copy to C:\fxmatrix\logs\<name>.log, then WinSCP to local.

---

## PROMPT FILES

All in d:\fxmatrix\prompts\:
- cursor_prompt_1_layerstruct.md ✅
- cursor_prompt_2_signal_inversion.md ✅
- cursor_prompt_3_execution_engine.md ✅
- cursor_prompt_4_carry_orchestration.md ✅
- cursor_patch_exit_direction.md ✅ (is_exit param)
- cursor_patch_closeby.md ✅ (CloseBy + position_ticket)
- cursor_patch_exit_intercept.md ✅ (DEAL_ENTRY_IN routing)
- cursor_patch_layer_inheritance.md ✅ (Layer 0 inheritance)
- cursor_patch_per_layer_spread.md ✅ (per-layer spread recompute)
- cursor_patch_instrument_direction.md ⬅ SENT TO CURSOR — AWAITING RESPONSE
- gemini_carry_1h_prior_ruling.md ⬅ SENT TO GEMINI — AWAITING RESPONSE

---

## WHAT TO SAY TO THE NEW CHAT

"I'm continuing development of FXMatrix EA. I've just sent two prompts:

1. cursor_patch_instrument_direction.md to Cursor — fixing L.instrument 
   and L.direction reading stale globals, and Layer 0 entry_spread_raw 
   using g_entry_spread. Awaiting self-review output.

2. gemini_carry_1h_prior_ruling.md to Gemini — asking whether 
   entry_price_eurusd_1h for Layer 1+ should use Layer 0 anchor or 
   live global. Awaiting ruling.

Please read the handoff document and pick up from here."

---

## KEY PEOPLE / CONTACTS

- Khalid Khan — Toronto, sell-side fixed income + rates, runs FXMatrix
- Lieum — BJJ training partner, prop trading
- Ryan Wagner, Parashar Soman — institutional contacts (OneTick tick data)

---

## CONSTRAINTS (NEVER VIOLATE)

- No scipy / QuantLib / ta-lib
- No startup DDL
- No git add -A
- PowerShell: use ; not && for chaining
- psycopg2 NUMERIC requires _norm_row() conversion (CandleLab, not fxmatrix)
- Poll Log Supremacy (CandleLab, not fxmatrix)
- WATCHLIST never crosses into live pipeline (CandleLab)
- Cursor edits LOCAL files only — never VPS directly
- Gemini rules architecture — never skip to Cursor on ambiguous questions
- DeepSeek audits code — never ask for architectural decisions
- No clarifying questions before starting — build first, note assumptions

