This message has a line count at the bottom

# PIPSHED's EXPORTS FOR THE WIND-DOWN (11 Nov 2026)

Made by `docs/runbooks/winddown-export.md` s5 on the desktop (`D:\fxmatrix-exports\winddown\pipshed\`), from
the archive-worker (pipshed `b9d2d22`, `scripts/archive_counts.py`). Every line parses as JSON (checked by Claude).
Archive queues empty first (05:49:31Z 10 Nov: queue 0, processing 0, dead-letter 0). Row counts at 12:04 EST:
`counts.txt`. `state_snapshots` (no retention) are left in pipshed for now.

## 1. THE ARCHIVE (`--export-archive`, all instances, 14:53 EST 11 Nov)

| file | bytes | rows | sha256 (first 16) | rows by table |
|---|---|---|---|---|
| `archive_all_20261111.jsonl` | 85590493 | 155498 | ca442cf756ba0f1b | config_events 1537, ea_events 67778, fill_logs 69299, scalp_history 16884 |

## 2. SEND LOGS (`--export-sends --instance <id>`, 72 instances, 15:05-15:14 EST 11 Nov; kept 14 days: from 28 Oct)

Retcode 10017 is `TRADE_RETCODE_TRADE_DISABLED`: E's storm after FTMO closed the account on 4 Nov. The first
run's files for `GRIND_CADCHF_ALT` and `GRIND_EURGBP_ALT` were empty (the Railway call failed); they were kept
as `*.jsonl.empty` and exported again (header only: no sends in the window).

| file | bytes | rows | 10017 | first | last | sha256 (first 16) |
|---|---|---|---|---|---|---|
| `sends_GRIND_AUDCAD_ALT.jsonl` | 70 | 0 | 0 | - | - | f1763049267f9265 |
| `sends_GRIND_AUDCAD_ALTC.jsonl` | 111052 | 184 | 0 | 2026-10-28 | 2026-11-11 | cfd92622e0614160 |
| `sends_GRIND_AUDCAD_ALTD.jsonl` | 100168 | 166 | 0 | 2026-10-28 | 2026-11-09 | 9630673696f2cd61 |
| `sends_GRIND_AUDCAD_ALTE.jsonl` | 3337140 | 5420 | 5350 | 2026-10-28 | 2026-11-04 | a0cdd880c73ad68c |
| `sends_GRIND_AUDCAD_OPT.jsonl` | 70 | 0 | 0 | - | - | 9e1fef849ceace66 |
| `sends_GRIND_AUDCAD_OPTB.jsonl` | 944255 | 1553 | 0 | 2026-10-28 | 2026-11-10 | 4300a2aec7d7e9b4 |
| `sends_GRIND_AUDCAD_OPTC.jsonl` | 222302 | 367 | 0 | 2026-10-28 | 2026-11-11 | f0e13eb90ba07ca6 |
| `sends_GRIND_AUDCAD_OPTD.jsonl` | 1536812 | 2525 | 0 | 2026-10-28 | 2026-11-10 | 1b07bbddeae4b5c9 |
| `sends_GRIND_AUDCAD_OPTE.jsonl` | 1619103 | 2636 | 2518 | 2026-10-28 | 2026-11-04 | 096bdb8698b1f787 |
| `sends_GRIND_AUDCHF_ALT.jsonl` | 70 | 0 | 0 | - | - | f08606cb033602f4 |
| `sends_GRIND_AUDCHF_ALTD.jsonl` | 122813 | 203 | 0 | 2026-10-28 | 2026-11-09 | decf87694f2158b8 |
| `sends_GRIND_AUDCHF_ALTE.jsonl` | 2404763 | 3907 | 3794 | 2026-10-28 | 2026-11-04 | b17223c01992e7b5 |
| `sends_GRIND_AUDCHF_OPT.jsonl` | 70 | 0 | 0 | - | - | 3ae93b75b35de4bb |
| `sends_GRIND_AUDCHF_OPTB.jsonl` | 1099170 | 1809 | 0 | 2026-10-28 | 2026-11-09 | 6dc4b73440b49181 |
| `sends_GRIND_AUDCHF_OPTC.jsonl` | 71 | 0 | 0 | - | - | 63aaaba67fcb9c37 |
| `sends_GRIND_AUDCHF_OPTD.jsonl` | 2365824 | 3887 | 0 | 2026-10-28 | 2026-11-10 | c5d3a3d597a3dd92 |
| `sends_GRIND_AUDCHF_OPTE.jsonl` | 1371889 | 2231 | 2057 | 2026-10-28 | 2026-11-04 | 680c8e7f98fdf371 |
| `sends_GRIND_AUDNZD_ALT.jsonl` | 70 | 0 | 0 | - | - | 39a1b654661e4b62 |
| `sends_GRIND_AUDNZD_ALTB.jsonl` | 71 | 0 | 0 | - | - | 6bdf16d158c98f5c |
| `sends_GRIND_AUDNZD_ALTC.jsonl` | 71 | 0 | 0 | - | - | 1c1272c16e5355db |
| `sends_GRIND_AUDNZD_ALTD.jsonl` | 71 | 0 | 0 | - | - | dc1bc69780c31ce3 |
| `sends_GRIND_AUDNZD_OPT.jsonl` | 70 | 0 | 0 | - | - | c094da90f9ffe661 |
| `sends_GRIND_AUDNZD_OPTB.jsonl` | 1076005 | 1768 | 0 | 2026-10-28 | 2026-11-10 | 08949eb3832a2bdf |
| `sends_GRIND_AUDNZD_OPTC.jsonl` | 71 | 0 | 0 | - | - | cb83163ef71f7bd9 |
| `sends_GRIND_AUDNZD_OPTD.jsonl` | 71 | 0 | 0 | - | - | 32f6f45115adfe25 |
| `sends_GRIND_CADCHF_ALT.jsonl` | 70 | 0 | 0 | - | - | a7401369d1e9a041 |
| `sends_GRIND_CADCHF_ALTD.jsonl` | 160498 | 265 | 0 | 2026-10-28 | 2026-11-09 | 235a0573b381672c |
| `sends_GRIND_CADCHF_ALTE.jsonl` | 5994358 | 9738 | 9638 | 2026-10-28 | 2026-11-04 | 10053c148da32116 |
| `sends_GRIND_CADCHF_OPT.jsonl` | 70 | 0 | 0 | - | - | 482c4cf5f78a9bb1 |
| `sends_GRIND_CADCHF_OPTB.jsonl` | 541364 | 891 | 0 | 2026-10-28 | 2026-11-09 | 0d8e1d37710c55b9 |
| `sends_GRIND_CADCHF_OPTC.jsonl` | 71 | 0 | 0 | - | - | 05556ddfef642b4d |
| `sends_GRIND_CADCHF_OPTD.jsonl` | 1283255 | 2108 | 0 | 2026-10-28 | 2026-11-09 | 1a9a7bf61f300520 |
| `sends_GRIND_CADCHF_OPTE.jsonl` | 1304188 | 2121 | 1942 | 2026-10-28 | 2026-11-04 | cb84726c27f387a2 |
| `sends_GRIND_EURGBP_ALT.jsonl` | 70 | 0 | 0 | - | - | 31a3af8b80213857 |
| `sends_GRIND_EURGBP_ALTD.jsonl` | 44491 | 74 | 0 | 2026-10-28 | 2026-11-09 | 01dcf7cc047104cc |
| `sends_GRIND_EURGBP_ALTE.jsonl` | 5325065 | 8651 | 8605 | 2026-10-28 | 2026-11-04 | d38f88d94cb3c984 |
| `sends_GRIND_EURGBP_OPT.jsonl` | 70 | 0 | 0 | - | - | 976eaf7ca67827bb |
| `sends_GRIND_EURGBP_OPTB.jsonl` | 613627 | 1009 | 0 | 2026-10-28 | 2026-11-10 | 0a2b612814d3f06e |
| `sends_GRIND_EURGBP_OPTC.jsonl` | 71 | 0 | 0 | - | - | 92b01628178c4b99 |
| `sends_GRIND_EURGBP_OPTD.jsonl` | 1059664 | 1741 | 0 | 2026-10-28 | 2026-11-10 | 6b435d072c1f56a4 |
| `sends_GRIND_EURGBP_OPTE.jsonl` | 1249232 | 2036 | 1757 | 2026-10-28 | 2026-11-04 | 3c070108f007978e |
| `sends_GRIND_EURUSD_ALT.jsonl` | 70 | 0 | 0 | - | - | 98f1ba1ca7c9de69 |
| `sends_GRIND_EURUSD_ALTC.jsonl` | 144709 | 239 | 0 | 2026-10-28 | 2026-11-11 | afc2372bb113c587 |
| `sends_GRIND_EURUSD_ALTD.jsonl` | 132638 | 219 | 0 | 2026-10-28 | 2026-11-09 | 82f17d73fe4f361c |
| `sends_GRIND_EURUSD_ALTE.jsonl` | 7677673 | 12469 | 12339 | 2026-10-28 | 2026-11-04 | a716e1be2029b51e |
| `sends_GRIND_EURUSD_OPT.jsonl` | 70 | 0 | 0 | - | - | 5a8c674f7bb93637 |
| `sends_GRIND_EURUSD_OPTB.jsonl` | 955892 | 1572 | 0 | 2026-10-28 | 2026-11-09 | ba36dd44eb51104c |
| `sends_GRIND_EURUSD_OPTC.jsonl` | 1554586 | 2555 | 0 | 2026-10-28 | 2026-11-11 | 7c51b4961c58eb64 |
| `sends_GRIND_EURUSD_OPTD.jsonl` | 1317278 | 2165 | 0 | 2026-10-28 | 2026-11-09 | 8f7069e2172a265e |
| `sends_GRIND_EURUSD_OPTE.jsonl` | 2274897 | 3715 | 2550 | 2026-10-28 | 2026-11-04 | 0c1406e2166ea994 |
| `sends_GRIND_GBPCHF_ALTC.jsonl` | 123355 | 204 | 0 | 2026-10-28 | 2026-11-11 | 58dedcc3c660cf6a |
| `sends_GRIND_GBPCHF_OPTC.jsonl` | 726414 | 1194 | 0 | 2026-10-28 | 2026-11-11 | 8c7b9b5a2fc9140a |
| `sends_GRIND_GBPUSD_ALT.jsonl` | 70 | 0 | 0 | - | - | 56bd08bba80cb2ef |
| `sends_GRIND_GBPUSD_ALTD.jsonl` | 102175 | 169 | 0 | 2026-10-28 | 2026-11-09 | 7731420f8e2375f1 |
| `sends_GRIND_GBPUSD_ALTE.jsonl` | 3415503 | 5559 | 5228 | 2026-10-28 | 2026-11-04 | 14228d1d2489d0ae |
| `sends_GRIND_GBPUSD_OPT.jsonl` | 70 | 0 | 0 | - | - | 2c0cd2508c48be26 |
| `sends_GRIND_GBPUSD_OPTB.jsonl` | 865422 | 1423 | 0 | 2026-10-28 | 2026-11-09 | 57b2e09b63c13fba |
| `sends_GRIND_GBPUSD_OPTC.jsonl` | 71 | 0 | 0 | - | - | 5a513e6cbf0f6437 |
| `sends_GRIND_GBPUSD_OPTD.jsonl` | 970324 | 1595 | 0 | 2026-10-28 | 2026-11-10 | 1a0be86efd3fee9a |
| `sends_GRIND_GBPUSD_OPTE.jsonl` | 1817240 | 2966 | 2140 | 2026-10-28 | 2026-11-04 | 51e39b17059f6721 |
| `sends_GRIND_NZDCAD_ALT.jsonl` | 70 | 0 | 0 | - | - | 84c2d5068b8f5c4c |
| `sends_GRIND_NZDCAD_ALTB.jsonl` | 71 | 0 | 0 | - | - | 7baf99e6b2716e7e |
| `sends_GRIND_NZDCAD_ALTC.jsonl` | 71 | 0 | 0 | - | - | 3feb865cf076ebaa |
| `sends_GRIND_NZDCAD_ALTD.jsonl` | 71 | 0 | 0 | - | - | 96dd360a10a0dccc |
| `sends_GRIND_NZDCAD_OPT.jsonl` | 70 | 0 | 0 | - | - | 8c7a903d9774d2fb |
| `sends_GRIND_NZDCAD_OPTB.jsonl` | 500101 | 823 | 0 | 2026-10-28 | 2026-11-10 | c21723e1ee2ad0b9 |
| `sends_GRIND_NZDCAD_OPTC.jsonl` | 71 | 0 | 0 | - | - | 03324c950c8cd424 |
| `sends_GRIND_NZDCAD_OPTD.jsonl` | 71 | 0 | 0 | - | - | 0142a2800b470cd2 |
| `sends_GRIND_NZDCHF_OPT.jsonl` | 70 | 0 | 0 | - | - | 37d3b515383feea1 |
| `sends_GRIND_NZDCHF_OPTB.jsonl` | 532987 | 878 | 0 | 2026-10-28 | 2026-11-10 | 01b511844b0b5194 |
| `sends_GRIND_NZDCHF_OPTC.jsonl` | 71 | 0 | 0 | - | - | c1b32c08a74d020b |
| `sends_GRIND_NZDCHF_OPTD.jsonl` | 71 | 0 | 0 | - | - | b98c5f4c9e5a3f73 |

Totals: 93035 send rows; 57918 refused with 10017 (E, 4 Nov).

Line count: 99
