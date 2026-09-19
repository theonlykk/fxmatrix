"""One-off cycle P&L reconciliation. Analysis only; not imported by EA."""
import re
from pathlib import Path

import pandas as pd

DUMP = Path("D:/fxmatrix/data/deals_dump_20260918_2354.csv")
GRIND_COMMENT_RE = re.compile(
    r"^GRIND\|(?P<slot>OPT|ALT)\|(?P<side>L|S)\|L(?P<layer>\d+)\|(?P<role>ENT|EXT)",
    re.I,
)


def load_deals(path: Path) -> pd.DataFrame:
    raw = pd.read_csv(path)
    for col in (
        "profit",
        "swap",
        "commission",
        "volume",
        "price",
        "magic",
        "position_id",
        "order",
        "reason",
    ):
        if col in raw.columns:
            raw[col] = pd.to_numeric(raw[col], errors="coerce")
    raw["time"] = pd.to_datetime(raw["time"])
    raw["comment"] = raw["comment"].fillna("").astype(str)
    raw["entry"] = raw["entry"].fillna("").astype(str).str.upper()
    raw["type"] = raw["type"].fillna("").astype(str).str.lower()
    raw["symbol"] = raw["symbol"].fillna("").astype(str)
    raw["net"] = raw["profit"].fillna(0) + raw["swap"].fillna(0) + raw["commission"].fillna(0)
    return raw.sort_values("time").reset_index(drop=True)


def grind_role(comment: str) -> str | None:
    m = GRIND_COMMENT_RE.match(comment)
    return m.group("role").upper() if m else None


def closeby_peer(comment: str) -> tuple[int | None, int | None]:
    m = re.match(r"#(\d+) by #(\d+)", comment.strip())
    if not m:
        return None, None
    return int(m.group(1)), int(m.group(2))


