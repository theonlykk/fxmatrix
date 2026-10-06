# Build log check (read-only): mon_logcheck.awk (monday-night 0.1) + the roll gate (ADR-166) and
# the API inputs (v2.2a, C100; WARN_API_ENTRY_STOP is BAD: Gemini GW7-5). One row per EA init after FROM (UTC); BAD lines in full; ROLL_DEFERRED
# lines counted per symbol (the gate holding a due roll).
# Usage (box shell): iconv -f UTF-16LE -t UTF-8 <MQL5 log> | tr -d '\r' | awk -v from=HH:MM:SS -f build_logcheck.awk
function newrec(s) { n++; rec[n] = s; rt[n] = t; rdeinit[n] = (dq[s] > 0) ? dr[s] : "-"; if (dq[s] > 0) dq[s]--; open_[s] = n; return n }
{
  if (!match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+/)) next
  t = substr($0, RSTART, 8)
  if (t < from) next
  src = "?"
  if (match($0, /fxgrind \([A-Z]+,/)) src = substr($0, RSTART + 9, RLENGTH - 10)
  if ($0 ~ /FATAL|CRITICAL|INVARIANT_FAIL|RECON_FAIL|REBUILD_EXIT_FAILED|REBUILD_EXIT_UNREADABLE|STARTUP_EXIT_SHORTFALL|REPLAY_INIT_DEFERRED|AMBIGUOUS_|duplicate magic|API_LIMITS_INVALID|API_LIMITS_MISMATCH|WARN_API_ENTRY_STOP/) { m = $0; sub(/^.*\t/, "", m); bad[++nb] = t " " src " " m }
  if ($0 ~ /grind telemetry POST ok/) { post[src]++; next }
  if ($0 ~ /ROLL_DEFERRED/) { deferred[src]++; next }
  if ($0 ~ /fxgrind deinit reason=/) { match($0, /reason=[0-9]+/); dr[src] = substr($0, RSTART + 7, RLENGTH - 7); dq[src]++; next }
  if ($0 ~ /GRIND_REPLAY ready/) { k = newrec(src); match($0, /seeded=[0-9]+/); rep[k] = "ready(" substr($0, RSTART + 7, RLENGTH - 7) ")"; next }
  if ($0 ~ /REPLAY_INIT_DEFERRED/) { k = newrec(src); rep[k] = "DEFERRED"; next }
  if ($0 ~ /GRIND_SESSION enable=/) { k = (src in open_) ? open_[src] : newrec(src); match($0, /enable=[a-z]+/); ses[k] = substr($0, RSTART + 7, RLENGTH - 7); next }
  if (!(src in open_)) next
  k = open_[src]
  if ($0 ~ /GRIND_LATTICE enable=/) { match($0, /enable=[a-z]+/); lat[k] = substr($0, RSTART + 7, RLENGTH - 7) }
  else if ($0 ~ /GRIND_REROLL enable=/) { match($0, /enable=[a-z]+/); rr[k] = substr($0, RSTART + 7, RLENGTH - 7) }
  else if ($0 ~ /GRIND_ROLL_GATE opposite_max=/) { match($0, /opposite_max=-?[0-9]+/); gate[k] = substr($0, RSTART + 13, RLENGTH - 13) }
  else if ($0 ~ /GRIND_API_LIMITS entry_stop=/) { match($0, /entry_stop=[0-9]+/); a1 = substr($0, RSTART + 11, RLENGTH - 11); match($0, /soft_warn=[0-9]+/); api[k] = a1 "/" substr($0, RSTART + 10, RLENGTH - 10) }
  else if ($0 ~ /GRIND_GEOMETRY/) {
    s = $0; g = ""
    while (match(s, /(width|add|exit)=[0-9.]+/)) { v = substr(s, RSTART, RLENGTH); sub(/^[a-z]+=/, "", v); sub(/0+$/, "", v); sub(/\.$/, "", v); g = g (g == "" ? "" : "/") v; s = substr(s, RSTART + RLENGTH) }
    split(g, a, "/"); geo[k] = "L" a[1] "/" a[2] "/" a[3] " S" a[4] "/" a[5] "/" a[6] }
  else if ($0 ~ /GRIND_REBUILD/) { match($0, /long=[a-z]+ short=[a-z]+/); r = substr($0, RSTART, RLENGTH); gsub(/long=|short=/, "", r); sub(/ /, "/", r); reb[k] = r; delete open_[src] }
}
END {
  for (i = 1; i <= n; i++)
    printf "%s %-7s deinit=%s replay=%s lattice=%s reroll=%s gate=%s api=%s geo=%s rebuild=%s\n", rt[i], rec[i], rdeinit[i], (i in rep ? rep[i] : "MISSING"), (i in lat ? lat[i] : "MISSING"), (i in rr ? rr[i] : "MISSING"), (i in gate ? gate[i] : "MISSING"), (i in api ? api[i] : "MISSING"), (i in geo ? geo[i] : "MISSING"), (i in reb ? reb[i] : "MISSING")
  printf "inits=%d  POST-ok lines per symbol since FROM:", n
  for (s in post) printf " %s=%d", s, post[s]
  printf "\nROLL_DEFERRED lines per symbol since FROM:"
  for (s in deferred) printf " %s=%d", s, deferred[s]
  printf "\nBAD lines: %d\n", nb
  for (i = 1; i <= nb; i++) print "  " bad[i]
}
