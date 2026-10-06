This message has a line count at the bottom

# CURSOR PROMPT -- ADR-166 POST-AUDIT FIX (restart at init; gate before backoff; RG7c label)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Branch `adr166-roll-gate`
at the commit that carries THIS file (on top of `f02098d`, the DeepSeek
response; EA code == `634c7ea`, suite 2580/2580 on GBPUSD and EURUSD).
Design: `prompts/cursor_adr166_roll_gate.md` (Gemini-reviewed; s1 P4, C6,
C8, s10). Written by Claude from source at `f02098d`, 6 Oct ~19:50Z.
Line numbers are that code. Gemini reviews THIS file (s7) before Cursor
starts.

## 0. RESTATE AND STOP (do this first, then wait)

1. `git fetch origin`; `git switch adr166-roll-gate`. Do NOT `git pull`
   (the branch's upstream may point at `origin/main`).
   `git rev-parse --short HEAD` must equal
   `git rev-parse --short origin/adr166-roll-gate`;
   `git diff --stat 634c7ea HEAD -- ea/` must be EMPTY. If not, STOP.
2. Restate each change in s2 in ONE line, quoting this prompt's words,
   and list every test name in s4 with its assertion count and tags.
3. Then STOP. Do not edit anything until the operator replies "go".

## 1. THE AUDIT, CHECKED (DeepSeek `prompts/deepseek_adr166_audit_response.md`)

| # | DeepSeek | Claude's check (source at `f02098d`) | Outcome |
|---|---|---|---|
| D1 | G1-G6 VERIFIED | agreed, each quote found | - |
| D2 | T-2 case 3: an EA restart while gated re-initialises tracking with the 24 h catch-up (`MathMax((long)(newest + 1) * 1000, (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000)`); if the gate is OPEN on the first call the loop replays a dip from the held period (P4) | AGREED, and it is caused by the gate: before this branch every dip in that window had already been rolled; with the gate the window holds DEFERRED dips | FIX Y2, Y3 |
| D3 | T-2 cases 1-2: in backoff (`if(now < backoff) return 0;` precedes the gate) or `blocked` (`Grind_LatticeOnTick` tracks, then `if(blocked) return;`), no restart runs, so a dip from that period can be replayed when the gate is open at the first ungated call | PARTLY: the replayed dips are those of the backoff / blocked period, which `8a3ec0c` replays too (the ADR-162 catch-up, VC3); not a regression. But the gate's rule is "nothing seen while it holds counts", and the backoff case breaks it for one line's cost; the blocked case lifts either by quarantine release (baseline behaviour) or, for a halt, by a reattach / compile = D2's path | FIX Y1 (backoff); blocked ACCEPTED |
| D4 | T-3, T-5: `ROLL_DEFERRED` only on a LIVE crossing (an extreme-driven deferral is silent); `ROLL_CLOSING_STUCK` not evaluated while gated; the fail count stays stale through a hold | as designed (C7, GR6-4, RG14 / Gemini GR6-7) | recorded, no change |
| D5 | T-6 `LATTICE_CONFIG` gains a key | additive; pipshed and `archive_counts.py` do not parse `LATTICE_CONFIG` (grep, pipshed `9b1faba`) | no change |
| D6 | T-7 the gated side still runs the exit queue; CPU of `CopyTicksRange` | the exit queue was never gated (design: rolls only); tick copies at cap exist today (ADR-162) | no change |
| D7 | T-8 RG7c is F, not G (32 F / 23 G); RG14d cannot fail on either commit; the test double's tick copy has no upper bound | RG7c AGREED (Claude's slip, confirmed by the suite 2548/2580); RG14d is a guard by tag; the harness bound is pre-existing (not this branch) | Y4 relabel |
| D8 | TEST GAPS 2-4: backoff in a hold, restart while gated, short-side restart | AGREED | RG15-RG17 |

## 2. CHANGES

| # | File | Change |
|---|---|---|
| Y1 | `ea/grind_engine.mqh` | in `Grind_LatticeTrySide`, MOVE the gate block (`if(Grind_RollGateHolds(roll_gate, opposite_depth)) { ... return 0; }`) AND the four lines after it that clear the deferred latch, unchanged, to directly after `if(!enabled || blocked)` / `return 0;` (1264-1265), i.e. BEFORE `datetime backoff = ...` (1267). Nothing else moves or changes |
| Y2 | `ea/grind_engine.mqh` | directly after `Grind_LatticeRollGateRestartExtreme` (1208-1220): `void Grind_LatticeRollGateInitRestart(const int gate)`: `if(gate < 0) return; if(Grind_MarketTimeMsc() <= 0) return; Grind_LatticeRollGateRestartExtreme(true); Grind_LatticeRollGateRestartExtreme(false);` (no market time yet: leave tracking to its normal 24 h-bounded start rather than copy ticks from 1 ms) |
| Y3 | `ea/fxgrind.mq5` | `OnInit`, on the line directly after `Print("GRIND_ROLL_GATE opposite_max=", InpRollGateOpposite);` (364): `Grind_LatticeRollGateInitRestart(InpRollGateOpposite);` (after `Grind_ReconstructState`, 267) |
| Y4 | `ea/fxgrind_tests_adr166.mqh` | relabel `"RG7c (G)"` to `"RG7c (F)"`; append the s4 tests before `#endif` |
| Y5 | `ea/fxgrind_tests.mq5` | call `Test_RG15_GatedInBackoffRestarts(); Test_RG16_InitRestart(); Test_RG17_ShortRestartWhileGated();` right after `Test_RG14_GatedPathLeavesClosingAndBackoff();` (9461) |

## 3. COMMITS

1. **Tests first:** Y3, Y4, Y5, and Y2 as a STUB (empty body). Message:
   tests first, 7 F / 10 G.
