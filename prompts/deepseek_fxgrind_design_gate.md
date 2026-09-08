This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: fxgrind PRE-BUILD DESIGN GATE (four undecided gates)
# Pre-build. No fxgrind source exists yet. Attack the DESIGN and its premises.
# Source baseline: origin/main @ 99760f6. You have READ access to ea/ and docs/.

## Role
Phase 1 Red Team (adversarial quant). Write ZERO implementation code. Attack the four
proposed design positions below AND the premise that these four are the complete set of
undecided gaps. Verify every GIVEN against real source in ea/ where a source claim is
made. You synthesize nothing; you break things.

## Frame (do NOT retail-judge)
Automated per-side market-maker on an FTMO Swing $10k demo. We POST resting limit orders
(a straddle: bid below mid, offer above). We never cross the spread and never pay entry
slippage. Adverse selection is the RAW MATERIAL of market-making, not a defect to avoid.
Wide spread / illiquidity is REVENUE to a maker, not a cost; spread matters only as a
capital-velocity effect, never as a per-scalp tax. There are NO stop-losses: risk is
managed by size (0.01 lots, stress-tested 2004-2026 within the $500 FTMO drawdown), by
the layer cap under discussion, and by the account cap. Fail-closed halts are a safety
primitive, not a defect. Do NOT critique leverage, absence of stops, absence of
predictive signal, or "most traders lose." Judge ONLY mechanical and statistical
correctness.

## Background
The current live system (signal arm + old-dumb arm) is being retired this weekend via a
"Complete Purge" and replaced by a clean-slate dumb-only EA family: fxgrind.mq5 plus
per-pair grind_preset_<pair>.mqh, magics 2226xxxx, deployed as SIX concurrent instances
(two slots x three pairs). Slot OPT runs swept geometry (GBPUSD 5/5, EURUSD 5/5, EURGBP
2.5/2 as width/exit in pips). Slot ALT runs the same widths with the OLD exit (5/3, 5/3,
2.5/3) to decompose width effect from exit effect live.

The strategy research that produced this is ratified and is NOT in scope here. What IS in
scope: on handover to a fresh engineering context, FOUR items were found to have been
never decided rather than decided-and-omitted. This teardown attacks the proposed
resolution of each.

## GIVENS (source-verified at 99760f6 -- do NOT re-litigate without a source counter)
G1. Existing State Reconstruction Engine is 2,420 lines: fxmatrix_v2_sre_oninit.mqh
    (977) + fxmatrix_v2_state_reconstruction.mqh (1,443). The Book-Consistency Checker
    reusing its matcher is a further 894 lines (fxmatrix_v2_bcc.mqh). It reconstructs
    managed layer state from broker DEAL HISTORY on OnInit.
G2. A hard layer cap mechanism already exists: `input int InpMaxLayers = 20;` in every
    production .mq5 target; consumed at fxmatrix_v2_engine.mqh:904 and :929
    (cfg.max_layers) and enforced at :586 and :1551 via `if (n <= 0 || n >=
    InpMaxLayers)`.
G3. Entry and exit are BOTH resting pending limit orders: TRADE_ACTION_PENDING,
    ORDER_TYPE_BUY_LIMIT / ORDER_TYPE_SELL_LIMIT, ORDER_TIME_GTC. Entry placement at
    fxmatrix_v2_engine.mqh:327-372; exit placement at :1216-1263.
G4. Order comments carry a ROLE TAG ONLY -- "V2_L0", "V2_Add", "V2_Reload"
    (fxmatrix_v2_engine.mqh:180, :202, :599, :1564). No layer index, no side, no slot is
    encoded in any comment today.
G5. Highest ADR referenced anywhere in committed source is ADR-123. ADR-124
    (fill-triggered re-centering) is SHIPPED AND LIVE -- its code is present in
    fxmatrix_v2_engine.mqh and fxmatrix_v2_entry_ab.mqh -- but is documented nowhere in
    the repo. Next free ADR number is 125.
