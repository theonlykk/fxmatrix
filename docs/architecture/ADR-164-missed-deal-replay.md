This message has a line count at the bottom

# ADR-164 -- REPLAY DEALS THE TERMINAL NEVER ANNOUNCED (C76)

Status: MERGED `main` `0335f25`, 2026-09-29 ~04:10Z (s11); deploys with C63.
Was: ACCEPTED rev 3, 2026-09-28 ~20:50Z (rev 1 ~17:15Z; rev 2 ~17:35Z
corrects D1 and adds C77; P1 PASS 17:22Z; rev 3 applies GF-1 to D6a).
Gemini's rulings and Claude's check in s8. Next: the Cursor spec. Written by Claude from
source at `main` `306e38d` (EA == `6a1e9ad`) and `5685e4f` (the live
build on the VPS and box 1). EA defect fix; nothing is built yet.
Line numbers are `main` unless marked.

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | Box 2 lost the IC trade server 16:27:29Z-16:27:34Z, 28 Sep (journal: `connection to ICMarketsSC-Demo lost`, re-authorised 16:27:33.764, `terminal synchronized ... 66 positions, 49 orders` 16:27:34.649); requests from 16:27:25 rejected "absence of network connection" | box 2 terminal journal `logs/20260928.log` | VERIFIED (operator paste) |
| A2 | Two GBPUSD_OPTC fills happened inside the gap: short L05 ENT (position 1970173871, 19:27:19 server) and long L00's EXT (position 1968639465, 19:27:22 server). The journal has NO deal line for either (the L04 fill at 16:25:35 has one) | same journal; pipshed `status_c` raw JSON 16:51Z | VERIFIED |
| A3 | Neither fill reached `fill_logs` (L04's did, id 6651); the engine never appended L05 and still held L00's exit as a resting order | archive export `--instance GRIND_GBPUSD_OPTC` 16:47Z; `status_c` JSON | VERIFIED |
| A4 | I3_SHORT_NAKED at 16:27:35.084 (0.4 s after the sync), 13 checks in 3158 ms, `QUARANTINE_HALT` 16:27:38.243 | box 2 Experts log | VERIFIED |
| A5 | The lost EXT fill raised NOTHING: the exit POSITION covers the layer for I3, and the close-by was never queued. It would have stalled that side silently | `grind_recon.mqh` 1253 (the tick check builds from the broker book), `Grind_ReconLayerHasExitCoverage` (order OR position) | VERIFIED in source |
| A6 | Repair: reattach 16:57:11Z (InpConfigWarning + " x"): `derived CloseBy pair ... L00`, `STARTUP_EXIT_SHORTFALL long=0 short=1`, L05's exit placed; both scalps closed by 16:59:00 | Experts log | VERIFIED |
| A7 | The event gate is the same on the live build: `Grind_OnTradeTransactionEngine`, `Grind_ArchiveRecordFill`, `Grind_DealSelect`, `Grind_AppendLayer` identical in effect at `5685e4f`; `Grind_HandleSideDealFill` differs only by roll telemetry and the per-side add | `git diff 5685e4f main` per function | VERIFIED |
| A8 | Nothing in the EA reads `TERMINAL_CONNECTED` | `git grep` on `ea/grind_*.mqh`, `fxgrind.mq5` | VERIFIED |
| A9 | After the resync the missed deals are in the terminal's LOCAL deal history (`HistorySelect` reaches them) | probe P1 on box 2, 17:22Z 28 Sep: deal 1583979787 (order 1970173871, IN, 1.32781, `GRIND\|OPT\|S\|L05\|ENT`) and deal 1583980820 (position 1968639465, IN, 1.32785, `GRIND\|OPT\|L\|L00\|EXT`), magic 22260101, both listed | VERIFIED (P1 PASS) |
| A10 | A successful `HistoryDealSelect` REPLACES the `HistorySelect` list with that one deal ("clears in a mql5-program the list of deals available for reference, and copies the single deal ... to go through all deals selected by HistorySelect() ... use HistoryDealGetTicket()") | MQL5 docs, HistoryDealSelect, Note; P1 on box 2 (build 6230): `total_before=26`, one select, `total_after=1` | VERIFIED (docs and live) |
| A11 | C77: `Grind_ExitQFindExitDealPosition` (engine 3047) calls `HistoryDealSelect` INSIDE its `HistorySelect` loop, so after the first deal it reads it can only match the account's newest deal in 30 days. On a miss its caller `Grind_ExitQHoldCancelLayer` (engine ~3106) zeroes the exit ticket and deletes the carry shift though the exit may have FILLED. The suite never runs the live branch (the deal-test seam takes over) | engine 3047-3100, 3106-3134 | VERIFIED in source; never observed live |

## 1. THE PROBLEM

Every change to the engine's book arrives through `OnTradeTransaction`
(`fxgrind.mq5` 457 -> `Grind_OnTradeTransactionEngine`, engine 3020 ->
`Grind_HandleSideDealFill`, engine 2560). A deal the terminal learns of
by SYNCHRONISATION after a lost connection produces no
`TRADE_TRANSACTION_DEAL_ADD`. The engine then diverges from the broker:

- a missed ENT: a position the engine does not own and whose exit is never
  placed. Under K=1/H=0 the newest layer is rank 0, so I3 sees it at once
  and halts after 3 s / 3 checks (`grind_quarantine.mqh` 13-14). Loud.
- a missed EXT: the engine keeps a resting-exit ticket for a filled exit;
  the close-by is never queued, the layer never leaves, adds stay
  anchored on it. I3 passes (the exit position covers it). SILENT.
- a missed OUT_BY (a close-by completed in the gap): the engine keeps a
  layer whose positions are gone. Recon at the next start would drop it;
  until then the side is wrong and the scalp is never reported.

Only a restart repaired it, because `Grind_ReconstructState` (recon 1281)
rebuilds from the broker book. Every fleet runs this gate today (A7).
Broker disconnects are routine; a real-money fleet must heal itself.

## 2. THE DECISION (PROPOSED)

**D1. A deal-history sweep, on the 1 s timer.** `OnTimer` already runs
every second (`EventSetTimer(1)`, `fxgrind.mq5` 359). Each call:
`HistorySelect(from, now)` with `from` = the later of the EA's init time
and the last sweep's time minus a margin (120 s); COPY the tickets of
every deal of this symbol and magic into a local array FIRST
(`HistoryDealGetTicket` + `HistoryDealGet*` only, no `HistoryDealSelect`:
A10), then, for each ticket NOT in a new SEEN set, in deal-time order:
`Grind_ArchiveRecordFill(deal)` then the SAME two
`Grind_HandleSideDealFill` calls the event path makes, then mark it seen,
then one archive marker `DEAL_REPLAYED` (deal, entry type, parsed role,
side, layer, age ms). No broker request: history is local.

**D2. SEEN is separate from PROCESSED.** The event path marks every
`DEAL_ADD` it receives as seen before anything else (the processed list,
engine 2027-2043, only holds deals a side acted on; deals no side owns
would otherwise be replayed and archived again every second).

**D3. Deals before init are never replayed.** They are already in the
book `Grind_ReconstructState` built. Defensive idempotency as well: an
ENT whose position is already a layer is skipped (no second append); an
EXT whose layer already holds that exit position is skipped.

**D4. Halted: archive only.** Same as the event path today: record the
fill, do not touch the book (engine 3033-3034).

**D5. Also sweep on the tick path when the invariant fails**, before
`Grind_QuarantineStep` (`fxgrind.mq5` 409-410), at most once a second,
then re-run the check on the same tick. The timer alone would normally
win the 3 s race; this removes the race.

**D6. Connection edge, logged only.** Track `TERMINAL_CONNECTED` in the
timer; on a false -> true edge emit `CONNECTION_RESTORED` (down seconds)
and force a sweep on the next timer call. Evidence for the log, not a
second mechanism.

**D6a. C77 in the same change (rev 3, after GF-1).**
`Grind_ExitQFindExitDealPosition` reads each deal by ticket from the
`HistorySelect` list (drop the `HistoryDealSelect` in the loop, A10/A11).
Its caller's miss branch is UNCHANGED: zero the exit ticket and delete the
shift (a genuinely cancelled order must not leave a phantom ticket; Gemini
GF-1). A fill that was only late reaches the layer anyway: the EXT branch
of `Grind_HandleSideDealFill` falls back to `Grind_FindLayerByIndex` when
the ticket is zeroed, by event or by the D1 sweep. Residual, as today: the
deleted shift can make a filled, shifted-closer exit read "adverse" for the
tick or two before its close-by (a quarantine transient). Tests: EQ-H1
(the order's deal is NOT the newest: found), EQ-H2 (miss: ticket zeroed;
a later EXT deal for that layer index re-attaches and queues the close-by).

**D7. What does NOT change:** I3, the quarantine thresholds, reconstruction
at init, the carry pass, the lattice, ejection, the processed list.

## 3. WHY NOT THE ALTERNATIVES

- **Re-run `Grind_ReconstructState` at runtime** when the book differs
  from the engine. It is what the reattach did (A6) and needs no history,
  but: it resets the side state (`Grind_ReconResetSide`, recon 277: add
  and L0 tickets, ADR-152 held adds, transitions) and the counters
  (recon 292) mid-session; it loses the missed deals' archive rows and
  scalp telemetry (C34, C56 counts short); and it is a second code path
  that owns the book. Kept as the FALLBACK if P1 shows history does not
  hold the deals.
- **Retry `HistoryDealSelect` in the event handler.** Does not help: there
  is no event.
- **Raise the quarantine thresholds.** Hides the loud case and does
  nothing for the silent one.

## 4. BOOT S4 "AN INVARIANT AND A RECONCILER MUST NEVER TARGET THE SAME CONDITION"

The sweep targets MISSED EVENTS (a deal in history the engine never saw),
not the I3 condition (a required layer without exit coverage in the
broker book). It never places or cancels anything itself: the handler it
calls does exactly what it does for a live event. After a replayed ENT
the exit is placed within one request; I3 may still enter quarantine for
that interval (the C40 transient) and releases on the next check. D5 runs
the sweep before the quarantine step so the two do not race. Gemini:
please rule on whether this satisfies the rule.

## 5. PRECONDITION -- PROBE P1 (READ-ONLY, BEFORE ANY SPEC)

A script `scripts/grind_deal_probe.mq5` on box 2 (the grind_bar_dump
pattern: no orders, no GlobalVariables, safe beside live EAs):
`HistorySelect(2026.09.28 19:25 server, 19:30 server)`, then print every
deal of GBPUSD with ticket, order, position, entry, time_msc, price and
comment. PASS: the L05 ENT deal (order 1970173871) and the L00 EXT deal
(position 1968639465) are listed, with comments that parse. If not, the
fallback of s3 is the design.
**RESULT 28 Sep 17:22Z (box 2): PASS.** Six GBPUSD deals in the window,
both missed deals among them (A9); A10 reproduced (26 -> 1).

## 6. TESTS TO WRITE (names later; tests first as always)

- DR1 an ENT deal in history, no event: the sweep appends the layer, the
  exit is placed (rank 0), a `DEAL_REPLAYED` marker, one archive row.
- DR2 an EXT deal in history, no event: the close-by is queued; the side's
  layer leaves on the OUT_BY; `scalp_closed` emitted.
- DR3 an OUT_BY pair in history with the layer still in the engine: the
  scalp completes as on the event path.
- DR4 the same deal delivered by event THEN seen by the sweep: nothing
  twice (no second append, no second archive row).
- DR5 a deal older than init: never replayed.
- DR6 halted: archived, book untouched.
- DR7 a deal of another magic or symbol: ignored.
- DR8 order: ENT then its EXT in one sweep (both missed) -> one layer
  appended then its close-by queued, in time order.
- DR9 the tick-path sweep runs before the quarantine step; a replayed ENT
  releases the quarantine without a halt.
- DR10 the sweep window: `from` never before init; margin applied.
- DR11 several deals in one sweep, the handler calling `HistoryDealSelect`
  on each: every deal is still handled (the ticket snapshot, A10).
- EQ-H1, EQ-H2 (D6a). Note: the deal-test seam hides A10; each of these
  needs a seam that models the list replacement, or the live branch is
  still untested.

## 7. FOR GEMINI

Verified claims are marked in the audit trail; A9 is inferred.
- **GQ1.** Replay through the event handler (D1) rather than a runtime
  reconstruction (s3). Accept?
- **GQ2.** A separate SEEN set (D2). Any path where a deal is seen but
  must still be handled later (e.g. `HistoryDealSelect` failing inside
  the event, the case we could not rule out on 28 Sep)? Proposal: mark
  seen only AFTER the deal was selected successfully.
- **GQ3.** `HistorySelect` is program-global state; the breaker
  (engine 1482, 1541), the exit-queue lookup (engine 3077) and the daily
  snapshot (`grind_snapshot.mqh` 270) also call it. Any caller that
  selects and then reads across a call to the sweep? (Claude reads them
  as select-then-read within one function; please confirm the rule.)
- **GQ4.** D5 re-runs the invariant on the same tick after a sweep.
  Sound, or only on the next tick?
- **GQ5.** The kill switch: BOOT s4 says a new behaviour defaults OFF
  (ADR-152 Rollout). This is a defect fix whose OFF state is today's
  silent stall. Default ON with `InpDealReplay` to turn it off, or no
  input at all?
- **GQ6.** Margin 120 s and the 1 s cadence: cost at 2,000 deals of
  history per day per account is a linear scan of the window only; any
  reason to go slower?

## 8. GEMINI'S RULINGS (28 Sep ~17:10Z) AND CLAUDE'S CHECK

His sign-off came with praise and no questions (BOOT s1: persuasive, not
necessarily correct), so each ruling was checked in source and docs.
- GQ1 ACCEPTED (replay, not runtime reconstruction). Two of his reasons
  overstate: `Grind_ReconResetCounters` resets fill and scalp COUNTS
  (recon 292-296), not daily P&L; `Grind_ReconResetSide` clears the
  ADR-152 held add (recon 282-283). Conclusion holds.
- GQ2 ACCEPTED with his condition, which is the rev-1 proposal: mark SEEN
  only after the deal was selected and read.
- **GQ3 REJECTED.** "Confirmed safe ... strict Select -> Loop/Read within
  one function" misses A10: the sweep's own loop calls the handler, which
  calls `HistoryDealSelect` (engine 2490), replacing the list mid-loop.
  Fixed in D1 (ticket snapshot). The same pattern already exists in
  `Grind_ExitQFindExitDealPosition` (A11, C77, fixed in D6a). The
  breaker (engine 1482, 1541) reads by ticket with no select: safe.
- GQ4 ACCEPTED (sweep, then re-check the invariant on the same tick).
- GQ5: his ruling is NO INPUT (always on). That departs from BOOT s4 (a
  new behaviour defaults OFF so a stale preset stays on baseline); his
  case is that OFF means the silent stall. OPERATOR TO DECIDE.
- GQ6 ACCEPTED (120 s margin, 1 s cadence).
- BOOT s4 rule: he agrees the sweep (missed events) and I3 (exit
  coverage) are different conditions.
- GF-1 (28 Sep ~20:45Z): D1's ticket snapshot ACCEPTED; D6a's "leave the
  ticket on a miss" REJECTED (a cancelled order would leave a phantom
  ticket); keep zeroing, the sweep delivers late fills. Claude's check:
  correct; the EXT branch's `Grind_FindLayerByIndex` fallback verified in
  source. GQ5 re-affirmed: no input. Cleared for the Cursor spec.
