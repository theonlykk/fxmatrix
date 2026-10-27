This message has a line count at the bottom

# MAGNET GRID -- DO ROUND NUMBERS PULL PRICE BACK? -- PRE-REGISTRATION v1 (27 Oct 2026 ~04:00Z; before any run)

| | |
|---|---|
| Status | **DRAFT v1** (Claude, HANDOFF s92 continued 8). No code, no run. Argon: not asked (19% of its week; the operator's call). |
| Why | The operator (27 Oct ~03:48-03:52Z): "we think that there is some magnetism to round numbers ... sell add levels at 1.5635 - exit 1.5625 ... buy 1.5615 - exit 1.5625 ... we basically work orders as we approach them ... working until filled - or removing them if they are far away"; then "magnets only at xx50 or xx00 ... we have rolls as well". |
| Not Osler | Osler (`research/cluster/results.md`: NONE / NONE) asked whether a TOUCH of a round level holds 15 minutes later. This asks whether price that has gone 10 pips THROUGH a round level comes back to it before running away, over any horizon, and whether that pays after costs. Osler's null is a warning, not an answer. |
| What follows | **Nothing live.** A MAGNET EFFECT (s7) becomes a design question for a level-anchored arm (its own pre-registration, simulator then harness). No effect: the idea stops, and that is reported, with the grid's own profit or loss beside it. |

## 1. ONE WORKED EXAMPLE (prices)

Magnets at every xx00 and xx50: ... 1.5600, 1.5650, 1.5700 ... Each magnet L has a SELL at L + 10 pips (exit L) and
a BUY at L - 10 pips (exit L). Price starts at 1.5630, between 1.5600 and 1.5650. Working: the sell at 1.5610 (magnet
1.5600) cannot rest (it is below the bid), the buy at 1.5590 rests; the sell at 1.5660 rests; the buy at 1.5640
(magnet 1.5650) cannot rest (above the ask). Price rises to 1.5672: the 1.5660 sell fills; the 1.5640 buy now rests
(price is above it). Price falls back to 1.5648: the sell exits at 1.5650 (+10 pips; the ask had to reach 1.5650) and re-arms; the
1.5640 buy has not filled. Price falls to 1.5636: the 1.5640 buy fills; it exits when price returns to 1.5650.

## 2. THE STRATEGY, EXACT

- **Magnets:** L = every multiple of 0.0050 (xx00, xx50). **Entry offset** d = 10 pips; **exit** at L.
- **Per magnet, two slots:** SELL slot (a sell limit at L + d) and BUY slot (a buy limit at L - d). A slot holds at most
  one open position; after its exit it re-arms.
- **Working an order:** a slot's limit is RESTING from the first bar whose open is on its passive side (sell: bid open
  < L + d; buy: ask open > L - d) while the slot is empty; it rests until filled (the operator's "removing them if far"
  changes only how many requests are sent, not fills; requests are not modelled, s10).
