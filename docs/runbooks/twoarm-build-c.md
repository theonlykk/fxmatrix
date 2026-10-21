This message has a line count at the bottom

# RUNBOOK -- THE TWO-ARM BUILD ON FLEET C (wine-c, IC 53071896)

| | |
|---|---|
| Status | **REVIEWED** (Argon `review/argon-runbook-c` `de1c107` on `3860a17`, checked by Claude in source, s9; amended 18 Oct ~03:50Z). **RUN 21 Oct 16:00-17:07Z** (HANDOFF s87 continued): s2-s5 done; EURUSD and AUDCAD flattened; s3's last two and the two kept charts flattened in bulk after a nine-line deinit gate (the operator); s6 by the log, its `ea_build` read waits for Railway. Before: DRAFT (Claude, 18 Oct ~01:30Z). Built from D's REVIEWED runbook (`docs/runbooks/twoarm-build-d.md`, `c39d59d`): every step that is the same there is the same here; what differs on C is s0, s2.5-2.6 (the Experts copy, C88), s4 (re-attach, not F7) and s5 (a new pair) |
| What | C runs the broken ring (fleet D note s10): EURUSD, GBPCHF, AUDCAD with OPT + ALT, exit = add, cap 7 (6 instances); GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCHF, NZDCAD, AUDNZD retire. **C88 closes:** after this build every chart on wine-c runs the Experts copy |
| Uses | `main` `c39d59d` or later: `ea/presets_c/<pair>_{opt,alt}_c_t1.set` (6 files; fingerprint s1); `scripts/build_logcheck.awk` on wine-c after the pull; cap10-reload s4.3-4.4 (the Experts compile and Remove-then-Attach, Gemini GW-5, accepted 4 Oct); pipshed branch `twoarm-fleets` `320afe6` (merged after D AND C: D's runbook s7) |
| When | **After D's build is done and its checks clean** (the same day if the slot allows, else the next market day), in market hours (London / New York, about 12:00-16:00Z). Never 20:50-21:15Z; not within 30 minutes of a tier-1 release. Never D and C at the same time. Safe to stop between steps 4, 5 and 6 |
| Rulings | Operator 17 Oct: "I could imagine the broken ring EURUSD GBPCHF AUDCAD on Fleet C"; ALT at q95 on C (as D); exit = add on both arms; "if we have to flatten all positions - so be it. these are demo accounts"; never log out an IC terminal (C150: the web login is refused since 12 Oct; the MT5 sessions are what remains) |

## 0. WHAT CHANGES, CHART BY CHART (from the presets at `c39d59d`)

C's EURUSD and AUDCAD OPT run the `_r2` geometry (round 3 changed only AUDCHF on C; `_r3` = `_r2` but the
warning text, diffed 18 Oct).

| Chart | Change | `geo=` after (L w/a/e S w/a/e) | `rebuild=` |
|---|---|---|---|
| EURUSD OPT (22260201) | re-attach (s4); cap 8 -> 7; add 6 -> 7; exit 10 -> 7 | L2/7/7 S2/7/7 | true/true |
| AUDCAD OPT (22260401) | re-attach (s4); cap 8 -> 7; add 5 -> 6; exit 10 -> 6 | L1.5/6/6 S1.5/6/6 | true/true |
| GBPCHF OPT (22261001, new pair) | width 2.5, add = exit 9, S 3.5 | L2.5/9/9 S2.5/9/9 | false/false |
| EURUSD ALT (22260202, new) | width 7.0, add = exit 27, S 8.0 | L7/27/27 S7/27/27 | false/false |
| AUDCAD ALT (22260402, new) | width 7.0, add = exit 27, S 8.0 | L7/27/27 S7/27/27 | false/false |
| GBPCHF ALT (22261002, new) | width 6.0, add = exit 24, S 7.0 (from its range: no fills yet) | L6/24/24 S6/24/24 | false/false |

**Retire (s3):** GBPUSD (22260101), EURGBP (22260301), AUDCHF (22260501), CADCHF (22260601), NZDCHF
(22260701), NZDCAD (22260801), AUDNZD (22260901), all `_OPTC`.

