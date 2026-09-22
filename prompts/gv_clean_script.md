This message has a line count at the bottom

# SPEC -- scripts/grind_gv_clean.mq5 (account-switch GlobalVariable clean-up)

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Purpose | Delete the fleet's PERSISTENT GlobalVariables when switching the VPS terminal to a new account. Used once per cycle | runbook `docs/runbooks/account-close-out.md` s4 |
| Names | every name below verified in `ea/` at fxmatrix `bd76f14` | Claude |
| Baseline | fxmatrix `origin/main` at `bd76f14` | read by Claude |
| Scope | ONE new file `scripts/grind_gv_clean.mq5`. No EA change | this spec |

## BRANCH

`feat/grind-gv-clean` from `origin/main`. Two commits (script; response
doc). Push. Do NOT merge. Do NOT open a PR.

## DESIGN

An MQL5 **script** (`#property script_show_inputs`) with ONE input:

    input bool InpForce = false;   // bypass the running-fleet guard

**1. Refuse if the fleet may be running -- by EXISTENCE, not by time.**
`GRIND_MAE_REPORTER_HEARTBEAT` is created with `GlobalVariableTemp`
(`ea/grind_mae.mqh:256`), so a terminal restart deletes it, and the
runbook restarts the terminal before this script runs. Therefore:

    if(GlobalVariableCheck("GRIND_MAE_REPORTER_HEARTBEAT") && !InpForce)
    {
       Print("grind_gv_clean: ABORT -- GRIND_MAE_REPORTER_HEARTBEAT exists. ",
             "Detach all fxgrind EAs, CLOSE and reopen the terminal, then run again. ",
             "Use InpForce=true ONLY if all EAs are detached, the terminal has been ",
             "restarted, and the variable still exists.");
       return;
    }

**Do NOT compare against any clock.** `TimeCurrent()` freezes when no
ticks arrive (weekends, disconnects), so a time-based guard would abort
falsely. `GlobalVariableTime()` returns last ACCESS time, which a read can
refresh. Existence after a restart is unambiguous.

If `InpForce` is true and the heartbeat exists, `Print` a WARNING line
naming it, then proceed.

**2. Delete by prefix**, each with `GlobalVariablesDeleteAll(prefix)`,
in this order, printing each prefix and the count it returned:

    "GRIND_DAILY_API_COUNT"
    "GRIND_DAILY_API_DATE"
    "GRIND_MAE_ANCHOR_"
    "GRIND_MAE_EQUITY_LOW_"
    "GRIND_CARRY_DAY_"
    "GRIND_CARRY_SHIFT_"
    "GRIND_CARRY_ACCRUED_"
    "GRIND_CARRY_RELEASE_"
    "GRIND2226_"
    "GRIND_DEINIT_"

**3. Report what survives.** Loop `GlobalVariablesTotal()` /
`GlobalVariableName(i)`; `Print` every remaining name that starts with
`GRIND`. Then `Print` `"grind_gv_clean: DONE deleted=<total> remaining_grind=<n>"`.

## NEGATIVE SPACE

- Delete ONLY the ten prefixes above. Do NOT call
  `GlobalVariablesDeleteAll()` with no argument or with `"GRIND"` alone.
- Never touch `V2_*` or any non-`GRIND` variable.
- No trading calls: no `OrderSend`, `PositionClose`, `CTrade`.
- Do NOT modify anything under `ea/`.
- Do NOT CLI compile, launch MetaTrader or run the script. The operator
  compiles and runs it.
- Stage by exact path. ASCII only.

## FAILURE MODES -- STOP AND REPORT

- Any prefix above does not appear anywhere in `ea/` (grep it): STOP and
  report which. The list was built from source; a miss means it is wrong.
- Any OTHER persistent `GlobalVariableSet` target under `ea/grind_*.mqh`
  not covered by these prefixes: STOP and list it. Temporary ones
  (`GlobalVariableTemp`) are excluded: the terminal restart clears them.

## RESPONSE FORMAT

`prompts/gv_clean_script_response.md`: commit hashes AS THEY EXIST ON
ORIGIN, the diff stat, the grep evidence for each prefix, and a true line
count in the footer. Reply in chat with ONLY the branch name, the hashes,
and one line saying it is pushed.

Line count: 91
