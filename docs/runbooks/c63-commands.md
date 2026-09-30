This message has a line count at the bottom

# C63 COMMAND SHEET -- THURSDAY 1 OCT (wine-c, then wine-test)

Companion to `docs/architecture/c63-deploy.md` (the plan, Gemini-accepted).
This sheet adds only the exact commands. Written by Claude 30 Sep ~22:00Z
from source at `main` `d8516d5` (EA == `0335f25`). The chat drives it ONE
STEP PER MESSAGE; this file is the reference, not a script to paste whole.

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| S1 | Init prints, in this order: `GRIND_REPLAY ready seeded=` (before recon), `fxgrind CONFIG ... key=<status>` (no key value), `GRIND_SESSION`, `GRIND_LATTICE enable=`, `GRIND_GEOMETRY` (4 dp), `GRIND_REBUILD`; deinit prints `fxgrind deinit reason=` | `fxgrind.mq5` 252, 287, 346-357, 374; `grind_replay.mqh` 183; `grind_config.mqh` | VERIFIED in source |
| S2 | `LATTICE_CONFIG` is an ARCHIVE marker, not a log line: check it with `--codes` | `fxgrind.mq5` 358 | VERIFIED |
| S3 | No `ea/` or preset change between `b6ad868` (wine-c repo, P2) and `main`; 76 EA files at `main` | git | VERIFIED |
| S4 | The log check (s1) was tested on synthetic UTF-16 logs under mawk, then dry-run on wine-c's real 28 Sep log (30 Sep ~22:50Z): 11 inits, geometry as the register, the 16:27Z halt and the 16:57Z shortfall caught as BAD lines | sandbox; wine-c | PASS (installed on wine-c; wine-test still to install) |
| S5 | Compile deinit reason 2 (recompile); Properties reload reason 5 | BOOT s3; 02_TRAPS 25 Sep | VERIFIED (docs) |

## 0. WHEN AND WHAT NOT TO DO

- Slot: **14:30Z (10:30 ET) onward**, after ISM (14:00Z). Not 12:00-13:00Z
  (claims 12:30Z), not 13:15-14:30Z (PMIs 13:45Z, ISM 14:00Z). Finish before
  ~20:00Z; never 20:50-21:00Z. Every spread well under the pair's width.
- Do NOT: run `fxgrind_tests` on either box; compile a FOLDER (one file:
  `Experts/fxmatrix/fxgrind.mq5`); screenshot the Inputs tab's last rows;
  touch the VPS; change geometry (no register rows at C63); `git stash`,
  `git clean`, push from a box.
- STOP (c63-deploy s5) on any BAD line, `lattice=MISSING`, `rebuild=` with
  `true`, `replay=DEFERRED` or `MISSING`, a `geo=` different from s4, or no
  POST ok: stop before the next chart and bring it to the chat.

## 1. THE LOG CHECK (install once per box; read-only)

W0 -- in `ssh box2` (then `ssh box1`) as root, paste this block once; it
writes `/root/c63_logcheck.awk`:

