This message has a line count at the bottom

# THE LINUX / WINE BOX

A second machine that can compile `fxgrind` and run the suite. Built
2026-09-20. **Since 2026-09-24 it runs FLEET B** (IC Markets demo 53066709,
Algo ON, `docs/architecture/fleet-b.md`) -- a different account from cycle
3, so the order limit and the GlobalVariable store are NOT shared. Never log
this terminal into the FTMO account while Algo is on.

---

## 1. WHAT IT IS

| | |
|---|---|
| Provider | Vultr, same account as the production box |
| Instance | `fxgrind-wine-test`, Shared CPU `vc2-2c-4gb`, 2 vCPU / 4 GB / 80 GB |
| Region | Chicago -- matched to the production Windows VPS |
| Cost | 20 USD/month, billed hourly; destroy when idle |
| OS | Ubuntu 24.04 LTS |
| IP | 207.148.14.197 (production Windows box is 149.28.123.38 -- do not confuse them) |
| Login | root (Vultr password), plus user `khalid` for the desktop session |

**It is not capacity relief.** The 200 positions+orders limit is per
ACCOUNT. A second terminal on the same account shares that limit and,
worse, has its own GlobalVariable store -- so the slot lock and the
commitment guard stop being fleet-wide. Hence: never Algo ON here on the
SAME account as the VPS. Fleet B is a different account, so it is safe.

---

## 2. WINE VERSION -- THE ONE THING THAT MATTERS

**Wine 11 does NOT work. Wine 9 does.**

MT5's installer aborts under Wine 11 with "A debugger has been found
running in your system". It is a known MetaQuotes/Wine incompatibility
reported since January 2026 on Ubuntu, openSUSE and macOS; deleting the
`AeDebug` registry keys does not fix it, and neither does the official
`mt5ubuntu.sh` / `mt5linux.sh` script, which installs Wine from WineHQ
(now 11.x).

**Do NOT add the WineHQ repository.** Ubuntu 24.04's own packages are
Wine 9.0 and work:

    sudo apt -y install wine64 wine32 winbind

If a rebuild ever needs Wine 10, it is available from WineHQ pinned by
version (`apt-cache madison winehq-stable`), but 9.0 from Ubuntu is
simpler.

---

## 3. BUILD FROM SCRATCH

As root over SSH:

    ufw allow 22/tcp && ufw --force enable
    apt update && apt -y upgrade
    apt -y install xfce4 xfce4-goodies xrdp
    dpkg --add-architecture i386
    apt -y install wine64 wine32 winbind
    adduser khalid
    usermod -aG sudo khalid
    echo xfce4-session > /home/khalid/.xsession
    chown khalid:khalid /home/khalid/.xsession
    systemctl enable --now xrdp

Answer **No** to the PAM "override local changes" prompt -- Vultr's own
auth config is what the root password login depends on.

Then MT5, as `khalid` in the desktop session:

    WINEPREFIX=~/.mt5 winecfg          # no to Mono/Gecko, set Windows 10
    wget -O ~/mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
    WINEPREFIX=~/.mt5 wine ~/mt5setup.exe

---

## 4. REACHING THE DESKTOP

**RDP is NOT open to the internet** -- only port 22 is. Tunnel it. In a
PowerShell window ON THE DESKTOP (not an SSH session):

    ssh -L 3390:localhost:3389 root@207.148.14.197

Leave that window open, then `mstsc` to `localhost:3390`, session
**Xorg**, user `khalid`.

**If RDP will not log you in** (the login box reappears; sesman log:
"window manager ... exited quickly"), `xrdp-sesman` has lost the running
session (02_TRAPS, 2026-09-26). Do NOT reboot while Fleet B runs. Attach
x11vnc to the live display instead (installed 26 Sep). In SSH as root:

    sudo -u khalid x11vnc -display :10 -auth /home/khalid/.Xauthority -localhost -rfbport 5910 -nopw -once -shared -noxdamage -bg -o /tmp/x11vnc-khalid.log

