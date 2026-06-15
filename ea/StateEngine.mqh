#ifndef STATE_ENGINE_MQH
#define STATE_ENGINE_MQH

#include "Globals.mqh"

//------------------------------------------------------------------
// GetStateFilename (parameterised — Phase 2)
// Returns the correct JSON filename for a given instrument.
//------------------------------------------------------------------
string GetStateFilename(int instrument) {
    if (instrument == INSTRUMENT_EURUSD) return "fxmatrix_state_EURUSD.json";
    if (instrument == INSTRUMENT_GBPUSD) return "fxmatrix_state_GBPUSD.json";
    return "fxmatrix_state_EURGBP.json";
}

//------------------------------------------------------------------
// SaveInventoryState (parameterised — Phase 2)
// Saves one instrument's inventory to its own state file.
// Includes layer_index in JSON schema.
//------------------------------------------------------------------
void SaveInventoryState(int instrument) {
    string filename = GetStateFilename(instrument);
    int fh = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR: SaveInventoryState(", instrument,
              ") — FileOpen failed: ", filename);
        return;
    }

    // Resolve correct globals for this instrument
    ulong pending_bid_ticket   = 0;
    ulong pending_offer_ticket = 0;
    ulong add_next_ticket_val = 0;
    int   n = 0;

    if (instrument == INSTRUMENT_EURUSD) {
        pending_bid_ticket   = g_pending_bid_EURUSD;
        pending_offer_ticket = g_pending_offer_EURUSD;
        add_next_ticket_val = g_add_next_EURUSD;
        n = ArraySize(g_inventory_EURUSD);
    } else if (instrument == INSTRUMENT_GBPUSD) {
        pending_bid_ticket   = g_pending_bid_GBPUSD;
        pending_offer_ticket = g_pending_offer_GBPUSD;
        add_next_ticket_val = g_add_next_GBPUSD;
        n = ArraySize(g_inventory_GBPUSD);
    } else {
        pending_bid_ticket   = g_pending_bid_EURGBP;
        pending_offer_ticket = g_pending_offer_EURGBP;
        add_next_ticket_val = g_add_next_EURGBP;
        n = ArraySize(g_inventory_EURGBP);
    }

    FileWrite(fh, "{");
    FileWrite(fh, "  \"pending_bid_ticket\": " +
              IntegerToString(pending_bid_ticket) + ",");
    FileWrite(fh, "  \"pending_offer_ticket\": " +
              IntegerToString(pending_offer_ticket) + ",");
    FileWrite(fh, "  \"add_next_ticket\": " +
              IntegerToString(add_next_ticket_val) + ",");
    FileWrite(fh, "  \"inventory\": [");

    for (int i = 0; i < n; i++) {
        Layer L;
        if (instrument == INSTRUMENT_EURUSD)      L = g_inventory_EURUSD[i];
        else if (instrument == INSTRUMENT_GBPUSD)  L = g_inventory_GBPUSD[i];
        else                                        L = g_inventory_EURGBP[i];

        string comma = (i < n - 1) ? "," : "";

        FileWrite(fh, "    {");
        FileWrite(fh, "      \"layer_index\": "
                  + IntegerToString(L.layer_index) + ",");
        FileWrite(fh, "      \"entry_price\": "
                  + DoubleToString(L.entry_price, 8) + ",");
        FileWrite(fh, "      \"entry_spread_raw\": "
                  + DoubleToString(L.entry_spread_raw, 8) + ",");
        FileWrite(fh, "      \"entry_time\": "
                  + IntegerToString(L.entry_time) + ",");
        FileWrite(fh, "      \"EU_mid_12bars_ago_at_entry\": "
                  + DoubleToString(L.EU_mid_12bars_ago_at_entry, 8) + ",");
        FileWrite(fh, "      \"GB_mid_12bars_ago_at_entry\": "
                  + DoubleToString(L.GB_mid_12bars_ago_at_entry, 8) + ",");
        FileWrite(fh, "      \"r_EU_at_entry\": "
                  + DoubleToString(L.r_EU_at_entry, 8) + ",");
        FileWrite(fh, "      \"r_GB_at_entry\": "
                  + DoubleToString(L.r_GB_at_entry, 8) + ",");
        FileWrite(fh, "      \"strongest_at_entry\": "
                  + IntegerToString(L.strongest_at_entry) + ",");
        FileWrite(fh, "      \"weakest_at_entry\": "
                  + IntegerToString(L.weakest_at_entry) + ",");
        FileWrite(fh, "      \"entry_price_eurusd\": "
                  + DoubleToString(L.entry_price_eurusd, 8) + ",");
        FileWrite(fh, "      \"entry_price_gbpusd\": "
                  + DoubleToString(L.entry_price_gbpusd, 8) + ",");
        FileWrite(fh, "      \"entry_price_eurusd_1h\": "
                  + DoubleToString(L.entry_price_eurusd_1h, 8) + ",");
        FileWrite(fh, "      \"entry_price_gbpusd_1h\": "
                  + DoubleToString(L.entry_price_gbpusd_1h, 8) + ",");
        FileWrite(fh, "      \"instrument\": "
                  + IntegerToString(L.instrument) + ",");
        FileWrite(fh, "      \"direction\": "
                  + IntegerToString(L.direction) + ",");
        FileWrite(fh, "      \"entry_spread_adjusted\": "
                  + DoubleToString(L.entry_spread_adjusted, 8) + ",");
        FileWrite(fh, "      \"entry_price_forward\": "
                  + DoubleToString(L.entry_price_forward, 8) + ",");
        FileWrite(fh, "      \"exit_spread_target\": "
                  + DoubleToString(L.exit_spread_target, 8) + ",");
        FileWrite(fh, "      \"exit_target\": "
                  + DoubleToString(L.exit_target, 8) + ",");
        FileWrite(fh, "      \"add_next\": "
                  + DoubleToString(L.add_next, 8) + ",");
        FileWrite(fh, "      \"lot_size\": "
                  + DoubleToString(L.lot_size, 8) + ",");
        FileWrite(fh, "      \"remaining_entry_volume\": "
                  + DoubleToString(L.remaining_entry_volume, 8) + ",");
        FileWrite(fh, "      \"remaining_exit_volume\": "
                  + DoubleToString(L.remaining_exit_volume, 8) + ",");
        FileWrite(fh, "      \"entry_ticket\": "
                  + IntegerToString(L.entry_ticket) + ",");
        FileWrite(fh, "      \"position_ticket\": "
                  + IntegerToString(L.position_ticket) + ",");

        string tkt_str = "      \"exit_tickets\": [";
        int nt = ArraySize(L.exit_tickets);
        for (int j = 0; j < nt; j++) {
            tkt_str += IntegerToString(L.exit_tickets[j]);
            if (j < nt - 1) tkt_str += ", ";
        }
        tkt_str += "]";
        FileWrite(fh, tkt_str);
        FileWrite(fh, "    }" + comma);
    }

    FileWrite(fh, "  ]");
    FileWrite(fh, "}");
    FileClose(fh);

    if (EnableVerboseLog)
        Print("INFO: SaveInventoryState(", instrument, ") — saved ",
              n, " layers to ", filename);
}

