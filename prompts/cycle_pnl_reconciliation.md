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

## COUNTERFACTUAL: 17-Sep GBPUSD force closes

On the evidence available (no Sep-17/18 GBPUSD rate file; EXT-fill lower bound
for highs), none of the 15 force-closed longs would have reached their formula
exit targets by 2026-09-18 23:50. Holding them to the last dump price
(1.33955) would have left -125.21 unrealised MTM versus -176.35 realised on
the closes -- a +51.14 equity difference (counterfactual minus actual), meaning
the closes destroyed about **$51 of equity** relative to simply holding. That
is not a large win for the closes: every position would still be underwater,
and the closes locked in roughly $51 more loss than mark-to-market at the end
of the window. True market highs may exceed our EXT lower bound, but the
nearest target (L08 at 1.34401) sits ~45 pips above the highest observed
|EXT| fill (1.33914), so flipping any position to a scalp exit is unlikely
under conservative assumptions. The answer is close: closes clearly hurt vs
hold-to-end, but neither path was profitable.

Note: a 16th GBPUSD manual OUT on 2026-09-17 at 17:23:36 (-9.12) sits outside
the two operator clusters and is excluded from the 15 below.

### Step 1 -- Closed positions and geometry

All 15 OUT deals match an ENT IN on `position_id`. All are long (`|L|` in
comment). Arm from magic: `22260101` = OPT (exit_pips 7, target entry+0.00070),
`22260102` = ALT (exit_pips 10, target entry+0.00100).

| position_id | close time | close px | actual net | ENT time | entry | arm | target | comment |
|-------------|------------|----------|------------|----------|-------|-----|--------|---------|
| 541060808 | 2026-09-17 06:23:42 | 1.33715 | -14.25 | 2026-09-14 06:00:52 | 1.35112 | ALT | 1.35212 | GRIND\|ALT\|L\|L00\|ENT |
| 541999470 | 2026-09-17 06:23:49 | 1.33716 | -13.20 | 2026-09-14 22:50:35 | 1.35008 | ALT | 1.35108 | GRIND\|ALT\|L\|L01\|ENT |
| 542056165 | 2026-09-17 06:23:53 | 1.33715 | -12.17 | 2026-09-15 04:24:22 | 1.34908 | ALT | 1.35008 | GRIND\|ALT\|L\|L02\|ENT |
| 543250220 | 2026-09-17 06:24:03 | 1.33718 | -11.10 | 2026-09-16 09:06:39 | 1.34809 | ALT | 1.34909 | GRIND\|ALT\|L\|L03\|ENT |
| 543261883 | 2026-09-17 06:24:10 | 1.33717 | -10.07 | 2026-09-16 11:01:02 | 1.34705 | ALT | 1.34805 | GRIND\|ALT\|L\|L04\|ENT |
| 540374044 | 2026-09-17 06:28:40 | 1.33709 | -14.88 | 2026-09-14 03:31:00 | 1.35169 | OPT | 1.35239 | GRIND\|OPT\|L\|L00\|ENT |
| 541050954 | 2026-09-17 06:28:44 | 1.33708 | -13.90 | 2026-09-14 06:18:17 | 1.35070 | OPT | 1.35140 | GRIND\|OPT\|L\|L01\|ENT |
| 542106297 | 2026-09-17 06:28:48 | 1.33708 | -12.85 | 2026-09-15 03:28:59 | 1.34969 | OPT | 1.35039 | GRIND\|OPT\|L\|L02\|ENT |
| 543251889 | 2026-09-17 06:28:53 | 1.33708 | -11.83 | 2026-09-16 09:01:37 | 1.34872 | OPT | 1.34942 | GRIND\|OPT\|L\|L03\|ENT |
| 543312365 | 2026-09-17 06:28:57 | 1.33704 | -10.87 | 2026-09-16 10:43:05 | 1.34772 | OPT | 1.34842 | GRIND\|OPT\|L\|L04\|ENT |
| 543354875 | 2026-09-17 17:32:43 | 1.33634 | -10.56 | 2026-09-16 13:00:07 | 1.34671 | OPT | 1.34741 | GRIND\|OPT\|L\|L05\|ENT |
| 543701009 | 2026-09-17 17:57:56 | 1.33520 | -10.04 | 2026-09-16 18:04:58 | 1.34505 | ALT | 1.34605 | GRIND\|ALT\|L\|L06\|ENT |
| 543415118 | 2026-09-17 18:50:03 | 1.33410 | -11.80 | 2026-09-16 14:51:33 | 1.34571 | OPT | 1.34641 | GRIND\|OPT\|L\|L06\|ENT |
| 543880431 | 2026-09-17 18:51:32 | 1.33407 | -10.16 | 2026-09-16 21:00:50 | 1.34404 | ALT | 1.34504 | GRIND\|ALT\|L\|L07\|ENT |
| 543881186 | 2026-09-17 19:25:02 | 1.33453 | -8.67 | 2026-09-16 21:01:11 | 1.34301 | ALT | 1.34401 | GRIND\|ALT\|L\|L08\|ENT |

