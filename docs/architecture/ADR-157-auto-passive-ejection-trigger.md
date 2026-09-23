This message has a line count at the bottom

# ADR-157 -- AUTOMATIC PASSIVE EJECTION TRIGGER

**Status:** ACCEPTED rev 1, 2026-09-23 (operator; Gemini critique folded
in). Builds on ADR-155 (mechanism, `95c89c6`, C15). Behind `InpAutoEject`,
default false. Operator stance: ship a clear rule, learn from the demo's
edge cases, adjust -- no analysis paralysis.

---

## 1. PURPOSE

A capped side has stopped working: it cannot add, so it cannot scalp near
the market; it only holds inventory. The EA now decides WHEN to move the
DEEPEST layer's resting exit to the best passive price (the ADR-155
mechanism), freeing the slot so the ladder keeps trading where price is.

**Constraints (operator):**
- Do not eject into a spike: that realises the loss at the worst price and
  strands the reload (the re-quoted layer-8 add sits at the spike low;
  price snaps back; it never fills).
- Fire on STABILITY; do not WAIT for a bounce.
- **No arbitrary barriers.** No fixed pip depth (random across pairs), no
  multiple of add (at cap 8 the deepest is ~7 x add from the newest entry
  by definition; it only bites in a choppy market, when sitting on our
  hands is exactly wrong), no 24-hour waits. Do not reintroduce them.

## 2. THE TRIGGER

Per side, each tick, fire when ALL hold:

1. **At cap:** depth == `InpMaxLayers`.
2. **Stable (S1, no new extreme):** over the last `2W` minutes the
   extreme -- lowest BID for a capped long, highest ASK for a capped short
   -- was set at least `W` minutes ago (`W` = `InpAutoEjectStableMinutes`,
   default **5**). Ties: the MOST RECENT occurrence counts, so a retest of
   the low is a new low. Stateless: computed from M1 bars.
3. **Spread normal (S3):** current spread <= `k` x the mean spread of the
   last 60 M1 bars (`k` = `InpAutoEjectSpreadMult`, default **1.5**). No
   baseline -> no fire. Blocks rollover and news.
4. **Not pending, or orphaned:** the deepest layer is not already ejected
   -- OR it is, and the new target is WORSE than its resting price by at
   least the min passive distance (a long exit lower; a short exit higher).
   Stability re-established at a new level trails the orphaned exit.
5. **Healthy:** not halted, not quarantined; when C17 exists, its breaker
   has not tripped (ejection realises losses; the breaker counts them).
6. `InpAutoEject` true.

Both sides may fire on the same tick (independent state and orders).

**No dwell timer** (Gemini, accepted): a side caps because price just made
a new extreme, so S1 already imposes at least `W` quiet minutes. The
operator's 5-minute brake lives in `W`.

## 3. ACTION

The SAME accept path as the operator command: `Grind_EjectPollCommand`'s
accept branch becomes `Grind_EjectAcceptLayer`, shared by both. Validation,
state-after-modify, carry and offset rules and telemetry are identical;
telemetry gains `"source":"auto"|"command"`.

## 4. DATA

M1 bars are built on BID: bar lows give bid lows directly. A capped short
needs ASK highs: bar high + that bar's spread (points). Spread baseline from
the bars' spread field.

## 5. CONSEQUENCES

- **Rolling in a trend:** cap -> stable -> eject -> fill (loss realised) ->
  re-add near market -> cap -> ... That is the intended flow-trader
  behaviour; C17 bounds a bad day.
- **Stair-steps** (drop, quiet W minutes, drop) eject during the pause.
  Accepted: no non-predictive rule avoids it (Gemini).
- API cost: at most one modify per side per stable window, plus
  re-ejections in a slow slide -- negligible.

## 6. EXPECTED TO NEED TUNING

`W`, `k`, and the tie rule are the dials. The demo will show the bad edge
cases; adjust by preset, not by rebuild.

Line count: 84
