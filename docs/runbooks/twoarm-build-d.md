This message has a line count at the bottom

# RUNBOOK -- THE TWO-ARM BUILD ON FLEET D (wine-d, IC 53077984)

| | |
|---|---|
| Status | **DRAFT** (Claude, 17 Oct ~23:30Z, HANDOFF s85 continued 10), for Gemini's review (s9) |
| What | D becomes FTMO's mirror (fleet D note s10-s12): EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF with OPT + ALT, exit = add, cap 7 (12 instances); NZDCHF, NZDCAD, AUDNZD retire |
| Uses | `main` `2426f94` or later: `ea/presets_d/<pair>_{opt,alt}_d_t1.set` (verified byte for byte, HANDOFF s85 continued 9); `/root/mon_logcheck.awk` on wine-d (monday-night 0.1, 2688 bytes); pipshed branch `twoarm-fleets` `320afe6` (merged AFTER D and C, s7) |
| When | **Wed 21 Oct or later, in market hours (London / New York, about 12:00-16:00Z)**, after plan 4's export (Tue 20 Oct 22:10Z). Never 20:50-21:15Z; not within 30 minutes of a tier-1 release (check the calendar on the day). Safe to stop between steps 4, 5 and 6 |
| Rulings | Operator 17 Oct: the layout (s10), exit = add on both arms and "if we have to flatten all positions - so be it. these are demo accounts" (s11); never log out wine-d's IC terminal (C150) |

## 0. WHAT CHANGES, CHART BY CHART (from the presets; Claude's table at `2426f94`)

**One worked example.** EURUSD OPT holds 5 longs, the deepest at 1.1600 with its exit resting at 1.1609 (exit
9). Reloaded at exit 7, the EA's start-up rebuild moves that exit to 1.1607 (`rebuild=true` on the long side);
its cap goes 8 -> 7, which the start-up check allows because 5 <= 7.

| Chart | Change | `geo=` after (L w/a/e S w/a/e) | `rebuild=` |
|---|---|---|---|
| GBPUSD OPT (22260101) | cap 8 -> 7 only | L2.5/9/9 S2.5/9/9 | false/false |
| EURUSD OPT (22260201) | cap 7; exit 9 / 11 -> 7 | L2/7/7 S2/7/7 | true/true |
| EURGBP OPT (22260301) | cap 7; exit 6 / 4 -> 3 | L1/3/3 S1/3/3 | true/true |
| AUDCAD OPT (22260401) | cap 7; exit 9 -> 6 | L1.5/6/6 S1.5/6/6 | true/true |
| AUDCHF OPT (22260501) | cap 7; exit 11 / 9 -> 4; width 1.5 -> 1.0, S 2.5 -> 2.0 | L1/4/4 S1/4/4 | true/true |
| CADCHF OPT (22260601) | cap 7; exit 11 / 9 -> 4 | L1/4/4 S1/4/4 | true/true |
| GBPUSD ALT (22260102, new) | add = exit 30, W 7.5, S 8.5 | L7.5/30/30 S7.5/30/30 | false/false |
| EURUSD ALT (22260202, new) | 27, W 7.0, S 8.0 | L7/27/27 S7/27/27 | false/false |
| EURGBP ALT (22260302, new) | 19, W 5.0, S 6.0 | L5/19/19 S5/19/19 | false/false |
| AUDCAD ALT (22260402, new) | 27, W 7.0, S 8.0 | L7/27/27 S7/27/27 | false/false |
| AUDCHF ALT (22260502, new) | 22, W 5.5, S 6.5 | L5.5/22/22 S5.5/22/22 | false/false |
| CADCHF ALT (22260602, new) | 12, W 3.0, S 4.0 | L3/12/12 S3/12/12 | false/false |

Every chart: cap 7, deadband 2.0, lattice and re-roll true, roll gate 0, breaker and auto-eject false.
No EA code change: the build is presets only (s2.3 checks it); no compile.

## 1. BEFORE (Claude, sandbox, the day before)

- `main` carries the `_t1` presets; their fingerprint (repo root):
  `for f in ea/presets_d/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12` and
  `ls ea/presets_d/*_t1.set | wc -l` = 12. **At `2426f94`: `eb0d6a097694`, 12** (computed 17 Oct; re-checked the day before).
