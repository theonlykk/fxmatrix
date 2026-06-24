#ifndef LAYER_STRUCT_MQH
#define LAYER_STRUCT_MQH

#define VOLUME_EPSILON       0.0001   // minimum volume for remaining_volume == 0 check
#define FALLBACK_TIME_WINDOW 30       // seconds, for ticket fallback matching
#define MAX_EXIT_TICKETS     20       // maximum exit ticket slots per layer

// ADR-024: V3 Generic Triad — pair slot indices
// Slot ordering is BINDING per Gemini ruling:
//   Slot 0 = PairAC (signal pair 1, e.g. EURUSD)
//   Slot 1 = PairBC (signal pair 2, e.g. GBPUSD)
//   Slot 2 = PairAB (cross pair,   e.g. EURGBP)
// DO NOT REORDER. LDAK correlation indices depend on this ordering.
#define SLOT_AC  0   // PairAC — first signal pair
#define SLOT_BC  1   // PairBC — second signal pair
#define SLOT_AB  2   // PairAB — cross pair

enum DirectionType {
    DIRECTION_BUY  =  1,
    DIRECTION_SELL = -1
};

struct Layer {
    // --- Layer identity ---
    int      layer_index;               // 0-based depth — enables ComputeSkew() in carry path
                                        // -1 = uninitialised sentinel (set at fill time only)

    // --- Entry state (immutable after first fill) ---
    double   entry_price;
    double   entry_spread_raw;
    datetime entry_time;
    double   anchor_A_at_entry;
    double   anchor_B_at_entry;
    double   r_AC_at_entry;
    double   r_BC_at_entry;
    int      strongest_at_entry;
    int      weakest_at_entry;

    // --- Carry recalculation inputs (immutable) ---
    double   entry_price_AC;
    double   entry_price_BC;
    double   entry_price_AC_1h;
    double   entry_price_BC_1h;
    int      instrument;
    int      direction;

    // --- Carry-adjusted state (ADR-003 updates only) ---
    double   entry_spread_adjusted;
    double   entry_price_forward;

    // --- Exit targets (ADR-003 OrderModify only) ---
    double   exit_spread_target;
    double   exit_target;
    double   exit_price_fixed;   // ADR-040: computed once at fill, never recomputed from live prices

    // --- Layer mechanics ---
    double   add_next;
    double   lot_size;
    double   remaining_entry_volume;        // decrements on entry fills; 0 = entry complete
    double   remaining_exit_volume;         // set to lot_size when entry complete; decrements on exits

    // --- Order tracking ---
    ulong    entry_ticket;
    ulong    position_ticket;
    ulong    exit_tickets[];
};

// CloseBy async queue task — used when MT5 ledger desync prevents
// immediate CloseBy after market hedge fill
struct CloseByTask {
    ulong ticket1;   // original position ticket
    ulong ticket2;   // new hedge position ticket
    int   retries;   // OnTick attempt counter (max 10)
};

//--- IMMUTABILITY CONTRACT (DO NOT MODIFY IN ANY OTHER FILE) ---
// The following Layer fields are set ONCE at first fill and
// must NEVER be modified by any function outside OnTradeTransaction:
//   layer_index
//   entry_price
//   entry_spread_raw
//   entry_time
//   anchor_A_at_entry
//   anchor_B_at_entry
//   r_AC_at_entry
//   r_BC_at_entry
//   strongest_at_entry
//   weakest_at_entry
//   entry_price_AC
//   entry_price_BC
//   entry_price_AC_1h
//   entry_price_BC_1h
//   instrument
//   direction
//   entry_ticket
//   position_ticket
//
// The following fields are modified ONLY by ADR-003 carry logic:
//   entry_spread_adjusted
//   entry_price_forward
//   exit_spread_target
//   exit_target
//   exit_tickets[] contents (OrderModify targets)
//
// remaining_entry_volume is decremented ONLY by HandleEntryFill().
// remaining_exit_volume is set by HandleEntryFill() when entry complete,
//   then decremented ONLY by HandleExitFill().
// exit_tickets[] array is appended ONLY by OnTradeTransaction.
// exit_tickets[] elements are removed ONLY by OnTradeTransaction.
//----------------------------------------------------------------

Layer InitLayer() {
    Layer L;
    L.layer_index                  = -1;   // sentinel — must be set at fill time
    L.entry_price                  = 0.0;
    L.entry_spread_raw             = 0.0;
    L.entry_time                   = 0;
    L.anchor_A_at_entry            = 0.0;
    L.anchor_B_at_entry            = 0.0;
    L.r_AC_at_entry                = 0.0;
    L.r_BC_at_entry                = 0.0;
    L.strongest_at_entry           = 0;
    L.weakest_at_entry             = 0;
    L.entry_price_AC               = 0.0;
    L.entry_price_BC               = 0.0;
    L.entry_price_AC_1h            = 0.0;
    L.entry_price_BC_1h            = 0.0;
    L.instrument                   = SLOT_AC;
    L.direction                    = DIRECTION_BUY;
    L.entry_spread_adjusted        = 0.0;
    L.entry_price_forward          = 0.0;
    L.exit_spread_target           = 0.0;
    L.exit_target                  = 0.0;
    L.exit_price_fixed             = -1.0;
    L.add_next                     = 0.0;
    L.lot_size                     = 0.0;
    L.remaining_entry_volume         = 0.0;
    L.remaining_exit_volume          = 0.0;
    L.entry_ticket                 = 0;
    L.position_ticket              = 0;
    ArrayResize(L.exit_tickets, 0);
    return L;
}

#endif // LAYER_STRUCT_MQH
