"""Counterfactual for 17-Sep GBPUSD force closes. Local analysis only."""
import re
from pathlib import Path

import pandas as pd

DUMP = Path("D:/fxmatrix/data/deals_dump_20260918_2354.csv")
LAST_PRICE = 1.33955
PIP_VALUE = 0.10
EXIT_COMM = -0.03


def peers(comment: str):
    m = re.match(r"#(\d+) by #(\d+)", str(comment).strip())
    return (int(m.group(1)), int(m.group(2))) if m else (None, None)


def main() -> None:
    df = pd.read_csv(DUMP)
    for col in ("profit", "swap", "commission", "position_id", "magic", "price", "volume", "order"):
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df["time"] = pd.to_datetime(df["time"])
    df["comment"] = df["comment"].fillna("").astype(str)
    df["entry"] = df["entry"].str.upper()
    df["net"] = df["profit"].fillna(0) + df["swap"].fillna(0) + df["commission"].fillna(0)

    out = df[(df["symbol"] == "GBPUSD") & (df["entry"] == "OUT") & (df["magic"] == 0)]
    closes = out[
        out["time"].between("2026-09-17 06:23:00", "2026-09-17 06:29:59")
        | out["time"].between("2026-09-17 17:32:00", "2026-09-17 19:26:59")
    ].sort_values("time")

    ents = df[(df["entry"] == "IN") & df["comment"].str.endswith("|ENT")].set_index("position_id")
    exts = df[
        (df["symbol"] == "GBPUSD") & (df["entry"] == "IN") & df["comment"].str.endswith("|EXT")
    ].sort_values("time")
    all_ext_pos = set(
        df[(df["symbol"] == "GBPUSD") & df["comment"].str.endswith("|EXT")]["position_id"].astype(int)
    )

    def scalp_window(start, end):
        cb = df[
            (df["symbol"] == "GBPUSD")
            & (df["entry"] == "OUT_BY")
            & (df["time"] >= start)
            & (df["time"] <= end)
        ].copy()
        cb["a"], cb["b"] = zip(*cb["comment"].map(peers))
        cb["scalp"] = cb.apply(lambda r: r["a"] in all_ext_pos or r["b"] in all_ext_pos, axis=1)
        ev = cb[cb["scalp"]].groupby("order")["net"].sum()
        ext_n = len(exts[(exts["time"] >= start) & (exts["time"] <= end)])
        return ext_n, len(ev), float(ev.sum())

    c1_end = closes[closes["time"] < "2026-09-17 12:00"]["time"].max()
    c2_end = closes[closes["time"] >= "2026-09-17 12:00"]["time"].max()
    for label, end in [("cluster1", c1_end), ("cluster2", c2_end)]:
        s = end + pd.Timedelta(seconds=1)
        e = end + pd.Timedelta(hours=4)
        n = scalp_window(s, e)
        cs = end - pd.Timedelta(days=1) + pd.Timedelta(seconds=1)
        ce = cs + pd.Timedelta(hours=4)
        c = scalp_window(cs, ce)
        print(label, "after", s, "to", e, n, "control", c)

    mtm_sum = 0.0
    for _, c in closes.iterrows():
        e = ents.loc[int(c["position_id"])]
        if isinstance(e, pd.DataFrame):
            e = e.iloc[0]
        arm = "OPT" if int(e["magic"]) == 22260101 else "ALT"
        ep = 7 if arm == "OPT" else 10
        tgt = float(e["price"]) + ep * 0.0001
        after = exts[exts["time"] > c["time"]]
        hi = after["price"].max()
        ht = after.loc[after["price"].idxmax(), "time"]
        mtm = (LAST_PRICE - float(e["price"])) / 0.0001 * PIP_VALUE
        mtm_sum += mtm
        print(
            int(c["position_id"]),
            c["time"],
            f"{c['net']:.2f}",
            e["time"],
            f"{float(e['price']):.5f}",
            arm,
            f"{tgt:.5f}",
            f"{hi:.5f}",
            ht,
            f"{mtm:.2f}",
        )
    print("actual", closes["net"].sum(), "mtm", mtm_sum, "diff", mtm_sum - closes["net"].sum())


if __name__ == "__main__":
    main()
