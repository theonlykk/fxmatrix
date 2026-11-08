This message has a line count at the bottom

# Argon Review: `docs/research/c162-go-no-go-memo-2026-11-08.md` (C162 Go / No-Go Memo, Draft)

- **Branch:** `review/argon-c162-memo`
- **Base commit (`origin/main`):** `2917efb25983fd1a13b2702867f8885f87d6b32e`
- **Files read (at `origin/main`):**
  - `prompts/argon_review_c162_memo.md` (lines 1-57)
  - `docs/research/c162-go-no-go-memo-2026-11-08.md` (lines 1-129)
  - `docs/research/two-arm-viability-2026-10-21.md` (lines 1-201)
  - `research/replay/results/sweep_notes.md` (lines 1-945)
  - `research/t3_drawdown/results.md` (lines 1-46)
  - `research/cluster/results.md` (lines 1-81)
  - `research/magnet/results.md` (lines 1-71)
  - `research/longrun/results.md` (lines 1-92)
  - `research/longrun/MANIFEST.md` (lines 1-25)
  - `research/longrun/out_limit/cont_{AUDCAD,AUDCHF,CADCHF,EURGBP,EURUSD,GBPUSD}.json` (line 1 of each, all 6 files)
  - `research/nocarry/PREREG.md` (lines 1-128)
  - `research/nocarry/results.md` (lines 1-88)
  - `research/nocarry/MANIFEST.md` (lines 1-74)
  - `research/nocarry/selfcheck_out.txt` (lines 1-65)
  - `research/nocarry/summarise.py` (lines 1-85)
  - `research/nocarry/out/{CONT,DAY,WEEK,DAY_w05,WEEK_w05}_{AUDCAD,AUDCHF,CADCHF,EURGBP,EURUSD,GBPUSD}.json` (line 1 of each, all 30 files)
  - `docs/FULL_TRIAL_RECORD_1514264399.md` (lines 1-129)
  - `docs/FULL_TRIAL_RECORD_1514582088.md` (lines 1-166)
  - `handoffs/HANDOFF_2026-09-24.md` (lines 9070-9298, covering s92 continued 10-12 and s93 through s93 continued 3)
  - `research/e_week1/PREREG.md` (lines 1-136)
  - `docs/research/replay-calibration-eurusd-4.md` (lines 1-191)
  - `research/opt_budget/MECHANICS.md` (lines 1-64)
  - `ea/grind_engine.mqh` (lines 1-1000, 1350-2165, 2375-2400, 2840-3515)
  - `ea/grind_api_counter.mqh` (lines 1-209)
  - `ea/grind_recon.mqh` (lines 1-1437)
- **Files NOT read:** None of the listed sources on `origin/main` were skipped. External non-repo files (`D:\fxmatrix-exports\...`, `D:\mt5-replay\...`, and the `.npz` arrays not in git) were not read, per Rule 4.

---

## Summary Table (Items 1-8)

