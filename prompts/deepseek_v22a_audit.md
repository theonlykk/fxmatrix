This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM v2.2a: C93 RECON SCAN RACE + C100 API LIMIT INPUTS

You are auditing a feature branch (`v22a-recon-api`) BEFORE it merges to
`main`. It is tested on GBPUSD and EURUSD: tests against stubs
(`2b23dcf`) 2475/2508, failing exactly the 33 predicted; the
implementation (`24b886d`) 2508/2508 on both. Find what tests cannot
see. The attached files carry NO line numbers: cite `file`, `function`
and QUOTE the line (one line, or part of one). A claim without a quote
is discarded. The attached spec (`cursor_v22a_c93_c100.md`) gives the
audit trail, the design, the tests and the rulings (s9).

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side),
nine to eleven instances per terminal, one symbol and magic each, all
sharing the account's ONE position list and ONE order list. Every tick
each instance rebuilds its book from the broker lists
(`Grind_ReconCollectBrokerTickets` -> `Grind_RebuildBookFromTickets`) and
checks invariants; a failure either quarantines (ADR-128: 3 s and 3
checks, then halt) or halts at once, by `Grind_IsQuarantinableReason`.
A halt cancels the instance's entry orders and stops it until a restart.

**The incident (C93):** FTMO, 1 Oct, AUDNZD halted `AMBIGUOUS_ADD_LONG`
(not quarantinable). The terminal Journal shows ONE resting L08 order;
the halt's ticket list held it twice. The collector walks
`OrdersTotal()-1 .. 0` with `OrderGetTicket(i)` while other EAs on the
account remove orders: a removal below index i shifts the list down and
the next index re-reads an order already counted (DUPLICATE); a removal
above i, or an insertion, can skip one (SKIP).

**This branch:**
- C93: `Grind_ReconAppendUnique` drops an entry whose ticket AND kind are
  already collected (counted in `dupes_io`). The collector reads
  `PositionsTotal()` / `OrdersTotal()` before and after each walk and
  repeats the walk while either changed, at most
  `GRIND_RECON_SCAN_MAX_WALKS` (3); the LAST walk is returned. A dropped
  duplicate or more than one walk raises a `RECON_SCAN_RACE` WARN marker
  and a `GRIND_RECON_SCAN` log line (counts only). On a recon failure,
  `Grind_ReconFailureCapture` prints ONE local Experts log line
  `RECON_TICKETS` with the ticket numbers, only when it differs from the
  last one printed; `Grind_ReconFailureClear` resets that memory.
- C100: inputs `InpApiEntryStop` (1000000) and `InpApiSoftWarn` (999000)
  replace two compiled constants (held in globals defaulting to the
  defines). `Grind_ApiLimitsApplyInputs` at init: valid -> set; invalid
  (either < 1, or soft > stop) -> keep the defines, return false, and
  `OnInit` raises an `API_LIMITS_INVALID` WARN later. Each chart then
  publishes the limits in force to two terminal Global Variables
  (`Grind_ApiLimitsPublishAndCheck`): if both exist and differ from its
  own, an `API_LIMITS_MISMATCH` WARN; then it overwrites them.

**Ruled -- do not re-open:** ticket numbers stay out of the failure
JSON, the heartbeat and the archive (ADR-125; the status endpoint is
public; GV-1); stability is a COUNT check, not a ticket-set comparison
(a same-count swap within one walk is accepted: GV-2); after three
unstable walks the last one is used with `"stable":false` (GV-3);
`AMBIGUOUS_*` stays an immediate halt (GV-4); NO API limit value or
mismatch may halt, fail init, unload or block anything: warnings only
(operator, 3 Oct: "api limits are not a hard line"; GV-5, GV-8); the
mismatch check is non-atomic, last init wins (GV-7). The other list
walks that only count (slots, exposure, heartbeat book) share the race
and are out of scope.

**Deployment:** not merged before Mon 5 Oct's build; then on the IC demo
fleets (three terminals, nine instances each) with a later reload; FTMO
later.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. With no list change during the walk and no duplicate, the
  collector returns the same entries, fields and order as before this
  branch, and raises no marker.
