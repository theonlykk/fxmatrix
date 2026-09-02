DEEPSEEK RED-TEAM TEARDOWN BRIEF
Phase 1 (Red Team Prime). No implementation code in your response.
Adversarial, statistically/mechanically rigorous critique only.

====================================================================
0. STANDING
====================================================================
Gemini (Staff Architect) has MANDATED Posture B and authorized a
single combined ADR-112. Your job is NOT to relitigate posture. Your
job is to break the MECHANISM of the history-readiness proof before it
is designed into code, because it is the load-bearing, hardest-to-
verify part. Gemini explicitly directed the audit be aimed "heavily at
the mechanics of the MT5 history-readiness proof, as terminal
synchronization states are notoriously hostile to evaluate
deterministically." Treat that as your primary target.

Source references are at repo HEAD bc4fdd4. Quoted line numbers are
real; verify against source.

====================================================================
1. WHAT FAILED (locked root cause - do not re-derive, attack the FIX)
====================================================================
V2_SRE_FindAnchor (ea/fxmatrix_v2_state_reconstruction.mqh, 775-830)
anchors on the most recent time bucket where cumulative managed entry
AND exit volume are both ~0 (the last observed FLAT), then replays
forward. It has two HALT_09 emit sites:
  - Site 1 (line 797): filtered window empty.
  - Site 2 (line 823): window non-empty but no dual-flat bucket found
    (last_flat == -1).

Live Gate 2: the orphan short 517307012 (opened 09:55:29) was the
FIRST-EVER 902/904 deal on the account. The short gather's earliest
deal is the orphan's own open; the side is +0.01 from bucket 0 and
never returns flat -> last_flat == -1 -> Site 2 HALT_09. Fail-closed
fired correctly.

====================================================================
2. THE CORE UNSAFE AMBIGUITY (the thing the fix must resolve)
====================================================================
From inside the EA at OnInit, two states are BYTE-IDENTICAL:
  (1) TRUE first position: the window genuinely opens flat. Anchoring
      window-start is SAFE.
  (2) PARTIAL gather: earlier deals exist but MT5 history has not
      finished syncing after a cold restart, so the earliest VISIBLE
      deal is not the true earliest. Anchoring window-start
      reconstructs from a FALSE flat and mis-counts layers on a LIVE
      position.

Timestamps do not disambiguate (case 2's missing deals have
timestamps; they are simply not loaded). The current gather cannot
tell these apart, so it fails closed on both - safe but blocks case 1.

VERIFIED AT SOURCE: there is NO readiness guard anywhere. The only
HistorySelect is ea/fxmatrix_v2_sre_oninit.mqh:286:
    if(!HistorySelect(from, lookback_from + 86400))
       return;
A false return and a synced-but-empty result are handled IDENTICALLY
(both -> zero deals). The proof must distinguish THREE states the code
currently collapses to one: sync-failed, synced-genuinely-empty,
synced-partial.

Insertion seam (from source, ea/fxmatrix_v2_sre_oninit.mqh):
  - V2_SRE_RunSideOnInit (677+) is the live path. Gather is called at
    731; result.history_read set true at ~734; then pure logic
    V2_SRE_RunOnInitSteps3To10 (385) runs on the gathered arrays.
  - The pure logic is fixture-injectable and separately unit-tested
    (19 tests). A readiness proof should live at the LIVE IO boundary
    (around 731), NOT inside the pure reconstruction math, so existing
    pure-logic tests and the parity gate stay valid. Confirm or
    contest that this seam is correct.

====================================================================
3. WHAT YOU MUST ATTACK - candidate readiness-proof mechanisms
====================================================================
MQL5 exposes no direct "history fully synchronized" primitive. Any
proof is assembled from indirect signals. For EACH candidate below,
hunt the failure mode: the specific broker/terminal/timing condition
under which the signal reports "ready/complete" while history is
actually still partial (a FALSE-COMPLETE), or reports "not ready"
forever (a livelock / permanent false-halt). A false-complete is the
catastrophic case: it re-opens the exact false-flat reconstruction we
are trying to prevent.

