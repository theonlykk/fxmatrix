This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-20 01:30Z

You are picking up mid-project. **Read `handoffs/Handover/01_BOOT.md` and
`02_TRAPS.md` first**, then this document. `02_TRAPS.md` is not optional --
two of its entries were written in the last 48 hours after real incidents.

---

## 0. THE SINGLE MOST IMPORTANT FACT

**F1 (the barbell exit queue) was deployed tonight and halted all 16
instances. It has been reverted. It is merged on `main` and MUST NOT be
deployed again without a migration path.** See s3.

---

## 1. STATE RIGHT NOW

| | |
|---|---|
| fxmatrix `main` | `e1efa23` |
| VPS running | `5454358` -- **DETACHED HEAD**, reverted at 01:20Z |
| Fleet | 16 attached, **0 halted**, all `recon_ok` / `invariant_ok` |
| Book | 105 positions, 61 orders, unchanged through the whole incident |
| Suite | 1354/1354 on `main`, operator-run |
| Carry | OFF. `InpEnableCarryPass=false`, `OnInit` FATAL guard intact |
| Account | demo, balance 10,091.94, equity 9,904.16, MTM -172.95 |
| Cycle | **3 days left** |
| Market | shut until 21:00Z Sunday |
| Tags | `vps-19b6faa`, `vps-5454358` |

**The VPS is in detached HEAD at `5454358`.** `deploy.ps1` starts with
`git pull origin main` and would drag F1 straight back. **Do not run it until
you mean to.**

**The terminal's `MQL5\Presets` already holds the NEW geometry.** Chart
inputs still hold the old values, so nothing has changed -- but reattaching
any chart will pick up the new grid. Know this before touching one.

Production delta, `main` vs the running build: `grind_engine.mqh`,
`grind_exitq.mqh`, `grind_recon.mqh` (F1) plus 12 presets (geometry).

---

## 2. WHAT SHIPPED AND IS RUNNING

**The stale-offset fix** (`241a905`) -- a live latent halt, pre-existing.
`GRIND_CARRY_SHIFT_<ticket>` was never cleared except on a scalp close, so a
clamped exit's offset survived a cancel and then sat stale against a
re-placed unclamped exit. I6 computed `raw + stale_offset` against a placed
`raw` and halted. Four lines: clear on cancel (two branches, NOT the
filled-exit branch) and an `else` clearing on unclamped placement.

**F2, held-layer carry accrual.** `grind_carry.mqh:767`/`:775` skipped any
layer with `exit_order_ticket == 0`, so held layers accrued nothing. Fixed
with a dedicated store:

    GRIND_CARRY_SHIFT_<t>    actual minus intended   (queue/pass on place)
    GRIND_CARRY_ACCRUED_<t>  accrued carry, price    (carry pass only)

    intended = raw + accrued ; SHIFT = actual - intended
    I6 = raw + accrued + SHIFT == actual

Both deployed 20:53Z, verified by reconstruction (105 positions before and
after, no ticks).

---

## 3. THE F1 FAILURE -- READ THIS CAREFULLY

**The barbell rule** replaces the prefix queue: `rest if rank < K OR rank ==
depth - 1`. Rank 0 plus the MOST UNDERWATER layer; drop the middle. Designed
in `docs/architecture/exitq-barbell-notes.md`, ratified by Gemini, merged at
`605bc85`, suite 1354/1354.

**Deployed 01:08Z. All 16 instances halted on `I3_LONG_NAKED` within two
minutes.**

Worked example, CADCHF OPT: long layers 0.58963 (L00), 0.58863 (L01), 0.58763
(L02); the only long exit is on L02. Depth 3, so L02 is rank 0 and **L00 is
rank 2 = depth-1**, which the barbell now requires coverage for. It has none.
Offending comment `GRIND|OPT|L|L00|ENT`. Every instance, same shape.

**Why: every existing book was built under the PREFIX rule, so no
highest-rank layer has an exit.** Reconstruction runs I3 before the queue can
place the missing exits, so it halts immediately.

