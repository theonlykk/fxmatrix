This message has a line count at the bottom

# EXPORT M1 BID/ASK BARS FOR THE EXIT COUNTERFACTUAL

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Purpose | Price input for the exit_pips counterfactual, `docs/architecture/geometry-cycle2-derivation.md` s7.2 | Method ruled by Gemini 2026-09-20 ("Approved") |
| Why ticks, not bars | Short exits fill on the ASK. `export_history.mq5` writes BID bars with one spread value per bar, which cannot say whether the ask traded a level | Verified in source, `scripts/export_history.mq5` header |
| Why aggregate to M1 | Nine days of raw ticks for 8 symbols is too large to move; per-minute bid AND ask high/low answers "did the level trade" exactly, to one-minute time resolution | Design choice |
| Baseline | fxmatrix `origin/main` at `2111eef` | Read by Claude |
| Scope | One new read-only MQL5 script, one new Python validator, one new pytest file | This spec |
| Review | Read-only export, no live orders. DeepSeek optional per ARCHITECT s2. Not sent to Gemini | Operator may override |

## BRANCH

Create `feat/export-m1-bidask` from `origin/main`. Three commits, in this
order. Push. Do NOT merge. Do NOT open a PR.

1. `tests/test_validate_m1_bidask.py` plus a stub
   `scripts/validate_m1_bidask.py` whose functions exist and raise
   `NotImplementedError`. The tests MUST fail.
2. `scripts/validate_m1_bidask.py` implemented. All tests pass.
3. `scripts/export_m1_bidask.mq5`.

## CONTEXT

- Tick and deal times on this broker are BROKER time, UTC+3. Store them as
  broker time in a column named `time_broker`. NEVER label them UTC or `Z`
  (ARCHITECT s11).
- Follow the conventions of `scripts/export_history.mq5`: read-only header
  comment, `FolderCreate(..., FILE_COMMON)`, `FileOpen(... FILE_WRITE |
  FILE_TXT | FILE_ANSI | FILE_COMMON)`, `Print` status per symbol.
- CSVs are never committed (`.gitignore` covers `data/`).

## DESIGN

### D1. `scripts/export_m1_bidask.mq5`

Script inputs:

    input datetime InpFrom   = D'2026.09.10 00:00:00';   // broker time
    input datetime InpTo     = D'2026.09.19 00:00:00';   // broker time
    input string   InpFolder = "m1_bidask";

Symbols, fixed array, exactly these eight:

    GBPUSD EURUSD EURGBP AUDCAD AUDCHF CADCHF NZDCAD AUDNZD

For each symbol:

1. Fetch ticks one broker DAY at a time with `CopyTicksRange(symbol,
   ticks, COPY_TICKS_INFO, from_msc, to_msc)`. Day chunks keep memory
   bounded.
2. Skip any tick where bid <= 0 or ask <= 0.
3. Bucket by minute: `minute = (tick.time_msc / 60000) * 60000`.
4. Per non-empty minute write one row:

       time_broker,bid_open,bid_high,bid_low,bid_close,ask_open,ask_high,ask_low,ask_close,ticks

   `time_broker` formatted `YYYY-MM-DD HH:MM:SS`. Prices with
   `DoubleToString(v, digits)` where `digits = SymbolInfoInteger(symbol,
   SYMBOL_DIGITS)`. Open = first tick in the minute, close = last, high
   and low over all ticks in the minute, separately for bid and ask.
   Minutes with no ticks are NOT written.
5. Output file `<InpFolder>\<SYMBOL>_m1_bidask.csv`, header row first.

Also write `<InpFolder>\symbols.csv` with header
`symbol,digits,point,contract_size` and one row per symbol, from
`SYMBOL_DIGITS`, `SYMBOL_POINT`, `SYMBOL_TRADE_CONTRACT_SIZE`.

At the end, `Print` per symbol: rows written, first and last
`time_broker`, total ticks.

### D2. `scripts/validate_m1_bidask.py`

Functions:

    load_bars(path) -> pandas.DataFrame
    check_bars(df) -> list[str]        # list of violation messages, empty = valid
    summarise(df) -> dict              # rows, first, last, rows_per_date

`check_bars` reports, one message per violated rule, naming the first
offending `time_broker`:

- R1 `time_broker` strictly increasing (no duplicates).
- R2 every `time_broker` has seconds == 0.
- R3 bid_low <= min(bid_open, bid_close) and bid_high >= max(bid_open, bid_close).
- R4 the same for ask.
- R5 ask_low >= bid_low and ask_high >= bid_high.
- R6 ticks >= 1.

CLI: `python scripts/validate_m1_bidask.py <folder>` validates every
`*_m1_bidask.csv` in the folder and prints, per symbol: rows, first, last,
violations (count and first message), and rows per date.

### D3. `tests/test_validate_m1_bidask.py`

Build the fixtures in the test file itself; no files on disk. Expected
values below are derived by hand.

| test | fixture | expected |
|---|---|---|
| T1 valid | 3 rows at 10:00, 10:01, 10:02, all rules hold | `check_bars` == [] |
| T2 duplicate minute | rows at 10:00, 10:00 | exactly 1 message, contains "R1" |
| T3 seconds | one row at 10:00:30 | exactly 1 message, contains "R2" |
| T4 bid high | bid_open 1.10005, bid_high 1.10000 | exactly 1 message, contains "R3" |
| T5 ask low | ask_close 1.10010, ask_low 1.10020 | exactly 1 message, contains "R4" |
| T6 crossed | ask_low 1.09990 below bid_low 1.10000, all else valid | exactly 1 message, contains "R5" |
| T7 ticks | ticks 0 | exactly 1 message, contains "R6" |
| T8 summarise | T1 fixture | rows 3, first "2026-09-10 10:00:00", last "2026-09-10 10:02:00", rows_per_date {"2026-09-10": 3} |

T2 to T7 each violate EXACTLY one rule. If a fixture you build trips two
rules, fix the fixture, not the expectation.

Commit 1: all eight tests FAIL against the stub. Commit 2: all eight PASS.
Report the pytest summary line at both commits. **If any test passes
against the stub, STOP and report it** -- it is not testing the change.

## NEGATIVE SPACE

- Do NOT deploy. Do NOT touch the VPS.
- Do NOT CLI compile. Do NOT launch MetaTrader. Do NOT run the MQL5 script.
  The operator compiles in the MetaEditor GUI and runs it.
- Do NOT modify any file under `ea/`, `ea/presets/`, or any existing script.
- No `OrderSend`, `OrderModify`, `OrderDelete`, `PositionClose`, trade
  class, or `GlobalVariable*` call anywhere in the new script.
- Do NOT commit any CSV or anything under `data/`.
- Do NOT `git stash`. Do NOT check out files from other commits. Do NOT
  merge. No PR. No `git add .` or `git add -u` -- stage files by exact name.
- ASCII only in every file.

## FAILURE MODES -- STOP AND REPORT

- `CopyTicksRange` has a different signature or flag name than written
  here: STOP, quote the MQL5 reference, do not guess.
- Anything in D1 requires a trading or GlobalVariable call: STOP.
- A test cannot be written to violate exactly one rule: STOP and say which.
- pytest is not available in the repo venv: STOP.

## SELF-REVIEW

Before each commit re-read the full diff. Confirm: no file outside the
three named; no forbidden call (grep the script for `Order`, `Position`,
`GlobalVariable`, `CTrade`); ASCII only.

## RESPONSE FORMAT

Write the full response to `prompts/export_m1_bidask_response.md` on the
same branch, containing: the three commit hashes AS THEY EXIST ON ORIGIN,
`git diff --stat origin/main...feat/export-m1-bidask`, the pytest summary
line at commit 1 and at commit 2, and anything you were unsure of. Open
with `This message has a line count at the bottom` and close with
`Line count: N` where N is the actual count.

PUSH the branch. Reply in chat with ONLY: the branch name, the commit
hashes as they exist on origin, and one line saying the report is pushed.

## AFTER CURSOR (operator)

1. GUI compile `scripts/export_m1_bidask.mq5`; run it on the DESKTOP
   terminal. Read-only, algo stays off.
2. Copy the output folder from the terminal's Common\Files to
   `D:\fxmatrix\data\local\m1_bidask\`.
3. `python scripts/validate_m1_bidask.py data\local\m1_bidask` and paste
   the output.
4. Upload the 8 CSVs plus `symbols.csv` and the deals dump to the chat.

Line count: 170
