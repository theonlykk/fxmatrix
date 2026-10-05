"""C124 tests: every expected value derived by hand in the comments."""
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ftmo_days as fd  # noqa: E402
import ftmo_sim as fs   # noqa: E402

D = 20722                       # 20722 * 86400 + 79200 = 1790460000 = an FTMO day start (22:00Z)
T0 = D * 86400 + 22 * 3600


def deal(t, pos, typ, entry, price, profit=0.0, comm=0.0, magic=7, sym="EURUSD", deal_id=None):
    return dict(deal=deal_id or int(t), position=pos, t=t, type=typ, entry=entry, magic=magic,
                symbol=sym, volume=0.01, price=price, commission=comm, swap=0.0, profit=profit)


BARS = {"EURUSD": ([T0, T0 + 600, T0 + 1200], [1.10000, 1.09900, 1.10050], [1.10010, 1.09910, 1.10060])}


class TestDays(unittest.TestCase):
    def test_D1_one_round_trip(self):
        # buy 0.01 at 1.10010 (T0+60, comm -0.03), sell at 1.10050 (T0+1200, profit +0.40, comm -0.03)
        # r = -0.03 + 0.40 - 0.03 = +0.34; m0 = m1 = 0
        # low: T0+600..T0+1140 the bid is 1.09900: realised -0.03 + (1.09900 - 1.10010) * 1000 = -0.03 - 1.10 = -1.13
        ds = [deal(T0 + 60, 1, 0, 0, 1.10010, comm=-0.03, deal_id=1),
              deal(T0 + 1200, 1, 1, 1, 1.10050, profit=0.40, comm=-0.03, deal_id=2)]
        days = fd.build_days(ds, BARS)
        self.assertEqual(len(days), 1)
        d = days[0]
        self.assertEqual(d["day"], D)
        self.assertAlmostEqual(d["r"], 0.34, places=6)
        self.assertAlmostEqual(d["m0"], 0.0, places=6)
        self.assertAlmostEqual(d["m1"], 0.0, places=6)
        self.assertAlmostEqual(d["low"], -1.13, places=6)
        self.assertEqual(d["n_open_max"], 1)

    def test_D2_short_on_a_cad_cross(self):
        # sell 0.01 AUDCAD at 0.90000; ask 0.90100; USDCAD mid 1.25 -> 1 CAD = 0.8 USD
        # MTM = -(0.90100 - 0.90000) * 100000 * 0.01 * 0.8 = -0.80
        bars = {"AUDCAD": ([T0], [0.90090], [0.90100]), "USDCAD": ([T0], [1.24995], [1.25005])}
        pos = dict(symbol="AUDCAD", price=0.90000, volume=0.01, side="S")
        self.assertAlmostEqual(fd.position_mtm(pos, bars, T0 + 30), -0.80, places=6)

    def test_D3_magic_filter_by_opening_deal(self):
        # position 1 opened by magic 7, closed by a manual deal (magic 0): kept; position 2 (magic 8): dropped
        ds = [deal(T0 + 60, 1, 0, 0, 1.10010, comm=-0.03, magic=7, deal_id=1),
              deal(T0 + 1200, 1, 1, 1, 1.10050, profit=0.40, magic=0, deal_id=2),
              deal(T0 + 60, 2, 1, 0, 1.10000, comm=-0.03, magic=8, deal_id=3),
              deal(T0 + 1200, 2, 0, 1, 1.10060, profit=-0.60, magic=8, deal_id=4)]
        days = fd.build_days(ds, BARS, magics={7})
        self.assertAlmostEqual(days[0]["r"], -0.03 + 0.40, places=6)   # +0.37: position 2 left out

    def test_D4_carried_position(self):
        # bought on day D at 1.10010, never closed; day D+1 has no deal, still a record:
        # m0 = low = (1.10050 - 1.10010) * 1000 = +0.40 (the bid at D+1's start is T0+1200's), r = 0
        # a bar inside day D+1 makes it a quoted day; until = an hour into D+1
        bars = {"EURUSD": (BARS["EURUSD"][0] + [T0 + 86400 + 60], BARS["EURUSD"][1] + [1.10050],
                           BARS["EURUSD"][2] + [1.10060])}
        ds = [deal(T0 + 60, 1, 0, 0, 1.10010, deal_id=1)]
        days = fd.build_days(ds, bars, until=T0 + 86400 + 3600)
        self.assertEqual([d["day"] for d in days], [D, D + 1])
        d1 = days[1]
        self.assertAlmostEqual(d1["r"], 0.0, places=6)
        self.assertAlmostEqual(d1["m0"], 0.40, places=6)
        self.assertAlmostEqual(d1["low"], 0.40, places=6)


