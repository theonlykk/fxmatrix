This message has a line count at the bottom

# RUNBOOK -- START CYCLE 3 (ELEVEN INSTANCES: NINE PAIRS + TWO DUPLICATES)

Run this only after `docs/runbooks/account-close-out.md` and only when
the readiness gate below is met. **There is no deadline.** Cycle 3 is a
pre-registered measurement (`docs/architecture/geometry-cycle3.md`), and
every change that lands mid-cycle blends two regimes into one result.

Covers backlog A9 (deploy sequence) and B1 (F1 on a flat book).

---

## 0. READINESS GATE (desktop)

Start only when every line is ticked. Anything unticked is a reason to
wait, not to start and patch later.

- [ ] Account is flat and clean: close-out runbook finished, no EA
      attached, no `GRIND` GlobalVariable (F3).
- [ ] `main` holds everything intended for this cycle. Note the SHA:
      `________`. **After this point, no compile until the cycle ends**
      except for a defect.
- [ ] Suite on that SHA, run from `MQL5\Scripts\`: full total, no FAIL,
      on TWO chart symbols. Total: `________`.
- [ ] EA compiles on the desktop: `0 errors, 0 warnings`.
- [ ] Deploy SHA contains ADR-156: `Select-String -Path C:\fxmatrix\ea\grind_recon.mqh -Pattern tolerate_exit_shortfall`.
- [ ] Instruments in place (A2 point 8, A3):
      - [ ] ADR-159 live in pipshed (daily snapshot table, CRITICAL
            banner, migration `002` applied) and merged in the EA
      - [ ] ADR-160 floating-loss gate merged in the EA; its pipshed
            columns (`gated_seconds`, migration `003`) live
      - [ ] `TimeGMT()` on the VPS matches real UTC (ADR-158/159/160 take
            the FTMO day from it): `________`
- [ ] All eleven presets carry `InpEnableCarryPass=true`,
      `InpEnableCommandedEject=true`, `InpAutoEject=true`,
      `InpAutoEjectStableMinutes=5`, `InpAutoEjectSpreadMult=1.5`,
      `InpBreakerEnable=true` (A2 point 2, A3 point 6, backlog C35).
- [ ] Telemetry key decided: rotate now (backlog C9) or keep.
- [ ] `geometry-cycle3.md` still describes what is about to run; if the
      plan changed, amend the pre-registration FIRST (s8).

---

## 1. DEPLOY THE BUILD (VPS)

- [ ] `cd C:\fxmatrix; git fetch origin; git checkout <SHA from step 0>`
- [ ] `git log --oneline -1` shows that SHA.
- [ ] `.\deploy.ps1` -- sources into the terminal.
- [ ] `.\scripts\deploy_presets.ps1` -- presets, with the telemetry key
      injected. **Rotate the key here if doing backlog C9.**
- [ ] MetaEditor: open `Experts\fxmatrix\fxgrind.mq5`, F7:
      `0 errors, 0 warnings`.
- [ ] `fxgrind.ex5` timestamp is NOW (MetaEditor can skip a rebuild when
      only an include changed).
- [ ] Byte-check the terminal copy against the repo: every `.mq5`/`.mqh`
      identical, count matches.
- [ ] `git tag vps-<sha7> && git push origin vps-<sha7>`

---

## 2. ATTACH THE ELEVEN (VPS)

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
| AUDNZD (second chart) | `audnzd_dup.set` | 22260902 |
| NZDCAD (second chart) | `nzdcad_dup.set` | 22260802 |

For EACH, before OK:
- [ ] chart symbol matches the preset's pair
- [ ] `InpAddPips` / `InpExitPips` / `InpWidthPips` match the table in
      `geometry-cycle3.md` s3
- [ ] `InpLots` = 0.01
- [ ] carry, commanded eject and auto eject `true`; W `5`; k `1.5`;
      `InpBreakerEnable` `true`
- [ ] `TelemetryAPIKey` is NOT blank
- [ ] Experts tab: no `FATAL`, no `INIT_FAILED`

**Read every input back before OK** -- loading a preset silently resets
values typed before it. **Do NOT attach any `_alt` preset** (the cycle-2
ALT geometry). The two `_dup` presets ARE attached (A3): the OPT geometry
on the pair's ALT magic.

- [ ] All eleven attached, then **Algo Trading ON**. Note the start time,
      broker and UTC: `________`.

---

## 3. FIRST HOUR

- [ ] Status read within 5 minutes: **11 live**, 0 halted, all
      `recon_ok` / `invariant_ok`, API count near zero.
- [ ] Account figures show the NEW balance; distance to the loss floor
      is sensible.
- [ ] Each instance shows its L0 straddle resting at mid +/- width.
- [ ] **No `STARTUP_EXIT_SHORTFALL` line at the flat attach.** A flat
      book has no exits to miss; any such line is a defect to report.
- [ ] **F1, first live run (B1):** when any side reaches depth 2, BOTH
      the nearest (rank 0) and the most underwater layer (rank depth-1)
      have a resting exit; middle layers do not. Check the first such
      side by hand.
- [ ] First scalp: exit filled at entry +/- `InpExitPips`, CloseBy
      netted, scalp counted.
- [ ] Guard well below 194 (eleven instances, flat start).
- [ ] The first `DAILY_SNAPSHOT` arrives at the first FTMO roll (22:00Z
      in summer): check the pipshed Daily card.

---

## 4. DURING THE CYCLE

- **Exit and cap may not change** (I6/I7 halt). Add, width, stranded and
  deadband may -- see `geometry-cycle3.md` s5 and its amendment A1.
- **Every reattach or compile is a fleet restart.** ADR-156 makes a
  missing exit survivable, but check pipshed's `Covered` column first,
  work one instance at a time, and never near rollover.
- **Manual rolls:** `docs/runbooks/manual-roll.md`, and log every one in
  `docs/runbooks/roll-log.md`.

---

## 5. IF SOMETHING HALTS

Do NOT compile to clear it. Status URL plus the Experts lines around the
halt, then diagnose. A halt at startup on a flat book is a defect, not
a state to clear.

**Startup lines to know (ADR-156).** `WARN STARTUP_EXIT_SHORTFALL` means
startup found required exits missing and is placing them -- expected
after a manual roll, a defect signal otherwise. `CRITICAL
STARTUP_EXIT_SHORTFALL_SIDE` means a side had EVERY required exit
missing: investigate, but the EA keeps running and places them. A halt
on `I3_*_NAKED` a few seconds after startup means placement kept failing
(for example a close-only window): diagnose before reattaching.

Line count: 148
