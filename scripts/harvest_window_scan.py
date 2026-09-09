#!/usr/bin/env python3
"""
Harvest-window scan for the AUD/CAD/CHF ring.

Harvest metric (scale-free, per pair)
-------------------------------------
For each candidate window on one pair:

    path_length    = sum( |close_i - close_{i-1}| )     over the window
    realized_range = max(HIGH) - min(LOW)               over the window
    score          = path_length / max(realized_range, 1e-9)

Numerator = total distance price travelled = raw harvest opportunity.
Denominator = vertical distance the grid had to span = layer cap / capital.
A high score means price travelled far while staying inside a tight box -- the
ideal harvest regime. The ratio is bounded below by 1 (path cannot be shorter
than range on a single axis) and cannot blow up: realized_range cannot approach
zero for any window containing real movement.

Scale-free across pairs: path and range are both in the same price units per
pair, so the ratio is dimensionless and directly comparable across AUDCAD,
AUDCHF, and CADCHF without normalising by level or pip size.

The max(..., 1e-9) guard is defensive hygiene for synthetic/corrupt data only.
If it fires on real data, that is a data problem -- a warning is logged naming
the pair and window.

Joint ring score
----------------
min() across AUDCAD, AUDCHF, CADCHF. Mean() is not used: one trending leg
poisons the ring.

Shift-stability check
---------------------
Top-5 candidates are re-scored at offsets -14d, -7d, +7d, +14d. REJECT if any
non-excluded shift drops below 80% of the base joint score.

Scan parameters (unchanged)
---------------------------
    window length : 90 calendar days
    step          : 7 calendar days (weekly)
    event buffer  : 30 calendar days before/after each pre-registered event
    min gap       : 90 calendar days between calibration and holdout harvest

NOTE: Scores from this metric are NOT comparable to the previous path/displacement
run (e.g. the old #1 at joint 5362). Different formula, different scale.
"""
from __future__ import annotations

import argparse
import logging
import warnings
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

RING_PAIRS = ("AUDCAD", "AUDCHF", "CADCHF")
ALL_SYMBOLS = (*RING_PAIRS, "USDCAD", "USDCHF", "AUDUSD")
DATA_ROOT = Path(__file__).resolve().parent.parent / "data"

WINDOW_DAYS = 90
STEP_DAYS = 7
EVENT_BUFFER_DAYS = 30
MIN_HARVEST_GAP_DAYS = 90
GAP_THRESHOLD_DAYS = 4
RANGE_EPSILON = 1e-9

STABILITY_TOP_N = 5
STABILITY_SHIFTS_DAYS = (-14, -7, 7, 14)
STABILITY_MIN_RETAIN = 0.80

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
    bar_counts: dict[str, int]

    @property
    def label(self) -> str:
        q = (self.start.month - 1) // 3 + 1
        return f"{self.start.year}q{q}"


@dataclass
class StabilityResult:
    window: WindowScore
    base_score: float
    shifted: dict[int, float | None] = field(default_factory=dict)
    excluded_shifts: list[int] = field(default_factory=list)
    worst_degradation_pct: float = 0.0
    verdict: str = "PASS"


def harvest_score(
    closes: np.ndarray,
    highs: np.ndarray,
    lows: np.ndarray,
    *,
    symbol: str | None = None,
    window_label: str | None = None,
) -> tuple[float, float]:
    """Return (score, realized_range) from path_length / max(realized_range, epsilon)."""
    if len(closes) < 2:
        return float("nan"), float("nan")
    closes = closes.astype(float)
    highs = highs.astype(float)
    lows = lows.astype(float)
    path_length = float(np.sum(np.abs(np.diff(closes))))
    realized_range = float(np.max(highs) - np.min(lows))
    if realized_range < RANGE_EPSILON:
        msg = (
            f"realized_range guard fired: pair={symbol or '?'} "
            f"window={window_label or '?'} range={realized_range:.2e}"
        )
        logger.warning(msg)
        warnings.warn(msg, stacklevel=2)
    score = path_length / max(realized_range, RANGE_EPSILON)
    return score, realized_range


