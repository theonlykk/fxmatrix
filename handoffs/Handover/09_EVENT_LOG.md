This message has a line count at the bottom

# EVENT LOG -- NOTABLE MARKET AND OPERATIONAL EVENTS

What happened, what it did to the fleet, how it was handled, what
changed because of it. Brief on purpose: the evidence column points at
the full record. Newest first. Times UTC. Add an entry for any event
that halts an instance, moves a book by more than a few layers in
minutes, touches an account limit, or needed a manual action.

Fleets: A = cycle 3 (FTMO, VPS), B = box 1 (IC), C = box 2 (IC), D =
wine-d (IC, from 1 Oct). Cycle 2
= the previous FTMO account (1514582088, ended 23 Sep).

---

### 5 Oct 22:20-23:21Z -- the Monday build: six IC twins closed by hand, B, C, D to `main`, re-roll ON (B, C, D)
- **What:** a structural change on all three IC fleets (C95, C96): the
  twins (NZDCAD and AUDNZD ALT) removed (deinit 1) and their books closed
  by hand (orders deleted entries first, Close By, the rest at market:
  about -$34 D, -$45 C, -$44 B, outside the EA's realised P&L); repo to
  `main` (EA code `2859be6`), one compile per box (wine-c its Scripts
  copy, C88), `InpLatticeReroll=true` by F7 on all 27 charts.
- **Handled:** per box the log checker (9 x `deinit=2`, then 9 x
  `deinit=5 reroll=true`, BAD 0) and the archive build stamp. Re-rolls on
  the fully rolled sides at once (EURUSD L C 9, EURGBP L B 10, others 2-4),
  their old layers realising within the hour (C: Rolls 9, -$65).
- **Changed:** nine instances per IC fleet; capped sides re-roll instead
  of stranding; no account-level backstop on B, C, D. pipshed C119.
- **Evidence:** HANDOFF s58; register rows closed.

### 5 Oct (email 10:23 ET, read ~21:00Z) -- FTMO's reply on the request count (A)
- **What:** FTMO answered the operator's Friday email about last week: a
  day's requests had slightly exceeded 2,000; keep under the limit (the
  email asks not to be shared: summarised here).
- **Handled:** no reply (no broker contact); A at seven instances ran 960
  requests to 20:27Z.
- **Changed:** A's `api_count` read in every status read (bring >~1,600);
  C106.
- **Evidence:** HANDOFF s58.

### 5 Oct 13:41-13:52Z -- FTMO GRIND_GBPUSD_OPT halted AMBIGUOUS_ADD_SHORT (A)
- **What:** the collector read one resting short add twice while
  CADCHF's instance cancelled an order in the same millisecond
  (13:41:07.517Z); the halt cancelled GBPUSD's entries (one short add
  #556944887 at 1.32088, one long entry #556941823 at 1.31903). The
  second C93 halt on FTMO (AUDNZD 1 Oct).
- **Handled:** VPS Journal grep (one short add; no GBPUSD deal during
  the halt), then F7 restart with ` x` at 13:52:12Z: `deinit reason=5`,
  CONFIG unchanged, entries re-placed at the same prices by 13:52:15Z.
- **Changed:** nothing in code; v2.2a (C93) is built, not merged, not
  on the VPS; a C93-only FTMO hotfix is the operator's call (C93).
- **Evidence:** HANDOFF s57; 02_TRAPS 5 Oct day.

### 3 Oct (afternoon, before ~17:00Z) -- FTMO VPS: 43 retired Global Variables deleted by exact name (A)
- **What:** the VPS terminal held 159 GRIND Global Variables; 43 belonged
  to the four instances retired on 2 Oct (32 retired-magic records, 11
  carry records of closed retired positions). A manual change on the
  live terminal.
- **Handled:** `scripts/grind_gv_list.mq5` (read-only) listed them;
  Claude classified each against the live magics and the deal history;
  `scripts/grind_gv_delete_exact.mq5` on the reviewed list: dry run 43/43
  found, then 43 deleted, 0 failed; re-list 116. No trading change.
- **Changed:** C107 done; the same method for the IC twins after the
  Monday build (runbook monday-build s7).
- **Evidence:** HANDOFF s42; 02_TRAPS 3 Oct afternoon (C93, C107).

