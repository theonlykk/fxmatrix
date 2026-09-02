# Gemini Ruling Request — entry_price_eurusd_1h for subsequent layers

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** Quick ruling — carry reference prices for Layer N+ fills

---

**Context**

DeepSeek audit identified a Medium priority issue in HandleEntryFill().
For subsequent layers (Layer 1+), `entry_price_eurusd_1h` and
`entry_price_gbpusd_1h` are currently set from live globals
`g_EU_mid_12bars_ago` and `g_GB_mid_12bars_ago`.

These globals are updated at each M5 bar close. If a Layer 1+ fill
occurs in a different M5 bar than when the global was last set, the
value could be slightly stale.

---

**The design question**

`entry_price_eurusd_1h` is used by ADR-003 carry recalculation as
the reference price for computing forward drift:

```
r_EU_fwd = log(EURUSD_fwd / layer.entry_price_eurusd_1h)
```

For Layer 0, this is set from `g_EU_mid_12bars_ago` at signal time
— i.e. EURUSD 1 hour before the signal bar. This is correct.

For Layer 1+, two options:

**Option A — Use Layer 0's anchor (inherit)**
Set `entry_price_eurusd_1h = L.EU_mid_12bars_ago_at_entry` (which
for Layer 1+ is already inherited from Layer 0). All layers share
the same carry reference baseline — the 1h-prior price at the time
of the original pod signal.

Implication: carry for Layer 1+ is computed relative to the same
reference as Layer 0. A Layer 4 that filled 4 hours after Layer 0
would have its carry computed as if it also filled at signal time.
This slightly overstates the carry for later layers.

**Option B — Capture live 1h-prior at each layer's fill time**
Set `entry_price_eurusd_1h = g_EU_mid_12bars_ago` at the moment
of each layer's fill. Each layer gets its own carry baseline.

This is more precise but introduces the live-global contamination
DeepSeek flagged — if the fill occurs mid-M5-bar, g_EU_mid_12bars_ago
reflects the last M5 close, not exactly 1 hour before the fill.

**Our position: Option A for V1.**

All layers in a pod represent the same dislocation event. Using the
same carry reference baseline (Layer 0's 1h-prior) keeps the carry
calculation simple, consistent, and auditable. The overstatement of
carry for later layers is small — typically minutes to hours difference
in reference time — and dwarfed by other approximations already
accepted in V1 (simple interest, hardcoded rates, calendar days).

**Ruling requested:** Confirm Option A — `entry_price_eurusd_1h` and
`entry_price_gbpusd_1h` for Layer 1+ should be set from
`L.EU_mid_12bars_ago_at_entry` and `L.GB_mid_12bars_ago_at_entry`
respectively (already-set layer-local fields, inherited from Layer 0).

