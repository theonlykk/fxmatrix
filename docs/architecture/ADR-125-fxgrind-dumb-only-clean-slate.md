# ADR-125: fxgrind — Dumb-Only Clean-Slate Market-Making EA Family

## Status

Accepted — 2026-09-07 (CloseBy hedging exit fix, Spec A of B); amended
2026-09-08 (stale resting add reconciliation + I8 invariant); amended
2026-09-09 (narrow I8 — invariant/reconciler boundary); amended
2026-09-09 (intrinsic layer index — decouple from array position); amended
2026-09-09 (I5 — uniqueness + non-negative, abandon contiguity).
Spec A of B (engine, presets, placement, caps) and Spec B (comment-only state
reconstruction + CAS currency cap) implemented. CloseBy queue port completes
the hedging-account exit path (Spec A closeby-exits branch).

## Context

The retired `fxmatrix_v2_*` family combined signal-driven quoting with dumb
straddle arms, path-dependent add-spacing ratchets, and fragmented cost/risk
logic. Simulation work (ADR-126) centralised P&L accounting; live deployment
requires a **clean-slate** dumb-only engine. Live P&L telemetry (floating MTM,
realised daily P&L, exit microstructure) is implemented in `grind_pnl.mqh`
(Decision 14); simulation accounting remains in ADR-126.

fxgrind replaces two retired families (signal 2026xxxx, old-dumb 2126xxxx) with
a single parameterised codebase using magic namespace **2226xxxx** only. Six
concurrent instances deploy: OPT and ALT slots on GBPUSD, EURUSD, EURGBP.

### Mental model

Automated market maker on FTMO Swing $10k: resting limits on both sides, never
crossing the spread. Adverse selection is expected raw material, not a defect.
No stop-losses. Risk via 0.01 lots, per-pair layer caps, and account currency cap
(Spec B). Layered inventory is inventory, not realised loss.

## Decision

1. **Single engine** `ea/fxgrind.mq5` with poisoned defaults (`InpWidthPips=-1.0`,
   `InpAddPips=-1.0`, `InpExitPips=-1.0`, etc.). OnInit returns `INIT_FAILED` if
   geometry or caps are not explicitly configured — unconfigured instances must
   never trade. Add spacing must satisfy `InpAddPips == GRIND_ADD_WIDTH_MULTIPLE
   × InpWidthPips` (2.0 × straddle half-width, matching
   `scripts/grid_sim_v7_real_signal.py`); a preset whose add spacing has drifted
   from its width fails at init.

2. **Comment-as-state contract** for Spec B:
   `GRIND|<slot>|<side>|L<nn>|<role>` (≤31 chars). Parser uses `StringSplit` and
   prefix-matches role field for broker suffix contamination (e.g. `EXT[tp]`).

3. **No re-center flag in comment.** Re-centering uses `OrderModify`
   (TRADE_ACTION_MODIFY), which cannot alter comments. Re-centered L0 remains L0;
   Spec B reads prices from broker, never infers layer identity from price geometry.

4. **Per-pair layer caps (ratified):** GBPUSD 12, EURUSD 12, EURGBP 8. Cap stops
   **new entry** placement only; exits and re-centering continue; no auto-close.

5. **Order-count arithmetic:** per side at depth n → n resting exits + at most one
   resting entry → 2n+2 per instance. Ratified caps → GBPUSD 26 + EURUSD 26 +
   EURGBP 18 = 70 per slot, **140 across both slots**. FTMO hard limit 200;
   project soft gate 180.

6. **Halt-in-place.** On unparseable comments or invariant violations the EA
   sets `g_grind_halted`, places nothing, emits CRITICAL telemetry naming the
   specific failure, stays attached. **Never** `ExpertRemove()`.

7. **Configurable add spacing** via `InpAddPips` (poisoned default `-1.0`).
   Fixed spacing at `GRIND_ADD_WIDTH_MULTIPLE` (2.0) × straddle half-width — no
   widen ratchet. The retired v2 `GRIND_ADD_PIPS_FLOOR` (9.0) is removed.
   **Add anchor:** previous layer's entry price (stateless, recoverable from open
   positions). The Python simulator was conformed to this EA anchor, not the
   reverse. Place-once straddle (ADR-123). Fill-triggered re-center (ADR-124) via
   OrderModify. Absolute-pip deadband (ADR-121/122). Offline-market guard.
   Exact magic equality.