### 2 Oct ~16:18-17:36Z -- pipshed.com saturated by its own page reads; C110
- **What:** from ~16:18Z (the C109 deploy) pipshed.com's CPU sat at ~4-4.5
  vCPU (all four gunicorn workers busy) and memory rose 0.6 -> 1.6 GB; from
  ~16:30Z about half the requests were 4xx and the total halved. Railway's
  Network Logs: EA pushes 499 (client gone) after ~1 s, page calls
  (`fleets`, `ejection`, `today_scalps`, `scalps`, `aggregate`) 19 s to
  2 min. No `WORKER TIMEOUT`. Closing the operator's tabs changed nothing:
  the paths' `Date.now()` suffix showed a page still polling (17:10Z,
  17:12Z, 17:14Z); the device was never found (the Claude app's browser
  pane was closed). Live states stayed fresh on all four fleets throughout
  (B 16:45Z, FTMO AUDCHF 16:47Z, C 16:49Z, D 16:48Z).
- **Cause:** every read of a scalp list parsed ALL of it (`lrange 0 -1`,
  `json.loads` per row; up to 3,000 rows per instance). Per page and 30 s
  the fleet strip parsed every instance of all four fleets twice (today and
  cycle), `today_scalps` and `scalps` parsed A's ids again, and the 5-s
  daily summary once more. In process with full lists: one strip call read
  81 MB from Redis (~1.2 s CPU), the daily summary 18 MB. The lists grew
  with the lattice's scalp volume until one open page saturated four cores.
- **Handled:** pipshed C110 (`8dcb60b` tests, `830f04b` fix, tree
  `b52cbbf2`, pushed ~17:35Z): one reader re-reads only new rows (warm
  strip call 0.4 MB, ~0.2 s CPU); all 13 page pollers skip a tick while
  their previous call runs. 35/35 suites. 17:39Z: strip answers at once,
  A 7/7, B/C/D 11/11 LIVE.
- **Changed:** C102 (the strip's cost) largely answered; C111 (cycle totals
  short once a list holds 3,000 rows); C112 (the EA drops an archive batch
  answered 400: check whether any rows were lost on 2 Oct).
- **Evidence:** Railway Metrics and Network Logs (screenshots in chat);
  pipshed `verify_c110_scalp_reads`; HANDOFF s36.

### 2 Oct ~15:50-16:18Z -- pipshed after the retirements: red banner, CONNECTION LOST badge
- **What:** after the cut to seven, Fleet A's card read PARTIAL 7/11;
  the critical banner stayed red over AUDCAD_OPT's 1 Oct INVARIANT_FAIL
  (a retired instance never "runs again", so the row never resolved);
  the pipshed.com badge read CONNECTION LOST with every card LIVE: the
  page opened on the first id of the rings JSON, which tojson sorts, so
  `aud_cad_chf` came first and the page polled retired AUDCAD_OPT.
- **Handled:** three pipshed changes, tests first, each pushed by the
  operator: C107 (A strip = seven, `94c7630`), C108 (every row of a
  retired instance shows "resolved: instance retired", `00a89ad`),
  C109 (the page opens on the fleet's default, GBPUSD, `0fd1a86`).
  Checked on pipshed.com 16:18Z: card LIVE 7/7, banner grey, badge Live.
- **Changed:** retiring an instance now needs its id added to
  pipshed's `GRIND_RETIRED_INSTANCES` and removed from the A strip.
- **Evidence:** pipshed `verify_c108_retired_critical`,
  `verify_c109_default_instance`; HANDOFF s34.

### 2 Oct ~15:00-15:45Z -- FTMO hyperactivity warning; cycle 3 cut from 11 to 7 instances
- **What:** FTMO email: "a high degree of hyperactivity" on 1514731800;
  threshold "2000 trades or server requests including SL/TP
  modifications, order cancellations etc., per day"; if alerts do not
  decrease "within the following days" the account is disabled. VPS
  Journal: ~2 lines per request (sent + accepted); ~1,300-1,500 requests
  00:00-15:08Z today (limits 646, cancels 292, close-bys ~175, modifies
  ~200+), close to our counter; the 1900 entry stop never bounded exits,
  cancels, close-bys or modifies.
- **Handled:** operator: fewer instances, not a lower stop. Retired by
  hand (EA removed, orders deleted entries first, Close By, market):
  AUDNZD_ALT and NZDCAD_ALT (15:14Z, ~-$21.60), then AUDCAD_OPT and
  NZDCHF_OPT for the seven-pair ring (~15:40Z, ~-$15.80). Seven live:
  EURUSD, GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD. Reply sent to
  FTMO (instruments and EAs reduced; within the limit; monitoring).
- **Changed:** geometry-cycle3 A7; register rows closed; C96 (FTMO ring),
  C106 (FTMO request budget), C107 (pipshed A list, retired GVs).
- **Evidence:** VPS Journal 20261002; HANDOFF s33.

### 2 Oct 14:16-14:55Z -- API entry stop raised on all four fleets (hotfix)
- **What:** Fleet D's shared request count was 1670 at 14:02Z (C 1403, B
  1261, FTMO 1231); at 1900 the EA's own constant stops every new entry
  on that fleet until the 21:00Z reset (FTMO reached 1881 on 1 Oct).
