This message has a line count at the bottom

# ADR-158 -- ACCOUNT DAILY-LOSS CIRCUIT BREAKER (C17)

**Status:** ACCEPTED rev 1, 2026-09-23 (operator; Gemini critique folded
in). Gates cycle 3. Operator stance: demo mode -- build the undisputed
core, watch it work, add the rest only if the demo shows the need.

---

## 1. FTMO'S RULE (ftmo.com/en/trading-objectives, 2-Step)

EQUITY (balance + open P/L +/- swaps - commissions) must never drop below
the day's limit = account BALANCE at 00:00 CE(S)T minus 5% of the Initial
Simulated Capital (a FIXED $500 on $10k). Day 1 uses the initial capital.

**Carried losses:** the anchor is BALANCE, so floating losses carried over
FTMO midnight count against the new day from its first second. Closing a
loss BEFORE midnight leaves today's equity unchanged but restores
tomorrow's full headroom -- at the cost of abandoning that inventory's
recovery. Not acted on in rev 1 beyond the pre-midnight entry halt.

## 2. DESIGN (rev 1)

1. **FTMO day from GMT.** Prague offset +1 (CET) / +2 (CEST) by the EU
   rule (last Sunday of March 01:00 UTC to last Sunday of October 01:00
   UTC). Independent of the broker's clock (FTMO's day turns at 01:00
   broker time, UTC+3).
2. **Anchor from deal history** (Gemini): balance now minus the profit +
   swap + commission + fee of EVERY deal (any type -- dividends, refunds and
   ledger adjustments move the balance too) booked since the FTMO day
   start. Deterministic, restart-proof, immune to a fill at 00:00:01.
   Exception: if the initial deposit itself falls inside the current FTMO
   day (account created mid-day), the anchor is the deposit -- FTMO's day-1
   rule; otherwise the sum would subtract the deposit and anchor at ~0.
3. **Allowance derived, not configured** (Gemini): 5% of the FIRST
   `DEAL_TYPE_BALANCE` deal (the initial deposit). No dollar input to
   fat-finger.
4. **Soft trip at 80%:** equity <= anchor - 0.8 x allowance. Checked every
   tick from account equity. **Latched** for the FTMO day via a shared
   persistent GV (`GRIND_BREAKER_TRIPPED_<day>`), so all instances agree and
   a restart does not un-trip it.
5. **On trip, every instance:** blocks new entries, cancels its resting
   entry orders once, emits `CRITICAL BREAKER_TRIPPED` once. Exits, the
   carry pass and ejection (manual and automatic) keep working.
6. **Pre-midnight entry halt** (Gemini): from 23:00 CE(S)T, while floating
   loss (balance - equity) >= 50% of the allowance, block new entries. Not
   latched; clears at FTMO midnight.
7. **One gate:** `Grind_EntriesBlocked()` = API entry stop OR breaker, at
   the five existing entry sites. Exits never pass through it.
8. `InpBreakerEnable` (default true).

## 3. EJECTION WHEN TRIPPED -- AMENDS ADR-157

FTMO measures equity, which already includes floating loss; a passive
ejection converts floating to closed at ~the same value and stops the
position floating. It REDUCES breach risk. Ejection stays available when
tripped (Gemini agreed); ADR-157's "healthy" condition no longer includes
the breaker. The stability wait is NOT loosened when tripped (Gemini).

## 4. DEFERRED (demo decides)

- A hard level (e.g. 95%): passive "eject every layer", or an emergency
  market-close path. The latter abandons the no-market-orders design and
  needs its own ADR + DeepSeek (closing positions under a running EA is
  what the invariants treat as corruption).
- Pre-midnight TRIMMING of carried loss (partial realisation).

Line count: 69
