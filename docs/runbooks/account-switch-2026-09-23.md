This message has a line count at the bottom

# RUNBOOK -- ACCOUNT SWITCH AND CYCLE-3 DEPLOY, WEDNESDAY 2026-09-23

Covers backlog A7 (GlobalVariable clean-up), A9 (deploy sequence) and B1
(F1 on a flat book). Pre-registration: `docs/architecture/geometry-cycle3.md`.

Work top to bottom. **Do not skip the checks** -- each one exists because
something went wrong once. Tick as you go.

---

## 0. BEFORE WEDNESDAY (desktop)

- [ ] `main` contains the build to deploy (currently F1 + ADR-153 + the
      suite fix). Note its SHA: `________`.
- [ ] Suite on that SHA, run from `MQL5\Scripts\`: **1387/1387** (or the
      then-current total), on TWO chart symbols.
- [ ] `scripts/grind_gv_clean.mq5` exists on `main` (spec:
      `prompts/gv_clean_script.md`) and compiles on the desktop.
- [ ] New account credentials from MetriX: login, password, **server
      name exactly as FTMO gives it**.

---

## 1. CLOSE OUT THE OLD ACCOUNT (VPS)

- [ ] Take a final status read (fresh URL segment). Save it: final MTM,
      positions, orders, scalps. This is the cycle-2 record.
- [ ] **Algo Trading OFF** (toolbar). Nothing can be sent from here on.
- [ ] Remove the EA from all 16 charts. Each deinit writes
      `GRIND_DEINIT_*` records -- they are cleaned in step 3.
- [ ] Confirm in the Experts tab: 16 deinit lines, no errors.

The old account's positions and orders stay where they are. Nothing
further is done to them.

**Order matters: detach BEFORE switching login.** An EA still attached
when the account changes reinitialises on the new account and starts
quoting with the old build and the old presets.

---

## 2. SWITCH ACCOUNT (VPS)

- [ ] File -> Login to Trade Account: new login, password, server.
- [ ] Toolbox -> Trade: balance as expected, **zero positions, zero
      orders**. A flat book is what makes F1 and the new exits safe.
- [ ] Note the switch time, broker and UTC: `________`. Pipshed does not
      yet separate accounts (backlog A5); this time is how the two cycles
      get told apart.

---

## 3. CLEAR PERSISTENT GLOBALVARIABLES (VPS)

**Close the terminal completely, then reopen it.** That deletes every
`GlobalVariableTemp` variable: `GRIND_SLOT_LOCK`, `GRIND2226_CAS_LOCK`,
`GRIND2226_MAGIC_LOCK_*`, `GRIND_MAE_REPORTER_HEARTBEAT` / `_MAGIC` /
`_CLAIM_LOCK`.

The PERSISTENT ones survive a restart and must be deleted. With Algo
Trading still OFF and NO EA attached, run the script
`grind_gv_clean` (Scripts). It deletes exactly these prefixes:

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

## 4. DEPLOY THE BUILD (VPS)

- [ ] `cd C:\fxmatrix; git fetch origin; git checkout <SHA from step 0>`
- [ ] `git log --oneline -1` shows that SHA.
- [ ] `.\deploy.ps1` -- sources into the terminal.
- [ ] `.\scripts\deploy_presets.ps1` -- presets, with the telemetry key
      injected. **Rotate the key here if doing backlog C9.**
- [ ] MetaEditor: open `Experts\fxmatrix\fxgrind.mq5`, F7:
      `0 errors, 0 warnings`.
- [ ] `fxgrind.ex5` timestamp is NOW (MetaEditor can skip a rebuild when
      only an include changed).
- [ ] Byte-check the terminal copy against the repo, as done for
      `5454358`: every `.mq5`/`.mqh` identical, count matches.
- [ ] `git tag vps-<sha7> && git push origin vps-<sha7>`

---

## 5. ATTACH THE NINE (VPS)

Algo Trading still OFF. For each pair: open a chart (M5), drag `fxgrind`
on, **Load** the preset, check the inputs, OK.

| chart | preset | magic |
|---|---|---:|
| GBPUSD | `gbpusd_opt.set` | 22260101 |
| EURUSD | `eurusd_opt.set` | 22260201 |
| EURGBP | `eurgbp_opt.set` | 22260301 |
| AUDCAD | `audcad_opt.set` | 22260401 |
| AUDCHF | `audchf_opt.set` | 22260501 |
| CADCHF | `cadchf_opt.set` | 22260601 |
| NZDCHF | `nzdchf_opt.set` | 22260701 |
| NZDCAD | `nzdcad_opt.set` | 22260801 |
| AUDNZD | `audnzd_opt.set` | 22260901 |

For EACH, before OK:
- [ ] chart symbol matches the preset's pair
- [ ] `InpAddPips` / `InpExitPips` / `InpWidthPips` match the table in
      `geometry-cycle3.md` s3
- [ ] `InpLots` = 0.01
- [ ] `TelemetryAPIKey` is NOT blank
- [ ] Experts tab: no `FATAL`, no `INIT_FAILED`

**Do NOT attach any `_alt` preset.** Cycle 3 is one arm per pair.

- [ ] All nine attached, then **Algo Trading ON**.

---

## 6. FIRST HOUR

- [ ] Status read within 5 minutes: **9 live**, 0 halted, all
      `recon_ok` / `invariant_ok`, API count near zero.
- [ ] Account figures show the NEW balance; distance to the loss floor
      is sensible.
- [ ] Each instance shows its L0 straddle resting at mid +/- width.
- [ ] **F1, first live run (B1):** when any side reaches depth 2, BOTH
      the nearest (rank 0) and the most underwater layer (rank depth-1)
      have a resting exit; middle layers do not. Check the first such side
      by hand.
- [ ] First scalp: exit filled at entry +/- `InpExitPips`, CloseBy
      netted, scalp counted.
- [ ] Guard well below 194 (nine instances, flat start).

## 7. IF SOMETHING HALTS

Do NOT compile to clear it. Status URL plus the Experts lines around the
halt, then diagnose. A halt at startup on a flat book is a defect, not
a state to clear.

Line count: 150
