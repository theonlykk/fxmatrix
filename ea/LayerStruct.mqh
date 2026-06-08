#ifndef LAYER_STRUCT_MQH
#define LAYER_STRUCT_MQH

#define VOLUME_EPSILON       0.0001   // minimum volume for remaining_volume == 0 check
#define FALLBACK_TIME_WINDOW 30       // seconds, for ticket fallback matching
#define MAX_EXIT_TICKETS     20       // maximum exit ticket slots per layer

enum InstrumentType {
    INSTRUMENT_EURUSD = 0,
    INSTRUMENT_GBPUSD = 1,
    INSTRUMENT_EURGBP = 2
};

enum DirectionType {
    DIRECTION_BUY  =  1,
    DIRECTION_SELL = -1
};

struct Layer {
    // --- Entry state (immutable after first fill) ---
    double   entry_price;
    double   entry_spread_raw;
    datetime entry_time;
    double   EU_mid_12bars_ago_at_entry;
    double   GB_mid_12bars_ago_at_entry;
    double   r_EU_at_entry;
    double   r_GB_at_entry;
    int      strongest_at_entry;
    int      weakest_at_entry;

    // --- Carry recalculation inputs (immutable) ---
    double   entry_price_eurusd;
    double   entry_price_gbpusd;
    double   entry_price_eurusd_1h;
    double   entry_price_gbpusd_1h;
    int      instrument;
    int      direction;

    // --- Carry-adjusted state (ADR-003 updates only) ---
    double   entry_spread_adjusted;
    double   entry_price_forward;

    // --- Exit targets (ADR-003 OrderModify only) ---
    double   exit_spread_target;
    double   exit_target;

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

//--- IMMUTABILITY CONTRACT (DO NOT MODIFY IN ANY OTHER FILE) ---
// The following Layer fields are set ONCE at first fill and
// must NEVER be modified by any function outside OnTradeTransaction:
//   entry_price
//   entry_spread_raw
//   entry_time
//   EU_mid_12bars_ago_at_entry
//   GB_mid_12bars_ago_at_entry
//   r_EU_at_entry
//   r_GB_at_entry
//   strongest_at_entry
//   weakest_at_entry
//   entry_price_eurusd
//   entry_price_gbpusd
//   entry_price_eurusd_1h
//   entry_price_gbpusd_1h
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
    L.entry_price                  = 0.0;
    L.entry_spread_raw             = 0.0;
    L.entry_time                   = 0;
    L.EU_mid_12bars_ago_at_entry   = 0.0;
    L.GB_mid_12bars_ago_at_entry   = 0.0;
    L.r_EU_at_entry                = 0.0;
    L.r_GB_at_entry                = 0.0;
    L.strongest_at_entry           = 0;
    L.weakest_at_entry             = 0;
    L.entry_price_eurusd           = 0.0;
    L.entry_price_gbpusd           = 0.0;
    L.entry_price_eurusd_1h        = 0.0;
    L.entry_price_gbpusd_1h        = 0.0;
    L.instrument                   = INSTRUMENT_EURUSD;
    L.direction                    = DIRECTION_BUY;
    L.entry_spread_adjusted        = 0.0;
    L.entry_price_forward          = 0.0;
    L.exit_spread_target           = 0.0;
    L.exit_target                  = 0.0;
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
