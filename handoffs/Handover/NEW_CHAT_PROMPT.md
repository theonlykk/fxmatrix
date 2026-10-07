This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-10-07 ~02:35Z (WEDNESDAY; ADR-166 ROLL GATE LIVE ON B, C, D SINCE 01:57-02:23Z; ROUND 2 = THU 8 + FRI 9)

**Updated 7 Oct ~02:35Z without a handover** (the chat continues): read
`handoffs/HANDOFF_2026-09-24.md` s64 and `docs/runbooks/wednesday-build-2026-10-07.md`
(s9 Gemini, s10 the run) as well; where this file and s64 disagree, s64
and BOOT s6 are newer.

**PRIORITY: FXMatrix ONLY.** MyFundedPerps (`theonlykk/mfperp`) is PARKED
(operator 3 Oct: "lets focus on fxmatrix - even when we dont have urgent
fixes"). Do not read or ask about it unless the operator brings it back.

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Verify HEADs in git first. Read, in
order: `handoffs/Handover/01_BOOT.md` (s2 RESTATE-AND-STOP for Cursor
prompts; s6 is the state); `handoffs/HANDOFF_2026-09-24.md` s57 to **s63**
(and **s64**, whose NEXT SESSION list is the one to follow); every section of
`handoffs/Handover/02_TRAPS.md` dated 2026-10-05 (early, day, night) and
**2026-10-06** (early, day, afternoon); `handoffs/Handover/08_BACKLOG.md`
(section C1; C88, C93, C106, C124-C133);
**`prompts/cursor_adr166_roll_gate.md`** (the roll gate: P1-P4, C1-C12,
Gemini s10) and **`prompts/cursor_adr166_audit_fixes.md`** (the DeepSeek
check s1, the fix, Gemini GE6 s7);
`docs/runbooks/round-reload.md` (the reload as run 6 Oct: exact commands);
`docs/runbooks/monday-build-2026-10-05.md` (the last IC build: the model
for Friday's); `docs/runbooks/compass-round.md` (the loop; s4.3 GC-1; s11
the round records); `docs/research/compass-round2-review.md` (round 2's
table, Gemini GR2-1..GR2-6, the operator's five answers);
`docs/research/holdout-verdict-criteria.md` (ACCEPTED; the window is OPEN,
5 Oct 22:00Z - 9 Oct 21:00Z: nothing of it is computed before Friday's
close; s8 amendments incl. the FTMO restart rule);
`research/compass/README.md` (with `fill_slippage.py`, C132), `round1.json`
and `round2.json`; `research/holdout/README.md`; `scripts/ic_presets.py`
(stage `round`, the half-pip rule) with `scripts/ic_geometry_r2.json`;
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
  day including modifications and cancellations (C106; A ran 491 by
  15:44Z on 6 Oct: watch `api_count`, bring >~1,600); ADR-160 gate and
  ADR-158 breaker ($500 daily limit is real; the breaker closes nothing).
  **FTMO decides the holdout verdict: no input change on A until the
  verdict (Fri 9 Oct close, or 16 Oct if extended).** A C93 halt
  (`AMBIGUOUS_ADD_*`) is repaired by the F7 restart (traps 5 Oct day)
  after the operator's go, listed with the results (criteria s8).
- **IC B (wine-test, 53066709, anchor), C (wine-c, 53071896, add probe),
  D (wine-d, 53077984, exit probe):** nine instances each, EA code
  **`main` `5bb5fdb` (v2.2a + ADR-166) since the Wednesday build, 7 Oct
  01:57-02:23Z, `InpRollGateOpposite=0` on all 27** (operator 6 Oct
  ~20:37Z: the gate on every IC fleet; no ungated fleet); re-roll ON;
  wine-c's charts load the Scripts `.ex5` (C88). Breaker off: no
  account-level backstop.
- **Compass, cap 8 this week. Round 2 reloaded 6 Oct 03:18-03:35Z** (BAD
  0; widths GBPUSD 2.5, EURUSD / NZDCAD / AUDNZD 2.0, AUDCAD 1.5, the rest
  1.0; S = W + 1; deadband 2; no promotion; NZDCAD the control). **Round 2
  = Wed 7 + Thu 8** (6 Oct 22:00Z - 8 Oct 22:00Z), scored Thu after 22:00Z
  with `round2.json`; **the IC bid / ask dump is compulsory** (open MTM
  reported, realised decides); C132 `fill_slippage.py` reported beside it.
  **MOVED by the Wednesday build: round 2 = Thu 8 + Fri 9 (7 Oct 22:00Z -
  9 Oct 22:00Z, `round2.json`), scored after Friday's close.**
- **`main` = v2.2a + ADR-166, DEPLOYED on B, C, D 7 Oct (not FTMO).** v2.2a (C93 unique recon
  tickets, C100 API stop inputs) merged `509705f`; **ADR-166 roll gate**
  merged `d57fe9b` (2597/2597 GBPUSD + EURUSD): `InpRollGateOpposite`
  (-1 = off; N >= 0 needs the lattice): a capped side does not roll or
  re-roll while the opposite side holds more than N FILLED layers; while
  gated it restarts its tick extreme (nothing seen during the hold is
  replayed; also at `OnInit`) and writes INFO `ROLL_DEFERRED`.
- **Round 3 (SUPERSEDED 6 Oct ~20:37Z: the gate is on every IC fleet; round 3's reload Mon 12, days Tue 13 + Wed 14; the old plan follows):** the IC build from `main` Fri 9 Oct in session
  with round 3's reload; wine-d runs the gate at N = 0 on the anchor
  geometry (its exit probes pause one round), scored on EQUITY against
  wine-test; every round-3 preset carries `InpRollGateOpposite` (-1 on B
  and C). Days Mon 12 + Tue 13. Slip: build Mon 12, round 3 Tue 13 + Wed
  14. Cap 10, fixed widths and AUDUSD DEFERRED.

**Operator rulings (do not re-open):** **EQUITY decides a compass round
from round 2** (operator 7 Oct ~14:53Z, `docs/research/compass-equity-amendment.md`;
realised reported; until round 1 realised decided); equity decides the holdout and
the roll gate ("rolling is a cost"; 6 Oct: rolls booked -$721 over 1-5 Oct
but were about a wash against holding); the one-hour markout is a proxy;
the flat side enters as fast as possible, passively; the deadband stays
for requests; cap 8 this week; NZDCAD control; IC keeps nine pairs; no
twins; no API limit may stop trading; no broker contact; post-once
execution with one 2,000-request pool (C117); the 200 positions+orders
limit holds on IC too; GC-1 decides from round 2; whether a WIN must
always repeat: OPEN, decided at round 2's scoring; mfperp parked.

**Reading live state:** pipshed through the desktop app's built-in
browser pane: open the `/api/g/<token>/fleets/<n>` URL the operator gives
and parse the JSON with the pane's JavaScript tool (traps 6 Oct day);
WebFetch times out and the sandbox is refused pipshed.com. Quote
`generated_at`. pipshed's strip: fleet cards and four tables (books,
quote gap, best bid / offer, geometry). Downloads must be GRANTED each
session; deliverables go there under NEW file names, read back.

**Watch every night on B, C, D (C87):** no chart edits 20:50-21:15Z; carry
pass 20:50-20:59Z (`archive_counts.py --carrypass --hours 2` after ~21:00Z:
34 summaries: 7 FTMO + 27 IC; BOOT s6).

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | after this patch: s63 docs + handover on `d57fe9b` (ADR-166 merge, tree `e44f78c2`; EA code = `5bb5fdb`) on `b63ddce`; `509705f` v2.2a; `24bcc4c` C132; `360ee75` s62 |
| pipshed `main` | `9b1faba` (C123 + C131, tree `b43a77f1`), 42/42. C121 (AUDUSD) WAITS |
| VPS (cycle 3) | `aa6970a` (tag `vps-aa6970a`), 7 instances, frozen for the holdout |
| wine-test (B), wine-c (C), wine-d (D) | EA `2859be6`, repos at `7551580`; round-2 presets in `MQL5/Presets` (`*_r2.set`, key injected); `/root/mon_logcheck.awk`; `ssh box1` / `ssh box2` / `root@216.128.158.33`; VNC 5910 / 5911 (both `-once`) / 5912 (`-forever`) |

## 2. NEXT, IN ORDER (= HANDOFF s63 NEXT SESSION)

1. The questions for the previous chat (above).
2. Tue 6 Oct after ~21:00Z: the carry pass (34 summaries); a status read
   after 22:00Z, when round 2's window opens.
3. Thu 8 Oct after 22:00Z: score round 2 (study export; the IC bid / ask
   dump; journals; `compass_score.py --round round2.json --bidask ...`;
   `fill_slippage.py --round round2.json --baseline round1.json`; GC-1
   from the round's own control; the operator decides promotion and the
   repeat rule). Then round 3's table with the gate on wine-d, Gemini
   (one document, with mechanisms and lines), presets, and a
   build-and-reload runbook (the Monday build's shape; log checker
   extended with `roll_gate=`; `GRIND_ROLL_GATE opposite_max=` read back).
4. Fri 9 Oct in session: the IC build (wine-d Experts, wine-c the Scripts
   copy (C88), wine-test Experts) with round 3's reload.
5. Sat 10 Oct: holdout scoring (criteria s5): FTMO bid / ask and deal
   history dumps, the archive export, `holdout_verdict.py`, any FTMO
   restarts listed.
6. Quiet slots: the twins' Global Variables (monday-build s7); C88; the
   width-guard change and C127 to Gemini. Later: C128 (cap 5 vs 8), C130.

## 3. TRAPS (full list in 02_TRAPS)

- Inputs dialog: comments replace names; read `InpTelemetryInstance`
  first; F7 on the chart, never the Navigator; read back before OK.
- PowerShell: quote `"HEAD^{tree}"`. Before `git am`, check
  `git log origin/main..HEAD`. `git am` re-stamps hashes: cite trees.
- Cursor prompts: name the exact line an insertion goes after ("first
  call" was ambiguous); `AssertTrue(name, x == y)` for longs; Cursor's
  branches track `origin/main` ("diverged": ignore, never pull); the
  suite count must equal the F / G prediction exactly.
- Grep logs, never paste them (UTF-16: `iconv`); one shell step per
  message; say which window each command runs in.
- Claude works only inside a turn: "meanwhile" means now or not at all.
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

Line count: 183
