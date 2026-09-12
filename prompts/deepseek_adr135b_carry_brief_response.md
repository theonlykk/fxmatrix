# DEEPSEEK AUDIT RESPONSE -- ADR-135b CARRY EXIT ADJUSTMENT

Brief integrity gate: PASS (line 1, line 124, last line 198, total 198).
Scope audited: design D1-D10 as written; ADR-135a shipped observe path; existing
Grind_Adr013Clamp*, I6 in grind_recon.mqh, Grind_CarryGateDue in grind_carry.mqh.

---

## T1 -- ACCOUNT-CURRENCY CONVERSION

VERDICT: AMEND

Reasoning:
POSITION_SWAP is account currency (USD on FTMO). Pip size in quote is
pip_size = (digits==3 || digits==5) ? 10*point : point. For volume V lots:

  price_delta = POSITION_SWAP * tick_size / (tick_value * V)

  ledger_pips = price_delta / pip_size

Guard each division: tick_size > 0, tick_value > 0, pip_size > 0, V > 0.
If any guard fails on a layer: SKIP that layer, emit CARRY_EXIT_SHIFT with
skip_reason=tick_value_invalid, do not modify.

EURUSD / GBPUSD (quote = USD = account): formula above is exact; no extra FX.
EURGBP (quote GBP, account USD): tick_value is already USD per quote tick at
the live cross; same formula yields GBP-denominated pips. No separate GBPUSD
read is required if tick_value is live.
AUDCAD / AUDCHF / CADCHF: tick_value embeds the third-rate cross into USD;
back-conversion to quote pips is correct only while tick_value is live. At
23:50 pre-close the book is thin; tick_value==0 or unchanged for minutes is
the real failure mode -- not wrong formula.

Hybrid pending term (already points-native):

  pending_pips = swap_points * mult_tonight / pip_div   (signed by side)

Total accrued_pips = ledger_pips + pending_pips (both signed: cost negative).

Historical ledger converted with TODAY tick_value: at 0.01 lots, a full-week
AUDCHF short accrual (~7.5 pips, ~$0.75) sees <0.2 pip FX drift if the cross
moves 1% intraday; EURUSD weekly drift <0.05 pip. Below cent-rounding noise
(T2) and usually below sign-guard margin, but material when |accrued| approaches
exit_pips on OPT arms -- monitor via dual telemetry (D10).

Replacement rule:
Define Grind_CarrySwapToPips(swap_acct, V, tick_value, tick_size, pip_size):
if tick_size<=0 || tick_value<=0 || pip_size<=0 || V<=0 return NaN sentinel;
else return (swap_acct * tick_size) / (tick_value * V * pip_size).
accrued_pips = Grind_CarrySwapToPips(POSITION_SWAP,...) + pending_pips; NaN
=> skip layer. Do not substitute yesterday tick_value; skip and retry (D9).

---

## T2 -- LEDGER GRANULARITY

VERDICT: AMEND

Reasoning:
At 0.01 lots EURUSD, one pip ~ $0.10; broker swap posts in cents ($0.01
steps) => ~0.1 pip quantisation per booking vs ~0.876 pip/night charge. Over
a week the ledger sum is accurate to ~0.1 pip; the single-night error is
one cent. The hybrid exists precisely because tonight is not yet booked.
Disagreement appears when ledger_pips + pending_pips differs from a fresh
points-native total by more than ~0.15 pip (1.5 cents at 0.01 lot on USD-
quoted pairs; scale linearly with volume).

Replacement rule:
Compute both ledger_hybrid = ledger_pips + pending_pips and points_total =
pending_pips + sum(historical nights from archived CARRY_SNAPSHOT rates if
needed, else ledger_pips). If |ledger_hybrid - points_total| > 0.15 pip,
use points_total for the shift amount and set telemetry flag
ledger_points_mismatch=true. Never use ledger alone when pending_pips is
non-zero and ledger_pips unchanged from prior snapshot (stale-cent pattern).

---

## T3 -- GLOBALVARIABLE LIFECYCLE

VERDICT: AMEND

Reasoning:
D7 requires per-position-ticket signed cumulative applied shift. Leak path:
position closes but GV remains => wrong shift applied if ticket reused (MT5
ticket reuse is rare but GV name collision is permanent). Stale GVs also waste
the 4-week MT5 GV pool under high scalp churn.

Replacement rule:
GV name: GRIND_CARRY_SHIFT_<magic>_<position_ticket>.
CREATE: on first successful exit modify for that ticket (value = signed shift
applied this pass, not target accrued).
UPDATE: after each successful modify, set to (actual_exit - formula_exit) in
pips (signed per D4 direction convention).
DELETE immediately when:
  (a) position ticket no longer in broker book (deal close, CloseBy, manual),
  (b) modify returns "order/position not found",
  (c) OnInit recon finds ticket absent.
