This message has a line count at the bottom

# RUNBOOK -- ADR-151 PHASE A DEPLOY, 2026-09-17 (Gemini option ii)

State below is from the 00:45Z status read. It is HISTORY, not current fact.
Re-read status at step 0.4 and stop if it differs materially.

| | |
|---|---|
| Build to deploy | `feat/adr151-exit-queue` at `5bc5a88` (EA code at `1390052`) |
| Desktop suite | 1136/1136 at 5bc5a88 (baseline 1038 + 98) |
| Rollback build | `rollback/adr151-k99-r2` at `f7e2123` (K = 99, one line) |
| Running (7) | GBPUSD ALT, EURGBP OPT, EURGBP ALT, AUDCAD OPT, AUDCAD ALT, CADCHF OPT, CADCHF ALT |
| Parked (7) | GBPUSD OPT 22260101, EURUSD OPT 22260201, EURUSD ALT 22260202, AUDCHF OPT 22260501, AUDCHF ALT 22260502, NZDCAD OPT 22260801, AUDNZD OPT 22260901 |
| Book 00:45Z | 86 positions + 97 orders = 183 / 200 |

Rules for the whole night:
- **NEVER run `fxgrind_tests.mq5` on the VPS.** The LK tests create and delete
  `GRIND_SLOT_LOCK` (the live fleet lock) and the prune tests delete carry GVs
  terminal-wide. Tests run on the desktop only.
- Paste every status URL with a NEW trailing segment (c2, c3, ...).
- Claude does not deploy. Each step ends with something for Claude to check.
- A QUARANTINE_ENTER / QUARANTINE_RELEASE pair on an unwind is EXPECTED
  (memo s4.4). A HALT is not.

---

## 0. PRECONDITIONS (desktop)

0.1 Desktop compiles, both `0 errors`:
    - `fxgrind.mq5` at `5bc5a88`
    - `fxgrind.mq5` at `f7e2123` (rollback)
    Send Claude both last lines.

0.2 Merge the feature branch into main:

    cd D:\fxmatrix
    git checkout main
    git pull origin main
    git branch --show-current
    git diff --stat origin/main..origin/feat/adr151-exit-queue
    git merge --no-ff origin/feat/adr151-exit-queue -m "Merge ADR-151 Phase A: exit queue and commitment guard"
    git push origin main
    git log --oneline -1 origin/main

    Diffstat must list only: ea/fxgrind.mq5, ea/fxgrind_tests.mq5,
    ea/fxgrind_tests_adr151.mqh, ea/grind_carry.mqh, ea/grind_closeby.mqh,
    ea/grind_config.mqh, ea/grind_engine.mqh, ea/grind_exitq.mqh,
    ea/grind_magic_lock.mqh, ea/grind_recon.mqh, and the two
    prompts/cursor_adr151_phaseA*_response.md files. Anything else: STOP.
    Send Claude the merge hash. Claude checks main's ea/ tree equals 5bc5a88's.

0.3 AccountLimits on the VPS. Send the count.

0.4 Status read. Claude confirms for each of the 7 parked instances:
    no ENT orders, every position has an exit (or is an ENT/EXT locked pair).
    A parked instance with a naked position: close it first (match on ticket).

---

## 1. DETACH THE 7 PARKED INSTANCES (VPS, algo stays ON)

For each of the 7 magics above:
  1. Open the chart. EA properties -> Inputs: confirm `InpMagic` and `InpSlot`
     match the table. Press CANCEL (OK can reinit).
  2. Remove the EA from that chart only.
  3. Tick it off the list.

Detaching is safe for these books: no entries, every position covered. An exit
that fills while detached leaves a locked pair; reattach nets it.
Detaching frees no slots.

1.5 Status read. The 7 will still show "live" with a frozen book (known trap:
    pipshed ages them out). Claude checks the 7 running instances are untouched.

---

## 2. DEPLOY TO THE 7 RUNNING INSTANCES (VPS)

2.1 Back up the current build:

    New-Item -ItemType Directory -Force C:\fxmatrix_backup | Out-Null
    Copy-Item "<terminal>\MQL5\Experts\fxmatrix\fxgrind.ex5" C:\fxmatrix_backup\fxgrind_adr150.ex5

    (`<terminal>` = the MetaQuotes terminal data folder for hash
    81A933A9AFC5DE3C23B15CAB19C63850. Keep the backup OUTSIDE Experts.)

2.2 Pull and copy:

    cd C:\fxmatrix
    git branch --show-current
    .\deploy.ps1

    Branch must be `main`. Must print "verified byte-identical". Send the last
    lines and `git log --oneline -1`.

2.3 MetaEditor: File -> Open `MQL5\Experts\fxmatrix\fxgrind.mq5` by explicit
    path. Compile. `0 errors`. This reloads the 7 attached instances.

---

