---

**To: Claude (Opus 4.7 / Red Team Lead)**
**From: Khalid & Gemini (Blue Team / Architecture)**
**Re: V3 Matrix — Hostile Environment Teardown (Red Team Audit)**

Claude, the Blue Team has completed a structural hardening of the V3 mean-reversion matrix. The codebase is at `d:\fxmatrix\ea\`. Read all files fresh from disk before beginning. The following patches have already been applied — audit the current state, not a pre-fix version:

- `5bcd31a` — F1 nuclear failsafe + W4 LDAK lot sizing
- `1a79a45` — W1 exit ticket liveness + W2 add_next stale validation + W3 structural resume routing
- `9041930` — O1 layer deserializer fix + O2 carry sign guard

Your objective is to break it.

You are conducting a Hostile Environment Red Team Audit. Do not look for syntax errors or basic logic bugs. Hunt for catastrophic state desyncs, memory leaks, and phantom margin drains under severe stress.

---

**Threat Scenario 1: The Asynchronous Meat Grinder**

The broker's prime-of-prime is failing. Execution is chaotic.

- `OnTradeTransaction` events are arriving out of chronological order.
- A `MARKET_MAKER` limit order receives two separate `DEAL_ENTRY_IN` events for the same order ticket — the MT5 mechanism for partial fills. Assume `BaseLotSize = 0.10` for this scenario (partial fills are not possible at the current 0.01 micro-lot default; scale up to make this realistic).
- The first event fills 0.03 lots, the second fills the remaining 0.07 lots.

**Your Audit:** Does `HandleEntryFill` cleanly process both partial fill events without corrupting `remaining_entry_volume` or duplicating the `Layer` instantiation? Can out-of-order execution messages bypass the `AuditExitLimits` reconciliation loop? Is there any path where two `HandleEntryFill` calls for the same order ticket result in two separate Layer structs being appended to `g_inventory_X`?

---

**Threat Scenario 2: The Blackout**

During a massive liquidity shock (e.g., NFP print), the MT5 terminal loses connection to the broker for exactly 7 minutes.

- During the blackout, price spikes through three grid layers and violently reverses.
- Multiple pending entry limits and resting exit limits are filled on the broker side while the EA is disconnected.
- The connection is restored and the EA is hit with a flood of synthetic `OnTradeTransaction` replays in chronological order.

**Your Audit:** Does `LoadInventoryState` and the subsequent tick loop flawlessly reconstruct the physical reality of the matrix after the O1 deserializer fix? Can a position become stranded if its corresponding exit limit was filled during the blackout — specifically, does `HandleExitFill` correctly process replayed exit fills against the restored inventory? What happens if a replayed fill arrives for a layer that was also partially reconstructed from the JSON state file?

---

**Threat Scenario 3: The Swap Shock**

It is Wednesday at 17:00 broker server time (Triple Swap Rollover).

- The broker widens the swap spread asymmetrically by 400%, turning a mildly negative carry into a violently negative bleed.
- `RunCarryRecalculation()` fires at exactly 17:00.

**Your Audit:** Does `CarryEngine.mqh` recalculate `entry_spread_adjusted` aggressively enough to force the exit target toward safety? If `new_spread` approaches zero (triggering the O2 sign guard), does the guard correctly fire before `OrderModify` is called, or is there a window where `OrderModify` fires with an invalid price first? If the required `exit_price` changes drastically, does the engine successfully fire `OrderModify` to move the physical limit, or does it fail silently due to freeze level or stop level proximity?

---

**Directives:**

1. Do not suggest feature additions.
2. If you find a fatal flaw, provide the exact file, line number, and the complete chain of events that triggers the failure.
3. If the architecture safely survives a scenario, state clearly which existing safety nets catch the threat and how.
4. Report findings as PASS / WARNING / FATAL per scenario.

Execute the teardown.

---