2. **Fix:** Y1, and Y2's body as written. Nothing else.
Do not compile (the operator compiles and runs the suite; do NOT report
a suite figure).

## 4. TESTS (F = fails at commit 1, G = passes at both)

Reuse `ADR166_T0`, `Adr166_TryLong`, `Adr166_TryShort`, the LB6 setup
(`Adr162b_SeedLong8(); Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);`).
Every test ends with `Grind_MarketTestReset(); Adr162b_Reset();`.

**RG15 gated while in backoff** (6): LB6 setup;
`Grind_MarketTestSeedTimeMsc(1790000000000); g_grind_vl_backoff_long = ADR166_T0 + 30; g_grind_vl_fail_count_long = 1; g_grind_vl_extreme_long = 1.20190; g_grind_vl_tracking_long = false;`
then `rc = Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, ADR166_T0, 1.20190, false, 0, 1)`:
a F `g_grind_vl_extreme_long` == 0.0; b F `g_grind_vl_tracking_long` true;
c G `g_grind_vl_backoff_long == ADR166_T0 + 30`; d G
`g_grind_vl_fail_count_long` == 1; e G rc == 0; f F `ROLL_DEFERRED` #0 != "".
(Commit 1: the backoff return comes first, nothing moves. Commit 2: the
gate holds before the backoff check; restart and note; backoff untouched.)

**RG16 the init restart** (8): `Adr162b_Reset(); Grind_MarketTestSeedTimeMsc(1790000000000);`
`g_grind_vl_extreme_long = 1.20190; g_grind_vl_tracking_long = false; g_grind_vl_from_msc_long = 1000;`
`g_grind_vl_extreme_short = 1.21000; g_grind_vl_tracking_short = false; g_grind_vl_from_msc_short = 2000;`
`Grind_LatticeRollGateInitRestart(-1);` a G `g_grind_vl_extreme_long` ==
1.20190; b G `g_grind_vl_from_msc_short == 2000`.
`Grind_LatticeRollGateInitRestart(0);` c F `g_grind_vl_extreme_long` ==
0.0; d F `g_grind_vl_from_msc_long == 1790000000001`; e F
`g_grind_vl_tracking_short` true; f F `g_grind_vl_extreme_short` == 0.0.
Then `Grind_MarketTestSeedTimeMsc(0); g_grind_vl_extreme_long = 1.20190; g_grind_vl_from_msc_long = 1000; g_grind_vl_tracking_long = false;`
`Grind_LatticeRollGateInitRestart(0);` g G `g_grind_vl_extreme_long` ==
1.20190; h G `g_grind_vl_from_msc_long == 1000`.

**RG17 the short side restarts while gated** (3; RG8's mirror, coverage of
existing code): `Adr162b_SeedShort8(); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0); Grind_MarketTestSeedTimeMsc(1790000000000);`
`g_grind_vl_extreme_short = 1.19800; g_grind_vl_tracking_short = false; g_grind_vl_from_msc_short = 1000;`
`Adr166_TryShort(ADR166_T0, false, 0, 1);` a G `g_grind_vl_extreme_short`
== 0.0; b G `g_grind_vl_tracking_short` true; c G
`g_grind_vl_from_msc_short == 1790000000001`.

Use `AssertTrue(name, x == y)` for every `long` / `datetime` comparison
(never `AssertEqInt` on a long). Totals: **17 assertions; 7 F, 10 G.**
At commit 1 the suite reads 2597 total, 2590 passing, exactly the 7 F
failing; at commit 2 2597/2597. ANY other count, any G failing, or any
existing test changing (other than RG7c's label): STOP and report.

## 5. NEGATIVE SPACE

- With `InpRollGateOpposite = -1` nothing changes (Y1 moves an inert
  block; Y2 returns at once for -1).
- Do not change `Grind_LatticeOnTick`, the `blocked` path, the backoff
  computation, `Grind_LatticeTrackOneSide`, `Grind_LatticeRollGateRestartExtreme`,
  `Grind_LatticeRollDeferredNote`, or any test other than RG7c's label.
- No heartbeat, telemetry, preset, pipshed or docs change; nothing on FTMO.
- Do not compile, do not launch MetaTrader, do not run the suite, do not
  CLI compile. Do not `git stash`, `pull`, merge, rebase, amend; no PR, no
  force-push, no `git add .` or `-u` (add each file by name). Push the
  branch after each commit: `git push origin adr166-roll-gate`.

## 6. STOP AND REPORT IF

- Step 0 fails; a line named in s2 is not found as quoted; your F/G
  re-derivation differs for any assertion; anything outside s2 seems
  needed.

## 7. FOR GEMINI (before Cursor starts)

- **GE6-1** Y3 restarts both sides' extreme once at `OnInit` when the
  gate is configured. If the gate is OPEN at that moment (opposite side
  flat), a dip during the EA's own downtime is no longer caught up
  (`8a3ec0c` would roll to it). Claude's lean: accept; it is GR6-3's rule
  ("we only care where it is right now") and the next real crossing rolls.
- **GE6-2** Y1 puts the gate before the backoff check, so a gated side in
  backoff restarts its extreme and may write `ROLL_DEFERRED`; the backoff
  and fail count stay untouched (RG14, RG15). The `blocked` path stays as
  it is (D3). Object?
- **GE6-3** Any test you would add, or any F/G tag you derive differently?

**Gemini, 6 Oct ~19:45Z (recorded after the merge, `d57fe9b`):** GE6-1
accepted (caveat: a spike during downtime while the gate is open is
lost; the next live crossing rolls); GE6-2 accepted (`blocked` stays
before the gate); GE6-3 every tag confirmed, no tests added.

Line count: 132
