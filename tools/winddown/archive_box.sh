#!/usr/bin/env bash
# archive_box.sh -- wind-down archive of one box's MT5 (docs/runbooks/winddown-export.md s3).
#
#   bash /root/archive_box.sh <label>        (as root on the box; label = the hostname, e.g. wine-test)
#
# Read-only on the box. Refuses to run while MT5 or MetaEditor runs (the archive must be final, and on wine-e
# nothing may start MT5) or if any output file already exists. Keeps EVERYTHING in the MT5 folder (the
# executables too: build 6231 is the only build that starts under Wine 9.0, 06_LINUX_WINE_BOX C161) and the Wine
# user's MetaQuotes AppData (MQL5's common Files folder). Writes five files to /root:
#   winddown_<label>_core.tar.zst     the MT5 folder, less Bases/*/history and Bases/*/ticks
#   winddown_<label>_cache.tar.zst    Bases/*/history and Bases/*/ticks (the broker's bar and tick caches)
#   winddown_<label>_appdata.tar.zst  drive_c/users/*/AppData/Roaming/MetaQuotes (empty archive if absent)
#   winddown_<label>_manifest.txt     every regular file: root (mt5 / appdata), size, mtime, path
#   winddown_<label>.sha256           sha256 of the four files above
# Then tests the archives (zstd -t), counts their regular files against the manifest, root by root, and prints
# ARCHIVE|PASS or ARCHIVE|FAIL. Any failed tar, zstd or count stops it (set -euo pipefail; no `|| true` on them).
set -euo pipefail
LABEL="${1:?usage: bash archive_box.sh <label>}"
WINE_C="${WINE_C:-/home/khalid/.mt5/drive_c}"
MT5_ROOT="${MT5_ROOT:-$WINE_C/Program Files/MetaTrader 5}"
OUT="${OUT:-/root}"

# Under Wine, MT5's process NAME is not terminal64 (the survey of 8 Nov: `pgrep -a terminal64` found nothing on
# three boxes whose terminals were running), so match the full command line, any case, skipping this script's
# own ancestors (a shell whose command text mentions terminal64 is not MT5).
ancestors() { local p=$$; while [ "${p:-1}" -gt 1 ]; do echo "$p"; p=$(ps -o ppid= -p "$p" | tr -d ' '); done; }
RUNNING=$(pgrep -fi 'terminal64|metaeditor64' | grep -vxF -f <(ancestors) || true)
if [ -n "$RUNNING" ]; then
    echo "ARCHIVE|ABORT|MT5 or MetaEditor is running (pid $(echo $RUNNING)): exit it first (runbook s3 step 3)"
    exit 1
fi
[ -d "$MT5_ROOT" ] || { echo "ARCHIVE|ABORT|no MT5 folder at $MT5_ROOT"; exit 1; }

CORE="$OUT/winddown_${LABEL}_core.tar.zst"
CACH="$OUT/winddown_${LABEL}_cache.tar.zst"
APPD="$OUT/winddown_${LABEL}_appdata.tar.zst"
MAN="$OUT/winddown_${LABEL}_manifest.txt"
SUM="$OUT/winddown_${LABEL}.sha256"
for f in "$CORE" "$CACH" "$APPD" "$MAN" "$SUM"; do
    [ -e "$f" ] && { echo "ARCHIVE|ABORT|$f exists: never overwrite (move it away first)"; exit 1; }
done

# the MetaQuotes AppData folders (normally one, under the Wine user)
APPDATA=()
while IFS= read -r -d '' a; do APPDATA+=("$a"); done < <(find "$WINE_C/users" -mindepth 4 -maxdepth 4 -type d \
    -path '*/AppData/Roaming/MetaQuotes' -print0 2>/dev/null | sort -z)

cd "$MT5_ROOT"
CACHE=()
while IFS= read -r -d '' c; do CACHE+=("$c"); done < <(find Bases -mindepth 2 -maxdepth 2 -type d \
    \( -name history -o -name ticks \) -print0 2>/dev/null | sort -z)

echo "ARCHIVE|START|$LABEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)|caches ${#CACHE[@]}|appdata ${#APPDATA[@]}"
{
    find . -type f -printf 'mt5\t%s\t%TY-%Tm-%Td_%TH:%TM\t%p\n'
    for a in "${APPDATA[@]}"; do find "$a" -type f -printf 'appdata\t%s\t%TY-%Tm-%Td_%TH:%TM\t%p\n'; done
} | LC_ALL=C sort -t $'\t' -k1,1 -k4 > "$MAN"
N_MT5=$(awk -F'\t' '$1 == "mt5"' "$MAN" | wc -l)
N_APP=$(awk -F'\t' '$1 == "appdata"' "$MAN" | wc -l)

EXCL=()
for c in "${CACHE[@]}"; do EXCL+=(--exclude="./$c"); done
# ./ paths, anchored, no wildcards: each exclude names exactly one folder
tar -cf - --anchored --no-wildcards "${EXCL[@]}" . | zstd -T0 -10 -q -o "$CORE"
if [ ${#CACHE[@]} -gt 0 ]; then
    tar -cf - "${CACHE[@]/#/./}" | zstd -T0 -3 -q -o "$CACH"
else
    tar -cf - --files-from /dev/null | zstd -q -o "$CACH"
fi
if [ ${#APPDATA[@]} -gt 0 ]; then
    REL=()
    for a in "${APPDATA[@]}"; do REL+=("${a#"$WINE_C"/}"); done      # stored as users/<user>/AppData/...
    tar -cf - -C "$WINE_C" "${REL[@]}" | zstd -T0 -10 -q -o "$APPD"
else
    tar -cf - --files-from /dev/null | zstd -q -o "$APPD"
fi

zstd -t -q "$CORE"; zstd -t -q "$CACH"; zstd -t -q "$APPD"
count() { zstd -dc "$1" | tar -tvf - | awk '/^-/{n++} END{print n+0}'; }
N_CORE=$(count "$CORE"); N_CACH=$(count "$CACH"); N_APPD=$(count "$APPD")

cd "$OUT"
sha256sum "$(basename "$CORE")" "$(basename "$CACH")" "$(basename "$APPD")" "$(basename "$MAN")" > "$SUM"

echo "ARCHIVE|COUNT|mt5 manifest $N_MT5|core $N_CORE|cache $N_CACH|appdata manifest $N_APP|appdata $N_APPD"
ls -l "$CORE" "$CACH" "$APPD" "$MAN" "$SUM" | awk '{print "ARCHIVE|FILE|" $5 "|" $9}'
sed 's/^/ARCHIVE|SHA256|/' "$SUM"
if [ "$N_MT5" -gt 0 ] && [ $((N_CORE + N_CACH)) -eq "$N_MT5" ] && [ "$N_APPD" -eq "$N_APP" ]; then
    echo "ARCHIVE|PASS|$LABEL"
else
    echo "ARCHIVE|FAIL|$LABEL|core + cache $((N_CORE + N_CACH)) against manifest $N_MT5|appdata $N_APPD against $N_APP"
    exit 1
fi
