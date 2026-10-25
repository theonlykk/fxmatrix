This message has a line count at the bottom

# RUNBOOK -- FLEET C's OPT RELOAD TO t2 (wine-c, IC 53071896): EURUSD OPT CAP 9; AUDCAD OPT ADD = EXIT 18, CAP 9

| | |
|---|---|
| Status | **DRAFT 25 Oct ~04:40Z (Claude, HANDOFF s90 continued 3), for review (Argon or Gemini, s8).** |
| Ruled | The operator 25 Oct ~04:10-04:14Z: C first (not D or E: the guard; E stays as it is), AUDCAD OPT 6 -> 18 with cap 9, reviewed before Monday, in session |
| Evidence | `research/opt_budget/PREREG_CAP.md` (simulator: cap 9 BETTER); `research/replay/results/sweep_notes.md` swcap (harness: CONFIRMED, both periods +$336.00 against +$230.64 at cap 7) |
| Uses | `main` with `ea/presets_c/{eurusd,audcad}_opt_c_t2.set` (fingerprint s1), `research/opt_budget/check_c_t2.py`; twoarm-build-c s2 and s4 (the commands); cap10-reload s4.4 (Remove then Attach, Gemini GW-5) |
| When | Monday 26 Oct in session, spreads normal: not before 22:30Z Sunday, never 20:50-21:15Z, not within 30 minutes of a tier-1 release. The operator picks the minute. Never with the market closed. |

## 0. WHAT CHANGES (two charts; C's other four charts untouched)

| Chart | Change | `geo=` after (L w/a/e S w/a/e) | `rebuild=` |
|---|---|---|---|
| EURUSD OPT (22260201) | cap 7 -> 9 | L2/7/7 S2/7/7 | false/false (exit unchanged) |
| AUDCAD OPT (22260401) | add = exit 6 -> 18; width 1.5 -> 4.5; stranded 2.5 -> 5.5; cap 7 -> 9 | L4.5/18/18 S4.5/18/18 | true/true |

Unchanged: EURUSD ALT, AUDCAD ALT, GBPCHF OPT and ALT (all t1, cap 7). ADR-153 add / width: 3.5, 4.0 (limit 4.0).

**One worked example (AUDCAD OPT long, prices):** layers at 0.9800 and 0.9794 (6 apart), exits resting at 0.9806 and
0.9800, the next add at 0.9788. After the reload the start-up rebuilds the exits to 0.9818 and 0.9812 (entry + 18) and
moves the next add to 0.9776 (deepest - 18). Nothing fills at once: the exits move AWAY from the market (1 Oct's
rebuild moved them closer).

## 0.1 AUDIT TRAIL (source at `main`, EA code `5bb5fdb`)

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | Raising `InpMaxLayers` cannot trip I7: it fails only when a side holds MORE layers than the cap | `grind_recon.mqh` 489-495 | VERIFIED |
| K2 | The lattice acts only at depth >= cap: a side at 7 under cap 9 stops rolling and adds again | `grind_engine.mqh` 1401-1415 (the call), 1303-1304 (the loop breaks below cap) | VERIFIED |
| K3 | With rolled layers, the add target anchors on the lowest effective entry (the VL) | `grind_engine.mqh` 2250-2288 | VERIFIED |
| K4 | A changed exit is rebuilt at start-up from the stored exit label (`GRIND_GEO_EXIT_<magic>_L/_S`), clamped passive where needed | `grind_carry.mqh` 614; `grind_engine.mqh` 3074-3169 | VERIFIED |
| K5 | After an exit rebuild the one-shot add re-price moves the resting add to the new distance | `fxgrind.mq5` 289-292; `grind_engine.mqh` 2561-2575 | VERIFIED |
| K6 | C's six charts load the Experts copy, built 21 Oct 16:21:21 (`ea_build`, C88 closed) | HANDOFF s89 continued 2 | VERIFIED (archive) |
| K7 | Guard: C's six instances peak far below 194 (harness, cap 9 on two OPT: well inside) | swcap; twoarm-build-c s0 | INFERRED |

## 1. BEFORE (Claude, sandbox)

- `main` carries the two `_t2` presets; fingerprint (repo root, Linux checkout):
  `for f in ea/presets_c/*_t2.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12` and
  `ls ea/presets_c/*_t2.set | wc -l` = 2. **`7ecd5b582851`, 2** (computed 25 Oct). `python research/opt_budget/check_c_t2.py`:
  `C t2 presets: ALL OK`.

## 2. ON WINE-C (ssh box2; VNC 5911: twoarm-build-c s2.1)

