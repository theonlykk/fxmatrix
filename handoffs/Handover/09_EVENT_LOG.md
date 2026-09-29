This message has a line count at the bottom

# EVENT LOG -- NOTABLE MARKET AND OPERATIONAL EVENTS

What happened, what it did to the fleet, how it was handled, what
changed because of it. Brief on purpose: the evidence column points at
the full record. Newest first. Times UTC. Add an entry for any event
that halts an instance, moves a book by more than a few layers in
minutes, touches an account limit, or needed a manual action.

Fleets: A = cycle 3 (FTMO, VPS), B = box 1 (IC), C = box 2 (IC). Cycle 2
= the previous FTMO account (1514582088, ended 23 Sep).

---

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
  Sep; unverified: confirm from the archive before `fill_logs` expire,
  ~8 Oct).
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

Line count: 164
