"""C125 T3 driver tests: every expected value derived by hand in the comments."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import holdout_t3 as h  # noqa: E402
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ejection_value"))
import ev_book  # noqa: E402

T0 = 1000000.0
T1 = T0 + 5 * 86400


def lay(instance, pid, side, open_t, open_price, close_t=None, net=None):
    l = ev_book.Layer(instance, pid)
    l.side, l.open_t, l.open_price, l.close_t = side, open_t, open_price, close_t
    l.open_commission = 0.0
    if close_t is not None:
        l.closeby_net = net
    return l


def book(*ls):
    out = {}
    for l in ls:
        out.setdefault(l.instance, {})[l.position_id] = l
    return out


class TestRealised(unittest.TestCase):
    def test_H1_closed_inside_the_window_both_sides(self):
        # +1.20 (long) and -0.50 (short) close inside; +9.00 closed before T0; one still open: 0.70
        i = "GRIND_GBPUSD_OPTB"
        L = book(lay(i, 1, "L", T0 - 100, 1.3, T0 + 10, 1.20), lay(i, 2, "S", T0 - 50, 1.3, T0 + 20, -0.50),
                 lay(i, 3, "L", T0 - 900, 1.3, T0 - 10, 9.00), lay(i, 4, "L", T0 + 30, 1.3))
        self.assertAlmostEqual(h.realised(L, i, T0, T1), 0.70, places=9)
        self.assertAlmostEqual(h.realised(L, "GRIND_NONE_OPTB", T0, T1), 0.0, places=9)


class TestMark(unittest.TestCase):
    def test_H2_mid_marks_in_usd(self):
        # GBPUSD long at 1.30000, mid (1.30090 + 1.30110) / 2 = 1.30100: +0.00100 x 100000 x 0.01 = +1.00
        # EURGBP short at 0.85000, mid 0.85050, GBP at 1.30100: -0.00050 x 1000 x 1.301 = -0.6505
        # a layer with no open price is not marked and is counted (1); a closed one is not open
        bars = {"GBPUSD": ([T0], [1.30090], [1.30110]), "EURGBP": ([T0], [0.85045], [0.85055])}
        L = book(lay("GRIND_GBPUSD_OPT", 1, "L", T0 - 60, 1.30000),
                 lay("GRIND_EURGBP_OPT", 2, "S", T0 - 60, 0.85000),
                 lay("GRIND_EURGBP_OPT", 3, "S", None, None),
                 lay("GRIND_EURGBP_OPT", 4, "L", T0 - 60, 0.85000, T0 - 1, 0.1))
        v, n = h.mtm_mid(L, "GRIND_GBPUSD_OPT", T0 + 30, bars)
        self.assertAlmostEqual(v, 1.00, places=9)
        self.assertEqual(n, 0)
        v, n = h.mtm_mid(L, "GRIND_EURGBP_OPT", T0 + 30, bars)
        self.assertAlmostEqual(v, -0.6505, places=9)
        self.assertEqual(n, 1)


def fleet_book(nets_rev, nets_trend, slot, t):
    """One closed layer per instance with the given nets, closed at t."""
    ls = []
    pid = 0
    for pairs, nets in ((h.REVERTING, nets_rev), (h.TRENDING, nets_trend)):
        for pair, n in zip(pairs, nets):
            if n is None:
                continue
            pid += 1
            ls.append(lay(h.inst(pair, slot), pid, "L", t - 60, 1.0, t, n))
    return ls


class TestT3(unittest.TestCase):
    W = ("1970-01-12T13:46Z", "1970-01-17T13:46Z", 5)    # = T0 .. T1 (1,000,000 s is 1970-01-12T13:46:40Z)
    M = ("1970-01-12T14:00Z", "1970-01-17T13:00Z")

    def build(self, rev_by_fleet):
        t = T0 + 7200
        ls = []
        trend = {"A": (-1.0, None, None), "B": (-0.5, -0.5, -0.5), "C": (0.0, 0.0, 0.0), "D": (0.0, 0.0, 0.0)}
        for f, slot in h.FLEETS:
            ls += fleet_book(rev_by_fleet[f], trend[f], slot, t)
        return book(*ls)

    def test_H3_t3a_three_of_four(self):
        # reverting group per fleet: A +1, B +2 (+1 +0.5 +0.5), C -1, D +0.5: three positive -> PASS
        L = self.build({"A": (1.0, 0.0, 0.0), "B": (1.0, 0.5, 0.5), "C": (-1.0, 0.0, 0.0), "D": (0.5, 0.0, 0.0)})
        r = h.t3(L, {}, window=self.W, marks=self.M)
        self.assertEqual(r["rev_net"], {"A": 1.0, "B": 2.0, "C": -1.0, "D": 0.5})
        self.assertEqual(r["t3a_positive"], 3)
        self.assertTrue(r["t3a_pass"])
        # D at -0.5: two positive -> not a pass
        L = self.build({"A": (1.0, 0.0, 0.0), "B": (1.0, 0.5, 0.5), "C": (-1.0, 0.0, 0.0), "D": (-0.5, 0.0, 0.0)})
        r = h.t3(L, {}, window=self.W, marks=self.M)
        self.assertEqual(r["t3a_positive"], 2)
        self.assertFalse(r["t3a_pass"])

    def test_H4_t3b_per_instance_day_ic_only(self):
        # B: reverting 2.0 over 3 instances x 5 days = 0.1333..., trending -1.5 / 15 = -0.1: diff 0.2333...
        # C: (-1.0 / 15) - 0 = -0.0667; D: 0.5 / 15 = 0.0333; A is not in T3b
        L = self.build({"A": (1.0, 0.0, 0.0), "B": (1.0, 0.5, 0.5), "C": (-1.0, 0.0, 0.0), "D": (0.5, 0.0, 0.0)})
        r = h.t3(L, {}, window=self.W, marks=self.M)
        self.assertEqual(sorted(r["t3b"]), ["B", "C", "D"])
        self.assertAlmostEqual(r["t3b"]["B"], 2.0 / 15 + 1.5 / 15, places=9)
        self.assertAlmostEqual(r["t3b"]["C"], -1.0 / 15, places=9)
        self.assertAlmostEqual(r["t3b"]["D"], 0.5 / 15, places=9)

    def test_H5_t3c_realised_plus_change_in_mtm(self):
        # two GBPUSD_OPTB longs at 1.30000, both opened before the first mark (T0 - 600 < T0 + 800):
        # layer 1 open at both marks; layer 2 closed at T0 + 7200 (between the marks) with net 1.50.
        # mid 1.29900 at mark 1: both open, -1.00 each = -2.00; mid 1.30200 at mark 2: layer 1 only, +2.00.
        # T3c = 1.50 + (2.00 - (-2.00)) = 5.50 (the tests commit wrote 4.50: it left layer 2 out of mark 1)
        m1, m2 = h.cs.utc(self.M[0]), h.cs.utc(self.M[1])
        bars = {"GBPUSD": ([m1 - 30, m2 - 30], [1.29895, 1.30195], [1.29905, 1.30205])}
        L = book(lay("GRIND_GBPUSD_OPTB", 1, "L", T0 - 600, 1.30000),
                 lay("GRIND_GBPUSD_OPTB", 2, "L", T0 - 600, 1.30000, T0 + 7200, 1.50))
        r = h.t3(L, {"B": bars}, window=self.W, marks=self.M)
        self.assertAlmostEqual(r["t3c"], 5.50, places=6)
        self.assertTrue(r["t3c_pass"])
        self.assertEqual(r["unpriced"], 0)
        # mid 1.29600 at mark 2 (layer 1 -4.00): T3c = 1.50 + (-4.00 - (-2.00)) = -0.50: no pass
        bars = {"GBPUSD": ([m1 - 30, m2 - 30], [1.29895, 1.29595], [1.29905, 1.29605])}
        r = h.t3(L, {"B": bars}, window=self.W, marks=self.M)
        self.assertAlmostEqual(r["t3c"], -0.50, places=6)
        self.assertFalse(r["t3c_pass"])


if __name__ == "__main__":
    unittest.main()