- G2. The collector's two callers (`Grind_CheckBookInvariants`,
  `Grind_ReconstructState`) and every existing signature are unchanged.
- G3. No ticket number reaches `g_grind_recon_failure_json`, the
  heartbeat or any archive marker: `RECON_SCAN_RACE` carries counts only,
  the API markers carry limits only.
- G4. With the default inputs the limits in force equal the old
  constants (1000000 / 999000), and no path added by this branch returns
  `INIT_FAILED`, halts, quarantines or blocks an entry for an API limit.
- G5. `Grind_IsQuarantinableReason` is unchanged: `I2_*_EXIT_DUP`,
  `I3_*_NAKED`, `I4_*_ORPHAN_EXIT` and `I6_*_EXIT_FILL_ADVERSE` quarantine;
  everything else (including `AMBIGUOUS_*`) halts.
- G6. The collector runs on every tick of every instance while not
  halted (through `Grind_CheckBookInvariants`) and once at init.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 The dedupe key.** Key = ticket AND kind, because a position's
  `POSITION_IDENTIFIER` equals the ticket of the order that opened it.
  Any real case where two DISTINCT broker entries share ticket and kind
  (so a real second order or position is dropped and a true
  `AMBIGUOUS_*` or I-failure is hidden), or where the same entry appears
  under both kinds and is now counted twice (it was before too)?
- **T-2 What a SKIP can still cause.** A skip inside a walk whose counts
  match (a same-count swap) is accepted (GV-2). List every reason a
  single skipped entry can produce in `Grind_RebuildBookFromTickets`
  (skipped position, skipped exit order, skipped entry order, skipped
  L0). Is any of them NOT quarantinable, so that one tick's skip still
  halts at once, as the duplicate did?
- **T-3 Marker and log volume.** `RECON_SCAN_RACE` and its Print fire on
  EVERY raced walk, on every tick, on every instance, with no throttle.
  On a busy terminal (nine instances modifying and placing; FOMC-like
  bursts), how often can a walk race? The archive queue holds 5000 rows
  per instance and an archive batch answered 400 is dropped. Is an
  unthrottled WARN here a risk to the archive or the telemetry, and what
  is the smallest bound (once per N seconds, or a count in the
  heartbeat)?
- **T-4 The walk loop.** `count` and the array are reset per walk;
  `dupes_total` accumulates over walks; the totals are read before and
  after each walk. Any path where the returned `count` and the array
  disagree, a stale entry survives from an earlier walk, or `stable` is
  reported wrongly? Cost: up to three walks per tick per instance.
- **T-5 RECON_TICKETS.** Printed on change only; the memory is reset by
  `Grind_ReconFailureClear`, which the rebuild calls on success. A
  failure that alternates with success prints every time. Any path where
  the line is built from a different list than the JSON (order, count,
  truncation at 40), or where `%I64u` misprints a `ulong` ticket?
- **T-6 The API limit inputs.** `Grind_ApiLimitsApplyInputs` runs in
  `OnInit` before the magic lock; globals versus a reason-5 re-init; the
  `(int)` cast of `GlobalVariableGet`; the two Global Variables persist on
  the terminal (and the suite deletes them, desktop only). Any path where
  the limits in force differ from what `GRIND_API_LIMITS` /
  `API_LIMITS_CONFIG` report, or where the WARN markers are emitted
  before the archive can take them?
- **T-7 Tests.** The collector itself is not unit-tested (it reads the
  live lists); its parts are. Which behaviour has no test that fails
  without it? Any assertion in `fxgrind_tests_v22a.mqh` that passes
  vacuously (left-over Global Variables or globals from an earlier test,
  a reset that does not clear what it should)? What is the smallest seam
  that would let a test drive the walk loop with a list that changes
  mid-walk?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G6), `T-1` ... `T-7`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` after the Monday build and to
deploy on the IC fleets), `TEST GAPS`. No preamble. Do not call anything
fatal that has a fix: give the smallest fix. If you assume a value (an
MT5 behaviour, an order of events), say ASSUMED and why.

Line count: 143
