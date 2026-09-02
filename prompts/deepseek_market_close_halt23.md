This message has a line count at the bottom.

# DeepSeek Phase 1 -- Full Teardown: Market-Close Harvest Exit Lifecycle
# (in-session recognition D1 + SRE deal-history compatibility D2)

## Role
Phase 1 Red Team (adversarial quant). Write ZERO implementation code. Break the
remediation options below AND attack the source-verified characterization of the
defect. You synthesize nothing; you hunt for what is wrong.

## Frame (do NOT retail-judge)
FXMatrix is an automated per-side market-maker on FTMO. It stacks resting limit
layers (up to 20 per side), harvests them individually at a fixed exit distance,
and treats fail-closed HALTs as a safety primitive (a halted side does not trade --
correct, not a defect). No stop-losses; structural lot sizing IS the risk model.
Do NOT critique leverage, "most traders lose," or the absence of predictive signals
-- out of scope. Judge only the mechanical correctness of the exit / close /
reconstruction state machine.

## GIVENS (source-verified at commit f74a180 -- do NOT re-litigate without a
##          concrete, source-grounded counterexample)

G1. Exit recognizer. ea/fxmatrix_v2_logic.mqh:324
      bool V2_IsManagedExitDeal(entry_type, deal_magic, exit_magic)
        return (entry_type == DEAL_ENTRY_IN && deal_magic == exit_magic);
    A deal is a managed exit ONLY if DEAL_ENTRY_IN stamped exit_magic.

G2. Normal exit shape (works). V2_BuildExitLimitRequest places a
    TRADE_ACTION_PENDING opposing *_LIMIT stamped exit_magic. Its fill is a fresh
    opposing position => DEAL_ENTRY_IN, magic exit_magic => recognized by G1. The
    engine then QUEUES a CloseBy to net the original layer against that opposing
    leg; the terminating deals are DEAL_ENTRY_OUT_BY. (Layer removal in the exit
    branch fires on the recognized IN deal; the CloseBy nets the broker book.)

G3. Market-close fallback shape (defect source). ea/fxmatrix_v2_logic.mqh:186
      V2_BuildExitMarketCloseRequest:
        req.action = TRADE_ACTION_DEAL; req.position = position_ticket;
        req.magic  = exit_magic;        req.comment  = "V2_Exit";
    Closing an existing position this way books a plain DEAL_ENTRY_OUT (NOT
    OUT_BY), magic exit_magic. G1 requires DEAL_ENTRY_IN, so is_long_exit == FALSE
    and Long_HandleDealFill removes no layer.

G4. SRE reconstruction + halt. On OnInit, reconstruction runs ONLY when the side
    is orphaned at startup. Guard at ea/fxmatrix_v2_sre_oninit.mqh ~800:
      if(!V2_IsOrphanedStartupState(cfg.layer_count, total_pos)) return V2_SRE_OK;
    with (ea/fxmatrix_v2_logic.mqh:263)
      V2_IsOrphanedStartupState(layer_count, broker_position_count)
        = (layer_count == 0 && broker_position_count > 0).
    On a fresh attach layer_count == 0, so reconstruction runs IFF the side still
    has >= 1 open position. When it runs,
    V2_SRE_CheckNonStandardClosures (ea/fxmatrix_v2_state_reconstruction.mqh ~1148)
    returns HALT_23_NON_STANDARD_ENTRY_CLOSE for any position that
      (a) has an entry-magic DEAL_ENTRY_IN in history
          (V2_SRE_IsEntryPositionId -- does NOT care if it later closed), and
      (b) is closed by a plain DEAL_ENTRY_OUT.
    It `continue`s past DEAL_ENTRY_OUT_BY and does NOT inspect the OUT deal's
    magic. V2_SRE_CheckAmbiguity returns nonstd_halt UNCONDITIONALLY.

G5. f74a180 scope. Its two-pass deal collection fixed phantom-layer NETTING only
    (magic-0 manual/stop-out closes now net out). Its commit states: "Untouched:
    ... SRE HALT semantics." HALT_23 / CheckNonStandardClosures were NOT modified.
    Existing test T-SRE-MC-7 covers only the flat case (IN + magic-0 OUT + broker
    flat -> zero layers).

## The defect, stated for attack

One deal shape (G3: plain DEAL_ENTRY_OUT stamped exit_magic on an entry-magic
position) produces two coupled failures:

D1 (in-session, CONFIRMED live 04:10:53 20260828, EURUSD dumb long): the OUT deal
   fails recognition (G1); the layer is never removed; managed_depth (1) diverges
   from broker_count (0); Trigger A HALTs the side.

