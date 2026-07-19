#!/usr/bin/env python3
"""Run MT5 backtests: original V2 EAs vs Phase-1 *_ref.ex5 on shared verify windows.

Compares V2_STATS_LONG/SHORT counts, in-test realized P&L (tester HTML deals),
and GBP-cap block events (side + net at each trigger) from tester journal logs.
Does not modify production .mq5 sources.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EA = ROOT / "ea"
TEMP = ROOT / "temp"
TERMINAL_EXE = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe")
TERM = Path(
    r"C:\Users\Khalid Khan\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)
EXPERTS = TERM / "MQL5" / "Experts"
CONFIG = TERM / "config"
REPORT_DIR = TERM

REF_EX5 = (
    "fxmatrix_v2_ref.ex5",
    "fxmatrix_v2_eurusd_ref.ex5",
    "fxmatrix_v2_eurgbp_ref.ex5",
)

SUITES = [
    {
        "id": "gbpusd_5day",
        "pair": "GBPUSD",
        "symbol": "GBPUSD",
        "orig_expert": "fxmatrix_v2.ex5",
        "ref_expert": "fxmatrix_v2_ref.ex5",
        "orig_ini": TEMP / "v2_production_5day_verify.ini",
        "from_date": "2026.03.09",
        "to_date": "2026.03.14",
        "long_magic": 20260901,
        "short_magic": 20260902,
        "cap_threshold": None,
    },
    {
        "id": "gbpusd_full_quarter",
        "pair": "GBPUSD",
        "symbol": "GBPUSD",
        "orig_expert": "fxmatrix_v2.ex5",
        "ref_expert": "fxmatrix_v2_ref.ex5",
        "orig_ini": TEMP / "v2_production_full_quarter_verify.ini",
        "from_date": "2026.03.09",
        "to_date": "2026.06.06",
        "long_magic": 20260901,
        "short_magic": 20260902,
        "cap_threshold": 12,
    },
    {
        "id": "eurusd_full_quarter",
        "pair": "EURUSD",
        "symbol": "EURUSD",
        "orig_expert": "fxmatrix_v2_eurusd.ex5",
        "ref_expert": "fxmatrix_v2_eurusd_ref.ex5",
        "orig_ini": TEMP / "v2_eurusd_full_quarter_verify.ini",
        "from_date": "2026.03.09",
        "to_date": "2026.06.06",
        "long_magic": 20260911,
        "short_magic": 20260912,
        "cap_threshold": None,
    },
    {
        "id": "eurgbp_full_quarter",
        "pair": "EURGBP",
        "symbol": "EURGBP",
        "orig_expert": "fxmatrix_v2_eurgbp.ex5",
        "ref_expert": "fxmatrix_v2_eurgbp_ref.ex5",
        "orig_ini": TEMP / "v2_eurgbp_full_quarter_verify.ini",
        "from_date": "2026.03.09",
        "to_date": "2026.06.06",
        "long_magic": 20260921,
        "short_magic": 20260922,
        "cap_threshold": 12,
    },
]

STRESS_SUITES = [
    {
        "id": "gbpusd_truss_crisis",
        "pair": "GBPUSD",
        "symbol": "GBPUSD",
        "orig_expert": "fxmatrix_v2.ex5",
        "ref_expert": "fxmatrix_v2_ref.ex5",
        "orig_ini": TEMP / "v2_gbpusd_truss_crisis_six.ini",
        "from_date": "2022.08.01",
        "to_date": "2022.11.01",
        "long_magic": 20260901,
        "short_magic": 20260902,
        "cap_threshold": None,
        "check_cap_blocks": True,
    },
    {
        "id": "eurusd_truss_crisis",
        "pair": "EURUSD",
        "symbol": "EURUSD",
        "orig_expert": "fxmatrix_v2_eurusd.ex5",
        "ref_expert": "fxmatrix_v2_eurusd_ref.ex5",
        "orig_ini": TEMP / "v2_eurusd_truss_crisis_six.ini",
        "from_date": "2022.08.01",
        "to_date": "2022.11.01",
        "long_magic": 20260911,
        "short_magic": 20260912,
        "cap_threshold": None,
        "check_cap_blocks": False,
    },
    {
        "id": "eurgbp_truss_crisis",
        "pair": "EURGBP",
        "symbol": "EURGBP",
        "orig_expert": "fxmatrix_v2_eurgbp.ex5",
        "ref_expert": "fxmatrix_v2_eurgbp_ref.ex5",
        "orig_ini": TEMP / "v2_eurgbp_truss_crisis_six.ini",
        "from_date": "2022.08.01",
        "to_date": "2022.11.01",
        "long_magic": 20260921,
        "short_magic": 20260922,
        "cap_threshold": None,
        "check_cap_blocks": True,
    },
    {
        "id": "gbpusd_vaccine_rally",
        "pair": "GBPUSD",
        "symbol": "GBPUSD",
        "orig_expert": "fxmatrix_v2.ex5",
        "ref_expert": "fxmatrix_v2_ref.ex5",
        "orig_ini": TEMP / "v2_gbpusd_vaccine_rally_six.ini",
        "from_date": "2020.10.15",
        "to_date": "2021.03.15",
        "long_magic": 20260901,
        "short_magic": 20260902,
        "cap_threshold": None,
        "check_cap_blocks": True,
    },
    {
        "id": "eurusd_vaccine_rally",
        "pair": "EURUSD",
        "symbol": "EURUSD",
        "orig_expert": "fxmatrix_v2_eurusd.ex5",
        "ref_expert": "fxmatrix_v2_eurusd_ref.ex5",
        "orig_ini": TEMP / "v2_eurusd_vaccine_rally_six.ini",
        "from_date": "2020.10.15",
        "to_date": "2021.03.15",
        "long_magic": 20260911,
        "short_magic": 20260912,
        "cap_threshold": None,
        "check_cap_blocks": False,
    },
    {
        "id": "eurgbp_vaccine_rally",
        "pair": "EURGBP",
        "symbol": "EURGBP",
        "orig_expert": "fxmatrix_v2_eurgbp.ex5",
        "ref_expert": "fxmatrix_v2_eurgbp_ref.ex5",
        "orig_ini": TEMP / "v2_eurgbp_vaccine_rally_six.ini",
        "from_date": "2020.10.15",
        "to_date": "2021.03.15",
        "long_magic": 20260921,
        "short_magic": 20260922,
        "cap_threshold": None,
        "check_cap_blocks": True,
    },
]

CAP_BLOCK_RE = re.compile(
    r"INFO V2_(LONG|SHORT) \| GBP cap blocked new add net=([-\d.]+)"
)


@dataclass
class SideStats:
    l0: int = -1
    add: int = -1
    reload: int = -1
    exits: int = -1
    max_layers: int = -1


@dataclass
class CapBlockEvent:
    side: str
    net: float


@dataclass
class RunResult:
    expert: str
    side_long: SideStats = field(default_factory=SideStats)
    side_short: SideStats = field(default_factory=SideStats)
    long_pnl: float = 0.0
    short_pnl: float = 0.0
    combined_pnl: float = 0.0
    cap_blocks: list[CapBlockEvent] = field(default_factory=list)
    report_path: Path | None = None
    log_marker: str = ""


def sync_ref_ex5() -> None:
    for name in REF_EX5:
        src = EA / name
        dst = EXPERTS / name
        if not src.is_file():
            raise FileNotFoundError(f"Missing compiled EA: {src}")
        shutil.copy2(src, dst)
        print(f"Synced {name} -> {dst}")


def make_ini(
    suite: dict,
    expert: str,
    report_name: str,
    cap_threshold: int | None,
) -> str:
    base = suite["orig_ini"].read_text(encoding="utf-8")
    lines = []
    in_tester = False
    in_inputs = False
    for raw in base.splitlines():
        line = raw
        if raw.strip().startswith("[Tester]"):
            in_tester = True
            in_inputs = False
        elif raw.strip().startswith("[TesterInputs]"):
            in_tester = False
            in_inputs = True
        elif raw.strip().startswith("[") and not raw.strip().startswith("[Tester"):
            in_tester = False
            in_inputs = False

        if in_tester:
            if raw.strip().startswith("Expert="):
                line = f"Expert={expert}"
            elif raw.strip().startswith("Symbol="):
                line = f"Symbol={suite['symbol']}"
            elif raw.strip().startswith("FromDate="):
                line = f"FromDate={suite['from_date'].replace('.', '')[:8]}"
                # keep dotted form from suite
                line = f"FromDate={suite['from_date']}"
            elif raw.strip().startswith("ToDate="):
                line = f"ToDate={suite['to_date']}"
            elif raw.strip().startswith("Report="):
                line = f"Report={report_name}"
        lines.append(line)

    if cap_threshold is not None:
        out = []
        replaced = False
        for line in lines:
            if line.strip().startswith("InpGbpCapThreshold="):
                out.append(
                    f"InpGbpCapThreshold={cap_threshold}||{cap_threshold}||1||20||N"
                )
                replaced = True
            else:
                out.append(line)
        if not replaced:
            # insert before first blank after TesterInputs block
            idx = next(
                (i for i, l in enumerate(out) if l.strip().startswith("InpVerboseLog=")),
                len(out),
            )
            out.insert(
                idx,
                f"InpGbpCapThreshold={cap_threshold}||{cap_threshold}||1||20||N",
            )
        lines = out

    return "\n".join(lines) + "\n"


def run_backtest(ini_path: Path, timeout_sec: int = 3600) -> None:
    print(f"  Launching MT5: {ini_path.name}")
    proc = subprocess.run(
        [str(TERMINAL_EXE), f"/config:{ini_path}"],
        capture_output=True,
        text=True,
        timeout=timeout_sec,
    )
    if proc.returncode not in (0, None):
        print(f"  terminal64 exit code: {proc.returncode}")


def tester_log_path() -> Path:
    today = date.today().strftime("%Y%m%d")
    return TERM / "Tester" / "logs" / f"{today}.log"


def read_log() -> str:
    p = tester_log_path()
    if not p.is_file():
        # fallback: latest log in folder
        logs = sorted((TERM / "Tester" / "logs").glob("*.log"), key=lambda x: x.stat().st_mtime)
        if not logs:
            return ""
        p = logs[-1]
    return p.read_text(encoding="utf-16-le", errors="ignore")


def parse_stats_line(line: str) -> SideStats:
    out = SideStats()
    for key, attr in (
        ("l0", "l0"),
        ("add", "add"),
        ("reload", "reload"),
        ("exits", "exits"),
        ("max_layers", "max_layers"),
    ):
        m = re.search(rf"{key}=(\d+)", line)
        if m:
            setattr(out, attr, int(m.group(1)))
    return out


def extract_run_block(log: str, marker: str) -> str:
    idx = log.rfind(marker)
    if idx < 0:
        return ""
    rest = log[idx:]
    nxt = re.search(r"fxmatrix_v2(?:_eurusd|_eurgbp|_ref)?(?:_eurusd|_eurgbp)?\.ex5 from|testing of Experts", rest[10:])
    end = 10 + nxt.start() if nxt else len(rest)
    return rest[:end]


def parse_cap_blocks(block: str) -> list[CapBlockEvent]:
    events: list[CapBlockEvent] = []
    for side, net_raw in CAP_BLOCK_RE.findall(block):
        events.append(CapBlockEvent(side=side, net=float(net_raw)))
    return events


def parse_run(log: str, expert: str, from_date: str, to_date: str, symbol: str, long_magic: int, short_magic: int, report_name: str) -> RunResult:
    marker = f"{expert} from {from_date} 00:00 to {to_date}"
    block = extract_run_block(log, marker)
    res = RunResult(expert=expert, log_marker=marker, report_path=REPORT_DIR / f"{report_name}.htm")
    long_lines = re.findall(r"V2_STATS_LONG \| ([^\n]+)", block)
    short_lines = re.findall(r"V2_STATS_SHORT \| ([^\n]+)", block)
    if long_lines:
        res.side_long = parse_stats_line(long_lines[-1])
    if short_lines:
        res.side_short = parse_stats_line(short_lines[-1])
    res.cap_blocks = parse_cap_blocks(block)
    if res.report_path and res.report_path.is_file():
        res.long_pnl, res.short_pnl, res.combined_pnl = read_html_pnl(
            res.report_path, symbol, long_magic, short_magic
        )
    return res


def read_html_pnl(path: Path, symbol: str, long_magic: int, short_magic: int) -> tuple[float, float, float]:
    html = path.read_text(encoding="utf-16-le", errors="ignore")
    part = html.split("<b>Deals</b>")[-1] if "<b>Deals</b>" in html else html
    rows = re.findall(r"<tr[^>]*align=right>(.*?)</tr>", part, re.S)
    long_pnl = short_pnl = combined = 0.0
    for row in rows:
        if "end of test" in row.lower():
            continue
        cells = [
            re.sub(r"<[^>]+>", "", c).strip()
            for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)
        ]
        if len(cells) < 11:
            continue
        if cells[2] != symbol:
            continue
        profit = float(cells[10].replace(" ", "").replace(",", ""))
        combined += profit
        magic_raw = cells[11] if len(cells) > 11 else ""
        magic_digits = re.sub(r"\D", "", magic_raw)
        if magic_digits:
            magic = int(magic_digits)
            if magic == long_magic:
                long_pnl += profit
            elif magic == short_magic:
                short_pnl += profit
    return round(long_pnl, 2), round(short_pnl, 2), round(combined, 2)


def compare_side(label: str, orig: SideStats, ref: SideStats) -> list[str]:
    lines = []
    ok = True
    for key in ("l0", "add", "reload", "exits", "max_layers"):
        o = getattr(orig, key)
        r = getattr(ref, key)
        match = o == r
        ok &= match
        mark = "OK" if match else "DIFF"
        lines.append(f"    {label} {key:<11} orig={o:>5} ref={r:>5} [{mark}]")
    return lines


def compare_pnl(label: str, orig: float, ref: float) -> str:
    match = orig == ref
    delta = round(ref - orig, 2)
    mark = "OK" if match else f"DIFF (delta={delta:+.2f})"
    return f"    {label:<10} orig=${orig:>8.2f} ref=${ref:>8.2f} [{mark}]"


def compare_cap_blocks(orig: RunResult, ref: RunResult) -> tuple[list[str], bool]:
    lines: list[str] = []
    ok = orig.cap_blocks == ref.cap_blocks
    lines.append(
        f"    cap_block_count orig={len(orig.cap_blocks)} ref={len(ref.cap_blocks)} "
        f"[{'OK' if len(orig.cap_blocks) == len(ref.cap_blocks) else 'DIFF'}]"
    )
    if not ok:
        n = max(len(orig.cap_blocks), len(ref.cap_blocks))
        for i in range(n):
            o = orig.cap_blocks[i] if i < len(orig.cap_blocks) else None
            r = ref.cap_blocks[i] if i < len(ref.cap_blocks) else None
            if o == r:
                mark = "OK"
            else:
                mark = "DIFF"
                ok = False
            o_s = f"{o.side} net={o.net}" if o else "—"
            r_s = f"{r.side} net={r.net}" if r else "—"
            lines.append(f"      [{i:>4}] orig={o_s:<18} ref={r_s:<18} [{mark}]")
    elif orig.cap_blocks:
        long_n = sum(1 for e in orig.cap_blocks if e.side == "LONG")
        short_n = sum(1 for e in orig.cap_blocks if e.side == "SHORT")
        lines.append(f"    cap_sequence exact: LONG={long_n} SHORT={short_n} events identical")
    else:
        lines.append("    cap_blocks: none in either run (cap inactive or threshold=0)")
    return lines, ok


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="V2 orig vs ref MT5 parity runner")
    p.add_argument(
        "--stress-only",
        action="store_true",
        help="Run Truss Crisis + Vaccine Rally suites only",
    )
    p.add_argument(
        "--calm-only",
        action="store_true",
        help="Run calm-window suites only (default when no flag)",
    )
    p.add_argument(
        "--all",
        action="store_true",
        help="Run calm + stress suites",
    )
    return p.parse_args()


def select_suites(args: argparse.Namespace) -> list[dict]:
    if args.stress_only:
        return STRESS_SUITES
    if args.all:
        return SUITES + STRESS_SUITES
    return SUITES


def main() -> int:
    args = parse_args()
    suites = select_suites(args)

    sync_ref_ex5()
    overall_ok = True
    results: dict[str, tuple[RunResult, RunResult]] = {}

    for suite in suites:
        print("\n" + "=" * 72)
        print(f"Suite: {suite['id']}")
        print("=" * 72)

        for variant, expert_key in (("orig", "orig_expert"), ("ref", "ref_expert")):
            expert = suite[expert_key]
            report = f"v2_ref_parity_{suite['id']}_{variant}"
            ini_name = f"v2_ref_parity_{suite['id']}_{variant}.ini"
            ini_text = make_ini(suite, expert, report, suite.get("cap_threshold"))
            ini_path = CONFIG / ini_name
            ini_path.write_text(ini_text, encoding="utf-8")
            TEMP_INI = TEMP / ini_name
            TEMP_INI.write_text(ini_text, encoding="utf-8")

            t0 = time.time()
            run_backtest(ini_path)
            elapsed = time.time() - t0
            print(f"  {variant} finished in {elapsed:.0f}s")

            # wait for report file
            report_path = REPORT_DIR / f"{report}.htm"
            for _ in range(60):
                if report_path.is_file():
                    break
                time.sleep(1)

        log = read_log()
        orig = parse_run(
            log,
            suite["orig_expert"],
            suite["from_date"],
            suite["to_date"],
            suite["symbol"],
            suite["long_magic"],
            suite["short_magic"],
            f"v2_ref_parity_{suite['id']}_orig",
        )
        ref = parse_run(
            log,
            suite["ref_expert"],
            suite["from_date"],
            suite["to_date"],
            suite["symbol"],
            suite["long_magic"],
            suite["short_magic"],
            f"v2_ref_parity_{suite['id']}_ref",
        )
        results[suite["id"]] = (orig, ref)

        print("\n  Count parity:")
        for line in compare_side("LONG", orig.side_long, ref.side_long):
            print(line)
        for line in compare_side("SHORT", orig.side_short, ref.side_short):
            print(line)

        print("\n  P&L parity:")
        print(compare_pnl("LONG", orig.long_pnl, ref.long_pnl))
        print(compare_pnl("SHORT", orig.short_pnl, ref.short_pnl))
        print(compare_pnl("COMBINED", orig.combined_pnl, ref.combined_pnl))

        cap_ok = True
        if suite.get("check_cap_blocks"):
            print("\n  GBP cap block parity (journal events):")
            cap_lines, cap_ok = compare_cap_blocks(orig, ref)
            for line in cap_lines:
                print(line)

        counts_ok = all(
            getattr(orig.side_long, k) == getattr(ref.side_long, k)
            for k in ("l0", "add", "reload", "exits", "max_layers")
        ) and all(
            getattr(orig.side_short, k) == getattr(ref.side_short, k)
            for k in ("l0", "add", "reload", "exits", "max_layers")
        )
        pnl_ok = (
            orig.long_pnl == ref.long_pnl
            and orig.short_pnl == ref.short_pnl
            and orig.combined_pnl == ref.combined_pnl
        )
        suite_ok = counts_ok and pnl_ok and cap_ok
        overall_ok &= suite_ok
        print(f"\n  Verdict: {'EXACT MATCH' if suite_ok else 'DIVERGENCE'}")

    print("\n" + "=" * 72)
    print(f"OVERALL: {'EXACT MATCH — ref parity confirmed' if overall_ok else 'DIVERGENCE DETECTED'}")
    print("=" * 72)
    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())
