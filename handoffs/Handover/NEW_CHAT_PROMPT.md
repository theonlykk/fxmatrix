This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-21 ~03:30Z (WEDNESDAY: BUILD DAY; PLAN 4 PASSED; A AND THE WINDOWS VPS CLOSE TONIGHT)

**Prepared 21 Oct ~03:30Z at the end of the s86 session (HANDOFF s86 and its continued blocks 1-10; patches
s86a-s86k).** **Plan 4 PASSED at timing 1** (`docs/research/replay-calibration-eurusd-4.md` s10): T1 B 98.2%,
C 99.1%, D 99.2% on a window nobody saw; the replay is fit for count-level use on EURUSD. **Today is build day:**
D, then C, in market hours; tonight A and the Windows VPS close and FTMO's fleet E starts on a new server wine-e.

**What the s86 session did (in order):** booted from s85o (s86a); **C158 RULED** (wine-e, a new Linux + wine server
from wine-d's recipe; a new FTMO demo; A to the end of Wednesday's session, then the VPS closed); "why are we
waiting?" answered: **the replay is this cycle's goal, the plan stood**; **E's runbook** drafted and REVIEWED (Argon
`3fb2523`, all 76 quotes exact; s86b-c); **plan 4's export runbook** drafted and REVIEWED (Argon `6f87f69`, committed
by the operator after Argon ran out of credits; s86d-e); **A removed after its trial: fleets B, C, D, E**; Sunday's
A read (after the open; clean); **C160 logged** (a DUP arm on C's broken ring, after ALT's first week; s86f); the
Monday and Tuesday carry passes (s86g); **the window exported and hashed** (s86h; `bad_px=0`, not 1: IC restored
the tick); **the scoring** (s86i-j: inputs built with the frozen builders, twelve runs, compare, score: **PASS**);
docs refreshed and this handover (s86k).

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone `https://github.com/theonlykk/fxmatrix` and
`https://github.com/theonlykk/pipshed` into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `replay-plan4`, `plan4-tools` and the `review/*` branches. **If `main` has moved past s86k, this file is
stale: say so and boot from the LAST NEXT SESSION in the HANDOFF.**

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6 the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s86 and all its "continued" blocks (1-10)**; follow the LAST NEXT SESSION.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-17** to **2026-10-21**.
4. **The three REVIEWED build runbooks** (each one's last section records its review): `docs/runbooks/twoarm-build-d.md`,
   `twoarm-build-c.md`, **`twoarm-build-e.md`** (wine-e, A's records, the VPS's close, E's twelve charts).
5. `docs/research/fleet-d-two-arm-ring-2026-10-16.md` s10-s12 (the layout, the geometry, the reload path).
6. `docs/research/replay-calibration-eurusd-4.md` s5, s6 and **s10 (the result)**.
7. `handoffs/Handover/08_BACKLOG.md`: C88, C106, C150, C152, C154, C157-C160.
8. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, **which of today's builds are done** (ask if the
   docs do not say), the time to the next time-gated step, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready to copy across in ONE block, at most ~12, each
   answerable in a line.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Build day, Wed 21 Oct (one fleet at a time; each by its REVIEWED runbook; one step a message):**
1. **D (wine-d) in market hours, about 12:00-16:00Z** (`twoarm-build-d.md`): retire NZDCHF, NZDCAD, AUDNZD; reload the
   six OPT charts with `_t1` (exit = add, cap 7); attach six ALT charts.
2. **C (wine-c) after D's checks are clean** (`twoarm-build-c.md`): compile the Experts copy; retire seven; re-attach
   EURUSD and AUDCAD OPT from Experts (C88 closes); attach GBPCHF OPT and three ALT.
3. **pipshed `twoarm-fleets` `320afe6` merged after D AND C** (a fast-forward of `fb0f9c8`; outside 20:50-21:00Z);
   then the Railway service "pipshed Fleet E" (`linuxe.pipshed.com`; D's runbook s7).
4. **20:50-20:59Z the carry pass** (all fleets; A's last).
5. **From ~21:00Z (5 PM ET): A off and its records, then the Windows VPS's records and its close** (`twoarm-build-e.md`
   s3-s4; the VPS is destroyed by the operator only after s4.1-4.2 are clean; a snapshot suggested).
6. **The new FTMO free trial** ($10k, 14 days; opened by the operator, never by Claude; the old one may have to be
   closed first) and **wine-e built Wednesday afternoon or sooner** (ruled 21 Oct: option (a); E's runbook s1).
7. **E's twelve charts from 22:05Z** (s5-s7: login read by grep; the suite once; spreads at most 1.5 x OPT width; pilot
   GBPUSD OPT, five OPT, six ALT, one check each); **E's pipshed card** by Claude's small patch after the pilot (s9;
   no Argon). If the build slips past the night, E's first chart is Thu 22:05Z (the trial's days run from the
   first trade).

**THE CAP RULE (every cap-cut reload; the stranded add):** both sides at **6 layers or fewer, counted in the Trade tab**
immediately before; after the reload **no resting `|L07|ENT`** (delete it by hand). A side above 7 halts on I7.

**Fleets until tonight:**
- **A** (Windows VPS 149.28.123.38, FTMO free trial 1514878887, $10k): seven `_OPT`, EA `5bb5fdb`, **breaker OFF since
  16 Oct** (the repo presets say true: **never load A's presets**). Ends tonight; its pipshed card stays (CONNECTION
  LOST) until a later prompt retires it.
- **B (wine-test, IC 53066709), C (wine-c, 53071896), D (wine-d, 53077984):** nine each, EA `5bb5fdb`, round 3
  geometry, roll gate 0, re-roll on, breaker off. **Plan 4's window closed Tue 22:00Z: the freeze is over.**
  **Never log out an IC terminal** (C150: the web login refused since 12 Oct).

**From tonight (fleet D note s10-s11; presets `ea/presets_{c,d,e}/*_t1.set` on `main`):**

| Fleet | Pairs | Arms, cap | Instances |
|---|---|---|---|
| E (FTMO, new demo, wine-e) | EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF | OPT + ALT q90, cap 7 | 12 |
| D (wine-d): E's mirror | the same six | OPT + ALT q95, cap 7 | 12 |
| C (wine-c): broken ring | EURUSD, GBPCHF, AUDCAD | OPT + ALT q95, cap 7 | 6 |
| B (wine-test): control | unchanged | OPT, cap 8 | 9 |

Geometry (exit = add on both arms): OPT EURUSD 7, GBPUSD 9, EURGBP 3, AUDCAD 6, AUDCHF 4, CADCHF 4, GBPCHF 9; ALT on E
(q90) 23, 24, 16, 27, 21, 9; ALT on D and C (q95) 27, 30, 19, 27, 22, 12, GBPCHF about 24.

**Operator rulings (do not re-open):**
- Exit = add on both arms; a kept chart may be flattened for a fresh start ("these are demo accounts").
- FTMO's request budget about 2,500 a day for 12 instances (C106): watch the count; report any FTMO email.
- q90 on E, q95 on D and C ("lets just see if there is a material difference"); ALT from price ranges where no fills.
- **A removed after its trial; next week's fleets B, C, D, E.** wine-e from wine-d's recipe, UTC, one terminal.
- **The replay is this cycle's goal** (the plan stood on 18 Oct for it); it PASSED.
- pipshed's E card by a config patch without Argon; E's runbook and every order-path document through Argon.
- C160 (DUP on C) only after ALT's first week. No time-series analysis or price signals; the lazy rolled exit
  REJECTED.

**The replay after plan 4 (s10; what it may be used for):** count-level (scalps, roll closes, roll acceptances per
side) on **EURUSD, IC's feed, at timing 1**, for geometries near those tested (B, C, D: add 7, exit 9-11, cap 8; ALT
at 23-27 pips is outside: a guide, confirmed live), in markets **without a scheduled-release burst**; rankings
confirmed live. Timing 0 still FAILS (C154): every run `-Timing 1`. Next uses: ALT's add 2x against 3.5x on
EURUSD; C160's DUP; one pre-registered question at a time.

