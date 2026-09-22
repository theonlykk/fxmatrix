This message has a line count at the bottom

# RUNBOOK -- CLOSE OUT THE OLD ACCOUNT (CYCLE 2)

Ends cycle 2 and leaves the VPS terminal flat, clean and idle. **Starting
cycle 3 is a separate runbook** (`docs/runbooks/cycle3-start.md`) and has
no deadline: the gap is deliberate, so the code is finished before a
pre-registered measurement begins.

Covers backlog A7 (GlobalVariable clean-up). Work top to bottom. **Do not
skip the checks** -- each one exists because something went wrong once.

---

## 0. BEFORE STARTING (desktop)

- [ ] `scripts/grind_gv_clean.mq5` exists on `main` (spec:
      `prompts/gv_clean_script.md`) and compiles on the desktop.
- [ ] New account credentials from MetriX in hand: login, password,
      **server name exactly as FTMO gives it**.

---

## 1. RECORD CYCLE 2 (VPS)

- [ ] Final status read (fresh URL segment). Save it whole: final MTM,
      positions, orders, scalps per instance.
- [ ] From the terminal: **balance, equity, and the day's swap**. Equity
      against the 10,000 start is cycle 2's result -- realised P&L alone
      is not (it counts only winners; see backlog C24).
- [ ] Note the figures here: equity `________`, balance `________`,
      open MTM `________`.

---

## 2. DETACH (VPS)

- [ ] **Algo Trading OFF** (toolbar). Nothing can be sent from here on.
- [ ] Remove the EA from all 16 charts. Each deinit writes
      `GRIND_DEINIT_*` records -- they are cleaned in step 4.
- [ ] Confirm in the Experts tab: 16 deinit lines, no errors.

The old account's positions and orders stay where they are. Nothing
further is done to them.

**Order matters: detach BEFORE switching login.** An EA still attached
when the account changes reinitialises on the new account and starts
quoting with the old build and the old presets.

---

## 3. SWITCH ACCOUNT (VPS)

- [ ] File -> Login to Trade Account: new login, password, server.
- [ ] Toolbox -> Trade: balance as expected, **zero positions, zero
      orders**.
- [ ] Note the switch time, broker and UTC: `________`. Pipshed does not
      yet separate accounts (backlog A5); this time is how the two cycles
      get told apart.

---

## 4. CLEAR PERSISTENT GLOBALVARIABLES (VPS)

**Close the terminal completely, then reopen it.** That deletes every
`GlobalVariableTemp` variable: `GRIND_SLOT_LOCK`, `GRIND2226_CAS_LOCK`,
`GRIND2226_MAGIC_LOCK_*`, `GRIND_MAE_REPORTER_HEARTBEAT` / `_MAGIC` /
`_CLAIM_LOCK`.

The PERSISTENT ones survive a restart and must be deleted.

- [ ] Copy the script into the terminal -- `deploy.ps1` does NOT carry the
      repo's `scripts\` folder:
      `Copy-Item C:\fxmatrix\scripts\grind_gv_clean.mq5 "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Scripts\" -Force`
      then compile it in MetaEditor (`0 errors, 0 warnings`).
- [ ] With Algo Trading still OFF and NO EA attached, run
      `grind_gv_clean` from the Navigator's Scripts, `InpForce` left
      false. If it prints ABORT, the terminal was not restarted -- restart
      and run again. It deletes exactly these prefixes:

| prefix | what it is | why it must go |
|---|---|---|
| `GRIND_DAILY_API_COUNT`, `GRIND_DAILY_API_DATE` | the shared daily request counter | FTMO counts per ACCOUNT; the old count would throttle the new account on day one |
| `GRIND_MAE_ANCHOR_`, `GRIND_MAE_EQUITY_LOW_` | the day's starting balance and equity low | the distance to the daily-loss floor would be measured from the OLD account's balance |
| `GRIND_CARRY_DAY_` | carry pass gate, per magic | stale day stamp |
| `GRIND_CARRY_SHIFT_`, `GRIND_CARRY_ACCRUED_`, `GRIND_CARRY_RELEASE_` | per-position exit offsets | keyed by the OLD account's tickets; dead weight, and a release flag bypasses the bound check if a ticket number ever repeats |
| `GRIND2226_` | cap exposure per magic and leg, plus `_time` | the old book's exposure |
| `GRIND_DEINIT_` | deinit reason/time/anchor per magic | the old fleet's shutdown records |

- [ ] Script prints its count of deleted variables and `DONE`.
- [ ] F3 (Global Variables): **no `GRIND` entry remains.** `V2_*`
      entries are old and harmless.

---

## 5. LEAVE IT IDLE

- [ ] No EA attached on any chart.
- [ ] **Algo Trading OFF.**
- [ ] VPS left running (the terminal stays logged in to the new,
      flat account).

The terminal can sit like this indefinitely. Nothing quotes, nothing
accrues. Cycle 3 starts only when `cycle3-start.md`'s readiness gate is
met.

- [ ] Record the close-out in the next handoff: cycle 2's equity result,
      the switch time, and the deleted-variable count.

Line count: 110
