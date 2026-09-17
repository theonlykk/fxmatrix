This message has a line count at the bottom

# ANSWERS FROM THE PREVIOUS CHAT -- to prompts/questions_for_previous_chat.md @ bf1fd82

Loaded whole: 142 lines, last line "Line count: 142".
Convention: "not discussed" means the topic never came up here. Where I give
a reason it was stated in this chat, or it is a source fact I re-checked at
`75a2715` (EA unchanged since 46b1749). Broker time is UTC+3 throughout.

## A. DEPLOY SEQUENCE AND THE PARKED INSTANCES

A1. **No, it was not known -- the plan is wrong here.** 16c s4 step 6 says
    every chart reloads at once, but the consequence that `OnInit` clears
    every halt (`g_grind_halted = false`, fxgrind.mq5 ~125) was not
    connected. Step 5 was written assuming parked instances would stay
    halted through the reload, and step 11 carried forward the earlier
    intent to keep GBPUSD OPT and EURUSD ALT out until morning. The two
    steps contradict each other. No sequence for "compile resumes all
    parked instances" was designed. Treat s4 steps 5, 6 and 11 as
    unresolved.

A2. Not discussed. The extra four halted after 16c was written (see E1).
    The only stated intent on record is 16c s4 step 11 (GBPUSD OPT, EURUSD
    ALT to wait) and the standing rule "no reinits into a full book".

A3. Not discussed for this deploy. Detaching was used earlier for capacity
    (NZDCAD ALT / AUDNZD ALT, `HANDOFF_2026-09-16.md` s3), which also
    records that detaching frees no slots (`02_TRAPS.md` CAPACITY section).

A4. Written with the CURRENT recon in mind, about naked layers generally:
    a halted instance with an exit-less position fails reconstruction on
    reload. Under ADR-151 recon a naked layer still fails if its rank is
    < K; a naked layer is usually the newest fill, which is rank 0. A
    naked layer ranked >= K would pass ADR-151 recon and be released by
    the engine. The rank dependence was not discussed.

A5. **Not discussed, and I agree it is a gap.** Restoring the ADR-150 .ex5
    after ADR-151 has trimmed exits puts held layers under I3-on-every-
    layer; each instance with held exits would fail reconstruction and
    halt. A rollback that re-places exits first (needing free slots) was
    not considered. 16c s4 step 10 is incomplete as written.

A6. Not discussed.

## B. CAPACITY AND LAYER CAPS

B1. The table in memo s3 (`docs/architecture/MEMO_2026-09-16_order_purgatory.md`)
    and the operator's view. The "majors now" row applied P=12 to all 7
    pairs; I did not compute the actual mixed fleet (4 x 16 + 10 x 12 =
    184), so that row overstated the case. The operator's reasons for a
    lower cap are in `HANDOFF_2026-09-16.md` s7: scalps earn while deep
    layers wait; prefers risk spread across pairs over GBPUSD holding ~36
    slots; "measure first" (scalp income by layer depth) was the proposed
    next step and has not been done. Gemini ruled it a follow-on ADR (Q6).
    MTM depth on GBPUSD was not cited as the driver.

B2. Yes, deliberately. From memo rev 4 onward the formula is "sizing
    guidance, not enforcement" and the commitment guard is the guarantee
    (memo rev 5 s3 and s4.7; DeepSeek rev 3 T-9 disposition in s7). The
    two-sided bound 2P + 2(K+H) is stated there.

B3. `HANDOFF_2026-09-16.md` s7, "Two traps, from source":
    1. `I7_LONG/SHORT_DEPTH` fires when depth > `max_layers` and is NOT
       quarantinable, so an instance holding 12 layers reinitialised with
       cap 8 halts immediately in reconstruction.
    2. `Grind_EnsureAddNext` keeps an already-resting add whose label
       matches the next index even at cap; if it fills, depth = cap + 1 and
       I7 halts. Delete that resting add right after reinit.

B4. Margin 4: Gemini's value (Q1), no derivation given. My stated rationale
    after adding the lock: margin only has to cover exit timing, because
    entries are serialised (memo rev 5 s4.7). ~28 slots: 2 resting entries
    x 14 instances, my estimate (memo rev 5 s9 q7; rev 2 was never
    committed), which Gemini accepted.

B5. Not discussed in this chat. `HANDOFF_2026-09-16.md` s5 item 8 notes
    GBPUSD/EURUSD have run `InpMaxLayers=12` since the original presets.

## C. EXIT QUEUE AND GUARD DESIGN

C1. Beyond Gemini: the operator's worked example used K=2
    (memo rev 5 s4.3a), and his "last say 4 positions" framing. Harvest
    cost of a fast reversal was NOT estimated. The only related design
    point is the gap clamp: a released exit whose target price has already
    passed is placed passive at or better than target (memo s4.5).

C2. Confirmed intended. Modifies and cancels consume no slot (memo s4.7
    table "always allowed"; spec 4h "not modifies, not cancels"). Note the
    only L0 modify path today is the ADR-124 recentre of a stranded
    opposite L0, which fires once outside the deadband, not every tick.

C3. Not discussed. The loop copies `Grind_CapTryAcquireLock`
    (grind_cap.mqh ~88), which also uses Sleep(1) with bounded retries.
    The ~50 ms worst case per tick was not considered.

C4. Not discussed as such. The considered and rejected alternative was
    letting a halted instance place exits for fills, because it breaks the
    halt contract (memo rev 5 s4.9; ADR-151 Consequences).
    Having the halt path close an untracked fill was never raised.

