# Section 0 restate — `prompts/cursor_presets_twoarm.md` at `068a5ed`

Operator: follow **§0. RESTATE AND STOP** only. Base commit for the future `presets-twoarm` work: `068a5ed` on `main`. No code or presets in this step.

---

## 1. Restate each item of s2 and s3 in one line (quoting the prompt)

### s2 — THE TABLE (`scripts/ic_geometry_twoarm.json`)

1. **Commit the table exactly** as the JSON block in s2: `"status": "TWO-ARM t1 (HANDOFF s85, fleet D note s10-s11): OPT + ALT per pair, exit = add on both, cap 7. E (FTMO) ALT at q90, D and C at q95 (research/alt_adds/results_2026-10-17.md s6); GBPCHF from its range."`
2. **`"round": "t1"`** — round id for filenames and warnings.
3. **`"cap": 7`**, **`"deadband": 2.0`**, **`"roll_gate": 0`** — geometry and roll gate for the stage.
4. **`"pair_index"`** — GBPUSD 1 … AUDNZD 9, **GBPCHF 10** (magic index).
5. **`"template": {"GBPCHF": "EURUSD"}`** — GBPCHF uses EURUSD’s D r3 file as template.
6. **Fleet E** — account `"FTMO demo, new account"`, box `"new Linux server"`; six pairs with OPT/ALT adds (GBPUSD 9/24, EURUSD 7/23, EURGBP 3/16, AUDCAD 6/27, AUDCHF 4/21, CADCHF 4/9).
7. **Fleet D** — `"IC Markets demo 53077984"`, `"wine-d"`; same six pairs (GBPUSD 9/30, EURUSD 7/27, EURGBP 3/19, AUDCAD 6/27, AUDCHF 4/22, CADCHF 4/12).
8. **Fleet C** — `"IC Markets demo 53071896"`, `"wine-c"`; EURUSD 7/27, AUDCAD 6/27, GBPCHF 9/24.
9. **Each table number** is the arm’s **add AND exit, in pips** (`Each number is the arm's add AND exit, in pips.`).

### s3 — THE STAGE `twoarm` (code)

10. **New stage only** — `--stage twoarm --table scripts/ic_geometry_twoarm.json [--write]`; do **not** change existing stages (`c10`, `p2`, `round`, `ftmo`), their functions, or their tests.
11. **Template path** — pair P: `ea/presets_d/<p>_opt_d_r3.set`; pairs in `"template"` (GBPCHF): named pair’s D r3 (EURUSD); output keeps template keys and order exactly.
12. **Output paths** — `ea/presets_<f>/<pair>_<slot>_<f>_t1.set` (lower case); **`ea/presets_e/` new**; **`--write` calls `os.makedirs(os.path.dirname(path), exist_ok=True)` before each `open`**; **12 E + 12 D + 6 C = 30 files**.
13. **`TWOARM_CHANGES` only** — every other key stays the template value.
14. **`InpMagic`** — `2226 * 10000 + pair_index * 100 + (1 OPT, 2 ALT)`; **`InpSlot`** — `OPT` / `ALT`; **`InpTelemetryInstance`** — `GRIND_<PAIR>_<SLOT><F>` (e.g. `GRIND_EURUSD_ALTD`, `GRIND_GBPCHF_OPTC`, `GRIND_AUDCAD_ALTE`).
15. **`InpCapLegA` / `InpCapLegB`** — first and last three letters of the pair.
16. **`InpAddPips` = `InpExitPips`** — table value; **`InpAddPipsLong/Short`, `InpExitPipsLong/Short`, `InpWidthPipsLong/Short`** — `-1.0`.
17. **`InpWidthPips`** — `tight_width([add])`; **`InpStrandedThreshPips`** — width + 1; **`InpDeadbandPips`** — table 2.0; **`InpMaxLayers`** — 7; **`InpRollGateOpposite`** — 0; **`InpBreakerEnable`** — `false`.
18. **`InpConfigWarning`** — `FLEET <F> two-arm t1 <PAIR> <SLOT> <tag>: cap 7, add = exit <a>, width <w>, deadband 2.0; lattice + reroll on, roll gate 0 (<account>, <box>)`; **`<tag>` order:** OPT → `-`; pair in `"template"` (GBPCHF) → `range guess`; fleet E → `q90`; fleets D and C → `q95`; **`<account>` / `<box>` from `table["fleets"][F]`** (not `ACCOUNT`, which has no E); numbers as `_num` (one decimal).
19. **`twoarm_preset(template_text, fleet, pair, slot, add, table)`** — returns preset text with bullets applied, key order kept.
20. **`validate_twoarm(template_text, out_text, fleet, pair, slot, add, table)`** — errors for: keys/order vs template (one error containing **`keys or order`**); single-key errors **name the key**; key outside `TWOARM_CHANGES`; any bullet value wrong; guard (T4) both sides; `InpVirtualLattice` / `InpLatticeReroll` true, `InpAutoEject` false, `InpLots` 0.01, `TelemetryAPIKey` blank.
21. **`build_twoarm(table, root)`** — `({path: text}, [errors])`; also errors for duplicate magic within one fleet or fleet pairs missing from `pair_index`.
22. **`main`** — summary rows; write only with `--write` and 0 errors (ASCII, LF), like **`round`**.

