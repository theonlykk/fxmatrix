This message has a line count at the bottom

# CURSOR PROMPT: TWO-ARM PRESETS FOR FTMO (FLEET E), D AND C -- A NEW STAGE IN ic_presets.py (TESTS FIRST)

| | |
|---|---|
| Written | 17 Oct 2026 (HANDOFF s85 continued 7), Claude (Lead Engineer) |
| Why | Next week's layout and geometry are RULED (`docs/research/fleet-d-two-arm-ring-2026-10-16.md` s10, s11): OPT and a wide ALT arm per pair, exit = add on both, cap 7, on a new FTMO demo (fleet E), on D (its mirror) and on C. `scripts/ic_presets.py` has no stage for it (FLEETS B, C, D; no ALT; no E) |
| Base | Branch `presets-twoarm` from `main` at the commit that adds THIS file. Python only: `scripts/ic_presets.py`, `scripts/test_ic_presets.py`, a new table, new preset files |
| Review | Argon (Gemini, in Cursor) on `333e7e6`: `review/argon-presets-twoarm` `ce53c05`, every point checked by Claude in source; T3 corrected and six fixes made in this version (s8). Cursor reads THIS version |

## 0. RESTATE AND STOP (do this first; write nothing else)

1. Restate each item of s2 and s3 in one line, quoting this prompt.
2. For every test of s4: its name and the values it asserts, with the arithmetic.
3. Say which tests fail at your tests commit and why, and which pass there (and why that is right).
4. STOP. Wait for the operator's "go".

## 1. AUDIT TRAIL (verified by Claude in source at `b9de35e`)

| # | Fact | Where | Status |
|---|---|---|---|
| T1 | B, C, D and A presets of one pair differ ONLY in add, exit (and per-side exits), width where probed, `InpTelemetryInstance`, `InpConfigWarning` and A's `InpBreakerEnable`; all nine `ea/presets_d/*_opt_d_r3.set` have the same 41 keys in the same order | `diff` of `eurusd` and `audcad` r3 across `presets_b/c/d`, `presets/eurusd_opt_a_r2.set` | READ |
| T2 | Magic scheme `2226` + pair index (2 digits) + slot (`01` OPT, `02` ALT): GBPUSD 01, EURUSD 02, EURGBP 03, AUDCAD 04, AUDCHF 05, CADCHF 06, NZDCHF 07, NZDCAD 08, AUDNZD 09. The same magic on every account | `presets_d/*_r3.set`, `presets/*_alt.set` | READ |
| T3 | `GRIND_CAP_ALL_MAGICS` (18 magics, pairs 01-09) feeds the currency cap (disabled: `InpCapLegAThresh` / `B` 0.0 everywhere) AND `Grind_IsFleetMagic`, by which the slot guard counts resting ENT orders a second time (`Grind_SlotRestingEnt`). A magic outside it (GBPCHF, index 10): its exposure GV is not summed (cap off), and its resting entries (at most 4 on C) are counted once, not twice: the guard reads up to 4 low on C (6 instances, about 90-96 of 194). Harmless now; no EA change in this prompt (backlog: add index 10 before a 12-instance fleet runs GBPCHF). The other two users are tests only | `ea/grind_cap.mqh` 17-31, 207-264; `ea/grind_exitq.mqh` 105-161; `ea/grind_engine.mqh` 145 (order-test harness); `ea/grind_magic_lock.mqh` 26-30 (called from `fxgrind_tests.mq5` only) | READ (Argon T3, G5) |
| T4 | ADR-153 guard, FATAL at init: 0.5 <= add / width <= 4.0 per side | `ea/fxgrind.mq5` 174-205; `ea/grind_pure.mqh` 10, 49; `GUARD_MIN/MAX` in `ic_presets.py` 47 | READ |
| T5 | Width is the L0 quote distance: buy at mid - width, sell at mid + width | ADR-123, ADR-124 | READ |
| T6 | The round stage's width rule: `tight_width(adds)` = ceil to the half pip of max(add) / 4; stranded = width + 1 | `ic_presets.py` 377-380, 393-413 | READ |
| T7 | `validate` requires `InpMaxLayers` = 10 unless given; `with_v22_keys` and the r3 presets already carry `InpRollGateOpposite=0`, `InpApiEntryStop=1000000`, `InpApiSoftWarn=999000` | `ic_presets.py` 262-309; `presets_d/eurusd_opt_d_r3.set` | READ |
| T8 | Every repo preset is ASCII, LF, `TelemetryAPIKey=` blank (the key is injected at deploy) | `ic_presets.py` 286-287, 544-545 | READ |

