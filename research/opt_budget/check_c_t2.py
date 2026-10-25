"""Check C's two t2 presets against the live t1 presets (run from the repo root):

    python research/opt_budget/check_c_t2.py

Read-only; standard library only. `ea/presets_c/<pair>_opt_c_t2.set` must equal `<pair>_opt_c_t1.set` line for line
(same keys, same order) except the values written here by hand (the operator 25 Oct ~04:14Z; sweep_notes swcap):
EURUSD OPT: InpMaxLayers 9 and the warning; AUDCAD OPT: add = exit 18.0, width 4.5 (add / 4, up to the half pip),
stranded 5.5 (width + 1), InpMaxLayers 9 and the warning.
"""
import os
import sys

DIR = os.path.join("ea", "presets_c")
WARN = ("FLEET C two-arm t2 %s OPT -: cap 9, add = exit %.1f, width %.1f, deadband 2.0; lattice + reroll on, "
        "roll gate 0 (IC Markets demo 53071896, wine-c)")
WANT = {
    "EURUSD": {"InpMaxLayers": "9", "InpConfigWarning": WARN % ("EURUSD", 7.0, 2.0)},
    "AUDCAD": {"InpAddPips": "18.0", "InpExitPips": "18.0", "InpWidthPips": "4.5", "InpStrandedThreshPips": "5.5",
               "InpMaxLayers": "9", "InpConfigWarning": WARN % ("AUDCAD", 18.0, 4.5)},
}


def lines(path):
    with open(path, encoding="ascii") as f:
        return [ln.rstrip("\r\n") for ln in f]


def check(pair):
    t1 = lines(os.path.join(DIR, "%s_opt_c_t1.set" % pair.lower()))
    t2 = lines(os.path.join(DIR, "%s_opt_c_t2.set" % pair.lower()))
    k1 = [x.partition("=")[0] for x in t1]
    if k1 != [x.partition("=")[0] for x in t2]:
        return ["keys or order differ from t1"]
    want, faults, seen = WANT[pair], [], set()
    for a, b in zip(t1, t2):
        k, _, v1 = a.partition("=")
        v2 = b.partition("=")[2]
        if k in want:
            seen.add(k)
            if v2 != want[k]:
                faults.append("%s=%s, not %s" % (k, v2, want[k]))
        elif v1 != v2:
            faults.append("%s changed: %s -> %s" % (k, v1, v2))
    if seen != set(want):
        faults.append("missing keys: %s" % sorted(set(want) - seen))
    return faults


def main():
    bad = 0
    for pair in ("EURUSD", "AUDCAD"):
        f = check(pair)
        bad += len(f)
        print("%s OPT t2: %s" % (pair, "OK" if not f else "; ".join(f)))
    print("C t2 presets: %s" % ("ALL OK" if not bad else "%d FAULTS" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
