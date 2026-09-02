This message has a line count at the bottom.

# DeepSeek Phase 1 Response — Market-Close Harvest Exit Lifecycle Teardown

## Integrity gate (courier)

| Check | Result | Observed |
|-------|--------|----------|
| line 1 | **PASS** | `This message has a line count at the bottom.` |
| line 83 | **PASS** | `## The remediation options to attack (do NOT pick one -- break each)` |
| last line | **PASS** | `Line count: 161` |
| total lines | **PASS** | `161` |

Source files opened and verified against brief GIVENS at commit f74a180:
`ea/fxmatrix_v2_logic.mqh`, `ea/fxmatrix_v2_state_reconstruction.mqh`,
`ea/fxmatrix_v2_sre_oninit.mqh`, `ea/fxmatrix_v2_engine.mqh`,
`ea/fxmatrix_v2_exits.mqh`, `ea/fxmatrix_v2_tests.mq5`.

---

## T-1 [PRIMARY] — Is the D2 characterization EXACT?

**VERDICT:** NO-EXPLOIT (characterization confirmed exact for the stated broker
footprint, with one documented position_id=0 blind spot)

**LOAD-BEARING CLAIM:** `V2_SRE_CheckNonStandardClosures`
(`ea/fxmatrix_v2_state_reconstruction.mqh:1145-1162`) halts on ANY deal where
(1) `position_id != 0`, (2) `V2_SRE_IsEntryPositionId(position_id, deals,
entry_magic)` is true, (3) `entry_type == DEAL_ENTRY_OUT` (or stop-out reason),
without inspecting OUT deal magic and without skipping `DEAL_ENTRY_OUT_BY`.
Orphan guard `V2_IsOrphanedStartupState` (`fxmatrix_v2_logic.mqh:263-265`) +
early return (`fxmatrix_v2_sre_oninit.mqh:800-801`) skips the entire
reconstruction pipeline when `layer_count==0 && broker_position_count==0`.

**MINIMAL REPRO / MECHANISM:**

*D2 arms (HALT_23 on reattach, non-flat stack):*
1. Side holds **3** entry-magic layers (position_ids P1, P2, P3); session running.
2. L0 harvest fires `V2_CloseExitAtMarket` → `V2_BuildExitMarketCloseRequest`
   (`logic.mqh:186-213`) → broker books **DEAL_ENTRY_OUT**, magic **exit_magic**,
   comment `"V2_Exit"`, `position_id=P1`.
3. Pass-1 of `V2_SRE_GatherDealHistory` (`sre_oninit.mqh:323-334`) captures the OUT
   (exit_magic filter). Pass-2 is irrelevant — deal already present.
4. EA detaches / VPS restart before in-memory layers are persisted (always
   `cfg.layer_count==0` on fresh attach). Broker still shows **2** entry-magic
   positions (P2, P3) → `V2_IsOrphanedStartupState(0, 2)==true` → Steps 3–10 run.
5. `V2_SRE_CheckNonStandardClosures(deals, now, lookback, entry_magic)` encounters
   the OUT on P1 → `IsEntryPositionId(P1)` true (IN with entry_magic exists in
   history) → not OUT_BY → **HALT_23**. `V2_SRE_CheckAmbiguity` (`:1397-1398`)
   propagates unconditionally.

*Benign flat case (brief claim holds):*
Same steps 1–2 harvesting **last** layer (P1 only). Broker flat at reattach →
`V2_IsOrphanedStartupState(0, 0)==false` → return `V2_SRE_OK` at `:800-801`.
`CheckNonStandardClosures` never executes regardless of history content.

*Anchor / lookback:* `CheckNonStandardClosures` does **not** use anchor_time — only
`deal_time >= lookback_from - lookback_sec`. Anchor interaction claimed in the
brief is **not** a suppressor. A market-close OUT within the 90-day window is
always scanned.

*Two-pass f74a180 collection:* Does **not** drop the market-close OUT — it is
pass-1 eligible (exit_magic). It does **not** convert OUT→OUT_BY. D2 is **not**
neutralized by f74a180.

*Blind spot — fires LESS than claimed:*
If the broker emits the market-close OUT with `DEAL_POSITION_ID==0`,
`:1153-1154` `continue` skips it → **no HALT_23** from that deal (possible
false-negative vs D2). Unit test `Test_SRE_NonStandardClosureBeforeAnchorHalts`
(`tests.mq5:2774-2789`) uses non-zero position_id; no test covers position_id=0
OUT. This does not refute D2 for normal MT5 position-close deals (typically
non-zero position_id) but must be empirically verified (feeds T-4).

*Fire where claimed benign — counterexample search:*
No source-grounded case where a **successful CloseBy limit-harvest** (IN exit_magic
+ OUT_BY) trips HALT_23 — `:1157-1158` skips OUT_BY. Manual magic-0 close on a
**non-flat** stack would also HALT_23 (intended); the brief’s “benign flat manual
close” relies on orphan-guard skip, not on CheckNonStandardClosures leniency —
confirmed exact.