- **Fills on M1 bars (bid OHLC + the bar's spread):** a resting SELL at P fills in a bar whose bid high >= P; a BUY at
  P fills in a bar whose ask low (bid low + spread x point) <= P. Fill price = P (no improvement on gaps). A short's exit (buy limit at L) fills when ask low <= L; a long's (sell limit at L) when bid
  high >= L; never in the bar of its entry (the order inside a bar is unknown; s10).
- **Cap and rolls (fxgrind's lattice, MECHANICS s3):** at most **cap = 8 open positions a side** (shorts, longs). A
  SELL slot that would fill while 8 shorts are open does not open a ninth: it ROLLS the open short with the lowest
  effective entry (the oldest, deepest under water) to it: that short's effective entry becomes P and its exit the new
  magnet L; it occupies the new slot and frees its old one; its loss is realised only when the new exit fills (at
  its REAL entry price). At most one roll per slot per bar. Longs mirror (the highest effective entry). No roll gate.
- **Units and money:** 0.01 lots a position; USD per pip at 0.01 lots fixed per pair (`research/replay/sweep.py`
  56-58: EURUSD 0.100, GBPUSD 0.100, EURGBP 0.134, AUDCAD 0.0714, AUDCHF 0.122, CADCHF 0.122; GBPCHF 0.122 assumed as
  the other CHF pairs); commission 0.06 USD per close (`sweep.py` 59). Spread is paid through the fills (s2). No swap.
- **Equity:** realised + open positions marked at each bar's close (longs at bid, shorts at ask).

## 3. DATA

The Osler files (`research/cluster/PREREG.md` s3: FTMO M1 bars, 2 Jan 2023 - 23 Oct 2026, seven pairs, hashes there;
re-checked by the code). **Halves:** H1 = 2023-01-02 .. 2024-12-31, H2 = 2025-01-01 .. 2026-10-23 (server dates); each
half run separately from flat; positions open at a half's end are marked, not closed.

## 4. THE COMPARISON (structure-matched: the lesson of Osler v3.1)

- **Real grid:** offset 0 (magnets at xx00 / xx50).
- **Placebo grids:** the same strategy with every price shifted by an offset o (magnets at o + n x 0.0050), **20 offsets
  per pair**, multiples of 0.00001 in [0.0005, 0.0045] (`random.Random(20261027 + pair_index)`, the PREREG v3.2 pair
  order), so no placebo magnet lies within 5 pips of a round one. The same offsets in both halves.
- **Per pair and half:** NET = realised + open at the half's end, USD, after commission. **The rank of the real grid's
  NET among the 21** (1 = best).
- **Pooled per half:** the sum of NET over the seven pairs for the real grid and for each placebo k (offset k of every
  pair), and the real grid's rank among the 21 pooled sums.

## 5. SELF-CHECKS FIRST (any failure: STOP, record, amend before any real number is read)

1. File hashes, bars, headers (as Osler s6.1).
2. The tests pass (s9).
3. **Exchangeability:** 20 day-permuted runs (Osler v3.2's `permute_within_days`, seeds `20261028 + run`): the real
   grid ranks first in the pooled NET of BOTH halves in at most 1 of 20 runs; and over the 20 runs x 2 halves its mean
   pooled rank lies in 7-15 (the uniform mean is 11).

## 6. ALSO REPORTED (not deciding)

Per grid: closes, rolls, realised, open at the end, the worst open drawdown (USD, peak to trough of equity), the
worst FTMO day of the seven pairs together (day = server 01:00 to 01:00, approximating Prague midnight; loss = the
day's start equity minus its lowest bar-close equity) against $500; the share of exits that were rolled. The same for
**variants**: quarters (magnets every 0.0025, placebo offsets in [0.0005, 0.0020]), d = 15 pips, and uncapped (no rolls).

## 7. THE DECISION

- **MAGNET EFFECT** if the real grid ranks **1st of 21 in pooled NET in BOTH halves** (p = 1/441 under exchangeability).
  1st in one half only: IN ONE HALF (reported, not built on). Otherwise: NONE.
- Per pair and the variants are reported, not deciding.

## 8. CLAUDE's PREDICTIONS (before any run)

1. MAGNET EFFECT: no. The real grid's pooled rank 5-17 in each half.
2. The real grid's pooled NET is negative in at least one half (trends leave capped, rolled stacks).
3. The worst FTMO day of the seven pairs together exceeds $500 at least once over the four years.
4. Self-check 3: 0 of 20 runs.

## 9. THE CODE

`research/magnet/magnet.py` with `test_magnet.py` first, against a stub, hand values: a sell fills at bid high = P and
not at P - 1 point; a buy fills when ask low <= P (spread added); no exit in the entry's bar; a slot re-arms after its
exit; the ninth short rolls the lowest-entry short (its exit moves to the new magnet, the realised loss at the real
entry on exit); a placebo offset shifts every price; NET marks open shorts at ask. Then the code; the operator runs it
on the desktop (`--stage selfcheck`, then `--stage real` only on PASS); outputs and a hash manifest committed; then
`results.md`.

## 10. LIMITS

M1 bars, not ticks (intrabar order unknown: no same-bar exit; fills at the limit price); one feed; requests not
modelled (the live EA's order count is a separate question); no swap (positions held for days pay or earn it); USD
per pip fixed; one entry offset and cap in the decision. A profit here is in-sample for H1 and out-of-sample only in
H2; it is not an edge until it survives the harness.

Line count: 103
