"""Hand-valued tests for solve_exit_eq_add.py's quantile option (run: python research/alt_adds/test_solve_exit_eq_add.py).

Expected values are worked by hand from the path below, never read from the code's output.

The path: ten hourly anchors at 1.1000, all after 9 Oct 00:00Z (so the whole file and the "from 9 Oct" subset
are the same anchors). In hour h the market dips to 1.1000 - d_h, then trades at 1.1060, then the next hour opens
at 1.1000 again. d_h = 60, 66, 72, ..., 114 pips.
- A LONG anchored at 1.1000 sees the dip (worst d_h) and recovers at 1.1060 for any exit up to 60 pips:
  excursion d_h.
- A SHORT anchored at 1.1000 recovers at the dip itself (d_h >= 60 >= any exit tried here): excursion 0.
So the worse side is the long, the depth does not depend on the exit, and the solve's fixed point is reached in
one step: add = (the quantile of {60, 66, ..., 114}) / 6 (cap 7).
Nearest rank over n = 10 (alt_excursions.quantile: the ceil(q * n)-th smallest):
  q80: ceil(8.0) = 8th = 102 -> 17.0;  q85: ceil(8.5) = 9th = 108 -> 18.0;
  q90: ceil(9.0) = 9th = 108 -> 18.0;  q95: ceil(9.5) = 10th = 114 -> 19.0.
"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import solve_exit_eq_add as sv  # noqa: E402

H = 3600000
T0 = 1791504000000 + H  # 9 Oct 2026 01:00Z
BROKER = 10800000       # IC's server GMT+3 (alt_excursions.BROKER_OFFSET_MS)


def write_path():
    rows = []
    for h in range(10):
        d = (60 + 6 * h) * 0.0001
        for frac, px in ((0.0, 1.1000), (0.2, 1.1000 - d), (0.4, 1.1060)):
            rows.append({"table": "fill_logs", "entry_type": "IN", "instance": "GRIND_EURUSD_OPTD",
                         "deal_time_broker_msc": T0 + int((h + frac) * H) + BROKER, "deal_price": round(px, 5)})
    fd, p = tempfile.mkstemp(suffix=".jsonl")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    return p


def run(argv):
    buf = io.StringIO()
    with redirect_stdout(buf):
        sv.main(argv)
    return buf.getvalue().strip()


class Quantiles(unittest.TestCase):
    def setUp(self):
        self.p = write_path()

    def tearDown(self):
        os.remove(self.p)

    def test_default_output_unchanged_q90_q95(self):
        # GUARD: the 17 Oct format and values; expected to pass before AND after the change.
        self.assertEqual(run([self.p]), "GRIND_EURUSD_OPTD  q90: 18.0  q95: 19.0")

    def test_q80_q85_by_option(self):
        self.assertEqual(run(["--q", "0.80,0.85", self.p]), "GRIND_EURUSD_OPTD  q80: 17.0  q85: 18.0")

    def test_four_quantiles_in_the_order_given(self):
        self.assertEqual(run(["--q", "0.95,0.80,0.90,0.85", self.p]),
                         "GRIND_EURUSD_OPTD  q95: 19.0  q80: 17.0  q90: 18.0  q85: 18.0")

    def test_quantile_out_of_range_refused(self):
        for bad in ("0", "1.5", "-0.2", "x"):
            with self.assertRaises(SystemExit):
                run(["--q", bad, self.p])


if __name__ == "__main__":
    unittest.main()
