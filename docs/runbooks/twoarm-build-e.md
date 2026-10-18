This message has a line count at the bottom

# RUNBOOK -- FLEET E: A NEW FTMO DEMO ON A NEW SERVER (wine-e); A AND THE WINDOWS VPS CLOSED

| | |
|---|---|
| Status | **DRAFT for review** (Claude, 18 Oct ~04:45Z). Built from D's and C's REVIEWED runbooks (`twoarm-build-d.md` `c39d59d`, `twoarm-build-c.md`), the box recipe (`handoffs/Handover/06_LINUX_WINE_BOX.md` s3, s9, s10) and the last FTMO switch (`ftmo-ic-start.md` s3-s12, run 7 Oct) |
| What | FTMO's fleet E: EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF with OPT + ALT, exit = add, cap 7, ALT at q90 (12 instances, fleet D note s10-s11), on a NEW FTMO demo, on a NEW Linux + wine server `wine-e`. Fleet A (FTMO 1514878887) is stopped and the Windows VPS closed |
| Uses | `main` `ceab0f7` or later: `ea/presets_e/<pair>_{opt,alt}_e_t1.set` (12 files, fingerprint `a448f4abb8a6`); `scripts/build_logcheck.awk`; pipshed `twoarm-fleets` `320afe6` (merged at D's s7) and a small pipshed patch for E's card (s9) |
| When | **Wed 21 Oct.** wine-e built any time before (s1; it needs no account). A off soon after 5 PM ET (21:00Z), after the carry pass (20:50-20:59Z). E's first chart after 6 PM ET (22:00Z), so its first FTMO day is full. Not within 30 minutes of a tier-1 release |
| Rulings | Operator 18 Oct ~04:00Z (HANDOFF s86): "we will make a new linux server. wine-e is fine"; "copy wine-d"; "new ftmo demo after this current one expires - same time limit. account size"; "utc is fine. we can only fit one terminal per vps"; close A "soon after 5PM ET - and then immediatley close the vps server"; "wait past 6PM ET on 21 Oct". 17 Oct: the layout, exit = add, q90 on FTMO, the request budget ("FTMO would be ok with 2500"). Presets G3: the breaker OFF on E |

## 0. AUDIT TRAIL AND WHAT E RUNS

| # | Fact | Where | Status |
|---|---|---|---|
| E1 | E's twelve presets = D's `_t1` but ALT's geometry (q90, not q95), the ids `_OPTE` / `_ALTE` and the warning; magics as D's (`2226` + pair + slot); a different account, so no clash | `diff ea/presets_e/eurusd_alt_e_t1.set ea/presets_d/eurusd_alt_d_t1.set` at `ceab0f7` | VERIFIED |
| E2 | Every E preset: cap 7, deadband 2.0, lattice and re-roll true, roll gate 0, `InpBreakerEnable=false`, auto-eject false, API 1000000 / 999000, session off | the twelve files | VERIFIED |
| E3 | E's twelve magics (22260101 to 22260602) are all in `GRIND_CAP_ALL_MAGICS` (`ea/grind_cap.mqh` 20-31): the slot guard counts their resting entries as designed (C159 does not apply) | source at `ceab0f7` | VERIFIED |
| E4 | The EA reads `TimeGMT()` for the FTMO day and the snapshot keys (`fxgrind.mq5` 358-423; `grind_engine.mqh` 1704-1723; `grind_snapshot.mqh` 261-356); no `TimeLocal()` in `fxgrind.mq5` or `grind_*.mqh`. Under Wine `TimeGMT()` follows the Linux clock: the box must be UTC and NTP-synchronised | `git grep` at `ceab0f7` | VERIFIED (source); the box clock read in s1.3 |
| E5 | FTMO free trials run 14 days from the first trade; opening a new trial meant closing the old one in FTMO's client area (7 Oct, 1514731800) | `ftmo-ic-start.md` s12 (s4, s5) | RECORDED |
| E6 | Twelve instances on FTMO: about 2,500 requests a day against FTMO's 2,000 (C106); A's seven used about 1,400-1,500. On a stressed day the guard reads about 180-192 of 194 (fleet D note s7): entries refused at the guard then are by design | backlog C106; note s10 | RECORDED (projection, not measured) |
| E7 | With the breaker off nothing in the EA stops at FTMO's daily loss ($500 on $10k) or overall loss; what FTMO does to a free trial at a breach is not known here | presets G3; `ftmo-ic-start.md` K3 | RULED (breaker off); FTMO's reaction UNKNOWN |
| E8 | pipshed's E card is a placeholder ("NOT BUILT") on `twoarm-fleets` (`app.py` 268-279: `placeholder` True, `built` False, `cycle_start` "2026-10-21"); `verify_twoarm_fleets.py` TA4 (E's fields) and TA7 (E NOT BUILT; books A-D) pin it; the new login needs a commission row in `sr_table.py` (an account not listed reads "unknown") | pipshed `320afe6` | VERIFIED |

