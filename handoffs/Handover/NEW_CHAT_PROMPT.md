This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-14 ~20:00Z (WEDNESDAY; PLAN 4: F1-F4 IMPLEMENTED BY CURSOR, THE COMMIT REVIEW NEXT)

**Prepared 14 Oct ~20:00Z (HANDOFF s82 continued 2; the s82 chat ran out of
space).** The EURUSD replay (an MQL5 harness on the EA's own engine, branch
`replay-harness`, never merged) FAILED plan 3 on T1 (C 94.4%, D 94.9%;
`docs/research/replay-calibration-eurusd-3.md` s7 note). Every miss is
explained: five at the Mon 12 Oct open (IC trades from 00:01; the harness
defeats the stale-feed guard), three first shorts (sync drops the layer at
EXT), one D L7 (the start-up reprice flags set by every sync reset).
**Plan 4** (`docs/research/replay-calibration-eurusd-4.md`, REVIEWED and
AGREED) asks the same question on a NEW window, Fri 16 Oct 00:00 to Wed 21
Oct 01:00 server, with the harness `145f092` + fixes F1-F4, frozen by one
amendment before the export.

**Since the s82 boot (all in HANDOFF s82 and its "continued" blocks):**
- Plan 3 s7 run and scored: FAIL. The operator: "why not work a bit more on
  that?" -> a consult with Argon (Gemini 4, in Cursor with repo access),
  `docs/research/replay-consult-plan4.md` s0-s12 -> plan 4.
- **The F1-F4 Cursor prompt** (`prompts/cursor_plan4_f1f4.md` at `3738152`):
  Part A (Python builders, branch `plan4-tools` from main), Part B (harness,
  branch `replay-plan4` from `replay-harness` `efada62`), tests first. Through
  Argon rounds 4-5, every point accepted.
- **Cursor's restate** (`review/cursor-restate`, `reviews/cursor_restate_f1f4.md`):
  RT65 corrected (`e4d96f4`) and checked. **"go" given ~19:50Z.** Cursor
  finished ~20:00Z and pushed both branches (s1 has the SHAs). **Nothing
  of it has been read yet.**

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first,
including `plan4-tools`, `replay-plan4` and the `review/*` branches.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s1-s5 the pipeline and conventions; s6
   the state: its first block).
2. `handoffs/HANDOFF_2026-09-24.md` **s82 and all its "continued" blocks**;
   follow the LAST NEXT SESSION list (s82 continued 2).
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-13** and
   **2026-10-14** (four of them).
4. `docs/research/replay-calibration-eurusd-4.md` (all of it); plan 3's s3,
   s4 and s7 notes.
5. `docs/research/replay-consult-plan4.md` s8, s10, s11, s12.
6. `prompts/cursor_plan4_f1f4.md` (all of it); `reviews/cursor_restate_f1f4.md`
   on `review/cursor-restate`; `reviews/argon_r5_f1f4.md` on `review/argon-r5`.
7. On `replay-harness` `efada62`: `ea/fxgrind_replay_core.mqh` (346-352,
   740-780, 870-940, 2280-2300, 2520-2575, 2665-2780), `ea/grind_engine.mqh`
   (2049-2100, 2540-2585, 3026-3075), `ea/grind_pure.mqh` (198-266).
8. `handoffs/Handover/08_BACKLOG.md`: C150, C151, C152.
9. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, what
   Cursor has pushed so far (SHAs and subjects only; the review comes after
   the answers), the fleets, and anything in the docs that disagrees with
   itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block, at most ~12, each
   answerable in a line.

Do not start the commit review, any fleet action or any run before the
answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC, seven `_OPT` instances, EA `5bb5fdb`. No input
  change until the trial ends (~21 Oct), except a defect fix. Follow its
  EQUITY, not realised.
- **IC B (wine-test, 53066709), C (wine-c, 53071896), D (wine-d,
  53077984):** nine instances each, EA `5bb5fdb`, roll gate 0, re-roll ON,
  breaker off; round 3 geometry, FROZEN (no round 4). **IC access (C150):**
  the web login is refused since 12 Oct; the MT5 logins still work (13 Oct).
  At every status read check each IC terminal's journal. **Do not advise
  re-verifying with different details.**
- **The carry pass runs 20:50-20:59Z nightly.** Fridays show `failed` 3-4
  per instance (retcode 10025): not news. `mult_tomorrow` 3 on a Tuesday is
  C144, known.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is, to its end.
- Compass rounds stopped; ADR-167 parked; the slower light side dropped.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades. Plan 3 is CLOSED:
  FAIL; nothing re-scores it. Plan 4 decides, on its own window.
