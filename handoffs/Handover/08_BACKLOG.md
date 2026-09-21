This message has a line count at the bottom

# BACKLOG -- OPEN WORK ITEMS

Standing list of what is open. **Not state** (that is `01_BOOT.md`), **not
direction** (`07_ROADMAP.md`), **not this session's plan** (the NEXT SESSION
block of the newest handoff, which picks items from here and orders them).

Rules: an item stays until it ships or is explicitly dropped. Each one says
what it is, why it is blocked or not, and where the evidence lives. Delete
when done -- the handoff records that it happened.

Last reviewed 2026-09-21 17:30Z.

---

## A. BEFORE WEDNESDAY (new demo account, flat book)

| # | Item | Status |
|---|---|---|
| A2 | **Lots: DECIDED 2026-09-21 -- 0.01 on every instance.** Overrides Gemini's dollars ruling: 0.01 is the broker minimum so no partial fill is possible, and the EA assumes full fills (C14) | decided |
| A3 | **Fleet: DECIDED -- nine pairs, one arm, cap 8.** Written up as the cycle-3 pre-registration, `docs/architecture/geometry-cycle3.md` | decided |
| A4 | **Presets: WRITTEN 2026-09-21** -- nine `ea/presets/*_opt.set` (ALT presets untouched, unattached). EURGBP exit 5 (fills). Deploy with A9 | ready |
| A5 | **Account identity in telemetry and archive.** Without it the two cycles' daily totals mix. Cheapest while there is one account | not started |
| A7 | **GlobalVariable clean-up: DONE 2026-09-21.** `scripts/grind_gv_clean.mq5` (merged `18aeab5`) deletes the ten persistent prefixes; the temporary ones (locks, reporter lease) are cleared by the terminal restart. Used in runbook step 3 | done |
| A9 | **Deploy sequence: WRITTEN** -- `docs/runbooks/account-switch-2026-09-23.md`. Includes the F1 first-live check (B1) | ready |

## B. WEDNESDAY, OPTIONAL BUT CHEAP

| # | Item | Status |
|---|---|---|
| B1 | **F1 (barbell) on the flat account.** Merged already; a flat book has nothing to fail reconstruction, so it deploys cleanly and is the groundwork for ejection. Add a test that it starts clean on an empty book first | ready |
| B2 | **Carry ON?** F2 made the mechanism correct and it is inert while carry is off. The book currently pays ~47 pips (~4.4 USD) a night, triple on Wednesdays. Separate decision from A4 | decision |

## C. AFTER WEDNESDAY

| # | Item | Status |
|---|---|---|
| C1 | **Passive ejection.** The ratified stability rule cannot fire (measured 2026-09-19); its corrected form -- refill bid measured from the nearest layer's entry -- is unwritten and unmeasured. Then spec, DeepSeek, Gemini, Cursor, behind `InpEnablePassiveEject = false`. **Must record the exit offset it creates, or the next restart halts on I6** | blocked on a written rule |
| C2 | **F1 migration path.** The barbell cannot deploy onto an EXISTING book: startup reconstruction demands an exit on `rank == depth - 1` and halts permanently. Needed for any mid-cycle change after Wednesday. Options: place-before-check at `OnInit`, or route the startup shortfall to quarantine | not started |
| C3 | **Second exit study** on the new account, using a difference-from-reference selection rule (the flaw in `prompts/exit_counterfactual_results.md` s6). Needs a week of fills | waiting on data |
| C4 | **Carry-skewed quoting.** Asymmetric L0 (e.g. mid -2 / mid +8) to prefer the positive-carry side. Breakeven is 2-3 nights held against a 3-pip skew, most holds are hours, and a fleet-wide skew becomes a carry trade. **First: split realised pips by side per pair, after swap, and see whether there is anything to capture** | analysis first |
| C6 | **Linux box qualification.** Run `fxgrind_tests` there (Strategy Tester); whitelist the pipshed URL and prove telemetry; systemd service so the terminal survives a reboot; watch for Wine crashes. Only then consider moving a fleet to it. `OrderSend` under Wine stays unproven until a live instance runs | partly done |
| C7 | **Monitoring for N accounts.** One pass/fail across accounts: anything halted, any account near its loss limit, any book near 200, any API count near cap, anything stopped reporting. See `07_ROADMAP.md` s4 | not started |
| C8 | **NZDCHF.** Rejected in ADR-146, never attached, presets still in the repo. Reopen only as part of ring selection, not as a one-off | idea |
| C12 | **Twelve tests price against the LIVE chart.** T45, T46, T46b, T46c, T57b, S1, S1b, S3, S4, S5, S6, Q10 reach exit placement on the 1001 fixture without `Grind_MarketTestSeed`. Their own assertions pass either way and the carry leak they caused is fixed (`29df88f`), but they still read live quotes. Seed the market in each | hygiene |
| C15 | **Commanded ejection -- FIRST BUILD AFTER WEDNESDAY.** A script (`grind_eject`, inputs magic + ticket) writes `GRIND_EJECT_<magic>`; the EA validates the ticket is its DEEPEST layer on a side, cancels that side's ENT, closes the position through its OWN path, updates its book (no quarantine, no reattach, no preset trap), clears the command and emits an `EJECT` telemetry event so pipshed records it. The engine's normal add re-quote then completes the roll. Separates MECHANISM (build and test once) from POLICY (human-triggered until the roll log and the retrace study say what the rule is). Passive ejection later = this mechanism + a trigger. EA code touching layer state: spec, tests first, DeepSeek. Must survive restart (I6) | not started |
| C16 | **Retrace study** -- from the M1 bid/ask data and fills: for each capped side, how often a retrace of `X` pips came within 24h vs how often price returned to the deepest layer's exit. Turns roll vs eject-and-wait into a number. Operator insight 2026-09-21: with add `a` < exit `X`, a retrace earns ~`X/a` pips per pip beyond the first `X` -- favours rolling | not started |
| C14 | **Partial-fill handling -- prerequisite for any lot above 0.01.** The EA reads filled volume only to LOG it (`grind_engine.mqh:1651`) and places each exit for `InpLots`. A partial fill leaves an exit sized for volume that never filled; CloseBy then nets part of it and leaves an unowned opposite position, and the second partial deal's handling is untraced. Operator wants to scale (e.g. 0.1 on a 100k account), so this gates growth. Tied to the API budget: handling partials costs requests | not started |
| C9 | **Rotate `TelemetryAPIKey`.** It appeared in a chat screenshot (not public). Deferred from Wednesday: rotating means touching every chart's inputs. Do it at a reattach that is happening anyway. **The separate, larger exposure is the pipshed READ token, which is in every handoff in a PUBLIC repo** -- see the standing question in `NEW_CHAT_PROMPT.md` | deferred |
| C10 | **Carry cost of cycle 3.** Tighter grids hold more layers, so the nightly swap bill rises, and that is NOT in the pips-per-day figures cycle 3 was chosen on. Measure after a week of the new geometry | waiting on data |

## D. STANDING / HYGIENE

| # | Item | Status |
|---|---|---|
| D1 | **Daily-loss headroom** is checked by eye in MetriX and was last verified 16-Sep. It is the one account limit nobody watches | recurring |
| D2 | **`research/geometry-depth-holdtime` is not merged**, though the cycle-2 memo says it is | small |
| D3 | **`.gitattributes` comment says "Docs stored CRLF"**, but `eol=crlf` controls the working copy; the repo stores LF | cosmetic |

Line count: 61