def load_pair_m5(symbol: str, data_root: Path = DATA_ROOT) -> pd.DataFrame:
    path = data_root / f"{symbol}_m5.csv"
    if not path.is_file():
        raise FileNotFoundError(f"Missing {path}")
    df = pd.read_csv(path, parse_dates=["datetime"])
    required = {"datetime", "OPEN", "HIGH", "LOW", "CLOSE"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"{path}: missing columns {sorted(missing)} -- cannot score without HIGH/LOW")
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


def score_window_on_frame(
    df: pd.DataFrame,
    start: pd.Timestamp,
    end: pd.Timestamp,
    symbol: str,
) -> tuple[float, int]:
    mask = (df["datetime"] >= start) & (df["datetime"] < end)
    segment = df.loc[mask]
    if len(segment) < 2:
        return float("nan"), 0
    label = f"{start.date()}->{end.date()}"
    score, _ = harvest_score(
        segment["CLOSE"].values,
        segment["HIGH"].values,
        segment["LOW"].values,
        symbol=symbol,
        window_label=label,
    )
    return score, len(segment)


def score_ring_window(
    frames: dict[str, pd.DataFrame],
    start: pd.Timestamp,
    end: pd.Timestamp,
) -> WindowScore | None:
    per_pair: dict[str, float] = {}
    bar_counts: dict[str, int] = {}
    for sym in RING_PAIRS:
        score, n_bars = score_window_on_frame(frames[sym], start, end, sym)
        if n_bars < 1000 or not np.isfinite(score):
            return None
        per_pair[sym] = score
        bar_counts[sym] = n_bars
    return WindowScore(
        start=start,
        end=end,
        joint=min(per_pair.values()),
        per_pair=per_pair,
        bar_counts=bar_counts,
    )


def build_candidate_starts(data_start: pd.Timestamp, data_end: pd.Timestamp) -> list[pd.Timestamp]:
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
    window_delta = pd.Timedelta(days=WINDOW_DAYS)

    candidates: list[WindowScore] = []
    for start in build_candidate_starts(common_start, common_end):
        end = start + window_delta
        if overlaps_buffered_events(start, end):
            continue
        ws = score_ring_window(frames, start, end)
        if ws is not None:
            candidates.append(ws)

    candidates.sort(key=lambda w: w.joint, reverse=True)
    return candidates, frames


def evaluate_stability(
    window: WindowScore,
    frames: dict[str, pd.DataFrame],
) -> StabilityResult:
    result = StabilityResult(window=window, base_score=window.joint)
    ratios: list[float] = []

    for shift_days in STABILITY_SHIFTS_DAYS:
        delta = pd.Timedelta(days=shift_days)
        s_start = window.start + delta
        s_end = window.end + delta
        if overlaps_buffered_events(s_start, s_end):
            result.shifted[shift_days] = None
            result.excluded_shifts.append(shift_days)
            continue
        shifted = score_ring_window(frames, s_start, s_end)
        if shifted is None:
            result.shifted[shift_days] = None
            result.excluded_shifts.append(shift_days)
            continue
        result.shifted[shift_days] = shifted.joint
        ratios.append(shifted.joint / window.joint)

    if ratios:
        worst_ratio = min(ratios)
        result.worst_degradation_pct = (1.0 - worst_ratio) * 100.0
        if worst_ratio < STABILITY_MIN_RETAIN:
            result.verdict = "REJECT"
    else:
        result.verdict = "REJECT"
        result.worst_degradation_pct = 100.0

    return result


def run_stability_check(
    candidates: list[WindowScore],
    frames: dict[str, pd.DataFrame],
    top_n: int = STABILITY_TOP_N,
) -> list[StabilityResult]:
    return [evaluate_stability(w, frames) for w in candidates[:top_n]]


def collect_stable_windows(
    candidates: list[WindowScore],
    frames: dict[str, pd.DataFrame],
    *,
    table_n: int = STABILITY_TOP_N,
    search_n: int = 30,
) -> tuple[list[StabilityResult], list[WindowScore]]:
    """Stability table on top `table_n`; search up to `search_n` for recommendation pool."""
    table = run_stability_check(candidates, frames, top_n=table_n)
    extended = run_stability_check(candidates, frames, top_n=search_n)
    stable = [r.window for r in extended if r.verdict == "PASS"]
    return table, stable


