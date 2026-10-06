This message has a line count at the bottom

# RUNBOOK -- A COMPASS ROUND RELOAD ON B, C, D (PRESETS ONLY)

| | |
|---|---|
| Status | Written 6 Oct ~03:50Z from the round-2 reload as run (6 Oct 03:18-03:35Z, HANDOFF s61; BAD 0 on 27 charts). Use it for round 3 onward |
| Uses | `scripts/ic_presets.py --stage round` (the `_rN` presets, committed and pushed first); `/root/mon_logcheck.awk` on each box (monday-night 0.1); compass-round s4.8 |
| When | In session, spreads normal (IC outside the 21Z hour: 0.1-0.5 pips); never 20:50-21:15Z; not within 30 min of a tier-1 release (check the calendar); finished before the 22:00Z that opens the round. Safe to stop between boxes: a round starts at the first 22:00Z after the LAST reload |

## 0. BEFORE (Claude, sandbox)

- The presets are on GitHub `main` (the generator's dry run 0 errors, then
  `--write`, committed, pushed by the operator).
- The fingerprint per fleet (`<f>` = b, c, d; `N` = the round), run from the repo root:

      for f in ea/presets_<f>/*_rN.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12

- The expected value table per chart (magic, W, add, exit per side, S =
  W + 1, deadband) and which charts change an EXIT (those show
  `rebuild=true` on that side; ADR-163).

## 1. PER BOX (wine-d, then wine-c, then wine-test; ssh window as root)

**1.1 Pull and fingerprint** (expected: the commit, the fingerprint, 9):

    sudo -u khalid git -C /home/khalid/fxmatrix-repo pull -q --ff-only && sudo -u khalid git -C /home/khalid/fxmatrix-repo log --oneline -1 | cut -c1-10 && (cd /home/khalid/fxmatrix-repo && for f in ea/presets_<f>/*_rN.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_<f>/*_rN.set | wc -l)

**1.2 Stage with the key, then check** (the key is never printed;
expected 9 lines `SAME_EXCEPT_KEY key_len=43`):

    K=$(tr -d '\r\n' < /home/khalid/.fxgrind_telemetry.key); P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Presets"; R=/home/khalid/fxmatrix-repo; for f in $R/ea/presets_<f>/*_rN.set; do sed "s|^TelemetryAPIKey=.*|TelemetryAPIKey=$K|" "$f" | sudo -u khalid tee "$P/$(basename $f)" >/dev/null; done; unset K; for f in $R/ea/presets_<f>/*_rN.set; do b=$(basename $f); if diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done

**1.3 The GBPUSD pilot (VNC):** F7 ON THE CHART (never the Navigator;
wine-c's charts load the Scripts `.ex5`, C88) -> Inputs -> Load
`gbpusd_opt_<f>_rN.set` -> read back BEFORE OK: `InpMagic`,
`InpTelemetryInstance`, width, add, exit, the six per-side rows, cap,
`InpStrandedThreshPips` (W + 1), `InpDeadbandPips`, lattice and re-roll
true, auto-eject and breaker false, the warning, the key row not blank.
OK; note the UTC time. Then (FROM = the minute before the OK):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /root/mon_logcheck.awk

Expected: one row `deinit=5`, `reroll=true`, `geo=` as the table,
`rebuild=` as the table, BAD 0. `from=` is a real time: the literal
`HH:MM:00` prints nothing.

**1.4 The other eight**, one chart at a time, the same read-back; then the
checker from the minute after the pilot: 8 rows, BAD 0. A read-back that
does not match: Cancel, never OK; tell Claude.

## 2. AFTER ALL THREE BOXES

1. Archive (desktop, `D:\pipshed`; expected "none."):

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes 'ROLL_STRANDED,ROLL_CLOSING_STUCK,ROLL_REFUSED,DEAL_EVENT_MISSED,REPLAY_SEED_FAILED,EJECT_ACCEPTED,INVARIANT_FAIL,QUARANTINE_HALT' --hours 1

2. pipshed's geometry table (C129): every cell of B, C, D as the table;
   the probes in amber, the control none.
3. Claude: register rows (close the old at each chart's reload time from
   the checker, open the new with the preset commit; a row per side
   where add or exit differ), `research/compass/roundN.json` (windows,
   probes, `reloads` = the register rows, control), one docs patch.

## 3. STOP

FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`, any `REBUILD_*` failure,
a missing POST ok, a `geo=` or `rebuild=` not as the table, a MISMATCH or
a fingerprint that differs, a magic or instance read back on the wrong
chart.

Line count: 72
