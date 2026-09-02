# Gemini Ruling Request — Two live/tester issues: CloseBy 10013 on 
# market hedge exits + stale pending entry tickets

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** Two issues found in Run 11 — may be linked

**Note: New chat session. Please re-establish full context before ruling.**

---

## Context

Run 11 backtest (StateEngine persistence patch, HEAD 5f82c62) produced
+$65.97 PF 9.04 vs Run 10's +$76.71 PF 12.52. Log analysis identified
two issues.

---

## Issue 1 — CloseBy retcode=10013 on market hedge exits

### What happens

When the Marketable Reversion Exception fires, it places a market
hedge (TRADE_ACTION_DEAL, no req.position) to open an opposing
position, appends the ticket to exit_tickets[], and waits for
OnTradeTransaction to intercept the DEAL_ENTRY_IN fill and route
to HandleExitFill() for CloseBy.

In Run 11, the market hedge places successfully but CloseBy fails:

```
INFO: Market hedge placed. ticket=46. Awaiting CloseBy intercept.
ERROR: CloseBy failed. position=28 position_by=46 retcode=10013
```

This happens for all 4 marketable reversion cases in the run.

### Key observation

In Run 10 (identical code minus StateEngine), CloseBy worked
perfectly for passive limit exits. The difference is the position
type: passive limit exits open the opposing position via a pending
order that fills naturally. Market hedge exits open the opposing
position via TRADE_ACTION_DEAL. The MT5 strategy tester may treat
these two position types differently for CloseBy eligibility.

### Question 1

Is TRADE_ACTION_CLOSE_BY incompatible with positions opened via
TRADE_ACTION_DEAL in the MT5 strategy tester? If so, what is the
correct mechanism to close a market-opened hedge position in both
tester and live environments?

---

## Issue 2 — Stale pending entry tickets filling after pod closes

### What happens

When a pod closes (all layers exit), the EA does not cancel the
remaining pending entry orders for that pod. These orders stay live
on the broker. When price eventually revisits those levels — days
or weeks later — they fill. HandleEntryFill() receives the fill,
finds no matching entry_ticket in g_inventory[] (layer_idx == -1),
and checks MaxLayers:

```
WARNING: Entry fill received but MaxLayers reached. ticket=13
WARNING: Entry fill received but MaxLayers reached. ticket=45
```

If MaxLayers is not reached, the fill would be treated as a fresh
Layer 0 with live globals — same state contamination bug we fixed
with StateEngine, now entering through the back door.

If MaxLayers IS reached, the position opens on the broker with no
inventory record — a guaranteed orphan that halts the EA on next
reload via CheckForOrphans().

### Question 2

Should the EA cancel all pending entry orders for a pod when the
last layer exits? Specifically: when ArraySize(g_inventory) reaches
0 after a layer removal in HandleExitFill(), should the EA loop
through all pending orders on _Symbol and cancel them?

---

## Possible link between issues

If Issue 2 creates an orphan position and the EA halts, marketable
reversion positions that needed CloseBy are left unmanaged. The two
issues compound each other in a live environment.

**Rulings requested on both issues.**