8. **Spec B — comment-only state reconstruction.** OnInit rebuilds from open
   **positions** and resting **orders** with exact magic equality only. No deal
   history, no 90-day lookback, no price-geometry inference.
   The retired `fxmatrix_v2_sre_oninit.mqh` / `fxmatrix_v2_state_reconstruction.mqh`
   (~2,420 lines) are explicitly rejected for fxgrind. `GrindCommentParse` is the
   sole layer identity source; unparseable tickets halt. Entry prices and exit
   targets are read from the broker, never recomputed. Telemetry counters reset
   to zero. Empty book is valid (genesis / Complete Purge).

   **CloseBy queue (hedging account, ratified 2026-09-07):** On FTMO hedging,
   an opposing exit limit fill opens a **new position** (`DEAL_ENTRY_IN`), it does
   not close the entry leg. fxgrind ports the proven v2 three-part exit:
   (1) place opposing limit, (2) on fill queue `{entry_ticket, hedge_ticket}`,
   (3) `TRADE_ACTION_CLOSE_BY` via per-side in-memory retry queues
   (`g_grind_long_closeby_queue` / `g_grind_short_closeby_queue`) processed every
   `OnTick`. Ticket order matches v2: `req.position` = original entry leg (older),
   `req.position_by` = exit fill leg (newer). Retry limit `GRIND_CLOSEBY_MAX_RETRIES`
   (10); exhaustion with both legs still live halts fail-closed with CRITICAL
   telemetry naming both tickets. CloseBy sends route through `Grind_OrderSendCounted`.
   The queue is transient (not persisted). **OnInit derivation (ratified 2026-09-07):**
   after reconstruction and invariant checks pass, each layer with `has_exit_position`
   queues `{position_id, exit_position_id}` into the correct per-side array — ticket
   order mirrors the live deal hook (`Grind_QueueCloseBy(..., orig_pos, position_id)` in
   `grind_engine.mqh`). Reconstruction must **not** queue when invariants fail. Queueing
   is idempotent inside `Grind_QueueCloseBy` (duplicate ticket pairs are ignored) so a
   restart cannot double-queue when the deal hook replays a pre-restart exit fill against
   an empty dedup array. Verbose init logs each derived pair (slot, side, layer, tickets).
   No file, GlobalVariable, or deal history — Gate 1 statelessness preserved through the
   pending-close window.

   **Scalp completion and P&L (ratified 2026-09-07):** A scalp completes on
   CloseBy success, not on exit-limit fill. `g_grind_scalp_count` and
   `realised_pnl_today` increment in the `DEAL_ENTRY_OUT_BY` deal hook on the
   **entry leg** (`position_id == layer.position_ticket`), net of
   `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION`. `DEAL_ENTRY_IN` from an exit
   fill does not count. The retired `DEAL_ENTRY_OUT` path never fires on hedging
   CloseBy and must not be used.

   **Note on retired SRE CloseBy pairing:** The original Spec B framing treated
   v2 CloseBy pairing as avoidable legacy complexity. That was mistaken. On a
   hedging account it is the necessary second half of the exit model; omitting it
   left entry layers naked after the first exit fill (observed live 2026-09-07:
   `I3_SHORT_NAKED` halt on EURGBP OPT/ALT with simultaneous buy/sell positions
   under magic 22260301). Do not repeat that error.

   **Stale resting add (ratified 2026-09-08):** `Grind_EnsureAddNext` derives the
   next add layer index from **`Grind_SideNextIndex`** (`max(layer_index)+1`, not
   array count) at placement time. The resting add order keeps whatever comment label it was born
   with; `OrderModify` cannot change comments. The pending add was **never
   cancelled** anywhere in the codebase — only set, cleared on fill, or forgotten.
   The engine implicitly assumed the ladder only ever grows. When CloseBy scalps
   unwind interior layers (possible only after the 2026-09-07 exit fix), depth
   drops while a stale add (e.g. `L03` at depth 1) remains at the broker →
   non-contiguous indices (`I5_*`) or duplicate adds (`AMBIGUOUS_ADD_*`). Observed
   live on GRIND_GBPUSD_OPT (magic 22260101) and EURGBP OPT 2026-09-08.

   **General lesson:** fixing one mechanism can expose a latent defect in another
   that it was masking. The exit path and the add path had never been exercised
   together until CloseBy unwinds became real.

   **Idempotent reconciliation (no depth-change memory):** every tick, if a resting
   add exists, parse its comment via `GrindCommentParse` and compare the layer
   index to `Grind_SideNextIndex`. On mismatch or unparseable comment: cancel via
   `TRADE_ACTION_REMOVE` through `Grind_OrderSendCounted` (MQL5 — not MQL4
   `OrderDelete`); clear `add_pending_ticket` **only on successful removal**;
   return without placing on that tick. Failed removal leaves the ticket tracked
   for retry. Next tick places a fresh add with correct label and price. Matching
   label: existing deadband/modify behaviour unchanged.

   **Placement guard:** immediately before add placement, assert label index ==
   `Grind_SideNextIndex`; on divergence halt in place with `HALT_ADD_INDEX_MISMATCH`
   (CRITICAL telemetry naming both indices; no order sent; no `ExpertRemove()`).

   **Invariant/reconciler boundary (ratified 2026-09-09):** An invariant defines
   a state the system cannot survive; a reconciler defines a state the system
   expects and heals. They must **never target the same condition.** Label index
   vs current depth is routine after a completed unwind (e.g. resting `L01` at
   depth 0) and is healed by `Grind_EnsureAddNext` (`TRADE_ACTION_REMOVE` +
   replace next tick). Halting on that condition (`I8_STALE_PENDING_ADD`) stopped
   the EA before the reconciler could run (observed live EURGBP OPT 2026-09-09:
   recon succeeded, scalp banked, heartbeat invariant halted). Reconstruction
   **adopts** the broker ticket into `add_pending_ticket` (read-only — no cancel
   on init); the reconciler removes it on the next tick when depth allows.

   **General rule:** if a condition has a reconciler, the invariant must not
   assert it. Index matching belongs entirely to the reconciler.

   **Intrinsic layer index (ratified 2026-09-09):** `GrindLayer.layer_index` is
   parsed from the order/position comment at fill and reconstruction and travels
   with the struct through array shifts. **Array position is meaningless** for
   layer identity. Using `ArraySize` or slot position as the index produced
   defects #2–#4 (stale add labels, orphan trackers, duplicate resting entries)
   when `Grind_RemoveLayerAt` shifted slots without updating broker comments.
   A per-tick layer reconciler (separate task) depends on this decoupling first.

   **Three meanings of "depth" (ratified 2026-09-09):**
   - **COUNT** (`Grind_SideDepth`): `ArraySize(layers)` — cap, loops, telemetry
     `open_layers_*` (unchanged: counts, not max index).
   - **NEXT INDEX** (`Grind_SideNextIndex`): `max(layer_index) + 1` (0 when
     empty) — labels the next add and feeds pending-add reconciliation.
   - **DEEPEST LAYER** (`Grind_FindDeepestLayerArrayIndex`): array index of the
     layer with highest `layer_index`; `-1` when empty — anchors add geometry.

   **Middle layer close (ratified 2026-09-09):** A retracement may close an inner
   layer while a deeper exit remains unfilled. The side may legitimately hold
   layers 0 and 2 with 1 gone; LIFO/FIFO is not assumed.

   **I5 amendment (ratified 2026-09-09):** Contiguous `0..count-1` indices encoded
   the monotonic-growth assumption and halted on legitimate gap books (e.g. sole
   `{3}` after 0–2 unwound, `{0,2}` after middle close). I5 now asserts **uniqueness**
   and **non-negative** only via `Grind_ReconLayerIndicesValid` (nested loop, no
   sort). **`max_layers` bounds count, never index** — indices may exceed
   `max_layers - 1` when the grid refills after partial unwind (e.g. holding
   `{3,4}` at count 2 with cap 5, next label L05).

