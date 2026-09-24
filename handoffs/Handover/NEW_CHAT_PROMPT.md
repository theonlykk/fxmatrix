This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-24 ~04:00Z

You are picking up mid-project. **Read `handoffs/Handover/01_BOOT.md`,
then `handoffs/HANDOFF_2026-09-24.md` (to the end: sections 7-8 are Fleet B and its dashboard),
then the two newest sections of `02_TRAPS.md` (2026-09-23/24 and 24 night)**, then this document. Verify `main`'s HEAD
SHA against section 1 before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACT

**Two fleets are LIVE.** Fleet B (section 1) is the second.

**Cycle 3 is LIVE and pre-registered.** Eleven instances on account
1514731800 since ~01:00Z Thu 24 Sep (`docs/architecture/geometry-cycle3.md`
with amendments A1-A3). Nothing lands in the EA mid-cycle except a defect
fix: every compile or reattach is a fleet restart and blends two regimes.
Pipshed and docs may change freely.

The account dies on FTMO's DAILY limit ($500 from the day-start BALANCE,
equity includes open MTM), not on bad trading: that is how cycle 2 ended
(`docs/FULL_TRIAL_RECORD_1514582088.md`). ADR-158's 80% breaker and
ADR-160's 50/40 floating-loss entry gate are the defences.

---

## 1. STATE

| | |
|---|---|
| fxmatrix `main` | `85cd555` or a docs-only descendant (EA code = `c22e9ff` = tested `6c57830`: `git diff --stat 6c57830 origin/main -- ea/*.mq5 ea/*.mqh scripts/ tools/` must be empty; presets changed since) |
| pipshed `main` | `39df6e0` (ADR-159; `/status_b`; fleet chosen by env `GRIND_FLEET`); two web services on Railway: `pipshed` (cycle 3, `pipshed.com`) and "pipshed Copy" (`GRIND_FLEET=B`, Fleet B) sharing Redis; one archive worker |
| VPS | branch `main` at `a01a5d4`, tag `vps-a01a5d4`, 11 instances, Algo ON |
| Suite | **1766/1766** (GBPUSD and EURUSD); EA compiles 0/0 |
| Account | FTMO free trial 1514731800, $10k, $500/day, 14 days |
| Fleet at 01:35Z | 11 live, 0 halted; first scalps closed; F1 confirmed live (AUDNZD depth 2, exits on both layers) |
| **Fleet B** | IC Markets demo **53066709** on the Linux box (Vultr 207.148.14.197), 11 live since ~02:50Z, Phase 0 = cycle-3 config; `docs/architecture/fleet-b.md`; dashboard `https://pipshed-copy-production.up.railway.app` (`linux.pipshed.com` pending) |

---

## 2. WHAT IS BUILT (all merged, all tested)

| item | what | where |
|---|---|---|
| ADR-159 | daily `DAILY_SNAPSHOT` per FTMO day (22 keys); CRITICAL + amber banner; ejections archived; `ejected` flag on scalps; account login everywhere; breaker latch read every tick (ADR-158 rev 2); NZDCHF in the fleet table (18 magics) | EA `1c4a549`, pipshed `e475506` |
| ADR-160 | all-day entry gate: no new entries while floating loss >= 50% of the allowance, clears at 40%; transitions archived; `gated_seconds` in the snapshot | EA `c22e9ff` |
| A3 | eleven instances: nine OPT + AUDNZD and NZDCAD duplicates (OPT geometry, ALT magics 22260902 / 22260802); carry and both ejections ON; breaker explicit | `a01a5d4` |

---

## 3. NEXT, IN ORDER

1. **Cycle 3 first-hour checks: DONE** (scalps closing, F1 seen live).
2. **22:00Z Thu 24 Sep: the first `DAILY_SNAPSHOT`.** Expect
   `start_known=false` (partial day) and one row on the Daily card. Every
   later day should be `start_known=true`.
3. **ADR-161 session window (C37)** -- Fleet B Phase 1: entries only
   07:00-17:00 Toronto, cancel resting entries at the close, default OFF.
   Tests first, Gemini, DeepSeek. Deploy on the Linux box ONLY.
4. **Pipshed D5** (ADR-160, C36): migration `003` (`gated_seconds`,
   `history_ok` columns, backfilled from `detail`), a Gated column,
   gated hours in `s4_scalps.py`. One Cursor prompt, pipshed only.
5. **C40:** benign I3 quarantines when F1 moves an exit (~200 ms); watch the
   episode count. Keep BOOT s6 current each session.
6. **Watch daily (both fleets):** the Carried column (day-start equity minus balance),
   `guard_total` (budget ~mid-170s vs 194), gate episodes, breaker trips.

---

## 4. TRAPS (full list in 02_TRAPS; newest section is 2026-09-23/24)

- **Verify every agent claim in git.** Cursor did 1 of 4 changes once;
  added a test without registering it once; implemented pure functions
  inside a "stub" commit once.
- **A test whose expected value is 0 passes against a stub.** Use non-zero
  expectations, and mutation-test anything that converts units or clocks.
- **DeepSeek overstates and mis-assumes** (a 5000 ms timeout that is 200;
  a "stuck" state that cannot occur). Check each verdict against source.
- **A fresh Gemini chat reasons from general architecture** (it invented
  `Grind_GridReconstruct`). Send BOOT with the prompt and point at files.
- **Fleet-table changes break fixtures** that encode the 16-magic fleet;
  grep the tests for magic lists and sizes.
- **`Write-Host` output cannot be filtered** with `Select-String`
  (`desktop_sync.ps1`, `deploy.ps1`); check files by hash instead.
- **Railway Postgres is private:** `railway run` cannot reach it from the
  desktop; run DB scripts via `railway ssh --service archive-worker`.
- **Algo Trading must be ON before attaching** on this terminal; each EA
  trades on OK, so read inputs back before OK.

---

## 5. WORKING PRACTICE

- Claude writes specs to files (bookends, ASCII, audit trail, negative
  space, failure modes); Gemini reviews every Cursor prompt with his
  questions inside it; Cursor implements on a branch; the operator
  compiles, runs the suite, merges and deploys.
- Tests first, stub commit behaviour-neutral, failures predicted BY NAME;
  both runs by the operator.
- DeepSeek via the Cursor runner task
  (`docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`;
  config-driven `tools/r1_audit/r1_audit.py --config`), mandatory for
  anything that places, moves or cancels orders.
- One shell step per message; the operator pastes output back.
- Operator stance: demo mode -- ship a clear rule, learn, adjust.

Line count: 109