## 2. THE TABLE (commit it exactly: `scripts/ic_geometry_twoarm.json`)

```json
{
  "status": "TWO-ARM t1 (HANDOFF s85, fleet D note s10-s11): OPT + ALT per pair, exit = add on both, cap 7. E (FTMO) ALT at q90, D and C at q95 (research/alt_adds/results_2026-10-17.md s6); GBPCHF from its range.",
  "round": "t1",
  "cap": 7,
  "deadband": 2.0,
  "roll_gate": 0,
  "pair_index": {"GBPUSD": 1, "EURUSD": 2, "EURGBP": 3, "AUDCAD": 4, "AUDCHF": 5, "CADCHF": 6,
                 "NZDCHF": 7, "NZDCAD": 8, "AUDNZD": 9, "GBPCHF": 10},
  "template": {"GBPCHF": "EURUSD"},
  "fleets": {
    "E": {"account": "FTMO demo, new account", "box": "new Linux server",
          "pairs": {"GBPUSD": {"OPT": 9, "ALT": 24}, "EURUSD": {"OPT": 7, "ALT": 23},
                    "EURGBP": {"OPT": 3, "ALT": 16}, "AUDCAD": {"OPT": 6, "ALT": 27},
                    "AUDCHF": {"OPT": 4, "ALT": 21}, "CADCHF": {"OPT": 4, "ALT": 9}}},
    "D": {"account": "IC Markets demo 53077984", "box": "wine-d",
          "pairs": {"GBPUSD": {"OPT": 9, "ALT": 30}, "EURUSD": {"OPT": 7, "ALT": 27},
                    "EURGBP": {"OPT": 3, "ALT": 19}, "AUDCAD": {"OPT": 6, "ALT": 27},
                    "AUDCHF": {"OPT": 4, "ALT": 22}, "CADCHF": {"OPT": 4, "ALT": 12}}},
    "C": {"account": "IC Markets demo 53071896", "box": "wine-c",
          "pairs": {"EURUSD": {"OPT": 7, "ALT": 27}, "AUDCAD": {"OPT": 6, "ALT": 27},
                    "GBPCHF": {"OPT": 9, "ALT": 24}}}
  }
}
```

Each number is the arm's add AND exit, in pips.

## 3. THE STAGE `twoarm` (code)

- **A new stage**, `--stage twoarm --table scripts/ic_geometry_twoarm.json [--write]`. Existing stages
  (`c10`, `p2`, `round`, `ftmo`), their functions and their tests are NOT changed.
- **Template:** for pair P, `ea/presets_d/<p>_opt_d_r3.set`; for a pair in `"template"` (GBPCHF), the
  named pair's D r3 file (EURUSD). The output keeps the template's keys and their order exactly.
- **Output:** one file per fleet, pair and slot: `ea/presets_<f>/<pair>_<slot>_<f>_t1.set`, all lower
  case (`ea/presets_e/` is new: `--write` calls `os.makedirs(os.path.dirname(path), exist_ok=True)`
  before each `open`). 12 for E, 12 for D, 6 for C: 30 files.
- **The keys the stage sets (`TWOARM_CHANGES`); every other key is the template's value:**
  - `InpMagic` = 2226 * 10000 + pair_index * 100 + (1 for OPT, 2 for ALT); `InpSlot` = `OPT` / `ALT`;
    `InpTelemetryInstance` = `GRIND_<PAIR>_<SLOT><F>` (e.g. `GRIND_EURUSD_ALTD`, `GRIND_GBPCHF_OPTC`,
    `GRIND_AUDCAD_ALTE`).
  - `InpCapLegA` / `InpCapLegB` = the pair's first and last three letters.
  - `InpAddPips` = `InpExitPips` = the table's value; `InpAddPipsLong/Short`, `InpExitPipsLong/Short`,
    `InpWidthPipsLong/Short` = `-1.0`.
  - `InpWidthPips` = `tight_width([add])`; `InpStrandedThreshPips` = width + 1; `InpDeadbandPips` = the
    table's 2.0; `InpMaxLayers` = 7; `InpRollGateOpposite` = 0; `InpBreakerEnable` = `false`.
  - `InpConfigWarning` = `FLEET <F> two-arm t1 <PAIR> <SLOT> <tag>: cap 7, add = exit <a>, width <w>,
    deadband 2.0; lattice + reroll on, roll gate 0 (<account>, <box>)`. `<tag>`, in this order: OPT
    -> `-`; a pair in the table's `"template"` (GBPCHF) -> `range guess`; fleet E -> `q90`; fleets D and
    C -> `q95`. `<account>` and `<box>` are `table["fleets"][F]["account"]` and `["box"]` (not
    `ACCOUNT`, which has no E). Numbers as `_num` (one decimal).
