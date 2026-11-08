This message has a line count at the bottom

# Argon Review: `research/nocarry/PREREG.md` (No-Carry Pre-Registration, 7 Nov 2026)

- **Branch:** `review/argon-nocarry`
- **Base commit (`origin/main`):** `9dca377be5f0be8267198b12c3cc2a6df6916d26`
- **Files read (at `origin/main`):**
  - `prompts/argon_review_nocarry.md` (lines 1-62)
  - `research/nocarry/PREREG.md` (lines 1-104)
  - `research/opt_budget/sim.py` (lines 1-575)
  - `research/opt_budget/MECHANICS.md` (lines 1-64)
  - `research/longrun/run_bars.py` (lines 1-105)
  - `research/longrun/results.md` (lines 1-92)
  - `research/longrun/MANIFEST.md` (lines 1-25)
  - `research/longrun/out_limit/cont_GBPUSD.json` (line 1)
  - `research/cluster/PREREG.md` (lines 1-159)
  - `ea/grind_pure.mqh` (lines 400-695)
  - `handoffs/HANDOFF_2026-09-24.md` (lines 2500-3160, 8900-9232)
  - `docs/research/ftmo-pass-probability.md` (lines 1-150)
  - `research/e_week1/PREREG.md` (lines 1-136)
  - `research/magnet/PREREG.md` (lines 1-103)
  - `scripts/grind_bar_dump.mq5` (lines 1-101)
  - `ea/presets_e/gbpusd_opt_e_t3.set` (lines 1-20)
- **Files NOT read:**
  - `D:\fxmatrix-exports\bars_ftmo\bars_1514878887_<PAIR>.csv` (**not read**, per Rule 4; not in the repo)
  - FTMO's website (**not read**, per Item 3; FTMO rules checked from the repo's own record)

---

## Summary Table (Items 1-8)

