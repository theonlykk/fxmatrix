This message has a line count at the bottom

# FLEET D AS A TWO-ARM RING: OPT AND A WIDE ALT ON SIX PAIRS, CAP 7 (PROPOSED 16 OCT)

| | |
|---|---|
| Status | **PROPOSED, agreed in principle by the operator 16 Oct ~19:23Z ("yep proceed").** Nothing built: presets, ALT adds, the retirements and the pipshed strip come next. Not before plan 4's window closes (**Tue 20 Oct 22:00Z**) |
| Origin | `docs/research/roll-geometry-notes-2026-10-15.md` s7-s8 (rolls realise at the turns of a range wider than the stack; ALT back or one geometry per fleet) |
| Operator's rulings in it | ALT with wider adds as a second arm; more pairs rather than fewer; **cap 7 on this fleet** (overriding "the cap stays 8" here); the ring USDCAD, EURUSD, EURGBP, GBPCHF, AUDCHF, AUDCAD |
| Open | **the layout ruled in s10 (FTMO and D the six with OPT + ALT; C three pairs; B unchanged)**; ALT's exit per pair, and the quantile behind ALT's adds (s9); the runbook (retirements, cap 7, ids, pipshed). Answered: "0.04 lots" (s1); **the first set (s8): EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF; the ring of s3 later** |

## 1. THE OPERATOR'S PLAN (16 OCT)

- ~18:57Z: "i think the plan is we have an alt branch with longer adds. we can use the pips that would have
  worked these last few days as a starting point. my view is that in the quiet periods - alt does very
  little. in the periods like the last few days - it makes money. obviously the opt arm will lose money -
  but i am hoping that the net result is broadly neutral and offsets the fact that we will be running 0.04
  lots." **Answered ~23:21Z (s85): 0.04 is exposure PER CURRENCY, not a lot size** ("in theory 4 lots of
  0.01 per ccy. currently we have 0.01 * 2 lots of EUR via EURUSD and EURGBP ... so a wild move in EUR would
  cause a lot of MTM. I think there is a good chance we hit our drawdown - but we can and should test. I
  think it is more important to have OPT and ALT"). Each instance stays 0.01 a layer.
- ~19:10Z: "i think it is better to have more fx pairs. i think 7 layers is fine - obv we can test when the
  replay works. lets do USDCAD EURUSD EURGBP GBPCHF AUDCHF AUDCAD. I know this is new pairs but i think the
  EURUSD GBPUSD EURGBP mini ring is not consistent."
- Claude's arithmetic on the idea (roll-geometry notes s8, HANDOFF s84 continued 6): in a 100-pip V the
  narrow arm loses about -200 pips, a wide ALT (add 14) makes about +84, together about -116: ALT softens
  the V, it does not cure it; in a trend both arms reach cap (16 lots a pip) and a wide roll costs about
  (cap - 1) x add. The bet is that ALT wins clearly in wide weeks and costs little in quiet ones: measured,
  not assumed (s6).

## 2. THE SLOT BUDGET

- The EA's entry guard counts positions + orders + every resting entry order AGAIN, and allows an entry
  while the total is <= 194 (200 - 2 - margin 4; pipshed `FLEET_GUARD_LIMIT`). Past it, NEW ENTRIES STOP
  account-wide (fail-closed: no breach of 200, but no scalping anywhere until the book shrinks).
- Measured 16 Oct, a stressed day: the IC fleets read guard 149-155 / 194 with 9 instances at cap 8, about
  **17 per instance** (about 10 positions, about 7 orders and entries). At cap 7 the loaded side holds one
  fewer position: about **15-16 per instance** (7 / 8 of 17 = 14.9 at best).
- **6 pairs x 2 arms x cap 7 = 12 instances x 15-16 = about 180-192 of 194** on a day like 16 Oct; a worse
  moment (both sides deep on several pairs, about 18 each) about 216: the guard stops entries until it
  clears. At the edge, by choice (the operator: more pairs). 5 pairs x 2 arms at cap 8 (about 170) is the
  comfortable alternative, not chosen.

## 3. THE PAIRS

**The chosen six form one closed ring:** USD -> CAD (USDCAD) -> AUD (AUDCAD) -> CHF (AUDCHF) -> GBP (GBPCHF)
-> EUR (EURGBP) -> USD (EURUSD): six currencies, each exactly twice. The EUR / GBP / USD triangle is broken
(GBPUSD out).

