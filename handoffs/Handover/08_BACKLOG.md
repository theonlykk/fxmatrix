This message has a line count at the bottom

# BACKLOG -- OPEN WORK ITEMS

Standing list of what is open. **Not state** (that is `01_BOOT.md`), **not
direction** (`07_ROADMAP.md`), **not this session's plan** (the NEXT SESSION
block of the newest handoff, which picks items from here and orders them).

Rules: an item stays until it ships or is explicitly dropped. Each one says
what it is, why it is blocked or not, and where the evidence lives. Delete
when done -- the handoff records that it happened.

Last reviewed 2026-09-21 19:40Z.

---

## A. BEFORE WEDNESDAY (new demo account, flat book)

| # | Item | Status |
|---|---|---|
| A2 | **Lots: DECIDED 2026-09-21 -- 0.01 on every instance.** Overrides Gemini's dollars ruling: 0.01 is the broker minimum so no partial fill is possible, and the EA assumes full fills (C14) | decided |
| A3 | **Fleet: DECIDED -- nine pairs, one arm, cap 8.** Written up as the cycle-3 pre-registration, `docs/architecture/geometry-cycle3.md` | decided |
| A4 | **Presets: WRITTEN 2026-09-21** -- nine `ea/presets/*_opt.set` (ALT presets untouched, unattached). EURGBP exit 5 (fills). Deploy with A9 | ready |
| A5 | **Account identity in telemetry and archive.** Without it the two cycles' daily totals mix. Cheapest while there is one account | not started |
| A9 | **Deploy sequence: WRITTEN** -- `docs/runbooks/account-close-out.md` + `docs/runbooks/cycle3-start.md`. Includes the F1 first-live check (B1) | ready |

## B. WEDNESDAY, OPTIONAL BUT CHEAP

| # | Item | Status |
|---|---|---|
| B1 | **F1 (barbell) on the flat account.** Merged already; a flat book has nothing to fail reconstruction, so it deploys cleanly and is the groundwork for ejection. Empty-book test not written; ADR-156 tests cover reconstruction | ready |
| B2 | **Carry ON?** F2 made the mechanism correct and it is inert while carry is off. The book currently pays ~47 pips (~4.4 USD) a night, triple on Wednesdays. Separate decision from A4 | decision |

## C. AFTER WEDNESDAY

