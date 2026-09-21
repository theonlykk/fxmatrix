# ROLL LOG

Manual rolls of capped sides. Procedure: `manual-roll.md`. One row per
roll; complete the 24-hour columns the following day. Swap is taken from
MT5 History and cross-checks the pipshed carry table: both 2026-09-21
rolls matched it within 2 cents (AUDCAD short -0.941 pips/night).

| date/time UTC | instance | side | ticket | entry | close | pips | USD price | USD swap | USD comm | USD total | depth before | new layer scalped? | re-capped? | max retrace 24h | notes |
|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| 2026-09-21 16:55 | AUDCAD OPT | short | 542339092 | 0.99003 | 0.99949 | -94.6 | -6.79 | -0.38 | -0.06 | -7.23 | 8 | -- | yes, within 9 min (L08 filled 17:05) | -- | cycle 2, exit 5, add 10. L08 added at 0.99952 (clamped from 0.99808) |
| 2026-09-21 17:00 | AUDCAD ALT | short | 541594698 | 0.98991 | 0.99953 | -96.2 | -6.91 | -0.45 | -0.06 | -7.42 | 8 | -- | -- | -- | cycle 2, exit 10, add 10. Reattach halted on I6 (preset exit 7); fixed with exit 10. L08 resting 0.99961 |
| 2026-09-21 ~19:00 | AUDCAD OPT | short | 544092579 | 0.99103 | (History) | ~-88.7 | -6.33 | (History) | -0.06 | -6.39 + swap | 8 | -- | -- | -- | **OUTSIDE TRIGGER: consecutive roll**, 2h after the 16:55 roll. L09 add placed at 1.00052 |
| 2026-09-21 ~19:03 | AUDCAD ALT | short | 542332509 | 0.99092 | (History) | ~-88.5 | -6.32 | (History) | -0.06 | -6.38 + swap | 8 | -- | -- | -- | **OUTSIDE TRIGGER: consecutive roll.** Position closed BEFORE detaching the EA; EA book briefly disagreed with the broker, reattached before it halted. L09 add placed at 1.00021 |
