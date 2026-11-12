This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-11-12 ~04:40Z (THU; WOUND DOWN 8 NOV; FLEET C ON WINE-C THE ONE LIVE FLEET)

**Prepared 12 Nov ~04:40Z in the s93 chat (HANDOFF s93, its continued blocks 1-11 and the hand-over block;
patches s93a-s93m).** Since the last hand-over (s92m, 4 Nov): the review of D and E (E breached FTMO's $500 daily
loss on 4 Nov; its EA then sent ~465 refused requests a minute); **the no-carry test: NO EDGE**; **the C162 memo,
ruled 8 Nov: WIND DOWN** ("it is tough to stomach but yes i think we have to wind this effort down"); wine-test,
wine-d and wine-e archived, verified and **destroyed 10 Nov**; pipshed's archive and send logs exported; **Fable
5.2's blind review: NO for 9 of 12 arms**, reached without seeing our results; its two tests, both against the
strategy: live fills measured, and **its one positive region (AUDCAD wide rungs) FAILS out of sample.**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first.
**If `main` has moved past s93m, this file is stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block and the rows).
2. `handoffs/HANDOFF_2026-09-24.md` **s93, its "continued" blocks 1-11 and "s93 hand-over"**; follow the LAST
   NEXT SESSION.
3. `docs/research/c162-go-no-go-memo-2026-11-08.md` (the ruling row and "What argues the other way").
4. `research/nocarry/results.md`; `reviews/fable_pass1/report_prose.md` (and `MANIFEST.md`);
   `research/fills/results.md`; `research/audcad_oos/results.md` (and its `PREREG.md` s2a).
5. `docs/runbooks/winddown-export.md` s8 (AS RUN) and `docs/runbooks/winddown/pipshed/EXPORTS.md`.
6. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-11-03**, **2026-11-10** and **2026-11-12**.
7. `handoffs/Handover/08_BACKLOG.md`: **C0** (C168-C171, the live list), C167, C162 (closed).
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what is live, what is closed, and anything in
   the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**The effort is wound down (C162, option A, 8 Nov).** What the operator kept: pipshed not going dark, by **both** a
small fleet and a tick recorder ("what about 1 and 2, run fleet c on one more ftmo demo?").

**Fleets now:**
- **C** (wine-c, IC demo 53071896; EA `bf832c0`): six charts; t2 since 25 Oct (EURUSD OPT cap 9 add = exit 7;
  AUDCAD OPT cap 9 add = exit 18; GBPCHF OPT cap 9), the three ALT at t1, cap 7. **The one live fleet;** its state
  was not read for this hand-over: read pipshed (the built-in browser) before saying anything about it.
