"""Summary of sweep3 reports: per pair, settings positive (net, gross), the neighbours rule
(a setting counts only if it AND each grid neighbour, one step in add, exit or layers, net
positive), the best setting, the median. Reads report_<pair>.md (geometry totals table)."""
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import sweep as sw  # noqa: E402

PAIRS = ("eurusd", "gbpusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf", "nzdcad", "audnzd")
A, E, N = (2.5, 5.0, 7.5, 10.0), (2.5, 5.0, 7.5, 10.0), (6, 8, 10)


def totals(path):
    out = {}
    for line in open(path):
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if len(c) == 10 and re.match(r"^a[\d.]+e[\d.]+n\d+$", c[0]):
            out[c[0]] = {"gross": float(c[7]), "net": float(c[9]), "S": int(c[1]), "R": int(c[2])}
    return out


def name(a, e, n):
    return "a%ge%gn%d" % (a, e, n)


def neighbours(i, j, k):
    for di, dj, dk in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
        x, y, z = i + di, j + dj, k + dk
        if 0 <= x < 4 and 0 <= y < 4 and 0 <= z < 3:
            yield name(A[x], E[y], N[z])


def main(here):
    rows = ["| pair | net > 0 (of 48) | gross > 0 | pass neighbours rule | best setting (net pips, $ at 0.01 lots) | median net |",
            "|---|---|---|---|---|---|"]
    for p in PAIRS:
        t = totals(os.path.join(here, "report_%s.md" % p))
        grid = {name(a, e, n): t[name(a, e, n)] for a in A for e in E for n in N}
        pos = [g for g, v in grid.items() if v["net"] > 0]
        gpos = [g for g, v in grid.items() if v["gross"] > 0]
        rule = [name(A[i], E[j], N[k]) for i in range(4) for j in range(4) for k in range(3)
                if grid[name(A[i], E[j], N[k])]["net"] > 0
                and all(grid[m]["net"] > 0 for m in neighbours(i, j, k))]
        best = max(grid, key=lambda g: grid[g]["net"])
        pip = sw.get_set("sw3_" + p)["pip_usd"]
        rows.append("| %s | %d | %d | %d | %s %+.0f ($%+.0f) | %+.0f |" % (
            p.upper(), len(pos), len(gpos), len(rule), best, grid[best]["net"], grid[best]["net"] * pip,
            statistics.median(v["net"] for v in grid.values())))
    return "\n".join(rows) + "\n"


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    txt = main(here)
    open(os.path.join(here, "summary.md"), "w").write(txt)
    print(txt)
