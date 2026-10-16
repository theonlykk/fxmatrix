# research/pair_choice -- pair cost ranking (docs/research/fleet-d-two-arm-ring-2026-10-16.md s3)

    python research/pair_choice/spread_rank.py <bidask folder>

Input: `grind_bidask_dump` minute bars, one file per pair. First run 16 Oct on `bidask_ftmo_2026-10-02`
(FTMO, 21 pairs, 20 Sep - 3 Oct; the markout study's set): `spread_rank_2026-10-02.txt`, inputs in
`inputs.sha256` (not in git). FTMO's feed and an older window: good for ranking pairs against each other,
not for IC's spreads today. No unit tests (exploratory; the research/markout convention).