**SEVERITY:** fixable-within-design (D2 is real for the G3 footprint; position_id=0
is a secondary empirical gap)

---

## T-2 — Break OPTION B (CloseBy-shaped market close)

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** Successful limit-harvest removes the layer on **DEAL_ENTRY_IN**
(exit_magic) and queues CloseBy (`engine.mqh:679-727`). Orphan reconstruction
**fail-closes on any open exit-magic position** via
`V2_SRE_PreCheckExitMagicOpen` (`state_reconstruction.mqh:307-311`) before
history analysis — returns **HALT_01** immediately (`sre_oninit.mqh:805-809`).
Option B necessarily creates an exit-magic **open position** (opposing market IN)
before CloseBy completes — the same structural window the normal path has, but
Option B **mandates** a market open at the through-target instant when liquidity
and freeze-level stress are highest.

**MINIMAL REPRO / MECHANISM:**

*Reattach during over-hedged window (fatal to “no SRE change” claim):*
1. Stack depth ≥1; harvest triggers Option B: market **SELL** IN (exit_magic) opens
   hedge position H; layer L0 still open on entry ticket E.
2. **Crash or EA detach** after H is open, before `V2_ProcessCloseByQueue`
   completes CloseBy (≥1 tick window — same async CloseBy architecture as G2).
3. Reattach: broker scan finds E (entry_magic) + H (exit_magic).
4. `V2_SRE_PreCheckExitMagicOpen(exit_positions)` → **HALT_01_EXIT_MAGIC_POSITION_OPEN**
   — reconstruction aborts **before** CloseBy history can pair the legs.
   Option B does **not** achieve “no SRE change”; it trades HALT_23 (plain OUT
   footprint) for HALT_01 (dangling exit-magic position) on crash-in-window.

*In-session failure at harvest moment:*
5. Opposing market order **rejected** (freeze level, off-quotes, margin) after
   bid≥target → fallback fails; layer stays with no removal — same naked-L0 class
   as today, but Option B adds market-order rejection surface that limit path
   avoids at the same trigger.

*Partial fill:*
6. Market IN fills 0.005 of 0.01 → `V2_QueueCloseBy(E, H_partial)` → CloseBy
   volume mismatch or residual hedge → `V2_ProcessCloseByQueue` exhaustion path
   (`exits.mqh:378-407`) can increment `g_v2_ta_samedir_crit` / halt side.

*BCC / exit_ticket collision:*
7. Recording market-hedge order as `exit_ticket` then filling IN: until CloseBy
   completes, BCC C1 exit-first scan (`DEEPSEEK_TEARDOWN_BCC premise`) sees a
   live exit-magic order/position without a stable layer pairing — same transient
   class as G2 CloseBy window; debounce required. Not novel, but Option B **always**
   enters this window on every market harvest (limit harvest also does, but limit
   can fail before IN — market path forces IN).

**SEVERITY:** fixable-within-design (same CloseBy-window class as production G2,
but strictly **wider** failure surface at the through-target moment + HALT_01 on
reattach-in-window)

---

## T-3 — Break OPTION C+D (SRE exemption specifically)

**VERDICT:** NO-EXPLOIT (exemption is narrow; magic-0 manual closes remain protected)

**LOAD-BEARING CLAIM:** Current HALT_23 trigger ignores OUT deal magic entirely
(`:1159-1160`). Option D adds a **continue** when `deals[i].deal_magic == exit_magic`
(plus comment gate per brief). f74a180 pass-2 merge
(`V2_SRE_MergeManagedPositionCloseDeals`, `:779-803`) adds magic-0 **OUT** on
managed entry position_ids — those deals have `deal_magic==0 != exit_magic`, so
exemption does **not** apply. Only G3’s `V2_BuildExitMarketCloseRequest` path
(`logic.mqh:203-204`) stamps exit_magic + `"V2_Exit"` on plain OUT today.

**MINIMAL REPRO / MECHANISM:**

*Hole search — other plain OUT + exit_magic on entry position:*
- G3 market close: **sanctioned** target of exemption (intended).
- Limit harvest + CloseBy: terminal close is **OUT_BY**, skipped at `:1157-1158` —
  exemption irrelevant.
- Manual human close in MT5 UI: typically magic **0**, not exit_magic → still
  HALT_23 (correct).
- Hypothetical external script closing with exit_magic: would be whitelisted — but
  that magic is EA-owned; masking it is equivalent to accepting EA-sanctioned
  closes. No additional attack surface beyond “trust exit_magic OUT == our harvest.”

*Interaction with f74a180 magic-0 netting:*
Pass-2 captures magic-0 OUT; exemption checks OUT magic, not merge logic.
Magic-0 manual close on P1 with remaining stack → still HALT_23 after exemption.
T-SRE-MC-7 flat case (`tests.mq5:2922-2945`) tests netting + phantom veto, **not**
CheckNonStandardClosures — add explicit HALT_23 regression for magic-0 non-flat
post-exemption in Phase 4.

