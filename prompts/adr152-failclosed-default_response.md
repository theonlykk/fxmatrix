This message has a line count at the bottom

Branch: fix/adr152-failclosed-default (from origin/main at 52f6870)
Commits: 9063ac3 (code and presets), e20411a (ADR text)
Not merged. Branch pushed.

SELF-REVIEW

ea/fxgrind.mq5 lines 23 and 24 (exact):

input bool   InpFillTimePlace      = false;   // D1 kill switch, preset opts in
input int    InpSlotNearReserve    = 0;       // preset opts in; Q = GRIND_SLOT_NEAR_RESERVE

git diff --stat origin/main...fix/adr152-failclosed-default (raw):

 docs/architecture/ADR-152-entry-purgatory.md | 18 ++++++++++++++++--
 ea/fxgrind.mq5                               |  4 ++--
 ea/presets/gbpusd_alt.set                    |  2 ++
 ea/presets/gbpusd_opt.set                    |  2 ++
 4 files changed, 22 insertions(+), 4 deletions(-)

Files changed: exactly 4 (fxgrind.mq5, gbpusd_opt.set, gbpusd_alt.set,
ADR-152-entry-purgatory.md). No other tracked files modified on the branch.

Suite figure observed (headless fxgrind_tests run after compile, terminal64
stopped for the run, log 20260918.log 00:30:16): SUMMARY: 1178/1178 passed

Line-ending checks:
- gbpusd_opt.set and gbpusd_alt.set: LF only (no CR bytes on disk or in git blob)
- fxgrind.mq5: unchanged line-ending style vs origin/main (LF)

Preset insertions: InpFillTimePlace=true and InpSlotNearReserve=8 immediately
after InpEnableCarryPass=false in both GBPUSD presets only. Other 16 presets
untouched.

Anything else changed: nothing beyond the four files above and this response
file (committed separately on the branch).

Line count: 39
