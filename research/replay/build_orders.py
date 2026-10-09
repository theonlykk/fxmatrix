"""build_orders.py -- the replay harness's orders_<seg_id>.csv (fix 2).

The real EA keeps its resting orders across an init (send_logs, 9 Oct: no send in the
minutes after 27 of the 29 window inits; the two others send for a change the init itself
made). The replay adopts the same book: the orders resting at the init, rebuilt from
send_logs and fill_logs (pipshed archive_counts --export-sends / --export-archive):

- send_logs, ok rows only, at ea_time_ms (UTC) + SERVER_OFFSET_MS: PENDING opens
  result_order (side, layer_index, role, requested_price, order_type); MODIFY sets
  order_ticket's price; REMOVE drops order_ticket; CLOSE_BY is not an order;
- fill_logs IN deals drop their order_ticket at deal_time_broker_msc (server ms);
- events strictly before the init count; same-ms events keep their input order;
- an order alive at the init that no PENDING row labels is an error.

Checked on the 9 Oct exports: the rebuilt book's price and label equal every fill's
order_price_open, side, layer and role (B 439, C 461, D 370; B's 4 earlier orders unlabelled,
none alive at a window init).

Header side,layer,role,price,ticket,type (type BUY_LIMIT / SELL_LIMIT); rows L before S,
EXT before ENT, then layer. Standard library only; ascii, LF.
"""
SERVER_OFFSET_MS = 3 * 3600 * 1000
ORDERS_HEADER = "side,layer,role,price,ticket,type"


def _events(rows):
    ev = []
    for k, r in enumerate(rows):
        tab = r.get("table")
        if tab == "send_logs":
            if not r.get("ok"):
                continue
            a = r.get("action")
            if a in ("PENDING", "MODIFY", "REMOVE"):
                ev.append((int(r["ea_time_ms"]) + SERVER_OFFSET_MS, k, a, r))
        elif tab == "fill_logs" and r.get("entry_type") == "IN":
            ev.append((int(r["deal_time_broker_msc"]), k, "FILL", r))
    ev.sort(key=lambda e: (e[0], e[1]))
    return ev


def book_at(rows, at_ms):
    book = {}
    for t, _k, a, r in _events(rows):
        if t >= at_ms:
            break
        if a == "PENDING":
            book[int(r["result_order"])] = {
                "side": r["side"], "layer": int(r["layer_index"]), "role": r["role"],
                "price": float(r["requested_price"]), "ticket": int(r["result_order"]),
                "type": r["order_type"].replace("ORDER_TYPE_", "")}
        elif a == "MODIFY":
            tk = int(r["order_ticket"])
            if tk not in book:
                book[tk] = {"side": None, "layer": None, "role": None, "price": None,
                            "ticket": tk, "type": None}
            book[tk]["price"] = float(r["requested_price"])
        else:   # REMOVE or FILL
            book.pop(int(r["order_ticket"]), None)
    for o in book.values():
        if o["side"] is None:
            raise ValueError("order %d is alive at %d but no PENDING row labels it"
                             % (o["ticket"], at_ms))
    return sorted(book.values(), key=lambda o: (0 if o["side"] == "L" else 1,
                                                0 if o["role"] == "EXT" else 1, o["layer"]))


def to_orders_csv(orders):
    lines = [ORDERS_HEADER] + ["%s,%d,%s,%.5f,%d,%s" % (o["side"], o["layer"], o["role"],
                                                        o["price"], o["ticket"], o["type"])
                               for o in orders]
    return "\n".join(lines) + "\n"


def check_against_seed(orders, seed):
    """Problems with an init's book against its seed (empty = consistent)."""
    layers = {(s["side"], int(s["layer_index"])) for s in seed}
    out = []
    seen_ext = set()
    ents = {}
    for o in orders:
        if o["role"] == "EXT":
            key = (o["side"], int(o["layer"]))
            if key in seen_ext:
                out.append("two EXT orders for %s layer %d" % key)
            seen_ext.add(key)
            if key not in layers:
                out.append("EXT %s layer %d has no seeded layer" % key)
        else:
            ents[o["side"]] = ents.get(o["side"], 0) + 1
    for side in ("L", "S"):
        if ents.get(side, 0) > 1:
            out.append("two ENT orders on %s" % side)
    return out
