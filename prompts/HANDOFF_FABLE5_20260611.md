# FXMatrix EA — Fable 5 Handoff
# Date: 2026-06-11
# Status: Active development, live on FTMO demo
# Current HEAD: 0bba98c
# Previous handoff: FX_matrix_handoff_20260607.md

---

## WHAT THIS IS

FXMatrix is a native MQL5 Expert Advisor implementing a
3-currency FX mean-reversion strategy on FTMO VPS.
NOT a Python/Railway system. Pure MQL5 on MetaTrader 5.

Repo: theonlykk/fxmatrix
Local: d:\fxmatrix
VPS: 149.28.123.38 (Vultr, Windows Server 2022)
MT5: account 1513622691, FTMO-Demo, Hedging, $10k Swing 2-Step
Current HEAD: 0bba98c

---

## THE STRATEGY

3-currency pod: EUR=0, GBP=1, USD=2

Signal decomposition:
  r_EU = log(EURUSD_now / EURUSD_12bars_ago)
  r_GB = log(GBPUSD_now / GBPUSD_12bars_ago)
  usd  = -(r_EU + r_GB) / 3
  eur  =   r_EU + usd
  gbp  =   r_GB + usd
  spread = scores[weakest] - scores[strongest]  ← always negative

Signal fires when |spread| > BaseThreshold (0.0004)
Exit: passive limit at entry_spread × (1 - ExitFraction)
ExitFraction = 0.70
MaxLayers = 20
EA_MAGIC = 20260608

---

## MULTI-AGENT PIPELINE

DeepSeek (Red Team) → Claude (Blue Team) → Gemini (Architect)
→ Cursor (Implementation)

Pipeline rules: d:\fxmatrix\prompts\ARCHITECT.md

---

## INFRASTRUCTURE

VPS:
- IP: 149.28.123.38
- Experts: C:\Users\Administrator\AppData\Roaming\MetaQuotes\
           Terminal\81A933A9AFC5DE3C23B15CAB19C63850\
           MQL5\Experts\fxmatrix\
- Deploy: C:\fxmatrix\deploy.ps1
- Logs: C:\fxmatrix\logs\

Local:
- d:\fxmatrix\ea\ — all EA source files
- d:\fxmatrix\prompts\ — all Gemini/Cursor prompt files
- d:\fxmatrix\logs\ — local log copies
- d:\fxmatrix\notebooks\fxmatrix_log_analysis.ipynb
- d:\fxmatrix\venv — Python venv
- d:\candlelab\venv — CandleLab venv (for r1_audit.py)

Tester: No delays mode (Random delay = non-reproducible)
Encoding: utf-16-le, re.split with \s+

---

## EA FILE STRUCTURE

- FXMatrix.mq5 — OnInit/OnTick, signal flow, helpers
- LayerStruct.mqh — Layer struct, enums (DIRECTION_BUY=1,
                    DIRECTION_SELL=-1)
- Globals.mqh — all inputs, globals, InitGlobals()
- MathEngine.mqh — signal, IsPassive, InvertSpreadToPrice,
                   ComputeEntry/ExitPrice, score globals
- ExecutionEngine.mqh — fills, ComputeNextLayerPrice,
                        HandleEntryFill, HandleExitFill
- CarryEngine.mqh — daily carry at 17:00
- StateEngine.mqh — JSON persistence

---

## CURRENT BACKTEST BASELINE (No delays)

All runs: EURGBP M5, 2026.03.07–2026.06.07, $10k, 1:30

| Run | Config | Net P&L | PF | Trades | Win% | DD |
|-----|--------|---------|-----|--------|------|----|
| 39 | Linear, No grad, EURGBP only | +$122 | 2.71 | 334 | 92.81% | 0.75% |
| 47 | All patches, 3-symbol attempt | -$12 | 0.68 | 71 | 97.18% | 0.37% |

Run 39 is the clean baseline (EURGBP only, linear threshold).

---

## PATCH HISTORY (this session)

| Commit | Patch | Description |
|--------|-------|-------------|
| 6b6cf60 | 4 | MathAbs(T) sign fix for EURUSD/GBPUSD passivity |
| aa9296b | 5 | Pending entry invalidation on signal change |
| 9c3cc53 | 5a | Remove _Symbol filter from CancelAllPendingEntries |
| c85117c | 6 | Value-based hysteresis rotation guard |
| 0bba98c | 7 | Entry price formula fix (T directly, not r_GB/r_EU) |

---

## THE IMMEDIATE PROBLEM (Fable 5 Priority 1)

Run 47 log shows:
  INFO: Freeze level skip — symbol=EURUSD distance=-2.17932
  INFO: PlaceNextEntryLimit skipped — add_next=3.35863

add_next=3.35863 on EURUSD is physically impossible.
Current EURUSD ~1.179. Something is producing a value
~3.36 for the next layer entry price.

