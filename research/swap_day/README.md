This message has a line count at the bottom

# research/swap_day -- which rollover is charged how many nights (C86)

Trade history only: each closed layer's swap (both OUT_BY deals of its
close-by, 0.01 lots) labelled by the pass days of the rollovers it was
held across, divided by its key's (fleet, pair, side) Mon/Thu one-night
median; keys under $0.03 a night are left out. Loaders are those of the
frozen replay v1 (`research/ejection_value`), imported read-only.

    python research/swap_day/swap_day.py --export <study_export.jsonl> [...]
    python research/swap_day/test_swap_day.py      # 7 hand-derived tests

## Result, 1 Oct ~02:10Z (export `study_export_1001early.jsonl`, sha256 `dde95342e203335b`, last close 01:58Z)

Single-night layers, median ratio to the Mon/Thu baseline (all fleets):
Mon 1.00 (n 75), **Tue 1.00 (n 110)**, **Wed 2.78 (n 13)**, Thu 1.00
(n 27); Fri+Sat+Sun 1.00 (n 38). Mon+Tue 2.00, Fri..Mon 2.00,
Thu..Mon 3.20: additive, as the single nights say.

The 30 Sep rollover (Wednesday's pass, 21:00Z) on its own: 27 layers
held across it had closed by 01:58Z. Every single-night one with a
readable baseline charged about three nights on BOTH brokers (A, B, C:
2.5-3.7 per layer; spread from the cent rounding of swaps of $0.02-0.36),
e.g. AUDCHF short B/C -$0.36 vs -$0.13, EURUSD long -$0.25 (IC) and
-$0.33 (FTMO) vs -$0.09, NZDCHF short -$0.21 vs -$0.08.

**So the triple charge is on the rollover that Wednesday's pass prices,
Tuesday's is single, and the weekend is charged once (by Friday's pass):
Mon 1, Tue 1, Wed 3, Thu 1, Fri 1.** The EA's pending multiplier
(`grind_carry.mqh` 1114, `day_of_week + 1`) gives Tue 3, Wed 1, Fri 0:
C86 confirmed on a sample large enough to act on.

Line count: 34
