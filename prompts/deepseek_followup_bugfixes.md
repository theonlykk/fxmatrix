# DeepSeek Follow-up — Fix Four Confirmed Bugs in the Code You Already Wrote

## Context

Your prior response (attached as `SimulationEngine.md` in this prompt's
context) contained a solid critique — Brownian bridge suitability,
calibration, sub-step bias, lookahead bias — which is being kept as-is,
no changes needed there. **The code in that same document has four
confirmed bugs**, found and verified by direct testing, not just
reading. None of these are in your own "Important Caveats" section —
they're separate implementation gaps.

**Please edit the existing code directly, rather than rewriting from
scratch.** The overall structure (dataclasses, bridge generation,
LIFO exit/add logic, Monte Carlo runner) is sound and should be
preserved — only the four specific issues below need fixing.

## Bug 1 — FLIPPING mode never flips

`get_signal()` is only ever called once, at bar index 0, to set the
initial layer's direction. It is never called again anywhere in the
per-bar or per-sub-step loop. Verified directly: running FLIPPING mode
on a synthetic V-shaped path (200 pips down, then 200 pips back up —
which should trigger a signal flip under any reasonable rule) produced
exactly one signal call for the entire simulation, `[(0, 1)]`, and the
position never changed direction.

**Design constraint for the fix, established through extensive real-data
investigation this session (not a guess): the real EA (`BIAS_BOTH`) does
NOT proactively close an existing position when the signal changes.** It
only becomes eligible to flip direction once it is fully flat — i.e.,
all layers of the current position have closed via their own individual
exit targets. A position stuck in a losing trend stays in that trend
until it resolves normally; the signal changing does not force an early
close. Please implement it this way specifically: check the current
signal only when `layers` is empty, and open the new position in
whatever direction the signal indicates at that moment. Do not add logic
that closes an open position early when the signal disagrees with it —
that would not match the real system's behavior.

## Bug 2 — No re-entry after going flat

Directly related to Bug 1, but distinct: `layers.append()` only occurs
in two places — the one-time `if i == 0` initial entry, and the "add
another layer to an existing position" branch. There is no path that
reopens a position after `layers` becomes empty later in the simulation.
Once a position fully resolves, the simulation stops trading permanently
for the rest of the run, in all three modes (`BUY_ONLY`/`SELL_ONLY`
included — not just `FLIPPING`). Fix this alongside Bug 1: whenever
`layers` is empty (checked once per bar, or per sub-step — your call,
but state which and why), enter a fresh position per the current mode's
signal.

## Bug 3 — 0.4-pip spread computed but never applied

`half_spread` is calculated once at the top of `simulate_one_path` and
never referenced again anywhere in the function. Verified by searching
the full function body — exactly one occurrence, the assignment itself.
Every entry, exit, and P&L calculation currently uses the raw bridge mid-
price directly. Please actually apply it: buys should enter at
`mid + half_spread` (ask) and exit at `mid - half_spread` (bid); sells
the reverse. This should measurably reduce total P&L compared to a
zero-spread run on the same price path and seed — please include a quick
before/after comparison in your response confirming this, so we can
verify the fix took effect rather than trusting the diff alone.

## Bug 4 — Drawdown tracking is a permanent stub

`drawdown_exceeded_3pct` and `drawdown_exceeded_4pct` are declared but
never set to `True` under any code path — confirmed by direct test, they
remain `False` regardless of input. This was the specific risk question
the tool exists to answer (matching the real EA's kill-switch levels),
so this needs a real implementation, not a placeholder.

**Design constraint, from the real EA's actual mechanism:** the kill-
switch resets **daily** — `InpSoftDrawdownLimit`/`InpHardDrawdownLimit`
are checked against a `daily_start_balance` that resets each calendar
day, not against a single all-time peak equity value. Please implement
it this way: track equity (realized P&L to date + unrealized P&L on
currently open layers, marked to the current simulated price) at
whatever resolution is practical (per bar is probably sufficient — you
don't need sub-step resolution for this), determine which calendar day
each M5 bar's timestamp falls on (the actual close-price series will
have real timestamps when we supply it), reset the daily reference
balance at the start of each new day, and flag if drawdown from *that
day's* starting balance crosses 3% or 4% at any point that day. A
same-day breach should flag the run; a decline that only becomes large
after accumulating across multiple days without resetting should not.

## What we need in your response

1. Corrected code for all four fixes.
2. For each fix, a brief explanation of exactly what changed and why it
   now behaves correctly.
3. Self-verification for each fix, the same way we verified the original
   bugs — don't just assert it works:
   - Bug 1/2: re-run the V-shaped path test and show the signal/direction
     actually changing and a new position opening after the flat point.
   - Bug 3: the before/after spread P&L comparison described above.
   - Bug 4: construct a synthetic path with a known, deliberate same-day
     4%+ drawdown and confirm the flag fires; also confirm a gradual
     decline spread across many days without ever breaching 3-4% in a
     single day does *not* incorrectly flag.

Please don't present this as fixed without those four checks actually
run and shown — that's the standard we're holding all code to this
session, not a special ask of you specifically.
