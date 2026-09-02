<!-- SENTINEL-FIRST: FXMATRIX-V2.5-TEARDOWN-BEGIN -->
# DeepSeek Teardown Commission -- FXMatrix V2.5 "Layer-Anchor Ratchet"

Phase 1 (Red Team Prime). You are the adversarial quant. Write ZERO
implementation code. Your job is to break this design or prove it sound,
per the four-phase pipeline. Hunt statistical pathologies, mechanical
flaws, and retail heuristics. If you find a fatal flaw that invalidates
the PREMISE (not merely a fixable detail), invoke the Override Rule and
say so explicitly.

---

## 0. READ THIS FIRST -- the going-concern frame (do NOT retail-judge)

FXMatrix V2 is a market-making / liquidity-provision going concern, NOT
a retail directional strategy. Judging it by retail metrics is a known
failure mode. The frame:

- The market lives in little trading ranges. We quote a grid and fade
  the extremes (bid the low, offer the high), harvesting oscillation.
  That IS the edge: being the mean-reversion counterparty inside a range.
- We NEVER stop out. By design. Stopping converts a recoverable MTM loss
  into a permanent realized one and breaks +EV.
- Risk shape is fundamentally short-gamma: win small/often in range, lose
  big/rarely on breaks. Layer depth is bounded by reality (hitting deep
  layers requires the pair going to ~0; geometry stress-tested against the
  largest directional moves of the last 25 years).

Therefore: no stops, held inventory, MTM drawdown, high trade counts are
CORRECT behavior, not bugs. Do NOT critique the design for "why no
stops" or "why hold offside inventory" -- that is the thesis, not the
target. Attack the RATCHET MECHANISM and its verification, nothing else.

Burden of proof for this change is NON-INFERIORITY, not superiority. It
is a CORRECTNESS / hygiene fix, expected P&L-NEUTRAL. It must not be
argued (by us or you) as "makes more money" or "fixes the doldrums" --
those claims are explicitly disavowed. Your teardown should hold us to
non-inferiority and to safety, not to a superiority claim we are not
making.

---

## 1. THE FLAW V2.5 FIXES

The current grid is ANCHOR-relative: L0 is a fixed price, layers are
fixed offsets from it (the tested +8/+12/+16... spacing). That gives an
arbitrary, possibly-outlier starting point false gravitational
significance -- the system implicitly "wants" price to return to L0.

## 2. THE MECHANISM (one rule)

On any qualifying EXIT fill, the exit price becomes the new ladder origin
L0'. Rebuild the STANDARD ladder from it (same tested spacing). No exit
(monotonic move) -> ladder unchanged. No harvest/no-harvest branch, no
floor, no ceiling. The exit is the origin.

Worked examples (pips):
- Monotonic, no exit = 10, 18, 30, 46 (classic anchored ladder).
- Exit at 27 -> L0'=27 -> 35, 47. Lands INSIDE the old corridor
  automatically, because min layer spacing (~8) > add-to-exit distance
  (~3).
- Gap exit at 21 -> L0'=21 -> 29. BELOW old L2=30, and that is CORRECT:
  21 is where the market really traded; re-basing there tracks the new
  regime, which is the entire point.

## 3. RESOLVED ARCHITECTURAL DECISIONS -- these are SETTLED GIVENS

The teardown attacks THIS fully-specified mechanism. Do NOT fork-hunt or
re-open these decisions to invent optionality. You MAY challenge any one
of them ONLY if you can PROVE it is unsafe/corrupting, in which case
state the concrete mechanism and a minimal repro -- not a hand-wave.

(D1) TOPOLOGY: per-side independent. MM_LONG and MM_SHORT run separately
by design. An exit re-bases ITS OWN side's origin only; the opposite side
is untouched. Consequence: T-1 (drift) is a WITHIN-SIDE analysis. Do not
construct a cross-side coupling attack -- there is no shared L0'.

(D2) RE-BASE TRIGGER = CLEAN HARVEST ONLY. Only a primary exit-hedge
magic (GBPUSD 903/904, EURUSD 913/914, EURGBP 923/...) filling as a
normal +3 target against a normal entry layer re-bases L0'. CloseBy
nets, exit-hedge-MECHANICS fills, and manual/reconciliation closes do
NOT re-base. Rationale: only a clean harvest is EVIDENCE of a micro-range
(we trade many separate micro-ranges); other exits are plumbing, not a
range signal. Note this already partially defends T-2 by construction: a
rollover ghost fill usually lands on non-harvest machinery, which cannot
re-base.