//------------------------------------------------------------------
// SaveAllInventoryState (Phase 2)
// Saves all three instrument state files in sequence.
// Use this at every mutation point.
//------------------------------------------------------------------
void SaveAllInventoryState() {
    SaveInventoryState(INSTRUMENT_EURUSD);
    SaveInventoryState(INSTRUMENT_GBPUSD);
    SaveInventoryState(INSTRUMENT_EURGBP);
}

//------------------------------------------------------------------
// LoadInventoryState (parameterised — Phase 2)
// Loads one instrument's state file into the correct array.
// Handles old state files that predate layer_index (sets -1 as
// fallback sentinel — will be overwritten at next fill).
//------------------------------------------------------------------
bool LoadInventoryState(int instrument) {
    string filename = GetStateFilename(instrument);
    if (!FileIsExist(filename)) {
        Print("INFO: LoadInventoryState(", instrument,
              ") — no state file found. Clean start.");
        return false;
    }

    int fh = FileOpen(filename, FILE_READ | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR: LoadInventoryState(", instrument,
              ") — FileOpen failed: ", filename);
        return false;
    }

    // Reset target array and tickets
    if (instrument == INSTRUMENT_EURUSD) {
        ArrayResize(g_inventory_EURUSD, 0);
        g_pending_bid_EURUSD   = 0;
        g_pending_offer_EURUSD = 0;
        g_add_next_EURUSD      = 0;
    } else if (instrument == INSTRUMENT_GBPUSD) {
        ArrayResize(g_inventory_GBPUSD, 0);
        g_pending_bid_GBPUSD   = 0;
        g_pending_offer_GBPUSD = 0;
        g_add_next_GBPUSD      = 0;
    } else {
        ArrayResize(g_inventory_EURGBP, 0);
        g_pending_bid_EURGBP   = 0;
        g_pending_offer_EURGBP = 0;
        g_add_next_EURGBP      = 0;
    }

    Layer L = InitLayer();
    bool in_layer     = false;
    bool in_inventory = false;

    while (!FileIsEnding(fh)) {
        string raw  = FileReadString(fh);
        string line = raw;

        StringTrimLeft(line);
        StringTrimRight(line);

        if (line == "" || line == "{" || line == "}") continue;

        if (StringFind(line, "\"inventory\"") >= 0) {
            in_inventory = true;
            continue;
        }
        if (in_inventory && line == "]") {
            in_inventory = false;
            continue;
        }

        if (line == "{" || line == "{,") {
            L = InitLayer();   // layer_index initialised to -1 sentinel
            in_layer = true;
            continue;
        }

        if (in_layer && (line == "}" || line == "},")) {
            // Append to correct array
            if (instrument == INSTRUMENT_EURUSD) {
                int idx = ArraySize(g_inventory_EURUSD);
                ArrayResize(g_inventory_EURUSD, idx + 1);
                g_inventory_EURUSD[idx] = L;
            } else if (instrument == INSTRUMENT_GBPUSD) {
                int idx = ArraySize(g_inventory_GBPUSD);
                ArrayResize(g_inventory_GBPUSD, idx + 1);
                g_inventory_GBPUSD[idx] = L;
            } else {
                int idx = ArraySize(g_inventory_EURGBP);
                ArrayResize(g_inventory_EURGBP, idx + 1);
                g_inventory_EURGBP[idx] = L;
            }
            in_layer = false;
            continue;
        }

        int colon = StringFind(line, ":");
        if (colon < 0) continue;
        string key = StringSubstr(line, 0, colon);
        string val = StringSubstr(line, colon + 1);

        StringReplace(key, "\"", "");
        StringTrimLeft(key);
        StringTrimRight(key);

        StringReplace(val, "\"", "");
        StringTrimLeft(val);
        StringTrimRight(val);
        if (StringLen(val) > 0 &&
            StringGetCharacter(val, StringLen(val) - 1) == ',')
            val = StringSubstr(val, 0, StringLen(val) - 1);

        if (!in_layer) {
            if (key == "pending_bid_ticket") {
                ulong t = (ulong)StringToInteger(val);
                if (instrument == INSTRUMENT_EURUSD)      g_pending_bid_EURUSD   = t;
                else if (instrument == INSTRUMENT_GBPUSD)  g_pending_bid_GBPUSD   = t;
                else                                        g_pending_bid_EURGBP   = t;
            } else if (key == "pending_offer_ticket") {
                ulong t = (ulong)StringToInteger(val);
                if (instrument == INSTRUMENT_EURUSD)      g_pending_offer_EURUSD = t;
                else if (instrument == INSTRUMENT_GBPUSD)  g_pending_offer_GBPUSD = t;
                else                                        g_pending_offer_EURGBP = t;
            } else if (key == "pending_entry_ticket") {
                // Legacy single-ticket schema — restore as bid side
                ulong t = (ulong)StringToInteger(val);
                if (instrument == INSTRUMENT_EURUSD)      g_pending_bid_EURUSD   = t;
                else if (instrument == INSTRUMENT_GBPUSD)  g_pending_bid_GBPUSD   = t;
                else                                        g_pending_bid_EURGBP   = t;
            } else if (key == "add_next_ticket") {
                ulong t = (ulong)StringToInteger(val);
                if (instrument == INSTRUMENT_EURUSD)      g_add_next_EURUSD = t;
                else if (instrument == INSTRUMENT_GBPUSD)  g_add_next_GBPUSD = t;
                else                                        g_add_next_EURGBP = t;
            }
            continue;
        }

        // Layer fields
        if      (key == "layer_index")
            L.layer_index = (int)StringToInteger(val);
        else if (key == "entry_price")
            L.entry_price = StringToDouble(val);
        else if (key == "entry_spread_raw")
            L.entry_spread_raw = StringToDouble(val);
        else if (key == "entry_time")
            L.entry_time = (datetime)StringToInteger(val);
        else if (key == "EU_mid_12bars_ago_at_entry")
            L.EU_mid_12bars_ago_at_entry = StringToDouble(val);
        else if (key == "GB_mid_12bars_ago_at_entry")
            L.GB_mid_12bars_ago_at_entry = StringToDouble(val);
        else if (key == "r_EU_at_entry")
            L.r_EU_at_entry = StringToDouble(val);
        else if (key == "r_GB_at_entry")
            L.r_GB_at_entry = StringToDouble(val);
        else if (key == "strongest_at_entry")
            L.strongest_at_entry = (int)StringToInteger(val);
        else if (key == "weakest_at_entry")
            L.weakest_at_entry = (int)StringToInteger(val);
        else if (key == "entry_price_eurusd")
            L.entry_price_eurusd = StringToDouble(val);
        else if (key == "entry_price_gbpusd")
            L.entry_price_gbpusd = StringToDouble(val);
        else if (key == "entry_price_eurusd_1h")
            L.entry_price_eurusd_1h = StringToDouble(val);
        else if (key == "entry_price_gbpusd_1h")
            L.entry_price_gbpusd_1h = StringToDouble(val);
        else if (key == "instrument")
            L.instrument = (int)StringToInteger(val);
        else if (key == "direction")
            L.direction = (int)StringToInteger(val);
        else if (key == "entry_spread_adjusted")
            L.entry_spread_adjusted = StringToDouble(val);
        else if (key == "entry_price_forward")
            L.entry_price_forward = StringToDouble(val);
        else if (key == "exit_spread_target")
            L.exit_spread_target = StringToDouble(val);
        else if (key == "exit_target")
            L.exit_target = StringToDouble(val);
        else if (key == "add_next")
            L.add_next = StringToDouble(val);
        else if (key == "lot_size")
            L.lot_size = StringToDouble(val);
        else if (key == "remaining_entry_volume")
            L.remaining_entry_volume = StringToDouble(val);
        else if (key == "remaining_exit_volume")
            L.remaining_exit_volume = StringToDouble(val);
        else if (key == "entry_ticket")
            L.entry_ticket = (ulong)StringToInteger(val);
        else if (key == "position_ticket")
            L.position_ticket = (ulong)StringToInteger(val);
        else if (key == "exit_tickets") {
            StringReplace(val, "[", "");
            StringReplace(val, "]", "");
            StringTrimLeft(val);
            StringTrimRight(val);
            ArrayResize(L.exit_tickets, 0);
            if (StringLen(val) > 0) {
                string tickets[];
                int count = StringSplit(val, ',', tickets);
                for (int k = 0; k < count; k++) {
                    StringTrimLeft(tickets[k]);
                    StringTrimRight(tickets[k]);
                    if (StringLen(tickets[k]) > 0) {
                        int tidx = ArraySize(L.exit_tickets);
                        ArrayResize(L.exit_tickets, tidx + 1);
                        L.exit_tickets[tidx] =
                            (ulong)StringToInteger(tickets[k]);
                    }
                }
            }
        }
    }

    FileClose(fh);

    int loaded = 0;
    if (instrument == INSTRUMENT_EURUSD)      loaded = ArraySize(g_inventory_EURUSD);
    else if (instrument == INSTRUMENT_GBPUSD)  loaded = ArraySize(g_inventory_GBPUSD);
    else                                        loaded = ArraySize(g_inventory_EURGBP);

    Print("INFO: LoadInventoryState(", instrument, ") — loaded ",
          loaded, " layers from ", filename);
    return true;
}