## 3. VERIFY THE 7 (first 15 minutes)

3.1 IMMEDIATELY: status read + AccountLimits. Claude expects:
    - all 7: `halted false`, `recon_ok true`, `invariant_ok true`
    - no trim on AUDCAD OPT/ALT or CADCHF OPT (at most 3 exits per side now)
    - per side at most 3 exit orders: GBPUSD ALT long keeps L11, L10, L09
      (lowest entries) and cancels 9; EURGBP ALT long cancels 3; EURGBP OPT
      long cancels 2; CADCHF ALT short cancels 1 -- about 15 cancels
    - book about 183 - 15 = 168, adjusted for anything that filled meanwhile
    - held layers show `has_exit_order false` with a non-zero `exit_target`

3.2 VPS Experts log, filtered to the last few minutes. Send any line containing
    `FATAL`, `CRITICAL`, `INIT_FAILED`, `SLOT_LOCK_STOLEN`, `counter self-verify`.

3.3 Archive (from D:\pipshed):

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" `
      python scripts/archive_counts.py --table config_events --limit 10
    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" `
      python scripts/archive_counts.py --table send_logs --limit 40
    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" `
      python scripts/archive_counts.py --table ea_events --limit 10

    Claude expects: 7 INIT rows on the new build; REMOVE actions for the trims
    with ok=true; NO retcode 10040; no INVARIANT_FAIL.

3.4 Second status read at ~15 min. Stable = no halts, `api_count` not climbing
    faster than tonight's ~320/hour, book not growing toward 200.

GO / NO-GO to step 4 is Claude's call on 3.1-3.4, stated explicitly.

---

## 4. REATTACH THE PARKED 7, ONE AT A TIME

Order (smallest book first): AUDNZD OPT, NZDCAD OPT, AUDCHF OPT, AUDCHF ALT,
EURUSD ALT, EURUSD OPT, GBPUSD OPT.

Expected trims at 00:45Z (recheck from the status read before each):
AUDNZD OPT 0 (flat), NZDCAD OPT 0, AUDCHF OPT 0, AUDCHF ALT 0,
EURUSD ALT 4 (long L00-L03 cancelled; its locked short pair 543923596 /
543996930 nets, +2 slots), EURUSD OPT 5, GBPUSD OPT 7.

For EACH instance:
  4.1 Status read + AccountLimits. Proceed only if book <= 185.
  4.2 Attach `fxgrind` to that instance's chart. Load its preset from
      `ea\presets\`. **Fill `TelemetryAPIKey`** (blank in repo presets) or the
      instance goes dark. Confirm `InpMagic`, `InpSlot`,
      `InpEnableCarryPass=false`. OK.
  4.3 Status read within 1 minute. Claude checks: `halted false`,
      `recon_ok true`, expected trims done, locked pair netted, entries placed
      or deferred (a deferral sends nothing and is not an error).
  4.4 Wait for Claude's OK before the next instance.

If an instance fails OnInit with INIT_FAILED: read the Experts log line.
Carry flag or magic lock are the two known causes. Do not retry blindly.

---

## 5. STOP CONDITIONS (any step)

Stop, change nothing further, and send Claude the status read plus the log:
  - any HALT (not a quarantine) on any instance after 2.3
  - any RECON_FAIL
  - any send with retcode 10040
  - `SLOT_LOCK_STOLEN` more than once
  - book reaches 195
  - an instance showing `api_counter_broken` / trading silently stopped

A single halt is diagnosed before deciding on rollback. Rollback is not automatic.

---

## 6. ROLLBACK (Gemini 2026-09-17, (a) and (b))

R1. Transition build, K = 99 (desktop, then VPS):

    cd D:\fxmatrix
    git checkout main
    git pull origin main
    git merge --no-ff origin/rollback/adr151-k99-r2 -m "ROLLBACK R1: GRIND_EXITQ_K 99"
    git diff HEAD~1 --stat
    git push origin main

    Diffstat: `ea/grind_config.mqh | 2 +-` and nothing else. Then VPS: deploy.ps1,
    compile. Every attached instance reloads with all ranks required; release
    re-places held exits where slots exist. Needs roughly one slot per held
    layer; if the book is near 200, detach nothing and let exits net first.

R2. Only when a status read shows ZERO held layers fleet-wide (every layer has
    an exit order or exit position) and a true code rollback is still wanted:
    Claude writes the revert commands at that point, against the actual main
    history. Never restore the ADR-150 build while any layer is held: it fails
    reconstruction and halts (F2).

---

## 7. AFTER

- Handoff: tonight's evidence, the 7/7 correction, the commit-1 compile defect,
  both inaccurate Cursor reports, the VPS test-suite ban.
- ADR-151 status line -> implemented and deployed (Phase A), with the merge hash.
- NEXT SESSION items resume from HANDOFF_2026-09-16c s5.

Line count: 206