- OPERATOR (28 Sep): no input (GQ5); deploy with C63 on Thursday.

## 9. NOT IN SCOPE

C31 (a book flattened by the broker: positions gone, not missed); C18
(quarantine escalation while a retry is blocked); pipshed showing
`DEAL_REPLAYED` / `CONNECTION_RESTORED` (a pipshed item after this
lands); C42 (unparseable comments).

## 10. DELIVERY

Full route (spec, Gemini, Cursor tests first, DeepSeek: it changes what
the engine does with orders). EA code on `main` is frozen until C63
except a defect fix; this is one. Timing is the operator's call: with
the v2.2 batch after C63, or before it. C63 does not add this exposure
(box 1 has it on `5685e4f` today). Add to 07_ROADMAP's gate before real
money.

## 11. BUILT AND MERGED (29 SEP) -- WHAT SHIPPED DIFFERS FROM s2 IN THREE PLACES

Spec `docs/architecture/ADR-164-cursor-spec.md` rev 2 (`9c0217c`),
Gemini SQ1-SQ8; tests `04e665c` (2259/2350, the 91 predicted), fixes
`3a2d800`, implementation `7ff1c97` (2350/2350); DeepSeek `6e49b87`
(checked, spec s9a and HANDOFF s22); fix round 2 `aa8ca67` (2360/2368,
the 8 predicted) and `97a2cd1` (2368/2368, GBPUSD and EURUSD); merge
`0335f25`. Differences from s2:
- **Seed BEFORE reconstruction** (Gemini SQ5), not after; the handler
  guards absorb a deal reconstruction already built.
- **SEEN only when the deal was fully handled:** `Grind_ProcessDeal`
  returns false if ANY deal select failed during it (a counter in
  `Grind_DealSelect`, Gemini GB1); the event path then leaves the deal
  unseen and the sweep replays it. D2's "mark seen after a successful
  select" was not enough (DeepSeek T-2; round 1's reorder did not close
  it either).
- **Init deferred without a server time** (Gemini GB2): if the clock is 0
  at init, `REPLAY_INIT_DEFERRED` and init at the first timer call with
  one; never a window from epoch.
Also: markers `DEAL_EVENT_AFTER_REPLAY` and `DEAL_EVENT_MISSED` (spec SQ1,
SQ3). Pipshed display: backlog C80. The VPS (`5685e4f`) keeps the C76 gap
until cycle 3 ends.

Line count: 259