void CheckForOrphans() {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        string pos_sym = PositionGetString(POSITION_SYMBOL);
        if (pos_sym != "EURUSD" &&
            pos_sym != "GBPUSD" &&
            pos_sym != "EURGBP") continue;
        if (PositionGetInteger(POSITION_MAGIC) != (long)EA_MAGIC) continue;

        bool found = false;
        int instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};
        for (int k = 0; k < 3 && !found; k++) {
            int inv_size = (instruments[k] == INSTRUMENT_EURUSD)
                           ? ArraySize(g_inventory_EURUSD)
                           : (instruments[k] == INSTRUMENT_GBPUSD)
                             ? ArraySize(g_inventory_GBPUSD)
                             : ArraySize(g_inventory_EURGBP);
            for (int j = 0; j < inv_size; j++) {
                ulong pos_tkt = (instruments[k] == INSTRUMENT_EURUSD)
                                ? g_inventory_EURUSD[j].position_ticket
                                : (instruments[k] == INSTRUMENT_GBPUSD)
                                  ? g_inventory_GBPUSD[j].position_ticket
                                  : g_inventory_EURGBP[j].position_ticket;
                if (pos_tkt == ticket) {
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            Print("ERROR: Orphan position detected — ticket=", ticket,
                  " symbol=", pos_sym,
                  " — EA cannot manage this position. Halting.");
            g_halted = true;
        }
    }
}

#endif // STATE_ENGINE_MQH
