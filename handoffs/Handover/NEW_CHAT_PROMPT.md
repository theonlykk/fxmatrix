This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-25 ~04:55Z (SUNDAY: MARKETS CLOSED; C's t2 STAGED; ARGON REVIEWS THE RUNBOOK)

**Prepared 25 Oct ~04:55Z in the s90 chat (HANDOFF s90 and its continued blocks 1-4; patches s90a-s90e).**
Sat 24 Oct: the leaked Anthropic key disabled and deleted from Railway (C163's first step); A's card retired
(pipshed `b9d2d22`). Then research, all pre-registered: t3's drawdown read (the carried inventory, not the day's move,
breaches FTMO's daily loss); the OPT budget and B2 (NOT WORTH IT); **OPT cap 9: simulator BETTER, harness CONFIRMED**.
The operator ruled C's OPT to t2 (EURUSD cap 9; AUDCAD add = exit 18, cap 9), its runbook reviewed before Monday.
**The operator has Argon credits: use them, starting with the runbook review (s2 item 3).**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `replay-plan4` and `plan4-tools`, and whether `review/argon-c-t2` exists yet. **If `main` has moved past
s90e, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block, the
   fxmatrix main, Fleet C, Fleet E and Next rows).
2. `handoffs/HANDOFF_2026-09-24.md` **s90 and all its "continued" blocks (1-4)**; follow the LAST NEXT SESSION.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-24** (early; day) and **2026-10-25** (early).
4. `research/opt_budget/MECHANICS.md`, then `results.md` (B2, depth, the cap sweep) and `PREREG_CAP.md`.
5. `research/replay/results/sweep_notes.md`: the swcap section (pre-registration and RESULT).
6. `research/t3_drawdown/results.md` (why E may breach FTMO's daily loss).
7. `docs/runbooks/twoarm-reload-c-t2.md`, then `prompts/argon_review_c_t2.md` (the review Argon is to do).
8. `handoffs/Handover/08_BACKLOG.md`: C160, C162, C163, C164.
9. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what is live, the time to the next time-gated
   step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in. Sending Argon's prompt is not a fleet action, but wait for
the answers anyway (the previous chat may correct the prompt).

---

## 0. THE MOST IMPORTANT FACTS

**Fleets now (unchanged since 21-23 Oct):**
- **B** (wine-test, IC 53066709): nine `_OPT` (the control). The operator: its value as a control is low; a
  repurpose as an 8-instance cap-9 test fleet is PROPOSED, not ruled (its ~94 open layers are the obstacle).
- **C** (wine-c, IC 53071896): 6, EURUSD, GBPCHF, AUDCAD; OPT 7, 9, 6; ALT 27, 24, 27; cap 7; since 21 Oct
  16:45-17:04Z on the Experts build `fxgrind 2026.10.21 16:21:21`. **t2 staged on `main` for two charts (below).**
- **D** (wine-d, IC 53077984): 12, the two-arm t1 set (E's mirror; OPT 7, 9, 3, 6, 4, 4 / ALT 27, 30, 19, 27, 22, 12;
  cap 7). **No cap 9 on D** (the operator: "we cannot have trades blocked due to a lack of slots").
- **E** (wine-e, FTMO free trial 1515045375, $10k, $500/day): twelve on `_t3` since 23 Oct 03:04-03:25Z, cap 7, breaker
  OFF. First fill 23 Oct 03:29:01Z; the trial runs to about Fri 6 Nov. At the close: balance 10,050.84, equity
  9,997.17, book 18 long / 27 short, deepest 4. **E stays as it is** ("we learn a lot from actual FTMO runs"). Whether
  to step in near the $500 daily loss is the operator's call, NOT ruled.

**C's t2 (ruled ~04:10-04:14Z 25 Oct):** EURUSD OPT (22260201) cap 7 -> 9 only; AUDCAD OPT (22260401) add = exit
6 -> 18, width 1.5 -> 4.5, stranded 2.5 -> 5.5, cap 7 -> 9 (E's t3 AUDCAD OPT but cap 9). ALT stays at 7. Presets
`ea/presets_c/{eurusd,audcad}_opt_c_t2.set`, fingerprint `7ecd5b582851` (2 files), `research/opt_budget/check_c_t2.py`
ALL OK. **Reload Monday 26 Oct in session: not before 22:30Z Sunday, never 20:50-21:15Z; the operator picks the
minute; EURUSD first as the pilot; Remove then Attach.** Rollback to `_t1` only when both sides hold 7 or fewer.

**Research settled 24-25 Oct (all pre-registered):**
- **t3's drawdown:** at 0.01 lots October's replay breaches FTMO's $500 (16 Oct) and Instant's $300 (from 8 Oct): the
  carried inventory binds. Not fixed by any variant tested.
- **The OPT budget (sections of three) and B2 (two of four): NOT WORTH IT.** OPT's layers 5-7 scalp as well as 1-4;
  splitting removes them.
- **OPT cap 9: BETTER** (simulator; 11 and 13 not) **and CONFIRMED** (harness swcap: both periods +$336.00 against
  +$230.64 at cap 7). The cost: FTMO days over $300 / $500 rise 11 / 3 -> 15 / 5. No help for Instant (C164).
- **The operator's thinking:** "boring remains best, but best is far from sufficient"; "we might end up with more
  layers but less fx pairs"; "we are searching for a cluster of tight mean reversion" (the cluster measurement: the
  reversion probability by distance from an anchor against a random walk's 50%, to be pre-registered).

**Railway / C163:** the leaked key (the CandleLab key `...3QAA`) DISABLED; `ANTHROPIC_API_KEY` and `ADMIN_TOKEN`
deleted from the five web services (unused on pipshed `main`). C163's full rotation waits on Railway's report.

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `c3160e2` (s90d; tree `128ff157`) + s90e (this hand-over: the Argon prompt, docs). EA code `5bb5fdb` on B, C, D, E |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0` (never merged); `D:\mt5-replay\MQL5\Files\replay` holds the swcap run files and outputs (`swaps.csv` = EURUSD's `581dab22`) |
| Research | `research/opt_budget/` (simulator `sim.py`, 13 tests; runs, scores, PREREG, PREREG_B2, PREREG_CAP, results); `research/t3_drawdown/`; swcap in `research/replay/{inputs,results}/swcap/` |
| pipshed `main` | `b9d2d22` (A's card retired); strip B 9 / 9, C 6 / 6, D 12 / 12, E 12 / 12 |
| Linux boxes | wine-test, wine-c, wine-d, wine-e; MT5 6231 everywhere (LiveUpdate: Later, C161) |
| Bridge | ask again in a new chat: Downloads, `D:\fxmatrix-exports`, `D:\mt5-replay\MQL5\Files\replay` |
| Browser | the built-in browser has `linuxd`, `linuxe`, `pipshed.com` allowed (ask for `linuxc` before Monday's read); read pipshed there (s3) |

## 2. NEXT, IN ORDER

1. The operator applies s90e; tree checked; pushed.
2. The boot reply (above) and the previous chat's answers.
3. **Argon reviews the runbook.** The operator pastes ONE line to Argon (Cursor, repo access):
   `Read prompts/argon_review_c_t2.md on origin/main and do exactly what it says.`
   Argon commits `reviews/argon_review_c_t2.md` to `review/argon-c-t2`. Claude fetches it, counts its lines, checks
   EVERY quote against `origin/main` (never trust the verdicts), and amends the runbook by patch if needed.
4. **C's t2 reload Monday 26 Oct in session** (the runbook s2-s4; the operator runs it; EURUSD the pilot; the
   checker after each chart).
5. **Sun 25 Oct ~21:00Z on:** Sunday's open read (E's first weekend gap); the FTMO day rolls at 23:00Z.
6. **More Argon while the credits last** (the operator wants them used; one document at a time): candidates are a
   review of the cluster-measurement pre-registration and of B's repurposing scope. Propose; the operator picks.
7. Pre-register: the cluster measurement; E's first-week read (BEFORE it is read). Scope B's repurposing.
8. Later: C163's full rotation; GBPCHF tick dumps and sweep12; C160 (DUP on C) after ALT's first week (~Wed 28 Oct);
   C164 (Instant) parked unless ruled.

## 3. TRAPS (full list in 02_TRAPS)

- **`git am` re-hashes every commit:** the sandbox's hashes are not GitHub's. Reset the sandbox to `origin/main`
  before building the next patch; cite commits by message.
- **The fetch tool caches pipshed and can ignore the query string:** read pipshed in the built-in browser with a
  same-origin `fetch(..., {cache: 'no-store'})`; keep each script short (a 45 s timeout). The sandbox's shell cannot
  reach pipshed.com.
- **A roll closes nothing:** it sets a virtual level and moves the exit; the layer stays open (its loss is carried).
- **FTMO's daily loss counts carried floating losses:** day-start balance minus the day's lowest equity.
- **A background job split by `&` loses the `&&` chain's variables;** a `pgrep -f` wait loop matches itself.
- **The operator's times are EDT (Z - 4 until 1 Nov).** Read `date -u`.
- **Bulk files go to D:, never C:.**

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs; never ask for pasted logs or screenshots of
  fleet state: read pipshed (the built-in browser).
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Research:** tests first in their own commit (against a stub), the code, the pre-registration committed before any
  result is read; self-checks first; an amendment, if any, before any net. **The operator: anchor on the actual
  episode; do not let rigour "throw the baby out with the bath water".**
- **Argon:** a prompt committed to `main`, ONE line pasted; Argon commits its own reply on a review branch; Claude
  reads it from git and checks every quote.
- **pipshed changes:** Claude's reference build first; a tests-first Cursor prompt (RESTATE AND STOP); Claude reads
  Cursor's commits against the reference; the operator merges by fast-forward and pushes outside 20:50-21:00Z.
- **EA, generator or order-path changes:** a prompt in an artifact -> Argon -> Claude checks -> Cursor RESTATES AND
  STOPS -> "go" -> commits read -> the operator compiles -> the suite.
- **Deploys in market hours** (the operator, 25 Sep), never with the market closed.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 139
