#!/usr/bin/env bash
# archive_box.sh -- wind-down archive of one box's MT5 data folder (docs/runbooks/winddown-export.md s3).
#
#   bash /root/archive_box.sh <label>        (as root on the box; label = the hostname, e.g. wine-test)
#
# Read-only on the MT5 folder. Refuses to run while terminal64.exe runs (the archive must be final, and on
# wine-e nothing may start MT5). Writes four files to /root:
#   winddown_<label>_core.tar.zst   everything kept: Bases (less its history / ticks caches), Config, logs,
#                                   MQL5 (Files, logs, Experts, Presets, Profiles ...), Profiles, Tester, llm-agent
#   winddown_<label>_cache.tar.zst  Bases/*/history and Bases/*/ticks (the broker's bar and tick caches)
#   winddown_<label>_manifest.txt   every regular file in those folders: size, mtime, path (sorted by path)
#   winddown_<label>.sha256         sha256 of the three files above
# Then tests both archives (zstd -t), counts their regular files against the manifest, and prints
# ARCHIVE|PASS or ARCHIVE|FAIL. The MT5 executables, Sounds and the icon are not kept (reinstallable).
set -euo pipefail
LABEL="${1:?usage: bash archive_box.sh <label>}"
MT5_ROOT="${MT5_ROOT:-/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5}"
OUT="${OUT:-/root}"

# Under Wine, MT5's process NAME is not terminal64 (the survey of 8 Nov: `pgrep -a terminal64` found nothing on
# three boxes whose terminals were running), so match the full command line, skipping this script's own ancestors
# (a shell whose command text mentions terminal64 is not MT5).
ancestors() { local p=$$; while [ "${p:-1}" -gt 1 ]; do echo "$p"; p=$(ps -o ppid= -p "$p" | tr -d ' '); done; }
RUNNING=$(pgrep -f terminal64 | grep -vxF -f <(ancestors) || true)
if [ -n "$RUNNING" ]; then
    echo "ARCHIVE|ABORT|terminal64.exe is running (pid $(echo $RUNNING)): exit MT5 first (runbook s3 step 3)"
    exit 1
fi
[ -d "$MT5_ROOT" ] || { echo "ARCHIVE|ABORT|no MT5 folder at $MT5_ROOT"; exit 1; }
cd "$MT5_ROOT"

DIRS=()
for d in Bases Config logs MQL5 Profiles Tester llm-agent; do [ -e "$d" ] && DIRS+=("$d"); done
CACHE=()
while IFS= read -r -d '' c; do CACHE+=("$c"); done < <(find Bases -mindepth 2 -maxdepth 2 -type d \( -name history -o -name ticks \) -print0 2>/dev/null | sort -z)

CORE="$OUT/winddown_${LABEL}_core.tar.zst"
CACH="$OUT/winddown_${LABEL}_cache.tar.zst"
MAN="$OUT/winddown_${LABEL}_manifest.txt"
SUM="$OUT/winddown_${LABEL}.sha256"
for f in "$CORE" "$CACH" "$MAN" "$SUM"; do
    [ -e "$f" ] && { echo "ARCHIVE|ABORT|$f exists: never overwrite (move it away first)"; exit 1; }
done

echo "ARCHIVE|START|$LABEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)|folders ${DIRS[*]}|caches ${#CACHE[@]}"
find "${DIRS[@]}" -type f -printf '%s\t%TY-%Tm-%Td_%TH:%TM\t%p\n' | LC_ALL=C sort -t $'\t' -k3 > "$MAN"
N_MAN=$(wc -l < "$MAN")

EXCL=()
for c in "${CACHE[@]}"; do EXCL+=(--exclude="./$c"); done
# archive with ./ paths so each exclude names exactly one folder (no wildcards)
tar -cf - "${EXCL[@]}" "${DIRS[@]/#/./}" | zstd -T0 -10 -q -o "$CORE"
if [ ${#CACHE[@]} -gt 0 ]; then
    tar -cf - "${CACHE[@]/#/./}" | zstd -T0 -3 -q -o "$CACH"
else
    tar -cf - --files-from /dev/null | zstd -q -o "$CACH"
fi

zstd -t -q "$CORE" && zstd -t -q "$CACH"
N_CORE=$(zstd -dc "$CORE" | tar -tvf - | grep -c '^-' || true)
N_CACH=$(zstd -dc "$CACH" | tar -tvf - | grep -c '^-' || true)

cd "$OUT"
sha256sum "$(basename "$CORE")" "$(basename "$CACH")" "$(basename "$MAN")" > "$SUM"

echo "ARCHIVE|COUNT|manifest $N_MAN|core $N_CORE|cache $N_CACH"
ls -l "$CORE" "$CACH" "$MAN" "$SUM" | awk '{print "ARCHIVE|FILE|" $5 "|" $9}'
cat "$SUM" | sed 's/^/ARCHIVE|SHA256|/'
if [ "$N_MAN" -gt 0 ] && [ $((N_CORE + N_CACH)) -eq "$N_MAN" ]; then
    echo "ARCHIVE|PASS|$LABEL"
else
    echo "ARCHIVE|FAIL|$LABEL|core + cache $((N_CORE + N_CACH)) against manifest $N_MAN"
    exit 1
fi
