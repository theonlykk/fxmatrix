This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-24 ~03:35Z (SATURDAY: MARKETS CLOSED; E's FIRST DAY DONE; RAILWAY BACK)

**Prepared 24 Oct ~03:35Z in the s89 chat (HANDOFF s89 and its continued blocks 1-4; patches s89a-s89f).**
Fri 23 Oct: E's first FTMO day (+$50.84 realised, no roll); Railway's CLI came back (~14:53Z) and every held
read was done (carry 21 / 22 / 23 Oct complete; C88 closed; A's archives); pipshed `twoarm-fleets` merged, **E's
page `linuxe` and E's card BUILT (Cursor without Argon, checked against Claude's reference)**, pipshed.com now
shows E's page. Then two research questions: C's arms by regime (scoped, not started) and **sessions: the
archive study came back NOT WORTH IT** (pre-registered; session gating dropped). The desktop's C: drive filled.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `replay-plan4` and `plan4-tools`. **If `main` has moved past s89f, this file is stale: say so and boot from
the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block, the
   pipshed main row and the Fleet E row).
2. `handoffs/HANDOFF_2026-09-24.md` **s89 and all its "continued" blocks (1-4)**; follow the LAST NEXT SESSION.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-23** (early; day).
4. `research/session_hours/PREREG.md` (s4 the rule, s8 the RESULT) and `results.md`.
5. `docs/research/two-arm-viability-2026-10-21.md` s8.7 (sweep11, E's t3; C162 open).
6. `research/replay/results/sweep_notes.md` sweep11 (the method C's arms would reuse).
7. pipshed `prompts/cursor_e_card_built.md` (the pattern for A's retirement prompt).
8. `handoffs/Handover/08_BACKLOG.md`: C158, C160, C162, C163, C164.
9. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what is live, the time to the next time-gated
   step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Fleets now (unchanged since Wed / Fri builds):**
- **B** (wine-test, IC 53066709): nine `_OPT` (the control).
- **D** (wine-d, IC 53077984): 12, the two-arm t1 set since 21 Oct 15:13-15:54Z (OPT 7, 9, 3, 6, 4, 4; ALT q95 27,
  30, 19, 27, 22, 12 on EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF; cap 7). E's mirror for the live test.
- **C** (wine-c, IC 53071896): 6, EURUSD, GBPCHF, AUDCAD; OPT 7, 9, 6; ALT 27, 24, 27; since 21 Oct 16:45-17:04Z (ALT's
  first week ends ~Wed 28 Oct). All six on the build `fxgrind 2026.10.21 16:21:21` (C88 closed).
- **E** (wine-e, FTMO 1515045375, $10k): twelve on `_t3` since 23 Oct 03:04-03:25Z (OPT / ALT add = exit GBPUSD 9 / 15,
  EURUSD 7 / 23, EURGBP 5 / 23, AUDCAD 18 / 26, AUDCHF 14 / 20, CADCHF 10 / 17; cap 7; breaker OFF; `211cb64a25ac`).
  **First fill 03:29:01Z, so the trial runs to about Fri 6 Nov.** First day: requests 404 by 14:50Z (~35 an hour),
  +$50.84 realised, equity 9,997.17 at 22:00Z, no roll, first `DAILY_SNAPSHOT` `start_known` false (expected).
- **A** closed 21 Oct; its card still shows NO CONNECTION on the strip (its retirement is a prompt, below).

**pipshed (`main` `0f80b30`):** page services pipshed.com (**E's page since ~22:15Z**: `GRIND_FLEET=E` on the
`pipshed` service, which defaulted to A; it also takes every EA post), `linux.` B, `linuxc.` C, `linuxd.` D, `linuxe.` E
(new). The strip: A NO CONNECTION, B 9 / 9, C 6 / 6, D 12 / 12, E 12 / 12; books, quotes, S/R carry an E column.

**Railway:** CLI login works (`railway ssh` fine). The security incident (C163) is still "Identified"; their report
was due ~noon ET 23 Oct. **Every pipshed service also holds `ANTHROPIC_API_KEY` and `ADMIN_TOKEN`: the Anthropic key
can be billed: revoke and reissue it first** (the operator, Anthropic Console), then C163's full rotation.

**Research settled on 23-24 Oct:**
- **Sessions: NOT WORTH IT** (pre-registered `3cdcedb`; A, B, D1 eras, 22 archives): outside ADR-161's window layers
  roll slightly more but earn more per closed layer: no era has a direction. The NY afternoon's loss is one
  afternoon, Wed 14 Oct (the flurry). The regime, not the hour, is the axis.
- **C's arms (operator: "an arm for each regime"):** EURUSD 7 / 27 ~ sweep11's 7 / 23 (keep); **AUDCAD OPT 6 loses in
  both regimes (calm -805, Oct -488): sweep11 says 18**; GBPCHF never swept. A third arm cannot be a trend arm; the
  candidate is a wide DUP for swings beyond ALT's stack (C160), unproven.

**The desktop:** C: was FULL (0.2 of 238 GB). Downloads' files older than 30 days moved to `D:\Downloads-archive`
(11.58 GB; nothing deleted): C: 11.9 GB free. **Bulk exports go to `D:\fxmatrix-exports\<session>`**; patches stay in
Downloads. Left on C: Google Drive's local copy 43 GB (move or stream in the app, never by hand), Cursor 10.9 GB.

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `fdf41fa` (s89e) + s89f (this hand-over). EA code `5bb5fdb` on B, C, D, E |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0` (never merged); `D:\mt5-replay\MQL5\Files\replay` as s88 left it (`swaps.csv` = EURUSD's `581dab22`) |
| Research | `research/session_hours/` (PREREG, code, tests, `inputs.sha256`, `results.md`); the 22 archives in `D:\fxmatrix-exports\s89` (D's six, EURGBP_OPTB, `c_sizes.txt`) and Downloads (A's seven, B's other eight) |
| pipshed `main` | `0f80b30` (E's card built); `prompts/cursor_e_card_built.md` at `61b0724` |
| Linux boxes | wine-test, wine-c, wine-d, wine-e; MT5 6231 everywhere (LiveUpdate: Later, C161) |
| Bridge | grants this session: Downloads, `D:\fxmatrix-exports` (ask again in a new chat). Stage a file at a time past ~150 MB |
| Browser | the built-in browser has `linuxd`, `linuxe`, `pipshed.com` allowed; read pipshed there (s4) |

## 2. NEXT, IN ORDER

1. The operator applies s89f; tree checked; pushed.
2. **The Anthropic API key** (C163): revoke and reissue; update every Railway service that holds it.
3. **A's card retired** (C158): Claude's REFERENCE BUILD first on pipshed `0f80b30` (drop A's `FLEET_STRIP` entry; about
   30 checks in 9 scripts use A as a fixture: BK1, BK3-5, QG2, QT4, QT5, GT3, GT5, ST8, ST10, ST11, FS2, FS4, FS8, FS11,
   FS20, FS22, FS37, FS42-44, TA4, TA7, TA10, TR5 and their re-runs); then a tests-first Cursor prompt like E's card,
   its changed lines diffed against the reference. Argon or not: ASK (E's card was "option 2", without Argon).
4. **C164 (FTMO Instant):** the two questions for FTMO (which consistency figure, 30% or 50%; whether a two-sided grid
   is caught by the opposing-positions clause); the free Instant trial with the breaker ON at $300 as a test.
5. **C's arms:** GBPCHF tick dumps (eight Aug - Sep weeks, and 1-21 Oct) on an IC box by VNC; then sweep12
   pre-registered (GBPCHF by sweep11's rule; a wide band up to ~3.5 x ALT's add on C's three, anchored on October's
   episodes); C's reload after ALT's first week (~Wed 28 Oct): AUDCAD OPT 6 -> 18 at least.
6. **Sun 25 Oct:** the FTMO day rolls at 23:00Z from now on; Sunday's open read (E's first weekend gap).
7. **E's first week:** the first-week read pre-registered BEFORE it is read; whether it may reload E is NOT ruled.
8. Later: C163's full rotation (six web services and the worker); C160 (DUP on C) after ALT's first week.

## 3. TRAPS (full list in 02_TRAPS)

- **The fetch tool caches pipshed and can ignore the query string** (23 Oct: an hour-old heartbeat for any
  instance): read pipshed in the built-in browser with a same-origin `fetch(..., {cache: 'no-store'})`. The sandbox's
  shell cannot reach pipshed.com at all.
- **`intraday_mae` on `/api/telemetry/live` is the page service's fleet's account, not the instance's**; `api_count`
  is the terminal's (one GV for every instance on it).
- **A Friday carry pass reads `failed` 2-4 on every instance:** Saturday's swap is 0, the modify is a no-op, retcode
  10025 (C60). Not a fault.
- **pipshed's verify scripts print `ST3 FAIL` and `FAIL BK1`:** compare per script `n/m` and both forms.
- **A prompt committed to `main` moves `main`:** pin the code base by diff, never "HEAD = <hash>".
- **The operator's times are EDT (Z - 4 until 1 Nov):** 23 Oct 22:55 EDT is 24 Oct 02:55Z. Read `date -u`.
- **Bulk files go to D:, never C:** (C: filled on 23 Oct).
- **Every desktop MT5 window is not "the FTMO one"; a chart on the wrong period is left alone.**

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs; never ask for pasted logs or screenshots of
  fleet state: read pipshed (the built-in browser, s3).
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Research:** tests first in their own commit (against a stub), the code, the pre-registration committed before any
  result is read; self-checks first; an amendment, if any, before any net. **The operator: anchor on the actual
  episode; do not let rigour "throw the baby out with the bath water".** Argon only when the operator asks.
- **pipshed changes:** Claude's reference build first; a tests-first Cursor prompt (RESTATE AND STOP, committed to
  pipshed `main` before Cursor reads it); Claude reads Cursor's commits against the reference and reruns every verify
  script at each commit; the operator merges by fast-forward and pushes outside 20:50-21:00Z.
- **EA, generator or order-path changes:** a prompt in an artifact -> Argon -> Claude checks -> Cursor RESTATES AND
  STOPS -> "go" -> commits read -> the operator compiles -> the suite.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 138
