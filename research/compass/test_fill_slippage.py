"""Tests for fill_slippage.py (C132). Expected values derived by hand."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compass_score as cs  # noqa: E402
import fill_slippage as fs  # noqa: E402

OFF = 10800


def T(text):
    return cs.utc(text)


def msc(t):
    return int((t + OFF) * 1000)


def fill(inst, side, t, slip, role="ENT", entry="IN", deal=1, order=2):
    return {"table": "fill_logs", "instance_id": inst, "side": side, "role": role,
            "entry_type": entry, "slippage_pips": slip, "deal_ticket": deal,
            "order_ticket": order, "deal_price": 1.1, "order_price_open": 1.1,
            "deal_time_broker_msc": msc(t)}


W = [(T("2026-10-06T22:00Z"), T("2026-10-07T22:00Z"), 1)]


class TestParse(unittest.TestCase):
    def test_SL1_fleet_and_pair(self):
        self.assertEqual(fs.fleet_of("GRIND_EURUSD_OPTB"), "B")
        self.assertEqual(fs.fleet_of("GRIND_EURUSD_OPTC"), "C")
        self.assertEqual(fs.fleet_of("GRIND_EURUSD_OPTD"), "D")
        self.assertEqual(fs.fleet_of("GRIND_EURUSD_OPT"), "A")
        self.assertEqual(fs.fleet_of("GRIND_AUDNZD_ALT"), "A")
        self.assertEqual(fs.pair_of("GRIND_EURGBP_OPTC"), "EURGBP")
        self.assertEqual(fs.pair_of("GRIND_AUDNZD_ALTB"), "AUDNZD")


class TestEntryFills(unittest.TestCase):
    def test_SL2_utc_from_server_clock(self):
        t = T("2026-10-07T03:00Z")
        f = fs.entry_fills([fill("GRIND_GBPUSD_OPTB", "L", t, 0.1)])
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0]["t"], t)
        self.assertEqual((f[0]["fleet"], f[0]["pair"], f[0]["side"], f[0]["slip"]),
                         ("B", "GBPUSD", "L", 0.1))

    def test_SL3_only_entry_fills_with_a_number(self):
        t = T("2026-10-07T03:00Z")
        rows = [fill("GRIND_GBPUSD_OPTB", "L", t, 0.1),
                fill("GRIND_GBPUSD_OPTB", "L", t, 0.3, role="EXT"),
                fill("GRIND_GBPUSD_OPTB", "L", t, None),
                fill("GRIND_GBPUSD_OPTB", "L", t, 0.2, role=None, entry="OUT_BY"),
                {"table": "scalp_history", "instance_id": "GRIND_GBPUSD_OPTB"}]
        self.assertEqual([x["slip"] for x in fs.entry_fills(rows)], [0.1])

    def test_SL4_fleet_filter_leaves_out_A(self):
        t = T("2026-10-07T03:00Z")
        rows = [fill("GRIND_GBPUSD_OPT", "L", t, 0.1), fill("GRIND_GBPUSD_OPTD", "S", t, -0.2)]
        self.assertEqual([x["fleet"] for x in fs.entry_fills(rows)], ["D"])
        self.assertEqual(sorted(x["fleet"] for x in fs.entry_fills(rows, fleets=("A", "D"))),
                         ["A", "D"])


class TestStats(unittest.TestCase):
    def test_SL5_window_start_in_end_out(self):
        a, b, _ = W[0]
        self.assertTrue(fs.in_windows(a, W))
        self.assertTrue(fs.in_windows(b - 1, W))
        self.assertFalse(fs.in_windows(b, W))
        self.assertFalse(fs.in_windows(a - 1, W))

    def test_SL6_stats_by_hand(self):
        s = fs.stats([0.5, -0.2, 0.0, -1.0])
        self.assertEqual(s["n"], 4)
        self.assertAlmostEqual(s["mean"], -0.175)      # (0.5 - 0.2 + 0 - 1.0) / 4
        self.assertAlmostEqual(s["median"], -0.1)      # (-0.2 + 0.0) / 2
        self.assertAlmostEqual(s["worse"], 0.5)        # -0.2 and -1.0
        self.assertAlmostEqual(s["worse_half"], 0.25)  # only -1.0 is below -0.5
        self.assertAlmostEqual(s["worst"], -1.0)
        self.assertEqual(fs.stats([])["n"], 0)

    def test_SL7_table_groups_by_pair_side_fleet_inside_windows(self):
        t_in = T("2026-10-07T03:00Z")
        t_out = T("2026-10-06T21:59Z")
        rows = [fill("GRIND_EURGBP_OPTC", "L", t_in, -0.5),
                fill("GRIND_EURGBP_OPTC", "L", t_in, 0.1),
                fill("GRIND_EURGBP_OPTC", "S", t_in, 0.2),
                fill("GRIND_EURGBP_OPTB", "L", t_in, 0.0),
                fill("GRIND_EURGBP_OPTC", "L", t_out, -9.0)]
        tab = fs.table(fs.entry_fills(rows), W)
        self.assertEqual(sorted(tab), [("EURGBP", "L", "B"), ("EURGBP", "L", "C"),
                                       ("EURGBP", "S", "C")])
        self.assertEqual(tab[("EURGBP", "L", "C")]["n"], 2)
        self.assertAlmostEqual(tab[("EURGBP", "L", "C")]["mean"], -0.2)
        self.assertAlmostEqual(tab[("EURGBP", "L", "C")]["worst"], -0.5)

    def test_SL8_outliers_below_threshold_worst_first(self):
        t = T("2026-10-07T03:00Z")
        rows = [fill("GRIND_EURUSD_OPTB", "L", t, -5.0, deal=11),
                fill("GRIND_EURUSD_OPTB", "L", t, -12.4, deal=12),
                fill("GRIND_EURUSD_OPTB", "L", t, -6.1, deal=13),
                fill("GRIND_EURUSD_OPTB", "L", T("2026-10-08T03:00Z"), -20.0, deal=14)]
        out = fs.outliers(fs.entry_fills(rows), W, below=-5.0)
        self.assertEqual([x["deal"] for x in out], [12, 13])


if __name__ == "__main__":
    unittest.main()
