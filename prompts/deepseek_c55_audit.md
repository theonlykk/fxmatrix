This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM C55: ADR-162 PHASE B2 (TICK CATCH-UP, ROLL_STRANDED, ROLL_CLOSING_STUCK)

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: stubs and tests (`4ca8119`) 2091/2114,
failing exactly the 23 predicted; the implementation (`9db6b85`, plus
`00e0e4e`, which only removes `static` from six file-scope helpers the
MQL5 compiler rejected) 2114/2114. Find what tests cannot see. The
attached files carry NO line numbers: cite `file`, `function` and QUOTE
the line (one line, or part of one). A claim without a quote is
discarded. Line numbers below are ours, for orientation.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders, hedging account, 0.01 lots, cap 8 layers per side).
Eleven instances per terminal share global variables. The exit queue
(ADR-151, K=1, H=0) keeps only rank 0 and the highest rank resting. I6
checks each resting exit against its formula; a quarantine that does not
clear in 3 s and 3 checks halts the instance.

**ADR-162 (on `main`, input `InpVirtualLattice`, default false):** at
cap, when the market trades through the next grid level, the OLDEST
unrolled layer is rolled: its exit is re-priced to that level's exit and
a virtual level GV records the level (`Grind_LatticeRollLayer` ~978).
`Grind_LatticeTrySide` (~1156) loops level by level (a gap rolls several
layers), backs a side off after a failed modify, and stops on a
"closing" candidate. B1 tested each level against the CURRENT ask (long)
/ bid (short) only.

**B2 (this branch):**
- `Grind_LatticeTrackExtremes` (~883) / `Grind_LatticeTrackOneSide`
  (~787), called from `Grind_LatticeOnTick` (~1248) BEFORE its `blocked`
  check: per side at cap, a running extreme -- lowest ASK (long) /
  highest BID (short) -- over the terminal's tick history
  (`Grind_LatticeCopyTicks` ~725: `CopyTicksRange(..., COPY_TICKS_INFO,
  from, current tick msc)`; a test seam when `g_grind_order_test_active`)
  and the live price. The window starts 1 s after the side's newest
  position open, at most 24 h back; a cursor (`from`) advances past the
  last tick read; a read failure changes nothing (retry next tick). The
  state resets when the side drops below cap. No GV: a restart re-reads.
- `TrySide` tests the level against `min(ask, extreme)` /
  `max(bid, extreme)`. When every layer is rolled and the LIVE market is
  2 add steps beyond the lowest effective level: WARN `ROLL_STRANDED`,
  latched per side (`Grind_LatticeMaybeStranded` ~1120). When the
  candidate stays "closing" 60 s on the same position: WARN
  `ROLL_CLOSING_STUCK`, latched (`Grind_LatticeNoteClosing` ~1084).

**Ruled -- do not re-open:** tick history instead of M1 bars (bid bars
carry only the bar's minimum spread); the running extreme since cap,
so a level crossed while a roll was held off (backoff, closing,
quarantine) rolls afterwards even if the market has come back -- the
OPERATOR's choice for these demos; window start and 24 h cap; S = 2 on
the live market; 60 s closing WARN; silent retry on a read failure
(Gemini GD1-GD6, attached spec, bottom). Earlier rulings (GA, GB, GC)
stand.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. `Grind_LatticeTickExtreme` ignores ticks before `from_msc` and
  non-positive asks (long) / bids (short), and returns the min ask /
  max bid.
- G2. Live code never reads the test seam: `Grind_LatticeCopyTicks`
  uses the seam only when `g_grind_order_test_active`.
- G3. Below cap, every B2 variable of that side is reset.
- G4. The extreme is used only for the crossing test; ROLL_STRANDED uses
  the live price.
- G5. `00e0e4e` changes only the six `static` keywords.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Tick-history semantics.** `CopyTicksRange` bounds (inclusive?),
  order, ticks sharing one `time_msc` (the cursor is `last msc + 1`: can
  a tick at the same msc arrive after the read and be skipped?), ticks
  newer than the current tick, `COPY_TICKS_INFO` ticks whose ask or bid
  is 0 or stale. Can any make the extreme WRONG in the unsafe direction
  (a roll where no limit could have filled)?
- **T-2 Stale extreme across a refill.** The state resets only when
  `OnTick` sees the side below cap. Can a rolled exit fill AND the real
  re-add fill with no `OnTick` in between (deals are processed in
  `OnTradeTransaction`; where is the re-add placed?), so the old
  extreme survives into a new cap episode and rolls a layer the market
  never reached after the re-add? Same question for a restart with a
  different book.
- **T-3 Cost of a read.** At a restart with a side at cap, the first read
  can span 24 h of ticks inside `OnTick`. How long can that block the
  EA (every instance on the terminal does it), and what happens while it
  returns -1 during history sync, tick after tick? Any path where it
  blocks every tick?
- **T-4 Latches.** ROLL_STRANDED clears when the side has a candidate or
  drops below cap; ROLL_CLOSING_STUCK clears when the loop ends without
  a closing stop. Can either spam, never fire when it should, or fire on
  a healthy book (a normal CloseBy of a few seconds; a side that is
  stranded only on the extreme)?
- **T-5 Off means off.** With `InpVirtualLattice=false`, does any B2 code
  run? With it on and the side below cap, does B2 change anything?
- **T-6 Blocked instances.** Tracking runs while halted or quarantined.
  Can anything it does (reads, resets, latches) interfere with a halt,
  a quarantine, reconstruction or the carry pass?
- **T-7 Tests.** Which B2 behaviour has no test that fails without it?
  Does any assertion in `fxgrind_tests_c55.mqh` pass vacuously (inside an
  `if`, on leftover state, on a fixture that never reaches the code)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-7`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` with the lattice OFF, and is B2
consistent with the operator's rule with it ON), `TEST GAPS`. No
preamble. If you assume a value (an MT5 behaviour, an order of events),
say ASSUMED and why.

Line count: 112
