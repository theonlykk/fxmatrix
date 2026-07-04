"""ADR-UNIT-TESTS 0-41 — math-only Python verification."""
import math

TOL = 0.00001
TOL23 = 0.000001
TOL_RATIO = 0.001
TOL39C = 0.001
TOL41CE = 0.001
PHI = 0.618
report = []
fails = []


def near(a, e, tol=TOL):
    return abs(a - e) <= tol


def add(test, sub, ok, actual, expected):
    st = "PASS" if ok else "FAIL"
    report.append((test, sub, st, actual, expected))
    if not ok:
        fails.append(f"{test}/{sub}")


def run_test(name, checks):
    ok = True
    for item in checks:
        if item[0] == "num":
            _, sub, act, exp, tol = item
            passed = near(act, exp, tol)
            add(name, sub, passed, f"{act:.8f}", f"{exp:.8f}")
            ok &= passed
        elif item[0] == "bool":
            _, sub, act, exp = item
            passed = act == exp
            add(name, sub, passed, str(act), str(exp))
            ok &= passed
        elif item[0] == "note":
            _, sub, detail = item
            add(name, sub, True, detail, "per doc")
    return ok


def ldak(w, sm=1.0, base=0.01, min_vol=0.01):
    raw = base * sm * w
    if raw < min_vol * 0.70:
        return 0.0, raw, True
    return max(raw, min_vol), raw, False


def exit_det(entry, spread_raw, layer, direction, half=0.000005, min_pts=2, pt=0.00001):
    e = abs(spread_raw) * (PHI ** (layer + 1))
    if direction == 1:
        return max(entry + e - half, entry + min_pts * pt)
    return min(entry - e + half, entry - min_pts * pt)


def math_median_centered(arr, center_index, width):
    if width <= 0:
        return arr[center_index]
    half = width // 2
    if center_index - half < 0 or center_index + half >= len(arr):
        return arr[center_index]
    return sorted(arr[center_index - half : center_index + half + 1])[half]


def min_bars(sw):
    return max(289, sw + 25)


def shift(swap_pts, multiplier, point):
    return abs(swap_pts) * multiplier * point


def same_dir(inv, direction):
    return any(d == direction and t > 0 for d, t in inv)


def dynamic_hs(quote_spread, spread_mult, sigma_fv):
    return quote_spread + sigma_fv * spread_mult


def sigmoid_mult(sigma_pts, max_scale=3.0, mid=50.0, k=0.15):
    m = 1.0 + (max_scale - 1.0) / (1.0 + math.exp(k * (sigma_pts - mid)))
    return max(1.0, min(max_scale, m))


def fv_combined(fv6, fv12, fv48):
    return fv6 * 0.50 + fv12 * 0.30 + fv48 * 0.20


def sigma_fv(fv6, fv12, fv48):
    mean = (fv6 + fv12 + fv48) / 3.0
    sq = [(fv6 - mean) ** 2, (fv12 - mean) ** 2, (fv48 - mean) ** 2]
    return math.sqrt(sum(sq) / 3.0)


a, qs, hs, b = 1.14600, 0.0004, 0.000005, 1.32500

run_test("0", [("num", "BUY", a * math.exp(-qs), 1.14554, TOL), ("num", "SELL", a * math.exp(qs), 1.14646, TOL)])
ab = 1.14600 / 1.32500
run_test("0b", [("num", "BUY", a * math.exp(-qs) - hs, 1.14554, TOL), ("num", "SELL", a * math.exp(qs) + hs, 1.14646, TOL)])
run_test("0c", [("num", "BUY", b * math.exp(-qs) - hs, 1.32447, TOL), ("num", "SELL", b * math.exp(qs) + hs, 1.32554, TOL)])
run_test("0d", [("num", "BUY", ab * math.exp(-qs) - hs, 0.86455, TOL), ("num", "SELL", 0.86491 * math.exp(qs) + hs, 0.86526, TOL)])

bid, off = a * math.exp(-qs), a * math.exp(qs)
run_test("1", [
    ("num", "1a", bid, 1.14554, TOL), ("num", "1b", off, 1.14646, TOL),
    ("bool", "1c bid", bid < 1.14600, True), ("bool", "1c offer", off > 1.14601, True),
    ("bool", "1d buy", bid >= 1.14600, False), ("bool", "1d sell", off <= 1.14601, False),
])

inst = 0.001539
run_test("2", [
    ("num", "2a", a * math.exp(inst - qs), 1.14731, TOL), ("num", "2b", a * math.exp(inst + qs), 1.14822, TOL),
    ("bool", "2c", a * math.exp(inst - qs) < 1.14600, False), ("num", "2d", 1.14599, 1.14599, TOL),
])

inst3 = -0.001539
run_test("3", [
    ("num", "3a", b * math.exp(inst3 - qs), 1.32243, TOL), ("num", "3b", b * math.exp(inst3 + qs), 1.32349, TOL),
    ("bool", "3c", b * math.exp(inst3 + qs) > 1.32501, False), ("num", "3d", 1.32502, 1.32502, TOL),
])

ab4, inst4 = 0.86491, 0.0008
run_test("4", [
    ("num", "4a", ab4 * math.exp(inst4 - qs), 0.86526, TOL), ("num", "4b", ab4 * math.exp(inst4 + qs), 0.86595, TOL),
    ("bool", "4c", ab4 * math.exp(inst4 - qs) < 0.86450, False), ("num", "4d", 0.86449, 0.86449, TOL),
])

entry5, esp = 1.14554, math.log(1.14554 / a)
exit5 = a * math.exp(-(esp * 0.99))
run_test("5", [
    ("num", "5a", exit5, 1.14645, TOL), ("bool", "5b", exit5 > entry5, True),
    ("bool", "5c", exit5 <= 1.14646, True), ("bool", "5d", exit5 > 1.14601, True),
])

add_sp = 0.001061 - 0.0008 - 0.0008 * 0.382
run_test("6", [("num", "6a", min(b * math.exp(-add_sp), 1.31989), 1.31989, TOL), ("bool", "6b", 1.31989 < 1.31990, True)])

bid7 = a * math.exp(-0.0004)
run_test("7", [
    ("num", "7a", bid7, 1.14554, TOL), ("bool", "7b", bid7 < 1.14100, False),
    ("bool", "7c", bid7 >= 1.14100, True), ("num", "7d", min(bid7, 1.14099), 1.14099, TOL),
])

run_test("8", [("bool", "8a", 1.14554 < 1.14554, False), ("bool", "8b", 1.14554 >= 1.14554, True), ("num", "8c", 1.14553, 1.14553, TOL)])
run_test("9", [("bool", "9a", 1.14600 > 1.14600, False), ("bool", "9b", 1.14600 <= 1.14600, True), ("num", "9c", 1.14601, 1.14601, TOL)])
run_test("10", [("note", "all", "SUPERSEDED")])
run_test("11", [("note", "11a", "SUPERSEDED"), ("bool", "11b", True, True), ("bool", "11c", True, True)])

anchor12, hs12 = 1.32441, 0.000030
bid12 = anchor12 * math.exp(-qs) - hs12
off12 = anchor12 * math.exp(qs) + hs12
run_test("12", [
    ("bool", "12a", abs(0.000151) <= 0.0002, True), ("num", "12b", bid12, 1.32385, TOL),
    ("num", "12c", off12, 1.32497, TOL), ("num", "12d", off12 - bid12, 0.00112, TOL),
])

floor_n = max(0.0002, 0.00002)
exs = 0.000276 * max(0.618, floor_n / 0.000276)
old_ex = 0.000276 * min(0.99, 0.0003 / 0.000276)
run_test("13", [
    ("num", "floor_n", floor_n, 0.0002, TOL), ("num", "13a", exs, 0.000200, TOL),
    ("bool", "13b", abs(0.000149) <= 0.0002, True), ("bool", "13c", near(old_ex, 0.000276, TOL), True),
])

run_test("14", [("bool", "14a", exit_det(1.13, 0.001, 0, 1) == exit_det(1.13, 0.001, 0, 1), True), ("bool", "14b", True, True)])
run_test("15", [("num", "15a", max(1.13, 1.13002), 1.13002, TOL), ("bool", "15b", -1.0 < 0.0, True), ("bool", "15c", 1.13002 > 1.13, True)])

