This message has a line count at the bottom

# ROADMAP -- WHERE fxgrind IS GOING

Longer-horizon direction. **Nothing here is ratified** unless it says so.
This file is for intent that outlives a handoff; per-session work lives in
`handoffs/HANDOFF_<date>.md` and current state in `01_BOOT.md`. It sits in
the Handover folder so a new chat sees the direction, not just the state.

Written 2026-09-20 from the operator's stated vision. Revisit when a
horizon item becomes a live decision.

---

## 1. THE SHAPE OF THE PROBLEM

Two limits are per ACCOUNT, not per strategy:

- **200 positions + orders.** The commitment guard stops entries at 194.
  On 2026-09-18 the book sat at 195 with 16 instances at 0.01 lots.
- **The broker API budget.** 2,000 requests/day on this demo. It is the
  reason partial fills cannot be handled richly, and the reason the fleet
  cannot simply quote more.

**Neither is relieved by a bigger account, a second terminal or a bigger
lot size.** Both are relieved by MORE ACCOUNTS. That single fact sets the
direction below.

---

## 2. THE DIRECTION: SEVERAL SMALL ACCOUNTS

Operator's vision, 2026-09-20: a handful of 10k accounts, each at 0.01
lots, each on its own cheap Linux/Wine VPS (`06_LINUX_WINE_BOX.md`),
rather than one account pushed to its limits.

Why it fits:

- Each account gets its own 200 slots and its own API budget.
- Each box is 20 USD/month and rebuildable from a documented list.
- A box or an account can be lost without taking the others down.

What it costs:

- N accounts means N daily-loss limits, N cycle clocks and N books to
  watch. **This is the real driver for the monitoring work in s4.**
- Inventory multiplies. Five accounts each carrying 100 underwater layers
  is five times the inventory, not a hedged version of one.

---

## 3. RING TOPOLOGY -- SAME CURRENCIES, DIFFERENT PATHS

Universe: EUR, USD, GBP, CAD, CHF, AUD, NZD. That is 21 pairs and 35
possible triangles, so several accounts can run genuinely different pair
sets from one currency pool.

**Mini rings, not one big loop.** The fleet already runs three
(EUR/GBP/USD, AUD/CAD/CHF, NZD extension). A triangle nets its currencies
the same way a seven-pair loop does, at a third of the slot cost, and it
stays a unit that can be paused or moved without breaking the structure.
A seven-pair loop only nets while all seven run, and fourteen instances
will not fit in 200 slots at depth.

Choosing the next rings -- decide from FILLS, not from a diagram:

- **Avoid expensive legs.** Wide-spread pairs (GBPNZD, GBPCAD, the NZD
  crosses) get fewer touches at any grid width. NZDCHF was rejected on
  this basis in ADR-146.
- **Avoid currencies that move together.** AUD/NZD barely diverges, which
  is why AUDNZD needed a 14-pip step to fill at all.
- **Rank candidates by scalps per day at a normalised grid**, using the
  method that produced geometry cycle 3. A pair with no history starts
  from a volume-matched add and is corrected from its own fills after a
  week.

**Never run the same PAIR on two accounts.** FTMO treats opposite
positions across linked accounts as manipulative trading, and a grid is
routinely long on one ladder and short on another. Two accounts both
running AUDCAD would regularly hold opposite AUDCAD positions. Give each
account its own rings, with no pair shared between accounts. (Same
strategy across own accounts is allowed, capped at 400k USD total
allocation per strategy.)

**Open structural question:** currencies overlap between rings, so an
account running two triangles is only flat in a currency if both are
complete. AUD currently sits in two rings. Harmless at 0.01 lots;
deliberate choice needed when there are several accounts.

---

## 4. MONITORING -- WHAT HAS TO EXIST BEFORE N > 2

Pipshed already takes a push per instance and groups by ring. Two gaps
matter, and the first is cheap NOW and expensive later:

1. **Account identity in telemetry and archive.** Without it, daily
   totals mix cycles and accounts. Needed before the Wednesday cycle
   change, never mind before a second account.
2. **One answer to "is anything wrong".** With N accounts, N status URLs
   is not a monitoring system. The questions that need a single answer:
   is any instance halted; is any account near its daily-loss limit; is
   any book near 200; is any API count near its cap; has any instance
   stopped reporting.

Not prettier charts. A single pass/fail, and the detail on demand.

---

## 5. DEPLOYMENT -- SCRIPT IT BEFORE IT IS THREE BOXES

Today a deploy is RDP, MetaEditor, F7, by hand. That does not survive
five machines. The Linux box helps: `scp` plus a scripted compile is
automatable where the Windows GUI is not. **Write the Linux build as a
script the second time it is built, not the fifth.**

---

## 6. STRATEGY WORK THAT GATES THE ABOVE

- **Passive ejection.** The cap is a hard ceiling with no way to clear a
  stuck layer except a manual close. Blocked behind geometry; the
  ratified trigger rule cannot fire and its corrected form is unwritten.
  Needed before tight grids can run unattended.
- **F1 migration.** The barbell is merged and cannot deploy onto an
  existing book (`02_TRAPS`). A flat account avoids it; any mid-cycle
  change does not.
- **Geometry cycle 3.** Even the pips across pairs by widening entry
  volume on the quiet ones. Objective: maximise pips per day AND cut the
  4.2x dispersion between pairs.
- **Carry.** OFF, and a known economic leak rather than a safe default.
  F2 made the mechanism correct; enabling it is a separate decision.
- **A second exit study** on the new account, using a
  difference-from-reference selection rule (the flaw recorded in
  `prompts/exit_counterfactual_results.md` s6).

---

## 6b. LOT SIZE -- GATED ON PARTIAL FILLS

The operator wants to scale lot size as accounts grow (e.g. 0.1 on a
100k account). Today every instance runs 0.01, the broker minimum, and
the EA silently depends on that: it assumes every entry fills in full and
sizes each exit from `InpLots`, not from the filled volume. At 0.01 a
partial fill is impossible; at anything larger it is not. **Partial-fill
handling (backlog C14) must land before any lot above 0.01**, and it costs
API requests, so it interacts with the per-account budget in s1.

## 7. WHAT WOULD CHANGE THIS PLAN

- **A funded account** would make the daily-loss limit, not the slot
  count, the binding constraint, and would change lot sizing from a
  tuning knob into a risk decision.
- **A bank desk** (see the BMO thread) has neither the 200-slot limit nor
  per-fill commission, so the cost model that drives geometry would be
  rebuilt from scratch.
- **Passive ejection working** would raise the useful depth per account
  and might make one account go further than it does today.

Line count: 160
