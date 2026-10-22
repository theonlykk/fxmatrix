"""Check E's six ALT t2 presets against the reviewed t1 ALT presets (run from the repo root):

    python research/alt_adds/check_e_t2.py

Read-only; standard library only. For each pair, `ea/presets_e/<pair>_alt_e_t2.set` must equal
`<pair>_alt_e_t1.set` line for line (same keys, same order), except exactly these five values, each equal to
the expected value written here by hand (q88 of the excursion method, results_2026-10-22.md):
  InpAddPips = InpExitPips = the add; InpWidthPips = add / 4 rounded UP to the half pip (ADR-153: add / width
  <= 4); InpStrandedThreshPips = width + 1; InpConfigWarning = the t2 / q88 text.
Prints one line per file, OK or the faults; exit 1 on any fault.
"""
import os
import sys

DIR = os.path.join("ea", "presets_e")
ADD = {"GBPUSD": 21, "EURUSD": 18, "EURGBP": 16, "AUDCAD": 26, "AUDCHF": 20, "CADCHF": 9}
WIDTH = {"GBPUSD": 5.5, "EURUSD": 4.5, "EURGBP": 4.0, "AUDCAD": 6.5, "AUDCHF": 5.0, "CADCHF": 2.5}  # by hand
ALLOWED = {"InpAddPips", "InpExitPips", "InpWidthPips", "InpStrandedThreshPips", "InpConfigWarning"}


def lines(path):
    with open(path, encoding="ascii") as f:
        return [ln.rstrip("\n") for ln in f]


def kv(ln):
    k, _, v = ln.partition("=")
    return k, v


def expected(pair):
    a, w = float(ADD[pair]), WIDTH[pair]
    return {
        "InpAddPips": "%.1f" % a,
        "InpExitPips": "%.1f" % a,
        "InpWidthPips": "%.1f" % w,
        "InpStrandedThreshPips": "%.1f" % (w + 1.0),
        "InpConfigWarning": ("FLEET E two-arm t2 %s ALT q88: cap 7, add = exit %.1f, width %.1f, deadband 2.0; "
                             "lattice + reroll on, roll gate 0 (FTMO demo, new account, new Linux server)"
                             % (pair, a, w)),
    }


def check(pair):
    t1 = lines(os.path.join(DIR, "%s_alt_e_t1.set" % pair.lower()))
    t2 = lines(os.path.join(DIR, "%s_alt_e_t2.set" % pair.lower()))
    faults = []
    if [kv(x)[0] for x in t1] != [kv(x)[0] for x in t2]:
        return ["keys or order differ from t1"]
    want = expected(pair)
    seen = set()
    for a, b in zip(t1, t2):
        k, v1 = kv(a)
        _, v2 = kv(b)
        if k in ALLOWED:
            seen.add(k)
            if v2 != want[k]:
                faults.append("%s=%s, not %s" % (k, v2, want[k]))
        elif v1 != v2:
            faults.append("%s changed: %s -> %s" % (k, v1, v2))
    if seen != ALLOWED:
        faults.append("missing keys: %s" % sorted(ALLOWED - seen))
    a, w = float(ADD[pair]), WIDTH[pair]
    if not (a / w <= 4.0 + 1e-9 and a / (w - 0.5) > 4.0 + 1e-9):
        faults.append("width %.1f is not the tightest half pip with add / width <= 4" % w)
    return faults


def main():
    bad = 0
    for pair in ADD:
        f = check(pair)
        bad += bool(f)
        print("%s_alt_e_t2.set: %s" % (pair.lower(), "OK (5 values as expected, every other line as t1)" if not f
                                        else "; ".join(f)))
    print("%d / %d OK" % (len(ADD) - bad, len(ADD)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
