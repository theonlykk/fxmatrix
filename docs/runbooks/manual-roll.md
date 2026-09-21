This message has a line count at the bottom

# RUNBOOK -- MANUAL ROLL OF A CAPPED SIDE

Operator procedure until the EA can eject on command (backlog C15).
First done 2026-09-21 on AUDCAD OPT and ALT, cycle 2.

**What a roll is:** close the DEEPEST layer of a capped side at the
market. The engine then re-quotes the side's next add, which lands near
the market (clamped passive) -- so the ladder moves up to price rather
than shrinking. The slot that was waiting for a full retrace now pays on
a retrace of `InpExitPips`.

**Why it can be worth it:** with add spacing `a` below exit `X`, a
retrace from the top of a ladder earns about `X / a` pips per pip beyond
the first `X`. The top of the ladder is where the money is; the deepest
layer only pays on a full retrace. The realised loss is NOT a new cost --
it was already in MTM. What a roll gives up is the deep layer's chance of
coming back, plus ~0.06 USD commission.

**What it does NOT do:** reduce exposure in a trend. The side stays at
the cap (AUDCAD OPT re-capped within nine minutes on 2026-09-21).

---

## 1. TRIGGER (pre-registered for cycle 3)

Roll a side only if ALL hold:

- it has been at its cap for **24 hours or more**
- its deepest layer is **50 pips or more** underwater
- the side has not been rolled in the last **24 hours**

One layer per roll. Never two sides of one instance at once.

---

## 2. PROCEDURE (VPS)

Record first: instance, side, ticket of the DEEPEST layer (lowest
`layer_index` still open; for a short, the lowest entry; for a long, the
highest), its entry price.

1. **Remove the EA** from that instance's chart. Check the chart title
   and magic -- OPT and ALT share a symbol.
2. **Delete that instance's ENTRY orders** (`...|ENT` comments). A fill
   while detached is a layer with no exit. **Leave every `...|EXT` order
   alone.**
3. **Close the deepest layer's position** (Trade tab -> close). Note the
   deal number and close price from History.
4. **Reattach.** Load the instance's preset, then **read every geometry
   input back against the status page before OK**: add, exit, width,
   stranded, max layers, magic, slot, lots. **Exit must match what is
   running**, or the instance halts on startup (`I6_*_EXIT`) -- as
   AUDCAD ALT did on 2026-09-21 when the preset still held a stale exit.
   Paste the telemetry key LAST, then OK.
5. **Status read** within two minutes: not halted, `recon_ok`, the side
   one layer shorter, and a new add resting near the market.

If step 5 shows a halt: remove the EA, reattach with the correct values.
Do not compile to clear it.

---

## 3. LOG -- EVERY ROLL

Manual closes are invisible to pipshed and to the EA's realised P&L.
Append a row to `docs/runbooks/roll-log.md`:

| date/time UTC | instance | side | ticket | entry | close | pips | USD (from History) | depth before | notes |
|---|---|---|---|---|---|---:|---:|---:|---|

**24 hours later**, add to the same row: did the new layer scalp; did the
side re-cap; how far did price retrace from the roll price.

That second half is what the ejection design needs: how often a fresh top
layer pays, against how often the rolled layer would have come back.

Line count: 79