(`:10` is the display on 26 Sep; check with `pgrep -u khalid -af Xorg`.)
Then, in a second PowerShell window on the desktop, `ssh -L
5910:localhost:5910 root@207.148.14.197`, and point the VNC viewer at
`localhost::5910`. Localhost only, behind SSH; it exits when the viewer
disconnects (rerun to reconnect). It is the LIVE desktop.

**RDP feels sluggish; the box is not.** Every redraw crosses Chicago to
Toronto. The same compile takes ~6.8 s here against ~10.8 s on the
desktop. Close MT5's chart windows, drop the RDP colour depth, and use
SSH for anything that does not need a GUI.

---

## 5. PATHS -- DIFFERENT FROM THE WINDOWS BOXES

This install is PORTABLE: MetaEditor and the terminal both use the
install directory, NOT `AppData`. An `AppData\...\Terminal\<hex>` folder
exists and is a decoy -- files copied there are invisible to the editor.

| | |
|---|---|
| Wine prefix | `~/.mt5` |
| Install | `~/.mt5/drive_c/Program Files/MetaTrader 5` |
| MQL5 root | `~/.mt5/drive_c/Program Files/MetaTrader 5/MQL5` |
| EA source | `<MQL5 root>/Experts/fxmatrix` |
| From Wine dialogs | the Linux filesystem is drive `Z:`, e.g. `Z:\home\khalid\...` |

