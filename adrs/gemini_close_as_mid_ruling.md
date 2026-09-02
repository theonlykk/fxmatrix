# Gemini Ruling Request — Close-as-Mid Approximation in Signal Layer

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** Formal blessing of close-as-mid approximation for signal
        computation

---

## Context

During Cursor's self-review of MathEngine.mqh (Prompt 2), it
flagged the following:

> "Mid from close — Signal uses M5 close as mid approximation,
>  but ADR-002 v4 Section 1 specifies mid = (Bid+Ask)/2."

ADR-002 v4 Section 1.1 states:

> "The signal layer uses mid-price throughout.
>  Mid = (Bid + Ask) / 2."

However, the signal computation uses CopyClose() to fetch
historical M5 bar data. Historical bars do not have bid/ask
prices — only OHLC. CopyClose() returns the bar close price,
which is the last traded price of that bar, not a synthetic
(Bid+Ask)/2 mid.

---

## The Practical Reality

For the signal layer log return computation:

```
r_EU = log(EURUSD_close_now / EURUSD_close_12bars_ago)
r_GB = log(GBPUSD_close_now / GBPUSD_close_12bars_ago)
```

There is no mechanism to retrieve historical bid/ask mid prices
via MQL5's standard CopyClose/CopyBid/CopyAsk functions at M5
bar resolution without building a custom tick aggregator. The
practical options are:

**Option A — Close price (current implementation)**
Use CopyClose() for all historical bar references. The close
price is a reasonable proxy for mid on liquid FX pairs where
the spread is 0.5–1 pip and the bar range is typically 10–30
pips. The error introduced is sub-pip and symmetric across
bars, so it cancels in the log return difference.

**Option B — (Bid+Ask)/2 for current bar only**
For the most recent bar (index 0 = current closed bar), use
live SymbolInfoDouble(SYMBOL_BID) and SymbolInfoDouble(SYMBOL_ASK)
to compute a true mid. For all historical bars (index 1–12),
use CopyClose(). This creates an asymmetry between the anchor
(historical close) and the current observation (live mid).

**Option C — CopyBid + CopyAsk for all bars**
MQL5 provides CopyBid() and CopyAsk() for historical bar data.
Using (CopyBid[i] + CopyAsk[i]) / 2 for all bars produces a
true mid at every point. More technically correct but adds two
additional data fetches per signal computation.

---

## Our Position: Option A — Close as mid, formally blessed

The log return signal is a relative measure — the spread S =
r_GB - r_EU. Any systematic offset introduced by using close
instead of mid cancels in the difference, since both legs are
subject to the same approximation. On EURUSD and GBPUSD with
typical spreads of 0.5–1 pip, the close-to-mid error is
0.25–0.5 pips, which is negligible relative to the 8-pip
entry threshold (EntryThreshold = 0.0008 log-return units).

Option C is more technically correct but adds complexity for
negligible benefit. Option B creates an asymmetry that is
worse than Option A.

We request formal ruling to bless Option A (close-as-mid for
all historical bar references in the signal layer) and update
ADR-002 v4 Section 1.1 to reflect this:

> "The signal layer uses mid-price convention. For historical
>  bar data fetched via CopyClose(), the bar close price is
>  used as a mid-price approximation. The error introduced is
>  sub-pip and symmetric, cancelling in the log return
>  difference. For V1 this approximation is acceptable."

---

## Ruling Requested

Confirm Option A. Authorise the ADR-002 v4 Section 1.1 language
update. Once confirmed, MathEngine.mqh is locked and we proceed
to Cursor Prompt 3 (Execution Engine).