D2 (reconstruction, LATENT, not yet observed live): the same OUT deal, once in
   90-day history, matches CheckNonStandardClosures (G4). By the model: harvesting
   the LAST layer (side goes flat) is benign -- the G4 orphan-guard short-circuits;
   harvesting ONE layer of a still-open stack leaves the side non-flat, so the next
   OnInit runs reconstruction and HALT_23s the side. Because the strategy stacks
   and harvests individual layers, D2 is armed in the COMMON case. This also
   explains why the flat production manual-close reconstructed clean (flat => guard
   skipped the check).

## The remediation options to attack (do NOT pick one -- break each)

OPTION B -- CloseBy-shaped market close.
  Instead of TRADE_ACTION_DEAL, open the opposing leg at MARKET (DEAL_ENTRY_IN,
  exit_magic -- same shape as a limit fill), record its order as the layer's
  exit_ticket, then CloseBy it against the layer. Terminal shape becomes
  IN + OUT_BY, identical to the normal path. Claim: needs NO recognizer change and
  NO SRE change (G1 recognizes the IN; G4 skips OUT_BY). Cost: a transient
  over-hedged (two-position, net-flat) window and market-order slippage/rejection
  on the opposing leg at the exact through-target moment the fallback exists for.

OPTION C+D -- dedicated in-session recognizer PLUS SRE exemption.
  C: add V2_IsManagedMarketCloseDeal(entry_type, deal_magic, exit_magic)
       = (entry_type == DEAL_ENTRY_OUT && deal_magic == exit_magic);
     give it an ISOLATED branch in Long_HandleDealFill that matches the layer by
     position_id, records market-harvest telemetry, and calls Long_RemoveLayerAt
     WITHOUT queuing CloseBy. Retain the accepted pending_market_close flag
     (Gemini's prior ruling) so Trigger A and the BCC exclude the layer during the
     OrderSend-success -> OUT-deal window.
  D: teach the SRE that a plain DEAL_ENTRY_OUT stamped exit_magic (comment
     "V2_Exit") is a SANCTIONED close: in CheckNonStandardClosures, `continue` when
     the OUT deal magic == exit_magic. This touches the SRE HALT semantics f74a180
     deliberately left alone.

## Threats (spend effort here)

### T-1 [PRIMARY] -- Is the D2 characterization EXACT?
DIRECTIVE: attack G4/D2. Construct any case where CheckNonStandardClosures does NOT
fire on a market-close footprint I claim it would (anchor/lookback interaction; the
two-pass deal collection admitting or dropping the OUT; a position_id==0 on the
market-close OUT so IsEntryPositionId misses it), OR fires where I claimed benign.
If D2 is real, give the minimal reattach sequence (stack depth, which layer
harvested, flat vs non-flat) that arms it.

### T-2 -- Break OPTION B.
DIRECTIVE: attack open-at-market + CloseBy. Failure modes: opposing market order
partial-fill / requote / rejection leaving a naked hedge; the over-hedged window
coinciding with an OnInit/crash (does the SRE reconstruct a two-position net-flat
side cleanly, or does the CloseBy-history Option A DEAL_ORDER pairing choke?);
CloseBy volume mismatch; whether recording the market-hedge order as exit_ticket
collides with the exit-audit / BCC machinery.

### T-3 -- Break OPTION C+D (the SRE exemption specifically).
DIRECTIVE: prove or refute that whitelisting exit-magic plain-OUT in
CheckNonStandardClosures opens a hole. Is there ANY other code path that produces a
plain DEAL_ENTRY_OUT stamped exit_magic on an entry-magic position (so the
exemption would mask a genuinely anomalous close)? Does the exemption interact with
the CloseBy-history mapping or the magic-0 netting? Confirm magic-0 manual closes
STILL HALT_23 after the exemption.

### T-4 -- Empirical position_id/magic unknown (feeds OPTION C).
DIRECTIVE: state exactly what must be verified from THIS broker's real deal record
before Option C is safe -- specifically whether the market-close OUT deal carries
DEAL_POSITION_ID == the closed position_ticket (Option C matches on it; the handler
has a position_id==0 -> position_ref fallback -- assess whether that fallback
suffices if the broker leaves BOTH empty). Name the exact History/Trades-log field
to pull. This is a live-data question, not answerable from source.

## Negative space
- Do NOT write implementation code (Phase 1).
- Do NOT re-litigate G1-G5 without a concrete, source-grounded counterexample.
- Do NOT judge by retail metrics or critique the MM thesis / absence of stops.
- Every claimed exploit needs a minimal concrete sequence (ticks / fills / deal
  history / reattach), not an assertion.

## Required output format
For EACH threat T-1..T-4:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file / function / invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then a COMPARATIVE VERDICT: B vs C+D -- which family has the smaller failure
surface, and whether any option-D-free variant is safer.

OVERRIDE CHECK (last line): Does any finding invalidate the premise of the
market-close fallback itself (is a market-close harvest fundamentally incompatible
with this SRE), or are all findings fixable within one of the options?

Line count: 161