**From Sun 25 Oct the FTMO day rolls at 23:00Z** (Prague leaves summer time): every fleet's `DAILY_SNAPSHOT` moves an
hour; brokers' midnight (21:00Z) and the carry window stay until the US change on 1 Nov (inferred: re-check).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `1e58d6f` (s86j) + s86k (this patch). EA code `5bb5fdb`, live on A, B, C, D. `_t1` presets fingerprints D `eb0d6a097694` (12), C `72ba0e3c19f6` (6), E `a448f4abb8a6` (12) |
| Replay | harness `replay-plan4` `8044284`, builders `plan4-tools` `a335ef0`: **plan 4 closed, PASS**; never merged. Window inputs `research/replay/inputs/eurusd_window_p4/`, runs `research/replay/runs_window_p4/`, scores `research/replay/results/plan4/window_*`. `D:\mt5-replay` holds the `8044284` build and the window set; the joined ticks `ticks_53077984_EURUSD_w2hw.csv` (`93816e45...6c81`, not in git) in `Files\replay` |
| `review/*` (s86) | `argon-runbook-e` `3fb2523`, `argon-plan4-export` `6f87f69`; older as BOOT |
| pipshed `main` | `fb0f9c8`; **`twoarm-fleets` `320afe6` verified and PARKED** (merge after D AND C) |
| Desktop | `D:\fxmatrix` on `main`; untracked leftovers `research/replay/_fix6_prompt_read.txt`, `research/replay/runs/` (ignore) |
| Linux boxes | wine-test, wine-c, wine-d: repos at `9425141` (the runbooks pull `main` first); git as `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...`. wine-e: not built yet |
| Bridge | Claude saves patches straight to `~/Downloads` (a NEW name each time; test a name by staging it: "does not exist" is the answer); the operator checks `Get-FileHash`; folder grants this session: Downloads, `D:\mt5-replay\MQL5\Files\replay`, `D:\fxmatrix\research\replay\runs`, `D:\fxmatrix\reviews` |

