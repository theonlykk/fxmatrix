This message has a line count at the bottom

# FLEET D -- WINE-D (IC MARKETS DEMO 53077984): PRE-REGISTRATION

Status: D0 written by Claude 1 Oct ~04:35Z on the operator's decision
("lets go with your recommendation - we want to make compass probe part
of our routine"). D0 is not reviewed by Gemini: it changes nothing that
B or C run, and the probe design (D1) is the document that goes to him.
Box: `06_LINUX_WINE_BOX.md` s10; backlog C85; cycle-4 note s8.3-s8.5,
s8.12 step 5.

## 1. SETUP

| | |
|---|---|
| Account | IC Markets demo **53077984**, `ICMarketsSC-Demo`, Hedge, Raw Spread, USD, 1:100, $10,000 |
| Box | wine-d, 216.128.158.33, Ubuntu 24.04, Wine 9.0 (06 s10); RDP via tunnel to local 3392 |
| Code | `main` `0335f25` (v2.1 + ADR-164 + C77), as on B and C; Experts and Scripts copies identical to the repo (06 s10), suite 2368/2368 once before any attach |
| Presets | `ea/presets_d/*_d_lat.set` (11): `presets_c` `_lat` files with only `InpTelemetryInstance` (`_OPTD`/`_ALTD`) and `InpConfigWarning` changed |
| Telemetry | key from `~/.fxgrind_telemetry.key` (sha `fc6b3d9c56a8`); page `https://linuxd.pipshed.com`; pipshed `GRIND_D_INSTANCES` = the 11 ids |
| History | starts with the C78 probe's deals (magic 99078001, 1 Oct 02:50-02:52Z): exclude them from any study |

## 2. PHASES

**D0 -- anchor settings, lattice on (from the attach, 1 Oct).** Fleet B's
current settings exactly (the B1 dial, cap 8, `InpVirtualLattice=true`,
`InpAutoEject=false`, carry on, commanded eject on, breaker on, session
off), starting FLAT. What it gives before any probe: the box proven live
(WebRequest, telemetry, Wine), and a fresh-ladder fleet on the same
settings as B and C, whose books are inherited (fleet-c.md s2's optional
comparison, now a whole fleet).

**D1 -- the first compass probe (after the roll-watch).** Per the
cycle-4 note s8.4: B holds the anchor, C and D the probes, one lever one
pip from the anchor per pair and side, on the side the evidence points
to. The first directions (s8.11 OPEN) go to Gemini as this file's D1
amendment, with the roll-watch and study evidence; deployed by preset
reload in session (v2.1 rebuilds exits on a live book). Operator, 1 Oct:
compass rounds are to become routine; ~05:25Z: "i really want to put the
correct compass probe points on fleet d" -- D1 is next, ahead of the
roll-watch (HANDOFF s26 NEXT SESSION item 2 lists the anchors and the
decisions in order).

## 3. ATTACH (D0)

In session, spreads well under every width, not 20:50-21:00Z, not
within 30 minutes of a tier-1 release.
1. Presets staged on wine-d with the key; 11 `SAME_EXCEPT_KEY key_len=43`.
2. The log checker (`c63-commands.md` s1) installed on wine-d.
3. Algo Trading ON first. Eleven charts (nine symbols; two each for
   AUDNZD and NZDCAD), each with fxgrind dragged from
   **Navigator -> Expert Advisors -> fxmatrix -> fxgrind (the Experts
   copy, never Scripts: 02_TRAPS 1 Oct C63)**, its `_d_lat` preset
   loaded and every input read back before OK. GBPUSD first as the
   pilot, until `grind telemetry POST ok`.
4. Pass per chart: `replay=ready`, `lattice=true`, `rebuild=false/false`,
   geometry = the register's B/C row, POST ok, no BAD line.
5. After: every `chart*.chr` `path=` reads `Experts\fxmatrix\fxgrind.ex5`;
   `LATTICE_CONFIG` for the 11 D ids.

STOP before the next chart on FATAL, CRITICAL, `INVARIANT_FAIL`,
`RECON_FAIL`, a `geo=` different from the register, `REPLAY_INIT_DEFERRED`
in session, or no POST ok.

## 4. KNOWN LIMITS

- Same broker, pairs and settings as B and C; a different account and a
  flat start, so fleet totals differ from B and C by the books.
- pipshed's strip shows D as NOT ATTACHED until its entry's `placeholder`
  is flipped and `cycle_start` set (C85 (f), a pipshed change).
- The ejection study does not read D until C84 is scored (C85 (d)).
- Geometry register: D's rows open at the attach (same values as B/C).

## 5. RECORD

- **D0 attached 1 Oct 05:10-05:19Z** (Asia session; spreads single-digit
  points), over VNC after the X display was unwedged (02_TRAPS 1 Oct
  wine-d). Presets staged 04:33Z (`MQL5/Presets` created first: a fresh
  box has none), 11 `SAME_EXCEPT_KEY key_len=43`; log checker installed;
  `Experts/fxmatrix/fxgrind.ex5` 317,844 bytes, 30 Sep 18:58, source =
  repo.
- GBPUSD pilot 05:10:32Z: `replay=ready(0) lattice=true geo=L5/9/10
  S5/9/10 rebuild=false/false`, POST ok. The other ten 05:12:58-05:19:23Z,
  each `lattice=true rebuild=false/false`, geometry = the table, twins
  add 8 / 10, BAD 0. AUDCHF first attached on H1 (05:15:04), removed and
  re-attached on M5 (05:15:34): one instance, its resting orders adopted.
- `LATTICE_CONFIG` for all 11 D ids; no `DEAL_EVENT_MISSED`, no
  `REPLAY_SEED_FAILED`. Geometry register: D rows opened at these times.
- Left: pipshed strip flip (`placeholder` off, `cycle_start` 2026-10-01;
  C85 (f); BUILT 05:40Z in `pipshed_c9_and_fleet_d_card.patch`, tree
  `fbed4e6c`, not pushed); every chart was dragged from Expert Advisors -> fxmatrix
  (the operator's attach; the chart profiles are written on exit, so the
  `path=` check waits for the next MT5 restart).

Line count: 95
