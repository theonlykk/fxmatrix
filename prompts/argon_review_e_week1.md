This message has a line count at the bottom

# ARGON: REVIEW OF THE PRE-REGISTRATION FOR FLEET E's FIRST-WEEK READ

| | |
|---|---|
| Written | 25 Oct 2026 ~18:40Z (HANDOFF s91 continued 3), Claude (Lead Engineer) |
| What | Attack the pre-registration before the week is read: is every measure computable from the named data, is every rule fair and fixed, is anything missing or gameable |
| The document | `research/e_week1/PREREG.md` on `origin/main` (all of it) |
| fxmatrix sources | `research/t3_drawdown/t3dd_output.txt`, `research/t3_drawdown/calm_comm_output.txt`, `research/t3_drawdown/results.md`, `ea/grind_engine.mqh`, `ea/grind_pure.mqh`, `docs/runbooks/twoarm-build-e.md`, `handoffs/Handover/08_BACKLOG.md` (C106, C162, C164), `handoffs/Handover/02_TRAPS.md` (2026-10-24 DAY) |
| pipshed sources | `D:\pipshed` at `origin/main` (`b9d2d22`): `scripts/archive_counts.py`, `migrations/*.sql`, `app.py` (`_fleet_scalps_per_roll` and `sr_table.py`). These sit outside your workspace: the operator approves each read. If a read is refused, write NOT READ |
| Your reply | ONE new file `reviews/argon_review_e_week1.md` on a NEW branch `review/argon-e-week1` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main` (pipshed: at `b9d2d22`). If you did not read a file or a line, write "not read". Open it; do not
   answer from memory.
2. Every verdict is one of: **DEFECT** (wrong, or not computable as written), **GAP** (a needed measure, check or rule
   is missing), **CONFIRMED**, **NOT A DEFECT** (say why, with a quote), **NOT READ**.
3. For any DEFECT or GAP, give the smallest change to the document's text that fixes it.
4. **Read-only.** Edit no file but your reply; no helper scripts left in the repo (put any in your own scratch folder
   outside `D:\fxmatrix` and `D:\pipshed`, or delete them before you commit). Do not compile, do not launch
   MetaTrader, do not run `railway` or touch any database, no `git stash`, no merge, no PR, no `git add .` or `-u`.
   You MAY run Python on the two committed `t3_drawdown` output files to recompute s8.
5. Commit only `reviews/argon_review_e_week1.md` to `review/argon-e-week1`, push it, then `git checkout main`.
6. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **s8, the bands:** recompute every rate and band from the two output files. Is `closes = commission / 0.06`
   right for October (quote the file's header and a row)? Is calm's S + R the right count? Is EURGBP OPT's
   calm-only band disclosed and fair?
2. **s2, the days:** are the FTMO day boundaries right across Prague's change on 25 Oct (quote `Grind_PragueUtcOffset`
   in `ea/grind_pure.mqh`)? Is 5.73 trading days right? Does W's end at 21:05Z miss any of Friday's session?
3. **s3 and s5, computable?** For each measure M1-M5 and the episode (s6): which table and columns give it
   (`state_snapshots`, `fill_logs`, `scalp_history`, `ea_events`)? Does `--export-archive --instance` include every
   table s5 needs? Is the rolled-close join (entry deal -> `fill_logs.position_id` -> `ea_events.ticket` of
   `ROLL_ACCEPTED`) possible with the columns as they are? Is `state_snapshots.balance` / `equity` the account's or
   the instance's?
4. **s4, the self-checks:** can each be run from the exports? Is $0.05 a sound tolerance for check 1? Anything that
   would make check 1 fail for a reason that is not an error (deposits, swaps on Wednesday's triple, FTMO's
   non-trade entries)?
5. **s7, the rules:** is Q1 right as to FTMO's trial (the $500 daily on day-start balance, the static $9,000 floor;
   quote what the repo records, say where it is only recorded and not read on FTMO's site)? Is Q2's band and its 9 of
   12 threshold fixed before any live number, and is it testing anything (could it pass whatever happens)? Is Q3
   honest about D's carried book and the two brokers?
6. **s6, the episode:** is the -$50 / -$100 definition well-defined (ties, a W that ends inside the episode, two
   lows equal)?
7. **Anything that would let the read be bent after the fact** (a choice left open, a measure without a formula).
8. **Anything missing** that the operator's two questions need (C162: t3 against t1; C164: the $300 day), kept to
   what you can quote.

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_e_week1.md`: a header (branch, base hash, files read, pipshed read or NOT READ), then one row
per item 1-8: the verdict, the quotes, and for a DEFECT or GAP the fixed text. End with one line: **SOUND** (commit as
written), **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 61