C1. Connection gate: TerminalInfoInteger(TERMINAL_CONNECTED) before
    gather. Attack: connected != history-synced; connection can be up
    while deal history is still streaming. Quantify the gap.

C2. Retry-until-stable: call HistorySelect + HistoryDealsTotal
    repeatedly with a delay until the count is unchanged across N
    consecutive polls, then proceed. Attack: what N and what interval
    defeat a slow/bursty sync? Can the count plateau MID-stream (a
    false plateau) and then resume? Is there any count value that
    proves completeness, or only stability? Bound the worst case.

C3. Positive lower bound via known truth: we KNOW the open position(s)
    exist (from PositionsTotal, already gathered at 702-703). Require
    that the gathered deal history CONTAINS the entry deal(s) for every
    currently-open managed position before trusting the window as
    complete. Attack: is "every open position's entry deal is present"
    sufficient to prove NO OTHER earlier deals are missing? Construct
    the counterexample where all open-position entry deals are present
    yet an earlier CLOSED cycle is still unsynced (which would still
    corrupt the flat-bucket scan). Does this narrow the ambiguity or
    only appear to?

C4. Time-anchored completeness: require the gather to contain at least
    one deal older than the oldest open position's open time, OR prove
    the account's first-ever deal is within the window. Attack:
    account-inception detection reliability; broker deal-time
    granularity; the boundary where "oldest open position" itself is
    the first-ever deal (the exact Gate 2 case) - does this candidate
    collapse to unfalsifiable there?

C5. Deadline + fail-closed fallback: bounded wait (e.g. up to T
    seconds of polling); if completeness not proven by T, remain
    HALT_09 (current behavior). Attack: does a deadline reintroduce
    non-determinism (same restart, different outcome by timing)? Is a
    timing-dependent fail-closed acceptable, or does it violate
    determinism? What T is defensible and on what evidence?

You are encouraged to reject all five and propose the failure-mode
class a correct proof must cover, if none is sound.

====================================================================
4. THE FIRST-POSITION ANCHOR (second half of the atomic change)
====================================================================
ONLY once completeness is proven may window-start be treated as a
valid last_flat for a first-ever position. Attack the coupling:
  - Is "completeness proven => window-start is flat" actually valid,
    or are there states where history is complete yet window-start is
    NOT a safe flat (e.g. a position opened before lookback_from - 90d
    horizon)? Interaction with the 90-day lookback bound.
  - Does allowing a first-position anchor weaken Site 2's protection
    for the ESTABLISHED-stack partial-gather case? Prove the anchor
    relaxation cannot fire unless completeness is proven.
  - Confirm the two halves are genuinely inseparable (Gemini's atomic-
    ADR rationale) or identify any safe decomposition.

====================================================================
5. SRE OBSERVABILITY (folded into the same ADR by Gemini)
====================================================================
Gemini mandates an OnInit reconstruction telemetry event. Minimum
payload he specified: total gathered deals, lookback window size,
anchor index, and the specific halt site/reason on failure.
Attack for completeness/safety only (not posture):
  - What ADDITIONAL fields are required to make a FUTURE live halt
    self-diagnosing without forensics (e.g. readiness-proof outcome,
    poll count/elapsed, earliest+latest gathered deal_time,
    open-position count, which candidate gate passed/failed)?
  - Emission timing: must the event emit BEFORE any halt-return on
    every path (including the empty-window Site 1 and the sync-not-
    ready fallback), or it will miss exactly the cases it exists for.
    Identify any return path that would skip it.
  - Payload must not leak secrets or block OnInit (WebRequest is
    synchronous - ea/TelemetryEngine.mqh:388). Flag any blocking/
    latency risk of emitting during OnInit.

====================================================================
6. REQUIRED OUTPUT FORMAT
====================================================================
For each candidate C1-C5: VERDICT (sound / unsound / conditional),
the precise failure mode with the triggering condition, and whether it
produces FALSE-COMPLETE (catastrophic) or FALSE-HALT (merely
unavailable). Then: your recommended readiness-proof construction (or
the failure-mode class a correct one must cover), the first-position
coupling verdict, and the observability field set. State any MHT/
selection/determinism concerns explicitly. No implementation code.
