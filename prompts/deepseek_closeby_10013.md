# DeepSeek Audit — CloseBy retcode=10013 on market hedge positions

## Role
You are the Red Team auditor for FXMatrix, a native MQL5 EA running
on FTMO MT5 in hedging mode. Your job is to identify the exact
mechanical cause of retcode=10013 on TRADE_ACTION_CLOSE_BY when
closing market-hedge-opened positions in the MT5 strategy tester,
and propose a fix.

## Context

FXMatrix implements a Marketable Reversion Exception: when an exit
target is already through the market at layer fill time, the EA
places a market hedge (TRADE_ACTION_DEAL, no req.position) to open
an opposing position. OnTradeTransaction intercepts the DEAL_ENTRY_IN
fill and routes to HandleExitFill() which fires TRADE_ACTION_CLOSE_BY
to merge the two positions.

An async queue (g_closeby_queue[]) was implemented to handle ledger
desync. When PositionSelectByTicket() fails or CloseBy returns 10013,
the task is queued and retried on every OnTick() call for up to 10
ticks.

## The problem

In the MT5 strategy tester, TRADE_ACTION_CLOSE_BY returns retcode=10013
on ALL 10 retry attempts — not just the first. The positions are never
merged. The EA halts after 10 retries with SEV-1 ERROR.

```
INFO: CloseBy retcode=10013. Queued for retry. position=2 position_by=3
WARNING: CloseBy queue retry 1/10 failed. retcode=10013 position=2 position_by=3
WARNING: CloseBy queue retry 2/10 failed. retcode=10013 position=2 position_by=3
... (all 10 retries fail)
SEV-1 ERROR: CloseBy queue task failed after 10 retries. halting EA.
```

For passive limit exits (position opened via pending order fill),
TRADE_ACTION_CLOSE_BY works correctly every time.

The only difference: the hedge position in the failing case was opened
via TRADE_ACTION_DEAL (market order), not via a pending limit fill.

## retcode=10013 meaning

In MT5, retcode=10013 is TRADE_RETCODE_INVALID — the request itself
is structurally invalid, not just a timing issue. This suggests the
tester is rejecting the CloseBy request on a fundamental basis, not
because of ledger timing.

## Hypothesis to evaluate

1. Does TRADE_ACTION_CLOSE_BY require both positions to have been
   opened via pending orders in the MT5 strategy tester? i.e. is
   CloseBy incompatible with market-order-opened positions in the
   tester specifically?

2. Is there a missing field in the CloseByTask request (e.g.
   req.symbol, req.volume, req.magic) that causes the tester to
   reject it as structurally invalid?

3. Is the tester rejecting CloseBy because the two positions are
   on different instruments (EURUSD original vs EURUSD hedge) but
   the request doesn't specify the symbol?

## What we need

1. Identify the exact cause of retcode=10013 for market-hedge
   CloseBy in the tester
2. Propose the minimal fix — either:
   a. Add missing fields to the CloseBy request
   b. Use an alternative close mechanism for market-hedge positions
      (e.g. TRADE_ACTION_DEAL with req.position targeting the hedge,
      or a direct market close on the original position)
3. Confirm whether the fix applies only to the tester or also
   affects live behaviour

Do not propose architectural changes. This is a targeted mechanical
fix only.
