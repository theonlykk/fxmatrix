This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-10 ~01:45Z (SATURDAY, EARLY; T1 PASSES; T2 FAILS ON THE UNPRICED SHARE; TWO QUESTIONS FOR GEMINI)

**Handover prepared 10 Oct ~01:45Z (HANDOFF s77 continued 2).** The
EURUSD replay calibration (`docs/research/replay-calibration-eurusd.md`,
the plan) runs end to end. The engine is an MQL5 harness on the EA's own
engine. Cursor builds it on branch `replay-harness`, which is never
merged. It runs in `D:\mt5-replay`, a portable MT5 on IC 53077984 with
the READ-ONLY login, driven by `tools/replay_run.ps1`. Its 29 segments run
on the committed inputs (`research/replay/inputs/eurusd_20261008/`) and
the w2 ticks. `research/replay/compare.py` scores the runs against plan
s6's marks. After fixes 1-5, at harness `90fbce4`:

| Fleet | T1 matched / touchable | Replay-only | T1 | UNPRICED share | T2 |
|---|---|---|---|---|---|
| B | 96.0% | 3.4% | PASS | 31.9% (segs 1, 2, 3) | FAIL |
| C | 96.1% | 4.5% | PASS | 36.2% (segs 11, 12, 13, 16) | FAIL |
| D | 96.5% | 2.4% | PASS | 34.6% (segs 21, 23) | FAIL |

T2's per-side sums pass on all six sides; it fails only because segments
missing T1's mark hold more than 20% of the deals. The misses left are
mostly TIMING: the harness's close-by is instant (the broker's ~1 s), the
EA's sends are serial, and the broker fills up to ~2 s after a touch in
bursts. One small harness defect is known: an order placed after a
close-by (stage CB_DONE) cannot fill on the next tick (4 sync cases).

**Two questions for Gemini, NOT yet sent** (plan s12, the last bullet):
(1) does s8's "T1 passes, T2 fails" or its "fail in M1-M3" govern? (2)
before the holdout, fix the CB_DONE defect and run s6's placement-latency
sensitivities (250 ms, 1 s; reported, never deciding), or freeze
`90fbce4` as it is? The holdout allows NO code change once it starts.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps is PARKED.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify the HEADs in git first.