```
cat > /root/c63_logcheck.awk <<'AWKEOF'
# C63 log check (read-only). One row per EA init after FROM (UTC), bad lines in full.
# Usage: iconv -f UTF-16LE -t UTF-8 <log> | tr -d '\r' | awk -v from=HH:MM:SS -f c63_logcheck.awk
function newrec(s) { n++; rec[n] = s; rt[n] = t; rdeinit[n] = (dq[s] > 0) ? dr[s] : "-"; if (dq[s] > 0) dq[s]--; open_[s] = n; return n }
{
  if (!match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+/)) next
  t = substr($0, RSTART, 8)
  if (t < from) next
  src = "?"
  if (match($0, /fxgrind \([A-Z]+,/)) src = substr($0, RSTART + 9, RLENGTH - 10)
  if ($0 ~ /FATAL|CRITICAL|INVARIANT_FAIL|RECON_FAIL|REBUILD_EXIT_FAILED|STARTUP_EXIT_SHORTFALL|REPLAY_INIT_DEFERRED/) { m = $0; sub(/^.*\t/, "", m); bad[++nb] = t " " src " " m }
  if ($0 ~ /grind telemetry POST ok/) { post[src]++; next }
  if ($0 ~ /fxgrind deinit reason=/) { match($0, /reason=[0-9]+/); dr[src] = substr($0, RSTART + 7, RLENGTH - 7); dq[src]++; next }
  if ($0 ~ /GRIND_REPLAY ready/) { k = newrec(src); match($0, /seeded=[0-9]+/); rep[k] = "ready(" substr($0, RSTART + 7, RLENGTH - 7) ")"; next }
  if ($0 ~ /REPLAY_INIT_DEFERRED/) { k = newrec(src); rep[k] = "DEFERRED"; next }
  if ($0 ~ /GRIND_SESSION enable=/) { k = (src in open_) ? open_[src] : newrec(src); match($0, /enable=[a-z]+/); ses[k] = substr($0, RSTART + 7, RLENGTH - 7); next }
  if (!(src in open_)) next
  k = open_[src]
  if ($0 ~ /GRIND_LATTICE enable=/) { match($0, /enable=[a-z]+/); lat[k] = substr($0, RSTART + 7, RLENGTH - 7) }
  else if ($0 ~ /GRIND_GEOMETRY/) {
    s = $0; g = ""
    while (match(s, /(width|add|exit)=[0-9.]+/)) { v = substr(s, RSTART, RLENGTH); sub(/^[a-z]+=/, "", v); sub(/0+$/, "", v); sub(/\.$/, "", v); g = g (g == "" ? "" : "/") v; s = substr(s, RSTART + RLENGTH) }
    split(g, a, "/"); geo[k] = "L" a[1] "/" a[2] "/" a[3] " S" a[4] "/" a[5] "/" a[6] }
  else if ($0 ~ /GRIND_REBUILD/) { match($0, /long=[a-z]+ short=[a-z]+/); r = substr($0, RSTART, RLENGTH); gsub(/long=|short=/, "", r); sub(/ /, "/", r); reb[k] = r; delete open_[src] }
}
END {
  for (i = 1; i <= n; i++)
    printf "%s %-7s deinit=%s replay=%s session=%s lattice=%s geo=%s rebuild=%s\n", rt[i], rec[i], rdeinit[i], (i in rep ? rep[i] : "MISSING"), (i in ses ? ses[i] : "MISSING"), (i in lat ? lat[i] : "MISSING"), (i in geo ? geo[i] : "MISSING"), (i in reb ? reb[i] : "MISSING")
  printf "inits=%d  POST-ok lines per symbol since FROM:", n
  for (s in post) printf " %s=%d", s, post[s]
  printf "\nBAD lines: %d\n", nb
  for (i = 1; i <= nb; i++) print "  " bad[i]
}
AWKEOF
wc -c /root/c63_logcheck.awk
```

Expected: `2493 /root/c63_logcheck.awk`.

Run it (FROM = the UTC time to look from, HH:MM:SS; the log is named by
UTC date):

```
L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:SS -f /root/c63_logcheck.awk
```

**Dry run tonight or before 14:30Z, wine-c only:** the 28 Sep log holds
Fleet C's attach (00:00-00:07Z) and the GBPUSD reattach (16:57Z):

```
L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/20260928.log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=00:00:00 -f /root/c63_logcheck.awk
```

Expected: ~11-12 rows (`replay=MISSING` is right there: `e2ac9fe` has no
ADR-164), `lattice=false`, `rebuild=false/false`, geometry as s4, and one
BAD line `STARTUP_EXIT_SHORTFALL long=0 short=1` at 16:57. If the rows do
not come out, the log format differs from the test: fix the checker before
Thursday, and fall back to plain `grep -a` of the same codes meanwhile.

## 2. WINE-C (box 2, Fleet C) -- FIRST

Access: VNC (06 s9): in `ssh box2` start x11vnc (the 06 s9 line, port
5911); on the desktop `ssh -L 5911:localhost:5911 box2`; viewer
`localhost::5911`.

**C1 pre-flight (read-only, `ssh box2`).** Repo, Experts drift, presets:

```
R=/home/khalid/fxmatrix-repo; X="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/Experts/fxmatrix; sudo -u khalid git -C $R log -1 --format='%h %s' | cut -c1-80; n=0; for f in $R/ea/*.mq5 $R/ea/*.mqh; do cmp -s "$f" "$X/$(basename "$f")" || { n=$((n+1)); echo "DIFF $(basename "$f")"; }; done; echo "files differing Experts vs repo: $n"
```

Expected: repo `b6ad868` or later; a handful of DIFF lines (the ADR-164 and
C77 files: `e2ac9fe` -> `0335f25`), e.g. `grind_replay.mqh` missing or
different.

```
P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/Presets; R=/home/khalid/fxmatrix-repo; for f in $R/ea/presets_c/*_lat.set; do b=$(basename $f); if [ -f "$P/$b" ] && diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done | sort | uniq -c | sort -rn | head -12
```

Expected: 11 lines `SAME_EXCEPT_KEY key_len=43`.

Also: the card `https://linuxc.pipshed.com` LIVE 11/11, no red; spreads
under widths (Market Watch).

**C2 copy (stage 1 code).** As khalid, both folders, then cmp:

```
R=/home/khalid/fxmatrix-repo; for d in Experts Scripts; do sudo -u khalid cp $R/ea/*.mq5 $R/ea/*.mqh "/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/$d/fxmatrix/; done; ok=0; bad=0; for d in Experts Scripts; do for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/$d/fxmatrix/$(basename "$f"); then ok=$((ok+1)); else bad=$((bad+1)); fi; done; done; echo "cmp ok=$ok bad=$bad"
```

Expected: `cmp ok=152 bad=0` (76 files x 2 folders). Copying source does
NOT reload anything; only the compile does.