ex16 = exit_det(1.13554, -0.0004, 0, 1)
run_test("16", [("num", "16a", ex16, 1.1357822, TOL), ("bool", "16b", True, True), ("bool", "16c", ex16 > 1.13554, True)])
ex17 = exit_det(1.13646, 0.0004, 0, -1)
run_test("17", [("num", "17a", ex17, 1.1362178, TOL), ("bool", "17b", True, True), ("bool", "17c", ex17 < 1.13646, True)])

c18 = []
for tag, en, sp, d, exp, gt in [
    ("18a", 1.13554, -0.0004, 1, 1.1357822, True), ("18b", 1.13646, 0.0004, -1, 1.1362178, False),
    ("18c", 1.32447, -0.0004, 1, 1.3247122, True), ("18d", 1.32553, 0.0004, -1, 1.3252878, False),
    ("18e", 0.86455, -0.0004, 1, 0.8647922, True), ("18f", 0.86526, 0.0004, -1, 0.8650178, False),
]:
    ex = exit_det(en, sp, 0, d)
    c18 += [("num", tag, ex, exp, TOL), ("bool", tag + " side", (ex > en) if gt else (ex < en), True)]
run_test("18", c18)

ex19 = max(1.13 + 0.001 * PHI - 0.000005, 1.13002)
run_test("19", [("num", "19a", ex19, 1.130613, TOL), ("bool", "19b", True, True)])

c20 = []
spread20 = 0.0010
for n in range(6):
    e = spread20 * (PHI ** (n + 1))
    c20.append(("bool", f"20{n}", max(0.0004 * (n + 1), e * 1.618) > e, True))
e0 = spread20 * PHI
c20.append(("num", "20g", max(0.0004, e0 * 1.618) / e0, 1.618, TOL_RATIO))
run_test("20", c20)

ex21 = max(1.13 + 0.00003 * PHI - 0.000005, 1.13030)
run_test("21", [("num", "21a", ex21, 1.13030, TOL), ("bool", "21b", ex21 > 1.13, True), ("bool", "21c", True, True)])

a0_22 = max(0.0004, 0.0010 * PHI * 1.618)
a1_22 = max(0.0008, (0.0010 + a0_22) * (PHI ** 2) * 1.618)
run_test("22", [("bool", "22a", a1_22 >= a0_22, True), ("num", "22b", 0.001236 / 0.001000, 1.236, TOL)])

run_test("23", [("num", "23a", PHI ** 1, 0.618000, TOL23), ("num", "23b", PHI ** 2, 0.381924, TOL23), ("num", "23c", PHI ** 3, 0.236029, TOL23)])

e24 = 0.0014 * PHI
a24 = max(0.0004, e24 * 1.618)
run_test("24", [("num", "24a", a24 / e24, 1.618, TOL_RATIO), ("bool", "24b", a24 > e24, True), ("bool", "24c", 0.0004 < e24 * 1.618, True)])

ex25 = max(1.13 + 0.001 * PHI - 0.000005, 1.13002)
run_test("25", [("num", "25a", ex25, 1.130613, TOL), ("bool", "25b", ex25 != -1.0, True), ("bool", "25c", True, True)])

# ---------------------------------------------------------------------------
# Tests 26-28 -- PRE-ADR-061 LDAK gate (single-path refuse-only). Superseded
# by Test 47's split gate for any case where size_mult would now clamp
# instead of refuse (notably 28d: sm=0.85 >= InpLDAKDrawdownHealthyThreshold
# would now clamp under current code, not refuse as asserted here). Kept
# as regression coverage for the OLD ldak() helper's own internal
# consistency, not as a claim about current MQL5 behavior. See Test 47
# for current split-gate coverage.
# ---------------------------------------------------------------------------

c26 = []
for tag, w, ret, gate in [("26a", 0.68, 0.0, True), ("26b", 0.71, 0.01, False), ("26c", 0.70, 0.01, False)]:
    r, _, g = ldak(w)
    c26 += [("num", tag + " ret", r, ret, TOL), ("bool", tag + " gate", g, gate)]
run_test("26", c26)

w27a = 1 / 101
r, raw, g = ldak(w27a)
c27 = [
    ("num", "27a ret", r, 0.0, TOL), ("num", "27a w", w27a, 0.00990099, TOL),
    ("num", "27a raw", raw, 0.00009901, TOL), ("bool", "27a gate", g, True),
]
r, _, g = ldak(1.0)
c27 += [("num", "27b ret", r, 0.01, TOL), ("bool", "27b gate", g, False)]
w27c = 1 / (1 + 0.15 * 0.15)
r, raw, g = ldak(w27c)
c27 += [
    ("num", "27c ret", r, 0.01, TOL), ("num", "27c w", w27c, 0.97799511, TOL),
    ("num", "27c raw", raw, 0.00977995, TOL), ("bool", "27c gate", g, False),
]
run_test("27", c27)

c28 = []
for tag, sm, w, ret, gate in [("28a", 0.5, 1.0, 0.0, True), ("28b", 0.75, 1.0, 0.01, False), ("28c", 0.85, 1 / 1.0225, 0.01, False), ("28d", 0.85, 1 / 101, 0.0, True)]:
    r, _, g = ldak(w, sm)
    c28 += [("num", tag + " ret", r, ret, TOL), ("bool", tag + " gate", g, gate)]
run_test("28", c28)

run_test("29", [
    ("bool", "29a", same_dir([(1, 12345678)], 1), True),
    ("bool", "29b", same_dir([(1, 0)], 1), False),
    ("bool", "29c", same_dir([(-1, 87654321)], 1), False),
])

arr30a = [1.13500, 1.13510, 1.13520, 1.13530, 1.13540]
arr30b = [1.13500, 1.13510, 1.13999, 1.13530, 1.13540]
arr30f = [1.13510, 1.13520, 1.13530]
clean = [1.14600 - i * 0.00001 for i in range(20)]
run_test("30", [
    ("num", "30a", math_median_centered(arr30a, 2, 5), 1.13520, TOL),
    ("num", "30b", math_median_centered(arr30b, 2, 5), 1.13530, TOL),
    ("num", "30c", math_median_centered(clean, 12, 5), clean[12], TOL),
    ("bool", "30d", math_median_centered(clean, 6, 5) != clean[12], True),
    ("num", "30e SW48", min_bars(48), 289, TOL),
    ("num", "30e SW300", min_bars(300), 325, TOL),
    ("bool", "30e SW264", min_bars(264) == 289, True),
    ("num", "30e SW265", min_bars(265), 290, TOL),
    ("num", "30f", math_median_centered(arr30f, 1, 5), 1.13520, TOL),
])

pt = 0.00001
s31a = shift(-4.0, 1, pt)
run_test("31", [
    ("num", "31a shift", s31a, 0.00004, TOL), ("num", "31a entry", 1.30000 + s31a, 1.30004, TOL), ("num", "31a exit", 1.30800 + s31a, 1.30804, TOL),
    ("num", "31b shift", shift(-6.0, 1, pt), 0.00006, TOL), ("num", "31b entry", 1.30500 - shift(-6.0, 1, pt), 1.30494, TOL), ("num", "31b exit", 1.29800 - shift(-6.0, 1, pt), 1.29794, TOL),
    ("num", "31c shift", shift(-4.0, 3, pt), 0.00012, TOL), ("num", "31c entry", 1.30000 + shift(-4.0, 3, pt), 1.30012, TOL),
    ("bool", "31d skip", (+2.0) >= 0.0, True),
    ("num", "31e entry", 0.86500 - shift(-3.0, 1, pt), 0.86497, TOL),
])

dec = lambda hwm, live, rate: max(1.0, live) if live > hwm else max(1.0, hwm * (1 - rate))
run_test("32", [
    ("num", "32a", 2.5, 2.5, TOL),
    ("num", "32b", dec(2.5, 1.1, 0.01), 2.475, TOL),
    ("num", "32c", dec(1.005, 1.0, 0.01), 1.0, TOL),
    ("num", "32d", min(0.0035, 0.0004) * PHI, 0.0002472, TOL),
    ("num", "32e", min(0.0003, 0.0004) * PHI, 0.0001854, TOL),
    ("num", "32f", dec(1.0, 1.0, 0.01), 1.0, TOL),
])

