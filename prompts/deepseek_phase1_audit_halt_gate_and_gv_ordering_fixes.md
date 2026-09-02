# Phase 1 Audit Request — OnTradeTransaction Halt Gate + Cap GV Publish Ordering Fixes

## Role reminder
Phase 1 Red Team submission per ARCHITECT.md. Mechanical audit only —
no full implementation code in the response. Gemini has already ruled
these two fixes should proceed as standalone ADRs; this submission is
about auditing the proposed MECHANICS of each fix before Cursor builds
either one, not re-litigating whether they should happen.

## Background
Both defects were confirmed against real source during the State
Reconstruction Engine audit (blocked/parked separately). Both exist in
today's production code, independent of that parked feature:

**Defect 1:** `g_long_halted` / `g_short_halted` gate `Long_OnTick` /
`Short_OnTick`, but `OnTradeTransaction` unconditionally calls
`Long_HandleDealFill` / `Short_HandleDealFill` regardless of halted
state. A "halted" instance (e.g. after the orphan guard trips) still
appends layers, places exit orders, and calls `EnsureAddNext` if a
fill arrives — the halt is not a real halt.

**Defect 2:** `OnInit` publishes layer-count GVs and resets
`V2GBP_CAP_TRIGGERS` / `V2EUR_CAP_TRIGGERS` unconditionally, before
the orphan scan runs. An instance that is about to halt due to real
open positions still broadcasts a confirmed-flat/zero-exposure signal
to peer instances and erases trigger history first, in the same
`OnInit` call where it discovers it isn't actually flat.

## Proposed fixes (concept level)

### Fix 1 — OnTradeTransaction halt gate
Add a check at the entry of `Long_HandleDealFill` / `Short_HandleDealFill`
(or equivalently at the top of `OnTradeTransaction` before dispatching
to each side): if that side's halted flag is true, return immediately
without modifying any layer array, without placing any order, and
without touching cap GVs. Since the fill is now fully ignored by
internal logic, add a loud log/alert (matching the existing
`system_alerts[]` style used elsewhere) so a human is notified that a
fill occurred on a halted/orphaned instance and needs manual
reconciliation — silently ignoring it would trade one silent failure
for another.

Questions for DeepSeek:
1. Does gating at `HandleDealFill`'s entry fully cover every path
   currently reachable unconditionally from `OnTradeTransaction`
   (`AppendLayer`, `PlaceExitForLayer`, `EnsureAddNext`, cap sync,
   CloseBy queuing on exit fills), or are there other reachable
   functions that need the same gate independently?
2. For an EXIT-magic fill specifically (not an entry fill) arriving
   on a halted instance — should CloseBy queuing still be attempted
   (to avoid leaving a hedge position stranded), or should this also
   be fully suppressed with just a loud alert, accepting that a human
   must close it manually? Flag which is safer given the array is
   already known-untrustworthy in the halted state.

### Fix 2 — Cap GV publish / trigger-reset ordering
Reorder `OnInit` so the orphan scan (position/state check) runs
BEFORE any `GlobalVariableSet` call for layer-count keys or trigger
keys. Only perform the zero-publish and trigger-reset if the orphan
scan confirms the instance is genuinely flat (no open positions found
matching this instance's magic). If orphan positions are found (halt
case), skip those GV writes entirely — leave whatever value was
already published from before this restart untouched, since a
stale-but-real prior count is a better estimate of current exposure
than a confirmed-wrong zero.

Questions for DeepSeek:
1. Is "skip the write entirely in the halt case, leave prior value
   standing" the right behavior, or is there a realistic scenario
   where the prior published value is itself dangerously stale (e.g.
   positions were closed manually while the instance was down),
   making "leave it alone" also produce wrong cap math? If so, is
   there a better fallback worth flagging (e.g. a separate
   "stale/unconfirmed" marker other instances could check), even
   though caps are currently at threshold 0 and this isn't yet
   trading-blocking?
2. Does reordering the orphan scan earlier in `OnInit` interact badly
   with anything currently expected to run before it (any
   initialization the orphan scan itself depends on)?

## Interaction check
Both fixes touch `OnInit` / `OnTradeTransaction` ordering in the same
three production files. Flag any interaction risk between doing both
in the same change — e.g. does Fix 1's halted-gate check need to be
set before or after Fix 2's reordered orphan scan for the sequencing
to be correct on first attach?

No implementation code in your response. Flag anything that should
block either fix from going to Cursor, or any assumption above that
doesn't hold once checked against real source.
