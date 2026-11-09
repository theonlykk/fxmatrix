#!/usr/bin/env bash
# test_archive_box.sh -- tests archive_box.sh on a fake MT5 folder (no MT5, no root needed).
#   bash tools/winddown/test_archive_box.sh        prints TEST|PASS|<n> or stops at the first TEST|FAIL
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "TEST|FAIL|$1"; exit 1; }
n=0; ok() { n=$((n + 1)); echo "TEST|ok|$1"; }

R="$T/drive_c/Program Files/MetaTrader 5"
mkdir -p "$R/Bases/ICMarketsSC-Demo/history/EURUSD" "$R/Bases/ICMarketsSC-Demo/ticks/EURUSD" \
         "$R/Bases/ICMarketsSC-Demo/trades/53066709" "$R/Bases/FTMO Demo 2/ticks/GBPUSD" "$R/Bases/Default/symbols" \
         "$R/Config" "$R/logs" "$R/MQL5/Files" "$R/MQL5/logs" "$R/MQL5/Shared Projects/x" "$R/Profiles/Charts/Default" \
         "$R/Tester" "$R/Sounds"
echo h1 > "$R/Bases/ICMarketsSC-Demo/history/EURUSD/2026.hcc"
echo t1 > "$R/Bases/ICMarketsSC-Demo/ticks/EURUSD/202611.tkc"
echo t2 > "$R/Bases/FTMO Demo 2/ticks/GBPUSD/202611.tkc"
echo deals > "$R/Bases/ICMarketsSC-Demo/trades/53066709/deals.dat"
echo sym > "$R/Bases/Default/symbols/symbols.dat"
echo cfg > "$R/Config/common.ini"; echo j > "$R/logs/20261109.log"
head -c 200000 /dev/urandom > "$R/MQL5/logs/20261109.log"
echo "a,b" > "$R/MQL5/Files/history_53066709.csv"; echo p > "$R/MQL5/Shared Projects/x/a b.txt"
echo chart > "$R/Profiles/Charts/Default/chart01.chr"; echo exe > "$R/terminal64.exe"; echo wav > "$R/Sounds/ok.wav"
mkdir -p "$T/out"

out="$(MT5_ROOT="$R" OUT="$T/out" bash "$HERE/archive_box.sh" wine-x 2>&1)"; rc=$?
echo "$out" | grep -q '^ARCHIVE|PASS|wine-x$' && [ $rc -eq 0 ] || { echo "$out"; fail "first run did not pass"; }
ok "first run: ARCHIVE|PASS"
echo "$out" | grep -q '^ARCHIVE|COUNT|manifest 11|core 8|cache 3$' || { echo "$out"; fail "counts"; }
ok "counts: 11 files = 8 core + 3 cache (executable and Sounds not kept)"

zstd -dc "$T/out/winddown_wine-x_core.tar.zst" | tar -tf - > "$T/core.lst"
zstd -dc "$T/out/winddown_wine-x_cache.tar.zst" | tar -tf - > "$T/cache.lst"
grep -q -e '/history/' -e '/ticks/' "$T/core.lst" && fail "a cache file is in core"
grep -q 'trades/53066709/deals.dat' "$T/core.lst" || fail "the trades folder is not in core"
grep -q 'FTMO Demo 2/ticks/GBPUSD/202611.tkc' "$T/cache.lst" || fail "a cache with a space in its server name is missing"
grep -q -e 'terminal64.exe' -e 'Sounds' "$T/core.lst" && fail "executable or Sounds kept"
ok "core holds trades, not caches; cache holds both servers' caches"

mkdir -p "$T/x"; zstd -dc "$T/out/winddown_wine-x_core.tar.zst" | tar -xf - -C "$T/x"
zstd -dc "$T/out/winddown_wine-x_cache.tar.zst" | tar -xf - -C "$T/x"
for d in Bases Config logs MQL5 Profiles Tester; do diff -r "$R/$d" "$T/x/$d" >/dev/null || fail "round trip differs in $d"; done
ok "round trip: every kept folder identical byte for byte"

(cd "$T/out" && sha256sum -c --quiet winddown_wine-x.sha256) || fail "sha256 file does not verify"
ok "the .sha256 file verifies"

out2="$(MT5_ROOT="$R" OUT="$T/out" bash "$HERE/archive_box.sh" wine-x 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out2" | grep -q '^ARCHIVE|ABORT|.*never overwrite' || { echo "$out2"; fail "second run overwrote"; }
ok "a second run with the same label refuses to overwrite"

bash -c 'exec -a terminal64.exe sleep 30' & SP=$!; sleep 0.3
out3="$(MT5_ROOT="$R" OUT="$T/out2" bash "$HERE/archive_box.sh" wine-y 2>&1)"; rc=$?
kill $SP 2>/dev/null
[ $rc -ne 0 ] && echo "$out3" | grep -q '^ARCHIVE|ABORT|terminal64.exe is running (pid' || { echo "$out3"; fail "ran while terminal64 ran"; }
[ -e "$T/out2" ] && ls "$T/out2" | grep -q . && fail "wrote files while aborting"
ok "refuses while terminal64.exe runs, writes nothing"

rm -rf "$R/Bases/ICMarketsSC-Demo/history" "$R/Bases/ICMarketsSC-Demo/ticks" "$R/Bases/FTMO Demo 2"
out4="$(MT5_ROOT="$R" OUT="$T/out" bash "$HERE/archive_box.sh" wine-z 2>&1)"; rc=$?
echo "$out4" | grep -q '^ARCHIVE|COUNT|manifest 8|core 8|cache 0$' && [ $rc -eq 0 ] || { echo "$out4"; fail "no caches"; }
ok "a box with no caches: empty cache archive, still PASS"

echo "TEST|PASS|$n"
