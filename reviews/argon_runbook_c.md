# Review of `docs/runbooks/twoarm-build-c.md` at `main` `3860a17`

Reviewed at commit `3860a170fabd6e6c64305a34d8c725be8bc7b11b` (`3860a17`) against:
- `docs/runbooks/twoarm-build-c.md`
- `docs/runbooks/twoarm-build-d.md` (including s10)
- `docs/runbooks/cap10-reload.md` (s4.3-s4.4)
- `ea/fxgrind.mq5`
- `ea/grind_engine.mqh`
- `ea/grind_recon.mqh`
- `ea/grind_pure.mqh`
- `ea/grind_replay.mqh`
- `ea/grind_carry.mqh`
- `ea/grind_cap.mqh`
- `ea/grind_exitq.mqh`
- `ea/grind_closeby.mqh`
- `ea/grind_magic_lock.mqh`
- `ea/grind_config.mqh`
- `ea/presets_c/*_t1.set` and `ea/presets_c/*_r3.set`
- `scripts/build_logcheck.awk`

---

## 1. Answers to `GC-1`..`GC-7` (`docs/runbooks/twoarm-build-c.md:184-204`)

### GC-1 (`docs/runbooks/twoarm-build-c.md:186-188`)

> `186: - **GC-1.** EURUSD and AUDCAD OPT by Remove-then-Attach from the Experts copy (fixes C88), not F7 + Load`
> `187:   (keeps the Scripts `.ex5`). Is the gap safe with a live book: what does start-up do with a fill, an exit`
> `188:   fill or an add fill that happened while no EA was attached (replay seed, deal history)?`

**Verdict:** Book reconstruction and order repair across the detached window are **safe** (no `I3` or `I6` halt on `OnInit`, missing exits are placed by `Grind_RetryMissingExits`, and filled exits are queued for `CloseBy` by `Grind_DeriveCloseByQueueFromBook`), **with two concrete caveats** that the operator and runbook must account for:
1. **Deal history / replay seed skips deals that executed during the detached gap:** `Grind_ReplayInit` marks all deals in `[init - 120s, init + 3600s]` as already seen, so an entry fill (`|L00|ENT` or `|Lnn|ENT`) or the `DEAL_ENTRY_IN` half of an exit fill (`|Lnn|EXT`) during the detached window does **not** run through `Grind_ProcessDeal` / `Grind_ArchiveRecordFill` (no `fill_log` row for that `IN` deal; for an exit fill, the `DEAL_ENTRY_OUT_BY` `CloseBy` deal still runs live after attach and records the scalp close).
2. **An entry (`L0` or `add`) fill during the detached gap emits `WARN STARTUP_EXIT_SHORTFALL`, which `scripts/build_logcheck.awk` flags as a `BAD` line:** `Grind_RetryMissingExits` immediately places the missing `|Lnn|EXT` order in `OnInit`, but `scripts/build_logcheck.awk:12` matches `STARTUP_EXIT_SHORTFALL`, so `BAD lines:` will be `1` (not `0`) even though the exit was repaired.

#### Exact Source Trace

1. **Replay seed and deal history across the Remove-to-Attach gap (`ea/fxgrind.mq5:265`, `ea/grind_replay.mqh:7-8, 149-184, 203-223`, `ea/grind_engine.mqh:3325-3345`):**
   - `ea/fxgrind.mq5:265`:
     ```mql5
     Grind_ReplayInit(InpMagic, GetTickCount64());
     ```
   - `ea/grind_replay.mqh:7-8`:
     ```mql5
     #define GRIND_REPLAY_MARGIN_S 120
     #define GRIND_REPLAY_TO_AHEAD_S 3600
     ```
   - `ea/grind_replay.mqh:149-184`:
     ```mql5
     void Grind_ReplayInit(const ulong magic, const ulong now_ms)
     {
        ArrayResize(g_grind_replay_seen, 0);
        g_grind_replay_init_time = Grind_HistNow();
        g_grind_replay_last_sweep_time = g_grind_replay_init_time;
        g_grind_replay_last_sweep_ms = now_ms;
        g_grind_replay_ready = false;
        g_grind_replay_seeded_count = 0;

        if(g_grind_replay_init_time <= 0) {
           Print("WARN GRIND_REPLAY init deferred: TimeCurrent unavailable");
           return;
        }

        const datetime init = g_grind_replay_init_time;
        if(!Grind_HistSelect(init - GRIND_REPLAY_MARGIN_S, init + GRIND_REPLAY_TO_AHEAD_S)) {
           Print("WARN GRIND_REPLAY init deferred: HistorySelect failed");
           return;
        }
        const int total = Grind_HistDealsTotal();
        int seeded = 0;
        for(int i = 0; i < total; i++) {
           const ulong t = Grind_HistDealGetTicket(i);
           if(t == 0) continue;
           if(Grind_HistDealGetSymbol(t) != _Symbol) continue;
           if(!Grind_MagicMatches(Grind_HistDealGetMagic(t), magic)) continue;
           const long msc = Grind_HistDealGetTimeMsc(t);
           if(!Grind_ReplayIsSeen(t)) {
              Grind_ReplayMarkSeen(t, msc);
              seeded++;
           }
        }
        g_grind_replay_ready = true;
        g_grind_replay_seeded_count = seeded;
        Print("GRIND_REPLAY ready seeded=", seeded);
     }
     ```
   - `ea/grind_replay.mqh:203-223`:
     ```mql5
     const datetime from = Grind_ReplayWindowFrom(g_grind_replay_init_time,
                                                  g_grind_replay_last_sweep_time,
                                                  GRIND_REPLAY_MARGIN_S);
     const datetime now = Grind_HistNow();
     if(now <= 0) return 0;
     if(!Grind_HistSelect(from, now + GRIND_REPLAY_TO_AHEAD_S))
        return 0;

     Grind_ReplayCandidate cands[];
     int cand_n = 0;
     const int total = Grind_HistDealsTotal();
     for(int i = 0; i < total; i++) {
        const ulong t = Grind_HistDealGetTicket(i);
        if(t == 0) continue;
        if(Grind_HistDealGetSymbol(t) != _Symbol) continue;
        if(!Grind_MagicMatches(Grind_HistDealGetMagic(t), magic)) continue;
        if(Grind_ReplayIsSeen(t)) continue;
     ```
   - Because any deal during the detached gap has `deal_time <= g_grind_replay_init_time`, `Grind_ReplayInit` seeds its ticket into `g_grind_replay_seen` (`ea/grind_replay.mqh:177`), and `Grind_ReplaySweep` skips it at `if(Grind_ReplayIsSeen(t)) continue;` (`ea/grind_replay.mqh:222`). Thus `Grind_ProcessDeal` (`ea/grind_engine.mqh:3325-3357`) and `Grind_ArchiveRecordFill` (`ea/grind_engine.mqh:3262-3322`, called at `:3344`) do not run for a deal executed while no EA was attached.

