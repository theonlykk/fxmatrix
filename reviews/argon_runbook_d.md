# Review of `docs/runbooks/twoarm-build-d.md` at `3086316`

Reviewed commit: `3086316e4ff608386794d2f51e536a5c2c2bc7a7` (`3086316` on `main`).

---

## 1. Fact-by-Fact Verification Against `3086316` (With File & Line Quotes)

### Header (`3086316:docs/runbooks/twoarm-build-d.md:1-11`)

- **Line 6 (`What`):**
  > `| **What** | D becomes FTMO's mirror (fleet D note s10-s12): EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF with OPT + ALT, exit = add, cap 7 (12 instances); NZDCHF, NZDCAD, AUDNZD retire |`
  - **Check — VERIFIED:**
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:194`:
      `| **D** (wine-d, IC 53077984) | **a mirror of FTMO**: the same six, OPT + ALT, cap 7; retire NZDCHF, NZDCAD, AUDNZD | 12 |`
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:224`:
      `**RULED: exit = add on OPT and ALT on FTMO, D and C; cap 7; ALT's adds at q90 on FTMO and q95 on D and C**`
    - `3086316:scripts/ic_geometry_twoarm.json:3-4, 15`:
      `"pairs_d": ["GBPUSD", "EURUSD", "EURGBP", "AUDCAD", "AUDCHF", "CADCHF"]`, `"retire_d": ["NZDCHF", "NZDCAD", "AUDNZD"]`, `"max_layers": 7`.

- **Line 7 (`Uses`):**
  > ``| **Uses** | `main` `2426f94` or later: `ea/presets_d/<pair>_{opt,alt}_d_t1.set` (verified byte for byte, HANDOFF s85 continued 9); `/root/mon_logcheck.awk` on wine-d (monday-night 0.1, 2688 bytes); pipshed branch `twoarm-fleets` `320afe6` (merged AFTER D and C, s7) |``
  - **Check — VERIFIED:**
    - `3086316:HANDOFF.md:57`:
      `- **Done (`2426f94`, 30 files; verified byte for byte against the spec):**`
    - `3086316:docs/runbooks/monday-night-2026-10-05.md:20-58`:
      `### 0.1 Stage the log checker on all four boxes ... wc -c /root/mon_logcheck.awk` / `Expected: 2688 /root/mon_logcheck.awk.`
    - `3086316:HANDOFF.md:62`:
      `- **Done on branch `twoarm-fleets` (`320afe6`, 6 files, 31 tests pass; NOT merged or deployed — deploy after D and C are on the new layout, same order as Monday 5 Oct s4):**`

