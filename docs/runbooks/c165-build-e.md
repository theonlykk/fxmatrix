This message has a line count at the bottom

# RUNBOOK -- C165 ON FLEET E (wine-e, FTMO 1515045375): THE CLAMPED-ADD HOLD, BY RECOMPILE

| | |
|---|---|
| Status | **DRAFT 26 Oct ~21:50Z (Claude, HANDOFF s92 continued 5).** Runs in market hours on the operator's go, before Fri 30 Oct's close. |
| Why | C165: at Sunday's open E's terminal sent ~1,700 requests in two hours (FTMO's limit 2,000 a day), ~1,550 of them three clamped adds chasing the spread. The next weekly open is Sun 1 Nov (~22:00Z after New York's change). |
| What | E's twelve charts go from EA code `5bb5fdb` to `main` `bf832c0` (merge of `c165-clamp-hold`): `Grind_AddClampHold` + a two-line guard in `Grind_EnsureAddNext`; the rest of the diff is tests. No input, preset, geometry or telemetry change. |
| Evidence | Prompt `prompts/cursor_c165_clamp_hold.md` (Argon GO); suite on the desktop 2612/2624 at the stub (exactly the 12 F) and **2624/2624** at `9b44b57`; DeepSeek `review/deepseek-c165` (NO GO on pre-existing behaviour only: HANDOFF s92 continued 5) |
| Model | `docs/runbooks/wednesday-build-2026-10-07.md` s3.2-3.6 (a recompile with the charts attached; run 7 Oct, BAD 0 on 27 charts) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | `git diff --stat 5bb5fdb bf832c0 -- 'ea/*.mq5' 'ea/*.mqh'`: 4 files, +316 (`fxgrind_tests.mq5`, `fxgrind_tests_c165.mqh`, `grind_engine.mqh` +2, `grind_pure.mqh` +17) | git | VERIFIED |
| K2 | A recompile re-initialises every chart that loads the compiled file (`deinit reason=2`) and keeps each chart's inputs by name; no new input here, so nothing else changes | 02_TRAPS 25 Sep; wednesday-build K4; c63-commands S5 | VERIFIED (precedent) |
| K3 | E's charts load `MQL5/Experts/fxmatrix/fxgrind.ex5` (twoarm-build-e s1.9: `fxgrind.mq5` is never in Scripts) | twoarm-build-e s1.9, s7 | VERIFIED (runbook); the INIT `ea_build` confirms (s3.5) |
| K4 | E's twelve inputs are the `_t3` set (fingerprint `211cb64a25ac`): OPT / ALT `geo=` below; cap 7, gate 0, `api=1000000/999000` | `ea/presets_e/*_e_t3.set` | VERIFIED |
| K5 | A re-init resets in-memory daily counters, not the terminal's request count (a GV, `grind_api_counter.mqh`); `OnInit` sets the one-shot add reprice, which C165 holds while an add rests at or beyond its target | 01_BOOT s3; `fxgrind.mq5` 291-292 | VERIFIED |

Expected `geo=` (L and S identical; width/add/exit): GBPUSD OPT 2.5/9/9, ALT 4/15/15; EURUSD OPT 2/7/7, ALT
6/23/23; EURGBP OPT 1.5/5/5, ALT 6/23/23; AUDCAD OPT 4.5/18/18, ALT 6.5/26/26; AUDCHF OPT 3.5/14/14, ALT
5/20/20; CADCHF OPT 2.5/10/10, ALT 4.5/17/17.

## 1. WHEN

In session with normal spreads: never 20:50-21:15Z (carry and rollover), never within 30 minutes of a tier-1
release (Wed 28 Oct: Australian CPI, the BoC, the Fed, the RBNZ; Thu 29 Oct: the ECB, US GDP and PCE; Fri 30 Oct: the
BoJ; times checked on the day),
never with the market closed. The operator picks the minute. One box only (E); the IC fleets after, the
operator's call (s6).

## 2. BEFORE (desktop)

1. pipshed (Claude): E 12/12 LIVE, none halted; the book and `api_count` noted.
2. `$E = 'root@104.207.140.130'` in the PowerShell window; the VNC tunnel `ssh -o ServerAliveInterval=15 -L
   5913:localhost:5913 $E`, viewer `localhost::5913` (twoarm-build-e s1.7).

## 3. ON WINE-E (one step at a time; Claude reads each output)

**3.1 Pull and check (ssh as root).** Expected `bf832c0`, then the four files of K1, then `211cb64a25ac` and 12:

    R=/home/khalid/fxmatrix-repo; sudo -u khalid git -C $R pull -q --ff-only && sudo -u khalid git -C $R log --oneline -1 | cut -c1-10 && sudo -u khalid git -C $R diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh' && (cd $R && for f in ea/presets_e/*_e_t3.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_e/*_e_t3.set | wc -l)

