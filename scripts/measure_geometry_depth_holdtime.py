#!/usr/bin/env python3
"""Ladder depth and hold time from deals dump. Analysis only."""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "data" / "deals_dump_20260918_2354.csv"

GRIND_COMMENT_RE = re.compile(
    r"^GRIND\|(?P<slot>OPT|ALT)\|(?P<side>L|S)\|L(?P<layer>\d+)\|(?P<role>ENT|EXT)$",
    re.I,
)

FLEET = (
    "GBPUSD",
    "EURUSD",
    "EURGBP",
    "AUDCAD",
    "AUDCHF",
    "CADCHF",
    "NZDCAD",
    "AUDNZD",
)

ADD_PIPS = {
    "GBPUSD": 10,
    "EURUSD": 14,
    "EURGBP": 6,
    "AUDCAD": 10,
    "AUDCHF": 10,
    "CADCHF": 10,
    "NZDCAD": 10,
    "AUDNZD": 14,
}

EXIT_PIPS = {
    "GBPUSD": {"OPT": 7, "ALT": 10},
    "EURUSD": {"OPT": 7, "ALT": 10},
    "EURGBP": {"OPT": 5, "ALT": 8},
    "AUDCAD": {"OPT": 5, "ALT": 10},
    "AUDCHF": {"OPT": 5, "ALT": 10},
    "CADCHF": {"OPT": 5, "ALT": 10},
    "NZDCAD": {"OPT": 5, "ALT": 7},
    "AUDNZD": {"OPT": 5, "ALT": 7},
}


def parse_grind(comment: str) -> dict | None:
    m = GRIND_COMMENT_RE.match(comment.strip())
    if not m:
        return None
    return {
        "slot": m.group("slot").upper(),
        "side": m.group("side").upper(),
        "layer": int(m.group("layer")),
        "role": m.group("role").upper(),
    }


def closeby_peer(comment: str) -> tuple[int | None, int | None]:
    m = re.match(r"#(\d+) by #(\d+)", comment.strip())
    if not m:
        return None, None
    return int(m.group(1)), int(m.group(2))


def load_deals(path: Path) -> pd.DataFrame:
    raw = pd.read_csv(path)
    for col in ("profit", "swap", "commission", "position_id", "order", "magic"):
        if col in raw.columns:
            raw[col] = pd.to_numeric(raw[col], errors="coerce")
    raw["time"] = pd.to_datetime(raw["time"])
    raw["comment"] = raw["comment"].fillna("").astype(str)
    raw["entry"] = raw["entry"].fillna("").astype(str).str.upper()
    raw["symbol"] = raw["symbol"].fillna("").astype(str)
    raw["net"] = (
        raw["profit"].fillna(0) + raw["swap"].fillna(0) + raw["commission"].fillna(0)
    )
    return raw.sort_values("time").reset_index(drop=True)


def fmt_num(x: float) -> str:
    if isinstance(x, (float, np.floating)) and np.isinf(x):
        return "inf"
    if isinstance(x, (float, np.floating)) and np.isnan(x):
        return "nan"
    if abs(x) >= 1000:
        return f"{x:.2f}"
    return f"{x:.4g}"


