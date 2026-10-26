This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-26 ~05:45Z (MON; C's t2 LIVE; THE OSLER RUN NEXT; E's REQUEST CHURN C165)

**Prepared 26 Oct ~05:45Z in the s91 chat (HANDOFF s91 and its continued blocks 1-11; patches s91a-s91m).**
25 Oct: C's three OPT charts reloaded to t2 (EURUSD, AUDCAD, GBPCHF at cap 9; AUDCAD add = exit 18), every check
clean; E's request burst at Sunday's open diagnosed (C165); E's first-week read and the round-number study
pre-registered and reviewed by Argon (now Gemini 4 Argon in Google's **Antigravity**: Cursor's credits ran out).
26 Oct: four years of FTMO minute bars dumped; `research/cluster/osler.py` (tests first) committed; **the run is next.**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `replay-plan4` and `plan4-tools`. **If `main` has moved past s91m, this file is stale: say so and boot
from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block, the
   fxmatrix main, Fleet C, Fleet E and Next rows).
2. `handoffs/HANDOFF_2026-09-24.md` **s91 and all its "continued" blocks (1-11)**; follow the LAST NEXT SESSION.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-25** (early; day) and **2026-10-26**.
4. `research/cluster/PREREG.md` (v3.1, the Osler replication), then `research/cluster/osler.py` and its tests.
5. `research/e_week1/PREREG.md` (E's first-week read, after Fri 30 Oct's close).
6. `docs/runbooks/twoarm-reload-c-t2.md` (C's t2: Status DONE; s5 the rollback).
7. `handoffs/Handover/08_BACKLOG.md`: C165, C166, C164, C163, C162, C160.
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what is live, the time to the next time-gated
   step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Fleets now:**
- **B** (wine-test, IC 53066709): nine `_OPT`, about 94 open layers; its repurposing (8 instances, cap 9) proposed,
  not ruled (the guard: 176 against 186 only with the old layers gone).
- **C** (wine-c, IC 53071896): six charts; **t2 since 25 Oct 22:30-22:46Z: EURUSD OPT cap 9 (add = exit 7), AUDCAD
  OPT cap 9 with add = exit 18 (width 4.5, stranded 5.5), GBPCHF OPT cap 9 (add = exit 9; never replayed: a live
  test)**; the three ALT at t1, cap 7. Fingerprint `f8d65e41f089` (3 files). Rollback (runbook s5) only when both
  sides hold 6 or fewer, else flatten.
- **D** (wine-d, IC 53077984): twelve, the two-arm t1 set, cap 7. No cap 9 on D (the guard).
- **E** (wine-e, FTMO free trial 1515045375, $10k, $500 a day): twelve on `_t3`, cap 7, breaker OFF, since 23 Oct;
  the trial runs to about Fri 6 Nov. "E stays as it is" (the operator); stepping in near $500 his call, NOT ruled.
  **The FTMO day rolls at 23:00Z since 25 Oct** (Prague's winter time); the brokers' midnight stays 21:00Z until
  ~1 Nov (to re-check then).

**C165 (E's request churn), the open defect:** Sunday's open took E's terminal to 1,672 requests (FTMO's limit 2,000
a day; repeated alerts disable the account). ~1,550 came from three resting adds whose ADR-013 clamp chases the
spread: the deadband is compared with the CLAMPED price (`grind_engine.mqh` 2549-2573), so every spread swing over 2
pips re-sends (EURGBP OPT's short add: 1,033 modifies in 70 minutes). B 1,908 and D 3,384 the same night (IC, no hard
limit). **Watch E at each Sunday open and the 21:00Z rollover;** the fix is an EA change through the full pipeline.

**The round-number study (the operator's lead idea, 26 Oct):** "if this is random walk ... we are just trying to read
tea leaves"; Osler found take-profits clustering at round numbers (reversals there) and stop-losses just beyond
(crossings run on). `research/cluster/PREREG.md` v3.1 replicates her test (round = 00 / 50; hit within 0.01%;
reversal or crossing at 15 minutes; arbitrary levels; common 10-day calendar blocks; sign test), on **FTMO M1 bars 2
Jan 2023 - 23 Oct 2026, seven pairs, in `D:\fxmatrix-exports\bars_ftmo` (hashes in s3; NOT READ YET)**, decided in
BOTH halves (2023-24, 2025-26). If it holds: a round-aware lattice (dense adds approaching 00 / 50, wider after a
crossing) gets its own simulator pre-registration.

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `bf3e94e` (`osler.py`) + s91m (this hand-over: docs). EA code `5bb5fdb` on B, C, D, E |
| Research | `research/cluster/` (PREREG v3.1, `osler.py`, 17 tests); `research/e_week1/PREREG.md`; earlier `research/opt_budget/`, `research/t3_drawdown/` |
| Reviews | `review/argon-c-t2`, `-c-t2-gbpchf`, `-e-week1`, `-cluster`, `-cluster-v2`, `-cluster-v3` (each one file, never merged) |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0` (never merged) |
| pipshed `main` | `b9d2d22`; strip B 9 / 9, C 6 / 6, D 12 / 12, E 12 / 12 |
| Data | FTMO M1 bars as above; IC tick history on wine-d only from 2 Jan 2026 (GBPUSD, EURGBP, AUDCAD, AUDCHF) / 1 Apr 2026 (EURUSD, CADCHF, GBPCHF); wine-d's MT5 caps bars at 100,000 |
| Bridge | ask again in a new chat: Downloads, `D:\fxmatrix-exports` |
| Browser | the built-in browser: `linuxc`, `linuxd`, `linuxe`, `pipshed.com` allowed; read pipshed with a same-origin `fetch(..., {cache: 'no-store'})` |
| Argon | Gemini 4 Argon in Antigravity (the operator's Google AI Pro), project `D:\fxmatrix`; Security preset Default (Custom with deny rules discussed) |

## 2. NEXT, IN ORDER

1. The operator applies s91m; tree checked; pushed.
2. The boot reply and the previous chat's answers.
3. **The Osler run on the desktop** (`D:\fxmatrix`; Python with numpy; check `python -c "import numpy"` first):
   `python research\cluster\osler.py --data D:\fxmatrix-exports\bars_ftmo --out D:\fxmatrix-exports\osler_out --stage selfcheck`;
   only if it prints `SELFCHECK: PASS`, the same with `--stage real`. Claude reads `selfcheck.txt`,
   `summary.json` and `pair_blocks.csv` through the bridge, commits them with a hash manifest, writes `results.md`.
4. **C165: the Cursor prompt** (tests first, RESTATE AND STOP; Argon reviews), then compile, suite, deploy in market
   hours.
5. C's t2 watched: the 8th and 9th OPT layers; AUDCAD's first scalps at 18; GBPCHF's cap 9.
6. After Fri 30 Oct's close: E's first-week read (its PREREG s3 exports, `read.py` tests first).
7. Later: C166 (pipshed's card day); C163's full rotation; the operator's calls (E near $500; DUP for ~Wed 28 Oct;
   swcap's log self-check; B's ~94 layers).

## 3. TRAPS (full list in 02_TRAPS)

- **`git am` re-hashes every commit:** the sandbox's hashes are not GitHub's. Reset to `origin/main` before the next
  patch; cite commits by message.
- **Read logs by grep, never the scrolling Experts tab** (the operator, 25 Oct): wine boxes `iconv -f UTF-16LE` the
  day's `MQL5/logs/<date>.log`; the desktop `Select-String -Encoding Unicode`.
- **pipshed: balance and equity come from ONE reporter instance per account** (`grind_mae.mqh` 314-326); the cards
  show zero scalps from 21:00Z to 23:00Z this week (C166: a display window, not missing fills).
- **A clamped add chases the spread** (C165); a long exit clamped passive rests at ask + the minimum distance.
- **The FTMO day rolls at 23:00Z; the brokers' midnight 21:00Z** (until ~1 Nov).
- **Bulk files go to D:, never C:.** The operator's times are EDT (Z - 4 until 1 Nov). Read `date -u`.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs; never ask for pasted logs or screenshots of
  fleet state: read pipshed (the built-in browser).
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Argon:** a prompt committed to `main`, ONE line pasted in Antigravity; Argon commits its own reply on a review
  branch (with line-count bookends); Claude counts its lines, checks EVERY quote by script against the source at the
  base, checks the substantive findings in source, then applies them by patch.
- **Research:** tests first in their own commit (against a stub), the code, the pre-registration committed before any
  result is read; self-checks first; an amendment, if any, before any net. **The operator: anchor on the actual
  episode; do not let rigour "throw the baby out with the bath water"; and remember the tea leaves.**
- **Live reloads:** the runbook, reviewed; the pilot slowly ("i do make mistakes tho when i rush"), then quicker;
  Remove then Attach; Claude confirms each step from the box's log by grep and from pipshed.
- **EA, generator or order-path changes:** a prompt in an artifact -> Argon -> Claude checks -> Cursor RESTATES AND
  STOPS -> "go" -> commits read -> the operator compiles -> the suite. **Deploys in market hours,** never closed.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 130
