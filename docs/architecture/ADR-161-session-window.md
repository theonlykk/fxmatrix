This message has a line count at the bottom

# ADR-161 -- ENTRY SESSION WINDOW (FLEET B PHASE 1, C37)

**Status:** ACCEPTED and MERGED, default OFF (merge `25a5f93`, tested at
`238bb66`: suite 1830/1830 on GBPUSD and EURUSD; EA and tests compile
0/0 on the desktop). NOT deployed: it runs only on Fleet B, from the
Phase 1 switch (`docs/architecture/fleet-b.md` s2). Cycle 3 (VPS,
`vps-a01a5d4`) is untouched; a later cycle-3 build carries it inert.

## 1. THE RULE

Operator, 2026-09-24: "outside those hours we can only keep exit orders
alive - no add orders". With `InpSessionEnable = true`: new entries (the
L0 straddle AND adds) only **07:00-16:55 Toronto time, Monday-Friday**
(local date; North American DST). Outside the window this instance's
resting entries are cancelled; exits, the carry pass, CloseBy and
ejection keep running. A flat instance therefore quotes nothing
overnight; at 07:00 the ordinary tick path places a fresh straddle at the
current mid and the next add on any side with depth.

## 2. DESIGN (full spec: `prompts/cursor_adr161_session_window.md`)

- Clock, pure (`grind_pure.mqh`): `Grind_NthSundayMonthUtc`,
  `Grind_TorontoUtcOffset` (-4 from the 2nd Sunday of March 07:00Z to the
  1st Sunday of November 06:00Z, else -5), `Grind_SessionOpenAt`
  (constants 25200 / 60900 local seconds). `TimeGMT()`, never broker time.
- Block: `Grind_SessionBlocksEntries()` (enabled AND closed) is ORed into
  `Grind_EntriesBlocked()`, which guards all five entry sites.
  Independent of `InpBreakerEnable`; its own state, not the breaker's
  cancel latch.
- Step (`Grind_SessionStep`, called in `OnInit`, `OnTimer` every second
  and `OnTick`): on the transition to closed, archive `SESSION_CLOSE`
  (`utc_offset`, `resting_ent`) and cancel own entries; while closed,
  retry only on ticks (a tick proves the market is open), at most every
  10 s; after 300 s with entries still resting, archive WARN
  `SESSION_CANCEL_STUCK` once; on reopening archive `SESSION_OPEN`.
- `OnInit` prints `GRIND_SESSION enable=<b> toronto_utc_offset=<n>
  open_now=<b>`: the operator's clock check on the box.

## 3. RULINGS (Gemini, 2026-09-24) AND OUR VERIFICATION

All five accepted, no changes. Gemini's first reply had no line-count
footer; his second declared 11 lines against 13 as pasted (matches only
without the footer and the blank before it).

- **G1 -- close at 16:55, not 17:00** (Claude's proposal against the
  pre-registered 17:00). 17:00 Toronto is the FX rollover; a cancel sent
  into a broker pause fails, and on a Friday the entries would rest into
  the Sunday gap. Adopted. His claim that IC Markets halts trading
  23:59-00:01 server time is UNSOURCED; the rule does not depend on it.
  To check on the box: Market Watch, symbol, Specification, sessions.
  **VERIFIED 2026-09-24:** trade 00:01-23:59 server Mon-Thu, Fri to
  23:57 (GBPUSD and AUDCHF): a 2-minute pause at 17:00 Toronto and a
  16:57 Friday close. 16:55 leaves 2 minutes on Fridays.
