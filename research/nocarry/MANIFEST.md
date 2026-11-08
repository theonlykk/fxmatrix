This message has a line count at the bottom

# NO CARRY -- MANIFEST (8 Nov 2026)

Inputs: FTMO M1 bars `bars_1514878887_<PAIR>.csv`, sha256 first 16 as `research/longrun/MANIFEST.md` (checked again 8 Nov: AUDCAD b8eccff28a6bcad0, AUDCHF 091fb6b90c308ff4, CADCHF a136cd9577ec0448, EURGBP e9a2be7535ea8d76, EURUSD 2bdf7e05817e41a6, GBPUSD 742d88add02017e0).
Code (sha256 first 16): `research/opt_budget/sim.py` 6ee9fc14b1de504a and `research/longrun/run_bars.py` 8af632ad527c1622 (both unchanged); `run_nocarry.py` d2b2019cf9565140; `test_nocarry.py` 66e80543b9c51303 (15 / 15 pass); `selfcheck.py` 3cf6c4553020fdcb; `summarise.py` 2e2ddd4853dbae52.
Run in Claude's sandbox, 7-8 Nov 2026: 30 runs (CONT, DAY, WEEK, DAY_w05, WEEK_w05 x six pairs), two at a time. The first batch stopped at the sandbox's time limit after 20 runs; the ten left (the 0.5 pip runs from DAY CADCHF on) were run again from scratch with the same code. None failed.
**Self-checks** (PREREG s5 a, c, d, e): all PASS, in `selfcheck_out.txt`, committed with this file **before any total was read**.
The JSONs are committed in `out/`. The per-tick `.npz` arrays (8.1 GB) are not committed; they rebuild from the bars and the runner, and their hashes are below. `cont_<PAIR>.json` (run_bars.py's format, for check a) is byte-identical to `research/longrun/out_limit/` and is not repeated.

| file | bytes | sha256 (first 16) |
|---|---|---|
| `CONT_AUDCAD.json` | 6711 | c8cf1678815a8c6e |
| `CONT_AUDCHF.json` | 6775 | 69d04c91b7f822eb |
| `CONT_CADCHF.json` | 6719 | 7f5121c33602bde4 |
| `CONT_EURGBP.json` | 6741 | 6926c582a04be569 |
| `CONT_EURUSD.json` | 6763 | b62c0956e1cad5eb |
| `CONT_GBPUSD.json` | 6785 | 320aa833d763bb04 |
| `DAY_AUDCAD.json` | 6526 | c915d6e18eac47a7 |
| `DAY_AUDCHF.json` | 6517 | 400e11ed4ca6ee9b |
| `DAY_CADCHF.json` | 6564 | 43e604651598b9e8 |
| `DAY_EURGBP.json` | 6514 | 2d88c316959fdd72 |
| `DAY_EURUSD.json` | 6566 | 6c9ef3a5709d297c |
| `DAY_GBPUSD.json` | 6594 | e03a9883eaab57de |
| `DAY_w05_AUDCAD.json` | 6532 | 8f5ba89afe950788 |
| `DAY_w05_AUDCHF.json` | 6539 | c7607f5809f400cd |
| `DAY_w05_CADCHF.json` | 6572 | f28ca65362893f5a |
| `DAY_w05_EURGBP.json` | 6533 | 8e6d1a545d8f5292 |
| `DAY_w05_EURUSD.json` | 6578 | 6415dc5d8fed61ee |
| `DAY_w05_GBPUSD.json` | 6599 | bf19cf233fd157e1 |
| `WEEK_AUDCAD.json` | 6537 | c759967857cb5fdc |
| `WEEK_AUDCHF.json` | 6653 | 1d29e749e83d595a |
| `WEEK_CADCHF.json` | 6661 | 91081c1a397b03e9 |
| `WEEK_EURGBP.json` | 6596 | 49e5bf790281810b |
| `WEEK_EURUSD.json` | 6648 | c1acd8929d438012 |
| `WEEK_GBPUSD.json` | 6721 | 3207939b250eb12f |
| `WEEK_w05_AUDCAD.json` | 6546 | 708625116de114af |
| `WEEK_w05_AUDCHF.json` | 6648 | 65f14a7925bde293 |
| `WEEK_w05_CADCHF.json` | 6661 | ebc65c0b38f58d9a |
| `WEEK_w05_EURGBP.json` | 6584 | ad1fc0d7f84e2c52 |
| `WEEK_w05_EURUSD.json` | 6657 | c8037cb6c8b3360b |
| `WEEK_w05_GBPUSD.json` | 6722 | 900f452cd0a05841 |
| `CONT_AUDCAD.npz` | 270847020 | 4fb8bbf3d6441520 |
| `CONT_AUDCHF.npz` | 270774828 | dd5285c65c3b25af |
| `CONT_CADCHF.npz` | 270604332 | e58d65a2d817f11e |
| `CONT_EURGBP.npz` | 270587820 | 00f42949fd0eabed |
| `CONT_EURUSD.npz` | 270276204 | 9f69adfb395ec3f9 |
| `CONT_GBPUSD.npz` | 270317676 | b73a96fb3ceb8520 |
| `DAY_AUDCAD.npz` | 270847020 | 97038ef4c2506f02 |
| `DAY_AUDCHF.npz` | 270774828 | b9b6156f730d9650 |
| `DAY_CADCHF.npz` | 270604332 | cb272d06ff119976 |
| `DAY_EURGBP.npz` | 270587820 | 1047410311b66260 |
| `DAY_EURUSD.npz` | 270276204 | 004ba9b7db0e9ea6 |
| `DAY_GBPUSD.npz` | 270317676 | fbd233ffd8f14459 |
| `DAY_w05_AUDCAD.npz` | 270847020 | 0a9ba6b4a9042a86 |
| `DAY_w05_AUDCHF.npz` | 270774828 | 036f6e6193855735 |
| `DAY_w05_CADCHF.npz` | 270604332 | 7d0cb61bc82e559e |
| `DAY_w05_EURGBP.npz` | 270587820 | c94cde0ff1650fc3 |
| `DAY_w05_EURUSD.npz` | 270276204 | f58a958fa3b2c893 |
| `DAY_w05_GBPUSD.npz` | 270317676 | ff4b44f754a6d262 |
| `WEEK_AUDCAD.npz` | 270847020 | 85942434f3dc4a44 |
| `WEEK_AUDCHF.npz` | 270774828 | 876d5c047d9d1184 |
| `WEEK_CADCHF.npz` | 270604332 | 76ee8eaf478cd181 |
| `WEEK_EURGBP.npz` | 270587820 | 7e885b0563cbd842 |
| `WEEK_EURUSD.npz` | 270276204 | 970bcf70e22a13a5 |
| `WEEK_GBPUSD.npz` | 270317676 | a89234061d4f8787 |
| `WEEK_w05_AUDCAD.npz` | 270847020 | 6de559e87e72cffa |
| `WEEK_w05_AUDCHF.npz` | 270774828 | 4eb5f5a064723a30 |
| `WEEK_w05_CADCHF.npz` | 270604332 | 4799fd1e8d31eb0b |
| `WEEK_w05_EURGBP.npz` | 270587820 | 82ab3d11d8944ede |
| `WEEK_w05_EURUSD.npz` | 270276204 | 0832f8fc93f7ed20 |
| `WEEK_w05_GBPUSD.npz` | 270317676 | b6c71b4e96d79aa7 |

Line count: 74