(D3) ORIGIN = FILL PRICE (broker truth -- "where it really traded"),
GATED by a spread-check that rejects/defers the re-base if the spread at
fill was anomalously wide (the T-2 rollover-ghost defense). Carry-exact
L0' (storing level+date so it stays aligned with carry-adjusted exits
across rollovers) is DEFERRED as a to-do; initial small fuzziness is
acceptable because exit-distance (~3 pips) << spacing (~9 pips). NOTE: an
EA CAN read last-exit price+time by magic via HistorySelect + DEAL_MAGIC,
but that is CLOSED history, which is untrusted on restart per ADR-112 --
which is exactly why durability (D4) is a fallback, NOT a history lookup.

(D4) DURABILITY / MID-FLIGHT-CRASH = POSITION_PRICE_OPEN FALLBACK. In the
~50ms window between an exit filling and the new ladder being placed, a
VPS hard-crash loses L0' (it is not yet in the order book, and closed
history is forbidden). On recovery, that one position rebuilds from
POSITION_PRICE_OPEN -- i.e. reverts to today's anchored logic for that
position only. Non-atomic but safe; NO new state-file dependency; manual
reconciliation if it ever bites. We are DELIBERATELY not building
crash-atomic state persistence for a one-in-a-million window with a
benign failure. See the narrowed T-A' directive below.

(D5) NON-INFERIORITY TEST -- PRE-REGISTERED (fixed BEFORE any run;
deciding "within noise" post-hoc is the trap we are avoiding):
  - Primary metric: per-window NET P&L across ~20-30 PRE-NAMED
    choppy/range-bound windows.
  - Delta (non-inferiority margin) = the LARGER of (a) the fixed-anchor
    arm's OWN measured cross-window P&L dispersion -- computed from the
    fixed-anchor arm FIRST, so the noise band itself sets the yardstick
    (this operationalizes "anchor P&L is partly luck"); or (b) 10%
    (stated willingness-to-pay for the correctness fix).
  - Guards (independent VETO even if P&L passes): max inventory-drawdown
    and time-in-inventory. If the re-base arm holds bigger/longer offside
    inventory, that is a risk-shape regression -> kill regardless of P&L.
  - Report the FULL per-window distribution, not just the mean. A
    concentrated loss in specific window-types (e.g. rollover-heavy) is a
    DIAGNOSIS (points at a specific threat), not a verdict -- fix the
    cause and re-run.
  - Decision rule (fixed before run): ship iff re-base is non-inferior on
    P&L within delta AND passes both guards; else kill or fix-and-re-run.

## 4. WHY WE BELIEVE IT IS SAFE (attack these claims)

- ORDER-BOOK-ENCODED by construction: re-base happens at exit-fill and
  immediately materializes as resting orders, so the SRE reconstructs it
  from the order book, NEVER from closed-deal history (respects the
  ADR-112/113 boundary).
- Preserves the range-fading edge: re-base tracks the band, does not march
  out.
- Never WIDER than today's ladder in the normal case.

---

## 5. THE FOUR THREATS -- with narrowed directives

### T-A' -- state persistence / mid-flight-crash race (NARROW)

Directive is NARROW by design. Do NOT propose building crash-atomic state
persistence -- that is deliberately deferred (D4). The ONLY question:

- On a mid-flight crash in the ~50ms window, does reverting THAT ONE
  position to anchored-from-POSITION_PRICE_OPEN stay cleanly localized,
  or can it CORRUPT the ratchet on the side's OTHER positions or its
  FUTURE re-bases? Prove localized-and-safe, or exhibit the corruption
  path.
- Confirm the framing: "position exists but limits wiped / failed to
  place" is ALREADY a normal SRE input today (reconstruction re-derives
  and re-posts exits). So the only NEW risk V2.5 introduces is that the
  ORIGIN for that rebuild is the lost exit price. Is that the complete
  delta, or is there a second new failure surface we have missed?

### T-1 -- re-base-chain drift (WITHIN-SIDE only, per D1)

Over many oscillations in a STATIC range, each qualifying exit re-bases
L0'. Prove the origin CONVERGES or oscillates STABLY around the range and
does NOT slowly ratchet/drift to a pathological level. Give the
mathematical argument (fixed point / bounded-oscillation) OR a concrete
counterexample sequence of fills that drives L0' pathologically. Because
topology is per-side, do this as a single-side analysis -- there is no
shared origin to couple across sides.

<!-- SENTINEL-MID: T2-CARRY-INVARIANT -->

### T-2 -- outlier/spike re-base, esp. the 17:00 EST rollover

