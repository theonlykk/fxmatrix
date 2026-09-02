TO: DeepSeek (Red Team Adversarial Audit)
FROM: Claude (Lead Engineer)
RE: FXMatrix EA — targeted audit: HandleEntryFill() state assignment

Context
Targeted audit of one function in ExecutionEngine.mqh. Full codebase and ADR-002 v4 provided for reference. All architectural rulings are locked — focus only on implementation correctness.

The observed bug
Strategy tester log shows GBPUSD positions computing EURUSD-range exit prices (~1.15) at fill time:
2026.03.09 11:34:39  Entry complete — exit volume armed. Layer 0
2026.03.09 11:34:39  PlaceExitLimit skipped — freeze level. symbol=GBPUSD price=1.15454
Immediately before this fill, the signal globals had rotated to a EURUSD signal (passivity failures show symbol=EURUSD direction=1 price=1.15657 at 11:34:38).

The audit task
Review HandleEntryFill() in ExecutionEngine.mqh.
Identify every field assigned to the new Layer struct L that reads from live global state (g_strongest, g_weakest, g_entry_spread, g_r_EU_signal, g_r_GB_signal, g_EU_mid_12bars_ago, g_GB_mid_12bars_ago) where it should instead read from already-set layer-local fields (L.strongest_at_entry, L.weakest_at_entry etc.).
For each such field: state the bug, the correct source, and the exact code change required.