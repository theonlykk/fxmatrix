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
| Code | EA sources copied and compiled from `main` at `87765be` (EA code = cycle 3's `6c57830`); presets pulled later at `85cd555` (EA code identical); EA and tests 0/0 on the box; suite **1766/1766** on the box, 2026-09-24 02:14Z |
| Presets | `ea/presets_b/*_b.set`: cycle 3's eleven presets, identical except `InpTelemetryInstance` (`GRIND_<PAIR>_OPTB`, `_ALTB` for the two duplicates) and the label. Magics are shared with cycle 3: separate account, separate terminal, separate GlobalVariable store |
| Telemetry | pipshed accepts any instance id; Fleet B is archived in full and its daily snapshots are kept apart by account login. It has no dashboard cards yet (pipshed ring config lists cycle 3 only). The cycle-3 s4 counter ignores it (median over ids ending `_OPT` only) |

---

## 2. TWO PHASES

**Phase 0 -- from the first attach until ADR-161 is merged and deployed
on the box.** Fleet B runs cycle 3's configuration exactly. Compared with
cycle 3 on the same days it measures the **broker effect** alone
(IC Markets raw spread vs FTMO), with no window.

**Phase 1 -- ADR-161 on, same fleet, same broker.** New entries only
between **07:00 and 16:55 Toronto time**, Mon-Fri (EDT until 1 Nov, EST
after; amended 2026-09-24 from 17:00, ADR-161 G1: the close must precede
the 17:00 rollover so the Friday cancel lands in an open market);
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
- **Verified 2026-09-24 (Specification, AUDCHF and GBPUSD):** trade
  00:01-23:59 server Mon-Thu, Fri to 23:57 (server = GMT+3 = NY close);
  stops level 0; commission $3.5/lot/side ($0.07 per 0.01 scalp round
  trip); filling Immediate or Cancel; swaps in points, triple Wednesday.

---

## 5. RECORD

- **Phase 0 started 2026-09-24:** GBPUSD attached ~02:38Z, all eleven by
  ~02:50Z; EA compiled from `87765be`, presets `85cd555`; telemetry
  confirmed (`grind telemetry POST ok`).
- **Read it:** `https://pipshed.com/api/g/k7m9p2x4q/status_b/<cachebuster>`
  (pipshed `0390f0e`), or per instance
  `/api/telemetry/live?instance=GRIND_GBPUSD_OPTB`. Daily snapshots: the
  Daily card, account 53066709.
- **Dashboard:** `https://linux.pipshed.com` (pipshed `39df6e0`, second Railway service,
  `GRIND_FLEET=B`; Cloudflare CNAME to Railway, proxied; `https://pipshed-copy-production.up.railway.app` also serves it).
- **Superseded since writing:** s1's "no dashboard cards yet" and s4's
  last bullet -- the dashboard is live (C38).
- **Plan changed 2026-09-24 evening (operator):** Phase 1 is NOT the
  window. From Mon 28 Sep Fleet B runs cycle 3's s5 dial rule on its own
  ratios (geometry-cycle3 A4), changes by `presets_b` and reattach; cycle
  3 is the control. The window (ADR-161) goes to Fleet C (new box, new IC
  Raw demo). First Daily row: FTMO day 24 Sep realised $66.86, 90 scalps.

Line count: 90
