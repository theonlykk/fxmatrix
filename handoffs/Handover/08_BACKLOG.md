This message has a line count at the bottom

# BACKLOG -- OPEN WORK ITEMS

Standing list of what is open. **Not state** (that is `01_BOOT.md`), **not
direction** (`07_ROADMAP.md`), **not this session's plan** (the NEXT SESSION
block of the newest handoff, which picks items from here and orders them).

Rules: an item stays until it ships or is explicitly dropped. Each one says
what it is, why it is blocked or not, and where the evidence lives. Delete
when done -- the handoff records that it happened.

Last reviewed 2026-09-20 22:15Z.

---

## A. BEFORE WEDNESDAY (new demo account, flat book)

| # | Item | Status |
|---|---|---|
| A1 | **ADR-153: remove the `add == 2 x width` rule** (`fxgrind.mq5:119`, `GRIND_ADD_WIDTH_MULTIPLE`, ADR-125 `0bd0877`) -- blocks every cycle-3 add value. Replace with a range check `0.5 <= add/width <= 4`, still fatal. **Gemini approved 2026-09-20** (retracted his keep-the-link ruling). **Scope also covers the stranded threshold**: it must follow WIDTH at `2 x width`, NOT add. Below `width` the stranded gate is permanently open -- a fresh L0 rests exactly `width` from mid -- and the deadband silently becomes the only brake on the ADR-124 recentre, costing `OrderModify` calls against the 2,000/day API cap. Add a startup check `stranded > width + deadband`. Next: Cursor spec, tests first, then DeepSeek (ARCHITECT s2: grid geometry AND it changes when orders are placed) | spec next |
| A2 | **Lots: pips or dollars.** Gemini ruled evenness should be measured in DOLLARS, which makes `InpLots` a second lever. Lot step is 0.01, so only 0.01 / 0.02 are available: putting AUDCAD, NZDCAD and AUDNZD on 0.02 narrows USD/pip dispersion from 2.3x to 1.4x and doubles their exposure. **Operator decision; changes the presets** | open |
| A3 | **Fleet size.** The book sat at guard 194-195 with 16 instances. Cycle 3 makes nearly every pair trade MORE, and F1 adds one resting exit per side of depth >= 2 (30 slots on Friday's book). Measure peak book per instance from the archive and choose the count | not started |
| A4 | **Cycle-3 presets.** add / exit / width / stranded per arm, from `prompts/gemini_memo_geometry_cycle3.md`, with EURGBP OPT 4/5 and ALT 4/11 (A8) and **stranded = 2 x width on every arm** (A1). Blocked by A1, shaped by A2 and A3 | blocked |
| A5 | **Account identity in telemetry and archive.** Without it the two cycles' daily totals mix. Cheapest while there is one account | not started |
| A7 | **GlobalVariable clean-up list**, source-verified. A terminal restart does NOT clear them. `GRIND_MAE_*` anchors on the OLD account's equity; carry keys are ticket-dead; slot/magic locks, cap exposure, `GRIND_DEINIT_`, `GRIND_CLOSEBY_EXHAUSTED` unread | not started |
| A8 | **EURGBP exit to 11.** Cleared the holdout AND the swap check (`prompts/exit_counterfactual_results.md` s7, +93 pips, interval [+32, +145]). Ship on one arm with the other at 8 as a control, or hold for the new account? | decision |
| A9 | **Deploy sequence.** Detach all 16 on the OLD account BEFORE switching login (attached EAs reinit on the new account and start quoting), switch, restart, clear GVs (A7), deploy build + presets, tag `vps-<sha7>`, attach | not started |

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
| C9 | **Rotate `TelemetryAPIKey`.** It appeared in a chat screenshot (not public). Deferred from Wednesday: rotating means touching every chart's inputs. Do it at a reattach that is happening anyway. **The separate, larger exposure is the pipshed READ token, which is in every handoff in a PUBLIC repo** -- see the standing question in `NEW_CHAT_PROMPT.md` | deferred |
| C10 | **Carry cost of cycle 3.** Tighter grids hold more layers, so the nightly swap bill rises, and that is NOT in the pips-per-day figures cycle 3 was chosen on. Measure after a week of the new geometry | waiting on data |

## D. STANDING / HYGIENE

| # | Item | Status |
|---|---|---|
| D1 | **Daily-loss headroom** is checked by eye in MetriX and was last verified 16-Sep. It is the one account limit nobody watches | recurring |
| D2 | **`research/geometry-depth-holdtime` is not merged**, though the cycle-2 memo says it is | small |
| D3 | **`.gitattributes` comment says "Docs stored CRLF"**, but `eol=crlf` controls the working copy; the repo stores LF | cosmetic |

Line count: 59