- **Line 8 (`When`):**
  > `| **When** | Wed 21 Oct or later, in market hours (London / New York, about 12:00-16:00Z), after plan 4's export (Tue 20 Oct 22:10Z). Never 20:50-21:15Z; not within 30 minutes of a tier-1 release (check the calendar on the day). Safe to stop between steps 4, 5 and 6 |`
  - **Check — VERIFIED:**
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:213-214`:
      `- **Order:** Tue 20 Oct night the export; then D and C in market hours (D first: the mirror), from Wed 21 Oct`
    - `3086316:docs/runbooks/round-reload.md:9`:
      `| **When** | In session, spreads normal (IC outside the 21Z hour: 0.1-0.5 pips); never 20:50-21:15Z; not within 30 min of a tier-1 release (check the calendar) |`

- **Line 9 (`Rulings`):**
  > `| **Rulings** | Operator 17 Oct: the layout (s10), exit = add on both arms and "if we have to flatten all positions - so be it. these are demo accounts" (s11); never log out wine-d's IC terminal (C150) |`
  - **Check — VERIFIED:**
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:201`:
      `- **wine-d's IC terminal is never logged out** (C150: the web login refused since 12 Oct; a fresh login may fail): D changes charts inside the running terminal only.`
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:221-222`:
      `*Operator ruling (17 Oct):* **"i think we dont learn much with b. if we have to flatten all positions - so be it. these are demo accounts."**`

---

### Section 0: What This Build Changes on Every Chart (`3086316:docs/runbooks/twoarm-build-d.md:13-35`)

- **Lines 15–17 (Worked example — `EURUSD OPT`, `22260201`):**
  > `Example — EURUSD OPT (22260201): today on wine-d it runs eurusd_opt_d_r3.set (width 2.0, add 7.0, exit 9.0 long / 11.0 short, cap 8). Suppose its long side holds 5 layers and the shallowest layer is at 1.1600 with its resting exit at 1.1609 (entry + 9 pips). When you load eurusd_opt_d_t1.set (width 2.0, add 7.0, exit 7.0, cap 7) and click OK, the EA checks 5 <= 7 (passes I7), sees the exit changed 9.0 -> 7.0 (long) and 11.0 -> 7.0 (short), and modifies that resting exit from 1.1609 to 1.1607 (entry + 7 pips) in place.`
  - **Check — VERIFIED:**
    - `3086316:ea/presets_d/eurusd_opt_d_r3.set:3-5, 10-12`:
      `InpWidthPips=2.0`, `InpAddPips=7.0`, `InpExitPips=9.0`, `InpExitPipsLong=9.0`, `InpExitPipsShort=11.0`, `InpMaxLayers=8`.
    - `3086316:ea/presets_d/eurusd_opt_d_t1.set:3-5, 10-12`:
      `InpWidthPips=2.0`, `InpAddPips=7.0`, `InpExitPips=7.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`.
    - `3086316:ea/grind_recon.mqh:489-492` (`I7_LONG_DEPTH` check in `Grind_ReconCheckInvariants`):
      `if(long_count > max_layers) { reason_out = "I7_LONG_DEPTH"; return false; }` (`5 <= 7` passes).
    - `3086316:ea/grind_recon.mqh:537, 1404-1417` and `3086316:ea/grind_carry.mqh:635-642`:
      `g_grind_rebuild_long = Grind_GeoExitChanged(g_grind_recon_magic, true, g_grind_recon_exit_pips);` (`9.0 != 7.0` -> `true`) and `g_grind_rebuild_short = Grind_GeoExitChanged(g_grind_recon_magic, false, short_exit_eff);` (`11.0 != 7.0` -> `true`); `if(tolerate_exit_price_long && !long_exit_filled) continue;` skips `I6_LONG_EXIT_PRICE` during `OnInit` reconstruction so `Grind_RebuildExitsAtStart` can reprice the resting exit order.
    - `3086316:ea/grind_engine.mqh:3116-3125` (`Grind_RebuildExitsAtStartSide`):
      `const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);` (`1.1600 + 7.0 * 0.00010 = 1.16070` for an unrolled layer with zero carry/eject offset) followed by `Grind_ModifyPendingPrice(exit_ticket, price, magic)`.

- **Lines 19–32 (Chart-by-chart table: `r3 -> t1`, `geo=` and `rebuild=` in `mon_logcheck.awk`):**
  - How `mon_logcheck.awk` formats `geo=` and `rebuild=`:
    - `3086316:ea/fxgrind.mq5:369-374`:
      ```mql5
      Print(Grind_LogTag(), "GRIND_GEOMETRY long=",
            DoubleToString(g_geo_width_long, 1), "/", DoubleToString(g_geo_add_long, 1), "/", DoubleToString(g_geo_exit_long, 1),
            " short=",
            DoubleToString(g_geo_width_short, 1), "/", DoubleToString(g_geo_add_short, 1), "/", DoubleToString(g_geo_exit_short, 1));
      Print(Grind_LogTag(), "GRIND_REBUILD long=", (g_grind_rebuild_long ? "true" : "false"),
            " short=", (g_grind_rebuild_short ? "true" : "false"));
      ```
    - `3086316:docs/runbooks/monday-night-2026-10-05.md:40-43`:
      `mon_logcheck.awk` strips `.0` (`gsub(/\.0/, "", g)`) and formats `geo=L<w>/<a>/<e> S<w>/<a>/<e>` and `rebuild=<long>/<short>`.
  - **Row-by-row check against `3086316:ea/presets_d/*_{r3,t1}.set` — ALL 12 ROWS VERIFIED:**
    1. **Line 21 (`GBPUSD OPT (22260101)`):**
       - `3086316:ea/presets_d/gbpusd_opt_d_r3.set:1-15`: `InpMagic=22260101`, `InpWidthPips=2.5`, `InpAddPips=9.0`, `InpExitPips=9.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=3.5`.
       - `3086316:ea/presets_d/gbpusd_opt_d_t1.set:1-15`: `InpMagic=22260101`, `InpWidthPips=2.5`, `InpAddPips=9.0`, `InpExitPips=9.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=3.5`.
       - Exit unchanged (`9.0 -> 9.0` both sides) -> `geo=L2.5/9/9 S2.5/9/9`, `rebuild=false/false`.
    2. **Line 22 (`EURUSD OPT (22260201)`):**
       - `3086316:ea/presets_d/eurusd_opt_d_r3.set:1-15`: `InpMagic=22260201`, `InpWidthPips=2.0`, `InpAddPips=7.0`, `InpExitPips=9.0`, `InpExitPipsLong=9.0`, `InpExitPipsShort=11.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=3.0`.
       - `3086316:ea/presets_d/eurusd_opt_d_t1.set:1-15`: `InpMagic=22260201`, `InpWidthPips=2.0`, `InpAddPips=7.0`, `InpExitPips=7.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=3.0`.
       - Exit `9.0/11.0 -> 7.0` -> `geo=L2/7/7 S2/7/7`, `rebuild=true/true`.
    3. **Line 23 (`EURGBP OPT (22260301)`):**
       - `3086316:ea/presets_d/eurgbp_opt_d_r3.set:1-15`: `InpMagic=22260301`, `InpWidthPips=1.0`, `InpAddPips=3.0`, `InpExitPips=6.0`, `InpExitPipsLong=6.0`, `InpExitPipsShort=4.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=2.0`.
       - `3086316:ea/presets_d/eurgbp_opt_d_t1.set:1-15`: `InpMagic=22260301`, `InpWidthPips=1.0`, `InpAddPips=3.0`, `InpExitPips=3.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=2.0`.
       - Exit `6.0/4.0 -> 3.0` -> `geo=L1/3/3 S1/3/3`, `rebuild=true/true`.
    4. **Line 24 (`AUDCAD OPT (22260401)`):**
       - `3086316:ea/presets_d/audcad_opt_d_r3.set:1-15`: `InpMagic=22260401`, `InpWidthPips=1.5`, `InpAddPips=6.0`, `InpExitPips=9.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=2.5`.
       - `3086316:ea/presets_d/audcad_opt_d_t1.set:1-15`: `InpMagic=22260401`, `InpWidthPips=1.5`, `InpAddPips=6.0`, `InpExitPips=6.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=2.5`.
       - Exit `9.0 -> 6.0` -> `geo=L1.5/6/6 S1.5/6/6`, `rebuild=true/true`.
    5. **Line 25 (`AUDCHF OPT (22260501)`):**
       - `3086316:ea/presets_d/audchf_opt_d_r3.set:1-15`: `InpMagic=22260501`, `InpWidthPips=1.5`, `InpAddPips=4.0`, `InpExitPips=11.0`, `InpExitPipsLong=11.0`, `InpExitPipsShort=9.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=2.5`.
       - `3086316:ea/presets_d/audchf_opt_d_t1.set:1-15`: `InpMagic=22260501`, `InpWidthPips=1.0`, `InpAddPips=4.0`, `InpExitPips=4.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=2.0`.
       - Width `1.5 -> 1.0`, stranded `2.5 -> 2.0`, exit `11.0/9.0 -> 4.0` -> `geo=L1/4/4 S1/4/4`, `rebuild=true/true`.
    6. **Line 26 (`CADCHF OPT (22260601)`):**
       - `3086316:ea/presets_d/cadchf_opt_d_r3.set:1-15`: `InpMagic=22260601`, `InpWidthPips=1.0`, `InpAddPips=4.0`, `InpExitPips=11.0`, `InpExitPipsLong=11.0`, `InpExitPipsShort=9.0`, `InpMaxLayers=8`, `InpStrandedThreshPips=2.0`.
       - `3086316:ea/presets_d/cadchf_opt_d_t1.set:1-15`: `InpMagic=22260601`, `InpWidthPips=1.0`, `InpAddPips=4.0`, `InpExitPips=4.0`, `InpExitPipsLong=-1.0`, `InpExitPipsShort=-1.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=2.0`.
       - Exit `11.0/9.0 -> 4.0` -> `geo=L1/4/4 S1/4/4`, `rebuild=true/true`.
    7. **Line 27 (`GBPUSD ALT (22260102, new)`):**
       - `3086316:ea/presets_d/gbpusd_alt_d_t1.set:1-15`: `InpMagic=22260102`, `InpSlot=ALT`, `InpWidthPips=7.5`, `InpAddPips=30.0`, `InpExitPips=30.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=8.5`.
       - No prior `GRIND_GEO_EXIT_22260102_L/_S` GV on wine-d (`Grind_GeoExitGet` returns `false`, `3086316:ea/grind_carry.mqh:621, 638`) -> `geo=L7.5/30/30 S7.5/30/30`, `rebuild=false/false`.
    8. **Line 28 (`EURUSD ALT (22260202, new)`):**
       - `3086316:ea/presets_d/eurusd_alt_d_t1.set:1-15`: `InpMagic=22260202`, `InpSlot=ALT`, `InpWidthPips=7.0`, `InpAddPips=27.0`, `InpExitPips=27.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=8.0` -> `geo=L7/27/27 S7/27/27`, `rebuild=false/false`.
    9. **Line 29 (`EURGBP ALT (22260302, new)`):**
       - `3086316:ea/presets_d/eurgbp_alt_d_t1.set:1-15`: `InpMagic=22260302`, `InpSlot=ALT`, `InpWidthPips=5.0`, `InpAddPips=19.0`, `InpExitPips=19.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=6.0` -> `geo=L5/19/19 S5/19/19`, `rebuild=false/false`.
    10. **Line 30 (`AUDCAD ALT (22260402, new)`):**
        - `3086316:ea/presets_d/audcad_alt_d_t1.set:1-15`: `InpMagic=22260402`, `InpSlot=ALT`, `InpWidthPips=7.0`, `InpAddPips=27.0`, `InpExitPips=27.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=8.0` -> `geo=L7/27/27 S7/27/27`, `rebuild=false/false`.
    11. **Line 31 (`AUDCHF ALT (22260502, new)`):**
        - `3086316:ea/presets_d/audchf_alt_d_t1.set:1-15`: `InpMagic=22260502`, `InpSlot=ALT`, `InpWidthPips=5.5`, `InpAddPips=22.0`, `InpExitPips=22.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=6.5` -> `geo=L5.5/22/22 S5.5/22/22`, `rebuild=false/false`.
    12. **Line 32 (`CADCHF ALT (22260602, new)`):**
        - `3086316:ea/presets_d/cadchf_alt_d_t1.set:1-15`: `InpMagic=22260602`, `InpSlot=ALT`, `InpWidthPips=3.0`, `InpAddPips=12.0`, `InpExitPips=12.0`, `InpMaxLayers=7`, `InpStrandedThreshPips=4.0` -> `geo=L3/12/12 S3/12/12`, `rebuild=false/false`.

- **Lines 34–35 (Common settings & no EA code change):**
  > `Every chart: cap 7, deadband 2.0, lattice and re-roll true, roll gate 0, breaker and auto-eject false. No EA code change: the build is presets only (s2.3 checks it); no compile.`
  - **Check — VERIFIED:**
    - Across all 12 `3086316:ea/presets_d/*_t1.set` files (`:12, 15, 18, 21-24`): `InpMaxLayers=7`, `InpDeadbandPips=2.0`, `InpEnableCarryBreaker=false`, `InpEnableAutoEject=false`, `InpEnableLattice=true`, `InpLatticeRollMinLayers=0`, `InpEnableReRoll=true`.
    - `git diff --stat 5bb5fdb 3086316 -- 'ea/*.mq5' 'ea/*.mqh'` is empty (verified against `3086316`).

---

### Section 1: Before You Start (`3086316:docs/runbooks/twoarm-build-d.md:37-43`)

- **Lines 39–42 (Local fingerprint `eb0d6a097694`):**
  > `sha256sum ea/presets_d/*_t1.set | sha256sum | cut -c1-12`
  > `Expected: eb0d6a097694.`
  - **Check — VERIFIED:**
    - Recomputed from the 12 LF-terminated git blobs `3086316:ea/presets_d/*_t1.set` sorted in C/ASCII order (`audcad_alt_d_t1.set` through `gbpusd_opt_d_t1.set`): `sha256sum` of the `sha256sum` output starts with `eb0d6a097694` (`eb0d6a0976943c3203d74b7650eb07e17805d94d704225461233bfebff6a760b`), and `ls -1 | wc -l` is `12`.
    - Also matches `3086316:docs/runbooks/round-reload.md:14-18` (using `*_t1.set` in place of `*_rN.set`).

---

### Section 2: On wine-d (`161.35.42.90`): Pull, Check, Stage (`3086316:docs/runbooks/twoarm-build-d.md:45-67`)

- **Lines 47–66 (`s2.1`–`s2.4`):**
  - `s2.1` (`:47`): `D="$HOME/.wine/drive_c/Program Files/MetaTrader 5 IC Markets Global/MQL5"` matches `3086316:docs/runbooks/round-reload.md:23` and `3086316:docs/runbooks/monday-build-2026-10-05.md:27`.
  - `s2.2` (`:50`): `wc -c /root/mon_logcheck.awk` -> `2688 /root/mon_logcheck.awk` matches `3086316:docs/runbooks/monday-night-2026-10-05.md:56-58`.
  - `s2.3` (`:52-56`): `git diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh'` prints nothing at `3086316`, matching the `5bb5fdb` EA baseline from `3086316:docs/runbooks/wednesday-build-2026-10-07.md:5, 16, 68`.
  - `s2.4` (`:58-66`): stages `ea/presets_d/*_t1.set` with `TelemetryAPIKey=` injected from `/root/.telemetry_key`, verifies `12` files and `eb0d6a097694` before injection and zero empty keys after injection, matching `3086316:docs/runbooks/round-reload.md:24-34`.

---

### Section 3: Retire NZDCHF, NZDCAD, AUDNZD in VNC (`3086316:docs/runbooks/twoarm-build-d.md:69-81`)

- **Lines 71–80 (`s3`):**
  > `Same steps as the Monday 5 Oct twin retirement (monday-build-2026-10-05.md s3.2), here for OPT on the three retiring pairs (`22260701`, `22260801`, `22260901`). Do one pair at a time:`
  - **Check — VERIFIED:**
    - Magic numbers in `3086316:ea/presets_d/nzdchf_opt_d_r3.set:1` (`22260701`), `3086316:ea/presets_d/nzdcad_opt_d_r3.set:1` (`22260801`), and `3086316:ea/presets_d/audnzd_opt_d_r3.set:1` (`22260901`).
    - Steps 1–4 match `3086316:docs/runbooks/monday-build-2026-10-05.md:65-79` (`3.2 Retire the two twins`), adapted from `GRIND|ALT|` to `GRIND|OPT|`, plus Step 5 (`Close the chart window`).
    - Removing the EA logs `fxgrind deinit reason=1` (`REASON_REMOVE`, `3086316:ea/fxgrind.mq5:404`).

---

### Section 4: Reload the Six OPT Charts in VNC (`3086316:docs/runbooks/twoarm-build-d.md:83-102`)

- **Lines 85–88 (The cap rule & `I7`):**
  > `The cap rule (I7, fleet D note s12): reload a chart only when BOTH its sides hold 6 layers or fewer, read on pipshed's D books table (or the Trade tab count of GRIND|OPT|L| and |S| on that symbol) just before. 6, not 7: one layer of margin for an add filling between the read and the OK. A side at 7 or 8: wait (layers come off as scalps fill), or flatten that chart as s3 steps 2-5 with the EA removed, then attach it fresh as s5.`
  - **Check against `3086316:ea/` and `fleet-d-two-arm-ring-2026-10-16.md` s12:**
    - `3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:235`:
      `- **Start-up check I7 (`long_count > max_layers` or `short_count > max_layers`, non-quarantinable):** if a side on D holds 8 layers when the preset is reloaded with `InpMaxLayers = 7`, the EA halts on `I7_LONG_DEPTH` or `I7_SHORT_DEPTH`. **Runbook rule:** check each chart's layer count before reloading; if a side is at 8, either wait until a scalp brings it to <= 7 or flatten that chart.`
    - `3086316:ea/grind_recon.mqh:489-496`:
      ```mql5
      if(long_count > max_layers) {
         reason_out = "I7_LONG_DEPTH";
         return false;
      }
      if(short_count > max_layers) {
         reason_out = "I7_SHORT_DEPTH";
         return false;
      }
      ```
    - `3086316:ea/grind_quarantine.mqh:30-42`: `Grind_IsQuarantinableReason` returns `true` only for `I3_`, `I5_`, `I6_`, `I8_`; `I7_` returns `false` (non-quarantinable).
    - **Two important caveats found in the EA source (detailed in GD-2, GD-7, and Section 3 below):**
      1. **Why `<= 6` is required by the EA even if no fill races the click (a side at `7` cannot simply be reloaded in place):** Under `r3` (`InpMaxLayers=8`), a side with `7` open layers (`L0..L6`, `n = 7`) has a resting 8th-layer add order `GRIND|OPT|L|7|ENT` (or `|S|7|ENT`) on the broker (`required_index = Grind_SideNextIndex(side) = 7`). If reloaded with `InpMaxLayers=7` while holding `7` layers, `Grind_ReconstructState()` (`3086316:ea/grind_recon.mqh:489-495, 1079, 1086`) passes `I7` (`7 <= 7`) and adopts `|7|ENT` into `side.add_pending_ticket`. Then on tick, `Grind_EnsureAddNext()` (`3086316:ea/grind_engine.mqh:2495-2528`) sees `parsed_layer == required_index` (`7 == 7`, `:2506`), does **not** cancel `side.add_pending_ticket`, and returns early at `:2525-2527` (`!Grind_CanPlaceEntryLayer(7, 7)`) **leaving `GRIND|OPT|...|7|ENT` live on the broker**. If that `|7|ENT` later fills, the side reaches 8 layers and halts on `INVARIANT_FAIL` (`I7_*_DEPTH`).
      2. **Flattening an OPT chart and re-attaching it does NOT produce `s5`'s `replay=ready(0)` or `rebuild=false/false`:** For `EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, and `CADCHF` OPT (`22260201..22260601`), removing the EA and closing positions does not delete the terminal's `GRIND_GEO_EXIT_22260[2-6]01_L/_S` Global Variables (`3086316:ea/grind_carry.mqh:612-642`) or deal history (`3086316:ea/grind_replay.mqh:163-184`). Re-attaching an OPT chart with `<pair>_opt_d_t1.set` therefore logs `replay=ready(N)` (`N >= 0`) and `rebuild=true/true` (matching `s0`'s OPT rows), not `s5`'s `replay=ready(0)` and `rebuild=false/false`.

- **Lines 90–102 (Reload steps 1–3, `mon_logcheck.awk`, and `I7` recovery):**
  - Steps 1–3 match `3086316:docs/runbooks/round-reload.md:38-64`.
  - `InpConfigWarning = FLEET D two-arm t1 <PAIR> OPT -` matches `3086316:ea/presets_d/gbpusd_opt_d_t1.set:37`, `eurusd_opt_d_t1.set:37`, `eurgbp_opt_d_t1.set:37`, `audcad_opt_d_t1.set:37`, `audchf_opt_d_t1.set:37`, `cadchf_opt_d_t1.set:37`.
  - `deinit=5` (`REASON_PARAMETERS`), `replay=ready(...)`, `lattice=true`, `reroll=true`, `geo=`, `rebuild=`, `BAD 0` match `3086316:ea/fxgrind.mq5:362-374, 404` and `3086316:docs/runbooks/monday-night-2026-10-05.md:20-53`.
  - `I7` recovery by reloading `<pair>_opt_d_r3.set` (`cap 8`) works cleanly in the EA source (verified in **GD-4** below).

---

### Section 5: Attach the Six ALT Charts in VNC (`3086316:docs/runbooks/twoarm-build-d.md:104-112`)

- **Lines 106–112 (`s5`):**
  > `For each of GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, one chart at a time:`
  > `1. Open a new M5 chart for the pair.`
  > `2. Drag fxgrind from Navigator -> Expert Advisors onto the chart. On Common, tick Allow Algo Trading. On Inputs, click Load, pick <pair>_alt_d_t1.set, check InpSlot = ALT, InpMaxLayers = 7, InpConfigWarning = FLEET D two-arm t1 <PAIR> ALT -, click OK.`
  > `3. Run the s4 step 3 log check with from=HH:MM:00. Expect: deinit=-, replay=ready(0), lattice=true, reroll=true, the ALT geo= from s0, rebuild=false/false, BAD 0, and two L0 limit orders (GRIND|ALT|L|0|ENT and GRIND|ALT|S|0|ENT) in the Trade tab at mid -/+ width. Wait up to 60s and re-run to confirm a POST ok.`
  - **Check — VERIFIED (with one log-checker ambiguity noted in Section 3 below):**
    - `InpSlot=ALT`, `InpMaxLayers=7`, `InpConfigWarning=FLEET D two-arm t1 <PAIR> ALT -` match `3086316:ea/presets_d/{gbpusd,eurusd,eurgbp,audcad,audchf,cadchf}_alt_d_t1.set:2, 12, 37`.
    - Fresh attach has no preceding deinit (`deinit=-`, `3086316:docs/runbooks/monday-night-2026-10-05.md:22`), zero historical deals for `22260[1-6]02` (`replay=ready(0)`, `3086316:ea/grind_replay.mqh:163-184`), and no prior `GRIND_GEO_EXIT_22260[1-6]02_L/_S` GV (`rebuild=false/false`, `3086316:ea/grind_carry.mqh:621, 638`).
    - On the first tick, `Grind_OnTickEngine` (`3086316:ea/grind_engine.mqh:3219-3222`) calls `Grind_EnsureStraddleIdle`, placing `GRIND|ALT|L|0|ENT` and `GRIND|ALT|S|0|ENT` at `mid -/+ width` (`3086316:ea/grind_pure.mqh:124-137`).

---

### Sections 6, 7, and 8 (`3086316:docs/runbooks/twoarm-build-d.md:114-131`)

- **Section 6 (`:114-118`):**
  - 12 charts (`6 pairs x 2 arms`), `BAD 0`, and non-zero `POST-ok` for each of the 6 symbols match `s0`–`s5`.
- **Section 7 (`:120-124`):**
  - Matches `3086316:HANDOFF.md:62` (pipshed `twoarm-fleets` `320afe6` deployed after both D and C are on the new layout).
- **Section 8 (`:126-131`):**
  - Matches `3086316:docs/runbooks/round-reload.md:66-70` and `3086316:docs/runbooks/monday-build-2026-10-05.md:157-166` (see **GD-7** and Section 3 below for missing STOP conditions).

---

## 2. Answers to Reviewer Questions `GD-1` to `GD-7`

> - **GD-1.** Retire by closing at market (the twins' precedent, GB-1), not by letting the books run off. Sound?

**Sound.** The EA has no per-chart "wind-down / exit-only" input (`InpApiEntryStop` at `3086316:ea/fxgrind.mq5:42, 415` is an account-wide emergency latch that cancels all entry orders when the terminal-wide `GRIND_API_ENTRY_STOP` GV is set). Leaving `NZDCHF`, `NZDCAD`, and `AUDNZD` attached would keep placing new L0s, adds, and lattice rolls. Removing the EA first (`s3` step 1), deleting resting orders (step 2), pairing opposite sides with `Close By` to save a spread (step 3), and closing the unhedged remainder at market (step 4) realizes only the floating MTM already in account equity (`3086316:docs/runbooks/monday-build-2026-10-05.md:75-76, 179-181`), frees broker order slots before Step 5 attaches six new charts, and follows the operator's 17 Oct ruling (`3086316:docs/research/fleet-d-two-arm-ring-2026-10-16.md:221-222`).

> - **GD-2.** The cap rule at 6, not 7 (s4): enough margin, or too conservative?

**Not too conservative — `<= 6` is strictly required by the EA code (reloading at `7` is broken even without a race), and the `<= 6` check must be read from the MT5 Trade tab immediately before F7 rather than from pipshed's books table.**

1. **Why reloading a side at `7` layers is unsafe in the EA even if no fill occurs during F7:**
   - Under `r3` (`InpMaxLayers = 8`), a side holding **7** open layers (`L0..L6`, `n = 7`, `required_index = Grind_SideNextIndex(side) = 7`) already has a resting 8th-layer add order (`GRIND|OPT|L|7|ENT` or `GRIND|OPT|S|7|ENT`) on the broker.
   - If you reload that chart with `<pair>_opt_d_t1.set` (`InpMaxLayers = 7`) while the side holds 7 layers:
     - `Grind_ReconstructState()` (`3086316:ea/grind_recon.mqh:489-495, 1079, 1086`) passes `I7` (`7 <= 7`) and adopts `GRIND|OPT|...|7|ENT` into `side.add_pending_ticket`.
     - On tick, `Grind_EnsureAddNext()` (`3086316:ea/grind_engine.mqh:2495-2528`) checks `if(parsed_layer != required_index)` (`7 != 7` is `false` at `:2506`), so it does **not** cancel `side.add_pending_ticket`, and then hits `if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))` (`!Grind_CanPlaceEntryLayer(7, 7)` at `:2525`) and returns at `:2527` **without cancelling the resting `|7|ENT` order**.
     - That leaves the 8th-layer `|7|ENT` order live on the broker with `BAD 0` in the logs. When `|7|ENT` later fills, the side reaches 8 layers (`8 > 7`) and halts on `INVARIANT_FAIL` (`I7_LONG_DEPTH` / `I7_SHORT_DEPTH`).
2. **Why `<= 6` is the right rule — with two operational tightenings:**
   - When a side holds `<= 6` layers at the moment `OnInit` runs, its resting add is at most `|6|ENT` (the 7th layer). Once `|6|ENT` later fills under `InpMaxLayers = 7`, `Grind_TryPlaceAddAtFill` (`3086316:ea/grind_engine.mqh:2424`) and `Grind_EnsureAddNext` (`:2525`) both check `Grind_CanPlaceEntryLayer(7, 7)` (`false`) and never place `|7|ENT`.
   - **Tightening 1:** Read layer depth in the **MT5 Trade tab** (not pipshed's D books table, which has up to 60s heartbeat lag) immediately before F7 -> Load -> OK.
   - **Tightening 2:** If a side was at `6` layers when checked and its `|6|ENT` order filled (and `Grind_TryPlaceAddAtFill` placed `|7|ENT`) during the seconds while F7 was open, `OnInit` will **not** fail `I7` (`7 <= 7`) — it will succeed with `BAD 0` and leave `|7|ENT` resting on the broker! Therefore, immediately after clicking OK in Step 4, check the Trade tab to confirm the reloaded chart has **no resting `GRIND|OPT|L|7|ENT` or `GRIND|OPT|S|7|ENT` order** (if one exists, either delete that `|7|ENT` pending order after reloading back to `r3` or reload `r3`).

> - **GD-3.** Order: retire, then reload OPT, then attach ALT. Any reason to attach ALT first?

**No — keep the runbook's order (`s3` retire -> `s4` reload OPT -> `s5` attach ALT). Do not attach ALT first:**

1. **Broker order-slot headroom (ADR-151):** Retiring `NZDCHF`, `NZDCAD`, and `AUDNZD` first removes 3 charts and their open layers + resting orders before any new chart is added, keeping total account positions + pending orders well below the 194-slot guard (`3086316:ea/grind_exitq.mqh:130-182`).
2. **Unambiguous log checking during Step 4:** `/root/mon_logcheck.awk` (`3086316:docs/runbooks/monday-night-2026-10-05.md:29, 31`) keys log records and `POST-ok` counts by chart **symbol** (`fxgrind (EURUSD,M5)` -> `EURUSD`), not by `InpTelemetryInstance` or `InpMagic`. Reloading the 6 OPT charts before attaching the 6 ALT charts ensures there is only one EA instance per symbol during Step 4.

> - **GD-4.** The I7 recovery by reloading the old `r3` preset (cap 8): does the start-up check pass at cap 8 on a book that halted at cap 7, and does the halt clear on reinit (BOOT: "a compile or reattach clears a halt and re-runs `OnInit`")?

**Yes to both — verified directly in `ea/fxgrind.mq5` and `ea/grind_recon.mqh`:**

1. **Halt state clears at the top of `OnInit()` (`3086316:ea/fxgrind.mq5:260-263`):**
   ```mql5
   g_grind_halted = false;
   g_grind_cap_blocked = false;
   g_grind_halt_reason = "";
   Grind_QuarantineReset();
   ```
   Pressing `F7 -> Load -> <pair>_opt_d_r3.set -> OK` triggers `OnDeinit(REASON_PARAMETERS)` followed by `OnInit()`, which resets `g_grind_halted = false` before running `Grind_ReconstructState()`.
2. **Why `Grind_ReconstructState()` passes cleanly at `cap 8` (`r3`) after an `I7` halt at `cap 7` (`t1`):**
   - When the `t1` (`InpMaxLayers = 7`) reload fails `Grind_ReconCheckInvariants()` on `I7_LONG_DEPTH` or `I7_SHORT_DEPTH` (`3086316:ea/grind_recon.mqh:489-496`), `Grind_ReconstructState()` cancels only resting `ENT` orders via `Grind_CancelOwnEntryOrders(g_grind_recon_magic, g_grind_recon_slot)` (`3086316:ea/grind_recon.mqh:1429`) and returns `false` (`:1430`).
   - Because `Grind_ReconstructState()` returns `false`, the `else` branch in `OnInit()` (`3086316:ea/fxgrind.mq5:270-294`) **does not execute**: neither `Grind_RebuildExitsAtStart(InpMagic)` (`:283`) nor `Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short)` (`:290`) runs.
   - Therefore, all resting `EXT` orders on the broker remain at their `r3` exit prices, and the terminal's `GRIND_GEO_EXIT_<magic>_L/_S` Global Variables remain at their `r3` values.
   - When `<pair>_opt_d_r3.set` (`InpMaxLayers = 8`) is then loaded, `long_count <= 8` and `short_count <= 8` pass `I7`, `I6` validates the untouched `r3` exits (`rebuild=false/false`), and the first `OnTick` (`3086316:ea/grind_engine.mqh:3219-3237`) re-places the cancelled `ENT` orders.

> - **GD-5.** No compile: the EA code is `5bb5fdb` and unchanged (s2.3). Any input in the `_t1` presets the running build does not know?

**None.** Every `3086316:ea/presets_d/*_t1.set` file has the exact same 41 input keys in the exact same order (`InpMagic` through `InpEnableCarryPass`) as `3086316:ea/fxgrind.mq5:14-54` and as `3086316:ea/presets_d/*_r3.set:1-41`. `git diff --stat 5bb5fdb 3086316 -- 'ea/*.mq5' 'ea/*.mqh'` is empty, and wine-d compiled `5bb5fdb` during the Wednesday 7 Oct build (`3086316:docs/runbooks/wednesday-build-2026-10-07.md:5, 16, 44-57`).

> - **GD-6.** The ALT L0 at width 3.0-7.5 pips from mid (s5): anything at start-up that assumes width <= 3?

**Nothing.** In the EA at `3086316`:

1. `Grind_ValidateGeometryInputs` (`3086316:ea/grind_pure.mqh:23-32`, called in `OnInit` at `3086316:ea/fxgrind.mq5:172, 184, 195`) requires only `width_pips > 0.0`, `add_pips > 0.0`, `exit_pips > 0.0`, `max_layers >= 1`, `lots > 0.0`.
2. `Grind_ValidateAddWidthRatio` (`3086316:ea/grind_pure.mqh:9-10, 41-51`, called at `3086316:ea/fxgrind.mq5:177, 190, 201`) requires `0.5 <= add_pips / width_pips <= 4.0`. Every D ALT preset satisfies this (`30.0 / 7.5 = 4.0`, `27.0 / 7.0 = 3.857`, `19.0 / 5.0 = 3.8`, `27.0 / 7.0 = 3.857`, `22.0 / 5.5 = 4.0`, `12.0 / 3.0 = 4.0`).
3. `Grind_StraddleBuyPrice` / `Grind_StraddleSellPrice` (`3086316:ea/grind_pure.mqh:124-137`) and `Grind_TryRecenterOppositeL0` (`3086316:ea/grind_engine.mqh:3025-3071`) use `width_pips` and `stranded_thresh_pips` directly (`InpStrandedThreshPips = InpWidthPips + 1.0` on all 6 ALT presets, so `S - W = 1.0` pip and the L0 re-centre threshold is `max(deadband, S - W) = max(2.0, 1.0) = 2.0` pips).
4. `InpEntryHorizonPips = 50.0` (`3086316:ea/presets_d/gbpusd_alt_d_t1.set:27`) is well above the widest L0 (`7.5` pips) and add (`30.0` pips).

> - **GD-7.** What failure is not on s8? What fact is missing?

1. **Failure not on `s8` — Silent `6 -> 7` fill race during F7 reload leaves a live 8th-layer `GRIND|OPT|...|7|ENT` order on the broker with `BAD 0`:**
   - As shown in **GD-2**, if an OPT chart is at 6 layers when checked and fills its 7th layer (`|6|ENT` fills and `Grind_TryPlaceAddAtFill` places `|7|ENT`) before OK is clicked in F7, `OnInit` at `cap 7` **passes** `I7` (`7 <= 7`, `BAD 0`), adopts `|7|ENT`, and `Grind_EnsureAddNext` (`3086316:ea/grind_engine.mqh:2495-2528`) returns early at `:2525-2527` without cancelling `|7|ENT`. When that `|7|ENT` fills later, the chart halts on `I7_*_DEPTH`.
   - **Add to `s8` STOP list:** *any resting `GRIND|OPT|L|7|ENT` or `GRIND|OPT|S|7|ENT` order (or any side at 7 layers) in the Trade tab after reloading an OPT chart to `cap 7`*.
2. **Failure not on `s8` — `grind telemetry dropped` and `mon_logcheck.awk` symbol collision in Step 5:**
   - `/root/mon_logcheck.awk` (`3086316:docs/runbooks/monday-night-2026-10-05.md:29-31, 50`) keys `post[src]` by **symbol** (`fxgrind (GBPUSD,M5)` -> `GBPUSD`) and does **not** include `grind telemetry dropped` (`3086316:ea/grind_telemetry.mqh:96, 99`) in its `BAD` regex (`:30`). In Step 5, `<PAIR> OPT` is already running on `<PAIR>` and logging `grind telemetry POST ok` every 60s under `fxgrind (<PAIR>,M5)`. Thus `POST-ok lines per symbol since FROM: <PAIR>=1` in Step 5 can be satisfied by `<PAIR> OPT` even if `<PAIR> ALT` failed its telemetry POST!
   - Also, `/home/khalid/fxmatrix-repo/scripts/build_logcheck.awk` (`3086316:scripts/build_logcheck.awk:12, 23-24, 33`) is already on wine-d after `git pull` in `s2.1` and additionally checks `gate=0`, `api=1000000/999000`, and `API_LIMITS_INVALID|API_LIMITS_MISMATCH|WARN_API_ENTRY_STOP`.
3. **Fact missing in `s4` — What happens if an OPT chart is flattened and re-attached (`s4` line 88):**
   - `s4` (`3086316:docs/runbooks/twoarm-build-d.md:88`) says: `"or flatten that chart as s3 steps 2-5 with the EA removed, then attach it fresh as s5."`
   - If an OPT chart (`EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, `CADCHF`) is flattened and re-attached with `<pair>_opt_d_t1.set`, its log row will **not** look like `s5` (`replay=ready(0)`, `rebuild=false/false`): because `GRIND_GEO_EXIT_22260[2-6]01_L/_S` Global Variables and deal history persist in the terminal across EA removal, re-attaching `<pair>_opt_d_t1.set` logs `replay=ready(N)` (`N > 0`) and `rebuild=true/true` (with `0` layers repriced), and you don't need to close the chart window (`s3` step 5) — just remove EA (`s3` step 1), delete orders and close positions (`s3` steps 2–4), and re-attach `fxgrind` with `<pair>_opt_d_t1.set`.
4. **Fact missing in `s0` / `s4` — Passive exit clamping on inward exit rebuild (`Grind_ExitQClampPassive`):**
   - Because `EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, and `CADCHF` OPT all **shrink** their exits (`9/11 -> 7`, `6/4 -> 3`, `9 -> 6`, `11/9 -> 4`, `11/9 -> 4`), an open layer whose unrealized profit at reload time is already between the new exit and the old exit (e.g., `+5` pips on `AUDCHF` or `CADCHF`) will have its modified exit clamped to `ask + min_dist` (long) or `bid - min_dist` (short) by `Grind_ExitQClampPassive` (`3086316:ea/grind_engine.mqh:3118`, `3086316:ea/grind_carry.mqh:443-476`), with the clamp residual recorded in `GRIND_CARRY_SHIFT_<pos>` + `GRIND_CARRY_RELEASE_<pos>` (`3086316:ea/grind_engine.mqh:3134`). Thus `ORDER_ACTION_MODIFY` will not fail even if price is inside the old exit distance, and the exit order may sit at `ask + 1 point` / `bid - 1 point` (and fill almost immediately) rather than at exact `entry +/- exit_pips`.
5. **Fact missing in `s3` — Orphan GVs from retired magics (`22260701`, `22260801`, `22260901`):**
   - Retiring `NZDCHF`, `NZDCAD`, and `AUDNZD` leaves `GRIND_GEO_EXIT_22260[789]01_L/_S`, `GRIND2226_22260[789]01_*`, and closed-ticket `GRIND_VL_*` / `GRIND_CARRY_ACCRUED_*` GVs in the terminal (`GRIND_CARRY_SHIFT_*`, `GRIND_CARRY_RELEASE_*`, and `GRIND_EJECT_OFFSET_*` for closed tickets are auto-pruned on the next `OnInit` by `Grind_CarryPruneShiftGvs`, `3086316:ea/grind_carry.mqh:1049-1077`). They are harmless (currency cap is off and those magics are retired) and can be cleaned up later via `grind_gv_list.mq5` / `grind_gv_delete_exact.mq5` as in `3086316:docs/runbooks/monday-build-2026-10-05.md:151-156`.

---

## 3. Steps That Are Wrong, Ambiguous, Out of Order, or Missing a STOP

1. **Section 4 (`3086316:docs/runbooks/twoarm-build-d.md:85-88`) — Ambiguous / unsafe layer-count source (pipshed vs Trade tab) and missing post-reload check for a stranded `|7|ENT` order:**
   - **What it says:** `reload a chart only when BOTH its sides hold 6 layers or fewer, read on pipshed's D books table (or the Trade tab count of GRIND|OPT|L| and |S| on that symbol) just before.`
   - **Why it is unsafe:** Pipshed's D books table is up to 60 seconds stale (`TelemetryIntervalSec=60`). Worse, if a side is at 6 layers when read on pipshed and fills its 7th layer (`|6|ENT` fills and `Grind_TryPlaceAddAtFill` places `|7|ENT`) before OK is clicked, `OnInit` at `cap 7` **does not halt on `I7`** (`7 <= 7` passes `I7_LONG_DEPTH` / `I7_SHORT_DEPTH` at `3086316:ea/grind_recon.mqh:489-495`) and `Grind_EnsureAddNext` (`3086316:ea/grind_engine.mqh:2495-2528`) leaves `GRIND|OPT|...|7|ENT` resting on the broker with `BAD 0`.
   - **Fix / Missing STOP:** Require reading the layer count from the **MT5 Trade tab** immediately before pressing F7, and add a **STOP** after clicking OK: check the Trade tab for that symbol and **STOP if side depth is `7` or if a `GRIND|OPT|L|7|ENT` or `GRIND|OPT|S|7|ENT` pending order exists** (if so, reload `<pair>_opt_d_r3.set` immediately).

2. **Section 4 (`3086316:docs/runbooks/twoarm-build-d.md:87-88`) — Wrong / ambiguous fallback instruction when flattening an OPT chart at 7–8 layers:**
   - **What it says:** `A side at 7 or 8: wait (layers come off as scalps fill), or flatten that chart as s3 steps 2-5 with the EA removed, then attach it fresh as s5.`
   - **Why it is wrong/ambiguous:**
     1. In `s3`, step 5 closes the chart window (`Close the chart window`), and `s5` loads `<pair>_alt_d_t1.set` and expects `replay=ready(0)` and `rebuild=false/false`.
     2. For a flattened **OPT** chart, you should **not** close the chart window (`s3` step 5 is unnecessary), you must load `<pair>_opt_d_t1.set` (not `_alt_d_t1.set`), and `mon_logcheck.awk` will output `replay=ready(N)` (`N > 0` from prior OPT deals) and `rebuild=true/true` for `EURUSD`, `EURGBP`, `AUDCAD`, `AUDCHF`, `CADCHF` (because `GRIND_GEO_EXIT_22260[2-6]01_L/_S` still hold the `r3` exit values in terminal GVs until `OnInit` overwrites them at `3086316:ea/fxgrind.mq5:290`), **not** `s5`'s `replay=ready(0)` and `rebuild=false/false`.

3. **Section 3 (`3086316:docs/runbooks/twoarm-build-d.md:73-75`) — Missing STOP between removing the EA (step 1) and deleting resting orders (step 2):**
   - **What it says:**
     `1. On its chart: right-click -> Expert List -> select fxgrind -> Remove (logs deinit reason=1).`
     `2. In the Trade tab, sort by Symbol: Delete its resting orders (GRIND|OPT|...|ENT and GRIND|OPT|...|EXT).`
   - **Missing STOP:** Confirm `fxgrind deinit reason=1` in the Experts tab (or that the EA hat icon is gone from the chart's top-right corner) **before** deleting any `EXT` or `ENT` orders in step 2; otherwise a still-attached EA can fire `Grind_EnsureExitOrders` / `Grind_EnsureAddNext` on tick while you are deleting orders.

4. **Section 5 (`3086316:docs/runbooks/twoarm-build-d.md:109-112`) — Ambiguous `POST ok` check on shared symbols and `from=HH:MM:00` overlap with Step 4:**
   - **What it says:** `3. Run the s4 step 3 log check with from=HH:MM:00. Expect: deinit=-, replay=ready(0), lattice=true, reroll=true, the ALT geo= from s0, rebuild=false/false, BAD 0, and two L0 limit orders (GRIND|ALT|L|0|ENT and GRIND|ALT|S|0|ENT) in the Trade tab at mid -/+ width. Wait up to 60s and re-run to confirm a POST ok.`
   - **Why it is ambiguous:**
     1. `/root/mon_logcheck.awk` keys `post[src]` by **symbol** (`GBPUSD`, `EURUSD`, etc., `3086316:docs/runbooks/monday-night-2026-10-05.md:29, 31, 50`). Because `<PAIR> OPT` is already running on `<PAIR>` during Step 5, `POST-ok lines per symbol since FROM: <PAIR>=1` can be produced by `<PAIR> OPT`'s 60s heartbeat even if `<PAIR> ALT` dropped its POST.
     2. Neither `/root/mon_logcheck.awk` nor `scripts/build_logcheck.awk` matches `grind telemetry dropped` (`3086316:ea/grind_telemetry.mqh:96, 99`) in `BAD`.
     3. If `from=HH:MM:00` is not advanced to a minute after Step 4's OPT reloads, `mon_logcheck.awk` will show both the Step 4 OPT row and the Step 5 ALT row for that symbol.
   - **Fix:** State explicitly in `s5` step 3 to set `from=HH:MM:00` to the current UTC minute **before** attaching the ALT chart, and verify in the log (or via `grep -F "telemetry dropped" "$LOG"`) that no `grind telemetry dropped` line appeared and that `HEARTBEAT GRIND_<PAIR>_ALTD` was followed by `grind telemetry POST ok`.

5. **Section 8 (`3086316:docs/runbooks/twoarm-build-d.md:126-131`) — Missing STOP conditions:**
   - Add to the Section 8 STOP list:
     - Any resting `GRIND|OPT|L|7|ENT` or `GRIND|OPT|S|7|ENT` order (or side depth `>= 7`) on a reloaded OPT chart in the Trade tab.
     - Any `grind telemetry dropped` line in the MQL5 log (`$D/Logs/$(date -u +%Y%m%d).log`).
     - Any `API_LIMITS_INVALID`, `API_LIMITS_MISMATCH`, or `WARN_API_ENTRY_STOP` line in the MQL5 log (checked by `3086316:scripts/build_logcheck.awk:12` and `3086316:docs/runbooks/wednesday-build-2026-10-07.md:133`).
