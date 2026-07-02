#ifndef STATE_ENGINE_MQH
#define STATE_ENGINE_MQH

#include "Globals.mqh"

void CancelAllPendingEntries();  // defined in FXMatrix.mq5

//------------------------------------------------------------------
// GetStateFilename (parameterised — Phase 2)
// Returns the correct JSON filename for a given instrument.
//------------------------------------------------------------------
string GetStateFilename(int instrument) {
    string inst_string = (instrument >= 0 && instrument < 3)
                         ? g_symbols[instrument]
                         : "UNKNOWN";
    string filename = "fxmatrix_state_" + inst_string + "_" + InstanceID + ".json";
    return filename;
}

//------------------------------------------------------------------
// GetGlobalStateFilename
// Returns path for the single global state JSON file.
// Scope: one file per EA instance (InstanceID-keyed).
//------------------------------------------------------------------
string GetGlobalStateFilename() {
    return "fxmatrix_global_state_" + InstanceID + ".json";
}

//------------------------------------------------------------------
// SaveGlobalState
// ADR-045: Persists global scalar state to disk.
// Schema is intentionally flat — Phase 3 globals (daily drawdown
// counters, correlated exposure limits) will be added here.
// Called at the end of SaveAllInventoryState().
//------------------------------------------------------------------
void SaveGlobalState() {
    string filename = GetGlobalStateFilename();
    int fh = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR [ADR-045] SaveGlobalState — FileOpen failed: ", filename);
        return;
    }
    FileWrite(fh, "{");
    FileWrite(fh, "  \"last_rollover_day_of_year\": "
              + IntegerToString(g_last_rollover_day_of_year) + ",");
    // Phase 3.A: persist daily state for reboot shield
    FileWrite(fh, "  \"daily_start_balance\": "
              + DoubleToString(g_daily_start_balance, 8) + ",");
    FileWrite(fh, "  \"daily_start_date\": \""
              + g_daily_start_date + "\",");
    FileWrite(fh, "  \"warning_sent\": "
              + (g_warning_sent ? "true" : "false"));
    FileWrite(fh, "}");
    FileClose(fh);
    if (EnableVerboseLog)
        Print("INFO [ADR-045] SaveGlobalState — saved. ",
              "last_rollover_day_of_year=", g_last_rollover_day_of_year,
              " daily_start_balance=", DoubleToString(g_daily_start_balance, 2),
              " daily_start_date=", g_daily_start_date);
}

