# Gemini Ruling Request — Wrong exit symbol on live: GBPUSD positions 
# getting EURUSD exit orders

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** Critical live bug — exit orders placed on wrong instrument

**Note: New chat session. Please re-establish context from prior 
rulings if needed before ruling.**

---

## Background

FXMatrix EA is running live on FTMO demo account 1513622691.
Current HEAD: 68537c1. The EA has been confirmed deployed and 
recompiled on VPS (149.28.123.38).

---

## What happened

A GBPUSD buy pod opened across multiple layers on 2026.06.08:
- Layer 0: buy GBPUSD 1.33222 @ 04:30 (ticket 466512635)
- Layer 1: buy GBPUSD 1.33250 @ 06:02 (ticket 466553280)
- Layer 2: buy GBPUSD 1.33214 @ 09:35 (ticket 466548868)
- Layer 3: buy GBPUSD 1.33214 @ 09:35 (ticket 466550640)

When Layer 1 filled at 06:02, the EA placed a **EURUSD sell limit**
as its exit order instead of a GBPUSD sell limit:
06:02:51 — deal buy 0.01 GBPUSD at 1.33250 (Layer 1 fill)
06:02:51 — sell limit 0.01 EURUSD at 1.15260 placed (wrong instrument)
06:02:51 — buy limit 0.01 GBPUSD at 1.33006 placed (next layer — correct)

When Layer 2 and Layer 3 filled at 09:35, same thing:
06:35:46 — deal buy 0.01 GBPUSD at 1.33214 (Layer 2 fill)
06:35:46 — sell limit 0.01 EURUSD at 1.15261 placed (wrong instrument)
06:35:46 — deal buy 0.01 GBPUSD at 1.33214 (Layer 3 fill)
06:35:46 — sell limit 0.01 EURUSD at 1.15261 placed (wrong instrument)

When those EURUSD sell limits filled at 10:17, the CloseBy intercept
tried to close the GBPUSD buy positions using EURUSD sell positions:
failed close position #466553280 buy 0.01 GBPUSD
by position #466694078 [Invalid request]
failed close position #466548868 buy 0.01 GBPUSD
by position #466723150 [Invalid request]
failed close position #466550640 buy 0.01 GBPUSD
by position #466723159 [Invalid request]

CloseBy correctly rejected cross-instrument merges. Result: 3 GBPUSD
buy positions open with no exit management, and 3 orphaned EURUSD
sell positions open as unintended directional trades.

---

## Root cause hypothesis

The exit_symbol derivation in HandleEntryFill() reads L.instrument:

```mql5
string exit_symbol = (g_inventory[layer_idx].instrument == INSTRUMENT_EURUSD)
                     ? "EURUSD"
                     : (g_inventory[layer_idx].instrument == INSTRUMENT_GBPUSD)
                       ? "GBPUSD" : "EURGBP";
```

L.instrument is set from L.strongest_at_entry / L.weakest_at_entry
earlier in the same function. This was confirmed working in backtests
(Run 10: +$76.71, PF 12.52, all exits correct).

However the live log shows the EA was reloaded multiple times between
Layer 0 fill (04:30) and Layer 1 fill (06:02):
02:07 — EA removed and reloaded
02:39 — EA removed and reloaded
03:25 — EA removed and reloaded
03:46 — EA removed and reloaded
04:16 — EA removed and reloaded
04:52 — EA removed and reloaded
05:34 — EA removed and reloaded
05:47 — EA removed and reloaded

**Our hypothesis: g_inventory[] state is not persisted across EA 
reloads.** When the EA reloads, g_inventory[] is re-initialised empty.
Layer 0's position (ticket 466512635) is still open on the broker,
but the EA has no record of it in g_inventory[]. 

When Layer 1's pending limit fills at 06:02, HandleEntryFill() finds
no matching entry_ticket in g_inventory[] (layer_idx == -1), and
enters the new layer branch. But at this point g_inventory is empty
(ArraySize == 0), so the code takes the **Layer 0 branch** and reads
live globals for routing — including the current signal which may
have rotated to a EURUSD routing case. L.instrument is therefore set
to EURUSD instead of GBPUSD.

The Layer 1 fill is being treated as a fresh Layer 0, with whatever
signal happens to be active at reload time — not the original GBPUSD
pod signal.

---

## The architectural gap

There is no startup reconciliation for g_inventory[]. On OnInit, the
EA does not scan existing open positions and pending orders to 
reconstruct g_inventory[] state. This was acceptable in backtesting
(no reloads mid-run) but is fatal in live trading where MT5 reloads
the EA frequently (network reconnects, terminal restarts, etc).

---

## Ruling requested

1. Confirm or correct our root cause hypothesis.

2. Should OnInit implement a startup reconciliation that rebuilds
   g_inventory[] from existing MT5 positions and pending orders?
   If yes, what is the minimum viable reconciliation for V1 —
   specifically, what fields can be reliably reconstructed from
   MT5 position/order data, and what fields cannot (and must
   therefore be approximated or defaulted)?

3. Are there other architectural gaps exposed by this failure
   that should be addressed before the next live session?