---

## 2. Every test in s4: name, asserted values, arithmetic

Rule: **`tight_width(add)`** = ceil to half pip of `add/4` (same as round stage: `ceil(add/4 * 2 - EPS) / 2`). **`stranded = width + 1`**. Guard: **`0.5 <= add/width <= 4.0`**.

| Test | Name (in `TestTwoArm`) | Asserts | Arithmetic |
|------|------------------------|---------|------------|
| **TW1** | width and stranded (`tight_width`) | For adds **3, 4, 6, 7, 9, 12, 16, 19, 21, 22, 23, 24, 27, 30**: widths **1.0, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 5.5, 5.5, 6.0, 6.0, 7.0, 7.5**; stranded = width + 1; every **add/width ∈ [0.5, 4.0]** (including **24/6.0=4.0**, **30/7.5=4.0**, **22/5.5=4.0**, **12/3.0=4.0**, **16/4.0=4.0** on upper bound). | 3→0.75→**1.0**; 4→**1.0**; 6→**1.5**; 7→1.75→**2.0**; 9→2.25→**2.5**; 12→**3.0**; 16→**4.0**; 19→4.75→**5.0**; 21→5.25→**5.5**; 22→**5.5**; 23→5.75→**6.0**; 24→**6.0**; 27→6.75→**7.0**; 30→**7.5**. Stranded: e.g. 27→7.0→**8.0**. |
| **TW2** | one preset, D EURUSD ALT | From repo template: **`InpMagic=22260202`**, **`InpSlot=ALT`**, **`InpTelemetryInstance=GRIND_EURUSD_ALTD`**, add=exit **27.0**, width **7.0**, stranded **8.0**, deadband **2.0**, cap **7**, six per-side keys **-1.0**, **`InpCapLegA=EUR`**, **`InpCapLegB=USD`**, breaker **false**, warning exactly **`FLEET D two-arm t1 EURUSD ALT q95: cap 7, add = exit 27.0, width 7.0, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53077984, wine-d)`**. | Magic: 2226×10000 + 2×100 + 2 = **22260202**. Width: tight_width([27]) = **7.0**; stranded **8.0**. Table D EURUSD ALT add **27**. Tag: fleet D → **q95**. |
| **TW3** | GBPCHF on C from EURUSD template | OPT magic **22261001**, ALT **22261002**; legs **GBP** / **CHF**; OPT add=exit **9.0**, width **2.5**, stranded **3.5**; ALT **24.0**, width **6.0**, stranded **7.0**, tag **`range guess`**; **`GRIND_GBPCHF_OPTC`** / **`GRIND_GBPCHF_ALTC`**. | Index 10: OPT **22261001**, ALT **22261002**. OPT: tight_width([9])=**2.5**, stranded **3.5**. ALT: tight_width([24])=**6.0**, stranded **7.0**. Template precedence → **`range guess`**. |
| **TW4** | E AUDCAD ALT + E EURUSD ALT | E AUDCAD ALT: magic **22260402**, **`GRIND_AUDCAD_ALTE`**, **27.0 / 7.0 / 8.0**, tag **q90**, warning ends **`(FTMO demo, new account, new Linux server)`**. E EURUSD ALT: **23.0**, width **6.0**, stranded **7.0**. | AUDCAD index 4, ALT magic **22260402**; tight_width([27])=**7.0**, stranded **8.0**; E → **q90**. EURUSD ALT add **23** → tight_width([23])=**6.0**, stranded **7.0**. |
| **TW5** | no key outside TWOARM_CHANGES | For all **30** outputs: **`changed <= TWOARM_CHANGES`** (subset; e.g. GBPUSD D may change only **`InpMaxLayers`** and **`InpConfigWarning`**); key order equals template. | Compare each output to its template; changed keys must be subset of the 20 `TWOARM_CHANGES` keys. |
| **TW6** | validate_twoarm catches each rule | One mutation each from valid output: cap **8**; exit ≠ add; width **6.5** for add **27**; stranded = width (not width+1); per-side not **-1.0**; wrong-slot magic; wrong-fleet instance; legs swapped; **`InpBreakerEnable=true`**; **`TelemetryAPIKey=x`**; key added; two keys swapped. Single-key mutations → error **naming that key**; add/swap → error containing **`keys or order`**. | e.g. add 27 valid width **7.0**; mutate width **6.5** → named width error. |
| **TW7** | build_twoarm on repo | **30** files, **0** errors; paths per s3; **12 E magics** **22260101, 22260102, …, 22260601, 22260602** (no duplicate); table with GBPCHF in fleet but not in **`pair_index`** → error; two pairs same index → duplicate-magic error. | E: 6 pairs × 2 slots = 12 files; magics 22260101–22260602 as listed. |
| **TW8** | committed files = generator | Call **`build_twoarm` FIRST**, then compare each returned text to file at path **byte for byte**. | At tests commit stub raises before compare. |
| **TW9** | *(not a unittest)* | **REPORT in s7:** pre-existing tests pass at both commits; **`git diff --stat main..presets-twoarm`** only s7 files (no `ea/presets/`, `ea/presets_b/`, no existing `*_r3.set` / `*_r2.set`). | N/A in §0 implementation. |