| Item | Section / Topic | Verdict | Summary of Finding |
|---|---|---|---|
| 1 | Every number in the memo against its source (and arithmetic of derived figures) | **GAP** | Every dollar figure, count, percentage, time, and arithmetic derivation (`+$1,087`, `-$11,487`, `+$15k`, `$79k`, `$108k`, `-$39.84`, `$330`, `$380`, `$23/day`, `11x`, `60x`, `+$180`) checks out against its source and against the raw `research/longrun/out_limit/cont_*.json` and `research/nocarry/out/*.json` files. **Two small date/window gaps:** (1) `memo:36` and `memo:81` call `Aug - 23 Oct 2026` (`+$180` on bars) and `sweep11` (`+$231` on ticks) `"the same twelve weeks"`, whereas `sweep11` summed 8 calm weeks (`3 Aug - 25 Sep`) + ~3 October weeks (`1-20 Oct`) = **about 11 weeks (54 trading days)** (`research/t3_drawdown/results.md:24`), while `+$180` (`+$179.97`) is the 3-month change from the `2026-07` month-end mark to `23 Oct 2026`; (2) `memo:9` says `fixed 7 Nov`, whereas `PREREG.md` was drafted 7 Nov and amended 8 Nov (`s93b`) before any runner or run. |
| 2 | Every quotation (the operator's words, s1 table and s3) against its source, person, and date | **GAP** | All three quotations (`memo:7`, `memo:42-43`, `memo:45`) match the operator's exact words and dates in their source files; no paraphrase is presented as a quote. **One context gap (`memo:45`):** in `research/longrun/results.md:8, 65-70`, the operator's 31 Oct quote had two parts (`"we are not really earning, we are just monetizing mtm winners"` and `"conversely, we are super relaxed about mtm losses and confident that they will turn into winners"`), and `results.md:68` explicitly ruled the second part **`NOT how the losses arrive`**. `memo:45-47` explains the roll mechanism immediately after `"confirmed"`, so adding four words (`confirmed on the winners; losers are...`) makes the verdict match `results.md:65-70` on both halves. |
| 3 | `s2`'s table labels ("in or out of sample") and `"Everything in sample said 'maybe'; everything out of sample said no"` | **DEFECT** | (1) In `s2`'s table, Row 2 (`sweep10`, `memo:27`) is labeled `out (of EURUSD)`, but `q88` (which set each pair's ALT add) was **fitted in-sample on D's fills of 1-16 Oct** (`sweep_notes.md:723`); Row 6 (`longrun`, `memo:31`) is labeled `out`, whereas ~2.5 of its 46 months (`Aug - 20 Oct 2026`) overlap `t3`'s in-sample selection window. (2) **`memo:35` (`"Everything in sample said 'maybe'; everything out of sample said no."`) is overstated on both sides:** in sample, `t3_drawdown` (`memo:29`) said **no** on FTMO survival (`breaches FTMO's $500 day on 16 Oct`), and `sweep9`'s pre-registered daily rule (`memo:26`) passed nothing; out of sample, `longrun` ALT was `+$800` (positive on 4 of 6 pairs, 3 of 4 years, and 20 of 34 twelve-month windows), `2026 to 23 Oct` was `+$876`, and live Fleet C (`t2`) was `+$77` (`OPT +$45 / ALT +$31`) with max day loss `~$230` on 4 Nov. |
| 4 | Balance: evidence FOR the grid in the sources that is missing or understated, and whether it changes the conclusion | **GAP** | Seven pieces of evidence cutting in favor of the grid or a subset are understated or omitted: (1) `CONT` ALT (`+$800.26`) was positive on **4 of 6 pairs**, **3 of 4 calendar years** (`2023 +$317, 2024 -$357, 2025 +$260, 2026 +$580`), and **20 of 34 twelve-month windows** (`14 of 34` negative) in `research/nocarry/out/CONT_*.json`; (2) **AUDCAD** was positive on both arms in `CONT` (`OPT +$772, ALT +$876`, total `+$1,648`) and ALT was positive in `WEEK` on AUDCAD (`+$171`) and EURGBP (`+$63`); (3) **`2026 to 23 Oct` was `+$876`** in `CONT`; (4) `sweep9` s8.2's whole `add 14-27` band and **`swcap` (25 Oct, `sweep_notes.md:938`)** where OPT cap 9 was `CONFIRMED` (`+$336.00` vs `+$230.64`); (5) Trial 1's `+$72.91` net grind before 4 early startup forced-closes; (6) **live ALT positive on all three fleets (`C +$31, D +$61, E +$23`)** to 30 Oct and **C surviving 4 Nov at `~$230` max day loss**; (7) the magnet main grid earning `+$589.85` (H1) and `+$198.67` (H2) before swap. **None changes the memo's conclusion**, because ALT's `+$800` over 46 months is only `~$17/month` across 6 pairs before swap (with `190-790 h` median loser hold times and `23 of 46` month-end open books `<= -$500`), and loses under `DAY` (`-$6,162`) and `WEEK` (`-$2,671`). |
| 5 | Stretch (`s3`, `s4`, `s5`, `s7`) and completeness of `s5` | **GAP** | (1) `s3` (`"Carry is not the problem"`) is true of **overnight holding vs cutting flat**, but should say `"Overnight holding is not the P&L problem"` so it is not read as broker swap/financing. (2) `s4` (`"by one mechanism"`): the FTMO day-start-balance accounting mechanism is identical in Trials 2 and 3, but `memo:59` should note Trial 2 ran 8 pairs with pre-re-roll near-identical OPT/ALT stacks (`5454358`), and `memo:65` should note that `1,181 of 1,191` FTMO days in `CONT` comes from a non-liquidating 4-year run carrying `-$471` to `-$1,163` open (`PREREG.md:64`), whereas a live FTMO account stops on the first breach. (3) `s5` omits: asymmetric `exit != add` and `cap 9` (`swcap`) were not run on the 4-year bars; `CONT` ALT-only FTMO-day breaches were not reported in `results.md`; and `PREREG.md:107-116`'s bar spread minimum, skipped `<4,000`-bar holiday weeks, and missing rollover pause. (4) `s7`: `replay-plan4` was validated for **count-level use on EURUSD outside scheduled-release bursts** (`P&L` outside validated counts), and its unseen blind window scored `98.2-99.2%` alongside `97.3-100.0%` on the seen development windows. |
| 6 | `s6`, the options: fairness, missing options, consistency with `PREREG.md` s6 and operator's 21 Oct test | **GAP** | Options A, B, C, D are fair and consistent with `research/nocarry/PREREG.md:95-96` and `two-arm-viability-2026-10-21.md:30-31`. **One missing sub-option in `B`:** keeping **only C (`t2`, 3 pairs) or an ALT-only demo** running (after the halt-on-refusal fix), since the operator noted C's frame on 31 Oct (`HANDOFF:9083`), C was `+$77` to 30 Oct and `~$230` max day loss on 4 Nov, and ALT was `+$800` in `CONT` and positive on C, D, and E to 30 Oct. It does not change the recommendation (`A`), because ALT earns `~$17/month` before swap over 46 months, but `B` should name it. |
| 7 | `s8`, the loose ends: E's storm, why reconciliation kept 95 layers, and any omitted open items | **GAP** | E's storm (`~465/min`, `~57,000` total, no `TRADE_RETCODE_TRADE_DISABLED` check) matches `HANDOFF:9175, 9190-9195` and `ea/grind_engine.mqh:1442-1468, 2096, 2151, 2386, 3502`. From `ea/grind_recon.mqh:1363-1435` and `ea/grind_engine.mqh:2876-2889`, reconciliation kept 95 layers because `Grind_ReconstructState` runs only in `OnInit`, `Grind_CheckBookInvariants` checks internal invariants on a temporary rebuild of the empty broker book (`count = 0` passes vacuously) without comparing against `g_grind_long`/`g_grind_short`, and `OnTradeTransaction` only removes layers on `DEAL_ENTRY_OUT_BY` with matching `magic`. **Two omitted loose ends:** (1) Fleet B's `~89-94` layers (`HANDOFF:9103, 9155, 9169`); (2) no standalone `docs/FULL_TRIAL_RECORD_1515045375.md` exists on `main` despite `memo:110` claiming `"three full trial records"`. |
| 8 | Fitness as an internal record: FTMO's rules and 6-month traceability on `main` | **GAP** | FTMO's daily-loss and Standard-funded weekend rules match the repo's record. **Three traceability gaps:** (1) `memo:110` claims `"three full trial records"`, but only two `docs/FULL_TRIAL_RECORD_*.md` files exist on `main` (Trial 3 is in `HANDOFF s93`); (2) `memo:105` cites `MECHANICS.md` without its directory (`research/opt_budget/MECHANICS.md`) and `memo:125` abbreviates `results.md, MANIFEST.md`; (3) `memo:9` says `fixed 7 Nov` whereas `research/nocarry/PREREG.md` was amended 8 Nov (`s93b`) before any run. |

---

## Detailed Review (Items 1-8)

### 1. Every number in the memo against its source

- **Verdict:** **GAP** (all arithmetic and source numbers confirmed; two minor window/date precision gaps in `memo:9` and `memo:36, 81`)

#### 1.1 Line-by-line audit of every number in `docs/research/c162-go-no-go-memo-2026-11-08.md`

| Memo line | Figure in memo | Source file & line | Arithmetic / Verification | Verdict |
|---|---|---|---|---|
| `memo:3` | `8 Nov 2026` | `HANDOFF:9277, 9282` | Drafted Sun 8 Nov 2026 (`s93 continued, 3`). | **CONFIRMED** |
| `memo:7` | `21 Oct`, `s1` | `two-arm-viability:3, 12, 30-31` | Question written 21 Oct 2026 in section 1 (`s1`). | **CONFIRMED** |
| `memo:9` | `s6, fixed 7 Nov before any run` | `nocarry/PREREG.md:3, 9, 87`; `HANDOFF:9232, 9239, 9250` | Drafted 7 Nov (`s93a`) and amended 8 Nov (`s93b`, `8ccf07c`) after Argon's review, still before any runner or run (`PREREG.md:9` says `Amended 7 Nov`, `HANDOFF:9232` records `Sun 8 Nov ~02:20Z`). Saying `7-8 Nov` avoids a date discrepancy with git history. | **GAP** |
| `memo:15` | `add = exit = 7 pips, cap 7` (`s1`) | `longrun/results.md:14, 26-28` | EURUSD OPT `2 / 7`, `add = exit = 7 pips, cap 7`. | **CONFIRMED** |
| `memo:16` | `+7 pips, $0.70 less $0.06` | `longrun/results.md:15` | At 0.01 lots on EURUSD (`$0.10/pip`), `7 x $0.10 = $0.70`, commission `$0.06`. | **CONFIRMED** |
| `memo:16-17` | `falls 60 pips`, `7 pips` | `longrun/results.md:15-16` | Exact match to worked example in `results.md:15-16`. | **CONFIRMED** |
| `memo:18` | `40 pips = -$4.00`, `Thirty small wins` | `longrun/results.md:17-18` | `40 x -$0.10 = -$4.00`; `30 x ($0.70 - $0.06) = 30 x $0.64 = $19.20` (for several rolled closes; exact wording from `results.md:17-18`). | **CONFIRMED** |
| `memo:19` | `+$22,096` scalps, `-$23,314` rolled | `longrun/results.md:18, 44`; `cont_EURUSD.json:1` | `scalp: 22096.08` (`+$22,096`), `rolled: -23314.17` (`-$23,314`). | **CONFIRMED** |
| `memo:26` | `22 Oct`, `sweep9`, `1-20 Oct`, `add >= 14` | `two-arm-viability:140, 142, 148`; `sweep_notes.md:620, 630, 635` | `22 Oct ~03:25Z`, `1 Oct 04:00 to 20 Oct 23:45`, `no geometry is MEANINGFUL`, `every cap 8 cell with add >= 14 is positive at every exit (+126 to +862)` (and on the cap-7 diagonal `10 +128, 14 +378, 18 +532, 20 +597, 23 +454, 27 +465`). | **CONFIRMED** |
| `memo:27` | `22 Oct`, `sweep10`, `other five pairs`, `negative on all five`, `2 of 5` | `two-arm-viability:177-180`; `sweep_notes.md:740, 754-761` | `22 Oct ~15:15Z`; OPT + ALT at q88: `-156.5, -1159.7, -306.0, -386.6, -332.9` (all 5 negative); `OFFSET at q88 on 2 of the 5 (GBPUSD, CADCHF)`. | **CONFIRMED** |
| `memo:28` | `23 Oct`, `sweep11`, `+$231`, `six pairs at 0.01 lots`, `three picks` | `two-arm-viability:184, 187-189`; `sweep_notes.md:858, 875, 877` | `23 Oct ~02:50Z`; six pairs in USD at 0.01 lots = `+$230.64` (rounds to `+$231`); 3 post-hoc operator picks (AUDCHF OPT 14, GBPUSD OPT 9, EURGBP ALT 23). | **CONFIRMED** |
| `memo:29` | `24 Oct`, `t3_drawdown`, `$91 a month`, `84%`, `$500 day on 16 Oct` | `t3_drawdown/results.md:3, 24-25, 30-32` | `24 Oct 2026`; `+$230.64` over ~11 weeks (`54` trading days / `~2.54` months) = `$90.69/month` (`about $91 a month`); October commission `$88 of $105 = 83.8%` (`84%`); FTMO day ending `16 Oct 22:00Z` = `$626.51 > $500`. | **CONFIRMED** |
| `memo:30` | `26-27 Oct`, `NONE; NONE` | `cluster/results.md:3, 7`; `magnet/results.md:3, 7` | Osler `26 Oct 2026` (`ROUND REVERSAL EFFECT: NONE. ROUND CROSSING EFFECT: NONE.`); Magnet `27 Oct 2026` (`MAGNET: NONE.`). | **CONFIRMED** |
| `memo:31` | `31 Oct`, `2 Jan 2023 - 23 Oct 2026`, `-$6,358`, `OPT -$7,158`, `ALT +$800`, `three of four years lose`, `27 of 34` | `longrun/results.md:3, 7, 50, 54, 56` | Sum across `cont_*.json`: OPT `-$7,157.83` (`-$7,158`), ALT `+$800.26` (`+$800`), total `-$6,357.57` (`-$6,358`); years `2023 -$2,232, 2024 -$3,113, 2025 -$1,887, 2026 +$876` (3 of 4 lose); `27 of 34` 12m windows negative. | **CONFIRMED** |
| `memo:32` | `8 Nov`, `NO EDGE`, `DAY -$22,711`, `every year negative`, `34 of 34`, `WEEK -$13,488` | `nocarry/results.md:3, 8, 16-18, 24` | `DAY` net `-$22,710.81` (`-$22,711`), years `-5,679 / -5,535 / -7,361 / -4,137` (4 of 4 negative), `34 of 34` 12m windows negative; `WEEK` net `-$13,487.59` (`-$13,488`). | **CONFIRMED** |
| `memo:33` | `23 Oct - 4 Nov`, `$500 day on 4 Nov`, `D ... at $490` | `HANDOFF:9181, 9186, 9201-9202`; `two-arm-viability:190` | E attached `23 Oct`, breached `$500` daily loss on `4 Nov` (`-$505.35`); D reached `$489.57` (`~$490`) by FTMO's count on `4 Nov`. | **CONFIRMED** |
| `memo:35-37` | `+$231`, `Aug - 23 Oct 2026 on bars gives +$180`, `46 months`, `-$6,358` | `longrun/results.md:37-38, 66`; `cont_*.json:1` | In `cont_*.json`, month-end equity at `2026-07` is `-$6,537.54` and at `2026-10` (`23 Oct`) is `-$6,357.57`; difference = `+$179.97` (`+$180`). Note (`memo:36, 81`): `sweep11` (`+$230.64`) was `3 Aug - 25 Sep` (8 calm weeks) + `1-20 Oct` (~3 weeks) = **about 11 weeks**, whereas `Aug - 23 Oct 2026` is **about 12 weeks** (`results.md:38` says `about the same twelve weeks`, `t3_drawdown/results.md:24` says `about 11 weeks`). | **GAP** |
| `memo:41, 44` | `24 Oct`, `+$1,087 in 46 months` | `t3_drawdown/results.md:5`; `nocarry/results.md:39, 47` | From `nocarry/results.md:39`: `scalps (+113,204) + rolled (-111,366) + open (-751) = +1,087`, or `net (-6,358) - commission (-7,445) = +1,087`. From `CONT_*.json` unrounded parts: `113,204.21 - 111,366.09 - 750.71 = +1,087.41` (`net_unrounded - comm = -6,358.1336 - (-7,445.04) = +1,086.91`). | **CONFIRMED** |
| `memo:45` | `31 Oct` | `longrun/results.md:3, 8` | Operator quote dated 31 Oct 2026. | **CONFIRMED** |
| `memo:49` | `+$15k`, `01:00 restart`, `$79k` roll losses, `$108k` cut losses | `nocarry/results.md:39, 41, 43, 46` | Scalps: `DAY (+128,631) - CONT (+113,204) = +$15,427` (`+$15k`; exact from `JSON`: `128,631.28 - 113,204.21 = +$15,427.07`). Rolled losses reduced by: `CONT (-111,366) - DAY (-32,259) = -$79,107` (`$79k`; exact `111,366.09 - 32,258.61 = $79,107.48`). Cut losses in `DAY`: `-$107,860` (`$108k`; exact `-$107,859.70`). | **CONFIRMED** |
| `memo:50` | `-$11,487` before commission | `nocarry/results.md:41, 47` | From `nocarry/results.md:41`: `scalps (+128,631) + rolled (-32,259) + cut (-107,860) = -11,488`, or `net (-22,711) - commission (-11,224) = -11,487`. From `DAY_*.json` summed parts: `128,631.28 - 32,258.61 - 107,859.70 = -$11,487.03` (`net - comm = -22,710.81 - (-11,223.78) = -$11,487.03`). | **CONFIRMED** |
| `memo:58` | `1514264399 (trial 1)`, `12-25 Aug`, `+$52.31`, `-$39.84` | `FULL_TRIAL_RECORD_1514264399.md:3, 28, 37, 86` | `12-25 Aug 2026`; final balance `$10,052.31 (+$52.31 realized vs $10k)`; final equity `$9,960.16` -> `$9,960.16 - $10,000.00 = -$39.84` (or `+$52.31 - $92.15 = -$39.84`); `TRIAL MIX: TREND=0, CHURN=10`. | **CONFIRMED** |
| `memo:59` | `1514582088 (trial 2, 16 instances)`, `10-23 Sep`, `-$505.34 at 13:51Z 23 Sep` | `FULL_TRIAL_RECORD_1514582088.md:3, 8, 24-26, 41` | `16 instances (8 pairs x OPT/ALT)`, `10-23 Sep 2026`, `-$505.34` at `13:51Z on 23 Sep`. | **CONFIRMED** |
| `memo:60` | `1515045375 (trial 3, E, t3)`, `23 Oct - 4 Nov`, `-$505.35 at 01:36:55Z 4 Nov`, `$9,746.75 from $10,000` | `e_week1/PREREG.md:37`; `HANDOFF:9181, 9186-9188` | Account `1515045375`; ran `23 Oct - 4 Nov`; closed `01:36:55-56Z 4 Nov`; day-start balance `$10,252.10` to close-out balance `$9,746.75` = `-$505.35` (`$10,252.10 - $9,746.75 = $505.35`), starting from `$10,000` initial trial balance. | **CONFIRMED** |
| `memo:63-64` | `about $330 of the $500 on 23 Sep`, `$380 on 4 Nov (E)` | `FULL_TRIAL_RECORD_1514582088.md:68, 78`; `HANDOFF:9186-9187` | Trial 2: `Equity then was about -$330 below it` (`-331` vs day-start balance, `-332` open MTM at `00:00Z`). Trial 3 (E): day-start balance `$10,252.10` less day-start equity `$9,871.67` = `$380.43` (`~$380`). | **CONFIRMED** |
| `memo:65` | `-$471 to -$1,163`, `1,181 of 1,191 FTMO days reach $500` | `longrun/results.md:57`; `nocarry/results.md:19, 56-58` | Across the 46 month-end marks in `CONT_*.json`, summed open MTM ranges from `-$1,162.74` (`2025-07`) to `-$470.69` (`2023-03`); `1,181 of 1,191` FTMO days reach `$500` or worse. | **CONFIRMED** |
| `memo:66` | `24 Oct` | `t3_drawdown/results.md:3, 30-32` | `24 Oct 2026` analysis showed `$626.51` FTMO-day loss on `16 Oct`. | **CONFIRMED** |
| `memo:68-69` | `3 days at $500 or worse`, `April 2025's tariff week`, `$23 a trading day`, `69 breaches` | `nocarry/results.md:19, 61-64`; `selfcheck_out.txt:7-12` | `DAY`: 3 days `>= $500` (`3 Apr $660, 4 Apr $826, 10 Apr $658` in Apr 2025); `-$22,710.81 / 989` cut nights = `-$22.963/day` (`about $23 a trading day`); `WEEK`: `69` days `>= $500`. | **CONFIRMED** |
| `memo:71-72` | `30 Oct`, `C +$77, D -$21, E -$4`, `4 Nov ($490 by FTMO's count)` | `HANDOFF:9078-9079, 9201-9202` | To Fri `30 Oct`: `C OPT +$45 / ALT +$31 (total +$77), D OPT -$81 / ALT +$61 (-$21), E OPT -$27 / ALT +$23 (-$4)`. On `4 Nov`: D's 23:00Z balance `$9,951.94` less 03:02Z equity low `$9,462.37` = `$489.57` (`$490`). | **CONFIRMED** |
| `memo:77` | `cap 7` | `longrun/results.md:7, 28` | `cap 7` in `t3`. | **CONFIRMED** |
| `memo:81` | `+$180 against +$231 over the same twelve weeks` | `longrun/results.md:37-38` | Same window precision point as `memo:36`: `+$180` (`Aug - 23 Oct 2026`, ~12 weeks) vs `+$231` (`3 Aug - 25 Sep` + `1-20 Oct`, ~11 weeks / 54 trading days). | **GAP** |
| `memo:94` | `0.01 lots`, `$1,000 a month`, `11 x`, `$500` | `t3_drawdown/results.md:24, 31-33` | `$230.64` over ~11 weeks (`2.543` months) = `$90.69/month`; `$1,000 / $90.69 = 11.03x` (`about 11 x`). | **CONFIRMED** |
| `memo:95` | `31 Oct (HANDOFF s92 continued 10)` | `HANDOFF:9074, 9101` | BMO listed in `s92 continued, 10` (`NEXT SESSION` item 3, 31 Oct). | **CONFIRMED** |
| `memo:103-104` | `97-100%`, `timing 1` | `replay-calibration-eurusd-4.md:51-52, 173-175` | Seen calibration `98.8 / 98.3 / 97.3%`, seen holdout `100.0% x 3` (`97.3-100.0%`, rounds to `97-100%`); unseen plan-4 window `98.2 / 99.1 / 99.2%`. | **CONFIRMED** |
| `memo:107` | `+$33,162`, `31 Oct`, `v3.1` | `longrun/results.md:3, 33-35`; `cluster/results.md:11, 64` | `--fill market` gave `+$33,162`, withdrawn `31 Oct`; Osler `v3.1` failed null check (`2 of 20`) before any real number was read. | **CONFIRMED** |
| `memo:109-110` | `four fleets`, `C165: a sixty-fold drop at the 1 Nov open`, `three full trial records` | `HANDOFF:9110-9111` | Four fleets (B, C, D, E); at 1 Nov open, E's first-hour API count dropped from `1,089` (25 Oct) to `17` (`1,089 / 17 = 64.06x`, `"a sixty-fold drop"` in `HANDOFF:9111`). Note on `"three full trial records"`: see Items 7 and 8 (only two `docs/FULL_TRIAL_RECORD_*.md` files exist; Trial 3 is in `HANDOFF s93`). | **CONFIRMED** |
| `memo:114-116` | `~465 a minute`, `~57,000 in all`, `95 layers` | `HANDOFF:9144-9145, 9175, 9181, 9190` | `~465 requests a minute (the terminal count 57,965 at 03:48Z)`, `~57,000 requests in all`, `95 layers`. | **CONFIRMED** |
| `memo:118` | `3-4 Nov` | `HANDOFF:9176, 9200-9204` | Move ran overnight Tue 3 Nov into Wed 4 Nov UTC. | **CONFIRMED** |

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:9` `| What the pre-registered rule says | `research/nocarry/PREREG.md` s6, fixed 7 Nov before any run: NO EDGE means **this memo says the project stops**. It does. The decision is the operator's (s6). |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:15` `EURUSD OPT, add = exit = 7 pips, cap 7 (`research/longrun/results.md` s1). In a range the stack fills and exits over`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:16` `and over: each close +7 pips, $0.70 less $0.06. Then price falls 60 pips and does not come back that week: the long`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:18` `closes at a loss of tens of pips (40 pips = -$4.00). Thirty small wins pay for one roll. Over four years EURUSD OPT`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:19` `scalped +$22,096 and paid -$23,314 in rolled closes. Close the book every night instead and the same losers are paid`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:26` `| 22 Oct | sweep9: EURUSD surface, 1-20 Oct, OPT against every wide arm by day | **no geometry MEANINGFUL** by the daily rule; over the period every add >= 14 positive | in |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:27` `| 22 Oct | sweep10: E's other five pairs | OPT + ALT **negative on all five**; the offset on 2 of 5 | out (of EURUSD) |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:28` `| 23 Oct | sweep11: t3 built, OPT add from the calm weeks, ALT add from October | **+$231** over both periods, six pairs at 0.01 lots; three picks made after the nets were read | in |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:29` `| 24 Oct | `research/t3_drawdown/`: t3 through October at 0.01 lots | about $91 a month; commission 84% of gross in October; **breaches FTMO's $500 day on 16 Oct** | in |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:30` `| 26-27 Oct | Osler round numbers; the magnet grid | **NONE; NONE** (pre-registered) | out |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:31` `| 31 Oct | `research/longrun/`: t3 continuous, 2 Jan 2023 - 23 Oct 2026 | **-$6,358** (OPT -$7,158, ALT +$800); three of four years lose; 27 of 34 twelve-month windows negative | out |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:32` `| 8 Nov | `research/nocarry/`: flat every night (DAY) or weekend (WEEK) | **NO EDGE** (pre-registered): DAY -$22,711, every year negative, 34 of 34 windows negative; WEEK -$13,488 | out |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:33` `| 23 Oct - 4 Nov | live: E (FTMO trial) beside D, C, B (IC Markets demos) | E's trial **ended on the $500 day** on 4 Nov; D the same move at $490 (s4) | out |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:35` `Everything in sample said "maybe"; everything out of sample said no. The +$231 of sweep11 is the in-sample fit the`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:36` `four years were run to check: the same set over Aug - 23 Oct 2026 on bars gives +$180, consistent with it; over all`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:37` `46 months it gives -$6,358.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:44` `  scalps and rolled losses nearly cancel on every pair; before commission the twelve made +$1,087 in 46 months.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:49` `  night, the grid scalps more (+$15k, a fresh straddle at every 01:00 restart) but turns $79k of roll losses into`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:50` `  $108k of cut losses. Before commission DAY is -$11,487. Overnight, carried layers were winning part of it back.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:58` `| 1514264399 (trial 1) | 12-25 Aug | expired: balance +$52.31, equity -$39.84 (no trend day in the trial) | `docs/FULL_TRIAL_RECORD_1514264399.md` |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:59` `| 1514582088 (trial 2, 16 instances) | 10-23 Sep | **the $500 daily loss**: -$505.34 at 13:51Z 23 Sep | `docs/FULL_TRIAL_RECORD_1514582088.md` |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:60` `| 1515045375 (trial 3, E, t3) | 23 Oct - 4 Nov | **the $500 daily loss**: -$505.35 at 01:36:55Z 4 Nov; balance $9,746.75 from $10,000 | HANDOFF s93 |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:63` `  balance, and the carried book's open loss is spent before the day begins: about $330 of the $500 on 23 Sep (trial`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:64` `  2's record s3), **$380** on 4 Nov (E). The four years show this as the steady state, not bad luck: carried, the`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:65` `  twelve hold -$471 to -$1,163 open at every month end, and 1,181 of 1,191 FTMO days reach $500 by FTMO's count`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:68` `- **Flat every night the grid is FTMO-safe** (3 days at $500 or worse in four years, all in April 2025's tariff week)`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:69` `  **and loses about $23 a trading day.** Flat over weekends (FTMO's Standard funded rule): 69 breaches, and it loses.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:71` `- **The fleets to 30 Oct** (pipshed's per-arm split, HANDOFF s92 continued 10): C +$77, D -$21, E -$4. D took the`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:72` `  same move as E on 4 Nov ($490 by FTMO's count) and ran on, as an IC demo has no daily limit. Two live weeks prove`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:81` `- **Bars, not ticks** over the four years (checked against the tick replay: +$180 against +$231 over the same twelve`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:82` `  weeks); **no swap** anywhere (it would lower CONT and WEEK further); one feed (FTMO's).`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:94` `| C. Real money, or scale | None found. | Every out-of-sample P&L test loses; at 0.01 lots $1,000 a month would need about 11 x the size and still breach FTMO's day (`research/t3_drawdown/`). |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:103` `- **A validated tick replay** of the EA's mechanics (`replay-plan4`: the T1 event-match score 97-100% on the calibration`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:104` `  and holdout windows at timing 1, `docs/research/replay-calibration-eurusd-4.md`),`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:107` `  before results. It caught the bar-fill flaw (+$33,162 of false profit, withdrawn 31 Oct) and v3.1 of the Osler test`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:110` `  solved (C165: a sixty-fold drop at the 1 Nov open), and three full trial records.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:114` `- **E's request storm** (HANDOFF s93): after FTMO closed the account, every instance re-sent refused orders every tick`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:115` `  (~465 a minute, ~57,000 in all); nothing in the EA tests `TRADE_RETCODE_TRADE_DISABLED`. Matters only if any fleet`
  - `research/longrun/results.md:14` `EURUSD OPT, add = exit = 7 pips, cap 7. Price ranges 1.1600 - 1.1630 for a day: the stack fills and exits over and over,`
  - `research/longrun/results.md:15` `each close +7 pips ($0.70 less $0.06). Then price falls 60 pips and does not come back that week: the long side fills`
  - `research/longrun/results.md:17` `7 pips, a rolled layer's exit fills: it closes at a loss of tens of pips (40 pips = -$4.00), realised. Thirty small wins pay`
  - `research/longrun/results.md:18` `for one such roll. Over four years EURUSD OPT collected +$22,096 in scalps and paid -$23,314 in rolled closes.`
  - `research/longrun/results.md:33` `  tick replay on all 12 cells, both the calm weeks and October), the DOLLARS were not: +$33,162 over the four years.`
  - `research/longrun/results.md:37` `  **Check against the tick replay:** Aug - 23 Oct 2026 the limit-fill run gives **+$180**; the tick replay of the same`
  - `research/longrun/results.md:38` `  set (sweep11, t3, about the same twelve weeks, IC's ticks) gave **+$231**. They agree; the market-fill run did not.`
  - `research/longrun/results.md:44` `| EURUSD | -3,418 | +22,096 | -23,314 | +109 | +7,673 | -7,235 |`
  - `research/longrun/results.md:50` `| **total** | **-7,158** | | | **+800** | | |`
  - `research/longrun/results.md:54` `- **By year (both arms):** 2023 -$2,232; 2024 -$3,113; 2025 -$1,887; 2026 to 23 Oct +$876.`
  - `research/longrun/results.md:56` `  27 of 34 twelve-month windows (79%); the worst twelve months -$4,599; peak to trough -$7,854.`
  - `research/longrun/results.md:57` `- **The open book stays bounded:** -$751 at the end, between -$471 and -$1,163 at every month end. The cap and`
  - `research/t3_drawdown/results.md:24` `- **Both periods: about $91 a month** (sweep11's +$230.64 over about 11 weeks; in-sample adds).`
  - `research/t3_drawdown/results.md:25` `- **Commission / gross: calm 38% ($133.80 of $348.85); October 84% ($88 of $105).** The tight OPT arms paid most of it:`
  - `research/t3_drawdown/results.md:31` `  8 Oct; $626.51 on the FTMO day ending 16 Oct 22:00Z.** At 0.01 lots, t3 replayed through October breaches the`
  - `research/t3_drawdown/results.md:33` `- **Scaling cannot fix it:** the limit is crossed at 1 x; $1,000 a month needs about 11 x.`
  - `research/nocarry/results.md:16` `| 1. Net | -$6,358 | **-$22,711** | -$13,488 | > 0: **FAIL** |`
  - `research/nocarry/results.md:17` `| 2. Years 2023 / 2024 / 2025 / 2026 | -2,232 / -3,113 / -1,887 / +876 | **-5,679 / -5,535 / -7,361 / -4,137** | -4,125 / -3,903 / -4,434 / -1,025 | 3 of 4 > 0: **FAIL (0 of 4)** |`
  - `research/nocarry/results.md:18` `| 3. Twelve-month windows negative | 27 of 34 | **34 of 34** | 34 of 34 | at most 16: **FAIL** |`
  - `research/nocarry/results.md:19` `| 4. FTMO days of $500 or worse | 1,181 of 1,191 | **3** | 69 | at most 4: pass |`
  - `research/nocarry/results.md:39` `| CONT | +113,204 | -111,366 | 0 | -751 | -7,445 | **-6,358** | +1,087 |`
  - `research/nocarry/results.md:40` `| WEEK | +125,938 | -69,846 | -60,746 | 0 | -8,834 | **-13,488** | -4,654 |`
  - `research/nocarry/results.md:41` `| DAY | +128,631 | -32,259 | -107,860 | 0 | -11,224 | **-22,711** | -11,487 |`
  - `research/nocarry/results.md:43` `- The scalps are real in every arm, and DAY earns the most of them (+$15k on CONT): each 01:00 restart places fresh`
  - `research/nocarry/results.md:46` `  night (DAY). DAY turns $79k of CONT's roll losses into $108k of cut losses. A layer cut at 23:45 has no night to`
  - `research/nocarry/results.md:61` `- **Flat every night, the grid is FTMO-safe and loses steadily.** DAY: 3 days at $500 or worse in four years, all in`
  - `research/nocarry/results.md:62` `  the tariff week of April 2025 (3 Apr $660, 4 Apr $826, 10 Apr $658); next worst 5 Aug 2024 $490, 9 Apr 2025 $431,`
  - `research/nocarry/results.md:63` `  14 Nov 2023 $401. It pays for that safety at about **$23 a trading day** (-$22,711 over 989 nights).`
  - `research/nocarry/results.md:64` `- **Flat every weekend** (FTMO's actual Standard-account rule): 69 days at $500 or worse; worst 4 Apr 2025 $1,660.`
  - `docs/FULL_TRIAL_RECORD_1514264399.md:28` `FTMO Free Trial, 2-Step, Swing, $10k. Start 12 Aug -> End 25 Aug 2026 (expired;`
  - `docs/FULL_TRIAL_RECORD_1514264399.md:37` `TRIAL MIX: TREND=0, CHURN=10, MIXED=0.`
  - `docs/FULL_TRIAL_RECORD_1514264399.md:86` `  Final balance $10,052.31 (+$52.31 realized vs $10k). Final equity $9,960.16`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:8` `      Daily Loss (-$505.34 against -$500) at 13:51Z on 23 Sep. No ruling`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:24` `| Type | FTMO Free Trial, Swing, $10,000, 16 instances (8 pairs x OPT/ALT) |`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:25` `| Start / end | 10 Sep / 23 Sep (ended by breach, the day it was due to expire) |`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:68` `$10,190.96. Equity then was about -$330 below it: the open book carried`
  - `handoffs/HANDOFF_2026-09-24.md:9078` `- **Per-arm split (pipshed scalps and live MTM, 28 and 31 Oct):** to Friday 30 Oct's close, C OPT +$45 / ALT +$31 (total`
  - `handoffs/HANDOFF_2026-09-24.md:9079` `  +$77), D OPT -$81 / ALT +$61 (-$21), E OPT -$27 / ALT +$23 (-$4); D's OPT scalped +$640 and paid -$529 in rolls and`
  - `handoffs/HANDOFF_2026-09-24.md:9110` `  **first hour E 17 (25 Oct: 1,089), D 60, B 29, C 13; first five hours E 41, D 149, B 106, C 24** (25 Oct's night: E`
  - `handoffs/HANDOFF_2026-09-24.md:9111` `  1,685 in two hours, D 3,384, B 1,908). C165 works; a calmer open cannot explain a sixty-fold drop on all four. **C165`
  - `handoffs/HANDOFF_2026-09-24.md:9181` `- **01:36:55-56Z 4 Nov: FTMO closed all 95 positions in ~1.5 s** (95 deals "based on order #576878989, ...":`
  - `handoffs/HANDOFF_2026-09-24.md:9186` `- **Why: the trial's $500 daily loss.** FTMO's day from 23:00Z 3 Nov: balance $10,252.10 (floor $9,752.10); equity`
  - `handoffs/HANDOFF_2026-09-24.md:9187` `  $9,871.67, the carried book -$391 using **$380.43 of the $500 before the day began**. Scalps +$41.68; the book to`
  - `handoffs/HANDOFF_2026-09-24.md:9188` `  -$523; equity $9,775.01 at 01:36:00Z; close-out balance **$9,746.75: loss $505.35**. The day before (FTMO 3 Nov)`
  - `handoffs/HANDOFF_2026-09-24.md:9190` `- **The storm: ~465 requests a minute** (the terminal count 57,965 at 03:48Z; the journal ~445 failed a minute,`
  - `handoffs/HANDOFF_2026-09-24.md:9201` `  the cap), AUDCAD longs to 7; EURGBP flat. D's open book -$367 (23:00Z) to -$509; equity low **$9,462.37 at 03:02Z`
  - `handoffs/HANDOFF_2026-09-24.md:9202` `  4 Nov**; counted as FTMO counts a day (from D's 23:00Z balance $9,951.94): **$489.57**. Closes 51 in the 01h hour.`
  - `docs/research/replay-calibration-eurusd-4.md:51` `  at timing 1 on both seen windows: holdout T1 100.0% x 3 (`results/plan4/holdout_score_8044284.md`),`
  - `docs/research/replay-calibration-eurusd-4.md:52` `  calibration T1 98.8 / 98.3 / 97.3% (`results/plan4/cal_score_8044284.md`). Nothing else in this file`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:9, 36, 81-82`):**
  - Line 9: replace `fixed 7 Nov before any run` with `fixed 7-8 Nov before any run`.
  - Line 36: replace `over Aug - 23 Oct 2026 on bars gives +$180` with `over Aug - 23 Oct 2026 on bars (about the same eleven-to-twelve weeks) gives +$180`.
  - Lines 81-82: replace `over the same twelve weeks` with `over about the same eleven-to-twelve weeks`.

---

### 2. Every quotation against its source, person, and date

- **Verdict:** **GAP** (all three quotes are verbatim and attributed to the right person and date; `memo:45` quotes the first clause of the operator's 31 Oct statement and says `confirmed`, whereas `research/longrun/results.md:65-70` confirmed the first clause and rejected the second clause)

| Memo line | Quoted text in memo | Attribution in memo | Source file & line | Exact check | Verdict |
|---|---|---|---|---|---|
| `memo:7` | `"if we cannot find a single geometry that uses an OPT/ALT and maybe even DUP arm that can at least stabilise in these last few weeks - then there is no future in this work."` | `The operator, 21 Oct` (`two-arm-viability-2026-10-21.md` s1) | `docs/research/two-arm-viability-2026-10-21.md:12, 30-31` | Character-for-character match to lines 30-31 (`21 OCT ~19:54-20:05Z`, the operator). | **CONFIRMED** |
| `memo:41-43` | `"we are seeing the expected results of running a short gamma strategy on a random walk ... squeezing the limited 'non random walk' part of the mkt action out - but that is eaten away by commission"` | `The operator's own reading (24 Oct, research/t3_drawdown/results.md)` | `research/t3_drawdown/results.md:5-7` | Character-for-character match to lines 6-7 (`operator, 24 Oct ~18:40-18:42Z`). | **CONFIRMED** |
| `memo:45` | `"we are just monetizing mtm winners"` | `(the operator, 31 Oct)` | `research/longrun/results.md:8, 65-70` | Exact substring of `results.md:8` (`The operator (31 Oct)`). However, the operator's sentence continued: `"conversely, we are super relaxed about mtm losses and confident that they will turn into winners."` In `results.md:65-70`, `"Not really earning"` was `TRUE`, while `"Relaxed about losses because they turn into winners"` was ruled **`NOT how the losses arrive`** (losses do not wait in the open book; they are realised through rolls on the partial bounce). `memo:45-47` explains the roll mechanism right after `confirmed`, so qualifying `confirmed` with `on the winners; losers do not wait in the open book, they are` aligns `memo:45` with `results.md:68`. | **GAP** |

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:7` `| Question | The operator, 21 Oct: "if we cannot find a single geometry that uses an OPT/ALT and maybe even DUP arm that can at least stabilise in these last few weeks - then there is no future in this work." (`docs/research/two-arm-viability-2026-10-21.md` s1) |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:41` `- **A short-gamma book on a near random walk.** The operator's own reading (24 Oct, `research/t3_drawdown/results.md`):`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:42` `  "we are seeing the expected results of running a short gamma strategy on a random walk ... squeezing the limited`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:43` `  'non random walk' part of the mkt action out - but that is eaten away by commission". The four years measure it:`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:45` `- **"we are just monetizing mtm winners" (the operator, 31 Oct): confirmed.** Winners are closed in hours, losers`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:46` `  held for days to weeks and then realised through rolls on the partial bounce. The loss is paid, in fewer and larger`
  - `docs/research/two-arm-viability-2026-10-21.md:12` `## 1. THE OPERATOR'S CONCERN, IN HIS WORDS (21 OCT ~19:54-20:05Z)`
  - `docs/research/two-arm-viability-2026-10-21.md:30` `> "if we cannot find a single geometry that uses an OPT/ALT and maybe even DUP arm that can at least stabilise in these`
  - `docs/research/two-arm-viability-2026-10-21.md:31` `> last few weeks - then there is no future in this work."`
  - `research/t3_drawdown/results.md:5` `**Why (operator, 24 Oct ~18:40-18:42Z):** "Having a strategy that makes less than $100 a month isnt very impressive";`
  - `research/t3_drawdown/results.md:6` `"we are seeing the expected results of running a short gamma strategy on a random walk ... squeezing the limited 'non`
  - `research/t3_drawdown/results.md:7` `random walk' part of the mkt action out - but that is eaten away by commission". Measures fixed in chat before`
  - `research/longrun/results.md:8` `| Why asked | The operator (31 Oct): "I feel that we are not really earning, we are just monetizing mtm winners - fearful that the gains will be given back. conversely, we are super relaxed about mtm losses and confident that they will turn into winners." |`
  - `research/longrun/results.md:65` `- **"Not really earning": TRUE.** Scalps and rolled losses nearly cancel pair by pair (s3); commission tips OPT clearly`
  - `research/longrun/results.md:68` `- **"Relaxed about losses because they turn into winners": NOT how the losses arrive.** They do not wait in the open`
  - `research/longrun/results.md:69` `  book; they are realised through rolls, on the partial bounce after a move. The loss is real and paid, in fewer and`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:45-46`):**
  - Replace `- **"we are just monetizing mtm winners" (the operator, 31 Oct): confirmed.** Winners are closed in hours, losers held for days to weeks and then realised through rolls on the partial bounce.` with `- **"we are not really earning, we are just monetizing mtm winners" (the operator, 31 Oct): confirmed (while losers do not wait in the open book: they are held for days to weeks and realised through rolls on the partial bounce).**`

---

### 3. `s2`'s table labels and `"Everything in sample said 'maybe'; everything out of sample said no"`

- **Verdict:** **DEFECT**

#### 3.1 Audit of `s2`'s "in or out of sample" column (`memo:26-33`)

| Row (`memo` line) | Test | Memo label | Fair against `two-arm-viability` s8 and `longrun/results.md` s2, s6? | Verdict |
|---|---|---|---|---|
| `memo:26` | `sweep9`: EURUSD surface, 1-20 Oct | `in` | Fair: `t1` ALT adds (`23 / 27`) were fitted on 1-16 Oct (`two-arm-viability:152`, `sweep_notes.md:645`), and the `18-20` band was read from this surface (`two-arm-viability:126, 173-175`). | **CONFIRMED** |
| `memo:27` | `sweep10`: E's other five pairs | `out (of EURUSD)` | **Partly in-sample:** the `q88` rule was transferred from EURUSD without retuning per pair (`two-arm-viability:174-178`), **but `q88` for each of those five pairs was fitted on D's fills of `1-16 Oct` inside the `1-20 Oct` test window** (`sweep_notes.md:723`: `q88 was fitted on D's fills of 1-16 Oct (in-sample)`). | **GAP** |
| `memo:28` | `sweep11`: `t3` built | `in` | Fair: OPT adds selected on the 8 calm weeks and ALT adds on 1-20 Oct, plus 3 post-hoc picks (`two-arm-viability:186-190`, `sweep_notes.md:844, 877`). | **CONFIRMED** |
| `memo:29` | `research/t3_drawdown/` | `in` | Fair: descriptive read of `sweep11`'s in-sample cells on the same calm and October data (`t3_drawdown/results.md:16-18, 24`). | **CONFIRMED** |
| `memo:30` | Osler; magnet grid | `out` | Fair: pre-registered on 2023-26 M1 bars (`cluster/results.md:3, 9`, `magnet/results.md:3`). | **CONFIRMED** |
| `memo:31` | `research/longrun/`: `t3` continuous, 2 Jan 2023 - 23 Oct 2026 | `out` | **Mostly out-of-sample (`43.5 of 46 months`):** `Jan 2023 - Jul 2026` is strictly out of sample for `t3`, while `Aug - 20 Oct 2026` (`~2.5 months`, `+$180` on bars) is the time window on which `t3`'s adds were chosen in `sweep11` (`longrun/results.md:37-38`). | **GAP** |
| `memo:32` | `research/nocarry/`: DAY / WEEK | `out` | Fair (same 43.5 of 46 months out of sample, and `DAY`/`WEEK` were never used to select `t3`). | **CONFIRMED** |
| `memo:33` | Live: E beside D, C, B (`23 Oct - 4 Nov`) | `out` | Fair: strictly out-of-sample live forward test (`two-arm-viability:7, 194-195`). | **CONFIRMED** |

#### 3.2 Is `"Everything in sample said 'maybe'; everything out of sample said no."` (`memo:35`) true of every row?

No -- it is **false in both directions (`DEFECT`)**:
1. **In sample did NOT say only `"maybe"`:**
   - Row 4 (`memo:29`, `research/t3_drawdown/`, labeled `in`) said **no** on FTMO survival: at 0.01 lots `t3` **`breaches FTMO's $500 day on 16 Oct`** (`$626.51`, and over `$300` on 11 of 20 days from 8 Oct; `t3_drawdown/results.md:30-32`).
   - Row 1 (`memo:26`, `sweep9`, labeled `in`) said **no** on its pre-registered daily rule (`**no geometry MEANINGFUL** by the daily rule`; `two-arm-viability:142-145`).
2. **Out of sample did NOT say `"no"` on every row or arm:**
   - In Row 6 (`memo:31`, `research/longrun/`), **ALT was `+$800`** over the four years (`research/longrun/results.md:7, 50`), positive on 4 of 6 pairs (`AUDCAD +$876, EURGBP +$565, CADCHF +$185, EURUSD +$109`), **AUDCAD was positive on both arms (`OPT +$772, ALT +$876`)**, and the calendar year **`2026 to 23 Oct` was `+$876`** across all 12 instances (`results.md:44-50, 54`).
   - In Row 8 (`memo:33, 71`, live `23 Oct - 4 Nov`), **Fleet C (`t2`) was `+$77`** (`OPT +$45 / ALT +$31` to 30 Oct, `HANDOFF:9078-9079`) and stayed within `~$230` of its day-start balance on 4 Nov (`HANDOFF:9203`), and **ALT was positive on all three live two-arm fleets to 30 Oct (`C +$31, D +$61, E +$23`)**.

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:27` `| 22 Oct | sweep10: E's other five pairs | OPT + ALT **negative on all five**; the offset on 2 of 5 | out (of EURUSD) |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:31` `| 31 Oct | `research/longrun/`: t3 continuous, 2 Jan 2023 - 23 Oct 2026 | **-$6,358** (OPT -$7,158, ALT +$800); three of four years lose; 27 of 34 twelve-month windows negative | out |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:35` `Everything in sample said "maybe"; everything out of sample said no. The +$231 of sweep11 is the in-sample fit the`
  - `research/replay/results/sweep_notes.md:723` `crosses; 17-20 Oct swaps from the 16 Oct rate; q88 was fitted on D's fills of 1-16 Oct (in-sample); P&L is outside plan`
  - `docs/research/two-arm-viability-2026-10-21.md:142` `**8.1 By s5's rule: no geometry is MEANINGFUL** (`research/replay/results/sweep_notes.md`, sweep9 RESULT;`
  - `docs/research/two-arm-viability-2026-10-21.md:174` `q88. **The operator: q88 on all six** (ALT add = exit 21, 18, 16, 26, 20, 9; `ea/presets_e/*_alt_e_t2.set`), chosen to`
  - `docs/research/two-arm-viability-2026-10-21.md:175` `land EURUSD in the band (in-sample; (B) checks the other five).`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:27, 31, 35`):**
  - Line 27: replace `| out (of EURUSD) |` with `| out of EURUSD (q88 fit on 1-16 Oct) |`.
  - Line 31: replace `| out |` with `| out (Jan 2023 - Jul 2026; Aug-Oct in) |`.
  - Line 35: replace `Everything in sample said "maybe"; everything out of sample said no.` with `In sample, P&L said "maybe" (+$231) while FTMO's daily limit already failed ($626.51 on 16 Oct); out of sample, every fleet-level test of t3 said no (ALT alone made +$800 over the four years, ~$17/month before swap, and lost under DAY and WEEK).`

---

### 4. Balance (evidence FOR the grid in the sources that is missing or understated)

- **Verdict:** **GAP** (none of the seven items changes the conclusion, but stating the key ones explicitly prevents the memo from understating the counter-arguments)

| # | Evidence FOR the grid in the sources | Where in sources | How treated in the memo | Does its absence change the conclusion? |
|---|---|---|---|---|
| 1 | **`CONT` ALT (`+$800.26`) was positive on 4 of 6 pairs (`AUDCAD +$876, EURGBP +$565, CADCHF +$185, EURUSD +$109`), in 3 of 4 calendar years (`2023 +$317.48, 2024 -$356.74, 2025 +$259.93, 2026 +$579.59`), and in 20 of 34 twelve-month windows (`14 of 34` negative).** | `longrun/results.md:44-50, 66`; `nocarry/out/CONT_*.json:1` | `memo:31` mentions `ALT +$800`, but omits that ALT was positive on 4 of 6 pairs, 3 of 4 years, and 20 of 34 twelve-month windows, and `s3` only quotes `+$1,087` for the 12 together. | **No.** `+$800.26` over 46 months across 6 pairs is `~$17/month` **before swap** (`longrun/results.md:66, 83`), while losing ALT layers are held for median `190-790 h` (`results.md:63-64`); in `CONT_*.json`, `alt6`'s month-end open book reaches `-$693.82` and is `<= -$500` on **23 of 46 month-ends**; and under `DAY` (`-$6,162`) and `WEEK` (`-$2,671`) `alt6` loses in all 4 years and 34 of 34 windows (`nocarry/results.md:28-29`). |
| 2 | **AUDCAD was positive on both arms in `CONT` (`OPT +$772, ALT +$876`, total `+$1,648`), and ALT was positive under `WEEK` on AUDCAD (`+$171.03`) and EURGBP (`+$62.55`).** | `longrun/results.md:46-47`; `nocarry/out/WEEK_AUDCAD.json:1`, `WEEK_EURGBP.json:1` | Omitted (`memo:44` says `scalps and rolled losses nearly cancel on every pair`, and `nocarry/results.md:29` notes `under CONT five of twelve made money`). | **No.** Picking 1 of 6 pairs (`~$36/month` before swap) post hoc out of 6 pairs is data-snooping, and under `DAY` all 12 instances (including AUDCAD OPT `-$1,019` and ALT `-$581`) lose (`nocarry/results.md:29`). |
| 3 | **`2026 to 23 Oct` was `+$876` in `CONT` (`OPT +$296, ALT +$580`).** | `longrun/results.md:54`; `nocarry/results.md:17` | `memo:31` says `three of four years lose` without naming that the positive year was the most recent one (`2026 to 23 Oct: +$876`). | **No.** `2026 to 23 Oct` includes the `Aug - Oct 2026` (`+$180`) in-sample window on which `t3` was selected, follows three losing years (`-$2,232, -$3,113, -$1,887`), and is `-$4,137` under `DAY` and `-$1,025` under `WEEK` (`nocarry/results.md:17`). |
| 4 | **`sweep9` s8.2's period-level offset (`add >= 14` positive across the whole `14-27` band on EURUSD, `OPT + ALT` positive in both calm and October) and `swcap` (25 Oct: OPT cap 9 `CONFIRMED` on the harness at `+$336.00` vs `+$230.64`).** | `two-arm-viability:147-152`; `sweep_notes.md:633-642, 938-945` | `memo:26` notes `over the period every add >= 14 positive`, but omits `two-arm-viability:150-152` (positive in both regimes on EURUSD across a broad band) and completely omits `swcap` (`CONFIRMED` on 25 Oct). | **No.** `sweep10` showed EURUSD's period-level offset failed to carry to the other 5 pairs (`OPT + ALT` negative on all 5), and `swcap` was on the same 11-week window and **increased** FTMO `$500`-day breaches in October from `3` to `5` (`$638.94` worst day, `sweep_notes.md:939-945`). |
| 5 | **Trial 1 (`1514264399`) earned `+$72.91` net grind from 264 scalps (`~10%` commission drag) before 4 early startup forced-close bugs (`~-$13`), ending at `+$52.31` realized balance.** | `FULL_TRIAL_RECORD_1514264399.md:47-51, 86, 98-101` | `memo:58` records `balance +$52.31, equity -$39.84 (no trend day in the trial)`, omitting `+$72.91` net grind. | **No.** Even in 10/10 churn days with zero trend days, Trial 1 held `-$92.15` of un-reverted EURUSD shorts at expiry (`equity -$39.84`), which is the exact MTM vs banked-scalps divergence measured over the 4 years. |
| 6 | **Fleet C (`t2`, 3 pairs, OPT cap 9 / ALT cap 7) was `+$77` (`OPT +$45 / ALT +$31`) to 30 Oct and survived 4 Nov with `~$230` max day loss; and live ALT was positive on all three two-arm fleets to 30 Oct (`C +$31, D +$61, E +$23`).** | `HANDOFF:9078-9079, 9083, 9155, 9203` | `memo:71` gives the fleet totals (`C +$77, D -$21, E -$4`) without the per-arm split (`ALT +$31, +$61, +$23`) or C's `~$230` max day loss on 4 Nov (`HANDOFF:9203`). | **No** for `t3` / C162 as a whole (two live weeks are one draw, and C trades 3 pairs at half the pair count), but `s4` (`memo:71-72`) should report the per-arm split and C's `~$230` on 4 Nov. |
| 7 | **The magnet test's main grid (`d 10, cap 8, rolls`) made `+$589.85` in H1 and `+$198.67` in H2 (and `d 15` made `+$1,068.70` and `+$506.05`) across 7 pairs on M1 bars.** | `magnet/results.md:22-27, 38-45` | `memo:30` and `memo:51-52` report `MAGNET: NONE` without mentioning that the fixed-anchor grids had positive net before swap in both halves. | **No.** As `magnet/results.md:38-45` states, those totals excluded swap on 55-57 underwater positions (`-$894 / -$904` open at half-end) and suffered `$1,280` (H1) and `$1,596` (H2) peak-to-trough drawdowns plus `$573.81` and `$601.35` FTMO-day breaches. |

- **Quotes (`origin/main`):**
  - `research/longrun/results.md:47` `| AUDCAD | +772 | +4,539 | -3,515 | +876 | +3,342 | -2,200 |`
  - `research/longrun/results.md:63` `  OPT 0.6 h against 13.6 h; GBPUSD OPT 0.7 against 17.8; AUDCAD OPT 8.8 against 165; ALT longer still (EURUSD 8.5`
  - `research/longrun/results.md:64` `  against 190 h; EURGBP 45 against 790 h).`
  - `research/longrun/results.md:66` `  negative; ALT, which pays far less commission, ends near zero (+$800 over 46 months, about $17 a month for six`
  - `research/nocarry/results.md:28` `- **OPT and ALT apart** (reported, not deciding): DAY OPT -$16,548, ALT -$6,162; WEEK OPT -$10,817, ALT -$2,671. All`
  - `research/nocarry/results.md:29` `  four NO EDGE; every year negative in each. Under DAY **all twelve instances lose**; under CONT five of twelve made money.`
  - `research/replay/results/sweep_notes.md:938` `**VERDICT: CONFIRMED.** Calm +$232.89 (t3 at cap 7: +$215.05), October +$103.11 (+$15.59): both +$336.00 against the`
  - `research/replay/results/sweep_notes.md:939` `rule's $276.77; October's largest FTMO-day loss $638.94 against the rule's $689.16 (cap 7: $626.51). Days over $300 /`
  - `research/replay/results/sweep_notes.md:940` `$500: 15 / 5 (cap 7: 11 / 3); max peak-to-trough $299.44 ($308.57). Per pair, calm OPT cap 9 / October OPT cap 9 (USD):`
  - `docs/FULL_TRIAL_RECORD_1514264399.md:47` `  NET grind $72.91 (264 scalps, 697.9 gross pips, gross $83.11, commission -$8.34`
  - `handoffs/HANDOFF_2026-09-24.md:9083` `  exactly 186); the operator: C's shape (few pairs, deep) the better frame.`
  - `handoffs/HANDOFF_2026-09-24.md:9203` `  An IC demo has no daily limit, so D ran on. C and B: never worse than ~$230 under their day-start balance.`
  - `research/magnet/results.md:38` `- **It made a little money in both halves** (+$590 over two years, +$199 over 22 months, seven pairs at 0.01 lots),`
  - `research/magnet/results.md:43` `- **Risk:** the worst FTMO day of the seven pairs together **$573.81 (5 Aug 2024)** and **$601.35 (4 Apr 2025)**, one`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:31, 44, 71-72`):**
  - Line 31: replace `three of four years lose; 27 of 34 twelve-month windows negative` with `2023-25 lose, 2026 +$876; 27 of 34 twelve-month windows negative (ALT alone +$800, 3 of 4 years > 0, ~$17/month before swap; AUDCAD +$1,648)`.
  - Line 44: after `before commission the twelve made +$1,087 in 46 months.` add `ALT alone kept +$800 after commission (~$17/month across six pairs before swap, holding losers 190-790 h with month-end open loss reaching -$694, and losing -$6,162 under DAY and -$2,671 under WEEK).`
  - Lines 71-72: replace `C +$77, D -$21, E -$4. D took the same move as E on 4 Nov ($490 by FTMO's count) and ran on` with `C +$77 (OPT +$45 / ALT +$31), D -$21 (-$81 / +$61), E -$4 (-$27 / +$23). On 4 Nov D took the same move as E ($490 by FTMO's count; C and B never worse than ~$230) and ran on`.

---

### 5. Stretch (`s3`, `s4`, `s5`, `s7`) and completeness of `s5`

- **Verdict:** **GAP**

1. **`s3` ("Carry is not the problem, and removing it makes things worse", `memo:48-50`):**
   - **Supported for overnight price-risk holding vs cutting flat:** `research/nocarry/results.md:39-47` shows that cutting flat at 23:45 (`DAY`) or Friday (`WEEK`) turns `$79k` of CONT's roll losses into `$108k` of cut losses (`DAY` gross `-$11,487` vs `CONT` gross `+$1,087`).
   - **Where wording could stretch:** In FX, "carry" also means **broker swap/financing carry**, which `memo:82` notes was **not charged** in `longrun` or `nocarry` (`no swap anywhere (it would lower CONT and WEEK further)`). Changing `"Carry is not the problem"` to `"Overnight holding is not the P&L problem"` avoids conflating overnight position holding with swap.
2. **`s4` ("Two of three trials ended on the daily loss, by one mechanism", `memo:59-66`):**
   - **The FTMO daily-loss accounting mechanism is the same** (`day-start balance - lowest equity`, where carried open MTM is spent before the day begins: `~$330` at `00:00Z` and `-$424` at liquidation on Trial 2, `$380.43` on Trial 3; `FULL_TRIAL_RECORD_1514582088.md:67-72, 99`, `HANDOFF:9186-9187`).
   - **Two qualifications needed so `s4` does not stretch:**
     a. Trial 2 (`1514582088`, `memo:59`) was **not `t3`**: it ran 16 instances across 8 pairs on build `5454358` (before re-roll and ADR-158), where `OPT and ALT held near-identical stacks, so every adverse move was paid twice` (`FULL_TRIAL_RECORD_1514582088.md:104-105, 134`).
     b. In `memo:65`, citing `1,181 of 1,191 FTMO days reach $500 by FTMO's count` alongside E's 2-week trial needs the parenthetical already in `research/nocarry/results.md:59-60` (`E had run weeks, not years; the backtest's book is older and larger`, and `CONT` never liquidates on a breach so a `- $471` to `- $1,163` open book is carried from day to day).
3. **`s5` scope and completeness (`memo:75-86`):**
   - **What `s5` covers well:** symmetric passive grid (`add = exit`, `cap 7`, lattice and re-roll, `t3` widths), bars vs ticks (`+$180` vs `+$231`), no swap, one feed (FTMO), and the desk-style overnight rule (pull adds at close, leave exits resting).
   - **Untested premises / biases recorded in the sources that `s5` omits (`GAP`):**
     a. **Asymmetric `exit != add` on the 4-year bars** (tested only on EURUSD's October ticks in `sweep9`, `sweep_notes.md:635`) and **OPT `cap 9` (`swcap`) on the 4-year bars** (`swcap` was `CONFIRMED` on the 11-week tick harness at `+$336.00` vs `+$230.64`, `sweep_notes.md:938`, but never run over the 4 years).
     b. **Bar-simulator simplifications recorded in `research/nocarry/PREREG.md:107-116`:** the bar's `spread` field may be the minute's lowest spread (flattering all fills alike); weeks under `4,000` bars (10 holiday-short weeks in 4 years) are skipped; and `sim.py` omits `Grind_LatticeRerollPaused` (`23:50-00:15` server).
4. **`s7` claims about the replay and C165 (`memo:103-105, 110`):**
   - **Replay (`memo:103-104`):** `docs/research/replay-calibration-eurusd-4.md:180-181` validated `replay-plan4` specifically **`for count-level use on EURUSD in markets without a scheduled-release burst`**, and `two-arm-viability-2026-10-21.md:127` explicitly notes **`P&L is outside plan 4's validated counts (a guide)`**. Also, `97-100%` (`97.3-100.0%`, `replay-calibration-eurusd-4.md:51-52`) was the development check on the two seen windows, while the **unseen plan-4 blind window (`s10`, lines 173-175) scored `98.2-99.2%`**.
   - **C165 (`memo:110`):** `"a sixty-fold drop at the 1 Nov open"` is exact for E's first hour (`1,089` on 25 Oct vs `17` on 1 Nov = `64.1x`, `HANDOFF:9110-9111`).

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:48` `- **Carry is not the problem, and removing it makes things worse** (`research/nocarry/results.md` s2): flat every`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:65` `  twelve hold -$471 to -$1,163 open at every month end, and 1,181 of 1,191 FTMO days reach $500 by FTMO's count`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:77` `- It tests the **symmetric passive grid** as built: OPT and ALT arms, add = exit, cap 7, the lattice and re-roll, at`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:78` `  E's t3 widths. sweep9-11 covered the add / exit surface on October's ticks; the four years cover t3 only. A`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:103` `- **A validated tick replay** of the EA's mechanics (`replay-plan4`: the T1 event-match score 97-100% on the calibration`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:104` `  and holdout windows at timing 1, `docs/research/replay-calibration-eurusd-4.md`),`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:99` `| **total** | **-424 (84%)** | **-81** |`
  - `docs/FULL_TRIAL_RECORD_1514582088.md:134` `2. **One arm.** OPT and ALT held near-identical stacks, so every`
  - `research/nocarry/results.md:59` `  death on 4 Nov ($380 of its $500 used before the day began) as the steady state, not bad luck. (E had run weeks,`
  - `research/nocarry/results.md:60` `  not years; the backtest's book is older and larger.)`
  - `research/nocarry/PREREG.md:107` `- The bars' spread field may be the bar's lowest spread: the sensitivity covers the cut; it also flatters every`
  - `research/nocarry/PREREG.md:112` `- **Holiday weeks:** a week under 4,000 bars is skipped (`run_bars.py`), so CONT carries its book across it while`
  - `research/nocarry/PREREG.md:115` `- **No rollover pause:** `sim.py` does not pause re-rolls in 23:50-00:15 server as the EA does`
  - `docs/research/replay-calibration-eurusd-4.md:173` `| B | 114 / 114 | 112 / 114 = 98.2% | 2 = 1.8% | PASS | PASS |`
  - `docs/research/replay-calibration-eurusd-4.md:174` `| C | 108 / 108 | 107 / 108 = 99.1% | 0 = 0.0% | PASS | PASS |`
  - `docs/research/replay-calibration-eurusd-4.md:175` `| D | 127 / 127 | 126 / 127 = 99.2% | 0 = 0.0% | PASS | PASS |`
  - `docs/research/replay-calibration-eurusd-4.md:180` `**VERDICT by s5 (from the T0 / T1 table and the counts verdict): PASS. The replay is fit for count-level use on`
  - `docs/research/replay-calibration-eurusd-4.md:181` `EURUSD in markets without a scheduled-release burst** (geometries bracketed by the live fleets; rankings confirmed`
  - `docs/research/two-arm-viability-2026-10-21.md:127` `  the out-of-sample part); P&L is outside plan 4's validated counts (a guide); E's other pairs need their own October`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:48, 59, 65, 78, 82, 103-104`):**
  - Line 48: replace `Carry is not the problem` with `Overnight holding is not the P&L problem`.
  - Line 59: replace `1514582088 (trial 2, 16 instances)` with `1514582088 (trial 2, 8 pairs, pre-re-roll, near-identical OPT/ALT)`.
  - Line 65: after `1,181 of 1,191 FTMO days reach $500 by FTMO's count` add `(in a non-liquidating continuous run)`.
  - Line 78: after `the four years cover t3 only.` add `(OPT cap 9 was confirmed on the 11-week tick harness at +$336 vs +$231, with 5 vs 3 October FTMO-day breaches, and was not run over the four years.)`
  - Line 82: after `one feed (FTMO's)` add `; the bar spread field may be the minute's minimum, holiday weeks under 4,000 bars are skipped, and the 23:50-00:15 rollover re-roll pause is not in sim.py (`research/nocarry/PREREG.md` s7)`.
  - Lines 103-104: replace `(`replay-plan4`: the T1 event-match score 97-100% on the calibration and holdout windows at timing 1, `docs/research/replay-calibration-eurusd-4.md`)` with `(`replay-plan4`: validated for count-level use on EURUSD outside release bursts, T1 97.3-100.0% on the seen windows and 98.2-99.2% on the blind window at timing 1, `docs/research/replay-calibration-eurusd-4.md`)`.

---

### 6. `s6`, the options

- **Verdict:** **GAP** (options A-D are fair and consistent with `PREREG.md` s6 and the operator's 21 Oct test; one narrower variant of Option B from the sources is worth naming)

1. **Are `for` and `against` fair and sourced for A, B, C, D (`memo:90-96`)?**
   - **A (Stop):** Fair and sourced (`research/nocarry/PREREG.md:95-96`, `longrun/results.md:7`, `nocarry/results.md:8`).
   - **B (Keep D, C, B running as demos):** Fair and sourced (`longrun/results.md:77-78`, `HANDOFF:9101, 9190-9195`).
   - **C (Real money, or scale):** Fair and sourced (`t3_drawdown/results.md:24, 31-33`: `$1,000 a month needs about 11 x` and already crosses `$500` at `1 x`).
   - **D (Take it to a desk / BMO):** Fair and sourced (`HANDOFF:9101`).
2. **Is any option missing?**
   - Between **A** (stop all) and **B** (keep D, C, B running as-is), the sources point to a narrower demo option: **keep only C (`t2`, 3 pairs, OPT cap 9 / ALT cap 7) or an ALT-only demo running** (after the halt-on-refusal fix), since on 31 Oct the operator noted `C's shape (few pairs, deep) the better frame` (`HANDOFF:9083`), C was `+$77` to 30 Oct and stayed within `~$230` of day-start balance on 4 Nov (`HANDOFF:9078, 9203`), and ALT was `+$800` over the 4 years in `CONT` (`longrun/results.md:50`). Naming this inside **B** (and noting why it still does not justify capital: `ALT` earns `~$17/month` before swap over 46 months) makes `s6` complete.
3. **Consistency with `research/nocarry/PREREG.md` s6 and the operator's 21 Oct test (`memo:7, 9, 97`):**
   - **Confirmed:** `research/nocarry/PREREG.md:95-96` pre-registered `Fails any of 1-3: **NO EDGE**, and the C162 memo says the project stops`, and `two-arm-viability-2026-10-21.md:30-31` set the operator's go/no-go test (`if we cannot find a single geometry ... then there is no future in this work`).

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:92` `| **A. Stop** (what the rule says) | The evidence is consistent across four years, three carry rules, two arms, three research angles and three FTMO trials. | Gives up the live evidence stream (small; s4). |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:93` `| B. Stop development, keep D, C, B running as demos | No money at risk; a few more weeks of live data. | VPS cost and attention; the four years already say what the weeks will show. E's storm (s8) shows an unattended EA can misbehave when a broker refuses it. |`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:97` `**Claude's recommendation: A.** Stop the grid as a trading strategy; archive the repos with this memo as the last`
  - `research/nocarry/PREREG.md:95` `- Passes 1-3 but not 4: **EDGE, NOT FTMO-SAFE.** Fails any of 1-3: **NO EDGE**, and the C162 memo says the`
  - `research/nocarry/PREREG.md:96` `  project stops.`
  - `handoffs/HANDOFF_2026-09-24.md:9101` `   the live weeks, the options (stop; keep the demos running as evidence at no money risk; scale; take it to BMO).`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:93`):**
  - Line 93: replace `| B. Stop development, keep D, C, B running as demos |` with `| B. Stop development, keep D, C, B (or C alone / ALT-only) running as demos |`.

---

### 7. `s8`, the loose ends

- **Verdict:** **GAP** (E's request storm is stated accurately against `HANDOFF s93` and `ea/grind_engine.mqh`; the reconciliation question in `memo:116` can be answered in one line from `ea/grind_recon.mqh` and `ea/grind_engine.mqh`, and two small open items from `HANDOFF` / `memo:110` are missing from `s8`)

1. **E's request storm (`memo:114-116`) checked against `HANDOFF s93` and `ea/grind_engine.mqh`:**
   - **Confirmed:**
     - `HANDOFF:9175, 9190`: `api_count` is the terminal-wide counter (`57,965 at 03:48Z`, `~57,000 requests in all`), climbing at `~465 requests a minute` (`~445 failed a minute` in the journal).
     - `HANDOFF:9183, 9192-9194` & `ea/grind_engine.mqh`: after FTMO closed all 95 positions at `01:36:55-56Z 4 Nov`, the EA's re-sends failed with `[Trade disabled]` (`TRADE_RETCODE_TRADE_DISABLED`, 10017). In `ea/grind_engine.mqh:1442-1468`, `Grind_PlaceLimit` sends `TRADE_ACTION_PENDING` via `Grind_OrderEngineSend(req, res)` and returns `0` whenever `res.retcode` is not `TRADE_RETCODE_DONE` or `TRADE_RETCODE_PLACED`. Neither `Grind_PlaceLimit` nor its callers (`side.l0_pending_ticket` at line `2096`, `layer.exit_order_ticket` at line `2151`, `side.add_pending_ticket` at line `2386`, and exit-queue promotion at line `3502`) check `TRADE_RETCODE_TRADE_DISABLED` or `AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)` or set `g_grind_halted = true`, so every subsequent tick retries placement.
2. **Why reconciliation kept 95 layers against an empty book with `recon_ok` and `invariant_ok` true (`memo:116`):**
   - `memo:116` says `not read; same condition` (matching `HANDOFF:9195-9196`: `not yet read`, so this is **NOT A DEFECT** in `memo:116`).
   - Having read `ea/grind_recon.mqh` and `ea/grind_engine.mqh`, the mechanism in source is three lines:
     a. `Grind_ReconstructState()` (`ea/grind_recon.mqh:1391-1435`), which sets `g_grind_recon_ok` (`line 1422`) and populates `g_grind_long` / `g_grind_short` from broker tickets, runs only at startup (`OnInit`).
     b. Runtime `Grind_CheckBookInvariants()` (`ea/grind_recon.mqh:1363-1388`) collects live broker tickets (`count = 0` when the broker book is empty) and rebuilds into temporary `long_tmp, short_tmp` (`lines 1367-1379`), checking internal invariants on `long_tmp, short_tmp` (which pass vacuously for an empty book) **without comparing `long_tmp, short_tmp` against `g_grind_long, g_grind_short`**.
     c. In `OnTradeTransaction` (`ea/grind_engine.mqh:2876-2889`), `Grind_ProcessDealForSide` filters by `Grind_MagicMatches(..., magic)` (`line 2876`) and only removes a layer on `entry_type == DEAL_ENTRY_OUT_BY` (`line 2889`), so server-side forced liquidation deals (`DEAL_ENTRY_OUT` or `DEAL_MAGIC == 0`) never remove layers from `g_grind_long` / `g_grind_short`.
3. **Anything open in the sources that a stop or continuation would need and `s8` leaves out (`GAP`):**
   - **Fleet B's `~89-94` open layers (`-$304.14` open at 4 Nov 03:49Z):** repeatedly listed as an open operator item in `HANDOFF:9072, 9103, 9132, 9155, 9169` (`B's ~94 layers: the operator's call`). If Option B is chosen, B's carried book is an open operational decision alongside C and D.
   - **Trial 3 (`1515045375`) standalone record:** `memo:110` states the project leaves `"three full trial records"`, whereas only Trial 1 (`docs/FULL_TRIAL_RECORD_1514264399.md`) and Trial 2 (`docs/FULL_TRIAL_RECORD_1514582088.md`) have standalone files in `docs/`, while Trial 3 (`1515045375`) is recorded in `HANDOFF s93` (`lines 9179-9197`).

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:114` `- **E's request storm** (HANDOFF s93): after FTMO closed the account, every instance re-sent refused orders every tick`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:115` `  (~465 a minute, ~57,000 in all); nothing in the EA tests `TRADE_RETCODE_TRADE_DISABLED`. Matters only if any fleet`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:116` `  keeps running (option B). Why reconciliation kept 95 layers against an empty book: not read; same condition.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:119` `- E's MT5 stays closed. D, C and B run until the operator rules.`
  - `handoffs/HANDOFF_2026-09-24.md:9155` `  - **For reference (03:49Z):** C 6 live, 51 layers, open -$209.59, api 303; B 9 live, 89 layers, open -$304.14, api`
  - `handoffs/HANDOFF_2026-09-24.md:9169` `5. B's ~94 layers and C's t2: the operator's call; both untouched.`
  - `handoffs/HANDOFF_2026-09-24.md:9175` `  `api_count` is the TERMINAL's count, shown by every instance: E's storm was ~57,000 requests in all, not each.`
  - `handoffs/HANDOFF_2026-09-24.md:9192` `- **In source (`bf832c0`): nothing tests `TRADE_RETCODE_TRADE_DISABLED` (10017) or the account's trade permission.**`
  - `handoffs/HANDOFF_2026-09-24.md:9193` `  `Grind_PlaceLimit` (`ea/grind_engine.mqh` 1442-1467) returns 0 on a refusal; its callers (L0 2096, exit 2151, add`
  - `handoffs/HANDOFF_2026-09-24.md:9194` `  2386, and 3502) set nothing, so the next tick sends again. **C167 (modify / cancel) is narrower than what happened:`
  - `handoffs/HANDOFF_2026-09-24.md:9195` `  the storm was the placement path.** Which caller sent each line: inferred, not traced. Why reconciliation kept 95`
  - `handoffs/HANDOFF_2026-09-24.md:9196` `  layers against 0 positions with `recon_ok` true: not yet read.`
  - `ea/grind_engine.mqh:1442` `ulong Grind_PlaceLimit(const ENUM_ORDER_TYPE type,`
  - `ea/grind_engine.mqh:1463` `   if(!Grind_OrderEngineSend(req, res))`
  - `ea/grind_engine.mqh:1464` `      return 0;`
  - `ea/grind_engine.mqh:1465` `   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)`
  - `ea/grind_engine.mqh:1466` `      return res.order;`
  - `ea/grind_engine.mqh:1467` `   return 0;`
  - `ea/grind_engine.mqh:2096` `   side.l0_pending_ticket = Grind_PlaceLimit(otype, target_price, lots, magic, comment);`
  - `ea/grind_engine.mqh:2151` `   layer.exit_order_ticket = Grind_PlaceLimit(otype, layer.exit_target, lots, magic, comment);`
  - `ea/grind_engine.mqh:2386` `   side.add_pending_ticket = Grind_PlaceLimit(otype, clamped, lots, magic, comment);`
  - `ea/grind_engine.mqh:2876` `   if(!Grind_MagicMatches(Grind_DealGetInteger(deal_ticket, DEAL_MAGIC), magic))`
  - `ea/grind_engine.mqh:2889` `   if(entry_type == DEAL_ENTRY_OUT_BY) {`
  - `ea/grind_engine.mqh:3502` `      const ulong ticket = Grind_PlaceLimit(otype, price, lots, magic, comment);`
  - `ea/grind_recon.mqh:1363` `bool Grind_CheckBookInvariants()`
  - `ea/grind_recon.mqh:1371` `   const bool ok = Grind_RebuildBookFromTickets(tickets, count,`
  - `ea/grind_recon.mqh:1377` `                                                long_tmp, short_tmp, reason,`
  - `ea/grind_recon.mqh:1380` `   g_grind_last_invariant_ok = ok;`
  - `ea/grind_recon.mqh:1391` `bool Grind_ReconstructState()`
  - `ea/grind_recon.mqh:1422` `   g_grind_recon_ok = ok;`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:116, 119`):**
  - Line 116: optionally replace `Why reconciliation kept 95 layers against an empty book: not read; same condition.` with `Why reconciliation kept 95 layers against an empty book: deals only close layers on DEAL_ENTRY_OUT_BY with matching magic (`ea/grind_engine.mqh` 2876, 2889), and `Grind_CheckBookInvariants` checks a temporary rebuild of the empty broker book without comparing it to `g_grind_long`/`g_grind_short` (`ea/grind_recon.mqh` 1363-1388); same condition.`
  - Line 119: replace `- E's MT5 stays closed. D, C and B run until the operator rules.` with `- E's MT5 stays closed. D (95 layers), C (51 layers, t2) and B (~89 layers) run until the operator rules.`

---

### 8. Fitness as an internal record

- **Verdict:** **GAP** (FTMO's rules are stated accurately as recorded in the repo; three small citation/traceability fixes will make every reference in the memo self-contained on `main`)

1. **FTMO's rules as recorded in the repo (`memo:62-63, 68-69`):**
   - **Daily loss (`memo:62-63`):** Measured from day-start balance (`day-start balance - the day's lowest equity`, `$500` on a `$10,000` Free Trial, resetting at midnight Prague / `01:00` server in standard time / `22:00Z` in summer time / `23:00Z` after Prague leaves summer time). **Confirmed** against `research/e_week1/PREREG.md:16-18, 24-26`, `research/nocarry/PREREG.md:26-28, 60-64`, and `docs/FULL_TRIAL_RECORD_1514582088.md:67-71, 147-148`.
   - **Weekend / overnight holding (`memo:69`):** FTMO's Standard funded account requires positions to be closed before market breaks over two hours (weekends/holidays) while allowing overnight weekday holding; Evaluation (Challenge/Verification) and Swing accounts have no weekend-close rule. **Confirmed** against `research/nocarry/PREREG.md:30-32` and `handoffs/HANDOFF_2026-09-24.md:9213-9214`.
2. **Anything a reader in six months could not trace to a file on `main` (`GAP`):**
   - **`memo:110` (`"and three full trial records"`):** On `main`, there are **two** `docs/FULL_TRIAL_RECORD_*.md` files (`docs/FULL_TRIAL_RECORD_1514264399.md` and `docs/FULL_TRIAL_RECORD_1514582088.md`), whereas Trial 3 (`1515045375`, E) is recorded in `handoffs/HANDOFF_2026-09-24.md` `s93` (`lines 9179-9197`), as `memo:60` itself cites (`HANDOFF s93`). A reader looking for `docs/FULL_TRIAL_RECORD_1515045375.md` will not find it.
   - **`memo:105` (`MECHANICS.md`) and `memo:125` (`results.md`, `MANIFEST.md`):** `memo:105` writes `(`research/opt_budget/sim.py`, MECHANICS.md)` instead of `research/opt_budget/MECHANICS.md`, and `memo:125` abbreviates `research/nocarry/results.md` and `research/nocarry/MANIFEST.md`.
   - **`memo:9` (`fixed 7 Nov`):** As noted in Item 1, `research/nocarry/PREREG.md` was drafted 7 Nov (`9dca377`) and amended 8 Nov (`8ccf07c`, `HANDOFF:9232-9250`) before any runner or run.

- **Quotes (`origin/main`):**
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:105` `  and a minute-bar simulator checked against it (`research/opt_budget/sim.py`, MECHANICS.md).`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:110` `  solved (C165: a sixty-fold drop at the 1 Nov open), and three full trial records.`
  - `docs/research/c162-go-no-go-memo-2026-11-08.md:125` ``research/longrun/results.md`; `research/nocarry/PREREG.md`, `results.md`, `MANIFEST.md`;`
  - `research/nocarry/PREREG.md:30` `  is a holiday), restart at 01:00 server on the next week's first trading day. This is FTMO's actual`
  - `research/nocarry/PREREG.md:31` `  rule on a Standard funded account: positions closed before any break over two hours (FTMO's FAQ, read 7 Nov;`
  - `research/nocarry/PREREG.md:32` `  the evaluation and the Swing account have no such rule). Overnight holding is allowed.`
  - `research/nocarry/PREREG.md:60` `  change in balance, and **the day's loss as FTMO counts it**: the balance at the day's start less the lowest`
  - `research/e_week1/PREREG.md:16` `At the low, balance $10,070, equity $9,770. **FTMO's daily loss = day-start balance - the day's lowest equity =`
  - `research/e_week1/PREREG.md:17` `$10,050 - $9,770 = $280**, though the day's closed P&L was +$20: $53 of it was carried in from earlier days`

- **Smallest change to the memo (`docs/research/c162-go-no-go-memo-2026-11-08.md:105, 110, 125`):**
  - Line 105: replace `(`research/opt_budget/sim.py`, MECHANICS.md)` with `(`research/opt_budget/sim.py`, `research/opt_budget/MECHANICS.md`)`.
  - Line 110: replace `and three full trial records.` with `and three trial records (`docs/FULL_TRIAL_RECORD_1514264399.md`, `docs/FULL_TRIAL_RECORD_1514582088.md`, and HANDOFF s93 for 1515045375).`
  - Line 125: replace ``research/nocarry/PREREG.md`, `results.md`, `MANIFEST.md`;` with ``research/nocarry/PREREG.md`, `research/nocarry/results.md`, `research/nocarry/MANIFEST.md`;`.

---

**SOUND WITH CHANGES** (1. In `s2` (`memo:27, 31, 35`), note that `sweep10`'s `q88` was fit on 1-16 Oct and `longrun`'s Aug-Oct 2026 overlaps `t3`'s selection window, and replace `"Everything in sample said 'maybe'; everything out of sample said no"` with the exact split: in sample said `"maybe"` on P&L (`+$231`) but `"no"` on FTMO's `$500` day (`$626.51` on 16 Oct), while out of sample every fleet-level test of `t3` lost (`ALT` alone made `+$800` in `CONT`, 3 of 4 years `> 0`, `~$17/month` before swap, with month-end open loss reaching `-$694`, and lost under `DAY` and `WEEK`); 2. In `s2`/`s3`/`s4`/`s5`/`s6` (`memo:31, 44, 71-72, 78, 93`), state the counter-evidence and why it does not change the verdict: `2026 to 23 Oct` `+$876` and `AUDCAD` `+$1,648` in `CONT`, live `ALT` positive on C/D/E to 30 Oct and C's `~$230` max day loss on 4 Nov, `swcap` cap-9 `CONFIRMED` on the 11-week harness (`+$336`, 5 vs 3 FTMO-day breaches), and C-only / ALT-only in Option B; 3. In `s3`/`s4`/`s5`/`s7`/`s8` (`memo:9, 36, 45, 48, 59, 65, 81-82, 103-105, 110, 116, 119, 125`), clarify `"Overnight holding is not the P&L problem"`, qualify `memo:45` (`confirmed` on winners while losers are realised via rolls), note Trial 2's pre-re-roll 8-pair setup and `CONT`'s non-liquidating `$500`-day count, add `PREREG.md` s7's bar-sim limits to `s5`, state `replay-plan4`'s count-level validation scope (`98.2-99.2%` blind window), note `7-8 Nov` for `PREREG.md` and `eleven-to-twelve weeks` for `+$180` vs `+$231`, and specify full paths and `HANDOFF s93` for Trial 3's record.)

Line count: 477