## 2. NEXT, IN ORDER

1. The operator applies s86k; tree checked; pushed.
2. **D's build** (market hours), then **C's**, then pipshed's merge and the Railway E service.
3. 20:50-20:59Z the carry pass; then **A off, its records, the VPS's records and close**; the new FTMO trial; wine-e
   (built in the afternoon by E's s1); **E from 22:05Z**; E's pipshed card patch after the pilot.
4. Thu 22 Oct: E's first FTMO day (requests: tell Claude above 1,700 by 14:00Z or 2,000 a day; E's first
   `DAILY_SNAPSHOT` reads `start_known` false: expected).
5. **Hand over again after the builds** if this chat is long; docs refreshed in the patch that hands over.
6. After E settles: A's pipshed card retired (a small prompt: A's ids are fixtures in pipshed's checks).
7. The replay's first uses (a pre-registered question each): ALT 2x against 3.5x on EURUSD; C160. C154 when time
   allows. After ALT's first week: C160 on C. After the trial: C153, C155, C156.

## 3. TRAPS (full list in 02_TRAPS)

- **A cap cut strands the next add** (above); **Remove-then-Attach** (C's re-attach): one `STARTUP_EXIT_SHORTFALL` per
  side allowed with its `|EXT` resting; 2 is a STOP. **An exit change on a reload is supported** (the exit label GV);
  never move a live chart to a new terminal.
- **An empty side's L0 is placed once** and not re-centred until a fill: attach only in normal spreads (E's s7 hold).
- **The desktop shell is PowerShell:** `Get-FileHash`; quote `'HEAD^{tree}'`; `$HOME\Downloads`; `;` not `&&`; quote
  comma lists (`--codes "A,B,C"`); read the header line back before trusting "none.".
- **Argon:** leaves the operator's copy on its review branch (start every patch step with `git status -sb`; `git switch
  main`); can run out of credits before committing (read its file from the desktop, then the operator commits it on
  its branch). **Check every quoted block by script against the reviewed commit** (76 / 76 on E's runbook, 5 of 49
  invented on the export runbook); its self-reported line count is wrong.
- **One `git am` per command line;** build every patch on a fresh fetch and test `git am` on a fresh clone; never reuse
  a patch name.
- **A later dump of the same span can differ** (IC corrects its history); **a dump after 00:00Z logs to the next UTC
  day's file.**
- **The handoff's stamps can run ahead of the clock:** read the clock before a time-gated step; give a time-gated step
  only when its time has come.
- **An archive's OUT_BY rows carry the OTHER position's entry as `deal_price`:** never a market price.
- **E's first `DAILY_SNAPSHOT` has `start_known` false** (it attaches after the rollover): expected.
- Your sandbox: `.md` files check out CRLF; the run outputs are LF in git.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs (`Select-String`, or `iconv | grep` over
  ssh); never ask for pasted logs. pipshed URLs in plain text, pasted by the operator (the fetch tool takes only
  pasted URLs; change the last segment every fetch).
- **Docs and small fixes:** Claude commits in its sandbox, `git format-patch`, checks `git am` on a fresh clone of
  GitHub's `main`, saves the patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it and gives the
  tree. The operator runs `git am`, checks the tree and pushes. **Claude never pushes.**
- **Replay, EA or generator changes:** a prompt in an artifact (questions for the reviewer inside it) -> Argon
  (commits its reply to `review/<name>`, quotes with file and lines; an unquoted or misquoted claim is void) ->
  Claude checks every point -> Cursor RESTATES AND STOPS -> Claude checks the restate -> "go" -> Claude reads the
  commits -> the operator compiles -> the suite -> runs -> Claude reads the outputs.
- If Cursor drifts from a prompt, the prompt was not good enough: fix the prompt.
- One document at a time for review. One paste per step. Count every line mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 175
