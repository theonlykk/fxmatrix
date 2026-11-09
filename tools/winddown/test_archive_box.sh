#!/usr/bin/env bash
# test_archive_box.sh -- tests archive_box.sh on a fake Wine drive_c with an MT5 folder (no MT5, no root needed).
#   bash tools/winddown/test_archive_box.sh        prints TEST|PASS|<n> or stops at the first TEST|FAIL
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "TEST|FAIL|$1"; exit 1; }
n=0; ok() { n=$((n + 1)); echo "TEST|ok|$1"; }
run() { WINE_C="$T/drive_c" OUT="$1" bash "$HERE/archive_box.sh" "$2" 2>&1; }

C="$T/drive_c"; R="$C/Program Files/MetaTrader 5"; A="$C/users/khalid/AppData/Roaming/MetaQuotes"
mkdir -p "$R/Bases/ICMarketsSC-Demo/history/EURUSD" "$R/Bases/ICMarketsSC-Demo/ticks/EURUSD" \
         "$R/Bases/ICMarketsSC-Demo/trades/53066709" "$R/Bases/FTMO Demo 2/ticks/GBPUSD" "$R/Bases/Default/symbols" \
         "$R/Bases/Default/history_notes" "$R/Config" "$R/logs" "$R/MQL5/Files" "$R/MQL5/logs" \
         "$R/MQL5/Shared Projects/x" "$R/Profiles/Charts/Default" "$R/Tester" "$R/Sounds" "$A/Terminal/Common/Files"
echo h1 > "$R/Bases/ICMarketsSC-Demo/history/EURUSD/2026.hcc"
echo t1 > "$R/Bases/ICMarketsSC-Demo/ticks/EURUSD/202611.tkc"
echo t2 > "$R/Bases/FTMO Demo 2/ticks/GBPUSD/202611.tkc"
echo deals > "$R/Bases/ICMarketsSC-Demo/trades/53066709/deals.dat"
echo sym > "$R/Bases/Default/symbols/symbols.dat"; echo nn > "$R/Bases/Default/history_notes/a.txt"
echo cfg > "$R/Config/common.ini"; echo j > "$R/logs/20261109.log"
head -c 200000 /dev/urandom > "$R/MQL5/logs/20261109.log"
echo "a,b" > "$R/MQL5/Files/history_53066709.csv"; echo p > "$R/MQL5/Shared Projects/x/a b.txt"
echo chart > "$R/Profiles/Charts/Default/chart01.chr"; echo exe > "$R/terminal64.exe"; echo wav > "$R/Sounds/ok.wav"
echo gv > "$R/gvariables.dat"; echo common > "$A/Terminal/Common/Files/ticks_common.csv"
mkdir -p "$T/out"

out="$(run "$T/out" wine-x)"; rc=$?
echo "$out" | grep -q '^ARCHIVE|PASS|wine-x$' && [ $rc -eq 0 ] || { echo "$out"; fail "first run did not pass"; }
ok "first run: ARCHIVE|PASS"
echo "$out" | grep -q '^ARCHIVE|COUNT|mt5 manifest 15|core 12|cache 3|appdata manifest 1|appdata 1$' \
    || { echo "$out"; fail "counts"; }
ok "counts: 15 MT5 files = 12 core + 3 cache; 1 AppData file"

zstd -dc "$T/out/winddown_wine-x_core.tar.zst" | tar -tf - > "$T/core.lst"
zstd -dc "$T/out/winddown_wine-x_cache.tar.zst" | tar -tf - > "$T/cache.lst"
zstd -dc "$T/out/winddown_wine-x_appdata.tar.zst" | tar -tf - > "$T/app.lst"
grep -q -e 'Demo/history/' -e '/ticks/' "$T/core.lst" && fail "a cache file is in core"
grep -q 'Default/history_notes/a.txt' "$T/core.lst" || fail "an unrelated folder was excluded"
grep -q 'trades/53066709/deals.dat' "$T/core.lst" || fail "the trades folder is not in core"
grep -q -e '^\./terminal64.exe$' "$T/core.lst" && grep -q '^\./gvariables.dat$' "$T/core.lst" \
    && grep -q 'Sounds/ok.wav' "$T/core.lst" || fail "executable, gvariables or Sounds not kept"
