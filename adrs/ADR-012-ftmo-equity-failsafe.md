# ADR-012 — FTMO Equity Failsafe

**Date:** 2026-06-14
**Status:** IMPLEMENTED
**Authors:** Claude (Lead Engineer), Gemini (Staff Architect)

## Context
Phase 5 stress testing revealed that the existing Tier 1 and Tier 2 CBs
monitor net floating P&L but FTMO enforces two separate equity floors:
1. Absolute Max Loss (10%): static floor from initial balance, never moves
2. Max Daily Loss (5%): resets at midnight CET from that day's opening balance

During Brexit 2016, net floating P&L never breached the 3% Tier 2 CB
threshold because positions were cycling, but peak equity drawdown reached
10.76% — which would terminate an FTMO account at the 10% absolute limit.

## Fix: FTMO Absolute & Daily Floor Circuit Breaker
On every CheckCircuitBreakers() call, compute both FTMO floors and fire
CloseAllPositions() + halt if current equity breaches either floor.

State is broker-held (balance), not EA-held. VPS restart safe.

## New Parameters
- FTMO_Initial_Balance: starting account balance (matches FTMO account)
- FTMO_Max_Loss_Pct: absolute loss buffer (default 0.09 = 9%, 1% below limit)
- FTMO_Daily_Loss_Pct: daily loss buffer (default 0.04 = 4%, 1% below limit)

## New State Globals
- g_daily_start_balance: balance at midnight CET, updated on day change
- g_current_day: tracks current day to detect midnight rollover

## Interaction with Existing CBs
Tier 1 (per-pod 3%): unchanged
Tier 2 (global 3% net floating): unchanged
Tier 3 (FTMO floors): NEW — catches gap events and sustained equity erosion

## Related
- ADR-009: Serial mode diagnostic
- ADR-011: LDAK volatility gate
- Phase 5: Stress test suite (Brexit equity DD = 10.76% identified the gap)
