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

    https://pipshed.com/api/g/k7m9p2x4q/fleets/f1

THE FLEET STRIP (pipshed `4faaf1b`, any host): one card per fleet (cycle
3, B, C, D placeholder): badge LIVE/PARTIAL/NO CONNECTION, alerts (red
= act, amber = look; codes in the page's legend), equity, balance, day
P&L against $500 (anchored on the latest daily row before today), open
risk, financing, today's ledger closes, cycle realised against $10,000.
Ask the fetch tool for exact quotes of the fields that matter.

    https://pipshed.com/api/g/k7m9p2x4q/critical/f2

The last 24 h of CRITICAL and allow-listed WARN events, grouped by
instance and code, with count, first and last time.

    https://pipshed.com/api/g/k7m9p2x4q/status/a1

(Fleet B: `.../status_b/a1`; Fleet C, box 2: `.../status_c/a1`, pipshed
`3184c88`. Each fleet's dashboard is its own Railway web service with
`GRIND_FLEET` set; all read the same Redis.)

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

    https://linux.pipshed.com/api/g/k7m9p2x4q/ejection/a1?hours=96

Passive ejection and closed P&L (C56): rolls, ejections, per-day closed
P&L by instance and side (scalps / rolls / ejections, commission, swap),
live depth and deepest price, warnings, reconciliation. Worker-built;
`view_age_s` says how old; 503 means the view is missing or stale, never
read it as zero. `pipshed.com` for cycle 3, `linux.` for Fleet B,
`linuxc.` for Fleet C (box 2).

**Ad-hoc SQL on production:** PowerShell mangles nested quotes in
`railway ssh ... python -c`. Open a shell in the worker
(`railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519"`),
then run `python -c '...'` at the container prompt with `%s` parameters
instead of inner quotes; `exit` after.

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
| `--codes A,B [--hours N]` | archived event counts per instance and code, first/last (pipshed `5e8b904`). Only `Grind_ArchiveMarker` codes are archived (EJECT_*, ROLL_*, QUARANTINE_*, WARN markers); `Grind_TelemetryEmit` codes such as `WARN_LAYER_CAP_REACHED` go to the Experts log only |
| `--depth [--cap 8] [--hours N]` | per instance and side: scalps, the deepest `stack_depth` at a scalp, scalps closed at or above the cap. How often sides reach cap, from fills |
| `--carrypass [--hours N]` | THE NIGHTLY CARRY CHECK (pipshed `c0a5f44`, default 30 h, honours `--instance`): every `CARRY_SNAPSHOT` (the 23:50-server ones land at 20:50Z = GMT+3; one is also written at every EA init), every `CARRY_PASS_SUMMARY`/`_INCOMPLETE` with its counts, and quarantine / invariant / critical markers grouped by reason, I6 first. `--carry` shows only the NEWEST snapshot per symbol, which after a reload is the init row, and it merges duplicate instances and both fleets |

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