| # | Item | Status |
|---|---|---|
| C2 | **DONE -- ADR-156, merged `3f72b9f` (2026-09-22).** Startup tolerates a missing required exit, places it, OnTick stays strict. Suite 1432/1432; DeepSeek audit `5e31430`; Gemini ruling `prompts/gemini_adr156_ruling.md` | done |
| C3 | **Second exit study** on the new account, using a difference-from-reference selection rule (the flaw in `prompts/exit_counterfactual_results.md` s6). Needs a week of fills | waiting on data |
| C4 | **Carry-skewed quoting.** Asymmetric L0 (e.g. mid -2 / mid +8) to prefer the positive-carry side. Breakeven is 2-3 nights held against a 3-pip skew, most holds are hours, and a fleet-wide skew becomes a carry trade. **First: split realised pips by side per pair, after swap, and see whether there is anything to capture** | analysis first |
| C6 | **Linux box qualification.** Run `fxgrind_tests` there (Strategy Tester); whitelist the pipshed URL and prove telemetry; systemd service so the terminal survives a reboot; watch for Wine crashes. Only then consider moving a fleet to it. `OrderSend` under Wine stays unproven until a live instance runs | partly done |
| C7 | **Monitoring for N accounts.** One pass/fail across accounts: anything halted, any account near its loss limit, any book near 200, any API count near cap, anything stopped reporting. See `07_ROADMAP.md` s4 | not started |
| C12 | **Twelve tests price against the LIVE chart.** T45, T46, T46b, T46c, T57b, S1, S1b, S3, S4, S5, S6, Q10 reach exit placement on the 1001 fixture without `Grind_MarketTestSeed`. Their own assertions pass either way and the carry leak they caused is fixed (`29df88f`), but they still read live quotes. Seed the market in each | hygiene |
| C17 | **Account daily-loss circuit breaker -- TOP PRIORITY AFTER WEDNESDAY.** Evidence (MetriX, 2026-09-21): $10k account, FTMO limit $500/day; **worst day -$420 (84%, FOMC night)**; about $217 of the day's limit already used by mid-session, apparently because floating inventory counts against each day from its start. **Nothing in the EA acts on this**: `GRIND_MAE_DAILY_LOSS_FRAC` (4.5%) only REPORTS the distance to the floor. Design (operator, 2026-09-21): **portfolio-level only** -- no per-instance budgets, because the fleet's pairs exist to diversify and absorb each other's losses. When the account's FTMO-day loss reaches a threshold (e.g. 80% of the limit), EVERY instance stops placing NEW entries (adds and L0); exits keep resting and filling, so the book can only shrink; resets at FTMO's daily reset (midnight CE(S)T). A backstop for technology failure and correlated tail days, not an everyday control. Reuses `GRIND_MAE_ANCHOR_<day>`, which must match FTMO's reference (verify: higher of balance or equity at day start). ADR, tests first, DeepSeek (it changes when orders are placed) | not started |
| C15 | **Commanded ejection -- FIRST BUILD AFTER WEDNESDAY.** A script (`grind_eject`, inputs magic + ticket) writes `GRIND_EJECT_<magic>`; the EA validates the ticket is its DEEPEST layer on a side, cancels that side's ENT, closes the position through its OWN path, updates its book (no quarantine, no reattach, no preset trap), clears the command and emits an `EJECT` telemetry event so pipshed records it. The engine's normal add re-quote then completes the roll. Separates MECHANISM (build and test once) from POLICY (human-triggered until the roll log and the retrace study say what the rule is). Passive ejection later = this mechanism + a trigger. EA code touching layer state: spec, tests first, DeepSeek. Must survive restart (I6) | not started |
| C16 | **Retrace study** -- from the M1 bid/ask data and fills: for each capped side, how often a retrace of `X` pips came within 24h vs how often price returned to the deepest layer's exit. Turns roll vs eject-and-wait into a number. Operator insight 2026-09-21: with add `a` < exit `X`, a retrace earns ~`X/a` pips per pip beyond the first `X` -- favours rolling | not started |
| C14 | **Partial-fill handling -- prerequisite for any lot above 0.01.** The EA reads filled volume only to LOG it (`grind_engine.mqh:1651`) and places each exit for `InpLots`. A partial fill leaves an exit sized for volume that never filled; CloseBy then nets part of it and leaves an unowned opposite position, and the second partial deal's handling is untraced. Operator wants to scale (e.g. 0.1 on a 100k account), so this gates growth. Tied to the API budget: handling partials costs requests | not started |
| C9 | **Rotate `TelemetryAPIKey`.** It appeared in a chat screenshot (not public). Deferred from Wednesday: rotating means touching every chart's inputs. Do it at a reattach that is happening anyway. **The separate, larger exposure is the pipshed READ token, which is in every handoff in a PUBLIC repo** -- see the standing question in `NEW_CHAT_PROMPT.md` | deferred |
| C10 | **Carry cost of cycle 3.** Tighter grids hold more layers, so the nightly swap bill rises, and that is NOT in the pips-per-day figures cycle 3 was chosen on. Measure after a week of the new geometry | waiting on data |
| C18 | **Quarantine escalates while the retry is blocked** (DeepSeek T-1 on ADR-156). Checks count even when `Grind_GuardsAllowTrading` is false, so ticks during a close-only window halt an instance that cannot repair itself. Smallest fix: count a check only when a retry was allowed. Quarantine-wide, so its own ADR (Gemini ruling item 4) | not started |
| C19 | **Pipshed does not render `CRITICAL_*` events.** They are stored in `ea_events` but no dashboard view shows them, so `STARTUP_EXIT_SHORTFALL_SIDE` is visible only in the Experts tab or an archive query | not started |
| C20 | **`r1_audit.py` carried a stale ADR-155 "AUDIT TASK" into the ADR-156 audit.** The run prompt edits only the config block; that text lives elsewhere in the local script (not in the candlelab repo). Find it and make it part of the per-audit config before the next audit | not started |
| C21 | **Guard ceiling rations entries by tick speed.** At `positions + orders + resting ENT > 194` every entry is blocked; each scalp frees room for about one entry, and the fastest-ticking instance takes it (2026-09-22: GBPUSD OPT took AUDCAD ALT's freed slot in 0.3 s). Safe (exits unaffected) but unfair. First: show the guard total in pipshed (`g_grind_last_guard_total` exists in the EA); watch it on the 9-instance account before designing any allocation | not started |
| C22 | **Score and compare pairs in USD, not only pips.** At 0.01 lots one pip is worth $0.057 (AUDNZD) to $0.134 (EURGBP), 2.3x apart (derived from the 2026-09-22 13:04Z book; last scalps confirm to the cent). Equal pips on AUDNZD and GBPUSD made about half the dollars. Judge geometry per pair in pips; judge contribution, risk and the C17 breaker in USD. For cycle 4: R2 scores USD per scalp. With lots fixed at 0.01, the dollar lever is pair SELECTION. Sizing lots by pip value is OUT while fills must stay atomic (see C23) | not started |
| C23 | **Assess partial-fill risk above 0.01 lots.** 0.01 is the minimum lot, so a fill is all or nothing, and the engine assumes it. Question: how often does a resting limit of 0.02 or 0.10 fill partially on this broker? Evidence first: the symbol's filling mode (`SYMBOL_FILLING_MODE`) and the order's `ORDER_FILLING_*`, then a small sample of deals whose volume is below the order volume. If partials are very rare, design a contingency that cannot threaten the API budget (one bounded action per partial -- for example keep the filled part as a smaller layer, or close the remainder once -- never a retry loop). Unlocks sizing by pip value (C22) | not started |
| C24 | **Daily close snapshot in pipshed: spread capture vs inventory P&L.** Realised P&L counts only winners (no stops), so it cannot show whether the system makes money. One row per day at a fixed time (broker day end or the FTMO reset C17 settles on): equity, balance, realised that day, change in open MTM, swap charged, layers per side per instance, guard total. The daily equation is spread capture (realised) minus adverse selection (MTM change: layers pile up because price moves against the book). 2026-09-22: ~+$80 realised on ~210 scalps, while one hour showed +$7.85 realised vs -$28.55 MTM. Cycle 2 all-in: equity 9,853 vs 10,000 start (-1.5%); closed about +$169, open book about -$316. Before/after measure for C15 ejection | not started |

## D. STANDING / HYGIENE

| # | Item | Status |
|---|---|---|
| D1 | **Daily-loss headroom** is checked by eye in MetriX and was last verified 16-Sep. It is the one account limit nobody watches | recurring |
| D2 | **`research/geometry-depth-holdtime` is not merged**, though the cycle-2 memo says it is | small |
| D3 | **`.gitattributes` comment says "Docs stored CRLF"**, but `eol=crlf` controls the working copy; the repo stores LF | cosmetic |

Line count: 66