**3.2 Keep the running build's source** (the rollback, s5). Expected `kept 79`:

    sudo -u khalid rm -rf /home/khalid/rollback_5bb5fdb && sudo -u khalid mkdir -p /home/khalid/rollback_5bb5fdb && sudo -u khalid git -C /home/khalid/fxmatrix-repo archive 5bb5fdb ea | sudo -u khalid tar -x -C /home/khalid/rollback_5bb5fdb && echo "kept $(ls /home/khalid/rollback_5bb5fdb/ea/*.mq5 /home/khalid/rollback_5bb5fdb/ea/*.mqh | wc -l)"

(5bb5fdb's own `ea/*.mq5` + `ea/*.mqh`: 79; `main` has 80, the new `fxgrind_tests_c165.mqh` added.)

**3.3 Copy to Experts, then cmp** (copying reloads nothing). Expected `cmp ok=80 bad=0`:

    R=/home/khalid/fxmatrix-repo; M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; sudo -u khalid cp $R/ea/*.mq5 $R/ea/*.mqh "$M/Experts/fxmatrix/" && ok=0; bad=0; for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "$M/Experts/fxmatrix/$(basename "$f")"; then ok=$((ok+1)); else bad=$((bad+1)); fi; done; echo "cmp ok=$ok bad=$bad"

**3.4 Compile ONE file** (MetaEditor GUI over VNC; Navigator -> Refresh first): `MQL5/Experts/fxmatrix/fxgrind.mq5`
(read the path in MetaEditor's tab). `0 errors, 0 warnings`. Note the UTC minute: the twelve charts re-initialise
now. Never `fxgrind_tests` on this box (02_TRAPS 25 Sep).

**3.5 Check the re-init** (FROM = the minute before the compile; ssh as root):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /home/khalid/fxmatrix-repo/scripts/build_logcheck.awk

Expected: **12 rows** `deinit=2`, `replay=ready(n)`, `lattice=true`, `reroll=true`, `gate=0`,
`api=1000000/999000`, `geo=` as s0, `rebuild=false/false`; **BAD 0** (or only s4's one allowed
`STARTUP_EXIT_SHORTFALL`); POST ok rising. Then (desktop, `D:\pipshed`)
the newest INIT row's `ea_build` = the compile minute:

    railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --table config_events --instance GRIND_GBPUSD_OPTE --limit 2

**3.6 Watch about 10 minutes:** pipshed 12/12 LIVE, none halted; `api_count` rising at the day's normal pace (it was
~20-55 an hour in London and New York on 26 Oct); the resting adds in the Trade tab unchanged by the compile
(K5: an add at or beyond its target is held, not repriced).

## 4. STOP (before going on)

FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`, `QUARANTINE_HALT`, any `REBUILD_*` failure, fewer or more than 12
rows, a `geo=` / `gate=` / `api=` not as expected, `cmp` bad > 0, a compile error or warning, `ea_build` not the
compile minute. One `STARTUP_EXIT_SHORTFALL` on a side is allowed (a fill during the seconds of the re-init); two
or more on a side: STOP. Bring it to Claude before any other action.

## 5. ROLLBACK (only on a STOP that the code causes; tell Claude first)

Copy 5bb5fdb's sources back and compile again (another `deinit=2` on all twelve; inputs unchanged):

    M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; B=/home/khalid/rollback_5bb5fdb/ea; sudo -u khalid cp $B/*.mq5 $B/*.mqh "$M/Experts/fxmatrix/" && echo copied

then MetaEditor compile of the same file, and s3.5's checker. (The two C165 test files left in Experts are not
included by `fxgrind.mq5`.)

## 6. AFTER

- The 21:00Z rollover that day: E's counter from 21:00Z (D's weekday precedent: 86-132 by 23:00Z).
- **Sun 1 Nov's open:** E's `api_count` read at about +20 and +60 minutes (26 Oct: 1,089 in the first hour).
- B, C, D (IC, no hard limit; B 1,908 and D 3,384 at Sunday's open): the same s3 per box, the operator's call;
  C's charts re-initialise with cap 9 on three OPT sides (inputs kept). Not before E has run one session clean.

## 7. NEGATIVE SPACE

No preset Load, no Remove / Attach, no F7 on any chart, no change to inputs, no compile of anything but s3.4's
file, nothing on B, C or D, no `fxgrind_tests` on wine-e, no attach or compile in 20:50-21:15Z or with the market
closed.

Line count: 105
