This message has a line count at the bottom.

# DeepSeek Phase 1 Response — fxgrind PRE-BUILD DESIGN GATE

**Brief integrity gate:** PASS (line 1, line 86 P-3 header, last line 173, total 173).  
**Baseline read:** ea/ and docs/architecture/ARCHITECT.md at repo state described in brief.

---

## T-1 [PRIMARY] — P-1: does the live book actually carry enough state?

**VERDICT:** DESIGN-UNSAFE

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_state_reconstruction.mqh` : `V2_SRE_ValidateReconstruction` : spec §5 invariant — path-dependent fields `last_exit_valid` and `current_add_pips` have no independent broker source (`:1402-1404`). Live engine holds them in `g_long_last_exit_valid`, `g_long_last_exit_price`, `g_long_current_add_pips` (`ea/fxmatrix_v2_engine.mqh` :232-234, :476-480, :594-599) and uses them to choose reload vs add and add spacing.

**MINIMAL REPRO / MECHANISM:**
1. Instance opens long stack: L0 fill → layer-0 exit pending at `entry + InpExitPips`. Layer-0 harvest completes; engine sets `g_long_last_exit_valid=true` and `g_long_last_exit_price=ExpectedExitPrice(entry)` (`engine.mqh` :692-704).
2. Terminal restarts before next add fills. Book-only recon sees: one open position + one exit pending + zero deals replayed. Positions alone cannot distinguish “reload-eligible after top harvest” from “fresh add after mid-stack partial” — both show one layer. Geometry fallback assigns L03 from price spacing but cannot recover `last_exit_valid`; next add may be placed as `V2_Add` at wrong anchor (`:476-480` uses last_exit when valid, else prior entry).
3. **ADR-124 confound:** Partner side fills; dumb arm recenters stranded L0 via `Long_ReplacePendingBuy(..., "V2_L0_RECENTER")` at **current mid ± width**, not genesis placement (`engine.mqh` :1396-1462). Geometry fallback assumes fixed-width ladder from mid; post-recenter resting price violates that assumption → layer index mis-assignment or false invariant pass.
4. **Comment truncation:** MT5 order comment limit is 31 chars. Proposed `GRIND|OPT|L|L03|EXIT` (20 chars) fits, but any extended tag (pair, slot, reload flag, recenter flag) approaches truncation; truncated comment → fallback geometry → silent mis-label (fail-closed HALT only if invariants catch mismatch — P-1 proposes HALT on invariant failure, but wrong label with self-consistent geometry may not trip).

**SEVERITY:** fatal-to-premise (for “no deal history, ever” as stated)

**BLOCKS WEEKEND DEPLOY:** yes — unless P-1 is amended to persist path-dependent state (minimal deal replay for `last_exit_valid` / add-pips widen, or explicit encoding in comment + recenter flag + placement_mid)

---

## T-2 — P-3: order-count arithmetic and cap as risk primitive

**VERDICT:** EXPLOIT-FOUND (arithmetic mostly sound; cap primitive misclassified)

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_engine.mqh` : per-side pending topology — at depth `n`: `n` exit pendings (`LongV2Layer.exit_ticket`, `:217-229`) + at most one add/reload pending (`g_long_add_ticket`, `:588-599`); at flat side one straddle L0 pending (`V2_StraddleL0OnTick`, `:156-204`). Symmetric both-side depth `n` ⇒ `2(n+1)=2n+2` pending orders per instance — matches P-3. ADR-123 place-once (`docs/architecture/ADR-123.md` :74-78) removes re-quote churn but does **not** change pending count; ADR-124 recenter uses Replace, not an extra pending (`engine.mqh` :1424, :1462). Cap enforcement: `if (n <= 0 || n >= InpMaxLayers)` blocks new adds only (`:586`, `:1551`).