grep -q 'FTMO Demo 2/ticks/GBPUSD/202611.tkc' "$T/cache.lst" || fail "a cache with a space in its server name is missing"
grep -q '^users/khalid/AppData/Roaming/MetaQuotes/Terminal/Common/Files/ticks_common.csv$' "$T/app.lst" \
    || fail "AppData not stored relative to drive_c"
ok "core holds trades, executables, gvariables and an unrelated history_* folder, not caches; cache both servers'; AppData relative"

mkdir -p "$T/x" "$T/xa"
zstd -dc "$T/out/winddown_wine-x_core.tar.zst" | tar -xf - -C "$T/x"
zstd -dc "$T/out/winddown_wine-x_cache.tar.zst" | tar -xf - -C "$T/x"
zstd -dc "$T/out/winddown_wine-x_appdata.tar.zst" | tar -xf - -C "$T/xa"
diff -r "$R" "$T/x" >/dev/null || fail "round trip differs in the MT5 folder"
diff -r "$C/users" "$T/xa/users" >/dev/null || fail "round trip differs in AppData"
ok "round trip: the MT5 folder and AppData identical byte for byte"

(cd "$T/out" && sha256sum -c --quiet winddown_wine-x.sha256) || fail "sha256 file does not verify"
[ "$(wc -l < "$T/out/winddown_wine-x.sha256")" -eq 4 ] || fail "sha256 file does not list four files"
ok "the .sha256 file lists four files and verifies"

out2="$(run "$T/out" wine-x)"; rc=$?
[ $rc -ne 0 ] && echo "$out2" | grep -q '^ARCHIVE|ABORT|.*never overwrite' || { echo "$out2"; fail "second run overwrote"; }
ok "a second run with the same label refuses to overwrite"

for p in terminal64.exe MetaEditor64.exe; do
    bash -c "exec -a 'C:\\Program Files\\MetaTrader 5\\$p' sleep 30" & SP=$!; sleep 0.3
    out3="$(run "$T/out_$p" wine-y)"; rc=$?
    kill $SP 2>/dev/null; wait $SP 2>/dev/null
    [ $rc -ne 0 ] && echo "$out3" | grep -q '^ARCHIVE|ABORT|MT5 or MetaEditor is running (pid' || { echo "$out3"; fail "ran while $p ran"; }
    [ -e "$T/out_$p" ] && fail "wrote files while aborting"
done
ok "refuses while terminal64.exe or MetaEditor64.exe runs (any case), writes nothing"

ln "$R/Config/common.ini" "$R/Config/common_hardlink.ini"
out5="$(bash -c 'WINE_C="$1" OUT="$2" bash "$3" wine-fail # the calling shell mentions terminal64.exe' \
    _ "$C" "$T/out" "$HERE/archive_box.sh" 2>&1)"; rc=$?
rm -f "$R/Config/common_hardlink.ini"
[ $rc -ne 0 ] && echo "$out5" | grep -q '^ARCHIVE|FAIL|wine-fail|core + cache 15 against manifest 16|' \
    || { echo "$out5"; fail "a count mismatch did not fail"; }
ok "a calling shell mentioning terminal64.exe is skipped; a count mismatch (a hard link) exits non-zero with ARCHIVE|FAIL"

rm -rf "$R/Bases/ICMarketsSC-Demo/history" "$R/Bases/ICMarketsSC-Demo/ticks" "$R/Bases/FTMO Demo 2" "$C/users"
out4="$(run "$T/out" wine-z)"; rc=$?
echo "$out4" | grep -q '^ARCHIVE|COUNT|mt5 manifest 12|core 12|cache 0|appdata manifest 0|appdata 0$' && [ $rc -eq 0 ] \
    || { echo "$out4"; fail "no caches, no AppData"; }
ok "a box with no caches and no AppData: empty archives, still PASS"

echo "TEST|PASS|$n"