| Item | Section / Topic | Verdict | Summary of Finding |
|---|---|---|---|
| 1 | `s3`, the cut, against `sim.py` (`Instance`/`Side` state, dealt exits, runner vs `sim.py`) | **GAP** | All `Instance` and `Side` state fields to clear/reset are identified, `s3` step 2 (`l.closing == True`) handles dealt exits before close-by cleanly, and the cut + flat window can live in `run_nocarry.py` without editing `sim.py` or breaking `s8` / check (a). **Two edge-case gaps in `s2`/`s3`:** (1) on the first Monday of the dataset (`00:05-00:59` server, before any `23:45` cut has occurred), `DAY` will trade `00:05-00:55` and fail check (c) unless the flat window `[00:00, 01:00)` is active from the start of the run; (2) in `WEEK`, a 4-day holiday week (e.g. Good Friday, `~5,720 >= 4,000` bars) is not skipped by `run_bars.py:64` and has no Friday (`isoweekday() == 5`) bars, so `"on Fridays only"` (`PREREG.md:28`) would carry the book over a 3-day weekend unless `WEEK` cuts at Friday `23:45` or at the week's last tick if the week ends before Friday `23:45`. |
| 2 | `s2`, the times (server time, `01:00` vs Prague midnight, `23:45` vs rollover, `fromtimestamp(t, utc)`) | **CONFIRMED** | Bar times are FTMO trade server time (`00:00` server = `17:00` New York year-round); `01:00` server equals `00:00` Prague (`Grind_PragueUtcOffset`) in both winter (`UTC+2` vs `UTC+1`) and summer (`UTC+3` vs `UTC+2`), and is out by 1 hour (`00:00` Prague = `02:00` server) for **21 or 28 calendar days (15 or 20 trading days) a year** (`98` calendar days / `70` weekdays across the dataset); `23:45` server is before the `23:50`/`23:55` rollover window; `fromtimestamp(t, utc)` yields the exact server weekday. |
| 3 | `s4`, the FTMO-day loss (5-minute marks vs 15 s ticks; day-start balance rule) | **DEFECT** | `"the balance at the day's start less the lowest equity in the day"` is **confirmed** from the repo's record (`docs/research/ftmo-pass-probability.md:21-23`, `research/e_week1/PREREG.md:16-17`, `handoffs/HANDOFF_2026-09-24.md:9186-9188`, `ea/grind_pure.mqh:660-678`). **Defect:** in `sim.py:537-540`, 5-minute marks are taken at `next_mark` (`:00, :05, ...`) using `prev[1], prev[2]` (the `:59:45, :04:45` bar close), so **5-minute marks never sample any M1 bar's high or low (`+15 s` and `+30 s`) and skip 4 of every 5 minutes**. Across 12 instances (`~$7-$9/pip` when stacked together), a 20-50 pip excursion between marks can miss **$150-$350+** and miss a `$500` breach (Rule 4). Lowest equity should be tracked on every 15-second tick (or every M1 bar's 4 ticks) across the 12 instances. |
| 4 | `s5`, the self-checks ((a) loop rewrite, (b) L0 restart, (c) sufficiency & boundary, (d) cent rounding, (e) bars check) | **DEFECT** | (a) is achievable. **(b) Defect:** `sim.py:385-389` sends at most one `ENT` per tick (`self.ent_sent = True`) and sets `self.busy = t + 287` ms, so the first tick at `01:00` places only `L.l0` and the second tick (`>= +287` ms, i.e. `01:00:15`) places `S.l0`; a 1-tick restart test in (b) will fail against `sim.py`. **(c) Defect/Gap:** `sim.py:537-540` records `marks` *before* tick actions and does not record resting orders; if the `23:45` mark is recorded before the `23:45` cut, (c) fails at `23:45`, and if the `01:00` mark is recorded after `on_tick(01:00)`, (c) fails at `01:00`. Also (c) should verify flat state after early closes and in `WEEK`, and zero fills in `(t_cut, t_restart)`. **(d)** needs a cent-rounding rule (`<= $0.02` or `net` defined as sum of rounded parts). **(e)** from the `23:45` bars alone checks cut exit prices (`bid`/`ask`) and P&L arithmetic, while open layers/entries come from the day's run. |
| 5 | `s6`, the decision rule (fixed in advance, 4-day bar, 12 instances together, 2026 to 23 Oct) | **GAP** | Thresholds are fixed and fair (`<= 4` days of `>= $500` is realistic for `DAY` starting flat, with `EDGE, NOT FTMO-SAFE` separating edge from tail; 12 instances matches E; 2026 to 23 Oct was the only positive year `+$876` in `CONT`). **Gap:** `s4`/`s6` must pin whether 12-month windows over the 46 month-ends use `E[i] - E[i-12]` for `i = 12..45` (**34** windows, as in `results.md:56`, `< 17` -> `<= 16`) or prepend `E[-1] = 0.0` at 2 Jan 2023 (**35** windows, `< 17.5` -> `<= 17`), and that yearly P&L is year-end equity change (`realised + open` after commission). |
| 6 | `s7`, the biases (no-swap confirmation, missing biases) | **GAP** | `"No swap anywhere"` is **confirmed** (`run_bars.py:70-72`, `sim.py:31, 472-474, 532-535`). **Gap:** `s7` should add: (1) the `< 4,000`-bar holiday-week skip (`run_bars.py:64`) carries `CONT`'s open book across skipped weeks, and early-close cuts (`PREREG.md:33-34`) use end-of-day lookahead on `tk`; (2) `sim.py` omits `Grind_LatticeRerollPaused` (`23:50-00:15` server, `ea/grind_pure.mqh:448-454`), affecting `CONT` and `WEEK` during the rollover when `DAY` is flat; (3) sequential cut execution across 12 instances in live MT5 takes several seconds of broker round-trips; and (4) `MqlRates.spread` is the bar's minimum spread (not just `"may be"`). |
| 7 | `s1`, the worked example (arithmetic, `s3` mechanics, GBPUSD `t3` preset in `GEO`) | **CONFIRMED** | Exact: GBPUSD OPT has `width = 2.5, add = exit = 9.0, stranded = 3.5` (`run_bars.py:23`, `ea/presets_e/gbpusd_opt_e_t3.set:3-5`), `$0.10`/pip, `$0.06`/close; shorts at `1.34500, 1.34590, 1.34680` closed at `ask = 1.34620` give `-12.0, -3.0, +6.0` pips = `-9.0` pips = `-$0.90 - $0.18 = -$1.08`. |
| 8 | Post-hoc bending vectors and what the C162 memo will need | **GAP** | **Bending vectors to pin:** (1) exact formula for `"the count and the median loss of cut closes"` (`PREREG.md:49`: per cut `Close` vs per night, all vs `<= 0`, pips vs USD); (2) exact mechanics of the `0.5` pip sensitivity (`exit = r5(bid - 0.5 * PIP)` for long / `r5(ask + 0.5 * PIP)` for short on every cut `Close`, flowing into Rules 1-4); (3) Monday `00:05-00:59` server FTMO-day assignment (`(t - 3600000) // 86400000`); (4) peak-to-trough domain (month-end vs intraday). **Needed for C162 memo:** report Rules 1-4 (including FTMO-day losses and `$500`/`$400` day counts) for **OPT alone (6 instances)** and **ALT alone (6 instances)** alongside the 12 together (since in `CONT`, OPT was `-$7,158` and ALT was `+$800`), plus `it.rolls` per instance. |

---

## Detailed Review (Items 1-8)

### 1. `s3`, the cut, against `sim.py`

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:24` `- **DAY (flat every night):** on every weekday, at the first tick at or after **23:45 server**, the instance is cut`
  - `research/nocarry/PREREG.md:25` `  (s3); it trades again from flat at the first tick at or after **01:00 server**. Server midnight is the brokers'`
  - `research/nocarry/PREREG.md:28` `- **WEEK (flat every weekend):** the same cut on Fridays only, restart Monday 01:00 server. This is FTMO's actual`
  - `research/nocarry/PREREG.md:33` `  skipped, from flat on 2 Jan 2023 to 23 Oct 2026. If a day's ticks end before 23:45 (an early close), the cut is`
  - `research/nocarry/PREREG.md:34` `  at that day's last tick.`
  - `research/nocarry/PREREG.md:38` `At the cut tick, after the deals and close-bys already due have run:`
  - `research/nocarry/PREREG.md:39` `1. Every resting order is removed (L0s, adds, exits, rolled exits): nothing can fill until the restart.`
  - `research/nocarry/PREREG.md:40` `2. A layer whose exit has already dealt closes at its exit price, as a normal close (scalp or rolled).`
  - `research/nocarry/PREREG.md:41` `3. Every other open layer closes at the cut tick's quote: a long at the bid, a short at the ask. Each is a`
  - `research/nocarry/PREREG.md:42` `   **cut close**, $0.06 commission like any close.`
  - `research/nocarry/PREREG.md:43` `4. Pending events and the close-by queue are cleared; the lattice's virtual levels and extremes reset; both sides`
  - `research/nocarry/PREREG.md:44` `   are empty. Between the cut and the restart no ticks reach the instance.`
  - `research/nocarry/PREREG.md:98` `3. The runner `research/nocarry/run_nocarry.py`, importing `sim.py` and `run_bars.py`'s loader unchanged; the cut`
  - `research/nocarry/PREREG.md:99` `   lives in the runner, not in `sim.py`.`
  - `research/opt_budget/sim.py:35` `class Layer:`
  - `research/opt_budget/sim.py:38` `    vl: float = None`
  - `research/opt_budget/sim.py:40` `    exit_order: object = None`
  - `research/opt_budget/sim.py:41` `    closing: bool = False`
  - `research/opt_budget/sim.py:42` `    exit_fill: float = None`
  - `research/opt_budget/sim.py:70` `    def resting(self):`
  - `research/opt_budget/sim.py:73` `        return not self.done and self.removed_ms is None`
  - `research/opt_budget/sim.py:77` `class Close:`
  - `research/opt_budget/sim.py:178` `class Side:`
  - `research/opt_budget/sim.py:180` `        self.is_long = is_long`
  - `research/opt_budget/sim.py:181` `        self.layers = []`
  - `research/opt_budget/sim.py:182` `        self.l0 = None`
  - `research/opt_budget/sim.py:183` `        self.add = None`
  - `research/opt_budget/sim.py:184` `        self.extreme = None`
  - `research/opt_budget/sim.py:185` `        self.track_from = 0`
  - `research/opt_budget/sim.py:194` `class Instance:`
  - `research/opt_budget/sim.py:197` `        self.side = {"L": Side(True), "S": Side(False)}`
  - `research/opt_budget/sim.py:198` `        self.orders = []`
  - `research/opt_budget/sim.py:199` `        self.events = []`
  - `research/opt_budget/sim.py:200` `        self.seq = 0`
  - `research/opt_budget/sim.py:201` `        self.busy = 0`
  - `research/opt_budget/sim.py:202` `        self.cb_queue = []`
  - `research/opt_budget/sim.py:203` `        self.closes = []`
  - `research/opt_budget/sim.py:204` `        self.rolls = 0`
  - `research/opt_budget/sim.py:209` `        self.ent_sent = False`
  - `research/opt_budget/sim.py:368` `        if self.busy > t:`
  - `research/opt_budget/sim.py:373` `        while self.cb_queue:`
  - `research/opt_budget/sim.py:374` `            l, s = self.cb_queue.pop(0)`
  - `research/opt_budget/sim.py:375` `            cur += D_CLOSEBY`
  - `research/opt_budget/sim.py:376` `            self._push(cur, "CB_DONE", (l, s))`
  - `research/opt_budget/sim.py:386` `            if sd.depth() == 0 and (sd.l0 is None or not sd.l0.resting()) and not self.ent_sent:`
  - `research/opt_budget/sim.py:421` `    def run_events(self, t, prev, cur_tick):`
  - `research/opt_budget/sim.py:422` `        while self.events and self.events[0][0] <= t:`
  - `research/opt_budget/sim.py:453` `            if l in sd.layers and not l.closing:`
  - `research/opt_budget/sim.py:454` `                l.closing = True`
  - `research/opt_budget/sim.py:455` `                l.exit_fill = r5(price)`
  - `research/opt_budget/sim.py:456` `                l.exit_order = None`
  - `research/opt_budget/sim.py:457` `                self.cb_queue.append((l, s))`
  - `research/opt_budget/sim.py:465` `        sd.layers.remove(l)`
  - `research/opt_budget/sim.py:466` `        self.closes.append(Close(side=s, entry=l.entry, exit=l.exit_fill, rolled=l.vl is not None,`
  - `research/opt_budget/sim.py:467` `                                 open_ms=l.open_ms, close_ms=due, swap_pips=l.swap_pips,`
  - `research/opt_budget/sim.py:468` `                                 depth_open=l.depth_open))`
  - `research/opt_budget/sim.py:548` `        for it in insts:`
  - `research/opt_budget/sim.py:549` `            it.run_events(t, prev, tk)`
  - `research/opt_budget/sim.py:550` `            it.bid, it.ask = bid, ask`
  - `research/opt_budget/sim.py:551` `            it.broker(t, sess)`
  - `research/opt_budget/sim.py:552` `        for it in insts:`
  - `research/opt_budget/sim.py:553` `            it.on_tick(t)`
- **Analysis:**
  1. **Every piece of `Instance` and `Side` state the cut must clear or reset (after `it.run_events(t, prev, tk)` has run at the cut tick `t`):**
     - **On each `Side` (`sd = it.side["L"]` and `it.side["S"]`, `sim.py:178-186`):**
       - `sd.layers`: iterate through `sd.layers` (in index order) to close each layer per steps 2 and 3, then clear `sd.layers.clear()` (which removes all `Layer` objects, including any with `l.vl is not None`, `l.closing == True`, `l.exit_order`, `l.exit_fill`, `l.swap_pips`).
       - `sd.l0 = None`: **must** be reset to `None` (or `sd.l0.removed_ms = t`). If only `it.orders.clear()` were called while `sd.l0` still pointed to the old `Order` object, `sd.l0.resting()` (`not self.done and self.removed_ms is None`, `sim.py:73`) would still return `True`, blocking `on_tick` (`sim.py:386`) from placing a new L0 at the `01:00` restart.
       - `sd.add = None`: **must** be reset to `None` (for the same reason in `resting_add_price` `sim.py:217` and `send_add` `sim.py:293`).
       - `sd.extreme = None`: reset lattice tick extreme.
       - `sd.track_from = 0`: reset lattice tracking start timestamp (`0`, matching `Side.__init__` `sim.py:185`, so even on synthetic ticks with reset clocks `sd.track_from < newest` holds).
       - (`sd.is_long` is constant and stays `True` / `False`.)
     - **On `Instance` (`it`, `sim.py:194-210`):**
       - `it.orders`: mark `o.removed_ms = t` on any resting order and clear `it.orders.clear()`.
       - `it.events`: clear `it.events.clear()`.
       - `it.cb_queue`: clear `it.cb_queue.clear()`.
       - `it.busy = 0`: reset to `0` so `if self.busy > t: return` (`sim.py:368`) cannot drop the first restart tick even in a synthetic unit test with small timestamp steps.
       - `it.ent_sent = False`: reset to `False`.
       - **Preserved across the cut:** `it.closes` (appended with step 2 and step 3 `Close` objects), `it.rolls`, `it.cfg`, `it.name`, `it.peer`, `it.budget`, `it.variant`, `it.seq`, and `it.bid, it.ask` (updated to `(bid, ask)` of the cut tick).
  2. **Is a layer whose exit has dealt but whose close-by has not run handled right by `s3` step 2?**
     - **Yes.** When an exit order (`o.role == "EXT"`) is touched on the tick before the cut (e.g. `23:44:45`, `15,000` ms before `23:45:00`), `broker` (`sim.py:414-415`) schedules `"DEAL"` at `t_touch + D_LAM` (`+261` ms). At the cut tick `t` (`23:45:00`), `it.run_events(t, prev, tk)` (`sim.py:421-433`) executes that due `"DEAL"` via `on_deal` (`sim.py:453-457`), which sets `l.closing = True`, `l.exit_fill = r5(price)`, `l.exit_order = None`, and appends `(l, s)` to `it.cb_queue` (or, if `on_tick` ran on an earlier tick `< 294` ms before `t` in a synthetic test, `"CB_DONE"` sits in `it.events` with `due > t` while `l.closing == True` and `l.exit_fill` is set).
     - Thus, after `it.run_events(t, prev, tk)` finishes at the cut tick `t`, every layer whose exit has already dealt but whose close-by has not completed is still in `sd.layers` with `l.closing == True` and `l.exit_fill` populated. Step 2 closes each `l` with `l.closing == True` by appending `Close(side=s, entry=l.entry, exit=l.exit_fill, rolled=l.vl is not None, open_ms=l.open_ms, close_ms=t, swap_pips=l.swap_pips, depth_open=l.depth_open)` (a normal scalp or rolled close), and step 4 clears `it.cb_queue` and `it.events` so the close-by is not double-processed at `01:00`.
     - Note also: at the cut tick `t`, after `it.run_events(t, prev, tk)` runs, neither `it.broker(t, sess)` nor `it.on_tick(t)` runs (step 1 removes resting orders before `broker` at `t`, and step 4 drops all ticks until `01:00`).
  3. **Can the cut and flat window be done in `run_nocarry.py` without editing `sim.py`, and does re-writing the loop break `s8` or self-check (a)?**
     - **Yes, it can be done entirely in `run_nocarry.py` without editing `sim.py` or `run_bars.py`, and it does NOT break `s8` or self-check (a).** `run_nocarry.py` imports `run_bars.load_sim("limit")` unchanged and drives `Instance` (`alt`, `opt`) in its own tick loop. Because `sim.Close` (`sim.py:77`) is a standard `@dataclass` (without `slots=True`), the runner can tag cut closes in step 3 with `c.cut = True` (and `rolled=False`) on the `sim.Close` instance appended to `it.closes`; `it.realised_pips()` (`sim.py:488-490`) and `len(it.closes)` then include cut closes automatically without touching `sim.py`. Running `CONT` through the exact same runner loop with the cut disabled (`arm == "CONT"`) exercises the runner's loop and reproduces all six `research/longrun/out_limit/cont_<PAIR>.json` files byte-for-byte.
  4. **Two edge-case gaps in `s2`/`s3` to fix:**
     - **Gap 1a (The first Monday `00:05-00:59` server):** `s2` (`PREREG.md:24-25`) says `DAY` is cut at `23:45` and restarts at `01:00`. On the very first day of the dataset (`2 Jan 2023 00:05` server, `research/cluster/PREREG.md:59`), no prior `23:45` cut has occurred yet. If `DAY` starts trading at `00:05` on the first Monday instead of waiting until `01:00`, it will hold orders/layers during `00:05-00:55` on that first day and **fail self-check (c)** (`PREREG.md:64`: `zero layers and zero resting orders at every five-minute mark between 23:45 and 01:00 server`). Similarly, `WEEK` should be flat during `[00:00, 01:00)` on the first Monday (and after any skipped week).
     - **Gap 1b (Holiday-closed Fridays in `WEEK`):** `s2` (`PREREG.md:28`) says `WEEK` cuts `"on Fridays only"`. A 4-day Mon-Thu week with Friday closed for a holiday (e.g. Good Friday) has `~5,720 >= 4,000` bars, so it is **not** skipped by `run_bars.py:64` (`len(weeks[k]) < 4000`), yet has zero Friday bars (`d.isoweekday() == 5`). Cutting `"on Fridays only"` would leave `WEEK`'s book open across the 3-day holiday weekend (violating FTMO's >2-hour break rule cited on line 29). `WEEK` must cut at the first tick at or after Friday `23:45` server, **or at the week's last tick if the week ends before Friday `23:45`**.