**MINIMAL REPRO / MECHANISM:**
1. **Order-count (PASS):** GBPUSD at depth 12 both sides ⇒ 26 pendings/instance × 3 pairs × 2 slots = 156 < 200 FTMO cap. Inherited `InpMaxLayers=20` ⇒ 42/instance × 6 = 252 > 200 (`fxmatrix_v2.mq5` :32) — P-3 caps fix real overflow.
2. **Risk primitive (FAIL):** Trend run loads 8 layers (EURGBP cap). Cap hit → stop adding (`:586`); existing 8×0.01 lots remain fully exposed with no stop. Drawdown sim at cap is necessary but cap does **not** bound loss on inventory already held — only bounds **future** accumulation rate.
3. **Recovery forgo:** Price trends through cap without harvest, then reverses. Uncapped sim would add layers 9-12 on the way out and harvest on reversal; capped instance sits idle at 8 layers, forgoing reload/add harvest that Monte Carlo at observed depth 4-7 never modeled (`G8`).

**SEVERITY:** fixable-within-design (arithmetic); fatal-to-premise only if P-3 is sold as drawdown control rather than order-budget control

**BLOCKS WEEKEND DEPLOY:** no for GBPUSD/EURUSD at proposed caps; **only-for-EURGBP** if concurrent drawdown sim at cap=8 has not been run (brief requires it; not verified in this audit)

---

## T-3 — P-2: swap and other path-dependent costs

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_eurusd.mq5` : placement helpers — every limit price clamped to `SYMBOL_TRADE_STOPS_LEVEL` (`:110`, `:901`, etc.). `ea/fxmatrix_v2_carry.mqh` : ADR-045 rollover shifts resting **exit** targets nightly (`:1-6`, unbounded drift). Sweep omitted swap/carry per `G6`; live engine **does** apply carry to exits (`carry.mqh`) while fxgrind proposes measure-first for ADR-114 reload anchor only.

**MINIMAL REPRO / MECHANISM:**
1. **EURGBP OPT 2-pip exit:** Target ≈ 20 points on 5-digit broker. If `SYMBOL_TRADE_STOPS_LEVEL ≥ 20` points, resting exit must be placed ≥ min distance from market — effective harvest distance > 2 pips or placement fails/rejects. Must read live symbol spec; code will clamp, not enforce nominal 2 pips.
2. **Commission + tick rounding:** Deal dump shows −$0.03 commission per leg. Round-trip ≈ $0.06 on 0.01 lot; 2-pip EURGBP scalp gross ≈ $0.20–0.26 → commission ≈ 23–30% of target before swap. Sweep path did not model this at 2-pip scale.
3. **Rollover drift:** Negative carry night shifts exit limit further out (`carry.mqh`); a 2-pip nominal target becomes 2+pips effective after one Wednesday triple swap — harvest rate falls without width change. P-2 scopes swap measurement but silent on rollover modify path fxgrind must either port or drop.
4. **No single threshold:** Materiality is pair×exit×hold-time dependent. EURGBP OPT (2-pip exit, long median hold ~9 min cumulative, overnight stacks possible) ≠ GBPUSD 5-pip. Defensible rule: measure swap+pips/night; mandatory correction if `|swap_pips| > 0.25 × exit_target` OR hold > 8h with open inventory (would need artifact: broker swap table + hold distribution at cap).

**SEVERITY:** fixable-within-design for GBPUSD/EURUSD; fatal-to-premise for blind EURGBP OPT 2-pip deploy without stops-level + commission + swap read

**BLOCKS WEEKEND DEPLOY:** only-for-EURGBP until measurement gate completes; no for other pairs if exit ≥ 5 pips and stops-level verified live

---

## T-4 — P-4: statistical validity of live A/B as OOS substitute

**VERDICT:** DESIGN-UNSAFE

**LOAD-BEARING CLAIM:** Statistical property claimed: “banked 9/3 baseline + live OPT/ALT trip-wire = acceptable OOS validation of swept geometry.” Confounders: `G7` (all regime windows used for selection; `_oos` suffix not holdout), width×exit sweep grid (9×7 = 63 cells in `scripts/run_width_exit_sweep.py` per ADR-121 lineage), concurrent OPT/ALT shares in-sample-selected **width** while varying exit only.

**MINIMAL REPRO / MECHANISM:**
1. **9/3 baseline vs OPT/ALT (Sep 5+):** Different calendar regimes. Sep 3 chop baseline (+$14.59 account day) is not exchangeable with Sep 5+ volatility without regime covariate. Trip-wire compares cumulative P&L across non-comparable samples — confound, not control.
2. **OPT vs ALT (controlled, not OOS):** Same width (in-sample from sweep), different exit (5 vs 3 on GBPUSD/EURUSD). This decomposes exit effect but does **not** validate width selection OOS — width was chosen on windows that include q1_chop/truss/full_quarter used in selection (`G7`).
3. **Multiple testing:** 63 grid cells, no multiplicity adjustment. Best-cell selection inflates expected live edge; trip-wire on one scalar (OPT vs 9/3) does not unwind 63 comparisons.
4. **Survival claim:** Mis-selected **width** can degrade survival via depth — wider straddle ⇒ fewer fills but larger adverse excursion per fill; sweep max depth 6-7 (`G8`) at width=9 not at OPT width=5. Proportionality “overfit costs harvest not survival” is unproven at OPT geometry; narrower width ⇒ faster turnover ⇒ **more** layers/hour at same cap, not fewer.

**SEVERITY:** fatal-to-premise (for “OOS validated” wording); fixable if P-4 reframed as **monitoring with pre-committed reopen trigger**, not inference

**BLOCKS WEEKEND DEPLOY:** no — deploy may proceed with explicit “directional live monitor, not confirmatory OOS” label; trip-wire still useful as circuit-breaker, not as statistical proof

---

## T-5 — cross-gate interaction (P-3 × CAS × P-1 restart)

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_eur_cap.mqh` : `V2_EurCapReadLayers` : missing peer GV ⇒ returns 0, permissive (`:17-24`, header `:6-7`). `docs/architecture/ARCHITECT.md` :304-321 — stale/missing GV reads as zero; cap thresholds must stay 0 until fixed. `engine.mqh` : `V2_Cap_Sync` on layer change (`:678`, `:720`) publishes own layer count to GV.

