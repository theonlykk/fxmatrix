This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM C165: A CLAMPED ADD STOPS CHASING THE SPREAD

You are auditing ONE change on a feature branch (`c165-clamp-hold` at `9b44b57`) before it is merged
and deployed to LIVE trading terminals. Find what the tests cannot see. The attached files carry NO
line numbers except where a header says so: cite `file`, `function` and QUOTE the line (one line, or
part of one). A claim without a quote is discarded. If you did not see something, say "not in the
attached files" rather than guess.

**Attached:** `c165_branch.diff` (the whole branch: tests first with a stub, then the change);
`grind_engine_add_path.mqh` (four excerpts of the engine at `9b44b57`, each headed with its lines:
`Grind_ModifyPendingPrice`; `Grind_ComputeAddTarget` to the end of `Grind_EnsureAddNext`; the L0
re-centre; the tick loop's calls); `grind_pure.mqh` (whole); `fxgrind.mq5` (whole);
`cursor_c165_clamp_hold.md` (the prompt Cursor implemented, reviewed by another model).

**The system:** an MQL5 passive limit-order FX market maker on hedging accounts, 0.01 lots, 5-digit
pairs only (EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, GBPCHF), cap 7 or 9 layers a side. Each side
holds layers; the next layer is a resting limit order (the ADD) at a target T = the most extreme
layer's entry plus `add` pips beyond it (a sell above for a short stack, a buy below for a long one).
ADR-013 clamps any limit that would be marketable to just outside the spread (sell: ask + min_dist;
buy: bid - min_dist), so an add whose T price has already passed rests at the market instead.

**The defect (measured):** while the clamp is active, the add's price is recomputed every tick and
modified whenever it differs from the resting price by the deadband (2.0 pips). At a weekly open the
spread flickered 0.3-3.5 pips: one sell add was modified 1,033 times in 70 minutes (resting 0.83975 <->
0.8401, T 0.83882). The account (FTMO) counts every open, modify and close as a request and allows
2,000 a day; repeated breaches disable it.

**The change:** `Grind_AddClampHold(is_long, theoretical, clamped, resting, point)` returns true when
the clamp is active (|clamped - T| > 0.1 point), the resting add is at or beyond T (sell: resting >= T;
buy: resting <= T; 0.1 point tolerance) and the new price is FARTHER from T than the resting one (sell:
higher; buy: lower). `Grind_EnsureAddNext` then returns without a modify. Everything else is as before.
Claimed bound: with the add's index and T unchanged, the resting price only moves toward T, by at
least the deadband each time, so at most ceil(|resting - T| / deadband) modifies and none from flicker.

**Ruled -- do not re-open:** first placement (`Grind_SendNextAddEnt`), the ADR-013 clamps themselves,
the deadband value, the entry horizon (off in every preset: `InpEntryHorizonPips=0`; its two modifies
are deliberately left), exits, carry and recon. Not adding a rate limit was a decision; argue it only
with a concrete remaining churn path.

**How it is used:** compiled on four Linux/Wine MT5 terminals (one FTMO, three IC Markets), 39 instances;
a compile reinitialises every instance (`OnInit`, including the start-up one-shot reprice).

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. In `Grind_EnsureAddNext` the one-shot flag is consumed and cleared BEFORE the hold test, so a
  held add on the first tick after start-up still clears it.
- G2. `Grind_AddClampHold` returns true ONLY in the case described above; with the clamp off
  (clamped equals T) it always returns false.
- G3. `Grind_Adr013ClampSell` never returns a price below T; `Grind_Adr013ClampBuy` never above T.
- G4. The marketability checks (`Grind_BuyLimitMarketable`, `Grind_SellLimitMarketable`) test the NEW
  clamped price, not the resting one, and run before the hold test.
- G5. No other caller of `Grind_AddClampHold` exists, and no other add-modify path changed.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Fill price.** Find any sequence (ticks with bid / ask, T, resting) in which a HELD add fills at a
  price worse than its T (a sell below T, a buy above T), including T moving while the order is held
  (a roll of the virtual lattice, a preset reload that changes `add`, a layer filling or closing).
- **T-2 Stuck.** Find a sequence in which a held add should have been moved (toward T) but is not, so it
  never fills while price trades at or through T; or rests so far away that the stack misses an add it
  would have taken before the change. Give prices to 5 decimals.
- **T-3 The broker.** A held add can sit INSIDE the spread (a sell between bid and ask when the spread
  widens). On MT5 (netting off, hedging account, `ORDER_FILLING_RETURN` limits) is a resting limit inside
  the spread valid, filled at its price or better when touched, and never rejected or cancelled by the
  server? Any interaction with the freeze level or stops level when a LATER modify of the same order is
  sent? Say ASSUMED where you rely on MT5 behaviour not in the files.
- **T-4 Remaining churn.** With the change, list every path by which the add path can still send more
  than a handful of requests per minute at a wide-spread open (label mismatch -> cancel and re-send,
  fills and re-placement, the one-shot, the L0 re-centre at 3028-3074). Estimate the count for one hour
  like the measured one.
- **T-5 Start-up and reload.** After a compile (every instance re-runs `OnInit`), and after a preset
  reload that changes `add` in either direction (6 -> 18, 18 -> 6), is the first tick's behaviour right,
  with the clamp active and inactive?
- **T-6 Numbers.** The tolerances (0.1 point) and the deadband (pips x point x 10) on 5-digit symbols:
  any equality case where floating arithmetic flips the hold (resting exactly at T; clamped exactly at
  resting) and produces a modify per tick?
- **T-7 Tests.** For CH1-CH8 and CE1-CE9 in the diff: which assertion passes vacuously or for the wrong
  reason (a set-up that makes `Grind_EnsureAddNext` return before reaching the hold: label, cap, slot
  guard, marketability)? Which behaviour of the change has no test that fails without it (the long
  mirror of CE4; T moving while held; the clamp switching off then on)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-7` (verdict, evidence with quotes, the
smallest fix if any, with a test: ticks, bid / ask to 5 decimals, T, resting, expected modifies),
`PREMISE VERDICT` (is the change safe to deploy on live terminals as it stands), `TEST GAPS`. No
preamble. Do not call anything fatal that has a fix: give the smallest fix. If you assume a value or an
MT5 behaviour, say ASSUMED and why.

Line count: 92