9. **Spec B — book invariants (read-only, no auto-repair).** I1–I8 checked at
   rebuild and on heartbeat: paired exits, no naked positions, no orphan exits,
   unique non-negative layer indices (`I5_*_CORRUPT_LAYER_INDICES`), exit within
   `2 × _Point` of entry ± `InpExitPips`,
   depth ≤ `InpMaxLayers`, and **I8_CORRUPT_PENDING_ADD** — structural corruption
   of a tracked pending add: `add_pending_ticket` points to a ticket that is not
   a resting order (`GRIND_RECON_TICKET_ORDER`) or is absent from the enumeration.
   **Unparseable comments are not I8 scope:** reconstruction halts at
   `UNPARSEABLE_COMMENT` (main ticket loop, before assignment); on tick the
   reconciler removes unparseable resting adds without halting. Index mismatch
   with depth is **not** an invariant (reconciler scope). Duplicate resting
   entry orders per side remain **`AMBIGUOUS_ADD_LONG` / `AMBIGUOUS_ADD_SHORT`**
   in the rebuild loop (needs full ticket list; not duplicated in I8). Magic
   mismatch on the tracked ticket is unreachable — enumeration filters exact
   magic before assignment. Violations halt with named CRITICAL reason.

   **Covered-layer amendment (ratified 2026-09-07):** A layer is covered if it
   has **either** (a) a resting EXT limit order, **or** (b) an open EXT position
   (filled, awaiting CloseBy), matched by **slot + side + layer index** from the
   comment (`GrindCommentParse` fields). I3 fires only when a layer has an ENT
   position and **neither** exit form. I4 orphan-exit fires only when an EXT
   artifact exists without a matching ENT layer at the same slot/side/layer index.
   The transient post-fill / pre-CloseBy state is legitimate and must not halt.

