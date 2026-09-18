This message has a line count at the bottom

The ~$292 gap is real and does not require a missing deposit or open MTM.
The account opened on 2026-09-10 with a single $10,000 balance deal; cumulative
deal net is $10,091.94, so trading P&L is +$91.94. Pipshed's cycle scalp headline
(+383.94 net on 602 scalps) omits the dominant offset: 81 manual OUT closes
(magic 0, empty comment) totalling -$284.86. Balance reconciles exactly as
scalp CloseBy net (+419.10) plus ENT/EXT open commissions (-42.30) plus manual
OUT (-284.86) equals +91.94. The arithmetic gap 383.94 - 91.94 = 292.00 splits
into -284.86 manual closes plus ~7.14 difference between pipshed scalp accounting
and deal-dump scalp-all-in (602 vs 612 events, gross/commission definition).

## Step 0 -- Schema (before analysis)

Source: `data/deals_dump_20260918_2354.csv` (2,716 rows). Loaded with
`pd.read_csv` following `notebooks/signal_vs_dumb_ab.ipynb` (numeric coercion on
profit/swap/commission, parse `time` to datetime).

Columns and dtypes after load:

| column | dtype |
|--------|-------|
| deal_ticket | int64 |
| time | datetime64 (parsed from string) |
| symbol | string |
| magic | int64 |
| entry | string |
| type | string |
| volume | float64 |
| price | float64 |
| profit | float64 |
| swap | float64 |
| commission | float64 |
| position_id | int64 |
| order | int64 |
| reason | int64 |
| comment | string |

First three rows:

| deal_ticket | time | symbol | magic | entry | type | volume | price | profit | swap | commission | comment |
|-------------|------|--------|-------|-------|------|--------|-------|--------|------|------------|---------|
| 516529281 | 2026-09-10 05:46:45 | (empty) | 0 | IN | unknown | 0.00 | 0.00000 | 10000.00 | 0.00 | 0.00 | Initial account balance |
| 516687057 | 2026-09-10 10:50:32 | EURGBP | 22260302 | IN | sell | 0.01 | 0.85884 | 0.00 | 0.00 | -0.03 | GRIND\|ALT\|S\|L00\|ENT |
| 516696714 | 2026-09-10 11:04:18 | EURGBP | 22260301 | IN | sell | 0.01 | 0.85886 | 0.00 | 0.00 | -0.03 | GRIND\|OPT\|S\|L00\|ENT |

Realised P&L columns: `profit`, `swap`, `commission`. Combined realised on each
row: `net = profit + swap + commission`.

Comment carries grind role: `GRIND|SLOT|SIDE|Lnn|ENT` (entry) or `|EXT` (exit
limit fill). CloseBy pairs use `#<pos_a> by #<pos_b>`.

Deal type / entry (this dump has no separate MQL5 enum name; use `entry`):

| entry | meaning in this dump | count |
|-------|----------------------|-------|
| IN | open / fill-in (ENT, EXT, balance) | 1411 |
| OUT_BY | close by netting (grind scalps realise here) | 1224 |
| OUT | direct market close | 81 |

`type` is buy/sell/unknown (1 unknown on the balance row). A close is
`entry` in {OUT, OUT_BY}. An open is `entry == IN`. Scalp exit-limit fills
appear as IN with `|EXT`; the layer P&L is realised on the paired OUT_BY
legs (both tickets share the same `order` id).

## Step 1 -- Premise check (opening balance)

Balance-type deals (`type == unknown`, comment contains "balance"):

| time | profit | comment |
|------|--------|---------|
| 2026-09-10 05:46:45 | +10000.00 | Initial account balance |

No other deposits, credits, withdrawals, or balance adjustments in the dump.
The first deal is the $10,000 FTMO deposit. Running balance from summing all
`net` from row 1 forward ends at **10,091.94**. Premise stands: opening balance
on cycle start date was $10,000. Proceed to steps 2 and 3.

## Step 2 -- Total realised reconciliation

| component | USD |
|-----------|-----|
| profit (all rows) | +10,157.17 |
| swap | -20.50 |
| commission | -44.73 |
| **combined (includes deposit)** | **+10,091.94** |
| less initial balance deal | -10,000.00 |
| **trading P&L** | **+91.94** |

Reported balance 10,091.94 minus deposit 10,000.00 equals +91.94. Combined
deal net matches balance exactly. **No discrepancy.**

## Step 3 -- Scalps vs everything else

### Method

