#!/usr/bin/env python3
"""Backfill missing grind scalp_closed events from an MT5 deal-history CSV dump.

Reads broker deal history, pairs CloseBy round-trips (one record per ENT
position), skips manual/FTMO closes, deduplicates against
/api/telemetry/today_scalps, and POSTs to /api/telemetry/scalp_closed.

Default mode is DRY RUN (print only). Pass --post to send after review.

Environment:
  PIPSHED_API_TOKEN  Bearer token for pipshed telemetry API (required for
                     dedup and posting).

Example:
  python scripts/backfill_scalp_closed.py \\
      --csv data/local/deals_dump_20260910_2246.csv
  PIPSHED_API_TOKEN=... python scripts/backfill_scalp_closed.py --csv ... --post
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

DEFAULT_CSV = Path("data/local/deals_dump_20260910_2246.csv")
SCALP_CLOSED_URL = "https://pipshed.com/api/telemetry/scalp_closed"
TODAY_SCALPS_URL = "https://pipshed.com/api/telemetry/today_scalps"
USER_AGENT = "fxmatrix-backfill/1.0"

GRIND_MAGIC_PREFIX = "2226"

MAGIC_TO_INSTANCE: dict[str, str] = {
    "22260101": "GRIND_GBPUSD_OPT",
    "22260102": "GRIND_GBPUSD_ALT",
    "22260201": "GRIND_EURUSD_OPT",
    "22260202": "GRIND_EURUSD_ALT",
    "22260301": "GRIND_EURGBP_OPT",
    "22260302": "GRIND_EURGBP_ALT",
    "22260401": "GRIND_AUDCAD_OPT",
    "22260402": "GRIND_AUDCAD_ALT",
    "22260501": "GRIND_AUDCHF_OPT",
    "22260502": "GRIND_AUDCHF_ALT",
    "22260601": "GRIND_CADCHF_OPT",
    "22260602": "GRIND_CADCHF_ALT",
}

ENT_COMMENT_RE = re.compile(r"^GRIND\|[^|]+\|(L|S)\|L(\d+)\|ENT$")
CLOSEBY_COMMENT_RE = re.compile(r"^#(\d+) by #(\d+)$")
MT5_TIME_FORMAT = "%Y.%m.%d %H:%M:%S"


@dataclass(frozen=True)
class ScalpRecord:
    ent_position_id: str
    close_time: str
    instance_id: str
    instrument: str
    direction: str
    entry_price: float
    exit_price: float
    layer_depth: int
    gross_pnl: float

    def payload(self) -> dict[str, Any]:
        return {
            "close_time": self.close_time,
            "instrument": self.instrument,
            "direction": self.direction,
            "entry_price": float(f"{self.entry_price:.5f}"),
            "exit_price": float(f"{self.exit_price:.5f}"),
            "layer_depth": self.layer_depth,
            "stack_depth": None,
            "gross_pnl": float(f"{self.gross_pnl:.2f}"),
            "instance_id": self.instance_id,
        }

    def payload_json(self) -> str:
        return json.dumps(self.payload(), separators=(",", ":"))


def parse_mt5_time(raw: str) -> str:
    dt = datetime.strptime(raw.strip(), MT5_TIME_FORMAT)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_ent_comment(comment: str) -> tuple[str, int] | None:
    match = ENT_COMMENT_RE.match(comment.strip())
    if not match:
        return None
    side, layer_text = match.group(1), match.group(2)
    direction = "LONG" if side == "L" else "SHORT"
    return direction, int(layer_text)


def is_grind_magic(magic: str) -> bool:
    return magic.startswith(GRIND_MAGIC_PREFIX) and magic in MAGIC_TO_INSTANCE


def load_deals(csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def summarize_dump(deals: list[dict[str, str]]) -> tuple[str, str]:
    times = [row["time"] for row in deals if row.get("time")]
    if not times:
        raise ValueError("CSV contains no deal timestamps")
    return times[0], times[-1]


def count_skipped_closes(deals: list[dict[str, str]]) -> dict[str, int]:
    counts = {
        "manual_or_ftmo_out": 0,
        "out_by_magic_zero": 0,
        "out_by_no_grind_ent": 0,
        "out_by_bad_group_size": 0,
    }

    ent_positions: set[str] = set()
    for row in deals:
        if not is_grind_magic(row["magic"]):
            continue
        if row["entry"] != "IN":
            continue
        if parse_ent_comment(row.get("comment", "")) is None:
            continue
        ent_positions.add(row["position_id"])

    for row in deals:
        if row["entry"] == "OUT" and row.get("magic", "0") in ("0", ""):
            counts["manual_or_ftmo_out"] += 1

    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in deals:
        if row["entry"] != "OUT_BY":
            continue
        groups[row["order"]].append(row)

    for order, group in groups.items():
        if any(deal.get("magic", "0") in ("0", "") for deal in group):
            counts["out_by_magic_zero"] += 1
            continue
        if len(group) != 2:
            counts["out_by_bad_group_size"] += 1
            continue
        if not any(deal["position_id"] in ent_positions for deal in group):
            counts["out_by_no_grind_ent"] += 1

    return counts


def pair_scalps(deals: list[dict[str, str]]) -> list[ScalpRecord]:
    """Pair CloseBy round-trips into one scalp per ENT position.

    Rule (matches fxgrind grind_engine.mqh):
      - Group OUT_BY deals by shared order ticket (one CloseBy => two rows).
      - Identify the ENT leg: the OUT_BY row whose position_id matches an
        IN|ENT open recorded under a grind magic in this dump.
      - Emit exactly one scalp per ENT position_id (dedup guard).
      - gross_pnl sums profit+swap+commission across BOTH OUT_BY rows.
    """
    ent_opens: dict[str, dict[str, str]] = {}
    for row in deals:
        if not is_grind_magic(row["magic"]):
            continue
        if row["entry"] != "IN":
            continue
        parsed = parse_ent_comment(row.get("comment", ""))
        if parsed is None:
            continue
        ent_opens[row["position_id"]] = row

    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in deals:
        if row["entry"] != "OUT_BY":
            continue
        if row.get("magic", "0") in ("0", ""):
            continue
        groups[row["order"]].append(row)

    scalps: list[ScalpRecord] = []
    seen_ent_positions: set[str] = set()

    for order, group in sorted(groups.items(), key=lambda item: item[1][0]["time"]):
        if len(group) != 2:
            raise ValueError(
                f"CloseBy order {order} has {len(group)} OUT_BY deals; expected 2"
            )

        ent_row = None
        ent_out = None
        for deal in group:
            if deal["position_id"] in ent_opens:
                ent_row = ent_opens[deal["position_id"]]
                ent_out = deal

        if ent_row is None or ent_out is None:
            continue

        ent_position_id = ent_row["position_id"]
        if ent_position_id in seen_ent_positions:
            raise ValueError(
                f"Duplicate scalp for ENT position {ent_position_id} (order {order})"
            )
        seen_ent_positions.add(ent_position_id)

        parsed = parse_ent_comment(ent_row["comment"])
        if parsed is None:
            continue
        direction, layer_depth = parsed

        gross_pnl = sum(
            float(deal["profit"]) + float(deal["swap"]) + float(deal["commission"])
            for deal in group
        )

        scalps.append(
            ScalpRecord(
                ent_position_id=ent_position_id,
                close_time=parse_mt5_time(ent_out["time"]),
                instance_id=MAGIC_TO_INSTANCE[ent_row["magic"]],
                instrument=ent_row["symbol"],
                direction=direction,
                entry_price=float(ent_row["price"]),
                exit_price=float(ent_out["price"]),
                layer_depth=layer_depth,
                gross_pnl=gross_pnl,
            )
        )

    scalps.sort(key=lambda scalp: scalp.close_time)
    return scalps


def api_auth_headers(token: str, *, content_type: str | None = None) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": USER_AGENT,
    }
    if content_type is not None:
        headers["Content-Type"] = content_type
    return headers


def api_get_json(url: str, token: str) -> Any:
    request = urllib.request.Request(
        url,
        headers=api_auth_headers(token),
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"GET {url} -> HTTP {exc.code}", file=sys.stderr)
        if body:
            print(body, file=sys.stderr)
        raise


def api_post_json(url: str, token: str, payload: dict[str, Any]) -> tuple[int, str]:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers=api_auth_headers(token, content_type="application/json"),
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def existing_scalp_keys(records: list[dict[str, Any]]) -> set[tuple[str, str]]:
    keys: set[tuple[str, str]] = set()
    for row in records:
        instance_id = row.get("instance_id", "")
        close_time = row.get("close_time", "")
        if instance_id and close_time:
            keys.add((instance_id, close_time))
    return keys


def scalp_already_present(
    candidate: ScalpRecord,
    existing_keys: set[tuple[str, str]],
) -> bool:
    return (candidate.instance_id, candidate.close_time) in existing_keys


def fetch_existing_scalps(token: str) -> list[dict[str, Any]]:
    payload = api_get_json(TODAY_SCALPS_URL, token)
    if not isinstance(payload, dict):
        raise ValueError(f"Unexpected today_scalps response shape: {type(payload)}")
    records = payload.get("records")
    if not isinstance(records, list):
        raise ValueError("today_scalps response missing records list")
    return records


def print_report(
    *,
    csv_path: Path,
    first_ts: str,
    last_ts: str,
    skipped: dict[str, int],
    all_scalps: list[ScalpRecord],
    existing: list[dict[str, Any]] | None,
    to_post: list[ScalpRecord],
    dry_run: bool,
) -> None:
    print(f"CSV: {csv_path}")
    print(f"Dump window: {first_ts} .. {last_ts} (server time)")
    print(
        "Skipped closes:",
        f"manual/FTMO OUT={skipped['manual_or_ftmo_out']},",
        f"OUT_BY magic 0 groups={skipped['out_by_magic_zero']},",
        f"OUT_BY without ENT={skipped['out_by_no_grind_ent']},",
        f"OUT_BY bad group size={skipped['out_by_bad_group_size']}",
    )
    print(f"Grind scalps paired (unique ENT positions): {len(all_scalps)}")
    dedup_count = len(all_scalps) - len(to_post)
    if existing is not None:
        print(f"Already in today_scalps panel: {len(existing)} records fetched")
        print(f"Dedup skipped (instance_id + close_time match): {dedup_count}")
    else:
        print("Already in today_scalps panel: unknown (no API token)")
        print("Dedup skipped: unknown (no API token)")
    print(f"Would post: {len(to_post)}")
    print(f"Summed gross_pnl of new scalps: {sum(s.gross_pnl for s in to_post):.2f}")
    print(f"Summed gross_pnl of all paired scalps: {sum(s.gross_pnl for s in all_scalps):.2f}")
    print()
    print("Pairing rule: group OUT_BY by order ticket; one scalp per ENT position_id; "
          "gross_pnl summed across both OUT_BY legs.")
    print()
    if dry_run:
        print("DRY RUN — payloads below are NOT posted.")
    else:
        print("LIVE POST — sending payloads.")
    print()

    for index, scalp in enumerate(to_post, start=1):
        print(
            f"[{index}/{len(to_post)}] {scalp.close_time} {scalp.instance_id} "
            f"{scalp.direction} L{scalp.layer_depth} "
            f"entry={scalp.entry_price:.5f} exit={scalp.exit_price:.5f} "
            f"pnl={scalp.gross_pnl:.2f}"
        )
        print(scalp.payload_json())


def sanity_check_counts(
    all_scalps: list[ScalpRecord],
    existing_count: int | None,
    to_post_count: int,
) -> None:
    total = len(all_scalps)
    if total < 10 or total > 60:
        raise SystemExit(
            f"STOP: implausible grind scalp count {total}; expected roughly 13 + day's activity."
        )

    if existing_count is not None:
        if existing_count > total:
            raise SystemExit(
                f"STOP: panel has {existing_count} scalps but dump only yielded {total}."
            )
        expected_new = total - existing_count
        if abs(to_post_count - expected_new) > 3:
            raise SystemExit(
                "STOP: dedup would post "
                f"{to_post_count} scalps but expected about {expected_new} "
                f"({total} paired minus {existing_count} already in panel)."
            )

    gross_all = sum(scalp.gross_pnl for scalp in all_scalps)
    if gross_all <= 0.0 or gross_all > 50.0:
        raise SystemExit(
            f"STOP: implausible total gross_pnl {gross_all:.2f}; expected > 0 and well below ~50."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Deal dump CSV path (default: {DEFAULT_CSV})",
    )
    parser.add_argument(
        "--post",
        action="store_true",
        help="POST payloads after checks (default: dry run only)",
    )
    parser.add_argument(
        "--api-token",
        default=os.environ.get("PIPSHED_API_TOKEN", ""),
        help="Bearer token (default: PIPSHED_API_TOKEN env var)",
    )
    args = parser.parse_args()

    csv_path = args.csv
    if not csv_path.exists():
        print(f"CSV not found: {csv_path}", file=sys.stderr)
        return 1

    deals = load_deals(csv_path)
    first_ts, last_ts = summarize_dump(deals)
    skipped = count_skipped_closes(deals)
    all_scalps = pair_scalps(deals)

    existing: list[dict[str, Any]] | None = None
    token = args.api_token.strip()
    if token:
        existing = fetch_existing_scalps(token)
    elif args.post:
        print("PIPSHED_API_TOKEN is required for --post", file=sys.stderr)
        return 1

    existing_keys: set[tuple[str, str]] | None = None
    to_post = all_scalps
    if existing is not None:
        existing_keys = existing_scalp_keys(existing)
        to_post = [
            scalp
            for scalp in all_scalps
            if not scalp_already_present(scalp, existing_keys)
        ]

    existing_count = len(existing) if existing is not None else None
    try:
        sanity_check_counts(all_scalps, existing_count, len(to_post))
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        print_report(
            csv_path=csv_path,
            first_ts=first_ts,
            last_ts=last_ts,
            skipped=skipped,
            all_scalps=all_scalps,
            existing=existing,
            to_post=to_post,
            dry_run=not args.post,
        )
        return 2

    print_report(
        csv_path=csv_path,
        first_ts=first_ts,
        last_ts=last_ts,
        skipped=skipped,
        all_scalps=all_scalps,
        existing=existing,
        to_post=to_post,
        dry_run=not args.post,
    )

    if not args.post:
        if not token:
            print()
            print("Set PIPSHED_API_TOKEN to deduplicate against today_scalps before posting.")
        return 0

    rejected_null_stack = False
    for scalp in to_post:
        status, body = api_post_json(SCALP_CLOSED_URL, token, scalp.payload())
        print(f"POST {scalp.instance_id} {scalp.close_time} -> HTTP {status}")
        if status >= 400:
            print(body)
            if "stack_depth" in body and "null" in body.lower():
                rejected_null_stack = True
            return 3

    if rejected_null_stack:
        print("API rejected null stack_depth — reported, no substitution attempted.")
        return 3

    print(f"Posted {len(to_post)} scalp_closed events.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