### Step 2 -- Highest GBPUSD price since each close

**Method used: fallback (EXT-fill lower bound).** No GBPUSD tick/M1 series
covering 2026-09-17 06:23 through 2026-09-18 21:00 was available in the
repository (`data/live_15d_export_20260808/gbpusd_m1.csv` ends 2026-08-07).

For each close, the running high of subsequent GBPUSD `|EXT` IN fill prices
after that close time:

| cluster | per-position high | timestamp | bias |
|---------|-------------------|-----------|------|
| morning (10 closes) | 1.34016 | 2026-09-17 09:55:15 | lower bound |
| afternoon (5 closes) | 1.33914 | 2026-09-18 20:10:46 | lower bound |

Overall post-06:23 high from EXT fills: **1.34016** at 2026-09-17 09:55:15.
Last GBPUSD deal price in dump: **1.33955** at 2026-09-18 22:46:17.

**Bias:** true highs may exceed EXT fills; using EXT therefore tends to
understate how often targets would have been reached, i.e. conservative toward
"the closes were justified." Here targets (1.347-1.352) lie far above even
generous EXT highs, so the bias does not change the classification.

### Step 3 -- Counterfactual

Classification rule: (a) subsequent EXT high >= exit target; else (b) still
open with MTM at last price 1.33955: `(last - entry) / 0.0001 * $0.10` per
0.01 lot. Scalp counterfactual (a) would be `exit_pips * $0.10 - $0.03`.

**Result: 0 would have exited (a); 15 still open (b).**

| | actual | counterfactual |
|---|---|---|
| realised on these 15 | -176.35 | 0.00 |
| unrealised still open | 0.00 | -125.21 |
| **equity effect** | **-176.35** | **-125.21** |

**Difference (counterfactual minus actual): +51.14 USD.** Positive => the
closes destroyed equity vs holding to the dump end. Positions were closed
deeper in loss than where GBPUSD stood at 2026-09-18 22:46.

Largest five would-be MTM losses if held (least bad first at -3.46):

| position | entry | target | EXT high | MTM at 1.33955 |
|----------|-------|--------|----------|----------------|
| 543881186 L08 ALT | 1.34301 | 1.34401 | 1.33914 | -3.46 |
| 543880431 L07 ALT | 1.34404 | 1.34504 | 1.33914 | -4.49 |
| 543701009 L06 ALT | 1.34505 | 1.34605 | 1.33914 | -5.50 |
| 543415118 L06 OPT | 1.34571 | 1.34641 | 1.33914 | -6.16 |
| 543354875 L05 OPT | 1.34671 | 1.34741 | 1.33914 | -7.16 |

### Step 4 -- What the closes bought (not netted)

GBPUSD scalp CloseBy net in the 4 hours after each cluster vs same clock on
2026-09-16 (crude control). **Cannot attribute** these to the force closes.

| window | after closes (17-Sep) | control (16-Sep) |
|--------|----------------------|------------------|
| 4h after morning cluster end (06:28:57 -> 10:28:57) | 7 scalps, +5.72 net | 5 scalps, +3.98 net |
| 4h after afternoon cluster end (19:25:02 -> 23:25:02) | 3 scalps, +2.43 net | 16 scalps, +14.09 net |

Afternoon-after is well below the prior-day control; morning-after is slightly
above. Guard-slot relief may have enabled some subsequent grind activity, but
this dump cannot separate causation from normal session variation.

Line count: 306
