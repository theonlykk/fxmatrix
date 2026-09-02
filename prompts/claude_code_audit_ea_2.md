Re-read all files in d:\fxmatrix\ea\ fresh from disk. Do not use cached content. Do not implement anything — audit and report only.
Run a Gate 3 audit across three objectives. Report exact file, line numbers, and PASS / WARNING / FATAL per objective.
Objective 1 — Serialization (StateEngine.mqh + LayerStruct.mqh)

Trace SaveAllInventoryState() and LoadInventoryState(). Does the JSON serializer correctly write and reconstruct the nested dynamic ulong exit_tickets[] array inside each Layer struct? If reconstruction fails, would AuditExitLimits() place duplicate exit limits on top of already-resting orders?
Objective 2 — Forward Carry Integration (MathEngine.mqh + CarryEngine.mqh)

Does ComputeExitPrice() use entry_spread_adjusted (carry-modified) or entry_spread_raw (static)?
Does RunCarryRecalculation() modify entry_spread_adjusted over time based on yield differentials?
After carry updates the exit spread target, does anything call OrderModify() to physically move the resting exit limit? Or does the new target only apply if the exit limit is re-placed?
Can carry make entry_spread_adjusted positive, causing ComputeExitPrice() to return an invalid price?

Objective 3 — Volume Floor (Globals.mqh + ExecutionEngine.mqh)

What is VOLUME_EPSILON and where is it defined?
Is it safely calibrated against the broker minimum lot step (0.01 lots at FTMO)?
Can remaining_entry_volume or remaining_exit_volume get stuck above VOLUME_EPSILON due to floating-point subtraction error?