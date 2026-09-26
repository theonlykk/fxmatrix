This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-26 ~22:00Z (SATURDAY)

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Read, in order:
`handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` s16 and
ALL of s17 (four parts, 25-26 Sep); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-09-25 or 2026-09-26;
`handoffs/Handover/08_BACKLOG.md`; `docs/architecture/ADR-162-virtual-lattice.md`
s13-s18; `docs/architecture/cycle4-live-geometry-search.md` s8 (rev 3);
`docs/architecture/fleet-b.md`; `docs/architecture/geometry-cycle3.md` A6;
`docs/architecture/ARCHITECT.md` s10; `handoffs/Handover/03_COOKBOOK.md`
(live state, `/ejection`, archive); `handoffs/Handover/06_LINUX_WINE_BOX.md`
s4 and s7; then this. Verify HEADs in git first.

---

## 0. THE SINGLE MOST IMPORTANT FACTS

**Both fleets run `5685e4f` (C52); the market is CLOSED until Sunday 17:00
ET (21:00Z).** `main`'s EA is `669da60`: ADR-162 COMPLETE, lattice default
OFF, deployed nowhere.

**Passive ejection is the operator's priority**, and the next step is
**C63: the lattice on Fleet B** (all 11 instances, `InpAutoEject=false`,
commanded eject ON, cycle 3 stays on ADR-157 as the comparison), on a
Tuesday or Thursday DURING the session. Both preconditions are met: the
tick probe (ADR-162 s16) and C56 telemetry (s18). Box 1 must compile
`main` BEFORE any lattice preset is loaded: `5685e4f` has no
`InpVirtualLattice`, so a lattice preset there = auto-eject off, no lattice.

**Read what the fleet did from pipshed, not logs** (C56, live, verified):

    https://linux.pipshed.com/api/g/k7m9p2x4q/ejection/a1?hours=96

(change the last path segment every fetch; `pipshed.com` for cycle 3;
503 = view missing or stale, never zero). Every roll and ejection, closed
P&L per instance, side and FTMO day from the broker ledger, live depth.

**Cycle 4 direction** (operator, 26 Sep; `cycle4-live-geometry-search.md`
s8): a NEW EA with add and exit PER SIDE; three IC fleets with the SAME
pairs and different settings (fleet 1 anchor, 2 and 3 probes); compass
steps of one pip; score = CLOSED P&L incl. rolls, ejections, commission,
swap; two-day rounds, $1/day margin. BLOCKER today: I6 halts an instance
reattached with a new EXIT (an ADD change is safe, geometry-cycle3 A6).

**NEVER run `fxgrind_tests` on a terminal with live EAs. Never reattach or
deploy with the market closed. Cycle 3 (VPS, FTMO) is FROZEN** except for
defect fixes.

**RDP to box 1 is locked out** (xrdp-sesman lost the session holding MT5).
Use x11vnc on `:10` (06 s4). Do NOT reboot while Fleet B runs there.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `e80da48` (docs); EA == `669da60`: `git diff --stat 669da60 origin/main -- ea/ tools/` must be empty |
| pipshed `main` | `1e88b10` (C56 + fixes 1-3); migration 004 applied in production |
| VPS (cycle 3) | `5685e4f`, tag `vps-5685e4f`, restore `vps-a01a5d4`; FTMO 1514731800; `pipshed.com` |
| Box 1 (Fleet B) | `5685e4f`; IC 53066709; `linux.pipshed.com`; box repo at `5685e4f` (probe script copied to Scripts only) |
| Suite | 2114/2114 at `00e0e4e` (EA of `669da60`); 1887/1887 at `5685e4f` |
| Evidence | Fleet B closed net (11 instances): $68.82 on 24 Sep (from 02:50Z), $61.82 on 25 Sep; commission $0.08/scalp; no side at cap yet (deepest 7) |

---

## 2. DONE IN THE LAST CHAT (25-26 Sep, HANDOFF s17)

- Resting-add re-pricing traced (geometry-cycle3 A6): a 1-2 pip ADD dial
  leaves a resting add at the old distance until it fills or the deepest
  layer scalps; no invariant.
- Tick-history probe on the box: all nine symbols, 65-117 k ticks / 24 h,
  4-14 ms (ADR-162 s16). GD6 precondition met.
- Group A dial on Fleet B: evaluated and ruled, then WITHDRAWN unapplied
  (design moved to cycle 4). A three-fleet plan was written and withdrawn
  (never pushed). Reduced Hours (ADR-161) is parked: both ejection paths
  act only at cap, so a windowed side below cap never ejects overnight.
- Cycle 4 rev 3 written (s8). C56 shipped in four rounds (spec + three
  fixes), verified on production: ledger closes = EA scalp rows = s4 on
  22/22 instance-days.

---

## 3. NEXT, IN ORDER

