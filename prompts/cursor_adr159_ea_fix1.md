This message has a line count at the bottom

# CURSOR -- ADR-159 EA FIX 1: TEST FIXTURES THAT ENCODE THE 16-MAGIC FLEET

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Branch | `adr159-ea` at `58920fe` | verified by Claude on origin |
| Stub check | `SUMMARY: 1661/1721` at `31978f6`; every predicted SN failure failed by name; `SN1 swap_day` passed because its expected value is 0.00 (fixed by SN15) | operator run, checked by Claude |
| Real branch | `SUMMARY: 1716/1724` at `58920fe`. Eight failures, ALL in existing tests: `CM2 total`, `CM2 peer_failed`, `CL1 allows entry`, `CL1 peer read ok`, `CL2 allows entry`, `CL2 peer read ok`, `CL4 magic count 16`, `RX3 total` | operator run |
| Cause | C29 grew `GRIND_CAP_ALL_MAGICS` from 16 to 18. `22260701` and `22260702` (indices 16-17) carry NZD and CHF. `Grind_CapReadStoredPeer` treats a fleet magic with no stored exposure as a FAILED peer (value maxed). These tests seed or assert a 16-magic fleet | read by Claude |
| Production | NO effect: `Grind_CapAllowsEntry` returns true immediately when both thresholds are 0.0, which every preset sets | read by Claude |
| Spec rule | The ADR-159 EA prompt permitted only CM1's expected value to change. **This fix amends that rule for exactly the four tests below**, each of which encodes the fleet composition that C29 changes on purpose. The operator approves by sending this prompt | amendment |

## FOR GEMINI

- **Q1.** Accept updating these four fixtures (new expected sums derived by
  hand below) rather than seeding the two NZDCHF magics at 0.0? Seeding at
  0.0 would keep the old numbers but would stop CM2 and RX3 proving that
  the NEW carriers are summed.

## BRANCH

`adr159-ea` from `58920fe`: `git fetch origin`, `git switch adr159-ea`,
`git pull --ff-only`, confirm HEAD is `58920fe`. ONE commit, pushed. No merge.

## CHANGES -- `ea/fxgrind_tests.mq5` ONLY

1. **`Grind_TestCapLegSeedHealthyAudChfFleet` AND
   `Grind_TestCapLegCleanupAudChfFleet`:** in BOTH, `chf_magics` becomes
   size 6: `{22260501UL, 22260502UL, 22260601UL, 22260602UL, 22260701UL,
   22260702UL}`. The cleanup must delete exactly what the seed sets. This
   alone fixes CL1 and CL2 (CHF total 6 x 0.02 = 0.12 plus 0.01, under the
   0.40 threshold). CL3 keeps passing: its stale `22260601` still blocks.
2. **`Test_CM2_CapSumIteratesLegCarryingMagics`:** the fixture list
   `expected` gains `22260701UL, 22260702UL` (size 18); both loops and both
   key arrays go from 16 to 18. Seeding stays `0.01 * (i + 1)`. Replace the
   comment and the expected value:
   `// CHF carriers are indices 8-11 and 16-17:`
   `//   0.09 + 0.10 + 0.11 + 0.12 + 0.17 + 0.18 = 0.77`
   `AssertNear("CM2 total", total, 0.77, 1e-9);`
3. **`Test_RX3_NzdLegSumIsolated`:** it already seeds every magic in the
   table. Replace the comment and the expected value:
   `// NZD carriers are indices 12-17, seeded 0.01*(i+1):`
   `//   0.13 + 0.14 + 0.15 + 0.16 + 0.17 + 0.18 = 0.93`
   `AssertNear("RX3 total", total, 0.93, 1e-9);`
4. **`Test_CL4_LegMembershipTableMatchesMagics`:** the first assert becomes
   `AssertTrue("CL4 magic count 18", ArraySize(GRIND_CAP_ALL_MAGICS) == 18);`

Change nothing else: no other test, no production file, no assertion name
other than CL4's.

**Commit message:** `ADR-159 EA fix 1: fleet-composition fixtures for 18 magics (CM2, CL1-CL2 helper, CL4, RX3)`

**Expected after the fix:** `SUMMARY: 1724/1724 passed` (the assertion
count is unchanged; CL4's assertion is renamed, not added).

## NEGATIVE SPACE

- Do NOT compile, run MetaTrader or the suite; the operator does.
- No `git add .` / `-u`, stash, amend, merge or PR. ASCII only.

## REPLY

ONLY the commit hash and the output of `git ls-remote origin adr159-ea`.

Line count: 68