**One worked example.** EURUSD at 1.1600 when E's EURUSD charts attach. OPT (width 2, add = exit 7) rests its
L0 straddle about 2 pips each side; ALT (width 6, add = exit 23) about 6 pips each side. A 50-pip fall fills
OPT's long stack to 7 layers by pip 42 (6 x 7) and rolls after; ALT holds 3 longs (L0 at 1.1594, adds at
1.1571 and 1.1548) and scalps each back at +23 pips.

| Chart | Magic | Instance | `geo=` (L w/a/e S w/a/e) | Stranded | Warning starts |
|---|---|---|---|---|---|
| GBPUSD OPT (pilot) | 22260101 | `GRIND_GBPUSD_OPTE` | L2.5/9/9 S2.5/9/9 | 3.5 | `FLEET E two-arm t1 GBPUSD OPT -` |
| EURUSD OPT | 22260201 | `GRIND_EURUSD_OPTE` | L2/7/7 S2/7/7 | 3.0 | `... EURUSD OPT -` |
| EURGBP OPT | 22260301 | `GRIND_EURGBP_OPTE` | L1/3/3 S1/3/3 | 2.0 | `... EURGBP OPT -` |
| AUDCAD OPT | 22260401 | `GRIND_AUDCAD_OPTE` | L1.5/6/6 S1.5/6/6 | 2.5 | `... AUDCAD OPT -` |
| AUDCHF OPT | 22260501 | `GRIND_AUDCHF_OPTE` | L1/4/4 S1/4/4 | 2.0 | `... AUDCHF OPT -` |
| CADCHF OPT | 22260601 | `GRIND_CADCHF_OPTE` | L1/4/4 S1/4/4 | 2.0 | `... CADCHF OPT -` |
| GBPUSD ALT | 22260102 | `GRIND_GBPUSD_ALTE` | L6/24/24 S6/24/24 | 7.0 | `... GBPUSD ALT q90` |
| EURUSD ALT | 22260202 | `GRIND_EURUSD_ALTE` | L6/23/23 S6/23/23 | 7.0 | `... EURUSD ALT q90` |
| EURGBP ALT | 22260302 | `GRIND_EURGBP_ALTE` | L4/16/16 S4/16/16 | 5.0 | `... EURGBP ALT q90` |
| AUDCAD ALT | 22260402 | `GRIND_AUDCAD_ALTE` | L7/27/27 S7/27/27 | 8.0 | `... AUDCAD ALT q90` |
| AUDCHF ALT | 22260502 | `GRIND_AUDCHF_ALTE` | L5.5/21/21 S5.5/21/21 | 6.5 | `... AUDCHF ALT q90` |
| CADCHF ALT | 22260602 | `GRIND_CADCHF_ALTE` | L2.5/9/9 S2.5/9/9 | 3.5 | `... CADCHF ALT q90` |

Every chart starts empty: `deinit=- replay=ready(0) rebuild=false/false` expected (a fresh terminal, no GVs).

## 1. BUILD wine-e (any day before; no account needed; ssh where possible)