10. **Spec B — CAS currency cap.** Cross-instance exposure via MT5 GlobalVariables
    under `GRIND2226_<magic>_<LEG>` plus companion `GRIND2226_<magic>_<LEG>_time`
    (never packed into one double). Lock `GRIND2226_CAS_LOCK` with backoff/timeout.
    **Phase 1 (OnInit):** each instance publishes own exposure unconditionally; no
    peer reads. **Phase 2 (OnTick):** peer reads before new entry placement only.
    Missing companion timestamp, missing peer key, or timestamp older than 300s
    reads as MAXED — reversing the retired v2 permissive-zero default. Threshold
    ≤ 0 means cap **off** (machinery runs, nothing blocked); threshold > 0 arms
    the limit. Cap gates **new entries only** — never exits, re-center, or close.

11. **Deploy configuration via MT5 .set files.** The unreachable `grind_preset_*.mqh`
    headers are deleted. Six committed presets live in `ea/presets/` (GBPUSD/EURUSD/
    EURGBP × OPT/ALT). `InpConfigWarning` is a dummy string input serialised into
    each .set so configuration identity survives MT5 GUI round-trips (not `;`
    comments). OnInit prints the full resolved configuration. Duplicate-magic guard:
    `GRIND2226_MAGIC_LOCK_<magic>` via `GlobalVariableTemp` (session-scoped, not
    persistent — survives terminal crash without blocking reattach). Claimed after
    geometry validation, **before** cap Phase-1 publish; released in OnDeinit.
    Heartbeat telemetry appends magic, slot, geometry, layer cap and cap-leg names
    at the end of the existing JSON schema.

12. **Ratified deploy geometry (confirmation sweep, n=50 seeds, substeps=100,
    cost model ac19a9f, entry-anchored adds).** All six cells gate-verified clear
    on FTMO Gate A (daily equity drawdown < $500) and Gate B (peak-to-trough <
    $1000), 0% breach rate; worst mean max drawdown $433.3 vs $500 daily limit:

    | Instance | Width | Exit | Add | Stranded |
    |----------|-------|------|-----|----------|
    | GBPUSD OPT | 5 | 5 | 10 | 10 |
    | GBPUSD ALT | 5 | 7 | 10 | 10 |
    | EURUSD OPT | **7** | 5 | 14 | 14 |
    | EURUSD ALT | 7 | 7 | 14 | 14 |
    | EURGBP OPT | 3 | 2 | 6 | 6 |
    | EURGBP ALT | 3 | 5 | 6 | 6 |

    Add and stranded threshold are always `2.0 × width` (`GRIND_ADD_WIDTH_MULTIPLE`).
    **EURUSD override:** sweep harvest optimum was 5/5 (mean max DD $473.9, 5%
    margin on $500 daily limit). Staff Architect ratified **7/5** ($322.8 DD) —
    a touch-fill Brownian-bridge simulator cannot model gap risk or sustained
    unidirectional prints, so 5% simulated buffer is not a real buffer; ~34%
    simulated harvest traded for margin. **Width-3 majors disqualified:** width-3
    was highest-harvest on both GBPUSD and EURUSD surfaces but breached Gate A on
    62% of EURUSD seeds ($932 mean max DD vs $1000 limit) — gate-then-optimise
    earns its place; do not revert to width-3 on majors without re-running gates.

