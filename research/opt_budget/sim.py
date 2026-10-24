"""OPT budget simulator -- STUB (tests first)."""
from dataclasses import dataclass, field


@dataclass
class Cfg:
    width: float; add: float; exit: float; cap: int; stranded: float; deadband: float
    lattice: bool = True; reroll: bool = True; gate: int = 0; carry: bool = False


@dataclass
class Layer:
    entry: float; idx: int; vl: float = None


def budget(a): raise NotImplementedError
def opt_add_target(d, a, own, alt_resting): raise NotImplementedError
def straddle(bid, ask, width): raise NotImplementedError
def clamp_buy(price, bid): raise NotImplementedError
def clamp_sell(price, ask): raise NotImplementedError
def add_target(layers, is_long, add): raise NotImplementedError
def resting_exit_idx(layers, is_long): raise NotImplementedError
def roll_candidate(layers, is_long): raise NotImplementedError
def run_single(ticks, cfg, carry_rows): raise NotImplementedError
def run_pair(ticks, cfg_opt, cfg_alt, carry_rows, budget): raise NotImplementedError
