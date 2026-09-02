This message has a line count of 129 lines.

FULL-TRIAL RECORD -- Account 1514264399 (FTMO Free Trial, 12-25 Aug 2026)
FROM: Khalid (Lead Quant), captured by Claude (Lead Engineer)
TO:   The record + Gemini
RE:   Complete account-life retrospective from live full export (1053 deals, all
      trading days). SUPERSEDES WEEK1_ASSESSMENT_MEMO.md, which over-projected the
      grind rate from a single strong week. This is the corrected full-sample
      epitaph. No ruling requested.

====================================================================
0. FRAMING CORRECTION (read first) -- "displacement", not "growing debt"
====================================================================
The offside open inventory is NOT an accumulating loss and does NOT decay on its
own (carry/swap aside). It is a DISPLACEMENT measurement: the distance the current
trading range has moved from where the inventory was built. When a range relocates,
the held inventory is marked offside by that distance -- a number as likely to
SHRINK as grow, mean-neutral drift, no inherent deterioration. Taking the
displacement hit and grinding it back while waiting for the range to return IS the
strategy, not a failure mode. So throughout: the displacement "did not revert
within the trial" (neutral fact -- the range did not return), NOT "the debt grew."
The ONLY genuinely growing cost is carry/swap (-$1.86 over the trial), which
accrues slowly with holding time -- small, but the honest exception.

====================================================================
1. THE ACCOUNT
====================================================================
FTMO Free Trial, 2-Step, Swing, $10k. Start 12 Aug -> End 25 Aug 2026 (expired;
last deal 2026-08-25 05:14). Live full export: 1053 deals, 264 completed scalps,
14 open positions at expiry.

====================================================================
2. REGIME -- 10/10 CHURN; THE HARD REGIME NEVER CAME
====================================================================
Every trading day classified CHURN (two days had one pair tick MIXED -- EURUSD
0.216 on the 19th, 0.207 on the 25th -- but each day as a whole was churn).
TRIAL MIX: TREND=0, CHURN=10, MIXED=0.
=> The market NEVER handed this account a TREND day. This is why the floor was
never threatened -- the account never faced the regime that deepens the book. So
"it survived" carries an asterisk: it survived the designed-for regime, ten times,
and never met the hard one. Trend-day resilience remains UNTESTED. (One account is
not a base rate.)

====================================================================
3. MECHANISM 1 -- CONFIRMED, at a LOWER honest run-rate than the weekly implied
====================================================================
  NET grind $72.91 (264 scalps, 697.9 gross pips, gross $83.11, commission -$8.34
  = 10.0% of gross, swap -$1.86).
  By week: wk1 (12-15) $26.94 ; wk2 (18-22) $44.25 ; tail (25) $1.72.
  Sustainable pace: ~$30/week (the FULL-sample rate), NOT the ~$44 the single
  strong week suggested. The one good week was ABOVE trend, not the trend.
CORRECTION TO PRIOR PROJECTION: stake recovery at ~$30/week takes ~3-4 weeks, not
the 2-3 the weekly memo implied. Still achievable; the honest timeline is longer.
This is the value of the full-account view -- it de-biases the cherry-picked week.
By symbol: GBPUSD $36.04, EURUSD $29.23, EURGBP $7.64.

====================================================================
4. L0 vs ADD -- signal measurably WORSE than dumb geometry (roadmap validated)
====================================================================
  L0 (signal): n=143, avg realized $0.192/scalp, fast-close(<=10m) 42.0%.
  Add (mechanical): n=48, avg realized $0.276/scalp, fast-close 33.3%.
  The mechanical Add OUT-EARNS the signal entry per scalp by ~44%. On the full
  sample the signal is not merely non-additive -- it is measurably inferior per
  unit. Strongest version yet of "signal is theatre, geometry is the edge."
=> Fully validates the V2.6/V3 reframe (cheap adaptive entry -> breadth). The full
sample sharpened the finding rather than overturning it.

====================================================================
5. MECHANISM 2 -- NEVER OBSERVED across a full account (the decisive gap)
====================================================================
  The three deep EURUSD shorts (opened 13-14 Aug) NEVER CLOSED -- still open at
  expiry, marked at -129 to -163p. Zero aged (>96h) round-trips closed at profit.
  The range that would return them to profit (a USD reversal) did not arrive within
  the trial window.
Correct framing: this is NOT "the debt grew." The displacement did not revert
because the market did not hand back the range before the trial expired. The
holding behaviour was exactly as designed (hold offside inventory, grind under it,
wait). What is unobserved is PHASE 3 -- the range-return / unwind that fires
Mechanism 2. After a full account life, it has produced zero observations. Half the
thesis (survive + grind) is confirmed; the other half (reversion pays down the
carried displacement) remains entirely untested.

====================================================================
6. SURVIVAL / FLOOR -- never threatened (proxy)
====================================================================
  Final balance $10,052.31 (+$52.31 realized vs $10k). Final equity $9,960.16
  (open displacement snapshot -$92.15). Final open book: 14 positions, agg MTM
  ~-$95.80 (EURUSD -$55.47, GBPUSD -$34.94, EURGBP -$5.39).
  Floor proxy $9,599.96; lowest equity on the realized path ~$9,907.79; closest
  approach ~+$307.83 above floor. PROXY only -- true intraday MAE unknown (the live
  MAE instrument was not deployed this account; it is now built and staged).
=> Even carrying a week-plus of un-reverted displacement through ten churn days,
the account stayed comfortably clear of the floor.

====================================================================
7. FORCED-CLOSE INCIDENTS -- 4, all early, then none
====================================================================
  #1 12 Aug 17:38 GBPUSD +$0.26 ; #2 12 Aug 17:48 EURGBP/EURUSD/GBPUSD -$5.13 ;
  #3 14 Aug 03:13 EURGBP/EURUSD/GBPUSD -$3.95 ; #4 14 Aug 18:16 EURGBP/GBPUSD
  -$4.13. Total realized ~-$13. All in the first three days, NONE after 14 Aug ->
  startup/shakeout events, not recurring; the system stabilised. Target ZERO on the
  next account (each is a realized crystallisation of displacement the strategy is
  meant to hold).

====================================================================
8. THE BALANCED VERDICT
====================================================================
PROVEN this account:
  - Survives comfortably in churn (floor never near, even holding deep displacement).
  - Grinds real extractable profit: ~$30/week sustainable, net of ~10% commission.
  - Entry signal is measurably worse than dumb geometry (V2.6/V3 validated).
OPEN / UNOBSERVED:
  - Trend-day resilience: never faced a trend day (0/10). Untested.
  - Mechanism 2 (range-return / unwind): zero observations across a full account.
  - Stake recovery: on pace (~3-4 weeks) but trial expired at $72.91 / ~73% of $100.
EPITAPH:
  Over 12-25 Aug 2026 (full live export), account 1514264399 ground $72.91 NET from
  264 scalps across ten CHURN days, confirming Mechanism 1 at ~$30/week and ~10%
  commission drag, and confirming the signal entry is measurably inferior to dumb
  geometry. It survived comfortably clear of the floor while holding carried
  displacement (three EURUSD shorts from 13-14 Aug, marked -130..-163p) that the
  strategy is DESIGNED to hold and grind back. The trial simply expired before the
  range returned to unwind that displacement -- so Mechanism 2, the decisive half of
  the thesis, was never observed, and no trend day ever tested the book. Not a
  triumph, not a failure: a clean confirmation of the survivable half and a complete
  non-observation of the decisive half. The account ended mid-cycle, holding as
  designed, ~73% of the way to recovering the stake.

This message has a line count of 129 lines.