**MINIMAL REPRO / MECHANISM:**
1. Six fxgrind instances restart after purge. P-1 book-rebuild OnInit: if rebuild HALT path triggers or init order is pair-by-pair, instances 2-6 start before peers publish GVs. `V2_EurNetExposure` sums four peer keys; absent keys = 0 (`eur_cap.mqh` :63-70). True net EUR exposure may be 12 layers; cap reads 0 → **add gate permissive**, allows widening add that full system would block.
2. P-3 cap-hit on EURGBP (8 layers) stops adds locally (`engine.mqh` :586) but does not reduce published layer count until harvest — peer GBPUSD instance still sees EURGBP GV=8. No deadlock, but **starvation asymmetry:** cap-hit instance stops harvesting new layers while peers continue; CAS uses layer **counts** not pending-order budget — P-3 order cap and CAS exposure cap operate on orthogonal axes; one can bind while the other is slack, producing uneven cross-pair EUR ring stress not seen in single-instance sweeps.
3. P-1 + restart: book-only recon that mis-orders layer indices (T-1) publishes wrong `V2_EurCapSyncInstance` count before HALT — peer sees wrong exposure until BCC/HALT catches up.

**SEVERITY:** fixable-within-design (startup barrier: no trade until all six GVs present + BCC pass; or retain zero cap thresholds per ARCHITECT.md)

**BLOCKS WEEKEND DEPLOY:** yes if `InpEurCapThreshold` / `InpGbpCapThreshold` > 0 before stale-GV fix; no if thresholds stay 0 as ARCHITECT.md requires

---

## T-6 [PREMISE] — are four gates the complete undecided set?

**VERDICT:** EXPLOIT-FOUND (premise incomplete)

**LOAD-BEARING CLAIM:** Premise: “P-1..P-4 exhaust pre-build undecided gaps.” Counter: shipped ea/ contains subsystems with no fxgrind migration plan in the brief.

**MINIMAL REPRO / MECHANISM — silent drops (each cited):**

