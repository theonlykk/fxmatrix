This message has a line count at the bottom

# CURSOR PROMPT -- C165: A CLAMPED ADD STOPS CHASING THE SPREAD (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat (Composer) in that workspace.
Branch `c165-clamp-hold` from `origin/main` at the commit that carries THIS file. Background:
backlog C165 (`handoffs/Handover/08_BACKLOG.md`), HANDOFF s91 continued 7 (E's request burst),
ADR-013 (the passive clamp). Written by Claude from source at `2f773ae` (EA code == `5bb5fdb`),
26 Oct. Line numbers are that code. **REVIEWED by Argon** (`reviews/argon_review_c165.md` on
`review/argon-c165`, `8aa2da3`, 320 lines, 137 quotes exact): **GO**; Q1-Q6 and Q8 checked in source by
Claude. Its Q7 checked hand values that are NOT this prompt's (another set-up): void; s5's values were
checked by Claude's script before the review. Taken: CE5's price assertion is G (s5); the entry horizon's
two modify sites stay uncovered (s6). s8 is kept as asked.

## 0. RESTATE AND STOP (do this first, then wait)

1. Run `git diff --stat 5bb5fdb HEAD -- ea/*.mq5 ea/*.mqh`. It must be EMPTY. If not, STOP and
   report it.
2. Restate each change in s3 in ONE line each, quoting this prompt's words, and list every test
   in s5 with its assertion count and its class (F or G).
3. Then STOP. Do not edit anything until the operator replies "go".

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | A resting add's price is re-derived every tick: `clamped` = the add target passed through the ADR-013 clamp | `grind_engine.mqh` 2543-2554 | VERIFIED |
| A2 | The sell clamp: if target <= ask, price = max(target, ask + min_dist), min_dist = max(point, stops x point); the buy clamp: if target >= bid, price = min(target, bid - min_dist) | `grind_pure.mqh` 198-226 | VERIFIED |
| A3 | A resting add is modified whenever `clamped` differs from the resting price by the deadband or more (2.0 pips in every E preset; 0.05 once after start-up) | `grind_engine.mqh` 2561-2573; `grind_pure.mqh` 158-171 | VERIFIED |
| A4 | So while the clamp is active the order follows the ASK (sell) or BID (buy): every spread swing over the deadband is one modify, and the swing back is another | A1-A3 | VERIFIED in source; seen live (A5) |
| A5 | Sun 25 Oct 21:00-22:10Z, E (FTMO, 2,000 requests a day): EURGBP OPT's short add 1,033 modifies in 70 minutes (target 0.83882 passed; resting moved 0.83975 <-> ~0.8401 every ~2 s as the spread flickered 0.3-3.5 pips); GBPUSD ALT long add 320; GBPUSD OPT 199; E's counter 1,685 by 23:00Z | `D:\fxmatrix-exports\api_burst` (send_logs); pipshed archive | MEASURED (HANDOFF s91 continued 7) |
| A6 | Weekday rollovers do not do this: D's counter 86 (21 Oct) and 132 (22 Oct) from 21:00Z to 23:00Z, against 3,384 at Sunday's open | pipshed archive, `GRIND_GBPUSD_OPTD` | MEASURED (26 Oct) |
| A7 | The other clamp users are out of scope: `Grind_SendNextAddEnt` (first placement, 2327-2341), the entry horizon (1860-1940; horizon 0 in every preset), the L0 re-centre (3046-3070, gated by `stranded`) | `grind_engine.mqh` | VERIFIED |

## 1. ONE WORKED EXAMPLE (prices)

EURGBP OPT short: deepest short at 0.83832, add 5.0, so the add target T = 0.83882. Price opens above
it: bid 0.83960, ask 0.83974. The clamp rests the sell add at ask + 1 point = 0.83975 (above T: a better
price for a short). The spread widens: ask 0.84009, clamp 0.84010, 3.5 pips from the resting price, so
TODAY the order is moved up to 0.84010. The spread narrows: ask 0.83974, clamp 0.83975, moved back
down. Two requests per flicker, about one flicker every two seconds.

AFTER this change: resting 0.83975 is at or beyond T, and 0.84010 is FARTHER from T than the resting
price, so the order is held. On the narrowing, 0.83975 equals the resting price (inside the deadband):
held. Zero requests. If the bid rises to 0.83975 the add fills there (9.3 pips past T, a better price for
the short). If price falls to bid 0.83900 / ask 0.83914, the clamp gives 0.83915, 6.0 pips CLOSER to T:
moved once. If it falls below T, the clamp is off and the order moves to T itself (as today).

## 2. THE RULE

While the clamp is ACTIVE (the clamped price differs from the theoretical target by more than 0.1 point)
and the resting add is AT OR BEYOND its target (sell: resting >= target; buy: resting <= target; both
within 0.1 point), do not move it FARTHER from the target (sell: to a higher price; buy: to a lower
price). Every other case is unchanged: a move toward the target still needs the deadband; an unclamped
target and a resting price worse than the target behave exactly as today.

Bound: with the add's index unchanged and the clamp active, the resting price only moves toward T,
by at least the deadband each time: at most ceil(|resting - T| / deadband) modifies, and none from
spread flicker.

## 3. CHANGES (two files of EA code; nothing else)

C1. `ea/grind_pure.mqh`: add, directly after `Grind_Adr013ClampSell` (ends line 226):

```
//+------------------------------------------------------------------+
// C165: hold a clamped add that rests at or beyond its target rather than
// chase the spread away from the target.
bool Grind_AddClampHold(const bool is_long,
                        const double theoretical,
                        const double clamped,
                        const double resting,
                        const double point)
{
   const double eps = point * 0.1;
   if(MathAbs(clamped - theoretical) <= eps)
      return false;
   if(is_long)
      return (resting <= theoretical + eps) && (clamped < resting - eps);
   return (resting >= theoretical - eps) && (clamped > resting + eps);
}
```

At commit 1 (s4) the body is ONLY `return false;` (the stub), with the same signature and comment.

C2. `ea/grind_engine.mqh`, `Grind_EnsureAddNext`, lines 2568-2574 become:

```
   if(side.add_pending_ticket != 0) {
      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
      if(Grind_AddClampHold(is_long, add_target, clamped, resting, _Point))
         return;
      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))
         return;
      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
      return;
   }
```

The one-shot flag lines (2561-2566) stay ABOVE this block and unchanged: the flag is cleared on this
tick whether or not the add is held. No other line in either file changes. No new log line, input,
global or GV.

## 4. COMMITS (on `c165-clamp-hold`; never on main)

1. **Tests first:** `ea/fxgrind_tests_c165.mqh` (new), its `#include` after
   `fxgrind_tests_adr166.mqh` in `ea/fxgrind_tests.mq5` (line 31), the test calls after
   `Test_RG17_ShortRestartWhileGated();` (before the SUMMARY line), and the STUB of C1 in
   `ea/grind_pure.mqh`. Message: `C165: tests first for the clamped-add hold (N F / M G, stub)`.
2. **The change:** C1's body and C2. Message: `C165: a clamped add at or beyond its target is held,
   not moved away (Grind_AddClampHold)`.

Push the branch: `git push -u origin c165-clamp-hold`. Report both hashes and `git diff --stat
origin/main..c165-clamp-hold`.

## 5. TESTS (F = fails at commit 1, passes at commit 2; G = passes at both)

Model every C test's set-up on `Test_RB12_AddOneShot` (`ea/fxgrind_tests_rb.mqh` 354-393): the same
resets, `g_grind_order_test_active = true`, `Adr152_TestPrepareIsolation()`,
`Grind_EngineConfigureAdr152(true, 0)`, `Adr152_TestSeedSlotSeams(200, 100, 0)`, the order stub
(`Grind_OrderTestUpsert`), and the same teardown. Magic `RB_MAGIC`, slot "OPT", lots 0.01, max layers 7,
deadband 2.0. Stops level 0 in every `Grind_MarketTestSeed`, so min_dist = 1 point (0.00001). Expected
values are derived by hand below; do NOT change one to match an output (STOP instead, s7).

**Short set-up (S):** one short layer, index 0, entry 0.83832, position 5101, exit order 6101 (BUY_LIMIT,
label OPT S 0 EXT, 0.83782); add 5.0, so T = 0.83882; the add order 6201 SELL_LIMIT, label
OPT S 1 ENT, at the stated resting price; `g_grind_short.add_pending_ticket = 6201`.
**Long set-up (L):** one long layer, index 0, entry 1.12070, position 5201, exit order 6301 (SELL_LIMIT,
OPT L 0 EXT, 1.12140); add 7.0, so T = 1.12000; the add order 6401 BUY_LIMIT, OPT L 1 ENT;
`g_grind_long.add_pending_ticket = 6401`.

Pure (`Grind_AddClampHold`, point 0.00001):

| Test | Call (is_long, theoretical, clamped, resting) | Expect | Class |
|---|---|---|---|
| CH1 sell held | (false, 0.83882, 0.84010, 0.83975) | true | F |
| CH2 sell toward | (false, 0.83882, 0.83915, 0.83975) | false | G |
| CH3 sell unclamped | (false, 0.83882, 0.83882, 0.83975) | false | G |
| CH4 sell worse | (false, 0.83882, 0.83901, 0.83870) | false | G |
| CH5 sell at target | (false, 0.83882, 0.84010, 0.83882) | true | F |
| CH6 buy held | (true, 1.12000, 1.11899, 1.11930) | true | F |
| CH7 buy toward | (true, 1.12000, 1.11960, 1.11894) | false | G |
| CH8 buy worse | (true, 1.12000, 1.11960, 1.12010) | false | G |

Through `Grind_EnsureAddNext` (count `g_grind_order_test_modify_calls` before and after; read the price
with `Grind_OrderGetPriceOpen`):

| Test | Set-up, resting | Market (bid / ask) | Expect | Class |
|---|---|---|---|---|
| CE1 short held | S, 0.83975 | 0.83960 / 0.84009 (clamp 0.84010) | 0 modifies; price 0.83975 | F |
| CE2 short toward | S, 0.83975 | 0.83900 / 0.83914 (clamp 0.83915) | 1 modify; price 0.83915 | G |
| CE3 short unclamped | S, 0.83975 | 0.83800 / 0.83814 (clamp off) | 1 modify; price 0.83882 | G |
| CE4 short worse | S, 0.83870 | 0.83860 / 0.83900 (clamp 0.83901) | 1 modify; price 0.83901 | G |
| CE5 flicker | S, 0.83975 | 50 x [0.83960 / 0.84009 then 0.83960 / 0.83974], one call each | 0 modifies in 100 calls; price 0.83975 | F (price assertion G: the 100th call is a narrow one) |
| CE6 long held | L, 1.11930 | 1.11900 / 1.11940 (clamp 1.11899) | 0 modifies; price 1.11930 | F |
| CE7 long toward | L, 1.11894 | 1.11961 / 1.11971 (clamp 1.11960) | 1 modify; price 1.11960 | G |
| CE8 one-shot held | S, 0.83975, `g_grind_start_add_reprice_short = true` | 0.83960 / 0.84009 | 0 modifies; price 0.83975; flag false after | F (flag assertion G) |
| CE9 short at target | S, 0.83882 | 0.83870 / 0.83910 (clamp 0.83911) | 0 modifies; price 0.83882 | F |

Each CE test asserts the modify count AND the price (two assertions; CE8 three). Every new F test must
fail at commit 1 and pass at commit 2; every G test must pass at both. **Report any F test that passes
at commit 1, or any G test that fails at either** (s7). `Test_RB12_AddOneShot` and every other existing
test must still pass at commit 2 (RB12's clamp is off: its result does not change).

## 6. NEGATIVE SPACE

- Do not change `Grind_Adr013ClampBuy` / `Grind_Adr013ClampSell`, the marketability checks, the deadband
  helpers, `Grind_SendNextAddEnt`, the entry horizon path, the L0 re-centre, any exit or carry path, the
  API counter, any preset, input, define or `GRIND_*` constant.
- No rate limit, timer or per-order counter (not in this change; s8 Q4).
- Do not add the guard to the entry horizon's modifies (`grind_engine.mqh` 1890, 1938): the horizon is 0 in every
  preset (Argon Q1); enabling it later needs the same guard (recorded in the backlog, not here).
- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run the suite (the operator
  compiles in MetaEditor and runs `fxgrind_tests` on the desktop terminal, which has no EAs; the suite
  figure is PENDING in your report).
- Do not `git stash`, do not check out files from other commits, do not merge, no PR, no `git add .`
  or `-u`, no amend, no rebase, nothing on main. ASCII only.

## 7. STOP AND REPORT IF

- s0's diff is not empty; any line number in s3 does not match the code at `2f773ae`.
- An expected value in s5 looks wrong to you: STOP and say why. Do not change it.
- The set-up of `Test_RB12_AddOneShot` cannot be reused as described (name what differs).
- Any F test would pass at commit 1, or any G test fail, by your reading.
- C1 or C2 cannot be applied exactly as written.

## 8. FOR ARGON (review this file before Cursor starts; reply on `review/argon-c165`)

Read this file on `origin/main`, then `ea/grind_engine.mqh`, `ea/grind_pure.mqh`,
`ea/fxgrind_tests_rb.mqh` and `ea/fxgrind_tests.mq5` at the same commit. Quote every line you rely on
exactly, with file and line number. Answer each, verdict CONFIRMED / DEFECT / NOT A DEFECT:

- Q1. A1-A4 and A7 against source; is any other caller of `Grind_ModifyPendingPrice` able to chase the
  spread the same way (name file and line)?
- Q2. A held add can sit INSIDE the spread when it widens (CE1: resting 0.83975 between bid 0.83960
  and ask 0.84009; a bid at 0.83975 fills it). Does any path assume a resting add stays at
  least min_dist from the market (the freeze level, I-invariants, recon, ADR-152's slot guard,
  `Grind_AddTargetNearMarket`)? Name the line or say none.
- Q3. Is the add's fill price still at or beyond T in every held case (a sell add fills at >= T, a buy add
  at <= T)? Any case where holding makes the add fill at a WORSE price than T?
- Q4. Is a per-order modify rate limit still needed as a backstop, given s2's bound? If yes, say where
  the remaining churn would come from, with a line.
- Q5. The one-shot after start-up (CE8): holding instead of the 0.05 reprice when the clamp is active.
  Safe after a reload that changes add (the AUDCAD 6 -> 18 reload of 25 Oct, both directions)?
- Q6. Rolls and the virtual lattice (`Grind_ComputeAddTarget` 2250-2296): can T move while the add's
  index is unchanged so that a held add ends up WORSE than the new T, and does C2 then move it (CE4's
  path)? Any oscillation between the two branches?
- Q7. Check every hand value in s5 (the clamp, T, the deadband) and the F / G classes.
- Q8. Anything else that makes this unsafe for E (FTMO) or the IC fleets.

Reply file: `reviews/argon_review_c165.md`, line-count bookends (first line `This message has a line
count at the bottom`, last line `Line count: N`), ASCII; verdict GO / GO WITH CHANGES / NO GO.
Commit ONLY that file on a new branch `review/argon-c165` from `origin/main`, push it, and stop. Do
not edit any other file, do not merge, do not touch main.

Line count: 216