- **Handled:** operator: "i do not want an api limit to stop trading".
  `GRIND_DAILY_API_ENTRY_STOP` 1900 -> 1000000, `GRIND_DAILY_API_SOFT_WARN`
  1800 -> 999000. IC `893e065` on `0335f25` (suite 2368/2368): wine-d
  14:16:00Z, wine-c 14:19:14Z, wine-test 14:20:54Z. FTMO `aa6970a` on
  `5685e4f` (suite 1887/1887): VPS 14:55:06Z, tag `vps-aa6970a`. Every
  box 11/11 re-init, inputs kept, FATAL 0.
- **Changed:** C100 hotfixed (input still v2.2); C105 (merge into main).
- **Evidence:** fleet-d.md s7; HANDOFF s32.

### 2 Oct ~10:00-14:27Z -- pipshed.com overloaded, then down; moved to gunicorn
- **What:** the web service ran Flask's dev server. EA posts started
  timing out (200 ms) ~10:00Z; down from 12:14Z (`can't start new
  thread`, 6.5 GB, 1 vCPU pinned, mostly 4xx). Cards and strip blind;
  trading unaffected; archive rows held in the EAs' queues (no drops).
- **Handled:** restart 14:00Z (relapsed ~10 min); start command changed
  to gunicorn (4 workers x 8 threads) ~14:27Z: backlog drained, all 2xx,
  memory flat.
- **Changed:** C102 (commit the start command; page services).
- **Evidence:** Railway metrics and deploy logs (screenshots in chat);
  wine-test log: POST ok per hour 650-740 overnight, 373 at 10h, 159 at
  11h, 1 at 12h.

### 2 Oct 03:41-03:52Z -- AUDCHF long stuck at cap on C; hand eject
- **What:** AUDCHF C (add probe, add 3): all eight layers rolled, ask
  0.57509 past its next level 0.57527 (status 03:41:41Z).
- **Handled:** operator: eject. `GRIND_EJECT_22260501` = 1978509127 (L10)
  over VNC (typed: VNC paste does not reach MT5); accepted 03:51:45Z,
  filled 03:52:31Z (~-$6.80).
- **Changed:** nothing; fleet-d.md s7. Close behind at 03:41Z: NZDCHF D
  (~6 pips), NZDCHF C (~8.5), AUDCHF B (~10).
- **Evidence:** wine-c Experts log 2 Oct.

### 2 Oct 02:55-03:05Z -- empty-side L0 re-quote tightened on the IC fleets (B, C, D)
- **What:** on a one-sided book the empty side's L0 lagged the market by
  S - W (5 pips; 7 on EURUSD, AUDNZD): e.g. EURGBP short L0 on B and C
  6.6 pips above mid at 02:19Z with the longs at cap.
- **Handled:** operator ruling ("i want to see the impact"):
  `InpStrandedThreshPips` = width + 1 by F7 on all 33 IC charts
  (wine-test 02:55:15-02:58:16Z, wine-c 03:00:14-03:01:49Z, wine-d
  03:03:03-03:04:54Z); deadband kept at 4 (request budget). Each box
  11/11 CONFIG read back, FATAL 0.
- **Changed:** 51 IC presets; the L0 now re-quotes after 4 pips of drift
  everywhere; C103 (a near-zero counter-side width needs code).
- **Evidence:** fleet-d.md s7; HANDOFF s31.

### 2 Oct 02:19-02:30Z -- NZDCHF long stuck at cap on B and C; hand ejects
- **What:** CHF strength continued after window 1 opened. NZDCHF long on
  B (rolled L10 at 22:13:44Z) and C: depth 8, all eight layers rolled,
  ask past the next level, so no roll candidate (live build `0335f25`;
  ADR-165 not deployed). D one roll left; AUDCHF C all rolled, 3.6 pips
  from its next level.
