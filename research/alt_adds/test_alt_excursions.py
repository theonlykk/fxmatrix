"""Hand-valued tests for alt_excursions.py (run: python research/alt_adds/test_alt_excursions.py).

Expected values are worked by hand from the paths below, never read from the code's output.
"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alt_excursions as ax  # noqa: E402

H = 3600000  # one hour in ms


def path(*pts):
    """[(hour, price)] -> [(t_ms, price)]"""
    return [(int(h * H), p) for h, p in pts]


class Excursions(unittest.TestCase):
    # A short anchored at 1.1000 (hour 0): price runs to 1.1035, then falls to 1.0990.
    # Exit 10 pips: L0's exit is 1.0990, reached at hour 4. Excursion = 1.1035 - 1.1000 = 35 pips.
    P = path((0, 1.1000), (1, 1.1020), (2, 1.1035), (3, 1.1010), (4, 1.0990))

    def test_short_excursion_35(self):
        e = ax.excursion(self.P, 0, "S", 0.0010)
        self.assertEqual(e, (35.0, False))

    def test_long_anchored_same_point_is_0_pips_and_recovers(self):
        # A long at 1.1000: its exit 1.1010 is reached at hour 1 (1.1020) before any fall below 1.1000.
        self.assertEqual(ax.excursion(self.P, 0, "L", 0.0010), (0.0, False))

    def test_long_from_the_top_45_censored_false(self):
        # A long at hour 2 (1.1035): falls to 1.0990 (45 pips) and never reaches 1.1045: censored.
        self.assertEqual(ax.excursion(self.P, 2, "L", 0.0010), (45.0, True))

    def test_exit_not_reached_inclusive(self):
        # Exit 15 pips for the short at 1.1000 needs 1.0985: not reached (1.0990): censored at 35.
        self.assertEqual(ax.excursion(self.P, 0, "S", 0.0015), (35.0, True))

    def test_anchors_one_per_hour_first_sample_at_or_after(self):
        pts = [(10, 1.0), (H - 1, 1.1), (H + 5, 1.2), (H + 9, 1.3), (3 * H + 1, 1.4)]
        # hour 0 -> index 0; hour 1 -> index 2; hour 2 -> none in [2H, 3H); hour 3 -> index 4
        self.assertEqual(ax.anchors(pts, H), [0, 2, 4])

    def test_quantile_nearest_rank(self):
        xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        self.assertEqual(ax.quantile(xs, 0.9), 9)
        self.assertEqual(ax.quantile(xs, 0.5), 5)
        self.assertEqual(ax.quantile(xs, 1.0), 10)


class Loader(unittest.TestCase):
    def test_in_fills_and_roll_levels_only_never_out_by(self):
        rows = [
            {"table": "_meta", "archive": True, "instance": "X"},
            {"table": "fill_logs", "entry_type": "IN", "deal_price": 1.1000,
             "deal_time_broker_msc": 10800000 + 1000},
            # OUT_BY's price is the OTHER position's entry: never a market price (02_TRAPS).
            {"table": "fill_logs", "entry_type": "OUT_BY", "deal_price": 1.2000,
             "deal_time_broker_msc": 10800000 + 2000},
            {"table": "ea_events", "code": "ROLL_ACCEPTED", "ea_time_ms": 3000,
             "detail": {"level": 1.1050}},
            {"table": "ea_events", "code": "CARRY_SNAPSHOT", "ea_time_ms": 4000, "detail": {}},
        ]
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8-sig") as f:
            for r in rows:
                f.write(json.dumps(r) + "\n")
            name = f.name
        try:
            self.assertEqual(ax.load(name), [(1000, 1.1000), (3000, 1.1050)])
        finally:
            os.unlink(name)


if __name__ == "__main__":
    unittest.main()