Paste works in an ssh window and not reliably in VNC (operator, 18 Oct), so everything that is not a GUI
click is done by ssh. **Claude gives each command with wine-e's address filled in** (on the desktop:
`$E = 'root@<the address>'` once per PowerShell window, typed with the real address; never leave the
angle brackets: PowerShell reads them as redirections).

**1.1 Vultr (the operator).** Cloud Compute, Shared CPU `vc2-2c-4gb`, **Chicago** (as every box and the VPS),
Ubuntu 24.04 LTS x64, label `fxgrind-wine-e`, hostname `wine-e`; the desktop's SSH key if it is on the Vultr
account (else root's password). Record the address and the creation time (UTC).

**1.2 Upgrade, then reboot while empty** (06 s9). As root over ssh: `apt update && apt -y upgrade` (answer
**No** to the PAM "override local changes" prompt: Vultr's root login depends on it), then `reboot`.

**1.3 The clock, then Wine 9 from Ubuntu** (06 s2: NEVER the WineHQ repository; Wine 11 does not run MT5).
After the reboot, one block (expected: `Time zone: Etc/UTC (UTC, +0000)`, `System clock synchronized: yes`,
then `wine-9.0`):

    uname -r; timedatectl | grep -E 'Time zone|synchronized'; dpkg --add-architecture i386 && apt update && apt -y install wine64 wine32 winbind xfce4 xfce4-goodies xrdp x11vnc git && wine --version

STOP if the zone is not UTC or the clock is not synchronised (E4): `timedatectl set-timezone Etc/UTC`, then
read again.

**1.4 The user and the desktop session** (`adduser` asks the password in the ssh window):

    adduser khalid && usermod -aG sudo khalid && echo xfce4-session > /home/khalid/.xsession && chown khalid:khalid /home/khalid/.xsession && systemctl enable --now xrdp

**1.5 The repo** (expected: the commit of `main`, e.g. `ceab0f7`, and an EMPTY diff line):

    sudo -u khalid git clone -q https://github.com/theonlykk/fxmatrix /home/khalid/fxmatrix-repo && sudo -u khalid git -C /home/khalid/fxmatrix-repo log --oneline -1 | cut -c1-10 && sudo -u khalid git -C /home/khalid/fxmatrix-repo diff --stat 5bb5fdb HEAD -- 'ea/*.mq5' 'ea/*.mqh'

**1.6 The telemetry key, box to box** (never through chat or the desktop's disk). On **wine-d** as root:
`scp /home/khalid/.fxgrind_telemetry.key root@<wine-e>:/home/khalid/` (Claude fills the address). Then on
wine-e (expected `44` and `fc6b3d9c56a8`, as on wine-d, 06 s10):

    chown khalid:khalid /home/khalid/.fxgrind_telemetry.key && chmod 600 /home/khalid/.fxgrind_telemetry.key && wc -c < /home/khalid/.fxgrind_telemetry.key && sha256sum /home/khalid/.fxgrind_telemetry.key | cut -c1-12

**1.7 GUI, first session (RDP; VNC after).** Desktop: `ssh -L 3393:localhost:3389 $E` (leave it open), `mstsc`
to `localhost:3393`, session Xorg, user `khalid` (3393: never mixes with the other boxes' tunnels). In the
XFCE session, a terminal: `WINEPREFIX=~/.mt5 winecfg` (no to Mono / Gecko; the `err:ole ... RpcSs` lines are
noise; Windows 10 is the default), then

    wget -O ~/mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" && WINEPREFIX=~/.mt5 wine ~/mt5setup.exe

(the installer's own Next / Finish clicks). Close the MT5 the installer started; start it detached from the
terminal, then close the terminal (06 s9: a terminal-started MT5 dies with its terminal; the Wine menu entry
does not start it):

    setsid nohup env WINEPREFIX=$HOME/.mt5 wine "$HOME/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/dev/null 2>&1 &

Then x11vnc for every later session, as root by ssh (the display from `pgrep -u khalid -af Xorg`, `:10`
expected): `sudo -u khalid x11vnc -display :10 -auth /home/khalid/.Xauthority -localhost -rfbport 5913 -nopw
-forever -noipv6 -shared -noxdamage -bg -o /tmp/x11vnc-e.log`; desktop tunnel `ssh -o ServerAliveInterval=15
-L 5913:localhost:5913 $E`, viewer on `localhost::5913`. Close the RDP session before using VNC (stale RDP
tunnels have wedged X, 02_TRAPS 1 Oct).

**1.8 Terminal options (GUI).** Tools -> Options -> Expert Advisors: "Allow WebRequest for listed URL"
ticked, `https://pipshed.com` typed in the list; Trade: One Click Trading OFF. **Algo Trading OFF** (toolbar).
No account yet. (A MetaTrader LiveUpdate right after install may refresh components: let it, nothing is
attached.)

**1.9 The EA into Experts ONLY, then compile.** Experts only, so no chart can ever load a Scripts copy (C88).
As root by ssh (expected `cmp ok=79 bad=0`, the count of `ea/*.mq5` + `ea/*.mqh` at `ceab0f7`; Claude
re-counts on the day):

    R=/home/khalid/fxmatrix-repo; M="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"; sudo -u khalid mkdir -p "$M/Experts/fxmatrix" && sudo -u khalid cp $R/ea/*.mq5 $R/ea/*.mqh "$M/Experts/fxmatrix/" && ok=0; bad=0; for f in $R/ea/*.mq5 $R/ea/*.mqh; do if cmp -s "$f" "$M/Experts/fxmatrix/$(basename "$f")"; then ok=$((ok+1)); else bad=$((bad+1)); fi; done; echo "cmp ok=$ok bad=$bad"

MetaEditor (GUI): Navigator -> Experts -> Refresh; open `MQL5\Experts\fxmatrix\fxgrind.mq5`, Compile: `0
errors, 0 warnings`; then `fxgrind_tests.mq5` the same, ONE file at a time. The suite waits for an account
(s6).

**1.10 Stage E's presets with the key** (as D's s2.3-2.4; expected `a448f4abb8a6`, `12`, then 12 lines
`SAME_EXCEPT_KEY key_len=43`):

    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_e/*_t1.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_e/*_t1.set | wc -l)

    K=$(tr -d '\r\n' < /home/khalid/.fxgrind_telemetry.key); P="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Presets"; R=/home/khalid/fxmatrix-repo; sudo -u khalid mkdir -p "$P"; for f in $R/ea/presets_e/*_t1.set; do sed "s|^TelemetryAPIKey=.*|TelemetryAPIKey=$K|" "$f" | sudo -u khalid tee "$P/$(basename $f)" >/dev/null; done; unset K; for f in $R/ea/presets_e/*_t1.set; do b=$(basename $f); if diff -q <(grep -v '^TelemetryAPIKey=' "$P/$b") <(grep -v '^TelemetryAPIKey=' "$f") >/dev/null; then k=$(grep '^TelemetryAPIKey=' "$P/$b" | cut -d= -f2- | tr -d '\r\n' | wc -c); echo "SAME_EXCEPT_KEY key_len=$k $b"; else echo "MISMATCH $b"; fi; done

wine-e is ready: MT5 running detached, Algo OFF, no account, EA compiled, presets staged. If `main` moves
before Wednesday, s1.5's pull and s1.9-1.10 are repeated on the day (`git pull --ff-only` first).

## 2. WEDNESDAY BEFORE 20:45Z (desktop)

- D's and C's builds done and pipshed `twoarm-fleets` merged (D's s7): the Railway service "pipshed Fleet
  E" exists (`GRIND_FLEET=E`, `linuxe.pipshed.com`; Cloudflare CNAME `linuxe` proxied and the
  `_railway-verify.linuxe` TXT by hand, 06 s9 step 10). If C slipped: E still runs; its card waits (s9).
- wine-e: `pgrep -a terminal64` shows one MT5; `pgrep -a x11vnc` shows the 5913 line; the repo at `main`.
- The FTMO calendar for 21:00-23:00Z: no tier-1 release.

## 3. A's LAST HOUR AND ITS RECORDS (from ~21:00Z, after the carry pass)

1. The carry pass for every fleet as usual (BOOT s6), A's seven included: then A is no longer needed.
2. **A's final status** (pipshed status read, fresh URL segment, plain text; saved whole): live, halts,
   `api_count`, balance, equity, open MTM. VPS Toolbox: balance, equity, positions, orders (written here).
3. **VPS: Algo Trading OFF**, then remove the EA from all seven charts (right-click -> Expert Advisors ->
   Remove). Experts tab: seven `fxgrind deinit reason=1`. Positions and orders are left as they are (the
   trial is closed with them; the dump below records them).
4. **Desktop terminal** (logged in to 1514878887, Algo off): `grind_history_dump.mq5` -> Downloads
   `history_1514878887.csv` (`HISTDUMP|deals=...|bad=0`). The operator: FTMO MetriX for 1514878887 as a PDF
   into Downloads.
5. **A's archives** (desktop, `D:\pipshed`; new names; then sizes, hashes and first lines as plan 3's
   export step 2):

       foreach ($p in 'GBPUSD','EURUSD','EURGBP','AUDCHF','CADCHF','NZDCAD','AUDNZD') { railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-archive --instance "GRIND_${p}_OPT" | Set-Content -Encoding utf8 "$HOME\Downloads\archive_${p}_OPT_2026-10-21_final.jsonl" }

## 4. THE WINDOWS VPS: WHAT LEAVES IT, THEN IT CLOSES (the operator)

1. **Nothing unpushed** (VPS PowerShell; expected `## main...origin/main` plus the known stray
   `deploy_presets.ps1`, then no commit line, then every `vps-*` tag also on origin):

       cd C:\fxmatrix; git status -sb; git fetch -q origin; git log --oneline origin/main..HEAD; git tag -l "vps-*"; git ls-remote --tags origin "vps-*"

2. **The files only the VPS holds**, zipped: `C:\fxmatrix-local` (cycle 3's binary, the checker's copies), the
   Experts logs (`MQL5\Logs`) and the Journal (`logs`), each under its own name (the two `logs` folders
   would collide in one zip root):

       $T = "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850"; $Z = "C:\vps_final_2026-10-21"; New-Item -ItemType Directory -Force $Z | Out-Null; Copy-Item -Recurse C:\fxmatrix-local "$Z\fxmatrix-local"; Copy-Item -Recurse "$T\MQL5\Logs" "$Z\experts_logs"; Copy-Item -Recurse "$T\logs" "$Z\journal_logs"; Compress-Archive -Path "$Z\*" -DestinationPath "$Z.zip"; Get-FileHash "$Z.zip" -Algorithm SHA256

   Copied to the desktop's Downloads (the RDP window's copy and paste, or `\\tsclient\` if drives are
   shared); `Get-FileHash` on the desktop equal.
3. **Close it:** Vultr -> the VPS -> (Claude suggests a snapshot first: cents a month, rebuilds in minutes, 06
   s8) -> Destroy. Irreversible: only after 1 and 2 are clean. The desktop terminal keeps 1514878887's
   login (read-only use) until the trial is gone.

## 5. THE NEW FTMO DEMO AND ITS LOGIN (the operator; ~21:30Z)

- The operator opens the new free trial: **$10,000, 14 days** (operator 18 Oct; E5: the old one may have
  to be closed first). Claude never creates accounts; login, password and server are never pasted into a
  chat. FTMO's rules for it read in the client area: daily and overall loss, the end date (written here).
- wine-e (VNC): File -> Login to Trade Account; the server `FTMO-Demo` (if it is not in the list: File ->
  Open an Account -> search "FTMO" -> pick FTMO's entry -> Cancel; then it appears, as IC's did, 06 s9).
- Read by ssh, not by eye (expected one `authorized on FTMO-Demo` line with the NEW login, and a hedging
  line; the journal is UTF-16LE, named by the UTC day):

      L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/logs/$(date -u +%Y%m%d).log"; iconv -f UTF-16LE -t UTF-8 "$L" | grep -a -o "'[0-9]*': authorized on [^ ]*" | tail -2; iconv -f UTF-16LE -t UTF-8 "$L" | grep -a -i 'hedging' | tail -1

- Toolbox -> Trade: $10,000, zero positions, zero orders. STOP on a netting account (Close By needs hedging).

## 6. THE SUITE, ONCE, BEFORE ANY EA (Algo OFF)

On a GBPUSD chart (M5): drag `fxgrind_tests` from the Navigator; it places no order (06 s7 step 5).
Expected `SUMMARY` 2597 / 2597 (the EA suite at `5bb5fdb`, BOOT s6), then close that chart; F3 (Global
Variables): EMPTY. **Never run it again on wine-e once an EA is attached** (it deletes shared GVs by prefix:
02_TRAPS 25 Sep, C52). A different total: STOP, tell Claude.

## 7. ATTACH (from 22:05Z; the pilot, then five OPT, then six ALT)

**Spreads first** (Market Watch, points): hold a pair whose spread is above 2 x its OPT width (EURUSD 40,
GBPUSD 50, AUDCAD 30, EURGBP / AUDCHF / CADCHF 20); 7 Oct at 22:07Z the CHF crosses read 10-12 and the NZD
crosses 61-88 (held until 22:15Z). **Algo Trading ON** (on this terminal an EA attached with Algo off stays
inactive, so each EA trades from its OK: the read-back is the only gate, ftmo-ic-start GF-1).

Per chart: File -> New Chart -> the symbol, M5; drag **Navigator -> Expert Advisors -> fxmatrix ->
fxgrind**; Inputs -> Load `<pair>_<arm>_e_t1.set` -> read back BEFORE OK: `InpMagic`, `InpSlot`,
`InpTelemetryInstance` and the warning as s0, width / add / exit, the six per-side rows (`-1.0`), cap 7,
`InpStrandedThreshPips`, deadband 2.0, lattice and re-roll true, roll gate 0, auto-eject false, **breaker
false**, API 1000000 / 999000, the key row not blank. A row not as s0: Cancel, never OK. OK; note the UTC
time. ALT on its OWN new chart of the pair (two charts per symbol).

The checker (as D's s4; FROM = the minute before the chart's OK; one row per chart since FROM):

    L="/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5/MQL5"/logs/$(date -u +%Y%m%d).log; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 -f /home/khalid/fxmatrix-repo/scripts/build_logcheck.awk; iconv -f UTF-16LE -t UTF-8 "$L" | tr -d '\r' | awk -v from=HH:MM:00 '{if(match($0,/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) && substr($0,RSTART,8)>=from && /telemetry dropped/) n++} END{print "telemetry dropped since FROM:", n+0}'

Expected per chart: `deinit=- replay=ready(0) lattice=true reroll=true gate=0 api=1000000/999000 geo=` as
s0, `rebuild=false/false`, BAD 0 (no `duplicate magic`, no `STARTUP_EXIT_SHORTFALL`: a flat attach has no
exit to place), a POST ok, `telemetry dropped since FROM: 0`; two L0 orders resting about `width` from mid.
Each instance's own heartbeat (the checker counts POST ok by SYMBOL; any page service reads the shared Redis
state; `"status": "live"` within about 60 s), the address in plain text:

    https://linuxd.pipshed.com/api/telemetry/live?instance=GRIND_GBPUSD_OPTE

1. **Pilot GBPUSD OPT**; its row and its heartbeat; five minutes: the L0 straddle at mid +/- 2.5, the account
   $10,000.
2. EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF OPT, one chart and one check at a time.
3. The six ALT in s0's order, one chart and one check at a time.

## 8. AFTER (desktop, `D:\pipshed`)

1. The pilot's newest `INIT` row: the NEW `account_login`, `ea_build` = s1.9's compile:

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --table config_events --instance GRIND_GBPUSD_OPTE --limit 2

2. Archive codes, last hour: D's s6 list, expected `none.`.
3. `LATTICE_CONFIG` 12 in the last hour (`--codes "LATTICE_CONFIG" --hours 1`), all `_OPTE` / `_ALTE`.

## 9. PIPSHED: E's CARD (Claude's patch; the operator pushes after s7's pilot)

Built by Claude once the login exists, on pipshed `main` after the `twoarm-fleets` merge (no Argon: a config
flip with no order path, operator 18 Oct): E's `placeholder` False and `built` True; `cycle_start` = E's
first FTMO day (an attach after 22:00Z Wed 21 Oct: `"2026-10-22"`); the new login's row in `sr_table.py`
(0.06 a close, FTMO's measured rate, checked on the new ledger after the first closes); TA4 and TA7 updated
to the built card. **Every `scripts/verify_*.py` run at the base and with the patch on a fresh clone; if any
check other than TA4 / TA7 changes, the flip becomes a prompt (Argon, Cursor).** The operator `git am`s it,
checks the tree, pushes outside 20:50-21:00Z. Check: E's card LIVE 12 / 12 on `https://linuxe.pipshed.com`.

## 10. THE FIRST FTMO DAY (Thu 22 Oct, 22:00Z to 22:00Z)

- Status reads as A's: live, halts, recon and invariant ok, `api_count`, the day's P&L against FTMO's daily
  limit (the breaker is off: nothing stops at it, E7).
- **Requests (C106, E6):** above 1,700 by 14:00Z (A's GF-4 trigger of 1,000 for seven, x 12 / 7), or above
  2,000 for a day: tell Claude the same hour. Any FTMO email about requests: tell Claude at once. The EA's
  counter resets at server midnight (21:00Z), the FTMO day at 22:00Z.
- The first scalp per arm, the first roll, the first `DAILY_SNAPSHOT` at 22:00Z.
- E is not changed during the trial except for a defect (as A, ftmo-ic-start s10).

## 11. STOP (before the next step)

D's s8 list, all of it, plus: the box clock not UTC or not synchronised; `wine --version` not 9.0; `cmp bad`
not 0; a compile not 0 / 0; the presets fingerprint not `a448f4abb8a6` or any MISMATCH; a key not 44 bytes or
not `fc6b3d9c56a8`; a login not on `FTMO-Demo`, a netting account, or a balance not $10,000; the suite not
2597 / 2597, or GVs not empty after it; any `STARTUP_EXIT_SHORTFALL` at a flat attach; a row other than
`rebuild=false/false`; s4.1 showing an unpushed commit or a tag not on origin (the VPS is not destroyed
then); an FTMO email about requests or a breach.

## 12. FOR THE REVIEWER (Argon): attack the premises, say which fact is missing

Quote the line of every source or runbook passage you cite (file and line at the commit); Claude checks each.

- **GE-1.** The EA in Experts only (s1.9), no Scripts copy: anything in the build, the suite or the scripts
  we run on a box (tick and history dumps, GV tools) that needs `Scripts\fxmatrix`?
- **GE-2.** The suite once on the new FTMO account before any EA (s6): can it place a request, start the
  trial's clock, or leave state an EA reads (GVs, files in `MQL5\Files`)?
- **GE-3.** E4: is there any place where the EA or the telemetry derives the FTMO day or a snapshot key from
  anything but `TimeGMT()` and `TimeTradeServer()` (e.g. `TimeCurrent()` on the dashboard's side), so that a
  wrong box clock would still matter, or not matter?
- **GE-4.** Twelve instances on one FTMO account, cap 7 (E6): the slot guard (`grind_exitq.mqh` 105-161) at
  about 180-192 of 194; does anything other than refused entries happen near the guard (exits keep 1 slot)?
- **GE-5.** Breaker off on FTMO (E7): any path in the EA that assumes the breaker is on for an FTMO account
  (the pre-midnight halt, the day anchor, the archive's DAILY rows)?
- **GE-6.** The attach rule (s7): the spread hold at 2 x OPT width, and from 22:05Z; enough, or too strict?
- **GE-7.** The order: A off and the VPS closed (s3-s4) before E attaches (s7), with the desktop terminal
  still on 1514878887. Any reason to keep the VPS until E's first day is clean?
- **GE-8.** What failure is not on s11? What fact is missing?

Line count: 282
