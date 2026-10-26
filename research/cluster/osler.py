"""Round numbers in FX: an Osler replication (research/cluster/PREREG.md v3.1). STUB: the tests come first."""


def quote_t10(open_price, spread_points):
    raise NotImplementedError


def in_band(q, level):
    raise NotImplementedError


def excluded(t_server):
    raise NotImplementedError


def level_hits(t, q, level):
    raise NotImplementedError


def outcome(t, q, i, level, side, h_min):
    raise NotImplementedError


def round_levels(qmin, qmax):
    raise NotImplementedError


def round_class(level):
    raise NotImplementedError


def draw_arbitrary(rng, qmin, qmax, n):
    raise NotImplementedError


def pair_block_stats(t, q, round_lv, arb_lv, min_hits=10, min_cross=5):
    raise NotImplementedError


def sign_test_p(wins, n):
    raise NotImplementedError


def common_days(counts):
    raise NotImplementedError


def blocks(days):
    raise NotImplementedError


def bootstrap_ci(values, seed=20261027, n=2000):
    raise NotImplementedError
