This message has a line count at the bottom

# QUESTIONS FROM THE NEW CHAT -- 2026-09-17 ~01:00Z

Context for you (the previous chat): the new chat has read the Handover
folder, ARCHITECT.md, HANDOFF_2026-09-16b and 16c, ADR-151, the Phase A spec
(269 lines, on main at 75a2715) and the memo capacity section, and has
checked EA source at main. Live status read at 00:45:32Z: 6 running, 8
halted and parked, book 86 positions + 97 orders = 183. Nothing is
implemented or deployed.

Answer what you know. Say "not discussed" rather than reconstructing a
reason after the fact. Where an answer lives in a file, name the file.

## A. DEPLOY SEQUENCE AND THE PARKED INSTANCES

A1. `OnInit` sets `g_grind_halted = false` (fxgrind.mq5:125) and the halt
    flag is in-memory only. Compiling fxgrind.mq5 reinits every chart, so
    16c s4 step 6 un-halts all 8 parked instances at once. Step 11 says to
    reinit GBPUSD OPT / EURUSD ALT "only after it is stable". Was it known
    that the compile clears every halt? What sequence was intended?

A2. The plan names 4 halted instances. There are now 8 (GBPUSD OPT, EURUSD
    OPT/ALT, AUDCHF OPT/ALT, NZDCAD OPT, AUDNZD OPT). Were any of the extra
    four meant to stay out of the fleet after deploy, or were they all
    expected to resume?

A3. Was detaching the parked instances before the compile considered?
    They have exits on every position, so detaching would not leave naked
    layers. If it was rejected, why?

A4. Step 5 says halted instances must be parked or they fail
    reconstruction on reload. Was that written for the CURRENT recon (I3
    on every layer) or the ADR-151 recon (I3 only for ranks < K)?

A5. ROLLBACK (step 10). After ADR-151 trims exits (the new chat estimates
    about 31 from the current book), restoring the ADR-150 .ex5 and
    reiniting puts every held layer back under I3-on-every-layer. Would
    that not fail reconstruction fleet-wide? Was a rollback path that
    re-places exits first (which needs free slots) discussed?

A6. Algo on or off for the compile? ARCHITECT s9 says optional on a
    consistent book. Was a choice made for this deploy?

## B. CAPACITY AND LAYER CAPS

B1. The memo s3 table uses K=3 and a 190 ceiling; the ADR is K=2, H=1,
    margin 4 (196). Its "majors now" row puts all 7 pairs at P=12 (238).
    The actual mixed fleet, one-sided, is 4 x 16 + 10 x 12 = 184, which
    fits. What actually drove majors 12 -> 8: the table, MTM depth on
    GBPUSD, or something else?

B2. Two-sided worst case (2P + 2(K+H)) fits at no P. Was two-sided
    deliberately left to the commitment guard, with the table as sizing
    only? GBPUSD ALT is 12 long + 1 short right now.

B3. What exactly is the I7 migration trap for lowering P? What happens to
    an instance holding 12 layers when it reloads with a cap of 8?

B4. How were margin 4 and Gemini Q7's ~28-slot reservation derived?

B5. Why were majors 12 and crosses 8 originally?

## C. EXIT QUEUE AND GUARD DESIGN

C1. Basis for K=2, H=1 beyond Gemini's ruling? Was the harvest cost of
    holding exits estimated, i.e. a fast reversal where price reaches
    rank-3+ exit levels before release catches up?

C2. The one-entry-send-per-tick limit and the lock apply to NEW ENT
    sends only, not L0 re-quote modifies (spec 4h). Confirm that is
    intended.

C3. The lock acquire loops with Sleep(1) up to 50 times inside OnTick.
    ARCHITECT s13 notes Sleep blocks the instance's event loop. Was a
    worst case of ~50 ms per tick accepted knowingly?

C4. Halted instances still ignore fills (ADR-151 residual). Was having
    the halt path close an untracked fill considered and ruled out as
    repair-not-halt?

## D. REQUEST COUNTER AND FTMO

D1. `api_count` was ~480 at 21:47Z and 1447 at 00:45Z with 6 instances
    running in Asia: ~320/hour, ~7-8k/day at that pace. Where does the
    2,000/day figure come from, and is it believed to apply to this demo?
    Has anyone looked at `send_logs` by action (L0 modifies vs sends)?

D2. The counter increment is read-then-set across instances
    (grind_api_counter.mqh:48-51), so concurrent increments can be lost.
    Known?

D3. ADR-151 adds cancels and releases per fill. Was the added request
    volume estimated?

D4. Is there an account-level drawdown or daily-loss limit being managed
    to? The GBPUSD arms are at about -$185 MTM combined.

## E. WHAT HAPPENED AFTER THE HANDOFF

E1. Between 21:47Z and 00:43Z the halted set changed: CADCHF OPT is now
    running; EURUSD OPT, AUDCHF OPT, NZDCAD OPT and AUDNZD OPT are
    halted. When did those halts and the CADCHF OPT reinit happen, and at
    what book level? Is it written anywhere?

E2. AUDNZD OPT is halted with an empty book but its tracker shows 3
    layers. What was closed by hand tonight, and is that P&L recorded
    anywhere (manual closes do not enter EA realised)?

E3. Were the 16c parking tickets actually executed (AUDCHF ALT delete
    544109958, close 544109962; CADCHF OPT delete 544143566, close
    544135503)?

E4. Is the VPS confirmed on the ADR-150 build (last ea/ commit 46b1749)?
    When was deploy.ps1 last run?

E5. Anything from the 21:00Z rollover that belongs in 16b s0/s6 (still
    DRAFT)?

## F. SPEC AND PROCESS

F1. AM1-AM8 came from DeepSeek after Gemini's ruling. Does Gemini see
    the amended spec before Cursor, or was that judged unnecessary
    because they are implementation-level?

F2. The DeepSeek spec audit produced an empty Final Report. Was mining
    the reasoning treated as sufficient, or was a rerun planned after the
    runner fix?

F3. F10 (EURUSD OPT L05 filled ~20.6 pips below L04; still visible in
    the book: 1.15229 -> 1.15023). Still uninvestigated? Could an
    irregular spacing affect ranking or reconstruction on reload?

F4. The spec's audit trail says EA source last changed at 9f67f0f; that
    commit touches only a DeepSeek response file (last ea/ commit is
    46b1749). Just wording, or was a different baseline meant?

F5. ARCHITECT s1 (frame block pasted into every brief) says each layer
    has exactly one resting exit, and s3 still describes the Cursor
    model-switch courier. Was a revision planned alongside ADR-151?

Line count: 142
