This message has a line count at the bottom

# MONDAY NIGHT 5 OCT -- SCORE ROUND 1, THEN THE BUILD (ONE CHECKLIST)

| | |
|---|---|
| Status | Claude, 5 Oct ~00:50Z (HANDOFF s54). Commands rehearsed against `main` `0c266b6` in the sandbox where they can be (s3.3 diff, the log checker on a synthetic UTF-16 log under awk and mawk, the scorer on the 2 Oct export) |
| Uses | `docs/runbooks/compass-round.md` s4.2 (scoring), `docs/runbooks/monday-build-2026-10-05.md` (the build: its STOP list and Gemini rulings stand), `docs/runbooks/c63-commands.md` s1 (the checker this extends) |
| When | After 22:00Z Mon 5 Oct (6pm ET): round 1's second window closes. Never 20:50-21:15Z. One shell step per message; the operator runs, Claude reads |

## 0. BEFORE 22:00Z (any time Monday, read-only)

**0.1 Install the Monday log checker on each box** (`ssh box1`, `ssh box2`,
`ssh root@216.128.158.33`; as root). It is the C63 checker (c63-commands
s1) with a `reroll=` column and `AMBIGUOUS_*`, `duplicate magic` and
`REBUILD_EXIT_UNREADABLE` added to the bad lines; the session column is
dropped. Paste once per box:

```
cat > /root/mon_logcheck.awk <<'AWKEOF'
# Monday build log check (read-only; c63 checker + reroll). One row per EA init after FROM (UTC), bad lines in full.
# Usage: iconv -f UTF-16LE -t UTF-8 <log> | tr -d '\r' | awk -v from=HH:MM:SS -f mon_logcheck.awk
function newrec(s) { n++; rec[n] = s; rt[n] = t; rdeinit[n] = (dq[s] > 0) ? dr[s] : "-"; if (dq[s] > 0) dq[s]--; open_[s] = n; return n }
{
  if (!match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+/)) next
  t = substr($0, RSTART, 8)
  if (t < from) next
  src = "?"
  if (match($0, /fxgrind \([A-Z]+,/)) src = substr($0, RSTART + 9, RLENGTH - 10)
  if ($0 ~ /FATAL|CRITICAL|INVARIANT_FAIL|RECON_FAIL|REBUILD_EXIT_FAILED|REBUILD_EXIT_UNREADABLE|STARTUP_EXIT_SHORTFALL|REPLAY_INIT_DEFERRED|AMBIGUOUS_|duplicate magic/) { m = $0; sub(/^.*\t/, "", m); bad[++nb] = t " " src " " m }
  if ($0 ~ /grind telemetry POST ok/) { post[src]++; next }
  if ($0 ~ /fxgrind deinit reason=/) { match($0, /reason=[0-9]+/); dr[src] = substr($0, RSTART + 7, RLENGTH - 7); dq[src]++; next }
  if ($0 ~ /GRIND_REPLAY ready/) { k = newrec(src); match($0, /seeded=[0-9]+/); rep[k] = "ready(" substr($0, RSTART + 7, RLENGTH - 7) ")"; next }
  if ($0 ~ /REPLAY_INIT_DEFERRED/) { k = newrec(src); rep[k] = "DEFERRED"; next }
  if ($0 ~ /GRIND_SESSION enable=/) { k = (src in open_) ? open_[src] : newrec(src); match($0, /enable=[a-z]+/); ses[k] = substr($0, RSTART + 7, RLENGTH - 7); next }
  if (!(src in open_)) next
  k = open_[src]
  if ($0 ~ /GRIND_LATTICE enable=/) { match($0, /enable=[a-z]+/); lat[k] = substr($0, RSTART + 7, RLENGTH - 7) }
  else if ($0 ~ /GRIND_REROLL enable=/) { match($0, /enable=[a-z]+/); rr[k] = substr($0, RSTART + 7, RLENGTH - 7) }
  else if ($0 ~ /GRIND_GEOMETRY/) {
    s = $0; g = ""
    while (match(s, /(width|add|exit)=[0-9.]+/)) { v = substr(s, RSTART, RLENGTH); sub(/^[a-z]+=/, "", v); sub(/0+$/, "", v); sub(/\.$/, "", v); g = g (g == "" ? "" : "/") v; s = substr(s, RSTART + RLENGTH) }
    split(g, a, "/"); geo[k] = "L" a[1] "/" a[2] "/" a[3] " S" a[4] "/" a[5] "/" a[6] }
  else if ($0 ~ /GRIND_REBUILD/) { match($0, /long=[a-z]+ short=[a-z]+/); r = substr($0, RSTART, RLENGTH); gsub(/long=|short=/, "", r); sub(/ /, "/", r); reb[k] = r; delete open_[src] }
}
END {
  for (i = 1; i <= n; i++)
    printf "%s %-7s deinit=%s replay=%s lattice=%s reroll=%s geo=%s rebuild=%s\n", rt[i], rec[i], rdeinit[i], (i in rep ? rep[i] : "MISSING"), (i in lat ? lat[i] : "MISSING"), (i in rr ? rr[i] : "MISSING"), (i in geo ? geo[i] : "MISSING"), (i in reb ? reb[i] : "MISSING")
  printf "inits=%d  POST-ok lines per symbol since FROM:", n
  for (s in post) printf " %s=%d", s, post[s]
  printf "\nBAD lines: %d\n", nb
  for (i = 1; i <= nb; i++) print "  " bad[i]
}
AWKEOF
wc -c /root/mon_logcheck.awk
```