- **B, D, E: CLOSED.** wine-test (B) destroyed 05:05Z 10 Nov, wine-d (D) 05:21Z, wine-e (E) 05:48Z, each after four
  MATCH lines. Archives (core, cache, appdata; manifest; sha256) on the desktop, `D:\fxmatrix-exports\winddown\`.
  B's and D's deal histories 19,488 and 20,549 deals; E's skipped (its login not to hand; the trade database and
  logs are in its archive). E's MT5 never ran again after 4 Nov. D's and B's IC demo accounts were left as they are.

**Why E ended (4 Nov, HANDOFF s93):** FTMO's daily loss counts from the day-start BALANCE; E's carried book had used
$380 of the $500 before the day began; at 01:36:55Z FTMO closed all 95 positions (loss $505.35). The EA re-sent
every refused order on every tick (`[Trade disabled]`, retcode 10017): 57,918 refused sends kept in pipshed's export.
**Nothing in the EA tests 10017 or the account's trade permission** (`Grind_PlaceLimit`, `ea/grind_engine.mqh`
1442-1467, and its callers). That is C168, **needed before C trades on any FTMO account.**

**The research, all no:** four years of the t3 grid on minute bars (`research/longrun/`); no carry (DAY -$22,711,
WEEK -$13,488, CONT -$6,358); Fable blind (9 of 12 arms no; three bar artefacts as big as the effect); live fills
+0.09 to +0.13 pip on average, a sixth worse than the limit; AUDCAD wide rungs 2020-2022 -16.04 USD a month (t -0.97),
0 of 10 cells positive. **Fable's region is closed;** the live remainder, if any, runs C's t2 as planned.

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `a7ee2f1` (s93l) + s93m (this hand-over: docs) |
| Research | `research/nocarry/`, `research/fills/`, `research/audcad_oos/` (each: PREREG where pre-registered, runner, tests, self-checks, MANIFEST, results); `reviews/fable_pass1/` (Fable's report, scripts, outputs; four big CSVs on the desktop only); earlier `research/longrun/`, `research/magnet/`, `research/cluster/` |
| Reviews | `review/argon-nocarry`, `review/argon-c162-memo`, `review/argon-winddown`, `review/argon-audcad-oos` (FAILED its quote check), `-oos-2`, `-oos-3` (each one file, never merged) |
| Tools | `tools/winddown/` (`archive_box.sh` + 9 tests, `extract_ticks.py`, `export_sends.ps1`) |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0` (never merged) |
| pipshed `main` | `b9d2d22`, unchanged; C's page on `linuxc` (same-origin API `/api/g/k7m9p2x4q/status/<cachebuster>`); B's, D's and E's pages show their last data (C171) |
| Data | FTMO M1 bars 2023 - 23 Oct 2026, seven pairs, `D:\fxmatrix-exports\bars_ftmo`; AUDCAD 2018-2022 `bars_ftmo_2018\`; Fable's cell tables `fable_review\out\`; the wind-down `winddown\` (boxes and `pipshed\`) |
| Bridge | ask again in a new chat (it was Downloads and `D:\fxmatrix-exports`) |
| Browser | the built-in browser: `linuxc` and `pipshed.com` allowed; WebFetch is NOT allowed on pipshed |
| Argon | Gemini in Antigravity, project `D:\fxmatrix`; it can leave the desktop on its review branch (02_TRAPS 26 Oct) |

## 2. NEXT, IN ORDER

1. The operator applies s93m; tree checked; pushed.
2. The boot reply and the previous chat's answers.
3. **The operator chooses the order (or stops here, with C on IC the one running fleet):**
   - **C168 stop on refusal** (an order-path change, the full pipeline, DeepSeek included): halt, not retry, when
     the broker refuses every order; and why reconciliation kept 95 layers against an empty book with `recon_ok`
     true. Widens C167. **Before C trades on FTMO.**
   - **C169 the tick recorder** on wine-c's terminal for the six pairs, and what pipshed needs to show it.
   - **C170 C on a new FTMO demo** on wine-c (the operator opens it; C's t2; then C's IC terminal closes). Keep
     build 6231's binaries (C161: 6274 does not start under Wine 9.0).
   - **C171 pipshed after the wind-down:** the closed fleets' pages; `state_snapshots` exported in weekly pieces (no
     retention, not yet exported); MetriX's CSV for E (optional).

## 3. TRAPS (full list in 02_TRAPS)

- **A breached FTMO account refuses everything and the EA retries every tick;** pipshed's LIVE and `recon_ok` do
  not catch an emptied book: compare positions + orders with the layers; watch `api_count`.
- **Under Wine, `pgrep` does not find MT5 by name:** `pgrep -af [t]erminal64`; check for a forgotten MetaEditor.
- **Agents invent quotes:** Argon's first AUDCAD review (29 of 122 real). Check every quote by script; reject.
- **FTMO's stored pre-2020 history has wide spreads** (AUDCAD median 1.4 / 4.0 pips in 2018 / 2019): check spreads
  by year before using old bars.
- **`git am` re-hashes every commit:** the sandbox's hashes are not GitHub's. Reset to `origin/main` before the next
  patch; cite commits by message. Before any patch: `cd D:\fxmatrix; git switch main; git branch --show-current`.
- **PowerShell eats braces:** quote `"HEAD^{tree}"`. PowerShell 5.1's `Out-File utf8` writes a BOM, `Tee-Object`
  UTF-16.
- **Bars are not ticks:** a simulated limit fills at its own price, never at the bar's extreme.
- **The FTMO day rolls at 23:00Z; IC's (GMT+2) at 22:00Z.** The operator's times are EST (Z - 5).
- **Large bridge files one per call.** Bulk files go to D:, never C:.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs; never ask for pasted logs or screenshots of
  fleet state: read pipshed (the built-in browser) and files through the bridge.
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Argon:** a prompt committed to `main`, ONE line pasted in Antigravity; Argon commits its own reply on a review
  branch; Claude counts its lines, checks EVERY quote by script against the source, checks findings in source.
- **Research:** pre-registration, Argon, tests first against a stub, the runner, self-checks committed before any
  result, the decision rule fixed in advance. **The operator: anchor on the actual episode; do not let rigour
  "throw the baby out with the bath water".**
- **EA, generator or order-path changes:** a prompt in an artifact -> Argon -> Claude checks -> Cursor RESTATES AND
  STOPS -> "go" -> commits read -> the operator compiles -> the suite. **Deploys in market hours,** never closed.
- **Live actions:** a runbook, the pilot slowly ("i do make mistakes tho when i rush"); confirm each step by grep and
  from pipshed. Stopping a terminal: graceful `wine taskkill /IM terminal64.exe`, never `/F`.
- **Review carefully before any distribution** of a write-up (the memo is an internal record).
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 132
