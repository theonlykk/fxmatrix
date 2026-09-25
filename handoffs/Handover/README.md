# HANDOVER -- START HERE

You are picking up an active algorithmic FX market-making project. Two fleets
of eleven EA instances trade live on two demo accounts right now (cycle 3 on
FTMO from the VPS; Fleet B on IC Markets from the Linux box).

This folder is the entry point for a new chat. Read these in order.

| File | What it is | Rewrite cadence |
|---|---|---|
| `01_BOOT.md` | Roles, machines, conventions, current state | state block every session; rest rarely |
| `02_TRAPS.md` | How the previous chat got things wrong | append when it happens again |
| `03_COOKBOOK.md` | Every endpoint, every archive query, the repos | when a tool is added |
| `04_DEEPSEEK_COURIER.md` | How DeepSeek is reached: the `r1_audit.py` API runner | rarely |
| `05_GIT_AS_TRANSPORT.md` | How specs and responses move through the repo | rarely |
| `06_LINUX_WINE_BOX.md` | The Vultr Ubuntu/Wine box: build, paths, Wine version trap | when it changes |
| `07_ROADMAP.md` | Where the project is going: multi-account, rings, monitoring | when the direction changes |
| `08_BACKLOG.md` | Every open work item, with status | as items land or are dropped |

`08_BACKLOG.md` is the standing list of open work; the newest handoff's
NEXT SESSION block picks from it and orders it. `07_ROADMAP.md` is intent,
not instruction -- read it for context on why a
decision is being framed a certain way, and do not treat anything in it as
ratified unless it says so.

`NEW_CHAT_PROMPT.md` is not part of the reading order -- it is what the
operator pastes to start a new chat. Update it only when the workflow
changes, not when the work changes.

Then read, in the fxmatrix repo:

- `docs/architecture/ARCHITECT.md` -- the governing engineering document.
  Binding. Read it before proposing anything.
- `handoffs/HANDOFF_<most recent>.md` -- what happened last session, open
  defects, what is ratified.
- The handoff before that, for deeper history.

## THE ONE-LINE VERSION

fxgrind is a passive limit-order FX market maker. Each instance posts a
two-sided straddle around mid, adds layers as price moves against it,
exits each layer a fixed distance from its own entry, and nets the pair
with CloseBy. Each fleet runs eleven instances: nine pairs on the OPT arm,
plus second instances of AUDNZD and NZDCAD on OPT geometry. Caps are hard.
It never crosses the spread.

## WHAT TO DO FIRST

1. Read this folder and ARCHITECT.md.
2. Ask the operator to paste a status URL (see `03_COOKBOOK.md`) and read
   the live fleet before forming any view.
3. Check `git log --oneline -1 origin/main` on both repos, and whether the
   VPS is on that commit. They diverge more often than you would think.
4. Ask questions. The previous chat may still be open; the operator will
   carry them across.

## WHEN YOU WRITE THE NEXT HANDOVER

Update `01_BOOT.md`'s state block and append to `02_TRAPS.md`. Leave the
rest unless it is actually wrong. That includes `NEW_CHAT_PROMPT.md` --
it points at the handoff rather than duplicating it, and should not acquire
work items. The point of this folder is that it stops
being rewritten from scratch every time.

Keep the per-session detail in `handoffs/HANDOFF_<date>.md`. This folder is
a pointer, not a duplicate.