//------------------------------------------------------------------
// LoadGlobalState
// ADR-045: Restores global scalar state from disk on OnInit().
// Must be called BEFORE LoadInventoryState() calls so global rules
// are established before per-slot inventory is hydrated.
// Returns false on missing file (clean start — value stays 0).
//------------------------------------------------------------------
bool LoadGlobalState() {
    string filename = GetGlobalStateFilename();
    if (!FileIsExist(filename)) {
        Print("INFO [ADR-045] LoadGlobalState — no file found. Clean start.");
        return false;
    }
    int fh = FileOpen(filename, FILE_READ | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR [ADR-045] LoadGlobalState — FileOpen failed: ", filename);
        return false;
    }
    while (!FileIsEnding(fh)) {
        string raw  = FileReadString(fh);
        string line = raw;
        StringTrimLeft(line);
        StringTrimRight(line);
        if (line == "" || line == "{" || line == "}") continue;
        int colon = StringFind(line, ":");
        if (colon < 0) continue;
        string key = StringSubstr(line, 0, colon);
        string val = StringSubstr(line, colon + 1);
        StringReplace(key, "\"", "");
        StringTrimLeft(key);  StringTrimRight(key);
        StringReplace(val, "\"", "");
        StringTrimLeft(val);  StringTrimRight(val);
        if (StringLen(val) > 0 &&
            StringGetCharacter(val, StringLen(val) - 1) == ',')
            val = StringSubstr(val, 0, StringLen(val) - 1);
        if (key == "last_rollover_day_of_year")
            g_last_rollover_day_of_year = (int)StringToInteger(val);
        else if (key == "daily_start_balance")
            g_daily_start_balance = StringToDouble(val);
        else if (key == "daily_start_date")
            g_daily_start_date = val;
        else if (key == "warning_sent")
            g_warning_sent = (val == "true");
    }
    FileClose(fh);
    Print("INFO [ADR-045] LoadGlobalState — loaded. ",
          "last_rollover_day_of_year=", g_last_rollover_day_of_year,
          " daily_start_balance=", DoubleToString(g_daily_start_balance, 2),
          " daily_start_date=", g_daily_start_date);
    return true;
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

    pending_bid_ticket   = g_pending_bid[instrument];
    pending_offer_ticket = g_pending_offer[instrument];
    add_next_ticket_val  = g_add_next[instrument];
    n = (instrument == 0) ? ArraySize(g_inventory_0)
      : (instrument == 1) ? ArraySize(g_inventory_1)
      : ArraySize(g_inventory_2);

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
        if (instrument == 0)      L = g_inventory_0[i];
        else if (instrument == 1) L = g_inventory_1[i];
        else                      L = g_inventory_2[i];

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
        FileWrite(fh, "      \"anchor_A_at_entry\": "
                  + DoubleToString(L.anchor_A_at_entry, 8) + ",");
        FileWrite(fh, "      \"anchor_B_at_entry\": "
                  + DoubleToString(L.anchor_B_at_entry, 8) + ",");
        FileWrite(fh, "      \"r_AC_at_entry\": "
                  + DoubleToString(L.r_AC_at_entry, 8) + ",");
        FileWrite(fh, "      \"r_BC_at_entry\": "
                  + DoubleToString(L.r_BC_at_entry, 8) + ",");
        FileWrite(fh, "      \"strongest_at_entry\": "
                  + IntegerToString(L.strongest_at_entry) + ",");
        FileWrite(fh, "      \"weakest_at_entry\": "
                  + IntegerToString(L.weakest_at_entry) + ",");
        FileWrite(fh, "      \"entry_price_AC\": "
                  + DoubleToString(L.entry_price_AC, 8) + ",");
        FileWrite(fh, "      \"entry_price_BC\": "
                  + DoubleToString(L.entry_price_BC, 8) + ",");
        FileWrite(fh, "      \"entry_price_AC_1h\": "
                  + DoubleToString(L.entry_price_AC_1h, 8) + ",");
        FileWrite(fh, "      \"entry_price_BC_1h\": "
                  + DoubleToString(L.entry_price_BC_1h, 8) + ",");
        FileWrite(fh, "      \"instrument\": "
                  + IntegerToString(L.instrument) + ",");
        FileWrite(fh, "      \"direction\": "
                  + IntegerToString(L.direction) + ",");
        FileWrite(fh, "      \"entry_spread_adjusted\": "
                  + DoubleToString(L.entry_spread_adjusted, 8) + ",");
        FileWrite(fh, "      \"entry_price_forward\": "
                  + DoubleToString(L.entry_price_forward, 8) + ",");
        FileWrite(fh, "      \"exit_target\": "
                  + DoubleToString(L.exit_target, 8) + ",");
        FileWrite(fh, "      \"exit_price_fixed\": "
                  + DoubleToString(L.exit_price_fixed, 8) + ",");
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
    SaveInventoryState(SLOT_AC);
    SaveInventoryState(SLOT_BC);
    SaveInventoryState(SLOT_AB);
    SaveGlobalState();  // ADR-045: persist global scalars after all slots saved
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
    if (instrument == 0)      ArrayResize(g_inventory_0, 0);
    else if (instrument == 1) ArrayResize(g_inventory_1, 0);
    else                      ArrayResize(g_inventory_2, 0);
    g_pending_bid[instrument]   = 0;
    g_pending_offer[instrument] = 0;
    g_add_next[instrument]      = 0;

    Layer L = InitLayer();
    bool in_layer     = false;
    bool in_inventory = false;

    while (!FileIsEnding(fh)) {
        string raw  = FileReadString(fh);
        string line = raw;

        StringTrimLeft(line);
        StringTrimRight(line);

        if (line == "") continue;
        if (!in_inventory && (line == "{" || line == "}")) continue;

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
            // Append to correct slot array
            if (instrument == 0) {
                int idx = ArraySize(g_inventory_0);
                ArrayResize(g_inventory_0, idx + 1);
                g_inventory_0[idx] = L;
            } else if (instrument == 1) {
                int idx = ArraySize(g_inventory_1);
                ArrayResize(g_inventory_1, idx + 1);
                g_inventory_1[idx] = L;
            } else {
                int idx = ArraySize(g_inventory_2);
                ArrayResize(g_inventory_2, idx + 1);
                g_inventory_2[idx] = L;
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
                g_pending_bid[instrument] = (ulong)StringToInteger(val);
            } else if (key == "pending_offer_ticket") {
                g_pending_offer[instrument] = (ulong)StringToInteger(val);
            } else if (key == "pending_entry_ticket") {
                // Legacy single-ticket schema — restore as bid side
                g_pending_bid[instrument] = (ulong)StringToInteger(val);
            } else if (key == "add_next_ticket") {
                g_add_next[instrument] = (ulong)StringToInteger(val);
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
        else if (key == "anchor_A_at_entry")
            L.anchor_A_at_entry = StringToDouble(val);
        else if (key == "anchor_B_at_entry")
            L.anchor_B_at_entry = StringToDouble(val);
        else if (key == "r_AC_at_entry")
            L.r_AC_at_entry = StringToDouble(val);
        else if (key == "r_BC_at_entry")
            L.r_BC_at_entry = StringToDouble(val);
        else if (key == "strongest_at_entry")
            L.strongest_at_entry = (int)StringToInteger(val);
        else if (key == "weakest_at_entry")
            L.weakest_at_entry = (int)StringToInteger(val);
        else if (key == "entry_price_AC")
            L.entry_price_AC = StringToDouble(val);
        else if (key == "entry_price_BC")
            L.entry_price_BC = StringToDouble(val);
        else if (key == "entry_price_AC_1h")
            L.entry_price_AC_1h = StringToDouble(val);
        else if (key == "entry_price_BC_1h")
            L.entry_price_BC_1h = StringToDouble(val);
        else if (key == "instrument")
            L.instrument = (int)StringToInteger(val);
        else if (key == "direction")
            L.direction = (int)StringToInteger(val);
        else if (key == "entry_spread_adjusted")
            L.entry_spread_adjusted = StringToDouble(val);
        else if (key == "entry_price_forward")
            L.entry_price_forward = StringToDouble(val);
        else if (key == "exit_target")
            L.exit_target = StringToDouble(val);
        else if (key == "exit_price_fixed")
            L.exit_price_fixed = StringToDouble(val);
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

    int loaded = (instrument == 0) ? ArraySize(g_inventory_0)
               : (instrument == 1) ? ArraySize(g_inventory_1)
               : ArraySize(g_inventory_2);

    Print("INFO: LoadInventoryState(", instrument, ") — loaded ",
          loaded, " layers from ", filename);
    return true;
}

//------------------------------------------------------------------
// PurgeClosedLayers — ADR-074 Tier 3 selective inventory purge
// Removes only layers whose position_ticket is confirmed closed.
// Stranded (still-open) layers remain for ADR-040 OnInit reconciliation.
// Layer &inv[] reference: mutates caller's global array in place via
// ArrayRemove() — standard MQL5 dynamic-array reference semantics.
//------------------------------------------------------------------
void PurgeClosedLayers(Layer &inv[], ulong &attempted[], bool &still_open_flags[]) {
    for (int i = ArraySize(inv) - 1; i >= 0; i--) {
        ulong pos_tkt = inv[i].position_ticket;
        bool purge = true;

        if (pos_tkt == 0) {
            purge = true;
        } else {
            bool found = false;
            for (int t = 0; t < ArraySize(attempted); t++) {
                if (attempted[t] == pos_tkt) {
                    found = true;
                    purge = !still_open_flags[t];
                    break;
                }
            }
            if (!found) {
                purge = !PositionSelectByTicket(pos_tkt);
            }
        }

        if (purge) ArrayRemove(inv, i, 1);
    }
}

//------------------------------------------------------------------
// ExecuteSystemSweep — ADR-074 / ADR-075
// Parameterized institutional sweep. target_instrument = -1: full
// Tier 3 sweep (all symbols, halt, detach). 0/1/2: scoped Tier 1
// pod amputation (single symbol, no detach).
//------------------------------------------------------------------
void ExecuteSystemSweep(int target_instrument = -1) {
    bool full_sweep = (target_instrument == -1);

    ulong close_attempted[];
    int total_pos = PositionsTotal();
    for (int i = total_pos - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0) continue;
        string pos_sym = PositionGetString(POSITION_SYMBOL);
        if (full_sweep) {
            if (pos_sym != g_symbols[SLOT_AC] &&
                pos_sym != g_symbols[SLOT_BC] &&
                pos_sym != g_symbols[SLOT_AB]) continue;
        } else {
            if (pos_sym != GetInstrumentSymbol(target_instrument)) continue;
        }
        long pos_magic = PositionGetInteger(POSITION_MAGIC);
        if (pos_magic != (long)EA_MAGIC &&
            pos_magic != (long)(EA_MAGIC + 1) &&
            pos_magic != (long)(EA_MAGIC + 2)) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action   = TRADE_ACTION_DEAL;
        req.position = ticket;
        req.symbol   = pos_sym;
        req.volume   = PositionGetDouble(POSITION_VOLUME);
        req.type     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                       ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        req.price    = (req.type == ORDER_TYPE_SELL)
                       ? SymbolInfoDouble(pos_sym, SYMBOL_BID)
                       : SymbolInfoDouble(pos_sym, SYMBOL_ASK);
        req.type_filling = ORDER_FILLING_IOC;
        req.comment  = full_sweep ? "FXMatrix_CircuitBreaker"
                                  : "FXMatrix_PodAmputation";

        if (!OrderSend(req, res))
            Print("WARNING [Phase3A] Emergency close send failed. ",
                  "ticket=", ticket, " magic=", pos_magic,
                  " retcode=", res.retcode);

        int idx = ArraySize(close_attempted);
        ArrayResize(close_attempted, idx + 1);
        close_attempted[idx] = ticket;
    }

    if (full_sweep) {
        CancelAllPendingEntries();

        for (int _i = OrdersTotal() - 1; _i >= 0; _i--) {
            ulong _tkt = OrderGetTicket(_i);
            if (_tkt == 0) continue;
            long _m = OrderGetInteger(ORDER_MAGIC);
            if (_m != (long)EA_MAGIC &&
                _m != (long)(EA_MAGIC + 1) &&
                _m != (long)(EA_MAGIC + 2)) continue;
            MqlTradeRequest _req = {};
            MqlTradeResult  _res = {};
            _req.action = TRADE_ACTION_REMOVE;
            _req.order  = _tkt;
            if (!OrderSend(_req, _res))
                Print("WARNING [Phase3A] Cancel failed. ticket=", _tkt,
                      " retcode=", _res.retcode);
        }
    } else {
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            ulong ticket = OrderGetTicket(i);
            if (ticket == 0) continue;
            if (OrderGetString(ORDER_SYMBOL) != GetInstrumentSymbol(target_instrument)) continue;
            long order_magic = OrderGetInteger(ORDER_MAGIC);
            if (order_magic != (long)EA_MAGIC &&
                order_magic != (long)(EA_MAGIC + 1) &&
                order_magic != (long)(EA_MAGIC + 2)) continue;

            MqlTradeRequest req = {};
            MqlTradeResult  res = {};
            req.action = TRADE_ACTION_REMOVE;
            req.order  = ticket;
            if (!OrderSend(req, res))
                Print("WARNING [Tier1] Scoped cancel failed. ticket=", ticket,
                      " retcode=", res.retcode);
        }
    }

    bool still_open[];
    ArrayResize(still_open, ArraySize(close_attempted));
    for (int k = 0; k < ArraySize(still_open); k++) still_open[k] = true;

    for (int poll = 0; poll < 5; poll++) {
        bool any_still_open = false;
        for (int t = 0; t < ArraySize(close_attempted); t++) {
            if (!still_open[t]) continue;
            if (!PositionSelectByTicket(close_attempted[t]))
                still_open[t] = false;
            else
                any_still_open = true;
        }
        if (!any_still_open) break;
        Sleep(50);
    }

    for (int t = 0; t < ArraySize(close_attempted); t++) {
        if (!still_open[t]) continue;
        string alert_msg = StringFormat(
            "CRITICAL: Tier 3 Sweep Failure. Stranded position ticket=%I64u",
            close_attempted[t]);
        Print(alert_msg);
        g_critical_alerts[g_critical_alert_write_idx] = alert_msg;
        g_critical_alert_write_idx = (g_critical_alert_write_idx + 1) % CRITICAL_ALERT_BUFFER_SIZE;
    }

    if (!full_sweep) {
        g_pending_bid[target_instrument]   = 0;
        g_pending_offer[target_instrument] = 0;
        g_add_next[target_instrument]      = 0;
    }

    if (full_sweep) {
        PurgeClosedLayers(g_inventory_0, close_attempted, still_open);
        PurgeClosedLayers(g_inventory_1, close_attempted, still_open);
        PurgeClosedLayers(g_inventory_2, close_attempted, still_open);
    } else {
        if (target_instrument == 0)      PurgeClosedLayers(g_inventory_0, close_attempted, still_open);
        else if (target_instrument == 1) PurgeClosedLayers(g_inventory_1, close_attempted, still_open);
        else                             PurgeClosedLayers(g_inventory_2, close_attempted, still_open);
    }

    SaveAllInventoryState();

    if (full_sweep) {
        g_halted = true;
        ExpertRemove();
    }
}

