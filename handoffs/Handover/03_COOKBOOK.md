# COOKBOOK -- WHERE TO LOOK

## THE TWO RULES

**You cannot construct URLs.** The fetch tool only accepts URLs that have
appeared in the conversation. Ask the operator to paste each one.

**The trailing segment is a cache-buster and MUST CHANGE every fetch.** The tool
caches by PATH and strips query strings, so `?v=2` does nothing. Use
`/status/a1`, then `a2`, then `a3`. The server ignores it entirely.

**Always check `generated_at` before trusting a read.** A stale cached response
caused two wrong conclusions.

---

## LIVE STATE -- Redis, seconds old

    https://pipshed.com/api/g/k7m9p2x4q/status/a1

The main one. Every instance: layers with entry and exit targets, resting
levels, the full broker book with tickets, prices, millisecond timestamps and
raw comments, `halted` / `halt_reason` / `invariant_ok` / `recon_ok`,
`api_count`, cap exposure, and ring roll-ups. When reconstruction rejects a
book it carries everything it saw before halting.

**This reproduces the MT5 Trade tab exactly.** Screenshots are a double-check,
not a primary source -- at the fleet's cap the book is 190+ orders and
screenshots stop working.

    https://pipshed.com/api/g/k7m9p2x4q/scalps/a1
    https://pipshed.com/api/g/k7m9p2x4q/scalps/a2?date=2026-09-10

Completed scalps: close time, direction, entry, exit, layer depth, P&L,
instance. `?date=` works; the segment is still what defeats the cache.

    https://pipshed.com/api/g/k7m9p2x4q/summary

Plain-text daily summary, copyable. Account, open risk, MTM, financing accrued,
per-symbol lines, cycle totals. Has a date picker.

    https://pipshed.com/api/g/k7m9p2x4q/carry/d1

The carry table: per-position swap, `mult_tomorrow`, pips.

    https://pipshed.com/api/g/k7m9p2x4q/carry_audit

Reconciles derived financing against the broker ledger.

    https://pipshed.com/

The dashboard: account header, ring sections, scalps, broker book tables.

---

## THE ARCHIVE -- Postgres, minutes old. THE PRIMARY DIAGNOSTIC ROUTE

The endpoints show STATE. The archive shows what HAPPENED. Every root cause
found on 2026-09-14 came from here.

Run from `D:\pipshed`:

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" `
      python scripts/archive_counts.py <flag>

| Flag | What it gives |
|---|---|
| `--table send_logs --limit 20` | every order request: action, requested price, ok, retcode, `duration_ms`. **`duration_ms=0` means the TERMINAL refused it locally** (e.g. 10027 CLIENT_DISABLES_AT, algo off) and it never reached the broker |
| `--table fill_logs --limit 40` | every deal: `order_price_open` vs `deal_price`, `slippage_pips`, `halted_at_receipt`, `entry_type` (IN / OUT_BY), `deal_time_broker` |
| `--table ea_events --limit 10` | markers: `INVARIANT_FAIL` (with the ADR-141 detail payload), `QUARANTINE_ENTER` / `RELEASE`, `RECON_DERIVED_CLOSEBY`, `CARRY_SNAPSHOT` |
| `--table config_events` | INIT / DEINIT with the full input dump -- catches a wrong-chart attach and confirms whether a compile took effect |
| `--table scalp_history` | the performance record, kept indefinitely |
| `--slippage` | distribution by instance and direction, plus every fill breaching the 0.2-pip I6 tolerance |
| `--carry` | swap mode and rates per symbol |
| `--rollovers` | broker-midnight crossings counted from `fill_logs`, with `swap_usd` ground truth alongside |

**Retention:** `send_logs`, `fill_logs` and `log_lines` 14 days;
`scalp_history` and `config_events` kept.

**Isolation is absolute.** Redis is operational truth; Postgres is an
asynchronous shadow. `/api/telemetry/push` must NEVER fail because the archive
is down. Receive, write Redis, return 200, RPUSH to a queue, and a separate
worker drains it.

---

## REPOS -- READ THE SOURCE, DO NOT REASON FROM DESCRIPTION

    https://github.com/theonlykk/fxmatrix
    https://github.com/theonlykk/pipshed
    https://github.com/theonlykk/candlelab

**fxmatrix** -- the EA (`ea/`), the simulator and sweep harness (`scripts/`),
ADRs and ARCHITECT (`docs/architecture/`), session handoffs (`handoffs/`),
DeepSeek templates (`docs/deepseek_prompts_templates/`).

**pipshed** -- dashboard, telemetry ingestion, the archive worker
(`scripts/archive_counts.py`, `scripts/archive_worker.py`).

**candlelab** -- **READ ONLY. Mothballed.** It is the Postgres template and has
a bounce feature worth borrowing. Do not write to it, do not deploy to it, do
not resurrect it by accident.

Several errors came from assuming what code did instead of opening it. Clone
and read.

---

## ANALYSIS TOOLING

`notebooks/signal_vs_dumb_ab.ipynb` -- A/B on REAL broker P&L (terminal
`DEAL_PROFIT` + swap + commission). Unaffected by every simulator defect found
so far, which makes it the trustworthy performance record.

`scripts/dump_deals_range.mq5` -- run in MetaEditor on the terminal holding the
account; writes a deal-history CSV to `MQL5\Files\`. The operator copies it to
`data\local\`, which is gitignored. **Never commit a CSV; the repo is public.**

`scripts/backfill_scalp_closed.py` -- replays scalps from a deal dump. Dry run
by default. Handles three silent traps: CloseBy splits P&L across TWO `OUT_BY`
deals so both must be summed; MT5 CSV dates use PERIODS and `fromisoformat`
throws; and **Cloudflare blocks Python-urllib's default User-Agent with error
1010** -- any script hitting pipshed needs an explicit UA.

`scripts/sweep_per_pair.py` -- per-pair extraction from a sweep JSON. **Use this
rather than the pooled summary**: one gate-disqualified pair makes every pooled
average `-inf`, which silently destroys a whole run's headline numbers.

`scripts/archive_counts.py` -- see the table above. Add a flag when you need a
new view; the pattern is established.