class TestPhase(unittest.TestCase):
    def test_S1_target_waits_for_four_days(self):
        # +600, +600 reach 11,200 on day 2, but 4 trading days are required: pass on day 4 at 11,200
        self.assertEqual(fs.run_phase([(600, 0, 0), (600, 0, 0), (0, 0, 0), (0, 0, 0)], 1000.0),
                         ("pass", 4, 11200.0))

    def test_S2_daily_limit_on_the_intraday_low(self):
        # day 2 closes +50 but its low is -501 vs the day-start balance: daily breach; equity 10,100 - 10
        self.assertEqual(fs.run_phase([(100, 0, 0), (50, -501, -10)], 1000.0), ("daily", 2, 10090.0))

    def test_S3_max_loss_on_equity(self):
        # day 1: 10,000 -> 9,400 (dip to 9,900); day 2: low -450 passes the daily test,
        # but 9,400 - 450 = 8,950 < 9,000: max loss
        self.assertEqual(fs.run_phase([(-600, -100, -100), (-300, -450, -450)], 1000.0), ("maxloss", 2, 8950.0))

    def test_S4_zero_drift_matches_gamblers_ruin(self):
        # days of +100 or -100 (a losing day dips to its close), block 1: a losing day from 9,000
        # breaches (9,000 - 100 < 9,000), so ruin is 11 steps down, the target 10 (5) up:
        # P = 11 / 21 = 0.5238 (Challenge), 11 / 16 = 0.6875 (Verification); 20,000 runs, se ~0.0036
        recs = [dict(r=100.0, m0=0.0, m1=0.0, low=0.0), dict(r=-100.0, m0=0.0, m1=0.0, low=-100.0)]
        rng = random.Random(7)
        for target, want in ((1000.0, 11 / 21), (500.0, 11 / 16)):
            n = 20000
            hits = 0
            for _ in range(n):
                st = fs.block_stream([recs], 1, rng)
                hits += fs.run_phase(fs.take(st, 2000), target)[0] == "pass"
            self.assertAlmostEqual(hits / n, want, delta=0.015)

    def test_S5_blocks_never_split_or_cross_sources(self):
        # a block is one contiguous slice of one source, length min(block, len - start)
        a = [dict(id=("A", i)) for i in range(3)]
        b = [dict(id=("B", i)) for i in range(2)]
        rng = random.Random(3)
        for _ in range(2000):
            blk = fs.draw_block([a, b], 2, rng)
            src = {x["id"][0] for x in blk}
            self.assertEqual(len(src), 1)
            idx = [x["id"][1] for x in blk]
            n = 3 if "A" in src else 2
            self.assertEqual(idx, list(range(idx[0], idx[0] + len(idx))))
            self.assertEqual(len(idx), min(2, n - idx[0]))

    def test_S6_attempt_and_payouts(self):
        # every day +100, no dip: Challenge passes on day 10 (11,000), Verification on day 5 (10,500);
        # funded: a payout every 21 days of 0.9 x 2,100 = 1,890, at k = 21 ... 231: 11 payouts = 20,790
        recs = [dict(r=100.0, m0=0.0, m1=0.0, low=0.0)]
        r = fs.attempt([recs], random.Random(1))
        self.assertEqual((r["phase1"], r["phase2"], r["days"]), ("pass", "pass", 15))
        self.assertEqual((r["n_payouts"], r["funded_days"]), (11, 250))
        self.assertAlmostEqual(r["payouts"], 20790.0, places=6)

    def test_S7_summary_and_value(self):
        # A passed: payouts 900, 30 + 33 days = 3 months of VPS (60): 900 - 100 - 60 = 740 (refund: 840)
        # B failed the Challenge on the daily limit after 4 days: -100 - 20 x 4 / 21 = -103.8095
        # EV = (740 - 103.8095) / 2 = 318.0952; with refund (840 - 103.8095) / 2 = 368.0952
        A = dict(phase1="pass", phase2="pass", days=30, funded_days=33, payouts=900.0, n_payouts=1)
        B = dict(phase1="daily", phase2=None, days=4, funded_days=0, payouts=0.0, n_payouts=0)
        s = fs.summarise([A, B])
        self.assertAlmostEqual(s["p_challenge"], 0.5)
        self.assertAlmostEqual(s["p_both"], 0.5)
        self.assertEqual(s["fails"], {"daily": 0.5})
        self.assertAlmostEqual(s["ev_per_attempt"], 318.0952, places=3)
        self.assertAlmostEqual(fs.summarise([A, B], refund=True)["ev_per_attempt"], 368.0952, places=3)



class TestWeekend(unittest.TestCase):
    def test_D5_unquoted_day_dropped(self):
        # position held through day D+1 with no bar in it (a closed market): no record for D+1
        ds = [deal(T0 + 60, 1, 0, 0, 1.10010, deal_id=1)]
        days = fd.build_days(ds, BARS, until=T0 + 86400 + 3600)
        self.assertEqual([d["day"] for d in days], [D])


class TestTail(unittest.TestCase):
    def test_S8_tail_day_replaces_with_probability_p(self):
        # p = 1: every day is the tail record (low -505.34 < -500): the Challenge fails on day 1
        good = [dict(r=100.0, m0=0.0, m1=0.0, low=0.0)]
        bad = dict(r=-173.34, m0=-332.0, m1=0.0, low=-505.34)
        r = fs.attempt([good], random.Random(1), tail=(1.0, bad))
        self.assertEqual((r["phase1"], r["days"]), ("daily", 1))
        # p = 0: never replaced (as S6: both phases pass in 15 days)
        r = fs.attempt([good], random.Random(1), tail=(0.0, bad))
        self.assertEqual((r["phase2"], r["days"]), ("pass", 15))


if __name__ == "__main__":
    unittest.main()
