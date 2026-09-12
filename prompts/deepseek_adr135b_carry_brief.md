This brief has a line count at the bottom; read to the end before answering.

# DEEPSEEK AUDIT BRIEF -- ADR-135b CARRY EXIT ADJUSTMENT (fxgrind)

You are auditing a DESIGN, not code. Nothing below is implemented. Find the
ways it breaks in production before we write it. This supersedes an earlier
draft; the observe phase (ADR-135a) has since shipped and changed three of
its assumptions.

## 1. THE SYSTEM

fxgrind is a passive limit-order market maker on MT5. Twelve instances (six
symbols x two geometry arms) share one FTMO demo account, separated by magic
number. It NEVER crosses the spread and NEVER uses stop losses.

Per side an instance holds a ladder of "layers". Each layer is one open
position plus exactly one resting exit limit:

- long layer:  BUY position, exit = SELL LIMIT above market
- short layer: SELL position, exit = BUY LIMIT below market
- exit price today = entry +/- exit_pips, fixed at fill time, never moved
- entry orders: L0 re-quoted toward MID every tick outside a deadband; adds
  priced from the layer anchor at add_pips spacing

Existing machinery that matters:
- `Grind_CheckBookInvariants` runs EVERY TICK. Invariant I6 requires
  |exit - (entry +/- exit_pips)| <= 2 * point or the instance HALTS. I6 is
  NOT quarantinable (ADR-128 quarantine covers I2/I3/I4 only).
- `Grind_ReconstructState` (OnInit) rebuilds layers from the broker book and
  applies the same I6 check.
- Conservative entry clamps exist: `Grind_Adr013ClampSell(theoretical, bid,
  ask, point, stops, out)` keeps a SELL LIMIT at or above ask + max(point,
  stops*point); `Grind_Adr013ClampBuy(theoretical, bid, point, stops, out)`
  keeps a BUY LIMIT at or below bid - max(point, stops*point).
- Archive (ADR-130/131/132, live): structured events flushed to Postgres
  every 2 s. `Grind_ArchiveMarker(level, code, reason, ticket, detail_json)`.
- Terminal GlobalVariables already carry state across reloads (ADR-133).
- ADR-135a (live 2026-09-11): a CARRY_SNAPSHOT ea_event per instance at
  OnInit and once per broker day, plus a PERSISTED once-per-day gate firing
  in the 23:50-23:59 broker window. It modifies no orders.

## 2. FACTS ESTABLISHED FROM LIVE DATA (do not re-derive)

- All six symbols: swap mode POINTS, 5 digits, stops level 0, weekly
  multipliers Mon1 Tue1 Wed3 Thu1 Fri1 (Sat/Sun absent), commission 2.5 USD
  per lot in+out. Pip = 10 points.
- Carry per night in pips: EURUSD long -0.876 / short +0.037; GBPUSD
  -0.434 / -0.563; EURGBP -0.706 / +0.018; AUDCAD +0.153 / -0.916; AUDCHF
  +0.271 / -1.067; CADCHF +0.098 / -0.674. Held a week, AUDCHF short costs
  -7.47 pips against a 5-pip exit target on one arm.
- Position size is 0.01 lots.

## 3. THE DESIGN TO AUDIT (all points ruled by the architect)

D1. WHEN. Once per broker day, inside 23:50-23:59 broker time (16:50-16:59
    New York, the dead minutes BEFORE the daily close), gated by a persisted
    day-of-year. Chosen over V2's post-midnight pass because a clamped exit
    at a gapped open can lock in a loss, whereas a missed fill in dead
    minutes costs a little profit.

D2. WHICH ORDERS. Adjust an order only when it is anchored to a POSITION
    BASIS that has accrued carry; never when anchored to mid.

    | State | Order | Anchor | Action |
    |---|---|---|---|
    | Long | exit sell limit | basis | ADJUST |
    | Long | add buy limit | basis | no change (deferred to a later ADR) |
    | Short | exit buy limit | basis | ADJUST |
    | Short | add sell limit | basis | no change (deferred) |
    | Flat | L0 buy limit | mid | NEVER |
    | Flat | L0 sell limit | mid | NEVER |

    The flat case is settled by reductio: applying "equivalence" to unfilled
    quotes raises the bid and lowers the offer, closing the spread by the
    sum of both carries per night and CROSSING it within days.

D3. AMOUNT (hybrid, ruled). Each pass RECOMPUTES from scratch:
      accrued_pips = pips(POSITION_SWAP for that position)      [historical]
                   + quoted_swap_points * tonight_multiplier / 10   [pending]
    POSITION_SWAP is the broker's ledger, so a mid-hold rate change or a
    missed pass is absorbed automatically. The pending term exists because
    at 23:50 tonight's charge has not yet been booked.

D4. DIRECTION (symmetric, ruled by the operator).
      new_exit = formula_exit - direction * accrued_pips
    with cost negative, credit positive, direction +1 long / -1 short.
    Worked: long at 100, exit 105, cost 2 pips -> 107. Short at 110, exit
    105, credit 0.5 -> 105.5. Long at 100, credit 0.5 -> 104.5. Short at
    110, cost 1 -> 104. Cost moves the exit AWAY from entry; credit moves it
    TOWARD entry.

D5. NEVER MARKETABLE. Any shift toward the market is clamped to stay passive
    by at least the stops level and outside the freeze level, reusing
    ClampSell for long exits and ClampBuy for short exits. Unused credit is
    simply not realised: the layer is then better than equivalent, never
    worse. Clamped passes are flagged in telemetry.