**Cost** (`research/pair_choice/spread_rank.py` on FTMO minute bars, 21 pairs, 20 Sep - 3 Oct; spread /
median hourly range, lower is cheaper; raw spread before commission; FTMO's feed, so a ranking, not IC's
spreads today): USD majors cheapest (EURUSD 0.011, GBPUSD 0.026, AUDUSD 0.038, USDCHF 0.055, USDCAD 0.059,
NZDUSD 0.059); crosses 0.07-0.21 (NZDCHF worst, 0.212). Daily path / range at one-minute resolution is
15-21 for every pair: it does not separate them.

**The best ring that avoids EURUSD, GBPUSD and EURGBP altogether** (the operator asked): with USD, EUR and
GBP kept but not paired with each other, each links twice into AUD / CAD / CHF, so there are exactly six
rings; all six priced, the cheapest:

| | The chosen ring | Best ring without EURUSD / GBPUSD / EURGBP |
|---|---|---|
| Pairs (spread / hourly range) | EURUSD 0.011, USDCAD 0.059, EURGBP 0.113, AUDCAD 0.132, AUDCHF 0.134, GBPCHF 0.135 | USDCHF 0.055, USDCAD 0.059, EURAUD 0.074, GBPAUD 0.098, GBPCAD 0.110, EURCHF 0.119 |
| Mean | 0.097 | 0.086 (about 11% cheaper) |
| Never run by us | 2 (USDCAD, GBPCHF) | 5 (all but USDCAD) |
| EURUSD (the replay's calibrated pair) | yes | no |

Kept: the chosen ring (EURUSD, four pairs with live history and geometry, within about 11% of the
cheapest). **EURGBP has the smallest daily range of the 21 (median 21.3 pips):** a wide ALT has the least
room there; expect it to do little.

## 4. THE FLEET AND ITS CHANGE

- **Fleet D (wine-d, IC 53077984), after Tue 20 Oct 22:00Z.** Not before: an ALT arm shares D's slot guard,
  and a guard stop could block D's EURUSD entries, which the replay does not model (plan 4's window).
- **From D's nine to the six x two:** keep EURUSD, EURGBP, AUDCHF, AUDCAD (OPT); add USDCAD and GBPCHF (OPT);
  add an ALT arm on all six; **retire GBPUSD, CADCHF, NZDCHF, NZDCAD, AUDNZD** (their open books wound down
  safely: detaching is safe only for the book as it stands; the C119 retirement of the twins is the
  precedent).
- **Cap 8 -> 7 on a live instance trips I7 if any side holds 8 layers, and I7 is not quarantinable** (BOOT
  s1). D's kept OPT instances can move to cap 7 only when no side is above 7, or by a fresh start of the
  instance. To be planned in the runbook, never by a blind F7.
- ALT ids and magics: cycle 3's `_ALT` slot exists in the EA and pipshed (twin rows); D's ids to be fixed in
  the presets. pipshed's strip (`FLEET_STRIP`) needs D's new instances.
- Requests: IC accepts more than 2,000 a day (C78 (2), 15 Oct): no budget concern on D.

## 5. ALT'S GEOMETRY (TO DERIVE, NOT GUESS)