- **G2 -- cancel until none, tick-only retries** (replacing C37's "cancel
  once"). Adopted.
- **G3 -- flat L0 cancelled too.** Adopted. The operator's words cover
  adds; the "no L0" restatement drew no objection but was not explicitly
  confirmed (flagged J1 in the spec).
- **G4 -- local Mon-Fri, no holiday calendar, constants.** Adopted. Gap
  he missed: brokers often close early on 24 and 31 Dec; if before
  16:55 Toronto, those entries rest over the holiday (C43).
- **G5 -- merge to `main`, default OFF** (BOOT s4, fail closed).
  Adopted. His reason overstates: cycle 3 does NOT run the same binary
  now; only a future VPS build would carry this code, inert.

## 4. IMPLEMENTATION RECORD

Cursor, branch `adr161-session`: stub `68eeb83`, implementation
`238bb66`. Verified in git by Claude before any run: stub
behaviour-neutral, real commit matches the spec, only the four EA files
touched. Cursor deviations:
- The stub `Grind_TorontoUtcOffset` returned -5, not 0, so five SW2
  assertions (the -5 cases) passed against the stub. Accepted (still
  neutral; the -4 cases catch a constant offset); prediction revised
  from 47 to 42 failures before the run.
- SW4 skipped the breaker save and harness reset; harmless (it failed
  against the stub as predicted).
- `AssertEqInt` used before its definition; MQL5 compiled it 0/0.

Runs by the operator: stub `SUMMARY: 1788/1830` on GBPUSD and EURUSD,
failing exactly the 42 predicted names (compared mechanically); real
`SUMMARY: 1830/1830` on both.

Harness defect found while writing the tests: the order-test path of
`Grind_CancelOwnEntryOrders` walks the records forwards while removing,
so it skips the record after each one removed (the live path walks
backwards). SW6 orders its book around it; not fixed (C41).

## 5. DEEPSEEK R1 AUDIT (`prompts/deepseek_adr161_audit_response.md`)

Inputs `41298ef`, response `de17bc3` (416 lines, 109,168 chars). It
concluded "not safe to merge"; every finding checked in source:
- G1-G5 CONFIRMED. T-1 (unwind untouched, EXT never cancelled), T-4
  (clock) and T-8 (OFF is inert in order traffic; the init Print is
  the specified clock check) HOLD.
- **T-5 REJECTED** (reinit while closed skips the cancel). If globals
  persist across an input or chart reinit, the state carried over is
  correct (already closed, entries already cancelled; no new closure to
  archive); a recompile or reattach resets them and takes the
  transition path. Enabling the input while closed is a transition,
  because the disabled path forces `closed = false` every step.
- **T-2 BOUNDED.** A fill in the gap between 16:55:00 and the next timer
  step (at most ~1 s) can place one add; that step is the transition and
  cancels it. `Grind_TryRecenterOppositeL0` modifies an existing L0 only
  (it returns while `l0_pending_ticket == 0`), so it needs a stuck L0
  first and cannot create an order.
- **T-3 PRE-EXISTING.** An ENT whose comment the broker rewrites, or an
  overlong comment (`GrindCommentBuild` prints FATAL yet still places),
  is invisible to cancel and count. Reconstruction depends on the same
  parse; Fleet B comments are ~19 of 31 chars (C42).
- **T-6 / T-7 BOUNDED.** A stuck cancel retries once per 10 s only while
  ticks arrive AND the broker keeps rejecting (worst case ~3,240 per
  instance, Sunday open to Monday 07:00); the WARN fires at 5 min; an
  entry that survives to 07:00 behaves as today's overnight baseline.
- Optional hardening, not required (C44): call the step at the top of
  `OnTradeTransaction`; cancel leftover entries on the open transition;
  cap retries per closure.

## 6. DEPLOY (Fleet B only, operator's call)

**Superseded 2026-09-24 evening:** the window deploys on **Fleet C** (a
second Vultr box, a new IC Markets Raw $10k demo), attached with
`InpSessionEnable=true` from the first attach; Fleet B takes the geometry
dials instead. The steps below apply to Fleet C's box.

Phase 0 runs about two days first (operator). Plan: at the weekend,
while the market is closed, on the box: `git pull --ff-only` of `main`,
copy into Experts and Scripts (`06_LINUX_WINE_BOX.md` s7), compile 0/0,
run the suite, set `InpSessionEnable=true` in the eleven `presets_b`
files (a separate docs-and-presets commit), reattach reading the input
back, then read each `GRIND_SESSION` line (expect offset -4 until 1 Nov,
`open_now=false` at the weekend). Record the switch time in fleet-b.md
s5. First live check: Monday 16:55 Toronto, eleven `SESSION_CLOSE`
markers and no resting ENT.

Line count: 138