- **`twoarm_preset(template_text, fleet, pair, slot, add, table)`** returns the preset text (the bullets
  above applied to the template; key order kept).
- **`validate_twoarm(template_text, out_text, fleet, pair, slot, add, table)`** returns a list of errors:
  keys or order differ from the template (one error containing `keys or order`); every single-key error
  names its key (e.g. `InpWidthPips 6.5, not 7.0`); a key outside `TWOARM_CHANGES` differs; any value of the
  bullets above not as specified; the guard (T4) on both sides; `InpVirtualLattice` / `InpLatticeReroll`
  `true`, `InpAutoEject` `false`, `InpLots` `0.01`, `TelemetryAPIKey` blank. **`build_twoarm(table,
  root)`** returns `({path: text}, [errors])`, adding: a duplicate magic within one fleet, or a fleet
  whose pairs are missing from `pair_index`, is an error. `main` prints `summary` rows and writes only
  with `--write` and 0 errors (ASCII, LF), as the `round` stage.

## 4. TESTS (their own commit, first; hand values)

Add `class TestTwoArm` to `scripts/test_ic_presets.py`. At the tests commit, add the TABLE of s2 and
stubs `twoarm_preset` / `validate_twoarm` / `build_twoarm` that raise `NotImplementedError`, so the file
imports and every test reaches a stub (never a missing file). Run `python -B -m unittest scripts/test_ic_presets.py -v` at both commits; report counts.

- **TW1 width and stranded** (`tight_width`): adds 3, 4, 6, 7, 9, 12, 16, 19, 21, 22, 23, 24, 27, 30 give
  widths 1.0, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 5.5, 5.5, 6.0, 6.0, 7.0, 7.5 (add / 4 = 0.75 -> 1.0;
  1.0; 1.5; 1.75 -> 2.0; 2.25 -> 2.5; 3.0; 4.0; 4.75 -> 5.0; 5.25 -> 5.5; 5.5; 5.75 -> 6.0; 6.0; 6.75 ->
  7.0; 7.5), stranded = width + 1; every add / width within [0.5, 4.0] (24 / 6.0 = 4.0, 30 / 7.5 = 4.0,
  22 / 5.5 = 4.0, 12 / 3.0 = 4.0, 16 / 4.0 = 4.0 sit ON the bound: allowed). GUARD (passes with the stub).
- **TW2 one preset, D EURUSD ALT** from the repo template: `InpMagic=22260202`, `InpSlot=ALT`,
  `InpTelemetryInstance=GRIND_EURUSD_ALTD`, add = exit 27.0, width 7.0, stranded 8.0, deadband 2.0, cap 7,
  per-side six keys `-1.0`, `InpCapLegA=EUR`, `InpCapLegB=USD`, breaker `false`, warning exactly
  `FLEET D two-arm t1 EURUSD ALT q95: cap 7, add = exit 27.0, width 7.0, deadband 2.0; lattice + reroll
  on, roll gate 0 (IC Markets demo 53077984, wine-d)`.
- **TW3 GBPCHF on C from EURUSD's template:** OPT magic `22261001`, ALT `22261002`; legs `GBP` / `CHF`;
  OPT add = exit 9.0, width 2.5, stranded 3.5; ALT 24.0, 6.0, 7.0, tag `range guess`; instances
  `GRIND_GBPCHF_OPTC` / `GRIND_GBPCHF_ALTC`.
- **TW4 E AUDCAD ALT:** magic `22260402`, `GRIND_AUDCAD_ALTE`, 27.0 / 7.0 / 8.0, tag `q90`, warning ends
  `(FTMO demo, new account, new Linux server)`. **E EURUSD ALT:** 23.0, width 6.0, stranded 7.0.
- **TW5 no key outside `TWOARM_CHANGES` changes** (`changed <= TWOARM_CHANGES`, a subset: many of its keys
  already hold the target value, e.g. GBPUSD D changes only `InpMaxLayers` and `InpConfigWarning`), and
  the key order equals the template's, for all 30 outputs.
- **TW6 `validate_twoarm` catches each rule** (one mutation each, from a valid output): cap 8; exit !=
  add; width 6.5 for add 27; stranded = width; a per-side input not `-1.0`; magic of the wrong slot;
  instance of the wrong fleet; legs swapped; `InpBreakerEnable=true`; `TelemetryAPIKey=x`; a key added;
  two keys swapped in order. Each single-key mutation returns an error naming that key; the added key
  and the swapped order return the error containing `keys or order`.