Copy source in from the desktop:

    scp -r D:\fxmatrix\ea root@207.148.14.197:/home/khalid/      # run on the DESKTOP
    # then, on the box:
    INSTALL=~/.mt5/drive_c/Program\ Files/MetaTrader\ 5/MQL5
    mkdir -p "$INSTALL/Experts/fxmatrix"
    cp ~/ea/*.mq5 ~/ea/*.mqh "$INSTALL/Experts/fxmatrix/"
    ls "$INSTALL/Experts/fxmatrix" | wc -l                        # expect 66

After copying, right-click Experts in MetaEditor's Navigator -> Refresh,
or the tree will not show the folder.

---

## 6. STATUS 2026-09-20

Proven:

- MT5 installs and runs under Wine 9 on Ubuntu 24.04.
- It connects to **FTMO-Demo** and shows the live book (algo OFF).
- MetaEditor compiles `fxgrind.mq5`: **0 errors, 0 warnings, 6787 ms**.
- The terminal's own full recompile: 131 files, no errors.

Done since (2026-09-24): the suite (1766/1766), telemetry to pipshed, the
pending restart. Fleet B runs here (section 7).

Not done yet (original list, now superseded):

- `fxgrind_tests` has not been compiled or run here. Run it in the
  **Strategy Tester**, not on a live chart, so nothing touches the
  account; compare the pass count against the desktop at the same commit.
- Telemetry to pipshed from this box has not been exercised.
- The box has a pending `*** System restart required ***` from its
  first upgrade.

Gotchas met on the way, all avoidable next time:

- The FTMO-branded installer URL 404s; the MetaQuotes generic one works.
- Logging into the wrong server (`FTMO-Server`) fails with "Invalid
  account"; the demo is on `FTMO-Demo`.
- One-click trading panels are ON by default on new charts. Turn them off
  (Tools -> Options -> Trade) -- a stray click sends a market order on the
  live demo.
- Pasting several commands at once loses everything queued behind an
  interactive prompt. Paste one at a time.

---

## 7. RUNNING FLEET B (2026-09-24)

Done that night, in order; each step is repeatable.

1. **Access.** Only port 22 is open. From the desktop: `ssh root@207.148.14.197`
   works; for the desktop session run `ssh -L 3390:localhost:3389
   root@207.148.14.197` in its own PowerShell window and `mstsc` to
   `localhost:3390`, session Xorg, user `khalid`. If RDP will not log in,
   use x11vnc (s4); do NOT reboot while Fleet B runs (02_TRAPS 26 Sep).
2. **Account.** IC Markets demo **53066709** (`ICMarketsSC-Demo`), opened on
   the IC Markets website (no ID needed when the field is left blank), then
   File -> Login in this terminal. Title bar must read `... - Hedge - Raw
   Trading Ltd`.
3. **Terminal options.** Tools -> Options: Expert Advisors -> allow
   WebRequest for `https://pipshed.com`; Trade -> One Click Trading OFF.
4. **Code, by git on the box** (no scp): `~/fxmatrix-repo` is a clone;
   `git -C ~/fxmatrix-repo pull --ff-only`, then copy `ea/*.mq5 ea/*.mqh`
   into BOTH `<MQL5 root>/Experts/fxmatrix` and `<MQL5 root>/Scripts/fxmatrix`
   (67 files each at `85cd555`; check with `cmp`), Refresh in MetaEditor,
   compile `fxgrind.mq5` and `fxgrind_tests.mq5`.
5. **Suite, ONLY on a box with no live EAs:** run `fxgrind_tests` on a
   GBPUSD chart (Algo off is fine; it does not trade). 1766/1766 at
   `85cd555`, before Fleet B attached. **Never on this box now:** Fleet B
   is live here, and the suite deletes shared carry, eject and VL GVs by
   prefix, which trips I6 fleet-wide (traps 2026-09-25 C52). Skip this
   step on a live box; the desktop runs the suite.
6. **Telemetry key:** in `~/.fxgrind_telemetry.key` (outside the repo,
   `chmod 600`, 44 bytes). Never in git, never pasted in chat.
7. **Presets:** `ea/presets_b/*_b.set` from the repo, written into
   `<MQL5 root>/Presets` with the key substituted by `sed` into the
   `TelemetryAPIKey=` line; check `SAME_EXCEPT_KEY` against the repo copy.
8. **Attach:** Algo Trading ON first; one pilot (GBPUSD) until
   `grind telemetry POST ok` appears, then the other ten.
9. **Logs:** `<MQL5 root>/logs/YYYYMMDD.log` (lowercase `logs`, UTC date,
   UTF-16) and `<install>/logs/YYYYMMDD.log` for the journal. Heartbeats
   per instance: `iconv -f UTF-16LE -t UTF-8 <log> | grep -o
   'TELEM|GRIND_[A-Z]*_[A-Z]*|HEARTBEAT' | sort | uniq -c`.
10. **Read it from anywhere:** the Fleet B dashboard `https://linux.pipshed.com`
    (or `https://pipshed-copy-production.up.railway.app`), or JSON at
    `https://pipshed.com/api/g/k7m9p2x4q/status_b/<n>`.

The box clock is UTC.

## 8. IF IT IS NOT NEEDED

Destroy the instance (billing is hourly) or take a snapshot first, which
costs pennies a month and rebuilds in minutes.

## 9. BOX 2 = FLEET C (C70, 27 Sep; cycle-4 note s8.12)

**Instance:** Vultr `fxgrind-wine-c`, Chicago, Ubuntu 24.04, vc2-2c-4gb,
built FRESH (a snapshot of box 1 would carry its 53066709 login and Algo
ON). IP: **64.177.116.219** (created 03:55Z 27 Sep). **Account:** IC
Markets Raw demo **53071896** (Hedge, USD, 1:100, $10k, one deposit),
`ICMarketsSC-Demo`, Raw Trading Ltd. Built 27 Sep 03:55-04:46Z; record in
`docs/architecture/fleet-c.md` s5.

**Build:** s3 as root (Wine 9 from Ubuntu's own packages, s2; no
WineHQ), MT5 as `khalid`; s4 access with THIS box's IP (RDP should work
on a fresh box; x11vnc is the fallback).
**Access (box 2):** RDP through `ssh -L 3391:localhost:3389
root@64.177.116.219` and `mstsc localhost:3391` (3391, so it never mixes
with box 1's 3390); x11vnc is installed for the s4 fallback (use port
5911 for box 2 if both are open at once). The prompt names the box:
`fxgrind-wine-test` = box 1, `fxgrind-wine-c` = box 2. Then s7 steps 2-9 with these
changes:
- Step 2: the new demo; title bar `... - Hedge - Raw Trading Ltd`.
- Step 4: `git clone https://github.com/theonlykk/fxmatrix ~/fxmatrix-repo`
  at `main` (v2.1, NOT `5685e4f`); copy `ea/*.mq5 ea/*.mqh` into both
  Experts/fxmatrix and Scripts/fxmatrix, `cmp` each, compile
  `fxgrind.mq5` and `fxgrind_tests.mq5` 0/0.
- Step 5: box 2 has no live EAs until Monday, so the suite MAY run here
  ONCE, before any attach (GBPUSD chart; expect 2220/2220): it checks
  v2.1 under Wine. Never again once an EA is attached.
- Step 6: the same key as box 1, copied without passing through chat
  (44 bytes, `chmod 600`).
- Step 7: `ea/presets_c/*_c.set` (ids `GRIND_<PAIR>_OPTC`/`_ALTC`,
  Fleet B's dialled values, per-side inputs at -1; C70).
- Step 8: MONDAY in session, not before. Check lines per instance:
  `GRIND_GEOMETRY`, `GRIND_REBUILD`, `GRIND_LATTICE enable=false`, clean
  recon, POST ok.
- Step 10: the Fleet C page (third Railway web service "pipshed Fleet
  C", `GRIND_FLEET=C`), `https://linuxc.pipshed.com`; JSON at
  `https://pipshed.com/api/g/k7m9p2x4q/status_c/<n>`. Built by
  duplicating Fleet B's web service: change `GRIND_FLEET` and the label,
  check no `DATABASE_URL`; custom domain port = the generated domain's;
  add the CNAME (proxied) and the `_railway-verify` TXT by hand in
  Cloudflare (not "Connect").

**Learned building box 2 (27 Sep); use for box 3:**
- Vultr's Ubuntu image already has ufw with 22/tcp allowed ("Skipping
  adding existing rule" is fine).
- After `apt -y upgrade`, REBOOT while the box is still empty (a kernel
  upgrade is usually pending; box 1 carried one for days and later could
  not reboot under a live fleet).
- `dpkg --add-architecture i386` needs `apt update` BEFORE `apt -y install
  wine64 wine32 winbind` (06 s3 omits it). `wine --version` must print
  `wine-9.0`.
- Install `x11vnc` at build time, before anything trades (06 s4 fallback).
- The first `winecfg` prints `err:ole ... RpcSs` lines: noise. Wine 9
  defaults to Windows 10.
- MT5 started from a terminal dies with that terminal. The Wine menu
  entry does NOT start it (its `Exec` calls `wine-stable`, a WineHQ name;
  Ubuntu's package installs `wine`). Start it detached, from a terminal
  in the desktop session, then close the terminal:
  `setsid nohup env WINEPREFIX=$HOME/.mt5 wine "$HOME/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/dev/null 2>&1 &`
- MT5 build 6230 logs "unstable and unsupported Wine 9.0 ... upgrade to
  Wine 10.0": a warning only (C71). A LiveUpdate right after install may
  only refresh components (`mt5onnx64`); restart when nothing is attached.
- IC server in the Login dropdown: pick **IC Markets Ltd /
  ICMarketsInternational** in File -> Open an Account (then cancel) and
  `ICMarketsSC-Demo` appears. Before authorisation the title reads
  "Netting" whatever the account is; trust the Journal line
  `demo account - hedging mode` and the title AFTER login.
- Read which server a box uses without touching its GUI: in `<install>/logs`,
  `iconv -f UTF-16LE -t UTF-8 <log> | grep -a -o "'[0-9]*': authorized on [^ ]*"`.
- The key: `scp` it box 1 -> box 2 as root, then `chown khalid:khalid`,
  `chmod 600`; compare `sha256sum | cut -c1-12` on both boxes.
- The suite on a terminal that never had an EA leaves Global Variables
  EMPTY (checked 04:43Z).


**Desktop SSH short names (28 Sep; `~/.ssh/config` on the desktop):**
`box1` (root@207.148.14.197), `box1-vnc` (box 1 + `LocalForward 5910
localhost:5910`), `box2` (root@64.177.116.219), `box2-rdp` (box 2 +
`LocalForward 3391 localhost:3389`); every host `ServerAliveInterval 30`
and `ServerAliveCountMax 4` (idle sessions had been dropping), identity
`~/.ssh/id_ed25519`. The file's ACL: SYSTEM and the operator only, set
with one `icacls` option per call (02_TRAPS 28 Sep). Then `ssh box2-rdp`
and `mstsc localhost:3391`, or `ssh box1-vnc` and the VNC viewer on
`localhost:5910`.

**Box 2 RDP fault (C75, 27/28 Sep night):** after login a teal screen
only; logout slow; `:10` stopped answering new clients and x11vnc hung;
MT5 kept trading. First look in daylight, READ-ONLY over `ssh box2`:
`ps -ef | grep -i -E "xrdp|Xorg|xfce|x11vnc" | grep -v grep` and
`tail -50 /var/log/xrdp-sesman.log`. Then switch off the XFCE screen
locker on both boxes (a locked session is a likely cause). Fix before
C63, which needs the GUI on box 2.

**Box 2 GUI, 28 Sep daylight (C75, resolved for C63):** X on `:10` answers
(`xdpyinfo` rc 0), XFCE runs, no locker running (light-locker and
gnome-screensaver are installed, not running). sesman RECONNECTS every
RDP login to `:10`; the 03:44Z one reached Xorg, then
`xrdp_mm_chansrv_connect` failed four times and the link hung until the
client dropped at 05:41Z (inferred: the teal screen, and why x11vnc hung
then). **Use VNC on box 2** (works; RDP repair in a closed-market slot).
In `ssh box2` as root:

    sudo -u khalid x11vnc -display :10 -auth /home/khalid/.Xauthority -localhost -rfbport 5911 -nopw -once -shared -noxdamage -bg -o /tmp/x11vnc-box2.log

then on the desktop `ssh -L 5911:localhost:5911 box2` (leave it open) and
the viewer on `localhost::5911`. It exits when the viewer disconnects. **2 Oct: a viewer kept open stays usable for a whole session of work (commanded ejects, 11 reloads per box); restart x11vnc only after closing it.**

**Files to box 2 (28 Sep):** scp from the desktop to `/root`, then as root
`install -o khalid -g khalid -m 664 /root/<file> "<MQL5 root>/Scripts/fxmatrix/<file>"`
(khalid cannot read `/root`); check `sha256sum | cut -c1-16`. The box's
repo `~/fxmatrix-repo` is owned by khalid (`sudo -u khalid git -C ...`).
**wine-test's repo moved to `main` at C63 (1 Oct 03:40Z, ff to `dcc108f`):
pull `main` there like wine-c.** **wine-c's charts load the SCRIPTS copy
of the EA** (`Scripts\fxmatrix\fxgrind.ex5`; backlog C88): compile that
file there, or re-attach from Experts first.


## 10. WINE-D = BOX 3 = FLEET D (C85, BUILT 30 SEP, NOT ATTACHED)

**Names (operator 30 Sep): call the boxes by hostname.** wine-test = box 1
(Fleet B, 207.148.14.197), wine-c = box 2 (Fleet C, 64.177.116.219),
wine-d = box 3 (Fleet D, 216.128.158.33). The desktop's `~/.ssh/config`
short names `box1`, `box1-vnc`, `box2`, `box2-rdp` are unchanged.

Built fresh from s3 with the s9 lessons, 30 Sep afternoon (holiday):
- Vultr, Ubuntu 24.04; `apt -y upgrade` and REBOOT
  while empty (new kernel confirmed with `uname`); i386 + `apt update`
  before `wine64 wine32 winbind`; `wine --version` = `wine-9.0`.
- xrdp + XFCE, user `khalid` in the right groups; **RDP works on wine-d**
  (XFCE desktop seen), through an SSH tunnel to local port 3392. Check
  `which x11vnc` before the attach and install it if missing (s9 fallback).
- `winecfg` once (the RpcSs `err:ole` lines are noise), MT5 installed and
  started detached (s9 `setsid nohup` line), logged in to IC Markets demo
  **53077984**; the shell that started it was closed and MT5 kept running.
  Before the attach, confirm `demo account - hedging mode` in the Journal.
- Repo cloned at `7ca65e2` (`~/fxmatrix-repo`, owned by khalid); EA files
  copied into `MQL5/Experts/fxmatrix` and `Scripts/fxmatrix`: 76 files
  identical to the repo (`cmp`). `fxgrind.mq5` and `fxgrind_tests.mq5`
  each compiled clean, ONE file at a time.
- **Suite 2368/2368** (SUMMARY line) on the empty terminal, run ONCE
  before anything trades; Global Variables empty afterwards. Never run
  it there again once an EA is attached.
- Key injected by `scp` wine-c -> wine-d as root, `chown khalid:khalid`,
  `chmod 600`: 44 bytes, `sha256sum | cut -c1-12` = `fc6b3d9c56a8` on
  both boxes (never print the key itself).
- **WebRequest CONFIRMED 30 Sep ~19:36Z** (Tools -> Options -> Expert
  Advisors, read by the operator over RDP): "Allow WebRequest for listed
  URL" ticked, `https://pipshed.com` listed; "Allow algorithmic trading"
  unticked. Title bar: `53077984 - ICMarketsSC-Demo: Demo Account -
  Hedge - Raw Trading Ltd`. Algo Trading stays OFF until the attach.
- **Reading terminal options without the GUI:** the folder is `Config`
  (capital C; Linux is case-sensitive) under the install:
  `iconv -f UTF-16LE -t UTF-8 "<install>/Config/common.ini" | grep -i
  webrequest` shows `WebRequest=1` but the URL list is ENCODED
  (`WebRequestUrl=<hex>`), and the encoding differs per install (wine-c
  and wine-d differ for the same one-URL list). Only the GUI tells you
  the URL.
- **Pipshed Fleet D page LIVE 30 Sep ~20:20Z (C85 b):** Railway service
  "pipshed Fleet D" (duplicate of Fleet C's; `GRIND_FLEET=D`, label
  "Fleet D - IC Markets 53077984", no `DATABASE_URL`), generated domain
  `pipshed-fleet-d-production.up.railway.app`; Cloudflare CNAME `linuxd`
  -> `qedollf2.up.railway.app` (proxied) and TXT
  `_railway-verify.linuxd` added by hand. `linuxd.pipshed.com` serves
  the eleven `_OPTD`/`_ALTD` ids; the strip shows D NOT ATTACHED.
- **C78 limit probe, 1 Oct 02:49-02:53Z** (`scripts/grind_limit_probe.mq5`,
  repo pulled to `dcec1f0`, sha `eafc291aa2500a4e`, compiled 0/0 ONE file,
  DRY then RUN with Algo Trading ON only for the run): 30 positions + 170
  BUY_LIMIT = 200, then 10040 "Position limit reached" (local, 0.2 ms);
  cleanup EMPTY; Algo Trading OFF again. The account's history now starts
  with these deals (magic 99078001). Backlog C78.
- **D0 ATTACHED 1 Oct 05:10-05:19Z** (fleet-d.md s5). GUI: x11vnc
  `-noipv6 -forever -rfbport 5912` on `:10`, tunnel from the desktop
  prompt; stale RDP tunnels can wedge X (02_TRAPS 1 Oct early morning). The rest of the path (pipshed page, Railway, Cloudflare,
  `fleet-d.md`, presets, attach) is backlog C85.

Line count: 395