def analyze(df: pd.DataFrame) -> dict:
    dump_start = df.loc[df["symbol"].astype(str).str.len() > 0, "time"].min()
    dump_end = df["time"].max()

    parsed = df["comment"].map(parse_grind)
    df = df.copy()
    df["grind"] = parsed
    df["is_grind"] = df["grind"].notna()

    def grind_role(g: dict | None, role: str) -> bool:
        return g is not None and g.get("role") == role

    ent = df[
        df["is_grind"]
        & df["grind"].map(lambda g: grind_role(g, "ENT"))
        & (df["entry"] == "IN")
        & (df["position_id"] > 0)
    ].copy()
    ent["slot"] = ent["grind"].map(lambda g: g["slot"])
    ent["side"] = ent["grind"].map(lambda g: g["side"])
    ent["layer"] = ent["grind"].map(lambda g: g["layer"])

    ext = df[
        df["is_grind"]
        & df["grind"].map(lambda g: grind_role(g, "EXT"))
        & (df["entry"] == "IN")
        & (df["position_id"] > 0)
    ].copy()

    ent_pos = set(ent["position_id"].astype(int))
    ext_pos = set(ext["position_id"].astype(int))
    ent_time = ent.groupby("position_id")["time"].min()
    ext_time = ext.groupby("position_id")["time"].min()

    # CloseBy scalp pairing (EXT leg present in pair)
    cb = df[(df["entry"] == "OUT_BY") & df["comment"].str.startswith("#")].copy()
    scalp_pairs: list[tuple[int, int, pd.Timestamp]] = []
    closeby_no_ext = 0
    for _order, grp in cb.groupby("order"):
        pos_a, pos_b = closeby_peer(grp["comment"].iloc[0])
        if pos_a is None:
            continue
        has_ext = pos_a in ext_pos or pos_b in ext_pos
        if not has_ext:
            closeby_no_ext += 1
            continue
        if pos_a in ext_pos and pos_b in ent_pos:
            ent_id, ext_id = pos_b, pos_a
        elif pos_b in ext_pos and pos_a in ent_pos:
            ent_id, ext_id = pos_a, pos_b
        else:
            continue
        t_exit = ext_time.get(ext_id, grp["time"].min())
        scalp_pairs.append((ent_id, ext_id, t_exit))

    ent_to_ext: dict[int, tuple[int, pd.Timestamp]] = {}
    for ent_id, ext_id, t_exit in scalp_pairs:
        if ent_id not in ent_to_ext or t_exit < ent_to_ext[ent_id][1]:
            ent_to_ext[ent_id] = (ext_id, t_exit)

    # Positions with exit activity but no ENT row in dump
    all_cb_ent = set()
    for ent_id, _ext_id, _ in scalp_pairs:
        all_cb_ent.add(ent_id)
    ent_missing_in_dump = len(all_cb_ent - ent_pos)

    depth_rows: list[dict] = []
    for (symbol, slot, side), g in ent.groupby(["symbol", "slot", "side"]):
        if symbol not in FLEET:
            continue
        layers = g["layer"].to_numpy()
        n = len(layers)
        dist = {i: int((layers == i).sum()) for i in range(int(layers.max()) + 1)} if n else {}
        beyond = int((layers >= 7).sum())
        shallow = int((layers <= 1).sum())
        depth_rows.append(
            {
                "symbol": symbol,
                "slot": slot,
                "side": side,
                "n_ent": n,
                "layer_counts": dist,
                "pct_at_cap": 100.0 * beyond / n if n else 0.0,
                "pct_shallow": 100.0 * shallow / n if n else 0.0,
                "max_depth_seen": int(layers.max()) if n else 0,
                "mean_depth": float(layers.mean()) if n else float("nan"),
            }
        )

    hold_rows: list[dict] = []
    cross_rows: list[dict] = []

    for symbol in FLEET:
        for slot in ("OPT", "ALT"):
            sub_ent = ent[(ent["symbol"] == symbol) & (ent["slot"] == slot)]
            if sub_ent.empty:
                continue

            holds: list[float] = []
            nets: list[float] = []
            for pid, row in sub_ent.groupby("position_id"):
                pid = int(pid)
                t_ent = row["time"].min()
                if pid in ent_to_ext:
                    _ext_id, t_ext = ent_to_ext[pid]
                    hold_min = (t_ext - t_ent).total_seconds() / 60.0
                    holds.append(hold_min)
                    ext_id = ent_to_ext[pid][0]
                    legs = df[df["position_id"].isin([pid, ext_id])]
                    nets.append(float(legs["net"].sum()))
                else:
                    holds.append(np.inf)

            h = pd.Series(holds, dtype=np.float64)
            if h.empty:
                continue
            h2 = h.fillna(np.inf)
            if np.all(np.isinf(h2.to_numpy())):
                q = pd.Series({0.25: np.inf, 0.5: np.inf, 0.75: np.inf, 0.9: np.inf})
            else:
                q = h2.quantile([0.25, 0.5, 0.75, 0.9])
            never_pct = 100.0 * float(np.isinf(h.to_numpy()).sum()) / len(h)

            # Depth aggregate for cross-cut (both sides)
            dsub = [r for r in depth_rows if r["symbol"] == symbol and r["slot"] == slot]
            total_ent = sum(r["n_ent"] for r in dsub)
            if total_ent:
                mean_depth = sum(r["mean_depth"] * r["n_ent"] for r in dsub) / total_ent
                pct_cap = sum(r["pct_at_cap"] * r["n_ent"] for r in dsub) / total_ent
            else:
                mean_depth = pct_cap = float("nan")

            hold_rows.append(
                {
                    "symbol": symbol,
                    "slot": slot,
                    "n_ent": len(sub_ent),
                    "n_scalp_paired": int(np.sum(np.isfinite(h.to_numpy()))),
                    "never_exited_pct": never_pct,
                    "hold_q25_min": float(q[0.25]),
                    "hold_median_min": float(q[0.5]),
                    "hold_q75_min": float(q[0.75]),
                    "hold_p90_min": float(q[0.9]),
                    "closeby_no_ext_events": closeby_no_ext,
                }
            )

            cross_rows.append(
                {
                    "symbol": symbol,
                    "slot": slot,
                    "add_pips": ADD_PIPS[symbol],
                    "exit_pips": EXIT_PIPS[symbol][slot],
                    "mean_depth": mean_depth,
                    "pct_at_cap": pct_cap,
                    "median_hold_min": float(q[0.5]),
                    "scalps_closed": len(nets),
                    "net_per_scalp": float(np.mean(nets)) if nets else float("nan"),
                }
            )

    return {
        "dump_start": str(dump_start),
        "dump_end": str(dump_end),
        "n_deals": len(df),
        "ent_missing_in_dump": ent_missing_in_dump,
        "closeby_no_ext_events": closeby_no_ext,
        "depth_rows": depth_rows,
        "hold_rows": hold_rows,
        "cross_rows": cross_rows,
    }