Read, in order:
1. `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP; s6 the state).
2. `handoffs/HANDOFF_2026-09-24.md` **s75-s77 continued 2**. Follow the
   last NEXT SESSION list.
3. `handoffs/Handover/02_TRAPS.md`: the sections dated **2026-10-09** and
   **2026-10-10**.
4. `docs/research/replay-calibration-eurusd.md`: all of it (s3 seeding,
   s6 the marks, s8 what a result means, s12 the rulings and the record).
5. The prompts `prompts/cursor_replay_fix3.md`, `cursor_replay_fix4.md`
   and **`cursor_replay_fix5.md`**. Each has Gemini's rulings at its end.
6. The branch `replay-harness` in git:
   - `ea/fxgrind_replay_core.mqh` (the per-tick sequence, ~1700-1800:
     `Rpl_ScanNewOrders` before `Rpl_ProcessCloseByDone`);
   - `ea/fxgrind_replay_tests.mq5`, `ea/fxgrind_replay.mq5`;
   - `tools/replay_run.ps1`;
   - `research/replay/runs/*_90fbce4/` and `_rpl_rt_90fbce4.txt`.
7. On `main`, `research/replay/`: `compare.py`, `classify_misses.py`,
   `read_orders.py`, `check_accrued.py` (rules in each header), and
   `results/eurusd_20261008_90fbce4/` (`report.md`, `misses.csv`,
   `classified.csv`, `orders_reading.csv`).
8. The EA, `ea/grind_engine.mqh` 3026-3070 (the opposite-L0 re-centre:
   stranded mark, deadband, API soft warn).
9. `handoffs/Handover/08_BACKLOG.md` (C142-C146).
10. `docs/research/grid-as-variance-trade.md` (s11-s14).
11. `docs/runbooks/compass-round.md` with `research/compass/round3.json`.
12. `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW).
13. Then this.

**YOUR FIRST REPLY, after the reading (operator's request):**
1. A short restate of the state as you found it in git: the HEADs, the
   fleets, and anything in the docs that disagrees with itself.
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block. Keep them short and
   answerable in a line each, at most ~12.

Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME.**
- **A (VPS, FTMO free trial 1514878887, $10k, since 7 Oct 22:08-22:17Z):**
  the IC strategy STATIC at B's round-2 anchor, seven `_OPT` instances, EA
  `5bb5fdb`, tag `vps-9346e42`. No input change until the trial ends (~21
  Oct), except a defect fix.
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe)
  and D (wine-d, 53077984, exit probe):** nine instances each, EA
  `5bb5fdb`, roll gate 0, re-roll ON, breaker off. **Round 3 reloaded 9
  Oct 04:24-04:32Z** on four charts (D EURUSD exit 9 / 11; AUDCHF width
  1.5 on B, C and D; C add 5 / 3; D exit 11 / 9). Window Mon 12 + Tue 13;
  **scored Tue 13 ~22:35Z**; the COHORT's EQUITY decides.
- **The carry pass runs 20:50-20:59Z nightly.** Every Friday shows
  `failed` 3-4 per instance; not news.

**Operator rulings (do not re-open):**
- The static FTMO-IC trial runs as it is.
- The COHORT's EQUITY decides a compass round.
- NZDCAD is the control. IC keeps nine pairs. No twins. No broker contact.
- No time-series analysis or price signals: work from our own trades.
- A replay is trusted only once it reproduces our trades; it is the
  veteran (ranges and stability, not optima).
- **The holdout (plan s8, operator 9 Oct ~22:40Z):** only D's EURUSD
  re-inited on 9 Oct (04:24:14Z); B and C run on from their 7 Oct inits
  (no synthetic init) to **Tue 13 22:00Z**; all three scored on deals
  after 9 Oct 04:32Z; B and C read w2 + the holdout dump joined at w2's
  01:30 server seam.
- **Gemini GO4-2/3:** the close-by latency stays a REPORTED sensitivity
  (s6); harness fixes do not count toward s8's three attempts.

**The replay's facts:**
- Server time is UTC+3. The archive's `ea_time_ms` is UTC on the EA's
  clock, which leads the broker's by ~0.6 s; harness files use server ms.
- The replay terminal's log is in the desktop's LOCAL time.
- send_logs keep 14 days: the holdout's must be exported soon after Tue 13.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `972a5a6` + the s77h patch (fix 5 results and this handover). EA code `5bb5fdb`, live on A, B, C, D |
| `replay-harness` | tip `6972e16` (code `90fbce4`; suite 390 / 390, `rt_90fbce4`) |
| `D:\mt5-replay` | Copy BEFORE compiling (`replay_run.ps1 -Mode Copy`); the operator compiles; `-Mode Suite` / `-Mode Run` start it and it shuts itself down. ini UTF-16 LE BOM, `Script=` form |
| pipshed `main` | `6ea487e` (`--export-sends`) |
| Data on the desktop (Downloads) | `archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl`, `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl`, `ticks_53077984_EURUSD_w2.csv` (sha256 `db2ea941...`). Stage them with the device tools |
| Inputs | `research/replay/inputs/eurusd_20261008/` + `.sha256` |

## 2. NEXT, IN ORDER (= HANDOFF s77 continued 2, NEXT SESSION)

1. The questions for the previous chat.
2. The two questions to Gemini (he reads only the attached plan file;
   never give him hashes). Check his rulings in source; record them in
   s12.
3. Then either **fix 6** (a Cursor prompt through Gemini: the CB_DONE
   placement time; a placement-latency input, default 0, for the s6
   sensitivity runs; tests; R0-R5 as fix 5) or **freeze** the harness. An
   adversarial DeepSeek read of the harness before the freeze is an option
   the operator holds.
4. On each box: `git -C /home/khalid/fxmatrix-repo log --oneline -1`.
5. Tue 13 after 22:00Z: the holdout's data (send_logs 9-13 Oct, the
   archives, one tick dump on wine-d from `2026.10.09 01:30` server to
   `2026.10.14 01:00` or later); ~22:35Z round 3 scored.
6. Optional: Friday carry retcodes; the IC-vs-FTMO rewrite to Gemini;
   pipshed C140, C143; C142, C144-C146 to rank.

## 3. TRAPS (full list in 02_TRAPS)

- Cursor leaves the desktop on its branch: every patch step starts with
  `git checkout main`. Quote `"HEAD^{tree}"` in PowerShell.
- Gemini's premises are often wrong even when the finding is right. Check
  every ruling in source.
- Before a spec deletes a behaviour, grep the tests that assert it (RT8b).
- Anything added after Gemini's reading goes back to him.
- The deals output's close-by leg also reads `EXT`; count exit fills with
  entry_type 0.
- Your sandbox: `git fetch` and `git reset --hard origin/main` before every
  patch. Check a patch on a clone reset to the REAL base hash. `.md` files
  check out CRLF: take LF bytes with `git show HEAD:<path>`.
- A count with no committed check is not a fact.

## 4. WORKING PRACTICE

- **One shell step per message**; split blocks at checkpoints. Grep logs
  (`Select-String`); never ask for pasted logs. pipshed URLs in plain text.
- **Docs and small fixes:** Claude commits in its sandbox, runs `git
  format-patch`, checks `git am` on a clean clone at the base, saves the
  patch STRAIGHT to Downloads and gives the tree hash. The operator runs
  `git am`, checks the tree and pushes. **Claude never pushes.**
- **Harness changes:** a prompt (RESTATE AND STOP, exact counts, questions
  for Gemini inside it) in an artifact -> Gemini -> Claude checks his
  rulings in -> Cursor -> Claude reads the commits -> the operator compiles
  -> Cursor runs -> Claude reads the outputs.
- One paste per step, for agents too. Count every line mechanically.
- Long chats: keep the docs current; propose a handoff only near the limit.

Line count: 177