void CheckForOrphans() {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        string pos_sym = PositionGetString(POSITION_SYMBOL);

        // Filter: only check positions on our configured triad symbols
        if (pos_sym != g_symbols[SLOT_AC] &&
            pos_sym != g_symbols[SLOT_BC] &&
            pos_sym != g_symbols[SLOT_AB]) continue;
        // F4 fix: check all EA magic variants.
        // EA_MAGIC   = flat-quote entry positions
        // EA_MAGIC+1 = deep add-next layer positions
        // EA_MAGIC+2 = hedge/exit positions
        // All three must be inspected — blind spots in +1/+2 leave
        // unmanaged deep-grid and hedge positions after blackout/reboot.
        long pos_magic = PositionGetInteger(POSITION_MAGIC);
        if (pos_magic != (long)EA_MAGIC &&
            pos_magic != (long)(EA_MAGIC + 1) &&
            pos_magic != (long)(EA_MAGIC + 2)) continue;

        bool found = false;
        for (int k = 0; k < 3 && !found; k++) {
            int inv_size = (k == 0) ? ArraySize(g_inventory_0)
                         : (k == 1) ? ArraySize(g_inventory_1)
                         : ArraySize(g_inventory_2);
            for (int j = 0; j < inv_size; j++) {
                ulong pos_tkt = (k == 0) ? g_inventory_0[j].position_ticket
                              : (k == 1) ? g_inventory_1[j].position_ticket
                              : g_inventory_2[j].position_ticket;
                if (pos_tkt == ticket) {
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            // ADR-054: Verify position is still open before halting.
            // CloseBy transient positions appear briefly as untracked
            // then settle — a re-check prevents spurious halts on
            // broker-side settlement lag.
            // Re-select the position ticket to confirm it still exists.
            if (!PositionSelectByTicket(ticket)) {
                // Position already closed/settled — not a real orphan
                Print("INFO [ADR-054] Transient position already closed. ",
                      "ticket=", ticket, " symbol=", pos_sym,
                      " — skipping orphan halt.");
                continue;
            }
            // Position still open and untracked — genuine orphan
            Print("ERROR: Orphan position detected — ticket=", ticket,
                  " symbol=", pos_sym,
                  " — EA cannot manage this position. Halting.");
            g_halted = true;
        }
    }
}

//------------------------------------------------------------------
// CheckDirectionConsistency — ADR-014 / ADR-071
// Periodic (OnTimer, 5s) reconciliation: for every layer with a
// live position_ticket, confirm the broker's POSITION_TYPE matches
// Layer.direction. A mismatch means the EA's belief about which
// way it is positioned is WRONG -- it cannot be trusted to place
// or manage exits correctly on that symbol. This is DETECTION
// ONLY; it does not alter trade placement logic.
//
// Comparison is done via explicit boolean normalization, NOT direct
// integer comparison -- DIRECTION_BUY (=1) and POSITION_TYPE_BUY
// (=0) are different, incompatible enum domains. A direct integer
// compare would silently and permanently misfire on every long
// position. See ADR-071 for the full investigation.
//------------------------------------------------------------------
void CheckDirectionConsistency() {
    for (int k = 0; k < 3; k++) {
        int inv_size = (k == 0) ? ArraySize(g_inventory_0)
                     : (k == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        for (int j = 0; j < inv_size; j++) {
            ulong pos_tkt = (k == 0) ? g_inventory_0[j].position_ticket
                          : (k == 1) ? g_inventory_1[j].position_ticket
                          : g_inventory_2[j].position_ticket;

            if (pos_tkt == 0) continue;  // nothing to verify

            if (!PositionSelectByTicket(pos_tkt)) continue;  // closed/stale -- not a mismatch

            int layer_dir = (k == 0) ? g_inventory_0[j].direction
                          : (k == 1) ? g_inventory_1[j].direction
                          : g_inventory_2[j].direction;

            bool is_layer_buy  = (layer_dir == DIRECTION_BUY);
            bool is_broker_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

            if (is_layer_buy != is_broker_buy) {
                string alert_msg = StringFormat(
                    "CRITICAL: ADR-014 Direction Mismatch. ticket=%I64u slot=%d layer_believed=%s broker_actual=%s",
                    pos_tkt, k,
                    is_layer_buy ? "BUY" : "SELL",
                    is_broker_buy ? "BUY" : "SELL"
                );

                Print(alert_msg);

                // Push to circular alert buffer BEFORE halting/removing,
                // since ExpertRemove() ends event processing immediately.
                g_critical_alerts[g_critical_alert_write_idx] = alert_msg;
                g_critical_alert_write_idx = (g_critical_alert_write_idx + 1) % CRITICAL_ALERT_BUFFER_SIZE;

                g_halted = true;
                ExpertRemove();
                return;  // stop scanning -- EA is being removed
            }
        }
    }
}

#endif // STATE_ENGINE_MQH