Every chart: cap 7, deadband 2.0, lattice and re-roll true, roll gate 0 (`gate=0`), API inputs
1000000 / 999000 (`api=1000000/999000`), breaker and auto-eject false, currency cap legs set with
threshold 0 (off). ADR-153 ratios (add / width): 3.5, 4.0, 3.6, 3.86, 3.86, 4.0 (limit 4.0). No EA code change
since `5bb5fdb` (s2.2); one compile, of the Experts copy that no chart loads (s2.6).

**Expected at an exit reload (not a STOP):** as D's s0: a layer already further in profit than its NEW exit
(EURUSD 10 -> 7, AUDCAD 10 -> 6) is clamped just outside the market (`Grind_ExitQClampPassive`,
`grind_exitq.mqh` 258, called in the rebuild at `grind_engine.mqh` 3118), recorded as a carry shift, and fills almost at once as a scalp.

**Expected at an add change (EURUSD 6 -> 7, AUDCAD 5 -> 6):** after a successful exit rebuild `OnInit` sets
the one-shot add re-price (`fxgrind.mq5` 289-292); `Grind_EnsureAddNext` runs every grid step
(`grind_engine.mqh` 3234-3237) and moves the resting add to the new distance with a 0.05-pip deadband
(2560-2571): each side's next add moves 1 pip further out at once.

**GBPCHF's magics (22261001 / 22261002) are outside `GRIND_CAP_ALL_MAGICS`** (backlog C159): the slot guard
counts their resting entries once instead of twice; on C (6 instances, far from the 194 guard) harmless.
Magic 22261001 was AUDUSD's in the cap-10 presets, never attached (the scout was deferred): no deals or
labels under it on wine-c, so GBPCHF OPT starts `replay=ready(0)`, `rebuild=false/false` (s5 checks it).

## 1. BEFORE (Claude, sandbox, the day before)

- `main` carries the `_t1` presets; fingerprint (repo root):
  `for f in ea/presets_c/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12` and
  `ls ea/presets_c/*_t1.set | wc -l` = 6. **At `c39d59d`: `72ba0e3c19f6`, 6** (computed 18 Oct).