13. **Telemetry transport to pipshed.** Four inputs matching the live v2 contract:
    `EnableTelemetry` (default false), `TelemetryURL`, `TelemetryAPIKey` (empty in
    source and .set — operator pastes at attach; **never committed**), and
    `TelemetryIntervalSec` (60). Not validated at init; telemetry off must not
    affect trading. `Grind_TelemetryWebPost` ports `V2TelemetryWebPost` (bearer
    auth, `StringToCharArray` with explicit length, 200ms timeout fixed). HTTP -1
    logged distinctly as URL-whitelist issue. Heartbeat driven by `OnTimer` with
    `EventSetTimer(1)` at init swapping to `TelemetryIntervalSec` on first tick
    (no `WebRequest` in OnInit — MQL5 error 4014). `Print("TELEM|"...)` retained
    as journal fallback. Telemetry failure is non-fatal: log and continue.

14. **P&L and exit-microstructure telemetry (`grind_pnl.mqh`).** Heartbeat
    appends six fields at the end of the existing JSON (append-only; `instance_id`
    remains first):

    | Field | Composition / semantics |
    |-------|-------------------------|
    | `net_mtm` | Floating **inventory** readout — not realised performance, not a risk-gate input (gates run on broker equity). Sum over open positions matching `InpMagic` by exact equality: `POSITION_PROFIT + POSITION_SWAP`. `POSITION_PROFIT` is unrealised price P&L; `POSITION_SWAP` is cumulative swap. **Commission deliberately excluded:** `POSITION_COMMISSION` is deprecated in MQL5; entry commission at 0.01 lots is ~$0.03/leg (&lt;$1 across a full grid vs a $500 daily gate); and `HistorySelectByPosition` would mutate shared history-selection state also used by `grind_recon.mqh` and the deal hook — unacceptable coupling on the timer path for a sub-dollar gain. Full commission is captured in `realised_pnl_today` via `DEAL_COMMISSION`; the OPT/ALT comparison runs on that field, not `net_mtm`. |
    | `realised_pnl_today` | Net of `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION` on each completed scalp (`DEAL_ENTRY_OUT_BY` on the entry leg after CloseBy). Resets daily at the **TimeTradeServer()** day boundary — FTMO trade servers run natively on CE(S)T, so `TimeTradeServer()` handles DST natively and matches the risk-gate day boundary. No hand-rolled GMT offset; no `TimeLocal()`. |
    | `scalp_pnl_last` | Net P&L of the most recent completed scalp (same three-part composition). |
    | `exit_penetration_pips_last` | Maximum favourable excursion (pips) beyond the exit fill price within `GRIND_EXIT_PENETRATION_WINDOW_SEC` (30 s) after fill. |
    | `exit_penetration_pips_mean` | Running mean of `exit_penetration_pips_last` for the current server day. |
    | `exit_touch_revert_count` | Scalps where penetration &lt; one spread width — fills a virtual exit would have missed. |

    **Non-persistence:** `realised_pnl_today`, microstructure counters, and daily
    accumulators are **not** persisted across restarts (same as fill/scalp counters).
    A restart resets them; this preserves Gate 1 statelessness.

    **Exit microstructure derivation:** On EXT limit fill (`DEAL_ENTRY_IN`), the
    fill timestamp and exit price are queued. `Grind_ProcessPendingExitMicrostructure()`
    runs on `OnTimer` (after the 30 s window elapses), calling `CopyTicksRange` over
    `[fill_time, fill_time + 30 s]` to compute maximum favourable excursion
    statelessly. **Zero additions to OnTick** beyond CloseBy queue processing —
    the execution thread is not polluted with tick buffers or post-fill watch loops.
    Touch-and-revert uses spread width captured at fill time; penetration below one
    spread width increments `exit_touch_revert_count`.