2. **What start-up does with an `L0` (`|L00|ENT`) or `add` (`|Lnn|ENT`) fill during the detached gap:**
   - The broker filled the pending `ENT` order into an open position (`GRIND|OPT|<L/S>|L<nn>|ENT`), and no EA was attached to place its `|Lnn|EXT` order.
   - `Grind_ReconstructState()` (`ea/grind_recon.mqh:1409-1421`) passes `tolerate_exit_shortfall = true`:
     ```mql5
     const bool ok = Grind_RebuildBookFromTickets(tickets, n,
                                                  g_grind_recon_magic, g_grind_recon_slot,
                                                  g_grind_recon_exit_pips,
                                                  Grind_SidePips(false, g_grind_recon_exit_pips,
                                                                 g_grind_recon_exit_pips_short),
                                                  g_grind_recon_max_layers, g_grind_recon_lots,
                                                  g_grind_recon_point,
                                                  g_grind_long, g_grind_short,
                                                  reason, detail,
                                                  true,
                                                  g_grind_rebuild_long,
                                                  g_grind_rebuild_short);
     ```
   - `Grind_RebuildBookFromTicketsInner` (`ea/grind_recon.mqh:1100-1105, 1121-1126`) records the missing exit in `g_grind_recon_exit_shortfall_long` / `g_grind_recon_exit_shortfall_short` instead of halting on `I3_LONG_NAKED` / `I3_SHORT_NAKED` (`ea/grind_recon.mqh:521-524, 552-555`), and computes `exit_target` at the new `exit_pips` (`ea/grind_recon.mqh:1170-1172, 1186-1188`):
     ```mql5
     if(Grind_ExitQRequired(i, long_count, GRIND_EXITQ_K)
        && !Grind_ReconLayerHasExitCoverage(long_scratch[i])) {
        if(tolerate_exit_shortfall)
           g_grind_recon_exit_shortfall_long++;
     }
     ```
   - In `OnInit` (`ea/fxgrind.mq5:271-282`), `Grind_RetryMissingExits` immediately places the missing `|Lnn|EXT` order at the new exit distance (`7` on EURUSD, `6` on AUDCAD):
     ```mql5
     const int a = g_grind_recon_exit_shortfall_long;
     const int b = g_grind_recon_exit_shortfall_short;
     if(a + b > 0) {
        Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);
        Grind_ArchiveMarker("WARN", "STARTUP_EXIT_SHORTFALL", "", 0,
                            StringFormat("{\"long\":%d,\"short\":%d}", a, b));
        if(Grind_StartupShortfallCritical(a, b))
           Grind_TelemetryCritical(g_grind_telemetry_instance,
                                   "STARTUP_EXIT_SHORTFALL_SIDE",
                                   StringFormat("long=%d short=%d", a, b));
     }
     Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
     ```
   - Then on the first tick (`ea/grind_engine.mqh:3219-3237`), `Grind_EnsureAddNext` sees `side.add_pending_ticket == 0` and places the next `|L(nn+1)|ENT` at the new `add_pips` (if `depth < max_layers`).
   - Because at most one `ENT` order per side was resting when the old EA was removed, `a <= 1` and `b <= 1`, so `Grind_StartupShortfallCritical(a, b)` (`return (long_n >= 2 || short_n >= 2);` at `ea/grind_pure.mqh:283-286`) is `false`. However, `Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);` (`ea/fxgrind.mq5:274`) matches `scripts/build_logcheck.awk:12` (see Section 2, Finding 2 below).

3. **What start-up does with an exit (`|Lnn|EXT`) fill during the detached gap:**
   - On the hedging account (`53071896`), a filled `|Lnn|EXT` limit order opens an opposite-direction position (`GRIND|OPT|<L/S>|L<nn>|EXT`) while the layer's `ENT` position remains open (`has_position = true`, `has_exit_position = true`).
   - In `Grind_ReconCheckInvariants` (`ea/grind_recon.mqh:531-544` for long, `:562-575` for short):
     ```mql5
     const double long_shift = Grind_CarryShiftGetForRecon(long_layers[i].position_id);
     const bool long_exit_filled = long_layers[i].has_exit_position;
     if(!Grind_ReconExitMatchesEntry(long_layers[i].entry_price,
                                    long_layers[i].exit_target,
                                    exit_pips, point, true, long_shift,
                                    long_exit_filled, long_layers[i].position_id)) {
        if(tolerate_exit_price_long && !long_exit_filled)
           continue;
        const string i6_reason = long_exit_filled ? "I6_LONG_EXIT_FILL_ADVERSE" : "I6_LONG_EXIT";
        return Grind_InvariantFail(reason_out, i6_reason,
                                   Grind_InvariantDetailI6(long_layers[i], true, exit_pips, point,
                                                           long_shift),
                                   long_layers[i].position_id);
     }
     ```
   - Notice that `if(tolerate_exit_price_long && !long_exit_filled) continue;` (`ea/grind_recon.mqh:537-538, 568-569`) does **not** bypass `Grind_ReconExitMatchesEntry` when `long_exit_filled` is `true`. Instead, `Grind_ReconExitMatchesEntry` (`ea/grind_recon.mqh:385-395`) checks:
     ```mql5
     const double eff = Grind_EffectiveEntry(entry, position_id);
     const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;
     const double diff = exit_target - expected;
     if(exit_is_filled) {
        if(is_long && diff >= 0.0)
           return true;
        if(!is_long && diff <= 0.0)
           return true;
     }
     ```
   - Because C's OPT exit distance **decreases** (`10 -> 7` on EURUSD OPT, `10 -> 6` on AUDCAD OPT), an `EXT` order that filled during the detached gap at the old `10`-pip target has `diff = +3` pips (`>= 0.0`) on long and `diff = -3` pips (`<= 0.0`) on short (or `+4` / `-4` pips on AUDCAD), so `Grind_ReconExitMatchesEntry` returns **`true`**.
   - `Grind_ReconstructState()` then calls `Grind_DeriveCloseByQueueFromBook(g_grind_recon_slot, g_grind_recon_verbose);` (`ea/grind_recon.mqh:1433`, defined at `ea/grind_closeby.mqh:278-315`), which enqueues the `(ent_ticket, ext_ticket)` pair and logs `RECON_DERIVED_CLOSEBY`.
   - `Grind_RebuildExitsAtStartSide` (`ea/grind_engine.mqh:3088-3089`) skips any layer with `side.layers[i].exit_position_ticket != 0`.
   - On the first `OnTick` (`ea/fxgrind.mq5:440`), `Grind_ProcessCloseByQueues` (`ea/grind_closeby.mqh:221-275`) sends `TRADE_ACTION_CLOSE_BY` (`:240`). The resulting `DEAL_ENTRY_OUT_BY` deal arrives while the EA is attached and is processed normally by `Grind_HandleSideDealFill` (`ea/grind_engine.mqh:2886-2944`), which records the scalp P&L, queues `scalp_closed`, removes the layer, and promotes the exit queue (`Grind_ExitQManageSide`, `:2941`). If that closed layer was the deepest layer (`L(k-1)`), on the next tick `Grind_EnsureAddNext` (`ea/grind_engine.mqh:2503-2520`) sees `parsed_layer != required_index`, cancels the stale `|L0k|ENT` add order (`:2518`), and places `|L0(k-1)|ENT` on the following tick.

