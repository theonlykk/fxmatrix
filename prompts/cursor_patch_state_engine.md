# Cursor Patch — New StateEngine.mqh (Inventory State Persistence)
# Gemini Ruling: APPROVED — disk persistence via JSON, StateEngine.mqh,
# terminal-local MQL5\Files\, filename includes _Symbol
# Blue Team: g_pending_entry_ticket also persisted

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## Files to create/modify
- CREATE: `d:\fxmatrix\ea\StateEngine.mqh` (new file)
- MODIFY: `d:\fxmatrix\ea\FXMatrix.mq5` (add #include and OnInit calls)
- MODIFY: `d:\fxmatrix\ea\ExecutionEngine.mqh` (add SaveInventoryState()
  calls at mutation points)

## Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
## or CarryEngine.mqh.

---

## Background

FXMatrix EA wipes g_inventory[] on every reload (network reconnect,
terminal restart, chart timeframe change). In live trading, layers
with pending entry orders can fill after a reload, at which point
g_inventory[] is empty and the EA treats them as fresh Layer 0s,
reading live globals for routing instead of the original pod anchors.

This caused a live failure on 2026.06.08: GBPUSD buy positions
received EURUSD sell exit orders. CloseBy failed with
[Invalid request] across all three affected layers.

Solution: persist g_inventory[] and g_pending_entry_ticket to disk
after every mutation. On OnInit(), hydrate from disk before any
trading logic runs.

---

## PART 1 — CREATE StateEngine.mqh

Create `d:\fxmatrix\ea\StateEngine.mqh` with the following:

### File header
```mql5
#ifndef STATE_ENGINE_MQH
#define STATE_ENGINE_MQH

#include "Globals.mqh"
```

### Filename helper
```mql5
string GetStateFilename() {
    return "fxmatrix_state_" + _Symbol + ".json";
}
```

### SaveInventoryState()

Writes g_inventory[] and g_pending_entry_ticket to
MQL5\Files\fxmatrix_state_{Symbol}.json.

Strict one key-value pair per line. exit_tickets[] written as a
JSON array on one line.

```mql5
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

        // exit_tickets[] as JSON array on one line
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
```

### LoadInventoryState()

Reads the state file and hydrates g_inventory[] and
g_pending_entry_ticket. Returns true if file found and loaded,
false if no file exists (clean start).

Strict line-by-line parser. Splits on first colon only.
Strips whitespace, quotes, commas, brackets.

```mql5
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
```

### Orphan detection helper
```mql5
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
```

### File footer
```mql5
#endif // STATE_ENGINE_MQH
```

---

## PART 2 — MODIFY FXMatrix.mq5

### Change 1 — Add #include for StateEngine.mqh

Find the existing includes at the top of FXMatrix.mq5:

#### BEFORE:
```mql5
#include "ExecutionEngine.mqh"
#include "CarryEngine.mqh"
```

#### AFTER:
```mql5
#include "ExecutionEngine.mqh"
#include "CarryEngine.mqh"
#include "StateEngine.mqh"
```

### Change 2 — Add LoadInventoryState() and CheckForOrphans()
to OnInit(), after InitGlobals() succeeds

Find this block in OnInit():

#### BEFORE:
```mql5
    int result = InitGlobals();
    if (result != INIT_SUCCEEDED) return result;
    return INIT_SUCCEEDED;
```

#### AFTER:
```mql5
    int result = InitGlobals();
    if (result != INIT_SUCCEEDED) return result;

    LoadInventoryState();
    CheckForOrphans();
    if (g_halted) {
        Print("ERROR: OnInit halted — orphan positions detected. "
              "Resolve manually before reattaching EA.");
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
```

---

## PART 3 — MODIFY ExecutionEngine.mqh

Add SaveInventoryState() call at every g_inventory[] mutation point.

### Change 1 — Save after new layer appended in HandleEntryFill()

#### BEFORE:
```mql5
        int new_idx = ArraySize(g_inventory);
        ArrayResize(g_inventory, new_idx + 1);
        g_inventory[new_idx] = L;
        layer_idx = new_idx;

        g_pending_entry_ticket = 0;
```

#### AFTER:
```mql5
        int new_idx = ArraySize(g_inventory);
        ArrayResize(g_inventory, new_idx + 1);
        g_inventory[new_idx] = L;
        layer_idx = new_idx;

        g_pending_entry_ticket = 0;
        SaveInventoryState();
```

### Change 2 — Save after exit_tickets[] updated in HandleEntryFill()

#### BEFORE:
```mql5
        if (exit_tkt > 0) {
            int n = ArraySize(g_inventory[layer_idx].exit_tickets);
            ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
            g_inventory[layer_idx].exit_tickets[n] = exit_tkt;
        }
```

#### AFTER:
```mql5
        if (exit_tkt > 0) {
            int n = ArraySize(g_inventory[layer_idx].exit_tickets);
            ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
            g_inventory[layer_idx].exit_tickets[n] = exit_tkt;
            SaveInventoryState();
        }
```

### Change 3 — Save unconditionally in HandleExitFill() after volume
decrement and ticket removal (covers both partial fills and full closes)

#### BEFORE:
```mql5
                g_inventory[i].remaining_exit_volume -= deal_volume;
                ArrayRemove(g_inventory[i].exit_tickets, j, 1);

                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");
                }
                return;
```

#### AFTER:
```mql5
                g_inventory[i].remaining_exit_volume -= deal_volume;
                ArrayRemove(g_inventory[i].exit_tickets, j, 1);

                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");
                }

                // Save unconditionally: captures both partial volume
                // decrements and full layer removals.
                SaveInventoryState();
                return;
```

### Change 4 — Save after market hedge ticket appended
in Marketable Reversion Exception

#### BEFORE:
```mql5
            int n = ArraySize(g_inventory[layer_idx].exit_tickets);
            ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
            g_inventory[layer_idx].exit_tickets[n] = res.order;

            Print("INFO: Market hedge placed. ticket=", res.order,
                  ". Awaiting CloseBy intercept.");
            return;
```

#### AFTER:
```mql5
            int n = ArraySize(g_inventory[layer_idx].exit_tickets);
            ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
            g_inventory[layer_idx].exit_tickets[n] = res.order;
            SaveInventoryState();

            Print("INFO: Market hedge placed. ticket=", res.order,
                  ". Awaiting CloseBy intercept.");
            return;
```

### Change 5 — Save after g_pending_entry_ticket assigned in
PlaceNextEntryLimit()

Find the block in PlaceNextEntryLimit() where the successful
OrderSend result is returned:

#### BEFORE:
```mql5
    Print("INFO: Next entry limit placed. ticket=", res.order,
          " add_next=", DoubleToString(price, 5));
    return res.order;
```

#### AFTER:
```mql5
    g_pending_entry_ticket = res.order;
    SaveInventoryState();
    Print("INFO: Next entry limit placed. ticket=", res.order,
          " add_next=", DoubleToString(price, 5));
    return res.order;
```

Note: g_pending_entry_ticket must be assigned here so a reload
immediately after order placement knows the pending ticket exists.
Without this, the EA wakes up with g_pending_entry_ticket = 0 and
loses track of the pending order entirely.

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  or CarryEngine.mqh
- Do NOT add SaveInventoryState() calls anywhere other than the
  four mutation points listed above
- Do NOT call LoadInventoryState() anywhere other than OnInit()
- Do NOT call CheckForOrphans() anywhere other than OnInit()
- Do NOT implement a generalized JSON parser — strict line-by-line
  only as specified
- Do NOT use FILE_COMMON flag on FileOpen — terminal-local only
- Do NOT add DDL or schema changes anywhere

---

## Self-Review

Before submitting:
1. Confirm StateEngine.mqh created with GetStateFilename(),
   SaveInventoryState(), LoadInventoryState(), CheckForOrphans()
2. Confirm filename uses _Symbol dynamically
3. Confirm FILE_COMMON not used in FileOpen calls
4. Confirm all 25 Layer fields persisted in SaveInventoryState()
5. Confirm g_pending_entry_ticket persisted
6. Confirm exit_tickets[] serialized as inline JSON array
7. Confirm LoadInventoryState() clears g_inventory[] before hydrating
8. Confirm CheckForOrphans() sets g_halted=true on orphan detection
9. Confirm SaveInventoryState() called at all 5 mutation points:
   - After new layer appended (HandleEntryFill)
   - After exit_tickets[] updated (HandleEntryFill)
   - Unconditionally after volume decrement in HandleExitFill
     (outside VOLUME_EPSILON block — covers partial fills)
   - After market hedge ticket appended (Marketable Reversion)
   - After g_pending_entry_ticket assigned (PlaceNextEntryLimit)
10. Confirm #include StateEngine.mqh added to FXMatrix.mq5
11. Confirm LoadInventoryState() + CheckForOrphans() called in
    OnInit() after InitGlobals()
12. Confirm no other files modified

Line count: 320
