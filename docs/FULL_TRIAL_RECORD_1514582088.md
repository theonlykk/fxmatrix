This message has a line count at the bottom

# FULL-TRIAL RECORD -- Account 1514582088 (FTMO Free Trial, 10-23 Sep 2026, cycle 2)

FROM: Khalid (Lead Quant), captured by Claude (Lead Engineer)
TO:   the record + Gemini
RE:   Cycle-2 epitaph from the full deal dump. Account ENDED on the Max
      Daily Loss (-$505.34 against -$500) at 13:51Z on 23 Sep. No ruling
      requested here; the open questions are backlog C28-C31.

Sources: FTMO MetriX for the account (objectives, statistics), and the
terminal deal dump `deals_dump_20260923_1741.csv` (4,317 deals, 4,318
lines, 10 Sep 05:46 to 23 Sep 16:51 broker time; kept in
`data/local/`, not committed). The dump reconciles to MetriX to the cent:
final balance $9,685.62, and the FTMO-day loss from 22:00Z is -$505.34.
All times below are UTC unless marked "broker" (UTC+3 in September).

---

## 1. THE ACCOUNT

| | |
|---|---|
| Type | FTMO Free Trial, Swing, $10,000, 16 instances (8 pairs x OPT/ALT) |
| Start / end | 10 Sep / 23 Sep (ended by breach, the day it was due to expire) |
| Max Daily Loss (-$500) | **-$505.34, breached** |
| Max Loss (-$1,000) | -$314.38 (-3.1%), not breached |
| Final balance = equity | $9,685.62 (flat: FTMO closed 128 positions, deleted all orders) |
| Result 10-22 Sep | +$190.96 at the FTMO-day boundary (MetriX daily table: +$194.83) |
| Result 23 Sep | -$505.34 (FTMO day); MetriX daily table shows -$509.21 on its own boundary |

---

## 2. WHERE THE -$314.38 CAME FROM

| bucket | deals | USD |
|---|---:|---:|
| Scalps (CloseBy pairs), incl. swap on those layers | 1,944 (972 scalps) | +624.28 |
| Entry commissions ($0.03 per fill) | 2,158 | -64.74 |
| Manual closes (rolls and the 17 Sep flattening; -$281.89 on 17 Sep) | 86 | -318.48 |
| FTMO liquidation, 23 Sep 13:51Z | 128 | -555.44 |
| **Total** | | **-314.38** |

Swap over the cycle: -$44.97 (all buckets).

**By pair** (total = scalps + commissions + manual + liquidation):

| pair | scalps | total USD |
|---|---:|---:|
| GBPUSD | 234 | -211.72 |
| EURUSD | 115 | -108.72 |
| AUDCAD | 164 | -18.78 |
| AUDCHF | 74 | -10.16 |
| CADCHF | 56 | -0.55 |
| NZDCAD | 121 | +8.73 |
| AUDNZD | 118 | +9.76 |
| EURGBP | 90 | +17.06 |

**The two USD majors lost $320.44; the other six pairs together made
+$6.06.** GBPUSD earned the most from scalps (+$199.02) and gave back
$395 on closes and liquidation.

---

## 3. THE BREACH DAY (FTMO day from 22:00Z 22 Sep)

**The day started two-thirds spent.** Balance at the FTMO day start was
$10,190.96. Equity then was about -$330 below it: the open book carried
in from earlier days. FTMO's daily limit counts from the day-start
BALANCE, and equity includes open MTM, so that carried displacement
counts against the day in full. The USD move then had to find about
$170 more.

Equity path (positions marked at the last fill price per pair):

| time | vs day-start balance | open MTM |
|---|---:|---:|
| 00:00Z | -331 | -332 |
| 06:00Z | -353 | -364 |
| 09:00Z | -387 | -409 |
| 12:00Z | -416 | -453 |
| 13:51Z | liquidated at -505.34 | |

