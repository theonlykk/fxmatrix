"""Execute fxmatrix_v2_tests.mq5 assertions in Python (mirrors mqh logic exactly)."""
from __future__ import annotations

import math

V2_ADD_PIPS_FLOOR = 9.0
V2_WIDEN_RATIO = 1.304
V2_ADD_PIPS_CEILING = 1000.0
TRADE_ACTION_SLTP = 6  # MQL5 enum value


def v2_spacing_pips_dn(n: int) -> float:
    if n <= 2:
        return V2_ADD_PIPS_FLOOR
    raw = V2_ADD_PIPS_FLOOR * (V2_WIDEN_RATIO ** (n - 2))
    return min(V2_ADD_PIPS_CEILING, raw)


def v2_on_own_stack_flat(last_exit_valid: bool, layer_count: int) -> bool:
    if layer_count == 0:
        return False
    return last_exit_valid


class MockStack:
    def __init__(self):
        self.entries: list[float] = []
        self.last_exit_price = 0.0
        self.last_exit_valid = False

    def reset(self):
        self.entries = []
        self.last_exit_price = 0.0
        self.last_exit_valid = False

    def pop_top(self):
        if not self.entries:
            return
        self.last_exit_price = self.entries[-1]
        self.last_exit_valid = True
        self.entries.pop()
        self.last_exit_valid = v2_on_own_stack_flat(self.last_exit_valid, len(self.entries))


def build_exit_sltp(symbol: str, position_ticket: int, tp: float) -> dict | None:
    if position_ticket == 0:
        return None
    return {
        "action": TRADE_ACTION_SLTP,
        "symbol": symbol,
        "position": position_ticket,
        "sl": 0.0,
        "tp": tp,
    }


def main():
    run = passed = 0

    def assert_true(name: str, cond: bool):
        nonlocal run, passed
        run += 1
        if cond:
            passed += 1
            print(f"PASS | {name}")
        else:
            print(f"FAIL | {name}")

    def assert_near(name: str, got: float, exp: float, tol: float):
        assert_true(name, abs(got - exp) <= tol)

    print("=== fxmatrix_v2 native unit tests (Python mirror of fxmatrix_v2_tests.mq5) ===")

    # (d)
    assert_near("D1 floor", v2_spacing_pips_dn(1), 9.0, 1e-9)
    assert_near("D2 floor", v2_spacing_pips_dn(2), 9.0, 1e-9)
    assert_near("D3 widen", v2_spacing_pips_dn(3), 9.0 * 1.304, 1e-6)
    assert_near("D4 widen", v2_spacing_pips_dn(4), 9.0 * V2_WIDEN_RATIO**2, 1e-6)
    assert_near("D5 widen", v2_spacing_pips_dn(5), 9.0 * V2_WIDEN_RATIO**3, 1e-4)
    d25 = v2_spacing_pips_dn(25)
    assert_true("D25 at ceiling", d25 <= V2_ADD_PIPS_CEILING + 1e-6)
    assert_true("D25 equals ceiling", abs(d25 - V2_ADD_PIPS_CEILING) < 1e-3)

    # (b)
    s = MockStack()
    s.reset()
    s.entries = [1.25000]
    s.pop_top()
    assert_true("after pop with 0 layers last_exit_valid false", not s.last_exit_valid)
    assert_true("layer count zero", len(s.entries) == 0)

    s.reset()
    s.entries = [1.24000, 1.25000]
    s.pop_top()
    assert_true("partial stack keeps reload gate", s.last_exit_valid)
    assert_true("one layer remains", len(s.entries) == 1)
    assert_near("last_exit_price stored", s.last_exit_price, 1.25000, 1e-9)

    # (a)
    long_s = MockStack()
    short_s = MockStack()
    long_s.reset()
    short_s.reset()
    long_s.entries = [1.25000]
    short_s.entries = [1.26000, 1.27000]
    short_s.last_exit_valid = False
    long_s.pop_top()
    assert_true("long flat clears own reload gate", not long_s.last_exit_valid)
    assert_true("long stack empty", len(long_s.entries) == 0)
    assert_true("short stack depth preserved", len(short_s.entries) == 2)
    assert_true("short last_exit_valid not coupled to long flat", short_s.last_exit_valid is False)
    short_s.pop_top()
    assert_true("short reload gate active after own pop", short_s.last_exit_valid)
    assert_true("long still flat/isolated", not long_s.last_exit_valid)
    assert_true("long still empty", len(long_s.entries) == 0)

    # (c)
    req = build_exit_sltp("GBPUSD", 123456789, 1.25300)
    assert_true("build sltp ok", req is not None)
    assert_true("action is TRADE_ACTION_SLTP", req["action"] == TRADE_ACTION_SLTP)
    assert_true("position ticket targeted", req["position"] == 123456789)
    assert_true("tp set", abs(req["tp"] - 1.25300) < 1e-9)
    assert_true("no sl on exit-only modify", req["sl"] == 0.0)
    assert_true("symbol set", req["symbol"] == "GBPUSD")
    assert_true("zero ticket rejected", build_exit_sltp("GBPUSD", 0, 1.25300) is None)

    print(f"=== summary: {passed}/{run} passed ===")
    if passed != run:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