def main() -> None:
    df = load_deals(DUMP)

    ext_positions = set(df.loc[df["comment"].str.contains(r"\|EXT$", regex=True), "position_id"].astype(int))
    ent_positions = set(df.loc[df["comment"].str.contains(r"\|ENT$", regex=True), "position_id"].astype(int))

    closes = df[df["entry"].isin(["OUT", "OUT_BY"])].copy()

    def classify_close(row) -> str:
        c = row["comment"]
        if c.startswith("#") and row["entry"] == "OUT_BY":
            pos_a, pos_b = closeby_peer(c)
            if pos_b in ext_positions or pos_a in ext_positions:
                return "closeby_scalp"
            return "closeby_other"
        if row["entry"] == "OUT":
            if row["magic"] == 0 or "GRIND" not in c:
                return "manual_or_other_out"
            return "grind_out"
        if row["entry"] == "OUT_BY" and not c.startswith("#"):
            return "closeby_unparsed"
        return "other_close"

    closes["category"] = closes.apply(classify_close, axis=1)

    # CloseBy events: aggregate both legs by order id
    cb = closes[closes["entry"] == "OUT_BY"].copy()
    cb["pos_a"], cb["pos_b"] = zip(*cb["comment"].map(closeby_peer))
    cb["is_scalp"] = cb.apply(
        lambda r: (r["pos_a"] in ext_positions or r["pos_b"] in ext_positions),
        axis=1,
    )
    cb_events = (
        cb.groupby("order", as_index=False)
        .agg(
            time=("time", "min"),
            symbol=("symbol", "first"),
            net=("net", "sum"),
            profit=("profit", "sum"),
            commission=("commission", "sum"),
            swap=("swap", "sum"),
            is_scalp=("is_scalp", "max"),
            comment=("comment", "first"),
        )
        .sort_values("time")
    )

    ext_deals = df[df["comment"].str.contains(r"\|EXT$", regex=True)]
    ext_count = len(ext_deals)

    scalp_events = cb_events[cb_events["is_scalp"]]
    non_scalp_cb = cb_events[~cb_events["is_scalp"]]
    out_only = closes[closes["entry"] == "OUT"]

    # Manual rolls window (broker time per dump; operator cited UTC)
    rolls = df[
        (df["symbol"] == "GBPUSD")
        & (df["time"] >= pd.Timestamp("2026-09-17 14:29:00"))
        & (df["time"] <= pd.Timestamp("2026-09-17 16:27:59"))
        & (df["entry"] == "OUT")
        & (~df["comment"].str.contains("GRIND", na=False))
    ]

    # Opening commissions on ENT/EXT (not closes)
    opens = df[df["entry"] == "IN"].copy()
    opens["category"] = opens["comment"].map(
        lambda c: "ext_open" if c.endswith("|EXT") else ("ent_open" if c.endswith("|ENT") else "other_in")
    )

    print("SCHEMA rows", len(df))
    print("Balance deals", df[df["type"] == "unknown"]["comment"].tolist())
    print("Cum net final", df["net"].sum())
    print("Trading net ex deposit", df["net"].sum() - 10000.0)
    print("EXT count", ext_count)
    print("Scalp closeby events", len(scalp_events), "net", scalp_events["net"].sum())
    print("Non-scalp closeby events", len(non_scalp_cb), "net", non_scalp_cb["net"].sum())
    print("OUT deals", len(out_only), "net", out_only["net"].sum())
    print("Manual rolls", len(rolls), "net", rolls["net"].sum())
    print("ENT open net", opens.loc[opens["category"] == "ent_open", "net"].sum())
    print("EXT open net", opens.loc[opens["category"] == "ext_open", "net"].sum())

    # Pipshed-style scalp: closeby scalp profit + commissions on ENT/EXT opens?
    scalp_gross_profit = scalp_events["profit"].sum()
    scalp_comm = scalp_events["commission"].sum()
    open_comm = opens.loc[opens["category"].isin(["ent_open", "ext_open"]), "commission"].sum()
    print("Scalp CB profit (gross)", scalp_gross_profit)
    print("Scalp CB commission", scalp_comm)
    print("Open ENT+EXT commission", open_comm)

    # Category table for group 2 (non-scalp realised on closes + balance)
    group2_parts = []
    for name, sub in [
        ("closeby_non_scalp", non_scalp_cb),
        ("out_manual_grind", out_only),
        ("ent_open_commission", opens[opens["category"] == "ent_open"]),
        ("ext_open_commission", opens[opens["category"] == "ext_open"]),
        ("other_in", opens[opens["category"] == "other_in"]),
        ("swap_on_non_close", df[~df["entry"].isin(["OUT", "OUT_BY"]) & (df["swap"] != 0)]),
    ]:
        group2_parts.append((name, len(sub), sub["net"].sum()))

    print("\nGROUP2 PARTS:")
    for row in group2_parts:
        print(row)

    # Full partition: everything except scalp closeby events and ext/ent marker deals
    scalp_net = scalp_events["net"].sum() + opens.loc[
        opens["category"].isin(["ent_open", "ext_open"]), "net"
    ].sum()
    print("Scalp all-in (cb net + open comm on ent/ext)", scalp_net)

    # Alternative: attribute all ENT+EXT commission + scalp CB to scalps
    total_non_scalp = df["net"].sum() - 10000.0 - scalp_events["net"].sum()
    print("Residual if only subtract scalp CB from trading net", total_non_scalp)

    print("\nLargest non-scalp losses (closes):")
    non_scalp_closes = closes[~closes.index.isin(scalp_events.index) if False else []]
    # use close-level rows not in scalp cb orders
    scalp_orders = set(scalp_events["order"])
    non_scalp_close_rows = closes[~((closes["entry"] == "OUT_BY") & closes["order"].isin(scalp_orders))]
    if ext_count:
        pass
    non_scalp_close_rows = df[
        df["entry"].isin(["OUT", "OUT_BY"])
        & ~((df["entry"] == "OUT_BY") & df["order"].isin(scalp_orders))
    ].copy()
    non_scalp_close_rows = non_scalp_close_rows.sort_values("net").head(10)
    print(non_scalp_close_rows[["time", "symbol", "net", "comment"]].to_string())

    print("\nManual rolls detail:")
    print(rolls[["time", "symbol", "profit", "commission", "net", "comment"]].to_string())


if __name__ == "__main__":
    main()
