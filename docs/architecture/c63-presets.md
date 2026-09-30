This message has a line count at the bottom

# C63 -- LATTICE PRESETS FOR BOX 1 AND BOX 2 (DOCUMENT 2 OF 3)

Status: ACCEPTED by Gemini 29 Sep ~23:25Z (s5). Written by Claude, 29 Sep ~22:30Z, with the 22
preset files it describes in the same commit. Deployment plan:
`docs/architecture/c63-deploy.md` (document 1, Gemini GC63-1..4
accepted). Nothing is staged on a box by this document.

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| P1 | `main` has 37 inputs. `presets_b` lacks 8 of them (the six per-side `Inp*PipsLong/Short`, `InpVirtualLattice`, `InpSessionEnable`); `presets_c` lacks 2 (`InpVirtualLattice`, `InpSessionEnable`) | `ea/fxgrind.mq5` inputs vs `ea/presets_b`, `ea/presets_c` | VERIFIED |
| P2 | Whether MT5's Properties -> Load resets an input ABSENT from the `.set` file to its default, or keeps the chart's current value, is not verified. So every new preset states all 37 inputs | MT5 behaviour | UNVERIFIED (made irrelevant) |
| P3 | `OnInit` refuses lattice on with auto-eject on (FATAL) | `fxgrind.mq5` 210-211 | VERIFIED |

## 1. THE FILES

22 NEW files beside the old ones (the old files are the rollback,
c63-deploy.md s6, and stay staged on the boxes):
`ea/presets_b/<pair>_opt_b_lat.set` (9) and `<pair>_dup_b_lat.set` (2);
`ea/presets_c/<pair>_opt_c_lat.set` (9) and `<pair>_dup_c_lat.set` (2).
Each lists all 37 inputs in the code's declaration order, one per line,
ASCII, LF, `TelemetryAPIKey=` empty (the key is injected on the box at
staging, never in git: the CURRENT key, c63-deploy.md s11).

## 2. WHAT CHANGED FROM THE PRESET NOW LOADED

| key | box 1 (`presets_b` -> `_lat`) | box 2 (`presets_c` -> `_lat`) |
|---|---|---|
| `InpVirtualLattice` | (absent) -> `true` | (absent) -> `true` |
| `InpAutoEject` | `true` -> `false` | `true` -> `false` |
| `InpSessionEnable` | (absent) -> `false` (explicit) | (absent) -> `false` (explicit) |
| six `Inp{Width,Add,Exit}Pips{Long,Short}` | (absent) -> `-1.0` (inherit, explicit) | already `-1.0` |
| `InpConfigWarning` (label, reporting only) | `FLEET B C63 (IC Markets demo 53066709, box 1): main 0335f25, lattice on, auto-eject off` | `FLEET C C63 (IC Markets demo 53071896, box 2): main 0335f25, lattice on, auto-eject off` |

Nothing else differs (checked by script, every file): identity
(`InpMagic`, `InpSlot`, `InpTelemetryInstance`), geometry (width, add,
exit, cap), carry ON, commanded eject ON, `InpAutoEjectStableMinutes` 5
and `InpAutoEjectSpreadMult` 1.5 (inert with auto-eject off), breaker,
fill-time place, slot reserve, horizon, cap legs, telemetry lines.

## 3. CHECKS RUN (29 Sep, sandbox)

- For each of the 22: the set of changed keys against its source preset
  is exactly the table above (10 keys on box 1, 4 on box 2).
- Width, add, exit and cap equal the open row of the geometry register
  for that instance (22 of 22); no register row changes (c63-deploy.md
  A8).
- All 37 inputs present, no extra key, `TelemetryAPIKey` empty, ASCII.
- On the box at staging (current key): each staged file equal to the repo
  file except the key line (`SAME_EXCEPT_KEY`, as for B1 and Fleet C).

## 4. FOR GEMINI

- **GP-1.** Every input explicit (P2) rather than only the two lattice
  lines. Accept?
- **GP-2.** New files beside the old (rollback = load the old file, with
  the key the rotation leaves valid) rather than editing in place.
  Accept?
- **GP-3.** Lattice on the two ALT duplicates too (operator 26 Sep: all
  11 instances), so the same-account twin comparison becomes lattice vs
  lattice at different adds. Any objection?

## 5. GEMINI'S RULINGS (29 SEP ~23:25Z)

GP-1, GP-2 ACCEPTED; GP-3 no objection. Checked: sound. One premise in
GP-2 is off: rollback needs no git work on a box at all (the old presets
are already staged in `MQL5/Presets`). Staging uses the CURRENT key
(c63-deploy.md s11: the rotation is not part of C63).

Line count: 73
