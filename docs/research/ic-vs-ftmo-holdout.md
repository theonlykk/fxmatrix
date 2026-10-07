This message has a line count at the bottom

# IC vs FTMO -- DOES THE IC STRATEGY BEAT CYCLE 3? (PRE-REGISTERED, MON 12 - FRI 23 OCT)

| | |
|---|---|
| Status | **TO BE REWRITTEN (7 Oct ~17:30Z): A is no longer cycle 3.** Operator ~16:40Z-16:45Z: FTMO 1514731800 expires 7 Oct; the new free trial runs the IC strategy STATIC at B's round-2 anchor (`docs/runbooks/ftmo-ic-start.md`), so the question becomes (1) does static IC make money on FTMO and (2) does B (moving with the compass) beat A (static); the trial's ~14 days (to ~20-21 Oct) set the window. Gemini's GI-1..GI-4 answers (7 Oct) carry into the rewrite. Below, the draft as first written: **DRAFT for Gemini** (Claude, 7 Oct ~16:10Z; s9). Fixed BEFORE its window opens (11 Oct 22:00Z); after acceptance nothing changes except by a dated amendment written before the scoring run |
| Origin | Operator 7 Oct ~15:59Z: "i think judging on ftmo isnt correct - we run a different strategy on ftmo vs ic"; ~16:03Z: "keeping ftmo is sensible - it is data point - and our best one at the moment. my thought was that the ic strategies would be much better than ftmo. it might be once again, boring is best ... probably a few more weeks of testing at least"; ~16:07Z: "draft pls" |
| Builds on | `docs/research/holdout-verdict-criteria.md` (V, the day-bootstrap; its scope amendment of 7 Oct in s8 points here); `research/ftmo_pass/ftmo_days.py` (`build_days`, unchanged); `research/holdout/holdout_verdict.py` |
| Decides | Whether the IC strategy (lattice, re-roll, roll gate, tight widths, compass-tuned) makes more money per day than cycle 3's FTMO configuration on the same pairs and days. Not a compass verdict; not FTMO's own edge (that is C125's V) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | FTMO (A, 1514731800) runs cycle 3 frozen: seven instances, auto-ejection, no lattice, no re-roll, no gate, wide widths, ADR-158 breaker and ADR-160 gate | BOOT s6; geometry-cycle3 | VERIFIED (docs) |
| K2 | IC B (53066709, the anchor) runs `main` `5bb5fdb` since 7 Oct 02:22Z: lattice, re-roll, roll gate 0, tight widths, deadband 2, cap 8, breaker off; nine pairs | event log 7 Oct; runbook wednesday-build s10 | VERIFIED |
| K3 | The seven pairs both run, with the SAME magic on A and B: GBPUSD 22260101, EURUSD 22260201, EURGBP 22260301, AUDCHF 22260501, CADCHF 22260601, NZDCAD 22260801, AUDNZD 22260901 | `ea/presets/*_opt.set`; `ea/presets_b/*_opt_b_r2.set` | VERIFIED (repo presets) |
| K4 | `ftmo_days.build_days(deals, bars, magics=...)` gives per-FTMO-day (22:00Z-22:00Z) realised (profit + swap + commission by deal time) and open MTM at each day boundary for positions OPENED by the given magics; C125's V uses it unchanged | `research/ftmo_pass/ftmo_days.py` 111-; `holdout_verdict.py` | VERIFIED |
| K5 | The IC strategy changed inside C125's window (re-roll ON 5 Oct night, round-2 reload 6 Oct, the gate build 7 Oct): a test of IC needs a window that starts after a fixed point | holdout criteria K6; event log | VERIFIED |
| K6 | A (FTMO) may get changes after C125's verdict (FTMO S = W + 1, D 3: operator 5 Oct, "only after the holdout") | HANDOFF s57 | VERIFIED |

## 1. THE QUESTION

On the days both run, over the seven common pairs, is IC B's daily change in
equity larger than FTMO A's? "IC better" means the added machinery earns its
keep; "no difference shown" or "FTMO better" means, in the operator's words,
boring is best.

## 2. THE WINDOW

- **FTMO days Mon 12 - Fri 23 Oct:** 11 Oct 22:00Z to 23 Oct 21:00Z, ten
  trading days (Friday days end at the close). It opens after round 3's
  reload (Fri 9 Oct).
- **A (FTMO) is not changed in the window** (no input change; defect fixes
  and C93 restarts as C125 s8, each listed with the result). Any other
  change to A moves the window's start to the first 22:00Z after it. K6's
  changes wait until 23 Oct.
- **B (IC) runs as the programme runs:** compass promotions to B, round
  reloads and EA builds are PART of the IC strategy and are allowed; each is
  listed with the result. A change that stops B trading (a halt, a rebuild)
  for more than 2 hours in a day voids that day for both fleets.

## 3. THE MEASURE

For each FTMO day d in the window:
- E_A(d) = A's change in equity on d over the seven magics (K3), and E_B(d)
  the same for B: `build_days(deals, bars, magics=K3)` on each account's own
  deal history and each broker's own minute bid / ask (K4); realised by deal
  time + change in open MTM between the day's boundaries.
- D(d) = E_B(d) - E_A(d).
Both accounts trade 0.01 lots; commissions and swaps are each venue's own
(the economics of running there).

## 4. THE VERDICT

Day-bootstrap of the mean of D(d) (20,000 resamples, seed 1, days drawn with
replacement; as C125's V):

| Verdict | Rule |
|---|---|
| **IC BETTER** | the 2.5% bound of the mean daily D > 0 |
| **FTMO BETTER** | the 97.5% bound < 0 |
| **NO DIFFERENCE SHOWN** | otherwise; the more complex strategy has not earned its keep (the burden of proof is on IC) |

Reported beside it, never deciding: each fleet's own mean daily equity change
and its 2.5% bound (does either make money?); D(d) per day; per pair, the sum
over the window for each fleet (realised and open MTM apart); B's compass
reloads and promotions inside the window.

## 5. SCORING (Sat 24 Oct)

1. A: `grind_history_dump.mq5` (desktop FTMO terminal, read-only) and
   `grind_bidask_dump.mq5` from `2026.10.11 23:00` (server).
2. B: the same two scripts on wine-test for 53066709 (history) and wine-c
   (IC bid / ask; B shares its server), scp to Downloads.
3. Claude: `research/holdout/ic_vs_ftmo.py` (to be built before 11 Oct 22:00Z,
   tests first, hand-derived; reuses `build_days` unchanged).
4. One results section appended here.

## 6. NEGATIVE SPACE

- Nothing of the window is computed before its end (status reads continue).
- C125 (FTMO's own edge, scored Sat 10 Oct) is unchanged except its scope
  amendment (holdout criteria s8, 7 Oct): its verdict covers cycle 3's FTMO
  configuration only.
- No change to the pairs, the measure, the window or the verdict table
  after acceptance, except a dated amendment before the scoring run.
- A verdict is not reinterpreted afterwards ("IC would have won without
  EUR"): that is a new hypothesis for a new window.

## 7. KNOWN LIMITS

- Two brokers: quotes, spreads, commission and swap differ (part of what
  is compared); the pairs and lot size are the same.
- B is one IC fleet (the anchor); C and D carry probes and are not used.
- Ten days at one FTMO day each: a real but small difference can be NO
  DIFFERENCE SHOWN (it means "not shown in ten days", not "equal").

## 8. RESULTS

(empty until Sat 24 Oct)

## 9. FOR GEMINI (attack the premises; say which fact is missing)

- **GI-1. Pairs and fleet.** Seven common pairs, B against A. Should C and D
  be pooled with B (three IC fleets, more data, but their probes differ
  from the anchor), or is the anchor the IC strategy's fair representative?
- **GI-2. A moving B.** Compass promotions and reloads inside the window
  count as the IC programme. Fair, or should B be frozen (then the compass
  stops promoting for two weeks)?
- **GI-3. Burden of proof.** Inconclusive = NO DIFFERENCE SHOWN, read as
  "keep the simpler one". Right default?
- **GI-4. Ten days.** FTMO's day sd was ~$59 (24 Sep - 2 Oct); a paired
  difference may be noisier. Is ten days enough to be worth running, and
  what fact is missing?

Line count: 118