Largely defused by construction (D2 clean-harvest-only + D3 spread-check).
Your job is the RESIDUAL hole:

- Can a ghost/spike fill still present as a CLEAN HARVEST (correct magic,
  looks like a normal +3 target) AND pass the spread-check, and thereby
  re-base L0' to an off-market price just as liquidity returns? Construct
  the fill sequence if so.
- Verify the invariant min_spacing (~8-9) > add-to-exit (~3) holds across
  ALL THREE pairs (GBPUSD, EURUSD, EURGBP -- note per-pair AddPipsFloor
  and any pair-specific spacing).
- Verify the invariant STILL holds under the carry/rollover exit
  adjustment: does carry shifting the effective exit target near a
  rollover grow add-to-exit toward or past min_spacing, breaking the
  "lands inside the old corridor" guarantee? This is the specific
  interaction to check, since carry-exact L0' is deferred (D3).

### T-3 -- backtester path-dependence (feasibility of the A/B harness)

Can MT5's Strategy Tester reliably simulate DYNAMIC, sequence-dependent
limit-order replacement -- each qualifying exit deletes the old ladder
and posts a fresh one from L0' -- WITHOUT tick-engine artifacts that
corrupt the non-inferiority baseline? Specifically:
- Model=4 (real-tick) fill-timing artifacts when a fresh limit is posted
  mid-bar at a price the same tick may have already traded through.
- Order-replacement race inside a single tick (delete-then-place
  atomicity in the tester vs live).
- Any tester behavior that would make the re-base arm and the
  fixed-anchor arm diverge for reasons UNRELATED to the mechanism,
  invalidating the comparison.
If the tester CANNOT cleanly simulate dynamic re-posting, say so plainly
-- that invalidates the pre-registered test and we need a different
verification path, which is a Phase 1 finding worth as much as any
mechanism flaw.

---

## 6. RED-TEAM THE TEST ITSELF (D5 as a statistical object)

Beyond T-3's mechanical feasibility, attack the pre-registered test for
statistical pathologies -- this is squarely your Phase 1 mandate:
- Is choosing ~20-30 "choppy/range-bound" windows itself a selection bias
  -- cherry-picking the exact regime where the rule looks most benign?
  How should window selection be pre-committed to avoid this?
- Delta = fixed-anchor's own dispersion: is this self-referential in a
  way that can be gamed (a noisier anchor arm auto-widens the pass band)?
  Is there a degenerate case where this makes the test un-failable?
- Multiple-hypothesis / multiple-window exposure: across 20-30 windows
  plus two guard metrics, what is the effective false-pass rate, and does
  the decision rule need a correction?
- Is "report the full distribution, fix-and-re-run on concentrated loss"
  a legitimate diagnosis path, or a back-door to unlimited re-tuning
  (in-sample overfitting by another name)? Where is the line?

---

## 7. NEGATIVE SPACE (what NOT to do)

- Do NOT propose crash-atomic state persistence for T-A' -- deferred by
  design (D4).
- Do NOT re-open D1-D5 to add optionality; challenge one ONLY with a
  proven corruption/unsafety mechanism.
- Do NOT judge by retail metrics (win rate, stops, per-trade P&L).
- Do NOT write implementation code (Phase 1 rule).
- Do NOT over-flag. Every claimed exploit MUST come with a concrete
  mechanism and a minimal repro (a fill sequence, a crash-timing, a tester
  behavior) -- not a generic "this could be risky." Unsupported flags will
  be independently checked against source and discarded.

---

## 8. REQUIRED OUTPUT FORMAT (so the finding is independently verifiable)

For EACH of T-A', T-1, T-2, T-3, and the Section 6 test critique, return:
- VERDICT: one of EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE /
  TEST-INVALID.
- LOAD-BEARING CLAIM: stated so it can be checked against source -- name
  the file / function / invariant / magic / formula it depends on (e.g.
  "fxmatrix_v2_carry.mqh exit-modify grows add-to-exit past AddPipsFloor
  for EURGBP"), so Claude can verify it in the repo rather than trust it.
- MINIMAL REPRO / MECHANISM: the concrete sequence or condition.
- SEVERITY: fatal-to-premise (Override) / fixable-within-design /
  cosmetic.

Finally, an OVERRIDE CHECK: does any finding invalidate the PREMISE of
the ratchet (fundamentally unsound), or are all findings fixable within
the given design? State this explicitly as the last line.

<!-- SENTINEL-LAST: FXMATRIX-V2.5-TEARDOWN-END -->
