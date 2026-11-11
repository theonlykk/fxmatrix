This message has a line count at the bottom

# FABLE 5.2 -- PASS 1 (BLIND) REVIEW: MANIFEST (11 Nov 2026)

| | |
|---|---|
| What | An independent, blind review of the passive grid by Claude Fable 5.2, in a separate chat in the Claude desktop app (10-11 Nov), with read access to `D:\fxmatrix` and `D:\fxmatrix-exports` and a written allowlist. |
| Prompt | `prompts/fable_review_pass1_v2.md` (v2 = v1 plus the memory paragraph at the top; v1 was never used). |
| Blindness | Its declarations (report s0): no memory file or past chat opened; it saw the automatic profile, preferences and memory listing, one preference line of which mentions a losing episode; the `run_bars.py` docstring mentions a fill flaw. It read no result, memo, handoff or review. |
| Order | Desktop file times: `A_expectations.md` 04:57:41Z, `B_plan.md` 05:00:31Z (its header says 00:10 EST; it was saved ten minutes before that), every script and output 07:21:46Z or later, in one batch: the scripts were copied from Fable's sandbox at the end. So the times prove A and B were saved first; that they preceded any data read rests on Fable's own statement (report s2, s3). |
| Checked by Claude (11 Nov) | Its run of `sim.py` (`out/07_crosscheck_*.txt`) reproduces `research/longrun/out_limit` to the dollar: EURUSD OPT -3,418, ALT +109; AUDCAD OPT +772, ALT +876. The exit-clamp difference it names (EA: a long's exit to ASK + 1 point, `grind_carry.mqh` 443-458; `sim.py`: BID + 1 point, 248-251) is real. |
| Desktop copy | `D:\fxmatrix-exports\fable_review\` (everything below). |

| file | bytes | sha256 (first 16) | in the repo |
|---|---|---|---|
| `00_data_summary.py` | 2156 | f04c91c1d3fc00a9 | yes |
| `01_null_calibration.py` | 2680 | 4a8fb6e3b490876b | yes |
| `02_reversal_bars.py` | 7241 | 353c133feb0af3be | yes |
| `03_variance_ratio.py` | 2706 | 1e998e66dfb1d0b3 | yes |
| `04_ladder_bars.py` | 5870 | 80f81ac29aae3f1b | yes |
| `04b_ladder_tables.py` | 4875 | 0a0d03371c1ce83b | yes |
| `05_ticks_inventory.py` | 2162 | f9146137da812f69 | yes |
| `06_ticks_tests.py` | 9007 | 3abef191bdd84ccc | yes |
| `07_crosscheck_sim.py` | 3559 | 798a4a49290985bb | yes |
| `08_summary.py` | 12844 | 1f9406f7c0ed6560 | yes |
| `09_phase_ensemble.py` | 3207 | 6c4063605a80c2a5 | yes |
| `10_fill_improvement.py` | 2550 | 0725d2e7da373b41 | yes |
| `11_micro_perturbation.py` | 1761 | 74d00f6faafb4f3b | yes |
| `12_report_tables.py` | 5680 | 63026e324f57113b | yes |
| `13_build_report.py` | 2965 | da3c4acf5ccb8ec9 | yes |
| `A_expectations.md` | 9445 | d1d8e6c3c8ed09bb | yes |
| `B_plan.md` | 7981 | 7f09e9cdc1e12e64 | yes |
| `common.py` | 5172 | 04238778fc2eab03 | yes |
| `core.py` | 16350 | b531eedbf1020b9e | yes |
| `dbg_c165.py` | 2590 | fad8ecb1f3834e51 | yes |
| `dbg_compare.py` | 2093 | 8547af512546604b | yes |
| `dbg_rolls.py` | 2792 | e829261d7a741ac4 | yes |
| `dbg_trace.py` | 1707 | 8b87e3c059f17151 | yes |
| `out/00_data_summary.txt` | 7216 | 9254c15174f9f07c | yes |
| `out/01_null_calibration.txt` | 2632 | 2a24957d5ded8286 | yes |
| `out/02_reversal_bars.csv` | 146883 | 93c0b5d756950888 | yes |
| `out/02_reversal_bars.txt` | 20387 | 8642d1726d11dd9a | yes |
| `out/02_reversal_by_hour.csv` | 89391 | 35b9b5cfd0d5f601 | yes |
| `out/02_reversal_by_runlen.csv` | 138213 | b543480884e2c197 | yes |
| `out/02_reversal_by_year.csv` | 146007 | ba8b584df4356280 | yes |
| `out/03_variance_ratio.csv` | 4053 | b17ba76a4059407e | yes |
| `out/03_variance_ratio.txt` | 1879 | 4223f699cf48f511 | yes |
| `out/04_ladder_cells_cont.csv` | 715315 | 63052ba31b142d92 | **no** (regenerate: `04_ladder_bars.py cont|one`) |
| `out/04_ladder_cells_one.csv` | 713740 | d224418cff16c238 | **no** (regenerate: `04_ladder_bars.py cont|one`) |
| `out/04_ladder_monthly_cont.csv` | 3399018 | bf5362554c619a0f | **no** (regenerate: `04_ladder_bars.py cont|one`) |
| `out/04_ladder_monthly_one.csv` | 3396131 | 64925603955b1955 | **no** (regenerate: `04_ladder_bars.py cont|one`) |
| `out/04_ladder_tables_cont.txt` | 55004 | 7e5cda83de47bb13 | yes |
| `out/04_ladder_tables_one.txt` | 55003 | 5dea05f37f555605 | yes |
| `out/05_ticks_inventory.txt` | 4369 | a2a2615e21b27558 | yes |
| `out/06_ticks_T1.csv` | 33272 | e2916c15d8a9b70d | yes |
| `out/06_ticks_ladder.csv` | 406360 | 5c31f0b0d5a1f8bd | yes |
| `out/06_ticks_tests.txt` | 42940 | b7f53df73e55ebff | yes |
| `out/07_crosscheck_AUDCAD.txt` | 960 | 442b9990576f8008 | yes |
| `out/07_crosscheck_EURUSD.txt` | 968 | 5c9ef83b671d68ca | yes |
| `out/08_summary.txt` | 36067 | 59954a4dc73d8cf8 | yes |
| `out/09_phase_ensemble.csv` | 13007 | 64c9e4699bfe4870 | yes |
| `out/09_phase_ensemble.txt` | 4006 | b9a5f914fbc0b064 | yes |
| `out/10_fill_improvement.csv` | 3686 | 31a79a848d704179 | yes |
| `out/10_fill_improvement.txt` | 5324 | 8a06b7ffd3dcd96b | yes |
| `out/11_micro_perturbation.txt` | 925 | 40011bad09c63d15 | yes |
| `out/12_report_tables.txt` | 11157 | 4bc56fa9c7d3514c | yes |
| `report_pass1.md` | 96287 | 8887a55a3ba6f909 | yes |
| `report_prose.md` | 35442 | 9430c8ec94d9cf78 | yes |
| `test_core.py` | 3322 | 5a927e5d9fc18756 | yes |
| `ticks.py` | 1996 | 3d2de45c97275d39 | yes |

Line count: 72