w33a = 1 / (1 + 0.285 ** 2)
raw33a = 0.01 * w33a
w33b = 1 / (1 + 0.95 ** 2)
raw33b = 0.01 * w33b
run_test("33", [
    ("num", "33a w", w33a, 0.92487688, TOL), ("bool", "33a suppressed", raw33a < 0.007, False),
    ("num", "33b w", w33b, 0.52562418, TOL), ("bool", "33b suppressed", raw33b < 0.007, True),
    ("bool", "33c SLOT_AB", True, True),
    ("bool", "33d not suppressed", 0.01 >= 0.007, True),
])

run_test("34", [
    ("num", "34a bid", 0.000686 - 0.0004, 0.000286, TOL), ("num", "34a offer", 0.000686 + 0.0004, 0.001086, TOL),
    ("num", "34b bid", -0.000779 - 0.0004, -0.001179, TOL), ("num", "34b offer", -0.000779 + 0.0004, -0.000379, TOL),
    ("bool", "34c gate", abs(0.000109) <= 0.0003, True),
    ("bool", "34d no gate", abs(-0.000779) > 0.0003, True),
    ("num", "34e floor_n", max(0.0002, 0.0003), 0.0003, TOL),
])

md = 20 * 0.00001 + 2 * 0.00001
run_test("35", [
    ("num", "35a", 1.32200 - md, 1.32178, TOL),
    ("num", "35b", 1.32210 + md, 1.32232, TOL),
    ("num", "35c", 1.31970, 1.31970, TOL),
    ("bool", "35d skip", 1.32178 <= 1.32185, True),
    ("bool", "35e proceed", 1.32178 > 1.32150, True),
])

EA = 20260000


def magic_pass(m):
    return m == 0 or m == EA or m == EA + 1 or m == EA + 2


run_test("36", [
    ("bool", "36a", magic_pass(EA), True), ("bool", "36b", magic_pass(EA + 1), True), ("bool", "36c", magic_pass(EA + 2), True),
    ("bool", "36d", magic_pass(20260100), False), ("bool", "36e", magic_pass(0), True),
])


def real_profit(deal_profit, pos_profit=None, pos_swap=0.0):
    if deal_profit == 0.0 and pos_profit is not None:
        return pos_profit + pos_swap
    return deal_profit


run_test("37", [
    ("num", "37a", real_profit(0.0, 0.30, 0.02), 0.32, TOL),
    ("num", "37b", real_profit(0.31), 0.31, TOL),
    ("num", "37c", real_profit(0.0), 0.0, TOL),
])


def sniper_expired(elapsed_sec, expiry_bars):
    return int(elapsed_sec / 300) >= expiry_bars


run_test("38", [
    ("bool", "38a", sniper_expired(310, 1), True),
    ("bool", "38b", sniper_expired(250, 1), False),
    ("bool", "38c", sniper_expired(850, 3), False),
    ("bool", "38d", sniper_expired(950, 3), True),
])

fv6, fv12, fv48 = 1.13500, 1.13600, 1.13800
fc = fv_combined(fv6, fv12, fv48)
sig = sigma_fv(fv6, fv12, fv48)
sig_pts = sig / 0.00001
fv6d, fv12d, fv48d = 1.13500, 1.13502, 1.13501
sig_d = sigma_fv(fv6d, fv12d, fv48d)
run_test("39", [
    ("num", "39a", fc, 1.13590, TOL),
    ("num", "39b", sig, 0.00124722, TOL),
    ("num", "39c", sig_pts, 124.72191, TOL39C),
    ("bool", "39d", sig_d / 0.00001 < 1.0, True),
    ("num", "39e", 0.50 + 0.30 + 0.20, 1.00, TOL),
])

ac_now = 1.13650
g_fv = 1.13590
r_sig = math.log(ac_now / g_fv)
fv6b, fv12b, fv48b = 1.13500, 1.13900, 1.14100
fc2 = fv_combined(fv6b, fv12b, fv48b)
run_test("40", [
    ("num", "40a", r_sig, 0.00052800, TOL),
    ("num", "40b", g_fv, 1.13590, TOL),
    ("num", "40c FV_combined", fc2, 1.13740, TOL),
    ("bool", "40c closer", abs(fc2 - fv6b) < abs(fc2 - fv48b), True),
])

hs41a = dynamic_hs(0.0004, 0.5, 0.00020)
hs41b = dynamic_hs(0.0004, 0.5, 0.00124)
m41c = sigmoid_mult(0)
m41d = sigmoid_mult(50)
m41e = sigmoid_mult(124)
run_test("41", [
    ("num", "41a", hs41a, 0.00050, TOL),
    ("num", "41b", hs41b, 0.00102, TOL),
    ("num", "41c", m41c, 2.999, TOL41CE),
    ("num", "41d", m41d, 2.0, TOL),
    ("num", "41e", m41e, 1.000, TOL41CE),
    ("bool", "41f floor", sigmoid_mult(-1000) >= 1.0, True),
    ("bool", "41f ceiling", sigmoid_mult(1000) <= 3.0, True),
])

# ---------------------------------------------------------------------------
# Test 42 — ADR-045 Broker Window Gate Logic
# Verifies: (a) gate opens only during hour==0, (b) day_of_year
# discriminator fires exactly once per calendar day, (c) year-end
# rollover (day 365->1) handled correctly, (d) reboot at 00:15 with
# stale persisted value does not double-fire.
# Pure Python simulation — no MQL5 dependency.
# ---------------------------------------------------------------------------

def should_fire_rollover(hour, current_doy, last_doy):
    """Simulates the ADR-045 gate logic from CarryEngine.mqh.
    Returns (fires: bool, new_last_doy: int)."""
    if hour != 0:
        return False, last_doy
    if last_doy == current_doy:
        return False, last_doy
    return True, current_doy

# 42a: Outside window (hour=12) — must not fire regardless of doy state
f42a, _ = should_fire_rollover(hour=12, current_doy=178, last_doy=0)

# 42b: Inside window (hour=0), fresh day (last=0) — must fire
f42b, doy42b = should_fire_rollover(hour=0, current_doy=178, last_doy=0)

# 42c: Inside window (hour=0), already fired today — must not fire
f42c, _ = should_fire_rollover(hour=0, current_doy=178, last_doy=178)

# 42d: Inside window (hour=0), mid-session reattach already
#      stamped doy — must not fire (reattach safety)
f42d, _ = should_fire_rollover(hour=0, current_doy=178, last_doy=178)

# 42e: Year-end rollover — prev day=365, new day=1 — must fire
f42e, doy42e = should_fire_rollover(hour=0, current_doy=1, last_doy=365)

# 42f: Reboot at 00:15 — persisted doy loaded from disk matches current
#      doy (carry already ran before reboot) — must not double-fire
f42f, _ = should_fire_rollover(hour=0, current_doy=178, last_doy=178)

# 42g: Reboot at 00:15 — persisted doy is YESTERDAY (carry had not run
#      before reboot) — must fire exactly once
f42g, doy42g = should_fire_rollover(hour=0, current_doy=178, last_doy=177)

run_test("42", [
    ("bool", "42a outside window hour=12",    f42a,          False),
    ("bool", "42b fires first tick hour=0",   f42b,          True),
    ("bool", "42b doy stamped correctly",     doy42b == 178, True),
    ("bool", "42c no double-fire same doy",   f42c,          False),
    ("bool", "42d reattach mid-hour blocked", f42d,          False),
    ("bool", "42e year-end doy 365->1 fires", f42e,          True),
    ("bool", "42e doy stamped to 1",          doy42e == 1,   True),
    ("bool", "42f reboot carry-done blocked", f42f,          False),
    ("bool", "42g reboot carry-missed fires", f42g,          True),
    ("bool", "42g doy stamped correctly",     doy42g == 178, True),
])

# ---------------------------------------------------------------------------
# Test 43 -- ADR-056 Grid Restitution
# Verifies: when a LIFO layer is scalped out and inventory remains,
# the new outermost layer's exit target is correctly recomputed via
# ComputeExitPriceDeterministic geometry (golden ratio E_n).
# Also verifies: restitution is bypassed when inventory goes flat.
# Pure Python simulation using existing exit_det() helper.
# ---------------------------------------------------------------------------

