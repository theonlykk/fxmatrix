# Phase 1 Audit Request — State Reconstruction Engine Design Sketch (v2, synthesized)

This is a Phase 1 adversarial red-team audit request, per ARCHITECT.md's
multi-agent workflow. Gemini formally reopened this initiative on
2026-08-04 and ruled on sequencing: Claude drafts first, DeepSeek
audits second. This version synthesizes two independently-drafted
design passes into one — the first pass (grounded in direct
inspection of the live account) and a second pass (covering
cumulative pod-session state the first pass didn't address) — rather
than picking one over the other. Neither pass has been touched by
DeepSeek yet.

## Background

V2's standing operational rule: no recompile/reload/reattach on any
live or demo instance unless the chart is 100% flat. Root cause:
OnInit never rebuilds g_long_layers[] / g_short_layers[] from actual
broker state — arrays start empty on every attach, and the orphan
guard halts (by design, safely) if it finds real open positions the
empty array doesn't know about. This has directly blocked shipping
already-verified fixes (ADR-102/103) for days.

Empirical grounding, confirmed this session from the live account
(1514123579, weekend snapshot): all 9 real open positions had a
paired V2_Exit pending order sharing an identical placement timestamp
with the position, correct exit direction (LONG->SELL_LIMIT,
SHORT->BUY_LIMIT), and exit magic = entry magic + 2. Also confirmed: a
layer whose exit placement is blocked (exit_ticket stuck at 0) already
self-heals via the existing tick-audit NEEDS_PLACE path, retrying
every 15 seconds with escalation logging at 90 seconds. No AlgoTrading
or trade-allowed gate exists anywhere on the OnTradeTransaction ->
AppendLayer path.

## Design, Part A — Hot state: direct matching, no history walk

For currently-open positions and currently-resting orders, reconstruct
via direct matching against current broker state, not deal-history
replay:

1. Enumerate open positions by magic/symbol, sort by open time,
   assign as layer array indices 0..n-1. Order matters beyond
   membership — layer index/depth feeds the easing ramp, MaxLayers,
   and possibly exit-fraction-by-depth elsewhere.

2. For each position, search live pending orders for a same-symbol,
   correct-exit-magic, correct-direction order whose placement
   timestamp exactly (or near-exactly) matches that position's open
   time. If found, assign as that layer's exit_ticket. If not found,
   or if more than one candidate is equally plausible, leave
   exit_ticket = 0 rather than guess — the existing NEEDS_PLACE
   self-healing path takes over from there.

3. Reconstruct the single per-side add/reload ticket
   (g_long_add_ticket / g_short_add_ticket) by scanning pending orders
   for the reload/add magic on that side — 1:1 per side, no matching
   ambiguity the way there is for exits.

4. If reconstruction cannot reach an unambiguous state (position count
   doesn't reconcile against what pending orders imply, or a genuinely
   ambiguous timestamp tie), fall back to current behavior: halt
   loudly via the orphan guard, exactly as today. This only removes
   the halt in the confident-reconstruction case; it does not weaken
   the fail-safe for the ambiguous case.

## Design, Part B — Cumulative state: anchored replay still needed

Part A recovers hot state (what's open, its depth/order, its exit and
add/reload tickets) entirely from current broker state. It cannot
recover state that depends on history no longer visible in current
positions/orders:

- V2PodSession accumulators (layers_closed, gross_pnl, layer0_entry,
  start_time) — genuinely path-dependent, no current-state shortcut.
- last_exit_valid / last_exit_price (reload vs fresh-add distinction)
  — depends on the most recent closed deal, not visible from open
  positions at all.

For this state only (not the hot state Part A already covers), walk
HistoryDealSelect backward per side (LONG/SHORT are independent
position sets under different magic numbers) to find the last point
this side had zero open layers — the pod boundary. Replay forward from
there, accumulating layers_closed/gross_pnl/layer0_entry/start_time.
last_exit_valid/last_exit_price come from the single most recent close
deal, which is not pod-bounded — a reload can reference a close from
the previous pod.

Known hazard: CloseBy (used in production's exit mechanism) pairs a
losing and profitable position into one transaction and does not map
1:1 onto a simple close of a single ticket. Deal parsing must handle
DEAL_ENTRY_OUT_BY explicitly, or the anchor-finding walk's running
volume counter gets corrupted.

Bounding: an unbounded backward walk is a latent risk on an account
with long history. Cap the walk at some maximum lookback and treat
"anchor not found within bound" as a hard failure requiring the
existing halt behavior, not an assumption that "probably flat before
that."

In-flight rollover retry state (ADR-101's close-and-reopen sequence)
is flagged separately, not solved here: a crash mid-sequence could
leave the account in a state that doesn't cleanly map to "normal" or
"needs retry." This likely needs its own detection logic and its own
conservative fallback (halt rather than resume-and-retry blind) rather
than folding into the general replay path.

## Design, Part C — Cap GV republish under reconstruction (open, not resolved)

ADR-103's cap-publish-skip logic was built for a halt-based world:
orphan scan runs before cap GV publish, the halted side skips cap sync
entirely, the clean side still publishes. Once halting is replaced by
resumption, this may need to change materially — a side that used to
skip publishing (because it was halted) now needs to publish its
*correctly reconstructed* net exposure instead, and the GBP/EUR
cross-instance cap GVs are read by other instances, so timing/ordering
across three instances reattaching independently matters. This is
flagged as an open design question, not something already solved by
ADR-103's existing mechanism.

## Things to hammer on

1. Is the exit-timestamp-match heuristic (Part A, step 2) actually
   reliable, or is one weekend's 9-for-9 match a small sample that
   happens to look clean? Are there known code paths (retries,
   requotes, partial fills, a cancelled-and-replaced exit) that would
   break exact timestamp equality in ways this wouldn't detect?

2. Layer index/depth reconstruction (Part A, step 1) assumes layers
   were always added in strict chronological order with no reordering
   possible. Confirm or refute against how AppendLayer actually
   assigns depth today.

3. Is current_add_pips genuinely a pure function of depth (derivable
   from Part A's reconstructed depth alone), or is there path
   dependency in the ease ramp (EaseDepthStart/EaseDepthFull/
   WidenRatio) that requires replay for it too?

4. Cap GV republish correctness under reconstruction (Part C) —
   what specific conditions should force which side publishes what,
   and in what order, across three independently-reattaching
   instances?

5. Ambiguous-case detection (Part A, step 4) — what specific
   conditions should force the "cannot reconstruct confidently, halt
   as today" fallback, precisely enough that this isn't a judgment
   call left to implementation? A false "confident" reconstruction
   that's actually wrong is worse than a halt.

6. CloseBy handling (Part B) — does it correctly preserve volume
   accounting in every case, including a CloseBy that spans the pod
   boundary (one leg before the anchor, one after)?

7. Scope — one shared reconstruction routine reused across all three
   production files, or three near-duplicate implementations? What's
   the real risk of the shared version given each file's magic
   constants and long/short structure differ slightly?

8. Verification path — Strategy Tester inits flat by construction; is
   there any way to backtest "EA starts with pre-existing open
   positions and orders" at all, or is this squarely in the same
   category as the caps' cross-instance GV mechanism: real
   verification only possible via an actual live/demo drill?

## Explicit tension, flagged for Gemini's Phase 3 ruling, not resolved here

Gemini's original ruling framed full deal-history replay as "the only
mathematically sound way" to solve this. Part A above reconstructs
hot state via direct matching against current broker state, with no
history walk at all. Does Part A's approach still satisfy that ruling,
or was the ruling describing the initiative's overall rigor rather
than mandating replay specifically for state that's directly derivable
from current broker state? Not resolving this here — flagging it for
DeepSeek to weigh in on technically (does Part A's approach actually
work, independent of whether it counts as "replay"), with the
labeling question landing at Gemini's Phase 3 ruling, informed by
DeepSeek's findings rather than decided ahead of them.

No implementation code in your response. Flag anything here that
should block this from going to Gemini, or any assumption above that
doesn't hold once checked against real source in the files included
alongside this memo.