---

### GC-2 (`docs/runbooks/twoarm-build-c.md:189-190`)

> `189: - **GC-2.** Does the re-attach read the old exit label exactly as an F7 reload does (`rebuild=true`), or`
> `190:   does `OnDeinit` reason 1 (`fxgrind.mq5` 396-405) or the attach clear it?`

**Verdict:** **Confirmed.** Neither `OnDeinit(1)` nor the attach clears `GRIND_GEO_EXIT_<magic>_L` or `GRIND_GEO_EXIT_<magic>_S` (nor any `GRIND_VL_*`, `GRIND_CARRY_ACCRUED_*`, `GRIND_CARRY_SHIFT_*`, or `GRIND_EJECT_OFFSET_*` Global Variable). The re-attach reads the old `10.0` exit label and sets `rebuild=true/true` identically to an `F7 + Load` reload (`deinit=1` instead of `deinit=5`).

#### Exact Source Trace

- `ea/fxgrind.mq5:396-405`:
  ```mql5
  void OnDeinit(const int reason)
  {
     Grind_ArchiveRecordDeinit(InpMagic, reason, TimeCurrent(), g_grind_archive_anchor_ms);

     GlobalVariablesFlush();
     EventKillTimer();
     Grind_MagicLockRelease(InpMagic);
     if(InpVerboseLog)
        Print("fxgrind deinit reason=", reason);
  }
  ```
- `Grind_ArchiveRecordDeinit` (`ea/grind_archive.mqh:568-576`) only writes `GRIND_DEINIT_REASON_<magic>`, `GRIND_DEINIT_TIME_<magic>`, and `GRIND_DEINIT_ANCHOR_<magic>`. `Grind_MagicLockRelease` (`ea/grind_magic_lock.mqh:18-23`) only deletes `GRIND2226_MAGIC_LOCK_<magic>`.
- On attach, `Grind_ReconstructState()` (`ea/grind_recon.mqh:1404-1407`) calls `Grind_GeoExitChanged` (`ea/grind_carry.mqh:635-641`):
  ```mql5
  g_grind_rebuild_long = Grind_GeoExitChanged(g_grind_recon_magic, true, g_grind_recon_exit_pips);
  g_grind_rebuild_short = Grind_GeoExitChanged(g_grind_recon_magic, false,
                                               Grind_SidePips(false, g_grind_recon_exit_pips,
                                                              g_grind_recon_exit_pips_short));
  ```
  ```mql5
  bool Grind_GeoExitChanged(const ulong magic, const bool is_long, const double current_exit_pips)
  {
     double stored = 0.0;
     if(!Grind_GeoExitGet(magic, is_long, stored))
        return false;
     return (MathAbs(stored - current_exit_pips) > 1e-6);
  }
  ```
- Because `GRIND_GEO_EXIT_22260201_L/_S` and `GRIND_GEO_EXIT_22260401_L/_S` still hold `10.0` from before `Remove`, `Grind_GeoExitChanged` returns `true` for both sides (`rebuild=true/true`), `Grind_RebuildExitsAtStart(InpMagic)` (`ea/fxgrind.mq5:283`) reprices the resting exits to `7.0` (EURUSD) and `6.0` (AUDCAD), and `Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short)` (`ea/fxgrind.mq5:290`) then updates the GVs to `7.0` / `6.0`.

---

### GC-3 (`docs/runbooks/twoarm-build-c.md:191-193`)

> `191: - **GC-3.** The add change with layers held (s0): Claude reads the resting add re-priced at the first`
> `192:   grid step (`fxgrind.mq5` 289-292, `grind_engine.mqh` 2560-2571 and 3234-3237), and reconstruction`
> `193:   adopting the resting `|Lnn|ENT` as `add_pending_ticket` (`grind_recon.mqh` 1079-1086), so no second add`
> `194:   is sent. Confirm.`

**Verdict:** **Confirmed.** Reconstruction adopts the existing resting `|Lnn|ENT` (`nn >= 1`) into `side.add_pending_ticket` without price validation; `OnInit` sets `g_grind_start_add_reprice_long = true` and `g_grind_start_add_reprice_short = true`; and on the first grid step `Grind_EnsureAddNext` uses the one-shot `0.05`-pip deadband (`< 1.0` pip, whereas normal `InpDeadbandPips=2.0` would suppress a `1.0`-pip move) to modify `side.add_pending_ticket` in place (`Grind_ModifyPendingPrice`) and `return` before `Grind_SendNextAddEnt`. No second add is sent.

#### Exact Source Trace

1. **Adoption into `add_pending_ticket` (`ea/grind_recon.mqh:1055-1089`):**
   ```mql5
   if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_ORDER) {
      if(c_side == "L") {
         if(c_layer == 0) {
            if(long_out.l0_pending_ticket != 0) {
               return Grind_InvariantFail(reason_out, "AMBIGUOUS_DUPLICATE_L0_LONG",
                                          StringFormat("tickets=%I64u,%I64u",
                                                       long_out.l0_pending_ticket, tickets[i].ticket));
            }
            long_out.l0_pending_ticket = tickets[i].ticket;
         }
         else {
            if(long_out.add_pending_ticket != 0) {
               return Grind_InvariantFail(reason_out, "AMBIGUOUS_DUPLICATE_ADD_LONG",
                                          StringFormat("tickets=%I64u,%I64u",
                                                       long_out.add_pending_ticket, tickets[i].ticket));
            }
            long_out.add_pending_ticket = tickets[i].ticket;
         }
      }
      else {
         if(c_layer == 0) {
            if(short_out.l0_pending_ticket != 0) {
               return Grind_InvariantFail(reason_out, "AMBIGUOUS_DUPLICATE_L0_SHORT",
                                          StringFormat("tickets=%I64u,%I64u",
                                                       short_out.l0_pending_ticket, tickets[i].ticket));
            }
            short_out.l0_pending_ticket = tickets[i].ticket;
         }
         else {
            if(short_out.add_pending_ticket != 0) {
               return Grind_InvariantFail(reason_out, "AMBIGUOUS_DUPLICATE_ADD_SHORT",
                                          StringFormat("tickets=%I64u,%I64u",
                                                       short_out.add_pending_ticket, tickets[i].ticket));
            }
            short_out.add_pending_ticket = tickets[i].ticket;
         }
      }
      continue;
   }
   ```
