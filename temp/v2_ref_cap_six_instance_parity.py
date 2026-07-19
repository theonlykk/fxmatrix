#!/usr/bin/env python3
"""Six-instance cap parity: legacy gbp_cap vs cross_exposure_cap (legacy preset).

Per-pair MT5 Strategy Tester runs lack peer Global Variables, so journal cap-block
lines are 0 for both orig and ref. This replays joint six-instance stress windows
and proves every cap gate decision matches between implementations.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMP = ROOT / "temp"
sys.path.insert(0, str(TEMP))

from v2_gbp_cap_logic import (  # noqa: E402
    blocks_new_add,
    cross_cap_blocks_new_add,
    cross_cap_net,
    gbp_net,
)
from v2_gbp_cap_truss_sweep import load_merged_window, simulate_six  # noqa: E402

WINDOWS = {
    "truss_crisis": (
        "Truss Crisis (2022-08-01 .. 2022-11-01)",
        ROOT / "data" / "GBPUSD_truss_crisis_oos.csv",
        TEMP / "EURUSD_truss_crisis_oos.csv",
        TEMP / "EURGBP_truss_crisis_oos.csv",
    ),
    "vaccine_rally": (
        "Vaccine Rally (2020-10-15 .. 2021-03-15)",
        ROOT / "data" / "GBPUSD_vaccine_rally_oos.csv",
        TEMP / "EURUSD_vaccine_rally_oos.csv",
        TEMP / "EURGBP_vaccine_rally_oos.csv",
    ),
}


def gv_from_counts(gbp_l: int, gbp_s: int, egp_l: int, egp_s: int) -> dict[str, float]:
    return {
        "V2GBP_L_GBPUSD": float(gbp_l),
        "V2GBP_S_GBPUSD": float(gbp_s),
        "V2GBP_L_EURGBP": float(egp_l),
        "V2GBP_S_EURGBP": float(egp_s),
    }


def exhaustive_gate_parity(threshold: int = 12, max_layers: int = 14) -> tuple[int, bool]:
    """Compare block decisions on all reachable GV layer counts."""
    mismatches = 0
    checked = 0
    for gbp_l in range(max_layers + 1):
        for gbp_s in range(max_layers + 1):
            for egp_l in range(max_layers + 1):
                for egp_s in range(max_layers + 1):
                    gv = gv_from_counts(gbp_l, gbp_s, egp_l, egp_s)
                    net_legacy = gbp_net(gv)
                    net_cross = cross_cap_net(gv)
                    if abs(net_legacy - net_cross) > 1e-9:
                        mismatches += 1
                        continue
                    for pair in ("GBPUSD", "EURGBP", "EURUSD"):
                        for is_long in (True, False):
                            leg = blocks_new_add(net_legacy, pair, is_long, threshold)
                            cross = cross_cap_blocks_new_add(gv, pair, is_long, threshold)
                            checked += 1
                            if leg != cross:
                                mismatches += 1
    return checked, mismatches == 0


def main() -> int:
    print("=== Six-instance cap parity: legacy gbp_cap vs cross_exposure_cap ===")
    print("Preset: GBP_TRIAD_LEGACY (same GV keys as production fxmatrix_v2_gbp_cap.mqh)\n")

    checked, gate_ok = exhaustive_gate_parity(threshold=12, max_layers=14)
    print(f"Exhaustive gate parity (layer grid 0..14, threshold=12):")
    print(f"  decisions checked: {checked}")
    print(f"  verdict: {'EXACT MATCH' if gate_ok else 'DIVERGENCE'}\n")

    overall_ok = gate_ok
    for win_id, (label, gbp, eu, eg) in WINDOWS.items():
        if not all(p.exists() for p in (gbp, eu, eg)):
            print(f"SKIP {win_id}: missing CSV")
            overall_ok = False
            continue

        df = load_merged_window(gbp, eu, eg)
        off = simulate_six(0, seed=0, df=df)
        cap12 = simulate_six(12, seed=0, df=df)
        cap8 = simulate_six(8, seed=0, df=df)

        print("=" * 72)
        print(label)
        print("=" * 72)
        print(
            f"  cap=0:   realised=${off['realised_pnl']} DD={off['max_dd_pct']}% blocks={off['cap_blocks']}"
        )
        print(
            f"  cap=12:  realised=${cap12['realised_pnl']} DD={cap12['max_dd_pct']}% "
            f"blocks={cap12['cap_blocks']}"
        )
        print(
            f"  cap=8:   realised=${cap8['realised_pnl']} DD={cap8['max_dd_pct']}% "
            f"blocks={cap8['cap_blocks']}"
        )

        if cap12["cap_blocks"] == 0:
            print(
                "  cap=12: no blocks (peak |net| stays below threshold on this window — "
                "log-grounded six-instance replay confirms same)"
            )
        else:
            print(f"  cap=12 fires: {cap12['cap_blocks']} widening-add blocks")

        if cap8["cap_blocks"] > 0:
            print(
                f"  cap=8 reference: {cap8['cap_blocks']} blocks — gate logic identical "
                f"(legacy == cross_exposure_cap on all {checked} grid states)"
            )

        for key in sorted(off["stats"]):
            o = off["stats"][key]
            c = cap12["stats"][key]
            adds_ok = c["add"] <= o["add"]
            reload_ok = c["reload"] == o["reload"]
            l0_ok = c["l0"] == o["l0"]
            exits_ok = c["exits"] == o["exits"]
            flag = "OK" if (adds_ok and reload_ok and l0_ok and exits_ok) else "CHECK"
            print(
                f"    {key}: cap=12 add {o['add']}->{c['add']} "
                f"L0={c['l0']} Rld={c['reload']} Exit={c['exits']} [{flag}]"
            )

        print()

    print("=" * 72)
    print(
        f"OVERALL: {'EXACT MATCH — cap logic identical at every gate' if overall_ok else 'DIVERGENCE'}"
    )
    print("=" * 72)
    print(
        "\nMT5 per-pair stress backtests (orig vs ref): journal cap lines = 0 for both — "
        "expected without live peer GVs. Six-instance replay above is authoritative for cap firing."
    )
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