Do NOT delete on failed modify (retry needs no shift change). On terminal kill
mid-pass: next OnInit recon compares broker exit to formula+GV; mismatch
without successful modify => delete GV and HALT on I6 (fail closed). Pass
must not create GV before OrderSend success.

---

## T4 -- I6 BYPASS SAFETY

VERDICT: AMEND

Reasoning:
D7 shifts I6 anchor from formula to formula+stored_shift. Defects that can
now pass I6:
  -- Wrong-layer exit if stray order price accidentally equals
     formula_wrong_entry + stored_shift_wrong_ticket (low probability but
     non-zero under ticket confusion).
  -- Double shift applied in broker price but GV updated once: exit matches
     formula+GV, I6 passes, economics wrong (GV must track actual exit).
  -- GV lost/corrupted to match a wrong exit: masks overwrite (rare).
  -- Reconstruction adopts broker exit after manual tamper: passes if GV
     agrees with tampered price.

GV lost => I6 HALT: good, fail closed. Wrong-layer with unmatched GV on
correct ticket still HALTs on the wrong layer's I6 unless shifts coincide.

2-point window is tight for normal ops; it does not stop wrong-layer assignment
when shifts are numerically unrelated -- that remains I3/I5 ticket-linkage
territory. stored_shift should be independently bounded.

Replacement rule:
After reading GV shift_gv, compute shift_implied = (exit - formula_exit) in
pips (signed). If |shift_gv - shift_implied| > 0.5 pip, HALT I6 (GV corrupt).
Bound |shift_gv| <= age_nights * nightly_max_pips * 1.5 where age_nights =
days since position open and nightly_max_pips = max over symbols of
|swap_points|*3/10; if exceeded, HALT I6. Apply same formula+shift check in
Grind_ReconExitMatchesEntry during 135b (recon must be carry-aware, not raw
formula only).

---

## T5 -- CLAMP AND SIGN GUARD

VERDICT: AMEND

Reasoning:
Sides confirmed: long exit SELL LIMIT uses Grind_Adr013ClampSell(theoretical,
bid, ask, point, stops, out) => passive at or above ask+min_dist. Short exit
BUY LIMIT uses Grind_Adr013ClampBuy => at or below bid-min_dist. D4 credit
moves exit toward market and triggers clamp; cost moves away and rarely clamps.
Spread widening into the close makes clamp more likely; D5 intent is stay
passive, not skip profitable adjustment.

Existing clamps use stops_level only; D5 also names freeze_level. grind_carry
already snapshots freeze_level but Grind_Adr013Clamp* ignores it. On FTMO
stops=0 today; freeze may still bind on other brokers or future spec changes.

D6 vs D5 ordering: evaluate D6 first. If credit pushes long exit to or below
entry (or short exit to or above entry), SKIP modify (sign guard). Only if D6
passes apply D5 clamp. They cannot disagree if pipeline is D6 then D5: D6
skips before clamp; D5 never creates wrong-side exit.

When equivalent price is already inside the passive band (would cross spread):
place at clamp price (realise partial credit), set clamped=true. Skipping
forfeits D4 symmetry; defer-only leaves carry unreconciled until retry window
may be closed.

Replacement rule:
Pipeline per layer: compute theoretical exit -> D6 sign guard (skip if fail)
-> D5 clamp with min_dist = max(point, stops*point, freeze*point) using
separate freeze read -> modify. If clamped, send; do not skip solely because
theoretical was inside spread. Extend clamp helper or wrap existing with
freeze-aware min_dist.

---

## T6 -- SESSION DETECTION

VERDICT: AMEND

Reasoning:
ADR-135a proved SYMBOL_TRADE_MODE_FULL with market closed. TimeCurrent() is
last quote time and freezes over weekends, so hour==23 && min>=50 is true on
a Saturday terminal showing Friday time -- gate would fire with stale quotes.
Multiplier=0 on Sat/Sun prevents a bogus pending charge but does not prevent
OrderSend on dead prices.

Replacement rule:
Before any carry modify, require ALL of:
  (1) SymbolInfoTick succeeds and bid>0, ask>0, ask>=bid,
  (2) tick.time_msc strictly increased since prior tick (same pattern as
      Grind_FeedStaleAfterTick / Grind_GuardsAllowTrading feed gate),
  (3) (TimeLocal() - tick.time) < 120 s (quote not frozen while wall clock
      advances -- catches weekend freeze),
  (4) SYMBOL_TRADE_MODE_FULL.
If any fail: abort entire pass for this instance (no gate-day persist until
pass completes -- see T7/T8), schedule retry timer. Do not use day_of_week
alone.

---

## T7 -- DOUBLE-APPLY AND ORDERING

VERDICT: AMEND

Reasoning:
135a Grind_CarryGateDue persists day-of-year BEFORE work completes; if 135b
inherits that, a partial pass blocks same-day retry. Exit fill during pass:
layer loses exit order -- skip, delete GV for closed position. Reconstruct at
23:55: carry-aware I6 must see broker exit and GV aligned. Second pass same
day: blocked by gate if day already stored.

