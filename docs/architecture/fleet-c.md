This message has a line count at the bottom

# FLEET C -- PRE-REGISTRATION (BOX 2, IC MARKETS DEMO, GRIND V2.1)

**Written 2026-09-27 ~03:00Z, before box 2's first attach.** Operator
roadmap, 27 Sep (cycle-4 note s8.12, backlog C70): a second IC Markets
box running `main` (grind v2.1: per-side add/exit, rebuild at start,
lattice default OFF). The letter C was moved here from the parked
session-window fleet (C51, Gemini GC-1). It never touches the FTMO
account, the VPS or Fleet B's account.

---

## 1. SETUP

| | |
|---|---|
| Box | Vultr `fxgrind-wine-c`, Chicago, Ubuntu 24.04, vc2-2c-4gb, built FRESH (not a snapshot of box 1) 2026-09-27 03:55Z; IP **64.177.116.219** |
| Build | `06_LINUX_WINE_BOX.md` s3 and s9: Wine 9.0 from Ubuntu (9.0~repack-4build3), kernel 6.8.0-142, portable MT5 build 6230 as `khalid`; x11vnc installed at build (06 s4 fallback) |
| Account | new IC Markets Raw demo, `ICMarketsSC-Demo`, **Hedge**, USD, 1:100, **$10,000** as the single opening deposit (breaker allowance $500, ADR-160 gate $250, as Fleet B and FTMO); login **53071896** (Journal 04:39Z: `authorized on ICMarketsSC-Demo`, `demo account - hedging mode`, 0 positions, 0 orders; title `... - Hedge - Raw Trading Ltd`) |
| Code | `main` cloned on the box at `e2ac9fe` (EA code == `2ff62f4`, grind v2.1 = v2.0 + ADR-163 on ADR-162; `ea/ tools/` diff vs `6a1e9ad` empty); 74 files in Experts and Scripts, `cmp` clean; EA and tests compiled 0/0 in MetaEditor on the box; suite run ONCE before any attach: **2220/2220 on GBPUSD, 04:42:58Z** |
| Presets | `ea/presets_c/*_c.set`: Fleet B's eleven presets AFTER the graded dial (`presets_b` at `dd4761e`, fleet-b.md B1), changed only in: `InpTelemetryInstance` (`GRIND_<PAIR>_OPTC`, `_ALTC` for the two duplicates); `InpConfigWarning` (the label; reporting only, it names Fleet C instead of Fleet B's account); six explicit per-side lines at -1 (`InpWidthPipsLong/Short`, `InpAddPipsLong/Short`, `InpExitPipsLong/Short` = inherit the base input). Key substituted on the box by `sed`, never in git |
| Magics | shared with cycle 3 and Fleet B: separate account, separate terminal, separate GlobalVariable store |
| Telemetry | ids `GRIND_<PAIR>_OPTC` / `_ALTC`; pipshed `3184c88` (`GRIND_C_INSTANCES`, `GRIND_FLEET=C`); JSON `https://pipshed.com/api/g/k7m9p2x4q/status_c/<n>`; dashboard: third Railway web service (`GRIND_FLEET=C`, `GRIND_FLEET_LABEL`, same Redis, NO `DATABASE_URL`): Railway service "pipshed Fleet C", domain **`https://linuxc.pipshed.com`** (proxied Cloudflare CNAME; also `https://pipshed-copy-copy-production.up.railway.app`) |

Geometry (identical to Fleet B after B1; width / add / exit, pips; cap 8
everywhere; auto-eject ON, lattice OFF, carry ON, commanded eject ON):

| instance | magic | width | add | exit |
|---|---|---|---|---|
| GBPUSD_OPTC | 22260101 | 5 | 9 | 10 |
| EURUSD_OPTC | 22260201 | 7 | 7 | 10 |
| EURGBP_OPTC | 22260301 | 3 | 3 | 5 |
| AUDCAD_OPTC | 22260401 | 5 | 6 | 10 |
| AUDCHF_OPTC | 22260501 | 5 | 4 | 10 |
| CADCHF_OPTC | 22260601 | 5 | 4 | 10 |
| NZDCHF_OPTC | 22260701 | 3 | 3 | 10 |
| NZDCAD_OPTC | 22260801 | 5 | 8 | 10 |
| NZDCAD_ALTC | 22260802 | 5 | 10 | 10 |
| AUDNZD_OPTC | 22260901 | 7 | 8 | 10 |
| AUDNZD_ALTC | 22260902 | 7 | 10 | 10 |

---

## 2. PHASE 1 -- CODE CHECK (MONDAY 28 SEP, IN SESSION)

**Purpose:** prove `main` (v2.1) trades cleanly on a live account under
Wine before it goes anywhere that matters (C63 on box 1). It is a CODE
check, not a geometry comparison: the settings are Fleet B's, every
per-side input inherited, so v2.1 should behave as `669da60` (ADR-163
s11) and as box 1's `5685e4f` apart from the new init lines.

**Attach** (06 s7 step 8): Algo Trading ON first; every input read back
BEFORE OK; the GBPUSD pilot until `grind telemetry POST ok`, then the
other ten. Never with the market closed.