- **Handled:** operator: "lets unstick the fx pairs that are stuck".
  Commanded eject (Global Variable `GRIND_EJECT_22260701`, over VNC):
  B L01 1970247358 accepted 02:26:15Z, filled 02:26:43Z (~-$7.90); C L00
  1971349402 accepted 02:29:27Z, filled 02:30:19Z (~-$8.20). Books clean
  (no EXT position; new adds rest at the lattice).
- **Changed:** nothing in code; realised inside round 1 window 1
  (fleet-d.md s7). The case for ADR-165 (re-roll) again.
- **Evidence:** wine-test and wine-c Experts logs 2 Oct; HANDOFF s31.

### 1 Oct 21:16-21:28Z -- breaker and gate switched OFF on the IC fleets (B, C, D)
- **What:** ADR-160's entry gate had blocked every entry on B and C
  since the CHF trend (floating loss above 50% of the $500 allowance:
  B $249-278, C $240-268; book = guard, no L0s, no adds, short sides
  flat). D ($152) was trading. Round 1's first window opened 22:00Z.
- **Handled:** operator ruling ("we need to trade"; the IC demo has no
  daily limit): `InpBreakerEnable=false` by F7 on all 33 IC charts,
  wine-d, wine-c, wine-test, 21:16-21:28Z; each box 11/11 re-inits,
  FATAL 0. B 102/102 -> 123/144, C 103/103 -> 124/145 within minutes.
- **Also:** the FTMO request count reached 1881 before the reset (new
  entries stopped at 1900 by design); it reset at the first new-date
  quote (~21:10Z). FTMO day 53.8% at 21:34Z, its gate not triggered
  (floating ~$150). Rollover 21:00Z clean on all four fleets.
- **Changed:** 51 IC presets `InpBreakerEnable=false`; C100 (API entry
  stop as an input) and C101 (a side-aware gate for FTMO, v2.2) added.
- **Evidence:** fleet-d.md s7; box greps in this chat; strip 21:34Z.

### 1 Oct 17:55Z -- VPS link stalled ~20 s: three deals arrived by sync only (A)
- **What:** the VPS terminal's link to FTMO-Demo went dead ~17:55:20Z;
  MT5 declared it lost only at 17:55:41.3, re-authorised 17:55:41.7,
  synchronized 17:55:42.6. Three deals filled in the dead window and
  never raised `OnTradeTransaction` (C76; A runs `5685e4f`, without the
  ADR-164 replay): AUDCAD_OPT long L14 ENT 555146463 (17:55:20.9Z) ->
  no exit -> `I3_LONG_NAKED`, halted 17:55Z; NZDCAD_OPT and NZDCAD_ALT
  short L00 EXT 555076933 / 555075403 (17:55:22Z) -> close-bys never
  queued, both short sides stalled SILENTLY (no invariant sees it).
  AUDCAD's short L01 exit then filled during the halt (17:57:52Z,
  ignored by design). An earlier drop at 17:31:38Z (0.6 s) lost nothing.
- **Handled (operator, RDP, reattach by `InpConfigWarning` + " x"):**
  AUDCAD 18:27:48 (derived close-by S L01, `STARTUP_EXIT_SHORTFALL
  long=1`, L14 exit at 0.98625, close-by success 18:27:53); NZDCAD OPT
  18:34:22 and ALT 18:36:00 (derived close-by S L00, success). Found by
  reading every instance's newest `HEARTBEAT_BOOK` for `|EXT` positions
  (traps); all 11 books clean afterwards.
- **Also:** FTMO's daily request count 1805/2000 at 18:28Z
  (`WARN_API_SOFT_LIMIT`, the ejection-heavy day); entries stop at 1900
  by design, exits and close-bys continue; the count resets at server
  midnight (21:00Z).
- **Changed:** C97 built (pipshed `eb19e5c`: an amber `ORPHAN_EXT` on the
  fleet strip for an unpaired EXT position); the orphan check added to
  the traps. The 17:16Z "previous authorization from 64.229.9.87" was the
  desktop test terminal (logged in to FTMO), not a third party.
- **Evidence:** VPS Journal and Experts logs 1 Oct (grep in this chat);
  Trade tab screenshot.

