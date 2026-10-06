This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-06 ~03:55Z (TUESDAY; ROUND 2 LIVE SINCE THE 03:18-03:35Z RELOAD)

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED
(operator 3 Oct: "lets focus on fxmatrix - even when we dont have urgent
fixes"). Do not read or ask about it unless the operator brings it back.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s54 to **s61**
(s61 ends with the NEXT SESSION list: follow it); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-04, 2026-10-05 (early, day,
night) and **2026-10-06** (early); `handoffs/Handover/08_BACKLOG.md`
(section C1; C88, C93, C106, C123-C131);
`docs/runbooks/round-reload.md` (the reload as run 6 Oct: exact commands);
`docs/runbooks/compass-round.md` (the loop; s4.3 GC-1; s6 this week's
width; s11 the round records); `docs/research/compass-round2-review.md`
(round 1's verdict, round 2's table, Gemini GR2-1..GR2-6 and the
operator's five answers, s6);
`docs/architecture/MEMO_2026-10-05_width_depth_counter_side.md` (cap 8,
tight widths, deadband 2, the counter side);
`docs/research/holdout-verdict-criteria.md` (ACCEPTED; the window is OPEN,
5 Oct 22:00Z - 9 Oct 21:00Z: nothing of it is computed before Friday's
close; s8 amendments incl. the FTMO restart rule);
`research/compass/README.md`, `round1.json` and **`round2.json`**;
`research/holdout/README.md`; `scripts/ic_presets.py` (stage `round`, the
half-pip rule) with `scripts/ic_geometry_r2.json`;
`docs/architecture/ADR-165-continuous-reroll.md` (s4, s5, s9, s10);
`handoffs/Handover/06_LINUX_WINE_BOX.md` s7, s9, s10;
`handoffs/Handover/07_ROADMAP.md` (GATE BEFORE REAL MONEY);
`handoffs/Handover/09_EVENT_LOG.md` (add to it);
`handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW = round 2); then this.

**YOUR FIRST REPLY, after the reading (operator's request, 2 Oct):**
1. A short restate of the state as you found it in git (HEADs, fleets,
   anything in the docs that disagrees with itself).
2. **A numbered list of questions for the PREVIOUS chat**, ready for the
   operator to copy and paste across in ONE block: live state after the
   docs were written, half-finished steps, exact commands, rulings heard
   but not written down. Short, answerable in a line each; at most ~12.
Do not start any fleet action before the answers are in.

---

## 0. THE MOST IMPORTANT FACTS

**Four fleets live. Call the boxes by HOSTNAME:**
- **Cycle 3** (VPS, FTMO 1514731800, `aa6970a`): SEVEN instances (EURUSD,
  GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD `_OPT`); 2,000 requests a
  day including modifications and cancellations (C106; FTMO replied 5 Oct:
  keep under it; A ran 960 to 20:27Z on 5 Oct: watch `api_count`, bring
  >~1,600); ADR-160 gate and ADR-158 breaker ($500 daily limit is real;
  the breaker closes nothing). **FTMO decides the holdout verdict: no
  input change on A until the verdict (Fri 9 Oct close, or 16 Oct if
  extended).** A C93 halt (`AMBIGUOUS_ADD_*`) is repaired by the F7
  restart (traps 5 Oct day) after the operator's go, listed with the
  results (criteria s8).
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe),
  D (wine-d, 53077984, exit probe):** nine instances each (twins retired 5
  Oct), on `main` (EA code `2859be6`), re-roll ON; wine-c's charts load the
  Scripts `.ex5` (C88, fix later). Breaker off: no account-level backstop.
- **Compass, cap 8 this week.** Round 1 scored (GC-1 $2.55). **Round 2
  reloaded 6 Oct 03:18-03:35Z** (BAD 0): tight widths (GBPUSD 2.5,
  EURUSD / NZDCAD / AUDNZD 2.0, AUDCAD 1.5, the rest 1.0), S = W + 1,
  deadband 2; **no promotion** (round 1's winners repeat as probes:
  EURUSD L C add 6, AUDCAD L D exit 9, AUDNZD S C add 7); losers flipped
  (EURUSD L/S D exit 11, EURGBP L D exit 6, CADCHF L D exit 11); EURGBP L
  C add **2.5** (the one half-pip probe); NZDCAD the control. **Round 2 =
  Wed 7 + Thu 8** (6 Oct 22:00Z - 8 Oct 22:00Z), scored Thu after 22:00Z
  with `round2.json`; **the IC bid / ask dump is compulsory** (open MTM
  reported, realised decides). Round 3: reload Fri 9, days Mon 12 + Tue
  13. Cap 10, fixed widths and AUDUSD DEFERRED.
- **First night of re-roll (5 Oct):** far rolled levels walked down to the
  market (EURUSD L C 9 re-rolls) and their old layers realised on the next
  bounce (C: rolls 9, -$65): designed, equity unchanged (traps 5 Oct
  night).

**Operator rulings (do not re-open):** realised P&L decides a compass
round (scalp P&L and open MTM reported); equity decides the holdout; the
one-hour markout is a proxy (no entry optimisation; C103 "boring is
best"); the flat side enters as fast as possible, passively (tight width);
the deadband stays for requests; cap 8 this week; NZDCAD control; IC keeps
nine pairs; no twins; no API limit may stop trading; no broker contact;
post-once execution with one 2,000-request pool (C117); the 200
positions+orders limit holds on IC too; GC-1 decides from round 2; a WIN
repeats once under the new structure before promotion (round 2; standing
rule OPEN); mfperp parked.

**Reading live state:** the operator saves
`/api/g/<token>/status{,_b,_c,_d}/<n>` to Downloads under a NEW file name
each time (the bridge can keep a name's first version; read it back);
WebFetch of pipshed needs the URL in the operator's message and can time
out (C102). pipshed's strip shows the fleet cards and four tables: books,
quote gap, best bid / offer, **geometry** (C129: what each EA runs).
Downloads and `D:\fxmatrix\temp` must be GRANTED each session.

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z; carry
pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after ~21:00Z:
34 summaries: 7 FTMO + 27 IC).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | after this patch: s61 + handover docs on `7551580` (s60). Before: `15b5f30` s59, `b438420` round-2 presets without promotion, `dd71202` s58. EA code `2859be6`; branch `v22a-recon-api` `8a3ec0c` (v2.2a: C93 + C100, 2525/2525, NOT merged) |
| pipshed `main` | `b023565` (C129 geometry table, tree `b40a0834`), 40/40. C121 (AUDUSD) WAITS; C123 to REBUILD on `b023565`; C131 to build |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances, frozen for the holdout |
| wine-test (B), wine-c (C), wine-d (D) | `main`, repos at `7551580`; round-2 presets in `MQL5/Presets` (`*_r2.set`, key injected); `/root/mon_logcheck.awk`; `ssh box1` / `ssh box2` / `root@216.128.158.33`; VNC 5910 / 5911 (both `-once`) / 5912 |

## 2. NEXT, IN ORDER (= HANDOFF s61 NEXT SESSION)

1. The questions for the previous chat (above).
2. Tue 6 Oct: a status read (halts, guards, counter-side fills at the new
   widths, requests on IC and A); the carry pass after ~21:00Z.
3. Thu 8 Oct after 22:00Z: score round 2 (study export; the IC bid / ask
   dump; journals; `compass_score.py --round round2.json --bidask ...`;
   GC-1 from the round's own control; the operator decides promotion).
   Then round 3's table, Gemini (one document, with the mechanisms and
   lines, traps 6 Oct early), presets, reload Fri 9 (`round-reload.md`).
4. Quiet slots: the twins' Global Variables (monday-build s7); C123 on
   `b023565`; C131; C88; the width-guard change and C127 to Gemini.
5. Sat 10 Oct: holdout scoring (criteria s5): FTMO bid / ask and deal
   history dumps, the archive export, `holdout_verdict.py`, any FTMO
   restarts listed.
6. Later: v2.2a merge and deploy; C128 (cap 5 vs 8); C130.

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names; read `InpTelemetryInstance`
  first; F7 on the chart, never the Navigator; read back before OK.
- One-digit ticket look-alikes between instances: match the comment.
- The checker's `from=` is a time; say which window each command runs in
  (Linux box vs desktop PowerShell).
- PowerShell: quote `"HEAD^{tree}"`. Before `git am`, check
  `git log origin/main..HEAD`. `git am` re-stamps hashes: cite trees.
- Grep logs, never paste them (UTF-16: `iconv`); one shell step per
  message.
- Verify every agent claim in committed source; count every line; clock
  times from the clock tool.

## 4. WORKING PRACTICE

- **One shell step per message**; say WHERE each command runs. Plain-text
  pipshed URLs. One question at a time when the operator asks for them.
- Docs and small fixes: Claude commits in its sandbox, `git format-patch`,
  checks `git am` on a clean clone at the base, delivers to Downloads with
  the expected tree (and reads it back); the operator `git am`s, checks the
  tree, pushes; Claude verifies on GitHub and resets its sandbox. **Claude
  never pushes.**
- Features: spec (Gemini questions inside, RESTATE AND STOP first) ->
  Gemini -> Cursor on a branch -> Claude reads the commits -> suite ->
  DeepSeek for anything that moves orders -> merge `--no-ff`. Research
  code and pipshed: Claude builds, tests first (predicted failures),
  hand-derived values, a mutation round, the full suite on a scratch PG.
- Long chats: keep docs current; propose a handoff only near the limit.

Line count: 162