- **BLIND from Thu 15 Oct 21:00Z (Fri 16 Oct 00:00 server) until plan 4's
  freeze amendment:** no EURUSD fill, send, scalp, roll or journal line of B,
  C or D after the cut, on pipshed or a box (plan 4 s2 lists what is
  allowed). The development gate uses SEEN windows only.
- The cap stays 8. Rolls only at 8/0 (roll gate 0).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `fb52762` (s82k) + this patch (s82l). EA code `5bb5fdb`, live on A, B, C, D; presets `_r3` (`fb92da8`) |
| `replay-harness` | tip `efada62`; code `145f092` (plan 3's frozen harness); suite 461 / 461 |
| `plan4-tools` | Cursor, Part A (A-1 to A-4), from main: `2193b6b` tests, `bcfc305` code |
| `replay-plan4` | Cursor, Part B from `efada62`: `19d8db6` B-0 (RT64-RT74), `538b15e` F3, `68fe443` F4, `acc93fd` F1, `9748480` F2, `7d8fa13` record; only `ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5` changed |
| `review/cursor-restate` | `e4d96f4` (the agreed test arithmetic) |
| `review/argon-r5` | `417a2bb` (Argon's round 5 on `702ca00`) |
| `replay-adr167` | tip `ed5d052` (parked) |
| `D:\mt5-replay` | the frozen `145f092` build; `MQL5\Files\replay` holds plan 3's holdout inputs and outputs (check before the gate) |
| `D:\fxmatrix` | should be on `main` (Cursor told to switch back) |
| Bridge | connected folders: `Downloads` and `D:\mt5-replay\MQL5\Files\replay` (NOT `D:\fxmatrix`) |
| pipshed `main` | `6ea487e` |
| Linux boxes | `9425141`; git there: `sudo -u khalid git -C /home/khalid/fxmatrix-repo ...` |

## 2. NEXT, IN ORDER

1. The operator applies s82l; tree checked; pushed.
2. **Cursor has stopped:** read every commit on both branches against the
   prompt and the restate: tests before code, commit order, harness files
   only, RT41 and the old tests untouched, each F against its prompt
   section. Argon reviews the commits too (one prompt, in an artifact).
3. The operator compiles (GUI) and runs the suite at B-0 (the new tests fail
   where they should; 461 old pass), then at the end (all pass). The Python
   tests on `plan4-tools`.
4. **The development gate** (plan 4 s4): inputs rebuilt with the new
   builders; `score_plan3.py`'s full verdict on the calibration window (n 6,
   no cut) and plan 3's holdout window (n 3, cut 1791531120000).
5. **The freeze amendment** to plan 4 s2 ("harness = <sha>"), before the
   export.
6. **Sat 17 Oct:** the insurance copies (tick dump, `send_logs`), hashed
   only. **Tue 20 Oct from 22:10Z:** the export, hashed only.
7. A static to ~21 Oct; the nightly carry check and C150 at each read. C151.

## 3. TRAPS (full list in 02_TRAPS)

- Every patch step starts with `git checkout main`. Quote `"HEAD^{tree}"`
  in PowerShell (unquoted, it printed the parent commit).
- **Never reuse a patch's file name in Downloads**; read every saved patch
  back and hash it; give the tree hash. `s82d` in Downloads is VOID.
- **Build every patch on `git checkout -B main origin/main`** (the operator's
  `git am` gives other hashes than your sandbox).
- **Argon invents when it summarises.** Every request to it says: quote
  every line you cite with its line number and commit, or write "not read";
  commit your reply to a `review/...` branch, push, switch back to main.
  Check every quote before a ruling is recorded.
- A test can pass for the wrong reason (RT65's first draft): check that no
  fill, recenter or other send produces the same rows.
- The suite rewrites `Files\replay\swaps.csv`: no suite after `-Mode
  Inputs`; `-SwapsSha` is the guard.
- The replay's outputs are named by tag and mode only: a second run of the
  same tag and mode overwrites the first.
- Give a time-gated step only when its time has come.
- Your sandbox: `.md` files check out CRLF: compare LF bytes.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs
  (`Select-String`); never ask for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git
  format-patch`, checks `git am` on a clean clone at the base, saves the
  patch STRAIGHT to Downloads under a NEW name, reads it back, hashes it
  and gives the tree hash. The operator runs `git am`, checks the tree and
  pushes. **Claude never pushes.**
- **Replay or EA changes:** a prompt in an artifact (questions for Argon
  inside it) -> Argon -> Claude checks every point -> Cursor RESTATES AND
  STOPS -> Claude checks the restate -> "go" -> Claude reads the commits
  -> the operator compiles -> the suite -> runs -> Claude reads the outputs.
- If Cursor drifts from a prompt, the prompt was not good enough: fix the
  prompt, not with instructions outside it.
- One document at a time for review. One paste per step. Count every line
  mechanically.
- **Explain with one small worked example in prices before any table.**
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 177