**Normally this self-heals in one tick** -- the queue would place the missing
exit and I3 would pass. **But the market was shut**, every order attempt
returned `[Market closed]`, and a halted instance does not trade at the open
either.

**Reverted at 01:20Z. All 16 recovered, books intact, nothing lost.**

### What F1 needs before it can ship again

One of:

- **Place before checking** -- let `Grind_ExitQManageSide` run a pass before
  `Grind_ReconCheckInvariants` gates on the new rule, so the missing exits
  exist by the time I3 looks.
- **Tolerate a bare highest rank for one pass** -- a grace state where I3
  does not require coverage at `depth - 1` until the queue has had a chance.
- **Deploy only into a LIVE market**, accept a transient halt, and confirm
  all 16 self-heal within a tick. Riskier and needs someone watching.

**Neither Gemini nor Claude caught this.** The steady state was tested
exhaustively -- 7 new tests plus 25 re-derived assertions -- and the
MIGRATION was never considered. That is the lesson, and it belongs in
`02_TRAPS`: **a change that requires placing orders to become compliant must
never be deployed into a closed market.**

---

## 4. THE GEOMETRY A/B -- READY, NOT DEPLOYED

Derived from our own deal history, not a volatility model. This was the
operator's insight and it is the most valuable thing from the weekend:
**the non-market information you get from trading**, available only because
the book does a lot of trades.

`scripts/measure_geometry_depth_holdtime.py`, 2,716 deals over 9 days.

**Key readings:**

- **`adds/L0` tracks `add_pips` almost monotonically** across 8 pairs.
  EURGBP at 6 pips gets 3.95 adds per L0 fill; AUDNZD at 14 gets 1.26.
- **AUDNZD is not short of ENTRIES** (3.0 L0 fills/day, mid-table). It is
  short of ADDS. The step is too wide; the quote is not.
- **GBPUSD is the only pair that caps** -- 22-24% of entries at layer 7+.
- **Quiet crosses hold for days** -- AUDCHF ALT median 58 h, CADCHF ALT 35 h,
  EURGBP ALT 28 h.

**Values merged at `e1efa23`, 12 preset files changed** (6 change
`InpAddPips` only, 6 change `InpExitPips` only, zero change both):

| pair | new OPT | new ALT | was |
|---|---|---|---|
| AUDNZD | 7/5 | 10/7 | 14/5, 14/7 |
| NZDCAD | 7/5 | 10/7 | 10/5, 10/7 |
| AUDCHF | 7/5 | 10/7 | 10/5, 10/10 |
| CADCHF | 7/5 | 10/7 | 10/5, 10/10 |
| AUDCAD | 10/5 | 10/7 | 10/5, 10/10 |
| EURGBP | 6/5 | 6/6 | 6/5, 6/8 |
| EURUSD | 14/5 | 14/7 | 14/7, 14/10 |
| GBPUSD | 10/7 | **14/10** | 10/7, 10/10 |

**Controls (zero diff):** `audcad_opt`, `eurgbp_opt`, `gbpusd_opt`,
`nzdcad_alt`.

**`InpWidthPips` deliberately UNCHANGED on all 16.** Width is the L0 straddle
half-width, currently exactly half `add_pips` on every pair. Tightening
`add_pips` breaks that ratio -- leave it broken. EURGBP quotes the narrowest
market (3) and gets the FEWEST L0 fills/day (2.1); CADCHF quotes 5 and gets
1.3. **L0 fill rate is driven by the pair's activity, not by how tight we
quote.** Changing it would add a second uncontrolled variable.

**GBPUSD ALT widening to 14 is the only test in the wide direction.** Gemini
approved: you cannot test a ceiling expansion on a pair that never leaves the
floor, and OPT at 10 hedges the baseline.

---

## 5. THE SUNDAY PLAN

**Deploy the geometry A/B. Do NOT deploy F1.**

The geometry change is presets only -- it places no orders to become
compliant, so it has no migration problem. F1 does, and has none yet.

### Sequence

