This message has a line count at the bottom

# FLEET D AS A TWO-ARM RING: OPT AND A WIDE ALT ON SIX PAIRS, CAP 7 (PROPOSED 16 OCT)

| | |
|---|---|
| Status | **PROPOSED, agreed in principle by the operator 16 Oct ~19:23Z ("yep proceed").** Nothing built: presets, ALT adds, the retirements and the pipshed strip come next. Not before plan 4's window closes (**Tue 20 Oct 22:00Z**) |
| Origin | `docs/research/roll-geometry-notes-2026-10-15.md` s7-s8 (rolls realise at the turns of a range wider than the stack; ALT back or one geometry per fleet) |
| Operator's rulings in it | ALT with wider adds as a second arm; more pairs rather than fewer; **cap 7 on this fleet** (overriding "the cap stays 8" here); the ring USDCAD, EURUSD, EURGBP, GBPCHF, AUDCHF, AUDCAD |
| Open | what "running 0.04 lots" refers to (s1); ALT's adds and exits per pair (s5); the retirement of five pairs (s4) |

## 1. THE OPERATOR'S PLAN (16 OCT)

- ~18:57Z: "i think the plan is we have an alt branch with longer adds. we can use the pips that would have
  worked these last few days as a starting point. my view is that in the quiet periods - alt does very
  little. in the periods like the last few days - it makes money. obviously the opt arm will lose money -
  but i am hoping that the net result is broadly neutral and offsets the fact that we will be running 0.04
  lots." (Asked, not yet answered: is 0.04 lots per layer, per arm, or the net per pair? Lots do not change
  the slot budget below; they scale P&L and margin.)
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

Line count: 102