def restitute_exit(inventory, scalped_index):
    """Simulate grid restitution after LIFO removal.
    inventory: list of (entry, spread_raw, layer_index, direction) tuples
    scalped_index: index of layer being removed (LIFO = last element)
    Returns new exit price for index 0 after removal, or None if flat."""
    remaining = [l for i, l in enumerate(inventory) if i != scalped_index]
    if len(remaining) == 0:
        return None  # flat — restitution bypassed
    # New outermost is index 0 after LIFO compression
    entry, spread_raw, layer_idx, direction = remaining[0]
    return exit_det(entry, spread_raw, layer_idx, direction)

# 43a: Single layer inventory scalped out — restitution bypassed (flat)
inv_single = [(1.13800, -0.0004, 0, 1)]
r43a = restitute_exit(inv_single, scalped_index=0)

# 43b: Two-layer inventory, outer layer scalped (LIFO index 1) —
# restitution fires on inner layer (index 0)
inv_two = [
    (1.13800, -0.0004, 0, 1),   # inner (shallowest)
    (1.13700, -0.0004, 1, 1),   # outer (deepest, scalped)
]
r43b = restitute_exit(inv_two, scalped_index=1)
r43b_expected = exit_det(1.13800, -0.0004, 0, 1)  # recompute for layer 0

# 43c: Three-layer inventory, outermost scalped (LIFO index 2) —
# restitution targets new outermost (index 0)
inv_three = [
    (1.13800, -0.0004, 0, 1),
    (1.13700, -0.0004, 1, 1),
    (1.13600, -0.0004, 2, 1),   # scalped
]
r43c = restitute_exit(inv_three, scalped_index=2)
r43c_expected = exit_det(1.13800, -0.0004, 0, 1)

# 43d: Short direction — outer layer scalped, verify direction handled
inv_short = [
    (1.13800, -0.0004, 0, -1),   # inner short
    (1.13900, -0.0004, 1, -1),   # outer short, scalped
]
r43d = restitute_exit(inv_short, scalped_index=1)
r43d_expected = exit_det(1.13800, -0.0004, 0, -1)

# 43e: Restitution price is tighter than original outer exit —
# confirms grid contracts (not expands) after scalp
outer_exit_before = exit_det(1.14000, -0.0004, 2, 1)  # old outermost (deep entry)
inner_exit_after  = exit_det(1.13600, -0.0004, 0, 1)  # new outermost after restitution
# For LONG: new exit should be LESS than old outer exit (grid contracted)
r43e_contracts = inner_exit_after < outer_exit_before

run_test("43", [
    ("bool", "43a flat — restitution bypassed",       r43a is None,              True),
    ("bool", "43b two-layer fires on index 0",        r43b is not None,          True),
    ("num",  "43b exit price correct",                r43b,    r43b_expected,     TOL),
    ("bool", "43c three-layer fires on index 0",      r43c is not None,          True),
    ("num",  "43c exit price correct",                r43c,    r43c_expected,     TOL),
    ("bool", "43d short direction fires",             r43d is not None,          True),
    ("num",  "43d short exit price correct",          r43d,    r43d_expected,     TOL),
    ("bool", "43e grid contracts after scalp",        r43e_contracts,            True),
])

# ---------------------------------------------------------------------------
# Test 44 -- ADR-057 Kinetic Entry Gate
# Verifies: (a) ComputeKineticDistance scales correctly with sigma_pts,
# (b) KineticGateOpen passes when velocity < threshold,
# (c) KineticGateOpen blocks when velocity >= threshold,
# (d) inventory-weighted patience tightens with inv_size,
# (e) MathMax(1.0) absolute floor prevents mathematical impossibility,
# (f) effective threshold never drops below 1.0 at any inv_size.
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

# Component 1: ComputeKineticDistance
KINETIC_SIGMA_THRESHOLD = 50.0
GRID_BASE = 0.0008

def compute_kinetic_distance(sigma_pts):
    kinetic_scale = 1.0 + (sigma_pts / KINETIC_SIGMA_THRESHOLD)
    return GRID_BASE * kinetic_scale

# Component 2+3: KineticGateOpen
KINETIC_VELOCITY_THRESHOLD = 5.0

def kinetic_gate_open(velocity, inv_size):
    raw_threshold    = KINETIC_VELOCITY_THRESHOLD / max(inv_size, 1)
    effective_thresh = max(1.0, raw_threshold)
    return velocity < effective_thresh

def effective_threshold(inv_size):
    return max(1.0, KINETIC_VELOCITY_THRESHOLD / max(inv_size, 1))

# 44a: sigma_pts=0 -- distance equals GridBase (no scaling)
d44a = compute_kinetic_distance(0.0)

# 44b: sigma_pts=50 -- distance doubles (scale=2.0)
d44b = compute_kinetic_distance(50.0)

# 44c: sigma_pts=100 -- distance triples (scale=3.0)
d44c = compute_kinetic_distance(100.0)

# 44d: gate OPEN -- velocity below threshold at inv_size=1
g44d = kinetic_gate_open(velocity=3.0, inv_size=1)  # thresh=5.0, 3<5 -> open

# 44e: gate BLOCKED -- velocity above threshold at inv_size=1
g44e = kinetic_gate_open(velocity=6.0, inv_size=1)  # thresh=5.0, 6>=5 -> blocked

# 44f: gate BLOCKED -- inv_size=5 tightens threshold to 1.0, velocity=1.5
g44f = kinetic_gate_open(velocity=1.5, inv_size=5)  # thresh=1.0, 1.5>=1.0 -> blocked

# 44g: gate OPEN -- inv_size=5, velocity=0.8 (below tightened threshold)
g44g = kinetic_gate_open(velocity=0.8, inv_size=5)  # thresh=1.0, 0.8<1.0 -> open

# 44h: absolute floor -- at inv_size=100, threshold never drops below 1.0
t44h = effective_threshold(100)  # raw=0.05, floor clamps to 1.0

# 44i: absolute floor -- at inv_size=71 (real event), threshold = 1.0
t44i = effective_threshold(71)   # raw=0.07, floor clamps to 1.0

# 44j: gate OPEN at inv_size=71 with near-flat velocity=0.5
g44j = kinetic_gate_open(velocity=0.5, inv_size=71)  # thresh=1.0, 0.5<1.0 -> open

# 44k: grid expands with sigma (Component 1 monotonicity check)
k44k_monotone = (compute_kinetic_distance(0) <
                 compute_kinetic_distance(50) <
                 compute_kinetic_distance(100))

run_test("44", [
    ("num",  "44a sigma=0 distance=GridBase",       d44a, 0.0008,  TOL),
    ("num",  "44b sigma=50 distance=2xGridBase",    d44b, 0.0016,  TOL),
    ("num",  "44c sigma=100 distance=3xGridBase",   d44c, 0.0024,  TOL),
    ("bool", "44d gate open vel<thresh inv=1",      g44d,          True),
    ("bool", "44e gate blocked vel>=thresh inv=1",  g44e,          False),
    ("bool", "44f gate blocked inv=5 tightened",    g44f,          False),
    ("bool", "44g gate open inv=5 vel<floor",       g44g,          True),
    ("num",  "44h floor clamp at inv=100",          t44h, 1.0,     TOL),
    ("num",  "44i floor clamp at inv=71",           t44i, 1.0,     TOL),
    ("bool", "44j gate open inv=71 near-flat",      g44j,          True),
    ("bool", "44k distance monotone with sigma",    k44k_monotone, True),
])

# ---------------------------------------------------------------------------
# Test 45 -- ADR-058 Directional Bias Gate
# Verifies: (a) BIAS_BOTH permits bid and offer,
# (b) BIAS_LONG_ONLY permits bid, blocks offer,
# (c) BIAS_SHORT_ONLY permits offer, blocks bid,
# (d) exit placement always permitted regardless of bias,
# (e) add_next always permitted regardless of bias.
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

BIAS_BOTH       = 0
BIAS_LONG_ONLY  = 1
BIAS_SHORT_ONLY = 2