2. **One-shot add reprice armed in `OnInit` (`ea/fxgrind.mq5:289-293`):**
   ```mql5
   else {
      Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short);
      g_grind_start_add_reprice_long = true;
      g_grind_start_add_reprice_short = true;
   }
   ```
3. **Modify-in-place with `0.05`-pip deadband and early `return` on the first grid step (`ea/grind_engine.mqh:2560-2574, 3234-3237`):**
   - `ea/grind_engine.mqh:3234-3237`:
     ```mql5
     if(Grind_SideDepth(g_grind_long) > 0 || g_grind_long.add_pending_ticket != 0)
        Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips_long, max_layers, lots, deadband_pips);
     if(Grind_SideDepth(g_grind_short) > 0 || g_grind_short.add_pending_ticket != 0)
        Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_pips_short, max_layers, lots, deadband_pips);
     ```
   - `ea/grind_engine.mqh:2560-2574`:
     ```mql5
     // One-shot startup re-price uses 0.05-pip deadband so add-distance changes apply immediately.
     const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;
     if(is_long)
        g_grind_start_add_reprice_long = false;
     else
        g_grind_start_add_reprice_short = false;
     const double add_deadband = one_shot ? 0.05 : deadband_pips;

     if(side.add_pending_ticket != 0) {
        const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
        if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))
           return;
        Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
        return;
     }
     ```
   - **Minor edge case in `ea/grind_engine.mqh:2562-2572`:** `g_grind_start_add_reprice_long` / `_short` is cleared to `false` at lines `2562-2565` before `Grind_ModifyPendingPrice` at line `2572`. If `Grind_ModifyPendingPrice` were rejected by the broker on that single tick, subsequent ticks would use `add_deadband = deadband_pips` (`2.0` pips), which is wider than the `1.0`-pip add change (`6 -> 7` on EURUSD, `5 -> 6` on AUDCAD) and would leave the resting add at its old price until filled.

---

### GC-4 (`docs/runbooks/twoarm-build-c.md:194-195`)

> `194: - **GC-4.** Compiling the Experts copy while nine charts run the Scripts copy (s2.6): can it re-init any`
> `195:   chart, touch the Scripts `.ex5`, or change a running chart's `ea_build`?`

