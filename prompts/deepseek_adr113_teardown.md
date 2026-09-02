DEEPSEEK RED-TEAM TEARDOWN BRIEF - ADR-113
Phase 1 (Red Team Prime). No implementation code in your response.
Adversarial, mechanically rigorous critique only.

====================================================================
0. STANDING
====================================================================
Gemini (Staff Architect) has RULED the external completeness witness =
an OPERATOR-SET GROUND-TRUTH SEED (a configured EA input, e.g.
InpSREAccountEpoch, asserting "no managed history exists on this
side/account before time T"). Do NOT relitigate that choice, and do NOT
propose broker-API / server-watermark witnesses - those were rejected as
over-engineering. Your job is to break the MECHANICS of using an
operator seed to safely enable the first-position anchor.

CRITICAL FRAMING (Gemini-acknowledged sharpening): the seed is NECESSARY
but not SUFFICIENT. It defines where managed history begins; it does NOT
prove the engine has LOADED history back to that point. Attack the
COMPOSITION - seed + "gather provably reaches the epoch" + the existing
ADR-112 readiness filters - not the seed in isolation. A design that
trusts the seed without proving gather-reach re-creates the original
false-flat with a deterministic bypass switch, which is worse than the
current fail-closed.

Source references at HEAD 155324f (ADR-112, shipped). Line numbers real;
verify against source.

====================================================================
1. WHAT SHIPPED (ADR-112) - the substrate ADR-113 builds on
====================================================================
V2_SRE_EvaluateReadiness (state_reconstruction.mqh) is a REJECTION
FILTER, verbatim:
  - R1: if !history_select_ok -> HALT_31_HISTORY_UNAVAILABLE.
  - R2: for each open entry position P, if P's own DEAL_ENTRY_IN with
        entry_magic is absent from the gathered deals -> HALT_32.
  - R3: if any open position P has open_time < (lookback_from -
        lookback_sec) -> HALT_32.
  - else V2_SRE_OK ("not rejected" - explicitly NOT "proven complete").

V2_SRE_FindAnchor (state_reconstruction.mqh, UNCHANGED by ADR-112)
anchors on the most recent time-bucket where cumulative managed entry
AND exit volume are both ~0 (a flat). Its Site-2 branch, verbatim:
    if(last_flat < 0) {
       result.halt = V2_SRE_HALT_09_ANCHOR_NOT_FOUND;
       return result;
    }
The first-position case (orphan is the first managed deal on its side)
reaches Site-2: no prior flat exists, so it halts. ADR-113's job is to
let this branch, UNDER PROVEN CONDITIONS ONLY, treat window-start as a
valid flat instead of halting.

Lookback: V2_SRE_DEFAULT_LOOKBACK_SEC = 90 days.

====================================================================
2. THE CORE THING TO ATTACK
====================================================================
ADR-113 will (conceptually) relax Site-2 to:
    if(last_flat < 0) {
       if( <first-position anchor is PROVEN SAFE> )
           treat window-start as the anchor;   // genesis
       else
           HALT_09;                             // unchanged fail-closed
    }
Your task: define what "<PROVEN SAFE>" must contain, and break every
weaker version of it. The candidate predicate is a CONJUNCTION:

  (S) Operator seed present and asserts epoch T for this side/account.
  (G) The gather PROVABLY reaches back to T: i.e. the engine can show
      the loaded deal set covers [T .. now] with no gap, OR that T is
      at/after the true earliest loadable point.
  (F) The ADR-112 filters (R1-R3) all pass.
  (Z) The side is genuinely flat from T to the first gathered managed
      deal (no open managed position straddles T).

Attack each, and attack the conjunction:

C-A. SEED-ONLY (S + F, no G). The naive design. Show the concrete
     partial-sync sequence where seed T is set, R1-R3 pass, yet the
     gather's earliest visible deal is AFTER T because earlier deals
     are unsynced - so window-start is a FALSE flat and the genesis
     anchor mis-reconstructs. Confirm this is a FALSE-COMPLETE
     (catastrophic), and that it is strictly worse than today's HALT
     because it is a deterministic bypass.

C-B. GATHER-REACH PROOF (G). How can the engine prove the gather
     reaches T using only in-terminal signals, given ADR-112 already
     established HistorySelect completeness is unprovable? Candidates to
     break:
     (i)  "earliest gathered deal_time <= T" - does a visible deal at
          or before T prove NO deal between T and that deal is missing?
     (ii) "HistorySelect(T, now) returned true" - does true mean
          complete, or just 'call succeeded'? (ADR-112 says the latter.)
     (iii) "gathered_deals count stable across a re-poll" - ADR-112
          already ruled stability != completeness. Does it become sound
          once bounded below by T? Prove or break.
     State whether ANY in-terminal signal upgrades seed T into a proven
     reach-back, or whether G is ALSO unprovable - in which case say so
     plainly and state what that means for ADR-113's feasibility.

C-C. SEED vs 90-DAY LOOKBACK (structural). Shipped R3 rejects positions
     older than lookback_from - 90d. But operator epoch T can be OLDER
     than 90 days. Enumerate the interaction: (1) T older than 90d +
     open position older than 90d -> R3 already HALTs; does the genesis
     anchor even get reached? (2) T older than 90d + gather only spans
     90d -> the window-start is 90d-ago, NOT T, so "genesis" would
     anchor at the wrong point entirely. Must the lookback be extended
     to T when a seed is present? What breaks if it is (performance,
     HistorySelect limits, deal-volume)? Rule on whether seed and
     lookback can coexist or must be reconciled.

C-D. SEED CORRECTNESS / TRUST MODEL. The seed is operator-asserted.
     (i)   Wrong T (too early: claims flat before a real position
           existed) -> genesis anchors over a real earlier position ->
           silent mis-reconstruction. Is this detectable at all, or
           purely "garbage in"?
     (ii)  Stale T carried across account changes / re-provisioning.
     (iii) Per-side vs per-account seed: the system has long/short per
           pair. Does one epoch cover all 6 instances, or does each
           side need its own T? Show a case where a single account-wide
           T is wrong for one side.
     (iv)  Auditability: what must be logged (ADR-112 observability is
           in place) so a bad seed is diagnosable AFTER a mis-recon,
           since it cannot be caught before?

C-E. THE "GENESIS IS FLAT" ASSUMPTION (Z). Even with S+G+F, is
     window-start provably flat? A position could have opened before T
     and closed after T (operator's T wrong), or opened before the
     gather's earliest reach but after T. Show whether R2 (open
     position entry present) fully covers this or leaves a hole for
     CLOSED pre-T cycles (the ADR-112 invisible-closed-cycle problem,
     recurring here).

====================================================================
3. WHAT A CORRECT ADR-113 PREDICATE MUST GUARANTEE
====================================================================
State the minimal conjunction that makes the genesis anchor safe, or
prove no in-terminal-plus-seed construction achieves it (in which case
ADR-113 is infeasible as scoped and we report that to Gemini). If it IS
achievable, specify:
  - the exact predicate (S/G/F/Z terms that must ALL hold),
  - which terms are provable in-terminal and which rely on the seed as
    an axiom,
  - the failure class of each residual gap (FALSE-COMPLETE vs
    FALSE-HALT), and confirm no residual is FALSE-COMPLETE,
  - whether the lookback must extend to T,
  - the determinism property (same inputs -> same verdict; no
    wall-clock/polling dependence in the safety decision).

====================================================================
4. INTEGRATION CONSTRAINTS (do not break these)
====================================================================
  - The genesis relaxation is a PURE-LOGIC change in FindAnchor. Per
    ADR-112 discipline it must enter as an explicit input (e.g.
    allow_window_start_anchor / a proven-genesis bool), NOT a global,
    so the 19 pure-logic tests + parity gate stay valid. Confirm or
    contest.
  - ADR-112 filters R1-R3 must remain; ADR-113 ADDS a gated path, it
    does not weaken existing rejections.
  - No positive "history complete" verdict may be emitted anywhere -
    the seed is an operator AXIOM, not a proof; keep that distinction
    explicit in naming and logging.
  - Single combined ADR-113 (Gemini ruling): seed infra + anchor
    enablement are one atomic change.

====================================================================
5. REQUIRED OUTPUT FORMAT
====================================================================
For each of C-A..C-E: VERDICT (sound / unsound / conditional), the
precise failure mode + triggering condition, and failure class
(FALSE-COMPLETE catastrophic / FALSE-HALT tolerable). Then: the minimal
safe predicate (or an infeasibility proof), the lookback-vs-T ruling,
the seed granularity ruling (per-side vs per-account), and the
observability fields needed to diagnose a bad seed after the fact.
State any MHT / determinism / trust-boundary concerns explicitly. No
implementation code.
