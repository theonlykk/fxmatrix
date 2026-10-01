This message has a line count at the bottom

# C9 -- TELEMETRY KEY ROTATION: PROCEDURE (DRAFT)

Status: DRAFT, written by Claude 1 Oct ~02:30Z. **Not for Gemini yet**
(one document at a time; after C63 and the v2.2 scope note). Timing is
the operator's: "closer to going live" (30 Sep). Prerequisite: pipshed
`pipshed_c9_and_fleet_d_card.patch` pushed and deployed (built 1 Oct;
its first two commits are C9; tree `fbed4e6c`; backlog C9). Nothing is rotated by this document.

**Rule for every step: the key is never pasted in chat, never printed
on a screen that is shared, never committed, never screenshotted.** It
moves box to box by `scp` or a file copy and is checked by `sha256sum |
cut -c1-12` only.

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| K1 | The EA sends `Authorization: Bearer <TelemetryAPIKey>` to `TelemetryURL` (`https://pipshed.com/api/telemetry/push` in all 64 presets) and its sibling endpoints; an empty key sends nothing | `fxgrind.mq5` 49, 136-137; `ea/presets*` | VERIFIED |
| K2 | Pipshed (after the patch) accepts `TELEMETRY_API_KEY` and, when set, `TELEMETRY_API_KEY_NEXT` on all four push endpoints, and records per instance which one it used: `/api/g/<token>/keyslots/<n>` | pipshed `f25199c8` tree, KN1-KN12 | VERIFIED (sandbox; not yet deployed) |
| K3 | Only the `pipshed.com` service receives pushes (K1); the Fleet B/C/D web services read Redis | 06 s7, s9, s10 | INFERRED from the URL: check each service's variables before step 1 |
| K4 | A refused push keeps archive events queued (up to 5,000) but heartbeats are not queued; a reload re-runs `Grind_ArchiveConfigureAt` and clears the queue | `grind_archive.mqh` 19, 64-113; c63-deploy.md s11 | VERIFIED; with two keys nothing is refused, so nothing is lost |
| K5 | Where the CURRENT key lives: Railway `pipshed.com` service variable; VPS `c:\fxmatrix-local\telemetry.key` (read by `scripts/deploy_presets.ps1`) and the staged `MQL5\Presets\*.set`; wine-test, wine-c, wine-d `~/.fxgrind_telemetry.key` (44 bytes with the newline, 43-char key) and the staged presets (`*_b`, `*_b_lat`, `*_c`, `*_c_lat`); the inputs of 33 attached charts | BOOT s3; 06 s7, s9, s10; c63-deploy P2 | VERIFIED in the docs. OPEN: any other copy (desktop, Cursor, a password manager) -- operator |
| K6 | `ea/Globals.mqh` (the old FXMatrix EA, not fxgrind) has a 43-char `TelemetryAPIKey` default committed 19 Jun; public. Never compared with the live key | `ea/Globals.mqh` 174 | VERIFIED; moot once rotated, blanked in the same patch |
| K7 | The pipshed READ token is a constant in `app.py` (`PUBLIC_GRIND_STATUS_TOKEN`) and in every handoff in the public repo. A separate exposure: making the repo private (operator, 28 Sep) is its fix | pipshed `app.py` 1436 | VERIFIED; OUT of this document |

## 1. ORDER (each step judged before the next)

1. **Deploy the pipshed patch** (any time; not 20:50-21:00Z). Check
   `/keyslots/<n>`: `current_configured` true, `next_configured` false,
   33 instances `current` with `at` within the last minute or two.
2. **Make the new key on the desktop**, into a file, never on screen:
   `python -c "import secrets; open(r'C:\fxmatrix-local\telemetry.key.new','w').write(secrets.token_urlsafe(32))"`
   (43 characters, the same alphabet as the old key; no newline, so the
   file is 43 bytes where the old one is 44). Note its `sha256` prefix
   (12 hex) only.
3. **Set `TELEMETRY_API_KEY_NEXT`** on the `pipshed.com` Railway
   service from that file (Railway redeploys: a few seconds without the
   web; heartbeats resume, archive events wait in the EA queue).
   `/keyslots`: `next_configured` true, all 33 still `current`.
4. **Copy the new key to each box** as `~/.fxgrind_telemetry.key.new`
   (`scp`, `chown khalid:khalid`, `chmod 600`; sha prefix equal to the
   desktop's) and to the VPS as `c:\fxmatrix-local\telemetry.key.new`.
5. **Re-stage every preset with the new key:** rewrite the staged
   `MQL5/Presets` files in place (the old key stays in `.key.old` for
   the rollback), byte-check
   `SAME_EXCEPT_KEY` against the repo, sha prefix of each key line equal
   to the new file. Every staged preset, including the rollback ones
   (`*_b.set`, `*_c.set`), so no later Load brings the old key back.
6. **Reload the charts, one at a time, in session** (Properties, Load
   the chart's CURRENT preset, read back, OK: reason 5). After each,
   `/keyslots`: that instance `next`. Order: wine-c, wine-test, then
   the VPS (if the operator includes cycle 3; see GK-3). wine-d: files
   only (not attached).
7. **Promote:** when `/keyslots` shows `current` 0 and every instance
   `next` with a fresh `at`, set `TELEMETRY_API_KEY` to the new key and
   clear `TELEMETRY_API_KEY_NEXT` in ONE Railway change. `/keyslots`:
   all `current` again, `next_configured` false.
8. **Prove the old key is dead** on one box, without printing it:
   `curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "Authorization: Bearer $(cat ~/.fxgrind_telemetry.key.old)" -H 'Content-Type: application/json' -d '{}' https://pipshed.com/api/telemetry/push`
   -> `401` (a live key would give `400`, the empty body). Then delete every `.old` and `.new` file; the live file is
   `~/.fxgrind_telemetry.key` (and `c:\fxmatrix-local\telemetry.key`).
9. **Repo:** blank `ea/Globals.mqh`'s default (K6) in a docs/code patch
   that touches no fxgrind file.

## 2. ROLLBACK

Until step 7 the old key still works everywhere: reload a chart with
the `.old` key preset, or clear `TELEMETRY_API_KEY_NEXT`. After step 7,
put the old key back in `TELEMETRY_API_KEY_NEXT` from the `.old` file
(deleted only at step 8).

## 3. NEGATIVE SPACE

- No EA change; no geometry change; no preset change other than the
  key line.
- No reload with the market closed or at 20:50-21:00Z (carry pass).
- Never a single-key switch (c63-deploy.md s11: it blinds the cards or
  loses the gap's archive rows).
- The read token (K7) is not rotated here.

## 4. FOR GEMINI (when this goes to him)

- GK-1. Is a two-key window with per-instance tracking the right shape,
  or is there a simpler safe one?
- GK-2. Step 5 rewrites the staged rollback presets with the new key.
  Any reason to keep an old-key copy beyond the `.old` key file?
- GK-3. Cycle 3 is frozen except defect fixes. Is a key-only reload of
  the VPS charts inside that rule, or should the VPS wait for the end
  of cycle 3 (leaving the old key valid as NEXT until then)?
- GK-4. `/keyslots` keeps each instance's LAST slot. Is that enough to
  decide step 7, or should it count pushes per slot over a window?

## 5. FOR THE OPERATOR

- Any other copy of the current key (K5)?
- Which Railway services carry `TELEMETRY_API_KEY` today (K3)?

Line count: 100
