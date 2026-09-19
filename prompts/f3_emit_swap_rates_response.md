This message has a line count at the bottom

# F3: Emit swap rates in heartbeat -- response

Branch: feat/f3-emit-swap-rates from origin/main (F2 merged at 5454358).
Telemetry only; no engine, carry, recon, preset, or ADR changes.

## Commits

1. bacb777 -- F3-1..F3-3 tests + Grind_HeartbeatTestSeedSwapRates hooks
2. bd11252 -- swap fields in Grind_HeartbeatBuildLayerDetailJson

## Nullable helper (unquoted %s slots)

string Grind_HeartbeatNullableSwapPointsJson(const double value,
                                             const bool points_mode)
{
   if(!points_mode)
      return "null";
   return DoubleToString(value, 2);
}

## StringFormat block (Grind_HeartbeatBuildLayerDetailJson, full)

   return StringFormat(
      "\"layers\":%s,"
      "\"l0_pending_long\":%s,\"l0_pending_long_comment\":%s,"
      "\"l0_pending_short\":%s,\"l0_pending_short_comment\":%s,"
      "\"add_pending_long\":%s,\"add_pending_long_comment\":%s,"
      "\"add_pending_short\":%s,\"add_pending_short_comment\":%s,"
      "\"resting_entries_long\":%d,\"resting_entries_short\":%d,"
      "\"swap_long_points\":%s,\"swap_short_points\":%s,\"swap_rate_mult\":%d",
      Grind_HeartbeatLayersJson(magic, digits),
      Grind_HeartbeatNullablePriceJson(g_grind_long.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_long.l0_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_short.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_short.l0_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_long.add_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_long.add_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_short.add_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_short.add_pending_ticket, magic),
      Grind_HeartbeatCountRestingEntries(magic, "L"),
      Grind_HeartbeatCountRestingEntries(magic, "S"),
      Grind_HeartbeatNullableSwapPointsJson(swap_long_points, swap_points_mode),
      Grind_HeartbeatNullableSwapPointsJson(swap_short_points, swap_points_mode),
      Grind_HeartbeatSwapRateMult()
   );

Specifiers: layers/l0/add/resting use existing mix; swap_long_points %s,
swap_short_points %s (no quotes around slots); swap_rate_mult %d. Argument
count matches.

## Swap sources

Live: SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG/SHORT) signed, no MathAbs.
SYMBOL_SWAP_MODE must be SYMBOL_SWAP_MODE_POINTS else both swap fields emit
null via helper.

Tests: Grind_HeartbeatTestSeedSwapRates injects values when
g_grind_heartbeat_test_swap_active.

## swap_rate_mult (derived, not a direct MT5 per-day API)

MQL5 exposes SYMBOL_SWAP_ROLLOVER3DAYS (weekday index of triple day), not
today's multiplier integer. Derived in Grind_HeartbeatSwapRateMult:

- Time function: TimeCurrent() (broker/session clock), NOT TimeLocal().
- TimeToStruct into MqlDateTime; day_of_week from that struct.
- rollover3days from SymbolInfoInteger(_Symbol, SYMBOL_SWAP_ROLLOVER3DAYS) or
  test hook.
- Saturday/Sunday (0,6): emit 1.
- If day_of_week == rollover3days: emit 3.
- Else: emit 1.

Test hook can set broker_time and rollover3days for deterministic mult tests
(future); F3-1 only asserts field presence.

## Expected failures on unfixed code (commit 1 only)

| Test | Unfixed |
|------|---------|
| F3-1 | FAIL -- keys absent |
| F3-2 | FAIL -- keys absent or wrong sign |
| F3-3 | PASS -- JSON structure unchanged aside from missing new keys |

## Self-review

- No grind_carry.mqh, grind_engine.mqh, grind_exitq.mqh, grind_recon.mqh changes.
- Deleted-assert grep empty (adr151 untouched).

Deleted-assert grep:

  git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"
  (empty)

git diff --stat origin/main...feat/f3-emit-swap-rates:

 ea/fxgrind_tests.mq5          | 37 ++++++++++++++++++++
 ea/grind_heartbeat_detail.mqh | 81 +++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 118 insertions(+)

Line count: 102