**Commit 1 contents (s4 + s7):** add **`TestTwoArm`**, commit **s2 table**, stubs **`twoarm_preset` / `validate_twoarm` / `build_twoarm`** raising **`NotImplementedError`**. Run **`python -B -m unittest scripts/test_ic_presets.py -v`** at both commits.

---

## 3. Tests commit (commit 1): what fails, what passes, why

**Baseline at `068a5ed`:** **41** test methods in `scripts/test_ic_presets.py` (no `TestTwoArm` yet).

**After commit 1** (table + stubs + `TestTwoArm` TW1–TW8): **49** tests total.

| Outcome | Tests | Why |
|---------|-------|-----|
| **Pass (42)** | All **41** pre-existing tests | Stubs and new stage must not alter `c10`, `p2`, `round`, `ftmo` or their behaviour; s5 forbids changing existing stages/tests. |
| **Pass (1)** | **TW1** | Prompt: *"TW1 passes (GUARD: it uses the existing `tight_width`)"* — only calls existing `tight_width` / guard logic, not the stubs. |
| **Fail (7)** | **TW2–TW8** | Each calls **`twoarm_preset`**, **`validate_twoarm`**, or **`build_twoarm`**; stubs **raise `NotImplementedError`**, which is the intended tests-commit state (*"TW2-TW8 fail on `NotImplementedError`"*). |
| **N/A** | **TW9** | Not a test method; verified in final **report** (s7), not at tests commit. |

**Expected unittest summary at commit 1:** **42 passed, 7 failed** (failures = `NotImplementedError` from TW2–TW8).

---

## 4. STOP

Waiting for the operator’s **"go"** before branch `presets-twoarm`, implementation, or any file beyond this restate.
