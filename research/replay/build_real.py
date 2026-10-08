"""build_real.py -- the replay harness's real_<tag>.csv and intervals_<tag>.csv (STUB: tests first)."""

REAL_HEADER = "time_ms,kind,side,layer,price,position_id,level"
INTERVALS_HEADER = "kind,from_ms,to_ms"


def real_rows(rows, from_ms, to_ms):
    raise NotImplementedError


def to_real_csv(real):
    raise NotImplementedError


def to_intervals_csv(intervals):
    raise NotImplementedError