def write_report(result: dict, path: Path) -> None:
    lines: list[str] = []
    lines.append("This message has a line count at the bottom")
    lines.append("")
    lines.append("# Geometry: ladder depth and hold time (deals dump)")
    lines.append("")

    # Lead from cross_rows heuristics
    deep = sorted(
        [r for r in result["cross_rows"] if r["mean_depth"] >= 2.5],
        key=lambda r: -r["mean_depth"],
    )
    shallow = sorted(
        [r for r in result["cross_rows"] if r["mean_depth"] <= 1.2],
        key=lambda r: r["mean_depth"],
    )
    fast = [r for r in result["cross_rows"] if r["median_hold_min"] < 5 and np.isfinite(r["median_hold_min"])]
    slow = [r for r in result["cross_rows"] if r["median_hold_min"] > 120 or np.isinf(r["median_hold_min"])]

    lines.append(
        f"Window {result['dump_start']} to {result['dump_end']} ({result['n_deals']} deals). "
        "Nine days, guard-saturated regime; depth readings are guard-affected more than hold time. "
        "Deeper stacking (mean_depth roughly 2.5+): "
        + (", ".join(f"{r['symbol']}/{r['slot']}" for r in deep[:6]) or "none prominent")
        + ". Shallow ladders (mean_depth roughly 1.2 or below): "
        + (", ".join(f"{r['symbol']}/{r['slot']}" for r in shallow[:6]) or "few")
        + ". Fast median holds under 5 min suggest tight exit_pips; "
        "slow or censored medians (2h+ or inf): "
        + (", ".join(f"{r['symbol']}/{r['slot']}" for r in slow[:6]) or "few")
        + ". "
        "No parameter recommendations here -- numbers only."
    )
    lines.append("")
    lines.append("## Method")
    lines.append("")
    lines.append(
        "ENT/EXT on the same position_id: zero rows in this dump. "
        "Scalp hold pairs inventory ENT to EXT leg via CloseBy (#ent by #ext); "
        "exit time is EXT deal time. CloseBy without EXT: reported separately."
    )
    lines.append("")
    lines.append("## Limits")
    lines.append("")
    lines.append(
        "Single regime week; fleet guard-saturated (suppresses entries). "
        f"Positions closed before first dump row without ENT: {result['ent_missing_in_dump']} ent legs excluded. "
        f"CloseBy events without EXT leg in pair: {result['closeby_no_ext_events']} (none in this dump if zero)."
    )
    lines.append("")
    lines.append("## Measurement 1 -- ladder depth")
    lines.append("")
    for row in result["depth_rows"]:
        lines.append(
            f"### {row['symbol']} {row['slot']} {row['side']} "
            f"(n={row['n_ent']} mean_depth={row['mean_depth']:.3f} "
            f"pct_at_cap={row['pct_at_cap']:.2f} pct_shallow={row['pct_shallow']:.2f} "
            f"max={row['max_depth_seen']})"
        )
        parts = [f"L{k}={v}" for k, v in sorted(row["layer_counts"].items())]
        lines.append("  " + " ".join(parts))
        lines.append("")

    lines.append("## Measurement 2 -- hold time (EXT scalp via CloseBy)")
    lines.append("")
    lines.append(
        "Hold quantiles include unclosed entries as inf. "
        "net_per_scalp uses closed positions only (both legs summed)."
    )
    lines.append("")
    for row in result["hold_rows"]:
        lines.append(
            f"{row['symbol']} {row['slot']}: entries={row['n_ent']} "
            f"scalp_paired={row['n_scalp_paired']} never_exited_pct={row['never_exited_pct']:.2f} "
            f"q25={fmt_num(row['hold_q25_min'])} med={fmt_num(row['hold_median_min'])} "
            f"q75={fmt_num(row['hold_q75_min'])} p90={fmt_num(row['hold_p90_min'])} min"
        )
    lines.append("")

    lines.append("## Cross-cut")
    lines.append("")
    lines.append(
        "| symbol | arm | add_pips | exit_pips | mean_depth | pct_at_cap | "
        "median_hold_min | scalps | net_per_scalp |"
    )
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for r in result["cross_rows"]:
        lines.append(
            f"| {r['symbol']} | {r['slot']} | {r['add_pips']} | {r['exit_pips']} | "
            f"{r['mean_depth']:.3f} | {r['pct_at_cap']:.2f} | "
            f"{fmt_num(r['median_hold_min'])} | {r['scalps_closed']} | "
            f"{fmt_num(r['net_per_scalp'])} |"
        )
    lines.append("")
    lines.append(f"Line count: {len(lines) + 1}")
    path.write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace")


def main() -> None:
    df = load_deals(DUMP)
    result = analyze(df)
    report = ROOT / "prompts" / "geometry_depth_holdtime.md"
    write_report(result, report)
    print(f"Wrote {report}")


if __name__ == "__main__":
    main()