**Verdict:** **No** on all three counts, provided all nine running charts are attached from `MQL5\Scripts\fxmatrix\fxgrind.ex5` (which `s2.6`'s `inits=0` check immediately verifies):
1. Compiling `MQL5\Experts\fxmatrix\fxgrind.mq5` in MetaEditor writes only `MQL5\Experts\fxmatrix\fxgrind.ex5`; it does not touch `MQL5\Scripts\fxmatrix\fxgrind.ex5` (verified by `s2.5` / `s2.6` comparing `ls -l --time-style=+%Y-%m-%dT%H:%M:%S "$M/Experts/fxmatrix/fxgrind.ex5" "$M/Scripts/fxmatrix/fxgrind.ex5"`, `docs/runbooks/twoarm-build-c.md:84, 89`).
2. As documented in `docs/runbooks/cap10-reload.md:121-124` (`s4.3`), MT5 binds each chart to the `.ex5` path from which it was attached (`Scripts\fxmatrix\fxgrind.ex5`, C88), so overwriting `Experts\fxmatrix\fxgrind.ex5` does not trigger `REASON_RECOMPILE` (`deinit=2`) on any chart running the Scripts copy:
   ```121:124:docs/runbooks/cap10-reload.md
   **On wine-c ONLY (C88):** the charts load `MQL5\Scripts\fxmatrix\fxgrind.ex5` (not `Experts`). In
   MetaEditor's Navigator expand **`Scripts -> fxmatrix`**, double-click **`fxgrind.mq5`** there, **F7** (0
   errors, 0 warnings). Compiling the `Experts` copy on wine-c does nothing to the running charts.
   ```
3. `GRIND_EA_BUILD` is a compile-time macro (`ea/fxgrind.mq5:56`) emitted only inside `OnInit` (`ea/fxgrind.mq5:329-330, 344-345`):
   ```56:56:ea/fxgrind.mq5
   #define GRIND_EA_BUILD ("fxgrind " + TimeToString(__DATETIME__, TIME_DATE|TIME_SECONDS))
   ```
   ```344:346:ea/fxgrind.mq5
   string init_cfg = Grind_ArchiveConfigFields(
      "INIT", GRIND_EA_BUILD,
      g_geo_width_long, g_geo_width_short,
   ```
   A chart that does not re-run `OnInit` on the newly compiled `.ex5` cannot change its `ea_build`.

---

### GC-5 (`docs/runbooks/twoarm-build-c.md:196-198`)

> `196: - **GC-5.** GBPCHF's magics outside `GRIND_CAP_ALL_MAGICS` (C159): any use of that table other than the`
> `197:   currency cap and the slot guard (`Grind_IsFleetMagic`) that matters for a magic outside it (orphan or`
> `198:   ownership checks, replay, the archive)?`

**Verdict:** **None.** Across all `.mq5` and `.mqh` files at `3860a17`, `GRIND_CAP_ALL_MAGICS` and `GRIND_CAP_MAGIC_COUNT` (`ea/grind_cap.mqh:18-31`) have **no** production call sites outside the currency-cap exposure sum (`Grind_CapSumLegExposure`) and the slot guard's resting-entry count (`Grind_IsFleetMagic` -> `Grind_SlotRestingEnt`).

#### Exhaustive Call-Site Audit of `GRIND_CAP_ALL_MAGICS`, `GRIND_CAP_MAGIC_COUNT`, and `Grind_IsFleetMagic`

1. **Definition (`ea/grind_cap.mqh:18-31`):**
   ```mql5
   const ulong GRIND_CAP_ALL_MAGICS[18] =
   {
      22260101UL, 22260201UL, 22260301UL, 22260401UL,
      22260501UL, 22260601UL, 22260801UL, 22260901UL,
      22260102UL, 22260202UL, 22260302UL, 22260402UL,
      22260502UL, 22260602UL, 22260802UL, 22260902UL,
      22260701UL, 22260702UL
   };

   #define GRIND_CAP_MAGIC_COUNT 18
   ```
2. **Currency cap (`ea/grind_cap.mqh:61-67, 236-264, 267-281`):**
   - `Grind_CapMagicCarriesLeg` (`ea/grind_cap.mqh:61-67`) and `Grind_CapSumLegExposure` (`ea/grind_cap.mqh:236-264`) iterate `GRIND_CAP_ALL_MAGICS`.
   - `Grind_CapAllowsEntry` (`ea/grind_cap.mqh:278-281`) short-circuits when both thresholds are `0.0`:
     ```mql5
     bool Grind_CapAllowsEntry(const string symbol, const ulong own_magic)
     {
        if(!Grind_CapThresholdEnabled())
           return true;
     ```
   - All six C presets set `InpCapLegAThresh=0.0` and `InpCapLegBThresh=0.0` (`ea/presets_c/*_t1.set:33-34`), so `Grind_CapAllowsEntry` always returns `true`. (`Grind_CapPublishOwnExposure` at `ea/grind_cap.mqh:206-233` writes `GRIND2226_<magic>_<leg>` directly from `InpMagic`, `InpCapLegA`, `InpCapLegB` without consulting `GRIND_CAP_ALL_MAGICS`.)
3. **Slot guard (`ea/grind_exitq.mqh:105-112, 125-184`):**
   ```mql5
   bool Grind_IsFleetMagic(const long magic)
   {
      for(int i = 0; i < GRIND_CAP_MAGIC_COUNT; i++) {
         if((long)GRIND_CAP_ALL_MAGICS[i] == magic)
            return true;
      }
      return false;
   }
   ```
   ```mql5
   int Grind_SlotUsed()
   {
      int p = PositionsTotal();
      int o = OrdersTotal();
      if(p < 0) p = 0;
      if(o < 0) o = 0;
      return p + o;
   }

   int Grind_SlotRestingEnt()
   {
      const int total = OrdersTotal();
      if(total <= 0)
         return 0;
      int count = 0;
      for(int i = 0; i < total; i++) {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         const long magic = OrderGetInteger(ORDER_MAGIC);
         if(!Grind_IsFleetMagic(magic))
            continue;
   ```
   `Grind_SlotUsed()` (`PositionsTotal() + OrdersTotal()`) counts all GBPCHF positions and orders; only `Grind_SlotRestingEnt()` skips `22261001` and `22261002` (at most 4 resting `ENT` orders across GBPCHF OPT + ALT).
4. **Test-only helpers (`ea/grind_magic_lock.mqh:26-31`, `ea/grind_engine.mqh:140-156`):**
   - `Grind_MagicLockReleaseAllKnown()` (`ea/grind_magic_lock.mqh:26-31`) and `Grind_OrderTestRestingEntFleetCount()` (`ea/grind_engine.mqh:140-156`) are only called in `ea/fxgrind_tests.mq5`. Production magic locking uses `Grind_MagicLockClaim(InpMagic)` (`ea/fxgrind.mq5:228`, `ea/grind_magic_lock.mqh:40-49`) and `Grind_MagicLockRelease(InpMagic)` (`ea/fxgrind.mq5:402`, `ea/grind_magic_lock.mqh:18-23`), keyed directly off `InpMagic`.
5. **Orphan / ownership checks, reconciliation, replay, carry, MAE, and archive:**
   - Reconciliation and orphan checks (`ea/grind_recon.mqh:908, 1328-1331, 1344-1347`), replay (`ea/grind_replay.mqh:174, 220, 413`), deal handling (`ea/grind_engine.mqh:2874, 3271, 3342`), carry (`ea/grind_carry.mqh:983, 1331-1332`), and archive (`ea/fxgrind.mq5:257`, `ea/grind_archive.mqh:561-566`) all filter by the chart's own `InpMagic` via `Grind_MagicMatches` (`ea/grind_pure.mqh:174-177`).

---

### GC-6 (`docs/runbooks/twoarm-build-c.md:200-201`)

> `200: - **GC-6.** GBPCHF ALT at 24 / width 6 from the daily range (no fills on IC): any start-up check that`
> `201:   fails on a new symbol with no history (spread sampling, deal history, the carry pass)?`

**Verdict:** **No start-up check fails** on `GBPCHF` (`OPT` at `2.5/9/9` or `ALT` at `6.0/24/24`) when `GBPCHF` is shown in Market Watch before attaching (`s5`, `docs/runbooks/twoarm-build-c.md:148-149`):
1. **ADR-153 add/width ratio guard (`ea/fxgrind.mq5:175-184`, `ea/grind_pure.mqh:14-15, 41-52`):**
   - `ea/grind_pure.mqh:14-15, 41-52`:
     ```mql5
     #define GRIND_ADD_WIDTH_RATIO_MIN 0.5
     #define GRIND_ADD_WIDTH_RATIO_MAX 4.0
     ```
     ```mql5
     bool Grind_ValidateAddWidthRatio(const double width_pips, const double add_pips)
     {
        if(!MathIsValidNumber(width_pips) || !MathIsValidNumber(add_pips))
           return false;
        if(width_pips <= 0.0 || add_pips <= 0.0)
           return false;
        const double r = add_pips / width_pips;
        if(r < GRIND_ADD_WIDTH_RATIO_MIN - 1e-9)
           return false;
        if(r > GRIND_ADD_WIDTH_RATIO_MAX + 1e-9)
           return false;
        return true;
     }
     ```
   - On `gbpchf_alt_c_t1.set` (`InpWidthPips=6.0`, `InpAddPips=24.0`, `ea/presets_c/gbpchf_alt_c_t1.set:3-4`), `r = 24.0 / 6.0 = 4.0`, which is right at the upper boundary `GRIND_ADD_WIDTH_RATIO_MAX = 4.0` (`4.0 <= 4.0 + 1e-9` passes). (On `gbpchf_opt_c_t1.set`, `r = 9.0 / 2.5 = 3.6`, passes.)
2. **Spread / M1 bar sampling (`ea/grind_engine.mqh:628-646`):**
   - `CopyRates(_Symbol, PERIOD_M1, 0, 60, spread_rates)` (`ea/grind_engine.mqh:644`) is only inside `Grind_AutoEjectOnTick`, which is never called in `OnInit` and returns immediately at line `634` (`if(!enabled || blocked) return;`) because `InpAutoEject=false` in all six `_t1` presets (`ea/presets_c/*_t1.set:18`).
3. **Deal history / replay seed (`ea/grind_replay.mqh:149-184`):**
   - `Grind_ReplayInit` uses `Grind_HistNow()` (`TimeCurrent()`, `ea/grind_engine.mqh:2815`, which is terminal-wide server time) and `HistorySelect(init - 120, init + 3600)` (`ea/grind_replay.mqh:164`, which is account-wide). With 0 deals on `GBPCHF`, the loop finds `seeded = 0`, sets `g_grind_replay_ready = true`, and logs `GRIND_REPLAY ready seeded=0` (`ea/grind_replay.mqh:181-183`).
4. **Carry snapshot and nightly carry pass (`ea/fxgrind.mq5:356`, `ea/grind_carry.mqh:1207-1270, 1290-1368`):**
   - `Grind_CarryEmitSnapshot(_Symbol, InpMagic)` (`ea/fxgrind.mq5:356`, `ea/grind_carry.mqh:1290-1368`) reads `SymbolInfoInteger` / `SymbolInfoDouble` on `GBPCHF` (already subscribed once `GBPCHF` is shown in Market Watch in `s5`) and enqueues `CARRY_SNAPSHOT` with `open_layers_long=0` and `open_layers_short=0`; it has no failure return path.
   - At rollover (`23:50-23:59` server), if `GBPCHF` still holds 0 layers, `Grind_CarryExitPassBegin` (`ea/grind_carry.mqh:975-1013`) sets `g_grind_carry_exit_work_count = 0` and `Grind_CarryExitPassStep` (`ea/grind_carry.mqh:1261-1268`) immediately emits `CARRY_PASS_SUMMARY` (`eligible=0, incomplete=false`) once `Grind_CarrySessionReady("GBPCHF")` sees a fresh tick.
5. **First L0 straddle placement on a new chart (`ea/grind_engine.mqh:1995-2012, 2073-2074, 2098-2099, 3193-3222`):**
   - `OnInit` does not place L0 orders; `Grind_OnTickEngine` places them on incoming ticks when `Grind_GuardsAllowTrading` (`ea/grind_engine.mqh:1995-2012`) sees `SYMBOL_TRADE_MODE_FULL` and a tick. Because `g_grind_ent_sent_this_tick` (`ea/grind_engine.mqh:2073-2074, 2098-2099, 3196`) caps new `ENT` sends to one per `OnTick`, the first tick after `OK` places the long L0 (`|L|L00|ENT`) and the second tick places the short L0 (`|S|L00|ENT`).

---

### GC-7 (`docs/runbooks/twoarm-build-c.md:202`)

> `202: - **GC-7.** What failure is not on s7? What fact is missing?`

Answered in Section 2 below (Findings 1 through 6).

---

## 2. Attack on `docs/runbooks/twoarm-build-c.md` at `3860a17`

### Finding 1 — Wrong Source File Citation in `s0` (`docs/runbooks/twoarm-build-c.md:37`)

- **Runbook passage (`docs/runbooks/twoarm-build-c.md:35-38`):**
  ```35:38:docs/runbooks/twoarm-build-c.md
    re-prices every resting exit order at start-up (`Grind_RebuildExitsAtStart`, `fxgrind.mq5` 283-290). A
    layer already past the new target (in profit by 7+ pips on EURUSD or 6+ on AUDCAD) has its exit
    clamped just outside the market (`Grind_ExitQClampPassive`, `grind_engine.mqh` 3116-3134) and fills almost at
    once as a scalp (`CloseBy`).
  ```
- **What is wrong:** `Grind_ExitQClampPassive` is defined in **`ea/grind_exitq.mqh:258-271`**, not in `ea/grind_engine.mqh`. Lines `3116-3134` of `ea/grind_engine.mqh` are the call site inside `Grind_RebuildExitsAtStartSide` (`ea/grind_engine.mqh:3075-3148`), which calls `Grind_ExitQClampPassive` at line `3118`.
- **Exact source (`ea/grind_exitq.mqh:258-271` and `ea/grind_engine.mqh:3116-3134`):**
  ```258:271:ea/grind_exitq.mqh
  double Grind_ExitQClampPassive(const bool is_long,
                                 const double target_price,
                                 const double best_bid_or_ask,
                                 const double point,
                                 const int digits,
                                 bool &clamped_out)
  {
     clamped_out = false;
     if(point <= 0.0 || best_bid_or_ask <= 0.0)
        return NormalizeDouble(target_price, digits);
     if(is_long) {
        const double floor_px = best_bid_or_ask + point;
        if(target_price < floor_px) {
           clamped_out = true;
           return NormalizeDouble(floor_px, digits);
        }
  ```
  ```3116:3134:ea/grind_engine.mqh
        const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);
        bool clamped = false;
        const double price = Grind_ExitQClampPassive(is_long, formula,
                                                     is_long ? best_ask : best_bid,
                                                     _Point, digits, clamped);
        if(price <= 0.0)
           continue;
        if(clamped)
           clamped_n++;
        const double resting = Grind_OrderGetPriceOpen(exit_ticket);
        if(Grind_PriceWithinDeadband(resting, price, GRIND_REBUILD_DEADBAND_PIPS, _Point))
           continue;
        if(Grind_ModifyPendingPrice(exit_ticket, price, magic)) {
           if(clamped)
              Grind_CarryRecordShift(pos, price - formula, true);
           rebuilt++;
           continue;
        }
  ```

---

### Finding 2 — Missing STOP / False-Positive `BAD` Trap in `s4` and `s7`: `STARTUP_EXIT_SHORTFALL`, `REPLAY_INIT_DEFERRED`, `AMBIGUOUS_`, and `WARN_API_ENTRY_STOP` Are Matched as `BAD` by `scripts/build_logcheck.awk:12` but Omitted from `s7` (`docs/runbooks/twoarm-build-c.md:109-111, 131-132, 178-180`)

- **Runbook passages (`docs/runbooks/twoarm-build-c.md:109-111, 131-132, 178-180`):**
  ```109:111:docs/runbooks/twoarm-build-c.md
  10-20 seconds per chart (Remove -> drag from Navigator -> Load -> read back -> OK). The book is unmanaged
  only for those seconds; a fill meanwhile is adopted at reconstruction (precedent 1 Oct 06:32Z, `NZDCAD_OPTD`
  re-attached from Experts, clean).
  ```
  ```131:132:docs/runbooks/twoarm-build-c.md
     Expected for EURUSD: `deinit=1`, `magic=22260201`, `slot=OPT`, `cap=7`, `gate=0`, `geo=2/7/7` (both sides),
     `rebuild=true/true`, `rebuilt=L:1/S:1`, `POST ok`, **`BAD lines: 0`**. Do NOT touch AUDCAD if `BAD != 0`.
  ```
  ```178:180:docs/runbooks/twoarm-build-c.md
  Any of: `cmp` `DIFF` or `MISS`; compile error or warning; `s2.6` `inits != 0` (unless explained); any `BAD`
  line from the checker (`FATAL`, `CRITICAL`, `INVARIANT_FAIL`, `RECON_FAIL`, `REBUILD_EXIT_FAILED`,
  `REBUILD_EXIT_UNREADABLE`, `API_LIMITS_*`, `duplicate magic`); a read-back that does not match s1; `rebuild=`
  ```
- **Exact source (`scripts/build_logcheck.awk:12` and `ea/fxgrind.mq5:271-282`):**
  ```12:12:scripts/build_logcheck.awk
  if ($0 ~ /FATAL|CRITICAL|INVARIANT_FAIL|RECON_FAIL|REBUILD_EXIT_FAILED|REBUILD_EXIT_UNREADABLE|STARTUP_EXIT_SHORTFALL|REPLAY_INIT_DEFERRED|AMBIGUOUS_|duplicate magic|API_LIMITS_INVALID|API_LIMITS_MISMATCH|WARN_API_ENTRY_STOP/) { m = $0; sub(/^.*\t/, "", m); bad[++nb] = t " " src " " m }
  ```
  ```271:282:ea/fxgrind.mq5
     const int a = g_grind_recon_exit_shortfall_long;
     const int b = g_grind_recon_exit_shortfall_short;
     if(a + b > 0) {
        Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);
        Grind_ArchiveMarker("WARN", "STARTUP_EXIT_SHORTFALL", "", 0,
                            StringFormat("{\"long\":%d,\"short\":%d}", a, b));
        if(Grind_StartupShortfallCritical(a, b))
           Grind_TelemetryCritical(g_grind_telemetry_instance,
                                   "STARTUP_EXIT_SHORTFALL_SIDE",
                                   StringFormat("long=%d short=%d", a, b));
     }
     Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
  ```
- **Why this matters in `s4`:**
  1. `s7`'s parenthetical list of `BAD` tokens omits four patterns present in `scripts/build_logcheck.awk:12`: `STARTUP_EXIT_SHORTFALL`, `REPLAY_INIT_DEFERRED`, `AMBIGUOUS_`, and `WARN_API_ENTRY_STOP`.
  2. Specifically in `s4`, because EURUSD OPT and AUDCAD OPT are reloaded by **Remove-then-Attach** (10-20s with no EA attached), if a resting `|L00|ENT` or `|Lnn|ENT` fills during those detached seconds, that new position has no `|Lnn|EXT` order when `OnInit` runs `Grind_ReconstructState()`. `OnInit` prints `WARN STARTUP_EXIT_SHORTFALL long=1 short=0` (or `long=0 short=1`) at `ea/fxgrind.mq5:274` and immediately places the missing `|Lnn|EXT` via `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots)` at `ea/fxgrind.mq5:282`.
  3. Because `scripts/build_logcheck.awk:12` matches `STARTUP_EXIT_SHORTFALL`, the checker in `s4` step 4 will print **`BAD lines: 1`** (`WARN STARTUP_EXIT_SHORTFALL ...`), contradicting `s4` line 110 ("a fill meanwhile is adopted at reconstruction ... clean") and line 132 ("`BAD lines: 0`. Do NOT touch AUDCAD if `BAD != 0`"). The runbook should note that a single-layer `WARN STARTUP_EXIT_SHORTFALL` (`long <= 1`, `short <= 1`, no `WARN: exitq place failed`) after Remove-then-Attach is caused by an entry fill during the detached gap and is repaired at `OnInit` line `282` (confirm the new layer's `|Lnn|EXT` order is resting in the Trade tab).

---

### Finding 3 — Hardcoded `rebuilt=L:1/S:1` in `s4` (`docs/runbooks/twoarm-build-c.md:132`) Is Only True When Both Sides Hold Exactly 1 Layer

- **Runbook passage (`docs/runbooks/twoarm-build-c.md:131-132`):**
  ```131:132:docs/runbooks/twoarm-build-c.md
     Expected for EURUSD: `deinit=1`, `magic=22260201`, `slot=OPT`, `cap=7`, `gate=0`, `geo=2/7/7` (both sides),
     `rebuild=true/true`, `rebuilt=L:1/S:1`, `POST ok`, **`BAD lines: 0`**. Do NOT touch AUDCAD if `BAD != 0`.
  ```
- **What is wrong:** Unlike `docs/runbooks/twoarm-build-d.md:107` (which writes `rebuilt=L:../S:..`), `twoarm-build-c.md:132` hardcodes `rebuilt=L:1/S:1` for EURUSD OPT (and does not state the AUDCAD OPT `rebuilt=` rule at lines `140-141`). Under ADR-151 (`GRIND_EXITQ_K = 1`), `Grind_ExitQRequired` keeps a resting exit order on **both** `rank == 0` (`L00`) and `rank >= depth - 1` (the deepest layer `L(depth-1)`).
- **Exact source (`ea/grind_config.mqh:7`, `ea/grind_exitq.mqh:43-50`, `ea/grind_engine.mqh:3083-3133`):**
  ```7:7:ea/grind_config.mqh
  #define GRIND_EXITQ_K 1
  ```
  ```43:50:ea/grind_exitq.mqh
  bool Grind_ExitQRequired(const int rank, const int depth, const int k)
  {
     if(depth <= 0 || rank < 0 || rank >= depth)
        return false;
     if(rank == 0)
        return true;
     return (rank >= depth - k);
  }
  ```
  ```3083:3090:ea/grind_engine.mqh
     int rebuilt = 0;
     const int n = ArraySize(side.layers);
     for(int i = 0; i < n; i++) {
        if(side.layers[i].position_ticket == 0)
           continue;
        const ulong exit_ticket = side.layers[i].exit_order_ticket;
        if(exit_ticket == 0 || side.layers[i].exit_position_ticket != 0)
           continue;
  ```
- Therefore, on each side of EURUSD OPT (`10 -> 7`) and AUDCAD OPT (`10 -> 6`), `rebuilt` in `rebuilt=L:<a>/S:<b>` is:
  - `0` if that side holds `0` layers at attach;
  - `1` if that side holds `1` layer (`L00` only);
  - `2` if that side holds `2..6` layers (`L00` and `L(depth-1)` both have resting `EXT` orders repriced by `Grind_RebuildExitsAtStartSide`).

---

### Finding 4 — Unsafe Ordering Detail in `s4` Steps 1-3 (`docs/runbooks/twoarm-build-c.md:113-124`): Re-Check the Trade Tab Immediately After Step 2 (`Remove`) Before Step 3 (`Attach`)

- **Runbook passage (`docs/runbooks/twoarm-build-c.md:113-124`):**
  ```113:124:docs/runbooks/twoarm-build-c.md
  1. **Check the Trade tab** for `22260201` (`GRIND|OPT|L|L..|ENT` and `|S|L..|ENT` positions): **both sides must
     hold `<= 6` filled layers** (not `<= 7`). Why `<= 6`: with `InpFillTimePlace=true`, when layer 6 (the 7th,
     `L00..L06`) fills under cap 8, the EA places `|L07|ENT` (the 8th) at once; a cap-7 reload does not cancel a
     resting `|L07|ENT` (`grind_recon.mqh` 1079-1086 adopts it; `Grind_EnsureAddNext` returns at `n >= max_layers`
     before the stale-add cancel, `grind_engine.mqh` 2525), and if it fills later the next start-up halts on
     `I7_*_DEPTH`. At `<= 6` layers the resting add is at most `|L06|ENT`, valid under cap 7. If either side is at
     7 or 8 layers, wait for a scalp to close (on EURUSD `22260201`, skip to AUDCAD first and come back; on
     AUDCAD, wait).
  2. Right-click the EURUSD chart -> Expert Advisors -> **Remove** (`deinit reason=1`; positions and orders stay).
  3. Drag `Experts -> fxmatrix -> fxgrind` onto the EURUSD chart.
     - Common tab: **Allow Algo Trading** ticked.
     - Inputs tab -> **Load** -> `eurusd_opt_c_t1.set` -> **read back against s1 BEFORE OK** (and `TelemetryAPIKey`
       not blank) -> **OK**. Note the UTC time.
  ```
- **Why step 2 (`Remove`) changes the race window compared to D's `F7 + Load`:**
  - While the old cap-8 EA is still attached (between step 1 checking the Trade tab and step 2 clicking `Remove`), if `|L06|ENT` fills, `Grind_TryPlaceAddAtFill` (`ea/grind_engine.mqh:2405-2429`, `2978-2979`) immediately places `|L07|ENT`.
  - Once step 2 (`Remove`) completes, **no EA is attached**, so no new `|L07|ENT` can be placed even if `|L06|ENT` fills during the 10-20s of step 3.
  - However, if `|L06|ENT` filled in the moment *before* `Remove` clicked through, `|L07|ENT` is already resting on the book during step 3's dialog read-back; if `|L07|ENT` fills before `OK`, `OnInit` halts on `I7_*_DEPTH` (`ea/grind_recon.mqh:489-495`) and calls `Grind_CancelOwnEntryOrders` (`ea/grind_recon.mqh:1429`).
  - **Fix in ordering:** Glance at the Trade tab **immediately after step 2 (`Remove`)**. Once the old EA is removed, the book cannot spawn `|L07|ENT`; if `|L07|ENT` is resting because `|L06|ENT` filled right before `Remove`, delete `|L07|ENT` in the Trade tab **before** step 3 (`Attach`).

---

### Finding 5 — Missing Verification Step After `s3` (`docs/runbooks/twoarm-build-c.md:94-105`) and Missing Failure Codes in `s6` Step 1 (`docs/runbooks/twoarm-build-c.md:168`)

1. **`s3` (`docs/runbooks/twoarm-build-c.md:94-105`) has no log check that the 7 retired charts (and neither `EURUSD` nor `AUDCAD`) logged `deinit reason=1`:**
   - Note that closing a chart window in MT5 without first clicking `Expert Advisors -> Remove` deinits the EA with `REASON_CHARTCLOSE` (`reason=4`), and `scripts/build_logcheck.awk:15, 22` only prints rows for charts that subsequently emit `GRIND_REPLAY ready`. A one-line grep on the journal after `s3` confirms all 7 retired charts logged `fxgrind deinit reason=1` and that neither `EURUSD` nor `AUDCAD` was touched.
2. **`s6` step 1 (`docs/runbooks/twoarm-build-c.md:168`, referencing `docs/runbooks/twoarm-build-d.md:134`) omits start-up failure codes that `ea/` writes to `event_log`:**
   - `docs/runbooks/twoarm-build-c.md:168`:
     ```168:168:docs/runbooks/twoarm-build-c.md
     1. **Archive codes, last hour** (expected `none.`): D's s6 step 1, the same command.
     ```
   - `docs/runbooks/twoarm-build-d.md:134`:
     ```134:134:docs/runbooks/twoarm-build-d.md
            railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes "ROLL_STRANDED,ROLL_CLOSING_STUCK,ROLL_REFUSED,DEAL_EVENT_MISSED,REPLAY_SEED_FAILED,EJECT_ACCEPTED,INVARIANT_FAIL,QUARANTINE_HALT" --hours 1
     ```
   - That `--codes` list omits `RECON_FAIL` (`ea/grind_recon.mqh:1381`), `REBUILD_EXIT_FAILED` (`ea/grind_engine.mqh:3140`), `REBUILD_EXIT_UNREADABLE` (`ea/grind_engine.mqh:3108`), `STARTUP_EXIT_SHORTFALL` (`ea/fxgrind.mq5:275`), `CRITICAL_STARTUP_EXIT_SHORTFALL_SIDE` (`ea/fxgrind.mq5:278-280`, `ea/grind_archive.mqh:550`), `API_LIMITS_INVALID` (`ea/fxgrind.mq5:248`), `API_LIMITS_MISMATCH` (`ea/fxgrind.mq5:253`), and `WARN_API_ENTRY_STOP` (`ea/grind_engine.mqh:3625`).

---

### Finding 6 — Minor Check in `s5` (`docs/runbooks/twoarm-build-c.md:148-149`): Confirm `Trade: Full access` in `GBPCHF` Specification

- **Runbook passage (`docs/runbooks/twoarm-build-c.md:148-149`):**
  ```148:149:docs/runbooks/twoarm-build-c.md
  **First, add GBPCHF to Market Watch:** in Market Watch right-click -> **Symbols** -> find **`GBPCHF`** ->
  **Show**. Right-click `GBPCHF` in Market Watch -> **Specification**: confirm **digits 5** (point `0.00001`).
  ```
- **Exact source (`ea/grind_engine.mqh:2001-2003`):**
  ```2001:2003:ea/grind_engine.mqh
     const long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
     if(!Grind_MarketTradeModeFull(trade_mode))
        return false;
  ```
- While the `GBPCHF` Specification dialog is open in `s5`, also confirm **Trade: Full access** (`SYMBOL_TRADE_MODE_FULL`); if `trade_mode != SYMBOL_TRADE_MODE_FULL`, `Grind_GuardsAllowTrading` returns `false` silently without logging any `BAD` line and no `L0` orders are placed.

---

## 3. Verified Constants, Presets, and Fingerprints at `3860a17`

All table values in `s1` (`docs/runbooks/twoarm-build-c.md:49-65`) and shell checks in `s2` (`docs/runbooks/twoarm-build-c.md:69-92`) match the repository at `3860a17`:
- `git diff --stat 5bb5fdb 3860a17 -- 'ea/*.mq5' 'ea/*.mqh'` is empty (matches `docs/runbooks/twoarm-build-c.md:32-33, 70`).
- `ea/presets_c/*_t1.set` count is `6` and combined sha256 fingerprint is `72ba0e3c19f6` (matches `docs/runbooks/twoarm-build-c.md:52, 74`).
- `ea/*.mq5` (`6`) + `ea/*.mqh` (`73`) = `79` files, so `s2.5` comparing both `Experts/fxmatrix` and `Scripts/fxmatrix` yields `ok=158` (matches `docs/runbooks/twoarm-build-c.md:81`).
- Every row of the `s1` input table (`docs/runbooks/twoarm-build-c.md:54-65`) matches `ea/presets_c/{eurusd,audcad,gbpchf}_{opt,alt}_c_t1.set:1-41`.