- **Smallest fix to `research/nocarry/PREREG.md:24-29, 33-34`:**
  - In `research/nocarry/PREREG.md:24-25`, change:
    `- **DAY (flat every night):** on every weekday, at the first tick at or after **23:45 server**, the instance is cut (s3); it trades again from flat at the first tick at or after **01:00 server**.`
    to:
    `- **DAY (flat every night):** flat in `[00:00, 01:00)` and `[23:45, 24:00)` server on every weekday (including the first day before 01:00): at the first tick at or after **23:45 server** (or at the day's last tick if the day ends before 23:45), the instance is cut (s3); it trades again from flat at the first tick at or after **01:00 server**.`
  - In `research/nocarry/PREREG.md:28`, change:
    `- **WEEK (flat every weekend):** the same cut on Fridays only, restart Monday 01:00 server.`
    to:
    `- **WEEK (flat every weekend):** flat on Mondays in `[00:00, 01:00)` server and after the weekly cut: the same cut on Fridays at or after **23:45 server** (or at the week's last tick if the week ends before Friday 23:45), restart at the first tick at or after **01:00 server** on the next week's first trading day.`

---

### 2. `s2`, the times

- **Verdict:** **CONFIRMED**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:25` `  (s3); it trades again from flat at the first tick at or after **01:00 server**. Server midnight is the brokers'`
  - `research/nocarry/PREREG.md:26` `  rollover (17:00 New York); 01:00 server is FTMO's day start (midnight Prague) in all but the few weeks a year`
  - `research/nocarry/PREREG.md:27` `  when Europe and New York change clocks apart. So each FTMO day starts flat, and no swap is ever paid.`
  - `research/longrun/run_bars.py:56` `            t = int(row[1]); o, h, l, c = map(float, row[2:6]); sp = int(row[6]) * 1e-5`
  - `research/longrun/run_bars.py:57` `            d = dt.datetime.fromtimestamp(t, dt.timezone.utc)`
  - `research/longrun/run_bars.py:58` `            if d.isoweekday() > 5:`
  - `research/longrun/run_bars.py:59` `                continue`
  - `research/longrun/run_bars.py:60` `            wk = (d - dt.timedelta(days=d.isoweekday() - 1)).strftime("%Y-%m-%d")`
  - `research/cluster/PREREG.md:58` `  M1 bars, bid OHLC, `spread_points`, server time (`server_minus_gmt_s` in each file's header).`
  - `research/cluster/PREREG.md:74` `- **Excluded minutes:** the server rollover, 23:55 to 00:10 server (spreads widen): no hit is taken there.`
  - `research/cluster/PREREG.md:129` `  23:00 server all year:** FTMO's server keeps 00:00 at 17:00 New York (GMT+2 in New York's winter, GMT+3 in its`
  - `research/cluster/PREREG.md:130` `  summer), so no offset conversion is needed (the header's `server_minus_gmt_s` is the dump day's only).`
  - `scripts/grind_bar_dump.mq5:7` `//| (the grind_tick_probe.mq5 pattern). Bar times are TRADE SERVER   |`
  - `scripts/grind_bar_dump.mq5:64` `   FileWriteString(fh, "time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n");`
  - `scripts/grind_bar_dump.mq5:67` `                                       BarDumpTime(r[i].time), (long)r[i].time,`
  - `ea/grind_pure.mqh:448` `bool Grind_LatticeRerollPaused(const datetime server_now)`
  - `ea/grind_pure.mqh:453` `   return (m >= 23 * 60 + 50) || (m < 15);`
  - `ea/grind_pure.mqh:543` `int Grind_PragueUtcOffset(const datetime gmt)`
  - `ea/grind_pure.mqh:547` `   const datetime dst_start = Grind_LastSundayMonthUtc(dt.year, 3);`
  - `ea/grind_pure.mqh:548` `   const datetime dst_end = Grind_LastSundayMonthUtc(dt.year, 10);`
  - `ea/grind_pure.mqh:549` `   if(gmt >= dst_start && gmt < dst_end)`
  - `ea/grind_pure.mqh:550` `      return 2;`
  - `ea/grind_pure.mqh:551` `   return 1;`
  - `ea/grind_pure.mqh:607` `int Grind_TorontoUtcOffset(const datetime gmt)`
  - `ea/grind_pure.mqh:611` `   const datetime dst_start = Grind_NthSundayMonthUtc(dt.year, 3, 2, 7);`
  - `ea/grind_pure.mqh:612` `   const datetime dst_end = Grind_NthSundayMonthUtc(dt.year, 11, 1, 6);`