G6. The width x exit sweep that produced the OPT geometry was a price-path Monte Carlo.
    It did NOT model swap, carry, rollover, or exit re-pricing. The swept optima are a
    PRE-CARRY optimum. (Session record, not source.)
G7. NO pre-registered calibration/holdout split was made. ALL regime windows (q1_chop,
    truss, full_quarter, and the n=200 precise windows) were used for SELECTION. The
    "_oos" suffix on some window filenames refers to those windows' origin, not to a
    held-out split in our procedure. A standing rule adopted 2026-08-02 requires a
    pre-registered split for exactly this class of work. (Session record, not source.)
G8. FTMO imposes a hard cap of 200 resting orders. The self-imposed pre-flight gate is
    180. Sweeps observed max layer depth of roughly 6-7 on GBPUSD and roughly 4 on
    EURGBP.

## The four proposed positions (ATTACK each)

### P-1: Reconstruct from the LIVE BOOK, not from deal history
Rather than porting the 2,420-line SRE, fxgrind encodes layer identity in the order
comment at placement time -- e.g. `GRIND|OPT|L|L03|EXIT` -- making the live book
self-describing. On OnInit the EA enumerates positions and orders by EXACT magic, parses
comments, and rebuilds the layer table from current broker state only. No deal history,
no CloseBy pairing, no 90-day lookback ceiling, no genesis-anchor problem. Fallback if a
comment is unreadable: derive layer index from price geometry, since width is fixed.
Fail-closed: if the rebuilt book fails its invariants, HALT and do not trade.

### P-2: Measure swap before ruling on carry correction
Do not port ADR-114 carry correction blind. First measure actual broker swap long/short
per symbol, convert to pips-per-night at 0.01 lots, express as a percentage of each
pair's exit target. Only if material -- worst case is EURGBP OPT at a 2-pip target --
port carry correction, widen that exit, or drop EURGBP from the initial deployment.

### P-3: Hard per-pair layer cap, sized from order-count arithmetic
Per side at depth n: n resting exits plus one resting entry/add pending. Per instance
across two sides: 2n + 2. At the inherited default cap of 20 that is 42 per instance and
252 across six instances -- over FTMO's hard 200. Proposed caps: GBPUSD 12, EURUSD 12,
EURGBP 8, giving 26 + 26 + 18 = 70 per slot and 140 across both slots. Behaviour at cap:
stop adding layers, emit telemetry, never auto-close. The concurrent drawdown sim must
run AT the cap, not at observed depth.

### P-4: Accept the live A/B as the out-of-sample check, with a pre-committed trip-wire
Given no holdout was pre-registered, either hold out a regime window and re-confirm
before finalising, or accept the live A/B as OOS and record that choice. The argument for
the latter: a banked 9/3 baseline exists from live trading of an ARBITRARY (unfitted)
geometry, so "swept geometry beats arbitrary geometry on live fills the sweep never saw"
is a real OOS claim. Trip-wire: if live OPT underperforms banked 9/3 by a stated margin
over a stated scalp count, geometry is reopened.

