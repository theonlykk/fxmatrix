This message has a line count at the bottom

# INTERIM NOTE 2026-09-16 -- CARD STATE MODEL, ANCHOR ARITHMETIC, RECONCILIATION

Continues `INTERIM_2026-09-15b-secondment.md`. Design conversation only.
Nothing ratified, no code in the repo yet. A working mockup exists at
`tools/ladder.html` (single file, no network calls) seeded from the live
book at 2026-09-16T01:12:25Z.

One ruling from your last memorandum is superseded by section 2. Everything
else is new.

---

## 1. THE TWO SCREENS ARE DIFFERENT PROBLEMS

Recorded because we conflated them for several exchanges.

**The bank's terminal is where speed matters.** It places the orders. In a
spike you are keying levels in as fast as you can read them.

**The web page places nothing.** It is a record and a prompt. There is
nothing to be fast about on it. Its job is to have ALREADY told you where the
next levels are, before the spike, so you can key them without computing
anything.

Consequence: the page shows the next THREE unposted levels as faint
projections, not just the next one. A fast market never surprises you -- you
glance once, you know the next three prices. The gap between "calculated"
and "confirmed working" is your to-do list, and in a fast market it is
EXPECTED to be non-empty rather than a defect.

An earlier proposal for a "fast add button" on the page was withdrawn. It
was solving for speed on the wrong screen.

---

## 2. THE ADD GATE -- SUPERSEDES LEVEL-TRIGGERED ADDS

Your 2026-09-15 ruling approved Route A: the add fires when the price LEVEL
is reached, regardless of size filled. That is right against the stall case
it was defending, but it is wrong in one window, and the operator's argument
is decisive:

**A resting residual at a better price cannot be skipped.** If 0.1 is still
working at 1.34665, the market cannot reach 1.34565 without trading through
1.34665 first. Posting the next add while a residual rests above it is
placing an order behind an order that must fill first.

**Revised gate: post the next add when the level is RESOLVED -- filled or
cancelled -- not when size completes.**

This is not the stall case. The operator holds the cancel, so a residual is
only outstanding while he chooses to leave it there. Cancel it and the add
goes up immediately. Your ruling and this one agree whenever the residual is
resolved promptly; they differ only while one is deliberately left working,
and the residual rule is correct in that window.

Note the operator's reason for LEAVING a residual working: a partial fill is
weak evidence the level is contested rather than through, and the 0.9 fill
plus its exit already defines a range he wants to trade. Cancelling is a
decision with consequences -- the level is then permanently capped at 0.9 --
and should be logged as a deliberate act.

### The four prompts, all card-triggered, none price-triggered

    entry fills               -> post exit for the filled size
    residual fills later      -> TOP UP the existing exit, same level
    level resolved            -> post the next add
    exit partially fills      -> nothing; the remainder is already working

That last one matters. A partially filled exit leaves the remainder resting
at the broker; nothing was amended. The tool must show it as STILL CONFIRMED
WORKING, not revert it to calculated -- otherwise it sends the operator to
the terminal for nothing.

---

## 3. ANCHOR ARITHMETIC -- REALISED LEVELS ARE NOT ON A GRID

The property the whole design rests on, stated precisely:

**Every level is `actual_fill_price +/- offset`. Never
`computed_level +/- offset`.**

If L04 was due at 1.34765 and filled at 1.34761, its exit is 1.34831 and
L05's entry is 1.34661 -- four points off the paper grid, and correct.

So the spacing between REALISED layers is whatever the market gave, not 6 or
10 pips. Only the unfilled projections ahead sit on a regular grid, because
there is no fill to anchor them to yet. The moment one fills it becomes the
anchor and everything below recomputes.

**Drift accumulates deliberately.** Each layer anchors on the one above, so
slippage compounds down the ladder. Six layers at a point each puts L06 six
points from a paper grid. The EA does exactly this -- see section 5.

**Therefore "is this order at the right price" can only be answered against
the FILL LIST, never against a grid.**

---

## 4. EDITING AND REPAIR

The terminal's blotter is the book of record for FILLS. The tool is the only
record of INTENT -- which layer a fill belongs to, and which exit pairs with
which entry. Neither can replace the other.

So the fill list must be editable, with three rules:

  1. **Edit fills, never derived levels.** Editing a derived price directly
     would put the tool in a state its own arithmetic cannot reproduce.
  2. **Deletion is a recorded event, not an erasure.** "deleted L05 fill 1.0
     @ 1.34765, corrected against blotter" is what you need at 16:00 when
     the numbers do not tie. A vanished row is indistinguishable from one
     never entered.
  3. **Any edit to a book clears every confirmed tick in that book.** The
     tick asserts a specific price is live in the terminal. If a fill
     changed, derived levels below it may have moved, so the assertion is no
     longer trustworthy. Better to re-walk them than leave stale ones
     standing.

