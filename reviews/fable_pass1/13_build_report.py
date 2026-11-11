"""Assembles report_pass1.md from the prose below and the tables in out/ (so that every table in the report is the
literal output of a script). Run after 00 .. 12. Output: report_pass1.md in the folder given as argv[1] (default: .)."""
import os, sys, re
from common import OUT
DEST = sys.argv[1] if len(sys.argv) > 1 else "."
rd = lambda f: open(f, encoding="utf-8").read().rstrip("\n")
S = rd(os.path.join(OUT, "08_summary.txt"))
T = rd(os.path.join(OUT, "12_report_tables.txt"))

def block(text, start, stop=None):
    i = text.index(start)
    j = text.index(stop, i) if stop else len(text)
    return text[i:j].rstrip("\n")

def code(s):
    return "```\n" + s + "\n```"

A_TXT = rd(os.path.join(DEST, "A_expectations.md"))
B_TXT = rd(os.path.join(DEST, "B_plan.md"))
PROSE = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "report_prose.md"), encoding="utf-8").read()
subs = {
    "{{A}}": A_TXT, "{{B}}": B_TXT,
    "{{S1}}": code(block(S, "S1.", "S2.")), "{{S2}}": code(block(S, "S2.", "S2b.")), "{{S2b}}": code(block(S, "S2b.", "S3.")),
    "{{S3}}": code(block(S, "S3.", "S4.")), "{{S4}}": code(block(S, "S4.", "S5.")), "{{S5}}": code(block(S, "S5.", "S6.")),
    "{{S6}}": code("\n".join(l for l in block(S, "S6.", "S7.").split("\n") if "a=20" not in l)),
    "{{S7}}": code(block(S, "S7.", "S8.")), "{{S8}}": code(block(S, "S8.", "S9.")),
    "{{Ta}}": code(block(T, "(a)", "(a2)")), "{{Ta2}}": code(block(T, "(a2)", "(b)")), "{{Tb}}": code(block(T, "(b)", "(c)")),
    "{{Tc}}": code(block(T, "(c)", "(d)")), "{{Td}}": code(block(T, "(d)", "(e)")), "{{Te}}": code(block(T, "(e)", "(f)")),
    "{{Tf}}": code(block(T, "(f)")),
    "{{VR}}": code(rd(os.path.join(OUT, "03_variance_ratio.txt"))),
    "{{NULL}}": code(rd(os.path.join(OUT, "01_null_calibration.txt"))),
    "{{X_AUDCAD}}": code(rd(os.path.join(OUT, "07_crosscheck_AUDCAD.txt"))), "{{X_EURUSD}}": code(rd(os.path.join(OUT, "07_crosscheck_EURUSD.txt"))),
    "{{FILL}}": code(rd(os.path.join(OUT, "10_fill_improvement.txt"))), "{{MICRO}}": code(rd(os.path.join(OUT, "11_micro_perturbation.txt"))),
    "{{PHASE}}": code("\n".join(rd(os.path.join(OUT, "09_phase_ensemble.txt")).split("\n")[-2:])),
}
body = PROSE
for k, v in subs.items():
    assert k in body, k
    body = body.replace(k, v)
assert "{{" not in body, re.findall(r"\{\{[^}]*\}\}", body)
body = body.rstrip("\n")
bad = sorted(set(ch for ch in body if ord(ch) > 127))
assert not bad, bad
lines = body.split("\n")
assert lines[0] == "This message has a line count at the bottom"
n = len(lines) + 2                      # blank line + the count line
out = body + "\n\nLine count: %d\n" % n
open(os.path.join(DEST, "report_pass1.md"), "w", encoding="ascii", newline="\n").write(out)
chk = open(os.path.join(DEST, "report_pass1.md"), encoding="ascii").read().split("\n")
if chk[-1] == "":
    chk = chk[:-1]
assert len(chk) == n and chk[-1] == "Line count: %d" % n, (len(chk), n)
print("report written: %d lines" % n)