**Pass, per instance, at init:**
- `GRIND_LATTICE enable=false`;
- `GRIND_GEOMETRY long width=W add=A exit=X short width=W add=A exit=X`
  with the table's values on BOTH sides, printed to four decimals (e.g.
  `width=5.0000`) (inherit worked);
- `GRIND_REBUILD long=false short=false` (no labels exist on a new
  account, so the first init is strict and writes them; ADR-163 s9);
- `GRIND_SESSION enable=false`; a clean reconstruction; `grind telemetry
  POST ok`;
- after init, Tools -> Global Variables shows `GRIND_GEO_EXIT_<magic>_L`
  and `_S` for each magic, equal to its exit (a spot check on two
  instances is enough).

**Pass, over the session:** from the attach to Monday's 17:00 ET close,
no FATAL, CRITICAL, `INVARIANT_FAIL`, `QUARANTINE_HALT` or halt on any
instance; scalps booking (`scalp_history` rows for `_OPTC` ids). Claude
adds (not an operator criterion): that night's carry pass reads clean
for the eleven `_OPTC`/`_ALTC` ids in the usual `--carrypass` check,
since v2.0 made the carry pass per side and this is its first live run.

**STOP** (stop attaching; bring it to the chat; do not reattach
blindly): FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`,
`STARTUP_EXIT_SHORTFALL`, a `GRIND_GEOMETRY` value that differs from the
table, `GRIND_REBUILD` true on either side, or no POST ok on the pilot.

**Not done:** no flattening of either box. Fleet C starts flat by
construction; Fleet B keeps its inherited book (the territory, cycle-4
s8.5; flattening it would reset the dial's baseline). The EA cannot close
positions anyway. A code check needs no equal books.

**Optional, like for like:** "fresh ladder" scalps: on both fleets, count
scalps only on ladders whose L0 opened after box 2's first attach. That
removes the inherited-book difference from a Fleet B vs Fleet C number.
Reported, not a pass criterion.

## 3. PHASE 2 -- MATCHED LATTICE AT C63

On the day C63 deploys (Tue or Thu, in session; backlog C63): box 1
compiles `main` with lattice presets (`InpVirtualLattice=true`,
`InpAutoEject=false`; OnInit refuses the pair otherwise) and box 2 gets
the same two lines the same day, so the two boxes stay matched (roadmap
s8.12 step 3). Written as an amendment here, with the `presets_c`
commit, before that reload. After a few days watching rolls (step 4),
box 2 becomes a PROBE fleet (step 5; box 1 the anchor).

---

## 4. KNOWN LIMITS

- Same broker and pairs as Fleet B but a different account: the books
  differ from the first minute (flat vs inherited), so fleet totals are
  not comparable in phase 1 (hence the fresh-ladder option).
- Suite residue: CHECKED 04:43Z, Tools -> Global Variables EMPTY after
  the suite on this terminal (no EA has run on it). Nothing to delete.
- MT5 prints "unstable and unsupported Wine 9.0 ... please upgrade to
  Wine 10.0 or later" at start. Box 2 stays on Wine 9.0 to match box 1
  (live on 9.0 since 24 Sep); backlog C71.
- The `/ejection` view on the Fleet C host is expected to list the eleven
  C ids (the web filters the worker's snapshot by its fleet's instance
  list); check once the page is up. Until Monday, 0 live is correct.

---

## 5. RECORD

- Box built 03:55Z 27 Sep, 64.177.116.219; upgraded and rebooted onto
  kernel 6.8.0-142 before anything was installed on it.
- IC demo 53071896 (Raw Spread, USD, 1:100, $10,000), logged in 04:39Z.
- Code on the box `e2ac9fe`; compile 0/0 (EA and tests); suite 2220/2220
  (GBPUSD, 04:42:58Z); Global Variables empty after it.
- Telemetry key copied box 1 -> box 2 by scp, 44 bytes, `chmod 600`,
  sha256 prefixes equal on both boxes (04:46Z).
- Presets staged 04:52Z: the eleven `*_c.set` from `ecdac67` into
  `MQL5/Presets` with the key (read loop, not `sed`); each
  `SAME_EXCEPT_KEY KEY_OK`; key 43 chars.
- MT5 restarted detached 04:57Z (`setsid nohup ... &`, 06 s9; the Wine
  menu entry calls `wine-stable` and does not start; it survived
  closing the terminal, confirmed by the operator 05:13Z); re-authorised
  on `ICMarketsSC-Demo`, hedging mode, 0 positions, 0 orders.
- Fleet C page 05:10Z: Railway service "pipshed Fleet C" (duplicate of
  Fleet B's web service; `GRIND_FLEET=C`, label "Fleet C - IC Markets
  53071896", no `DATABASE_URL`), `linuxc.pipshed.com` (CNAME proxied +
  `_railway-verify` TXT). `/ejection` on both hosts: fleet C, the eleven C
  ids only, view 20 s old; `pipshed.com/.../status_c`: total 11, live 0.
- Phase 1 attach: (pilot time, all eleven time).
- Phase 1 verdict: (after Monday's session and that night's carry pass).

## 6. AMENDMENTS

(none yet)

Line count: 148