- **TW7 `build_twoarm` on the repo:** 30 files, 0 errors; paths as s3; the 12 E magics are 22260101,
  22260102, ..., 22260601, 22260602 (no duplicate); a table with GBPCHF in a fleet but not in
  `pair_index` gives an error; a table giving two pairs the same index gives a duplicate-magic error.
- **TW8 the committed files equal the generator's output byte for byte:** call `build_twoarm` FIRST
  (the stub raises at the tests commit), then compare each returned text with the file at its path.
- **TW9 nothing else moved (a REPORT check in s7, not a test method):** every test that existed before
  this branch passes unchanged at both commits, and `git diff --stat main..presets-twoarm` lists only
  the files of s7 (no file under `ea/presets/`, `ea/presets_b/`, no existing `*_r3.set` / `*_r2.set`).
- **At the tests commit** TW1 passes (GUARD: it uses the existing `tight_width`); TW2-TW8 fail on
  `NotImplementedError`; every older test passes.

## 5. NEGATIVE SPACE (do NOT)

- No change to any `ea/*.mq5` / `ea/*.mqh`, to any existing preset file, to the existing stages or their
  tests, to `scripts/deploy_presets.ps1`, or to pipshed. No telemetry key in any file.
- No MetaTrader, no compile, no deploy, no `git stash`, no checkout of files from other commits, no merge,
  no PR, no `git add .` or `-u`, no push to `main`.
- Do not "improve" the table's numbers, the width rule, the warning text or the magic scheme: if one looks
  wrong, STOP and report it (s6 lists the ones already questioned).

## 6. FOR THE REVIEWER (Gemini / Argon): attack the premises, say which fact is missing

- **G1. ALT's L0 rests about add / 4 from mid** (width 6.0-7.5 pips on most pairs; T4, T5): the ADR-153
  guard forbids an ALT at OPT's width with a 4x larger add. Acceptable for an arm meant to be dormant in
  a tight range, or should the guard be revisited (an EA change: out of this prompt)?
- **G2. FTMO as fleet `E` with ids `_OPTE` / `_ALTE`**, so its archive never mixes with A's (`GRIND_<PAIR>_OPT`,
  the trial ending ~21 Oct). Sound, or reuse A's ids?
- **G3. `InpBreakerEnable=false` on E** (the operator turned A's breaker off on 16 Oct: "this breaker is
  silly"; it also gates the float and the pre-midnight halt). Nothing on E stops entries before FTMO's own
  daily limit. Flag if the new account needs it.
- **G4. Carry pass ON for ALT** (the template's value; cycle 3's ALT presets had it off). Any reason a wide
  arm should not shift its exits by carry?
- **G5. GBPCHF's magic (index 10) is outside `GRIND_CAP_ALL_MAGICS`** (T3): harmless while the currency cap
  is off. Agree?
- **G6. One template per pair (D's r3) for every fleet** (T1): any key that should differ by account?
- **G7.** What fact is missing?

Save your reply as `reviews/argon_presets_twoarm.md` on a branch `review/argon-presets-twoarm` from this
commit, and commit it; Claude reads it there.

## 7. COMMITS AND REPORT

1. Tests (TestTwoArm), the stubs and the table. 2. The code and the 30 presets (`--write`). Nothing else.
Report: both commit hashes; the unittest counts at each; the dry-run summary (30 rows); `git diff --stat
main..presets-twoarm`. STOP on any failure you cannot explain from this prompt.

## 8. THE REVIEW (Argon, `ce53c05`, on `333e7e6`) AND CLAUDE'S CHECK

Every quote checked in source at `333e7e6`. T1, T2, T4-T8 confirmed. Points taken:

- **T3 / G5 / G7-1, accepted (a premise of ours was incomplete):** the table also feeds the slot guard's
  second count of resting entries (T3 now). Harmless on C; backlog before GBPCHF on a 12-instance fleet.
- **Fixes 1-6, accepted:** `os.makedirs` for `ea/presets_e/` (s3); `twoarm_preset`'s signature (s3); the
  table in the tests commit and TW8 calling the build first (s4, s7); TW5 a subset check; TW6's error
  matching; the tag precedence and the account and box from the table (s3).
- **G1 (ALT's width), G2 (fleet E), G3 (breaker off on E), G4 (carry on ALT), G6 (one template):** the
  reviewer agrees with each. G3's consequence goes in the FTMO runbook: nothing on E halts entries before
  FTMO's own daily limit (C155 before any paid account).
- **G7-3 (downstream):** `scripts/deploy_presets.ps1` targets the Windows VPS (`c:\fxmatrix`); E's preset
  deployment on the new Linux server is the FTMO runbook's (not this prompt; s5 forbids changing it).

Line count: 186