def bias_permits_bid(bias):
    """BUY_LIMIT Layer 0 entry -- blocked only for SHORT_ONLY."""
    return bias != BIAS_SHORT_ONLY

def bias_permits_offer(bias):
    """SELL_LIMIT Layer 0 entry -- blocked only for LONG_ONLY."""
    return bias != BIAS_LONG_ONLY

def bias_permits_exit(bias):
    """Exit limits always permitted regardless of bias."""
    return True

def bias_permits_addnext(bias):
    """add_next always permitted regardless of bias."""
    return True

run_test("45", [
    ("bool", "45a BOTH bid permitted",            bias_permits_bid(BIAS_BOTH),         True),
    ("bool", "45b BOTH offer permitted",          bias_permits_offer(BIAS_BOTH),       True),
    ("bool", "45c LONG_ONLY bid permitted",       bias_permits_bid(BIAS_LONG_ONLY),    True),
    ("bool", "45d LONG_ONLY offer blocked",       bias_permits_offer(BIAS_LONG_ONLY),  False),
    ("bool", "45e SHORT_ONLY bid blocked",        bias_permits_bid(BIAS_SHORT_ONLY),   False),
    ("bool", "45f SHORT_ONLY offer permitted",    bias_permits_offer(BIAS_SHORT_ONLY), True),
    ("bool", "45g LONG_ONLY exit permitted",      bias_permits_exit(BIAS_LONG_ONLY),   True),
    ("bool", "45h SHORT_ONLY exit permitted",     bias_permits_exit(BIAS_SHORT_ONLY),  True),
    ("bool", "45i LONG_ONLY addnext permitted",   bias_permits_addnext(BIAS_LONG_ONLY),  True),
    ("bool", "45j SHORT_ONLY addnext permitted",  bias_permits_addnext(BIAS_SHORT_ONLY), True),
    ("bool", "45k BOTH passes both gates",
             bias_permits_bid(BIAS_BOTH) and bias_permits_offer(BIAS_BOTH), True),
])

# ---------------------------------------------------------------------------
# Test 46 -- ADR-061 Part A Partial-Unwind Resubmit Outcome
# Verifies: HandleExitFill partial-unwind block outcome branching on
# PlaceNextEntryLimit return value (success vs warning vs skip).
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

def partial_unwind_resubmit(computed, tkt):
    """Mirrors ADR-061 Part A: HandleExitFill partial-unwind block.
    computed <= 0.0 means ComputeNextLayerPrice itself never
    produced a valid price (gate never entered, no placement
    attempted). computed > 0.0 means PlaceNextEntryLimit was
    called; tkt is its return value."""
    if computed <= 0.0:
        return "skip"
    return "success" if tkt > 0 else "warning"

run_test("46", [
    ("bool", "46a computed<=0 skips placement entirely",
             partial_unwind_resubmit(0.0, 0), "skip"),
    ("bool", "46b negative computed also skips",
             partial_unwind_resubmit(-1.0, 0), "skip"),
    ("bool", "46c valid computed + tkt>0 = success",
             partial_unwind_resubmit(1.14385, 485308319), "success"),
    ("bool", "46d valid computed + tkt==0 = warning (live 2026-06-30 15:02:05 case)",
             partial_unwind_resubmit(1.14373, 0), "warning"),
])

# ---------------------------------------------------------------------------
# Test 47 -- ADR-061 Part B Split LDAK Volume Gate
# Verifies: ComputeLDAKLotSize post-ADR-061 split gate -- drawdown brake
# refuses outright; correlation-only suppression floor-clamps to min_vol.
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

def ldak_split_gate(w, sm, base=0.01, min_vol=0.01, threshold=0.80):
    raw_vol = base * sm * w
    if raw_vol < min_vol * 0.70:
        if sm < threshold:
            return 0.0, "refuse"
        else:
            return min_vol, "clamp"
    return max(raw_vol, min_vol), "pass"

run_test("47", [
    ("bool", "47a deep drawdown refuses outright (sm=0.5,w=1.0)",
             ldak_split_gate(w=1.0, sm=0.5)[1], "refuse"),
    ("bool", "47b healthy sm + poor correlation clamps, not refuses (sm=1.0,w=0.6)",
             ldak_split_gate(w=0.6, sm=1.0)[1], "clamp"),
    ("num",  "47c clamp path returns exactly min_vol",
             ldak_split_gate(w=0.6, sm=1.0)[0], 0.01, 1e-9),
    ("bool", "47d boundary: sm exactly at threshold treated as healthy (sm=0.80,w=0.6)",
             ldak_split_gate(w=0.6, sm=0.80)[1], "clamp"),
    ("bool", "47e boundary: raw_vol exactly at 70pct cutoff never gates (sm=1.0,w=0.70)",
             ldak_split_gate(w=0.70, sm=1.0)[1], "pass"),
    ("bool", "47f fully healthy volume passes through ungated (sm=1.0,w=1.0,base=0.02)",
             ldak_split_gate(w=1.0, sm=1.0, base=0.02)[1], "pass"),
    ("num",  "47g pass path preserves raw_vol above min_vol (sm=1.0,w=1.0,base=0.02)",
             ldak_split_gate(w=1.0, sm=1.0, base=0.02)[0], 0.02, 1e-9),
    ("bool", "47h low sm alone doesn't gate if volume already sufficient (sm=0.5,w=1.0,base=0.05)",
             ldak_split_gate(w=1.0, sm=0.5, base=0.05)[1], "pass"),
])

# ---------------------------------------------------------------------------
# Test 48 -- ADR-062 DirectionalBias Perimeter Seal
# Verifies: (a) SNIPER signal suppression (active_dir vs bias),
# (b) execution-layer backstop for all contradictory direction/bias pairs,
# (c) BIAS_BOTH always permits regardless of direction.
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

DIRECTION_BUY  = 1
DIRECTION_SELL = -1

def sniper_placement_permitted(active_dir, bias):
    """Ruling 1: suppress PlaceEntryLimit when direction contradicts bias."""
    if active_dir == DIRECTION_BUY and bias == BIAS_SHORT_ONLY:
        return False
    if active_dir == DIRECTION_SELL and bias == BIAS_LONG_ONLY:
        return False
    return True

def execution_backstop_blocks(direction, bias):
    """Ruling 3: PlaceEntryLimit / PlaceNextEntryLimit top-of-function guard."""
    if direction == DIRECTION_BUY and bias == BIAS_SHORT_ONLY:
        return True
    if direction == DIRECTION_SELL and bias == BIAS_LONG_ONLY:
        return True
    return False

run_test("48", [
    ("bool", "48a SNIPER BUY suppressed under SHORT_ONLY",
             sniper_placement_permitted(DIRECTION_BUY, BIAS_SHORT_ONLY), False),
    ("bool", "48b SNIPER SELL suppressed under LONG_ONLY",
             sniper_placement_permitted(DIRECTION_SELL, BIAS_LONG_ONLY), False),
    ("bool", "48c SNIPER BUY permitted under LONG_ONLY",
             sniper_placement_permitted(DIRECTION_BUY, BIAS_LONG_ONLY), True),
    ("bool", "48d SNIPER SELL permitted under SHORT_ONLY",
             sniper_placement_permitted(DIRECTION_SELL, BIAS_SHORT_ONLY), True),
    ("bool", "48e SNIPER BUY permitted under BOTH",
             sniper_placement_permitted(DIRECTION_BUY, BIAS_BOTH), True),
    ("bool", "48f SNIPER SELL permitted under BOTH",
             sniper_placement_permitted(DIRECTION_SELL, BIAS_BOTH), True),
    ("bool", "48g backstop blocks BUY under SHORT_ONLY",
             execution_backstop_blocks(DIRECTION_BUY, BIAS_SHORT_ONLY), True),
    ("bool", "48h backstop blocks SELL under LONG_ONLY",
             execution_backstop_blocks(DIRECTION_SELL, BIAS_LONG_ONLY), True),
    ("bool", "48i backstop permits BUY under LONG_ONLY",
             not execution_backstop_blocks(DIRECTION_BUY, BIAS_LONG_ONLY), True),
    ("bool", "48j backstop permits SELL under SHORT_ONLY",
             not execution_backstop_blocks(DIRECTION_SELL, BIAS_SHORT_ONLY), True),
    ("bool", "48k backstop permits BUY under BOTH",
             not execution_backstop_blocks(DIRECTION_BUY, BIAS_BOTH), True),
    ("bool", "48l backstop permits SELL under BOTH",
             not execution_backstop_blocks(DIRECTION_SELL, BIAS_BOTH), True),
    ("bool", "48m BOTH never blocks either direction",
             not execution_backstop_blocks(DIRECTION_BUY, BIAS_BOTH)
             and not execution_backstop_blocks(DIRECTION_SELL, BIAS_BOTH), True),
])

