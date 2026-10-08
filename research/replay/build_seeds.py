"""build_seeds.py -- the replay harness's seed_<seg_id>.csv files (STUB: tests first)."""

SEED_HEADER = "side,layer_index,entry,open_ms,ticket,vl,swap,volume"


def open_positions(rows, at_ms):
    raise NotImplementedError


def latest_vl(rows, ticket, at_ms):
    raise NotImplementedError


def seed_rows(rows, snaps, at_ms):
    raise NotImplementedError


def to_seed_csv(seed):
    raise NotImplementedError


def cap_warnings(seed, cap, preload_from_ms):
    raise NotImplementedError
