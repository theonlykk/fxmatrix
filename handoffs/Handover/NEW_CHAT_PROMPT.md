This message has a line count at the bottom

# NEW CHAT PROMPT -- FXMATRIX, 2026-09-25 ~01:40Z

You are picking up mid-project as Lead Engineer. Clone
`https://github.com/theonlykk/fxmatrix` and `https://github.com/theonlykk/pipshed`
into your sandbox and READ FROM THEM. Read, in order:
`handoffs/Handover/01_BOOT.md`; `handoffs/HANDOFF_2026-09-24.md` to the end
(section 10 is the newest); the three newest sections of
`handoffs/Handover/02_TRAPS.md`; `handoffs/Handover/08_BACKLOG.md`; then
this. Verify HEADs in git before anything else.

---

## 0. THE SINGLE MOST IMPORTANT FACTS

**Two fleets are LIVE; cycle 3 is FROZEN** (geometry-cycle3 A4): nothing
lands on the FTMO VPS except a defect fix. Fleet B (IC Markets, Linux
box) takes mid-cycle geometry changes from Mon 28 Sep. A third fleet
(Fleet C, session window) is planned, NOT built.

The FTMO account dies on the DAILY limit ($500 from day-start BALANCE,
equity includes open MTM): cycle 2 ended that way. ADR-158 breaker and
ADR-160 gate are the defences.

---

## 1. STATE (verify each in git)

| | |
|---|---|
| fxmatrix `main` | `c12901a` or a docs-only descendant. EA code == tested `9466b22`: `git diff --stat 9466b22 origin/main -- ea/ scripts/ tools/` must be empty |
| pipshed `main` | `2f3e749` (D5 + daily-card fix, verify 23/23; migration 003 applied) |
| VPS (cycle 3) | `a01a5d4`, tag `vps-a01a5d4`, 11 live, FTMO 1514731800, dashboard `pipshed.com` |
| Box 1 (Fleet B) | built from `87765be`, presets `85cd555`, 11 live, IC 53066709, `linux.pipshed.com` |
| Suite | 1875/1875 at `9466b22` (the deployed EAs are 1766/1766 at `6c57830`) |
| Daily rows | first rows FTMO day 24 Sep (partial): C3 $82.96 / 111 scalps, B $66.86 / 90, gated 0.0h |

---

## 2. BUILT TODAY (all merged, all verified)

| item | where |
|---|---|
| ADR-161 session window, default OFF, 07:00-16:55 Toronto Mon-Fri | EA `25a5f93`; record `docs/architecture/ADR-161-session-window.md` |
| D5: generated gated_seconds/history_ok, Gated (h), s4 gated hours | pipshed `405573c` |
| Daily card Decimal fix (ADR-159 build had never seen a real row) | pipshed `2f3e749` (no Gemini review: show him) |
| ADR-162 Phase A (effective entry, inert), Gemini GA1-GA5, DeepSeek | merge `c12901a`; record `docs/architecture/ADR-162-virtual-lattice.md` s12 |

---

## 3. NEXT, IN ORDER

1. **Fleet C (backlog C51)** by Sun 27 Sep 17:01 Toronto: operator
   deploys the Vultr box and opens an IC Raw $10k demo; build FRESH from
   `06_LINUX_WINE_BOX.md` s3 one step at a time (RDP tunnel on local
   port 3391); `presets_c` (`_OPTC`/`_ALTC`, `InpSessionEnable=true`);
   pipshed Fleet C support (Gemini -> Cursor); `docs/architecture/fleet-c.md`
   pre-registration.
2. **Fleet B group A dials, Mon 28 Sep before the London open:**
   `railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/s4_scalps.py --days 2`
   from `D:\pipshed`; apply the s5 rule to `_OPTB` ratios; change
   `presets_b`; reattach on the box. Group B the following Wednesday.
3. **ADR-162 Phase B**: Phase A (plumbing, inert) merged `c12901a`.
   Phase B = trigger, roll, M1 catch-up, WARN, "roll here", plus B1-B4
   from ADR-162 s12; tests first, Gemini, Cursor, both suite runs,
   DeepSeek. Operator defaults: at cap only (Q1), "roll here" refuses
   when all are rolled (Q3), deploy target at week end (Q4).
   Evidence (week end): cycle 3's ejections, cycle 2's deep books.
4. **Watch daily (22:00Z):** Carried (first real value Fri), gated
   hours, guard_total (budget mid-170s vs 194), carry clamps (C26).

---

## 4. TRAPS (full list in 02_TRAPS)

- Verify every agent claim in git; count lines mechanically.
- A test whose expected value is 0 passes against a stub.
- A publish path that never saw a real row fails on the first one.
- Gemini and DeepSeek assert code behaviour they have not read.
- A downloaded file inside the repo blocks `git am`; keep copies outside.
- Cursor leaves its branch checked out: `git switch main` before merging.

---

## 5. WORKING PRACTICE

- One shell step per message; the operator pastes output back.
- Docs and small fixes: Claude commits in its sandbox, hands over
  `git format-patch` files (always with a present_files card and byte
  size); the operator `git am`s and pushes; Claude verifies the pushed
  tree on GitHub against its own.
- Features: spec with bookends and Gemini questions inside -> Gemini ->
  Cursor on a branch, tests first, stub failures predicted BY NAME ->
  the operator compiles and runs both suites -> DeepSeek for anything
  that places, moves or cancels orders -> operator merges `--no-ff`.
- Operator stance: boring is best; live trade history is the evidence.
- **Watch the chat's length.** When the conversation gets long, say so
  and propose a handoff (docs patch + fresh chat) BEFORE starting work
  that needs close reading of code. The operator prefers this.

Line count: 102
