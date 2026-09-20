This message has a line count at the bottom

# Geometry cycle 2 -- preset response

Branch: feat/geometry-cycle2 from origin/main.
Scope: InpAddPips / InpExitPips only in ea/presets/*.set (12 files).

## Self-review

InpWidthPips unchanged in all 16 fleet presets (and NZDCHF pair untouched).
Controls with zero diff: audcad_opt, eurgbp_opt, gbpusd_opt, nzdcad_alt.

git diff --stat origin/main...feat/geometry-cycle2:

 ea/presets/audcad_alt.set | 2 +-
 ea/presets/audchf_alt.set | 2 +-
 ea/presets/audchf_opt.set | 2 +-
 ea/presets/audnzd_alt.set | 2 +-
 ea/presets/audnzd_opt.set | 2 +-
 ea/presets/cadchf_alt.set | 2 +-
 ea/presets/cadchf_opt.set | 2 +-
 ea/presets/eurgbp_alt.set | 2 +-
 ea/presets/eurusd_alt.set | 2 +-
 ea/presets/eurusd_opt.set | 2 +-
 ea/presets/gbpusd_alt.set | 2 +-
 ea/presets/nzdcad_opt.set | 2 +-
 12 files changed, 12 insertions(+), 12 deletions(-)

Full diff (12 lines changed):

diff --git a/ea/presets/audcad_alt.set b/ea/presets/audcad_alt.set
--- a/ea/presets/audcad_alt.set
+++ b/ea/presets/audcad_alt.set
-InpExitPips=10.0
+InpExitPips=7.0
diff --git a/ea/presets/audchf_alt.set b/ea/presets/audchf_alt.set
--- a/ea/presets/audchf_alt.set
+++ b/ea/presets/audchf_alt.set
-InpExitPips=10.0
+InpExitPips=7.0
diff --git a/ea/presets/audchf_opt.set b/ea/presets/audchf_opt.set
--- a/ea/presets/audchf_opt.set
+++ b/ea/presets/audchf_opt.set
-InpAddPips=10.0
+InpAddPips=7.0
diff --git a/ea/presets/audnzd_alt.set b/ea/presets/audnzd_alt.set
--- a/ea/presets/audnzd_alt.set
+++ b/ea/presets/audnzd_alt.set
-InpAddPips=14.0
+InpAddPips=10.0
diff --git a/ea/presets/audnzd_opt.set b/ea/presets/audnzd_opt.set
--- a/ea/presets/audnzd_opt.set
+++ b/ea/presets/audnzd_opt.set
-InpAddPips=14.0
+InpAddPips=7.0
diff --git a/ea/presets/cadchf_alt.set b/ea/presets/cadchf_alt.set
--- a/ea/presets/cadchf_alt.set
+++ b/ea/presets/cadchf_alt.set
-InpExitPips=10.0
+InpExitPips=7.0
diff --git a/ea/presets/cadchf_opt.set b/ea/presets/cadchf_opt.set
--- a/ea/presets/cadchf_opt.set
+++ b/ea/presets/cadchf_opt.set
-InpAddPips=10.0
+InpAddPips=7.0
diff --git a/ea/presets/eurgbp_alt.set b/ea/presets/eurgbp_alt.set
--- a/ea/presets/eurgbp_alt.set
+++ b/ea/presets/eurgbp_alt.set
-InpExitPips=8.0
+InpExitPips=6.0
diff --git a/ea/presets/eurusd_alt.set b/ea/presets/eurusd_alt.set
--- a/ea/presets/eurusd_alt.set
+++ b/ea/presets/eurusd_alt.set
-InpExitPips=10.0
+InpExitPips=7.0
diff --git a/ea/presets/eurusd_opt.set b/ea/presets/eurusd_opt.set
--- a/ea/presets/eurusd_opt.set
+++ b/ea/presets/eurusd_opt.set
-InpExitPips=7.0
+InpExitPips=5.0
diff --git a/ea/presets/gbpusd_alt.set b/ea/presets/gbpusd_alt.set
--- a/ea/presets/gbpusd_alt.set
+++ b/ea/presets/gbpusd_alt.set
-InpAddPips=10.0
+InpAddPips=14.0
diff --git a/ea/presets/nzdcad_opt.set b/ea/presets/nzdcad_opt.set
--- a/ea/presets/nzdcad_opt.set
+++ b/ea/presets/nzdcad_opt.set
-InpAddPips=10.0
+InpAddPips=7.0

Changed lines summary:

    audcad_alt.set:  InpExitPips 10.0 -> 7.0
    audchf_alt.set:  InpExitPips 10.0 -> 7.0
    audchf_opt.set:  InpAddPips 10.0 -> 7.0
    audnzd_alt.set:  InpAddPips 14.0 -> 10.0
    audnzd_opt.set:  InpAddPips 14.0 -> 7.0
    cadchf_alt.set:  InpExitPips 10.0 -> 7.0
    cadchf_opt.set:  InpAddPips 10.0 -> 7.0
    eurgbp_alt.set:  InpExitPips 8.0 -> 6.0
    eurusd_alt.set:  InpExitPips 10.0 -> 7.0
    eurusd_opt.set:  InpExitPips 7.0 -> 5.0
    gbpusd_alt.set:  InpAddPips 10.0 -> 14.0
    nzdcad_opt.set:  InpAddPips 10.0 -> 7.0

## Old / new table (all 16 active presets)

| file | InpAddPips old -> new | InpExitPips old -> new | changed |
|---|---|---|---|
| audnzd_opt.set | 14.0 -> 7.0 | 5.0 -> 5.0 | add |
| audnzd_alt.set | 14.0 -> 10.0 | 7.0 -> 7.0 | add |
| nzdcad_opt.set | 10.0 -> 7.0 | 5.0 -> 5.0 | add |
| nzdcad_alt.set | 10.0 -> 10.0 | 7.0 -> 7.0 | control |
| audchf_opt.set | 10.0 -> 7.0 | 5.0 -> 5.0 | add |
| audchf_alt.set | 10.0 -> 10.0 | 10.0 -> 7.0 | exit |
| cadchf_opt.set | 10.0 -> 7.0 | 5.0 -> 5.0 | add |
| cadchf_alt.set | 10.0 -> 10.0 | 10.0 -> 7.0 | exit |
| audcad_opt.set | 10.0 -> 10.0 | 5.0 -> 5.0 | control |
| audcad_alt.set | 10.0 -> 10.0 | 10.0 -> 7.0 | exit |
| eurgbp_opt.set | 6.0 -> 6.0 | 5.0 -> 5.0 | control |
| eurgbp_alt.set | 6.0 -> 6.0 | 8.0 -> 6.0 | exit |
| eurusd_opt.set | 14.0 -> 14.0 | 7.0 -> 5.0 | exit |
| eurusd_alt.set | 14.0 -> 14.0 | 10.0 -> 7.0 | exit |
| gbpusd_opt.set | 10.0 -> 10.0 | 7.0 -> 7.0 | control |
| gbpusd_alt.set | 10.0 -> 14.0 | 10.0 -> 10.0 | add |

NZDCHF presets not modified.

Line count: 130