| Gap | Source | Blocks weekend? |
|-----|--------|-----------------|
| **BCC invariant sweep** (894 lines) | `ea/fxmatrix_v2_bcc.mqh`; ADR-123 `:98-99` “BCC backstops duplicate pending” | **yes** — without BCC or equivalent, ADR-123 fill-in-flight duplicate L0 possible one tick |
| **API daily counter + soft warn** | `ea/fxmatrix_v2_api_counter.mqh` : `V2_DAILY_API_COUNT_GV`, `:124-126` | **no** short-term; **yes** over weeks if six instances churn |
| **Feed staleness guard** | `ea/fxmatrix_v2_entry_ab.mqh` : `V2_FeedStaleAfterTick` :72-91; ADR-123 tests T-SL-10/11 | **yes** — trade on stale quotes without this |
| **Marketability skip** | `entry_ab.mqh` : `V2_StraddleL0BuyMarketable` :93-96; ADR-123 T-SL-3 | **yes** — places limits inside spread → instant adverse selection |
| **Telemetry / heartbeat** | `ea/fxmatrix_v2_telemetry.mqh`, `engine.mqh` :262 | **no** for trading; **yes** for ops/trip-wire (P-4) |
| **Stranded-leg / ADR-124 recenter** | `engine.mqh` :1396-1462; `entry_ab.mqh` :145-163; **undocumented** (G5) | **no** if intentionally dropped; **yes** if dumb straddle parity required — changes book geometry P-1 must encode |
| **HALT_30 CloseBy price inconsistent** | `state_reconstruction.mqh` :53, :1092; `sre_oninit.mqh` :138 | **yes** on restart after partial CloseBy if P-1 drops SRE entirely — need equivalent halt |
| **Rollover exit drift (ADR-045)** | `ea/fxmatrix_v2_carry.mqh` | **no** day-one; **yes** multi-day holds at cap |
| **ADR-114 reload anchor / carry correction** | `docs/architecture/ADR-114.md`; P-2 defers but reload spacing uses `last_exit_valid` | **no** if fxgrind uses fixed dumb spacing only; **yes** if reload path ported |
| **Deploy sync scope** | `deploy.ps1` : `xcopy ea\*` all files — no header whitelist | **no** — but new fxgrind must land in ea/ or deploy breaks |
| **Cap-enablement GV stale-read** | `ARCHITECT.md` :304-321; `eur_cap.mqh` :17-24 | **yes** if caps enabled >0 |
| **Circuit breaker / fail-closed halt lattice** | `ea/fxmatrix_v2_circuit_breaker.mqh`, `g_*_halted` flags | **yes** — fxgrind needs halt primitive set |
| **Processed-deal dedup** | `engine.mqh` :257-258 `g_long_processed_deals[]` | **yes** — OnInit without deal cursor replays fills |

**SEVERITY:** fatal-to-premise (completeness claim); individual gaps fixable-by-explicit-port-or-cut list

**BLOCKS WEEKEND DEPLOY:** yes for undeclared cuts (BCC, staleness, marketability, halt lattice, deal dedup) — must appear on fxgrind Day-1 checklist even if not numbered P-5..P-n

---

## PREMISE VERDICT

**P-1 (live book, self-describing comments):** **Not sound as stated.** Source explicitly documents path-dependent state with no broker observable (`state_reconstruction.mqh` :1402-1404). ADR-124 recenter breaks fixed-width geometry fallback. Acceptable only as **book + minimal path ledger** (last harvest, add-pips widen, recenter flag), not pure book.

**P-2 (measure swap first):** **Sound sequence**, incomplete scope. Must include stops-level, commission, rollover drift — not swap alone. EURGBP OPT 2-pip is the binding edge case.

**P-3 (per-pair layer cap 12/12/8):** **Sound as FTMO order-budget arithmetic**; **not sound as drawdown bound.** Requires concurrent sim at cap before EURGBP deploy.

**P-4 (live A/B as OOS):** **Not statistically sound** as OOS validation (`G7`, regime confound, 63-cell selection). **Sound as operational trip-wire** if labeled non-inferential.

**Four gates complete?** **No.** Minimum undeclared Day-1 ports: BCC (or substitute duplicate-pending guard), feed staleness, marketability skip, halt/fail-closed lattice, OnInit deal-dedup cursor, telemetry for trip-wire. ADR-124/stranded handling needs explicit keep/drop decision affecting P-1 comment schema.

---

## OVERRIDE CHECK

P-4 and P-3 caps are fixable within stated positions (relabel OOS; run cap sim). **P-1 kills the pure “no deal history” formulation outright** — requires amendment before build. **P-2 blocks EURGBP OPT only** until measurement. **T-6 gaps block weekend deploy unless named on an explicit port list** (BCC + staleness + marketability minimum). No finding kills the entire fxgrind program; one finding kills one sentence of P-1.

Line count: 146
