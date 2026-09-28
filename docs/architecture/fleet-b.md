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

---

## 6. AMENDMENTS

**B1 (2026-09-26 ~23:55Z) -- GRADED ADD DIAL ON ALL NINE PRIMARIES,
PRE-REGISTERED. NOT YET APPLIED.** Operator decision, 26 Sep, replacing
the s5 rule for this dial (band, one step, groups A/B, GBPUSD fixed):
- **Aim: increase scalp volume**, and balance it: the less active a pair,
  the larger its cut, to move it towards the high performers. A move the
  other way is as useful a result. P&L is reported, not targeted (with
  one lever, maximising P&L "seems silly"; P&L drives the cycle-4 dials).
- **Graded cuts** give nine points of scalp response against the size of
  the cut (the convexity of the add distance). Each point is a different
  pair, so this is suggestive, not a fit.
- **Controls.** The two duplicates (`GRIND_AUDNZD_ALTB`,
  `GRIND_NZDCAD_ALTB`) stay at add 10: same pair, account and ticks as
  their dialled primaries. Cycle 3 (VPS, frozen by A4) trades all nine
  pairs unchanged: a twin per pair on another broker. So the s5 stagger
  and the fixed GBPUSD are no longer needed for a control.

Ratios: s4 = `scalp_history`, the nine `_OPTB` primaries, duplicates
excluded, pooled over FTMO days 24 (from 02:50Z) and 25 Sep, divided by
the median 16 (EURGBP); day 25 alone in brackets (computed ~01:30Z 26 Sep
by the previous chat).

| pair | ratio | add | cut | width | add/width | room to cap (8 x add) |
|---|---|---|---|---|---|---|
| AUDCAD | 1.81 (1.88) | 7 -> 6 | 14% | 5 | 1.20 | 56 -> 48 pips |
| GBPUSD | 1.63 (1.25) | 10 -> 9 | 10% | 5 | 1.80 | 80 -> 72 |
| EURUSD | 1.31 (1.13) | 8 -> 7 | 13% | 7 | 1.00 | 64 -> 56 |
| NZDCAD | 1.13 (1.13) | 10 -> 8 | 20% | 5 | 1.60 | 80 -> 64 |
| EURGBP | 1.00 (1.00) | 4 -> 3 | 25% | 3 | 1.00 | 32 -> 24 (add 3 is the floor) |
| AUDNZD | 0.75 (0.88) | 10 -> 8 | 20% | 7 | 1.14 | 80 -> 64 |
| AUDCHF | 0.56 (0.75) | 6 -> 4 | 33% | 5 | 0.80 | 48 -> 32 |
| CADCHF | 0.44 (0.25) | 6 -> 4 | 33% | 5 | 0.80 | 48 -> 32 |
| NZDCHF | 0.25 (0.13) | 6 -> 3 | 50% | 3 | 1.00 | 48 -> 24 |

Guards: every add/width within 0.5-4.0; no add below 3. Width, exit,
cap, stranded and deadband unchanged. Presets: the nine `*_opt_b.set`
in `ea/presets_b` (the commit that adds this amendment); the two
`*_dup_b.set` unchanged. The box build stays `5685e4f`: no compile.

**Staged 2026-09-27 00:06Z:** the nine new presets written into
`MQL5/Presets` on the box with the key (each checked equal to
`dd4761e` + key; the old files first checked equal to `d2cfd87` + key and
backed up to `/home/khalid/preset_backup_20260926`); the box repo
fetched only (HEAD still `5685e4f`). Reloading from the backups restores
the 24-26 Sep geometry.

Applied by reloading the nine charts' inputs from the new presets
(Properties, Load, OK: deinit reason 5), in session, never with the
market closed. Every cut is 1-3 pips, inside the 4-pip deadband, so
(geometry-cycle3 A6) each side's resting add keeps its old distance
until it fills or the side's deepest layer scalps; every later add uses
the new value. Record the reload times here in UTC.

Expected side effects: sides reach cap sooner (last column), so ADR-157
auto-eject (on in these presets, never yet fired live) may fire; deeper
books raise open loss, so the ADR-158 breaker and the ADR-160 gate may
block entries more often (gated hours on the Daily card); the slot guard
is nearer (entries only). The CHF crosses carry the heaviest pip value.

Watched, per FTMO day and instance: scalps against the 24-25 baseline,
against the pair's `_ALTB` twin (AUDNZD, NZDCAD) and against its cycle-3
twin; closed P&L from `/ejection`; gated hours; ejections. The lattice
(C63) replaces ADR-157 on this fleet from Tuesday. A recount must use
`s4_scalps.py --days 3` and read days 24 and 25 (after 22:00Z Saturday,
`--days 2` returns 25 and 26).

**B1 APPLIED 2026-09-27 (Sunday evening, in session, spreads settled at
1-6 points):** the nine `_opt_b` charts reloaded over VNC (Properties,
Load, OK), each read back before OK; staged presets re-checked first
(18:55Z: all nine `SAME_EXCEPT_KEY key=1` against `dd4761e`). Reload
times (UTC): GBPUSD 23:05:24, EURUSD 23:43:13, EURGBP 23:44:32, AUDCAD
23:45:17, AUDCHF 23:46:34, CADCHF 23:47:20, NZDCHF 23:48:26, NZDCAD_OPTB
23:49:49, AUDNZD_OPTB 23:50:52. Each: `deinit reason=5`, a CONFIG line
with the new `InpAddPips`, `GRIND_SESSION enable=false`, POST ok, no
FATAL/CRITICAL/INVARIANT_FAIL/STARTUP_EXIT_SHORTFALL/RECON/duplicate;
the day's log `reloads: 9`, no bad line. The two `_ALTB` twins untouched
(one deinit per twin pair; card LIVE 11/11 at 23:52Z and 00:09Z). The
first FTMO day under B1 is 28 Sep (from 22:00Z 27 Sep); 28 Sep also
opens with gap fills (02_TRAPS 27 Sep).

Line count: 173
