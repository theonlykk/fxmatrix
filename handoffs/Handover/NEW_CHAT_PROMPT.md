This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-11-04 ~03:55Z (WED; D AND E BLEW UP ON 3 NOV; E's MT5 CLOSED; THE REVIEW FIRST)

**Prepared 4 Nov ~03:55Z in the s92 chat (HANDOFF s92 and its continued blocks 1-12; patches s92a-s92m).**
Since the last hand-over: C165 (E's request churn) fixed and live on all four fleets (27 Oct), confirmed at Sun 1
Nov's open (first hour E 17 requests against 1,089) and CLOSED. Three research answers, all no: Osler's round-number
test NONE / NONE; the magnet grid NONE; **four years of the t3 grid on minute bars: no edge** (OPT -$7,158, ALT +$800
after commission). **Tue 3 Nov: "fleet d and e blew up" (the operator).** E's broker book was empty while its EA
retried ~57,000 requests an instance; its MT5 was closed at 03:47Z 4 Nov. D still runs with an open book of -$473.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `replay-plan4` and `plan4-tools`. **If `main` has moved past s92m, this file is stale: say so and boot
from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block and the rows).
2. `handoffs/HANDOFF_2026-09-24.md` **s92 and all its "continued" blocks (1-12)**; follow the LAST NEXT SESSION.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-26** (both), **2026-10-27** and **2026-11-03**.
4. `research/longrun/results.md` (four years: no edge), `research/magnet/results.md`, `research/cluster/results.md`.
5. `docs/runbooks/c165-build-e.md` (how the fleets were rebuilt; s8 E, s9 the IC fleets).
6. `research/e_week1/PREREG.md` (E's first-week read, still owed; now overtaken by the review).
7. `handoffs/Handover/08_BACKLOG.md`: C167, C166, C165 (closed), C164, C162.
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what is live, what is stopped, and anything in
   the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in. **Do not restart E's MT5.**

---

## 0. THE MOST IMPORTANT FACTS

**Fleets now (pipshed 4 Nov ~03:45-03:50Z):**
- **B** (wine-test, IC 53066709): nine `_OPT`, 89 open layers, open -$304; LIVE, quiet. Its repurposing (8
  instances, cap 9) proposed, not ruled.
- **C** (wine-c, IC 53071896): six charts; t2 since 25 Oct (EURUSD OPT cap 9 add = exit 7; AUDCAD OPT cap 9 add =
  exit 18; GBPCHF OPT cap 9), the three ALT at t1, cap 7. 51 layers, open -$210; LIVE, quiet.
- **D** (wine-d, IC 53077984): twelve, the two-arm t1 set, cap 7. **LIVE, none halted, open -$472.50, 95 layers:**
  AUDCAD, AUDCHF, CADCHF both arms long 7 at the cap; GBPUSD both arms short 7; EURUSD short 5-6.
- **E** (wine-e, FTMO free trial 1515045375, $10k, $500 a day; twelve on `_t3`, cap 7, breaker OFF): **MT5 CLOSED
  03:47Z 4 Nov** (graceful `taskkill`). Before that: the broker book EMPTY on all 12 (0 positions, 0 orders), the
  EA's state still 95 layers, `api_count` ~57,000 an instance (~3,000 a minute for the terminal), `recon_ok` TRUE.
  Not yet verified: FTMO closed the positions and disabled the account; the EA retried every tick (cf. C167).
- EA code `bf832c0` (C165 merged) on B, C, D, E.

**The research verdict (31 Oct; `research/longrun/results.md`):** t3 on FTMO M1 bars, 2 Jan 2023 - 23 Oct 2026, six
pairs: scalps and rolled losses cancel pair by pair; commission makes OPT clearly negative; three of four years lose;
79% of twelve-month windows negative. The operator's hypothesis ("we are just monetizing mtm winners") TRUE: winners
closed in under an hour, losers held for days and paid through rolls. A first run with market fills at the bar
extreme (+$33k) was a flaw, found and withdrawn. **This is the input to the C162 go / no-go memo.**

**Vultr's maintenance (3 Nov 06:00-10:00Z) passed:** all four terminals ran through it; no reboot (`uptime`).

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `1418fe2` (s92l) + s92m (this hand-over: docs) |
| Research | `research/longrun/` (`run_bars.py --fill limit`, outputs, MANIFEST, results); `research/magnet/`; `research/cluster/` (v3.2); `research/e_week1/PREREG.md`; earlier `research/opt_budget/` (`sim.py`: its market-fill deal line is the flaw on bars) |
| Reviews | `review/argon-c165`, `review/deepseek-c165`, `review/argon-cluster*`, `review/argon-e-week1` (each one file, never merged) |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0` (never merged) |
| pipshed `main` | `b9d2d22`; same-origin API `/api/g/k7m9p2x4q/status/<cachebuster>` on `linuxc`, `linuxd`, `linuxe`; B at `pipshed.com` `/status_b/<cachebuster>` |
| Data | FTMO M1 bars 2023 - 23 Oct 2026, seven pairs, `D:\fxmatrix-exports\bars_ftmo`; archive exports `D:\fxmatrix-exports\api_burst\` |
| Bridge | ask again in a new chat: Downloads, `D:\fxmatrix-exports` |
| Browser | the built-in browser: `linuxc`, `linuxd`, `linuxe`, `pipshed.com` allowed; WebFetch is NOT allowed on pipshed |
| Argon | Gemini 4 Argon in Antigravity, project `D:\fxmatrix`; it can leave the desktop on its review branch (02_TRAPS 26 Oct) |

## 2. NEXT, IN ORDER

1. The operator applies s92m; tree checked; pushed.
2. The boot reply and the previous chat's answers.
3. **THE REVIEW OF D AND E (3 Nov):** for each, the timeline from the archive (`--export-snapshots`, 3 Nov, equity,
   open book, rolls, closes per hour), the move (pairs, pips, times). For E: when the book emptied, FTMO's journal
   line and the first rejected request (grep wine-e's terminal and `MQL5/logs/<date>.log` with `iconv -f UTF-16LE`),
   the account's state, and whether the C167 path drove the storm (in source). Anchor on the episode itself.
4. What the EA must do when the broker rejects everything (halt, not retry): a design question, through the pipeline.
5. **The decision memo (C162):** the four-year result, the live weeks, D and E's day.
6. Later: B's ~94 layers; C's t2; C166; E's first-week read if still wanted.

## 3. TRAPS (full list in 02_TRAPS)

- **pipshed's LIVE and `recon_ok` do not catch an emptied broker book:** compare positions + orders with the layers;
  watch `api_count`.
- **`git am` re-hashes every commit:** the sandbox's hashes are not GitHub's. Reset to `origin/main` before the next
  patch; cite commits by message. Before any patch: `cd D:\fxmatrix; git switch main; git branch --show-current`.
- **PowerShell eats braces:** quote `"HEAD^{tree}"`.
- **Read logs by grep, never the scrolling Experts tab:** wine boxes `iconv -f UTF-16LE`; the desktop
  `Select-String -Encoding Unicode`.
- **Bars are not ticks:** a simulated limit fills at its own price, never at the bar's extreme.
- **The FTMO day rolls at 23:00Z; the brokers' day (GMT+2) at 22:00Z.** The operator's times are EST (Z - 5).
- **Large bridge files one per call** (four 93 MB in one call timed out). Bulk files go to D:, never C:.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs; never ask for pasted logs or screenshots of
  fleet state: read pipshed (the built-in browser).
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Argon:** a prompt committed to `main`, ONE line pasted in Antigravity; Argon commits its own reply on a review
  branch; Claude counts its lines, checks EVERY quote by script against the source, checks findings in source.
- **Research:** tests first in their own commit (against a stub), the code, the pre-registration committed before any
  result is read; self-checks first. **The operator: anchor on the actual episode; do not let rigour "throw the baby
  out with the bath water"; and remember the tea leaves.**
- **EA, generator or order-path changes:** a prompt in an artifact -> Argon -> Claude checks -> Cursor RESTATES AND
  STOPS -> "go" -> commits read -> the operator compiles -> the suite. **Deploys in market hours,** never closed.
- **Live actions:** the runbook, the pilot slowly ("i do make mistakes tho when i rush"); confirm each step by grep and
  from pipshed. Stopping a terminal: graceful `wine taskkill /IM terminal64.exe`, never `/F`.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 121