## D. REQUEST COUNTER AND FTMO

D1. The 2,000/day figure came from third-party sources during the FOMC
    session, explicitly flagged as needing verification against FTMO's own
    documentation (16c s5 item 8 carries it). Whether it applies to demo:
    unknown. `send_logs` by action: not done. Note the counter includes
    sends the terminal refuses locally (grind_api_counter.mqh ~76), so it
    overstates server requests during a storm.

D2. Not known and not discussed. Checked now at source: the increment is
    read-then-set (grind_api_counter.mqh ~47-51) and is followed by a
    self-verify `after == before + 1`; on mismatch it sets
    `g_grind_api_counter_broken`, and `Grind_GuardsAllowTrading`
    (grind_engine.mqh ~398) refuses trading when that flag is set. So a
    concurrent increment could both lose a count AND stop an instance
    trading. Not verified live.

D3. Only qualitatively: "about one extra cancel per add fill beyond K+H,
    and the release place a scalp would have needed anyway" (memo s5,
    ADR-151 Consequences). No numbers.

D4. Not discussed in this chat.

## E. WHAT HAPPENED AFTER THE HANDOFF

E1. Inferred from status reads b67 (00:37:01Z) and b68 (00:43:11Z); not
    written anywhere else. Fill time = the moment a layer went naked;
    the halt would follow ~3 s later. Confirm with `ea_events`.
      - EURUSD OPT: short L00 filled 22:17:09Z, naked -> halt. Its long L08
        exit then filled while halted at 00:05:34Z (locked pair).
      - AUDNZD OPT: long L00 filled 22:17:39Z, naked -> halt. A short L01
        exit filled while halted at 22:25:02Z.
      - NZDCAD OPT: long L02 filled 23:51:52Z, naked -> halt.
      - CADCHF OPT: fresh entries placed 00:02:13Z = reinitialised then
        (after its parking). Running at b67/b68.
      - AUDCHF ALT: fresh entries placed 00:01:55Z = reinitialised; short
        L03 filled 00:03:59Z, naked -> halted again.
      - AUDCHF OPT: short L03 filled 00:33:35Z, naked -> halt.
    Book level: 200/200 at 21:47Z (b66) and at 00:37Z (b67). Levels at the
    individual halt times are not known. Who reinitialised CADCHF OPT and
    AUDCHF ALT was not stated; the operator did the parking.

E2. Closed by the operator on my instructions at ~00:40Z (b67 profit
    figures, i.e. quotes at 00:37Z, not realised amounts):
      AUDNZD OPT: close 544109619 buy 1.23970 (~+0.61); Close By
        544163788/544164101 (~+0.23); Close By 543745101/543783548 (~+0.04).
      AUDCHF ALT: close 544203136 (~-0.55). AUDCHF OPT: close 544212393
        (~-0.22). EURUSD OPT: close 544144260 (~+0.07); Close By
        544072001/544157503 (~+0.72). NZDCAD OPT: close 544190049 (~-0.59);
        Close By 544117303/544176884 (~+0.24).
    Earlier (~21:50Z): AUDCHF ALT close 544109962 (~-0.31); CADCHF OPT close
    544135503 (~-0.19). b68 shows every one of these gone. Recorded nowhere
    but this chat; the MT5 History tab holds the realised figures.

E3. Yes. The operator stated "i did fix" those four tickets, and b67 is
    consistent (AUDCHF ALT's old entry and CADCHF OPT's short L03 absent).

E4. Not confirmed. 16c s0 says "as far as known"; `config_events` was never
    queried. When `deploy.ps1` was last run: not discussed.

E5. Rollover facts seen: request counters reset (475-488 per instance at
    21:47Z). Note the AUDCHF ALT and CADCHF OPT halts (short L03 fills at
    20:08:17Z and 20:31:23Z) happened BEFORE the rollover, not after. Book
    200/200 at 21:47Z. Nothing else was observed; 16b was never finalised.

## F. SPEC AND PROCESS

F1. Not discussed. 16c s4 goes spec -> Cursor with no Gemini step for
    AM1-AM8; that was an omission, not a considered judgement.

F2. Mining the reasoning was treated as sufficient for that night, because
    of time. No rerun was planned; runner fixes are listed as open
    (`handoffs/Handover/04_DEEPSEEK_COURIER.md`, "OPEN IMPROVEMENTS").

F3. Uninvestigated. It was carried as a low-priority open item from the
    FOMC session ("EURUSD OPT add filled 1.15023 at reinit, below expected").
    Its effect on ADR-151 was not discussed. For what it is worth: ADR-151
    ranks by entry ORDER, not spacing, and reconstruction keys on comment
    layer indices, so irregular spacing alone should not change ranking;
    `Grind_ComputeAddTarget` prices the next add from the deepest layer.
    Not verified.

F4. Wording. I diffed ea/ between 9f67f0f and 96af7b1 (empty) and wrote
    "unchanged since 9f67f0f" meaning "at least since". The last ea/
    commit is 46b1749. No different baseline was intended.

F5. Not planned. ARCHITECT s1's stale L0 sentence was flagged in
    `HANDOFF_2026-09-16.md` s5 and carried in `01_BOOT.md`; the briefs used
    a corrected frame instead. That s1's "exactly one resting exit" becomes
    false under ADR-151, and that s3 still describes the model-switch
    courier, were not noticed. Only `04_DEEPSEEK_COURIER.md` was rewritten.

Line count: 193