**2.1 Read the box (VNC):** Algo Trading ON; six charts; pipshed C page (`linuxc`): six LIVE, none halted. Note
EURUSD OPT's and AUDCAD OPT's layers per side (Trade tab, `GRIND|OPT|L|` / `GRIND|OPT|S|`).

**2.2 Repo to `main`** (twoarm-build-c s2.2's command; the last line prints nothing).

**2.3 Fingerprint and checker** (expected `7ecd5b582851`, then 2, then `C t2 presets: ALL OK`):

    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_c/*_t2.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_c/*_t2.set | wc -l; python3 research/opt_budget/check_c_t2.py | tail -1)

**2.4 Stage with the key** (twoarm-build-c s2.4's command with `*_t1.set` replaced by `*_t2.set` in BOTH loops;
expected 2 lines `SAME_EXCEPT_KEY key_len=43`).

No compile: no EA code changes; the charts keep the Experts `.ex5` of 21 Oct (K6).

## 3. RELOAD EURUSD OPT, THEN AUDCAD OPT (VNC; one chart at a time; EURUSD is the pilot)

**Remove, then Attach (cap10-reload s4.4, GW-5): never drag over a running EA, never F7.** Per chart (FROM = the
minute before the Remove):
1. Right-click the chart -> Expert Advisors -> Remove. Gate: the Experts log shows `fxgrind deinit reason=1` for
   that symbol and the EA icon is gone.
2. Drag **Navigator -> Expert Advisors -> fxmatrix -> fxgrind** (the Experts copy) onto the chart -> Inputs -> Load
   `<pair>_opt_c_t2.set` -> read back BEFORE OK: `InpMagic` (22260201 / 22260401), `InpTelemetryInstance`
   (`GRIND_<PAIR>_OPTC`), width, add, exit (s0), the six per-side rows `-1.0`, **cap 9**, stranded (3.0 / 5.5),
   deadband 2.0, lattice and re-roll true, roll gate 0, auto-eject and breaker false, the warning (`FLEET C two-arm t2
   <PAIR> OPT -: cap 9 ...`), the key row not blank. Common: Algo Trading allowed. OK; note the UTC time.
3. The checker (twoarm-build-c s4 step 4's two commands, FROM as above). Expected one row: `deinit=1
   replay=ready(N) lattice=true reroll=true gate=0 api=1000000/999000`, `geo=` and `rebuild=` as s0, BAD 0, a POST
   ok, `telemetry dropped since FROM: 0`. The single `WARN STARTUP_EXIT_SHORTFALL long=1 short=0` (or 0 / 1) is
   allowed as in twoarm-build-c s4; 2 or more on a side is a STOP.
4. Trade tab for that symbol: each layer's exits as K4 (AUDCAD: entry + 18 on the rank-0 and the furthest layer;
   the middle layers' exits are held, ADR-151); the resting add at the new distance within a minute (K5).
5. pipshed `linuxc`: the instance LIVE, its geometry row cap 9 (AUDCAD 18 / 18). Then the next chart.

## 4. AFTER

- Tonight's carry pass (from ~21:00Z): C 6 / 6, none incomplete (01_BOOT s6's command).
- Watch, not act: EURUSD OPT's 8th and 9th layers when they come; AUDCAD's first scalps at 18.

## 5. ROLLBACK (only if a chart misbehaves; tell Claude first)

Remove, then Attach with `<pair>_opt_c_t1.set` (staged 21 Oct). **Cap 9 -> 7 trips I7 on a side holding 8 or 9
layers (K1): roll back only when both sides hold 7 or fewer** (Trade tab), or flatten the chart first (twoarm-build-c
s3 steps 1-4, keep the chart).

## 6. NEGATIVE SPACE

No compile; no change to C's other four charts, to D, E or B; no F7; no attach outside session or in 20:50-21:15Z;
no change to the telemetry key; no flattening except under s5.

## 8. FOR THE REVIEWER (Argon or Gemini): attack the premises

1. K1-K5: is any path at a CAP RAISE with rolled layers (VLs) not covered, e.g. a re-roll state or the lattice's
   extreme tracking at a side that was at cap 7 and is now below cap 9?
2. AUDCAD's exit change moves every exit 12 pips AWAY: is anything in the rebuild (clamps, carry shift records)
   built for exits moving closer only?
3. Is Remove-then-Attach still the right path when the chart already runs the Experts copy (K6), or is F7 + Load now
   equivalent?
4. Is anything missing that a reload with a new cap needs on pipshed or the archive (the geometry table, `vs_anchor`)?

Line count: 107
