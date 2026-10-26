"""Extract the DeepSeek C165 audit inputs from git into temp/deepseek_c165/ (LF bytes), check each
against its expected line count and sha256, and print one line per file. Standard library only.
Run from the repo root:  python prompts/deepseek_c165_inputs.py
Exit 1 on any mismatch (nothing is sent to DeepSeek then)."""
import hashlib
import os
import subprocess
import sys

OUT = os.path.join("temp", "deepseek_c165")
HEAD = "9b44b57"     # c165-clamp-hold: the change (commit 2)
BASE = "c9f94fe"     # main before the branch
# (out name, kind, rev, path, ranges) -- ranges: list of (first, last) 1-based inclusive, or None = whole file
INPUTS = [
    ("c165_branch.diff", "diff", BASE + " " + HEAD, "ea/", None),
    ("grind_engine_add_path.mqh", "show", HEAD, "ea/grind_engine.mqh",
     [(1418, 1441), (2250, 2586), (3028, 3074), (3200, 3250)]),
    ("grind_pure.mqh", "show", HEAD, "ea/grind_pure.mqh", None),
    ("fxgrind.mq5", "show", HEAD, "ea/fxgrind.mq5", None),
]
EXPECT = {
    "c165_branch.diff": (362, "22d392933e858829320825888fa6cda41ba7e2520195814976d8e9f95bbfc5a2"),
    "grind_engine_add_path.mqh": (466, "e31913cbf92bdd71d7153e1dddf783f8c904fec0099c6fe9e3e92ae2e26d1fba"),
    "grind_pure.mqh": (708, "879451212f758d51ce6fa881c1ee88295fe3207a8f49911e42a79d1918f5e335"),
    "fxgrind.mq5": (521, "ac3966d82447784588dbf5001a4703b26e7408c4328ca5a17988161440bb800f"),
}


def git(args):
    r = subprocess.run(["git"] + args, capture_output=True)
    if r.returncode != 0:
        sys.exit("git %s failed: %s" % (" ".join(args), r.stderr.decode("utf-8", "replace")))
    return r.stdout.replace(b"\r\n", b"\n")


def build(item):
    name, kind, rev, path, ranges = item
    if kind == "diff":
        r1, r2 = rev.split()
        return git(["diff", "--no-color", "--no-ext-diff", "--diff-algorithm=myers", "-U3", r1, r2, "--", path])
    data = git(["show", "%s:%s" % (rev, path)])
    if ranges is None:
        return data
    lines = data.split(b"\n")
    out = []
    for lo, hi in ranges:
        out.append(b"// ---- grind_engine.mqh lines %d-%d at %s ----" % (lo, hi, rev.encode()))
        out += lines[lo - 1:hi] + [b""]
    return b"\n".join(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    bad = 0
    for item in INPUTS:
        data = build(item)
        with open(os.path.join(OUT, item[0]), "wb") as f:
            f.write(data)
        n = data.count(b"\n")
        h = hashlib.sha256(data).hexdigest()
        want = EXPECT.get(item[0])
        ok = want is not None and want == (n, h)
        bad += 0 if ok else 1
        print("%-28s lines=%-5d chars=%-7d sha256=%s %s" % (item[0], n, len(data), h, "OK" if ok else "MISMATCH"))
    print("INPUTS %d/%d ok" % (len(INPUTS) - bad, len(INPUTS)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