ComputeNextLayerPrice() in ExecutionEngine.mqh already
uses negated thresholds (-current_threshold, -next_threshold)
from Patch 3.1. Patch 7 changed InvertSpreadToPrice() to
use T directly (not r_GB_fixed ± MathAbs(T)).

Trace the exact computation:
- deal_price ≈ 1.17932
- next_layer_idx = 1 (after Layer 0 appended)
- strongest=2, weakest=0 (EURUSD BUY)
- ComputeLayerThreshold(0) = 0.0004
- ComputeLayerThreshold(1) = 0.0006
- Negated: -0.0004 and -0.0006 passed as T
- Patch 7 EURUSD BUY: r_EU_target = T = -0.0006
- price = g_EU_mid_12bars_ago * MathExp(-0.0006) ≈ 1.1783

That should give add_next ≈ 1.1789. Not 3.35.
Something in the call chain is wrong.

Hypothesis: g_EU_mid_12bars_ago is not ~1.179 at EURUSD
fill time. It may be the EURGBP anchor or an uninitialized
value. Check what globals are populated when a EURUSD
fill occurs during an EURGBP-routed signal.

---

## THE -$35.80 LOSS

Run 47 has one catastrophic loss of -$35.80 that wiped
out $13.34 of consecutive wins. This occurred around
April 15-16 based on the graph. Needs log analysis to
identify root cause — likely a pod that built multiple
layers and couldn't exit, or a CloseBy failure.

---

## LOCKED ARCHITECTURAL RULINGS

MathEngine.mqh:
- Passivity guard returns -1.0 — NEVER remove
- InvertSpreadToPrice T convention: spread is always
  negative (scores[weakest] - scores[strongest])
- EURUSD BUY:  r_EU_target = T (Patch 7)
- EURUSD SELL: r_EU_target = -T (Patch 7)
- GBPUSD BUY:  r_GB_target = T (Patch 7)
- GBPUSD SELL: r_GB_target = -T (Patch 7)
- EURGBP: MathExp(-T) on anchor ratio (unchanged)

ExecutionEngine.mqh:
- Physical ledger is ground truth at fill time
- exit_symbol always from L.instrument
- All exits route through CloseBy
- ComputeNextLayerPrice uses -threshold (negated)
- layer_idx captured BEFORE ArrayResize

CarryEngine.mqh:
- scores_fwd[weakest] - scores_fwd[strongest]
- retcode=10025 treated as success
- SaveInventoryState() after loop

StateEngine.mqh:
- SaveInventoryState() at all 5 mutation points
- LoadInventoryState() + CheckForOrphans() in OnInit()

FXMatrix.mq5:
- Highlander Rule: one pending entry limit at a time
- g_signal_active required in nudge block guard
- Patch 5: pending entry invalidation on signal change
- Patch 6: value-based hysteresis rotation guard
- GetImpliedIndices() maps symbol/direction to indices
- g_score_eur/gbp/usd populated from RunSignalOnBarClose

---

## PENDING ITEMS FOR FABLE 5

Priority 1 — Fix add_next=3.35 on EURUSD/GBPUSD
Priority 2 — Fix -$35.80 catastrophic loss
Priority 3 — Full architectural review
Priority 4 — Radar removal (GetBestRadarTarget deleted)
Priority 5 — Multi-pod architecture design
Priority 6 — Risk sizing (BaseLotSize for $500 target)
Priority 7 — Batch ADR generation

---

## OPEN DEEPSEEK FINDINGS (not yet fixed)

Critical:
- Pending entry invalidation ← FIXED in Patch 5

High:
- StateEngine: validate loaded layers vs live positions
- StateEngine: persist CloseBy queue

Medium:
- Radar model mismatch ← ABANDONED per DeepSeek ruling

Low:
- #property strict warning ← known, harmless
- ProcessCloseByQueue: verify both positions exist
- NudgePips assumes 5-digit broker

---

## KNOWN ISSUES

- LAYER_EXIT gross_pnl=0.00 — CloseBy P&L not captured
- CarryEngine stale ticket: OrderSelect not verified
- CloseBy retcode=10013 in tester only
- Symbols counter in tester counts loaded not traded
- add_next=3.35 on EURUSD — root cause unknown
- -$35.80 single loss — root cause unknown
- EURUSD/GBPUSD still not contributing meaningfully
  despite Patches 4-8

---

## PARAMETERS (current live + backtest)

BaseThreshold = 0.0004
ThresholdStep = 0.0002
ExitFraction = 0.70
ExitFractionStep = 0.0 (graduation disabled)
ExitFractionMin = 0.40
MaxLayers = 20
BaseLotSize = 0.01
RotationThreshold = 0.0 (hysteresis disabled for testing)
Delays = No delays (tester)