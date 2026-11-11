"""Tick inventory and real spreads (IC Markets raw). Output: out/05_ticks_inventory.txt
Per pair: range, ticks, gaps; spread: time-weighted mean, tick-count mean, median; by server hour;
and how the MT5 bar convention (minimum spread of each minute) compares with the mean spread of the same minute."""
from ticks import *
L = []
P = lambda s="": (L.append(s), print(s, flush=True))
for pair in PAIRS:
    t, bid, ask = load_ticks(pair)
    sp = (ask - bid) / PIP
    dt = np.diff(t); w = np.minimum(dt, 60000).astype(float)     # time weights, gaps capped at 60 s
    tw = (sp[:-1] * w).sum() / w.sum()
    hr = (t // 3600000) % 24
    P("%s ticks=%d first=%s last=%s gaps>10min=%d (weekends incl.)" % (pair, len(t), pd.to_datetime(t[0], unit="ms"),
      pd.to_datetime(t[-1], unit="ms"), (dt > 600000).sum()))
    P("  spread pips: time-weighted mean=%.2f tick mean=%.2f median=%.2f p90=%.2f p99=%.2f ; negative or zero spread ticks=%d"
      % (tw, sp.mean(), np.median(sp), np.percentile(sp, 90), np.percentile(sp, 99), (sp <= 0).sum()))
    P("  time-weighted spread by server hour: " + " ".join("%d:%.2f" % (h, (sp[:-1][hr[:-1] == h] * w[hr[:-1] == h]).sum() / max(w[hr[:-1] == h].sum(), 1)) for h in range(24)))
    b = bars_from_ticks(t, bid, ask)
    bh = (b["t"] // 3600) % 24
    core = (bh >= 2) & (bh <= 21)
    P("  M1 bars from ticks: n=%d ; mean of per-minute MIN spread=%.2f, of per-minute MEAN spread=%.2f (core hours 2-21: min %.2f, mean %.2f, first-tick %.2f)"
      % (len(b["t"]), b["sp"].mean() / PIP, b["sp_mean"].mean() / PIP, b["sp"][core].mean() / PIP, b["sp_mean"][core].mean() / PIP,
         b["sp_first"][core].mean() / PIP))
    fb = load_bars(pair)
    m = (fb["t"] >= b["t"][0]) & (fb["t"] <= b["t"][-1])
    fh = (fb["t"][m] // 3600) % 24
    fcore = (fh >= 2) & (fh <= 21)
    P("  FTMO bars, same dates: mean recorded spread=%.2f (core hours %.2f) ; mean bar range FTMO %.2f vs IC %.2f pips"
      % (fb["sp"][m].mean() / PIP, fb["sp"][m][fcore].mean() / PIP, ((fb["h"] - fb["l"])[m]).mean() / PIP, ((b["h"] - b["l"])).mean() / PIP))
    P()
open(os.path.join(OUT, "05_ticks_inventory.txt"), "w").write("\n".join(L) + "\n")
