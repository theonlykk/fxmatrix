"""extract_ticks.py -- copy the IC tick dumps out of wine-d's wind-down archive, for an independent review.

    py extract_ticks.py            (on the desktop; needs: py -m pip install zstandard)

Reads   D:\\fxmatrix-exports\\winddown\\wine-d\\winddown_wine-d_core.tar.zst   (read-only; never modified)
Writes  D:\\fxmatrix-exports\\ticks_ic\\ticks_53077984_<...>.csv              (only MQL5/Files/ticks_*.csv)
Refuses if D:\\fxmatrix-exports\\ticks_ic already exists. Checks each file's size against the archive's manifest
(winddown_wine-d_manifest.txt) and prints EXTRACT|PASS|<n files>|<bytes> or EXTRACT|FAIL."""
import os
import sys
import tarfile

try:
    import zstandard
except ImportError:
    sys.exit("EXTRACT|ABORT|zstandard missing: run  py -m pip install zstandard  first")

SRC = sys.argv[1] if len(sys.argv) > 1 else r"D:\fxmatrix-exports\winddown\wine-d"
DST = sys.argv[2] if len(sys.argv) > 2 else r"D:\fxmatrix-exports\ticks_ic"
ARC = os.path.join(SRC, "winddown_wine-d_core.tar.zst")
MAN = os.path.join(SRC, "winddown_wine-d_manifest.txt")
PREFIX = "./MQL5/Files/ticks_"

if os.path.exists(DST):
    sys.exit("EXTRACT|ABORT|%s exists: never overwrite" % DST)
want = {}
with open(MAN, encoding="utf-8") as f:
    for line in f:
        root, size, _mtime, path = line.rstrip("\n").split("\t", 3)
        if root == "mt5" and path.startswith(PREFIX) and path.endswith(".csv"):
            want[os.path.basename(path)] = int(size)
os.makedirs(DST)
got = {}
with open(ARC, "rb") as fh:
    with zstandard.ZstdDecompressor().stream_reader(fh) as zr:
        with tarfile.open(fileobj=zr, mode="r|") as tf:
            for m in tf:
                if m.isfile() and m.name.startswith(PREFIX) and m.name.endswith(".csv"):
                    name = os.path.basename(m.name)
                    src = tf.extractfile(m)
                    out = os.path.join(DST, name)
                    with open(out, "wb") as w:
                        while True:
                            b = src.read(1 << 20)
                            if not b:
                                break
                            w.write(b)
                    got[name] = os.path.getsize(out)
                    print("EXTRACT|FILE|%d|%s" % (got[name], name))
bad = [n for n in want if got.get(n) != want[n]] + [n for n in got if n not in want]
if want and not bad:
    print("EXTRACT|PASS|%d|%d" % (len(got), sum(got.values())))
else:
    print("EXTRACT|FAIL|expected %d, got %d, wrong: %s" % (len(want), len(got), bad[:5]))
    sys.exit(1)
