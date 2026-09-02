Here's the Claude Code prompt:

---

You are performing a formal execution audit of the FXMatrix Expert Advisor — a native MQL5 algorithmic trading system running on FTMO funded demo accounts. The codebase is at `d:\fxmatrix\ea\`.

**Read all source files in that directory before doing anything else.** There are 8 files: `FXMatrix.mq5`, `ExecutionEngine.mqh`, `MathEngine.mqh`, `Globals.mqh`, `LayerStruct.mqh`, `StateEngine.mqh`, `CarryEngine.mqh`, `TelemetryEngine.mqh`.

Your task is a four-gate execution audit. Produce a written audit report covering all four gates.

---

**Gate 1 — Entry Routing & Passivity**

Trace the complete path from signal computation to a physical limit order resting on the broker's book. Starting from `RunSignalOnBarClose()` through `InvertSpreadToPrice()` to `PlaceEntryLimit()` and `PlaceNextEntryLimit()`.

Audit questions:
- Are the `bid_strongest/bid_weakest` and `offer_strongest/offer_weakest` slot index mappings in the MM flat quoting loop mathematically consistent with the routing convention in `InvertSpreadToPrice()`?
- If `PlaceEntryLimit()` or `PlaceNextEntryLimit()` fails (freeze level, passivity, OrderSend rejection), is there a retry mechanism or does the signal silently die?
- Is there any path where `strongest == weakest` can reach `InvertSpreadToPrice()`?

---

**Gate 2 — Fill Intercept (OnTradeTransaction → HandleEntryFill)**

Trace the path from broker fill confirmation to the virtual Layer struct being populated.

Audit questions:
- Does `HandleEntryFill` reliably capture the physical position ticket via `DEAL_POSITION_ID`?
- Is `entry_spread_raw` anchored correctly at fill time using the 12-bar anchor, or can it drift?
- Does the LDAK lot sizing correctly decrement `remaining_entry_volume`?
- Is there any scenario where the same fill could be processed twice?

---

**Gate 3 — Continuous State Reconciliation (OnTick)**

Audit the safety nets that protect against broker async delays.

Audit questions:
- Review `AuditExitLimits()` — are the three conditions (entry filled, exit missing, exit volume armed) sufficient to guarantee no false positives?
- Is there an equivalent audit for add_next limits? If a pod is active and `g_add_next[slot] == 0` but the sleep gate has expired, does OnTick reliably re-arm the add_next limit?
- What happens if the MT5 terminal loses broker connection for 5+ minutes during an active grid? Does state recover correctly on reconnect?

---

**Gate 4 — Unwind & Reset (HandleExitFill + CloseBy)**

Trace the path from exit limit fill to return to flat quoting.

Audit questions:
- When an exit limit fills, does `HandleExitFill` correctly decrement `remaining_exit_volume` and remove the layer from `g_inventory_N`?
- Does the CloseBy queue process the LIFO offset cleanly with no stranded positions?
- When the final layer closes, are all orphaned add_next limits cancelled before MM resumes two-way quoting?
- Is there any scenario where `g_inventory_N` has zero layers but a stale `g_pending_bid[slot]` or `g_pending_offer[slot]` ticket remains?

---

**Output format:**

For each gate produce:
1. A step-by-step trace of the execution thread with exact function names and line numbers
2. A list of findings — PASS / WARNING / FATAL per audit point
3. Any recommended fixes for WARNING or FATAL findings

Close with an overall verdict and prioritised fix list.

---