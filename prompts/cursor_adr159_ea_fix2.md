This message has a line count at the bottom

# CURSOR -- ADR-159 EA FIX 2: START VALUES KEYED BY ACCOUNT (T-4), HISTORY FLAG (T-5)

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Branch | `adr159-ea` at `7ffc506` (code = `05f5ae7`, suite 1724/1724) | verified by Claude on origin |
| Audit | `prompts/deepseek_adr159_audit_response.md` (318 lines, all sections, no key) | counted by Claude |
| T-1 no-basis | DeepSeek BREAKS -- **rejected**: `g_grind_breaker_day_key = key` is set BEFORE the no-basis `return`, so every later tick skips the branch and adopts normally; adoption is one tick late, only on a day the initial deposit never loaded (and once known it stays known for the session) | verified by Claude in `grind_engine.mqh` `Grind_BreakerOnTick` |
| T-1 enable switch | DeepSeek BREAKS -- **by design**: `InpBreakerEnable=false` is ADR-158's per-instance off switch; the cycle-3 preset check must confirm no preset disables it | noted for the preset step |
| T-3 forced flush | DeepSeek NEEDS-FIX -- **rejected**: the archive `WebRequest` timeout is 200 ms (`grind_telemetry.mqh`, 4th argument), not 5000 ms; the routine flush already posts every 2 s | verified by Claude |
| T-6 queue | DeepSeek NEEDS-FIX -- **rejected**: queue max 5000, drop-oldest; eject events are a handful a day behind the backoff | verified by Claude |
| **T-4** | **Accepted.** Start GVs are keyed by day only; stale values from a previous account could be used with `start_known=true` if the close-out clean-up is skipped | this prompt |
| **T-5** | **Accepted.** If `HistorySelect` fails at the roll, `nontrade` and `swap_day` are silently 0, and a history-rebuilt `balance_start` is wrong | this prompt |
| Pipshed | `snapshot_row_from_detail` maps only the 21 contract keys and stores the full detail JSON; an extra `history_ok` key is kept, and `null` in any money field becomes NULL and renders as `--` | verified by Claude at pipshed `e475506` |

## FOR GEMINI

- **Q1.** T-5 nulls: when history fails, `nontrade` and `swap_day` are
  null; and when the start is ALSO unknown, `balance_start` and
  `realised` are null too. Fields from stored values stay. Accept?

## BRANCH

`adr159-ea` from `7ffc506`: `git fetch origin`, `git switch adr159-ea`,
`git pull --ff-only`, confirm HEAD `7ffc506`. TWO commits (tests + stubs,
then implementation), push after each. No merge.

## 1. CHANGES -- `ea/grind_snapshot.mqh`

**T-4.**
- `#define GRIND_SNAPSHOT_START_LOGIN "GRIND_SNAPSHOT_START_LOGIN"`.
- Pure: `bool Grind_SnapshotStartKnown(const bool day_exists, const int
  stored_day, const int ended_num, const bool login_exists, const long
  stored_login, const long login_now)` returns `day_exists && stored_day
  == ended_num && login_exists && stored_login == login_now`.
- In `Grind_SnapshotEmit`, compute `start_known` with it, reading
  `GRIND_SNAPSHOT_START_LOGIN` as `(long)GlobalVariableGet(...)`, and
  `login_now = AccountInfoInteger(ACCOUNT_LOGIN)`.
- Where the new day's start values are written, also
  `GlobalVariableSet(GRIND_SNAPSHOT_START_LOGIN, (double)login_now)`.
  (The clean-up prefix `GRIND_SNAPSHOT_` already covers it.)

**T-5.**
- `GrindSnapshot` gains `bool history_ok`.
- `Grind_SnapshotCompute` sets `s.history_ok = true;` as its first line (a
  default; `Grind_SnapshotEmit` overrides it).
- In `Grind_SnapshotEmit`: `const bool history_ok = HistorySelect(win_from,
  win_to);`, keep the deal loop inside `if(history_ok)`, and after the
  compute call set `s.history_ok = history_ok;`.
- `Grind_SnapshotJson`: `nontrade` is `null` when `!history_ok`;
  `swap_day` is `null` when `!start_known || !history_ok`; `balance_start`
  and `realised` are `null` when `!start_known && !history_ok`. Append
  `,"history_ok":true|false` as the LAST key, after `balance_start_source`.

## 2. TESTS (commit 1) -- `ea/fxgrind_tests.mq5`, registered after SN15

Same reset discipline as the other SN tests. Hand derivation above every
numeric expectation. In SN17 and SN18, set `start_known` and `history_ok`
AFTER the `Grind_SnapshotCompute` call (compute sets the default).

| test | assert |
|---|---|
| `Test_SN16_StartKnownRequiresLogin` | (true,20260923,20260923,true,1514582088,1514582088) true; stored day 20260922 false; login 1514264399 vs 1514582088 false; login_exists false false; day_exists false false |
| `Test_SN17_JsonHistoryFailedKnownStart` | SN3's compute inputs, `start_known` true, `history_ok` false: contains `"nontrade":null`, `"swap_day":null`, `"history_ok":false`, `"balance_start":10190.96`, `"inventory_pnl":330.46` |
| `Test_SN18_JsonHistoryFailedUnknownStart` | SN4's compute inputs, `start_known` false, `history_ok` false: contains `"balance_start":null`, `"realised":null`, `"nontrade":null`, `"swap_day":null` |
| `Test_SN19_JsonHistoryOkDefault` | SN3's struct after `Grind_SnapshotCompute` (default `history_ok`): contains `"history_ok":true` |

**Commit 1** `ADR-159 EA fix 2 tests and stubs (SN16-SN19)`: the struct
field and `GRIND_SNAPSHOT_START_LOGIN` exist; `Grind_SnapshotStartKnown`
returns `false`; `Grind_SnapshotCompute`, `Grind_SnapshotEmit` and
`Grind_SnapshotJson` are UNCHANGED.

**Commit 2** `ADR-159 EA fix 2: start values keyed by account (T-4), history_ok (T-5)`.

**Expected (operator runs):** stub `SUMMARY: 1731/1739`, failing exactly
`SN16 match`, `SN17 nontrade null`, `SN17 swap_day null`, `SN17 history_ok
false`, `SN18 balance_start null`, `SN18 realised null`, `SN18 nontrade
null`, `SN19 history_ok true`. Real: `SUMMARY: 1739/1739`. Use exactly
these assertion names (SN16's other four: `SN16 day mismatch`, `SN16 login
mismatch`, `SN16 login missing`, `SN16 day missing`; SN17's other two:
`SN17 balance_start kept`, `SN17 inventory kept`; SN18's fourth: `SN18
swap_day null`).

## NEGATIVE SPACE

- No change outside `ea/grind_snapshot.mqh` and `ea/fxgrind_tests.mq5`.
- No change to any existing assertion. No change to D9, the breaker, the
  flush, or the archive queue (T-1, T-3, T-6 are rejected above).
- Do NOT compile, run MetaTrader or the suite. No `git add .` / `-u`,
  stash, amend, merge or PR. ASCII only.

## REPLY

ONLY the two commit hashes and `git ls-remote origin adr159-ea`.

Line count: 99
