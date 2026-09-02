# DeepSeek R1 Audit — HandleEntryFill() Pre-V2 vs V2 Behavioral Diff

## ROLE

You are a ruthless code auditor. Your job is to find behavioral differences
between two versions of `HandleEntryFill()` that could cause the V2 version
to accumulate more layers than the pre-V2 version. Do not suggest architectural
changes. Do not write implementation code. Only audit the logic differences.

---

## Prior Audit Context

A previous DeepSeek audit verified the Phase 0 grid geometry and signal
inversion math as correct. That audit is stored at:
`D:\fxmatrix\adrs\deepseek_audit_latest.md`

The following were verified as PASS in that audit and are NOT in scope here:
- Exit spread target formula
- add_next spread formula and invariant
- InvertSpreadToPrice directionality for all 6 routings
- Anchor computation (no look-ahead, no off-by-one)

Treat those as proven correct. Focus exclusively on the behavioral
differences in `HandleEntryFill()` logic between pre-V2 and V2.

---

## Context

FXMatrix is a passive limit order EA. `HandleEntryFill()` fires when an entry
limit order fills. It creates a new layer in the inventory, places an exit
limit, and places the next add_next limit.

Pre-V2 used a single global `g_inventory[]` and a single `g_pending_entry_ticket`.
V2 routes to per-instrument arrays (`g_inventory_EURUSD[]`, `g_inventory_GBPUSD[]`,
`g_inventory_EURGBP[]`) with per-instrument tickets.

Pre-V2 Run 60 had a max of 3 concurrent layers across all instruments.
V2 Phase 2f (after the add_next orphan fix) still shows deeper layering
than expected despite the fix. We need to identify why.

---

## Pre-V2 HandleEntryFill() — Key Logic

```mql5
void HandleEntryFill(ulong deal_ticket, ulong order_ticket,
                     double deal_volume, double deal_price,
                     datetime deal_time, string deal_symbol,
                     long deal_type) {

    // Search g_inventory[] for existing layer with this ticket
    int layer_idx = -1;
    for (int i = 0; i < ArraySize(g_inventory); i++) {
        if (g_inventory[i].entry_ticket == order_ticket) {
            layer_idx = i; break;
        }
    }

    if (layer_idx == -1) {
        // New layer — not found in inventory
        layer_idx = ArraySize(g_inventory);
        if (layer_idx >= MaxLayers) {
            Print("WARNING: MaxLayers reached.");
            return;
        }

        Layer L = InitLayer();
        // ... populate L (entry price, spread, instrument, direction etc.) ...

        ArrayResize(g_inventory, layer_idx + 1);
        g_inventory[layer_idx] = L;

        // Clear the single global pending entry ticket
        g_pending_entry_ticket = 0;
        SaveInventoryState();
    }

    // Decrement remaining entry volume
    g_inventory[layer_idx].remaining_entry_volume -= deal_volume;

    double rem_entry = g_inventory[layer_idx].remaining_entry_volume;
    double rem_exit  = g_inventory[layer_idx].remaining_exit_volume;
    double lot       = g_inventory[layer_idx].lot_size;

    // Arm exit volume when fully filled
    if (rem_entry <= VOLUME_EPSILON && rem_exit == 0.0) {
        g_inventory[layer_idx].remaining_exit_volume = lot;
        // Place exit limit
        ulong exit_tkt = PlaceExitLimit(exit_price, deal_volume,
                                        direction, deal_symbol);
        if (exit_tkt > 0) {
            // append to exit_tickets
        }
        SaveInventoryState();
    }

    // Place next entry limit
    double filled_so_far = lot - g_inventory[layer_idx].remaining_entry_volume;
    bool threshold_met   = filled_so_far >= MinFillThreshold * lot;
    bool next_not_placed = ArraySize(g_inventory) == layer_idx + 1;
    bool capacity_ok     = ArraySize(g_inventory) < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok) {
        PlaceNextEntryLimit(g_inventory[layer_idx], deal_symbol);
        Print("INFO: Next layer triggered at add_next=", ...);
    }
}
```