Worked example the operator raised: believed L04, L05 and L06 were done, but
only L04 and L06 actually traded. Delete the L05 fill; L06 re-derives from
L04's anchor -- which is the correct answer, because that is where the EA
would have anchored it. If the recorded L06 fill no longer sits at a derived
level, THAT MISMATCH IS THE USEFUL OUTPUT: either the layer index is wrong
or the blotter shows slippage.

This argues for a repair MODE rather than inline editing: pick a book, see
the fill list as a plain table, correct against the blotter, and on exit the
tool shows derived-versus-last-confirmed as a diff -- what to place, what to
pull. Same view you want after a spike when you are several events behind.

---

## 5. VALIDATION AGAINST THE LIVE EA

The mockup derives every level from fill prices alone, with no market data
and no seeded targets. Checked against what the EA actually has resting at
2026-09-16T01:12Z:

    GBPUSD OPT long  deepest 1.34665 -> derived add 1.34565  EA 1.34565
    EURGBP ALT long  deepest 0.85603 -> derived add 0.85543  EA 0.85543
    EURUSD OPT long  deepest 1.15373 -> derived add 1.15233  EA 1.15233
    GBPUSD OPT L00   1.35169 + 7     -> derived exit 1.35239 EA 1.35239

Every book matches to the point except one: AUDCAD OPT short, deepest
0.99203, derived 0.99303, EA has 0.99304. One point. Most likely the ADR-013
stops-level clamp adjusting the price at placement.

**That single divergence is the argument for the reconciler's invariant
being "at or better than derived", not exact equality.** Exact equality
would flag a broker-side clamp as a defect. The weaker invariant catches
real errors and tolerates the broker doing broker things. It is also the
same invariant the ceiling rule needs, so the two agree.

---

## 6. RECONCILIATION WITHOUT SHARING TRADE DATA

The operator must not export firm positions or trade detail. He believes he
can share NET POSITION PER BOOK -- a lot count per currency per book, four
numbers per pair, no prices, no times.

That is sufficient as a CHECKSUM and insufficient as a RECORD:

  - "GBPUSD OPT 6L" gives depth, not anchors. It cannot tell you where the
    six exits go, and the exits are what must be worked.
  - In the ideal case two numbers per book -- anchor and depth -- would
    reconstruct everything, because the ladder is deterministic. Slippage
    and partials break that: each layer's anchor is its own fill price.

**Division of labour:** the tool holds the fill list (higher fidelity, never
leaves the machine, per your client-side-only ruling). The terminal's net
position per book is the daily checksum. Compare implied depth against
terminal net lots, per book. Agreement means the record is intact;
disagreement names the book to investigate.

Forty-eight integers for a twelve-pair fleet. A five-minute end-of-day
ritual, not a constant display.

---

## 7. THE RESTING BOOK MEASURES THE MARKET

Falls out of section 3 and is free.

Every unfilled resting order is a bound. Take the highest unfilled buy and
the lowest unfilled sell across all books of a pair:

    GBPUSD, 2026-09-16T01:12Z
      highest unfilled buy   1.34623  (OPT short L00 exit)
      lowest  unfilled sell  1.34735  (OPT long  L05 exit)
      => market is inside 1.34623 / 1.34735, an 11-pip window

Cross-check from reported P&L: L05 long at 1.34665 showing +0.14 puts bid
near 1.34679; short L00 at 1.34693 showing +0.04 puts ask near 1.34689. Both
inside the bracket.

The ALT arm contributed nothing -- its bracket, 1.34605 / 1.34793, is wider
on both edges. **This is structural: the tighter-exit arm always binds**,
because exits sit closest to market. Under the barbell, where arms differ in
WIDTH as well as exit, that stops being reliable and the tool would need to
say which book the bound came from.

The window narrows every time anything fills and widens only as price leaves
your orders. **So the strategy does not merely need no price feed -- the
resting book IS a continuously updating measurement of the market.**

The mockup now renders this as a market band aligned across all four books
of a pair, with columns padded so the band sits at the same height in each.

---

## 8. OPEN

  - screen grab of the bank terminal, to build a mock beside the ladder and
    rehearse the two-screen loop. Key unknowns: does their blotter expose an
    order ID (pairing is trivial) or must pairing be by price and time
    (harder); are resting orders and fills in one view; is there any export.
  - whether clicking the CARD should replace the action buttons. The card is
    what the operator reacts to; the buttons are indirection. Trade-off is
    mis-click cost, since "I have placed this" would be a single click with
    no dialog.
  - session measurement (`--session` spec) still unwritten, deprioritised by
    the operator. `fill_logs` has no retention policy, so the sample grows
    on its own -- see the 2026-09-15 corrections.

Line count: 230