1. **Before 21:00Z**, on the VPS:

       cd c:\fxmatrix
       git checkout 5454358          # stay on the running build

   Then hand-copy ONLY the 12 changed presets from `main` into
   `MQL5\Presets`, or check out `main` for the preset files alone. **Do not
   copy `ea\*.mqh`** -- that would bring F1 back.

   Simplest safe route: `git checkout e1efa23 -- ea/presets/` while detached
   at `5454358`, then run `.\deploy_presets.ps1`.

2. **Verify no source file moved:**

       Select-String -Path ea\grind_exitq.mqh -Pattern "const int depth"

   **Must return nothing.** If it matches, F1 is back -- stop.

3. **No compile is needed** if only presets changed. Reattach each of the 16
   charts: Properties -> Inputs -> **Load preset** -> OK. The key is injected
   by `deploy_presets.ps1`, so **no copy/paste**. Check `add`/`exit` read the
   new values on each.

4. **After the 21:00Z open**, pull a status URL and confirm 16 live, 0
   halted, and that orders are being re-priced to the new grid.

### Expect a hybrid ladder

**Changing `add_pips` does not move existing layers, only where the NEXT add
goes.** Every ladder is a mix of old and new spacing until it rebuilds.
**Depth readings will not be meaningful for a day or two.** Do not read the
first day's `mean_depth` as a result.

---

## 6. OPEN WORK, IN ORDER

1. **F1 migration path** (s3). It is merged and cannot ship without one.
2. **Watch Sunday's open** -- first live ticks on `5454358`. The stale-offset
   clears fire on the first rank rotation, which is the first add fill.
3. **Placement-path normalisation.** `grind_engine.mqh:1845-1851` stores
   `exit_target` and the shift from the UN-normalised price while
   `Grind_PlaceLimit` normalises what it sends. Sub-point, inside I6's
   tolerance, halts nothing -- but `exit_target` records a price that was
   never placed. Pre-existing, own branch, not urgent.
4. **pipshed carry table** reads 0.000 because `archive_worker.py:149` builds
   the pips columns from `mult_tomorrow`, and
   `Grind_CarrySwapMultiplier` correctly returns 0 at weekends. **The table
   was displaying the weekend, not a fault.** Gemini ruled: show the raw
   per-night rate with `mult` alongside. pipshed-side, small.
5. **Passive ejection** -- blocked behind geometry. The stability rule as
   ratified is a NULL SET (proof and measurement in
   `exitq-barbell-notes.md` s2k); `range_mult = 2.0` makes it fire ~11% with
   ~1 h median wait on GBPUSD, but 1% and 15 h on AUDNZD. Gemini: **pin
   nothing until geometry is settled.**
6. **Dynamic chunking** of the journal `Print` (4,096 limit, detail line at
   ~4,090). Latent, not live -- telemetry goes by HTTP POST, so it costs a
   readable log line, not data. Demoted behind F1 and geometry.
7. Carried: ARCHITECT s1/s8/s9 say 12 instances, README says 14; MetriX
   daily-loss unverified since 16-Sep; the roll-modes sweeps informed nothing
   and must not be cited.

---

## 7. WORKING PRACTICE THAT EARNED ITS KEEP

- **Verify against committed source. Never trust an agent's claim or CLI
  compile output.** Four wrong diagnoses on 2026-09-18 all came from reading
  rather than running.
- **Instrument before fixing.** Every real fix this weekend came from a
  `Print`, not an argument. Wrap diagnostics in `DoubleToString(v, 8)` --
  MQL5 `Print` truncates and a sub-pip delta reads as `0.0`.
- **Read the thing before changing the thing.** F3 was specced to fix a
  symptom without reading pipshed; the whole pipeline already existed in
  ADR-136. Withdrawn before it shipped.
- **A near-green suite after deleting code is a warning, not a result.**
- **The VPS PULLS. Create tags on the desktop.**
- **MQL5 has no reference variables.** `GrindSideState &side = g_grind_long;`
  is a compile error; a value copy silently discards mutations.
- Gemini catches mechanical MQL5/pandas traps well. **His premises are only
  as good as what he is told** -- three rulings this weekend were reversed
  once a false premise was corrected.

Line count: 258