def check_coverage(frames: dict[str, pd.DataFrame], data_root: Path = DATA_ROOT) -> None:
    print("=" * 72)
    print("DATA COVERAGE")
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
        else:
            print(f"    {sym}: none")
    if not any_bad:
        print("  No problematic gaps detected.")


def report_chf_depeg(frames: dict[str, pd.DataFrame]) -> None:
    print("\n" + "=" * 72)
    print("CHF DE-PEG WINDOW (Jan 2015)")
    print("=" * 72)
    depeg = pd.Timestamp("2015-01-15")
    ring_frames = {s: frames[s] for s in RING_PAIRS}
    data_start = max(df["datetime"].iloc[0] for df in ring_frames.values())
    pre_days = (depeg - data_start).days
    print(f"  Data start (ring common): {data_start}")
    print(f"  SNB de-peg date:          {depeg}")
    print(f"  Pre-event history:        ~{pre_days} calendar days")
    print("  Known limitation: only ~2 weeks of pre-de-peg M5 before event.")


def report_trend_sanity(candidates: list[WindowScore], frames: dict[str, pd.DataFrame]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3e -- TREND SANITY CHECK (necessary, not sufficient)")
    print("=" * 72)
    name, t_start, t_end = SANITY_TREND_WINDOW
    ws = score_ring_window(frames, t_start, t_end)
    if ws is None:
        print("  Could not score COVID trend window.")
        return
    print(f"  {name} ({t_start.date()} -> {t_end.date()})")
    print(f"    joint (min): {ws.joint:.2f}")
    for sym in RING_PAIRS:
        print(f"    {sym}: {ws.per_pair[sym]:.2f}")

    if candidates:
        ref = candidates[0]
        print(f"\n  Top chop candidate: {ref.start.date()} -> {ref.end.date()}, joint={ref.joint:.2f}")
        ratio = ref.joint / ws.joint if ws.joint > 0 else float("inf")
        print(f"  Chop / COVID trend ratio: {ratio:.2f}x")
        if ref.joint <= ws.joint * 1.1:
            print("  WARNING: trend period does not score conspicuously worse - review metric.")


def windows_separated(a: WindowScore, b: WindowScore) -> bool:
    min_gap = pd.Timedelta(days=MIN_HARVEST_GAP_DAYS)
    no_overlap = a.end <= b.start or b.end <= a.start
    gap_before = a.start - b.end
    gap_after = b.start - a.end
    separated = (gap_before >= min_gap) or (gap_after >= min_gap)
    return no_overlap and separated


def pick_harvest_windows(stable: list[WindowScore]) -> tuple[WindowScore, WindowScore] | None:
    if not stable:
        return None
    calib = stable[0]
    for w in stable[1:]:
        if windows_separated(calib, w):
            return calib, w
    for w in stable:
        if w is calib:
            continue
        if windows_separated(calib, w):
            return calib, w
    return None


def print_top_candidates(candidates: list[WindowScore], n: int = 10) -> None:
    print("\n" + "=" * 72)
    print(f"DELIVERABLE 3a -- TOP {n} CANDIDATES (joint = min across ring)")
    print("=" * 72)
    print(
        "  METRIC: path_length / max(max(HIGH)-min(LOW), 1e-9). "
        "Scores NOT comparable to previous path/displacement run."
    )
    print(
        f"  Scan: {WINDOW_DAYS}-day windows, step {STEP_DAYS}d; "
        f"event buffer +/-{EVENT_BUFFER_DAYS}d; min harvest gap {MIN_HARVEST_GAP_DAYS}d"
    )
    print(f"  {'Rank':<5} {'Start':<12} {'End':<12} {'Joint':>8}  Per-pair scores")
    for i, w in enumerate(candidates[:n], 1):
        parts = "  ".join(f"{sym}={w.per_pair[sym]:.2f}" for sym in RING_PAIRS)
        print(f"  {i:<5} {w.start.date()} {w.end.date()} {w.joint:8.2f}  {parts}")


def print_stability_table(results: list[StabilityResult]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3b -- SHIFT-STABILITY TABLE (top 5, threshold 80%)")
    print("=" * 72)
    header = (
        f"  {'Rank':<5} {'Start':<12} {'Base':>8} "
        f"{'-14d':>8} {'-7d':>8} {'+7d':>8} {'+14d':>8} "
        f"{'Worst%':>8} {'Verdict':<8}"
    )
    print(header)
    for i, r in enumerate(results, 1):
        w = r.window
        def fmt(shift: int) -> str:
            val = r.shifted.get(shift)
            if shift in r.excluded_shifts:
                return "  EXCL"
            if val is None:
                return "     n/a"
            return f"{val:8.2f}"

        print(
            f"  {i:<5} {w.start.date()} {r.base_score:8.2f} "
            f"{fmt(-14)} {fmt(-7)} {fmt(7)} {fmt(14)} "
            f"{r.worst_degradation_pct:7.1f}% {r.verdict:<8}"
        )


def print_recommendations(calib: WindowScore, holdout: WindowScore) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3c -- RECOMMENDATIONS (operator pre-registers final choice)")
    print("=" * 72)
    print("  Scores use the new path/range metric -- NOT comparable to the old run.")

    calib_name = f"calib_chop_{calib.label}"
    holdout_name = f"holdout_chop_{holdout.label}"

    print(f"\n  Calibration harvest: {calib_name}")
    print(f"    {calib.start.date()} -> {calib.end.date()}  joint={calib.joint:.2f}")
    print("    Reason: highest stable joint chop score after shift-stability filter.")

    print(f"\n  Holdout harvest:     {holdout_name}")
    print(f"    {holdout.start.date()} -> {holdout.end.date()}  joint={holdout.joint:.2f}")
    gap_days = min(
        abs((calib.start - holdout.end).days),
        abs((holdout.start - calib.end).days),
    )
    print(f"    Reason: best stable candidate separated by {gap_days}d from calibration.")
    print("\n  Final pre-registration is the operator's decision, not this script's.")


def print_surprises(candidates: list[WindowScore], stability: list[StabilityResult]) -> None:
    print("\n" + "=" * 72)
    print("DELIVERABLE 3d -- OBSERVATIONS")
    print("=" * 72)
    passed = sum(1 for r in stability if r.verdict == "PASS")
    rejected = len(stability) - passed
    print(f"  Stability: {passed}/{len(stability)} of top 5 PASSED (20% degradation threshold).")
    if rejected:
        rejects = [r for r in stability if r.verdict == "REJECT"]
        for r in rejects:
            print(
                f"    REJECT {r.window.start.date()}: worst degradation {r.worst_degradation_pct:.1f}%"
            )

    if not candidates:
        return
    top10 = candidates[:10]
    years = [w.start.year for w in top10]
    yr_counts = Counter(years)
    dominant = yr_counts.most_common(1)[0]
    if dominant[1] >= 5:
        print(f"  Top-10 cluster in {dominant[0]} ({dominant[1]}/10 windows).")

    spreads = []
    for w in top10:
        vals = list(w.per_pair.values())
        spreads.append(max(vals) / min(vals))
    print(
        f"  Per-pair score spread (max/min) in top 10: "
        f"min={min(spreads):.2f}x med={np.median(spreads):.2f}x max={max(spreads):.2f}x"
    )


def main() -> None:
    logging.basicConfig(level=logging.WARNING, format="%(levelname)s: %(message)s")
    parser = argparse.ArgumentParser(description="Harvest-window scan for AUD/CAD/CHF ring")
    parser.add_argument("--data-root", type=Path, default=DATA_ROOT)
    args = parser.parse_args()

    candidates, frames = scan_ring(args.data_root)
    check_coverage(frames)
    report_chf_depeg(frames)
    report_trend_sanity(candidates, frames)

    print_top_candidates(candidates)

    stability_table, stable_windows = collect_stable_windows(candidates, frames)
    print_stability_table(stability_table)
    print_surprises(candidates, stability_table)

    if not any(r.verdict == "PASS" for r in stability_table):
        print("\n  *** ALL TOP-5 CANDIDATES FAILED STABILITY ***")
        print("  No stable harvest regime at 90 days -- consider changing window length.")
        return

    if not stable_windows:
        print("\n  No stable windows in extended search -- consider changing window length.")
        return

    picked = pick_harvest_windows(stable_windows)
    if picked is None:
        print(
            f"\n  WARNING: {len(stable_windows)} stable window(s) in top 30 "
            "but none pair with 90d separation."
        )
        return
    print_recommendations(*picked)


if __name__ == "__main__":
    main()