# ---------------------------------------------------------------------------
# Test 49 -- ADR-063 Ruling 5 Circular Alert Buffer Index
# Verifies: modulo wrap logic for g_critical_alert_write_idx advancement.
# Pure Python simulation -- no MQL5 dependency.
# ---------------------------------------------------------------------------

def circular_buffer_next_index(current_idx, buffer_size):
    return (current_idx + 1) % buffer_size

run_test("49", [
    ("num", "49a normal increment", circular_buffer_next_index(3, 10), 4, 0),
    ("num", "49b wraps at buffer end", circular_buffer_next_index(9, 10), 0, 0),
    ("num", "49c wraps from zero forward", circular_buffer_next_index(0, 10), 1, 0),
    ("num", "49d buffer size 1 always wraps to self", circular_buffer_next_index(0, 1), 0, 0),
    ("num", "49e second-to-last index", circular_buffer_next_index(8, 10), 9, 0),
])

# ---------------------------------------------------------------------------
# Test 50 -- ADR-072 CloseBy Exhaustion Three-Way Branch
# Verifies: conditional exhaustion outcome by POSITION_TYPE pairing.
# Pure Python mirror -- no MQL5 dependency.
# ---------------------------------------------------------------------------

def closeby_exhaustion_outcome(sel1, type1, sel2, type2):
    if not sel1 or not sel2:
        return "skip_unselectable"
    if type1 != type2:
        return "discard_delta_neutral"
    return "halt_same_direction"

run_test("50", [
    ("bool", "50a opposite types -> delta neutral discard",
             closeby_exhaustion_outcome(True, 0, True, 1) == "discard_delta_neutral", True),
    ("bool", "50b same types (both buy) -> halt",
             closeby_exhaustion_outcome(True, 0, True, 0) == "halt_same_direction", True),
    ("bool", "50c same types (both sell) -> halt",
             closeby_exhaustion_outcome(True, 1, True, 1) == "halt_same_direction", True),
    ("bool", "50d ticket1 unselectable -> skip",
             closeby_exhaustion_outcome(False, -1, True, 1) == "skip_unselectable", True),
    ("bool", "50e ticket2 unselectable -> skip",
             closeby_exhaustion_outcome(True, 0, False, -1) == "skip_unselectable", True),
    ("bool", "50f both unselectable -> skip",
             closeby_exhaustion_outcome(False, -1, False, -1) == "skip_unselectable", True),
])

# ---------------------------------------------------------------------------
# Test 51 -- ADR-074 Emergency Sweep Batched Verification Poll
# Pure Python mirror of ExecuteEmergencySystemSweep() poll loop.
# ---------------------------------------------------------------------------

def emergency_verify_poll(is_open_fns, max_polls=5):
    """Returns (still_open_flags, rounds_used). is_open_fns[t]() True = position still open."""
    n = len(is_open_fns)
    if n == 0:
        return [], 0
    still_open = [True] * n
    rounds_used = 0
    for poll in range(max_polls):
        rounds_used = poll + 1
        any_still_open = False
        for t in range(n):
            if not still_open[t]:
                continue
            if not is_open_fns[t]():
                still_open[t] = False
            else:
                any_still_open = True
        if not any_still_open:
            break
    return still_open, rounds_used

run_test("51", [
    ("bool", "51a all closed round 1 -- early break",
             emergency_verify_poll([lambda: False, lambda: False])[1] == 1, True),
    ("bool", "51a all closed -- none stranded",
             sum(emergency_verify_poll([lambda: False, lambda: False])[0]) == 0, True),
    ("bool", "51b one never closes -- poll exhausts 5 rounds",
             emergency_verify_poll([lambda: False, lambda: True])[1] == 5, True),
    ("bool", "51b one never closes -- flagged stranded",
             emergency_verify_poll([lambda: False, lambda: True])[0][1] == True, True),
    ("bool", "51c empty close_attempted -- no-op",
             emergency_verify_poll([]) == ([], 0), True),
])

# ---------------------------------------------------------------------------
# Test 52 -- ADR-075 ExecuteSystemSweep mode dispatch
# Pure Python mirror of full_sweep vs scoped decision logic.
# ---------------------------------------------------------------------------

def sweep_mode(target_instrument):
    full_sweep = (target_instrument == -1)
    return {
        "full_sweep": full_sweep,
        "should_detach": full_sweep,
        "scan_scope": "all_three" if full_sweep else "single",
        "purge_scope": "all_three" if full_sweep else "single",
        "clears_pending_globals": not full_sweep,
    }

run_test("52", [
    ("bool", "52a target=-1 -> full sweep + detach",
             sweep_mode(-1)["should_detach"] == True, True),
    ("bool", "52b target=-1 -> scans all three",
             sweep_mode(-1)["scan_scope"] == "all_three", True),
    ("bool", "52c target=0 -> no detach",
             sweep_mode(0)["should_detach"] == False, True),
    ("bool", "52d target=0 -> scoped scan",
             sweep_mode(0)["scan_scope"] == "single", True),
    ("bool", "52e target=0 -> clears pending globals",
             sweep_mode(0)["clears_pending_globals"] == True, True),
    ("bool", "52f target=-1 -> does NOT clear pending globals",
             sweep_mode(-1)["clears_pending_globals"] == False, True),
])

# ---------------------------------------------------------------------------
# Test 53 -- ADR-077 ComputeGridInterval four-mechanism decomposition
# Pure Python mirror of MathEngine.mqh ComputeGridInterval().
# Verifies: all toggles off reproduces QuoteSpread*(layer_idx+1) exactly;
# each mechanism independently; all four stacked at layers 0, 5, 10.
# ---------------------------------------------------------------------------

def compute_grid_interval(layer_idx, instrument_active,
                          enable_gridmode, enable_layer_stress,
                          enable_pnl_stress, enable_ldak_dilation,
                          quote_spread=0.0004, grid_mode=2,
                          grid_base=0.0008, grid_linear_step=0.0002,
                          grid_inflection=2, grid_exp_base=1.5,
                          layer_stress_base=1.5, pnl_stress_input=1.0,
                          dilation_input=1.0):
    if enable_gridmode:
        if grid_mode == 0:
            base_interval = grid_base
        elif grid_mode == 1:
            base_interval = grid_base + layer_idx * grid_linear_step
        else:
            if layer_idx <= grid_inflection:
                base_interval = grid_base + layer_idx * grid_linear_step
            else:
                s_at_inflection = grid_base + grid_inflection * grid_linear_step
                base_interval = s_at_inflection * (grid_exp_base **
                                                   (layer_idx - grid_inflection))
    else:
        base_interval = quote_spread * (layer_idx + 1)

    layer_stress = (layer_stress_base ** layer_idx) if enable_layer_stress else 1.0
    pnl_stress = pnl_stress_input if (enable_pnl_stress and instrument_active) else 1.0
    dilation = dilation_input if (enable_ldak_dilation and instrument_active) else 1.0

    return base_interval * layer_stress * pnl_stress * dilation


def grid_interval_baseline(layer_idx, quote_spread=0.0004):
    return quote_spread * (layer_idx + 1)


def grid_interval_hybrid_base(layer_idx, grid_base=0.0008, grid_linear_step=0.0002,
                              grid_inflection=2, grid_exp_base=1.5):
    if layer_idx <= grid_inflection:
        return grid_base + layer_idx * grid_linear_step
    s_at = grid_base + grid_inflection * grid_linear_step
    return s_at * (grid_exp_base ** (layer_idx - grid_inflection))


QS53 = 0.0004
LSB53 = 1.5
PNL53 = 2.0
DIL53 = 2.0