1. **C63 prep** (docs and presets as patches): a `fleet-b.md` amendment
   pre-registering the lattice on Fleet B (what is watched: rolls, roll
   cost, strands, closed P&L by class, vs cycle 3 on ADR-157); the
   `presets_b` lattice keys; the box-1 procedure (x11vnc; repo to `main`;
   copy `ea/*`; compile 0/0; reattach all 11; check lines and STOP list;
   read `/ejection`). Presets are loaded only after the compile.
2. **C63 deploy**: Tuesday or Thursday, in session, spreads settled.
3. **Every night:** `archive_counts.py --carrypass --hours 2` after 21:00Z.
4. **Cycle 4** (C46-C48): the per-side EA spec (I6 must allow a rebuild
   at start; exits and resting adds rebuilt; width tied to add, rule
   open), then pipshed's compass. The big piece.
5. **Small:** C64 (summary commission 0.05 vs 0.08), C65 (heartbeat
   price and ticket), C66 (reconciliation gross basis), C67 (tidy
   `D:\pipshed` untracked files, never `git clean`), C57, C62.

---

## 4. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in git; RUN every verify script yourself
  (a "green" branch had a test that could not pass anywhere).
- Pull a PRODUCTION sample before writing fixtures: `scalp_history` has
  no deal tickets; commission is on IN deals only; the EA's gross
  includes swap. Zeros are not data: unknown = NULL or 503.
- The pipshed web never holds `DATABASE_URL` (ARCHITECT s10).
- Check an advisor's premise, not only his conclusion (Gemini assumed a
  pre-merge migration was possible; read an incomplete close as
  corruption when `fill_logs` is simply never pruned).
- PowerShell mangles nested quotes in `railway ssh ... python -c`: use a
  shell inside the container (cookbook).
- Claude's sandbox PostgreSQL can stop between runs: `select 1` first.

---

## 5. WORKING PRACTICE

- One shell step per message; the operator pastes output back. Say WHERE
  each command runs (desktop PowerShell, box SSH, container, GUI).
- Docs and small fixes: Claude commits in its sandbox, hands over
  `git format-patch` files (byte size, expected tree hash); the operator
  `git am`s from Downloads and pushes; Claude verifies on GitHub.
- Features: spec (bookends, Gemini questions inside, tests first,
  failures predicted BY NAME) -> Gemini -> Cursor on a branch, pushed ->
  Claude reads the commits and runs every verify -> merge `--no-ff` ->
  Claude checks production. Pipshed: pushing `main` redeploys; migrations
  run inside the worker; avoid 20:50-21:00Z.
- The operator (26 Sep): ask OPEN questions, not multiple choice, for a
  while; say plainly when something sounds wrong; move strategically, not
  along the path of least resistance.
- Long chats: keep working and keep docs current; propose a handoff only
  near the real limit.
---

## 6. THE MAIN THREADS (operator's list, 26 Sep; detail in the docs named)

1. **Passive ejection.** Live: ADR-157 auto-eject (at cap only; never
   fired, deepest side 7). Built, OFF: ADR-162 lattice (past cap every
   level is virtual; the oldest layer's exit rolls there, bounded cost;
   `ROLL_STRANDED` hands over). Preconditions met (probe, C56). Next: C63
   on Fleet B. Limit: both act only at cap (why Reduced Hours is parked).
2. **Carry.** C52 live on both fleets since 25 Sep, nightly passes clean;
   C60 refused no-change modifies are harmless; open: C57 (GVs pruned at
   init with no connection check), C58. Nightly `--carrypass` check. The
   carry pass already rebuilds each exit from entry + CURRENT exit pips +
   the broker's swap ledger (cycle-4 note s8.6).
3. **Linux boxes.** Box 1 = Fleet B (IC, comparable to FTMO). Cycle 4:
   three IC fleets, one box and account each, the SAME pairs, fleet 1
   anchor, 2 and 3 probes (~11 EAs a box); one FTMO fleet runs anchors
   only. RDP lockout: x11vnc, never reboot (06 s4).
4. **The new EA** (C46-C48): add and exit per side; width follows add
   (rule open); at start, exits rebuilt (entry + exit + carry) and resting
   adds moved ignoring the deadband; stores only VL and eject offset; the
   lattice per side. Blocker: I6 halts a new EXIT today; ADD is safe (A6).
5. **The round** (cycle-4 note s8.4-s8.8): two FTMO days; per pair and
   side, closed P&L (rolls, ejections, commission, swap; ledger) across
   the three fleets; a probe beating the anchor by > $1/day becomes the
   anchor; probes one pip either side, outward until bracketed, then
   half pips; pipshed recommends and writes `.set`; the operator deploys
   in session; anchors that hold go to FTMO if they fit its daily limit.
6. **Schedule.** Sun 27 open: nothing to deploy; glance at `/ejection`.
   Mon 28: C63 prep (fleet-b.md amendment, lattice presets, box-1
   procedure). Tue 29 or Thu 1 Oct, in session: C63 deploy, then watch
   rolls. Through the week: the cycle-4 EA spec; C64-C67 anywhere. Later:
   boxes 2 and 3, accounts, round 1.

Line count: 175
