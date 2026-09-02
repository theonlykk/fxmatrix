### No Recompile or Reattach on a Live/Demo Instance Unless the Chart Is Confirmed Flat

**Finding:** `OnInit` does not rebuild an EA's internal layer-tracking
state from actual broker positions on restart. If an EA is
recompiled, reloaded, or reattached while it holds open positions, the
existing orphan-detection guard halts the instance outright rather
than reconstructing state from broker truth. This requires manual
intervention to recover — it is not a momentary accuracy gap, it is a
full stop of that instance's trading.

Every production deployment prior to this rule's adoption succeeded
only because the affected chart happened to be flat at the exact
moment of reattach — this was never a checked precondition, and
should not be relied upon as one.

**Rule:** No recompile, reload, or reattach cycle may be executed on
any live or demo trading instance unless the target chart is confirmed
**100% flat** — zero open positions AND zero pending orders — at the
time of the action. This applies regardless of how small or
"logic-free" the change being deployed is (a pure logging addition is
not exempt).

**Backlog reference:** see **Parked Backlog → State Reconstruction
Engine** below. Until that initiative exists, the flat-chart
precondition is the operative safeguard and should not be skipped even
under time pressure or for changes believed to be low-risk.

### VPS Live Deployment Sequence

1. Confirm the account is 100% flat — zero open positions, zero
   pending orders, across all three instances.
2. Turn AlgoTrading off.
3. Delete any resting limit orders manually if present.
4. Detach the EA(s) from their chart(s).
5. Run `deploy.ps1`.
6. Compile in MetaEditor.
7. Turn AlgoTrading back on.
8. Reattach the EA(s).

This sequence, and the flat-chart precondition specifically, governs
VPS/live-demo instances only — see Machine Topology above for why
desktop compiling is exempt.