### 1 Oct ~14:00-16:00Z -- CHF trend: seven lattice sides stranded, five unstranded by hand; FTMO AUDNZD halted twice (A, B, C, D)
- **What:** CHF rallied ~14:00-16:00Z. B, C and D rolled all eight long
  layers on AUDCHF (B, C, D), CADCHF (C) and NZDCHF (B, C, D) within ~35
  min; `ROLL_STRANDED` on AUDCHF B 14:53, AUDCHF C 14:49, CADCHF C 14:49,
  NZDCHF B 14:49, AUDCHF D 15:14, NZDCHF C 15:51, NZDCHF D 15:52Z. A (FTMO,
  ADR-157) auto-ejected 44 times on the day. A's GRIND_AUDNZD_OPT halted
  15:24Z `AMBIGUOUS_ADD_LONG` (two resting long adds; the halt cancelled
  both), then on the first restart 15:46Z `I6_SHORT_EXIT_FILL_ADVERSE`
  (short L02's BUY_LIMIT at 1.23360 filled at 1.23365 during the halt).
- **Impact (16:03Z strip):** day A -$263 (52.5%, open -$144), B -$235
  (closed +$46, open -$282), C -$241 (closed +$41, open -$283), D equity
  $9,895 (from $10,000). Day totals within ~$28 of each other: ejections
  realise now, rolls defer.
- **Handled:** commanded ejects (ADR-155) of each stranded side's most
  underwater layer via a Global Variable typed in MT5 (F3):
  NZDCHF B 15:32:38 (filled 15:33:10), AUDCHF C 15:35:29 (15:35:34), CADCHF
  C 15:37:41 (15:37:44), AUDCHF D 15:55:53 (15:55:57), AUDCHF B 15:30:40 and
  re-issued 16:00:10 (filled 16:00:13; the first exit trailed the market).
  ~$38 realised. NZDCHF C/D were all rolled but back inside their range at
  16:04Z: left. AUDNZD_OPT: restarted (reason 5, ` x`), then short L02
  closed BY its filled exit by hand, restarted 15:51:59Z: clean.
- **Changed:** operator: the lattice must never strand (ADR-165 draft,
  continuous re-roll, option B); pipshed C94 (stale `ROLL_STRANDED` greys);
  backlog C92 (I6 vs adverse limit fills), C93 (duplicate add on A), C95,
  C96 (rings of seven: too much CHF); 02_TRAPS 1 Oct afternoon.
- **Evidence:** HANDOFF s28; archive `EJECT_*`/`ROLL_*` 14:00-16:05Z.

### 1 Oct 06:19-06:50Z -- D1, the first compass round, reloaded; NZDCAD_OPTD off 8 min (C, D)
- **What:** D1 presets reloaded in session: wine-d's exit probe
  06:19-06:35Z (the first live exit rebuild, `rebuild=true/true` on all
  nine, clean), wine-c's add probe 06:45-06:50Z. At 06:24:17Z the NZDCAD
  twin's preset went onto the PRIMARY chart, which failed init
  (`DUPLICATE_MAGIC 22260802`) and was unloaded.
- **Impact:** NZDCAD_OPTD's book unmanaged 06:24:17-06:32:18Z (no fill
  missed: no shortfall at the re-attach); a red DUPLICATE_MAGIC on the
  banner for 24 h. Nothing else.
- **Handled:** re-attached with its own D0 preset (06:32:18Z, clean);
  the twin reloaded after reading its magic before Load (06:35:12Z).