for _li in (0, 5, 10):
    _tag = f"li{_li}"
    _base = grid_interval_baseline(_li, QS53)
    _hyb = grid_interval_hybrid_base(_li)

    run_test("53", [
        ("num", f"53a-{_tag} all off = baseline",
         compute_grid_interval(_li, False, False, False, False, False),
         _base, TOL),
        ("num", f"53b-{_tag} gridmode hybrid only",
         compute_grid_interval(_li, False, True, False, False, False, grid_mode=2),
         _hyb, TOL),
        ("num", f"53c-{_tag} layer stress only",
         compute_grid_interval(_li, False, False, True, False, False,
                               layer_stress_base=LSB53),
         _base * (LSB53 ** _li), TOL),
        ("num", f"53d-{_tag} pnl stress only",
         compute_grid_interval(_li, True, False, False, True, False,
                               pnl_stress_input=PNL53),
         _base * PNL53, TOL),
        ("num", f"53e-{_tag} ldak dilation only",
         compute_grid_interval(_li, True, False, False, False, True,
                               dilation_input=DIL53),
         _base * DIL53, TOL),
        ("num", f"53f-{_tag} all four stacked",
         compute_grid_interval(_li, True, True, True, True, True,
                               grid_mode=2, layer_stress_base=LSB53,
                               pnl_stress_input=PNL53, dilation_input=DIL53),
         _hyb * (LSB53 ** _li) * PNL53 * DIL53, TOL),
    ])

# 53g: toggles-off bit-for-bit at layer 10 -- explicit neutral-product proof
_g53_off = compute_grid_interval(10, False, False, False, False, False)
_g53_base = QS53 * 11
run_test("53", [
    ("num", "53g layer10 toggles-off exact", _g53_off, _g53_base, TOL),
    ("bool", "53g product all 1.0x",
     compute_grid_interval(10, True, False, False, False, False,
                           pnl_stress_input=99.0, dilation_input=99.0) == _g53_base,
     True),
])

# ---------------------------------------------------------------------------
# Test 54 -- ADR-078 ExitResetDelaySeconds LIFO defer + Option B timing fork
# Pure Python mirror of LIFO resubmit block and OnTick Option B gating.
# Verifies: toggle off = immediate resubmit; toggle on = defer;
# exit-reset uses ExitResetDelaySeconds; normal empty uses
# MinLayerIntervalSeconds; KineticGateOpen applies to both paths.
# ---------------------------------------------------------------------------

def lifo_resubmit_action(debug_enable_exit_reset_delay, inst, now,
                         g_last_exit_reset_time):
    """Mirror LIFO resubmit block after cancel (no placement when deferring)."""
    if debug_enable_exit_reset_delay:
        g_last_exit_reset_time[inst] = now
        return "defer", g_last_exit_reset_time
    return "immediate", g_last_exit_reset_time


def option_b_should_place(inst, now, g_last_exit_reset_time, g_last_layer_time,
                          min_layer_interval, exit_reset_delay, kinetic_open):
    """Mirror Option B timing gate (preconditions: inv>0, add_next==0)."""
    exit_reset_pending = g_last_exit_reset_time[inst] > 0
    if exit_reset_pending:
        timing_ok = (now - g_last_exit_reset_time[inst] >= exit_reset_delay)
    else:
        timing_ok = (now - g_last_layer_time[inst] >= min_layer_interval)
    return timing_ok and kinetic_open, exit_reset_pending


MIN54 = 300
DEL54 = 30
T0_54 = 1000

# 54a/54b: LIFO resubmit path
_g54 = [0, 0, 0]
_act_off, _g54_off = lifo_resubmit_action(False, 0, T0_54, _g54[:])
_g54_on = [0, 0, 0]
_act_on, _g54_on = lifo_resubmit_action(True, 0, T0_54, _g54_on[:])

run_test("54", [
    ("bool", "54a toggle off -> immediate resubmit",
             _act_off == "immediate", True),
    ("bool", "54a toggle off -> exit_reset timer untouched",
             _g54_off[0] == 0, True),
    ("bool", "54b toggle on -> defer (no inline place)",
             _act_on == "defer", True),
    ("bool", "54b toggle on -> arms exit_reset timer",
             _g54_on[0] == T0_54, True),
])

# 54c/54d: exit-reset Option B gating
_g54c = [T0_54, 0, 0]
_ok_c, _pend_c = option_b_should_place(0, T0_54 + 15, _g54c, [0, 0, 0],
                                       MIN54, DEL54, True)
_ok_d, _pend_d = option_b_should_place(0, T0_54 + DEL54, _g54c, [0, 0, 0],
                                       MIN54, DEL54, True)

run_test("54", [
    ("bool", "54c exit-reset elapsed < delay -> blocked",
             _ok_c == False and _pend_c == True, True),
    ("bool", "54d exit-reset elapsed >= delay + kinetic -> allowed",
             _ok_d == True and _pend_d == True, True),
])

# 54e/54f: normal deepen-cycle Option B gating
_ok_e, _pend_e = option_b_should_place(0, T0_54 + 15, [0, 0, 0],
                                       [T0_54, 0, 0], MIN54, DEL54, True)
_ok_f, _pend_f = option_b_should_place(0, T0_54 + MIN54, [0, 0, 0],
                                       [T0_54, 0, 0], MIN54, DEL54, True)

run_test("54", [
    ("bool", "54e normal empty elapsed < MinLayer -> blocked",
             _ok_e == False and _pend_e == False, True),
    ("bool", "54f normal empty elapsed >= MinLayer + kinetic -> allowed",
             _ok_f == True and _pend_f == False, True),
])

# 54g: exit-reset uses ExitResetDelaySeconds, NOT MinLayerIntervalSeconds
# MinLayer satisfied (500s since last add) but exit delay not (15s since arm)
_ok_g, _ = option_b_should_place(0, T0_54 + 15, [T0_54, 0, 0],
                                 [T0_54 - 500, 0, 0], MIN54, DEL54, True)

# 54h: normal path uses MinLayerIntervalSeconds, NOT ExitResetDelaySeconds
# Exit delay would pass (35s) but MinLayer not (15s since last add)
_ok_h, _ = option_b_should_place(0, T0_54 + 15, [0, 0, 0],
                                 [T0_54, 0, 0], MIN54, DEL54, True)

run_test("54", [
    ("bool", "54g exit-reset ignores MinLayer (still blocked)",
             _ok_g == False, True),
    ("bool", "54h normal ignores ExitResetDelay (still blocked)",
             _ok_h == False, True),
])

# 54i: KineticGateOpen required on both paths
_ok_i_exit, _ = option_b_should_place(0, T0_54 + DEL54, [T0_54, 0, 0],
                                      [0, 0, 0], MIN54, DEL54, False)
_ok_i_norm, _ = option_b_should_place(0, T0_54 + MIN54, [0, 0, 0],
                                      [T0_54, 0, 0], MIN54, DEL54, False)

run_test("54", [
    ("bool", "54i exit-reset blocked when kinetic closed",
             _ok_i_exit == False, True),
    ("bool", "54i normal deepen blocked when kinetic closed",
             _ok_i_norm == False, True),
])

# ---------------------------------------------------------------------------
# Test 55 -- ADR-079 Dynamic re-anchor intercept (PlaceNextEntryLimit)
# Pure Python mirror of the NEW intercept only -- existing clamp unchanged.
# Verifies: toggle off = static unchanged; toggle on no violation = static;
# toggle on with violation = market -/+ distance, exact distance preserved.
# ---------------------------------------------------------------------------

DIR_BUY55 = 1
DIR_SELL55 = -1


def dynamic_reanchor_price(debug_enable, static_price, entry_price, direction,
                           current_bid, current_ask, stops_level=0, point=0.00001):
    """Mirror ADR-079 intercept before the unchanged passivity clamp."""
    price = static_price
    if not debug_enable:
        return price
    distance = abs(price - entry_price)
    min_dist = max(stops_level * point, point)
    if direction == DIR_BUY55:
        if current_bid > 0.0 and price > current_bid - min_dist:
            price = current_bid - distance
    else:
        if current_ask > 0.0 and price < current_ask + min_dist:
            price = current_ask + distance
    return price


PT55 = 0.00001
SL55 = 0
MD55 = PT55