*Interaction with CloseBy history mapping:*
Exemption only affects `CheckNonStandardClosures`, not `V2_SRE_MapHedgeToEntry`.
Sanctioned plain OUT removes net volume on P1 via `V2_SRE_PositionNetVolume`;
replay events for removals come from CloseBy **pairs**, not plain OUT — a
sanctioned harvest layer may be absent from replay pairs (same class as any
non-CloseBy removal). Flag for Phase 4: confirm `last_exit_valid` / path-state
replay still correct when top layer exits via plain OUT rather than hedge pair.
Not a HALT_23 hole; a path-state correctness check.

*Option C without D (D-free variant):*
C fixes D1 in-session but leaves D2 armed on reattach — **incomplete**.

**SEVERITY:** fixable-within-design (exemption is tight; path-state replay needs
Phase 4 verification, not a security bypass)

---

## T-4 — Empirical position_id / magic (feeds OPTION C)

**VERDICT:** DESIGN-UNSAFE (to implement Option C without live deal capture first)

**LOAD-BEARING CLAIM:** Option C matches layers via `DEAL_POSITION_ID` with
fallback `position_ref` from `OnTradeTransaction` (`engine.mqh:644-646,
690-696`). If both are zero/wrong, handler logs
`WARN V2_LONG | exit fill with no matching layer` and **does not** remove layer
(D1 persists). `CheckNonStandardClosures` blind spot at `position_id==0` (`:1153-1154`)
means D2 may **also** fail to arm — inconsistent safety (silent D1, no HALT_23).

**MINIMAL REPRO / MECHANISM:** Not constructible from source alone. Required
live verification after the **next** market-harvest event (or induced demo harvest):

Pull from MT5 **Account History → Deals** (or `HistoryDealSelect` in script),
for the **closing** deal ticket:

| Field | API constant | Pass criterion for Option C |
|-------|--------------|----------------------------|
| Entry type | `DEAL_ENTRY` | `DEAL_ENTRY_OUT` |
| Magic | `DEAL_MAGIC` | `== magic_long_exit` / `magic_short_exit` |
| Position id | `DEAL_POSITION_ID` | `== POSITION_IDENTIFIER` of harvested layer (compare to `g_long_layers[i].position_ticket` / `PositionGetInteger(POSITION_IDENTIFIER)`) |
| Comment | `DEAL_COMMENT` | `"V2_Exit"` |
| Order | `DEAL_ORDER` | optional cross-check to originating close request |

Also capture `trans.position` and `trans.deal` from `OnTradeTransaction` on the
same event (Experts/Journal will **not** contain deal_ticket today — the
20260828 live D1 sequence logged no ticket). If `DEAL_POSITION_ID==0` on OUT
but `trans.position` is non-zero, Option C must prefer transaction ref over
history-only read, and Option D must **not** rely on position_id-scoped exemption
without an alternate key.

**Note:** Brief references `pending_market_close` flag for TA/BCC exclusion — **not
present in ea/ at f74a180** (grep over `ea/*.mqh`). Option C as specified assumes
machinery that still needs implementation; empirical gate applies before coding.

**SEVERITY:** fatal-to-premise **for Option C implementation timing** (not fatal to
the defect diagnosis — block coding until one real deal row is captured)

---

## COMPARATIVE VERDICT: Option B vs Option C+D

| Dimension | Option B | Option C+D |
|-----------|----------|------------|
| D1 (in-session) | Fixes if IN+CloseBy succeeds same as limit path | Fixes via dedicated OUT branch |
| D2 (reattach HALT_23) | Avoids plain OUT **if** CloseBy completes | D explicitly exempts exit_magic OUT |
| SRE touch | Claims none, but **HALT_01** on reattach mid-CloseBy | D modifies HALT semantics f74a180 preserved |
| Harvest-moment risk | Market order rejection, partial fill, slippage | Plain OUT (current broker API); fewer legs |
| Transient two-position window | Required every harvest | None (no opposing leg) |
| Empirical gate | CloseBy pairing assumed | **Required** deal field capture (T-4) |

**Smaller failure surface: Option C+D**, provided (a) live deal verification (T-4)
passes, (b) `pending_market_close` TA/BCC exclusion is implemented as brief
states, (c) path-state replay after sanctioned OUT is regression-tested.

**Safer D-free variant:** **None.** Option C alone without D fixes D1 only; the
next non-flat reattach still HALT_23s. Option B without SRE tolerance is **strictly
riskier** than C+D at the harvest instant and on crash-in-window (HALT_01).

**Option D alone** (exemption without C) would stop D2 but leave D1 live — worst
of both.

---

## OVERRIDE CHECK

All findings are fixable within remediation — the market-close harvest fallback is
**not** fundamentally incompatible with the SRE, but it **is** incompatible with
the **current** plain-OUT + IN-only-recognizer combination (G1/G3 mismatch). D1
is confirmed live; D2 is source-confirmed latent for non-flat reattach with
standard MT5 deal shape. The defect premise stands. No abort required.

OVERRIDE CHECK: Premise stands — fixable within Option C+D (preferred) after T-4
empirical deal capture; Option B is a strictly larger mechanical failure surface
and does not deliver its “no SRE change” claim under crash-in-window reattach.

Line count: 263