- **Scalp closes:** OUT_BY events where either leg's `position_id` matches an
  `|EXT` IN deal (CloseBy scalp path). Aggregate both legs per `order` ticket.
- **Other closes:** all OUT deals (direct market close).
- Opening commissions on ENT/EXT IN deals are not closes but are realised P&L
  required to tie balance; reported separately.

### Group 1 -- EXT / scalp CloseBy closes

| metric | deal dump | pipshed cycle |
|--------|-----------|---------------|
| scalp count | 612 CloseBy events (617 `\|EXT` IN fills) | 602 scalps |
| gross (profit on CloseBy) | +432.05 | +414.04 |
| commission on CloseBy | 0.00 | (in -30.10 total) |
| swap on CloseBy | -12.95 | (not stated) |
| CloseBy net | +419.10 | -- |
| ENT+EXT open commission | -42.30 | -30.10 (pipshed comm line) |
| scalp-all-in (CB net + open comm) | **+376.80** | **+383.94 net** |

Count difference: +10 CloseBy events in dump vs pipshed (612 vs 602). First
602 CloseBy events sum to +425.40 profit / +412.92 net -- closer to pipshed
gross but still not exact; pipshed likely uses telemetry counters, not raw
deal profit. Value difference on scalp-all-in: +7.14 (pipshed higher).

Grind scalps do **not** realise on the `\|EXT` IN row (profit 0, commission
-0.03 only). P&L is on the OUT_BY pair closing the ENT layer against the EXT
position.

### Group 2 -- Everything else (non-scalp realised)

**Closing deals (non-scalp):**

| category | count | net USD |
|----------|-------|---------|
| manual OUT (magic 0, empty comment) | 81 | -284.86 |
| non-scalp OUT_BY | 0 | 0.00 |

**Other realised (not closes, required for balance tie):**

| category | count | net USD |
|----------|-------|---------|
| ENT open commission (IN) | 793 | -23.79 |
| EXT open commission (IN) | 617 | -18.51 |

**Manual OUT breakdown (largest contributor):**

| subcategory | count | net USD |
|-------------|-------|---------|
| GBPUSD OUT 2026-09-17 06:23-06:29 | 10 | -125.12 |
| GBPUSD OUT 2026-09-17 17:32-19:26 | 5 | -51.23 |
| EURUSD OUT (all dates) | 17 | -94.98 |
| other symbols OUT | 34 | -6.48 |
| OUT by date 2026-09-17 (all) | 33 | -281.89 |

All 81 OUT deals: `magic == 0`, blank `comment` -- platform/manual market
closes, not grind scalps. No CloseBy netting among these.

**Operator manual rolls (2026-09-17, GBPUSD, ~14:29-16:27 UTC):** dump
timestamps appear to be broker/server time (not UTC). No OUT rows fall in
14:29-16:27 as written. Closest match: **five** GBPUSD OUT at 17:32-19:25
(-51.23 net), not six / -59.50. A separate batch of **ten** GBPUSD OUT at
06:23-06:29 (-125.12) dominates Sep-17 losses.

**Largest five individual non-scalp closing losses:**

| time | symbol | net USD | comment |
|------|--------|---------|---------|
| 2026-09-17 06:28:40 | GBPUSD | -14.88 | (empty) |
| 2026-09-17 06:23:42 | GBPUSD | -14.25 | (empty) |
| 2026-09-17 06:28:44 | GBPUSD | -13.90 | (empty) |
| 2026-09-17 06:23:49 | GBPUSD | -13.20 | (empty) |
| 2026-09-17 06:28:48 | GBPUSD | -12.85 | (empty) |

### Balance tie (explicit)

| line | USD |
|------|-----|
| scalp CloseBy net | +419.10 |
| ENT+EXT open commission | -42.30 |
| manual OUT closes | -284.86 |
| **trading P&L** | **+91.94** |
| plus deposit | +10,000.00 |
| **balance** | **10,091.94** |

### Where the ~$292 went

| item | USD |
|------|-----|
| pipshed scalp net (headline) | +383.94 |
| actual balance gain | +91.94 |
| **apparent gap** | **292.00** |
| manual OUT closes | -284.86 |
| pipshed vs dump scalp-all-in delta | +7.14 |
| **sum** | **-292.00** (explains gap) |

Open MTM (-172.95) and financing (-14.83) affect equity only; they are already
netted in the equity line and do not move balance.

Analysis script (local, not committed): `scripts/cycle_pnl_recon.py`.
CSV not committed per dump script instruction.

Line count: 197
