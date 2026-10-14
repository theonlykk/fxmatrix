"""Extract the DeepSeek F2 audit inputs from git into temp/deepseek_f2/ (LF bytes), check each
against its expected line count and sha256, and print one line per file. Standard library only.
Run from the repo root:  python prompts/deepseek_f2_inputs.py
Exit 1 on any mismatch (nothing is sent to DeepSeek then)."""
import hashlib
import os
import subprocess
import sys

OUT = os.path.join("temp", "deepseek_f2")
# (out name, kind, rev or revs, path, first line, last line) -- lines 1-based, inclusive; 0 = whole file
INPUTS = [
    ("fxgrind_replay_core.mqh", "show", "7d8fa13", "ea/fxgrind_replay_core.mqh", 0, 0),
    ("replay_core_F1F4.diff", "diff", "efada62 7d8fa13", "ea/fxgrind_replay_core.mqh", 0, 0),
    ("replay_tests_RT64_RT74.mq5", "show", "7d8fa13", "ea/fxgrind_replay_tests.mq5", 2493, 3178),
    ("grind_engine_deals_exitq.mqh", "show2", "efada62", "ea/grind_engine.mqh", (2857, 3240), (3326, 3513)),
    ("grind_closeby.mqh", "show", "efada62", "ea/grind_closeby.mqh", 0, 0),
]
EXPECT = {
    "fxgrind_replay_core.mqh": (3988, "51d02b587c6bca4cf76586e5e2259f576d952568eb7998f7cbff0c56ce672110"),
    "replay_core_F1F4.diff": (618, "ef2b1591ebca93d717e5c73c7419c21e3e5ea41818974ec53d7c5053bc7b96bf"),
    "replay_tests_RT64_RT74.mq5": (686, "84dcedeaffe5bd6352ab656c9eeee3b1c76ba955d980eb6610cb5dbaea1b2b7a"),
    "grind_engine_deals_exitq.mqh": (573, "eac9cc08d5605965752a98643617b2b86ea9af0acc2e5e04b739556151159877"),
    "grind_closeby.mqh": (317, "0d59e691b24fa6ddd4040bcc42e56104d9108b292c41ce7de3697781a3704f41"),
}


def git(args):
    r = subprocess.run(["git"] + args, capture_output=True)
    if r.returncode != 0:
        sys.exit("git %s failed: %s" % (" ".join(args), r.stderr.decode("utf-8", "replace")))
    return r.stdout.replace(b"\r\n", b"\n")


def build(item):
    name, kind, rev, path, a, b = item
    if kind == "diff":
        r1, r2 = rev.split()
        return git(["diff", "--no-color", "--no-ext-diff", "--diff-algorithm=myers", "-U3", r1, r2, "--", path])
    data = git(["show", "%s:%s" % (rev, path)])
    lines = data.split(b"\n")
    if kind == "show2":
        out = []
        for lo, hi in (a, b):
            out += lines[lo - 1:hi] + [b""]
        return b"\n".join(out)
    if a == 0:
        return data
    return b"\n".join(lines[a - 1:b]) + b"\n"


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
        print("%-32s lines=%-5d chars=%-7d sha256=%s %s" % (item[0], n, len(data), h, "OK" if ok else "MISMATCH"))
    print("INPUTS %d/%d ok" % (len(INPUTS) - bad, len(INPUTS)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
