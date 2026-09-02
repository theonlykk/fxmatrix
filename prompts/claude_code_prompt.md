Analyse the FINAL run only in logs/20260608_backtest_inheritance.log. You have permission to proceed with all file reading and analysis operations without asking for confirmation. Do not ask for confirmation at any step.

Identify the final run by finding the last occurrence of "FXMatrix EA initialised" and analyse only from that point forward.

This run produced +$78.40 net profit, profit factor 12.88, 37 trades (20 long, 17 short), 86.49% win rate. The Layer 0 inheritance fix was applied — Layer N+ now inherits anchor/routing state from Layer 0 instead of reading stale globals.

Give me:
1. Did CloseBy fire successfully across ALL layers this time? How many times total? Break down by layer.
2. Did the pod reach fully flat at any point intra-test? If yes, what was the balance at that moment?
3. Per-layer exit status — confirm all 5 layers now have correct GBPUSD exit prices (~1.33 range). Show the exit prices placed for each layer.
4. Did the carry module run cleanly through June 5 with no errors?
5. Are there any remaining ERROR lines?
6. What is the theoretical P&L ex-swap vs actual — how much of the gap remains?
7. Are the MaxLayers overflow warnings still occurring? How many unmanaged positions remain at end of test?
8. What are the remaining structural issues in priority order — specifically the instrument/direction fields still using live globals (flagged by Cursor) and any other issues.

Context: EUR=0, GBP=1, USD=2. Direction 1=BUY, -1=SELL. ExitFraction=0.70. Layer inheritance fix applied this run.