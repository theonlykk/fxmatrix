#ifndef STATE_ENGINE_MQH
#define STATE_ENGINE_MQH

#include "Globals.mqh"

string GetStateFilename() {
    return "fxmatrix_state_" + _Symbol + ".json";
}

void SaveInventoryState() {
    string filename = GetStateFilename();
    int fh = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR: SaveInventoryState — FileOpen failed: ", filename);
        return;
    }

    FileWrite(fh, "{");
    FileWrite(fh, "  \"pending_entry_ticket\": " +
              IntegerToString(g_pending_entry_ticket) + ",");
    FileWrite(fh, "  \"inventory\": [");

    int n = ArraySize(g_inventory);
    for (int i = 0; i < n; i++) {
        Layer L = g_inventory[i];
        string comma = (i < n - 1) ? "," : "";

        FileWrite(fh, "    {");
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
        Print("INFO: SaveInventoryState — saved ", n,
              " layers to ", filename);
}

bool LoadInventoryState() {
    string filename = GetStateFilename();
    if (!FileIsExist(filename)) {
        Print("INFO: LoadInventoryState — no state file found. Clean start.");
        return false;
    }

    int fh = FileOpen(filename, FILE_READ | FILE_TXT);
    if (fh == INVALID_HANDLE) {
        Print("ERROR: LoadInventoryState — FileOpen failed: ", filename);
        return false;
    }

    ArrayResize(g_inventory, 0);
    g_pending_entry_ticket = 0;

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
            L = InitLayer();
            in_layer = true;
            continue;
        }

        if (in_layer && (line == "}" || line == "},")) {
            int idx = ArraySize(g_inventory);
            ArrayResize(g_inventory, idx + 1);
            g_inventory[idx] = L;
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
            if (key == "pending_entry_ticket")
                g_pending_entry_ticket = (ulong)StringToInteger(val);
            continue;
        }

        if      (key == "entry_price")
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
    Print("INFO: LoadInventoryState — loaded ",
          ArraySize(g_inventory), " layers from ", filename);
    return true;
}

void CheckForOrphans() {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        bool found = false;
        for (int j = 0; j < ArraySize(g_inventory); j++) {
            if (g_inventory[j].position_ticket == ticket) {
                found = true;
                break;
            }
        }

        if (!found) {
            Print("ERROR: Orphan position detected — ticket=", ticket,
                  " symbol=", _Symbol,
                  " — EA cannot manage this position. Halting.");
            g_halted = true;
        }
    }
}

#endif // STATE_ENGINE_MQH
