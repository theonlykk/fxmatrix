This message has a line count at the bottom

# FLEET B -- PRE-REGISTRATION (IC MARKETS DEMO, LINUX/WINE BOX)

**Written 2026-09-24 ~02:30Z, before Fleet B's first fill.** Operator
decision, 2026-09-24: run a second fleet on the Linux/Wine box to test an
ENTRY WINDOW. It is a demo experiment beside cycle 3; it never touches the
FTMO account or the VPS.

---

## 1. SETUP

| | |
|---|---|
| Account | IC Markets demo **53066709**, server `ICMarketsSC-Demo`, **Hedge**, Raw Spread, USD, 1:100, **$10,000** as the single opening deposit (so the breaker allowance is $500 and the ADR-160 gate $250, as on FTMO) |
| Box | Vultr `fxgrind-wine-test`, 207.148.14.197, Ubuntu 24.04, Wine 9, portable MT5 (`06_LINUX_WINE_BOX.md`) |
| Code | `main` at `87765be` (EA code = cycle 3's `6c57830`); EA and tests 0/0 on the box; suite **1766/1766** on the box, 2026-09-24 02:14Z |
| Presets | `ea/presets_b/*_b.set`: cycle 3's eleven presets, identical except `InpTelemetryInstance` (`GRIND_<PAIR>_OPTB`, `_ALTB` for the two duplicates) and the label. Magics are shared with cycle 3: separate account, separate terminal, separate GlobalVariable store |
| Telemetry | pipshed accepts any instance id; Fleet B is archived in full and its daily snapshots are kept apart by account login. It has no dashboard cards yet (pipshed ring config lists cycle 3 only). The cycle-3 s4 counter ignores it (median over ids ending `_OPT` only) |

---

## 2. TWO PHASES

**Phase 0 -- from the first attach until ADR-161 is merged and deployed
on the box.** Fleet B runs cycle 3's configuration exactly. Compared with
cycle 3 on the same days it measures the **broker effect** alone
(IC Markets raw spread vs FTMO), with no window.

**Phase 1 -- ADR-161 on, same fleet, same broker.** New entries only
between **07:00 and 17:00 Toronto time** (EDT until 1 Nov, EST after);
outside the window resting entry orders are cancelled and only exits,
the carry pass and ejection run. Compared with Phase 0 it measures the
**window effect** without the broker confound. The switch time is
recorded here, in UTC, when it happens.

---

## 3. WHAT IS COMPARED (per FTMO day, from the daily snapshot)

1. **Carried open MTM at the day roll** (`equity_start - balance_start`):
   the quantity that ended cycle 2. The window's hypothesis is that it
   falls, because no layers are added overnight.
2. Realised, inventory P&L, total, swap; gated seconds (ADR-160).
3. Scalps per pair and per day (reported, not a target).
4. Breaker trips and gate episodes: RECORDED, not stops.

No USD target. Fleet B is not pre-registered against cycle 3's s4.

---

## 4. KNOWN LIMITS

- Different broker: spreads, commissions, swaps and fills differ, so
  Fleet B's scalp economics are not FTMO's (that is what Phase 0 is for).
- IC Markets' order limit is not verified; if it reports none, the slot
  guard is off on Fleet B (`Grind_SlotEntryAllowed` treats 0 as unlimited).
- Nobody liquidates Fleet B at $500: it can survive days that would end
  an FTMO account. That is intended -- it shows what happens after.
- Dashboard cards and a Fleet B view: backlog (pipshed).

---

## 5. RECORD

- **Phase 0 started 2026-09-24:** GBPUSD attached ~02:38Z, all eleven by
  ~02:50Z; code `85cd555`; telemetry confirmed (`grind telemetry POST ok`).
- **Read it:** `https://pipshed.com/api/g/k7m9p2x4q/status_b/<cachebuster>`
  (pipshed `0390f0e`), or per instance
  `/api/telemetry/live?instance=GRIND_GBPUSD_OPTB`. Daily snapshots: the
  Daily card, account 53066709.
- **Dashboard:** `https://pipshed-copy-production.up.railway.app` (pipshed `39df6e0`, second Railway service,
  `GRIND_FLEET=B`); `linux.pipshed.com` to follow.
- **Phase 1 switch:** not yet (ADR-161).

Line count: 77