The marks lag fast moves, so the path runs about $50 short of FTMO's own
equity at the end. The pipshed status at 13:16Z read open MTM -$508.

**Where the day's -$505 sat:**

| pair | positions carried in | positions opened on 23 Sep |
|---|---:|---:|
| GBPUSD | -209 | +11 |
| EURUSD | -79 | -15 |
| AUDCHF | -45 | -11 |
| EURGBP | -36 | -3 |
| CADCHF | -31 | -3 |
| AUDNZD | -17 | +1 |
| NZDCAD | -5 | -21 |
| AUDCAD | -2 | -40 |
| **total** | **-424 (84%)** | **-81** |

77 of the 128 liquidated positions were opened before the FTMO day
(-$450.14 at liquidation); the oldest dated from 15 Sep.

**The ADR-158 breaker counterfactual** (the breaker was NOT on this
build, `5454358`). The 80% line (-$400) was crossed at about 09:17Z on
the lagging marks, so possibly earlier. Blocking every entry from then
removes 57 entries and their paired exits, net -$19.36: the day ends at
about **-$486**, $14 inside the limit at the moment FTMO liquidated, with
the USD move still running. Even with NO entries from 22:00Z the day is
about -$425. First-order only: blocked entries would also have changed
slot use and later fills. **The breaker is the right tool for a day that
goes bad; it cannot rescue a day that starts bad.**

---

## 4. THE FLEET AFTER THE LIQUIDATION

At 14:38Z (47 minutes after FTMO flattened the account), all 16 instances
were still live, and each reported its old layers with `recon_ok:true`
and `invariant_ok:true` against an empty book. The shared API counter rose
from 506 (13:16Z) to 1,906 (14:38Z). Every instance was logging
`WARN_API_SOFT_LIMIT` when the operator switched Algo Trading off.
Observed, cause not yet traced (backlog C31).

---

## 5. LESSONS FOR CYCLE 3

1. **Displacement meets a daily ruler.** The strategy carries offside
   inventory and waits for the range to return (the 1514264399 record,
   s0). FTMO charges that displacement to whichever day it is observed
   on. So the binding constraint is carried open MTM against the $500
   daily limit, not the day's trading. (C28)
2. **One arm.** OPT and ALT held near-identical stacks, so every
   adverse move was paid twice. Cycle 3's single arm halves both the
   carried MTM and the day's move; as a rough scaling, 23 Sep lands
   near -$250. It is not a replay: cycle 3's geometry differs.
3. **The USD majors carry the risk.** At equal lots they are $0.100 per
   pip against $0.057-0.071 for the CAD- and NZD-quoted crosses. They
   lost $320 while the crosses broke even. (C22 already covers scoring in
   USD.)
4. **Pip values measured from 23 Sep's closing deals**, USD per pip at
   0.01 lots: AUDNZD 0.057, AUDCAD 0.071, NZDCAD 0.071, GBPUSD and
   EURUSD 0.100, AUDCHF 0.122, CADCHF 0.122, EURGBP 0.133. NZDCHF
   (CHF-quoted) should sit near 0.12. This bears on which pairs a
   duplicate instance should double. (C30)
5. **FTMO's day boundary is 22:00Z** (00:00 CEST): measuring from
   there reproduces -$505.34 exactly, confirming ADR-158's anchor.

---

## 6. METHOD AND CAVEATS

- USD value per unit of price per pair is the median over 23 Sep closing
  deals of profit / (price move x volume). GBPUSD and EURUSD are exactly
  $100,000 per lot.
- Marks use the last deal price on each pair (a fill or a close), so bid
  and ask are mixed and fast moves lag. The trip time and the equity path
  are approximate; the realised totals are exact.
- A scalp is a distinct CloseBy order (two OUT_BY deals). The breaker
  counterfactual removes every ENT opened after the trip, plus its
  CloseBy partner.
- The MetriX share link carries a token and is deliberately not recorded
  in this public repo.

Line count: 166
