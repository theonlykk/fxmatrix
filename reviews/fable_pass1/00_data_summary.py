"""Data inventory for the bars: range, counts, gaps, spread field by hour. Output: out/00_data_summary.txt"""
from common import *
import sys
lines = []
P = lambda s="": (lines.append(s), print(s))
for pair in PAIRS:
    P(bar_header(pair))
    b = load_bars(pair)
    t = b["t"]
    dt = pd.to_datetime(t, unit="s")
    P("%s bars=%d first=%s last=%s weekday_bars=%d weekend_bars=%d" % (pair, len(t), dt[0], dt[-1],
      weekday_mask(t).sum(), (~weekday_mask(t)).sum()))
    gaps = np.diff(t)
    P("  gaps: >5min=%d >60min=%d >1day=%d ; time not increasing=%d" % ((gaps > 300).sum(), (gaps > 3600).sum(),
      (gaps > 86400).sum(), (gaps <= 0).sum()))
    sp = b["sp"] / PIP
    rng = (b["h"] - b["l"]) / PIP
    P("  spread pips: mean=%.2f median=%.2f p10=%.2f p90=%.2f p99=%.2f max=%.1f ; bar range pips: mean=%.2f median=%.2f p90=%.2f p99=%.2f"
      % (sp.mean(), np.median(sp), np.percentile(sp, 10), np.percentile(sp, 90), np.percentile(sp, 99), sp.max(),
         rng.mean(), np.median(rng), np.percentile(rng, 90), np.percentile(rng, 99)))
    bad = ((b["h"] < b["l"]) | (b["o"] > b["h"] + 1e-9) | (b["o"] < b["l"] - 1e-9) | (b["c"] > b["h"] + 1e-9) | (b["c"] < b["l"] - 1e-9)).sum()
    P("  ohlc inconsistent bars=%d ; zero-spread bars=%d" % (bad, (b["sp"] <= 0).sum()))
    hr = dt.hour.values
    yr = dt.year.values
    P("  median spread (pips) by server hour: " + " ".join("%d:%.1f" % (h, np.median(sp[hr == h])) for h in range(24)))
    P("  mean   spread (pips) by server hour: " + " ".join("%d:%.1f" % (h, sp[hr == h].mean()) for h in range(24)))
    P("  by year: " + " | ".join("%d bars=%d med_sp=%.2f mean_sp=%.2f mean_rng=%.2f" % (y, (yr == y).sum(), np.median(sp[yr == y]),
      sp[yr == y].mean(), rng[yr == y].mean()) for y in sorted(set(yr))))
    # daily close-to-close sigma (pips) from last bar of each server day
    day = t // 86400
    last = np.r_[np.nonzero(np.diff(day))[0], len(t) - 1]
    dc = b["c"][last]
    P("  daily sigma (pips, close-to-close of server days): %.1f ; days=%d" % (np.std(np.diff(dc)) / PIP, len(dc)))
    P()
open(os.path.join(OUT, "00_data_summary.txt"), "w").write("\n".join(lines) + "\n")
