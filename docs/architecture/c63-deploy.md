This message has a line count at the bottom

# C63 -- DEPLOYMENT PRE-REGISTRATION: MAIN + LATTICE ON BOX 1 AND BOX 2 (THURSDAY 1 OCT)

Status: DRAFT for Gemini (document 1 of 3 before C63; 2 = lattice
presets, 3 = key rotation and the step-by-step runbook). Written by
Claude from source at `main` `013b5c2` (EA == `0335f25`), 29 Sep ~22:10Z.
Nothing is deployed by this document. Amends `fleet-b.md` (B2) and
`fleet-c.md` (A2), which point here.

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | `main` `0335f25` = v2.1 (per-side inputs, ADR-163 rebuild at start) + ADR-162 lattice + ADR-164 replay + C77; suite 2368/2368 on GBPUSD and EURUSD at `97a2cd1` (same EA tree) | HANDOFF s22 | VERIFIED |
| A2 | Box 1 (Fleet B) runs `5685e4f`; box 2 (Fleet C) runs `e2ac9fe` (v2.1 without ADR-164) | BOOT s6; fleet-c.md s1 | VERIFIED in the docs; box repos to be re-read on the day |
| A3 | `OnInit` refuses `InpVirtualLattice=true` with `InpAutoEject=true` (FATAL) | `fxgrind.mq5` 210-211 | VERIFIED in source |
| A4 | The effective entry reads a stored VL whatever `InpVirtualLattice` says, so a rolled layer stays consistent under I6 with the lattice switched off again | `grind_carry.mqh` 662-664 | VERIFIED in source |
| A5 | `CopyTicksRange(COPY_TICKS_INFO)` (the lattice's catch-up read) was probed on box 1 only (26 Sep, ADR-162 s16); never on box 2 | ADR-162 s16; `scripts/grind_tick_probe.mq5` (read-only, safe beside live EAs) | VERIFIED |
| A6 | Box 1 has never run v2.x: no `GRIND_GEO_EXIT_<magic>_L/_S` labels exist there, so its first v2.1 init is STRICT (no rebuild) and writes the labels (ADR-163 s9). Its exits were priced by `5685e4f` with the same formula at the same exit | ADR-163 s4 D1, s9; geometry register (exits unchanged since 24 Sep) | VERIFIED in source 29 Sep: `Grind_ExitQFormulaTarget`, `Grind_ExitPrice`, `Grind_ReconExitMatchesEntry` and `Grind_CarryShiftGetForRecon` are identical at `5685e4f` and `0335f25`; the carry GV names are the same (`main` adds only `GRIND_GEO_EXIT_`); the short side checks the resolved `exit_s` (= the base at -1); the rebuild tolerance needs a label that exists and differs (none on box 1). The strict pass is INFERRED from that, not run (GC63-4) |
| A7 | A compile reinitialises every attached instance with its CURRENT inputs; an input change is a reason-5 reinit of that chart only | BOOT s3; 02_TRAPS 28 Sep | VERIFIED |
| A8 | No geometry changes at C63: width, add, exit and cap stay as in the register | `10_GEOMETRY_REGISTER.md` | VERIFIED |

## 1. WHAT CHANGES

| | Box 1 = Fleet B (IC 53066709) | Box 2 = Fleet C (IC 53071896) | VPS = cycle 3 (FTMO) |
|---|---|---|---|
| Code | `5685e4f` -> `0335f25` (first time on `main`) | `e2ac9fe` -> `0335f25` (adds ADR-164 and C77 only) | none: `5685e4f`, frozen (A4 of cycle 3) |
| Inputs | `presets_b` + `InpVirtualLattice=true` + `InpAutoEject=false` + the NEW key | `presets_c` + the same two lines + the NEW key | the NEW key only (document 3) |
| At cap | rolls (ADR-162) instead of ejecting | rolls | keeps ejecting (ADR-157): the comparison |
| Unchanged | geometry, cap, carry ON, commanded eject ON (the only manual tool for a `ROLL_STRANDED` side), breaker, gate, session OFF | same | everything but the key |

## 2. PRECONDITIONS (all met before the first compile on Thursday)

- **P1** Box 2 tick probe: `grind_tick_probe.mq5` on a spare chart (VNC),
  nine symbols, `err=0` and ticks on each (A5). Wednesday.
- **P2** Lattice presets committed and byte-checked for both boxes
  (document 2), staged on each box with the new key.
- **P3** Key rotation ordered so no instance loses telemetry longer than
  its own reload (document 3: whether pipshed can accept two keys at
  once decides the order).
- **P4** Desktop suite green at the deployed EA tree (MET: 2368/2368).
- **P5** GUI on both boxes over VNC (MET 28 Sep; box 2 RDP still broken).
- **P6** In session, every spread well under its pair's width, outside
  the carry window (20:50-21:00Z), not within 30 min of a tier-1 release;
  never with the market closed.

## 3. SEQUENCE (per box: CODE first, then INPUTS)

**Order of boxes: box 2 first, then box 1** (proposal; operator
decides, GC63-2). Box 2 is the probe fleet and its code step is the
smaller one (v2.1 -> v2.1 + ADR-164); box 1 carries the anchor and the
larger step.

**Stage 1 -- code.** On the box: pull `main` into the box repo, copy
`ea/*.mq5 ea/*.mqh` into `Experts/fxmatrix` and `Scripts/fxmatrix`,
`cmp` every file, compile `fxgrind.mq5` in the MetaEditor GUI. The
compile reinitialises all eleven with their CURRENT inputs (lattice
off, auto-eject on): a code check under known inputs, as Fleet C's
phase 1 was (A7). Never run the suite on a box with live EAs. Watch
10 minutes; card 11/11.

**Stage 2 -- inputs.** Chart by chart, GBPUSD first as the pilot:
Properties, Load the lattice preset, read EVERY input back before OK
(identity and magic first on the twin charts; the key row is read, never
screenshotted), OK. The pilot's check lines before the other ten.

## 4. PASS LINES (Experts log, per instance)

Stage 1 (compile): `deinit` at the compile second; CONFIG; `GRIND_GEOMETRY`
on both sides equal to the register (four decimals); `GRIND_LATTICE
enable=false`; `GRIND_SESSION enable=false`; `GRIND_REBUILD long=false
short=false`; `GRIND_REPLAY ready seeded=<n>`; clean reconstruction;
`grind telemetry POST ok`. Box 1 only: two spot checks in Tools ->
Global Variables for `GRIND_GEO_EXIT_<magic>_L` and `_S` equal to the
exit (the labels written by the first v2.1 init).

Stage 2 (reload): `deinit reason=5`; CONFIG with the new inputs;
`GRIND_LATTICE enable=true` and the `LATTICE_CONFIG` marker; `GRIND_REBUILD
long=false short=false`; `GRIND_REPLAY ready`; POST ok with the new key.

After each box: card LIVE 11/11, no red; that night's `--carrypass` reads
33/33 with no I6.

## 5. STOP (stop before the next chart; bring it to the chat; no blind reattach)

FATAL (including `InpVirtualLattice requires InpAutoEject=false` and
duplicate magic), CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`,
`REBUILD_EXIT_FAILED`, `GRIND_REBUILD` true on either side (the exit did
not change, so true means a label or exit mismatch), `STARTUP_EXIT_SHORTFALL`,
`REPLAY_INIT_DEFERRED` (in session it means the terminal had no server
time), a `GRIND_GEOMETRY` value different from the register, or no POST ok.

## 6. ROLLBACK (inputs, not code)

Reload the chart from its PREVIOUS preset (lattice off, auto-eject on;
the old key if the rotation is what failed). No recompile: `main` honours
the VLs of layers already rolled (A4), and ADR-164 stays. Recompiling
`5685e4f` on box 1 is kept only for a fault in `main` itself; it also
reads VLs (ADR-162 Phase A) but drops ADR-164 and the rebuild labels'
meaning. Every rollback is recorded here with its time.

## 7. WHAT IS WATCHED AFTERWARDS (roadmap s8.12 step 4: a few days)

- Rolls on B and C: `ROLL_*` rows and minutes to fill (`/ejection`),
  `ROLL_STRANDED` and `ROLL_CLOSING_STUCK` WARNs (the first live lattice
  anywhere); ejections on B and C only by command.
- A (still ejecting) vs B and C (rolling): closed P&L, carried MTM at the
  FTMO roll, scalps per pair; the study scores rolls the same way as
  ejections.
- ADR-164: `DEAL_EVENT_MISSED` (the fault signal) and `DEAL_REPLAYED`
  counts per instance (`--codes`); expected: some `path:timer` replays.
- Geometry register: no rows at C63 (A8).

## 8. KNOWN LIMITS

- The FTMO VPS keeps the C76 gap until cycle 3 ends (`5685e4f`).
- Box 1's first v2.1 init runs on an inherited book (Fleet C started
  flat): the strictest step of the day (GC63-4).
- The lattice has never run live; B and C switch on the same day, by
  design (roadmap s8.12 step 3: the two boxes stay matched).
- Quarantine noise (C74) will continue to show amber.

## 9. FOR GEMINI

- **GC63-1.** Two stages per box (compile under the current inputs, then
  reload with the lattice preset) rather than staging presets first and
  letting the compile pick them up (it does not: a compile keeps each
  chart's inputs, A7). Accept?
- **GC63-2.** Box 2 before box 1. Any reason to reverse it?
- **GC63-3.** Rollback by inputs (A4), not by recompiling `5685e4f`. Accept?
- **GC63-4.** Box 1's first v2.1 init is strict I6 on a book priced by
  `5685e4f` (same formula, same exit, carry shifts and accruals from the
  nightly pass). Any path where v2.0/v2.1 prices an existing resting exit
  differently from `5685e4f` at the SAME inputs (per-side resolution to
  -1, `Grind_SidePips`, the carry pass's per-side work base)? Claude
  compared the four functions in both builds (A6) and finds none;
  please check the premise, not only the conclusion.

Line count: 140