**C3 compile (GUI, VNC).** MetaEditor -> Navigator -> Experts -> right-click
-> Refresh -> open `Experts/fxmatrix/fxgrind.mq5` -> Compile (that ONE
file). Expect 0 errors, 0 warnings. Note the UTC second of the compile.
This reinitialises all eleven with their CURRENT inputs (lattice off).

**C4 stage 1 check** (FROM = one minute before the compile), then watch
~10 min and look at the card:

Expected: 11 rows, `deinit=2`, `replay=ready(n)`, `session=false`,
`lattice=false`, `rebuild=false/false`, `geo=` as s4, BAD lines 0, POST-ok
counts rising on every symbol. Card LIVE 11/11.

**C5 stage 2 pilot: GBPUSD (GUI).** Chart -> Properties (F7) -> Inputs ->
Load -> `gbpusd_opt_c_lat.set`. Read back BEFORE OK: `InpMagic=22260101`,
`InpTelemetryInstance=GRIND_GBPUSD_OPTC`, `InpVirtualLattice=true`,
`InpAutoEject=false`, width/add/exit 5/9/10, the six per-side -1,
`InpConfigWarning=FLEET C C63 ...`; the key row read, never shown. OK.
Then the log check from the pilot's minute: one row `deinit=5`,
`lattice=true`, `rebuild=false/false`, `replay=ready`, geo L5/9/10 S5/9/10,
BAD 0, POST ok after it.

**C6 the other ten**, one chart at a time, the same read-back (table s4;
TWINS: read `InpTelemetryInstance` and `InpMagic` on the chart BEFORE Load;
`_dup_` preset on the ALT chart only). Log check from the first of the ten:
10 more rows, all `lattice=true`.

**C7 after wine-c:** card LIVE 11/11, no red. From `D:\pipshed`:

```
railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes LATTICE_CONFIG --hours 2
```

Expected: 11 C ids at the reload times (plus the 11 from the compile with
`enable:false` in their detail).

## 3. WINE-TEST (box 1, Fleet B) -- SECOND

Access: `ssh box1-vnc`, then on the box as root the x11vnc line of 06 s4
(port 5910); viewer `localhost::5910`.

**B0** the checker (W0) on this box.

**B1 pre-flight, repo first (read-only):**

```
sudo -u khalid git -C /home/khalid/fxmatrix-repo status -sb | head -5; sudo -u khalid git -C /home/khalid/fxmatrix-repo log -1 --format='%h %s' | cut -c1-80
```

Expected `5685e4f`. What comes next (fetch + checkout/pull to `main`)
depends on this output (branch or detached): decided in the chat.

**B2** the move to `main`, then the same drift check as C1 (more DIFF lines
here: `5685e4f` -> `0335f25` is v2.0 + v2.1 + ADR-164), and the presets
check with `presets_b` (`*_b_lat.set`, 11 `SAME_EXCEPT_KEY key_len=43`).

**B3-B7** as C2-C7 with `presets_b` and the B ids, plus (c63-deploy s4) after
the compile: Tools -> Global Variables (F3), two spot checks,
`GRIND_GEO_EXIT_<magic>_L` and `_S` equal to the exit (e.g. 22260101 ->
10, 22260301 -> 5). This is wine-test's FIRST v2.1 init on an inherited
book: `rebuild=false/false` is the pass (GC63-4); any `true` or
`STARTUP_EXIT_SHORTFALL` is a STOP.

## 4. EXPECTED GEOMETRY (both boxes; register; long = short)

| chart | magic | geo (width/add/exit) |
|---|---|---|
| GBPUSD | 22260101 | L5/9/10 S5/9/10 |
| EURUSD | 22260201 | L7/7/10 S7/7/10 |
| EURGBP | 22260301 | L3/3/5 S3/3/5 |
| AUDCAD | 22260401 | L5/6/10 S5/6/10 |
| AUDCHF | 22260501 | L5/4/10 S5/4/10 |
| CADCHF | 22260601 | L5/4/10 S5/4/10 |
| NZDCHF | 22260701 | L3/3/10 S3/3/10 |
| NZDCAD OPT | 22260801 | L5/8/10 S5/8/10 |
| NZDCAD ALT | 22260802 | L5/10/10 S5/10/10 |
| AUDNZD OPT | 22260901 | L7/8/10 S7/8/10 |
| AUDNZD ALT | 22260902 | L7/10/10 S7/10/10 |

(The checker keys rows by symbol: the two AUDNZD rows and the two NZDCAD
rows tell OPT from ALT by the add, 8 vs 10.)

## 5. AFTER BOTH

- Tonight's `--carrypass --hours 2`: 33 summaries, no I6.
- Records (one docs patch): event log entry, fleet-b.md B2 and fleet-c.md
  A2 records with times, c63-deploy.md s6 rollbacks (if any), backlog C63
  done / C76 C77 live on B and C, BOOT s6. No geometry register rows.

Line count: 220