D6. SIGN GUARD (from V1). If the adjustment would move the exit to the wrong
    side of the entry (long exit at or below entry, short exit at or above),
    SKIP the modify and retain the existing exit rather than clamping.

D7. I6 TOLERANCE. The cumulative APPLIED shift per position ticket is stored
    in a terminal GlobalVariable, signed; I6 accepts
    |exit - (formula +/- stored_shift)| <= 2 * point. "Widen I6 by generous
    headroom" was rejected: it would blind I6 to wrong-layer exit overwrites,
    a defect class hit twice in the week before this brief.

D8. ELIGIBILITY. At 23:50 every currently-open layer is about to be charged,
    so eligibility is EVERY open layer of this magic. (ADR-135a shipped
    "opened before the last midnight", which is correct only for a
    post-midnight pass; live data showed EURGBP reporting 2 eligible longs
    while the arm held 5.)

D9. RETRY. A failed modify records only that position ticket for a bounded,
    timer-based same-day retry (V2 ADR-101 pattern). A successful layer is
    never retried in the same pass.

D10. TELEMETRY. CARRY_EXIT_SHIFT ea_event per shift carrying BOTH amounts --
     the ledger-derived accrued pips AND a points-native equivalent
     (rollovers crossed x quoted rate) -- plus old price, new price, clamped
     flag, skipped-by-sign-guard flag. They should agree; recording both
     lets production prove it.

## 4. THREATS / QUESTIONS (spend effort here)

T1. ACCOUNT-CURRENCY CONVERSION. POSITION_SWAP is in ACCOUNT currency; pips
    are quote currency. Write the exact formula using SYMBOL_TRADE_TICK_VALUE
    / SYMBOL_TRADE_TICK_SIZE and volume, for: EURUSD (quote = account),
    GBPUSD, EURGBP (quote != account), AUDCAD / AUDCHF / CADCHF (crosses on a
    USD account, where tick value floats with a third rate). Identify every
    division and its zero/stale guard. What is read at 23:50 on a thin
    pre-close book if tick value is 0 or stale? NOTE: converting a
    historical accrued amount with TODAY's tick value introduces a small FX
    delta -- quantify whether it matters at 0.01 lots.

T2. LEDGER GRANULARITY. At 0.01 lots one EURUSD pip is about 0.10 USD. If
    the broker books swap rounded to cents, quantisation is about 0.1 pip
    against a 0.876 pip nightly charge. Does that break the hybrid, and
    should the design prefer the points-native figure when the two disagree
    by more than a threshold?

T3. GLOBALVARIABLE LIFECYCLE. When is the per-position shift record created,
    updated and DELETED? Scalps close constantly; a leak means thousands of
    stale GVs (MT5 keeps unused ones about 4 weeks). Cover: normal close,
    CloseBy (both tickets), manual operator close, EA removed with layers
    open, terminal killed mid-pass, and a position closing between the read
    and the modify.

T4. I6 BYPASS SAFETY. With D7, which wrong-exit defects can now pass I6 that
    would previously have halted -- a stray exit written to the wrong layer,
    an exit adopted at reconstruction, a shift applied twice, a GV lost or
    corrupted? Is the 2-point window around (formula + stored_shift) still
    tight enough? Would you bound the stored shift by something independently
    verifiable?

T5. CLAMP AND SIGN GUARD. Confirm sides: long exit = SELL LIMIT clamped
    against ask + min distance; short exit = BUY LIMIT clamped against
    bid - min distance. Spreads widen into the close: if the equivalent
    price is already inside the clamp, should the pass place at the clamp,
    skip, or defer to retry? Does the freeze level need separate handling
    from the stops level? Can D5 and D6 ever disagree?

T6. SESSION DETECTION. ADR-135a proved SYMBOL_TRADE_MODE is NOT a market-open
    check: it read "tradeable" with the market closed. Also, TimeCurrent()
    returns the last QUOTE time, so the clock FREEZES at weekends (a Saturday
    snapshot reported Friday's multiplier). What is the correct, robust test
    that the session is open and quotes are live before sending a modify?

T7. DOUBLE-APPLY AND ORDERING. The pass modifies exits while the engine runs
    every tick. What if an exit FILLS during the pass, if reconstruction runs
    right after (a reload at 23:55), or if the pass runs twice in one day? Is
    recomputing from accrued swap genuinely idempotent?

T8. MISSED DAYS AND OUTAGES. The EA may be offline at 23:50 (V2 deferred this
    as "Design B"). With D3 recomputing from the ledger, is a missed day
    self-healing at the next pass? Does anything need to run outside the
    window to catch up after a multi-day outage?

T9. FTMO BUDGET AND LATENCY. Each shift is one MODIFY. Worst case is every
    open layer across twelve instances in the same minute, against a shared
    2000 request/day budget (about 1200/day used). Sends have been observed
    at 100-200 ms and once at 52 s. Is a stagger needed, and what should the
    pass do if it cannot finish inside the 10-minute window?

T10. ANYTHING WE HAVE NOT ASKED. If there is a failure mode outside T1-T9
     that would halt an instance or corrupt the book, say so plainly.

## 5. WHAT WE WANT BACK

For each of T1-T10: verdict (UPHOLD / AMEND / REJECT), the reasoning, and
where you AMEND, the concrete replacement rule, specific enough to implement
without further interpretation. If a threat is a non-issue, say so in one
line and move on. Do not pad.

Do NOT write MQL5 code. Do NOT redesign settled scope: exits-only, symmetric,
pre-close window, and the hybrid amount are decided.

Line count: 198
