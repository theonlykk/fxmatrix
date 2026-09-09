#!/usr/bin/env python3
"""
Harvest-window scan for the AUD/CAD/CHF ring.

Oscillation metric (scale-free, per pair)
----------------------------------------
Let p_0, p_1, ..., p_n be close prices in a candidate window.

    r_i       = ln(p_i / p_{i-1})          for i = 1 ... n   (log returns)
    path_len  = sum |r_i|
    net_disp  = |ln(p_n / p_0)|
    score     = path_len / max(net_disp, 1e-9)

Higher score => more path travelled per unit net displacement (chop, not trend).
Log returns make the ratio dimensionless and comparable across AUDCAD, AUDCHF,
CADCHF despite different price levels and volatilities.

Joint ring score
----------------
For each candidate window, score each ring pair, then take min() -- the worst leg
defines the window. Mean() is deliberately not used: one trending leg poisons the
ring even if the other two are flat.

Rejected alternative
--------------------
Realised volatility alone (std of log returns, or ATR) ranks the most volatile
pair/period first and ignores trend-vs-chop structure -- a sustained commodity
rally and a tight range both look "volatile". Rejected in favour of path/disp
because the grid cares about round-trip harvestability, not raw variance.

Scan parameters (committed)
---------------------------
    window length : 90 calendar days
    step          : 7 calendar days (weekly)
    event buffer  : 30 calendar days before/after each pre-registered event
    min gap       : 90 calendar days between calibration and holdout harvest
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

RING_PAIRS = ("AUDCAD", "AUDCHF", "CADCHF")
ALL_SYMBOLS = (*RING_PAIRS, "USDCAD", "USDCHF", "AUDUSD")
DATA_ROOT = Path(__file__).resolve().parent.parent / "data"

WINDOW_DAYS = 90
STEP_DAYS = 7
EVENT_BUFFER_DAYS = 30
MIN_HARVEST_GAP_DAYS = 90
GAP_THRESHOLD_DAYS = 4  # calendar days; weekends ~2-3 days between Fri and Mon
EPSILON = 1e-9
EPSILON_HIT_THRESHOLD = 1e-8  # net_disp below this hit the score denominator floor
MAX_PAIR_SPREAD_FOR_RECOMMEND = 5.0  # max/min per-pair score ratio for recommendations

EVENT_WINDOWS: list[tuple[str, pd.Timestamp, pd.Timestamp]] = [
    ("calib_stress_commodity", pd.Timestamp("2022-02-01"), pd.Timestamp("2022-05-01")),
    ("holdout_stress_covid", pd.Timestamp("2020-02-01"), pd.Timestamp("2020-05-01")),
    ("holdout_tail_chf_depeg", pd.Timestamp("2015-01-01"), pd.Timestamp("2015-02-01")),
]

SANITY_TREND_WINDOW = ("holdout_stress_covid", pd.Timestamp("2020-02-01"), pd.Timestamp("2020-05-01"))


@dataclass(frozen=True)
class WindowScore:
    start: pd.Timestamp
    end: pd.Timestamp
    joint: float
    per_pair: dict[str, float]
    per_pair_net_disp: dict[str, float]
    bar_counts: dict[str, int]

    @property
    def label(self) -> str:
        q = (self.start.month - 1) // 3 + 1
        return f"{self.start.year}q{q}"

    def epsilon_hits(self) -> list[str]:
        return [
            sym
            for sym in RING_PAIRS
            if self.per_pair_net_disp[sym] < EPSILON_HIT_THRESHOLD
        ]

    def pair_spread_ratio(self) -> float:
        """Max/min score ratio using only pairs above epsilon floor."""
        usable = [
            self.per_pair[sym]
            for sym in RING_PAIRS
            if self.per_pair_net_disp[sym] >= EPSILON_HIT_THRESHOLD
        ]
        if len(usable) < 2:
            return float("inf")
        return max(usable) / min(usable)

    def recommendable(self) -> bool:
        return not self.epsilon_hits() and self.pair_spread_ratio() <= MAX_PAIR_SPREAD_FOR_RECOMMEND


def oscillation_score(closes: np.ndarray) -> tuple[float, float]:
    """Return (score, net_disp) from path-length / net-displacement ratio on log returns."""
    if len(closes) < 2:
        return float("nan"), float("nan")
    log_p = np.log(closes.astype(float))
    log_returns = np.diff(log_p)
    path_len = float(np.sum(np.abs(log_returns)))
    net_disp = float(abs(log_p[-1] - log_p[0]))
    return path_len / max(net_disp, EPSILON), net_disp


def assert_zero_displacement_scored() -> None:
    """Verify identical start/end prices score finite and high (not inf/NaN)."""
    prices = np.array([1.0, 1.001, 0.999, 1.002, 0.998, 1.0])
    score, net_disp = oscillation_score(prices)
    assert net_disp == 0.0
    assert np.isfinite(score), f"zero-displacement window must score finite, got {score}"
    assert score > 1.0, f"choppy zero-net window should score > 1, got {score}"


def load_pair_m5(symbol: str, data_root: Path = DATA_ROOT) -> pd.DataFrame:
    path = data_root / f"{symbol}_m5.csv"
    if not path.is_file():
        raise FileNotFoundError(f"Missing {path}")
    df = pd.read_csv(path, parse_dates=["datetime"])
    return df.sort_values("datetime").reset_index(drop=True)


def buffered_event_ranges() -> list[tuple[pd.Timestamp, pd.Timestamp]]:
    ranges = []
    for _, start, end in EVENT_WINDOWS:
        buf = pd.Timedelta(days=EVENT_BUFFER_DAYS)
        ranges.append((start - buf, end + buf))
    return ranges


def overlaps_buffered_events(start: pd.Timestamp, end: pd.Timestamp) -> bool:
    for ev_start, ev_end in buffered_event_ranges():
        if start < ev_end and end > ev_start:
            return True
    return False


def score_window_on_series(
    times: pd.Series,
    closes: np.ndarray,
    start: pd.Timestamp,
    end: pd.Timestamp,
) -> tuple[float, float, int]:
    mask = (times >= start) & (times < end)
    segment = closes[mask.to_numpy()]
    score, net_disp = oscillation_score(segment)
    return score, net_disp, int(mask.sum())


def build_candidate_starts(data_start: pd.Timestamp, data_end: pd.Timestamp) -> list[pd.Timestamp]:
    """Weekly starts on calendar dates (midnight) within common data coverage."""
    t = data_start.normalize()
    end_limit = data_end.normalize()
    window_delta = pd.Timedelta(days=WINDOW_DAYS)
    step = pd.Timedelta(days=STEP_DAYS)
    starts: list[pd.Timestamp] = []
    while t + window_delta <= end_limit:
        starts.append(t)
        t += step
    return starts


def scan_ring(data_root: Path = DATA_ROOT) -> tuple[list[WindowScore], dict[str, pd.DataFrame]]:
    frames = {sym: load_pair_m5(sym, data_root) for sym in RING_PAIRS}
    common_start = max(df["datetime"].iloc[0] for df in frames.values())
    common_end = min(df["datetime"].iloc[-1] for df in frames.values())

    candidates: list[WindowScore] = []
    window_delta = pd.Timedelta(days=WINDOW_DAYS)

    for start in build_candidate_starts(common_start, common_end):
        end = start + window_delta
        if overlaps_buffered_events(start, end):
            continue

        per_pair: dict[str, float] = {}
        per_pair_net_disp: dict[str, float] = {}
        bar_counts: dict[str, int] = {}
        for sym in RING_PAIRS:
            df = frames[sym]
            score, net_disp, n_bars = score_window_on_series(
                df["datetime"], df["CLOSE"].values, start, end
            )
            per_pair[sym] = score
            per_pair_net_disp[sym] = net_disp
            bar_counts[sym] = n_bars

        if any(n_bars < 1000 for n_bars in bar_counts.values()):
            continue

        joint = min(per_pair.values())
        candidates.append(
            WindowScore(
                start=start,
                end=end,
                joint=joint,
                per_pair=per_pair,
                per_pair_net_disp=per_pair_net_disp,
                bar_counts=bar_counts,
            )
        )

    candidates.sort(key=lambda w: w.joint, reverse=True)
    return candidates, frames


def check_coverage(frames: dict[str, pd.DataFrame], data_root: Path = DATA_ROOT) -> None:
    print("=" * 72)
    print("DELIVERABLE 4a -- DATA COVERAGE")
    print("=" * 72)
    for sym in ALL_SYMBOLS:
        if sym not in frames:
            frames[sym] = load_pair_m5(sym, data_root)
    for sym in ALL_SYMBOLS:
        df = frames[sym]
        t0, t1 = df["datetime"].iloc[0], df["datetime"].iloc[-1]
        print(f"  {sym}: {t0} -> {t1}  ({len(df):,} bars)")

    print("\n  Gaps longer than ~3 days (weekends excepted; threshold > 4 calendar days):")
    any_bad = False
    for sym in ALL_SYMBOLS:
        df = frames[sym]
        gaps = df["datetime"].diff()
        big = gaps[gaps > pd.Timedelta(days=GAP_THRESHOLD_DAYS)]
        if len(big):
            any_bad = True
            print(f"    {sym}: {len(big)} gap(s) > {GAP_THRESHOLD_DAYS}d - worst {gaps.max()}")
            for idx in big.index[:3]:
                prev = df.loc[idx - 1, "datetime"]
                curr = df.loc[idx, "datetime"]
                print(f"      {prev} -> {curr}  ({curr - prev})")
        else:
            print(f"    {sym}: none")
    if not any_bad:
        print("  No problematic gaps detected.")


def report_chf_depeg(frames: dict[str, pd.DataFrame]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 4b -- CHF DE-PEG WINDOW (Jan 2015)")
    print("=" * 72)
    depeg = pd.Timestamp("2015-01-15")
    ring_frames = {s: frames[s] for s in RING_PAIRS}
    data_start = max(df["datetime"].iloc[0] for df in ring_frames.values())
    pre_days = (depeg - data_start).days
    print(f"  Data start (ring common): {data_start}")
    print(f"  SNB de-peg date:          {depeg}")
    print(f"  Pre-event history:        ~{pre_days} calendar days (~{pre_days * 288 // 7:,} M5 bars est.)")
    print("  Known limitation: only ~2 weeks of pre-de-peg M5 before event.")


def report_trend_sanity(candidates: list[WindowScore], frames: dict[str, pd.DataFrame]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 4c -- TREND-PERIOD SANITY CHECK")
    print("=" * 72)
    name, t_start, t_end = SANITY_TREND_WINDOW
    per_pair: dict[str, float] = {}
    for sym in RING_PAIRS:
        df = frames[sym]
        score, _, _ = score_window_on_series(df["datetime"], df["CLOSE"].values, t_start, t_end)
        per_pair[sym] = score
    trend_joint = min(per_pair.values())
    print(f"  {name} ({t_start.date()} -> {t_end.date()})")
    print(f"    joint (min): {trend_joint:.2f}")
    for sym in RING_PAIRS:
        print(f"    {sym}: {per_pair[sym]:.2f}")

    if candidates:
        ref = next((w for w in candidates if w.recommendable()), candidates[0])
        print(f"\n  Reference chop candidate: {ref.start.date()} -> {ref.end.date()}, joint={ref.joint:.2f}")
        ratio = ref.joint / trend_joint if trend_joint > 0 else float("inf")
        print(f"  Chop / COVID trend ratio: {ratio:.2f}x")
        if ref.joint <= trend_joint * 1.1:
            print("  WARNING: trend period does not score conspicuously worse - review metric.")


def check_pair_disagreement(candidates: list[WindowScore], top_n: int = 10) -> bool:
    """Flag if ring pairs disagree sharply. Returns True if alert triggered."""
    if len(candidates) < top_n:
        return False
    top = candidates[:top_n]
    spreads = [w.pair_spread_ratio() for w in top if np.isfinite(w.pair_spread_ratio())]
    if not spreads:
        return False
    median_spread = float(np.median(spreads))
    if median_spread > 3.0:
        print("\n  *** PAIR DISAGREEMENT ALERT ***")
        print(f"  Median max/min per-pair ratio in top {top_n} (epsilon-excluded): {median_spread:.2f}x")
        print("  A single ring-wide harvest window may be the wrong model.")
        return True
    return False


def windows_separated(a: WindowScore, b: WindowScore) -> bool:
    min_gap = pd.Timedelta(days=MIN_HARVEST_GAP_DAYS)
    no_overlap = a.end <= b.start or b.end <= a.start
    gap_before = a.start - b.end
    gap_after = b.start - a.end
    separated = (gap_before >= min_gap) or (gap_after >= min_gap)
    return no_overlap and separated


def pick_harvest_windows(candidates: list[WindowScore]) -> tuple[WindowScore, WindowScore, bool]:
    """
    Pick calibration and holdout harvest windows.
    Prefers recommendable windows (no epsilon floor hits, pair spread <= 5x).
    Returns (calib, holdout, used_fallback).
    """
    pool = [w for w in candidates if w.recommendable()]
    used_fallback = False
    if not pool:
        pool = candidates
        used_fallback = True

    calib = pool[0]
    holdout = None
    for w in pool[1:]:
        if windows_separated(calib, w):
            holdout = w
            break
    if holdout is None:
        for w in candidates:
            if w is calib:
                continue
            if windows_separated(calib, w):
                holdout = w
                break
    if holdout is None:
        raise RuntimeError("Could not find non-overlapping holdout harvest window with min gap.")
    return calib, holdout, used_fallback


def print_top_candidates(candidates: list[WindowScore], n: int = 10) -> None:
    print("\n" + "=" * 72)
    print(f"DELIVERABLE 3a -- TOP {n} CANDIDATES (joint = min across ring)")
    print("=" * 72)
    print(
        f"  Scan: {WINDOW_DAYS}-day windows, step {STEP_DAYS}d; "
        f"event buffer +/-{EVENT_BUFFER_DAYS}d; min harvest gap {MIN_HARVEST_GAP_DAYS}d"
    )
    print(f"  {'Rank':<5} {'Start':<12} {'End':<12} {'Joint':>8}  Per-pair scores / bars")
    for i, w in enumerate(candidates[:n], 1):
        flags = []
        eps = w.epsilon_hits()
        if eps:
            flags.append(f"eps:{','.join(eps)}")
        spread = w.pair_spread_ratio()
        if np.isfinite(spread):
            flags.append(f"spr:{spread:.1f}x")
        flag_str = f"  [{'; '.join(flags)}]" if flags else ""
        parts = "  ".join(
            f"{sym}={w.per_pair[sym]:.1f}({w.bar_counts[sym]:,})" for sym in RING_PAIRS
        )
        print(f"  {i:<5} {w.start.date()} {w.end.date()} {w.joint:8.2f}  {parts}{flag_str}")


def print_recommendations(
    calib: WindowScore,
    holdout: WindowScore,
    raw_top: WindowScore,
    used_fallback: bool,
    disagreement: bool,
) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3b/3c -- RECOMMENDATIONS (operator pre-registers final choice)")
    print("=" * 72)

    if raw_top.start != calib.start:
        print(
            f"  Note: raw metric #1 is {raw_top.start.date()} -> {raw_top.end.date()} "
            f"(joint={raw_top.joint:.1f}) but epsilon/disagreement flags favour the pick below."
        )
    if used_fallback:
        print("  WARNING: no fully recommendable window found; using raw ranking.")
    if disagreement:
        print("  WARNING: pair disagreement alert active -- review per-pair columns before pre-registering.")

    calib_name = f"calib_chop_{calib.label}"
    holdout_name = f"holdout_chop_{holdout.label}"

    print(f"\n  Calibration harvest: {calib_name}")
    print(f"    {calib.start.date()} -> {calib.end.date()}  joint={calib.joint:.2f}")
    print(
        f"    Reason: best joint chop among ring-balanced windows "
        f"(pair spread {calib.pair_spread_ratio():.1f}x, no epsilon floor hits)."
    )

    print(f"\n  Holdout harvest:     {holdout_name}")
    print(f"    {holdout.start.date()} -> {holdout.end.date()}  joint={holdout.joint:.2f}")
    gap_days = min(
        abs((calib.start - holdout.end).days),
        abs((holdout.start - calib.end).days),
    )
    print(
        f"    Reason: next-best separated candidate ({gap_days}d from calibration); "
        f"pair spread {holdout.pair_spread_ratio():.1f}x."
    )
    print("\n  Final pre-registration is the operator's decision, not this script's.")


def print_surprises(candidates: list[WindowScore]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3d -- SURPRISES / RING OBSERVATIONS")
    print("=" * 72)
    if not candidates:
        print("  No candidates survived filters.")
        return

    top10 = candidates[:10]
    years = [w.start.year for w in top10]
    yr_counts = Counter(years)
    dominant = yr_counts.most_common(1)[0]
    if dominant[1] >= 5:
        print(f"  Top-10 cluster in {dominant[0]} ({dominant[1]}/10 windows) - era-specific chop.")

    ratios = [w.pair_spread_ratio() for w in top10 if np.isfinite(w.pair_spread_ratio())]
    if ratios:
        print(
            f"  Per-pair score spread (max/min, epsilon-excluded) in top 10: "
            f"min={min(ratios):.2f}x med={np.median(ratios):.2f}x max={max(ratios):.2f}x"
        )
    eps_count = sum(1 for w in top10 if w.epsilon_hits())
    if eps_count:
        print(f"  {eps_count}/10 top windows hit the net_disp epsilon floor on at least one leg.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Harvest-window scan for AUD/CAD/CHF ring")
    parser.add_argument("--data-root", type=Path, default=DATA_ROOT)
    args = parser.parse_args()

    print("Zero-displacement metric self-test ...")
    assert_zero_displacement_scored()
    print("  OK - identical start/end prices score finite and high.\n")

    candidates, frames = scan_ring(args.data_root)
    check_coverage(frames)
    report_chf_depeg(frames)
    report_trend_sanity(candidates, frames)
    disagreement = check_pair_disagreement(candidates)

    print_top_candidates(candidates)
    print_surprises(candidates)

    if len(candidates) >= 2:
        calib, holdout, used_fallback = pick_harvest_windows(candidates)
        print_recommendations(calib, holdout, candidates[0], used_fallback, disagreement)


if __name__ == "__main__":
    main()