- **Changed:** 02_TRAPS 1 Oct D1 (read the magic BEFORE Load); backlog
  C89 (a failed init frees the live holder's lock), C90 (pipshed).
- **Evidence:** fleet-d.md s6 and s7 record; fleet-c.md A3; register.

### 1 Oct ~04:40-05:05Z -- wine-d's X display wedged; Fleet D attached over VNC (D)
- **What:** with the operator's internet dropping, RDP to wine-d failed,
  then VNC: two stale sshd RDP tunnels held xrdp on a dead client and
  wedged the X display; a `-once` x11vnc exited after one try.
- **Impact:** the D0 attach waited ~30 min; no fleet affected (D had no
  EAs; B and C untouched).
- **Handled:** the stale sshd pids killed (X unwedged); x11vnc
  `-noipv6 -forever` on 5912; D0 attached 05:10-05:19Z, clean.
- **Changed:** 02_TRAPS 1 Oct early morning (wine-d); 06 s10.
- **Evidence:** HANDOFF s26 "FLEET D"; fleet-d.md s5.

### 1 Oct 03:20-04:20Z -- C63: `main` + lattice on wine-test and wine-c (B, C; not A)
- **What:** `main` `0335f25` (v2.1 + ADR-164 + C77) compiled and every
  chart reloaded with its `_lat` preset: wine-test 03:46:05Z / 03:51-
  04:02Z, wine-c 04:10:52Z / 04:12-04:16Z. The first live lattice; the
  first `main` on wine-test (strict start on its inherited book: clean).
- **Impact:** a restart per chart; wine-c's EAs down ~1-2 min at its MT5
  restart (04:07-04:08Z). No halt, no bad line, no rollback.
- **Handled:** wine-c's compiles of the Experts copy did not reload: its
  charts load the Scripts copy (found in the chart profiles); compiling
  `Scripts/fxmatrix/fxgrind.mq5` did. wine-test went first meanwhile.
- **Changed:** B and C roll at cap; ADR-164 live on both IC fleets (C76,
  C77); 02_TRAPS 1 Oct C63; backlog C88 (move wine-c's charts to the
  Experts copy).
- **Evidence:** both boxes' `MQL5/logs/20261001.log` (checker rows),
  `config_events`, `--codes LATTICE_CONFIG`; c63-deploy.md s12.

### 30 Sep 21:00-21:13Z -- IC's rollover held order requests (B, C; not A)
- **What:** at the 30 Sep server midnight (quarter-end and month-end,
  the triple-swap night) IC Markets answered modifies `[Market closed]`
  up to ~2m48s late or not at all: 15 requests on box 1 and 17 on box 2
  timed out at exactly 180 s (retcode 10012), at the same seconds on both
  boxes, on every pair the EAs touched (AUDNZD, NZDCAD, CADCHF, NZDCHF,
  AUDCHF). Before it, 23:50-23:53 server, IC had no AUDNZD quotes (10021:
  the carry pass's "failed" on C's AUDNZD). FTMO over the same window:
  every request ok, slowest 1.5 s.
- **Impact:** none seen: no halt, no CRITICAL, carry pass 33/33. Each
  timeout blocked that EA's thread for 3 minutes.
- **Handled:** measured, not acted on. The wine-c journal shows no
  disconnect (broker-side; Wine not excluded without an IC account on
  Windows). Over 7 nights it happened once; every other IC night rejects
  fast at the documented 23:59-00:01 break.
- **Changed:** backlog C87 (measure, then an IC rollover quiet window,
  default OFF, Gemini); 02_TRAPS 1 Oct early.
- **Evidence:** pipshed `send_logs` (AUDNZD on A, B, C; the all-instance
  count by retcode), wine-c `logs/20260930.log`; HANDOFF s25.

### 30 Sep 01:47Z -- AUD cluster: four ejections in 7 seconds (B, C; not A)
- **What:** 01:46:58-01:47:05Z four AUD sides on box 1 reached cap and
  auto-ejected (`AUDNZD_ALTB`, `AUDNZD_OPTB`, `AUDCAD_OPTB`,
  `AUDCHF_OPTB`); two more 02:22-02:24Z (`AUDNZD_OPTB`, `AUDCHF_OPTB`).
  Fleet C: the same pairs and counts (AUDNZD 3, AUDCAD 1, AUDCHF 2).
  Fleet A: one AUDCHF ejection, none on AUDNZD. Likely an Australian
  data release (operator; calendar not checked). The same-second timing
  is partly the trigger's clock: ADR-157's S1 flips on an M1 boundary, so
  sides capped in one move come due together (ejections land at :57-:00
  s on every fleet).
- **Impact:** ejections cost B $23.51, C $22.83; the broker day's closed
  net stayed positive on all three (03:46Z: A +27.66, B +11.87, C
  +13.38) and every fleet's equity is above its start.
- **Handled:** no action.
- **Changed:** a named case for Thursday's study interim: the depth of
  every AUD side on A, B and C just before 01:46Z. `AUDNZD_ALTB` runs A's
  exact AUDNZD geometry (7/10/10, cap 8) and still ejected, so the B1
  dial alone does not explain the contrast: book depth going in, or
  FTMO's prices never reaching the levels. Live example of `k` and the
  worst cluster (`grid-thesis.md` s4, M2).
- **Evidence:** pipshed `/ejection` (box 1 host, 8 h) and fleet cards,
  30 Sep 03:46Z.

### 28 Sep 16:27Z -- broker resync swallowed two fills (C, GBPUSD)
- **What:** box 2 lost the IC trade server for ~5 s. A short L05 entry
  and a long L00 exit filled in the gap and reached the terminal only by
  resync: no `OnTradeTransaction`, no archive row, no layer.
- **Impact:** GBPUSD_OPTC halted on I3 (16:27:38Z). The missed exit
  would have stalled the long side silently.
- **Handled:** reattach 16:57:11Z (`InpConfigWarning` + " x"); both
  scalps closed by 16:59. Every fleet had the same gap.
- **Changed:** ADR-164 (deal-history replay) merged 29 Sep `0335f25`;
  live on B and C from C63. A (`5685e4f`) keeps the gap until cycle 3
  ends. Gate item before real money.
- **Evidence:** ADR-164 A1-A11; HANDOFF 2026-09-24 s21-s22; C76.

### 28 Sep (session) -- first live automatic ejections (A, B, C)
- **What:** ADR-157 fired for the first time: 18 ejections by 13:22Z
  (A 5, B 9, C 4), each filled in 0-2 min, $3.00-5.49 each.
- **Impact:** working as designed; the B1-dialled pairs ejected most
  (smaller room to cap). Each ejection costs about six scalps.
- **Handled:** no action.
- **Changed:** ejection value study (C16) asks whether ejecting beats
  holding; the lattice replaces ejection on B and C at C63.
- **Evidence:** HANDOFF s20; `docs/research/ejection-value-study.md`.

### 27-28 Sep night -- box 2 remote desktop failed (C)
- **What:** RDP showed a teal screen; the X display stopped answering
  new clients. MT5 kept trading throughout (card LIVE 11/11).
- **Handled:** left alone overnight (nothing touched on a live box in
  the dark); x11vnc on port 5911 in daylight. RDP repair deferred to a
  closed-market slot.
- **Changed:** "the card, not the remote desktop, says whether a fleet
  is alive" (02_TRAPS 28 Sep); C75.
- **Evidence:** HANDOFF s20-s21; 06 s9.

### 27 Sep 21:05Z -- Sunday open: wide spreads and gap fills (A, B)
- **What:** IC crosses opened 130-180 points wide (GBPUSD 72) for about
  an hour, wider than the L0 widths. Resting limits gapped through:
  exits filled 6.4-11.2 pips BETTER than their limits, long adds
  5.7-13.2 pips better.
- **Impact:** six transient `QUARANTINE_ENTER` (released); the gap also
  added inventory, so day P&L moved -54 -> -70 while scalps booked.
- **Handled:** no action. Fleet C's first attach and B's dial reload
  waited until spreads were 1-6 points (~2 h after the open).
- **Changed:** rule: attach or reload only once every spread is well
  under its pair's width; C73 (show gap slippage).
- **Evidence:** HANDOFF s19; 02_TRAPS 27 Sep.

### 27 Sep ~23:57Z -- telemetry key visible in a screenshot (security)
- **What:** the EA Inputs dialog shows `TelemetryAPIKey` in clear; a
  screenshot put the full key in a chat. A 43-char key has also sat in
  `ea/Globals.mqh` in the public repo since 19 Jun.
- **Handled:** rotation planned for the C63 reattach, then (29 Sep) moved
  out of C63 to later in the week: pipshed must first accept a second
  key during the changeover; never screenshot the Inputs tab's last rows.
- **Changed:** C9; 07 gate (key rotated and repo private before real
  money).

### 25 Sep 06:27Z -- box 1 remote desktop locked out (B)
- **What:** `xrdp-sesman` restarted (almost certainly an unattended
  library upgrade) and forgot the running session; every RDP login failed. MT5 and the
  fleet were unaffected.
- **Handled:** x11vnc onto the live display; no reboot under a live
  fleet.
- **Changed:** 06 s4 (VNC fallback), 02_TRAPS 26 Sep.

### 25 Sep ~04:00Z -- carry-pass race found before it fired (A, B)
- **What:** a DeepSeek audit exposed a live defect: a layer released
  during the nightly carry pass could get its accrual committed while
  its exit kept yesterday's price, then halt on I6. Latent: logs showed
  it had not fired.
- **Handled:** fixed, tested and deployed the same night (C52, `main`
  `5685e4f`, B 04:42Z, A 04:50Z); the first live pass that night was
  clean.
- **Changed:** C52; carry check `--carrypass` every night.
- **Evidence:** HANDOFF s11-s12.

### 24 Sep 07:30Z -- SNB decision: CHF crosses spiked (A, B)
- **What:** the CHF crosses rallied through the short ladders: L0-L3
  filled within seconds on both fleets.
- **Impact:** no side reached cap (none did in cycle 3's first 48 h), no
  halt, no quarantine recorded. Those instances' closed P&L for the FTMO
  day was positive, with no ejections (read through the fetch tool, 29
  Sep; unverified: confirm from the archive; `fill_logs` are kept, the
  "~8 Oct" expiry noted here was wrong, `grid-thesis.md` T8).
- **Handled:** no action.
- **Changed:** C49 (add delays: measure, do not build) -- shallow layers
  WANT spike fills; nothing argued for a delay.
- **Evidence:** 08 C49; HANDOFF s16.

### 24 Sep 03:13Z -- first cycle-3 quarantines (A, AUDNZD)
- **What:** `QUARANTINE_ENTER I3_SHORT_NAKED`, released after one check
  (~200 ms): the exit queue moved an exit (cancel, then place).
- **Handled:** diagnosed benign; no action.
- **Changed:** C40 (observe); C74 (banner noise).
- **Evidence:** HANDOFF s8; branch `logs/audnzd-quarantine-20260924`.

### 23 Sep 13:51Z -- cycle 2 ended on the FTMO daily-loss limit
- **What:** a USD move on a day that STARTED about -$330 down from
  positions carried in from earlier days (FTMO counts the day from the
  day-start balance, open marks included). FTMO liquidated all 128
  positions at -$505.34 against -$500. The two USD majors lost $320; the
  other six pairs made +$6.
- **After:** the 16 instances ran on for 47 min reporting their old
  layers against an empty book; the API count rose 506 -> 1,906 until
  the operator switched Algo off.
- **Handled:** account closed out; cycle 3 started 24 Sep.
- **Changed:** cycle 3 runs ONE arm per pair (halves carried exposure);
  ADR-158 daily-loss breaker (not on that build; counterfactual -$486,
  inside the limit); ADR-160 floating-loss entry gate; C28 (carried
  MTM); C31 (a flattened book must halt, still open).
- **Evidence:** `docs/FULL_TRIAL_RECORD_1514582088.md`.

### 17 Sep 03:22Z -- manual flattening of the USD ladders (cycle 2)
- **What:** the four USD-pair instances had deep ladders; the equity low
  that day was -$421 against the day's anchor (84% of the daily limit).
- **Handled:** operator closed L00-L04 on each by hand (detach, delete
  entries, close, reattach with cap 8): about -$218, -$282 realised that
  day. Manual closes never reach the EA's realised P&L or `scalp_history`.
- **Changed:** cap 8 on those four (fleet-wide from cycle 3); the
  daily-loss breaker work (C17, ADR-158).
- **Evidence:** HANDOFF 2026-09-17b s1-s2; trial record s3.

### 16 Sep -- FOMC day: the 200-order limit halted the fleet (cycle 2)
- **What:** with deep ladders the account hit its 200 positions + orders
  limit; the terminal refused the exit placed after a fill (10040), the
  layer went naked and the instance halted. 14+ halts over the day,
  untracked fills on halted instances, 822 -> 3,414 requests in 23 min,
  reinits that re-halted.
- **Handled:** reinits; NZD ALT arms detached.
- **Changed:** ADR-151 exit queue (only rank 0 and the highest rank
  rest, so exits stop holding slots); ADR-152 entry purgatory; the slot
  guard (entries need `positions + orders + resting <= 194`).
- **Evidence:** HANDOFF 2026-09-16; ADR-151.

---

## PATTERNS SO FAR

- **Liquidity events fill whole ladders in seconds** (SNB, the Sunday
  gap). The ladder absorbed both; what hurts is inventory that is still
  open when the NEXT day starts.
- **Account limits end accounts, not single trades:** the 200-order
  limit (16 Sep) and the daily loss counted from the day-start balance
  (23 Sep). Both now have guards; carried MTM (C28) is still the biggest
  exposure.
- **Infrastructure faults halt instances; markets mostly do not** (the
  resync, the remote-desktop faults). The fleet kept trading through
  every desktop fault; the card is the source of truth.

Line count: 502
