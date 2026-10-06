This message has a line count at the bottom

# RUNBOOK -- THE WEDNESDAY BUILD, 7 OCT: v2.2a + ADR-166, THE ROLL GATE AT 0 ON B, C, D

| | |
|---|---|
| Status | **REVIEWED 6 Oct ~21:40Z** (Claude's draft; Gemini GW7-1..GW7-5 and Claude's check, s9: `WARN_API_ENTRY_STOP` / `WARN_API_SOFT_LIMIT` added to the STOP list; a request watch). Runs Wed 7 Oct in session on the operator's go |
| Ruling | Operator 6 Oct ~20:37Z: the gate on ALL THREE IC fleets as soon as possible ("why roll if you have a position in place for the market trading against you"; the quote gap table shows how tight the range is before something triggers); the build Wed 7 Oct; round 2 = Thu 8 + Fri 9. Replaces the s63 plan (the gate on wine-d only, Fri 9, scored on equity against wine-test) |
| Backlog | C133 (ADR-166, merged `d57fe9b`), C93 + C100 (v2.2a, merged `509705f`), C88 (wine-c loads the Scripts copy: still deferred) |
| Model | `docs/runbooks/monday-build-2026-10-05.md` (run 5 Oct 22:20-23:21Z, BAD 0) and `docs/runbooks/round-reload.md` (run 6 Oct 03:18-03:35Z, BAD 0) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | `main` EA code = `5bb5fdb` (ADR-166 tip) on v2.2a; suite 2597/2597 on GBPUSD and EURUSD (desktop, 6 Oct) | HANDOFF s63; `git diff --stat 5bb5fdb main -- 'ea/*.mq5' 'ea/*.mqh'` empty | VERIFIED |
| K2 | B, C, D run `2859be6` EA code (Monday build); the trading-code difference to `5bb5fdb` is v2.2a (C93 recon walk, C100 API inputs) and ADR-166 (the gate) | `git diff --stat 2859be6 5bb5fdb -- 'ea/*.mq5' 'ea/*.mqh'` (9 files) | VERIFIED |
| K3 | New inputs: `InpRollGateOpposite` (default -1 = off), `InpApiEntryStop` (1000000), `InpApiSoftWarn` (999000); the API defaults equal the hotfix constants the boxes run today | `ea/fxgrind.mq5` 36, 42-43 | VERIFIED |
| K4 | A recompile keeps each chart's inputs by name and gives a NEW input its default: after the compile every chart runs v2.2a + ADR-166 with the gate OFF (-1). The gate comes on per chart only at its F7 + Load (s3.7) | MT5 behaviour (the Monday build: `InpLatticeReroll` read `false` on all 27 after the compile until F7) | VERIFIED (5 Oct) |
| K5 | `OnInit` prints `GRIND_ROLL_GATE opposite_max=<n>` and `GRIND_API_LIMITS entry_stop=<n> soft_warn=<n>` between `GRIND_REROLL` and `GRIND_GEOMETRY`; `LATTICE_CONFIG` carries `"roll_gate"`; with a gate >= 0 `OnInit` restarts both sides' tick extremes (`Grind_LatticeRollGateInitRestart`) | `ea/fxgrind.mq5` 363-379 | VERIFIED |
| K6 | The gate: a capped side does not roll or re-roll while the opposite side holds more than N FILLED layers; while held it restarts its tick extreme and writes INFO `ROLL_DEFERRED` (archive and Experts log, once per episode, only when a roll is due); never `ROLL_STRANDED` while held | `prompts/cursor_adr166_roll_gate.md` s2-s3; `grind_engine.mqh` 1278-1286 | VERIFIED |
| K7 | The 27 `_r2` presets now carry `InpRollGateOpposite=0`, `InpApiEntryStop=1000000`, `InpApiSoftWarn=999000` at the EA's positions; each differs from the set loaded 6 Oct (`b438420`) by exactly those three lines and the warning text (", roll gate 0"); the geometry is unchanged. Fingerprints b `fce104ecbacf`, c `6f8a3d3b1a5f`, d `f02163b4e417` | `scripts/ic_presets.py` (G1-G8, 35/35, thirteen mutations caught); sandbox diff of all 27 | VERIFIED |
| K8 | `scripts/build_logcheck.awk` = the Monday checker plus `gate=`, `api=`, BAD on `API_LIMITS_INVALID` / `API_LIMITS_MISMATCH` / `WARN_API_ENTRY_STOP`, and `ROLL_DEFERRED` lines counted per symbol; run from the box's repo (no paste) | the file; checked on a synthetic UTF-16 log under mawk | VERIFIED |
| K9 | pipshed shows no gate: it is not in the heartbeat (the geometry table's cells do not change); `LATTICE_CONFIG` and `ROLL_DEFERRED` are archive rows (`archive_counts.py --codes`) | `fxgrind.mq5` 103-105 (heartbeat keys); `archive_counts.py` `--codes` | VERIFIED |
| K10 | FOMC minutes Wed 7 Oct 2:00 pm ET = 18:00Z | federalreserve.gov October 2026 calendar | CHECK the calendar on the morning |
| K11 | `WARN_API_ENTRY_STOP` is written to the Experts log and the archive once the terminal's count reaches `InpApiEntryStop`; `WARN_API_SOFT_LIMIT` is a TELEMETRY event only (pipshed), sent each telemetry interval while the count is at or above `InpApiSoftWarn`. At 1000000 / 999000 neither can fire on a real day (IC fleets 700-840 requests by 15:44Z, 6 Oct) | `grind_api_counter.mqh` 176-186; `fxgrind.mq5` 431-432 | VERIFIED |

## 1. WHAT CHANGES

- **Code:** B, C, D from `2859be6` to `main` (`5bb5fdb` EA code): v2.2a and ADR-166.
- **Input:** `InpRollGateOpposite=0` on all 27 IC charts, by F7 + Load of the
  regenerated `_r2` presets (the full read-back shows the three new inputs).
- **Not changed:** geometry (every `geo=` as round 2's table, s6), cap 8,
  deadband 2, S = W + 1, re-roll ON, breaker off, the pairs. FTMO (A,
  `aa6970a`) is not touched (holdout).
- **Structural** (compass-round s4.1): round 2 starts at the first 22:00Z
  after the LAST box: **round 2 = FTMO days Thu 8 + Fri 9** (7 Oct 22:00Z -
  9 Oct 22:00Z; `round2.json`). If the build cannot finish Wednesday, the
  rest is done Thursday in session and round 2 becomes Fri 9 + Mon 12.
- **What the gate does from the Load on:** a side at cap with ANY filled
  layer on the other side does not roll or re-roll; when the other side is
  flat the side rolls on the next call, all crossed levels at once for first
  rolls (GR6-1: up to 8 modifies, ~3 requests each). Layers already rolled
  keep their rolled exits (nothing is un-rolled). Expect `ROLL_DEFERRED`
  rows and far fewer `ROLL_ACCEPTED`. Nothing at account level stops a
  trend (breaker off, monday-build s1): the watch stays by hand.

## 2. WHEN

- **Wed 7 Oct, start ~13:00Z** (09:00 Toronto) after a calendar check (no
  tier-1 release within 30 minutes). Spreads normal.
- **Never 17:30-18:30Z** (FOMC minutes 18:00Z, K10) and **never
  20:50-21:15Z** (IC break; ADR-165's pause). A box is finished before a
  blocked slot or not started.
- **Safe to stop between boxes** (each box is self-contained; the round
  starts after the last one).

## 3. PER BOX (wine-d, then wine-c, then wine-test; one step at a time)

**3.1 Read the box.** Shell as root: `pgrep -a x11vnc` (wine-test and
wine-c were started `-once` on 6 Oct; restart if gone: 06 s9 start line,
port 5910 / 5911; wine-d 5912 `-forever`); the tunnel and the viewer.
pipshed card: 9/9 LIVE, none halted.

**3.2 Pull and check (shell as root).** Expected: the commit, an EMPTY diff
line, the fingerprint (s0 K7) and 9:

    R=/home/khalid/fxmatrix-repo; sudo -u khalid git -C $R pull -q --ff-only && sudo -u khalid git -C $R log --oneline -1 | cut -c1-10 && sudo -u khalid git -C $R diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh' && (cd $R && for f in ea/presets_<f>/*_r2.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_<f>/*_r2.set | wc -l)

(`<f>` = d, c, b. The pathspec is the code only: `-- ea/` lists the presets.)

**3.3 Stage the presets with the key** (round-reload 1.2; the key is never
printed). Expected: 9 lines `SAME_EXCEPT_KEY key_len=43`:

    K=$(tr -d '\r\n' < /home/khalid/.fxgrind_telemetry.key); P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Presets"; R=/home/khalid/fxmatrix-repo; for f in $R/ea/presets_<f>/*_r2.set; do sed "s|^TelemetryAPIKey=.*|TelemetryAPIKey=$K|" "$f" | sudo -u khalid tee "$P/$(basename $f)" >/dev/null; done; unset K; for f in $R/ea/presets_<f>/*_r2.set; do b=$(basename $f); if diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done

**3.4 Copy the sources to BOTH folders, then cmp** (as khalid). Expected
`cmp ok=158 bad=0` (79 files x 2). Copying reloads nothing:

    R=/home/khalid/fxmatrix-repo; M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; for d in Experts Scripts; do sudo -u khalid cp $R/ea/*.mq5 $R/ea/*.mqh "$M/$d/fxmatrix/"; done; ok=0; bad=0; for d in Experts Scripts; do for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "$M/$d/fxmatrix/$(basename "$f")"; then ok=$((ok+1)); else bad=$((bad+1)); fi; done; done; echo "cmp ok=$ok bad=$bad"

**3.5 Compile ONE file, the one the charts load** (MetaEditor GUI, VNC;
Refresh first): wine-d and wine-test `Experts/fxmatrix/fxgrind.mq5`;
**wine-c `Scripts/fxmatrix/fxgrind.mq5` (C88)**. 0 errors, 0 warnings.
Note the UTC minute. Never `fxgrind_tests` on a live box (traps 25 Sep).
On wine-c, never the Experts copy and never a Navigator drag (GB-5).

**3.6 Check the re-init** (FROM = the minute before the compile):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /home/khalid/fxmatrix-repo/scripts/build_logcheck.awk

Expected: 9 rows `deinit=2`, `replay=ready(n)`, `lattice=true`,
`reroll=true`, **`gate=-1`**, **`api=1000000/999000`**, `geo=` as s6,
`rebuild=false/false`, BAD 0, POST-ok rising. Then the build stamp
(desktop PowerShell, `D:\pipshed`), the pilot's newest INIT row
`ea_build` = today's compile time:

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --table config_events --instance GRIND_GBPUSD_OPTD --limit 2

(`_OPTC` on wine-c, `_OPTB` on wine-test.)

**3.7 The gate ON, chart by chart** (F7 ON THE CHART -> Inputs -> Load
`<pair>_opt_<f>_r2.set` -> read back BEFORE OK). Read back:
`InpTelemetryInstance` and `InpMagic` (s6), width / add / exit and the six
per-side rows, cap 8, `InpStrandedThreshPips` W + 1, `InpDeadbandPips` 2,
lattice and re-roll true, **`InpRollGateOpposite` 0**, **`InpApiEntryStop`
1000000**, **`InpApiSoftWarn` 999000**, auto-eject and breaker false, the
warning ending "roll gate 0 (IC Markets demo ...)", the key row not blank.
A read-back that does not match: Cancel, never OK. Pilot GBPUSD, then the
checker (FROM = the minute before the OK): one row `deinit=5`, **`gate=0`**,
`api=` as 3.6, `geo=` unchanged, `rebuild=false/false`, BAD 0. Then the
other eight; the checker from the minute after the pilot: 8 rows, the same.

**3.8 After the box** (desktop, `D:\pipshed`):

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes 'ROLL_STRANDED,ROLL_CLOSING_STUCK,ROLL_REFUSED,DEAL_EVENT_MISSED,REPLAY_SEED_FAILED,EJECT_ACCEPTED,INVARIANT_FAIL,QUARANTINE_HALT,RECON_SCAN_RACE,API_LIMITS_MISMATCH,API_LIMITS_INVALID,WARN_API_ENTRY_STOP,WARN_API_SOFT_LIMIT,ROLL_DEFERRED,LATTICE_CONFIG' --hours 1

Expected: `LATTICE_CONFIG` 18 on this box's nine (compile + Load) plus any
earlier box; `ROLL_DEFERRED` on some capped sides (INFO: the gate holding);
`RECON_SCAN_RACE` reported, not a STOP (v2.2a re-walks, one a minute at
most); none of the others. pipshed card 9/9 LIVE, no `WARN_API_SOFT_LIMIT` on
the strip, and the fleet's `api_count` noted (GW7-3). A few minutes' look,
then the next box.

## 4. STOP (before the next chart or box)

FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`, any `REBUILD_*` failure, a
missing POST ok, a `geo=` or `rebuild=` not as s6, **a `gate=` or `api=`
not as expected**, `API_LIMITS_INVALID` / `API_LIMITS_MISMATCH`, **`WARN_API_ENTRY_STOP`
(log or archive) or `WARN_API_SOFT_LIMIT` (pipshed)**: at these inputs
neither can fire, so either means the inputs did not take (GW7-5), a MISMATCH
or a fingerprint that differs, a magic or instance on the wrong chart, two
re-rolls of one side with the same `ea_time_ms` (GB-4).

## 5. AFTER ALL THREE BOXES

1. Register: no rows (the gate is not geometry; the `_r2` presets carry it:
   `10_GEOMETRY_REGISTER` note). Event log entry with the times.
2. Claude (Thursday, on the study export): no `ROLL_ACCEPTED` after a
   chart's Load while that side's opposite held a filled layer (the gate
   in the field); `ROLL_DEFERRED` per fleet; requests per fleet before /
   after (`api_count`); the largest single-call roll burst after a gate
   release (`ROLL_ACCEPTED` rows sharing one `ea_time_ms`) per fleet
   (GW7-3: IC's own daily budget is unmeasured, C78 (2)).
3. The carry pass that night: 34 summaries as usual (BOOT s6).

## 6. EXPECTED VALUES PER CHART (`geo=` = L width/add/exit S width/add/exit; round 2's table)

| pair | magic | wine-d (D) | wine-c (C) | wine-test (B) |
|---|---|---|---|---|
| GBPUSD | 22260101 | `L2.5/9/9 S2.5/9/9` | `L2.5/8/10 S2.5/8/10` | `L2.5/9/10 S2.5/9/10` |
| EURUSD | 22260201 | `L2/7/11 S2/7/11` | `L2/6/10 S2/6/10` | `L2/7/10 S2/7/10` |
| EURGBP | 22260301 | `L1/3/6 S1/3/4` | `L1/2.5/5 S1/4/5` | `L1/3/5 S1/3/5` |
| AUDCAD | 22260401 | `L1.5/6/9 S1.5/6/9` | `L1.5/5/10 S1.5/5/10` | `L1.5/6/10 S1.5/6/10` |
| AUDCHF | 22260501 | `L1/4/9 S1/4/9` | `L1/3/10 S1/3/10` | `L1/4/10 S1/4/10` |
| CADCHF | 22260601 | `L1/4/11 S1/4/9` | `L1/3/10 S1/3/10` | `L1/4/10 S1/4/10` |
| NZDCHF | 22260701 | `L1/3/9 S1/3/9` | `L1/4/10 S1/4/10` | `L1/3/10 S1/3/10` |
| NZDCAD | 22260801 | `L2/8/10 S2/8/10` | `L2/8/10 S2/8/10` | `L2/8/10 S2/8/10` |
| AUDNZD | 22260901 | `L2/8/9 S2/8/9` | `L2/7/10 S2/7/10` | `L2/8/10 S2/8/10` |

Instance ids `GRIND_<PAIR>_OPTD` / `_OPTC` / `_OPTB`. Every row: cap 8,
deadband 2.0, S = W + 1, gate 0 after 3.7.

## 7. RECORD (per box)

Box, compile time and `.ex5` path, the 3.6 rows, the pilot's and the
eight's Load times, `ea_build`, the 3.8 counts.

## 8. FOR GEMINI (attack the premises; say which fact is missing)

- **GW7-1. Compile first, gate by Load after (K4).** Between the compile
  and each chart's Load the chart runs v2.2a + ADR-166 with the gate off
  (-1), i.e. today's trading plus v2.2a's recon change. Any reason to
  prefer a different order (the input does not exist on `2859be6`)?
- **GW7-2. Load the whole preset rather than F7 one row.** The `_r2` files
  differ from the loaded ones by the three new inputs and the warning only
  (K7), so a Load re-applies identical geometry (`rebuild=false/false`)
  and shows the three new inputs in the read-back. Object?
- **GW7-3. The release burst at N = 0 on all 27 charts (GR6-1).** When a
  side's opposite goes flat, first rolls for every crossed level go in one
  call; IC's daily request budget is unmeasured (C78 (2)). Missing fact?
- **GW7-4. Round 2 on Thu 8 + Fri 9.** Friday's window ends at 22:00Z as
  round 1's did (2 Oct), one day each; data end at the close, so the
  scorer prints "provisional" on a Friday export: read as expected. Object?
- **GW7-5. The STOP list (s4).** What failure at this build is not on it?

Ruled, not for review: the gate on all three fleets (operator, above); no
fleet runs without it, so gate against no gate is not measured live (the
5 Oct study: rolls about a wash in equity, C133).

## 9. GEMINI'S RULINGS (6 OCT ~21:40Z) AND CLAUDE'S CHECK

Gemini read this file as an attachment; his answers pasted by the
operator; each premise checked against `main` (`5bb5fdb` EA code).
- **GW7-1 ACCEPTED** (compile first, gate by Load). His "effectively
  `2859be6`" is not exact: v2.2a's recon change (C93) and the API inputs
  are live from the compile; only the gate waits for the Load.
- **GW7-2 ACCEPTED** (Load the whole preset).
- **GW7-3 REJECTED as stated; a watch added.** His mechanism: a release
  burst trips `InpApiSoftWarn` / `InpApiEntryStop` and endangers FTMO.
  The limits are 999000 / 1000000 (K11; IC fleets ran 700-840 requests
  by 15:44Z on 6 Oct): a 70-modify burst (~200 requests) cannot reach
  them. The build touches only the IC demos; FTMO's counter is its own
  terminal's on the VPS and A is not changed (holdout). The burst is
  smaller than he assumes: while gated the extreme restarts every call
  (`grind_engine.mqh` 1208-1220), so at release only levels the CURRENT
  market has crossed roll, never everything crossed during the hold
  (GR6-3). What stands: IC's own daily request budget is unmeasured (C78
  (2)), so s3.8 notes `api_count` per box and s5 reports the largest
  release burst per fleet.
- **GW7-4 REJECTED as a skew.** The compass compares C and D with B on the
  SAME ticks, so a thin Friday afternoon reaches every fleet alike, and
  GC-1 is re-estimated from the round's own control gaps (compass-round
  s4.3): less flow widens the threshold, it does not bias a probe. Round 1
  also had a Friday. Rounds are not scored against each other except by
  pooling repeats under one structure (GC-2).
- **GW7-5 ACCEPTED, reason corrected.** Both warnings join the STOP list
  (s4), the checker (`WARN_API_ENTRY_STOP` is BAD) and s3.8. The reason
  is not a burst (GW7-3): at these inputs neither can fire, so either one
  means the inputs did not take. `WARN_API_SOFT_LIMIT` is telemetry only,
  seen on pipshed, not in the log (K11).

Line count: 223
