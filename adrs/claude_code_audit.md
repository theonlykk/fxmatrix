 FXMatrix EA — Four-Gate Execution Audit

  Date: 2026-06-19 | Build: 1da31ec | Auditor: Claude Sonnet 4.6

  ---
  GATE 1 — Entry Routing & Passivity

  Execution Thread Trace

  1. RunSignalOnBarClose() (MathEngine.mqh:56) — copies 289 M5 closes for PairAC/PairBC, converts bid-close to mid, sets
  g_anchor[0/1] (12-bar-ago mids), g_r_signal[0/1], decomposes into g_scores[0/1/2] via zero-sum constraint, sets
  g_strongest/g_weakest.
  2. OnTick new-bar block (FXMatrix.mq5:130–177) — for each of 3 instrument slots, hardcoded structural bid/offer index
  pairs are assigned:
    - SLOT_AC: bid(2→0), offer(0→2) — BUY/SELL EURUSD
    - SLOT_BC: bid(2→1), offer(1→2) — BUY/SELL GBPUSD
    - SLOT_AB: bid(1→0), offer(0→1) — BUY/SELL EURGBP
    - bid_spread = inst_spread + QuoteSpread, offer_spread = inst_spread - QuoteSpread
  3. InvertSpreadToPrice() (MathEngine.mqh:256) — routes to physical symbol via (strongest, weakest) pair. Returns
  anchor * exp(±T) ± half-bid-ask-spread. Passivity guard (enforce_passivity=false in flat-quoting path).
  4. PlaceEntryLimit() (ExecutionEngine.mqh:24) — ADR-013 gap clamp, IsClearOfFreezeLevel(), IsPassive(), then
  OrderSend(PENDING, BaseLotSize, GTC). Returns ticket or 0.
  5. PlaceNextEntryLimit() (ExecutionEngine.mqh:149) — gap-aware passive clamp using live bid/ask, same freeze/passivity
  checks, places with magic = EA_MAGIC+1, writes g_add_next[inst].

  ---
  Findings

  G1-1 — Slot index / InvertSpreadToPrice consistency → PASS

  Every (strongest, weakest) pair passed from the flat-quoting loop lands in a valid branch of InvertSpreadToPrice and
  produces the correct trade direction. The hardcoded structural mapping is internally consistent:
  - bid(2,0) → InvertSpreadToPrice branch strongest==2 && weakest==0 → BUY PairAC ✓
  - offer(0,2) → strongest==0 && weakest==2 → SELL PairAC ✓
  - All six instrument-direction combinations verified.

  The bid_direction / offer_direction variables passed to PlaceEntryLimit match the direction InvertSpreadToPrice
  derives internally for all 6 cases. No mismatch possible.

  G1-2 — Failure retry → WARNING

  If PlaceEntryLimit returns 0 (freeze level / passivity / OrderSend rejection):
  - g_pending_bid[inst] is not updated (stays 0)
  - The deadband check next iteration: current_bid_price = GetPendingOrderPrice(0) returns −1 → deadband skipped → retry
  fires
  - Retry latency is one full M5 bar (up to 5 minutes) — signal does not silently die but is gated to bar close

  For PlaceNextEntryLimit failures, the OnTick re-arm block (FXMatrix.mq5:189) fires every tick when g_add_next[inst] ==
  0. Add-next recovery is effectively continuous; flat-quote recovery is bar-gated. The asymmetry is undocumented but
  not a correctness bug.

  G1-3 — strongest == weakest can reach InvertSpreadToPrice → WARNING (RESUME PATH)

  In the flat-quoting loop, structural hardcoding prevents this: bid(2,0) etc. can never collapse to equal indices. PASS
  for flat-quoting.

  In the resume-quoting block inside HandleExitFill (ExecutionEngine.mqh:855–864), score-dependent routing IS used:
  inst_strongest = (g_scores[0] > g_scores[2]) ? 0 : 2;
  inst_weakest   = (g_scores[0] < g_scores[2]) ? 0 : 2;
  If g_scores[0] == g_scores[2], both ternaries take the false branch → inst_strongest = inst_weakest = 2.
  InvertSpreadToPrice hits the else branch, prints ERROR, returns −1.0. bid_price < 0 → PlaceEntryLimit not called.
  Resume quotes are silently dropped — flat-quoting will resume on the next M5 bar close. Low-probability but a real
  failure mode.

  Fix: Replace score-conditional routing in the resume-quoting block with the same structural if/else already used in
  the flat-quoting loop. Four lines, directly mirrors FXMatrix.mq5:150–177.

  ---
  GATE 2 — Fill Intercept (OnTradeTransaction → HandleEntryFill)

  Execution Thread Trace

  1. OnTradeTransaction() (ExecutionEngine.mqh:1002) — filters TRADE_TRANSACTION_DEAL_ADD, calls HistoryDealSelect,
  extracts all deal fields. Routes by (deal_entry, deal_magic):
    - DEAL_ENTRY_IN + magic EA_MAGIC or EA_MAGIC+1 → HandleEntryFill()
    - DEAL_ENTRY_IN + magic EA_MAGIC+2 → HandleExitFill() (hedge position from marketable reversion)
    - DEAL_ENTRY_OUT + magic EA_MAGIC+2 → HandleExitFill() (normal exit limit)
  2. HandleEntryFill() (ExecutionEngine.mqh:318) — resolves instrument, clears g_add_next if filling ticket matches,
  searches inventory for existing entry_ticket. If not found, creates new Layer via InitLayer().
  3. Layer 0 creation (ExecutionEngine.mqh:393–440) — snaps anchor_A/B_at_entry = g_anchor[0/1], computes live mid
  prices, recomputes scores against frozen 12-bar anchor, sets entry_spread_raw. Structural (strongest_at_entry,
  weakest_at_entry) assignment from instrument+direction.
  4. Layer 1+ creation (ExecutionEngine.mqh:442–474) — inherits anchor and routing from Layer 0. Recomputes
  entry_spread_raw using live mids vs Layer 0 anchor.
  5. Volume tracking (ExecutionEngine.mqh:612–634) — decrements remaining_entry_volume -= deal_volume. When
  remaining_entry_volume <= VOLUME_EPSILON && remaining_exit_volume == 0.0, arms remaining_exit_volume = lot_size.
  6. Exit placement (ExecutionEngine.mqh:637–702) — reads exit_target from Layer, calls PlaceExitLimit() or fires market
  hedge if exit_target < 0.

  ---
  Findings

  G2-1 — DEAL_POSITION_ID capture → PASS

  L.position_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) (ExecutionEngine.mqh:524). Called
  within a confirmed HistoryDealSelect() scope. For DEAL_ENTRY_IN this reliably returns the opened position's ID. Set
  once at layer creation; partial fills on an existing layer correctly bypass this block.

  G2-2 — entry_spread_raw anchor → PASS

  g_anchor[0/1] are set by RunSignalOnBarClose() at each M5 bar close and held immutable until the next bar.
  HandleEntryFill uses these frozen anchors to recompute entry_spread_raw at fill time. The maximum drift is one bar
  period (5 min). For Layer 1+, the anchor is inherited from Layer 0 (set at Layer 0 fill time) — correctly frozen to
  the pod's opening anchor for the entire pod lifecycle.

  G2-3 — LDAK lot sizing / remaining_entry_volume → WARNING

  PlaceEntryLimit (line 79) and PlaceNextEntryLimit (line 189) always place req.volume = BaseLotSize. LDAK lot-size
  computation in HandleEntryFill (lines 482–519) runs after the order was already placed — it has no effect on the
  physical fill size.

  Result: Layer.lot_size is set to the LDAK-adjusted value (≤ BaseLotSize), but the physical fill arrives for
  BaseLotSize. When LDAK penalty is active:
  - remaining_entry_volume initialized to LDAK value (e.g., 0.005) but fill is for 0.01 → goes negative
  - Exit armed with remaining_exit_volume = lot_size = 0.005 but PlaceExitLimit(exit_price, deal_volume=0.01, ...) is
  called
  - Exit fills for 0.01 → remaining_exit_volume = 0.005 − 0.01 = −0.005 ≤ VOLUME_EPSILON → layer removed ✓

  Mathematically self-consistent because deal_volume tracks the real size throughout. However Layer.lot_size is a lie —
  it underrepresents the real position. The MinFillThreshold gate computes filled_so_far = lot_size −
  remaining_entry_volume which over-fires but doesn't block. No hard failure, but LDAK lot-size reduction has zero
  effect on execution — the feature is dead code.

  Fix: Move LDAK lot-size computation to PlaceEntryLimit / PlaceNextEntryLimit and apply it to req.volume. Alternatively
  remove it as dead code and document that LDAK affects grid spacing only (via ComputeGridInterval).

  G2-4 — Double-processing → PASS

  MT5 guarantees each DEAL_ADD transaction fires once. State is persistent in JSON; LoadInventoryState on reconnect
  correctly restores tickets. No identified path for the same fill to invoke HandleEntryFill twice.

  ---
  GATE 3 — Continuous State Reconciliation (OnTick)

  Execution Thread Trace

  1. AuditExitLimits() (FXMatrix.mq5:752) — called on every OnTick before signal logic. Iterates all layers across all 3
  slots. Three skip conditions: entry not complete, exit already placed, exit volume not armed.
  2. Add-next re-arm block (FXMatrix.mq5:187–222) — fires every tick when inst_inv_size > 0 && g_add_next[inst] == 0.
  Checks MinLayerIntervalSeconds sleep gate, calls PlaceNextEntryLimit.

  ---
  Findings

  G3-1 — AuditExitLimits false-positive safety → WARNING (ORPHAN TICKET BLIND SPOT)

  The three conditions correctly guard against the main failure modes. However: Condition 2 (ArraySize(L.exit_tickets) >
  0) does not verify the recorded ticket still exists on the broker's order book.

  If a broker-side cancellation silently removes an exit limit (margin call, order expiry, broker reject),
  exit_tickets[] still contains the stale ticket. AuditExitLimits skips the layer on Condition 2. The result: an open
  position with no exit limit and no recovery — stranded indefinitely.

  No OrderSelect(ticket) validation is performed. This is the most operationally significant gap in the EA.

  Fix (3 lines in the Condition 2 block):
  if (ArraySize(L.exit_tickets) > 0) {
      bool any_live = false;
      for (int t = 0; t < ArraySize(L.exit_tickets); t++) {
          if (OrderSelect(L.exit_tickets[t])) { any_live = true; break; }
      }
      if (any_live) continue;
      // stale ticket array — fall through to re-place
      ArrayResize(inventory[slot][i].exit_tickets, 0);
  }

  G3-2 — add_next re-arm ticket validation → WARNING

  The re-arm block fires when g_add_next[inst] == 0. It correctly re-places the add_next limit. However, it does NOT
  validate that a non-zero g_add_next[inst] ticket is still alive on the broker. A broker-cancelled add_next order
  leaves g_add_next[inst] pointing to a dead ticket. The re-arm block sees g_add_next[inst] != 0 and does nothing — the
  next-layer limit is silently absent.

  Fix: Same pattern as G3-1 — add an OrderSelect(g_add_next[inst]) check; if it fails, zero the global and let the
  re-arm block fire.

  G3-3 — 5+ minute disconnect recovery → PASS

  MT5 replays synthetic OnTradeTransaction events in chronological order on reconnect. Entry/exit fills during the gap
  are correctly processed by HandleEntryFill / HandleExitFill. CloseBy tasks queued during the gap are processed by
  ProcessCloseByQueue() on the first post-reconnect tick. Flat-quoting resumes on the next M5 bar close (up to 5-min
  delay — acceptable).

  ---
  GATE 4 — Unwind & Reset (HandleExitFill + CloseBy)

  Execution Thread Trace

  1. HandleExitFill() (ExecutionEngine.mqh:737) — searches all 3 inventory arrays for matching exit_tickets[j] ==
  order_ticket. On match: queues CloseBy if hedge position present, decrements remaining_exit_volume, removes matched
  ticket from array, removes layer if volume ≤ epsilon.
  2. Pod-flat branch (ExecutionEngine.mqh:806–906) — when remaining == 0: captures and cancels add_next ticket, zeros
  g_add_next, calls resume-quoting, emits telemetry.
  3. Partial-unwind branch (ExecutionEngine.mqh:908–940) — cancels stale add_next, resubmits for new shallowest layer
  (index 0 after LIFO removal).
  4. ProcessCloseByQueue() (FXMatrix.mq5:810) — retries CloseBy up to 10 times; graceful discard after 10 (delta-neutral
  comment).

  ---
  Findings

  G4-1 — HandleExitFill volume decrement and layer removal → PASS

  Volume decrement, ticket removal, and layer array removal are all correct. The re-read of CurL after modification
  (line 789) correctly captures the updated state before the remaining_exit_volume check. LogLayerExit fires before
  ArrayRemove — correct. SaveAllInventoryState called after all mutations.

  G4-2 — CloseBy queue — stranded positions → PASS

  Queue exhaustion path (10 retries, WARNING + discard) is safe for the stated reason: offsetting positions are
  delta-neutral. The history check (HistorySelectByPosition) correctly handles the case where a prior CloseBy or manual
  close already netted the positions. No stranding scenario identified.

  G4-3 — Orphaned add_next on final unwind → PASS

  ExecutionEngine.mqh:807–827 explicitly captures and cancels the add_next ticket before zeroing g_add_next[inst] and
  placing new flat quotes. Partial-unwind path (line 908) also cancels the stale add_next and resubmits for the new
  shallowest layer. Both paths correct.

  G4-4 — Zero-inventory with stale pending tickets → FATAL (NUCLEAR FAILSAFE PATH)

  This is the most severe finding in the audit.

  The global nuclear failsafe path (CheckCircuitBreakers, Tier 2) calls:
  CloseAllPositions();         // closes all positions at market
  CancelAllPendingEntries();   // cancels magic=EA_MAGIC flat-quote entries
  g_halted = true;

  CancelAllPendingEntries() (FXMatrix.mq5:689) iterates OrdersTotal() and cancels orders where ORDER_MAGIC == EA_MAGIC.
  Exit limit orders carry magic EA_MAGIC + 2 — they are never touched. Add-next orders carry EA_MAGIC + 1 — also not
  touched (and explicitly protected).

  Similarly, CancelAllPending() (FXMatrix.mq5:672) also filters on ORDER_MAGIC == EA_MAGIC strictly — it does NOT cancel
  exit limits either.

  Result: After a nuclear failsafe fires:
  - All positions are closed at market
  - All exit limit orders (magic EA_MAGIC+2, GTC) remain live on the broker's order book
  - g_halted = true causes OnTradeTransaction to drop all subsequent fills silently
  - SaveAllInventoryState() is called from CancelAllPendingEntries — saves inventory with layers pointing to closed
  positions and live exit tickets

  On EA restart:
  - LoadInventoryState restores stale inventory
  - CheckForOrphans checks open positions against inventory. All positions are closed → no orphans detected → EA starts
  normally
  - On first tick: AuditExitLimits finds layers with remaining_entry_volume <= 0, exit_tickets[] = [] (tickets were
  recorded but... wait, are they still in the JSON?)

  Actually the JSON saves exit_tickets at the point of the nuclear halt. The exit limit orders are still live.
  AuditExitLimits condition 2 (ArraySize(exit_tickets) > 0) would skip these layers — IF the tickets were saved.

  But the real risk: those GTC exit limit orders sitting on the broker will eventually fill (when price reaches the
  target). When they fill after the halt with g_halted = true, OnTradeTransaction drops the event. A new untracked
  position is opened by the exit fill. CheckForOrphans on next restart catches it and prevents EA start — but the
  phantom position is open, unmanaged, and consuming margin.

  Fix: Add a cancel loop for EA_MAGIC+2 orders to the nuclear failsafe:
  // In CheckCircuitBreakers, Tier 2, after CloseAllPositions():
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong tkt = OrderGetTicket(i);
      if (tkt == 0) continue;
      long m = OrderGetInteger(ORDER_MAGIC);
      if (m != (long)EA_MAGIC &&
          m != (long)(EA_MAGIC+1) &&
          m != (long)(EA_MAGIC+2)) continue;
      MqlTradeRequest req = {}; MqlTradeResult res = {};
      req.action = TRADE_ACTION_REMOVE;
      req.order  = tkt;
      OrderSend(req, res);
  }
  ArrayResize(g_inventory_0, 0);
  ArrayResize(g_inventory_1, 0);
  ArrayResize(g_inventory_2, 0);
  SaveAllInventoryState();

  ---
  Overall Verdict

  ┌────────┬────────┬──────────────────────────────────────────────────────────────────┐
  │  Gate  │ Status │                        Critical Findings                         │
  ├────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ Gate 1 │ AMBER  │ WARNING: resume-quoting strongest==weakest silent drop           │
  ├────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ Gate 2 │ AMBER  │ WARNING: LDAK lot size is dead code — no effect on physical fill │
  ├────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ Gate 3 │ RED    │ WARNING: exit ticket and add_next ticket liveness not validated  │
  ├────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ Gate 4 │ RED    │ FATAL: nuclear failsafe leaves exit limit orders live on broker  │
  └────────┴────────┴──────────────────────────────────────────────────────────────────┘

  ---
  Prioritised Fix List

  Priority 1 — FATAL (immediate)

  F1: Nuclear failsafe does not cancel exit limit orders (EA_MAGIC+2)
  - File: FXMatrix.mq5, CheckCircuitBreakers(), Tier 2 block (~line 596)
  - Add an explicit cancel loop for all EA magic variants before g_halted = true
  - Also clear and save all three inventory arrays to prevent phantom AuditExitLimits recovery on next start

  ---
  Priority 2 — WARNING (high, next session)

  W1: AuditExitLimits does not validate exit ticket liveness
  - File: FXMatrix.mq5, AuditExitLimits() (~line 767)
  - Add OrderSelect() check on each ticket in exit_tickets[]; if all stale, clear array and allow re-placement

  W2: add_next re-arm does not validate stale ticket
  - File: FXMatrix.mq5, OnTick add_next re-arm block (~line 187)
  - Add OrderSelect(g_add_next[inst]) before the inst_add_next == 0 check; zero and re-arm if stale

  W3: Resume-quoting uses score-dependent routing (strongest == weakest risk)
  - File: ExecutionEngine.mqh, HandleExitFill(), ~line 855
  - Replace score-conditional ? : routing with the same structural if/else used in the flat-quoting loop

  ---
  Priority 3 — WARNING (low, housekeeping)

  W4: LDAK lot sizing is dead code
  - File: ExecutionEngine.mqh, HandleEntryFill(), ~line 482
  - Either move computation to PlaceEntryLimit/PlaceNextEntryLimit (to actually size orders), or remove and document
  that LDAK only affects grid spacing

✻ Churned for 5m 53s