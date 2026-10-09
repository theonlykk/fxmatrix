"""Tests for build_orders.py (hand-derived; run: python -B -m unittest test_build_orders).

orders_<seg_id>.csv (fix 2): the EA's own resting orders at a segment's init, which the real
EA keeps across an init (no send in the minutes after 27 of the 29 inits; send_logs, 9 Oct).
Rebuilt from send_logs (ok rows only: PENDING opens result_order with its side, layer, role,
requested_price and order_type; MODIFY sets order_ticket's price; REMOVE drops it) and
fill_logs (an IN deal drops its order_ticket at deal_time_broker_msc). Send times are
ea_time_ms (UTC) + 10,800,000 (server). An order alive at the init that no PENDING row
labels is an error. Header side,layer,role,price,ticket,type; rows L before S, EXT before
ENT, then layer.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_orders as bo  # noqa: E402

OFF = 10_800_000
T = 1791000000000   # a server ms


def send(action, srv_ms, ok=True, **kw):
    r = {"table": "send_logs", "action": action, "ea_time_ms": srv_ms - OFF, "ok": ok,
         "order_ticket": None, "result_order": None, "side": None, "layer_index": None,
         "role": None, "requested_price": None, "order_type": None}
    r.update(kw)
    return r


def place(srv_ms, ticket, side, layer, role, price, otype, ok=True):
    return send("PENDING", srv_ms, ok=ok, result_order=ticket, side=side, layer_index=layer,
                role=role, requested_price=price, order_type=otype)


def fill(order, srv_ms, deal=1):
    return {"table": "fill_logs", "entry_type": "IN", "order_ticket": order, "deal_ticket": deal,
            "deal_time_broker_msc": srv_ms}


class TestBook(unittest.TestCase):
    def test_place_modify_remove_fill(self):
        rows = [
            place(T + 1, 11, "L", 2, "EXT", 1.10100, "ORDER_TYPE_SELL_LIMIT"),
            place(T + 2, 12, "S", 0, "ENT", 1.10500, "ORDER_TYPE_SELL_LIMIT"),
            place(T + 3, 13, "L", 3, "ENT", 1.09900, "ORDER_TYPE_BUY_LIMIT"),
            send("MODIFY", T + 4, order_ticket=11, requested_price=1.10108),
            send("MODIFY", T + 5, ok=False, order_ticket=12, requested_price=1.2),
            send("REMOVE", T + 6, order_ticket=13),
            place(T + 7, 14, "S", 1, "EXT", 1.10400, "ORDER_TYPE_BUY_LIMIT"),
            fill(14, T + 8),
            send("CLOSE_BY", T + 9),
            place(T + 10, 15, "L", 3, "ENT", 1.09800, "ORDER_TYPE_BUY_LIMIT", ok=False),
        ]
        got = bo.book_at(rows, T + 20)
        self.assertEqual(got, [
            {"side": "L", "layer": 2, "role": "EXT", "price": 1.10108, "ticket": 11,
             "type": "SELL_LIMIT"},
            {"side": "S", "layer": 0, "role": "ENT", "price": 1.10500, "ticket": 12,
             "type": "SELL_LIMIT"}])

    def test_strictly_before_the_init(self):
        rows = [place(T, 11, "L", 0, "ENT", 1.1, "ORDER_TYPE_BUY_LIMIT"),
                send("REMOVE", T + 5, order_ticket=11)]
        self.assertEqual([o["ticket"] for o in bo.book_at(rows, T + 5)], [11])
        self.assertEqual(bo.book_at(rows, T + 6), [])
        self.assertEqual(bo.book_at(rows, T), [])
        # a fill at the init's own ms has not happened yet either
        rows2 = [place(T, 11, "L", 0, "ENT", 1.1, "ORDER_TYPE_BUY_LIMIT"), fill(11, T + 5)]
        self.assertEqual([o["ticket"] for o in bo.book_at(rows2, T + 5)], [11])

    def test_same_ms_order(self):
        # a REMOVE and a PLACE in the same ms (the EA replaces an exit): the new one stays.
        rows = [place(T, 11, "L", 1, "EXT", 1.1, "ORDER_TYPE_SELL_LIMIT"),
                send("REMOVE", T + 3, order_ticket=11),
                place(T + 3, 12, "L", 1, "EXT", 1.2, "ORDER_TYPE_SELL_LIMIT")]
        self.assertEqual([o["ticket"] for o in bo.book_at(rows, T + 4)], [12])
        # a PLACE and a MODIFY of the same order in one ms apply in their input order
        rows = [place(T, 11, "L", 1, "EXT", 1.1, "ORDER_TYPE_SELL_LIMIT"),
                send("MODIFY", T, order_ticket=11, requested_price=1.10008)]
        self.assertEqual([o["price"] for o in bo.book_at(rows, T + 1)], [1.10008])

    def test_only_in_deals_fill_an_order(self):
        rows = [place(T, 11, "L", 1, "EXT", 1.1, "ORDER_TYPE_SELL_LIMIT"),
                dict(fill(11, T + 2), entry_type="OUT_BY")]
        self.assertEqual([o["ticket"] for o in bo.book_at(rows, T + 3)], [11])

    def test_order_of_rows(self):
        rows = [place(T + 1, 21, "S", 2, "ENT", 1.2, "ORDER_TYPE_SELL_LIMIT"),
                place(T + 2, 22, "S", 1, "EXT", 1.1, "ORDER_TYPE_BUY_LIMIT"),
                place(T + 3, 23, "L", 5, "EXT", 1.3, "ORDER_TYPE_SELL_LIMIT"),
                place(T + 4, 24, "L", 2, "EXT", 1.3, "ORDER_TYPE_SELL_LIMIT"),
                place(T + 5, 25, "L", 1, "ENT", 1.0, "ORDER_TYPE_BUY_LIMIT")]
        self.assertEqual([o["ticket"] for o in bo.book_at(rows, T + 9)], [24, 23, 25, 22, 21])

    def test_unlabelled_order_is_an_error(self):
        rows = [send("MODIFY", T, order_ticket=77, requested_price=1.1)]
        with self.assertRaises(ValueError):
            bo.book_at(rows, T + 1)
        # ...unless it is gone by the init
        rows.append(fill(77, T + 2))
        self.assertEqual(bo.book_at(rows, T + 3), [])

    def test_csv(self):
        orders = [{"side": "L", "layer": 2, "role": "EXT", "price": 1.10108, "ticket": 11,
                   "type": "SELL_LIMIT"}]
        self.assertEqual(bo.to_orders_csv(orders),
                         "side,layer,role,price,ticket,type\nL,2,EXT,1.10108,11,SELL_LIMIT\n")
        self.assertEqual(bo.to_orders_csv([]), "side,layer,role,price,ticket,type\n")


class TestCheck(unittest.TestCase):
    def test_exits_need_a_seeded_layer(self):
        seed = [{"side": "L", "layer_index": 2}, {"side": "S", "layer_index": 0}]
        ok = [{"side": "L", "layer": 2, "role": "EXT"}, {"side": "S", "layer": 1, "role": "ENT"}]
        self.assertEqual(bo.check_against_seed(ok, seed), [])
        bad = [{"side": "S", "layer": 2, "role": "EXT"}]
        self.assertEqual(bo.check_against_seed(bad, seed),
                         ["EXT S layer 2 has no seeded layer"])
        dup = [{"side": "L", "layer": 2, "role": "EXT"}, {"side": "L", "layer": 2, "role": "EXT"}]
        self.assertEqual(bo.check_against_seed(dup, seed), ["two EXT orders for L layer 2"])
        two_ent = [{"side": "L", "layer": 3, "role": "ENT"}, {"side": "L", "layer": 4, "role": "ENT"}]
        self.assertEqual(bo.check_against_seed(two_ent, seed), ["two ENT orders on L"])


if __name__ == "__main__":
    unittest.main()