- The operator: "use the pips that would have worked these last few days as a starting point." From our
  own fills: per pair, the stack (cap - 1) x add that would have ridden the recent swings without rolling
  (B's GBPUSD / EURGBP archives are in hand; EURUSD and the others by export). New pairs (USDCAD, GBPCHF):
  a volume-matched start from the dump's ranges, corrected from their own fills after a week (07_ROADMAP).
- Exit for ALT: open (exit = add, the s5 hurdle's clean case, or the current 10).
- The hurdle per arm (roll-geometry notes s5): scalps per roll step >= (cap - 1) x add / exit (6 with
  exit = add at cap 7).

## 6. HOW IT IS JUDGED

- Per arm and combined, per pair, per week, against B and C unchanged as controls (pipshed compares fleets
  side by side); quiet weeks and wide weeks reported apart.
- The operator's hypothesis: ALT does little in quiet weeks and makes money in wide ones; OPT the reverse;
  the sum about neutral in wide weeks. The replay, if plan 4 passes, scores the same weeks with and
  without ALT on EURUSD before anything moves to an FTMO account.

## 7. EXPOSURE PER CURRENCY, AND A THREE-PAIR OPTION (16 OCT ~23:21Z)

**One worked example (EUR down 100 pips against USD and GBP; EURUSD 1.1600 -> 1.1500; adds illustrative:
OPT 7, ALT 14, cap 7):** OPT is full after 6 x 7 = 42 pips, ALT after 6 x 14 = 84. At 100 pips all four EUR
stacks of the six-pair ring (EURUSD and EURGBP, OPT and ALT) are full and all long EUR: **28 layers, 0.28
lots, about $3 a further pip.** D today in the same move: EURUSD and EURGBP at cap 8, 16 layers, 0.16 lots,
about $1.70 a pip. (Pip values per 0.01: EURUSD $0.10, EURGBP a little more.)

**The operator's alternative ("we might end up with broken rings like just EURUSD GBPCHF AUDCAD - we will
have to see"):** the six currencies each appear ONCE, so with OPT + ALT every currency sits in two
instances: 14 layers, 0.14 lots at full, today's exposure rather than double. Slots: 6 instances x about
15-16 = about 90-96 of 194 (room for cap 8). Cost: EURGBP, USDCAD and AUDCHF dropped, so fewer pairs and
less data (against "more pairs", s1).

| Set | Instances | Currency's instances | At full, one currency | Guard, stressed day |
|---|---|---|---|---|
| Six-pair ring | 12 | 4 | 28 layers, 0.28 lots | about 180-192 / 194 |
| EURUSD, GBPCHF, AUDCAD | 6 | 2 | 14 layers, 0.14 lots | about 90-96 / 194 |
| D today (9 pairs, OPT, cap 8) | 9 | 2-3 | 16-24 layers | 149-155 / 194 |

Not chosen: the operator decides with ALT's adds (s5) in hand.

## 8. THE FIRST SET: TWO TRIANGLES FROM D's OWN PAIRS (17 OCT ~00:17Z)

The operator, 16 Oct ~23:40Z: "is there a way to do 6 ring and not have to build new pairs? I feel like 6
ring will blow up the demo - but i can live with that. we will have just 7 layers." Among the pairs we run,
EUR, GBP and USD pair only with each other, so a six-pair set with each currency twice must hold the
EURUSD / GBPUSD / EURGBP triangle (three candidates were tabled: two triangles, the six-pair ring of s3, A's
square). **17 Oct ~00:17Z: "longer term i think we want my ring - but it seems sensible to use yours EURUSD,
GBPUSD, EURGBP + AUDCAD, AUDCHF, CADCHF first as we have the actual data." RULED for D's first build.**

- **D: EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, OPT + ALT each, cap 7: 12 instances.** All six are on
  D now (their `_OPTD` charts keep running and gain an ALT arm); **NZDCHF, NZDCAD, AUDNZD retire** (their
  books wound down, C119 the precedent). The ring of s3 (USDCAD, GBPCHF) stays the longer-term set.
- Exposure as s7: each currency in two pairs, so four instances; 28 layers at full. Slots as s2.
- **Every kept OPT chart moves cap 8 -> 7:** a side holding 8 at the change trips I7 (s4): the runbook
  checks each side from the heartbeat and changes a chart only when both sides hold 7 or fewer.
- **ALT for a pair with no fills of ours (operator, 16 Oct ~23:26Z): "the new pairs ALT can be from price
  ranges - basically any sensible guess is fine."** (For the ring later; the first set has fills.)

**ALT's adds, first guess (Claude, 16 Oct ~23:45Z; to be refined from our own fills before the presets).**
D's OPT stacks ((cap - 1) x add at cap 8) sit near one median day's range; an ALT stack of about two days'
range at cap 7 gives add ~ daily range / 3, about 2.3-3.3 x OPT's add. Worked example: a 100-pip EURUSD
fall fills OPT (add 7) by pip 42; ALT at add 18 holds 6 layers at pip 100 and has not yet rolled when price
turns. Ranges: `research/pair_choice/spread_rank_2026-10-02.txt` (FTMO minute bars, 20 Sep - 3 Oct, a quiet
fortnight; the last week was wider, GBPUSD ~200 pips on 16 Oct).

| Pair | OPT add (D r3) | Median daily range | ALT add, first guess |
|---|---|---|---|
| EURUSD | 7 | 53.5 | 18 |
| GBPUSD | 9 | 61.2 | 20 |
| EURGBP | 3 | 21.3 | 7 |
| AUDCAD | 6 | 59.1 | 20 |
| AUDCHF | 4 | 39.4 | 13 |
| CADCHF | 4 | 27.4 | 9 |

## 9. ALT'S ADDS FROM OUR OWN FILLS (17 OCT ~01:10Z; SUPERSEDES s8's FIRST GUESS)

`research/alt_adds/` (`alt_excursions.py`, hand-valued tests, `results_2026-10-17.md`, inputs hashed): on
D's archives (1-16 Oct), for a side opened at each hour, how far the market went against it before L0's
exit filled. ALT add at cap 7 = the 90th percentile of the worse side / 6, the larger of the whole period
and the week from 9 Oct.

| Pair | OPT add | ALT add proposed | s8's guess |
|---|---|---|---|
| EURUSD | 7 | 16 | 18 |
| GBPUSD | 9 | 21 | 20 |
| EURGBP | 3 | 14 | 7 |
| AUDCAD | 6 | 25 | 20 |
| AUDCHF | 4 | 19 | 13 |
| CADCHF | 4 | 9 | 9 |

- **EURGBP's guess was wrong by half:** its daily range is the smallest of the 21, but it trended in early
  October; 46% of its long anchors passed the live 21-pip stack. One-way distance decides a roll, not range.
- **ALT's exit moves the answer as much as the add** (results s4): with exit = add, the 90th percentiles
  grow by up to about 2x on AUDCAD long. Claude recommends ALT's exit = OPT's exit for the first build.
- Lower bounds where many anchors are censored (EURGBP long, AUDCHF long). Open: the operator's choice of
  quantile and ALT's exit; then the presets.

## 10. THE LAYOUT FOR NEXT WEEK: FTMO, B, C, D (17 OCT ~02:43Z; SUPERSEDES s8's "D ONLY")

The operator, 17 Oct ~02:37-02:43Z: "I think that OPT/ALT arms will be on FTMO (moved to linux) on the new
demo. Fleet B will be unchanged. I could imagine the broken ring EURUSD GBPCHF AUDCAD on Fleet C"; on the
request budget, "i think FTMO would be ok with 2500"; on wine-d, "we should be wary about logging out of
the IC account on wine D - we might not be able to get back in ... i would be more keen to switch the
windows vps to a new linux server"; then "perhaps we mirror the FTMO set up in wine -d. So if we do have to
shut down FTMO for unforseen circumstances we still have the setup continued". **RULED.**

| Fleet | Next week | Instances |
|---|---|---|
| **FTMO** (a new demo, on a NEW Linux + wine server replacing the Windows VPS; C158) | EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, OPT + ALT, cap 7 | 12 |
| **D** (wine-d, IC 53077984) | **a mirror of FTMO**: the same six, OPT + ALT, cap 7; retire NZDCHF, NZDCAD, AUDNZD | 12 |
| **C** (wine-c, IC 53071896) | EURUSD, GBPCHF, AUDCAD (each currency once), OPT + ALT; retire the other seven; GBPCHF new on IC | 6 |
| **B** (wine-test, IC 53066709) | unchanged: the control | 9 |

- **What each comparison answers:** D against B, ALT's effect at one broker; D against FTMO, the same set-up
  at two brokers; C, the each-currency-once exposure (s7) against D's each-currency-twice.
- **wine-d's IC terminal is never logged out** (C150: the web login refused since 12 Oct; a fresh login may
  fail): D changes charts inside the running terminal only.
- **FTMO's request budget, recorded:** FTMO's email of 2 Oct: 2,000 requests a day, repeated alerts ->
  account disabled (C106); A's seven used about 1,400-1,500 a day (~200 an instance), so twelve is about
  2,500 (ALT's wider adds may need fewer; not measured). The operator judges FTMO will accept it. The EA
  counts every request and stops none (`InpApiEntryStop` 1000000); watch the count per day on pipshed
  for the first days, and any FTMO alert email.
- **ALT's adds:** s9's (measured on D's fills) for FTMO and D; C's EURUSD and AUDCAD the same; GBPCHF (no
  fills of ours) from its range (daily 63.5 pips): OPT about 9, ALT about 21 at cap 7 (the operator: "any
  sensible guess is fine"). Still open: ALT's exit and the quantile (s9).
- The replay's check of ALT on EURUSD comes after, not before, FTMO (s6 said before): on a fresh free demo
  the stake is the trial.
- **Order:** Tue 20 Oct night the export; then D and C in market hours (D first: the mirror), from Wed 21
  Oct; FTMO when the new server is up and the trial on 1514878887 has ended (~21 Oct). One presets prompt
  and one pipshed prompt cover all three fleets; a runbook per fleet.

Line count: 217