Expected: `2688 /root/mon_logcheck.awk`.

**0.2 Tunnels and viewers:** VNC 5912 (wine-d), 5911 (wine-c), 5910
(wine-test); keep each viewer open for the night.

**0.3 Grants:** Downloads and `D:\fxmatrix\temp` connected (device
folders), so Claude reads every file directly.

## 1. SCORE ROUND 1 (22:05Z onward; the operator makes three files, Claude scores)

**1.1 Study export** (desktop, `D:\pipshed`):

```
railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-study --days 14 | Set-Content -Encoding utf8 "$HOME\Downloads\study_2026-10-05_14d.jsonl"
```

Claude checks the last fill is after 22:00Z (else the scorer prints
"provisional": wait a few minutes and export again).

**1.2 IC bid/ask (reported only, never deciding; skip if late).** wine-c,
VNC: Navigator -> Scripts -> fxmatrix -> `grind_bidask_dump` onto any
chart; `InpFrom` = `2026.10.02 01:00` (server = UTC + 3: window 1 opened
Thu 22:00Z), `InpTo` empty; OK. Then on the desktop:

```
mkdir "$HOME\Downloads\bidask_ic_1005" -Force | Out-Null; scp "box2:/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/bidask_53071896_*.csv" "$HOME\Downloads\bidask_ic_1005"
```

(scp to box2 may ask root's password: 02_TRAPS 30 Sep. No trailing
backslash on the target: 02_TRAPS 3 Oct morning.)

**1.3 Journals for `disconnects.py`**, one folder PER BOX: the tool reads
the date from each file name's first eight characters, and all three
boxes name their files `YYYYMMDD.log`. Never rename them; never mix boxes
in one folder. Days: 1, 2, 4, 5 Oct (UTC files; the windows are Thu
22:00Z-Fri 22:00Z and Sun 22:00Z-Mon 22:00Z). One box per step:

```
mkdir "$HOME\Downloads\journals_1005\wine-test" -Force | Out-Null; scp "box1:/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/logs/2026100[1245].log" "$HOME\Downloads\journals_1005\wine-test"
```

then `box2` -> `wine-c`, then `root@216.128.158.33` -> `wine-d`.