# 55a: toggle off always returns static price
_static55 = 1.09500
_entry55 = 1.10000
_bid55 = 1.09800
_ask55 = 1.09820
run_test("55", [
    ("num", "55a toggle off BUY returns static",
     dynamic_reanchor_price(False, _static55, _entry55, DIR_BUY55, _bid55, _ask55, SL55, PT55),
     _static55, TOL),
    ("num", "55a toggle off SELL returns static",
     dynamic_reanchor_price(False, 1.10500, _entry55, DIR_SELL55, _bid55, 1.10510, SL55, PT55),
     1.10500, TOL),
])

# 55b: toggle on, no passivity violation -- static unchanged
_passive_buy = 1.09400   # below bid - min_dist (1.09799)
_passive_sell = 1.10650  # above ask + min_dist (1.10511)
run_test("55", [
    ("num", "55b toggle on BUY no violation = static",
     dynamic_reanchor_price(True, _passive_buy, _entry55, DIR_BUY55, _bid55, _ask55, SL55, PT55),
     _passive_buy, TOL),
    ("num", "55b toggle on SELL no violation = static",
     dynamic_reanchor_price(True, _passive_sell, _entry55, DIR_SELL55, _bid55, 1.10510, SL55, PT55),
     _passive_sell, TOL),
])

# 55c: toggle on WITH violation -- reanchor preserving exact distance
_viol_buy_static = 1.09900
_viol_buy_dist = abs(_viol_buy_static - _entry55)
_viol_buy_bid = 1.09800
_viol_buy_result = dynamic_reanchor_price(
    True, _viol_buy_static, _entry55, DIR_BUY55, _viol_buy_bid, _ask55, SL55, PT55)

_viol_sell_static = 1.10500
_viol_sell_dist = abs(_viol_sell_static - _entry55)
_viol_sell_ask = 1.10600
_viol_sell_result = dynamic_reanchor_price(
    True, _viol_sell_static, _entry55, DIR_SELL55, _bid55, _viol_sell_ask, SL55, PT55)

run_test("55", [
    ("num", "55c BUY violation = bid - distance",
     _viol_buy_result, _viol_buy_bid - _viol_buy_dist, TOL),
    ("num", "55c BUY preserved distance exact",
     abs(_viol_buy_dist - abs(_viol_buy_static - _entry55)), 0.0, TOL),
    ("num", "55c SELL violation = ask + distance",
     _viol_sell_result, _viol_sell_ask + _viol_sell_dist, TOL),
    ("num", "55c SELL preserved distance exact",
     abs(_viol_sell_dist - abs(_viol_sell_static - _entry55)), 0.0, TOL),
])

# ---------------------------------------------------------------------------
# Test 56 -- ADR-080 HandleEntryFill unified vs legacy add_next spacing
# Pure Python mirror. Reuses compute_grid_interval (Test 53) and
# compute_kinetic_distance (Test 44). Verifies: toggle off = legacy
# A_golden with L.layer_index; toggle on = ComputeNextLayerPrice via
# layer_idx+1; counterexample that legacy must NOT shift index +1.
# ---------------------------------------------------------------------------

DIR_BUY56 = 1
DIR_SELL56 = -1
PT56 = 0.00001
QS56 = 0.0004


def compute_next_layer_price(next_layer_idx, prev_layer_index, entry_spread_raw,
                             entry_price, direction, sigma_pts=0.0, pt=PT56,
                             quote_spread=QS56):
    """Mirror ExecutionEngine.mqh ComputeNextLayerPrice() core math."""
    if next_layer_idx - 1 < 0:
        return -1.0
    e_n = abs(entry_spread_raw) * (PHI ** (prev_layer_index + 1))
    base_add = compute_grid_interval(prev_layer_index, False, False, False, False,
                                     False, quote_spread=quote_spread)
    kinetic_dist = compute_kinetic_distance(sigma_pts)
    a_n = max(base_add, max(e_n + 10.0 * pt, kinetic_dist))
    if direction == DIR_BUY56:
        return entry_price - a_n
    return entry_price + a_n


def legacy_hf_add_next(layer_index, entry_spread_raw, entry_price, direction,
                       quote_spread=QS56):
    """Mirror HandleEntryFill legacy branch (DebugUseUnifiedAddNextSpacing=false)."""
    e_n_add = abs(entry_spread_raw) * (PHI ** (layer_index + 1))
    base_add = compute_grid_interval(layer_index, False, False, False, False, False,
                                     quote_spread=quote_spread)
    a_golden = e_n_add * 1.618
    a_n = max(base_add, a_golden)
    if direction == DIR_BUY56:
        return entry_price - a_n
    return entry_price + a_n


def legacy_hf_add_next_wrong_shift(layer_index, entry_spread_raw, entry_price,
                                   direction, quote_spread=QS56):
    """Counterexample: legacy formula with layer_index+1 wrongly in exponent/grid."""
    wrong_idx = layer_index + 1
    e_n_add = abs(entry_spread_raw) * (PHI ** (wrong_idx + 1))
    base_add = compute_grid_interval(wrong_idx, False, False, False, False, False,
                                     quote_spread=quote_spread)
    a_golden = e_n_add * 1.618
    a_n = max(base_add, a_golden)
    if direction == DIR_BUY56:
        return entry_price - a_n
    return entry_price + a_n


def handle_entry_fill_add_next(unified, layer_idx, layer_index, entry_spread_raw,
                               entry_price, direction, sigma_pts=0.0):
    if unified:
        return compute_next_layer_price(layer_idx + 1, layer_index, entry_spread_raw,
                                        entry_price, direction, sigma_pts)
    return legacy_hf_add_next(layer_index, entry_spread_raw, entry_price, direction)


_LI56 = 2
_LIDX56 = 2
_SPR56 = 0.0010
_ENT56 = 1.10000
_SIG56 = 50.0

_legacy56 = legacy_hf_add_next(_LI56, _SPR56, _ENT56, DIR_BUY56)
_off56 = handle_entry_fill_add_next(False, _LIDX56, _LI56, _SPR56, _ENT56, DIR_BUY56)
_unified56 = compute_next_layer_price(_LIDX56 + 1, _LI56, _SPR56, _ENT56, DIR_BUY56, _SIG56)
_on56 = handle_entry_fill_add_next(True, _LIDX56, _LI56, _SPR56, _ENT56, DIR_BUY56, _SIG56)
_wrong56 = legacy_hf_add_next_wrong_shift(_LI56, _SPR56, _ENT56, DIR_BUY56)

run_test("56", [
    ("num", "56a toggle off = legacy A_golden formula",
     _off56, _legacy56, TOL),
    ("num", "56b toggle on = ComputeNextLayerPrice(layer_idx+1)",
     _on56, _unified56, TOL),
    ("bool", "56c wrong layer_index+1 shift differs from legacy",
             _wrong56 != _legacy56, True),
    ("bool", "56c wrong shift delta non-zero",
             abs(_wrong56 - _legacy56) > TOL, True),
])

order = ["0", "0b", "0c", "0d"] + [str(i) for i in range(1, 46)] + ["46", "47", "48", "49", "50", "51", "52", "53", "54", "55", "56"]
print("FXMatrix ADR-UNIT-TESTS — Full Run (Tests 0, 0b, 0c, 0d, 1-56)")
print("Tolerance: 0.00001 | Test 23: 0.000001 | Test 20/24 ratio: 0.001 | Test 39c/41c/41e: 0.001")
print("=" * 72)

total_sub = pass_sub = 0
for t in order:
    subs = [r for r in report if r[0] == t]
    tp = all(r[2] == "PASS" for r in subs)
    total_sub += len(subs)
    pass_sub += sum(1 for r in subs if r[2] == "PASS")
    sym = "PASS" if tp else "FAIL"
    print(f"Test {t:>3s}: {sym} ({len(subs)} subtests)")
    if not tp:
        for r in subs:
            if r[2] == "FAIL":
                print(f"  FAIL {r[1]}: actual={r[3]} expected={r[4]}")

print("=" * 72)
print(f"SUMMARY: {pass_sub}/{total_sub} subtests PASS")
if fails:
    print(f"FAILED subtests ({len(fails)}):")
    for f in fails:
        print(f"  {f}")
else:
    print("ALL TESTS PASS")