## Threats (spend effort here)
### T-1 [PRIMARY] -- P-1: does the live book actually carry enough state?
Attack comment-based reconstruction against real source and MQL5 reality. The MT5 comment
field is length-limited and brokers may truncate or overwrite it on the pending-to-
position transition. Verify against ea/ what state the engine actually holds per layer
that is NOT recoverable from positions + orders alone. Construct a concrete book state
that is ambiguous under P-1 but unambiguous under deal-history reconstruction. Does
ADR-124 fill-triggered re-centering (see G5, code in ea/) move exit prices in a way that
breaks the geometry fallback? Does a partial fill, a broker-side order expiry, or a fill
that occurs while the terminal is down produce a book P-1 misreads as valid?
### T-2 -- P-3: is the order-count arithmetic sound, and is the cap the right primitive?
Verify the 2n+2 topology claim against ea/ (G2, G3). Does the place-once-and-wait design
(ADR-123) rest a different number of pendings than the old add/reload path? Attack the
cap as a RISK primitive: with no stops, does capping layers bound drawdown, or only bound
the RATE of accumulation while leaving existing inventory fully exposed? Does a capped
grid in a sustained trend behave worse than an uncapped one when price returns -- i.e.
does the cap forgo the recovery layers that would have harvested the reversal?
### T-3 -- P-2: is swap the ONLY path-dependent cost the sweep omitted?
Attack the measure-then-rule sequence. Beyond swap, what else does a price-path Monte
Carlo omit that a 2-pip exit target is sensitive to -- commission, tick rounding, minimum
stop distance (SYMBOL_TRADE_STOPS_LEVEL, see ea/), weekend gaps, quote granularity? Is a
2-pip target even placeable on EURGBP given the broker's minimum distance constraints?
Name the threshold at which carry correction becomes mandatory, or prove no single
threshold is defensible.
### T-4 -- P-4: statistical validity of the proposed OOS substitute
This is the statistics threat; spend real effort. Attack the claim that a banked 9/3
baseline constitutes out-of-sample validation. The baseline ran in a DIFFERENT time
period than OPT/ALT will -- so the comparison is confounded by regime, not controlled.
Conversely OPT vs ALT is concurrent and controlled but shares an in-sample-selected
width. Is there any comparison available here that is BOTH controlled and out-of-sample?
Quantify multiple-hypothesis exposure across the width x exit sweep grid. Is the claimed
proportionality argument -- that overfit geometry costs harvest quality but not survival
-- actually true, or can a mis-selected width degrade survival through layer depth?
### T-5 -- cross-gate interaction
The four gates are presented as independent. Attack that. Does the P-3 cap interact with
the atomic CAS currency-exposure cap (six instances, shared GVs, EUR/GBP/USD mini-ring)
to produce a state where one instance's cap-hit starves or deadlocks another? Does P-1
reconstruction interact with the CAS cap on restart -- e.g. does a rebuilding instance
publish stale or missing exposure that the cap reads as permissive zero? (See the
Cap-Enablement Gate section in docs/architecture/ARCHITECT.md for the known
stale/missing-GV-reads-as-zero problem.)
### T-6 -- PREMISE: are these four the complete set of undecided gaps?
The premise under attack is that four gates cover it. Hunt for what ELSE a clean-slate
rewrite silently drops that the old system had earned the hard way. Read ea/ and
docs/architecture/ARCHITECT.md. Candidates to check, not an exhaustive list: the API-call
budget and its counter, spread-floor clamping, the feed-staleness guard, the marketability
skip, telemetry/heartbeat, stranded-leg handling and its per-pair threshold, HALT_30, the
BCC invariant sweep, and the deploy/sync scripts' hardcoded header set. Name each gap you
find, cite source, and rate whether it blocks the weekend deploy.

## Negative space
No implementation code. No re-litigating ratified strategy conclusions: entry-as-theatre,
the signal retirement, the E7 no-distribution verdict, ATR rejection, 0.01 lot sizing, the
2x-not-4x deployment, or the Complete Purge sequence are OUT OF SCOPE. No re-litigating
G1-G8 without a concrete source-grounded counterexample from ea/ or docs/. No retail
judgment. Every claimed exploit needs a minimal concrete sequence -- a tick, fill, reject,
restart, or window -- not an assertion.

## Required output format
For EACH threat T-1..T-6:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source), or for T-4 the
  specific statistical property claimed
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
- BLOCKS WEEKEND DEPLOY: yes / no / only-for-EURGBP
Then a PREMISE VERDICT: are P-1..P-4 sound as stated, and are the four gates the complete
set of undecided gaps?
OVERRIDE CHECK (last line): does any finding kill a proposed position outright, or are all
findings fixable within the four positions as stated?

Line count: 173
