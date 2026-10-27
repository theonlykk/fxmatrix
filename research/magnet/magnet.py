"""Magnet grid (research/magnet/PREREG.md v1). STUB: tests first."""


def sell_fills(prev_close_bid, bid_high, p):
    raise NotImplementedError


def buy_fills(prev_close_ask, ask_low, p):
    raise NotImplementedError


def sell_entry(o, s, d, n):
    raise NotImplementedError


def buy_entry(o, s, d, n):
    raise NotImplementedError


def magnet(o, s, n):
    raise NotImplementedError


def run_grid(b, o, s, d, cap, usd_per_pip):
    raise NotImplementedError


def placebo_offsets(rng, s, k):
    raise NotImplementedError


def rank_of_real(real, placebos):
    raise NotImplementedError


def ftmo_day(t_server):
    raise NotImplementedError


def permute_bars_within_days(b, rng):
    raise NotImplementedError
