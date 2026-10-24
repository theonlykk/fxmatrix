This message has a line count at the bottom

# OPT BUDGET -- THE ENGINE MECHANICS THE SIMULATOR MIRRORS (24 Oct 2026)

Read from source at fxmatrix `main` (EA) and `replay-plan4` `8044284` (harness). The simulator (`sim.py`) mirrors
these; anything not listed is left out on purpose (s9). File:line at those commits.

## 1. One instance, one side

- **Depth** = open layers on the side (`grind_engine.mqh` 2015). Entries allowed while depth < cap (`grind_pure.mqh` 229).
- **L0** (depth 0, no resting L0): BUY_LIMIT at mid - width, SELL_LIMIT at mid + width (`grind_pure.mqh` 124-137;
  `grind_engine.mqh` 3214-3222), clamped at least 1 point off the market (ADR-013, `grind_pure.mqh` 198-227), placed only
  if marketable (buy < ask, sell > bid; 186-195). Placed once and left resting (ADR-123, 2066-2072).
- **Re-centre:** while one side holds layers and the other is flat, the flat side's resting L0 moves to mid -/+ width
  when it is more than `stranded` pips from mid and not within `deadband` of the new price (3026-3071).
- **Adds:** target = anchor - add (long) / + add (short); anchor = the deepest layer's entry, or, if any layer is
  rolled, the most extreme EFFECTIVE entry (2250-2288). One resting add; placed at the ENT fill (`fill_time_place`,
  2405-2430) or on a later tick; modified when the target moves by >= deadband (2483-2616). No entry horizon
  (`entry_horizon_pips` 0 in every run).
- **One ENT send per tick per instance** (`g_grind_ent_sent_this_tick`, 2087, 2361).

## 2. Exits

- Exit target = effective entry + exit (long) / - exit (short), plus the carry shift (`grind_exitq.mqh` 241-256).
- **Only two exits rest per side** (ADR-151, `GRIND_EXITQ_K` 1, `GRIND_EXITQ_H` 0, `grind_config.mqh` 7-8): rank 0
  (the lowest effective entry for a long) and rank n-1 (the highest); the others are held and placed as ranks change
  (`grind_engine.mqh` 3451-3511). A held exit that price has passed is placed clamped passive (1 point off market).
- An EXT fill opens the opposite position; a close-by pairs them (`grind_closeby.mqh`): the layer closes at the exit
  fill's price. SCALP_CLOSED; `rolled` if the layer had a virtual level.

## 3. The lattice (at cap)

- Only when depth >= cap (`grind_engine.mqh` 1401-1415). Roll gate: no roll while the OPPOSITE side holds more than
  `gate` layers (gate 0 live: rolls only while the opposite side is flat; `grind_pure.mqh` 444-447).
- Level = the add target (above). Crossed when the probe (long: min(ask, the lowest ask since the newest layer
  opened); short: max(bid, ...)) is at or beyond it (1290-1320; 770-893).
- **A roll does not close the layer:** the candidate (long: the highest-entry layer not yet rolled) gets the level as
  its virtual level (VL); its exit moves to VL + exit (+ carry) (1025-1097). The loss is realised only when that exit
  fills. Each roll is ROLL_ACCEPTED (A). Up to cap rolls per tick while the level keeps crossing.
- **Re-roll:** when every layer is rolled, the highest-VL layer re-rolls to the new level, at most once per tick
  (964-992, 1318-1330).

## 4. The replay's broker and clock (timing 1, sens base; `fxgrind_replay_core.mqh`)

- Order placed at t is live from t + 287 ms; a modify takes effect at t + 288 ms; a close-by completes at t + 294 ms
  (429-445).
- A BUY_LIMIT is touched when ask <= price, a SELL_LIMIT when bid >= price (631-652); the deal executes at t + 261 ms at
  the market then (ask for a buy, bid for a sell; 1060-1070, `limit_price` false in base).
- The EA is single-threaded: while a send is in flight, new ticks are dropped (1239-1252). Fills only inside the
  session file (Mon-Thu 00:01-23:59, Fri 00:01-23:57 server).
- Carry (October runs only): at each server-day change every open position accrues the night's swap (points x mult,
  `swaps_<PAIR>.csv`, 2336-2368); the exit moves by the accrued pips (`grind_carry.mqh` 387-390, 1100-1180).

## 5. Accounting (as the committed scores)

Pips at 0.01 lots; commission 0.06 USD a close (`sweep.py` 59); USD per pip by pair (`sweep.py` 56-58); equity as
`score9.equity_at`. SCALP_CLOSED with `rolled` = R, else S.

## 9. Left out (do not matter at 0.01 lots on one instance per pair and arm)

Slot guard and commitment guard, API counter, breaker, session window (ADR-161, off), eject, stale-feed skip,
quarantine and invariants, the carry pass's exact minute (shift applied at the day change).

Line count: 64
