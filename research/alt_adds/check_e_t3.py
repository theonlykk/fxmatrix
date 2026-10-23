"""Check E's twelve t3 presets against the reviewed t1 presets (run from the repo root):

    python research/alt_adds/check_e_t3.py

Read-only; standard library only. Each `ea/presets_e/<pair>_<arm>_e_t3.set` must equal `<pair>_<arm>_e_t1.set` line
for line (same keys, same order) except exactly five values, each equal to the value written here by hand (sweep11's
selection with the operator's rulings, HANDOFF s88 continued 4): InpAddPips = InpExitPips = the add; InpWidthPips =
add / 4 rounded UP to the half pip (the replay's width: sw10's rule; EURUSD's 7 is 2.0 under sw9's too);
InpStrandedThreshPips = width + 1; InpConfigWarning = the t3 / sw11 text.
"""
import os
import sys

DIR = os.path.join("ea", "presets_e")
SET = {("GBPUSD", "OPT"): (9, 2.5), ("GBPUSD", "ALT"): (15, 4.0), ("EURUSD", "OPT"): (7, 2.0),
       ("EURUSD", "ALT"): (23, 6.0), ("EURGBP", "OPT"): (5, 1.5), ("EURGBP", "ALT"): (23, 6.0),
       ("AUDCAD", "OPT"): (18, 4.5), ("AUDCAD", "ALT"): (26, 6.5), ("AUDCHF", "OPT"): (14, 3.5),
       ("AUDCHF", "ALT"): (20, 5.0), ("CADCHF", "OPT"): (10, 2.5), ("CADCHF", "ALT"): (17, 4.5)}
ALLOWED = {"InpAddPips", "InpExitPips", "InpWidthPips", "InpStrandedThreshPips", "InpConfigWarning"}


def lines(path):
    with open(path, encoding="ascii") as f:
        return [ln.rstrip("\n") for ln in f]


def kv(ln):
    k, _, v = ln.partition("=")
    return k, v


def check(pair, arm):
    a, w = SET[(pair, arm)]
    t1 = lines(os.path.join(DIR, "%s_%s_e_t1.set" % (pair.lower(), arm.lower())))
    t3 = lines(os.path.join(DIR, "%s_%s_e_t3.set" % (pair.lower(), arm.lower())))
    if [kv(x)[0] for x in t1] != [kv(x)[0] for x in t3]:
        return ["keys or order differ from t1"]
    want = {"InpAddPips": "%.1f" % a, "InpExitPips": "%.1f" % a, "InpWidthPips": "%.1f" % w,
            "InpStrandedThreshPips": "%.1f" % (w + 1.0),
            "InpConfigWarning": ("FLEET E two-arm t3 %s %s sw11: cap 7, add = exit %.1f, width %.1f, deadband 2.0; "
                                 "lattice + reroll on, roll gate 0 (FTMO demo, new account, new Linux server)"
                                 % (pair, arm, a, w))}
    faults, seen = [], set()
    for x, y in zip(t1, t3):
        k, v1 = kv(x)
        v3 = kv(y)[1]
        if k in ALLOWED:
            seen.add(k)
            if v3 != want[k]:
                faults.append("%s=%s, not %s" % (k, v3, want[k]))
        elif v1 != v3:
            faults.append("%s changed: %s -> %s" % (k, v1, v3))
    if seen != ALLOWED:
        faults.append("missing keys: %s" % sorted(ALLOWED - seen))
    if not (a / w <= 4.0 + 1e-9 and a / (w - 0.5) > 4.0 + 1e-9):
        faults.append("width %.1f is not the tightest half pip with add / width <= 4" % w)
    return faults


def main():
    bad = 0
    for pair, arm in sorted(SET):
        f = check(pair, arm)
        bad += bool(f)
        print("%s_%s_e_t3.set: %s" % (pair.lower(), arm.lower(), "OK" if not f else "; ".join(f)))
    print("%d / %d OK" % (len(SET) - bad, len(SET)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
