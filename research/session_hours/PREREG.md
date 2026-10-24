This message has a line count at the bottom

# SESSION HOURS: DOES A LAYER'S OUTCOME DEPEND ON WHEN IT WAS ENTERED? (PRE-REGISTERED 24 OCT ~03:30Z)

| | |
|---|---|
| For | The operator, 24 Oct ~00:08Z ("the different session one sounds interesting. we are already testing calm vs not calm") and ~02:48Z ("ok let's proceed"): step 1 of 3 before any session gate (HANDOFF s89 continued 2) |
| Question | Do layers entered INSIDE ADR-161's entry window (07:00-16:55 Toronto = 11:00-20:55Z, weekdays) fare differently from those entered OUTSIDE it, consistently enough to justify a replay of a gated arm? |
| Inputs | 22 archive exports (A seven, B nine, D six): `inputs.sha256` (full hashes, sizes); not in git |
| Code | `session_hours.py`; tests `test_session_hours.py` 21 / 21, committed FIRST and failing against a stub (21 errors); 12 single-line mutants all caught |
| Status | **PRE-REGISTERED: committed before any hour split of the real data is read.** Results go to `results.md` from `session_hours.py`, unchanged |

## 1. ONE WORKED EXAMPLE

An illustrative EURUSD OPT (add = exit 9, 0.01 lots: 0.10 USD a pip). A long ENT fills at 1.16000 at 06:40Z (ASIA, outside the window). London
opens at 07:00Z and EURUSD falls 60 pips by 10:00Z: the layer is added under, the side reaches 8 and rolls,
and this layer is closed by the roll at 1.15400: gross -$6.00, net -$6.08. A second long ENT fills at
1.15400 at 13:20Z (inside the window) and its exit at 1.15490 fills at 13:45Z: gross +$0.90, net +$0.82.
The study books the first against OUTSIDE and the second against INSIDE: a gate that blocks entries at
06:40Z would not have opened the first layer at all. That is the comparison: by ENTRY time, because a session
gate controls entries (ADR-161 s1), not exits.

## 2. DATA AND ERAS

| Era | Account | Instances | Entries from | to (outcomes censored here) | Deciding |
|---|---|---|---|---|---|
| A | FTMO 1514878887 | seven `_OPT` | 7 Oct 22:08Z (the IC-strategy attach) | 21 Oct 21:46Z (Algo off) | yes |
| B | IC 53066709 | nine `_OPTB` | 7 Oct 02:25Z (the gate build) | 23 Oct 21:00Z (Friday's close) | yes |
| D1 | IC 53077984 | six `_OPTD` | 7 Oct 02:25Z | 21 Oct 14:50Z (the rebuild's first flatten) | yes |
| D2 | IC 53077984 | six `_OPTD` | 21 Oct 15:55Z (t1, exit = add) | 23 Oct 21:00Z | reported only (two days) |

Not used: C (its probes changed several times in the span), E (one day), the ALT arms (two days). The
roll-flurry EPISODE days, by entry date (UTC): 7, 14, 15, 16 Oct (the viability note s3; 1 and 5-6 Oct fall
before the eras). Commission a closed layer: A 0.06, B and D 0.08 USD (`sr_table.py`). Swap is not counted.

## 3. UNIT, LINKING, MEASURES (as coded; the tests fix each rule)

- A layer = an ENT position (an IN fill with role ENT; duplicates by deal ticket once). Entry time = that
  fill's broker time minus 3 h (GMT+3; a scalp row with another offset STOPS the run).
- Its outcome = the scalp_history row of the same instance, direction and entry price whose close time is
  within 2 s of the position's first OUT_BY / OUT fill; each row used once. Status: scalped, rolled
  (`rolled`), ejected (`ejected`), unlinked (a close and no row), open (no close before the era's end).
- Per era and per pair, inside / outside the window: entered, closed, scalped, rolled, open, unlinked, net
  USD (gross less commission per closed layer), net per closed layer, roll rate (rolled / closed). Also by
  block (ASIA 21-07Z, LDN_AM 07-11Z, LDN_NY 11-16Z, NY_PM 16-21Z) and episode days against the rest.

## 4. THE RULE (decides; written before any read)

An era has a DIRECTION when, pooled over its pairs:
- OUTSIDE WORSE: net per closed layer outside < inside AND roll rate outside > inside AND outside is worse on
  net per closed layer on at least half of the pairs counted (a pair counts with >= 20 closed layers each side);
- INSIDE WORSE: the mirror.
**WORTH A REPLAY if at least two of A, B, D1 share a direction; else NOT WORTH IT.**

- **WORTH A REPLAY (either way):** step 2: the replay of the same arm with ADR-161's window against 24 h, on
  sweep11's calm weeks and October, pre-registered then. No EA change (ADR-161 is merged, default off).
- **NOT WORTH IT:** session gating is dropped for now; the regime axis (OPT / ALT / a wide arm) stays the
  question; the block tables stay on record.

## 5. SELF-CHECKS FIRST (any failure: STOP, report, amend before any net is read)

1. Every input's sha256 equals `inputs.sha256`.
2. Per era: unlinked <= 5% of (closed + unlinked); at least 200 closed layers in each deciding era.
3. Per era: inside + outside = the era total, and the four blocks sum to it (entered and closed).
4. No scalp row with a broker offset other than 10800 s (the code stops).

## 6. CLAUDE'S PREDICTIONS (before any read)

1. NOT WORTH IT: the day (calm or October) moves outcomes far more than the hour.
2. LDN_AM (07-11Z, outside the window) has the highest roll rate of the four blocks in at least 2 of A, B, D1.

## 7. LIMITS

- One market path of about two and a half weeks; A, B and D trade mostly the same pairs at the same times, so
  "two of three eras" is closer to one market seen through three accounts than three independent tests.
- By entry time only: a layer entered in Asia and rolled in London counts as Asia (the gating question).
- Open layers carry no outcome and are more often the late ones of an era: reported per block, not scored.
- ADR-161's fixed window only; any other window needs an EA change (the full pipeline) and would be chosen
  in-sample. The study cannot say which window is best, only whether this one separates outcomes.
Line count: 80
