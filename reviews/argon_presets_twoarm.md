# Argon Review of `prompts/cursor_presets_twoarm.md` at `333e7e6`

Fetch: `git fetch origin`. Reviewed commit on `main`: `333e7e6d472a1cb8a3f66b7bc31fd78dda57eb53` (`333e7e6`).

---

## 1. Audit Trail (`s1`, `T1`–`T8`) Checked Against Source at `333e7e6`

### T1 — **MATCHES** (with one note on asymmetric C add probes in `r3` and `r2` vs `r3` width on `AUDCHF`)

`333e7e6:prompts/cursor_presets_twoarm.md:21`
```
| T1 | B, C, D and A presets of one pair differ ONLY in add, exit (and per-side exits), width where probed, `InpTelemetryInstance`, `InpConfigWarning` and A's `InpBreakerEnable`; all nine `ea/presets_d/*_opt_d_r3.set` have the same 41 keys in the same order | `diff` of `eurusd` and `audcad` r3 across `presets_b/c/d`, `presets/eurusd_opt_a_r2.set` | READ |
```

- **EURUSD across `presets_b/c/d` (`r3`) and `presets/eurusd_opt_a_r2.set`:** differ only in `InpAddPips` (line 4), `InpExitPips` (line 5), `InpExitPipsLong` / `InpExitPipsShort` (lines 10–11), `InpBreakerEnable` (line 24), `InpTelemetryInstance` (line 35), and `InpConfigWarning` (line 37):
  - `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:4` `InpAddPips=7.0`
  - `333e7e6:ea/presets_c/eurusd_opt_c_r3.set:4` `InpAddPips=6.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:4` `InpAddPips=7.0`
  - `333e7e6:ea/presets/eurusd_opt_a_r2.set:4` `InpAddPips=7.0`
  - `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:5` `InpExitPips=10.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:5` `InpExitPips=9.0`
  - `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:10` `InpExitPipsLong=-1.0`
  - `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:11` `InpExitPipsShort=-1.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:10` `InpExitPipsLong=9.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:11` `InpExitPipsShort=11.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:24` `InpBreakerEnable=false`
  - `333e7e6:ea/presets/eurusd_opt_a_r2.set:24` `InpBreakerEnable=true`
  - `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTB`
  - `333e7e6:ea/presets_c/eurusd_opt_c_r3.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTC`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTD`
  - `333e7e6:ea/presets/eurusd_opt_a_r2.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPT`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:37` `InpConfigWarning=FLEET D round 3 EURUSD EXIT probe: cap 8, width 2.0, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53077984, wine-d)`
- **AUDCAD across `presets_b/c/d` (`r3`):** differ only in `InpAddPips` (line 4), `InpExitPips` (line 5), `InpTelemetryInstance` (line 35), and `InpConfigWarning` (line 37):
  - `333e7e6:ea/presets_b/audcad_opt_b_r3.set:4` `InpAddPips=6.0`
  - `333e7e6:ea/presets_c/audcad_opt_c_r3.set:4` `InpAddPips=5.0`
  - `333e7e6:ea/presets_d/audcad_opt_d_r3.set:5` `InpExitPips=9.0`
  - `333e7e6:ea/presets_d/audcad_opt_d_r3.set:35` `InpTelemetryInstance=GRIND_AUDCAD_OPTD`
- *(Note: on pairs with asymmetric C add probes in `r3` — `eurgbp_opt_c_r3.set:8-9` and `audchf_opt_c_r3.set:8-9` — `InpAddPipsLong` and `InpAddPipsShort` also differ on C; `s3` already resets all six per-side keys to `-1.0` in `TWOARM_CHANGES`.)*
- **All nine `ea/presets_d/*_opt_d_r3.set` (`gbpusd`, `eurusd`, `eurgbp`, `audcad`, `audchf`, `cadchf`, `nzdchf`, `nzdcad`, `audnzd`):** every file has the exact same 41 keys in the exact same order (lines 1–41, matching the 41 `input` declarations in `333e7e6:ea/fxgrind.mq5:14-54`), from `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:1` (`InpMagic=22260201`) to `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:41` (`TelemetryIntervalSec=60`).

---

### T2 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:22`
```
| T2 | Magic scheme `2226` + pair index (2 digits) + slot (`01` OPT, `02` ALT): GBPUSD 01, EURUSD 02, EURGBP 03, AUDCAD 04, AUDCHF 05, CADCHF 06, NZDCHF 07, NZDCAD 08, AUDNZD 09. The same magic on every account | `presets_d/*_r3.set`, `presets/*_alt.set` | READ |
```

- **OPT (`01`) in `ea/presets_d/*_opt_d_r3.set` and across `B`, `C`, `A`:**
  - `333e7e6:ea/presets_d/gbpusd_opt_d_r3.set:1` `InpMagic=22260101`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:1` `InpMagic=22260201`
  - `333e7e6:ea/presets_d/eurgbp_opt_d_r3.set:1` `InpMagic=22260301`
  - `333e7e6:ea/presets_d/audcad_opt_d_r3.set:1` `InpMagic=22260401`
  - `333e7e6:ea/presets_d/audchf_opt_d_r3.set:1` `InpMagic=22260501`
  - `333e7e6:ea/presets_d/cadchf_opt_d_r3.set:1` `InpMagic=22260601`
  - `333e7e6:ea/presets_d/nzdchf_opt_d_r3.set:1` `InpMagic=22260701`
  - `333e7e6:ea/presets_d/nzdcad_opt_d_r3.set:1` `InpMagic=22260801`
  - `333e7e6:ea/presets_d/audnzd_opt_d_r3.set:1` `InpMagic=22260901`
  - Same magic across accounts: `333e7e6:ea/presets_b/eurusd_opt_b_r3.set:1` (`InpMagic=22260201`), `333e7e6:ea/presets_c/eurusd_opt_c_r3.set:1` (`InpMagic=22260201`), `333e7e6:ea/presets/eurusd_opt_a_r2.set:1` (`InpMagic=22260201`).
- **ALT (`02`) in `ea/presets/*_alt.set`:**
  - `333e7e6:ea/presets/gbpusd_alt.set:1` `InpMagic=22260102`
  - `333e7e6:ea/presets/eurusd_alt.set:1` `InpMagic=22260202`
  - `333e7e6:ea/presets/eurgbp_alt.set:1` `InpMagic=22260302`
  - `333e7e6:ea/presets/audcad_alt.set:1` `InpMagic=22260402`
  - `333e7e6:ea/presets/audchf_alt.set:1` `InpMagic=22260502`
  - `333e7e6:ea/presets/cadchf_alt.set:1` `InpMagic=22260602`
  - `333e7e6:ea/presets/nzdchf_alt.set:1` `InpMagic=22260702`
  - `333e7e6:ea/presets/nzdcad_alt.set:1` `InpMagic=22260802`
  - `333e7e6:ea/presets/audnzd_alt.set:1` `InpMagic=22260902`

---

### T3 — **PARTIALLY WRONG (`GRIND_CAP_ALL_MAGICS` also feeds `Grind_IsFleetMagic` / `Grind_SlotRestingEnt` in `ea/grind_exitq.mqh`; still harmless on Fleet C at 6 instances)**

`333e7e6:prompts/cursor_presets_twoarm.md:23`
```
| T3 | `GRIND_CAP_ALL_MAGICS` (18 magics, pairs 01-09) feeds only the currency cap, which is disabled (`InpCapLegAThresh` / `B` 0.0 everywhere): a magic outside it (GBPCHF, index 10) publishes its own exposure GV and is not summed by peers. No EA change | `ea/grind_cap.mqh` 17-29, 207-232, 236-264 | READ |
```

- **What matches in `ea/grind_cap.mqh`:**
  - `333e7e6:ea/grind_cap.mqh:18` `const ulong GRIND_CAP_ALL_MAGICS[18] =`
  - `333e7e6:ea/grind_cap.mqh:20` `   22260101UL, 22260102UL,`
  - `333e7e6:ea/grind_cap.mqh:28` `   22260701UL, 22260702UL`
  - `333e7e6:ea/grind_cap.mqh:31` `#define GRIND_CAP_MAGIC_COUNT 18`
  - `333e7e6:ea/grind_cap.mqh:207` `bool Grind_CapPublishOwnExposure(const ulong magic,`
  - `333e7e6:ea/grind_cap.mqh:219` `      const string key_a = Grind_CapExposureKey(magic, leg_a);`
  - `333e7e6:ea/grind_cap.mqh:236` `bool Grind_CapSumLegExposure(const string leg,`
  - `333e7e6:ea/grind_cap.mqh:247` `   for(int i = 0; i < ArraySize(GRIND_CAP_ALL_MAGICS); i++) {`
  - `333e7e6:ea/grind_cap.mqh:281` `   if(!Grind_CapThresholdEnabled())`
  - `333e7e6:ea/grind_cap.mqh:282` `      return true;`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:33` `InpCapLegAThresh=0.0`
  - `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:34` `InpCapLegBThresh=0.0`
- **What is missing / wrong in "feeds only the currency cap":** `GRIND_CAP_ALL_MAGICS` and `GRIND_CAP_MAGIC_COUNT` also feed `Grind_IsFleetMagic`, which filters resting `ENT` orders in the ADR-151 account-wide slot guard (`Grind_SlotRestingEnt`), as well as `Grind_MagicLockReleaseAllKnown`:
  - `333e7e6:ea/grind_exitq.mqh:105` `bool Grind_IsFleetMagic(const long magic)`
  - `333e7e6:ea/grind_exitq.mqh:107` `   for(int i = 0; i < GRIND_CAP_MAGIC_COUNT; i++) {`
  - `333e7e6:ea/grind_exitq.mqh:108` `      if((long)GRIND_CAP_ALL_MAGICS[i] == magic)`
  - `333e7e6:ea/grind_exitq.mqh:135` `int Grind_SlotRestingEnt()`
  - `333e7e6:ea/grind_exitq.mqh:148` `      const long magic = OrderGetInteger(ORDER_MAGIC);`
  - `333e7e6:ea/grind_exitq.mqh:149` `      if(!Grind_IsFleetMagic(magic))`
  - `333e7e6:ea/grind_exitq.mqh:150` `         continue;`
  - `333e7e6:ea/grind_engine.mqh:145` `      if(!Grind_IsFleetMagic(rec.magic))`
  - `333e7e6:ea/grind_engine.mqh:2085` `   const int resting_ent = Grind_SlotRestingEnt();`
  - `333e7e6:ea/grind_engine.mqh:2086` `   g_grind_last_guard_total = used + resting_ent;`
  - `333e7e6:ea/grind_engine.mqh:2088` `   if(!Grind_SlotEntryAllowed(limit, used, resting_ent, true)) {`
  - `333e7e6:ea/grind_engine.mqh:2372` `   const int resting_ent = Grind_SlotRestingEnt();`
  - `333e7e6:ea/grind_magic_lock.mqh:28` `   for(int i = 0; i < GRIND_CAP_MAGIC_COUNT; i++)`
  - `333e7e6:ea/grind_magic_lock.mqh:29` `      Grind_MagicLockRelease(GRIND_CAP_ALL_MAGICS[i]);`
- See **G5** below for why this is still safe on Fleet C (6 instances) without an EA change in this prompt.

---

### T4 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:24`
```
| T4 | ADR-153 guard, FATAL at init: 0.5 <= add / width <= 4.0 per side | `ea/fxgrind.mq5` 174-205; `ea/grind_pure.mqh` 10, 49; `GUARD_MIN/MAX` in `ic_presets.py` 47 | READ |
```

- `333e7e6:ea/fxgrind.mq5:177` `   if(!Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)) {`
- `333e7e6:ea/fxgrind.mq5:190` `   if(!Grind_ValidateAddWidthRatio(g_geo_width_long, g_geo_add_long)) {`
- `333e7e6:ea/fxgrind.mq5:201` `   if(!Grind_ValidateAddWidthRatio(g_geo_width_short, g_geo_add_short)) {`
- `333e7e6:ea/fxgrind.mq5:204` `      return INIT_FAILED;`
- `333e7e6:ea/grind_pure.mqh:9` `#define GRIND_ADD_WIDTH_RATIO_MIN 0.5`
- `333e7e6:ea/grind_pure.mqh:10` `#define GRIND_ADD_WIDTH_RATIO_MAX 4.0`
- `333e7e6:ea/grind_pure.mqh:47` `   if(r < GRIND_ADD_WIDTH_RATIO_MIN - 1e-9)`
- `333e7e6:ea/grind_pure.mqh:49` `   if(r > GRIND_ADD_WIDTH_RATIO_MAX + 1e-9)`
- `333e7e6:scripts/ic_presets.py:47` `GUARD_MIN, GUARD_MAX = 0.5, 4.0`
- `333e7e6:scripts/ic_presets.py:93` `def guard_ok(width, add):`
- `333e7e6:scripts/ic_presets.py:95` `    return GUARD_MIN - EPS <= r <= GUARD_MAX + EPS`

---

### T5 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:25`
```
| T5 | Width is the L0 quote distance: buy at mid - width, sell at mid + width | ADR-123, ADR-124 | READ |
```

- `333e7e6:docs/architecture/ADR-123.md:11` `The dumb straddle (`ENTRY_STRADDLE`) posts two passive L0 limits when flat: buy at`
- `333e7e6:docs/architecture/ADR-123.md:12` `mid − width, sell at mid + width. ADR-121/122 layered a bespoke re-quote state`
- `333e7e6:docs/architecture/ADR-124-l0-recentering.md:61` `Re-centering uses `OrderModify` (`TRADE_ACTION_MODIFY`) at mid +/- width`
- `333e7e6:ea/grind_pure.mqh:128` `   return mid - Grind_PipsToPrice(width_pips, point);`
- `333e7e6:ea/grind_pure.mqh:136` `   return mid + Grind_PipsToPrice(width_pips, point);`
- `333e7e6:ea/grind_engine.mqh:3214` `   double buy_target = Grind_StraddleBuyPrice(mid, width_pips, _Point);`
- `333e7e6:ea/grind_engine.mqh:3215` `   double sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);`

---

### T6 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:26`
```
| T6 | The round stage's width rule: `tight_width(adds)` = ceil to the half pip of max(add) / 4; stranded = width + 1 | `ic_presets.py` 377-380, 393-413 | READ |
```

- `333e7e6:scripts/ic_presets.py:377` `def tight_width(adds):`
- `333e7e6:scripts/ic_presets.py:380` `    return math.ceil(max(float(a) for a in adds) / 4.0 * 2.0 - EPS) / 2.0`
- `333e7e6:scripts/ic_presets.py:393` `def round_preset(base_text, width, adds, exits, fleet, pair, role, cap, deadband, rnd, roll_gate=None):`
- `333e7e6:scripts/ic_presets.py:401` `        "InpWidthPips": _num(w),`
- `333e7e6:scripts/ic_presets.py:402` `        "InpStrandedThreshPips": _num(w + 1.0),`

---

### T7 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:27`
```
| T7 | `validate` requires `InpMaxLayers` = 10 unless given; `with_v22_keys` and the r3 presets already carry `InpRollGateOpposite=0`, `InpApiEntryStop=1000000`, `InpApiSoftWarn=999000` | `ic_presets.py` 262-309; `presets_d/eurusd_opt_d_r3.set` | READ |
```

- `333e7e6:scripts/ic_presets.py:50` `CAP = 10`
- `333e7e6:scripts/ic_presets.py:240` `def with_v22_keys(pairs, gate):`
- `333e7e6:scripts/ic_presets.py:244` `    new = {"InpRollGateOpposite": str(int(gate)), "InpApiEntryStop": str(API_ENTRY_STOP),`
- `333e7e6:scripts/ic_presets.py:245` `           "InpApiSoftWarn": str(API_SOFT_WARN)}`
- `333e7e6:scripts/ic_presets.py:262` `def validate(base_text, out_text, width, cap=None, deadband=None, gate=None):`
- `333e7e6:scripts/ic_presets.py:288` `    want_cap = CAP if cap is None else int(cap)`
- `333e7e6:scripts/ic_presets.py:289` `    if p["InpMaxLayers"] != str(want_cap):`
- `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:23` `InpRollGateOpposite=0`
- `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:29` `InpApiEntryStop=1000000`
- `333e7e6:ea/presets_d/eurusd_opt_d_r3.set:30` `InpApiSoftWarn=999000`

---

### T8 — **MATCHES**

`333e7e6:prompts/cursor_presets_twoarm.md:30`
```
| T8 | Every repo preset is ASCII, LF, `TelemetryAPIKey=` blank (the key is injected at deploy) | `ic_presets.py` 286-287, 544-545 | READ |
```

- `333e7e6:scripts/ic_presets.py:286` `    if p.get("TelemetryAPIKey", "") != "":`
- `333e7e6:scripts/ic_presets.py:287` `        errs.append("TelemetryAPIKey not blank")`
- `333e7e6:scripts/ic_presets.py:335` `    with open(path, encoding="ascii") as fh:`
- `333e7e6:scripts/ic_presets.py:544` `                with open(path, "w", encoding="ascii", newline="\n") as fh:`
- `333e7e6:scripts/ic_presets.py:545` `                    fh.write(text)`
- `333e7e6:scripts/deploy_presets.ps1:72` `    $out = $text -replace 'TelemetryAPIKey=', "TelemetryAPIKey=$key"`

---

## 2. Reviewer Questions (`s6`, `G1`–`G7`)

### G1. ALT's L0 at `ceil_0.5(add / 4)` from mid (`width` 6.0–7.5 pips on most pairs) under ADR-153

**Verdict: Acceptable as-is; do NOT widen the ADR-153 guard for this build.**

- Once L0 fills at `entry_0`, both L0's exit (`entry_0 +/- exit_pips`) and L1's add (`entry_0 -/+ add_pips`) are anchored to `entry_0`, not `mid` (`333e7e6:ea/grind_pure.mqh:140-155`). Thus a wider `InpWidthPips` does not reduce ALT's scalp profit (`exit = add`), and shifts the full 7-layer stack `(cap - 1) * add` further from the initial `mid` by `W_ALT - W_OPT` (~3.5–5.0 pips), giving slightly more excursion room before rolling.
- On an empty side opposite a holding side (`Grind_TryRecenterOppositeL0`, `333e7e6:ea/grind_engine.mqh:3025-3071`), `S = W + 1` and `D = 2.0` keep the re-centre drift cadence at `max(D, S - W) = max(2.0, 1.0) = 2.0` pips — identical to OPT.
- For an arm ruled to be dormant in a tight range (`333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:220`: `"in a tight range trading market it is ok if ALT is completely dormant"`), quoting L0 at 6.0–7.5 pips from `mid` is preferable to quoting at 1.5–2.0 pips: quoting ALT's L0 at OPT's width would open L0 on routine 2-pip noise and leave a single 0.01 layer sitting open for days waiting for a 16–30 pip exit or add.

### G2. FTMO as Fleet `E` with `_OPTE` / `_ALTE` vs reusing `A`'s IDs

**Verdict: Sound — use Fleet `E` (`_OPTE` / `_ALTE` and `ea/presets_e/`). Do NOT reuse `A`'s IDs.**

- Fleet A's `ea/presets/*_opt_a_r2.set` (`333e7e6:ea/presets/eurusd_opt_a_r2.set:35`) and cycle 2/3's `ea/presets/*_{opt,alt}.set` (`333e7e6:ea/presets/eurusd_alt.set:18`) used suffixless `GRIND_<PAIR>_OPT` and `GRIND_<PAIR>_ALT`.
- Using `GRIND_<PAIR>_OPTE` and `GRIND_<PAIR>_ALTE` keeps the new Linux/Wine FTMO demo (`cap 7`, `exit = add`, two-arm) cleanly partitioned in pipshed's `archive_events`, `scalp_events`, and `config_events` tables from both the outgoing Windows VPS trial (`1514878887`, ending ~21 Oct) and cycle 2/3 history, and makes the naming scheme uniform across all active fleets (`B`, `C`, `D`, `E`).

### G3. `InpBreakerEnable=false` on Fleet `E`

**Verdict: Keep `InpBreakerEnable=false` on `E` (matching the operator's ruling), and record the two-sided consequence in the Fleet E runbook.**

- In `333e7e6:ea/grind_engine.mqh:1582-1587` and `1698-1771`, `InpBreakerEnable` gates three coupled behaviours at `allowance = 0.05 * initial_deposit` ($500 on a $10k FTMO demo, `333e7e6:ea/grind_engine.mqh:1713`):
  1. `Grind_BreakerFloatGate` (`333e7e6:ea/grind_pure.mqh:673-681`): blocks all new `L0` and `add` entries account-wide when floating loss `balance - equity >= 0.5 * allowance` ($250), releasing below $200.
  2. `Grind_BreakerPreMidnightHalt` (`333e7e6:ea/grind_pure.mqh:663-670`): blocks entries after 23:00 Prague when `balance - equity >= 0.5 * allowance` ($250).
  3. `Grind_BreakerShouldTrip` (`333e7e6:ea/grind_pure.mqh:655-660`): trips and cancels resting entry orders at `equity <= anchor - 0.8 * allowance` (-$400).
- With 12 instances (OPT + ALT) on a $10k FTMO demo, a wide swing of the size ALT is built to trade will routinely exceed $250 floating loss (as 7 OPT-only instances already did on 16 Oct at $224–$250, `e732eed`). Enabling `InpBreakerEnable=true` as currently coded would trip the $250 float gate (`Grind_EntriesBlocked()`, `333e7e6:ea/grind_engine.mqh:1600-1604`) and block ALT's adds and OPT's post-roll entries, breaking the E-vs-D mirror (`333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:189-196`).
- **Flag:** With `InpBreakerEnable=false`, nothing in the EA halts entries before FTMO's hard $500 daily loss limit. That is acceptable only because E is a disposable demo mirrored on D (`333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:189-190, 222`); before moving to a paid challenge, C155 (per-side / decoupled breaker vs float gate) will be needed. Note that `DAILY_SNAPSHOT` (`333e7e6:ea/grind_snapshot.mqh:306-367`) runs on `OnTimer` independently of `InpBreakerEnable`, so daily FTMO telemetry remains active.

### G4. Carry pass ON (`InpEnableCarryPass=true`) for ALT

**Verdict: Sound — keep `InpEnableCarryPass=true` on ALT.**

- Cycle 2's `ea/presets/*_alt.set` (`333e7e6:ea/presets/eurusd_alt.set:10`, added in `7c4f4b1`) had `InpEnableCarryPass=false` only because Cycle 2's `OPT` vs `ALT` was a live A/B test of the carry pass itself (`InpSlot=ALT` later had `InpEnableCarryPass=true` on all `_dup` presets, e.g. `333e7e6:ea/presets_d/audnzd_dup_d_lat.set:16`).
- A wide ALT arm (exits 9–30 pips) holds layers across more rollovers than OPT. In `Grind_CarryExitShiftLayer` (`333e7e6:ea/grind_carry.mqh:1080-1144`), negative carry shifts exits outward to recover swap, while positive carry shifts exits inward subject to `Grind_CarrySignGuardAppliesAtShift` (`333e7e6:ea/grind_carry.mqh:691-700, 1134`), which prevents shifting an exit past `Grind_EffectiveEntry(entry, pos)`. Carry GVs are keyed by `magic` (gate) and `position_ticket` (accrued/shift), so OPT and ALT do not collide.

### G5. GBPCHF's magic (index 10: `22261001`, `22261002`) outside `GRIND_CAP_ALL_MAGICS`

**Verdict: Agree it is harmless for next week's Fleet C deployment (no EA change needed now), but correct `T3`'s premise.**

- Contrary to `T3`, `GRIND_CAP_ALL_MAGICS` (`333e7e6:ea/grind_cap.mqh:18`) does **not** feed only the currency cap; it also feeds `Grind_IsFleetMagic` (`333e7e6:ea/grind_exitq.mqh:105-112`), which is called by `Grind_SlotRestingEnt()` (`333e7e6:ea/grind_exitq.mqh:149`) in the ADR-151 account-wide slot guard (`333e7e6:ea/grind_engine.mqh:2085, 2372`).
- Because `22261001` and `22261002` are not in `GRIND_CAP_ALL_MAGICS`:
  - `Grind_SlotUsed()` (`PositionsTotal() + OrdersTotal()`, `333e7e6:ea/grind_exitq.mqh:131`) is magic-agnostic and **does** count GBPCHF's open positions, resting `EXT` orders, and resting `ENT` orders once.
  - `Grind_SlotRestingEnt()` (`333e7e6:ea/grind_exitq.mqh:135-161`) skips `!Grind_IsFleetMagic(magic)` at line 149, so GBPCHF's resting `ENT` orders (at most 2 per instance = 4 across `GBPCHF_OPTC` and `GBPCHF_ALTC`) are **not** counted a second time in `resting_ent`.
- On Fleet C, there are only **6 instances total** (~90–96 guard slots used on a stressed day vs the 194 limit, `333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:121, 195`). Undercounting `resting_ent` by 0–4 slots on C cannot approach the 194 guard threshold, so no EA change is needed for next week's build (only `guard_total` in C's heartbeat/snapshot will read 0–4 lower). Before GBPCHF (or USDCAD) is ever placed on a 12-instance fleet near 180–192 / 194, `22261001UL, 22261002UL` must be added to `GRIND_CAP_ALL_MAGICS` (as C29 did for NZDCHF in `31978f6`).

### G6. One template per pair (`ea/presets_d/<p>_opt_d_r3.set`) for every fleet

**Verdict: Agreed — no key outside `TWOARM_CHANGES` should differ across `E`, `D`, and `C`.**

- Across all nine `ea/presets_d/*_opt_d_r3.set` files, the 21 keys outside `TWOARM_CHANGES` (`InpLots=0.01`, `InpEnableCarryPass=true`, `InpEnableCommandedEject=true`, `InpAutoEject=false`, `InpAutoEjectStableMinutes=5`, `InpAutoEjectSpreadMult=1.5`, `InpVirtualLattice=true`, `InpLatticeReroll=true`, `InpSessionEnable=false`, `InpFillTimePlace=true`, `InpSlotNearReserve=8`, `InpEntryHorizonPips=0`, `InpApiEntryStop=1000000`, `InpApiSoftWarn=999000`, `InpCapLegAThresh=0.0`, `InpCapLegBThresh=0.0`, `InpVerboseLog=true`, `EnableTelemetry=true`, `TelemetryURL=https://pipshed.com/api/telemetry/push`, `TelemetryAPIKey=`, `TelemetryIntervalSec=60`) have identical values.
- In particular, `InpApiEntryStop=1000000` and `InpApiSoftWarn=999000` are intentionally kept on `E` per `333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:205-207`.

### G7. What fact is missing?

1. **Slot-guard use of `GRIND_CAP_ALL_MAGICS` (`T3` / `G5`):** `Grind_IsFleetMagic` (`333e7e6:ea/grind_exitq.mqh:105-112`) and `Grind_SlotRestingEnt` (`333e7e6:ea/grind_exitq.mqh:135-161`) use `GRIND_CAP_ALL_MAGICS`, so `22261001`/`22261002` resting `ENT` orders are counted once (in `Grind_SlotUsed`) rather than twice (not in `Grind_SlotRestingEnt`).
2. **`ea/presets_e/` directory creation on `--write` (`s3`):** `333e7e6:scripts/ic_presets.py:542-545` does not call `os.makedirs`, and `ea/presets_e/` does not exist in the repo yet (see Section 3, Item 1).
3. **(Downstream, outside this prompt's files):** When Fleet D and Fleet C reload their kept OPT charts (`6` on D, `2` on C) from `*_r3.set` (`InpWidthPips` 1.0–2.5) to `*_t1.set`, **C's EURUSD OPT** changes `InpAddPips` (`6.0 -> 7.0`) and `InpExitPips` (`10.0 -> 7.0`), and **D's and C's kept OPT charts** change `InpExitPips` to `= add`. As noted in `333e7e6:docs/research/fleet-d-two-arm-ring-2026-10-16.md:254-269` (`s12`), `Grind_RebuildExitsAtStart` (`333e7e6:ea/grind_engine.mqh:3074-3167`) re-prices resting exits on reload when `GRIND_GEO_EXIT_<magic>_L/_S` exists and both sides hold `<= 7` layers; on **Fleet E**, all 12 charts start on a fresh terminal where no `GRIND_GEO_EXIT_*` GVs or open positions exist yet. Also, `scripts/deploy_presets.ps1` (`333e7e6:scripts/deploy_presets.ps1:15`) hardcodes `c:\fxmatrix\ea\presets` for the old Windows VPS; the new Linux + Wine server for Fleet E will need its own preset deployment path from `ea/presets_e/`.

---

## 3. Issues in `s2`–`s4` (and `s7`) That Are Wrong, Ambiguous, or Would Make Cursor Improvise

1. **`s3` (`333e7e6:prompts/cursor_presets_twoarm.md:67-68, 87-88`) — `main --write` will raise `FileNotFoundError` on `ea/presets_e/` unless `os.makedirs` is called.**
   - `333e7e6:prompts/cursor_presets_twoarm.md:67-68`: `Output: one file per fleet, pair and slot: ea/presets_<f>/<pair>_<slot>_<f>_t1.set, all lower case (ea/presets_e/ is new).`
   - `333e7e6:prompts/cursor_presets_twoarm.md:87-88`: `main prints summary rows and writes only with --write and 0 errors (ASCII, LF), as the round stage.`
   - In `333e7e6:scripts/ic_presets.py:542-545`, the `round` stage writes files with:
     - `333e7e6:scripts/ic_presets.py:543` `            for path, text in files.items():`
     - `333e7e6:scripts/ic_presets.py:544` `                with open(path, "w", encoding="ascii", newline="\n") as fh:`
   - Because `ea/presets_e/` does not exist at `333e7e6`, `open(path, "w", ...)` raises `FileNotFoundError` unless `os.makedirs(os.path.dirname(path), exist_ok=True)` is called before `open`. Specify `os.makedirs(os.path.dirname(path), exist_ok=True)` in `s3`.

2. **`s3` vs `s4` (`333e7e6:prompts/cursor_presets_twoarm.md:82-89, 93`) — `twoarm_preset` is required as a stub in `s4` (`build_twoarm / validate_twoarm / twoarm_preset`), but its signature is never defined in `s3`.**
   - `333e7e6:prompts/cursor_presets_twoarm.md:82`: `- validate_twoarm(template_text, out_text, fleet, pair, slot, add, table) returns a list of errors:`
   - `333e7e6:prompts/cursor_presets_twoarm.md:85`: `build_twoarm(table, root) returns ({path: text}, [errors]),`
   - `333e7e6:prompts/cursor_presets_twoarm.md:93`: `At the tests commit, add a stub build_twoarm / validate_twoarm / twoarm_preset that raise NotImplementedError so the file imports.`
   - `twoarm_preset` is never mentioned in `s3`, forcing Cursor to improvise its parameter list (e.g. `(template_text, fleet, pair, slot, add, table)` vs `(template_text, fleet, pair, slot, table)`). Define `twoarm_preset(template_text, fleet, pair, slot, add, table)` explicitly in `s3`.

3. **`s4` (`TW2`–`TW8`) vs `s7` (`333e7e6:prompts/cursor_presets_twoarm.md:92-94, 120, 154`) — Commit 1 vs Commit 2 ordering of `scripts/ic_geometry_twoarm.json` and `TW8` / `TW9`.**
   - `333e7e6:prompts/cursor_presets_twoarm.md:154`: `1. Tests (TestTwoArm and the stubs). 2. The code, the table and the 30 presets (--write). Nothing else.`
   - If `scripts/ic_geometry_twoarm.json` is not committed until Commit 2, then at Commit 1 any test in `TestTwoArm` (`TW2`–`TW8`) that calls `ip.load_table(os.path.join(HERE, "ic_geometry_twoarm.json"))` before calling a stub (`twoarm_preset` / `validate_twoarm` / `build_twoarm`) will fail with `FileNotFoundError` instead of `NotImplementedError`. Similarly, in `TW8` (`333e7e6:prompts/cursor_presets_twoarm.md:120`), reading the 30 files on disk before calling `build_twoarm` would fail with `FileNotFoundError` (or 0 files matched) at Commit 1.
   - **Fix:** Either move `scripts/ic_geometry_twoarm.json` into Commit 1 (`1. Tests (TestTwoArm, the stubs, and scripts/ic_geometry_twoarm.json)`), or instruct Cursor to call the stub (`build_twoarm` / `twoarm_preset` / `validate_twoarm`) before reading uncommitted files in `TW8` and pass an in-memory/loaded table. Also state explicitly whether `TW9` (`333e7e6:prompts/cursor_presets_twoarm.md:121-123`) is a `GUARD` test method in `TestTwoArm` (which passes at Commit 1 alongside `TW1`, giving 41 + 2 = 43 passing and 7 failing at Commit 1) or a git check in `s7`.

4. **`s4` (`TW5`, `333e7e6:prompts/cursor_presets_twoarm.md:112`) — "only `TWOARM_CHANGES` change" is a subset check (`changed <= TWOARM_CHANGES`), NOT set equality (`changed == TWOARM_CHANGES`).**
   - `333e7e6:prompts/cursor_presets_twoarm.md:112`: `- TW5 only TWOARM_CHANGES change and the key order equals the template's, for all 30 outputs.`
   - `TWOARM_CHANGES` (`s3`, lines 70–81) contains 20 keys: `InpMagic`, `InpSlot`, `InpTelemetryInstance`, `InpCapLegA`, `InpCapLegB`, `InpAddPips`, `InpExitPips`, `InpAddPipsLong`, `InpAddPipsShort`, `InpExitPipsLong`, `InpExitPipsShort`, `InpWidthPipsLong`, `InpWidthPipsShort`, `InpWidthPips`, `InpStrandedThreshPips`, `InpDeadbandPips`, `InpMaxLayers`, `InpRollGateOpposite`, `InpBreakerEnable`, `InpConfigWarning`.
   - In every `ea/presets_d/<p>_opt_d_r3.set` template, `InpDeadbandPips=2.0`, `InpRollGateOpposite=0`, `InpBreakerEnable=false`, `InpWidthPipsLong=-1.0`, `InpWidthPipsShort=-1.0`, `InpAddPipsLong=-1.0`, and `InpAddPipsShort=-1.0` already equal the `twoarm` target values; on `ea/presets_d/gbpusd_opt_d_t1.set`, only 2 keys (`InpMaxLayers` and `InpConfigWarning`) actually change from `gbpusd_opt_d_r3.set`.
   - Because existing tests `TestC10.test_only_cap_width_s_and_warning_change` (`333e7e6:scripts/test_ic_presets.py:97`) and `TestFtmoStage.test_f1_exactly_three_keys_change` (`333e7e6:scripts/test_ic_presets.py:489`) assert `self.assertEqual(changed, ...)`, clarify in `TW5` that `changed <= TWOARM_CHANGES` (no key outside `TWOARM_CHANGES` changes, matching `s3` line 83 and `333e7e6:scripts/ic_presets.py:358`).

5. **`s4` (`TW6`, `333e7e6:prompts/cursor_presets_twoarm.md:113-116`) — "Each returns at least one error naming the key" vs the two key-list/order mutations and existing `validate()` wording.**
   - `333e7e6:prompts/cursor_presets_twoarm.md:115-116`: `a key added; two keys swapped in order. Each returns at least one error naming the key.`
   - `333e7e6:prompts/cursor_presets_twoarm.md:83`: `validate_twoarm(template_text, out_text, fleet, pair, slot, add, table) returns a list of errors: keys or order differ from the template;`
   - In `333e7e6:scripts/ic_presets.py:268-269` and `477-478`, when a key is added or two keys are swapped, the function returns `["keys or their order differ from ..."]`, and existing tests (`333e7e6:scripts/test_ic_presets.py:186, 427`) match the substring `"order"` (not the added/swapped key's name). Moreover, existing `validate()` (`333e7e6:scripts/ic_presets.py:293`) writes `"width not %s on both sides"` without the literal key name `InpWidthPips`.
   - **Fix:** State in `s3`/`TW6` that every single-key value error in `validate_twoarm` names its `Inp...` / `TelemetryAPIKey` key (e.g. `InpWidthPips`, `InpAddPipsLong`), while the added-key and swapped-order mutations are matched on `"keys"` or `"order"` (from `"keys or order differ from the template"`).

6. **`s3` (`333e7e6:prompts/cursor_presets_twoarm.md:79-81`) — `<tag>` precedence for `GBPCHF` on `C` and reading table fields.**
   - `333e7e6:prompts/cursor_presets_twoarm.md:80-81`: `where <tag> is q90 for E's ALT, q95 for D's and C's ALT, range guess for GBPCHF's ALT, and - for OPT.`
   - Because `GBPCHF` runs on Fleet `C`, an `if/elif` that checks `fleet in ("D", "C")` before `pair == "GBPCHF"` (or `pair in table.get("template", {})`) will produce `q95` instead of `range guess`. State the precedence explicitly (`slot == "OPT"` -> `"-"`; `pair in table.get("template", {})` -> `"range guess"`; `fleet == "E"` -> `"q90"`; `fleet in ("D", "C")` -> `"q95"`), and note that `<account>` and `<box>` come from `table["fleets"][fleet]["account"]` and `table["fleets"][fleet]["box"]` (since `ACCOUNT` at `333e7e6:scripts/ic_presets.py:44-46` only has `"B"`, `"C"`, `"D"`).