**Key pre-V2 constraint — Option A deafness (OnTick):**
```mql5
// Single global guard — ALL instruments deaf while ANY inventory exists
if (ArraySize(g_inventory) == 0) {
    // signal evaluation and entry placement
}
```

When Layer 0 fills on EURUSD, `g_inventory` has 1 element.
GBPUSD and EURGBP signal evaluation is completely suppressed until
`g_inventory` returns to 0. No new Layer 0 can open on any instrument.

**Key pre-V2 constraint — single add_next ticket:**
```mql5
// g_add_next_ticket is cleared in CancelAllPendingEntries()
// which fires when pod goes flat (ArraySize(g_inventory) == 0)
```

---

## V2 HandleEntryFill() — Key Logic (Phase 2f, HEAD e5c3a6f)

```mql5
void HandleEntryFill(ulong deal_ticket, ulong order_ticket,
                     double deal_volume, double deal_price,
                     datetime deal_time, string deal_symbol,
                     long deal_type) {

    int instrument = GetInstrumentFromSymbol(deal_symbol);

    // Phase 2f fix: clear add_next ticket if this fill IS the add_next
    ulong cur_add_next = (instrument == INSTRUMENT_EURUSD) ? g_add_next_EURUSD
                       : (instrument == INSTRUMENT_GBPUSD) ? g_add_next_GBPUSD
                       : g_add_next_EURGBP;

    if (order_ticket == cur_add_next) {
        if (instrument == INSTRUMENT_EURUSD)      g_add_next_EURUSD = 0;
        else if (instrument == INSTRUMENT_GBPUSD)  g_add_next_GBPUSD = 0;
        else                                        g_add_next_EURGBP = 0;
        cur_add_next = 0;
    }

    // Search per-instrument array for existing layer
    int layer_idx = -1;
    // search g_inventory_X[] for entry_ticket == order_ticket

    int inv_size = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                 : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                 : ArraySize(g_inventory_EURGBP);

    if (layer_idx == -1) {
        layer_idx = inv_size;
        if (inv_size >= MaxLayers) return;

        Layer L = InitLayer();
        L.layer_index = layer_idx;
        // ... populate L ...

        // Append to correct per-instrument array
        if (instrument == INSTRUMENT_EURUSD) {
            ArrayResize(g_inventory_EURUSD, layer_idx + 1);
            g_inventory_EURUSD[layer_idx] = L;
        } // etc.

        // Clear per-instrument pending entry ticket
        if (instrument == INSTRUMENT_EURUSD)      g_pending_entry_EURUSD = 0;
        else if (instrument == INSTRUMENT_GBPUSD)  g_pending_entry_GBPUSD = 0;
        else                                        g_pending_entry_EURGBP = 0;

        SaveAllInventoryState();
    }

    // Decrement remaining entry volume on correct array
    // Arm exit when fully filled, place exit limit
    // ...

    // Re-read CurL from correct array
    Layer CurL = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx]
               : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx]
               : g_inventory_EURGBP[layer_idx];

    // Place next entry limit
    double filled_so_far = CurL.lot_size - CurL.remaining_entry_volume;
    bool threshold_met   = filled_so_far >= MinFillThreshold * CurL.lot_size;
    int  cur_inv_size    = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                         : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                         : ArraySize(g_inventory_EURGBP);
    bool next_not_placed = cur_inv_size == layer_idx + 1;
    bool capacity_ok     = cur_inv_size < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok && cur_add_next == 0) {
        PlaceNextEntryLimit(CurL, deal_symbol);
        Print("INFO: Next layer triggered at add_next=", ...);
    }
}
```

**Key V2 constraint — per-instrument Option A deafness (OnTick):**
```mql5
// Per-instrument guard — only THIS instrument is deaf
int inst_inv_size = ArraySize(g_inventory_X);
if (inst_inv_size > 0) continue;  // only skips THIS instrument
// Other instruments continue evaluating signals and can open Layer 0
```

