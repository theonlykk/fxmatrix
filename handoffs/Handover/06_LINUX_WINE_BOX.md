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
   check `systemctl is-active xrdp` and reboot (stale sessions).
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
5. **Suite:** run `fxgrind_tests` on a GBPUSD chart (Algo off is fine; it
   does not trade). 1766/1766 at `85cd555`.
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

Line count: 204
