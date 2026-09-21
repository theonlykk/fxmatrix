This message has a line count at the bottom

# grind_gv_clean -- response

Spec read at commit `45cf24f` (`prompts/gv_clean_script.md`, footer `Line count: 91` verified).

## Commits on origin

| # | role | hash |
|---|---|---|
| 1 | `scripts/grind_gv_clean.mq5` | `f466643` |
| 2 | this file | `a3f2616` |

## git diff --stat origin/main...feat/grind-gv-clean

```
 prompts/gv_clean_script_response.md | 40 +++++++++++++++++++++++++
 scripts/grind_gv_clean.mq5          | 60 +++++++++++++++++++++++++++++++++++++
 2 files changed, 100 insertions(+)
```

## Prefix grep evidence (`ea/`)

| prefix | example path |
|---|---|
| `GRIND_DAILY_API_COUNT` | `ea/grind_api_counter.mqh` |
| `GRIND_DAILY_API_DATE` | `ea/grind_api_counter.mqh` |
| `GRIND_MAE_ANCHOR_` | `ea/grind_mae.mqh` |
| `GRIND_MAE_EQUITY_LOW_` | `ea/grind_mae.mqh` |
| `GRIND_CARRY_DAY_` | `ea/grind_carry.mqh` |
| `GRIND_CARRY_SHIFT_` | `ea/grind_carry.mqh` |
| `GRIND_CARRY_ACCRUED_` | `ea/grind_carry.mqh` |
| `GRIND_CARRY_RELEASE_` | `ea/grind_config.mqh`, `ea/grind_carry.mqh` |
| `GRIND2226_` | `ea/grind_cap.mqh`, `ea/grind_magic_lock.mqh` |
| `GRIND_DEINIT_` | `ea/grind_archive.mqh` |

Persistent `GlobalVariableSet` targets in `ea/grind_*.mqh` are covered by these prefixes; reporter heartbeat/magic/claim lock use `GlobalVariableTemp`.

Line count: 38