**Key V2 constraint — per-instrument add_next tickets:**
```mql5
// Each instrument has its own add_next ticket
ulong g_add_next_EURUSD = 0;
ulong g_add_next_GBPUSD = 0;
ulong g_add_next_EURGBP = 0;
```

---

## Questions

**Q1 — Layer accumulation per instrument:**
Are there any logical differences between pre-V2 and V2 `HandleEntryFill()`
that could cause more layers to accumulate PER INSTRUMENT in V2?
The per-instrument deafness means EURUSD can accumulate layers independently
of GBPUSD, but within EURUSD alone — is the layering logic identical?

**Q2 — Pending ticket clearing and new Layer 0 entries:**
In pre-V2, clearing `g_pending_entry_ticket = 0` when Layer 0 fills meant
the Highlander Rule blocked new entries on ALL instruments.
In V2, clearing `g_pending_entry_EURUSD = 0` only affects EURUSD.
Is there a scenario where EURUSD's per-instrument deafness (`inst_inv_size > 0`)
fails to prevent a new Layer 0 from opening on EURUSD while an add_next is
already live or while a layer is being processed?

**Q3 — `next_not_placed` equivalence:**
Pre-V2: `next_not_placed = ArraySize(g_inventory) == layer_idx + 1`
V2: `next_not_placed = cur_inv_size == layer_idx + 1`
where `cur_inv_size` is `ArraySize(g_inventory_X)` for the current instrument.
Are these logically equivalent? Is there any scenario where `cur_inv_size`
differs from what `ArraySize(g_inventory)` would have returned in pre-V2?

**Q4 — `cur_add_next` state at PlaceNextEntryLimit guard:**
The V2 Phase 2f fix clears `cur_add_next` at the TOP of `HandleEntryFill()`
if `order_ticket == cur_add_next`. But `cur_add_next` is a LOCAL variable
set at the top of the function. If `PlaceNextEntryLimit()` fires and sets
`g_add_next_X` to a new ticket, the local `cur_add_next` is still 0 (stale).
Is there any scenario where a SECOND call to `HandleEntryFill()` (e.g. for a
partial fill on the same order) could fire before `g_add_next_X` is updated,
causing `cur_add_next == 0` to evaluate true incorrectly?

**Q5 — Exit placement and add_next interaction:**
In pre-V2, the exit limit is placed BEFORE the add_next check.
In V2, the same order is preserved. However, in V2 the exit ticket is appended
to `g_inventory_X[layer_idx].exit_tickets[]`, and then `CurL` is re-read from
the array. Is there any scenario where the re-read `CurL` has stale data
(e.g. `add_next = 0.0`) that could cause `PlaceNextEntryLimit()` to place
an add_next at price 0?

**Q6 — Layer 0 entry while add_next is live:**
In pre-V2, when `g_inventory` had 1 element (Layer 0 open, add_next live),
`ArraySize(g_inventory) == 0` was false so Option A blocked all new entries.
In V2, when `g_inventory_EURUSD` has 1 element, only EURUSD is deaf.
But could a NEW Layer 0 entry limit be placed on EURUSD itself if:
- `g_pending_entry_EURUSD == 0` (cleared when Layer 0 filled)
- `inst_inv_size > 0` (should block it)
Is the `inst_inv_size > 0` check in `OnTick()` sufficient to prevent a new
Layer 0 entry on EURUSD while EURUSD already has an open layer?

---

## What To Look For

- Logic branches present in one version but missing in the other
- State variable clearing differences that could allow extra entries
- Conditions where V2 places more add_next limits than pre-V2
- Race conditions between `OnTick()` deafness checks and `HandleEntryFill()` state updates
- Any path where `PlaceNextEntryLimit()` fires when it should not

## Output Format

For each question (Q1-Q6):
1. PASS or FAIL
2. Algebraic proof or concrete counterexample
3. If FAIL: exact condition under which extra layers accumulate and direction of error

Be concise. Flag only genuine behavioral differences, not stylistic concerns.