- pipshed `main` still `fb0f9c8` (else the merge in s7 is not a fast-forward: STOP and tell Claude).

## 2. ON WINE-D (ssh as root: `ssh root@216.128.158.33`; VNC 5912)

**2.1 Read the box (VNC, read-only).** Algo Trading ON; the Journal shows no logout; nine charts. pipshed
D page: nine LIVE, none halted. Note each retiring chart's open positions and resting orders (Trade tab,
comment `GRIND|OPT|`, symbol NZDCHF, NZDCAD, AUDNZD).

**2.2 The checker is installed** (expected `2688 /root/mon_logcheck.awk`): `wc -c /root/mon_logcheck.awk`

**2.3 Repo to `main`, no EA code change** (as root; the last line must print nothing):

    sudo -u khalid git -C /home/khalid/fxmatrix-repo fetch -q origin && sudo -u khalid git -C /home/khalid/fxmatrix-repo checkout -q main && sudo -u khalid git -C /home/khalid/fxmatrix-repo pull -q --ff-only && sudo -u khalid git -C /home/khalid/fxmatrix-repo log --oneline -1 | cut -c1-10 && sudo -u khalid git -C /home/khalid/fxmatrix-repo diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh'

**2.4 Fingerprint** (expected: `eb0d6a097694`, then 12):

    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_d/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_d/*_t1.set | wc -l)

**2.5 Stage with the key, then check** (the key never printed; expected 12 lines `SAME_EXCEPT_KEY key_len=43`):

    K=$(tr -d '\r\n' < /home/khalid/.fxgrind_telemetry.key); P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Presets"; R=/home/khalid/fxmatrix-repo; for f in $R/ea/presets_d/*_t1.set; do sed "s|^TelemetryAPIKey=.*|TelemetryAPIKey=$K|" "$f" | sudo -u khalid tee "$P/$(basename $f)" >/dev/null; done; unset K; for f in $R/ea/presets_d/*_t1.set; do b=$(basename $f); if diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done

## 3. RETIRE NZDCHF, NZDCAD, AUDNZD (VNC, by hand; as the twins on 5 Oct, monday-build s3.2)

For each of the three charts (F7 to read `InpTelemetryInstance` and `InpMagic`, then **Cancel**: F7 then OK
is a restart, not a removal):
1. Right-click the chart -> Expert Advisors -> Remove. Experts log: `deinit reason=1`.
2. Delete its resting orders, ENTRIES FIRST (`...|ENT`), then exits (`...|EXT`): an entry that fills after
   removal is unmanaged.
3. Close By its longs against its shorts (match the comment and the symbol, never a ticket from memory).
4. Close the rest at market (operator's ruling 17 Oct: demo; the realised loss equals the open MTM already in
   equity).
5. Trade tab: no position or order left on that symbol. Close the chart.

## 4. RELOAD THE SIX OPT CHARTS (VNC; GBPUSD first as the pilot)

**The cap rule (I7, fleet D note s12): reload a chart only when BOTH its sides hold 6 layers or fewer**,
read on pipshed's D books table (or the Trade tab count of `GRIND|OPT|L|` and `|S|` on that symbol) just
before. 6, not 7: one layer of margin for an add filling between the read and the OK. A side at 7 or 8:
wait (layers come off as scalps fill), or flatten that chart as s3 steps 2-5 with the EA removed, then
attach it fresh as s5.

Per chart: **F7 ON THE CHART** (never the Navigator) -> Inputs -> Load `<pair>_opt_d_t1.set` -> read back
BEFORE OK: `InpMagic`, `InpTelemetryInstance`, width, add, exit, the six per-side rows (`-1.0`), cap 7,
`InpStrandedThreshPips`, deadband 2.0, lattice and re-roll true, roll gate 0, auto-eject and breaker false,
the warning (`FLEET D two-arm t1 <PAIR> OPT -`), the key row not blank. OK; note the UTC time. Then (FROM =
the minute before the OK):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /root/mon_logcheck.awk

Expected one row: `deinit=5 replay=ready(...) lattice=true reroll=true geo=` and `rebuild=` as s0, BAD 0,
a POST ok. The pilot's row first; then the other five, one chart and one check at a time.

**If a chart halts on I7 anyway** (`RECON_FAIL` / `I7_*_DEPTH`): F7 -> Load its OLD preset
`<pair>_opt_d_r3.set` (cap 8) -> OK: the start-up check passes at cap 8 and the chart trades as before. Tell
Claude; retry later under the cap rule.

## 5. ATTACH THE SIX ALT CHARTS (VNC; GBPUSD ALT first as the pilot)

Per pair: File -> New Chart -> the symbol; M5 (as D's charts); drag **Navigator -> Expert Advisors ->
fxmatrix -> fxgrind (the Experts copy)**; Inputs -> Load `<pair>_alt_d_t1.set` -> the same read-back as s4,
with `InpSlot=ALT`, the magic and instance of s0 (`GRIND_<PAIR>_ALTD`), the warning `FLEET D two-arm t1 <PAIR>
ALT q95`. OK; the checker from the minute before. Expected: `deinit=- replay=ready(0) lattice=true
reroll=true geo=` as s0, `rebuild=false/false`, BAD 0 (in particular no `duplicate magic`), a POST ok; two L0
orders resting about `width` from mid (e.g. GBPUSD ALT 7.5 pips each side).

## 6. AFTER (desktop, `D:\pipshed`)

1. Archive codes, last hour (expected `none.`; the codes quoted, 02_TRAPS 15 Oct evening):

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes "ROLL_STRANDED,ROLL_CLOSING_STUCK,ROLL_REFUSED,DEAL_EVENT_MISSED,REPLAY_SEED_FAILED,EJECT_ACCEPTED,INVARIANT_FAIL,QUARANTINE_HALT" --hours 1

2. pipshed's D page still lists the old nine (the new ids appear at s7): the six OPT LIVE; the three
   retired show CONNECTION LOST; the ALT heartbeats are in Redis but not on the page yet.

## 7. PIPSHED (after D AND C; never before)

The branch `twoarm-fleets` retires C's and D's pairs on the strip: merge only once C's runbook is done too.
Then, outside 20:50-21:00Z (expected: `fb0f9c8..320afe6`, a fast-forward; the tree `git rev-parse
origin/twoarm-fleets^{tree}`): `git checkout main; git fetch origin; git merge --ff-only
origin/twoarm-fleets; git push origin main`. Deployed in ~3 minutes. Then the Railway service "pipshed
Fleet E" (duplicate "pipshed Fleet D"; `GRIND_FLEET=E`; domain `linuxe.pipshed.com`; start command as
"pipshed Copy", RAILWAY.md). Check: D's strip 12 / 12 LIVE; C's 6 / 6; E's card NOT BUILT.

## 8. STOP (before the next chart)

FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`, any `REBUILD_*` failure, `duplicate magic`, a missing POST
ok, a `geo=` or `rebuild=` not as s0, a MISMATCH or a fingerprint that differs, a magic or instance read
back on the wrong chart, an order or position left on a retired symbol, the IC terminal logged out (never
log in again with other details: C150).

## 9. FOR THE REVIEWER (Gemini): attack the premises, say which fact is missing

- **GD-1.** Retire by closing at market (the twins' precedent, GB-1), not by letting the books run off. Sound?
- **GD-2.** The cap rule at 6, not 7 (s4): enough margin, or too conservative?
- **GD-3.** Order: retire, then reload OPT, then attach ALT. Any reason to attach ALT first?
- **GD-4.** The I7 recovery by reloading the old `r3` preset (cap 8): does the start-up check pass at cap 8
  on a book that halted at cap 7, and does the halt clear on reinit (BOOT: "a compile or reattach clears a
  halt and re-runs `OnInit`")?
- **GD-5.** No compile: the EA code is `5bb5fdb` and unchanged (s2.3). Any input in the `_t1` presets the
  running build does not know?
- **GD-6.** The ALT L0 at width 3.0-7.5 pips from mid (s5): anything at start-up that assumes width <= 3?
- **GD-7.** What failure is not on s8? What fact is missing?

Line count: 146