- D's build done: its s4 and s5 rows clean, its s6 archive check `none.`.
- pipshed `main` still `fb0f9c8` (else D's s7 merge is not a fast-forward: STOP and tell Claude).

## 2. ON WINE-C (ssh as root: `ssh box2`, i.e. `root@64.177.116.219`; VNC 5911)

**2.1 VNC and read the box.** As root: `pgrep -a x11vnc`. If nothing (06 s9; it may have run `-once`):

    sudo -u khalid x11vnc -display :10 -auth /home/khalid/.Xauthority -localhost -rfbport 5911 -nopw -forever -noipv6 -shared -noxdamage -bg -o /tmp/x11vnc-box2.log

then on the desktop `ssh -L 5911:localhost:5911 box2` (leave it open) and the viewer on `localhost::5911`.
Read-only: Algo Trading ON; the Journal shows no logout; nine charts. pipshed C page
(`https://linuxc.pipshed.com`, plain text): nine LIVE, none halted. Note each retiring chart's open
positions and resting orders (Trade tab, comment `GRIND|OPT|`, the seven symbols of s0).

**2.2 Repo to `main`, no EA code change** (as root; the last line must print nothing):

    sudo -u khalid git -C /home/khalid/fxmatrix-repo fetch -q origin && sudo -u khalid git -C /home/khalid/fxmatrix-repo checkout -q main && sudo -u khalid git -C /home/khalid/fxmatrix-repo pull -q --ff-only && sudo -u khalid git -C /home/khalid/fxmatrix-repo log --oneline -1 | cut -c1-10 && sudo -u khalid git -C /home/khalid/fxmatrix-repo diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh'

**2.3 Fingerprint and checker** (expected: `72ba0e3c19f6`, then 6, then the checker's size, non-zero):

    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_c/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_c/*_t1.set | wc -l; wc -c < scripts/build_logcheck.awk)

**2.4 Stage with the key, then check** (the key never printed; expected 6 lines `SAME_EXCEPT_KEY key_len=43`):

    K=$(tr -d '\r\n' < /home/khalid/.fxgrind_telemetry.key); P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Presets"; R=/home/khalid/fxmatrix-repo; for f in $R/ea/presets_c/*_t1.set; do sed "s|^TelemetryAPIKey=.*|TelemetryAPIKey=$K|" "$f" | sudo -u khalid tee "$P/$(basename $f)" >/dev/null; done; unset K; for f in $R/ea/presets_c/*_t1.set; do b=$(basename $f); if diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done

**2.5 Both EA copies equal the repo** (the Wednesday build copied the sources to Experts AND Scripts, 7 Oct;
expected `cmp ok=158 bad=0`, 79 files x 2; then both `.ex5` times: Scripts 2026-10-07 02:06, Experts
older):

    R=/home/khalid/fxmatrix-repo; M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; ok=0; bad=0; for d in Experts Scripts; do for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "$M/$d/fxmatrix/$(basename "$f")"; then ok=$((ok+1)); else bad=$((bad+1)); fi; done; done; echo "cmp ok=$ok bad=$bad"; ls -l --time-style=+%Y-%m-%dT%H:%M:%S "$M/Experts/fxmatrix/fxgrind.ex5" "$M/Scripts/fxmatrix/fxgrind.ex5"

**2.6 Compile the Experts copy** (cap10-reload s4.3). MetaEditor (VNC): open
**`MQL5\Experts\fxmatrix\fxgrind.mq5`** (the path in MetaEditor's tab: never the Scripts copy, which nine
charts load), Compile: 0 errors, 0 warnings. No chart loads the Experts copy (C88), so nothing re-inits.
Check (FROM = the minute before the compile): the s4 checker prints `inits=0`; the 2.5 `ls` shows the Experts
`.ex5` at today's compile time (note it: s4's `ea_build`). An init row here means a chart already runs the
Experts copy: not a STOP if BAD is 0 (the code is the same); tell Claude (C88's record).

## 3. RETIRE THE SEVEN (VNC, by hand; as D's s3, one chart at a time)

GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCHF, NZDCAD, AUDNZD (`_OPTC`). For each chart (F7 to read
`InpTelemetryInstance` and `InpMagic`, then **Cancel**: F7 then OK is a restart, not a removal):
1. Right-click the chart -> Expert Advisors -> Remove. **Gate: the Experts log shows `fxgrind deinit
   reason=1` for that symbol and the chart's EA icon is gone, BEFORE step 2.**
2. Delete its resting orders, ENTRIES FIRST (`...|ENT`), then exits (`...|EXT`).
3. Close By its longs against its shorts (match the comment and the symbol, never a ticket from memory).
4. Close the rest at market (demo; the realised loss equals the open MTM already in equity).
5. Trade tab: no position or order left on that symbol. Close the chart.

Their Global Variables stay in the terminal (harmless; cleaned later as the twins', monday-build s7).

**After the seven** (FROM = the minute before the first Remove; expected seven lines, the seven symbols, each
`reason=1`; no EURUSD or AUDCAD; a `reason=4` means a chart was closed with its EA on: tell Claude):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 '{if(match($0,/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) && substr($0,RSTART,8)>=from && /fxgrind deinit reason=/ && match($0,/fxgrind \([A-Z]+,/)) print substr($0,RSTART+9,RLENGTH-10), $NF}'

## 4. RE-ATTACH EURUSD AND AUDCAD OPT FROM THE EXPERTS COPY (VNC; EURUSD first as the pilot)

**Remove, then Attach (cap10-reload s4.4, GW-5): never drag over a running EA, never F7** (F7 + Load keeps
the Scripts `.ex5`, C88). The book is unmanaged only for those seconds; a fill meanwhile is adopted at
reconstruction (precedent 1 Oct 06:32Z, NZDCAD_OPTD re-attached from Experts, clean). The start-up sees the
old exit label in the terminal (`GRIND_GEO_EXIT_<magic>_L/_S`) and rebuilds the exits (`rebuild=true`).

**The cap rule (D's s4, I7):** attach only when BOTH sides hold 6 layers or fewer, counted in the **Trade
tab** (positions on that symbol with comment `GRIND|OPT|L|` and `GRIND|OPT|S|`) immediately before the
Remove; pipshed lags up to 60 s. A side at 7 rests its `|L07|ENT` under cap 8, which the cap-7 EA neither
cancels nor re-uses (`grind_engine.mqh` 2492-2528): if it fills, the side holds 8 and halts on I7. A side at 7
or 8: wait, or flatten the chart (s3 steps 1-4, KEEP the chart) and attach it empty.

Per chart (FROM = the minute before the Remove):
1. Right-click the chart -> Expert Advisors -> Remove; gate as s3 step 1 (`deinit reason=1`, icon gone).
2. **Trade tab for that symbol, now: no resting `GRIND|OPT|L|L07|ENT` or `GRIND|OPT|S|L07|ENT`.** One can
   rest if a 7th layer filled between the count and the Remove; delete it NOW (no EA is attached to re-place
   it), then go on.
3. Drag **Navigator -> Expert Advisors -> fxmatrix -> fxgrind** (the Experts copy; never Scripts) onto the
   now-empty chart -> Inputs -> Load `<pair>_opt_c_t1.set` -> read back BEFORE OK: `InpMagic`,
   `InpTelemetryInstance` (`GRIND_<PAIR>_OPTC`), width, add, exit, the six per-side rows (`-1.0`), cap 7,
   `InpStrandedThreshPips`, deadband 2.0, lattice and re-roll true, roll gate 0, auto-eject and breaker
   false, the warning (`FLEET C two-arm t1 <PAIR> OPT -`), the key row not blank. Common tab: Algo Trading
   allowed. OK; note the UTC time.
4. The checker (as D's s4, same two commands):

       L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /home/khalid/fxmatrix-repo/scripts/build_logcheck.awk; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 '{if(match($0,/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) && substr($0,RSTART,8)>=from && /telemetry dropped/) n++} END{print "telemetry dropped since FROM:", n+0}'

   Expected one row: `deinit=1 replay=ready(N) lattice=true reroll=true gate=0 api=1000000/999000 geo=` and
   `rebuild=` as s0, BAD 0, a POST ok, `telemetry dropped since FROM: 0`. Exception: a single `WARN STARTUP_EXIT_SHORTFALL long=1 short=0` (or `0 / 1`) is the one BAD line allowed: an entry
   filled while no EA was attached and its exit is placed at start-up (`fxgrind.mq5` 271-282); check that
   layer's `|EXT` rests in the Trade tab. `long` or `short` >= 2 (`STARTUP_EXIT_SHORTFALL_SIDE`, CRITICAL) is a STOP.
5. **Trade tab for that symbol, again: no resting `GRIND|OPT|L|L07|ENT` or `GRIND|OPT|S|L07|ENT`.** If one rests,
   delete it by hand.
6. The build it loaded (desktop, `D:\pipshed`): `ea_build` = the Experts `.ex5` time of s2.6, NOT 7 Oct
   02:06:35:

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --table config_events --instance GRIND_EURUSD_OPTC --limit 2

The pilot's rows first; then AUDCAD.

**If a chart halts on I7 anyway** (`RECON_FAIL` / `I7_*_DEPTH`): F7 on the chart (it now runs the Experts
copy) -> Load `<pair>_opt_c_r3.set` (cap 8, staged 9 Oct) -> OK: the chart trades as before at cap 8. Tell
Claude; retry later under the cap rule.

## 5. ATTACH GBPCHF OPT, THEN THE THREE ALT CHARTS (VNC)

**GBPCHF first:** Market Watch -> right-click -> Symbols -> GBPCHF -> Show; its Specification: digits 5
(pip 0.0001; every geometry above assumes it) and Trade "Full access" (else `Grind_GuardsAllowTrading`
refuses every order silently, `grind_engine.mqh` 2001-2003): STOP if either is not. File -> New Chart -> GBPCHF; M5 (as C's charts).

Order: GBPCHF OPT (the new pair's pilot), then EURUSD ALT, AUDCAD ALT, GBPCHF ALT, one chart and one check at
a time. Per chart: drag **Navigator -> Expert Advisors -> fxmatrix -> fxgrind (the Experts copy)** (ALT on a
NEW chart of the pair, M5) -> Inputs -> Load `<pair>_<arm>_c_t1.set` -> the read-back of s4 step 2, with
`InpSlot` (OPT or ALT), the magic and instance of s0 (`GRIND_<PAIR>_OPTC` / `_ALTC`), the warning (`FLEET C
two-arm t1 <PAIR> OPT -`, `... ALT q95`, GBPCHF ALT `... ALT range guess`). OK; the s4 checker with FROM = the
minute before THIS chart's OK. Expected: `deinit=- replay=ready(0) lattice=true reroll=true gate=0
api=1000000/999000 geo=` as s0, `rebuild=false/false` (anything else on GBPCHF means an old label or deal
under its magic: STOP), BAD 0 (no `duplicate magic`), `telemetry dropped since FROM: 0`; two L0 orders resting
about `width` from mid (GBPCHF OPT 2.5 pips, the ALTs 7.0 / 7.0 / 6.0). The checker counts POST ok by SYMBOL
(two charts per pair); each new instance's own heartbeat (within about 60 s; `"status": "live"`):

    https://linuxc.pipshed.com/api/telemetry/live?instance=GRIND_<PAIR>_<ARM>C

(`GRIND_GBPCHF_OPTC`, `GRIND_EURUSD_ALTC`, `GRIND_AUDCAD_ALTC`, `GRIND_GBPCHF_ALTC`.)

## 6. AFTER (desktop, `D:\pipshed`)

1. Archive codes, last hour (expected `none.`; the start-up criticals included, Argon 18 Oct):

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --codes "ROLL_STRANDED,ROLL_CLOSING_STUCK,ROLL_REFUSED,DEAL_EVENT_MISSED,REPLAY_SEED_FAILED,EJECT_ACCEPTED,INVARIANT_FAIL,QUARANTINE_HALT,RECON_SCAN_RACE,RECON_FAIL,REBUILD_EXIT_FAILED,REBUILD_EXIT_UNREADABLE,STARTUP_EXIT_SHORTFALL_SIDE,API_LIMITS_MISMATCH,API_LIMITS_INVALID,WARN_API_ENTRY_STOP" --hours 1

2. `ea_build` of each of the six = the s2.6 Experts time (s4 step 6's command per instance). With the
   seven retired, no chart on wine-c loads the Scripts copy: **C88 closed** (record the six `ea_build`).
3. pipshed's C page still lists the old nine (the new ids appear at D's s7 merge): EURUSD and AUDCAD OPT
   LIVE; the seven retired CONNECTION LOST; GBPCHF and the ALTs in Redis (s5), not on the page yet.
4. Then D's s7 (pipshed merge, after D AND C; the Railway service "pipshed Fleet E"); its check: C's
   strip 6 / 6 LIVE.

## 7. STOP (before the next chart)

D's s8 list, all of it, plus: an init row at the Experts compile with BAD lines (s2.6); `cmp bad` not 0
(s2.5); a re-attached chart whose `ea_build` is still 7 Oct (it loaded the Scripts copy: Remove it and
attach again from Experts); GBPCHF not 5 digits or not Full access; s3's check not seven `reason=1` lines;
`STARTUP_EXIT_SHORTFALL` with 2 or more on a side, or a layer left without a resting `|EXT`; GBPCHF OPT not `replay=ready(0)` / `rebuild=false/false`;
a resting `|L07|ENT` on EURUSD or AUDCAD OPT after the attach that will not delete.

## 8. FOR THE REVIEWER (Argon, answered in s9): attack the premises, say which fact is missing

Quote the line of every source or runbook passage you cite; Claude checks each quote.

- **GC-1.** EURUSD and AUDCAD OPT by Remove-then-Attach from the Experts copy (fixes C88), not F7 + Load
  (keeps the Scripts `.ex5`). Is the gap safe with a live book: what does start-up do with a fill, an exit
  fill or an add fill that happened while no EA was attached (replay seed, deal history)?
- **GC-2.** Does the re-attach read the old exit label exactly as an F7 reload does (`rebuild=true`), or does
  `OnDeinit` reason 1 (`fxgrind.mq5` 396-405) or the attach clear it?
- **GC-3.** The add change with layers held (s0): Claude reads the resting add re-priced at the first grid
  step (`fxgrind.mq5` 289-292, `grind_engine.mqh` 2560-2571 and 3234-3237), and reconstruction adopting the
  resting `|Lnn|ENT` as `add_pending_ticket` (`grind_recon.mqh` 1079-1086), so no second add is sent. Confirm.
- **GC-4.** Compiling the Experts copy while nine charts run the Scripts copy (s2.6): can it re-init any chart,
  touch the Scripts `.ex5`, or change a running chart's `ea_build`?
- **GC-5.** GBPCHF's magics outside `GRIND_CAP_ALL_MAGICS` (C159): any use of that table other than the
  currency cap and the slot guard (`Grind_IsFleetMagic`) that matters for a magic outside it (orphan or
  ownership checks, replay, the archive)?
- **GC-6.** GBPCHF ALT at 24 / width 6 from the daily range (no fills on IC): any start-up check that fails on
  a new symbol with no history (spread sampling, deal history, the carry pass)?
- **GC-7.** What failure is not on s7? What fact is missing?

## 9. THE REVIEW (Argon, `de1c107`, on `3860a17`) AND CLAUDE'S CHECK

Every claim used below was checked in source at `3860a17`.

- **Taken:** (1) **an entry filled in the Remove-to-Attach gap** (GC-1): the start-up places its missing exit
  (`fxgrind.mq5` 271-282) but prints `WARN STARTUP_EXIT_SHORTFALL`, which `build_logcheck.awk` line 12 counts
  as BAD: one per side allowed and checked, two a STOP (`Grind_StartupShortfallCritical` is `>= 2`,
  `grind_pure.mqh` 283-286) (s4, s7); (2) a resting `|L07|ENT` checked and deleted between Remove and
  Attach, when no EA can re-place it (s4 step 2); (3) GBPCHF's Specification also "Full access"
  (`grind_engine.mqh` 2001-2003) (s5); (4) the seven `reason=1` lines after s3; (5) the archive check with
  the start-up criticals (`Grind_TelemetryCritical` archives its event as the code, `grind_telemetry.mqh`
  161-184) (s6, also D's s6); (6) the clamp's definition is `grind_exitq.mqh` 258 (s0, also D's s0).
- **Agreed answers:** GC-1 (deals in the gap are seeded as seen, `grind_replay.mqh` 149-184: no fill row for
  them; an exit filled in the gap passes `Grind_ReconExitMatchesEntry` as a filled exit, `grind_recon.mqh`
  385-395, and is closed by the derived Close By); GC-2 (`OnDeinit` writes the deinit GVs and frees the lock
  only: the exit label stays, `rebuild=true`); GC-3 (confirmed: adopted at `grind_recon.mqh` 1079-1086,
  re-priced once with 0.05 pips; if that one modify is refused the add rests at the old distance, 1 pip
  closer: acceptable); GC-4 (no); GC-5 (no other use: replay, recon, carry and archive filter by the chart's
  own magic); GC-6 (no check fails on a new symbol; ADR-153 ratio 4.0 on GBPCHF ALT passes at the limit).
- **Void (the reviewer invented):** every runbook passage it "quoted" in its findings 1-6 (`rebuilt=L:1/S:1`,
  "10-20 seconds per chart", "Any of: cmp DIFF or MISS", `InpFillTimePlace`, "First, add GBPCHF to Market
  Watch": none is in the runbook); `cap10-reload.md` 121-124 as quoted (not its text); the source quoted for
  `Grind_ExitQClampPassive` (it is `bool`, three arguments), for `grind_engine.mqh` 3234-3237 (argument order)
  and a comment at 2560 that does not exist. Its substance on GC-1..GC-6 held where checked.

Line count: 244