15. **Per-layer price detail in heartbeat (`grind_heartbeat_detail.mqh`).** The
    flat heartbeat payload was sufficient for reconstruction but insufficient for
    observability — every state question last cycle (phantom layers, stale adds,
    duplicate labels) required a terminal screenshot because telemetry carried
    layer **counts** only, not prices. v2 published `layer_detail[]` with
    entry/exit prices per layer; grind now closes the same gap.

    **Append-only schema** (after `exit_touch_revert_count`; `instance_id` remains
    first). pipshed stores the payload verbatim and ignores unknown keys until the
    dashboard reads them — no ingestion-path field-set validation.

    | Field | Semantics |
    |-------|-----------|
    | `layers` | Array of open layers (long then short). Each entry: `layer_index`, `side` (`L`/`S`), `entry_price`, `exit_target`, `has_exit_order`, `has_exit_position`. Prices via `DoubleToString(price, _Digits)` — never `%f` or raw concatenation. |
    | `l0_pending_long` / `l0_pending_short` | Resting L0 straddle price, or JSON `null` when no order or order does not select. |
    | `add_pending_long` / `add_pending_short` | Resting add price, or `null` when absent. |
    | `resting_entries_long` / `resting_entries_short` | **Broker-side** count of resting pending orders with parsed comment role `ENT` on that side — enumerated via `OrdersTotal()` + `OrderGetTicket()` with magic check **before** comment parse. **Not** derived from `l0_pending_ticket` / `add_pending_ticket`; exposes EA/broker disagreement (e.g. duplicate `L01` entries invisible to the tracker). Reporting only — no halt, no reconciliation action. |

    **Tickets deliberately excluded:** order/position ticket numbers are not emitted
    because the public status endpoint would expose broker identifiers. Coverage
    flags (`has_exit_order`, `has_exit_position`) carry the diagnostic value.

    **Journal `Print` limit:** MQL5 truncates at 4096 characters. Worst case at
    cap (12 layers × 2 sides = 24 layer entries) is ~3–4 kB for the detail block;
    full heartbeat may exceed the journal line limit. `Grind_TelemetryEmitHeartbeat`
    splits into `HEARTBEAT` (scalar fields) + `HEARTBEAT_DETAIL` (layer block) when
    needed. The HTTP POST body is always the complete JSON — unaffected by Print limit.

    Tests D1–D9 in `ea/fxgrind_tests.mq5` cover layer serialisation, non-contiguous
    indices, empty arrays, null pending levels, no-ticket policy, schema append-only,
    worst-case size measurement, broker-side resting-entry count, and
    `DoubleToString` price formatting.

## Consequences

- Spec B enables trading after successful reconstruction on a valid book; invalid
  or unparseable books halt in place.
- Geometry ratified in `ea/presets/*.set` (confirmation sweep complete); EA source
  retains poisoned defaults for unattached instances. `InpAddPips` must remain
  `2.0 × width` in every preset — init asserts the relationship.
- MetaEditor GUI compile required; CLI compile not trusted in this project.
- pipshed URL must be whitelisted in terminal Options; API key entered at attach.
- `desktop_sync.ps1` / `deploy.ps1` header lists must be re-derived from fxgrind
  include graph in a separate task.

## References

- ADR-123 (place-once straddle), ADR-124 (re-centering — reserved write-up)
- ADR-126 (simulation cost model — separate branch)
- `ea/fxmatrix_v2_engine.mqh` :1396-1462 (re-center reference behaviour)
- `ea/fxgrind.mq5`, `ea/grind_*.mqh`, `ea/presets/*.set`, `ea/fxgrind_tests.mq5`
  (T1–T58 including CloseBy exit tests T45–T52, recon derivation T53–T58, P&L
  telemetry tests T40–T44, layer-detail heartbeat tests D1–D9, stale-add tests
  A1–A8, I8-boundary tests N1–N5, tracker-orphan tests O1–O3, intrinsic-index
  tests L1–L7, and I5 gap-index tests I5a–I5h)
- `ea/fxmatrix_v2_exits.mqh` :370–491 (CloseBy queue reference — read only)
