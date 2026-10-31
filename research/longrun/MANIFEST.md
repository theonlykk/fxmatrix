This message has a line count at the bottom

# LONGRUN -- MANIFEST (31 Oct 2026)

Inputs: FTMO M1 bars `bars_1514878887_<PAIR>.csv` (research/cluster/PREREG.md s3; sha256 first 16: EURUSD 2BDF7E05817E41A6, GBPUSD 742D88ADD02017E0, EURGBP E9A2BE7535EA8D76, AUDCAD B8ECCFF28A6BCAD0, AUDCHF 091FB6B90C308FF4, CADCHF A136CD9577EC0448).
Engine: `research/opt_budget/sim.py` at `main` `a0a75cb` (sha256 6ee9fc14b1de504a); `run_bars.py` 8af632ad527c1622.
Run in Claude's sandbox, 31 Oct 2026 (the bars staged from `D:\fxmatrix-exports\bars_ftmo`, hashes checked 26 Oct).
**Reproduced:** AUDCAD re-run with the committed `run_bars.py` (both fills) gave byte-identical JSON to the files below.

| file | sha256 (first 16) |
|---|---|
| `out_limit/cont_EURUSD.json` | 1189dc6b1063d184 |
| `out_limit/cont_GBPUSD.json` | 6fd40063de683d39 |
| `out_limit/cont_EURGBP.json` | bde916c5a4640490 |
| `out_limit/cont_AUDCAD.json` | 93f03256cddceaf1 |
| `out_limit/cont_AUDCHF.json` | 769fba0519d0a3c6 |
| `out_limit/cont_CADCHF.json` | f2962576ae65fe7e |
| `out_market/cont_EURUSD.json` | 4237391dd958073e |
| `out_market/cont_GBPUSD.json` | a08d9a66050af217 |
| `out_market/cont_EURGBP.json` | dafa8e76fdcf5127 |
| `out_market/cont_AUDCAD.json` | 9a6183307acbb66c |
| `out_market/cont_AUDCHF.json` | 9076237ee2a390d1 |
| `out_market/cont_CADCHF.json` | 2c88b1446826e5f7 |

Line count: 25