**1.4 Claude scores** (sandbox, from Downloads): `compass_score.py
--export study_2026-10-05_14d.jsonl --round round1.json --bidask
bidask_ic_1005`, then `disconnects.py` per box folder. The report: the
verdict table under the fixed $1.19 AND under GC-1 (the control's six
gaps), the open-MTM and disconnect reports, the three VOID / cut rows
(NZDCHF long, AUDCHF long C). **The operator chooses which threshold
decides round 1.** The verdict then feeds `scripts/ic_geometry.json`
(next session's presets), not tonight's build.

## 2. THE BUILD (runbook monday-build s3, per box: wine-d, wine-c, wine-test)

**2.1 Read the box** (monday-build 3.1): card LIVE 11/11; the twins'
positions and orders (`GRIND|ALT|`).

**2.2 Retire the two twins** (monday-build 3.2; read `InpTelemetryInstance`
and `InpMagic` in F7, then Cancel; Remove; entries first; Close By; the
rest at market). **Ask the operator's go before the first close.**
Check the removals in the box's Experts log (UTF-16, field 3 the time):

```
L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | grep -a "deinit reason=1" | tail -4
```

Expected: two lines, the NZDCAD and AUDNZD charts, at the removal times.

**2.3 Repo to `main`** (monday-build 3.3; the diff line must print
nothing: checked empty at `0c266b6`). **2.4 Copy to BOTH copies, `cmp`
drift 0** (3.4). **2.5 Compile ONE file** (3.5: wine-d and wine-test
`Experts/fxmatrix/fxgrind.mq5`; **wine-c `Scripts/fxmatrix/fxgrind.mq5`**).

**2.6 Check the re-init** (FROM = one minute before the compile):

```
L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:SS -f /root/mon_logcheck.awk
```

Expected: 9 rows, `deinit=2` (recompile), `replay=ready(n)`,
`lattice=true`, `reroll=false`, `geo=` as the register (D1 values on C
and D), `rebuild=false/false`, BAD 0, POST-ok rising. Then the build
stamp of the pilot from the archive (desktop, `D:\pipshed`):

```
railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --table config_events --instance GRIND_GBPUSD_OPTD --limit 2
```

Expected: the newest INIT row's `ea_build` = `fxgrind 2026.10.05 <the
compile time>` (`_OPTC` on wine-c: its Scripts `.ex5`; `_OPTB` on
wine-test).

**2.7 Re-roll ON chart by chart** (3.7: F7 ON THE CHART ->
`InpLatticeReroll=true` -> OK; GBPUSD pilot, then eight). The checker from
the pilot's minute: one row per chart, `deinit=5`, `reroll=true`,
everything else as 2.6.

**STOP** (monday-build s3, unchanged): FATAL, CRITICAL, `INVARIANT_FAIL`,
`RECON_FAIL`, any `REBUILD_*`, a missing POST ok, a changed `geo=`, a twin
order or position left, a burst of `ROLL_ACCEPTED` with `"reroll":true`
beyond the fully rolled sides, or two re-rolls of one side with the same
`ea_time_ms`. Expected, not a STOP: the fully rolled sides re-roll on the
first ticks if the market is past their next level: at the 5 Oct 02:52Z
read EURGBP long B, C, D (C and D within a roll of stuck), EURUSD long B,
C, NZDCHF long B, C, D (HANDOFF s56, s57).

## 3. AFTER ALL THREE BOXES

1. pipshed C119 (`git am` the Downloads patch, tree `e3b23a94`, push,
   Railway): B, C, D strips 9/9, the twins' critical rows resolved.
2. The roll-watch codes (c63-commands s6.2) over the build's hours.
3. Claude: one docs patch (scores, choice of threshold, build times,
   register rows for the twins' close, traps).
4. Next session: the presets from the verdict (`scripts/ic_presets.py`),
   the cap-10 reload (`docs/runbooks/cap10-reload.md`), the IC twins'
   Global Variables (monday-build s7).

## 4. REHEARSED IN THE SANDBOX (5 Oct ~00:50Z)

- monday-build s3.3: `git diff --stat 2859be6 origin/main -- 'ea/*.mq5'
  'ea/*.mqh'` empty at `0c266b6`.
- The checker (0.1): a synthetic UTF-16 log (a reason-5 reload with
  `reroll=true`, a second with `reroll=false` and an `AMBIGUOUS_ADD_LONG`,
  a reason-1 removal before FROM) gives two rows, the right columns and
  one BAD line, identical under awk and mawk; 2688 bytes.
- The scorer with both thresholds on the 2 Oct export (provisional GC-1
  2.41); `--bidask` and `disconnects.py` are covered by their tests
  (39 + 9).
- Not rehearsable here: the scp globs, the box paths (from 06 s9-s10 and
  the traps), the Railway commands (used 2-3 Oct).

Line count: 189