- **Analysis:**
  1. **Are the bars' times server time?** Yes: `scripts/grind_bar_dump.mq5:64, 67` writes `(long)r[i].time` into `row[1]` (`time_unix_server`), which in MT5 `CopyRates` is the trade server timestamp (`research/cluster/PREREG.md:58, 129-130`).
  2. **Is `01:00` server FTMO's day start in both halves of the year, and how many days a year is it out by an hour?**
     - Yes: FTMO's server is `UTC+2` in North American winter and `UTC+3` in North American summer (`00:00` server = `17:00` New York, `research/cluster/PREREG.md:129-130`), while Prague (`Grind_PragueUtcOffset`, `ea/grind_pure.mqh:543-552`) is `UTC+1` (CET) in European winter and `UTC+2` (CEST) in European summer. Thus in both winter (`2 - 1 = 1`) and summer (`3 - 2 = 1`), `00:00` Prague equals **`01:00` server**.
     - It is out by 1 hour (`00:00` Prague = `23:00` UTC = **`02:00` server**, when the US is on EDT `UTC-4` / server `UTC+3` while Prague is on CET `UTC+1`) between the **2nd Sunday in March** and the **last Sunday in March** (14 calendar days / 10 weekdays in 2023; 21 calendar days / 15 weekdays in 2024, 2025, and 2026) and between the **last Sunday in October** and the **1st Sunday in November** (7 calendar days / 5 weekdays in 2023, 2024, and 2025; after the dataset's 23 Oct end in 2026). That is **21 or 28 calendar days (15 or 20 trading days) per year** (`98` calendar days / `70` weekdays across the 2023-23 Oct 2026 span). Even on those days, `DAY` is flat from `23:45` to `01:00` server (`20:45` to `22:00` UTC) and starts flat before `02:00` server (`23:00` UTC = `00:00` CET), while no swap is ever charged at `00:00` server.
  3. **Is `23:45` server before the rollover's wide spreads on these bars?**
     - Yes: `23:45` server is 5 minutes before `Grind_LatticeRerollPaused` (`23:50-00:15` server, `ea/grind_pure.mqh:453`), 10 minutes before the Osler rollover exclusion (`23:55-00:10` server, `research/cluster/PREREG.md:74`), and 12 minutes before Friday's session close (`23:57` server, `research/opt_budget/MECHANICS.md:50`), with the `0.5` pip sensitivity (`PREREG.md:55-56`) testing wider cut spreads.
  4. **Does `run_bars.py`'s use of `fromtimestamp(t, utc)` for weekdays still give the right server day?**
     - Yes: because `row[1]` (`t`) is seconds since `1970-01-01 00:00:00` **server time**, `dt.datetime.fromtimestamp(t, dt.timezone.utc)` (`run_bars.py:57`) decodes `t` with zero offset, returning the exact server calendar date, server `hour:minute`, and server ISO weekday (`1..5` = Monday `00:00` server through Friday `23:59` server, covering the entire Sunday `17:00` NY to Friday `17:00` NY FX week).

---

### 3. `s4`, the FTMO-day loss

- **Verdict:** **DEFECT**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:50` `- **By FTMO day (01:00 server to 01:00 server), the twelve instances together** (E's account): the day's change in`
  - `research/nocarry/PREREG.md:51` `  balance, and **the day's loss as FTMO counts it**: the balance at the day's start less the lowest equity in the`
  - `research/nocarry/PREREG.md:52` `  day (realised + open, from the five-minute marks). The count of days at **$500 or worse**, and at $400 or worse;`
  - `research/nocarry/PREREG.md:53` `  the worst ten days with dates. For CONT the carried book counts against the day, as it did for E.`
  - `research/opt_budget/sim.py:537` `        while next_mark <= t:`
  - `research/opt_budget/sim.py:538` `            marks.append((next_mark, [(it.realised_pips(), it.open_pips(prev[1], prev[2]), len(it.closes),`
  - `research/opt_budget/sim.py:539` `                                       it.open_layers()) for it in insts]))`
  - `research/opt_budget/sim.py:540` `            next_mark += mark_ms`
  - `research/longrun/run_bars.py:67` `            for j, p in enumerate([o, l, h, c] if c >= o else [o, h, l, c]):`
  - `research/longrun/run_bars.py:68` `                tk.append((t * 1000 + j * 15000, round(p, 5), round(p + sp, 5)))`
  - `docs/research/ftmo-pass-probability.md:21` `- **Daily loss $500 from the BALANCE at 00:00 CE(S)T** = 22:00Z ("the`
  - `docs/research/ftmo-pass-probability.md:22` `  account balance recorded at 00:00 CE(S)T of the current day"): open`
  - `docs/research/ftmo-pass-probability.md:23` `  loss carried over midnight counts against the new day at once.`
  - `research/e_week1/PREREG.md:16` `At the low, balance $10,070, equity $9,770. **FTMO's daily loss = day-start balance - the day's lowest equity =`
  - `research/e_week1/PREREG.md:17` `$10,050 - $9,770 = $280**, though the day's closed P&L was +$20: $53 of it was carried in from earlier days`
  - `handoffs/HANDOFF_2026-09-24.md:9186` `- **Why: the trial's $500 daily loss.** FTMO's day from 23:00Z 3 Nov: balance $10,252.10 (floor $9,752.10); equity`
  - `handoffs/HANDOFF_2026-09-24.md:9187` `  $9,871.67, the carried book -$391 using **$380.43 of the $500 before the day began**. Scalps +$41.68; the book to`
  - `handoffs/HANDOFF_2026-09-24.md:9188` `  -$523; equity $9,775.01 at 01:36:00Z; close-out balance **$9,746.75: loss $505.35**. The day before (FTMO 3 Nov)`
  - `ea/grind_pure.mqh:660` `double Grind_BreakerDayAnchor(const double balance_now,`
  - `ea/grind_pure.mqh:668` `   return Grind_BreakerAnchor(balance_now, amounts, times, n, boundary);`
  - `ea/grind_pure.mqh:672` `bool Grind_BreakerShouldTrip(const double equity, const double anchor,`
  - `ea/grind_pure.mqh:677` `   return (equity <= anchor - frac * allowance);`
- **Analysis:**
  1. **Is `"balance at the day's start"` right for FTMO in the repo's record?**
     - **Yes, confirmed** across four places in the repo (FTMO's site not read): `docs/research/ftmo-pass-probability.md:21-23`, `research/e_week1/PREREG.md:16-17`, `handoffs/HANDOFF_2026-09-24.md:9186-9188` (E's actual 4 Nov liquidation at `$505.35` below the `23:00Z` day-start balance of `$10,252.10`), and `ea/grind_pure.mqh:660-678` (`Grind_BreakerDayAnchor` / `Grind_BreakerShouldTrip`).
  2. **Why computing lowest equity from `sim.py`'s 5-minute marks is a DEFECT, and how big the miss can be:**
     - In `run_bars.py:67-68`, each M1 bar is expanded into four ticks 15 s apart: `+0 s` (`open`), `+15 s` and `+30 s` (`low` and `high`), and `+45 s` (`close`).
     - In `sim.py:537-540`, `marks` are emitted only when `next_mark <= t` (`mark_ms = 300,000` ms, i.e. at `:00:00, :05:00, :10:00, ...`) **before** tick `t` is processed, using `prev[1], prev[2]` -- which is the **close (`+45 s`) of every 5th minute bar** (`:59:45, :04:45, :09:45, ...`).
     - Consequently, **the 5-minute marks never observe any M1 bar's `high` or `low` ticks (`+15 s` and `+30 s`) -- not even in the 5th minute -- and completely skip 4 out of every 5 minutes (19 of every 20 ticks)**.
     - **Size of the miss:** At cap 7 (`0.01` lots), a single pair stacked on both OPT and ALT (14 layers) has sensitivity `$1.40/pip` on EURUSD/GBPUSD (`$1.71/pip` on AUDCHF/CADCHF, `$1.88/pip` on EURGBP), and across a correlated multi-pair USD/CHF/EUR move (like 4 Nov's 95 layers in `HANDOFF_2026-09-24.md:9144, 9200`) the 12 instances together have sensitivity **`~$7.00-$8.50/pip`**. A 20-50 pip excursion on a bar's high/low wick or inside a 5-minute window that pulls back before the 5-minute close (or triggers a roll whose exit has not yet filled, or recovers before `23:45`) misses **`$28-$70` on a single pair and `$140-$400+` across the 12 instances**, directly affecting Rule 4 (`at most four FTMO days of $500 or worse`, `PREREG.md:75`).
     - **Should lowest equity be tracked on every tick instead?** **Yes.** Because every bar's four ticks across all six pairs lie on the exact 15-second grid `t_bar * 1000 + j * 15000` (`j in 0, 1, 2, 3`), advancing the six pairs in lockstep (or indexing equity on the 15-second tick grid within each FTMO day, carrying forward the previous tick's `(realised, open)` for any pair missing that minute's bar, evaluated **after** `run_events`, `broker`, and `on_tick`/cut at tick `t` using tick `t`'s `(bid, ask)`) captures the exact tick-level lowest equity across all four ticks (`open, low, high, close`) of every M1 bar while keeping the 5-minute marks for self-check (a) and the month-end series.
- **Smallest fix to `research/nocarry/PREREG.md:51-52`:**
  - Change:
    `balance, and **the day's loss as FTMO counts it**: the balance at the day's start less the lowest equity in the day (realised + open, from the five-minute marks).`
    to:
    `balance, and **the day's loss as FTMO counts it**: the balance at the day's start (01:00 server) less the lowest equity in the day (realised + open across the twelve instances, evaluated after each 15 s tick's events, fills or cut, holding a pair's last tick mark across any missing minute).`

---

### 4. `s5`, the self-checks

- **Verdict:** **DEFECT**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:60` `a. CONT reproduces the six `out_limit` files byte for byte (hashes in `research/longrun/MANIFEST.md`).`
  - `research/nocarry/PREREG.md:61` `b. Unit tests on a synthetic tick stub, committed first and failing against a stub runner: the cut closes every`
  - `research/nocarry/PREREG.md:62` `   layer at the right side of the quote; no order fills between cut and restart; a dealt exit at the cut is a`
  - `research/nocarry/PREREG.md:63` `   normal close; the restart places a fresh L0 on both sides; the FTMO-day loss of a hand-worked two-day example.`
  - `research/nocarry/PREREG.md:64` `c. DAY: zero layers and zero resting orders at every five-minute mark between 23:45 and 01:00 server.`
  - `research/nocarry/PREREG.md:65` `d. The accounting closes per instance: scalps + rolled + cut + open + commission = net, to the cent.`
  - `research/nocarry/PREREG.md:66` `e. One week by hand: the data's last week (**19-23 Oct 2026**), GBPUSD OPT: every cut close listed and checked`
  - `research/nocarry/PREREG.md:67` `   against the 23:45 bars.`
  - `research/opt_budget/sim.py:220` `    def _place(self, cur, is_buy, price, role, s, layer=None):`
  - `research/opt_budget/sim.py:221` `        cur += D_PLACE`
  - `research/opt_budget/sim.py:372` `        self.ent_sent = False`
  - `research/opt_budget/sim.py:385` `        for sd, tgt, s in ((L, buy_t, "L"), (S, sell_t, "S")):`
  - `research/opt_budget/sim.py:386` `            if sd.depth() == 0 and (sd.l0 is None or not sd.l0.resting()) and not self.ent_sent:`
  - `research/opt_budget/sim.py:387` `                if (tgt < ask) if sd.is_long else (tgt > bid):`
  - `research/opt_budget/sim.py:388` `                    sd.l0, cur = self._place(cur, sd.is_long, tgt, "ENT", s)`
  - `research/opt_budget/sim.py:389` `                    self.ent_sent = True`
  - `research/opt_budget/sim.py:401` `        self.busy = cur`
  - `research/opt_budget/MECHANICS.md:20` `- **One ENT send per tick per instance** (`g_grind_ent_sent_this_tick`, 2087, 2361).`
  - `research/longrun/run_bars.py:78` `    def split(it):`
  - `research/longrun/run_bars.py:79` `        sc = sum(pips(c) for c in it.closes if not c.rolled)`
  - `research/longrun/run_bars.py:80` `        rc = sum(pips(c) for c in it.closes if c.rolled)`
  - `research/longrun/run_bars.py:81` `        return {"scalp": round(sc * u, 2), "rolled": round(rc * u, 2), "open": round(it.open_pips(tk[-1][1], tk[-1][2]) * u, 2),`
  - `research/longrun/run_bars.py:82` `                "comm": round(-COMM * len(it.closes), 2), "layers": it.open_layers()}`
- **Analysis:**
  1. **Is (a) achievable if the runner re-writes the loop?**
     - **Yes.** When `run_nocarry.py` runs `CONT` through its rewritten loop with no cuts, it executes the exact same `Instance` calls and `marks` updates as `sim.run_instances` (`sim.py:526-558`) and produces byte-identical JSON to `research/longrun/out_limit/cont_<PAIR>.json` (note: on Windows, write with `newline="\n"` so `LF` line endings match the `MANIFEST.md` sha256 hashes).
  2. **Defect in (b) (`"the restart places a fresh L0 on both sides"`, `PREREG.md:63`):**
     - In `sim.py:385-389`, `on_tick` enforces **one `ENT` placement per tick per instance** (`self.ent_sent = True`, `MECHANICS.md:20`) and sets `self.busy = t + D_PLACE` (`t + 287` ms, `sim.py:221, 401`).
     - Therefore, at the restart at `01:00`, the **first** tick (`01:00:00`) places **only the long L0 (`L.l0`)**; the **short L0 (`S.l0`)** is placed on the **second** tick at or after `t_restart + 287` ms (`01:00:15` on bar ticks). If the unit test in (b) feeds a single tick at `01:00` and asserts that both sides have a resting L0, it will **fail against `sim.py`**.
  3. **Defect and sufficiency gap in (c) (`"DAY: zero layers and zero resting orders at every five-minute mark between 23:45 and 01:00 server"`, `PREREG.md:64`):**
     - **Ordering / boundary defect:** In `sim.py:537-540`, `while next_mark <= t:` appends `marks` **before** tick `t` is processed (`run_events`, `broker`, `on_tick`/cut) and `marks` does not record resting order counts. If the `23:45:00` mark is recorded *before* the `23:45:00` cut executes, `open_layers()` at `23:45:00` is non-zero (failing check (c) at `23:45`); conversely, if marks were moved *after* `on_tick`, the `01:00:00` mark would see `L.l0` resting (failing check (c) at `01:00`). Check (c) must specify the half-open interval `[23:45, 01:00)` (`23:45, 23:50, ..., 00:55` server) evaluated **after** the `23:45` cut has run at `23:45:00` (and before `01:00:00` restarts).
     - **Sufficiency gap:** Checking 5-minute marks in `[23:45, 01:00)` for `DAY` does not check: (i) **early-close days** (`PREREG.md:33-34`) where ticks end before `23:45`, (ii) **`WEEK`** across the weekend, or (iii) that no `Layer` or `Close` has `open_ms` or `close_ms` strictly inside `(t_cut, t_restart)`. Adding those three assertions makes (c) complete.
  4. **Non-error failure trap in (d) (`"scalps + rolled + cut + open + commission = net, to the cent"`, `PREREG.md:65`):**
     - In `run_bars.py:81-82`, `scalp`, `rolled`, `open`, and `comm` are each independently rounded to 2 decimals (`round(..., 2)`). If `net` is defined as `scalp + rolled + cut + open + comm` (as in `results.md:52`), it holds to `$0.00` by definition; if `net` is rounded directly from unrounded total pips (`round((sc + rc + cc + open_pips) * u - COMM * len(closes), 2)`), the sum of the five rounded components can differ by `$0.01-$0.02` due to cent rounding. Define `net = round(scalp + rolled + cut + open + comm, 2)` (or allow `<= $0.02` against unrounded total pips).
  5. **Is (e) (`"One week by hand: the data's last week (19-23 Oct 2026), GBPUSD OPT: every cut close listed and checked against the 23:45 bars"`, `PREREG.md:66-67`) checkable from the bars alone?**
     - From the `23:45` bars alone, one can verify that every cut close's timestamp is `23:45:00` server (or the day's last tick), its exit price equals the `23:45` bar's opening `bid` (`open`, for a long) or opening `ask` (`open + spread_points * 1e-5`, for a short), and its pip/USD P&L matches `(exit - entry)` / `(entry - exit)` less `$0.06`. Which layers are open at `23:45` and their `entry` prices depend on the day's `01:00-23:44` fills and rolls, so (e) should state that the `23:45` bars check each cut close's exit price and P&L arithmetic (with each layer's `entry` and `open_ms` traced to its `ENT` fill earlier that day).
- **Smallest fix to `research/nocarry/PREREG.md:61-67`:**
  - Change lines `63-67` from:
    ```markdown
       normal close; the restart places a fresh L0 on both sides; the FTMO-day loss of a hand-worked two-day example.
    c. DAY: zero layers and zero resting orders at every five-minute mark between 23:45 and 01:00 server.
    d. The accounting closes per instance: scalps + rolled + cut + open + commission = net, to the cent.
    e. One week by hand: the data's last week (**19-23 Oct 2026**), GBPUSD OPT: every cut close listed and checked
       against the 23:45 bars.
    ```
    to:
    ```markdown
       normal close; the restart places a fresh L0 on L at the first restart tick and on S at the next tick (>= 287 ms later); the FTMO-day loss of a hand-worked two-day example.
    c. DAY and WEEK: zero layers and zero resting orders after every cut (including early closes) and at every five-minute mark in [23:45, 01:00) server (evaluated after the 23:45 cut), and zero opens or closes in (t_cut, t_restart).
    d. The accounting closes per instance: net = scalps + rolled + cut + open + commission, to the cent (and within $0.02 of unrounded total pips x USD/pip + commission).
    e. One week by hand: the data's last week (**19-23 Oct 2026**), GBPUSD OPT: every cut close listed (with its entry fill time and price from that day's run) and its exit price and P&L checked against the 23:45 bar's open bid / ask.
    ```

---

### 5. `s6`, the rule

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:54` `- By calendar year; the share of single months, three-month and twelve-month windows negative; peak to trough.`
  - `research/nocarry/PREREG.md:71` `**EDGE WITHOUT CARRY** only if DAY passes all four, the twelve instances together, after commission:`
  - `research/nocarry/PREREG.md:72` `1. Net over the whole period above zero.`
  - `research/nocarry/PREREG.md:73` `2. At least three of the four calendar years (2023, 2024, 2025, 2026 to 23 Oct) above zero.`
  - `research/nocarry/PREREG.md:74` `3. Fewer than half of the twelve-month windows negative.`
  - `research/nocarry/PREREG.md:75` `4. **At most four FTMO days of $500 or worse** over the period (about one a year).`
  - `research/nocarry/PREREG.md:77` `- Passes 1-3 but not 4: **EDGE, NOT FTMO-SAFE.** Fails any of 1-3: **NO EDGE**, and the C162 memo says the`
  - `research/nocarry/PREREG.md:78` `  project stops.`
  - `research/nocarry/PREREG.md:80` `- WEEK is judged by the same four rules and reported beside DAY; it does not decide. OPT and ALT are reported`
  - `research/nocarry/PREREG.md:81` `  apart; the rule is on the twelve together, because that is the account E ran.`
  - `research/longrun/results.md:50` `| **total** | **-7,158** | | | **+800** | | |`
  - `research/longrun/results.md:54` `- **By year (both arms):** 2023 -$2,232; 2024 -$3,113; 2025 -$1,887; 2026 to 23 Oct +$876.`
  - `research/longrun/results.md:55` `- **Windows of the month-end equity:** negative in 27 of 45 single months (60%), 29 of 43 three-month windows (67%),`
  - `research/longrun/results.md:56` `  27 of 34 twelve-month windows (79%); the worst twelve months -$4,599; peak to trough -$7,854.`
  - `research/longrun/results.md:57` `- **The open book stays bounded:** -$751 at the end, between -$471 and -$1,163 at every month end. The cap and`
- **Analysis:**
  1. **Could DAY pass or fail whatever happens (is `"at most four $500 days"` loose or tight)?**
     - It is neither trivially loose nor impossible: in `CONT`, the carried open book is `-$471` to `-$1,163` at every month-end (`results.md:57`) and caused E's `$505.35` breach on 4 Nov (`$380.43` carried in, `HANDOFF_2026-09-24.md:9187-9188`). In `DAY`, every FTMO day starts flat (`$0` carried loss), so a `$500` day requires losing `$500` within a single day (`01:00-23:45` server) from flat across the 12 instances. Allowing at most 4 such tail days in ~4 years (~1/year) is a realistic FTMO survival threshold, and `PREREG.md:77` cleanly separates edge (Rules 1-3) from FTMO tail risk (Rule 4) via **`EDGE, NOT FTMO-SAFE`**.
  2. **Is judging the twelve instances together fair, and is 2026 (to 23 Oct) as a year fair?**
     - Judging the 12 instances together is fair for E's account (`PREREG.md:81`), provided OPT (6 instances) and ALT (6 instances) are also scored separately on Rules 1-4 for the C162 memo (see Item 8, since OPT lost `-$7,158` while ALT gained `+$800` in `CONT`, `results.md:50`).
     - Treating `2026 (to 23 Oct)` (~10 months, 81% of a year) as the fourth year in Rule 2 is fair and slightly generous: in `CONT` (`results.md:54`), `2026 to 23 Oct` was the **only** positive year (`+$876`), while 2023 (`-$2,232`), 2024 (`-$3,113`), and 2025 (`-$1,887`) were all negative.
  3. **Gap in `s4`/`s6` (window denominator and calendar-year formula):**
     - In `results.md:55-56`, the 46 month-end marks `E[0..45]` (`2023-01` to `2026-10`) were differenced as `E[i] - E[i - k]` for `i = k..45` without prepending `E[-1] = 0.0` at 2 Jan 2023, giving **45** single-month, **43** three-month, and **34** twelve-month windows (`< 17` -> at most `16` negative), whereas prepending `E[-1] = 0.0` (so the first 12-month window `E[11] - 0.0` is full year 2023) gives **46**, **44**, and **35** windows (`< 17.5` -> at most `17` negative). A result with 17 negative 12-month windows would flip between PASS and FAIL depending on whether `E[-1] = 0.0` is prepended.
     - Similarly, `s4`/`s6` should state explicitly that each calendar year's P&L in Rule 2 is the change in combined month-end equity (`realised + open` after commission) from the prior year's last mark (`0.0` at start of 2023) to that year's last mark (matching `results.md:54`), with `"above zero"` meaning `> 0.0` and `"negative"` meaning `< 0.0`.
- **Smallest fix to `research/nocarry/PREREG.md:54, 73-74`:**
  - In `research/nocarry/PREREG.md:54`, change:
    `- By calendar year; the share of single months, three-month and twelve-month windows negative; peak to trough.`
    to:
    `- By calendar year (change in combined year-end equity `realised + open` from 0.0 at 2 Jan 2023); the share of single-month (45), three-month (43) and twelve-month (34) windows of the 46 month-end equity marks `E[i] - E[i - k] < 0` (as `results.md` s3; also reported with `E[-1] = 0` prepended: 46, 44, 35); peak to trough of month-end equity.`
  - In `research/nocarry/PREREG.md:74`, change:
    `3. Fewer than half of the twelve-month windows negative.`
    to:
    `3. Fewer than half of the 34 twelve-month windows negative (at most 16 with `E[i] - E[i - 12] < 0`).`

---

### 6. `s7`, the biases

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:85` `- **Bars are not ticks:** limits fill at their own price; a cut closes at the 23:45 bar's open quote, no latency.`
  - `research/nocarry/PREREG.md:86` `- **No swap anywhere:** this flatters CONT and WEEK, which carry; DAY never pays swap, so the comparison is`
  - `research/nocarry/PREREG.md:87` `  conservative against DAY.`
  - `research/nocarry/PREREG.md:88` `- The bars' spread field may be the bar's lowest spread: the sensitivity covers the cut; it also flatters every`
  - `research/nocarry/PREREG.md:89` `  fill, in all three arms alike.`
  - `research/nocarry/PREREG.md:90` `- The FTMO day at 01:00 server is out by an hour for a few weeks a year (s2).`
  - `research/nocarry/PREREG.md:91` `- A restart at 01:00 places fresh L0s straddling the price, so DAY trades the open of every day: if the first`
  - `research/nocarry/PREREG.md:92` `  hour is costly, DAY pays it; that is the arm as an operator would run it.`
  - `research/longrun/run_bars.py:64` `        if len(weeks[k]) < 4000:          # skip holiday-short weeks (as the weekly runs did)`
  - `research/longrun/run_bars.py:65` `            continue`
  - `research/longrun/run_bars.py:70` `    co = sim.Cfg(width=wo, add=ao, exit=ao, cap=7, stranded=so, deadband=2.0)`
  - `research/longrun/run_bars.py:71` `    ca = sim.Cfg(width=wa, add=aa, exit=aa, cap=7, stranded=sa, deadband=2.0)`
  - `research/longrun/run_bars.py:72` `    r = sim.run_pair(tk, co, ca)`
  - `research/opt_budget/sim.py:31` `    carry: bool = False`
  - `research/opt_budget/sim.py:472` `    def rollover(self, t, row):`
  - `research/opt_budget/sim.py:473` `        if not self.cfg.carry or row is None:`
  - `research/opt_budget/sim.py:474` `            return`
  - `research/opt_budget/sim.py:532` `        if day is not None and d != day and carry_rows is not None:`
  - `research/opt_budget/sim.py:567` `def run_pair(ticks, cfg_opt, cfg_alt, carry_rows=None, budget=False, sessions=None, variant="B"):`
- **Analysis:**
  1. **Confirm `"no swap anywhere"`:**
     - **Confirmed.** `run_bars.py:70-72` constructs `sim.Cfg(...)` with default `carry: bool = False` (`sim.py:31`) and calls `sim.run_pair(tk, co, ca)` with default `carry_rows=None` (`sim.py:567`), so `if day is not None and d != day and carry_rows is not None:` (`sim.py:532`) is never entered and `rollover()` (`sim.py:472-474`) never accrues `swap_pips`.
  2. **What is missing or understated in `s7`:**
     - **The weekly `< 4,000`-bar skip (`run_bars.py:64`) and early-close lookahead (`PREREG.md:33-34`):** Skipping weeks with `< 4,000` bars carries `CONT`'s open book straight across the skipped holiday week to the next kept Monday open (a 9-day jump with no intermediate ticks, whereas `DAY` and `WEEK` are flat across it); and on early-close days inside a kept week, cutting at `"that day's last tick"` uses lookahead on the bar list `tk` (standing in for a known holiday schedule in live operation).
     - **The rollover window (`23:45-01:00` server) and the restart's first hour:** `sim.py` does not implement `Grind_LatticeRerollPaused` (`23:50-00:15` server, `ea/grind_pure.mqh:448-454`) or the session file's `23:59`/`00:01` gap (`sessions=None` in `run_bars.py:72`). Thus `CONT` and `WEEK` remain exposed to wide rollover spreads in `23:45-01:00` (which can trigger short exit/add fills and lattice rolls on ask spikes), whereas `DAY` avoids `23:45-01:00` and instead pays the `01:00` re-entry straddle every day.
     - **Latency at the cut:** `PREREG.md:85` notes `"no latency"` at `23:45`; in live MT5, cancelling all resting orders and market-closing up to dozens of layers across 12 instances executes sequentially over several seconds (`D_REMOVE = 43` ms, deals `~261` ms each), so later closes can slip from the `23:45:00` open quote (partially covered by the `0.5` pip sensitivity).
     - **The bar spread field's meaning:** In MT5 `MqlRates` (`scripts/grind_bar_dump.mq5:72`), `r[i].spread` (`spread_points`) **is** the bar's minimum spread in points (not just `"may be"` as written on line 88).
- **Smallest fix to `research/nocarry/PREREG.md:85, 88-92`:**
  - In `research/nocarry/PREREG.md:85`, change `no latency.` to `no sequential close latency across the twelve instances (partially covered by the 0.5 pip sensitivity).`
  - In `research/nocarry/PREREG.md:88`, change `The bars' spread field may be the bar's lowest spread:` to `The bars' spread field (`MqlRates.spread`) is the minute's minimum spread:`
  - After `research/nocarry/PREREG.md:92`, add:
    `- **Holiday weeks and early closes:** skipping weeks with under 4,000 bars (`run_bars.py` 64) carries CONT's open book across the skipped week while DAY and WEEK are flat; cutting at an early close's last tick uses the bar file's end-of-day timestamp as a proxy for a known holiday schedule. Also, `sim.py` does not pause re-rolls in 23:50-00:15 server (`Grind_LatticeRerollPaused`), which affects CONT and WEEK during the rollover when DAY is flat.`

---

### 7. `s1`, the worked example

- **Verdict:** **CONFIRMED**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:14` `GBPUSD OPT (add = exit = 9 pips). At 23:44 server the short side holds three layers sold at 1.34500, 1.34590 and`
  - `research/nocarry/PREREG.md:15` `1.34680; the ask is 1.34620. At 23:45 DAY closes all three at the ask: -12.0, -3.0 and +6.0 pips, so -9.0 pips`
  - `research/nocarry/PREREG.md:16` `= -$0.90 less 3 x $0.06 commission = **-$1.08**, realised. No orders rest overnight. At 01:00 server the instance`
  - `research/nocarry/PREREG.md:17` `starts again from flat, as on a fresh attach. In the continuous run those three layers would have been carried, and`
  - `research/nocarry/PREREG.md:18` `the -12 pip layer was free to come back, or to be rolled 9 pips at a time if price kept rising.`
  - `research/longrun/run_bars.py:23` `GEO = {"EURUSD": ((2.0, 7, 3.0), (6.0, 23, 7.0)), "GBPUSD": ((2.5, 9, 3.5), (4.0, 15, 5.0)),`
  - `research/longrun/run_bars.py:26` `USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}`
  - `research/longrun/run_bars.py:27` `COMM = 0.06`
  - `ea/presets_e/gbpusd_opt_e_t3.set:3` `InpWidthPips=2.5`
  - `ea/presets_e/gbpusd_opt_e_t3.set:4` `InpAddPips=9.0`
  - `ea/presets_e/gbpusd_opt_e_t3.set:5` `InpExitPips=9.0`
  - `ea/presets_e/gbpusd_opt_e_t3.set:12` `InpMaxLayers=7`
  - `ea/presets_e/gbpusd_opt_e_t3.set:14` `InpStrandedThreshPips=3.5`
- **Analysis:**
  - **Geometry and parameters:** GBPUSD OPT in `run_bars.py:23` and `ea/presets_e/gbpusd_opt_e_t3.set:3-5` has `width = 2.5`, `add = exit = 9.0` pips (`0.00090`), `stranded = 3.5`, `USD["GBPUSD"] = $0.100`/pip (`run_bars.py:26`), and `COMM = $0.06`/close (`run_bars.py:27`).
  - **Stack and exits:** Short layers at `1.34500`, `1.34590`, and `1.34680` are spaced by `9.0` pips (`0.00090`). Their exit targets (`entry - 9.0` pips) are `1.34410`, `1.34500`, and `1.34590`; at `ask = 1.34620 > 1.34590`, none of the three exits is marketable at the cut.
  - **Cut arithmetic (`s3` step 3, shorts closed at `ask = 1.34620`):**
    - Layer 0 (`1.34500`): `(1.34500 - 1.34620) / 0.0001 = -12.0` pips
    - Layer 1 (`1.34590`): `(1.34590 - 1.34620) / 0.0001 = -3.0` pips
    - Layer 2 (`1.34680`): `(1.34680 - 1.34620) / 0.0001 = +6.0` pips
    - Total pips: `-12.0 + (-3.0) + 6.0 = -9.0` pips = `-9.0 x $0.100 = -$0.90` gross, less `3 x $0.06 = $0.18` commission = **`-$1.08`** net realised.

---

### 8. Anything that would let the result be bent after the fact, and anything missing for the C162 memo

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/nocarry/PREREG.md:48` `- Per pair, arm and grid (OPT, ALT): scalps, rolled closes, **cut closes**, open at the end (zero for DAY),`
  - `research/nocarry/PREREG.md:49` `  commission, net; the count and the median loss of cut closes; month-end series as the longrun run.`
  - `research/nocarry/PREREG.md:55` `- **Sensitivity:** the same run with every cut close a further **0.5 pip** worse (the bars' spread field may`
  - `research/nocarry/PREREG.md:56` `  understate the spread near the rollover).`
  - `research/nocarry/PREREG.md:79` `- A pass that fails under the 0.5 pip sensitivity is reported **FRAGILE**, which the memo treats as NO EDGE.`
  - `research/nocarry/PREREG.md:80` `- WEEK is judged by the same four rules and reported beside DAY; it does not decide. OPT and ALT are reported`
  - `research/nocarry/PREREG.md:81` `  apart; the rule is on the twelve together, because that is the account E ran.`
  - `research/longrun/run_bars.py:86` `        los = [(c.close_ms - c.open_ms) / 3.6e6 for c in it.closes if pips(c) <= 0]`
  - `research/longrun/run_bars.py:87` `        med = lambda v: sorted(v)[len(v) // 2] if v else None`
  - `handoffs/HANDOFF_2026-09-24.md:9227` `3. **The C162 memo:** the four years, the no-carry result, the live weeks, D and E's day; reviewed before any`
- **Analysis:**
  1. **Choices or measures without an exact formula that should be pinned before coding:**
     - **How the `0.5` pip sensitivity (`PREREG.md:55-56, 79`) is applied:** State explicitly that under the sensitivity, each cut `Close` in `s3` step 3 records `exit = r5(bid - 0.5 * PIP)` (long) or `exit = r5(ask + 0.5 * PIP)` (short) (equivalently subtracting `0.5 * USD[pair]` per cut close from realised P&L at the cut timestamp `t_cut`). Because the instance is flat from `t_cut` to `01:00`, order and fill trajectories are identical to the base run, and the `0.5` pip penalty per cut layer flows into **all four rules (1-4)**, including the `23:45-01:00` balance/equity inside that FTMO day for Rule 4.
     - **Exact definition of `"the count and the median loss of cut closes"` (`PREREG.md:49`):** A cut close can be positive or negative (e.g. `+6.0` pips on the third layer in `s1`, `PREREG.md:15`). Specify: (i) the count `n_cut` of individual cut `Close` records (and how many are `<= 0` pips vs `> 0` pips), (ii) the median signed P&L in pips and USD (before commission) over all cut closes using `sorted(v)[len(v) // 2]` (`run_bars.py:87`), and (iii) the median net USD P&L per **cut event (night)** across the instance's cuts.
     - **Exact FTMO-day key and Monday `00:05-00:59` server sliver (`PREREG.md:50-53`):** Define the FTMO day key for timestamp `t` (in server ms) as `ftmo_day = (t - 3600000) // 86400000` (so `[01:00, 01:00)` server is one FTMO day), `day_start_balance` as the combined realised balance after commission at the start of that FTMO day (`0.0` initially), and `day_loss = max(0.0, day_start_balance - min_equity_in_day)`, with Rule 4 counting days where `round(day_loss, 2) >= 500.00` (and `>= 400.00`). Note that on Mondays `00:05-00:59` server, `DAY` and `WEEK` are flat (`day_loss = 0`), while `CONT`'s `00:05-00:59` server ticks belong to the Sunday-open FTMO day (`(t - 3600000) // 86400000`, matching `research/e_week1/PREREG.md:24-25`).
  2. **What is missing that the C162 memo will need from this test:**
     - **Rules 1-4 (including FTMO-day losses and `$500`/`$400` day counts) evaluated separately for OPT (the 6 OPT instances together) and ALT (the 6 ALT instances together):** In `CONT` (`results.md:50`), OPT lost `-$7,158` (`-$6,064` commission) while ALT gained `+$800` (`-$1,380` commission). The C162 memo must decide whether *any* part of the t3 grid (such as ALT alone, or C's low-frequency shape) has a viable edge or FTMO profile without carry, or whether both OPT and ALT fail once overnight/weekend carry is cut. Currently `s4` (`PREREG.md:50`) computes FTMO-day losses only for the 12 instances together.
     - **Roll step counts (`it.rolls`) per instance/arm in `s4`:** Reporting `it.rolls` (`ROLL_ACCEPTED` count) alongside `scalps`, `rolled` closes, and `cut` closes shows directly whether cutting at `23:45` prevents stacks from reaching cap 7 and rolling, or whether intraday trends still roll the stack before `23:45`.
- **Smallest fix to `research/nocarry/PREREG.md:48-56`:**
  - In `research/nocarry/PREREG.md:48-49`, change:
    `- Per pair, arm and grid (OPT, ALT): scalps, rolled closes, **cut closes**, open at the end (zero for DAY), commission, net; the count and the median loss of cut closes; month-end series as the longrun run.`
    to:
    `- Per pair, arm and grid (OPT, ALT): scalps, rolled closes, **cut closes**, roll steps (`it.rolls`), open at the end (zero for DAY and WEEK), commission, net; cut close counts (`n_cut`, `n_cut_loss` with pips <= 0) and median cut P&L (pips and USD, `sorted(v)[len(v) // 2]`, over all cut closes and per cut night); month-end series as the longrun run.`
  - In `research/nocarry/PREREG.md:50`, change:
    `- **By FTMO day (01:00 server to 01:00 server), the twelve instances together** (E's account):`
    to:
    `- **By FTMO day (`(t - 3600000) // 86400000`, 01:00 server to 01:00 server), for the twelve instances together** (E's account, deciding) **and separately for the six OPT and six ALT instances**:`
  - In `research/nocarry/PREREG.md:55-56`, change:
    `- **Sensitivity:** the same run with every cut close a further **0.5 pip** worse (the bars' spread field may understate the spread near the rollover).`
    to:
    `- **Sensitivity:** the same run with every cut close's exit price a further **0.5 pip** worse (`bid - 0.5 * PIP` for longs, `ask + 0.5 * PIP` for shorts at s3 step 3, flowing into balance and Rules 1-4).`

---

## Overall Verdict

**SOUND WITH CHANGES** (1. define `DAY` as flat in `[00:00, 01:00)` on the first day too, and cut `WEEK` at the week's last tick if a week ends before Friday `23:45`; 2. track FTMO-day lowest equity across the 12 instances on every 15 s tick rather than 5-minute bar-close marks; 3. in `s5`, fix (b)'s two-tick L0 placement (`L` at `01:00:00`, `S` at `01:00:15`), specify `[23:45, 01:00)` post-cut marks and early-close/WEEK/no-fill checks in (c), state cent rounding in (d), and clarify (e); 4. pin the 34-window denominator, calendar-year equity formula, cut-close median/roll counts, `0.5`-pip sensitivity formula across Rules 1-4, and report OPT-only / ALT-only FTMO-day metrics for C162; 5. note the `< 4,000`-bar holiday skip and missing `Grind_LatticeRerollPaused` in `s7`).

Line count: 443
