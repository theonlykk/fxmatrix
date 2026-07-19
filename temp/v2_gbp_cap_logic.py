"""Python mirror of ea/fxmatrix_v2_gbp_cap.mqh — keep in sync for unit tests."""
from __future__ import annotations

CAP_GV = {
    ("GBPUSD", True): "V2GBP_L_GBPUSD",
    ("GBPUSD", False): "V2GBP_S_GBPUSD",
    ("EURGBP", True): "V2GBP_L_EURGBP",
    ("EURGBP", False): "V2GBP_S_EURGBP",
}


def read_layers(gv: dict[str, float], key: str) -> int:
    if key not in gv:
        return 0
    return int(gv[key])


def gbp_net(gv: dict[str, float]) -> float:
    gbp_l = read_layers(gv, "V2GBP_L_GBPUSD")
    gbp_s = read_layers(gv, "V2GBP_S_GBPUSD")
    egp_l = read_layers(gv, "V2GBP_L_EURGBP")
    egp_s = read_layers(gv, "V2GBP_S_EURGBP")
    return float((gbp_l - gbp_s) - (egp_l - egp_s))


def cap_delta(pair: str, is_long: bool) -> float:
    if pair == "GBPUSD":
        return 1.0 if is_long else -1.0
    if pair == "EURGBP":
        return -1.0 if is_long else 1.0
    return 0.0


def blocks_new_add(net: float, pair: str, is_long: bool, threshold: int) -> bool:
    """Exact mirror of V2_GbpCapBlocksNewAdd()."""
    if threshold <= 0:
        return False
    delta = cap_delta(pair, is_long)
    if delta == 0.0:
        return False
    new_net = net + delta
    if abs(new_net) <= abs(net) + 1e-9:
        return False
    return abs(new_net) > threshold


def sync_instance(gv: dict[str, float], pair: str, is_long: bool, layers: int) -> None:
    key = CAP_GV.get((pair, is_long), "")
    if key:
        gv[key] = float(layers)


# --- Mirror of ea/fxmatrix_v2_cross_exposure_cap.mqh (legacy triad preset) ---

CROSS_CAP_PEERS = (
    ("GBPUSD_LONG", "V2GBP_L_GBPUSD", +1.0),
    ("GBPUSD_SHORT", "V2GBP_S_GBPUSD", -1.0),
    ("EURGBP_LONG", "V2GBP_L_EURGBP", -1.0),
    ("EURGBP_SHORT", "V2GBP_S_EURGBP", +1.0),
)

LOCAL_CAP = {
    "GBPUSD": ("V2GBP_L_GBPUSD", "V2GBP_S_GBPUSD", +1.0, -1.0),
    "EURGBP": ("V2GBP_L_EURGBP", "V2GBP_S_EURGBP", -1.0, +1.0),
}


def cross_cap_net(gv: dict[str, float]) -> float:
    """Mirror V2_CrossCapNetExposure() for GBP_TRIAD_LEGACY peers."""
    total = 0.0
    for _iid, key, coef in CROSS_CAP_PEERS:
        total += coef * read_layers(gv, key)
    return total


def cross_cap_delta(pair: str, is_long: bool) -> float:
    """Mirror V2_CrossCapDeltaForAdd() for GBPUSD/EURGBP legacy preset."""
    cfg = LOCAL_CAP.get(pair)
    if not cfg:
        return 0.0
    return cfg[2] if is_long else cfg[3]


def cross_cap_blocks_new_add(gv: dict[str, float], pair: str, is_long: bool, threshold: int) -> bool:
    """Mirror V2_CrossCapBlocksNewAdd() for GBP_TRIAD_LEGACY preset."""
    if threshold <= 0:
        return False
    delta = cross_cap_delta(pair, is_long)
    if delta == 0.0:
        return False
    net = cross_cap_net(gv)
    new_net = net + delta
    if abs(new_net) <= abs(net) + 1e-9:
        return False
    return abs(new_net) > threshold


def cross_cap_sync(gv: dict[str, float], pair: str, is_long: bool, layers: int) -> None:
    cfg = LOCAL_CAP.get(pair)
    if not cfg:
        return
    key = cfg[0] if is_long else cfg[1]
    gv[key] = float(layers)
