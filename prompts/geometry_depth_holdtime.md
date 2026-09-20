This message has a line count at the bottom

# Geometry: ladder depth and hold time (deals dump)

Window 2026-09-10 10:50:32 to 2026-09-18 23:50:02 (2716 deals). Nine days, guard-saturated regime; depth readings are guard-affected more than hold time. Deeper stacking (mean_depth roughly 2.5+): GBPUSD/ALT, GBPUSD/OPT, EURGBP/OPT, EURUSD/OPT, EURGBP/ALT, EURUSD/ALT. Shallow ladders (mean_depth roughly 1.2 or below): AUDNZD/OPT, NZDCAD/ALT, AUDNZD/ALT. Fast median holds under 5 min suggest tight exit_pips; slow or censored medians (2h+ or inf): GBPUSD/ALT, EURUSD/OPT, EURUSD/ALT, EURGBP/OPT, EURGBP/ALT, AUDCAD/OPT. No parameter recommendations here -- numbers only.

## Method

ENT/EXT on the same position_id: zero rows in this dump. Scalp hold pairs inventory ENT to EXT leg via CloseBy (#ent by #ext); exit time is EXT deal time. CloseBy without EXT: reported separately.

## Limits

Single regime week; fleet guard-saturated (suppresses entries). Positions closed before first dump row without ENT: 0 ent legs excluded. CloseBy events without EXT leg in pair: 0 (none in this dump if zero).

## Measurement 1 -- ladder depth

### AUDCAD ALT L (n=27 mean_depth=0.926 pct_at_cap=0.00 pct_shallow=74.07 max=3)
  L0=10 L1=10 L2=6 L3=1

### AUDCAD ALT S (n=24 mean_depth=2.917 pct_at_cap=8.33 pct_shallow=33.33 max=7)
  L0=5 L1=3 L2=3 L3=4 L4=3 L5=1 L6=3 L7=2

### AUDCAD OPT L (n=40 mean_depth=1.050 pct_at_cap=0.00 pct_shallow=72.50 max=3)
  L0=14 L1=15 L2=6 L3=5

### AUDCAD OPT S (n=41 mean_depth=3.000 pct_at_cap=7.32 pct_shallow=34.15 max=7)
  L0=9 L1=5 L2=3 L3=6 L4=4 L5=9 L6=2 L7=3

### AUDCHF ALT L (n=14 mean_depth=0.786 pct_at_cap=0.00 pct_shallow=78.57 max=3)
  L0=7 L1=4 L2=2 L3=1

### AUDCHF ALT S (n=16 mean_depth=2.438 pct_at_cap=0.00 pct_shallow=25.00 max=4)
  L0=1 L1=3 L2=2 L3=8 L4=2

### AUDCHF OPT L (n=20 mean_depth=0.850 pct_at_cap=0.00 pct_shallow=75.00 max=3)
  L0=9 L1=6 L2=4 L3=1

### AUDCHF OPT S (n=28 mean_depth=1.750 pct_at_cap=0.00 pct_shallow=50.00 max=5)
  L0=9 L1=5 L2=4 L3=5 L4=4 L5=1

### AUDNZD ALT L (n=13 mean_depth=0.846 pct_at_cap=0.00 pct_shallow=84.62 max=2)
  L0=4 L1=7 L2=2

### AUDNZD ALT S (n=15 mean_depth=1.133 pct_at_cap=0.00 pct_shallow=60.00 max=4)
  L0=8 L1=1 L2=3 L3=2 L4=1

### AUDNZD OPT L (n=16 mean_depth=0.750 pct_at_cap=0.00 pct_shallow=87.50 max=2)
  L0=6 L1=8 L2=2

### AUDNZD OPT S (n=17 mean_depth=0.647 pct_at_cap=0.00 pct_shallow=88.24 max=3)
  L0=9 L1=6 L2=1 L3=1

### CADCHF ALT L (n=10 mean_depth=1.500 pct_at_cap=0.00 pct_shallow=50.00 max=3)
  L0=2 L1=3 L2=3 L3=2

### CADCHF ALT S (n=8 mean_depth=1.375 pct_at_cap=0.00 pct_shallow=50.00 max=3)
  L0=3 L1=1 L2=2 L3=2

### CADCHF OPT L (n=17 mean_depth=1.353 pct_at_cap=0.00 pct_shallow=47.06 max=3)
  L0=4 L1=4 L2=8 L3=1

### CADCHF OPT S (n=15 mean_depth=1.400 pct_at_cap=0.00 pct_shallow=46.67 max=3)
  L0=3 L1=4 L2=7 L3=1

### EURGBP ALT L (n=19 mean_depth=2.737 pct_at_cap=5.26 pct_shallow=31.58 max=7)
  L0=4 L1=2 L2=3 L3=3 L4=3 L5=2 L6=1 L7=1

### EURGBP ALT S (n=16 mean_depth=2.562 pct_at_cap=6.25 pct_shallow=43.75 max=7)
  L0=5 L1=2 L2=1 L3=2 L4=2 L5=2 L6=1 L7=1

### EURGBP OPT L (n=29 mean_depth=2.966 pct_at_cap=3.45 pct_shallow=27.59 max=7)
  L0=4 L1=4 L2=7 L3=3 L4=2 L5=4 L6=4 L7=1

### EURGBP OPT S (n=30 mean_depth=2.667 pct_at_cap=6.67 pct_shallow=43.33 max=7)
  L0=6 L1=7 L2=2 L3=4 L4=3 L5=5 L6=1 L7=2

### EURUSD ALT L (n=24 mean_depth=4.125 pct_at_cap=37.50 pct_shallow=20.83 max=8)
  L0=4 L1=1 L2=2 L3=5 L4=1 L5=1 L6=1 L7=8 L8=1

### EURUSD ALT S (n=20 mean_depth=0.700 pct_at_cap=0.00 pct_shallow=85.00 max=2)
  L0=9 L1=8 L2=3

### EURUSD OPT L (n=32 mean_depth=4.438 pct_at_cap=34.38 pct_shallow=15.62 max=8)
  L0=4 L1=1 L2=2 L3=8 L4=1 L5=2 L6=3 L7=7 L8=4

### EURUSD OPT S (n=25 mean_depth=0.400 pct_at_cap=0.00 pct_shallow=92.00 max=2)
  L0=17 L1=6 L2=2

### GBPUSD ALT L (n=51 mean_depth=6.980 pct_at_cap=49.02 pct_shallow=15.69 max=15)
  L0=6 L1=2 L2=3 L3=5 L4=6 L5=1 L6=3 L7=3 L8=1 L9=2 L10=1 L11=4 L12=6 L13=2 L14=3 L15=3

### GBPUSD ALT S (n=52 mean_depth=1.173 pct_at_cap=0.00 pct_shallow=65.38 max=5)
  L0=21 L1=13 L2=10 L3=5 L4=2 L5=1

### GBPUSD OPT L (n=52 mean_depth=6.692 pct_at_cap=46.15 pct_shallow=9.62 max=14)
  L0=4 L1=1 L2=3 L3=7 L4=6 L5=6 L6=1 L7=2 L8=1 L9=3 L10=7 L11=2 L12=2 L13=3 L14=4

### GBPUSD OPT S (n=57 mean_depth=0.930 pct_at_cap=0.00 pct_shallow=71.93 max=4)
  L0=27 L1=14 L2=11 L3=3 L4=2

### NZDCAD ALT L (n=11 mean_depth=1.091 pct_at_cap=0.00 pct_shallow=63.64 max=3)
  L0=5 L1=2 L2=2 L3=2

### NZDCAD ALT S (n=13 mean_depth=0.769 pct_at_cap=0.00 pct_shallow=76.92 max=2)
  L0=6 L1=4 L2=3

### NZDCAD OPT L (n=19 mean_depth=1.579 pct_at_cap=0.00 pct_shallow=42.11 max=4)
  L0=4 L1=4 L2=8 L3=2 L4=1

### NZDCAD OPT S (n=22 mean_depth=1.636 pct_at_cap=0.00 pct_shallow=45.45 max=4)
  L0=4 L1=6 L2=8 L3=2 L4=2

## Measurement 2 -- hold time (EXT scalp via CloseBy)

Hold quantiles include unclosed entries as inf. net_per_scalp uses closed positions only (both legs summed).

GBPUSD OPT: entries=109 scalp_paired=84 never_exited_pct=22.94 q25=18.07 med=117.4 q75=1195.02 p90=nan min
GBPUSD ALT: entries=103 scalp_paired=81 never_exited_pct=21.36 q25=37.86 med=193.9 q75=917.5 p90=nan min
EURUSD OPT: entries=57 scalp_paired=44 never_exited_pct=22.81 q25=51.48 med=251.9 q75=1761.15 p90=nan min
EURUSD ALT: entries=44 scalp_paired=33 never_exited_pct=25.00 q25=64.98 med=347.7 q75=inf p90=nan min
EURGBP OPT: entries=59 scalp_paired=51 never_exited_pct=13.56 q25=58.6 med=275.9 q75=1666.93 p90=nan min
EURGBP ALT: entries=35 scalp_paired=26 never_exited_pct=25.71 q25=436.1 med=1702.57 q75=nan p90=nan min
AUDCAD OPT: entries=81 scalp_paired=68 never_exited_pct=16.05 q25=29.58 med=131.4 q75=727.5 p90=nan min
AUDCAD ALT: entries=51 scalp_paired=39 never_exited_pct=23.53 q25=69.81 med=614.4 q75=2112.45 p90=nan min
AUDCHF OPT: entries=48 scalp_paired=33 never_exited_pct=31.25 q25=103.9 med=694.7 q75=nan p90=nan min
AUDCHF ALT: entries=30 scalp_paired=19 never_exited_pct=36.67 q25=771.5 med=3494.61 q75=nan p90=nan min
CADCHF OPT: entries=32 scalp_paired=25 never_exited_pct=21.88 q25=52.67 med=396.2 q75=2970.72 p90=nan min
CADCHF ALT: entries=18 scalp_paired=12 never_exited_pct=33.33 q25=668.7 med=2115.43 q75=nan p90=nan min
NZDCAD OPT: entries=41 scalp_paired=34 never_exited_pct=17.07 q25=69.65 med=156 q75=792.3 p90=nan min
NZDCAD ALT: entries=24 scalp_paired=17 never_exited_pct=29.17 q25=131.4 med=320 q75=nan p90=nan min
AUDNZD OPT: entries=33 scalp_paired=25 never_exited_pct=24.24 q25=48.82 med=153 q75=nan p90=nan min
AUDNZD ALT: entries=28 scalp_paired=21 never_exited_pct=25.00 q25=52.7 med=142.1 q75=inf p90=nan min

## Cross-cut

| symbol | arm | add_pips | exit_pips | mean_depth | pct_at_cap | median_hold_min | scalps | net_per_scalp |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GBPUSD | OPT | 10 | 7 | 3.679 | 22.02 | 117.4 | 84 | 0.6457 |
| GBPUSD | ALT | 10 | 10 | 4.049 | 24.27 | 193.9 | 81 | 0.9578 |
| EURUSD | OPT | 14 | 7 | 2.667 | 19.30 | 251.9 | 44 | 0.6305 |
| EURUSD | ALT | 14 | 10 | 2.568 | 20.45 | 347.7 | 33 | 0.9367 |
| EURGBP | OPT | 6 | 5 | 2.814 | 5.08 | 275.9 | 51 | 0.5488 |
| EURGBP | ALT | 6 | 8 | 2.657 | 5.71 | 1702.57 | 26 | 0.8746 |
| AUDCAD | OPT | 10 | 5 | 2.037 | 3.70 | 131.4 | 68 | 0.2984 |
| AUDCAD | ALT | 10 | 10 | 1.863 | 3.92 | 614.4 | 39 | 0.6467 |
| AUDCHF | OPT | 10 | 5 | 1.375 | 0.00 | 694.7 | 33 | 0.5361 |
| AUDCHF | ALT | 10 | 10 | 1.667 | 0.00 | 3494.61 | 19 | 1.134 |
| CADCHF | OPT | 10 | 5 | 1.375 | 0.00 | 396.2 | 25 | 0.5224 |
| CADCHF | ALT | 10 | 10 | 1.444 | 0.00 | 2115.43 | 12 | 1.102 |
| NZDCAD | OPT | 10 | 5 | 1.610 | 0.00 | 156 | 34 | 0.3024 |
| NZDCAD | ALT | 10 | 7 | 0.917 | 0.00 | 320 | 17 | 0.4394 |
| AUDNZD | OPT | 14 | 5 | 0.697 | 0.00 | 153 | 25 | 0.2072 |
| AUDNZD | ALT | 14 | 7 | 1.000 | 0.00 | 142.1 | 21 | 0.3438 |

Line count: 155