Recompute-from-ledger idempotency: target = formula - direction*accrued_pips.
If |current_exit - target| <= 2*point, skip modify (no API spend). Idempotent
ONLY if GV updated atomically with successful modify and accrued recomputed
each pass. Shift applied twice in one day without ledger change: second pass
skips if already at target.

Race: read accrued -> position closes -> modify naked order: prevent by re-
select position and exit order immediately before OrderSend.

Replacement rule:
Persist GRIND_CARRY_DAY_<magic> only after pass completes (success or bounded
retry queue drained for the day). Per layer: if no open position or no linked
exit order ticket, skip. If |exit - target| <= 2*point, skip modify. Re-validate
position+order existence immediately before OrderSend. During modify loop,
suppress HALT from I6 on layers being actively shifted (pass-in-progress flag)
OR accept transient I6 fail until GV written -- prefer flag over blind I6 widen.

---

## T8 -- MISSED DAYS AND OUTAGES

VERDICT: UPHOLD (with AMEND on sign-guard edge only)

Reasoning:
Missed 23:50 window while offline: gate not advanced (under amended T7 rule),
next online day at 23:50 recomputes full POSITION_SWAP ledger plus tonight
pending -- self-healing for economics. Multi-day outage accumulates larger
|accrued_pips|; one pass applies full shift. No catch-up outside the window
is required for ledger correctness.

Exception: D6 sign guard blocks modify when |accrued| >= exit_pips (e.g.
AUDCHF short ~7.5 pip carry vs 5 pip exit). Layer stays at formula exit;
not a halt, but not equivalent -- persistent under-reconciliation.

Replacement rule (sign-guard edge only):
When D6 skips for wrong-side, emit CARRY_EXIT_SHIFT with
skipped_by_sign_guard=true and accrued_pips in telemetry. Do not run outside
23:50-23:59 for catch-up (settled scope). Operator visibility only; no extra
pass window.

---

## T9 -- FTMO BUDGET AND LATENCY

VERDICT: AMEND

Reasoning:
Worst case: all twelve instances x every open layer in the same 10-minute
window. At ~1200/2000 daily budget used, ~800 modifies headroom -- likely
 sufficient for typical depth but not provably sufficient at max_layers across
twelve symbols. Observed 52 s latency once: 50 layers x 52 s exceeds 10 min.

Replacement rule:
Round-robin stagger: >= 75 ms between OrderSend calls per terminal, >= 250 ms
offset between instances sharing the account (hash magic mod 12). Track pass
start time; if (now > window_end - 60s) and layers remain, enqueue remainder
to D9 same-day retry timer (ADR-101 pattern) and emit pass_incomplete=true.
Do not consume gate-day until retry queue empty or window hard-expires at
23:59:50; after hard-expiry, stop sends, retry next tick day. Count each
modify against existing API counter; if daily budget < layers_remaining, stop
and defer to next broker day (ledger grows -- acceptable).

---

## T10 -- UNASKED FAILURE MODES

VERDICT: AMEND

Reasoning:
Additional production risks outside T1-T9:

1. Recon/I6 not carry-aware: if Grind_ReconExitMatchesEntry stays formula-only
while exits are shifted, every tick HALTs after first successful shift unless
D7 recon change ships in the same release.

2. Gate-before-complete (135a): partial pass burns the day (T7).

3. In-memory layer state vs broker during pass: every-tick
Grind_CheckBookInvariants may HALT mid-pass when exit moved but GV not yet
written -- needs pass-in-progress quarantine for I6 only (not a general I6
widen).

4. Ticket reuse after GV delete failure: bounded by T3 delete-on-close.

5. Wednesday 23:50: mult_tonight=3; if session guard fails and pass retries
after midnight, pending term wrong -- session guard + single window prevents.

Replacement rule:
Ship carry-aware I6 check (T4) and I6 quarantine flag during active carry
pass in the same changeset as first modify. Never persist day gate before pass
completion (T7). Document pass_in_progress in telemetry.

---

## SUMMARY

| Item | Verdict |
|------|---------|
| T1   | AMEND   |
| T2   | AMEND   |
| T3   | AMEND   |
| T4   | AMEND   |
| T5   | AMEND   |
| T6   | AMEND   |
| T7   | AMEND   |
| T8   | UPHOLD (+ sign-guard telemetry AMEND) |
| T9   | AMEND   |
| T10  | AMEND   |

Core design (D1-D4 hybrid, symmetric, pre-close, exits-only) is sound. Primary
gaps: tick_value guards and conversion (T1), cent quantisation (T2), GV
lifecycle (T3), carry-aware I6 plus shift bounds (T4), freeze in clamp (T5),
live-quote session gate (T6), gate-day persist timing (T7), stagger/budget
(T9), and recon co-ship (T10).

Line count: 325
