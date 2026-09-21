This message has a line count at the bottom

# BACKLOG -- OPEN WORK ITEMS

Standing list of what is open. **Not state** (that is `01_BOOT.md`), **not
direction** (`07_ROADMAP.md`), **not this session's plan** (the NEXT SESSION
block of the newest handoff, which picks items from here and orders them).

Rules: an item stays until it ships or is explicitly dropped. Each one says
what it is, why it is blocked or not, and where the evidence lives. Delete
when done -- the handoff records that it happened.

Last reviewed 2026-09-21 14:50Z.

---

## A. BEFORE WEDNESDAY (new demo account, flat book)

| # | Item | Status |
|---|---|---|
| A2 | **Lots: pips or dollars.** Gemini ruled evenness should be measured in DOLLARS, which makes `InpLots` a second lever. Lot step is 0.01, so only 0.01 / 0.02 are available: putting AUDCAD, NZDCAD and AUDNZD on 0.02 narrows USD/pip dispersion from 2.3x to 1.4x and doubles their exposure. **Operator decision; changes the presets** | open |
| A3 | **Fleet: DECIDED IN PRINCIPLE 2026-09-20 -- nine pairs, ONE arm each, cap 8.** GBPUSD, EURUSD, EURGBP plus the complete AUD/CAD/CHF/NZD block (AUDCAD, AUDCHF, AUDNZD, CADCHF, NZDCAD, NZDCHF). Modelled from the fills: peak ~144 slots, median ~112, against 16 instances on cycle 3 at 251. OPT/ALT paused: the objective (even pips per pair) is cross-sectional, volume is high-count, and a staggered mid-week schedule replaces the second arm as the control. Needs the cycle-3 revision doc: pre-registered metric (scalps/day as a ratio to the fleet median), stagger schedule, starting geometry | write-up next |
| A4 | **Presets.** UNBLOCKED by ADR-153 (merged `01b71d8`). Starting geometry proposed in chat 2026-09-20 (add / exit / width / stranded): GBPUSD 10/10/5/10, EURUSD 8/10/7/14, EURGBP 4/**?**/3/8, AUDCAD 7/10/5/10, AUDCHF 6/10/5/10, CADCHF 6/10/5/10, NZDCAD 10/10/5/10, AUDNZD 10/10/7/14, NZDCHF 6/10/3/8. **EURGBP's exit is an operator call: 5 (fills), 8 (middle), 11 (replay).** Exit and cap are FIXED for the cycle (I6/I7 halt on a mid-cycle change); add, width, stranded and deadband are reconstruction-safe mid-week dials | EURGBP exit open |
| A5 | **Account identity in telemetry and archive.** Without it the two cycles' daily totals mix. Cheapest while there is one account | not started |
| A7 | **GlobalVariable clean-up list**, source-verified. A terminal restart does NOT clear them. `GRIND_MAE_*` anchors on the OLD account's equity; carry keys are ticket-dead; slot/magic locks, cap exposure, `GRIND_DEINIT_`, `GRIND_CLOSEBY_EXHAUSTED` unread | not started |
| A8 | **Superseded by A3.** With one arm per pair there is no EURGBP OPT-vs-ALT exit test; EURGBP's exit becomes a single choice in A4 | superseded |
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
| C11 | **NZDCHF -- ADR-154.** Rejected in ADR-146 on a SIMULATOR tail-window gate (2015 SNB) at width 7 -- a geometry, not the pair; the same ADR shows width 3 surviving 60-74% and admits the live CHF pairs fail the same gate. Completes the AUD/CAD/CHF/NZD block, and CHF instance count FALLS (4 today -> 3). Needs a short ADR superseding ADR-146 D1 before it is attached | not started |
| C12 | **Twelve tests price against the LIVE chart.** T45, T46, T46b, T46c, T57b, S1, S1b, S3, S4, S5, S6, Q10 reach exit placement on the 1001 fixture without `Grind_MarketTestSeed`. Their own assertions pass either way and the carry leak they caused is fixed (`29df88f`), but they still read live quotes. Seed the market in each | hygiene |
| C13 | **Stale `MQL5\Experts\fxmatrix\fxgrind_tests.mq5` on the desktop terminal.** `desktop_sync.ps1` does not write there; the suite runs from `MQL5\Scripts\`. Compiling the stale copy gives an old suite and a misleading result. Delete it, or have the sync maintain it | small |
| C9 | **Rotate `TelemetryAPIKey`.** It appeared in a chat screenshot (not public). Deferred from Wednesday: rotating means touching every chart's inputs. Do it at a reattach that is happening anyway. **The separate, larger exposure is the pipshed READ token, which is in every handoff in a PUBLIC repo** -- see the standing question in `NEW_CHAT_PROMPT.md` | deferred |
| C10 | **Carry cost of cycle 3.** Tighter grids hold more layers, so the nightly swap bill rises, and that is NOT in the pips-per-day figures cycle 3 was chosen on. Measure after a week of the new geometry | waiting on data |

## D. STANDING / HYGIENE

| # | Item | Status |
|---|---|---|
| D1 | **Daily-loss headroom** is checked by eye in MetriX and was last verified 16-Sep. It is the one account limit nobody watches | recurring |
| D2 | **`research/geometry-depth-holdtime` is not merged**, though the cycle-2 memo says it is | small |
| D3 | **`.gitattributes` comment says "Docs stored CRLF"**, but `eol=crlf` controls the working copy; the repo stores LF | cosmetic |

Line count: 61
